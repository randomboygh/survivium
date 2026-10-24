extends SceneTree
## Makes the sounds of the game from noise and tones (tools/sound/synth.gd) and saves
## them as the mods' sounds, which content/<mod>/data/sounds.yaml lists:
## content/<mod>/sounds/<name>.wav, or <name>_1.wav, <name>_2.wav ... for a sound with
## variants. A sound replaced by hand is overwritten, so name the sounds to make:
## godot --headless --path . --script res://tools/make_sounds.gd -- [sound ...]
## Each sound has its own seed: making it again gives the same file.

const Synth := preload("res://tools/sound/synth.gd")

## Seconds of the loops, and how much of their end is faded into their start.
const LOOP := 8.0
const OVERLAP := 1.0
## name: [mod, variants, loop]; the sound is made by the method `_<name>`.
const SOUNDS := {
	# Nature: loops.
	"wind": ["core", 1, true],
	"rain": ["core", 1, true],
	"hail": ["core", 1, true],
	"blizzard": ["core", 1, true],
	"water": ["core", 1, true],
	"fire": ["core", 1, true],
	"crickets": ["core", 1, true],
	# Nature: one-off.
	"thunder": ["core", 2, false],
	"bird": ["core", 5, false],
	"owl": ["core", 2, false],
	# The player.
	"step_grass": ["core", 4, false],
	"step_dirt": ["core", 4, false],
	"step_stone": ["core", 4, false],
	"step_sand": ["core", 4, false],
	"step_snow": ["core", 4, false],
	"step_wood": ["core", 4, false],
	"step_water": ["core", 3, false],
	"swim": ["core", 3, false],
	"jump": ["core", 2, false],
	"land": ["core", 2, false],
	"splash": ["core", 2, false],
	# Work.
	"chop": ["core", 3, false],
	"dig": ["core", 3, false],
	"hit_stone": ["core", 3, false],
	"rustle": ["core", 3, false],
	"knock": ["core", 2, false],
	"swish": ["core", 3, false],
	"mow": ["core", 3, false],
	"place": ["core", 3, false],
	"pickup": ["core", 2, false],
	"craft": ["core", 1, false],
	"eat": ["core", 2, false],
	"ignite": ["core", 1, false],
	# The interface.
	"click": ["core", 1, false],
	"tab": ["core", 1, false],
	"open": ["core", 1, false],
	"close": ["core", 1, false],
	# Animals.
	"rabbit": ["core", 2, false],
	"squirrel": ["core", 2, false],
	"cat": ["core", 2, false],
	"deer": ["core", 2, false],
	"wolf_howl": ["core", 2, false],
	"wolf_growl": ["core", 2, false],
	"sparrow": ["birds", 3, false],
	# Music: notes the music plays at other pitches (src/client/audio/music.gd).
	"note_pluck": ["core", 1, false],
	"note_bell": ["core", 1, false],
	"pad": ["core", 1, true],
}

var rng := RandomNumberGenerator.new()


func _init() -> void:
	var only := OS.get_cmdline_user_args()
	var count := 0
	for name: String in SOUNDS:
		if not only.is_empty() and not name in only:
			continue
		var spec: Array = SOUNDS[name]
		var dir := "res://content/%s/sounds" % spec[0]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		for v in spec[1]:
			rng.seed = hash(name) + v * 7919
			var b: PackedFloat32Array = call("_" + name, v)
			b = Synth.loopify(b, OVERLAP) if spec[2] else Synth.fade(b)
			var file := "%s/%s.wav" % [dir, name if spec[1] == 1 else "%s_%d" % [name, v + 1]]
			if Synth.save(b, ProjectSettings.globalize_path(file)) != OK:
				push_error("could not save " + file)
			count += 1
	print("%d sounds made" % count)
	quit()


## A slow wave of `cycles` whole turns over the loop (so it joins at the seam), 0..1.
static func _wave(t: float, cycles: int, phase := 0.0) -> float:
	return 0.5 + 0.5 * sin(TAU * (t / (LOOP + OVERLAP) * cycles) + phase)


# --- Nature ----------------------------------------------------------------

func _wind(_v: int) -> PackedFloat32Array:
	var span := LOOP + OVERLAP
	var b := Synth.brown(span, rng)
	b = Synth.bandpass(b, func(t: float) -> float: return 260.0 + 300.0 * _wave(t, 3) + 120.0 * _wave(t, 7, 1.0), 0.9)
	var hiss := Synth.highpass(Synth.white(span, rng), 2500.0)
	b = Synth.mix(Synth.normalize(b, 1.0), Synth.normalize(hiss, 0.08))
	b = Synth.shape(b, func(t: float, _l: float) -> float: return 0.45 + 0.4 * _wave(t, 2) + 0.15 * _wave(t, 5, 2.0))
	return Synth.normalize(b, 0.8)


