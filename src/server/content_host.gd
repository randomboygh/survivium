extends RefCounted
## What a server gives of its mods' files (decision 189): the list of the files its world
## plays with (ModFiles.of_set: every YAML, the pictures and sounds of the world's
## bundles), the hash that names them (`digest`, said in the refusal WHY_MODS and compared
## with a game's at HELLO), and the files themselves, cut in pieces and sent to each
## connection no faster than RATE (a Feed per connection: what it asked for and how far
## the sending went). A game whose files are the same asks for nothing; one that lacks
## some asks for those by hash. The list is read from disk at the first need and again by
## `read` (the host's `reload`). Files may be put over the mods' own (`over`: the test mod
## of a server for checking, TestMod): the list names them, and `table` is what the
## server's own data is then read through (Content.serve).

const ModFiles := preload("res://src/shared/content/mod_files.gd")
const Protocol := preload("res://src/shared/net/protocol.gd")

## Bytes of files in one message (several small files, or a piece of a large one).
const PIECE := 96 << 10
## Bytes of files a connection is sent a second, and at once after a quiet while.
const RATE := 2 << 20
const BURST := 512 << 10
## While a connection has more than this waiting to go out, nothing is added (a slow
## link takes what it can).
const BUFFERED_MAX := 512 << 10
## Hashes a connection may ask for in one message, and have waiting.
const ASK_MAX := 256
const QUEUE_MAX := 4096
## Times a connection may be sent the list, and the bytes of files it may be sent in all,
## as a multiple of the set's bytes: one that asks for more is not answered.
const LISTS_MAX := 8
const SENT_MAX := 3


## What one connection asked for and how far the sending went.
class Feed extends RefCounted:
	## The hashes asked for and not sent yet, in order.
	var queue: Array[String] = []
	## The file being sent (the first of the queue): its bytes and how many went.
	var bytes := PackedByteArray()
	var loaded := ""
	var at := 0
	## Bytes it may be sent now (RATE), and when that was counted.
	var tokens := float(BURST)
	var tokens_at := -1.0
	## Lists and bytes of files sent so far.
	var lists := 0
	var sent := 0


## Files put over the mods' own, or added to them: {path inside content/: the file}. Of
## the process, like Content.served: a new world of the server keeps them.
static var over := {}

## The mods' folder and the bundles of the world.
var root := ""
var bundles: Array = []
## Every file of the folder with those put over: {path inside content/: [hash, size]}.
var all := {}
## The files: {path inside content/: [hash, size]}, and the path of each hash.
var list := {}
var by_hash := {}
## The hash that names the files, their bytes, and the list packed for the wire.
var digest := ""
var size := 0
var packed: Array = []
var _read_once := false
## A file asked for that is no longer what the list says ("" none): its path.
var changed := ""


func _init(mods_root: String, world_bundles: Array) -> void:
	root = mods_root
	bundles = world_bundles.duplicate()


## Reads the list from disk if it was not read yet.
func ready() -> void:
	if not _read_once:
		read()


## Reads the list from disk again (for `set` when given: the world's bundles now); whether
## the files changed.
func read(set: Array = []) -> bool:
	_read_once = true
	if not set.is_empty():
		bundles = set.duplicate()
	var was := digest
	changed = ""
	all = ModFiles.scan(root).duplicate()
	for rel: String in over:
		var f := FileAccess.open(over[rel], FileAccess.READ)
		if f != null and ModFiles.valid_path(rel):
			all[rel] = [FileAccess.get_sha256(over[rel]).left(ModFiles.HASH_LEN), f.get_length()]
	list = ModFiles.of_set(all, bundles)
	by_hash = {}
	for rel: String in list:
		by_hash[list[rel][0]] = rel
	digest = ModFiles.digest(list)
	size = ModFiles.total(list)
	packed = ModFiles.pack(list)
	return digest != was


