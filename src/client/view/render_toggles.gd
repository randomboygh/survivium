extends Node
## Hides parts of the picture one by one, to find which of them draws a fault on a device
## («Тестирование» → «Отладка» → «Что рисуется», the user's ask 2026-11-15: coloured
## wedges and lines on Android and PC after going from a game of one's own to a server).
## The parts: the groups of the draw census (DrawCensus.groups: the chunks' ground,
## water, grass, crowns..., the animals, the effects, every other kind of thing in the
## world), a group for each shader of shaders/ the world or the screen is drawn with, and
## the lights, the sun's shadow and the environment. A part hidden stays hidden till it
## is shown again or the scene is made anew: what comes into the world meanwhile (new
## chunks, a new animal) is hidden as it comes, and a node the game shows again by itself
## (the fire shadows by night) is hidden again the next frame. A tool for the developer.

const DrawCensus := preload("res://src/client/view/draw_census.gd")

## Seconds between two searches of the world for new nodes of a hidden part.
const RESCAN := 0.5
## The shaders' folder: a node drawn with a shader there is in that shader's part.
const SHADERS := "res://shaders/"

var game
## The names of the parts hidden.
var hidden := {}
## The nodes hidden here (node: true), shown again when their part is.
var _nodes := {}
## The parts that are no nodes, hidden: name: the Callable that shows them again.
var _undo := {}
var _rescan := 0.0


func _init(g) -> void:
	game = g
	process_mode = Node.PROCESS_MODE_ALWAYS


## The parts, in the order listed: [name, nodes] for a part made of nodes, [name,
## Callable(hide: bool)] for one that is switched another way.
func groups() -> Array:
	var out := []
	# The census's own groups of the world; the interface is left alone (hidden, nothing
	# could be tapped to show it again).
	for g: Array in DrawCensus.groups_of(game, null):
		var name: String = g[0]
		if name.begins_with("screen") or name == "whole screen" or name.begins_with("Camera3D"):
			continue
		out.append([name, g[1]])
	# The effects a piece at a time (the user's ask, 2026-11-15): by the var of Effects that
	# holds each, else by kind (the campfires' models and lights, the bursts' emitters...).
	var fx = game.effects
	if fx != null:
		var names := {}
		for prop in fx.get_property_list():
			if not prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				continue
			var v = fx.get(prop.name)
			var held: Array = v if v is Array else [v]
			for e in held:
				if e is Node and not names.has(e):
					names[e] = String(prop.name).trim_prefix("_")
		var parts := {}
		for n in fx.get_children():
			var key: String = names.get(n, _kind_of(n))
			if not parts.has(key):
				parts[key] = []
			parts[key].append(n)
		var fx_keys := parts.keys()
		fx_keys.sort()
		for key: String in fx_keys:
			out.append(["effects: %s (%d)" % [key, parts[key].size()], parts[key]])
	var by_shader := {}
	for n in game.world_root.find_children("*", "GeometryInstance3D", true, false):
		for shader in _shaders_of(n):
			var path: String = "shader: " + shader.get_file()
			if not by_shader.has(path):
				by_shader[path] = []
			by_shader[path].append(n)
	for n in game.find_children("*", "CanvasItem", true, false):
		var m: Material = n.material
		if m is ShaderMaterial and m.shader != null and m.shader.resource_path.begins_with(SHADERS):
			var key: String = "screen shader: " + m.shader.resource_path.get_file()
			if not by_shader.has(key):
				by_shader[key] = []
			by_shader[key].append(n)
	var keys := by_shader.keys()
	keys.sort()
	for path: String in keys:
		var nodes: Array = by_shader[path]
		out.append(["%s (%d)" % [path, nodes.size()], nodes])
	var sky = game.sky
	if sky != null and sky.sun != null:
		out.append(["light: sun and moon", [sky.sun]])
		out.append(["light: sun and moon shadow", func(hide: bool) -> void:
			if is_instance_valid(sky.sun):
				sky.sun.shadow_enabled = not hide])
	out.append(["light: fires and torches", game.world_root.find_children("*", "OmniLight3D", true, false)])
	if sky != null and sky.env != null:
		var env: Environment = sky.env
		out.append(["environment: fog", func(hide: bool) -> void: env.fog_enabled = false if hide else env.get_meta("fog", env.fog_enabled)])
		out.append(["environment: glow", func(hide: bool) -> void: env.glow_enabled = false if hide else env.get_meta("glow", env.glow_enabled)])
		out.append(["environment: colour adjustment", func(hide: bool) -> void:
			env.adjustment_enabled = false if hide else env.get_meta("adjustment", env.adjustment_enabled)])
	return out


