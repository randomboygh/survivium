extends Node
## The playtest server's own part (Config.playtest: .github/workflows/playtest.yml,
## docs/systems/network.md "A server for checking"), a child of the server's scene: it
## stops the server when its minutes are over and gives it an hour more on «/test hour»
## (at most MOST_MINUTES from its start). The bots, the other worlds and «/test» itself,
## which any player may send there, are TestCommands'.

const Lang := preload("res://src/shared/content/lang.gd")
## Minutes a server lives at most (the workflow's job ends at 320).
const MOST_MINUTES := 300
const HOUR := 60
## Minutes before the end when the players are told.
const WARN := 5

## The server's scene (server_main.gd): its `server`, `config` and `say`.
var main: Node
var _start := 0.0
var _end := 0.0
var _warned := false
var _clock := 0.0


func _init(m: Node) -> void:
	main = m


func _ready() -> void:
	_start = Time.get_unix_time_from_system()
	_end = _start + main.config.minutes * 60.0 if main.config.minutes > 0 else 0.0
	main.say("playtest server: %s, bots %d; «/test» for everyone" % [left_text(), main.config.bots])


func _process(delta: float) -> void:
	_clock += delta
	if _clock < 1.0 or _end <= 0.0 or main.server == null or main.server.stopping:
		return
	_clock = 0.0
	var left := _end - Time.get_unix_time_from_system()
	if left <= 0.0:
		main.say("the playtest server's time is up")
		main.server.stop()
	elif left <= WARN * 60.0 and not _warned:
		_warned = true
		_tell_all(Lang.line("[the_test_server_stops_in]", [ceili(left / 60.0)]))


## «/test hour»: an hour more; the answer.
func extend() -> String:
	if _end <= 0.0:
		return "The server has no time limit"
	var most := _start + MOST_MINUTES * 60.0
	if _end >= most - 60.0:
		return "No longer: %s" % left_text()
	_end = minf(_end + HOUR * 60.0, most)
	_warned = false
	main.say("playtest server extended: " + left_text())
	return "Extended: " + left_text()


## How long the server has left, in words.
func left_text() -> String:
	if _end <= 0.0:
		return "no time limit"
	return "%d min left" % maxi(0, ceili((_end - Time.get_unix_time_from_system()) / 60.0))


func _tell_all(text: String) -> void:
	for key in main.server.accounts:
		main.server.accounts[key].link.hear(0, "", text)
