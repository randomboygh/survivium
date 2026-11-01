extends "res://src/shared/game/clock.gd"
## The client's copy of the clock (Clock), fed by the server's snapshots
## (Protocol.CLOCK; Mirror) a few times a second: the time, the season, the weather and
## what it leaves on the ground, for the sky, the sounds and the interface, which read
## it as they read the clock. Between the snapshots it runs the time of day itself
## (advance), at the speed the snapshot gave, so the sun moves every frame; the
## weather's strengths move only with the snapshots (a few times a second is smooth
## enough: they change over minutes). It decides nothing: the seasons turn and the
## weather changes on the server, and the playtest page writes there.

## False until the first snapshot: the season it brings is the world's, not a new one,
## so it is taken without season_changed.
var _synced := false


## Takes the server's snapshot; the first one sets the season quietly.
func from_snapshot(a: Array) -> bool:
	if _synced:
		return super(a)
	var at := SNAPSHOT.find(&"season")
	if at >= 0 and a.size() == SNAPSHOT.size() and (a[at] is int or a[at] is float):
		season = int(a[at])
	if not super(a):
		return false
	_synced = true
	return true


## Runs the time of day for `delta` seconds since the last frame; the day turns, the
## season waits for the server.
func advance(delta: float) -> void:
	if real_time:
		return
	time_of_day += days(delta)
	if time_of_day >= 1.0:
		time_of_day -= 1.0
		day += 1


## A copy does not run the weather: the server's snapshots bring it.
func step(_delta: float, _at := Vector3.INF) -> void:
	pass
