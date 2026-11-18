extends Node3D
## Tumbleweeds (the user's ask, 2026-11-18): dry balls of twigs that roll with the wind
## over the open ground of the biomes with `tumbleweeds` (the desert's), turning as they
## roll, hopping over bumps, faster in a strong wind; they come in from upwind past the
## edge of the screen and roll off the other side. A picture of the client only (each
## player sees their own), lit by the sun and casting its shadow (sprite.gdshader, as
## the animals). Held and stepped by NatureEffects, with the setting «Жизнь в воздухе»;
## hidden in «Что рисуется» as its `effects: tumbleweeds`.

const PixelView := preload("res://src/client/view/pixel_view.gd")
const PlayerScript := preload("res://src/client/view/player.gd")
const SpriteShader := preload("res://shaders/sprite.gdshader")
const WorldData := preload("res://src/shared/world/world_data.gd")
const Mat := preload("res://src/shared/content/materials.gd")
const Biomes := preload("res://src/shared/content/biomes.gd")

const CELL := WorldData.CELL
## The picture: SIZE px square, FRAMES turns of it side by side (a turn of the ball is
## FRAMES frames), drawn from TWIGS arcs of a twig.
const SIZE := 14
const FRAMES := 8
const TWIGS := 14
## Speed along the wind, world units a second: at the calmest and per unit of the wind's
## strength (Sky.wind_now, about 0.3 calm, 1 a breeze, 3 a storm), and how fast a
## ball takes up the wind's speed (per second).
const PACE := 0.5
const PACE_PER_WIND := 1.2
const TAKE_UP := 1.5
const GRAVITY := 14.0
## A hop: the chance a second of one while rolling on the ground, its speed up, and how
## much of the speed down a landing gives back up (a bounce).
const HOP_CHANCE := 0.5
const HOP := Vector2(1.0, 2.6)
const BOUNCE := 0.35
## A rise ahead up to this many cells is rolled or hopped up; a higher one stops the ball
## (it rests against it a while and goes).
const CLIMB := 1.2
const STUCK_MOST := 4.0
## Past the edge of the screen (world units) a ball comes in from and is gone at.
const EDGE := 3.0
## Seconds between looks at the biome round the player, and between two balls coming in.
const LOOK_EVERY := 0.5
const COME_GAP := Vector2(1.5, 6.0)

var game
var _sheet: ImageTexture
var _mesh: ArrayMesh
## Each ball: {"node", "on", "at" (world point of its bottom), "vel" (Vector2), "vy",
## "roll" (radians), "pace" (its own share of the wind's speed), "stuck"}.
var _balls: Array[Dictionary] = []
var _want := 0
var _look_in := 0.0
var _come_in := 0.0


func _init(g) -> void:
	game = g


func _ready() -> void:
	_sheet = ImageTexture.create_from_image(sheet())
	_mesh = PixelView.sprite_mesh(SIZE, SIZE)


