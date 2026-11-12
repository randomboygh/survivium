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
## "minimal" / "stencil" / "include" / "world_coords" code or a key of CODES), lights ("none", "sun", "omni" = sun and an omni light,
## "shadow" = the sun's shadow, "shadow_omni" = both; "sun" = the sun alone), what to cut
## from the shader's code (a list of: "stencil"; "light" = no light(), "plain_light" = a
## plain one, "fragment" / "vertex" = that function's body left plain,
## "varyings" = none declared, "arrays" = the world's int arrays of 1)].
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
	# The warm-up with every shadow off (2026-11-12): all things drew under the sun and a
	# torch, then the world crashed under the sun alone. Cut the world shader apart there.
	["world, many, sun alone, no stencil", "multi", "res://shaders/world.gdshader", "sun", "stencil"],
	["world, sun alone, no stencil", "box", "res://shaders/world.gdshader", "sun", "stencil"],
	["engine standard, many, sun alone", "multi", "standard", "sun", ""],
	["minimal shader, sun alone", "box", "minimal", "sun", ""],
	["world, sun alone, no light()", "multi", "res://shaders/world.gdshader", "sun", "stencil,light"],
	["world, sun alone, plain light()", "multi", "res://shaders/world.gdshader", "sun", "stencil,plain_light"],
	["world, sun alone, plain fragment()", "multi", "res://shaders/world.gdshader", "sun", "stencil,fragment"],
	["world, sun alone, plain vertex()", "multi", "res://shaders/world.gdshader", "sun", "stencil,vertex"],
	["leaves, sun alone, no stencil", "multi", "res://shaders/leaves.gdshader", "sun", "stencil"],
	["grass, sun alone, no stencil", "multi", "res://shaders/grass.gdshader", "sun", "stencil"],
	["sprite, sun alone", "box", "res://shaders/sprite.gdshader", "sun", ""],
	["water, sun alone", "box", "res://shaders/water.gdshader", "sun", ""],
	# Round 3 (2026-11-13): the world under the sun alone crashed with any one function
	# made plain, and every shader of ours under the sun's shadow, the bare ones not:
	# two functions plain, all three, and the bare shader with our include or world coords.
	["world, sun alone, all plain", "box", "res://shaders/world.gdshader", "sun", "stencil,light,fragment,vertex"],
	["world, sun alone, plain fragment, no light()", "box", "res://shaders/world.gdshader", "sun", "stencil,light,fragment"],
	["world, sun alone, plain vertex, no light()", "box", "res://shaders/world.gdshader", "sun", "stencil,light,vertex"],
	["world, sun alone, plain vertex and fragment", "box", "res://shaders/world.gdshader", "sun", "stencil,fragment,vertex"],
	["include, sun alone", "box", "include", "sun", ""],
	["include, sun shadow", "box", "include", "shadow", ""],
	["world coords, sun shadow", "box", "world_coords", "shadow", ""],
	["world, sun shadow, all plain", "box", "res://shaders/world.gdshader", "shadow", "stencil,light,fragment,vertex"],
	["sprite, sun shadow, all plain", "box", "res://shaders/sprite.gdshader", "shadow", "stencil,light,fragment,vertex"],
	# Round 4: even the world with every function plain crashed under the sun alone, and
	# the sprite under the sun's shadow; the include alone did not. What is left are
	# the declarations: varyings, material uniforms (the world's int arrays).
	["world, sun alone, all plain, no varyings", "box", "res://shaders/world.gdshader", "sun", "stencil,light,fragment,vertex,varyings"],
	["sprite, sun shadow, all plain, no varyings", "box", "res://shaders/sprite.gdshader", "shadow", "stencil,light,fragment,vertex,varyings"],
	["int array, sun alone", "box", "int_array", "sun", ""],
	["int array, sun shadow", "box", "int_array", "shadow", ""],
	["varyings, sun alone", "box", "varyings", "sun", ""],
	["varyings, sun shadow", "box", "varyings", "shadow", ""],
	["texture, sun shadow", "box", "texture", "shadow", ""],
	["float uniforms, sun shadow", "box", "floats", "shadow", ""],
	["world coords + varyings, sun shadow", "box", "coords_varyings", "shadow", ""],
	["world coords + varyings, sun alone", "box", "coords_varyings", "sun", ""],
	# Round 5: the sprite came through its shadow once its varyings were gone, the world
	# under the sun alone did not: left were its two int arrays of 63. Two arrays, one long
	# one, the world with arrays of 1, the sprite's own varyings in a bare shader.
	["two int arrays, sun alone", "box", "two_int_arrays", "sun", ""],
	["int[126], sun alone", "box", "int_array_126", "sun", ""],
	["world, sun alone, all plain, no varyings, arrays of 1", "box", "res://shaders/world.gdshader", "sun", "stencil,light,fragment,vertex,varyings,arrays"],
	["world, sun alone, arrays of 1", "box", "res://shaders/world.gdshader", "sun", "stencil,arrays"],
	["world, many, sun alone, arrays of 1", "multi", "res://shaders/world.gdshader", "sun", "stencil,arrays"],
	["world, sun shadow, arrays of 1", "box", "res://shaders/world.gdshader", "shadow", "stencil,arrays"],
	["world, sun shadow, all plain, no varyings", "box", "res://shaders/world.gdshader", "shadow", "stencil,light,fragment,vertex,varyings"],
	["sprite's varyings unused, sun shadow", "box", "sprite_varyings", "shadow", ""],
	["sprite's varyings used, sun shadow", "box", "sprite_varyings_used", "shadow", ""],
]
const MINIMAL := "shader_type spatial;\nvoid fragment() { ALBEDO = vec3(0.5); }\n"
const INCLUDE := "shader_type spatial;\n#include \"res://shaders/common.gdshaderinc\"\nvoid fragment() { ALBEDO = vec3(0.5); }\n"
const WORLD_COORDS := "shader_type spatial;\nrender_mode world_vertex_coords, cull_back;\nvoid fragment() { ALBEDO = vec3(0.5); }\n"
## Bare shaders with one kind of declaration each (round 4).
const CODES := {
	"int_array": "shader_type spatial;\nuniform int bits[63];\nvoid fragment() { ALBEDO = vec3(float(bits[1] & 3) * 0.2 + 0.3); }\n",
	"varyings": "shader_type spatial;\nvarying vec3 pos;\nvarying flat vec2 packed;\nvarying float clouds;\nvoid vertex() { pos = VERTEX; packed = UV; clouds = 0.5; }\nvoid fragment() { ALBEDO = vec3(clouds) + pos * 0.01 + vec3(packed, 0.0) * 0.01; }\n",
	"texture": "shader_type spatial;\nuniform sampler2D tex : source_color, filter_nearest;\nvoid fragment() { ALBEDO = texture(tex, UV).rgb; }\n",
	"floats": "shader_type spatial;\nuniform vec4 frame_uv = vec4(0.0, 0.0, 1.0, 1.0);\nuniform float splash = 0.0;\nuniform vec3 tint = vec3(1.0);\nvoid fragment() { ALBEDO = tint * (0.5 + splash) + frame_uv.xyz * 0.01; }\n",
	"two_int_arrays": "shader_type spatial;\nuniform int shapes[63];\nuniform int bits[63];\nvoid fragment() { ALBEDO = vec3(float((bits[1] & 3) + shapes[2]) * 0.2 + 0.3); }\n",
	"int_array_126": "shader_type spatial;\nuniform int bits[126];\nvoid fragment() { ALBEDO = vec3(float((bits[1] & 3) + bits[70]) * 0.2 + 0.3); }\n",
	"sprite_varyings": "shader_type spatial;\nrender_mode world_vertex_coords, cull_disabled;\nvarying float shade;\nvarying vec3 world_pos;\nvarying float clouds;\nvarying vec3 lamp_gain;\nvarying vec2 light_xz;\nvarying vec3 drawn;\n void fragment() { ALBEDO = vec3(0.5); }\n",
	"sprite_varyings_used": "shader_type spatial;\nrender_mode world_vertex_coords, cull_disabled;\nvarying float shade;\nvarying vec3 world_pos;\nvarying float clouds;\nvarying vec3 lamp_gain;\nvarying vec2 light_xz;\nvarying vec3 drawn;\n void vertex() { shade = 1.0; world_pos = VERTEX; clouds = 0.5; lamp_gain = vec3(1.0); light_xz = VERTEX.xz; drawn = VERTEX; }\nvoid fragment() { ALBEDO = vec3(shade * clouds) + world_pos * 0.01 + lamp_gain * 0.1 + vec3(light_xz, 0.0) * 0.01 + drawn * 0.01; }\n",
	"coords_varyings": "shader_type spatial;\nrender_mode world_vertex_coords, cull_disabled;\nvarying vec3 pos;\nvarying vec3 lamp_gain;\nvarying vec2 light_xz;\nvarying float clouds;\nvoid vertex() { pos = VERTEX; lamp_gain = vec3(1.0); light_xz = VERTEX.xz; clouds = 0.5; }\nvoid fragment() { ALBEDO = vec3(clouds) + pos * 0.01 + lamp_gain * 0.1 + vec3(light_xz, 0.0) * 0.01; }\n",
}
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
	_sun.visible = s[3] != "none"  # "sun", "omni", "shadow", "shadow_omni"
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
	elif what == "include":
		shader.code = INCLUDE
	elif what == "world_coords":
		shader.code = WORLD_COORDS
	elif CODES.has(what):
		shader.code = CODES[what]
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


## `code` with the body of `func` put as `body` (the whole function dropped when null).
static func _body(code: String, func_name: String, body: Variant) -> String:
	var head := "void %s() {" % func_name
	var start := code.find(head)
	if start < 0:
		return code
	var depth := 0
	var i := start + head.length() - 1
	while i < code.length():
		var c := code[i]
		if c == "{":
			depth += 1
		elif c == "}":
			depth -= 1
			if depth == 0:
				break
		i += 1
	var replaced := "" if body == null else "%s\n\t%s\n}" % [head, body]
	return code.substr(0, start) + replaced + code.substr(i + 1)


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