func _rain(_v: int) -> PackedFloat32Array:
	var span := LOOP + OVERLAP
	var bed := Synth.lowpass(Synth.highpass(Synth.white(span, rng), 900.0), 7000.0)
	var drops := Synth.grains(span, 90.0, 0.012, 3200.0, 2.0, rng, 3.0)
	var b := Synth.mix(Synth.normalize(bed, 0.5), Synth.normalize(drops, 0.6))
	return Synth.normalize(b, 0.7)


func _hail(_v: int) -> PackedFloat32Array:
	var span := LOOP + OVERLAP
	var bed := Synth.lowpass(Synth.highpass(Synth.white(span, rng), 1200.0), 6000.0)
	var ticks := Synth.grains(span, 160.0, 0.006, 4200.0, 3.0, rng, 1.5)
	var b := Synth.mix(Synth.normalize(bed, 0.25), Synth.normalize(ticks, 0.8))
	return Synth.normalize(b, 0.7)


func _blizzard(_v: int) -> PackedFloat32Array:
	var span := LOOP + OVERLAP
	var whistle := Synth.bandpass(Synth.white(span, rng), func(t: float) -> float: return 900.0 + 500.0 * _wave(t, 4) + 200.0 * _wave(t, 9, 0.5), 18.0)
	whistle = Synth.shape(Synth.normalize(whistle, 1.0), func(t: float, _l: float) -> float: return 0.3 + 0.7 * _wave(t, 3, 1.5))
	var bed := Synth.bandpass(Synth.brown(span, rng), func(t: float) -> float: return 500.0 + 300.0 * _wave(t, 5), 0.7)
	var b := Synth.mix(Synth.normalize(bed, 0.7), whistle, 0.35)
	return Synth.normalize(b, 0.8)


## Water flowing: a low murmur that swells and ebbs, the hiss of the current over it and
## now and then a soft low gurgle, not a pot boiling.
func _water(_v: int) -> PackedFloat32Array:
	var span := LOOP + OVERLAP
	var murmur := Synth.bandpass(Synth.brown(span, rng), func(t: float) -> float: return 520.0 + 200.0 * _wave(t, 5) + 100.0 * _wave(t, 11, 2.0), 0.8)
	murmur = Synth.shape(Synth.normalize(murmur, 1.0), func(t: float, _l: float) -> float: return 0.7 + 0.3 * _wave(t, 3, 0.7))
	var hiss := Synth.lowpass(Synth.lowpass(Synth.highpass(Synth.white(span, rng), 700.0), 1800.0), 1800.0)
	hiss = Synth.shape(Synth.normalize(hiss, 1.0), func(t: float, _l: float) -> float: return 0.6 + 0.4 * _wave(t, 4, 1.9))
	var b := Synth.mix(murmur, hiss, 0.22)
	for i in int(span * 3.0):
		var f := rng.randf_range(260.0, 620.0)
		var d := rng.randf_range(0.04, 0.09)
		var bub := Synth.tone(d * 3.0, func(t: float) -> float: return f * (1.0 + t / d * 0.15))
		bub = Synth.shape(bub, func(t: float, _l: float) -> float: return minf(t / 0.012, 1.0) * exp(-t / d))
		b = _add(b, bub, rng.randf_range(0.04, 0.12), rng.randf() * (span - d * 3.0))
	return Synth.normalize(Synth.lowpass(Synth.lowpass(b, 2400.0), 2400.0), 0.6)


func _fire(_v: int) -> PackedFloat32Array:
	var span := LOOP + OVERLAP
	var rumble := Synth.lowpass(Synth.brown(span, rng), 260.0)
	rumble = Synth.shape(Synth.normalize(rumble, 1.0), func(t: float, _l: float) -> float: return 0.6 + 0.4 * _wave(t, 5, 0.3))
	var crackle := Synth.grains(span, 70.0, 0.004, 2600.0, 0.8, rng, 4.0)
	var pops := Synth.grains(span, 6.0, 0.02, 900.0, 1.5, rng, 1.5)
	var b := Synth.mix(Synth.normalize(rumble, 0.35), Synth.normalize(crackle, 0.7))
	b = Synth.mix(b, Synth.normalize(pops, 0.5))
	return Synth.normalize(b, 0.75)