## The names of the parts, as groups() lists them, with the shaders' counts left out
## (they change as the world streams), so a name stays the same between two lists.
static func key_of(name: String) -> String:
	var i := name.rfind(" (")
	return name.left(i) if i > 0 and name.ends_with(")") else name


## Hides part `name` (as groups() calls it) or shows it again.
func set_hidden(name: String, hide: bool) -> void:
	var key := key_of(name)
	if hide == hidden.has(key):
		return
	if hide:
		hidden[key] = true
		print("render toggles: hidden %s" % key)
	else:
		hidden.erase(key)
		print("render toggles: shown %s" % key)
	_apply()


## Shows every part again.
func show_all() -> void:
	hidden.clear()
	_apply()


func is_hidden(name: String) -> bool:
	return hidden.has(key_of(name))


func _process(delta: float) -> void:
	if _nodes.is_empty() and hidden.is_empty():
		return
	# What the game showed again by itself is hidden again at once; new nodes are found
	# by the search now and then.
	for n in _nodes.keys():
		if not is_instance_valid(n):
			_nodes.erase(n)
		elif n.visible:
			n.visible = false
	_rescan -= delta
	if _rescan <= 0.0:
		_rescan = RESCAN
		_apply()


## Hides the nodes of the hidden parts, shows those of the parts shown again.
func _apply() -> void:
	var keep := {}
	for g: Array in groups():
		var key := key_of(g[0])
		var hide := hidden.has(key)
		if g[1] is Callable:
			if hide and not _undo.has(key):
				_remember_env()
				(g[1] as Callable).call(true)
				_undo[key] = g[1]
			continue
		if not hide:
			continue
		for n in g[1]:
			if is_instance_valid(n):
				keep[n] = true
				if not _nodes.has(n):
					_nodes[n] = true
				n.visible = false
	for n in _nodes.keys():
		if not keep.has(n):
			_nodes.erase(n)
			if is_instance_valid(n):
				n.visible = true
	for key in _undo.keys():
		if not hidden.has(key):
			(_undo[key] as Callable).call(false)
			_undo.erase(key)


## The environment's switches as they were before any was hidden.
func _remember_env() -> void:
	var env: Environment = game.sky.env if game.sky != null else null
	if env == null or env.has_meta("fog"):
		return
	env.set_meta("fog", env.fog_enabled)
	env.set_meta("glow", env.glow_enabled)
	env.set_meta("adjustment", env.adjustment_enabled)


## The paths of the shaders node `n` is drawn with ("standard material" for Godot's own).
static func _shaders_of(n: GeometryInstance3D) -> Array:
	var mats := []
	if n.material_override != null:
		mats.append(n.material_override)
	var mesh: Mesh = null
	if n is MeshInstance3D:
		mesh = n.mesh
		for i in n.get_surface_override_material_count():
			mats.append(n.get_surface_override_material(i))
	elif n is MultiMeshInstance3D and n.multimesh != null:
		mesh = n.multimesh.mesh
	elif n is GPUParticles3D:
		mesh = n.draw_pass_1
	if mesh != null and n.material_override == null:
		for i in mesh.get_surface_count():
			mats.append(mesh.surface_get_material(i))
	var out := []
	for m in mats:
		var path := ""
		if m is ShaderMaterial and m.shader != null:
			path = m.shader.resource_path if m.shader.resource_path != "" else "inline shader"
		elif m is BaseMaterial3D:
			path = "standard material"
		if path != "" and not out.has(path):
			out.append(path)
	return out


## A node's kind: its script's file, else its class (a particle emitter, a light).
static func _kind_of(n: Node) -> String:
	var sc: Script = n.get_script()
	if sc != null and sc.resource_path != "":
		return sc.resource_path.get_file().get_basename()
	return n.get_class()
