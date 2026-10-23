extends Node
## The sound of the game on this device: the buses and their volumes from the settings,
## the ear that hears the world, one-off sounds from a place in the world or from the
## interface, and the loops that go on by themselves (wind, rain, a river near), each
## brought up and down to the level the game wants. `game` is the Main node.
## A browser keeps a page silent until the first tap or key (its autoplay rule), so
## nothing starts before `unlocked`: the loops fade in after it, and one-off sounds
## asked for before it are dropped rather than heard late.
## The phone is kept light: a few voices for the world (VOICES), the quietest one taken
## over when all are busy, and a sound asked for again within MIN_GAP is not doubled.

## The buses under Master: music, and the sounds with nature and the interface under
## them, so the sound volume turns all of them down at once.
const BUSES := [["Music", "Master"], ["Sounds", "Master"], ["Nature", "Sounds"], ["UI", "Sounds"]]
## Volume steps of the settings, «выкл» to «100%».
const STEPS := 5
## How many sounds from places in the world play at once, and from the interface.
const VOICES := 8
const UI_VOICES := 3
## Seconds within which the same sound is not started again.
const MIN_GAP := 0.05
## How far a sound from the world is heard, in world units, and from how far it gets quieter.
const HEAR_RANGE := 24.0
const FULL_RANGE := 2.0
## How fast a loop goes to the level asked for: the share of the way gone in a second.
const FADE_RATE := 1.5
## A level this low is silent: the loop is stopped.
const SILENT := 0.001

var game
## Whether the browser lets the page sound yet (always on elsewhere).
var unlocked := not OS.has_feature("web")
## The sounds known, by name: an array of streams, one picked at random each time.
var sounds := {}
var _voices: Array[AudioStreamPlayer3D] = []
var _ui_voices: Array[AudioStreamPlayer] = []
var _listener: AudioListener3D
## When each sound was last started, by name, in seconds of the clock below.
var _started := {}
var _time := 0.0
## The loops: name -> {"player", "level" (now), "want" (asked for)}.
var _loops := {}


func _init(g) -> void:
	game = g
	name = "Sound"
	process_mode = Node.PROCESS_MODE_ALWAYS
	make_buses()


## Adds the buses of BUSES that are not there yet.
static func make_buses() -> void:
	for b: Array in BUSES:
		if AudioServer.get_bus_index(b[0]) >= 0:
			continue
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, b[0])
		AudioServer.set_bus_send(i, b[1])


## Sets bus `bus` to volume step `step` of STEPS (0 mutes it).
static func set_volume(bus: String, step: int) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return
	AudioServer.set_bus_mute(i, step <= 0)
	AudioServer.set_bus_volume_db(i, linear_to_db(float(maxi(step, 1)) / STEPS))


## Puts the ear and the voices into the 3D scene inside the view's SubViewport.
func build(world_root: Node3D) -> void:
	game.view.viewport.audio_listener_enable_3d = true
	_listener = AudioListener3D.new()
	world_root.add_child(_listener)
	_listener.make_current()
	for i in VOICES:
		var p := AudioStreamPlayer3D.new()
		p.bus = "Sounds"
		p.unit_size = FULL_RANGE
		p.max_distance = HEAR_RANGE
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		world_root.add_child(p)
		_voices.append(p)
	for i in UI_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "UI"
		add_child(p)
		_ui_voices.append(p)


## Adds sound `key` (streams, one played at random each time).
func add(key: String, streams: Array) -> void:
	sounds[key] = streams


## The first tap, click or key lets the browser sound.
func input(event: InputEvent) -> void:
	if unlocked:
		return
	if (event is InputEventScreenTouch or event is InputEventMouseButton or event is InputEventKey) \
			and event.is_pressed():
		unlocked = true


## Plays sound `key` once from `pos` in the world (with the listener's distance and
## side), or from the interface when `pos` is INF; `volume` is linear, `pitch` the
## speed (a little random on top, so a sound repeated does not sound the same).
func play(key: String, pos := Vector3.INF, volume := 1.0, pitch := 1.0) -> void:
	if not unlocked or not sounds.has(key):
		return
	if _time - float(_started.get(key, -1.0)) < MIN_GAP:
		return
	var streams: Array = sounds[key]
	if streams.is_empty():
		return
	_started[key] = _time
	var stream: AudioStream = streams[randi() % streams.size()]
	var db := linear_to_db(maxf(volume, SILENT))
	var p_scale := pitch * randf_range(0.94, 1.06)
	if pos == Vector3.INF:
		var u := _free(_ui_voices)
		u.stream = stream
		u.volume_db = db
		u.pitch_scale = p_scale
		u.play()
		return
	if _listener != null and pos.distance_to(_listener.global_position) > HEAR_RANGE:
		return
	var v: AudioStreamPlayer3D = _free(_voices)
	v.stream = stream
	v.volume_db = db
	v.pitch_scale = p_scale
	v.global_position = pos
	v.play()


## A voice of `pool` that is not playing, or the one that has played longest.
static func _free(pool: Array) -> Variant:
	var best: Variant = pool[0]
	var best_t := -1.0
	for p in pool:
		if not p.playing:
			return p
		var t: float = p.get_playback_position()
		if t > best_t:
			best_t = t
			best = p
	return best


## Asks loop `key` (one of `sounds`, looping) to go to `level` (linear, 0 silent) on
## bus `bus`; it fades there (see FADE_RATE).
func loop(key: String, level: float, bus := "Nature") -> void:
	if not _loops.has(key):
		if level <= SILENT or not sounds.has(key) or sounds[key].is_empty():
			return
		var p := AudioStreamPlayer.new()
		p.bus = bus
		p.stream = sounds[key][0]
		add_child(p)
		_loops[key] = {"player": p, "level": 0.0, "want": 0.0}
	_loops[key].want = level


## The level loop `key` is at now (0 when it is not playing).
func loop_level(key: String) -> float:
	return _loops[key].level if _loops.has(key) else 0.0


func _process(delta: float) -> void:
	_time += delta
	if _listener != null and game.player != null:
		# The ear stands at the player and turns with the camera, so a sound on the
		# right of the screen comes from the right.
		_listener.global_transform = Transform3D(game.view.camera.global_transform.basis, game.player.global_position)
	var k := 1.0 - exp(-FADE_RATE * delta)
	for key in _loops.keys():
		var l: Dictionary = _loops[key]
		var p: AudioStreamPlayer = l.player
		var want: float = l.want if unlocked else 0.0
		l.level = lerpf(l.level, want, k)
		if absf(l.level - want) < SILENT:
			l.level = want
		if l.level <= SILENT:
			if p.playing:
				p.stop()
			continue
		p.volume_db = linear_to_db(l.level)
		if not p.playing:
			# A loop starts somewhere in the middle, so two of the same do not beat together.
			p.play(randf() * maxf(p.stream.get_length() - 0.1, 0.0))
