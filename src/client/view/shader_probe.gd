extends Node
## «Проверка шейдеров» (settings, tab «Отладка» of the developer mode): draws the game's
## 3D shaders one at a time in a small hidden view, from the engine's own material to
## each of shaders/*.gdshader, with and without lights, to find the one a phone's
## graphics driver crashes on (an Adreno 840 crashed the app in the warm-up, 2026-11-12,
## where the browser on the same phone draws fine). A crash ends the app, so each step is
## written to FILE before it is drawn: the next run marks it crashed and goes on with
## the steps not tried yet. report() lists them all, to copy and send.

const FILE := "user://shader_probe.cfg"
## Frames a step is shown: the first draw compiles its shaders.
const FRAMES := 3
## [name, mesh ("box" or "multi"), material ("unshaded", "standard", a shader's path or
## "minimal" / "stencil" code), lights ("none", "sun", "omni" = sun and an omni light,
## "shadow" = the sun's shadow, "shadow_omni" = both), what to cut from the shader's code ("" or "stencil")].
const STEPS := [
	["engine unshaded", "box", "unshaded", "none", ""],
	["engine standard", "box", "standard", "none", ""],
	["engine standard, sun", "box", "standard", "sun", ""],
	["engine standard, sun + omni", "box", "standard", "omni", ""],
	["engine standard, sun shadow", "box", "standard", "shadow", ""],
	["engine standard, many", "multi", "standard", "omni", ""],
	["minimal shader", "box", "minimal", "omni", ""],
	["minimal shader + stencil", "box", "stencil", "omni", ""],
	["world, no lights", "box", "res://shaders/world.gdshader", "none", ""],
	["world, no lights, no stencil", "box", "res://shaders/world.gdshader", "none", "stencil"],
	["world", "box", "res://shaders/world.gdshader", "omni", ""],
	["world, many", "multi", "res://shaders/world.gdshader", "omni", ""],
	["leaves", "box", "res://shaders/leaves.gdshader", "omni", ""],
	["grass", "box", "res://shaders/grass.gdshader", "omni", ""],
	["leaves, no stencil", "box", "res://shaders/leaves.gdshader", "omni", "stencil"],
	["grass, no stencil", "box", "res://shaders/grass.gdshader", "omni", "stencil"],
	["world, no lights, again", "box", "res://shaders/world.gdshader", "none", ""],
	["leaves, again", "box", "res://shaders/leaves.gdshader", "omni", ""],
	["sprite", "box", "res://shaders/sprite.gdshader", "omni", ""],
	["sprite_xray", "box", "res://shaders/sprite_xray.gdshader", "omni", ""],
	["sprite_water", "box", "res://shaders/sprite_water.gdshader", "omni", ""],
	["water", "box", "res://shaders/water.gdshader", "omni", ""],
	["land", "box", "res://shaders/land.gdshader", "omni", ""],
	["track", "multi", "res://shaders/track.gdshader", "omni", ""],
	["particle", "box", "res://shaders/particle.gdshader", "omni", ""],
	["fire_shadow", "box", "res://shaders/fire_shadow.gdshader", "omni", ""],
	["leaf_shadow", "box", "res://shaders/leaf_shadow.gdshader", "omni", ""],
	["sun_rays", "box", "res://shaders/sun_rays.gdshader", "omni", ""],
	["fishing_line", "box", "res://shaders/fishing_line.gdshader", "omni", ""],
	["cursor", "box", "res://shaders/cursor.gdshader", "omni", ""],
	# As the game draws them on Android since 2026-11-12 (no stencil), under the sun's
	# shadow, which builds each shader's depth pass too: the warm-up still crashed there.
	["world, many, no stencil", "multi", "res://shaders/world.gdshader", "omni", "stencil"],
	["world, sun shadow, no stencil", "box", "res://shaders/world.gdshader", "shadow", "stencil"],
	["world, sun shadow + omni, no stencil", "box", "res://shaders/world.gdshader", "shadow_omni", "stencil"],
	["world, many, sun shadow, no stencil", "multi", "res://shaders/world.gdshader", "shadow_omni", "stencil"],
	["leaves, sun shadow, no stencil", "box", "res://shaders/leaves.gdshader", "shadow_omni", "stencil"],
	["grass, sun shadow, no stencil", "box", "res://shaders/grass.gdshader", "shadow_omni", "stencil"],
	["sprite, sun shadow", "box", "res://shaders/sprite.gdshader", "shadow_omni", ""],
	["minimal shader, sun shadow", "box", "minimal", "shadow", ""],
	["engine standard, many, sun shadow", "multi", "standard", "shadow_omni", ""],
]
const MINIMAL := "shader_type spatial;\nvoid fragment() { ALBEDO = vec3(0.5); }\n"
const STENCIL := "shader_type spatial;\nstencil_mode write, compare_always, 1;\nvoid fragment() { ALBEDO = vec3(0.5); }\n"

