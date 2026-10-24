extends RefCounted
## The first time a thing is drawn under lights it was not drawn under before (the
## torch at dusk, the shadow of the nearest fire, a moonless night with no sun at all),
## the renderer builds the shaders for it, and on a phone that stops the game for 100 ms
## or more (2026-10-24; under software GL the first night took 10 s). So when the world
## is ready, a small view no one sees draws one of each kind of thing in the world under
## every mix of those lights, a frame each, and the shaders are built while the game
## starts rather than at the first dusk.

const MeshBuffers := preload("res://src/client/world/mesh_buffers.gd")

## The mixes of lights: [the sun, a light without a shadow (the torch, the far fires),
## a light with a shadow (the nearest fire)]. The sun goes out when its energy is 0, at
## dusk and on a moonless night.
const MIXES := [
	[true, true, true], [true, false, true], [true, true, false],
	[false, true, true], [false, false, true], [false, true, false], [false, false, false],
]
## How far apart the copies stand, in world units, and the lights' reach over them all.
const SPACING := 4.0
const REACH := 64.0

var game
var viewport: SubViewport
var sun: DirectionalLight3D
var lamp: OmniLight3D
var fire: OmniLight3D
var frames := 0


func _init(g) -> void:
	game = g


## Builds the hidden view in a world of its own, with a copy of one thing of each kind
## found under the main view (the same mesh and material, so the same shaders).
func start() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(64, 64)
	viewport.own_world_3d = true
	viewport.msaa_3d = game.view.viewport.msaa_3d
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	game.view.world_root.add_child(viewport)
	var kinds := {}
	_collect(game.view.world_root, kinds)
	# What may not be around yet: the ground's, water's and the low things' material on a
	# face like the chunks have.
	for mat: Material in [game.world_mat, game.low_mat, game.water_mat]:
		var b := MeshBuffers.new()
		b.quad([Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)], Vector3.UP,
			[Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)], Color.WHITE, Vector2.ZERO)
		var face := MeshInstance3D.new()
		face.mesh = b.to_mesh()
		face.material_override = mat
		var key := _key(face)
		if not kinds.has(key):
			kinds[key] = face
	var side := ceili(sqrt(kinds.size()))
	var i := 0
	for copy: GeometryInstance3D in kinds.values():
		copy.extra_cull_margin = 16384.0
		viewport.add_child(copy)
		copy.position = Vector3((i % side) * SPACING, 0.0, (i / side) * SPACING)
		i += 1
	var middle := Vector3(side, 0.0, side) * SPACING * 0.5
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = side * SPACING + 8.0
	camera.near = 1.0
	camera.far = 200.0
	camera.environment = game.sky.env
	viewport.add_child(camera)
	camera.look_at_from_position(middle + Vector3(0.0, 100.0, 0.01), middle)
	camera.current = true
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = game.sky.sun.shadow_enabled
	sun.directional_shadow_mode = game.sky.sun.directional_shadow_mode
	viewport.add_child(sun)
	sun.look_at_from_position(middle + Vector3(1.0, 10.0, 1.0), middle)
	lamp = _light(middle + Vector3(-2.0, 3.0, 0.0), false)
	fire = _light(middle + Vector3(2.0, 3.0, 0.0), true)
	_mix(0)


func _light(at: Vector3, shadow: bool) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.omni_range = REACH
	light.omni_attenuation = 0.0
	light.shadow_enabled = shadow
	viewport.add_child(light)
	light.position = at
	return light


func _mix(i: int) -> void:
	var m: Array = MIXES[i]
	sun.visible = m[0]
	lamp.visible = m[1]
	fire.visible = m[2]


## A copy of each thing under `node` that differs from the ones in `kinds` in what
## picks its shaders: how it is drawn (a mesh, many instances, with colours or custom
## data) and its materials.
func _collect(node: Node, kinds: Dictionary) -> void:
	for child in node.get_children():
		if child == viewport:
			continue
		if child is MeshInstance3D and child.mesh != null:
			var mi: MeshInstance3D = child
			var key := _key(mi)
			if not kinds.has(key):
				var copy := MeshInstance3D.new()
				copy.mesh = mi.mesh
				copy.material_override = mi.material_override
				for s in mi.get_surface_override_material_count():
					copy.set_surface_override_material(s, mi.get_surface_override_material(s))
				copy.cast_shadow = mi.cast_shadow
				kinds[key] = copy
		elif child is MultiMeshInstance3D and child.multimesh != null and child.multimesh.mesh != null:
			var mmi: MultiMeshInstance3D = child
			var mm := mmi.multimesh
			var key := ["multimesh", mmi.material_override, mm.mesh, mm.use_colors, mm.use_custom_data, mm.transform_format]
			if not kinds.has(key):
				var copy := MultiMeshInstance3D.new()
				var one := MultiMesh.new()
				one.transform_format = mm.transform_format
				one.use_colors = mm.use_colors
				one.use_custom_data = mm.use_custom_data
				one.mesh = mm.mesh
				one.instance_count = 1
				if mm.use_colors:
					one.set_instance_color(0, Color.WHITE)
				copy.multimesh = one
				copy.material_override = mmi.material_override
				copy.cast_shadow = mmi.cast_shadow
				kinds[key] = copy
		_collect(child, kinds)


func _key(mi: MeshInstance3D) -> Array:
	var key := ["mesh", mi.material_override, mi.mesh.get_surface_count()]
	for s in mi.mesh.get_surface_count():
		key.append(mi.get_active_material(s))
		key.append(mi.mesh.surface_get_format(s) if mi.mesh is ArrayMesh else 0)
	return key


## Called every frame; true once every mix was drawn and the hidden view is gone.
func step() -> bool:
	frames += 1
	if frames < MIXES.size():
		_mix(frames)
		return false
	viewport.queue_free()
	return true