## Where each file is, for the server's own data to be read with those put over
## (Content.serve): {path inside content/: the file}.
func table() -> Dictionary:
	var out := {}
	for rel: String in all:
		out[rel] = over.get(rel, root.path_join(rel))
	return out


## The message with the list for `feed`, empty when it had its share of them.
func list_msg(feed: Feed) -> PackedByteArray:
	ready()
	feed.lists += 1
	if feed.lists > LISTS_MAX:
		return PackedByteArray()
	return Protocol.encode(Protocol.event(Protocol.MOD_LIST, packed))


## Takes `hashes` (the args of MOD_FILES) into the queue of `feed`; false when they are
## not hashes or too many.
func ask(feed: Feed, hashes: Variant) -> bool:
	ready()
	if not hashes is Array or hashes.size() > ASK_MAX or feed.queue.size() + hashes.size() > QUEUE_MAX:
		return false
	for h: Variant in hashes:
		if not ModFiles.valid_hash(h):
			return false
	for h: String in hashes:
		feed.queue.append(h)
	return true


## The messages (MOD_DATA) to send `feed` now, at time `now` (seconds), with `buffered`
## bytes of its connection still waiting to go out.
func pieces(feed: Feed, now: float, buffered: int) -> Array[PackedByteArray]:
	var out: Array[PackedByteArray] = []
	if feed.tokens_at >= 0.0:
		feed.tokens = minf(BURST, feed.tokens + (now - feed.tokens_at) * RATE)
	feed.tokens_at = now
	while not feed.queue.is_empty() and feed.tokens > 0.0 and buffered < BUFFERED_MAX:
		var parts := []
		var room := PIECE
		while room > 0 and not feed.queue.is_empty():
			var hash := feed.queue[0]
			if feed.loaded != hash:
				feed.loaded = hash
				feed.at = 0
				feed.bytes = _bytes_of(hash) if feed.sent <= size * SENT_MAX else PackedByteArray()
				if feed.bytes.is_empty() and not _is_empty(hash):
					# No such file here, or one the server cannot read.
					parts.append([hash, 0, -1, 0, PackedByteArray()])
					feed.queue.pop_front()
					feed.loaded = ""
					continue
			var n := mini(room, feed.bytes.size() - feed.at)
			var piece := feed.bytes.slice(feed.at, feed.at + n)
			var small := piece.compress(FileAccess.COMPRESSION_ZSTD) if n >= 64 else piece
			if n >= 64 and small.size() < n * 9 / 10:
				parts.append([hash, feed.at, feed.bytes.size(), n, small])
				room -= small.size()
				feed.tokens -= small.size()
			else:
				parts.append([hash, feed.at, feed.bytes.size(), 0, piece])
				room -= n
				feed.tokens -= n
			# A file of no bytes still takes room: a message ends.
			room -= 64
			feed.at += n
			feed.sent += n
			if feed.at >= feed.bytes.size():
				feed.queue.pop_front()
				feed.loaded = ""
				feed.bytes = PackedByteArray()
		if parts.is_empty():
			break
		var msg := Protocol.encode(Protocol.event(Protocol.MOD_DATA, parts))
		buffered += msg.size()
		out.append(msg)
	return out


## The bytes of the file of `hash`, empty when the list has none, the file cannot be read
## (a picture of a game exported for a phone is there only as imported) or is not what
## it was when the list was read (`changed` names it: the host is told to `reload`).
func _bytes_of(hash: String) -> PackedByteArray:
	if not by_hash.has(hash):
		return PackedByteArray()
	var path: String = over.get(by_hash[hash], root.path_join(by_hash[hash]))
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	var bytes := FileAccess.get_file_as_bytes(path)
	if ModFiles.hash_of(bytes) != hash:
		changed = by_hash[hash]
		return PackedByteArray()
	return bytes


func _is_empty(hash: String) -> bool:
	return by_hash.has(hash) and int(list[by_hash[hash]][1]) == 0 \
		and FileAccess.file_exists(over.get(by_hash[hash], root.path_join(by_hash[hash])))
