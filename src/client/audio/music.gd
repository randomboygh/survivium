extends RefCounted
## Quiet music, now and then (decision 89): at dawn, in a new kind of land, in the
## evening by a fire, on the main menu, and rarely at other times; between pieces long
## silence, as long as the setting «Как часто» asks. Each piece is made anew from the
## mods' notes (note_pluck, note_bell, pad: a C each, played at other pitches): a key,
## a scale of five notes, a slow pace and a melody that walks the scale, its first
## phrase coming back changed, a bass on each bar and a held tone under the chords.
## The notes are scheduled ahead and started on the frame they fall in, which a slow
## piece forgives. `game` is the Main node; Sound runs it each frame.

const Clock := preload("res://src/shared/game/clock.gd")
const Placed := preload("res://src/shared/game/placed.gd")

## Minutes of silence at least between two pieces, by the setting (rarely, sometimes,
## often), and the chance a minute of a piece coming by itself after that.
const GAPS := [12.0, 6.0, 3.0]
const BY_ITSELF := 0.08
## The moods: scale (semitones over the key), the note of the melody, beat seconds,
## the chords' roots (semitones over the key, a bar each).
const MOODS := {
	"dawn": {"scale": [0, 2, 4, 7, 9], "voice": "core:note_bell", "beat": [0.55, 0.7], "chords": [0, 9, 5, 7]},
	"place": {"scale": [0, 2, 4, 7, 9], "voice": "core:note_pluck", "beat": [0.5, 0.65], "chords": [0, 5, 9, 7]},
	"fire": {"scale": [0, 3, 5, 7, 10], "voice": "core:note_pluck", "beat": [0.7, 0.9], "chords": [0, 8, 3, 10]},
	"night": {"scale": [0, 3, 5, 7, 10], "voice": "core:note_bell", "beat": [0.8, 1.0], "chords": [0, 5, 8, 7]},
	"day": {"scale": [0, 2, 4, 7, 9], "voice": "core:note_pluck", "beat": [0.55, 0.75], "chords": [0, 7, 9, 5]},
}
## Keys (semitones over C) a piece may be in: the notes stay within an octave and a
## half of the files' pitch.
const KEYS := [-5, -3, -2, 0]
## Bars a phrase, beats a bar, phrases a piece.
const BARS := 2
const BEATS := 4
const PHRASES := [4, 6]
## Note voices.
const VOICES := 6
## A lit fire this near (world units) at night, for this many seconds, is an evening by
## the fire.
const FIRE_NEAR := 5.0
const FIRE_TIME := 8.0

var game
var rng := RandomNumberGenerator.new()
## Seconds of play since the last piece ended (it starts as if a gap had passed, less a
## minute, so the first dawn or new land is heard).
var _since := 0.0
## The notes waiting: [time, voice id, semitones over the file's C, volume], in order.
var _notes: Array = []
var _time := 0.0
var _voices: Array[AudioStreamPlayer] = []
var _pad: AudioStreamPlayer
var _pad_level := 0.0
var _pad_want := 0.0
var _end := -1.0
var _last_time_of_day := -1.0
var _biomes := {}
var _by_fire := 0.0
var _menu_heard := false


func _init(g) -> void:
	game = g
	rng.randomize()
	_since = (GAPS[0] - 1.0) * 60.0
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		g.sound.add_child(p)
		_voices.append(p)
	_pad = AudioStreamPlayer.new()
	_pad.bus = "Music"
	g.sound.add_child(_pad)


## Whether a piece is playing.
func playing() -> bool:
	return _end >= 0.0


## Starts the notes due and fades the held tone; every frame.
func update(delta: float) -> void:
	_time += delta
	_play_due()
	_fade_pad(delta)
	if playing() and _time >= _end:
		_end = -1.0
		_since = 0.0


## Looks whether a piece is due, `delta` seconds since the last look.
func think(delta: float) -> void:
	if playing():
		return
	_since += delta
	var mood := _occasion(delta)
	if mood != "":
		start(mood)


## Starts a piece of `mood` (see MOODS) now.
func start(mood: String) -> void:
	var m: Dictionary = MOODS[mood]
	var key: int = KEYS[rng.randi() % KEYS.size()]
	var beat := rng.randf_range(m.beat[0], m.beat[1])
	var scale: Array = m.scale
	var chords: Array = m.chords
	var phrases := rng.randi_range(PHRASES[0], PHRASES[1])
	var motif := _phrase(scale.size())
	var t := _time + 1.0
	_notes.clear()
	for ph in phrases:
		# Every other phrase brings the first one back, a little changed; the last ends home.
		var line: Array = motif.duplicate(true) if ph % 2 == 0 else _phrase(scale.size())
		if ph % 2 == 0 and ph > 0:
			_vary(line, scale.size())
		if ph == phrases - 1:
			line[line.size() - 1] = [0, 2.0]
		var b := 0.0
		for n: Array in line:
			if n[0] != null:
				var degree: int = n[0]
				var octave := floori(float(degree) / scale.size())
				var semis: int = key + scale[posmod(degree, scale.size())] + 12 * octave
				_notes.append([t + b * beat, m.voice, semis, rng.randf_range(0.55, 0.8)])
			b += n[1]
		# A bass note on each bar, an octave below, and the chord held under it.
		for bar in BARS:
			var root: int = chords[(ph * BARS + bar) % chords.size()]
			_notes.append([t + bar * BEATS * beat, "core:note_pluck", key + root - 12, 0.45])
			_notes.append([t + bar * BEATS * beat, "pad", key + root, 0.0])
		t += BARS * BEATS * beat
	_notes.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	_end = t + 3.0
	_pad_want = 0.35


