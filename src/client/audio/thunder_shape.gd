extends RefCounted
## The shape of each thunder in time, shared by the tool that makes the sounds
## (tools/make_sounds.gd, `_thunder`) and the phone's vibration that follows the one
## heard (Vibration.rumble): how long it lasts, its crack(s) and the swells of its
## rumble rolling in and out, so what is felt rises and falls with what is heard.
## Each kind is a different thunder: near (a crack, then a big roll), far (no crack,
## slow low rolls), a double clap, a long roller of many echoes, a growl that grows
## and dies, a short one.

## The kinds, one a variant of the sound (thunder_1.wav … in the order made).
const KINDS := ["near", "far", "double", "roller", "growl", "short"]


## The shape of thunder variant `v` (0-based): {"span" s, "cracks": [[at s, strength]…],
## "swells": [[at s, width s, height]…], "low" Hz of the rumble's lowpass}.
static func of(v: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4111 + v * 613
	var kind: String = KINDS[v % KINDS.size()]
	var swells := []
	var cracks := []
	var span := 6.0
	var low := 220.0
	match kind:
		"near":
			span = rng.randf_range(5.5, 6.5)
			cracks = [[0.0, 1.0]]
			swells = [[0.25, 0.4, 1.0], [rng.randf_range(1.2, 1.6), 0.6, 0.7], [rng.randf_range(2.6, 3.2), 0.8, 0.45]]
			low = 260.0
		"far":
			span = rng.randf_range(7.0, 8.0)
			low = 150.0
			var at := 0.6
			for i in 4:
				swells.append([at, rng.randf_range(0.6, 0.9), rng.randf_range(0.5, 1.0)])
				at += rng.randf_range(1.0, 1.6)
		"double":
			span = rng.randf_range(5.0, 5.8)
			cracks = [[0.0, 0.8], [rng.randf_range(0.8, 1.1), 1.0]]
			swells = [[0.2, 0.35, 0.8], [1.2, 0.45, 1.0], [rng.randf_range(2.3, 2.8), 0.7, 0.5]]
			low = 240.0
		"roller":
			span = rng.randf_range(8.5, 9.5)
			low = 200.0
			var at := 0.3
			var n := rng.randi_range(6, 7)
			for i in n:
				swells.append([at, rng.randf_range(0.35, 0.6), lerpf(1.0, 0.35, float(i) / n) * rng.randf_range(0.75, 1.0)])
				at += rng.randf_range(0.8, 1.25)
		"growl":
			span = rng.randf_range(6.5, 7.5)
			low = 180.0
			for i in 5:
				var at := 0.4 + i * rng.randf_range(0.8, 1.0)
				swells.append([at, 0.55, 0.3 + 0.7 * sin(PI * (i + 0.5) / 5.0)])
		_:
			span = rng.randf_range(3.5, 4.2)
			cracks = [[0.0, 0.6]]
			swells = [[0.3, 0.5, 1.0], [rng.randf_range(1.3, 1.8), 0.6, 0.6]]
	return {"span": span, "cracks": cracks, "swells": swells, "low": low}


## How loud thunder `s` (see of) rolls at `t` seconds: its swells over a low floor,
## fading out by the end (0 .. about 1.3).
static func gain(s: Dictionary, t: float) -> float:
	var span: float = s.span
	var g := 0.0
	for w: Array in s.swells:
		g += w[2] * exp(-pow((t - w[0]) / w[1], 2.0))
	return (0.15 + g) * smoothstep(span, span * 0.5, t) * minf(t / 0.05, 1.0)
