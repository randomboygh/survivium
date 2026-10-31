extends RefCounted
## The settings of a server (plan/architecture/server.md, «Хозяин сервера»): read from
## `user://server.cfg` (the window «Создать сервер» will write the same file, С5, so a
## server set up there starts from the terminal the same), then the user arguments of
## the command line over it: `godot --headless -- --server [--config <file>] [--port N]
## [--world <folder>] [--seed N] [--players N] [--password <word>] [--name <title>]
## [--autosave <seconds>] [--no-save]`. The
## world is a folder of the game's own saves (WorldStore.root: a name under it, or a
## path), or the world of `seed_value` and `settings` (a new one when it has no save).

const WorldGen := preload("res://src/shared/world/world_gen.gd")
const WorldStore := preload("res://src/shared/world/world_store.gd")

const FILE := "user://server.cfg"
## Players a server takes at most, by default; the port by default.
const PLAYERS := 8
const PORT := 7777

## The server's name, for the players.
var title := "Survivium"
var port := PORT
var max_players := PLAYERS
## The word a player must give to come in; "" asks none.
var password := ""
## The folder of the world's save: a name under WorldStore.root ("20261018-11111") or a
## path; "" for the world of `seed_value` and `settings`.
var world := ""
var seed_value := 20261018
## WorldGen's settings of a new world.
var settings: Dictionary = WorldGen.DEFAULT_SETTINGS.duplicate()
## The bundles of a new world; empty for every bundle there is.
var mods: Array = []
## The terminal is read for commands (not in tests).
var console := true
## The address to listen on: "*" every one of this machine's.
var bind := "*"
## Seconds between saves of the world (ServerStore); the world is not saved at all
## when `save` is off (a test world tried out).
var autosave := 10.0
var save := true


## Reads `path` (a ConfigFile); a file that is not there leaves the defaults.
func read(path := FILE) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	title = str(cfg.get_value("server", "title", title))
	port = int(cfg.get_value("server", "port", port))
	max_players = int(cfg.get_value("server", "players", max_players))
	password = str(cfg.get_value("server", "password", password))
	bind = str(cfg.get_value("server", "bind", bind))
	autosave = float(cfg.get_value("server", "autosave", autosave))
	save = bool(cfg.get_value("server", "save", save))
	world = str(cfg.get_value("world", "folder", world))
	seed_value = int(cfg.get_value("world", "seed", seed_value))
	for k: String in settings:
		settings[k] = int(cfg.get_value("world", k, settings[k]))
	var m: Variant = cfg.get_value("world", "mods", mods)
	mods = Array(m) if m is Array or m is PackedStringArray else mods


## Writes the settings to `path`.
func write(path := FILE) -> bool:
	var cfg := ConfigFile.new()
	cfg.set_value("server", "title", title)
	cfg.set_value("server", "port", port)
	cfg.set_value("server", "players", max_players)
	cfg.set_value("server", "password", password)
	cfg.set_value("server", "bind", bind)
	cfg.set_value("server", "autosave", autosave)
	cfg.set_value("server", "save", save)
	cfg.set_value("world", "folder", world)
	cfg.set_value("world", "seed", seed_value)
	for k: String in settings:
		cfg.set_value("world", k, settings[k])
	cfg.set_value("world", "mods", mods)
	return cfg.save(path) == OK


## Takes the command line's user `args` (after `--`) over what was read; the settings
## file named by `--config` is read first.
func take_args(args: PackedStringArray) -> void:
	var i := args.find("--config")
	if i >= 0 and i + 1 < args.size():
		read(args[i + 1])
	var j := 0
	while j < args.size():
		var next := args[j + 1] if j + 1 < args.size() else ""
		match args[j]:
			"--port":
				port = int(next)
				j += 1
			"--players":
				max_players = int(next)
				j += 1
			"--password":
				password = next
				j += 1
			"--name":
				title = next
				j += 1
			"--world":
				world = next
				j += 1
			"--seed":
				seed_value = int(next)
				world = ""
				j += 1
			"--bind":
				bind = next
				j += 1
			"--autosave":
				autosave = maxf(1.0, float(next))
				j += 1
			"--no-save":
				save = false
		j += 1


## The path of the world's save folder: `world` as given when it is a path, else under
## WorldStore.root; the folder of `seed_value` and `settings` when `world` is "".
func world_path() -> String:
	if world == "":
		return WorldStore.world_dir(seed_value, settings)
	if world.contains("://") or world.begins_with("/"):
		return world
	return WorldStore.root + "/" + world