func _crickets(_v: int) -> PackedFloat32Array:
	var span := LOOP + OVERLAP
	var b := Synth.silence(span)
	# A few crickets, each at its own pitch and pace, nearer ones louder; each sings a
	# while and then rests, so most of the time one or two are heard, not a choir.
	for c in 3:
		var hz := rng.randf_range(3800.0, 4600.0)
		var period := rng.randf_range(0.9, 1.4)
		var level := rng.randf_range(0.3, 1.0) if c > 0 else 1.0
		var pulses := rng.randi_range(2, 3)
		var t := rng.randf() * 3.0
		while t < span - 0.2:
			var bout := t + rng.randf_range(1.5, 3.5)
			while t < minf(bout, span - 0.2):
				for p in pulses:
					var chirp := Synth.env(Synth.tone(0.03, hz), 0.006, 0.012)
					b = _add(b, chirp, level, t + p * 0.04)
				t += period * rng.randf_range(0.9, 1.1)
			t += rng.randf_range(2.0, 4.5)
	return Synth.normalize(Synth.lowpass(b, 6000.0), 0.45)


func _thunder(_v: int) -> PackedFloat32Array:
	var span := rng.randf_range(3.5, 5.0)
	var crack := Synth.env(Synth.bandpass(Synth.white(0.4, rng), 1800.0, 0.6), 0.002, 0.08)
	var rumble := Synth.lowpass(Synth.brown(span, rng), 220.0)
	var swells := [rng.randf_range(0.2, 0.6), rng.randf_range(0.8, 1.6), rng.randf_range(1.8, 2.8)]
	rumble = Synth.shape(Synth.normalize(rumble, 1.0), func(t: float, l: float) -> float:
		var g := 0.0
		for s: float in swells:
			g += exp(-pow((t - s) / 0.5, 2.0))
		return (0.3 + g) * smoothstep(l, l * 0.4, t) * minf(t / 0.05, 1.0))
	var b := Synth.mix(Synth.normalize(rumble, 0.9), crack, 0.5 * rng.randf())
	return Synth.normalize(b, 0.9)


func _bird(_v: int) -> PackedFloat32Array:
	var b := Synth.silence(0.05)
	var t := 0.0
	var base := rng.randf_range(2600.0, 4200.0)
	var notes := rng.randi_range(2, 6)
	var kind := rng.randi() % 3
	for n in notes:
		var d := rng.randf_range(0.05, 0.13)
		var f0 := base * rng.randf_range(0.85, 1.2)
		var f1 := f0 * (rng.randf_range(1.1, 1.5) if kind == 0 else rng.randf_range(0.6, 0.9) if kind == 1 else 1.0)
		var trill := 30.0 if kind == 2 else 0.0
		var note := Synth.tone(d, func(x: float) -> float: return lerpf(f0, f1, x / d) + sin(x * TAU * trill) * 200.0,
			[[1.0, 1.0, 0.0], [2.0, 0.15, 0.0]])
		note = Synth.shape(note, func(x: float, l: float) -> float: return sin(PI * x / l))
		b = _add(b, note, 1.0, t)
		t += d + rng.randf_range(0.02, 0.09)
	return Synth.normalize(b, 0.6)


func _owl(_v: int) -> PackedFloat32Array:
	var b := Synth.silence(0.1)
	var hoots := [0.0, 0.55, 0.8] if rng.randf() < 0.5 else [0.0, 0.7]
	var f := rng.randf_range(340.0, 420.0)
	for h: float in hoots:
		var d := 0.35 if h == 0.0 else 0.22
		var hoot := Synth.tone(d, func(x: float) -> float: return f * (1.0 - 0.06 * x / d), [[1.0, 1.0, 0.0], [2.0, 0.08, 0.0]])
		hoot = Synth.shape(hoot, func(x: float, l: float) -> float: return sin(PI * x / l) * sin(PI * x / l))
		var breath := Synth.env(Synth.bandpass(Synth.white(d, rng), f * 2.0, 2.0), 0.05, d * 0.5)
		b = _add(b, Synth.mix(hoot, breath, 0.05), 1.0, h)
	return Synth.normalize(b, 0.6)


# --- The player --------------------------------------------------------------

