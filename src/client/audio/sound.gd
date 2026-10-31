extends Node
## The sound of the game on this device: the buses and their volumes from the settings,
## the ear that hears the world, one-off sounds from a place in the world or from the
## interface, the loops that go on by themselves (wind, rain) and the ones that sound
## from a place (a fire, a river), each brought up and down to the level asked for.
## The sounds are the mods' (Content `sounds`, files under content/<mod>/sounds), named
## by id; what each part of the game sounds like is in Nature, Steps, Voices and Music
## and in the calls the controls make (work, pick up, craft). `game` is the Main node.
## A browser keeps a page silent until the first tap or key (its autoplay rule), so
## nothing starts before `unlocked`: the loops fade in after it, and one-off sounds
## asked for before it are dropped rather than heard late. The files load a few a frame
## once the game can sound, and a sound asked for before its turn loads at once.
## The phone is kept light: a few voices for the world (VOICES), the one that has
## played longest taken over when all are busy, and a sound asked for again within
## MIN_GAP is not doubled.

const Content := preload("res://src/shared/content/content.gd")
const Mat := preload("res://src/shared/content/materials.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const Placed := preload("res://src/shared/game/placed.gd")
const Nature := preload("res://src/client/audio/nature.gd")
const Steps := preload("res://src/client/audio/steps.gd")
const Voices := preload("res://src/client/audio/voices.gd")
const Music := preload("res://src/client/audio/music.gd")
const SoundMarks := preload("res://src/client/ui/sound_marks.gd")
const TouchButton := preload("res://src/client/input/touch_button.gd")

## The buses under Master: music, and the sounds with nature and the interface under
## them, so the sound volume turns all of them down at once.
const BUSES := [["Music", "Master"], ["Sounds", "Master"], ["Nature", "Sounds"], ["UI", "Sounds"]]
## Volume steps of the settings, «выкл» to «100%».
const STEPS := 5
## How many sounds from places in the world play at once, and from the interface.
const VOICES := 10
const UI_VOICES := 3
## Seconds within which the same sound is not started again.
const MIN_GAP := 0.05
## How far a sound from the world is heard, in world units (the screen is about 40
## wide), and up to how far it is as loud as it is.
const HEAR_RANGE := 22.0
const FULL_RANGE := 3.0
## How fast a loop goes to the level asked for: the share of the way gone in a second.
const FADE_RATE := 1.5
## A level this low is silent: the loop is stopped.
const SILENT := 0.001
## Files loaded a frame once the game can sound.
const LOADS_PER_FRAME := 3
## Seconds between two looks at the world round the player (the weather, the water,
## whether music is due); the animals are listened to a few a frame (Voices.SLICES).
const TICK := 0.25

var game
## The parts: the world around, the player's body, the animals, the music, and the
## marks of where an important sound came from.
var nature: Nature
var steps: Steps
var voices: Voices
var music: Music
var marks: SoundMarks
## Whether the browser lets the page sound yet (always on elsewhere).
var unlocked := not OS.has_feature("web")
## No sound can be heard (headless tests and tools): everything runs but nothing is
## started, so no playback is left in the AudioServer when they quit at once.
var mute := AudioServer.get_driver_name() == "Dummy"
## The sound records by id (Content `sounds`), the id of each bare name (see resolve), and
## the streams of those loaded.
var records := {}
var _by_name := {}
var _streams := {}
var _to_load: Array = []
var _voices: Array[AudioStreamPlayer3D] = []
var _ui_voices: Array[AudioStreamPlayer] = []
var _listener: AudioListener3D
## When each sound was last started, by id, in seconds of the clock below.
var _started := {}
var _time := 0.0
## The loops heard everywhere: id -> {"player", "level" (now), "want" (asked for)};
## and the ones from a place: id -> the same with an AudioStreamPlayer3D.
var _loops := {}
var _spots := {}
## One-off sounds waiting for their moment (the strike of a swing, thunder after the
## flash): [time, id, pos, volume, pitch, bus].
var _later: Array = []
var _tick := 0.0


func _init(g) -> void:
	game = g
	name = "Sound"
	process_mode = Node.PROCESS_MODE_ALWAYS
	make_buses()
	for rec: Dictionary in Content.records("sounds"):
		records[rec.id] = rec
		_by_name[rec.id.get_slice(":", 1)] = rec.id
		_to_load.append(rec.id)


func _ready() -> void:
	# Every button of the interface clicks (the touch controls do not).
	get_tree().node_added.connect(_on_node_added)
	print("sound: driver %s, %d Hz, %d sounds%s" % [AudioServer.get_driver_name(), AudioServer.get_mix_rate(),
		records.size(), ", muted" if mute else ""])


## Adds the buses of BUSES that are not there yet. They are all in default_bus_layout.tres,
## which the engine loads at start: in the browser the sounds play as Web Audio samples
## through a copy of the buses made then, and a bus added later is silent there.
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


## Puts the ear and the voices into the 3D scene inside the view's SubViewport, the
## marks into the interface, and listens to what the game does.
func build(world_root: Node3D) -> void:
	game.view.viewport.audio_listener_enable_3d = true
	_listener = AudioListener3D.new()
	world_root.add_child(_listener)
	_listener.make_current()
	for i in VOICES:
		_voices.append(_player_3d(world_root))
	for i in UI_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "UI"
		add_child(p)
		_ui_voices.append(p)
	nature = Nature.new(game)
	steps = Steps.new(game)
	voices = Voices.new(game)
	music = Music.new(game)
	marks = SoundMarks.new(game)
	game.hud.add_child(marks)
	# Under the rest of the interface, over the body's feedback.
	game.hud.move_child(marks, 1)
	game.actions.taken.connect(_on_taken)
	game.workshop.made.connect(_on_made)
	game.placed.added.connect(_on_placed)
	game.placed.lit_changed.connect(_on_lit)
	for w: Control in [game.hud.bag, game.hud.map_view]:
		w.visibility_changed.connect(_on_window.bind(w))


func _player_3d(parent: Node) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.bus = "Sounds"
	p.unit_size = FULL_RANGE
	p.max_distance = HEAR_RANGE
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	parent.add_child(p)
	return p


## The first tap, click or key lets the browser sound.
func input(event: InputEvent) -> void:
	if unlocked:
		return
	if (event is InputEventScreenTouch or event is InputEventMouseButton or event is InputEventKey) \
			and event.is_pressed():
		unlocked = true
		print("sound: on after the first tap")


## The record id of sound `name`: a full id (`sounds:click`) as it is, a bare name (`chop`,
## what the code asks for) the sound of that name in the last mod that gives one, "" when
## no loaded mod has it (then nothing sounds).
func resolve(name: String) -> String:
	if records.has(name):
		return name
	return _by_name.get(name, "")


## The streams of sound `id` (loaded now if they were not yet), [] for an unknown one.
func streams(id: String) -> Array:
	id = resolve(id)
	if _streams.has(id):
		return _streams[id]
	if not records.has(id):
		return []
	var rec: Dictionary = records[id]
	var out := []
	if game != null and game.hud != null:
		game.hud.perf.mark("звук")
	for path in Content.sound_files(rec):
		var s: AudioStream = load(path)
		if s == null:
			continue
		if rec.loop and s is AudioStreamWAV:
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_begin = 0
			s.loop_end = int(s.get_length() * s.mix_rate)
		out.append(s)
	_streams[id] = out
	return out


## Whether the ear can hear world point `pos` at all.
func in_range(pos: Vector3) -> bool:
	return _listener != null and pos.distance_to(_listener.global_position) <= HEAR_RANGE


## Plays sound `id` once from `pos` in the world (with the ear's distance and side),
## or from the interface when `pos` is INF; `volume` is linear on top of the sound's
## own, `pitch` the speed (a little random on top, so a sound repeated does not sound
## the same), `bus` where it goes (Sounds, the interface's UI for a sound from no
## place; or Nature for the birds and the weather).
func play(id: String, pos := Vector3.INF, volume := 1.0, pitch := 1.0, bus := "Sounds") -> void:
	id = resolve(id)
	if id == "" or not unlocked or volume <= SILENT or _time - float(_started.get(id, -1.0)) < MIN_GAP:
		return
	if pos != Vector3.INF and not in_range(pos):
		return
	var list := streams(id)
	if list.is_empty():
		return
	_started[id] = _time
	var stream: AudioStream = list[randi() % list.size()]
	var db := linear_to_db(volume * records[id].volume)
	var p_scale := pitch * randf_range(0.94, 1.06)
	if pos == Vector3.INF:
		var u: AudioStreamPlayer = free_voice(_ui_voices)
		u.bus = "UI" if bus == "Sounds" else bus
		u.stream = stream
		u.volume_db = db
		u.pitch_scale = p_scale
		if not mute:
			u.play()
		return
	var v: AudioStreamPlayer3D = free_voice(_voices)
	v.stream = stream
	v.volume_db = db
	v.pitch_scale = p_scale
	v.bus = bus
	v.global_position = pos
	if not mute:
		v.play()


## Plays sound `id` (see play) `delay` seconds from now.
func play_later(delay: float, id: String, pos := Vector3.INF, volume := 1.0, pitch := 1.0, bus := "Sounds") -> void:
	id = resolve(id)
	if id == "" or not unlocked:
		return
	if delay <= 0.0:
		play(id, pos, volume, pitch, bus)
	else:
		_later.append([_time + delay, id, pos, volume, pitch, bus])


## A voice of `pool` that is not playing, or the one that has played longest.
static func free_voice(pool: Array) -> Variant:
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


## Asks loop `id` (a sound with `loop`) to go to `level` (linear, 0 silent) on bus
## `bus`, heard the same everywhere; it fades there (see FADE_RATE).
func loop(id: String, level: float, bus := "Nature") -> void:
	id = resolve(id)
	if id == "":
		return
	if not _loops.has(id):
		if level <= SILENT or streams(id).is_empty():
			return
		var p := AudioStreamPlayer.new()
		p.bus = bus
		p.stream = streams(id)[0]
		add_child(p)
		_loops[id] = {"player": p, "level": 0.0, "want": 0.0, "gain": records[id].volume}
	_loops[id].want = level


## Asks loop `id` to sound from world point `pos` at `level` (see loop); the place may
## move each time it is asked.
func spot(id: String, pos: Vector3, level: float, bus := "Nature") -> void:
	id = resolve(id)
	if id == "":
		return
	if not _spots.has(id):
		if level <= SILENT or streams(id).is_empty() or _listener == null:
			return
		var p := _player_3d(_listener.get_parent())
		p.bus = bus
		p.stream = streams(id)[0]
		_spots[id] = {"player": p, "level": 0.0, "want": 0.0, "gain": records[id].volume}
	_spots[id].want = level
	if pos.is_finite():
		_spots[id].player.global_position = pos


## The level loop `id` is at now (0 when it is not playing).
func loop_level(id: String) -> float:
	id = resolve(id)
	return _loops[id].level if _loops.has(id) else 0.0


## The sound of the hands' work `done` (a result of a WorldActions rule, see
## Controls._did) played as `kind` (one of player.yaml `works`), at the moment of its
## strike, `strike` of the way through the swing: a block set down thuds, a blade
## through grass or leaves mows, the material struck sounds its `hit`, a swing that
## strikes nothing whooshes.
func work(done: Dictionary, kind: String, strike: float) -> void:
	var at: Vector3 = done.at if done.at.is_finite() else game.player.position
	var stuff: int = done.get("stuff", -1)
	var id := ""
	if done.has("placed"):
		id = "place"
	elif done.get("hit", false):
		id = "knock"
	elif kind == "reach" and stuff < 0:
		return
	elif kind in ["mow", "slash"] and stuff in [Mat.GRASS, Mat.LEAVES]:
		id = "mow"
	elif stuff >= 0 and stuff < Mat.COUNT:
		id = Mat.RECORDS[stuff].hit
	if id == "":
		id = "swish"
	play_later(done.time * strike, id, at)


## Everything is stopped when the game goes, so no sound is left playing in the
## AudioServer past its stream.
func _exit_tree() -> void:
	for p in find_children("*", "AudioStreamPlayer", true, false) + _voices:
		p.stop()
	for l: Dictionary in _spots.values():
		l.player.stop()


func _on_taken(_id: String, from: Vector3) -> void:
	play("pickup", from)


func _on_made(_recipe: Dictionary) -> void:
	play("craft")


func _on_placed(e: Dictionary) -> void:
	if game.ready_to_play:
		play("place", Placed.center(e))


func _on_lit(e: Dictionary) -> void:
	if e.lit:
		play("ignite", Placed.center(e))


func _on_window(w: Control) -> void:
	play("open" if w.visible else "close")


func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node is TouchButton:
		node.pressed.connect(_on_button.bind(node))


func _on_button(b: BaseButton) -> void:
	play("tab" if b.toggle_mode else "click")


func _process(delta: float) -> void:
	_time += delta
	if unlocked and not _to_load.is_empty():
		for i in mini(LOADS_PER_FRAME, _to_load.size()):
			streams(_to_load.pop_back())
	if _listener != null and game.player != null:
		# The ear stands at the player and turns with the camera, so a sound on the
		# right of the screen comes from the right.
		_listener.global_transform = Transform3D(game.view.camera.global_transform.basis, game.player.position)
	if unlocked and game.player != null and game.world != null:
		music.update(delta)
		if game.ready_to_play:
			steps.update(delta)
			voices.update(delta)
		_tick += delta
		if _tick >= TICK:
			nature.update(_tick)
			music.think(_tick)
			_tick = 0.0
	var i := 0
	while i < _later.size():
		var l: Array = _later[i]
		if l[0] <= _time:
			_later.remove_at(i)
			play(l[1], l[2], l[3], l[4], l[5])
		else:
			i += 1
	var k := 1.0 - exp(-FADE_RATE * delta)
	for list: Dictionary in [_loops, _spots]:
		for id in list:
			_fade(list[id], k)


## Takes loop `l` (see _loops) a step `k` of the way to its level.
func _fade(l: Dictionary, k: float) -> void:
	var p: Node = l.player
	var want: float = l.want if unlocked else 0.0
	if l.level == want and (p.playing or mute if want > SILENT else not p.playing):
		return
	l.level = lerpf(l.level, want, k)
	if absf(l.level - want) < SILENT:
		l.level = want
	if l.level <= SILENT:
		if p.playing:
			p.stop()
		return
	p.volume_db = linear_to_db(l.level * l.gain)
	if not p.playing and not mute:
		# A loop starts somewhere in the middle, so two of the same do not beat together.
		p.play(randf() * maxf(p.stream.get_length() - 0.1, 0.0))
