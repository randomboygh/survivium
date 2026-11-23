extends Control
## What is shown over the world while the character lies dead, behind the death screen
## (DeathScreen): one look picked at random at each death (LOOKS, never the one before),
## the user's picks of 2026-11-23. The grade (grade.gdshader `death_*`) fades, cools,
## darkens or tints the world round the body; this control draws the small things over
## it on the picture's grid (a light, dust, flowers, a ghost, moths, leaves, snow,
## stars), each a pixel of the low-res image. At the moment of death the world slows
## for a moment (alone in one's own world: Engine.time_scale) and its sounds and the
## music are muffled (Sound.hush) while the death lasts; the death's sound and the
## look's own are the interface's. When the character lives again it all fades out.
## The clock is the real one, so the slowing does not slow the look. `game` is the Main node.

const PixelView := preload("res://src/client/view/pixel_view.gd")
const SoundScript := preload("res://src/client/audio/sound.gd")

## The looks, in the order of grade.gdshader's `death_look` (1-based).
const LOOKS := ["light", "dust", "sepia", "flowers", "ghost", "rings", "night", "moths", "leaves", "snow",
	"stars", "fog"]
## How long the look takes to come in, and to go when the character lives again.
const COME_IN := 2.6
const FADE_OUT := 0.8
## The world's pace at the moment of death, and when it is back to normal.
const SLOWEST := 0.15
const SLOW_FOR := 1.6
## How loud the world and the music are while the character is dead (linear).
const HUSHED := 0.3
const HUSH_IN := 0.4
const HUSH_OUT := 1.5
## When the look's own sound plays, seconds after the death.
const LOOK_SOUND_AT := 0.7
## At most this many snowflakes (each a rectangle drawn a frame: the phone is slow).
const MOST_FLAKES := 400
## The 4x4 ordered dither, as grade.gdshader and sprite.gdshader have it.
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

var game
## The look shown ("" none), forced by the shots and tests (`force`), and the one before.
var look := ""
var force := ""
## Seconds each frame takes the look on when above 0 (the shots, which draw slowly),
## instead of the real clock's.
var fixed_step := 0.0
var _last := ""
## Real seconds since the death, and since the character lives again (-1 still dead).
var time := 0.0
var _since := -1.0
var _clock := 0
## How much of the look shows, 0..1, and how loud the world is let be.
var mix := 0.0
var _hush := 1.0
var _slowing := false
var _sounded := false
## The body: the world pixel of its middle, its pixels' world pixels and their turns
## to go (sprite.gdshader `dissolve`); the top left of its frame, its size.
var at := Vector2.ZERO
var body: Array[Vector2i] = []
var turns: Array[float] = []
var edge: Array[bool] = []
## What this look keeps: sparks, flowers, flakes and so on, made at its start.
var bits: Array = []
var rng := RandomNumberGenerator.new()


func _init(g) -> void:
	game = g
	name = "DeathFx"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Run every frame once the world is built: starts the look at a death, leads it on,
