extends Node3D
## Sunlight among the trees by day (the «Солнечные лучи» setting): shafts of light
## that come down past the edges of the crowns along the sun's way to the ground, the
## sun's flecks that shimmer on the ground in the crowns' shadows, and specks of dust
## glinting in the shafts. Each tree near the player gets a few of each, placed from
## its column (the same every time); every tree whose light can reach the picture gets
## them, the nearest first, laid out again when the player has moved MOVE world units,
## the sun or the camera has turned or the trees have changed; the shaders
## (sun_rays.gdshader) draw them. Sky tells how strong and what colour they are and
## where the sun is (see Sky._update_rays). `game` is the Main node.

const PixelView := preload("res://src/client/view/pixel_view.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const Mat := preload("res://src/shared/content/materials.gd")
const SunRaysShader := preload("res://shaders/sun_rays.gdshader")
const ParticleShader := preload("res://shaders/particle.gdshader")

const CELL := WorldData.CELL
## How far past the picture's edges, in world units, a tree is looked for: its crown
## and shafts reach into the picture from there.
const REACH := 12.0
## The farthest from the player a tree is looked for, in world units.
const FARTHEST := 40.0
## The player moves this far, in world units, before the light is laid out again.
const MOVE := 2.0
## The sun turns this much (the dot of its old and new way, 1 - it) before the light
## is laid out again.
const TURN := 0.0004
## How far a shaft leans from straight down at most, sideways a unit down.
const LEAN := 0.7
const MAX_SHAFTS := 256
const MAX_FLECKS := 512
## Shafts and flecks a tree gets at most.
const SHAFTS := 3
const FLECKS := 8
## Levels a crown is looked for above the foot of its trunk.
const CROWN_LEVELS := 24
## Columns from the trunk a crown is looked for at the middle of its height.
const CROWN_REACH := 8
## The crowns found: {column: Vector3(foot, top, radius) in world units}.
const MAX_CROWNS := 4096

var game
## How strong the light is (0 none) and its colour, and the way to the sun.
var amount := 0.0
var color := Color(1.0, 0.95, 0.8)
var to_sun := Vector3.UP
var shafts: MultiMeshInstance3D
var flecks: MultiMeshInstance3D
var motes: CPUParticles3D
var _shaft_mat: ShaderMaterial
var _fleck_mat: ShaderMaterial
var _crowns := {}
## Where and for what sun the light was laid out last, and how many trees there were.
var _laid_at := Vector3.INF
var _laid_sun := Vector3.ZERO
var _laid_trees := -1
var _laid_view := []


func _ready() -> void:
	_shaft_mat = _material(0)
	_fleck_mat = _material(1)
	shafts = _instances(MAX_SHAFTS, _shaft_mat)
	flecks = _instances(MAX_FLECKS, _fleck_mat)
	motes = CPUParticles3D.new()
	motes.amount = 48
	motes.lifetime = 5.0
	motes.local_coords = false
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	motes.emission_points = PackedVector3Array([Vector3.ZERO])
	motes.direction = Vector3.UP
	motes.spread = 180.0
	motes.initial_velocity_min = 0.02
	motes.initial_velocity_max = 0.08
	motes.gravity = Vector3(0.0, -0.01, 0.0)
	motes.color_ramp = Gradient.new()
	motes.color_ramp.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	motes.color_ramp.colors = PackedColorArray([Color(1, 0.95, 0.8, 0), Color(1, 0.95, 0.8, 1), Color(1, 0.9, 0.7, 1), Color(1, 0.9, 0.7, 0)])
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE / PixelView.PIXELS_PER_UNIT
	var m := ShaderMaterial.new()
	m.shader = ParticleShader
	m.set_shader_parameter("brightness", 1.3)
	quad.material = m
	motes.mesh = quad
	motes.extra_cull_margin = 32.0
	motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	motes.emitting = false
	add_child(motes)


func _material(mode: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SunRaysShader
	m.set_shader_parameter("mode", mode)
	return m


func _instances(count: int, mat: ShaderMaterial) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _quad()
	mm.instance_count = count
	mm.visible_instance_count = 0
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The shaders put each one where it falls in the view.
	node.extra_cull_margin = 16384.0
	add_child(node)
	return node


## A quad x -0.5..0.5, y 0..1, which the shader lays along a shaft or on the ground.
static func _quad() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-0.5, 0, 0), Vector3(0.5, 0, 0), Vector3(0.5, 1, 0), Vector3(-0.5, 1, 0)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 0, 3, 2])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _process(_delta: float) -> void:
	var on := amount > 0.0 and game != null and game.player != null and to_sun.y > 0.05
	shafts.visible = on
	flecks.visible = on
	if motes.emitting != on:
		motes.emitting = on
	if not on:
		return
	var down := _shaft_way()
	for m in [_shaft_mat, _fleck_mat]:
		m.set_shader_parameter("amount", amount)
		m.set_shader_parameter("light_color", color)
		m.set_shader_parameter("light_down", down)
	var p: Vector3 = game.player.position
	var near := _near(p)
	var count := _tree_count(near)
	var view := [PixelView.up, PixelView.squash, PixelView.slope, game.view.image_size]
	if p.distance_to(_laid_at) < MOVE and to_sun.dot(_laid_sun) > 1.0 - TURN and count == _laid_trees and view == _laid_view:
		return
	_laid_view = view
	_lay_out(p, near, count, down)