## A step: a low thud and a band of crunch.
func _step(thud_hz: float, crunch_hz: float, crunch: float, length: float, grain_rate: float) -> PackedFloat32Array:
	var thud := Synth.env(Synth.lowpass(Synth.white(length, rng), thud_hz), 0.003, length * 0.2)
	var grit := Synth.grains(length, grain_rate, 0.01, crunch_hz, 1.2, rng, 1.5)
	grit = Synth.env(grit, 0.005, length * 0.35)
	return Synth.normalize(Synth.mix(Synth.normalize(thud, 1.0), Synth.normalize(grit, 1.0), crunch), 0.6)


## A soft step on earth: a muffled thump of the foot that rises gently rather than
## knocks, and a hush of what is pressed under it (`lo`..`hi` Hz) a little behind it,
## with a few quiet grains (`grit`) of soil or grass blades.
func _soft_step(length: float, thump_hz: float, lo: float, hi: float, hush: float, grit_hz: float, grit: float) -> PackedFloat32Array:
	var thump := Synth.lowpass(Synth.lowpass(Synth.white(length, rng), thump_hz), thump_hz)
	thump = Synth.shape(Synth.normalize(thump, 1.0), func(t: float, l: float) -> float: return smoothstep(0.0, 0.02, t) * exp(-t / (l * 0.2)))
	var press := Synth.lowpass(Synth.lowpass(Synth.highpass(Synth.white(length, rng), lo), hi), hi)
	press = Synth.shape(Synth.normalize(press, 1.0), func(t: float, l: float) -> float: return smoothstep(0.0, l * 0.25, t) * smoothstep(l, l * 0.3, t))
	var grains := Synth.grains(length, 90.0, 0.008, grit_hz, 0.9, rng, 2.5)
	grains = Synth.shape(Synth.normalize(grains, 1.0), func(t: float, l: float) -> float: return smoothstep(0.0, l * 0.2, t) * smoothstep(l, l * 0.4, t))
	var b := Synth.mix(thump, press, hush)
	return Synth.normalize(Synth.lowpass(Synth.mix(b, grains, grit), hi), 0.35)


func _step_grass(_v: int) -> PackedFloat32Array:
	return _soft_step(0.24, 140.0, rng.randf_range(600.0, 800.0), 2200.0, 0.55, 1800.0, 0.12)


func _step_dirt(_v: int) -> PackedFloat32Array:
	return _soft_step(0.18, 170.0, 300.0, rng.randf_range(1100.0, 1500.0), 0.35, 900.0, 0.2)


func _step_stone(_v: int) -> PackedFloat32Array:
	var click := Synth.env(Synth.bandpass(Synth.white(0.08, rng), rng.randf_range(1400.0, 2000.0), 3.0), 0.001, 0.015)
	return Synth.normalize(Synth.mix(_step(500.0, 3000.0, 0.15, 0.08, 60.0), click, 0.8), 0.6)


func _step_sand(_v: int) -> PackedFloat32Array:
	var shh := Synth.highpass(Synth.white(0.2, rng), rng.randf_range(2500.0, 3500.0))
	shh = Synth.shape(shh, func(t: float, l: float) -> float: return sin(PI * t / l) * exp(-t * 8.0))
	return Synth.normalize(Synth.mix(_step(260.0, 2000.0, 0.2, 0.2, 80.0), shh, 0.6), 0.5)


func _step_snow(_v: int) -> PackedFloat32Array:
	var crunch := Synth.grains(0.22, 600.0, 0.006, rng.randf_range(1800.0, 2600.0), 1.0, rng, 1.2)
	crunch = Synth.shape(crunch, func(t: float, l: float) -> float: return sin(PI * minf(t / l * 1.3, 1.0)))
	return Synth.normalize(Synth.mix(_step(250.0, 1500.0, 0.1, 0.22, 40.0), Synth.normalize(crunch, 1.0), 0.9), 0.55)


func _step_wood(_v: int) -> PackedFloat32Array:
	var f := rng.randf_range(160.0, 220.0)
	var body := Synth.tone(0.12, f, [[1.0, 1.0, 0.04], [2.3, 0.5, 0.025], [4.1, 0.25, 0.012]])
	var click := Synth.env(Synth.bandpass(Synth.white(0.03, rng), 2500.0, 2.0), 0.0005, 0.006)
	return Synth.normalize(Synth.mix(body, click, 0.4), 0.6)


