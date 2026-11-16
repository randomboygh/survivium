extends RefCounted
## The fog over the edge of the world built (setting «Туман на краю», on by default; user
## 2026-11-16, before a haze of the sky's colour): where the player outran the building of
## the chunks (ChunkStreamer) or jumped far, the chunks on the screen with no ground yet are
## covered by a dense white fog (no clouds over it, user 2026-11-16), instead of the empty
## background; it thins out over the built chunks beside them, and once a chunk is built its
## fog dissolves over DISSOLVE seconds (shaders/edge_fog.gdshader). How much fog each chunk
## has is a texel of a small texture round the player (GRID chunks a side), written only while
## something changes. The fog lies on the land itself (user 2026-11-16: it lay at the
## player's height, so land drawn higher or lower and a jump showed the background): each
## chunk under it has a top at its ground's height (from the cells the server sent, else
## from its neighbours', else the player's), joined to its neighbours by walls, so the steps
## cover the screen where that land is drawn. `game` is the Main node.

const FogShader := preload("res://shaders/edge_fog.gdshader")
const WorldData := preload("res://src/shared/world/world_data.gd")
const PixelView := preload("res://src/client/view/pixel_view.gd")

const CHUNK := WorldData.CHUNK
const CELL := WorldData.CELL
## How far past a missing chunk's edge the screen counts it, in world units (the fog
## reaches into the built ones beside it).
const FADE := 3.0
## Seconds a built chunk's fog takes to dissolve.
const DISSOLVE := 1.2
## The chunks a side of the texture of the fog's amounts, round the player.
const GRID := 32
## The fog's light by day, and how much of it is kept at night (the rest the background).
const FOG_COLOR := Color(0.97, 0.98, 1.0)
const NIGHT_KEEP := 0.3
## How far (world units) the player goes before the chunks on the screen are looked over
## again with nothing else changed: a chunk's edge that far into the screen is within the
## FADE the test on the screen allows round it.
const LOOK_AGAIN := 0.5
## How many chunks past those the screen holds at the player's height are looked at: land
## lower than the player is drawn higher up the screen.
const DEEP_RING := 4
## How many rings round a chunk with no cells yet are looked at for its land's height.
const GUESS_RINGS := 6
## Seconds between looks at the heights of the land under the fog while nothing else
## changes (the cells of a chunk not built may arrive meanwhile).
const HEIGHTS_EVERY := 0.3

var game
var node: MeshInstance3D
var material: ShaderMaterial
## How much fog each chunk has, 0..1 (missing ones 1, built ones dissolving), by chunk.
var amounts := {}
## The chunks missing on the screen at the last look (see update).
var _missing: Array[Vector2i] = []
var _image: Image
var _texture: ImageTexture
## The texture's corner chunk, the quad's chunks and the level it lies at.
var _origin := Vector2i(1 << 30, 0)
var _quad := Rect2i()
var _level := 1 << 30
## The heights (world y) of the chunks under the fog, by chunk: `_known` from their
## cells (kept), `_heights` those the mesh was last built with.
var _known := {}
var _heights := {}
var _heights_ms := -1
## What the last look over the chunks went by (see update): the changes of the chunks
## built, where the player stood, the screen's half size; the colour last set; the time.
var _looked_changes := -1
var _looked_at := Vector2.INF  # the screen's middle
var _looked_half := Vector2.ZERO
var _color := Color(0, 0, 0, 0)
var _last_ms := -1


func _init(g) -> void:
	game = g
	material = ShaderMaterial.new()
	material.shader = FogShader
	# Under the cursor and the borders of the land, over the world.
	material.render_priority = -1
	_image = Image.create(GRID, GRID, false, Image.FORMAT_L8)
	_texture = ImageTexture.create_from_image(_image)
	material.set_shader_parameter("amounts", _texture)
	material.set_shader_parameter("span", float(GRID * CHUNK) * CELL)
	node = MeshInstance3D.new()
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Laid over chunks anywhere on the screen and moved up it by the shear.
	node.extra_cull_margin = 64.0
	node.visible = false
	game.world_root.add_child(node)


func free_node() -> void:
	if is_instance_valid(node):
		node.queue_free()