## A phrase of the melody: [scale degree or null for a rest, beats] notes filling
## BARS bars, walking the scale by small steps within an octave and a step (degrees
## 0..degrees + 1) from about its middle.
func _phrase(degrees: int) -> Array:
	var out := []
	var left := float(BARS * BEATS)
	var d := rng.randi_range(2, degrees)
	while left > 0.0:
		var length: float = [0.5, 1.0, 1.0, 1.0, 2.0][rng.randi() % 5]
		length = minf(length, left)
		if rng.randf() < 0.25:
			out.append([null, length])
		else:
			d = clampi(d + rng.randi_range(-2, 2), 0, degrees + 1)
			out.append([d, length])
		left -= length
	return out


## Changes a few notes of phrase `line` by a step of the scale.
func _vary(line: Array, degrees: int) -> void:
	for n: Array in line:
		if n[0] != null and rng.randf() < 0.3:
			n[0] = clampi(n[0] + rng.randi_range(-1, 1), 0, degrees + 1)


## Starts the notes whose time has come.
func _play_due() -> void:
	while not _notes.is_empty() and _notes[0][0] <= _time:
		var n: Array = _notes.pop_front()
		var pitch := pow(2.0, float(n[2]) / 12.0)
		if n[1] == "pad":
			_set_pad(pitch)
			continue
		var list: Array = game.sound.streams(n[1])
		if list.is_empty():
			continue
		var p: AudioStreamPlayer = game.sound.free_voice(_voices)
		p.stream = list[0]
		p.pitch_scale = pitch
		p.volume_db = linear_to_db(n[3])
		if not game.sound.mute:
			p.play()


## Holds the pad at `pitch`; a new chord glides in under a short dip.
func _set_pad(pitch: float) -> void:
	var list: Array = game.sound.streams("core:pad")
	if list.is_empty():
		return
	if not _pad.playing and not game.sound.mute:
		_pad.stream = list[0]
		_pad.volume_db = linear_to_db(0.001)
		_pad.play()
	_pad.pitch_scale = pitch
	_pad_level *= 0.6


func _fade_pad(delta: float) -> void:
	if not playing() or _time > _end - 4.0:
		_pad_want = 0.0
	_pad_level = move_toward(_pad_level, _pad_want, delta * 0.15)
	if _pad.playing:
		if _pad_level <= 0.001 and _pad_want == 0.0:
			_pad.stop()
		else:
			_pad.volume_db = linear_to_db(maxf(_pad_level, 0.001))


## The mood of a piece due now, or "": dawn, a new kind of land, an evening by a fire,
## the main menu, or rarely by itself; none before a gap of silence.
func _occasion(delta: float) -> String:
	var clock = game.clock
	var menu = game.menu
	if menu != null and menu.is_open:
		if not _menu_heard:
			_menu_heard = true
			return "day" if clock.daylight() > 0.4 else "night"
		return ""
	var gap: float = GAPS[clampi(game.settings.values.music_often, 0, GAPS.size() - 1)] * 60.0
	var dawn: bool = _last_time_of_day >= 0.0 and _last_time_of_day < 0.24 and clock.time_of_day >= 0.24
	_last_time_of_day = clock.time_of_day
	var biome: int = clock.biome
	var new_place := biome >= 0 and not _biomes.has(biome)
	if biome >= 0:
		_biomes[biome] = true
	var fire := _fire_near()
	_by_fire = _by_fire + delta if fire and clock.daylight() < 0.3 else 0.0
	if _since < gap:
		return ""
	if dawn:
		return "dawn"
	# The land the game starts in is not new.
	if new_place and _biomes.size() > 1:
		return "place"
	if _by_fire >= FIRE_TIME:
		return "fire"
	if rng.randf() < BY_ITSELF * delta / 60.0:
		return "day" if clock.daylight() > 0.4 else "night"
	return ""


func _fire_near() -> bool:
	var p: Vector3 = game.player.position
	for e in game.placed.things:
		if e.lit and Placed.is_fire(e) and Placed.center(e).distance_to(p) <= FIRE_NEAR:
			return true
	return false