## The picture of a tumbleweed, FRAMES turns of it side by side: arcs of twig crossing
## round a hollow middle, the twigs in three dry tones, a darker one at the back.
static func sheet() -> Image:
	var img := Image.create_empty(SIZE * FRAMES, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7151
	var twigs := []
	for i in TWIGS:
		# Middle of the arc (from the ball's middle), its radius, start, length (radians).
		twigs.append([rng.randf() * TAU, rng.randf_range(0.5, 3.0), rng.randf_range(3.0, 5.5),
			rng.randf() * TAU, rng.randf_range(0.9, 1.9), i % 3])
	var tones := [Color(0.58, 0.44, 0.27), Color(0.42, 0.31, 0.19), Color(0.72, 0.59, 0.38)]
	var mid := (SIZE - 1) * 0.5
	var radius := SIZE * 0.5
	for f in FRAMES:
		var turn := f * TAU / FRAMES
		for t: Array in twigs:
			var c: Vector2 = Vector2(cos(t[0] + turn), sin(t[0] + turn)) * t[1]
			var steps := ceili(t[4] * t[2] * 2.0)
			for k in steps + 1:
				var a: float = t[3] + turn + t[4] * k / steps
				var p: Vector2 = Vector2(mid, mid) + c + Vector2(cos(a), sin(a)) * t[2]
				var px := roundi(p.x)
				var py := roundi(p.y)
				if Vector2(px - mid, py - mid).length() > radius - 0.2 or px < 0 or py < 0 or px >= SIZE or py >= SIZE:
					continue
				# The lower right of the ball is in its own shade.
				var shade: bool = (px - mid) + (py - mid) > 6.0
				img.set_pixel(f * SIZE + px, py, tones[1] if shade else tones[t[5]])
	return img


## Steps the balls by `delta` seconds: `on` when life in the air is shown outside,
## `wind` where it blows and how hard (Sky.wind_now).
func update(delta: float, on: bool, wind: Vector2) -> void:
	var player = game.player
	var world = game.world
	if player == null or world == null or game.view == null or _sheet == null:
		return
	var centre: Vector3 = player.position
	_look_in -= delta
	if _look_in <= 0.0:
		_look_in = LOOK_EVERY
		_want = wanted(world, centre) if on else 0
	var far := _far()
	var gone_at := far + EDGE * 2.0
	var shown := 0
	for b: Dictionary in _balls:
		if not b.on:
			continue
		if _roll(b, delta, wind, world) and Vector2(b.at.x - centre.x, b.at.z - centre.z).length() < gone_at:
			shown += 1
			_place(b)
		else:
			b.on = false
			b.node.visible = false
	_come_in -= delta
	if shown < _want and _come_in <= 0.0:
		_come_in = randf_range(COME_GAP.x, COME_GAP.y)
		_come(world, centre, wind, far)


## Lets `n` balls in at once on the screen round the player, not past its edge (the
## screenshots' `tumbleweeds`, tools/shot.gd).
func scatter(n: int, wind: Vector2) -> void:
	var player = game.player
	if player == null or game.world == null or _sheet == null:
		return
	var half := _far() - EDGE
	for i in n * 4:
		if n <= 0:
			break
		var spot := Vector2(player.position.x, player.position.z) + Vector2(randf_range(-0.6, 0.6), randf_range(-0.6, 0.6)) * half
		if _put(game.world, spot, wind):
			n -= 1


## How many tumbleweeds roll round world point `at`: the `tumbleweeds` of the biome
## there (0 off the open ground of one that has them).
static func wanted(world, at: Vector3) -> int:
	var b: int = world.biome_at(floori(at.x / CELL), floori(at.z / CELL))
	if b < 0 or b >= Biomes.RECORDS.size():
		return 0
	return int(Biomes.RECORDS[b].get("tumbleweeds", 0))


## Half the screen's larger side in world units, plus EDGE: where balls come in from.
func _far() -> float:
	var half := Vector2(game.view.viewport.size) / PixelView.PIXELS_PER_UNIT * 0.5
	return maxf(half.x, half.y) + EDGE


## Lets a ball in upwind of `centre`, past the edge of the screen, on open ground of a
## biome with tumbleweeds.
func _come(world, centre: Vector3, wind: Vector2, far: float) -> void:
	var dir := wind.normalized() if wind.length() > 0.01 else Vector2.RIGHT
	var side := Vector2(-dir.y, dir.x) * randf_range(-far, far)
	_put(world, Vector2(centre.x, centre.z) - dir * far + side, wind)


## Puts a ball on the ground at world point `spot` (x, z) if a biome with tumbleweeds is
## there; false if not.
func _put(world, spot: Vector2, wind: Vector2) -> bool:
	var ground := _ground(world, spot)
	if not is_finite(ground) or wanted(world, Vector3(spot.x, ground, spot.y)) <= 0:
		return false
	var b: Dictionary = {}
	for one: Dictionary in _balls:
		if not one.on:
			b = one
			break
	if b.is_empty():
		var m := MeshInstance3D.new()
		m.mesh = _mesh
		m.material_override = PlayerScript.sprite_material(SpriteShader, _sheet)
		m.layers = PixelView.LAYER_THINGS
		m.extra_cull_margin = 16.0
		add_child(m)
		b = {"node": m}
		_balls.append(b)
	b.on = true
	b.at = Vector3(spot.x, ground, spot.y)
	b.vel = wind.normalized() * PACE if wind.length() > 0.01 else Vector2.ZERO
	b.vy = 0.0
	b.roll = randf() * TAU
	b.pace = randf_range(0.7, 1.25)
	b.stuck = 0.0
	b.node.scale = Vector3.ONE * randf_range(0.8, 1.15)
	b.node.visible = true
	_place(b)
	return true


## Rolls ball `b` on for `delta` seconds with `wind`; false when it is gone (off the
## ground the world keeps, into water, or stuck too long against a wall).
func _roll(b: Dictionary, delta: float, wind: Vector2, world) -> bool:
	var speed: float = (PACE + PACE_PER_WIND * wind.length()) * b.pace
	var want: Vector2 = wind.normalized() * speed if wind.length() > 0.01 else Vector2.ZERO
	b.vel = b.vel.lerp(want, minf(1.0, TAKE_UP * delta))
	var at: Vector3 = b.at
	var next: Vector2 = Vector2(at.x, at.z) + b.vel * delta
	var ground := _ground(world, next)
	if not is_finite(ground):
		return false
	var on_ground: bool = at.y <= _ground(world, Vector2(at.x, at.z)) + 0.01
	if ground > at.y + CLIMB * CELL:
		# A wall: it rests against it, rocking, and is let go after a while.
		b.vel *= -0.2
		b.stuck += delta
		if b.stuck > STUCK_MOST:
			return false
	else:
		at.x = next.x
		at.z = next.y
		if ground > at.y and on_ground:
			# Up a rise of a cell: a hop onto it.
			b.vy = maxf(b.vy, sqrt(2.0 * GRAVITY * (ground - at.y + 0.05)))
	if on_ground and b.vy <= 0.0 and randf() < HOP_CHANCE * delta * clampf(b.vel.length(), 0.0, 2.0):
		b.vy = randf_range(HOP.x, HOP.y) * clampf(b.vel.length() * 0.6, 0.4, 1.0)
	b.vy -= GRAVITY * delta
	at.y += b.vy * delta
	if at.y <= ground:
		at.y = ground
		b.vy = -b.vy * BOUNCE if b.vy < -1.5 else 0.0
	b.at = at
	# It turns as far as it rolls along the ground, the way it goes on the screen.
	var s := PixelView.screen_dir(b.vel * delta)
	b.roll += s.x / (SIZE * 0.5 / PixelView.PIXELS_PER_UNIT * b.node.scale.x)
	return true


## The top of the ground under world point `p` (x, z), in world units (WorldData
## ground_height: up and down slopes); NAN where the world keeps no chunk and over water.
static func _ground(world, p: Vector2) -> float:
	var x := p.x / CELL
	var z := p.y / CELL
	if world.chunk_at(floori(x), floori(z)) == null:
		return NAN
	var top: float = world.ground_height(x, z)
	if world.get_cell(floori(x), floori(top - 0.01), floori(z)) == Mat.WATER:
		return NAN
	return top * CELL


## Puts ball `b`'s picture where it is, the frame of its turn.
func _place(b: Dictionary) -> void:
	var m: MeshInstance3D = b.node
	m.position = PixelView.snap(b.at)
	var f := posmod(int(floorf(b.roll / TAU * FRAMES)), FRAMES)
	(m.material_override as ShaderMaterial).set_shader_parameter("frame_uv", Vector4(float(f) / FRAMES, 0.0, 1.0 / FRAMES, 1.0))