func _spray(length: float, hz: float) -> PackedFloat32Array:
	var noise := Synth.bandpass(Synth.white(length, rng), func(t: float) -> float: return hz * (1.0 + t * 1.5), 0.8)
	noise = Synth.shape(noise, func(t: float, l: float) -> float: return minf(t / 0.01, 1.0) * exp(-t / (l * 0.25)))
	var b := Synth.normalize(noise, 0.8)
	for i in int(length * 30.0):
		var f := rng.randf_range(500.0, 1500.0)
		var bub := Synth.env(Synth.tone(0.08, func(t: float) -> float: return f * (1.0 + t * 8.0)), 0.002, 0.02)
		b = _add(b, bub, rng.randf_range(0.1, 0.4), rng.randf() * length * 0.6)
	return Synth.normalize(b, 0.6)


func _step_water(_v: int) -> PackedFloat32Array:
	return _spray(0.22, rng.randf_range(900.0, 1300.0))


## A stroke: water pushed by the arms, a soft whoosh that swells and falls back, with a
## gurgle or two low under it; no slap at its start.
func _swim(_v: int) -> PackedFloat32Array:
	var length := 0.6
	var hz := rng.randf_range(650.0, 850.0)
	var push := Synth.bandpass(Synth.white(length, rng), func(t: float) -> float: return hz * (1.0 - 0.45 * t / length), 0.7)
	push = Synth.lowpass(push, 1600.0)
	push = Synth.shape(Synth.normalize(push, 1.0), func(t: float, l: float) -> float: return smoothstep(0.0, 0.16, t) * smoothstep(l, 0.2, t))
	var b := push
	for i in rng.randi_range(1, 2):
		var f := rng.randf_range(280.0, 480.0)
		var bub := Synth.tone(0.12, func(t: float) -> float: return f * (1.0 + t * 1.5))
		bub = Synth.shape(bub, func(t: float, _l: float) -> float: return minf(t / 0.015, 1.0) * exp(-t / 0.035))
		b = _add(b, bub, rng.randf_range(0.08, 0.15), rng.randf_range(0.2, 0.4))
	return Synth.normalize(b, 0.5)


func _jump(_v: int) -> PackedFloat32Array:
	var w := Synth.bandpass(Synth.white(0.18, rng), func(t: float) -> float: return 500.0 + t * 6000.0, 1.0)
	w = Synth.shape(w, func(t: float, l: float) -> float: return sin(PI * t / l))
	return Synth.normalize(w, 0.3)


func _land(_v: int) -> PackedFloat32Array:
	var thud := Synth.env(Synth.lowpass(Synth.white(0.2, rng), 180.0), 0.003, 0.05)
	return Synth.normalize(Synth.mix(Synth.normalize(thud, 1.0), _step_dirt(0), 0.6), 0.7)


func _splash(_v: int) -> PackedFloat32Array:
	return _spray(0.7, rng.randf_range(600.0, 800.0))


# --- Work ------------------------------------------------------------------

## A knock on wood: a click and the wood's body ringing a moment at `hz`.
func _wood_hit(hz: float, ring: float) -> PackedFloat32Array:
	var body := Synth.tone(ring * 4.0, hz, [[1.0, 1.0, ring], [2.1, 0.6, ring * 0.6], [3.7, 0.35, ring * 0.35], [5.3, 0.2, ring * 0.2]])
	var click := Synth.env(Synth.bandpass(Synth.white(0.04, rng), 3000.0, 1.5), 0.0005, 0.005)
	var thunk := Synth.env(Synth.lowpass(Synth.white(0.1, rng), 200.0), 0.002, 0.025)
	var b := Synth.mix(Synth.normalize(body, 1.0), Synth.normalize(click, 1.0), 0.5)
	return Synth.normalize(Synth.mix(b, Synth.normalize(thunk, 1.0), 0.6), 0.75)


func _chop(_v: int) -> PackedFloat32Array:
	return _wood_hit(rng.randf_range(210.0, 280.0), 0.05)


func _knock(_v: int) -> PackedFloat32Array:
	return Synth.gain(_wood_hit(rng.randf_range(320.0, 420.0), 0.03), 0.8)


func _dig(_v: int) -> PackedFloat32Array:
	var thud := Synth.env(Synth.lowpass(Synth.white(0.3, rng), 500.0), 0.004, 0.06)
	var grit := Synth.env(Synth.grains(0.3, 300.0, 0.01, 1400.0, 1.0, rng, 1.5), 0.01, 0.09)
	var scrape := Synth.env(Synth.bandpass(Synth.white(0.3, rng), 2600.0, 6.0), 0.01, 0.05)
	var b := Synth.mix(Synth.normalize(thud, 1.0), Synth.normalize(grit, 1.0), 0.7)
	return Synth.normalize(Synth.mix(b, Synth.normalize(scrape, 1.0), 0.15), 0.7)


