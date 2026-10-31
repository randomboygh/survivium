extends RefCounted
## What this device keeps of the servers it joined (plan/architecture/server.md, «Меню и
## экраны»), in `user://servers.cfg`: the key each server gave the player (by address,
## sent back in HELLO so the server knows them again), the servers joined lately with
## their names (the «Присоединиться» screen lists them) and the name the player goes by.
## Also how an address typed by hand is read: `normalize` and `problem`.

const Protocol := preload("res://src/shared/net/protocol.gd")

## The file; a test points it elsewhere.
static var path := "user://servers.cfg"
## Servers kept in the list of recent ones, the newest first.
const RECENT := 5
## Letters of a name at most (the server cuts it there too).
const NAME_MAX := 24


static func _read() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(path)
	return cfg


## The key `url` gave the player before, "" the first time.
static func key(url: String) -> String:
	return str(_read().get_value("keys", url, ""))


## The server of `url` let the player in: its key, and the server goes first in the
## recent ones under its name `title`.
static func remember(url: String, given_key: String, title: String) -> void:
	var cfg := _read()
	cfg.set_value("keys", url, given_key)
	cfg.set_value("recent", url, [title, int(Time.get_unix_time_from_system())])
	var all := recent_of(cfg)
	for r: Dictionary in all.slice(RECENT):
		cfg.erase_section_key("recent", r.url)
	cfg.save(path)


## The recent servers, the newest first: {url, title, at (unix seconds)} each.
static func recent() -> Array[Dictionary]:
	return recent_of(_read())


static func recent_of(cfg: ConfigFile) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not cfg.has_section("recent"):
		return out
	for url in cfg.get_section_keys("recent"):
		var v: Variant = cfg.get_value("recent", url)
		if v is Array and v.size() == 2:
			out.append({"url": url, "title": str(v[0]), "at": int(v[1])})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.at > b.at)
	return out


## Takes `url` out of the recent ones (its key stays, so the player comes back as the same).
static func forget(url: String) -> void:
	var cfg := _read()
	if cfg.has_section_key("recent", url):
		cfg.erase_section_key("recent", url)
		cfg.save(path)


## The name the player went by last time, "" before the first.
static func player_name() -> String:
	return str(_read().get_value("player", "name", ""))


static func set_player_name(name: String) -> void:
	var cfg := _read()
	cfg.set_value("player", "name", name)
	cfg.save(path)


## The address `text` as the socket takes it: spaces gone, `https://` read as `wss://`
## and `http://` as `ws://`, none at all as `wss://` for a name (a tunnel's) and `ws://`
## for numbers or `localhost` (the home network); `ws://` without a port gets the
## server's port by default (Protocol.PORT). A slash at the end goes. "" stays "".
static func normalize(text: String) -> String:
	var t := text.strip_edges().replace(" ", "")
	if t == "":
		return ""
	var lower := t.to_lower()
	if lower.begins_with("https://"):
		t = "wss://" + t.substr(8)
	elif lower.begins_with("http://"):
		t = "ws://" + t.substr(7)
	elif not lower.begins_with("ws://") and not lower.begins_with("wss://"):
		var host := t.get_slice("/", 0).get_slice(":", 0)
		var home := host == "localhost" or host.replace(".", "").is_valid_int()
		t = ("ws://" if home else "wss://") + t
	while t.ends_with("/"):
		t = t.left(-1)
	if t.begins_with("ws://"):
		var host_port := t.substr(5).get_slice("/", 0)
		if not ":" in host_port:
			t = "ws://" + host_port + ":%d" % Protocol.PORT + t.substr(5 + host_port.length())
	return t


## What is wrong with the address `url` (normalized), "" when nothing: no host, or a
## page served over https (`secure`, the browser) asked for `ws://`, which the browser
## does not allow but at the device itself.
static func problem(url: String, secure: bool) -> String:
	var host := url.get_slice("://", 1).get_slice("/", 0).get_slice(":", 0)
	if url == "" or host == "":
		return "Введите адрес сервера"
	if secure and url.begins_with("ws://") and host != "localhost" and host != "127.0.0.1":
		return "Из браузера — только wss:// (сервер через туннель)"
	return ""
