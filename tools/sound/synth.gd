extends RefCounted
## Sounds made from noise and tones, a buffer of samples (-1..1) at RATE at a time:
## noises, filters, envelopes, oscillators, the plucked string, mixing, a seamless loop,
## and saving as a WAV the game reads (tools/make_sounds.gd says what each sound is).
## Everything takes an RNG, so the same seed makes the same sound.

const RATE := 22050


static func frames(seconds: float) -> int:
	return int(seconds * RATE)


static func silence(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(frames(seconds))
	return b


static func white(seconds: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := silence(seconds)
	for i in b.size():
		b[i] = rng.randf_range(-1.0, 1.0)
	return b


## Noise with more of the low sound in it (integrated white noise, kept from drifting).
static func brown(seconds: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := silence(seconds)
	var v := 0.0
	for i in b.size():
		v = v * 0.995 + rng.randf_range(-1.0, 1.0) * 0.1
		b[i] = v
	return normalize(b, 1.0)


## One-pole low-pass at `hz`.
static func lowpass(b: PackedFloat32Array, hz: float) -> PackedFloat32Array:
	var a := 1.0 - exp(-TAU * hz / RATE)
	var y := 0.0
	var out := b.duplicate()
	for i in out.size():
		y += a * (out[i] - y)
		out[i] = y
	return out


static func highpass(b: PackedFloat32Array, hz: float) -> PackedFloat32Array:
	var low := lowpass(b, hz)
	var out := b.duplicate()
	for i in out.size():
		out[i] -= low[i]
	return out


## A band of the sound round `hz` (a biquad, `q` how narrow); `hz` may be a Callable of
## the time in seconds, for a band that moves.
static func bandpass(b: PackedFloat32Array, hz: Variant, q: float) -> PackedFloat32Array:
	var out := b.duplicate()
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	var moving: bool = hz is Callable
	var c := _band(hz if not moving else hz.call(0.0), q)
	for i in out.size():
		if moving and i % 32 == 0:
			c = _band(hz.call(float(i) / RATE), q)
		var x := out[i]
		var y: float = c[0] * x + c[1] * x2 - c[2] * y1 - c[3] * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		out[i] = y
	return out


## Coefficients of a band-pass biquad, unit gain at the centre: b0, b2, a1, a2.
static func _band(hz: float, q: float) -> Array:
	var w := TAU * clampf(hz, 20.0, RATE * 0.45) / RATE
	var alpha := sin(w) / (2.0 * q)
	var a0 := 1.0 + alpha
	return [alpha / a0, -alpha / a0, -2.0 * cos(w) / a0, (1.0 - alpha) / a0]


## Multiplies by an envelope: up in `attack` seconds, then falling by e every `decay`.
static func env(b: PackedFloat32Array, attack: float, decay: float) -> PackedFloat32Array:
	var out := b.duplicate()
	var na := maxf(attack * RATE, 1.0)
	for i in out.size():
		var t := float(i) / RATE
		var g := minf(float(i) / na, 1.0) * exp(-maxf(t - attack, 0.0) / decay)
		out[i] *= g
	return out


## Multiplies by `f(t)` (seconds, the sound's length) sample by sample.
static func shape(b: PackedFloat32Array, f: Callable) -> PackedFloat32Array:
	var out := b.duplicate()
	var length := float(out.size()) / RATE
	for i in out.size():
		out[i] *= f.call(float(i) / RATE, length)
	return out


## A tone of `seconds` whose pitch is `hz` (a number, or a Callable of the time),
## with these harmonics: [multiple, level, decay (seconds, 0 none)] each.
static func tone(seconds: float, hz: Variant, harmonics := [[1.0, 1.0, 0.0]]) -> PackedFloat32Array:
	var b := silence(seconds)
	var phases := []
	phases.resize(harmonics.size())
	phases.fill(0.0)
	var moving: bool = hz is Callable
	var f: float = 0.0 if moving else hz
	for i in b.size():
		var t := float(i) / RATE
		if moving:
			f = hz.call(t)
		var v := 0.0
		for h in harmonics.size():
			var hm: Array = harmonics[h]
			phases[h] += TAU * f * hm[0] / RATE
			var g: float = hm[1]
			if hm[2] > 0.0:
				g *= exp(-t / hm[2])
			v += sin(phases[h]) * g
		b[i] = v
	return b


## A plucked string (Karplus-Strong): `hz`, `seconds` long, `damp` 0..1 how fast the
## high sound dies.
static func pluck(hz: float, seconds: float, damp: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := silence(seconds)
	var n := maxi(int(RATE / hz), 2)
	var ring := PackedFloat32Array()
	ring.resize(n)
	# A soft excitation: noise smoothed, for a mellow string rather than a twangy one.
	var prev := 0.0
	for i in n:
		prev = lerpf(prev, rng.randf_range(-1.0, 1.0), 0.5)
		ring[i] = prev
	var k := 0
	for i in b.size():
		var nxt := (k + 1) % n
		var v := ring[k]
		ring[k] = (v * (1.0 - damp * 0.5) + ring[nxt] * damp * 0.5) * 0.998
		b[i] = v
		k = nxt
	return b


## Adds `src` times `gain` into `dst` from `at` seconds, growing `dst` as needed.
static func mix(dst: PackedFloat32Array, src: PackedFloat32Array, gain := 1.0, at := 0.0) -> PackedFloat32Array:
	var out := dst.duplicate()
	var o := frames(at)
	if out.size() < o + src.size():
		out.resize(o + src.size())
	for i in src.size():
		out[o + i] += src[i] * gain
	return out


static func gain(b: PackedFloat32Array, g: float) -> PackedFloat32Array:
	var out := b.duplicate()
	for i in out.size():
		out[i] *= g
	return out


static func normalize(b: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var m := 0.0
	for v in b:
		m = maxf(m, absf(v))
	return gain(b, peak / m) if m > 0.0 else b


## Short rises and falls at the ends, so a one-off sound neither clicks in nor out.
static func fade(b: PackedFloat32Array, inn := 0.002, out := 0.01) -> PackedFloat32Array:
	var r := b.duplicate()
	var ni := maxi(frames(inn), 1)
	var no := maxi(frames(out), 1)
	for i in mini(ni, r.size()):
		r[i] *= float(i) / ni
	for i in mini(no, r.size()):
		r[r.size() - 1 - i] *= float(i) / no
	return r


## Makes `b` loop without a seam: its last `overlap` seconds are faded into its start
## and cut off.
static func loopify(b: PackedFloat32Array, overlap: float) -> PackedFloat32Array:
	var n := frames(overlap)
	var keep := b.size() - n
	var out := b.slice(0, keep)
	for i in n:
		var t := float(i) / n
		# Equal power, so the seam is not quieter.
		out[i] = out[i] * sin(t * PI * 0.5) + b[keep + i] * cos(t * PI * 0.5)
	return out


## Short noise clicks sprinkled over `seconds`: `per_second` of them, each `length`
## seconds long round `hz` with `q`, louder ones rarer (power `spread`).
static func grains(seconds: float, per_second: float, length: float, hz: float, q: float,
		rng: RandomNumberGenerator, spread := 2.0) -> PackedFloat32Array:
	var b := silence(seconds)
	var count := int(seconds * per_second)
	for c in count:
		var g := white(length * rng.randf_range(0.6, 1.4), rng)
		g = env(bandpass(g, hz * rng.randf_range(0.7, 1.4), q), 0.0005, length * 0.3)
		var o := frames(rng.randf() * maxf(seconds - length, 0.0))
		var level := pow(rng.randf(), spread)
		for i in mini(g.size(), b.size() - o):
			b[o + i] += g[i] * level
	return b


## Saves `b` as a 16-bit mono WAV at RATE.
static func save(b: PackedFloat32Array, path: String) -> Error:
	var data := PackedByteArray()
	data.resize(b.size() * 2)
	for i in b.size():
		data.encode_s16(i * 2, int(clampf(b[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w.save_to_wav(path)
