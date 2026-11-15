extends RefCounted
## The shape of each thunder in time, shared by the tool that makes the sounds
## (tools/make_sounds.gd, `_thunder`) and the phone's vibration that follows the one
## heard (Vibration.rumble): a thunder is «ту-дууух» — one or two dull hits («ту»),
## then a big boom («дууух») a moment after, then a few rolls fading out. The kinds
## differ in how near (a sharp hit or a soft one), how long the boom and how many rolls.

## The kinds, one a variant of the sound (thunder_1.wav … in the order made).
const KINDS := ["near", "far", "double", "roller", "growl", "short"]


## The shape of thunder variant `v` (0-based): {"span" s, "hits": [[at s, strength]…]
## (the «ту»), "boom": [at s, length s] (the «дууух»), "rolls": [[at s, width s,
## height]…] after it, "body" Hz the sound's body is centred on}.
static func of(v: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4111 + v * 613
	var kind: String = KINDS[v % KINDS.size()]
	var hits := [[0.0, 1.0]]
	var boom := [rng.randf_range(0.14, 0.22), 0.55]
	var rolls := []
	var span := 4.0
	var body := 320.0
	match kind:
		"near":
			boom = [rng.randf_range(0.10, 0.16), 0.7]
			rolls = [[1.4, 0.5, 0.45], [2.3, 0.6, 0.25]]
			span = 4.0
			body = 380.0
		"far":
			hits = [[0.0, 0.5]]
			boom = [rng.randf_range(0.25, 0.35), 0.9]
			rolls = [[1.9, 0.7, 0.4], [3.0, 0.8, 0.25]]
			span = 4.8
			body = 260.0
		"double":
			hits = [[0.0, 0.8], [rng.randf_range(0.16, 0.22), 1.0]]
			boom = [rng.randf_range(0.36, 0.44), 0.6]
			rolls = [[1.6, 0.5, 0.35]]
			span = 3.8
			body = 340.0
		"roller":
			boom = [rng.randf_range(0.16, 0.22), 0.6]
			var at := 1.2
			for i in 4:
				rolls.append([at, 0.4, lerpf(0.55, 0.2, i / 3.0)])
				at += rng.randf_range(0.6, 0.8)
			span = 5.0
			body = 300.0
		"growl":
			hits = [[0.0, 0.6]]
			boom = [rng.randf_range(0.2, 0.28), 1.1]
			rolls = [[2.0, 0.7, 0.3]]
			span = 4.2
			body = 280.0
		_:
			boom = [rng.randf_range(0.12, 0.18), 0.4]
			rolls = [[1.0, 0.4, 0.25]]
			span = 2.6
			body = 360.0
	return {"span": span, "hits": hits, "boom": boom, "rolls": rolls, "body": body}


## How loud the boom and rolls of thunder `s` (see of) are at `t` seconds (0..1): the
## boom swells fast and dies over its length, each roll a soft swell after it.
static func gain(s: Dictionary, t: float) -> float:
	var at: float = s.boom[0]
	var length: float = s.boom[1]
	var g := 0.0
	if t >= at:
		var x := t - at
		g = minf(x / 0.06, 1.0) * exp(-x / (length * 0.45))
	for r: Array in s.rolls:
		g += r[2] * exp(-pow((t - r[0]) / r[1], 2.0))
	return minf(g, 1.0) * smoothstep(s.span, s.span * 0.7, t)
