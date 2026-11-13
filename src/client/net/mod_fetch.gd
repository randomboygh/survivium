extends RefCounted
## Takes the mods' files of a server (decision 189): given the hash that names the
## server's set and its bundles, finds where each of its files is on this device (the
## game's own file when its bytes are the same, the built-in copy's, one kept from a
## server before, ModCache), asks the server for the list (unless the set is kept) and
## for the files that are nowhere here, keeps them as they come (each checked, ModCache)
## and ends with `table`: every path of the set → the file that holds it, for
## Content.serve. Used before the game is let into a server whose files are not its own
## (Main, the loading screen shows `got` of `want`) and in the game when the server's
## host reloaded the data (ModReload). What a server sends is never trusted: the list
## and each file are checked (ModFiles.unpack, may_be), and a server that goes quiet for
## STALL seconds ends the taking.

const Protocol := preload("res://src/shared/net/protocol.gd")
const Content := preload("res://src/shared/content/content.gd")
const ModFiles := preload("res://src/shared/content/mod_files.gd")
const ModCache := preload("res://src/client/net/mod_cache.gd")

## Seconds without a word from the server before the taking fails.
const STALL := 20.0
## Hashes asked for in one message, and asked for and not come yet at most.
const BATCH := 200
const WINDOW := 800
## Bytes of files taken without asking the player first.
const ASK_ABOVE := 50 << 20
## Bytes a piece may be once unpacked.
const PIECE_MAX := 1 << 20

## The taking ended: `state` is "done" (`table` is whole) or "failed" (`error` says why).
signal finished(ok: bool)

## The connection (Connection), and what is taken: the set's hash and bundles.
var net
var digest := ""
var bundles: Array = []
## "" not begun, "list" waiting for the list, "ask" waiting for the player's yes (more
## than ASK_ABOVE to take: `allow`), "files" taking files, "done", "failed".
var state := ""
## Why it failed: words for the player (a key).
var error := ""
## The set's files ({path: [hash, size]}), and where each is on this device.
var list := {}
var table := {}
## The files to take: hash → {"size", "names" (`<hash>.<ext>` → the paths that are it)}.
var need := {}
## Bytes to take and taken, and files.
var want := 0
var got := 0
var files := 0
var _order: Array[String] = []
var _asked := 0
var _waiting := 0
## Files under way: hash → the bytes come so far.
var _open := {}
var _packed: Array = []
var _heard := 0
## Take more than ASK_ABOVE without asking (a bot, a test).
var no_ask := false


## Begins taking the set `set_digest` of `set_bundles` over `connection`.
func begin(connection, set_digest: String, set_bundles: Array) -> void:
	net = connection
	digest = set_digest
	bundles = set_bundles.duplicate()
	_heard = Time.get_ticks_msec()
	net.event.connect(_on_event)
	var kept := ModCache.set_of(digest)
	if not kept.is_empty() and kept.bundles == bundles:
		list = kept.list
		_plan()
		return
	state = "list"
	net.send(Protocol.MOD_LIST, [])


## Call each frame: a server gone quiet fails the taking.
func update() -> void:
	if state in ["list", "files"] and Time.get_ticks_msec() - _heard > STALL * 1000.0:
		_fail("[the_server_does_not_respond]")


## The player agreed to take `want` bytes (state "ask").
func allow() -> void:
	if state == "ask":
		_start()


## Stops listening (the taking is dropped).
func stop() -> void:
	if net != null and net.event.is_connected(_on_event):
		net.event.disconnect(_on_event)
	if state in ["list", "ask", "files"]:
		state = "failed"


## Where each file of `set_list` is on this device and which are missing: {"table" (path →
## file), "need" (hash → {"size", "names"})}.
static func plan(set_list: Dictionary) -> Dictionary:
	var own := ModFiles.scan(Content.ROOT)
	var built: Dictionary = ModFiles.listed() if Content.ROOT != ModFiles.BUILT_IN else {}
	var t := {}
	var n := {}
	for rel: String in set_list:
		var hash: String = set_list[rel][0]
		var size: int = set_list[rel][1]
		var ext := rel.get_extension()
		if own.has(rel) and own[rel][0] == hash:
			t[rel] = Content.ROOT.path_join(rel)
		elif built.has(rel) and built[rel][0] == hash:
			t[rel] = ModFiles.BUILT_IN.path_join(rel)
		elif ModCache.has(hash, ext, size):
			t[rel] = ModCache.path(hash, ext)
		else:
			if not n.has(hash):
				n[hash] = {"size": size, "names": {}}
			var name := "%s.%s" % [hash, ext]
			if not n[hash].names.has(name):
				n[hash].names[name] = []
			n[hash].names[name].append(rel)
	return {"table": t, "need": n}


