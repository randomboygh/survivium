extends RefCounted
## The end of the log of the game's last run on this device, for «Данные для теста»
## (SettingsMenu.report_text): an app on a phone that crashes shows no message, but the
## engine's file log (user://logs, on a computer and on Android; the browser keeps none)
## tells after the next start what it was doing last. The engine renames the last run's
## godot.log to godot<date and time>.log at the start, so the newest of those is it.

const DIR := "user://logs"
const LINES := 30
## Kept while the game runs in front: found at the next start, the last run ended in a
## crash, not by quitting or being sent away (main.gd _notification).
const RUNNING := "user://running"

## The last run crashed (begin): the main menu offers its log («Журнал вылета»).
static var crashed := false
static var _begun := false


## At the game's first start in this process (not again for another world): whether the
## last run crashed; the game runs now. The browser keeps no log.
static func begin() -> void:
	if _begun or OS.has_feature("web"):
		return
	_begun = true
	crashed = FileAccess.file_exists(RUNNING) and tail() != ""
	running(true)


## The game is in front (true) or was closed or sent away (false).
static func running(on: bool) -> void:
	if not _begun:
		return
	if on:
		var f := FileAccess.open(RUNNING, FileAccess.WRITE)
		if f != null:
			f.store_string("1")
	elif FileAccess.file_exists(RUNNING):
		DirAccess.remove_absolute(RUNNING)


## The last LINES lines of the last run's log, "" when there is none.
static func tail() -> String:
	var dir := DirAccess.open(DIR)
	if dir == null:
		return ""
	var newest := ""
	for f in dir.get_files():
		if f.begins_with("godot") and f.ends_with(".log") and f != "godot.log" and f > newest:
			newest = f
	if newest == "":
		return ""
	var text := FileAccess.get_file_as_string(DIR.path_join(newest)).strip_edges()
	var lines := text.split("\n")
	return "%s:\n%s" % [newest, "\n".join(lines.slice(maxi(0, lines.size() - LINES)))]