## The way the shafts run down: the sun's, but never leaning further than LEAN from
## straight down, so a low sun's shafts still fall among the trees instead of lying
## along the ground like its shadows.
func _shaft_way() -> Vector3:
	var flat := Vector2(-to_sun.x, -to_sun.z) / maxf(to_sun.y, 0.05)
	return Vector3(flat.x, -1.0, flat.y).normalized() if flat.length() <= LEAN \
		else Vector3(flat.normalized().x * LEAN, -1.0, flat.normalized().y * LEAN).normalized()


## The picture in screen-plane world units, grown by MOVE (the player walks that far
## before the light is laid out again), and how far from the player a tree whose
## light reaches it can stand: Rect2 and the distance.
func _near(p: Vector3) -> Array:
	var half: Vector2 = Vector2(game.view.image_size) / PixelView.PIXELS_PER_UNIT * 0.5 + Vector2.ONE * MOVE
	var picture := Rect2(PixelView.screen_plane(p) - half, half * 2.0)
	return [picture, minf(FARTHEST, half.length() / minf(PixelView.squash, 1.0) + REACH)]


## How many trees stand within the distance of `near` (see _near) of the player:
## counted by chunk, so a change shows.
func _tree_count(near: Array) -> int:
	var n := 0
	for key: Vector2i in _chunks(near[1]):
		n += game.world.tree_chunks.get(key, {}).size()
	return n


func _chunks(reach: float) -> Array:
	var p: Vector3 = game.player.position
	var c0 := Vector2i(floori((p.x - reach) / CELL) >> WorldData.SHIFT, floori((p.z - reach) / CELL) >> WorldData.SHIFT)
	var c1 := Vector2i(floori((p.x + reach) / CELL) >> WorldData.SHIFT, floori((p.z + reach) / CELL) >> WorldData.SHIFT)
	var out := []
	for kz in range(c0.y, c1.y + 1):
		for kx in range(c0.x, c1.x + 1):
			out.append(Vector2i(kx, kz))
	return out


## The trunk columns within the distance of `near`, nearest to the player first.
func _trees_near(p: Vector3, near: Array) -> Array:
	var reach: float = near[1]
	var out := []
	for key: Vector2i in _chunks(reach):
		for col: Vector2i in game.world.tree_chunks.get(key, {}):
			if Vector2((col.x + 0.5) * CELL - p.x, (col.y + 0.5) * CELL - p.z).length() < reach:
				out.append(col)
	var at := Vector2(p.x, p.z)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return at.distance_squared_to((Vector2(a) + Vector2.ONE * 0.5) * CELL) < at.distance_squared_to((Vector2(b) + Vector2.ONE * 0.5) * CELL))
	return out