func _hit_stone(_v: int) -> PackedFloat32Array:
	var f := rng.randf_range(1500.0, 2100.0)
	var ping := Synth.tone(0.5, f, [[1.0, 1.0, 0.09], [1.73, 0.6, 0.06], [2.62, 0.4, 0.04], [3.9, 0.2, 0.02]])
	var click := Synth.env(Synth.highpass(Synth.white(0.05, rng), 2000.0), 0.0003, 0.004)
	var gravel := Synth.env(Synth.grains(0.3, 120.0, 0.008, 2500.0, 1.5, rng, 2.0), 0.02, 0.08)
	var b := Synth.mix(Synth.normalize(ping, 0.5), Synth.normalize(click, 1.0), 0.7)
	return Synth.normalize(Synth.mix(b, Synth.normalize(gravel, 1.0), 0.4), 0.7)


func _rustle(_v: int) -> PackedFloat32Array:
	var n := Synth.highpass(Synth.white(0.35, rng), 1800.0)
	var flutter := rng.randf_range(18.0, 30.0)
	n = Synth.shape(n, func(t: float, l: float) -> float: return sin(PI * t / l) * (0.5 + 0.5 * absf(sin(TAU * flutter * t))))
	var leaves := Synth.grains(0.35, 200.0, 0.006, 4000.0, 1.0, rng, 2.0)
	return Synth.normalize(Synth.mix(Synth.normalize(n, 1.0), Synth.normalize(leaves, 1.0), 0.5), 0.5)


func _swish(_v: int) -> PackedFloat32Array:
	var up := rng.randf_range(2000.0, 3500.0)
	var w := Synth.bandpass(Synth.white(0.22, rng), func(t: float) -> float: return 400.0 + up * sin(PI * t / 0.22), 1.5)
	w = Synth.shape(w, func(t: float, l: float) -> float: return pow(sin(PI * t / l), 2.0))
	return Synth.normalize(w, 0.45)


func _mow(_v: int) -> PackedFloat32Array:
	var cut := Synth.env(Synth.grains(0.25, 500.0, 0.005, 3500.0, 1.0, rng, 1.3), 0.03, 0.06)
	return Synth.normalize(Synth.mix(_swish(0), Synth.normalize(cut, 1.0), 0.6), 0.55)


func _place(_v: int) -> PackedFloat32Array:
	var thud := Synth.env(Synth.lowpass(Synth.white(0.15, rng), rng.randf_range(250.0, 400.0)), 0.002, 0.03)
	var click := Synth.env(Synth.bandpass(Synth.white(0.03, rng), 1200.0, 1.5), 0.0005, 0.008)
	return Synth.normalize(Synth.mix(Synth.normalize(thud, 1.0), Synth.normalize(click, 1.0), 0.4), 0.6)


func _pickup(_v: int) -> PackedFloat32Array:
	var f := rng.randf_range(560.0, 680.0)
	var pop := Synth.tone(0.25, func(t: float) -> float: return f * (1.0 + minf(t / 0.05, 1.0) * 0.5), [[1.0, 1.0, 0.05], [2.0, 0.3, 0.03]])
	return Synth.normalize(Synth.env(pop, 0.003, 0.06), 0.4)


## A soft bell at `hz`, ringing `ring` seconds.
func _bell(hz: float, ring: float) -> PackedFloat32Array:
	return Synth.env(Synth.tone(ring * 4.0, hz, [[1.0, 1.0, ring], [2.0, 0.4, ring * 0.5], [3.01, 0.15, ring * 0.3], [4.2, 0.08, ring * 0.2]]), 0.003, ring * 2.0)


func _craft(_v: int) -> PackedFloat32Array:
	var b := Synth.mix(_bell(659.26, 0.25), _bell(987.77, 0.35), 0.8, 0.12)
	return Synth.normalize(b, 0.45)


func _eat(_v: int) -> PackedFloat32Array:
	var b := Synth.silence(0.5)
	for bite in rng.randi_range(2, 3):
		var crunch := Synth.env(Synth.grains(0.12, 400.0, 0.006, rng.randf_range(1200.0, 2000.0), 1.0, rng, 1.5), 0.005, 0.03)
		b = _add(b, crunch, 1.0, bite * rng.randf_range(0.14, 0.2))
	return Synth.normalize(b, 0.5)