## Called after each step, and when every step was tried.
signal stepped
signal finished

var _view: SubViewport
var _sun: DirectionalLight3D
var _omni: OmniLight3D
var _thing: GeometryInstance3D
var _step := -1
var _frames := 0


## The steps' results so far: name → "ok" or "crashed"; a step started and not ended
## (the app died on it) counts as crashed.
static func results() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(FILE) != OK:
		return {}
	var out: Dictionary = cfg.get_value("probe", "results", {})
	var current := str(cfg.get_value("probe", "current", ""))
	if current != "":
		out[current] = "crashed"
	return out


static func _save(res: Dictionary, current: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("probe", "results", res)
	cfg.set_value("probe", "current", current)
	cfg.save(FILE)


## Every step and how it went, a line each, with the device: the text to send.
static func report() -> String:
	var res := results()
	var lines := ["Shader probe: %s, %s" % [OS.get_name(), RenderingServer.get_video_adapter_name()]]
	for s: Array in STEPS:
		lines.append("%s: %s" % [s[0], res.get(s[0], "not tried")])
	return "\n".join(lines)


## Forgets the results.
static func clear() -> void:
	DirAccess.remove_absolute(FILE)


func _ready() -> void:
	var res := results()
	_save(res, "")
	_view = SubViewport.new()
	_view.size = Vector2i(64, 64)
	_view.own_world_3d = true
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_view)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.0
	_view.add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 10.0, 0.01), Vector3.ZERO)
	camera.current = true
	_sun = DirectionalLight3D.new()
	_view.add_child(_sun)
	_sun.look_at_from_position(Vector3(1.0, 10.0, 1.0), Vector3.ZERO)
	_omni = OmniLight3D.new()
	_omni.omni_range = 20.0
	_omni.position = Vector3(0.0, 3.0, 0.0)
	_view.add_child(_omni)
	_next()


func _process(_delta: float) -> void:
	if _step < 0:
		return
	_frames += 1
	if _frames < FRAMES:
		return
	var res := results()
	res[STEPS[_step][0]] = "ok"
	_save(res, "")
	print("shader probe: %s ok" % STEPS[_step][0])
	stepped.emit()
	_next()


## Shows the next step not tried yet, written down first; ends when none is left.
func _next() -> void:
	if _thing != null:
		_thing.queue_free()
		_thing = null
	var res := results()
	_step += 1
	while _step < STEPS.size() and res.has(STEPS[_step][0]):
		_step += 1
	if _step >= STEPS.size():
		_step = -1
		print("shader probe: done")
		finished.emit()
		queue_free()
		return
	var s: Array = STEPS[_step]
	_save(res, s[0])
	print("shader probe: %s ..." % s[0])
	_sun.visible = s[3] != "none"
	_sun.shadow_enabled = s[3].begins_with("shadow")
	_omni.visible = s[3] == "omni" or s[3] == "shadow_omni"
	_thing = _make(s[1], _material(s[2], s[4]))
	_view.add_child(_thing)
	_frames = 0


static func _material(what: String, cut: String) -> Material:
	if what == "unshaded" or what == "standard":
		var m := StandardMaterial3D.new()
		if what == "unshaded":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		return m
	var shader := Shader.new()
	if what == "minimal":
		shader.code = MINIMAL
	elif what == "stencil":
		shader.code = STENCIL
	else:
		var code: String = (load(what) as Shader).code
		if cut == "stencil":
			var at := code.find("stencil_mode")
			if at >= 0:
				code = code.substr(0, at) + "//" + code.substr(at)
		shader.code = code
	var sm := ShaderMaterial.new()
	sm.shader = shader
	return sm


static func _make(mesh: String, material: Material) -> GeometryInstance3D:
	var box := BoxMesh.new()
	if mesh == "multi":
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = box
		mm.instance_count = 1
		mm.set_instance_color(0, Color.WHITE)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = material
		mmi.extra_cull_margin = 16384.0
		return mmi
	var mi := MeshInstance3D.new()
	mi.mesh = box
	mi.material_override = material
	mi.extra_cull_margin = 16384.0
	return mi