func _lay_out(p: Vector3, near: Array, count: int, down: Vector3) -> void:
	_laid_at = p
	_laid_sun = to_sun
	_laid_trees = count
	var picture: Rect2 = near[0]
	var trees := _trees_near(p, near)
	var w = game.world
	var ns := 0
	var nf := 0
	var dust := PackedVector3Array()
	var sm: MultiMesh = shafts.multimesh
	var fm: MultiMesh = flecks.multimesh
	# Where the ground is along a shaft from a height h over it, and the shadow.
	var lean := Vector2(down.x, down.z) / -down.y
	var shadow := Vector2(-to_sun.x, -to_sun.z) / maxf(to_sun.y, 0.05)
	for col: Vector2i in trees:
		var crown := _crown(w, col)
		if crown.x <= -INF:
			continue
		var foot := crown.x
		var tall := crown.y - foot
		var r := crown.z
		var mid := Vector2((col.x + 0.5) * CELL, (col.y + 0.5) * CELL)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(col)
		# Each shaft and fleck draws all its numbers first, so the rest of the tree's
		# stay the same whether this one is in the picture or not.
		for i in SHAFTS:
			var skip := rng.randf() < 0.3
			# Just past the crown's edge, from high in it.
			var a := rng.randf() * TAU
			var at := mid + Vector2(cos(a), sin(a)) * r * rng.randf_range(0.95, 1.3)
			var h := tall * rng.randf_range(0.6, 0.85)
			var look := Color(rng.randf_range(0.35, 0.8), 0.0, rng.randf(), rng.randf_range(0.5, 1.0))
			var motes_at := Vector2(rng.randf_range(0.2, 0.8), rng.randf_range(0.2, 0.8))
			if skip or ns >= MAX_SHAFTS:
				continue
			var top := Vector3(at.x, foot + h, at.y)
			var ground := _ground(w, at + lean * h)
			if ground <= -INF or ground > top.y - 0.5:
				continue
			var bottom := top + down * ((top.y - ground) / -down.y)
			if not picture.intersects(Rect2(PixelView.screen_plane(top), Vector2.ZERO).expand(PixelView.screen_plane(bottom)).grow(1.0)):
				continue
			look.g = top.y - ground
			sm.set_instance_transform(ns, Transform3D(Basis(), top))
			sm.set_instance_color(ns, look)
			ns += 1
			for t: float in [motes_at.x, motes_at.y]:
				dust.append(top + down * (t * (top.y - ground) / -down.y))
		# The flecks in the crown's shadow on the ground.
		var shade := mid + shadow * (tall * 0.6)
		for i in FLECKS:
			var at := shade + Vector2.from_angle(rng.randf() * TAU) * r * sqrt(rng.randf()) * 0.85
			var look := Color(rng.randf_range(0.15, 0.3), 0.0, rng.randf(), rng.randf_range(0.6, 1.0))
			if nf >= MAX_FLECKS:
				break
			var ground := _ground(w, at)
			if ground <= -INF or not picture.has_point(PixelView.screen_plane(Vector3(at.x, ground, at.y))):
				continue
			fm.set_instance_transform(nf, Transform3D(Basis(), Vector3(at.x, ground, at.y)))
			fm.set_instance_color(nf, look)
			nf += 1
	sm.visible_instance_count = ns
	fm.visible_instance_count = nf
	if dust.is_empty():
		dust.append(Vector3(p.x, -1000.0, p.z))
	motes.emission_points = dust


## The height of the ground a walker stands on at world point `at`, -INF over water.
func _ground(w, at: Vector2) -> float:
	var h: float = w.ground_height(at.x / CELL, at.y / CELL)
	return h * CELL if h >= 0.0 else -INF


## The crown of the tree with its trunk in column `col`: Vector3(the foot of the trunk,
## the top of the crown, how far it reaches from the trunk) in world units, x -INF
## when no trunk is there; looked for once.
func _crown(w, col: Vector2i) -> Vector3:
	if _crowns.has(col):
		return _crowns[col]
	if _crowns.size() > MAX_CROWNS:
		_crowns.clear()
	var found := Vector3(-INF, 0.0, 0.0)
	# The column's top is the trunk's (crowns are left out): down it to the foot.
	var base := floori(w.ground_height(col.x + 0.5, col.y + 0.5))
	if w.get_cell(col.x, base - 1, col.y) != Mat.LOG:
		base = -1
	while base > 0 and w.get_cell(col.x, base - 1, col.y) == Mat.LOG:
		base -= 1
	if base >= 0:
		var top := base
		while top < base + CROWN_LEVELS and w.get_cell(col.x, top, col.y) != Mat.AIR:
			top += 1
		var middle := (base + top) / 2
		var reach := 1
		for d in range(1, CROWN_REACH):
			if w.get_cell(col.x + d, middle, col.y) == Mat.AIR and w.get_cell(col.x - d, middle, col.y) == Mat.AIR \
					and w.get_cell(col.x, middle, col.y + d) == Mat.AIR and w.get_cell(col.x, middle, col.y - d) == Mat.AIR:
				break
			reach = d + 1
		found = Vector3(base * CELL, top * CELL, reach * CELL)
	_crowns[col] = found
	return found