func _ignite(_v: int) -> PackedFloat32Array:
	var whoosh := Synth.bandpass(Synth.white(0.8, rng), func(t: float) -> float: return 300.0 + t * 1500.0, 0.8)
	whoosh = Synth.shape(whoosh, func(t: float, l: float) -> float: return minf(t / 0.15, 1.0) * exp(-t * 3.0))
	var crackle := Synth.env(Synth.grains(0.8, 50.0, 0.004, 2600.0, 0.8, rng, 3.0), 0.1, 0.4)
	return Synth.normalize(Synth.mix(Synth.normalize(whoosh, 1.0), Synth.normalize(crackle, 1.0), 0.7), 0.6)


# --- The interface -----------------------------------------------------------

func _tick(hz: float, length: float) -> PackedFloat32Array:
	var t := Synth.env(Synth.tone(length * 4.0, hz, [[1.0, 1.0, 0.0], [2.7, 0.3, 0.0]]), 0.001, length)
	return Synth.normalize(t, 0.35)


func _click(_v: int) -> PackedFloat32Array:
	return _tick(1600.0, 0.012)


func _tab(_v: int) -> PackedFloat32Array:
	return Synth.gain(_tick(1100.0, 0.015), 0.8)


func _open(_v: int) -> PackedFloat32Array:
	var b := Synth.mix(_wood_hit(330.0, 0.025), _wood_hit(440.0, 0.025), 0.8, 0.06)
	return Synth.normalize(b, 0.35)


func _close(_v: int) -> PackedFloat32Array:
	var b := Synth.mix(_wood_hit(440.0, 0.025), _wood_hit(330.0, 0.025), 0.8, 0.06)
	return Synth.normalize(b, 0.35)


# --- Animals -----------------------------------------------------------------

## A voice: harmonics of a pitch that moves by `hz(t)`, its brightness `bright` (how
## much of the higher harmonics), a share of breath `noise`, shaped by `amp(t, l)`.
func _voice(seconds: float, hz: Callable, bright: float, noise: float, amp: Callable) -> PackedFloat32Array:
	var harm := []
	for h in range(1, 8):
		harm.append([float(h), pow(bright, h - 1), 0.0])
	var v := Synth.tone(seconds, hz, harm)
	var breath := Synth.bandpass(Synth.white(seconds, rng), 1200.0, 0.8)
	v = Synth.mix(Synth.normalize(v, 1.0), Synth.normalize(breath, 1.0), noise)
	return Synth.shape(v, amp)


func _rabbit(_v: int) -> PackedFloat32Array:
	var f := rng.randf_range(1800.0, 2400.0)
	var d := rng.randf_range(0.07, 0.11)
	var b := _voice(d, func(t: float) -> float: return f + 300.0 * sin(TAU * 40.0 * t), 0.2, 0.1,
		func(t: float, l: float) -> float: return sin(PI * t / l))
	return Synth.normalize(b, 0.4)


func _squirrel(_v: int) -> PackedFloat32Array:
	var b := Synth.silence(0.7)
	var t := 0.0
	while t < 0.6:
		var f := rng.randf_range(2800.0, 3600.0)
		var chirp := _voice(0.03, func(x: float) -> float: return f * (1.0 - x * 5.0), 0.3, 0.3,
			func(x: float, l: float) -> float: return sin(PI * x / l))
		b = _add(b, chirp, rng.randf_range(0.6, 1.0), t)
		t += rng.randf_range(0.06, 0.1)
	return Synth.normalize(b, 0.45)


func _cat(_v: int) -> PackedFloat32Array:
	var d := rng.randf_range(0.5, 0.75)
	var f0 := rng.randf_range(420.0, 520.0)
	var b := _voice(d, func(t: float) -> float:
		var x := t / d
		return f0 * (1.0 + 0.5 * sin(PI * minf(x * 1.4, 1.0)) - 0.15 * x), 0.55, 0.05,
		func(t: float, l: float) -> float: return sin(PI * t / l) * (0.6 + 0.4 * sin(PI * t / l)))
	# "Me-ow": the mouth opens and closes, a band that moves.
	b = Synth.bandpass(b, func(t: float) -> float: return 800.0 + 1400.0 * sin(PI * clampf(t / d, 0.0, 1.0)), 0.9)
	return Synth.normalize(b, 0.5)


