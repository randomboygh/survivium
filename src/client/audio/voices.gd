extends RefCounted
## The animals' voices: each species says its `calls` now and then while it is up and
## about (by day, by night or always, as it is `active`), and cries its `alarm` when it
## starts to flee or to hunt. An animal is often heard before it is seen (decision 89):
## a voice of a meat eater big enough to be a danger (AiRules: heavier than DANGER) is
## heard from farther off, and when it comes from off the screen a faint mark at the
## screen's edge shows its side (SoundMarks). `game` is the Main node; Sound runs it
## each frame.

const AiRules := preload("res://src/shared/content/ai_rules.gd")

## Seconds between two calls of one animal, about (a flock shares one voice, see
## FLOCK_SHARE).
const CALL_EVERY := 25.0
## A bird in a flock calls more, but the flock not louder: the chance of each is
## divided among about this many.
const FLOCK_SHARE := 4.0
## Seconds before an animal cries out again.
const ALARM_AGAIN := 4.0
## A meat eater this heavy (kg) is a danger to a person, and how far its voice carries
## (world units).
const DANGER := 20.0
const FAR_REACH := 60.0
## At most one voice starts in this many seconds.
const GAP := 0.3
## The animals are listened to over this many frames, a share each frame.
const SLICES := 8

var game
var rng := RandomNumberGenerator.new()
## The state each animal was in, and when it may cry out again.
var _state := {}
var _quiet := {}
var _gap := 0.0
var _time := 0.0
var _cursor := 0


func _init(g) -> void:
	game = g
	rng.randomize()


func update(delta: float) -> void:
	var wildlife = game.wildlife
	if wildlife == null:
		return
	_time += delta
	_gap -= delta
	var animals: Array = wildlife.animals
	if animals.is_empty():
		return
	var daylight: float = game.clock.daylight()
	var ear: Vector3 = game.player.position
	# A share of the animals a frame, each listened to for the frames since its last turn.
	var n := ceili(float(animals.size()) / SLICES)
	var dt := delta * SLICES
	for k in n:
		_cursor = (_cursor + 1) % animals.size()
		_listen(animals[_cursor], dt, daylight, ear)
	# Animals gone are let go of.
	if _cursor < n and _state.size() > animals.size() * 2:
		for a in _state.keys():
			if a.gone:
				_state.erase(a)
				_quiet.erase(a)


## Animal `a`, `delta` seconds since it was last listened to: an alarm when it starts
## to flee or hunt, now and then its call.
func _listen(a, delta: float, daylight: float, ear: Vector3) -> void:
	var spec: Dictionary = AiRules.SPECIES.get(a.kind, {})
	if spec.is_empty() or a.gone:
		return
	var was: String = _state.get(a, "")
	_state[a] = a.state
	var reach: float = FAR_REACH if _danger(spec) else game.sound.HEAR_RANGE
	if a.pos.distance_squared_to(ear) > reach * reach:
		return
	if a.state != was and a.state in ["flee", "hunt"] and spec.alarm != "" and _time >= float(_quiet.get(a, 0.0)):
		_quiet[a] = _time + ALARM_AGAIN
		_say(spec.alarm, a.pos, spec)
		return
	if spec.calls == "" or a.state == "rest" or not _awake(spec, daylight):
		return
	var share: float = FLOCK_SHARE if spec.flock[1] > 1 else 1.0
	if rng.randf() < delta / (CALL_EVERY * share):
		_say(spec.calls, a.pos, spec)


## Whether a species is up and about at `daylight`.
static func _awake(spec: Dictionary, daylight: float) -> bool:
	match spec.active:
		"day":
			return daylight > 0.3
		"night":
			return daylight < 0.5
	return true


static func _danger(spec: Dictionary) -> bool:
	return "meat" in spec.diet and spec.mass >= DANGER


## Says sound `id` from `pos`: a far voice is heard from the edge of hearing, quieter.
func _say(id: String, pos: Vector3, spec: Dictionary) -> void:
	if _gap > 0.0:
		return
	_gap = GAP
	var sound = game.sound
	var ear: Vector3 = game.player.position
	var d := pos.distance_to(ear)
	var at := pos
	var volume := 1.0
	var reach: float = sound.HEAR_RANGE * 0.9
	if d > reach:
		at = ear + (pos - ear) / d * reach
		volume = clampf(1.0 - (d - reach) / (FAR_REACH - reach), 0.15, 1.0) * 0.6
	sound.play(id, at, volume, 1.0, "Nature")
	if _danger(spec) and game.sound.marks != null:
		game.sound.marks.show_at(pos)