## Covers the chunks on the screen around `at` (world units x, z; `half` the screen's
## half size, see ChunkStreamer._screen_half) that `built` has no nodes for, at height
## `y`, and dissolves the fog of those built since; the colour follows the sky. `changes`
## counts the changes of `built` (ChunkStreamer.nodes_changes, -1: unknown): while it, the
## screen and the level stay and the player is within LOOK_AGAIN of where the chunks were
## last looked over, they are not looked over (it ran every frame, 2026-11-14 audit WA-036).
func update(built: Dictionary, at: Vector2, half: Vector2, y: float, changes := -1) -> void:
	var now := Time.get_ticks_msec()
	var delta := clampf((now - _last_ms) / 1000.0, 0.0, 0.25) if _last_ms >= 0 else 0.0
	_last_ms = now
	var color := fog_color()
	if color != _color:
		_color = color
		material.set_shader_parameter("color", color)
	var level := floori(y / CELL)
	var middle := screen_middle(Vector3(at.x, y, at.y))
	if not (changes >= 0 and changes == _looked_changes and half == _looked_half and level == _level \
			and middle.distance_squared_to(_looked_at) < LOOK_AGAIN * LOOK_AGAIN):
		_looked_changes = changes
		_looked_at = middle
		_looked_half = half
		_missing = missing_on_screen(built, Vector3(at.x, y, at.y), middle, half)
	if _missing.is_empty() and amounts.is_empty():
		node.visible = false
		return
	var changed := step(amounts, _missing, delta)
	var home := Vector2i((at / (CHUNK * CELL)).floor())
	if absi(home.x - (_origin.x + GRID / 2)) > GRID / 4 or absi(home.y - (_origin.y + GRID / 2)) > GRID / 4:
		_origin = home - Vector2i(GRID / 2, GRID / 2)
		material.set_shader_parameter("origin", Vector2(_origin) * (CHUNK * CELL))
		changed = true
	if changed:
		_paint()
	var quad := cover(amounts.keys())
	if quad != _quad or level != _level or now - _heights_ms >= HEIGHTS_EVERY * 1000.0:
		_heights_ms = now
		var heights := heights_under(quad, level * CELL)
		if quad != _quad or heights != _heights:
			_quad = quad
			_heights = heights
			node.mesh = build_mesh(quad, heights) if quad.has_area() else null
		_level = level
	node.visible = not amounts.is_empty()


## Where the middle of the screen is (PixelView.screen_plane): the camera's, which trails
## the player on a fall or a jump; `at` (the player) without one.
func screen_middle(at: Vector3) -> Vector2:
	var view = game.view
	if view == null or view.camera == null:
		return PixelView.screen_plane(at)
	var c: Vector3 = view.camera.global_position
	return PixelView.plane_of(Vector2(c.x, c.z))


## The chunks round `at` (the player, world units) whose land, at its height
## (height_of), is drawn on the screen (`middle`, `half`) and that `built` has no nodes for.
func missing_on_screen(built: Dictionary, at: Vector3, middle: Vector2, half: Vector2) -> Array[Vector2i]:
	var size := CHUNK * CELL
	var home := Vector2i((Vector2(at.x, at.z) / size).floor())
	var r := ceili(half.length() / size) + 1 + DEEP_RING
	var out: Array[Vector2i] = []
	for cz in range(home.y - r, home.y + r + 1):
		for cx in range(home.x - r, home.x + r + 1):
			var key := Vector2i(cx, cz)
			if not built.has(key) and on_screen(key, height_of(key, at.y), middle, half):
				out.append(key)
	return out


## Moves the fog of the chunks in `amounts` on by `delta` seconds: the `missing` ones whole
## at once (a hole is never seen), the others dissolving over DISSOLVE and dropped at 0.
## True when something changed.
static func step(amounts: Dictionary, missing: Array[Vector2i], delta: float) -> bool:
	var changed := false
	var keep := {}
	for k in missing:
		keep[k] = true
		if amounts.get(k, 0.0) < 1.0:
			amounts[k] = 1.0
			changed = true
	for k: Vector2i in amounts.keys():
		if keep.has(k):
			continue
		var a: float = amounts[k] - delta / DISSOLVE
		changed = changed or delta > 0.0
		if a <= 0.0:
			amounts.erase(k)
		else:
			amounts[k] = a
	return changed


## The chunks the quad covers: those with fog and one round them (the fog thins into it).
static func cover(keys: Array) -> Rect2i:
	if keys.is_empty():
		return Rect2i()
	var r := Rect2i(keys[0], Vector2i.ONE)
	for k: Vector2i in keys:
		r = r.merge(Rect2i(k, Vector2i.ONE))
	return r.grow(1)


## The heights (world y) of the ground of the chunks in `r` (height_of).
func heights_under(r: Rect2i, fallback: float) -> Dictionary:
	if _known.size() > GRID * GRID * 4:
		_known.clear()
	var out := {}
	for cz in range(r.position.y, r.end.y):
		for cx in range(r.position.x, r.end.x):
			var key := Vector2i(cx, cz)
			out[key] = height_of(key, fallback)
	return out