func _deer(_v: int) -> PackedFloat32Array:
	var d := rng.randf_range(0.2, 0.3)
	var f := rng.randf_range(280.0, 360.0)
	var b := _voice(d, func(t: float) -> float: return f * (1.0 - 0.3 * t / d), 0.6, 0.5,
		func(t: float, l: float) -> float: return minf(t / 0.01, 1.0) * exp(-t / (l * 0.4)))
	return Synth.normalize(Synth.lowpass(b, 2500.0), 0.55)


func _wolf_howl(_v: int) -> PackedFloat32Array:
	var d := rng.randf_range(2.2, 3.0)
	var lo := rng.randf_range(330.0, 380.0)
	var hi := lo * rng.randf_range(1.5, 1.8)
	var b := _voice(d, func(t: float) -> float:
		var x := t / d
		var f := lerpf(lo, hi, smoothstep(0.0, 0.25, x)) * (1.0 - 0.2 * smoothstep(0.6, 1.0, x))
		return f * (1.0 + 0.012 * sin(TAU * 5.0 * t) * smoothstep(0.2, 0.4, x)), 0.35, 0.04,
		func(t: float, l: float) -> float: return smoothstep(0.0, 0.3, t) * smoothstep(l, l * 0.7, t))
	return Synth.normalize(Synth.lowpass(b, 3000.0), 0.6)


func _wolf_growl(_v: int) -> PackedFloat32Array:
	var d := rng.randf_range(0.7, 1.0)
	var f := rng.randf_range(80.0, 110.0)
	var b := _voice(d, func(t: float) -> float: return f * (1.0 + 0.1 * sin(TAU * 3.0 * t)), 0.8, 0.6,
		func(t: float, l: float) -> float: return sin(PI * t / l) * (0.6 + 0.4 * sin(TAU * 28.0 * t)))
	return Synth.normalize(Synth.lowpass(b, 1500.0), 0.6)


func _sparrow(_v: int) -> PackedFloat32Array:
	var b := Synth.silence(0.05)
	var t := 0.0
	for n in rng.randi_range(1, 3):
		var f := rng.randf_range(3800.0, 4600.0)
		var d := rng.randf_range(0.04, 0.07)
		var chirp := Synth.tone(d, func(x: float) -> float: return f * (1.0 + 0.4 * sin(PI * x / d)), [[1.0, 1.0, 0.0], [2.0, 0.2, 0.0]])
		chirp = Synth.shape(chirp, func(x: float, l: float) -> float: return sin(PI * x / l))
		b = _add(b, chirp, 1.0, t)
		t += d + rng.randf_range(0.03, 0.08)
	return Synth.normalize(b, 0.5)


# --- Music -----------------------------------------------------------------

## The notes are C4 (261.63 Hz); the music plays them at other pitches.
func _note_pluck(_v: int) -> PackedFloat32Array:
	var b := Synth.pluck(261.63, 3.0, 0.6, rng)
	b = Synth.lowpass(b, 2400.0)
	return Synth.normalize(Synth.env(b, 0.004, 1.2), 0.6)


func _note_bell(_v: int) -> PackedFloat32Array:
	var b := Synth.tone(3.5, 261.63, [[1.0, 1.0, 1.4], [2.0, 0.35, 0.7], [3.0, 0.12, 0.4], [4.07, 0.06, 0.25], [6.1, 0.02, 0.12]])
	return Synth.normalize(Synth.env(b, 0.006, 1.6), 0.6)


## A soft held tone of two voices a little apart, which the music holds under a phrase.
func _pad(_v: int) -> PackedFloat32Array:
	var span := LOOP + OVERLAP
	var b := Synth.silence(span)
	for detune: float in [0.997, 1.003]:
		var v := Synth.tone(span, 130.81 * detune, [[1.0, 1.0, 0.0], [2.0, 0.35, 0.0], [3.0, 0.12, 0.0], [4.0, 0.05, 0.0]])
		b = Synth.mix(b, v, 0.5)
	b = Synth.shape(b, func(t: float, _l: float) -> float: return 0.8 + 0.2 * _wave(t, 3))
	return Synth.normalize(Synth.lowpass(b, 1200.0), 0.5)


## Adds `src` times `level` into `dst` from `at` seconds, in place (growing it).
static func _add(dst: PackedFloat32Array, src: PackedFloat32Array, level: float, at: float) -> PackedFloat32Array:
	var o := Synth.frames(at)
	if dst.size() < o + src.size():
		dst.resize(o + src.size())
	for i in src.size():
		dst[o + i] += src[i] * level
	return dst
