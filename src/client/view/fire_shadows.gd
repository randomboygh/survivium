extends MultiMeshInstance3D
## Drawn shadows from every fire on the screen and the torch: a flat wedge on the ground
## behind the player, each animal and each tree trunk in a fire's light, pointing away
## from it and as dark as the fire's ring it lies in (fire_shadow.gdshader multiplies it
## into the ground).
## A few draws a frame where a real shadow (Effects, the "real" fire shadows setting)
## draws everything around the fire six times more; it shades nothing but the ground.

const PixelView := preload("res://src/client/view/pixel_view.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const Mat := preload("res://src/shared/content/materials.gd")
const FireShadowShader := preload("res://shaders/fire_shadow.gdshader")

const CELL := WorldData.CELL
const MAX_SHADOWS := 512
## Trunks remembered before the memory is cleared.
const MAX_TRUNKS := 4096
## Fires within this many world units of the player (and their light's range) throw
## shadows: as far as a wide screen shows.
const VIEW_REACH := 32.0
## World units a fire's light stands above its ground, and the torch's above the feet
## and to the south of them (see Effects.add_campfire and Player.place_sprite).
const FIRE_HEIGHT := 0.6
const TORCH_HEIGHT := 1.2
const TORCH_AHEAD := 0.3
## Widths of the shadows at their foot, world units.
const PLAYER_WIDTH := 0.4
const TRUNK_WIDTH := 0.5
## Casters stand on the light's ground within this many world units up or down.
const SAME_GROUND := 0.6
## The far end of a wedge is at most this many times as wide as its foot.
const MAX_SPREAD := 5.0
## The light of a dark night and of the full moon as a share of a fire's brightest ring
## (fire_shadow.gdshader).
const NIGHT_LIGHT := Vector2(0.14, 0.6)
## Lights the shader knows of, the nearest to the player (`lights` in fire_shadow.gdshader).
const MAX_LIGHTS := 8

var game
## The fire shadows setting is on "drawn".
var enabled := true
## Base of each trunk by its column (see WorldData.trees), found once: Vector2(height
## or -INF where none was found, the level looked from).
var _trunk_base := {}
## The feet of the trunks of a chunk by Vector3i(chunk x, chunk z, the level they were
## looked for from): [the chunk's number of trees then, PackedVector3Array].
var _chunk_feet := {}
## The trunk shadows of the fires, which stand still, are the first instances and are
## written again only when something they depend on changes: what they were made for
## (fires, their light's strength, the trees around) and how many there are.
var _trunks_for := ""
var _trunks_count := 0


func _ready() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = _wedge_mesh()
	mm.instance_count = MAX_SHADOWS
	mm.visible_instance_count = 0
	multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = FireShadowShader
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The shadows are moved every frame wherever the casters are.
	extra_cull_margin = 16384.0


## A unit quad on the ground: x across from -0.5 to 0.5, z along from 0 to 1.
static func _wedge_mesh() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-0.5, 0, 0), Vector3(0.5, 0, 0), Vector3(0.5, 0, 1), Vector3(-0.5, 0, 1)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 0, 3, 2])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _process(_delta: float) -> void:
	var mm := multimesh
	var n := 0
	if enabled and game.ready_to_play and game.effects.dark:
		var moon := clampf(game.sky.sky_light / 0.45, 0.0, 1.0)
		material_override.set_shader_parameter("night", lerpf(NIGHT_LIGHT.x, NIGHT_LIGHT.y, moon))
		var lights := _lights()
		n = _fire_trunks(lights)
		for l: Dictionary in lights:
			n = _cast_all(l, n)
		_show_lights(lights)
	else:
		_trunks_for = ""
	mm.visible_instance_count = n


## Puts the shadows the fires' lights throw from tree trunks first, unless they are
## there already from the last frame; returns the next free instance.
func _fire_trunks(lights: Array) -> int:
	var w = game.world
	var key := ""
	for l: Dictionary in lights:
		if l.torch:
			continue
		var trees := 0
		var k := _chunks_lit(l)
		for kz in range(k.position.y, k.end.y + 1):
			for kx in range(k.position.x, k.end.x + 1):
				trees += w.tree_chunks.get(Vector2i(kx, kz), {}).size()
		key += "%s %.2f %d;" % [l.at, l.strength, trees]
	if key == _trunks_for:
		return _trunks_count
	var n := 0
	for l: Dictionary in lights:
		if not l.torch:
			n = _cast_trunks(l, n)
	_trunks_for = key
	_trunks_count = n
	return n


## The chunks (as a rectangle of chunk keys, ends included) a light reaches.
func _chunks_lit(l: Dictionary) -> Rect2i:
	var at: Vector3 = l.at
	var r: float = l.range
	var k0 := Vector2i(floori((at.x - r) / CELL) >> WorldData.SHIFT, floori((at.z - r) / CELL) >> WorldData.SHIFT)
	var k1 := Vector2i(floori((at.x + r) / CELL) >> WorldData.SHIFT, floori((at.z + r) / CELL) >> WorldData.SHIFT)
	return Rect2i(k0, k1 - k0)


## Tells the shader where the lights nearest to the player are.
func _show_lights(lights: Array) -> void:
	var p: Vector3 = game.player.position
	var near := lights.duplicate()
	near.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return p.distance_squared_to(a.at) < p.distance_squared_to(b.at))
	var at := PackedVector4Array()
	var strengths := PackedFloat32Array()
	at.resize(MAX_LIGHTS)
	strengths.resize(MAX_LIGHTS)
	var count := mini(near.size(), MAX_LIGHTS)
	for i in count:
		var l: Dictionary = near[i]
		at[i] = Vector4(l.at.x, l.at.y + l.height, l.at.z, l.range)
		strengths[i] = l.strength
	var mat: ShaderMaterial = material_override
	mat.set_shader_parameter("lights", at)
	mat.set_shader_parameter("strengths", strengths)
	mat.set_shader_parameter("light_count", count)


