extends RefCounted
## The terminal of a server run headless (plan/architecture/server.md, «Терминал»): a
## thread reads the standard input, since a read blocks, and `lines()` gives the lines
## that came in, for the server's commands (Server.command). The thread ends when the
## input ends (a pipe closed) or after a line that stops the server (STOP), when it can
## be joined; a server stopped another way quits with the thread still in its read, and
## the engine notes the thread was not joined (harmless at exit).

## The command that stops the server, after which the thread ends.
const STOP := "stop"
## Bytes read at a time.
const BUFFER := 4096

var _thread: Thread
var _mutex := Mutex.new()
var _lines: PackedStringArray = []
var _rest := ""
var _over := false


## Starts reading the input.
func start() -> void:
	_thread = Thread.new()
	_thread.start(_read)


## The lines that came in since the last call, without their line ends.
func lines() -> PackedStringArray:
	_mutex.lock()
	var out := _lines
	_lines = PackedStringArray()
	_mutex.unlock()
	return out


## The input ended, or the stop line came: the thread is done and is joined.
func over() -> bool:
	return _over


## Joins the thread if it is done; true when it was, or there is none.
func stop() -> bool:
	if _thread == null:
		return true
	if not _over:
		return false
	_thread.wait_to_finish()
	_thread = null
	return true


func _read() -> void:
	while true:
		var got := OS.read_buffer_from_stdin(BUFFER)
		if got.is_empty():
			break
		var text := _rest + got.get_string_from_utf8()
		var parts := text.split("\n")
		_rest = parts[parts.size() - 1]
		var stopped := false
		_mutex.lock()
		for i in parts.size() - 1:
			var line := parts[i].strip_edges()
			if line != "":
				_lines.append(line)
			if line == STOP:
				stopped = true
		_mutex.unlock()
		if stopped:
			break
	_over = true
