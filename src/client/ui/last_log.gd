extends RefCounted
## The end of the log of the game's last run on this device, for «Данные для теста»
## (SettingsMenu.report_text): an app on a phone that crashes shows no message, but the
## engine's file log (user://logs, on a computer and on Android; the browser keeps none)
## tells after the next start what it was doing last. The engine renames the last run's
## godot.log to godot<date and time>.log at the start, so the newest of those is it.

const DIR := "user://logs"
const LINES := 30


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
