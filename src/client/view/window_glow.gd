extends RefCounted
## Windows lit from inside: the glass of a window glows warm from outside at dusk and at
## night while a fire burns or a light set down is lit in the room behind it (under a
## roof, within its reach). Props hands over each window placed (add) with its model;
## the glass of it (the panes' voxels, bluer than the plank frame) is drawn again over the
## window in a warm colour (window_glow.gdshader), only the faces that look away from
## the lights. Which lights reach which window is worked out every PICK_EVERY seconds,
## the glow eases to it in between, and a window that does not glow draws nothing.
## Effects owns it and calls update with its fires and lights set down.

const PixelView := preload("res://src/client/view/pixel_view.gd")
const VoxelModel := preload("res://src/client/view/voxel_model.gd")
const WindowGlowShader := preload("res://shaders/window_glow.gdshader")
const Items := preload("res://src/shared/content/items.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")

## How often the lights are matched to the windows, in seconds.
const PICK_EVERY := 0.4
## How far a fire burning in full lights a window, in world units (a cell is half a unit);
## one burning low, less.
const FIRE_REACH := 6.0
## How far up or down from a window's middle a light may stand, in world units.
const HEIGHT := 1.5
## How strongly a window glows at most (how much of the glass turns warm), in full night.
const MOST := 0.85
## The windows begin to glow as the sky's light (Sky.sky_light) falls under DUSK, and
## glow in full under NIGHT.
const DUSK := 0.8
const NIGHT := 0.15
## How fast the glow follows the room, a share of the way a second.
const EASE := 3.0
## A voxel of a window's model is glass when its blue is this much over its red.
const GLASS_BLUE := 0.05

## The material shared by the glass of windows not glowing yet (ShaderWarmup draws it
## ahead); a window glowing gets its own copy.
static var material: ShaderMaterial

## Each window by its cell: {"node" (the window's model), "glow" (its glass, or null
## till it first glows), "model", "mid" (its middle, world units), "target", "amount"}.
var windows := {}
## Glass meshes by the window's model (VoxelModel).
var _glass := {}
var _wait := 0.0
## How bright a fire burning in full is (Effects.FIRE_ENERGY, its record's `base`).
var fire_full := 2.1


static func shared_material() -> ShaderMaterial:
	if material == null:
		material = ShaderMaterial.new()
		material.shader = WindowGlowShader
	return material


## Window placed on `cell`, drawn by `node` from voxel model `model` (Props).
func add(cell: Vector3i, node: MeshInstance3D, model) -> void:
	remove(cell)
	# Where it stands, not where it is drawn while it drops into place.
	var mid := Vector3(cell) * WorldData.CELL + node.mesh.get_aabb().get_center() / 16.0
	windows[cell] = {"node": node, "glow": null, "model": model, "mid": mid,
		"target": 0.0, "amount": 0.0}
	_wait = 0.0


func remove(cell: Vector3i) -> void:
	windows.erase(cell)


## The models were read anew (a hot reload): their glass is built again.
func forget_models() -> void:
	_glass = {}


## Matches the lights to the windows (every PICK_EVERY seconds) and eases each window's
## glow to what reaches it, as dark as `sky` (sky.gd) makes it round: `fires` and `lamps`
## are Effects', `roofed` tells whether a world point is under a roof.
func update(delta: float, sky, fires: Array, lamps: Array, roofed: Callable) -> void:
	if windows.is_empty():
		return
	_wait -= delta
	if _wait <= 0.0:
		_wait = PICK_EVERY
		_pick(sky, fires, lamps, roofed)
	var step := minf(1.0, delta * EASE)
	# A window whose node was freed before `remove` is let go after the loop: not erased
	# from the dictionary while it is walked.
	var gone: Array[Vector3i] = []
	for cell: Vector3i in windows:
		var w: Dictionary = windows[cell]
		if w.amount == w.target:
			continue
		w.amount = w.target if absf(w.target - w.amount) < 0.01 else lerpf(w.amount, w.target, step)
		if not _show(cell, w):
			gone.append(cell)
	for cell in gone:
		windows.erase(cell)


## Every lit light under a roof near each window, as the window's target glow, where they
## stand (weighted), and how much of it is a fire's.
func _pick(sky, fires: Array, lamps: Array, roofed: Callable) -> void:
	var dark := clampf((DUSK - sky.sky_light) / (DUSK - NIGHT), 0.0, 1.0)
	var lights: Array = []
	if dark > 0.0:
		for f: Dictionary in fires:
			var s: float = f.base / fire_full
			if roofed.call(f.at):
				lights.append([f.at, s, FIRE_REACH * lerpf(0.6, 1.0, s), 1.0])
		for rec: Dictionary in lamps:
			var e: Dictionary = rec.placed
			var left := 1.0
			if not e.is_empty() and Items.burns(e.item) > 0.0:
				left = 1.0 - float(e.burnt) / Items.burns(e.item)
			if roofed.call(rec.at):
				lights.append([rec.at, sky.charge_gain(left), float(rec.get("reach", 4.0)), 0.3])
	for cell: Vector3i in windows:
		var w: Dictionary = windows[cell]
		var mid: Vector3 = w.mid
		var sum := 0.0
		var at := Vector3.ZERO
		var flicker := 0.0
		for l: Array in lights:
			var p: Vector3 = l[0]
			if absf(p.y - mid.y) > HEIGHT:
				continue
			var d := Vector2(p.x - mid.x, p.z - mid.z).length()
			var k: float = l[1] * clampf(1.5 * (1.0 - d / float(l[2])), 0.0, 1.0)
			if k <= 0.0:
				continue
			sum += k
			at += p * k
			flicker += float(l[3]) * k
		w.target = minf(sum, 1.0) * dark * MOST
		if sum > 0.0:
			w.source = at / sum
			w.flicker = flicker / sum


## Draws window `w` on `cell` as bright as its amount: its glass made the first time.
## False when its node was freed (a typed variable cannot take a freed one: checked first).
func _show(cell: Vector3i, w: Dictionary) -> bool:
	if not is_instance_valid(w.node):
		return false
	var node: MeshInstance3D = w.node
	var glow: MeshInstance3D = w.glow
	if glow == null:
		if w.amount <= 0.0:
			return true
		glow = MeshInstance3D.new()
		glow.mesh = _glass_of(w.model)
		var mat := shared_material().duplicate() as ShaderMaterial
		mat.set_shader_parameter("seed", fmod(cell.x * 0.37 + cell.z * 0.71 + cell.y * 0.13, 1.0))
		glow.material_override = mat
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glow.layers = node.layers
		glow.custom_aabb = node.custom_aabb
		node.add_child(glow)
		w.glow = glow
	var mat: ShaderMaterial = glow.material_override
	glow.visible = w.amount > 0.0
	mat.set_shader_parameter("amount", w.amount)
	if w.has("source"):
		mat.set_shader_parameter("source", w.source)
		mat.set_shader_parameter("flicker", w.flicker)
	return true


## The panes of a window's voxel model `model`: its glass alone, in voxel units.
func _glass_of(model) -> ArrayMesh:
	if not _glass.has(model):
		var glass := VoxelModel.new()
		for p: Vector3i in model.voxels:
			var c: Color = model.voxels[p]
			if c.b > c.r + GLASS_BLUE:
				glass.set_voxel(p, c)
		_glass[model] = glass.build_mesh()
	return _glass[model]