## The lights that throw shadows: {"at": ground under the light, "height", "range",
## "strength" 0..1, "torch": bool}.
func _lights() -> Array:
	var out := []
	var p: Vector3 = game.player.position
	var effects = game.effects
	for f in effects.fires:
		var light: OmniLight3D = f.light
		if p.distance_to(f.at) < light.omni_range + VIEW_REACH:
			out.append({"at": f.at, "height": FIRE_HEIGHT, "range": light.omni_range,
				"strength": light.shadow_opacity, "torch": false})
	var torch: OmniLight3D = game.player.torch
	if torch.light_energy > 0.01:
		out.append({"at": p + Vector3(0.0, 0.0, TORCH_AHEAD), "height": TORCH_HEIGHT, "range": torch.omni_range,
			"strength": clampf(torch.light_energy / 1.3, 0.0, 1.0), "torch": true})
	return out


## Adds the shadows that move, thrown by light `l`, from instance `n` on: the player's
## and the animals', and the trunks' from the torch; returns the next free instance.
func _cast_all(l: Dictionary, n: int) -> int:
	if not l.torch:
		n = _cast(l, game.player.position, game.player.HEIGHT * CELL, PLAYER_WIDTH, n)
	var at: Vector3 = l.at
	var r2: float = l.range * l.range
	for c in game.wildlife.animals:
		# Most animals are far from every light.
		if Vector2(c.pos.x - at.x, c.pos.z - at.z).length_squared() >= r2:
			continue
		var aabb: AABB = game.creatures.looks[c.kind][0].get_aabb()
		n = _cast(l, c.pos, aabb.size.y, aabb.size.x * 0.4, n)
	if l.torch:
		n = _cast_trunks(l, n)
	return n


## Adds the shadows thrown by light `l` from the tree trunks around it from instance
## `n` on; returns the next free one.
func _cast_trunks(l: Dictionary, n: int) -> int:
	var at: Vector3 = l.at
	var r2: float = l.range * l.range
	var k := _chunks_lit(l)
	for kz in range(k.position.y, k.end.y + 1):
		for kx in range(k.position.x, k.end.x + 1):
			for foot: Vector3 in _feet(Vector2i(kx, kz), at):
				if Vector2(foot.x - at.x, foot.z - at.z).length_squared() < r2:
					n = _cast(l, foot, 64.0, TRUNK_WIDTH, n)
	return n


## The feet of the trunks of chunk `key` seen from a light at `at` (see _base), kept
## while the chunk's trees stay the same.
func _feet(key: Vector2i, at: Vector3) -> PackedVector3Array:
	var w = game.world
	var trees: Dictionary = w.tree_chunks.get(key, {})
	var id := Vector3i(key.x, key.y, floori(at.y / CELL))
	var known: Array = _chunk_feet.get(id, [])
	if not known.is_empty() and known[0] == trees.size():
		return known[1]
	var feet := PackedVector3Array()
	for col: Vector2i in trees:
		var base := _base(w, col, at)
		if base > -INF:
			feet.append(Vector3((col.x + 0.5) * CELL, base, (col.y + 0.5) * CELL))
	if _chunk_feet.size() > MAX_TRUNKS:
		_chunk_feet.clear()
	_chunk_feet[id] = [trees.size(), feet]
	return feet


## Height of the foot of the trunk in column `col` near the light at `at`, or -INF.
func _base(w, col: Vector2i, at: Vector3) -> float:
	var y0 := floori(at.y / CELL)
	if _trunk_base.has(col):
		var known: Vector2 = _trunk_base[col]
		# A trunk found stays where it is; one not found is looked for again from
		# another level.
		if known.x > -INF or known.y == y0:
			return known.x
	if _trunk_base.size() > MAX_TRUNKS:
		_trunk_base.clear()
	var base := -INF
	for y in range(y0 - 3, y0 + 4):
		if w.get_cell(col.x, y, col.y) == Mat.LOG and w.get_cell(col.x, y - 1, col.y) != Mat.LOG:
			base = y * CELL
			break
	_trunk_base[col] = Vector2(base, y0)
	return base


## One shadow of a caster standing at `foot`, `height` tall and `width` wide, thrown by
## light `l`, as instance `n`; returns the next free instance.
func _cast(l: Dictionary, foot: Vector3, height: float, width: float, n: int) -> int:
	if n >= MAX_SHADOWS or absf(foot.y - l.at.y) > SAME_GROUND:
		return n
	var away := Vector2(foot.x - l.at.x, foot.z - l.at.z)
	var d := away.length()
	var lh: float = l.height + l.at.y - foot.y
	var reach := sqrt(maxf(l.range * l.range - lh * lh, 0.0))
	if d < 0.25 or d >= reach or lh <= 0.05:
		return n
	# A caster taller than the light throws its shadow to the edge of the light.
	var length := reach - d if height >= lh else minf(d * height / (lh - height), reach - d)
	var spread := minf((d + length) / d, MAX_SPREAD)
	var dir := away / d
	var x_axis := Vector3(dir.y, 0.0, -dir.x) * width * spread
	var z_axis := Vector3(dir.x, 0.0, dir.y) * length
	var t := Transform3D(Basis(x_axis, Vector3.UP, z_axis), foot + Vector3(0.0, 0.01, 0.0))
	multimesh.set_instance_transform(n, t)
	var r: float = l.range
	multimesh.set_instance_custom_data(n, Color(d / r, length / r, lh / r, 1.0 / spread))
	multimesh.set_instance_color(n, Color(l.strength, 0.0, 0.0, 1.0))
	return n + 1