## The height (world y) of the ground of chunk `key`: of a chunk whose cells are here, the
## highest of a few columns (kept); of one not here yet, the mean of the nearest ring round it
## (up to GUESS_RINGS) with chunks that are, else `fallback` (the player's): after a far
## jump the cells come from the middle out, and the land round is about as high.
func height_of(key: Vector2i, fallback: float) -> float:
	var h := _known_height(key)
	if not is_nan(h):
		return h
	for ring in range(1, GUESS_RINGS + 1):
		var sum := 0.0
		var n := 0
		for dz in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dz)) != ring:
					continue
				var k := _known_height(key + Vector2i(dx, dz))
				if not is_nan(k):
					sum += k
					n += 1
		if n > 0:
			return sum / n
	return fallback


func _known_height(key: Vector2i) -> float:
	if _known.has(key):
		return _known[key]
	var h := ground_of(key)
	if not is_nan(h):
		_known[key] = h
	return h


## The ground's height (world y) of chunk `key` from its cells, NAN when they are not here:
## the highest of 16 columns, so the fog over it hides its land as it dissolves.
func ground_of(key: Vector2i) -> float:
	var world = game.world
	if world == null or world.chunk_at(key.x * CHUNK, key.y * CHUNK) == null:
		return NAN
	var top := -INF
	for i in 4:
		for j in 4:
			var h: float = world.ground_height(key.x * CHUNK + 2.0 + i * 4.0, key.y * CHUNK + 2.0 + j * 4.0)
			top = maxf(top, h if h >= 0.0 else float(world.sea_level + 1))
	return top * CELL


## The fog's mesh over chunks `r`: a top over each at its height in `heights` (world y, by
## chunk; missing ones at 0) and a wall between two side by side at different heights.
static func build_mesh(r: Rect2i, heights: Dictionary) -> ArrayMesh:
	var size := CHUNK * CELL
	var verts := PackedVector3Array()
	for cz in range(r.position.y, r.end.y):
		for cx in range(r.position.x, r.end.x):
			var key := Vector2i(cx, cz)
			var y: float = heights.get(key, 0.0)
			var x0 := cx * size
			var z0 := cz * size
			var x1 := x0 + size
			var z1 := z0 + size
			for c: Vector2 in [Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z0), Vector2(x1, z1), Vector2(x0, z1)]:
				verts.append(Vector3(c.x, y, c.y))
			if cx + 1 < r.end.x:
				_wall(verts, Vector2(x1, z0), Vector2(x1, z1), y, heights.get(key + Vector2i(1, 0), 0.0))
			if cz + 1 < r.end.y:
				_wall(verts, Vector2(x0, z1), Vector2(x1, z1), y, heights.get(key + Vector2i(0, 1), 0.0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _wall(verts: PackedVector3Array, a: Vector2, b: Vector2, y0: float, y1: float) -> void:
	if is_equal_approx(y0, y1):
		return
	var lo := minf(y0, y1)
	var hi := maxf(y0, y1)
	for c: Vector3 in [Vector3(a.x, lo, a.y), Vector3(b.x, lo, b.y), Vector3(b.x, hi, b.y), Vector3(a.x, lo, a.y), Vector3(b.x, hi, b.y), Vector3(a.x, hi, a.y)]:
		verts.append(c)


## Writes the amounts into the texture (GRID² bytes, a few times a second at most while
## the fog moves).
func _paint() -> void:
	_image.fill(Color.BLACK)
	for k: Vector2i in amounts:
		var p := k - _origin
		if p.x >= 0 and p.y >= 0 and p.x < GRID and p.y < GRID:
			_image.set_pixel(p.x, p.y, Color(amounts[k], amounts[k], amounts[k]))
	_texture.update(_image)


## The fog's light now: white by day, towards the background the empty world shows at night.
func fog_color() -> Color:
	var sky = game.sky
	if sky == null or sky.env == null:
		return FOG_COLOR
	var bg: Color = sky.env.background_color
	return bg.lerp(FOG_COLOR, NIGHT_KEEP + (1.0 - NIGHT_KEEP) * clampf(sky.sky_light, 0.0, 1.0))


## Whether chunk `key`, its land at height `y`, is drawn on the screen whose middle is
## `middle` (PixelView.screen_plane) and half size `half`, or within FADE of it.
static func on_screen(key: Vector2i, y: float, middle: Vector2, half: Vector2) -> bool:
	var size := CHUNK * CELL
	var lo := Vector2.INF
	var hi := -Vector2.INF
	for c: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var p := PixelView.screen_plane(Vector3((key.x + c.x) * size, y, (key.y + c.y) * size)) - middle
		lo = lo.min(p)
		hi = hi.max(p)
	return lo.x - FADE <= half.x and hi.x + FADE >= -half.x and lo.y - FADE <= half.y and hi.y + FADE >= -half.y
