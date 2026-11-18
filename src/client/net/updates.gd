extends Node
## A newer build of the game and what it brings, for «Что нового» (the main menu's dot on the
## button, the update's changes on top of the page, «Обновить»), and the changes that came since
## the build run before this one.
##
## Every merge into main deploys the web build with `latest.json` beside it (tools/build_info.py
## --latest: the version, when its PR was merged, its newest changes) and publishes the same
## build as the GitHub release marked latest (APK, Windows, Linux). A build of main asks for that
## file once a run, WAIT s after the menu shows (the phone's cold start is not slowed); offline,
## or for a build of a pull request or the editor, nothing is asked and nothing shows.
## A build is newer when its PR was merged later than this one's: the version's number is the
## PR's, which can go down when a smaller PR merges later.

const Protocol := preload("res://src/shared/net/protocol.gd")
const Playtest := preload("res://src/client/net/playtest.gd")

## The web build, always the newest of main (src/server/tunnel.gd PAGE).
const PAGE := "https://randomboygh.github.io/survivium/"
const LATEST := PAGE + "latest.json"
const RELEASES := "https://github.com/%s/releases/latest" % Playtest.REPO
## The builds this device ran: [run] merged and version of this one, of the one before.
const PATH := "user://versions.cfg"
## Seconds after the menu shows before asking, and how long the asking may take.
const WAIT := 3.0
const TIMEOUT := 15.0
## The web build's update: the game's pack and the page asked again past the browser's cache
## (Pages lets it keep them ten minutes), then the page reloaded with them.
const RELOAD_JS := "(function(){'use strict';var o={cache:'reload'};" \
		+ "Promise.all([fetch('index.pck',o),fetch(location.href,o)])" \
		+ ".catch(function(){}).then(function(){location.reload();});})();"

## A newer build was found (`latest` holds it).
signal found

## The tests' own file (scene tests keep the player's).
static var path := PATH
## The newer build: {"version", "merged", "changes": [...]} as build_info.json, {} when none.
static var latest := {}
## When the PR of the build run before this one was merged, and its version; "" when none
## (the first run on this device).
static var before := ""
static var before_version := ""
static var _asked := false
static var _noted := false


## The build that runs: this one's build_info.json.
static func mine() -> Dictionary:
	return Protocol.build_info()


## When the PR of build `info` was merged (UTC, "2026-11-18T14:07:00Z"); "" when unknown (a
## run from the editor). Builds before this field take their newest change's.
static func merged_of(info: Dictionary) -> String:
	var m := str(info.get("merged", ""))
	if m == "":
		var changes: Variant = info.get("changes", [])
		if changes is Array and not changes.is_empty() and changes[0] is Dictionary:
			m = str(changes[0].get("merged", ""))
	return m


## Whether this build looks for a newer one: a build of main (not "dev", not a pull request's
## "+pr"), with a screen.
static func checks() -> bool:
	var v := Protocol.build_version()
	return not v.ends_with("dev") and not "+" in v and merged_of(mine()) != "" \
			and DisplayServer.get_name() != "headless"


## Remembers this run's build once a run; a build other than the one remembered moves that one
## to `before`, whose changes since are this build's new ones.
static func note_run(info := mine()) -> void:
	if _noted:
		return
	_noted = true
	var own := merged_of(info)
	if own == "":
		return
	var cfg := ConfigFile.new()
	cfg.load(path)
	var last := str(cfg.get_value("run", "merged", ""))
	if last == own:
		before = str(cfg.get_value("run", "before", ""))
		before_version = str(cfg.get_value("run", "before_version", ""))
		return
	before = last
	before_version = str(cfg.get_value("run", "version", ""))
	cfg.set_value("run", "merged", own)
	cfg.set_value("run", "version", str(info.get("version", "")))
	cfg.set_value("run", "before", before)
	cfg.set_value("run", "before_version", before_version)
	cfg.save(path)


## Whether change `c` of this build came since the build run before it.
static func is_new(c: Dictionary, info := mine()) -> bool:
	var m := str(c.get("merged", ""))
	return before != "" and m > before and m <= merged_of(info)


## A newer build is known.
static func newer() -> bool:
	return not latest.is_empty()


## The changes the newer build brings, newest first ([] without one).
static func coming(info := mine()) -> Array:
	var own := merged_of(info)
	var out := []
	for c: Variant in latest.get("changes", []):
		if c is Dictionary and str(c.get("merged", "")) > own:
			out.append(c)
	return out


## Takes the newer build's file `data` (parsed latest.json): kept when its PR merged after this
## build's. Returns whether it is newer.
static func take(data: Variant, info := mine()) -> bool:
	if not data is Dictionary or not data.get("changes") is Array:
		return false
	var own := merged_of(info)
	if own == "" or merged_of(data) <= own:
		return false
	latest = data
	return true


## Gets the newer build: the web page reloaded, the APK or the PC archive of the latest
## release downloaded by the system's browser.
static func update() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval(RELOAD_JS, true)
		return
	var file := Protocol.game_name().to_lower().replace(" ", "-")
	if OS.has_feature("android"):
		OS.shell_open("%s/download/%s-android.apk" % [RELEASES, file])
	elif OS.has_feature("windows"):
		OS.shell_open("%s/download/%s-windows.zip" % [RELEASES, file])
	elif OS.has_feature("linuxbsd"):
		OS.shell_open("%s/download/%s-linux.tar.gz" % [RELEASES, file])
	else:
		OS.shell_open(RELEASES)


func _ready() -> void:
	note_run()
	if newer():
		found.emit.call_deferred()
	if _asked or not checks():
		return
	_asked = true
	await get_tree().create_timer(WAIT).timeout
	var req := HTTPRequest.new()
	req.timeout = TIMEOUT
	add_child(req)
	req.request_completed.connect(_on_answer.bind(req))
	# The time in the address: past any cache between here and Pages.
	if req.request("%s?t=%d" % [LATEST, int(Time.get_unix_time_from_system())]) != OK:
		req.queue_free()


func _on_answer(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, req: HTTPRequest) -> void:
	req.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		print("updates: no answer from %s (result %d, code %d)" % [LATEST, result, code])
		return
	if take(JSON.parse_string(body.get_string_from_utf8())):
		print("updates: a newer build %s" % latest.get("version", "?"))
		found.emit()
