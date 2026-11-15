extends RefCounted
## The shape of each thunder in time, shared by the tool that makes the sounds
## (tools/make_sounds.gd, `_thunder`) and the phone's vibration that follows the one
## heard (Vibration.rumble). Like a recorded peal: a hit or two («ту»), the roar coming
## up fast and holding loud for a second or two («дууух»), its loudness jostling as it
## holds, then a long falling roll, sometimes with a late roll after. The kinds differ
## in how near (a sharp hit or none), how long the roar holds and how long the roll.

## The kinds, one a variant of the sound (thunder_1.wav … in the order made).
const KINDS := ["near", "far", "double", "roller", "growl", "short"]


## The shape of thunder variant `v` (0-based): {"span" s, "hits": [[at s, strength]…],
## "rise" s the roar takes to come up, "hold": [from s, length s] it stays loud,
## "fall" s its roll takes to fall by e, "rolls": [[at s, width s, height]…] late
## ones, "low"/"high" Hz the grains' cut-offs range over, "seed"}.
static func of(v: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4111 + v * 613
	var kind: String = KINDS[v % KINDS.size()]
	var s := {"span": 6.0, "hits": [[0.0, 1.0]], "rise": 0.08, "hold": [0.1, 1.4], "fall": 1.3,
		"rolls": [], "low": 160.0, "high": 700.0, "seed": 977 + v * 31}
	match kind:
		"near":
			s.hold = [0.06, rng.randf_range(1.2, 1.6)]
			s.fall = 1.1
			s.span = 5.5
			s.high = 900.0
		"far":
			s.hits = []
			s.rise = 0.45
			s.hold = [0.4, rng.randf_range(1.8, 2.4)]
			s.fall = 1.8
			s.span = 7.0
			s.low = 110.0
			s.high = 420.0
		"double":
			s.hits = [[0.0, 0.8], [rng.randf_range(0.35, 0.5), 1.0]]
			s.hold = [0.4, rng.randf_range(1.1, 1.4)]
			s.fall = 1.2
			s.span = 5.5
		"roller":
			s.hold = [0.12, rng.randf_range(1.3, 1.7)]
			s.fall = 1.0
			s.rolls = [[rng.randf_range(3.6, 4.2), 0.6, 0.75], [rng.randf_range(5.4, 6.0), 0.5, 0.4]]
			s.span = 8.0
		"growl":
			s.hits = [[0.0, 0.5]]
			s.rise = 0.7
			s.hold = [0.7, rng.randf_range(1.4, 1.8)]
			s.fall = 1.5
			s.span = 6.5
			s.high = 550.0
		_:
			s.hold = [0.06, rng.randf_range(0.6, 0.8)]
			s.fall = 0.8
			s.span = 3.8
	return s


## How loud thunder `s` (see of) roars at `t` seconds (0..1, before its jostle): up
## over `rise`, held, then falling, with the late rolls; silent by the end.
static func gain(s: Dictionary, t: float) -> float:
	var from: float = s.hold[0]
	var end: float = from + float(s.hold[1])
	var g := minf(t / maxf(s.rise, 0.01), 1.0)
	if t > end:
		g *= exp(-(t - end) / float(s.fall))
	for r: Array in s.rolls:
		g += r[2] * exp(-pow((t - r[0]) / r[1], 2.0))
	return minf(g, 1.0) * smoothstep(s.span, s.span * 0.8, t)