func _plan() -> void:
	var p := plan(list)
	table = p.table
	need = p.need
	want = 0
	_order.clear()
	for hash: String in need:
		want += int(need[hash].size)
		_order.append(hash)
	files = _order.size()
	if need.is_empty():
		_finish()
	elif want > ASK_ABOVE and not no_ask:
		state = "ask"
	else:
		_start()


func _start() -> void:
	state = "files"
	_heard = Time.get_ticks_msec()
	_ask_more()


func _ask_more() -> void:
	while _asked < _order.size() and _waiting + BATCH <= WINDOW:
		var batch := _order.slice(_asked, _asked + BATCH)
		_asked += batch.size()
		_waiting += batch.size()
		net.send(Protocol.MOD_FILES, [Array(batch)])


func _on_event(kind: String, args: Variant) -> void:
	if kind == Protocol.MOD_LIST and state == "list":
		_heard = Time.get_ticks_msec()
		if not args is Array or args.size() != 2:
			_fail("[the_server_answered_in_an]")
			return
		list = ModFiles.unpack(args[0], args[1])
		if list.is_empty() or ModFiles.digest(list) != digest:
			_fail("[the_server_answered_in_an]")
			return
		_packed = args
		_plan()
	elif kind == Protocol.MOD_DATA and state == "files":
		_heard = Time.get_ticks_msec()
		if not args is Array:
			_fail("[the_server_answered_in_an]")
			return
		for part: Variant in args:
			if not _take(part):
				return
		_ask_more()
		if need.is_empty() and state == "files":
			_finish()


## Takes one piece ([hash, offset, the file's bytes, bytes before packing, the piece]);
## false when the taking failed on it.
func _take(part: Variant) -> bool:
	if not part is Array or part.size() != 5 or not part[0] is String or not part[1] is int or not part[2] is int \
			or not part[3] is int or not part[4] is PackedByteArray or not need.has(part[0]):
		_fail("[the_server_answered_in_an]")
		return false
	var hash: String = part[0]
	var size: int = need[hash].size
	if part[2] < 0:
		_fail("[the_server_could_not_give]")
		return false
	var piece: PackedByteArray = part[4]
	if part[3] > 0:
		if part[3] > PIECE_MAX:
			_fail("[the_server_answered_in_an]")
			return false
		piece = piece.decompress(part[3], FileAccess.COMPRESSION_ZSTD)
		if piece.size() != part[3]:
			_fail("[the_server_answered_in_an]")
			return false
	var bytes: PackedByteArray = _open.get(hash, PackedByteArray())
	if part[2] != size or part[1] != bytes.size() or bytes.size() + piece.size() > size:
		_fail("[the_server_answered_in_an]")
		return false
	bytes.append_array(piece)
	got += piece.size()
	if bytes.size() < size:
		_open[hash] = bytes
		return true
	_open.erase(hash)
	for name: String in need[hash].names:
		if not ModCache.store(hash, name.get_extension(), bytes):
			_fail("[a_mod_file_from_the]")
			return false
		for rel: String in need[hash].names[name]:
			table[rel] = ModCache.path(hash, name.get_extension())
	need.erase(hash)
	_waiting -= 1
	return true


func _finish() -> void:
	if not _packed.is_empty():
		ModCache.keep_set(digest, bundles, _packed)
	var kept := ModCache.in_use(table)
	ModCache.used(kept.keys())
	ModCache.trim(ModCache.LIMIT, kept)
	state = "done"
	stop()
	finished.emit(true)


func _fail(why: String) -> void:
	if state in ["done", "failed"]:
		return
	error = why
	state = "failed"
	_open.clear()
	stop()
	finished.emit(false)