## fades it out once the character lives again.
func update(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	var step := 0.0 if _clock == 0 else (now - _clock) / 1000.0
	if fixed_step > 0.0:
		step = fixed_step
	_clock = now
	var dead: bool = game.character.is_dead()
	if dead and look == "":
		start()
	elif dead and _since >= 0.0:
		_since = -1.0
	elif not dead and look != "" and _since < 0.0:
		_since = 0.0
	if look == "":
		_ease_hush(step)
		return
	time += step
	if _since >= 0.0:
		_since += step
		mix = minf(mix, 1.0 - _since / FADE_OUT)
		game.player.dissolve = 0.0
		if _since >= FADE_OUT:
			stop()
			return
	else:
		mix = smoothstep(0.0, COME_IN, time - 0.3)
	_slow()
	_ease_hush(step)
	if not _sounded and time >= LOOK_SOUND_AT:
		_sounded = true
		game.sound.play("death_" + look)
	_grade()
	queue_redraw()


## Starts a look (`force` or one at random, not the last one) at the body as it lies now.
func start() -> void:
	look = force
	if look == "":
		var pick: Array = LOOKS.duplicate()
		pick.erase(_last)
		look = pick[randi() % pick.size()]
	_last = look
	time = 0.0
	_since = -1.0
	mix = 0.0
	_sounded = false
	rng.seed = Time.get_ticks_usec()
	_read_body()
	_make_bits()
	game.sound.play("death")
	_slowing = _alone()
	print("death look: %s" % look)


## Ends the look: the grade and the body as they were, the world at its pace.
func stop() -> void:
	look = ""
	mix = 0.0
	bits.clear()
	game.player.dissolve = 0.0
	if _slowing:
		Engine.time_scale = 1.0
		_slowing = false
	var g: ShaderMaterial = game.view.grade_mat
	if g != null:
		g.set_shader_parameter("death_look", 0)
		g.set_shader_parameter("death_mix", 0.0)
	queue_redraw()


## Whether the world is this device's alone (no other players): only then may its
## pace change.
func _alone() -> bool:
	return game.host != null and game.link.join_url == "" and game.host.session.players.size() <= 1


func _slow() -> void:
	if not _slowing:
		return
	var k := smoothstep(0.2, SLOW_FOR, time)
	Engine.time_scale = lerpf(SLOWEST, 1.0, k)
	if k >= 1.0:
		_slowing = false


func _ease_hush(step: float) -> void:
	var want := HUSHED if look != "" and _since < 0.0 else 1.0
	if _hush == want:
		return
	_hush = move_toward(_hush, want, step * (1.0 - HUSHED) / (HUSH_IN if want < _hush else HUSH_OUT))
	SoundScript.hush(_hush)


## The body's pixels as it lies (Player: its sheet's frame of `sleep`), in world pixels
## (PixelView.screen_plane), and the turn of each to go, as sprite.gdshader counts it.
func _read_body() -> void:
	body.clear()
	turns.clear()
	edge.clear()
	var player = game.player
	var foot: Vector2 = PixelView.screen_plane(player.sprite.global_position) * PixelView.PIXELS_PER_UNIT
	at = foot + Vector2(0.0, -4.0)
	var sheet = player.sheet
	if sheet == null or sheet.texture == null:
		return
	var img: Image = sheet.texture.get_image()
	if img == null:
		return
	var size: Vector2i = sheet.frame_size
	var f: Vector4 = sheet.frame_uv(player.drawn_facing(), "sleep", player.anim_time)
	var flip := f.z < 0.0
	var x0 := roundi((f.x + f.z if flip else f.x) * img.get_width())
	var y0 := roundi(f.y * img.get_height())
	var top := Vector2i(roundi(foot.x) - size.x / 2, roundi(foot.y) - size.y)
	var solid := {}
	for y in size.y:
		for x in size.x:
			var sx := size.x - 1 - x if flip else x
			if img.get_pixel(x0 + sx, y0 + y).a >= 0.5:
				solid[Vector2i(x, y)] = true
	var sum := Vector2.ZERO
	for p: Vector2i in solid:
		body.append(top + p)
		turns.append(turn_of(p, size))
		edge.append(not (solid.has(p + Vector2i.LEFT) and solid.has(p + Vector2i.RIGHT)
			and solid.has(p + Vector2i.UP) and solid.has(p + Vector2i.DOWN)))
		sum += Vector2(top + p) + Vector2(0.5, 0.5)
	if not body.is_empty():
		at = sum / body.size()


## A texel's turn to go as sprite.gdshader `dissolve` counts it: 0.6 by its column, 0.4
## by the 4x4 matrix.
static func turn_of(p: Vector2i, size: Vector2i) -> float:
	return 0.6 * float(p.x) / size.x + 0.4 * (BAYER[(p.y % 4) * 4 + p.x % 4] + 0.5) / 16.0


## Makes what this look keeps: each bit an Array of its numbers (see _draw).
func _make_bits() -> void:
	bits.clear()
	match look:
		"dust":
			for i in body.size():
				bits.append([Vector2(body[i]), 0.8 + turns[i] * 2.0, rng.randf_range(6.0, 11.0), rng.randf_range(0.0, 6.0)])
		"flowers":
			var colours := [Color8(240, 240, 230), Color8(150, 180, 255), Color8(255, 220, 90), Color8(240, 150, 190),
				Color8(200, 160, 255)]
			for i in 34:
				var a := rng.randf_range(0.0, TAU)
				var r := rng.randf_range(3.0, 16.0)
				bits.append([(at + Vector2(cos(a) * r * 1.3, 2.0 + sin(a) * r * 0.8)).floor(), colours[rng.randi() % colours.size()],
					1.0 + rng.randf_range(0.0, 1.8), [1, 2, 2, 3][rng.randi() % 4]])
			bits.sort_custom(func(a: Array, b: Array) -> bool: return a[0].y < b[0].y)
		"night":
			for i in 14:
				bits.append([Vector2(rng.randf_range(-60.0, 60.0), rng.randf_range(-100.0, 40.0)), rng.randf_range(0.0, 6.0)])
		"moths":
			for i in 6:
				bits.append([0.9 + i * 0.35, rng.randf_range(0.0, 6.0), [-1.0, 1.0][rng.randi() % 2], rng.randf_range(7.0, 11.0)])
		"leaves":
			var colours := [Color8(222, 140, 50), Color8(240, 190, 70), Color8(180, 90, 40), Color8(200, 120, 60)]
			for i in 120:
				var to := at + Vector2(rng.randf_range(-60.0, 60.0), rng.randf_range(-140.0, 60.0))
				if i < 40:
					to = at + Vector2(rng.randf_range(-9.0, 9.0), rng.randf_range(-5.0, 5.0))
				bits.append([to, rng.randf_range(0.6, 4.5), rng.randf_range(0.0, 6.0), colours[rng.randi() % colours.size()]])
		"snow":
			var size: Vector2 = Vector2(game.view.image_size)
			for i in mini(MOST_FLAKES, int(size.x * size.y / 160.0)):
				bits.append([Vector2(rng.randf_range(0.0, size.x), rng.randf_range(0.0, size.y)), rng.randf_range(3.0, 7.0),
					rng.randf_range(0.0, 6.0), rng.randf() < 0.25, rng.randf()])
		"stars":
			for i in 60:
				bits.append([at + Vector2(rng.randf_range(-90.0, 90.0), rng.randf_range(-110.0, 40.0)), rng.randf_range(0.0, 6.0)])
		"light":
			for i in 60:
				bits.append([0.7 + i * 0.12, rng.randf_range(-1.0, 2.0), rng.randf_range(0.0, 6.0)])


## Where the look's light is (light, ghost), x and y in world pixels and z how strong.
func _light_at() -> Vector3:
	match look:
		"light":
			var a := smoothstep(0.7, 1.3, time)
			var p := at + Vector2(sin(time * 1.3) * 3.0, -3.0 - minf(26.0, maxf(0.0, time - 0.7) * 9.0) + sin(time * 2.2) * 1.2)
			return Vector3(p.x, p.y, a * mix)
		"ghost":
			var g := _ghost()
			return Vector3(at.x + g.x, at.y + g.y, g.z * mix)
	return Vector3.ZERO


## How far the ghost has risen over the body and how much of it shows.
func _ghost() -> Vector3:
	if time < 0.8:
		return Vector3.ZERO
	var a := smoothstep(0.8, 1.6, time) * (1.0 - 0.6 * smoothstep(3.5, 5.5, time))
	return Vector3(roundf(sin(time * 1.4) * 2.0), -roundf(minf(30.0, (time - 0.8) * 9.0)), a)


func _grade() -> void:
	var g: ShaderMaterial = game.view.grade_mat
	if g == null:
		return
	g.set_shader_parameter("death_look", LOOKS.find(look) + 1)
	g.set_shader_parameter("death_mix", mix)
	g.set_shader_parameter("death_time", time)
	g.set_shader_parameter("death_at", at)
	g.set_shader_parameter("death_light", _light_at())
	match look:
		"dust":
			game.player.dissolve = smoothstep(0.8, 2.8, time) * 1.01
		"flowers":
			game.player.dissolve = smoothstep(1.0, 2.6, time) * 1.01


## How bright what is drawn over the world may be by night (glowing things are not dimmed).
func _dim() -> float:
	return lerpf(0.35, 1.0, clampf(game.sky.sky_light, 0.0, 1.0))


## A pixel at world pixel `w` (its whole part) in colour `c`, over the picture's grid.
func _px(w: Vector2, c: Color) -> void:
	if c.a <= 0.01:
		return
	var view = game.view
	var origin: Vector2 = view.origin_px
	var s: float = view.view_scale
	var p: Vector2 = view.container.position + (w.floor() - origin) * s
	draw_rect(Rect2(p, Vector2(s, s)), c)


func _draw() -> void:
	if look == "" or mix <= 0.0 or game.view.first_person:
		return
	var t := time
	var fade := mix if _since >= 0.0 else 1.0
	match look:
		"light":
			var l := _light_at()
			if l.z > 0.0:
				var p := Vector2(roundf(l.x), roundf(l.y))
				for d: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
					_px(p + d, Color8(255, 248, 210, int(255 * l.z)))
				for d: Vector2 in [Vector2(0, -1), Vector2(0, 2), Vector2(-1, 0), Vector2(-1, 1), Vector2(2, 0), Vector2(2, 1)]:
					_px(p + d, Color8(255, 200, 110, int(180 * l.z)))
			for b: Array in bits:
				var age: float = t - b[0]
				if age < 0.0 or age >= 1.4:
					continue
				# A spark falls off the light from where it was then.
				var then: float = b[0]
				var lp := at + Vector2(sin(then * 1.3) * 3.0 + b[1], -1.0 - minf(26.0, (then - 0.7) * 9.0) + sin(then * 2.2) * 1.2)
				_px(lp + Vector2(sin(age * 4.0 + b[2]) * 1.5, age * 5.0), Color8(255, 210, 120, int(255 * (1.0 - age / 1.4) * fade)))
				if then + 7.2 < t:
					b[0] = then + 7.2
		"dust":
			for b: Array in bits:
				var age: float = t - b[1]
				if age < 0.0 or age >= 2.2:
					continue
				var sp: float = b[2]
				var p: Vector2 = b[0] + Vector2(age * sp * 0.6 + sin(age * 3.0 + b[3]) * 1.5, -age * sp)
				var c := Color8(225, 205, 175).lerp(Color8(255, 236, 190), minf(1.0, age))
				c.a = (1.0 - age / 2.2) * fade
				_px(p, c)
		"flowers":
			var dim := _dim()
			for b: Array in bits:
				var grow := smoothstep(b[2], b[2] + 0.5, t)
				if grow <= 0.0:
					continue
				var h: int = b[3]
				var hh := maxi(1, roundi(h * grow))
				var stem := Color8(70, 130, 50) * dim
				stem.a = fade
				for s in hh:
					_px(b[0] + Vector2(0, -s), stem)
				if grow >= 1.0:
					var c: Color = b[1] * dim
					c.a = fade
					_px(b[0] + Vector2(0, -hh), c)
					if h >= 2:
						c.a = 0.75 * fade
						for d: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1)]:
							_px(b[0] + Vector2(0, -hh) + d, c)
			_flies(6, 1.5, 0.5)
		"ghost":
			var g := _ghost()
			if g.z > 0.0:
				for i in body.size():
					var p := Vector2(body[i]) + Vector2(g.x, g.y)
					var o: float = (BAYER[(posmod(int(p.y), 4)) * 4 + posmod(int(p.x), 4)] + 0.5) / 16.0
					if edge[i] and o < g.z:
						_px(p, Color(0.88, 0.94, 1.0, 0.8 * fade))
					elif not edge[i] and o < g.z * 0.4:
						_px(p, Color(0.78, 0.86, 1.0, 0.5 * fade))
		"night":
			_flies(14, 1.8, 1.0)
		"moths":
			var colours := [Color8(250, 250, 240), Color8(255, 236, 170), Color8(200, 220, 255)]
			for j in bits.size():
				var b: Array = bits[j]
				var age: float = t - b[0]
				if age < 0.0:
					continue
				var p := (at + Vector2(b[2] * age * 4.0 + sin(age * 3.0 + b[1]) * 4.0, -2.0 - age * b[3])).round()
				if p.y < at.y - 200.0:
					continue
				var c: Color = colours[j % 3]
				c.a = fade
				var open := int(t * 8.0 + j) % 2 == 0
				var parts := [Vector2(0, 0), Vector2(1, 0)]
				parts.append_array([Vector2(-1, -1), Vector2(2, -1), Vector2(-1, 0), Vector2(2, 0)] if open else [Vector2(0, -1), Vector2(1, -1)])
				for d: Vector2 in parts:
					_px(p + d, c)
		"leaves":
			var dim := _dim()
			for b: Array in bits:
				var age: float = t - b[1]
				if age < 0.0:
					continue
				var k := minf(1.0, age / 1.6)
				var p: Vector2 = (b[0] + Vector2(sin(age * 3.0 + b[2]) * 3.0 * (1.0 - k), -(1.0 - k) * 40.0)).round()
				var c: Color = b[3] * dim
				c.a = fade
				_px(p, c)
				if k >= 1.0 or int(age * 6.0) % 2 == 1:
					_px(p + Vector2(1, 0), Color(c.r * 0.8, c.g * 0.8, c.b * 0.8, c.a))
				if k >= 1.0:
					_px(p + Vector2(0, 1), Color(c.r * 0.7, c.g * 0.7, c.b * 0.7, c.a))
		"snow":
			var size: Vector2 = Vector2(game.view.image_size)
			var origin: Vector2 = game.view.origin_px
			var dense := smoothstep(0.3, 2.0, t)
			var dim := lerpf(0.55, 1.0, clampf(game.sky.sky_light, 0.0, 1.0))
			for b: Array in bits:
				if b[4] > dense:
					continue
				# The flakes keep to the screen as the picture glides (they fall in the air).
				var y: float = fposmod(b[0].y + t * b[1], size.y)
				var x: float = b[0].x + sin(t * 1.2 + b[2]) * 2.0
				var w := origin + Vector2(x, y)
				_px(w, Color(0.96 * dim, 0.98 * dim, dim, 0.9 * fade))
				if b[3]:
					_px(w + Vector2(1, 0), Color(0.92 * dim, 0.95 * dim, dim, 0.6 * fade))
		"stars":
			var sky := at + Vector2(0.0, -38.0)
			var pts := [Vector2(0, -14), Vector2(-5, -6), Vector2(5, -6), Vector2(-9, 2), Vector2(9, 2), Vector2(0, 2),
				Vector2(-4, 12), Vector2(4, 12)]
			var lines := [[0, 5], [1, 2], [1, 3], [2, 4], [1, 5], [2, 5], [5, 6], [5, 7]]
			for b: Array in bits:
				var a := smoothstep(1.0, 2.0, t) * (0.5 + 0.5 * sin(t * 3.0 + b[1]))
				if a > 0.4:
					_px(b[0], Color(0.78, 0.82, 1.0, a * 0.8 * fade))
			var la := smoothstep(2.4, 3.4, t)
			if la > 0.0:
				for ln: Array in lines:
					var p0: Vector2 = pts[ln[0]]
					var p1: Vector2 = pts[ln[1]]
					var n := int(maxf(absf(p1.x - p0.x), absf(p1.y - p0.y)))
					for s in range(0, n + 1, 2):
						_px((sky + p0 + (p1 - p0) * float(s) / n).round(), Color(0.67, 0.75, 1.0, 0.6 * la * fade))
			for j in pts.size():
				var a := smoothstep(1.0 + j * 0.18, 1.4 + j * 0.18, t)
				if a <= 0.0:
					continue
				var tw := 0.8 + 0.2 * sin(t * 5.0 + j)
				var p: Vector2 = (sky + pts[j]).round()
				_px(p, Color(1.0, 1.0, 0.92, a * tw * fade))
				for d: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
					_px(p + d, Color(0.86, 0.9, 1.0, 0.6 * a * tw * fade))


## Fireflies round the body: `count` of the bits, lit from `from` seconds, `spread` of
## the bits' offsets.
func _flies(count: int, from: float, spread: float) -> void:
	var fade := mix if _since >= 0.0 else 1.0
	for i in mini(count, bits.size()):
		var b: Array = bits[i] if look == "night" else [Vector2(sin(i * 2.1) * 20.0, cos(i * 1.7) * 15.0 - 10.0), i * 1.3]
		var a := smoothstep(from, from + 1.0, time) * (0.5 + 0.5 * sin(time * 2.3 + b[1]))
		if a <= 0.35:
			continue
		var p: Vector2 = at + b[0] * spread + Vector2(sin(time * 0.5 + b[1]) * 5.0, cos(time * 0.6 + b[1]) * 4.0)
		_px(p, Color(0.9, 1.0, 0.59, a * fade))


## Leaving the world (to the menu) mid-death: the pace and the sounds as they were.
func _exit_tree() -> void:
	if _slowing:
		Engine.time_scale = 1.0
		_slowing = false
	SoundScript.hush(1.0)
