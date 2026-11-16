extends RefCounted
## One's own mod put on the server this game is a host of (stage 2 item 3, step 7;
## Protocol.MOD_PUT): the content editor's saves, joined to a server far away, send the
## mod's zip (ModZip.pack) in pieces of Protocol.MOD_PIECE, each after the answer to the
## one before; the server unpacks it, reads it and sends its files to every player, this
## game too (ModReload). Not more often than EVERY (the server refuses one sooner,
## Requests.MOD_PUT_EVERY): a save in between is put once the time is up, so the last
## one always gets there. Of the game, not of the editor's window: closing the editor
## does not stop a put.

const Protocol := preload("res://src/shared/net/protocol.gd")
const ModZip := preload("res://src/shared/content/mod_zip.gd")
const Lang := preload("res://src/shared/content/lang.gd")

## Seconds between two puts (above Requests.MOD_PUT_EVERY).
const EVERY := 5.5

## The connection to the server, the mod's folder and what is told how it went
## (`told(text: String)`, dropped when its object is gone).
static var net = null
static var dir := ""
static var told := Callable()
## Which put is going on (a later one drops an earlier's answers), whether one is going
## on, whether another is wanted after it, when the last began (msec), and how many were
## put whole.
static var number := 0
static var busy := false
static var again := false
static var began := -1000000
static var done := 0


## Puts the own mod in folder `mod_dir` on the server of connection `connection` now, or
## once EVERY seconds have gone since the last; `tell` gets what to show.
static func put(connection, mod_dir: String, tell: Callable) -> void:
	net = connection
	dir = mod_dir
	told = tell
	var wait := EVERY - (Time.get_ticks_msec() - began) / 1000.0
	if busy or wait > 0.0:
		if not again and not busy:
			(Engine.get_main_loop() as SceneTree).create_timer(wait).timeout.connect(_later)
		again = true
		return
	again = false
	var bytes := ModZip.pack(dir)
	var pieces := ceili(bytes.size() / float(Protocol.MOD_PIECE))
	if bytes.is_empty() or pieces > Protocol.MOD_PIECES:
		_tell("[editor_too_large_for_server]")
		return
	number += 1
	busy = true
	began = Time.get_ticks_msec()
	_tell("[editor_putting_on_server]")
	_piece(dir.trim_suffix("/").get_file(), bytes, 0, pieces, number)


static func _later() -> void:
	if again and not busy:
		again = false
		put(net, dir, told)


static func _piece(id: String, bytes: PackedByteArray, i: int, n: int, which: int) -> void:
	var piece := bytes.slice(i * Protocol.MOD_PIECE, (i + 1) * Protocol.MOD_PIECE)
	net.request(Protocol.MOD_PUT, [id, i, n, piece]).then(_answered.bind(id, bytes, i, n, which))


## The server's answer `v` to piece `i` of `n`: the next piece, or what came of the whole.
static func _answered(v: Variant, id: String, bytes: PackedByteArray, i: int, n: int, which: int) -> void:
	if which != number:
		return
	if v is bool and v and i + 1 < n:
		_piece(id, bytes, i + 1, n, which)
		return
	busy = false
	var error := str(v.get("error", "")) if v is Dictionary else ""
	if v is Dictionary and error == "":
		done += 1
		_tell(Lang.line("[editor_put_on_server]", [int(v.get("files", 0)), id]))
	elif error.begins_with("[") and error.length() <= 64:
		_tell(error)
	else:
		_tell("[editor_server_refused]")
	if again:
		again = false
		put(net, dir, told)


static func _tell(text: String) -> void:
	if told.is_valid():
		told.call(text)
	print("mod put: ", Lang.t(text) if text.begins_with("[") else text)
