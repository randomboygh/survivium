extends RefCounted
## Access from the internet (plan/architecture/server.md, «Доступ из интернета», decision
## 153 6Б): runs Cloudflare's `cloudflared tunnel --url http://localhost:<port>` beside
## the server and reads the address it gives (`https://<words>.trycloudflare.com`) from
## what it prints; friends join `wss://<words>.trycloudflare.com`, or open the game's page
## with `?server=` and that address (`link`). No account and no router setup: a quick
## tunnel gets a new address each start. `cloudflared` is looked for where it was told
## (Config.cloudflared), beside the game's executable, then on the PATH; without it
## `failed` says how to get it. Only on a computer (OS.execute_with_pipe).

## Where the web build lives; a friend's link opens it with the server's address.
const PAGE := "https://randomboygh.github.io/survivium/"
## Bytes read from cloudflared's output a poll at most, and kept to look for the address.
const READ := 4096
const KEPT := 16384

## The address found ("" until cloudflared gives it): wss://….trycloudflare.com.
var url := ""
## Why the tunnel is not there, "" while it runs or starts.
var failed := ""
## The program run, and its process.
var program := ""
var pid := 0
var _pipes := {}
var _text := ""


## Starts cloudflared for the server's `port`, the program at `path` ("" to look for
## it); false (and `failed` says why) when it cannot.
func start(port: int, path := "") -> bool:
	program = find(path)
	if program == "":
		failed = "cloudflared не найден: скачайте его с github.com/cloudflare/cloudflared/releases и положите рядом с игрой"
		return false
	var args := PackedStringArray(["tunnel", "--no-autoupdate", "--url", "http://localhost:%d" % port])
	_pipes = OS.execute_with_pipe(program, args, false)
	if _pipes.is_empty():
		failed = "cloudflared не запустился: " + program
		return false
	pid = int(_pipes.pid)
	return true


## Reads what cloudflared printed since the last poll; true when the address was found
## just now.
func poll() -> bool:
	if _pipes.is_empty():
		return false
	var before := url
	for k in ["stderr", "stdio"]:
		var f: FileAccess = _pipes.get(k)
		if f == null:
			continue
		var got := f.get_buffer(READ)
		if not got.is_empty():
			_text = (_text + got.get_string_from_utf8()).right(KEPT)
	if url == "":
		var found := url_in(_text)
		if found != "":
			url = found
	if url == "" and pid > 0 and not OS.is_process_running(pid):
		failed = "cloudflared остановился, не дав адреса"
		_pipes = {}
	return url != before


## Stops cloudflared.
func stop() -> void:
	if pid > 0 and OS.is_process_running(pid):
		OS.kill(pid)
	pid = 0
	_pipes = {}


## The page of the game that opens «Присоединиться» with this server's address.
func link() -> String:
	return PAGE + "?server=" + url if url != "" else ""


## The quick tunnel's address in cloudflared's output `text`, as wss://, "" when none.
static func url_in(text: String) -> String:
	var re := RegEx.create_from_string("https://([a-z0-9-]+\\.trycloudflare\\.com)")
	var m := re.search(text)
	return "wss://" + m.get_string(1) if m != null else ""


## The cloudflared to run: `path` when it is a file, else one beside the game's
## executable, else the name for the PATH (when `which`/`where` finds it); "" for none.
static func find(path := "") -> String:
	if path != "":
		return path if FileAccess.file_exists(path) else ""
	var exe := "cloudflared.exe" if OS.has_feature("windows") else "cloudflared"
	var beside := OS.get_executable_path().get_base_dir().path_join(exe)
	if FileAccess.file_exists(beside):
		return beside
	var out: Array = []
	if OS.execute("where" if OS.has_feature("windows") else "which", [exe], out) == 0 and not out.is_empty():
		var first := str(out[0]).strip_edges().get_slice("\n", 0).strip_edges()
		if first != "":
			return first
	return ""
