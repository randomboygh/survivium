extends RefCounted
## The haze over the edge of the world built (setting «Дымка на краю», off by default):
## where the player outran the building of the chunks (ChunkStreamer), the chunks on the
## screen with no ground yet are covered by a haze in the colour of the sky's background
## instead of the empty background, and it thins out over FADE world units of the built
## chunks beside them, so the edge of the world is a mist, not a cut. One mesh of quads
## laid at the player's height (the shear draws them where ground at that height is
## drawn), built again only when the set of missing chunks or the player's level changes.
## `game` is the Main node.

const CursorShader := preload("res://shaders/cursor.gdshader")
const WorldData := preload("res://src/shared/world/world_data.gd")
const PixelView := preload("res://src/client/view/pixel_view.gd")

const CHUNK := WorldData.CHUNK
const CELL := WorldData.CELL
## How far the haze reaches over the built chunks beside a missing one, in world units.
const FADE := 3.0
## How much of the way from the background to a light mist the haze is by day.
const MIST := 0.55
const MIST_COLOR := Color(0.74, 0.79, 0.84)

var game
var node: MeshInstance3D
var material: ShaderMaterial
## The chunks the mesh covers now and the level it lies at (see update).
var _shown: Array[Vector2i] = []
var _level := 1 << 30


func _init(g) -> void:
	game = g
	material = ShaderMaterial.new()
	material.shader = CursorShader
	# Under the cursor and the borders of the land, over the world.
	material.render_priority = -1
	node = MeshInstance3D.new()
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Laid over chunks anywhere on the screen and moved up it by the shear.
	node.extra_cull_margin = 64.0
	game.world_root.add_child(node)


func free_node() -> void:
	if is_instance_valid(node):
		node.queue_free()


## Covers the chunks on the screen around `at` (world units x, z; `half` the screen's
## half size, see ChunkStreamer._screen_half) that `built` has no nodes for, at height
## `y`; the colour follows the sky.
func update(built: Dictionary, at: Vector2, half: Vector2, y: float) -> void:
	material.set_shader_parameter("color", haze_color())
	var size := CHUNK * CELL
	var home := Vector2i((at / size).floor())
	var reach := Vector2i(ceili(half.length() / size) + 1, ceili(half.length() / size) + 1)
	var missing: Array[Vector2i] = []
	for cz in range(home.y - reach.y, home.y + reach.y + 1):
		for cx in range(home.x - reach.x, home.x + reach.x + 1):
			var key := Vector2i(cx, cz)
			if not built.has(key) and _on_screen(key, at, half):
				missing.append(key)
	var level := floori(y / CELL)
	if missing == _shown and level == _level:
		return
	_shown = missing
	_level = level
	node.mesh = build_mesh(missing, level * CELL) if not missing.is_empty() else null


## The haze's colour now: the background the empty world shows, towards a light mist
## by day.
func haze_color() -> Color:
	var sky = game.sky
	if sky == null or sky.env == null:
		return MIST_COLOR
	var bg: Color = sky.env.background_color
	return bg.lerp(MIST_COLOR, MIST * clampf(sky.sky_light, 0.0, 1.0))


static func _on_screen(key: Vector2i, at: Vector2, half: Vector2) -> bool:
	var d := (Vector2(key) + Vector2(0.5, 0.5)) * (CHUNK * CELL) - at
	var r := CHUNK * CELL * 0.71 + FADE
	return absf(d.dot(PixelView.right)) - r <= half.x and absf(d.dot(PixelView.up)) - r <= half.y


## The mesh of the haze over chunks `keys` at height `y`: each chunk whole, and where a
## side or a corner borders a chunk not in `keys`, a strip or a corner fading out over
## FADE (vertex alpha 1 at the chunk, 0 at the far edge).
static func build_mesh(keys: Array[Vector2i], y: float) -> ArrayMesh:
	var inside := {}
	for k in keys:
		inside[k] = true
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var size := CHUNK * CELL
	for k in keys:
		var x0 := k.x * size
		var z0 := k.y * size
		var x1 := x0 + size
		var z1 := z0 + size
		_quad(verts, colors, y, [Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)], [1.0, 1.0, 1.0, 1.0])
		var n := not inside.has(k + Vector2i(0, -1))
		var s := not inside.has(k + Vector2i(0, 1))
		var w := not inside.has(k + Vector2i(-1, 0))
		var e := not inside.has(k + Vector2i(1, 0))
		if n:
			_quad(verts, colors, y, [Vector2(x0, z0 - FADE), Vector2(x1, z0 - FADE), Vector2(x1, z0), Vector2(x0, z0)], [0.0, 0.0, 1.0, 1.0])
		if s:
			_quad(verts, colors, y, [Vector2(x0, z1), Vector2(x1, z1), Vector2(x1, z1 + FADE), Vector2(x0, z1 + FADE)], [1.0, 1.0, 0.0, 0.0])
		if w:
			_quad(verts, colors, y, [Vector2(x0 - FADE, z0), Vector2(x0, z0), Vector2(x0, z1), Vector2(x0 - FADE, z1)], [0.0, 1.0, 1.0, 0.0])
		if e:
			_quad(verts, colors, y, [Vector2(x1, z0), Vector2(x1 + FADE, z0), Vector2(x1 + FADE, z1), Vector2(x1, z1)], [1.0, 0.0, 0.0, 1.0])
		# Corners where both sides fade: alpha 1 at the chunk's corner only.
		if n and w:
			_quad(verts, colors, y, [Vector2(x0 - FADE, z0 - FADE), Vector2(x0, z0 - FADE), Vector2(x0, z0), Vector2(x0 - FADE, z0)], [0.0, 0.0, 1.0, 0.0])
		if n and e:
			_quad(verts, colors, y, [Vector2(x1, z0 - FADE), Vector2(x1 + FADE, z0 - FADE), Vector2(x1 + FADE, z0), Vector2(x1, z0)], [0.0, 0.0, 0.0, 1.0])
		if s and e:
			_quad(verts, colors, y, [Vector2(x1, z1), Vector2(x1 + FADE, z1), Vector2(x1 + FADE, z1 + FADE), Vector2(x1, z1 + FADE)], [1.0, 0.0, 0.0, 0.0])
		if s and w:
			_quad(verts, colors, y, [Vector2(x0 - FADE, z1), Vector2(x0, z1), Vector2(x0, z1 + FADE), Vector2(x0 - FADE, z1 + FADE)], [0.0, 1.0, 0.0, 0.0])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Two triangles of the quad with corners `p` (x, z; north-west, north-east, south-east,
## south-west) and their alphas `a`, wound clockwise seen from above.
static func _quad(verts: PackedVector3Array, colors: PackedColorArray, y: float, p: Array, a: Array) -> void:
	for i: int in [0, 1, 2, 0, 2, 3]:
		var c: Vector2 = p[i]
		verts.append(Vector3(c.x, y, c.y))
		colors.append(Color(1.0, 1.0, 1.0, a[i]))
