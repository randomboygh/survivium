extends MultiMeshInstance3D
## Drawn shadows from every fire on the screen and the torch, as dark as the fire's ring
## they lie in (fire_shadow.gdshader multiplies them into the ground):
## - a flat wedge on the ground behind the player, each animal, each campfire and each
##   tree trunk in a light, pointing away from it;
## - the shadows of the blocks and of the things placed (chests, stations): each light
##   keeps a map of the cells around it (see _maps), and the shaders of the world and
##   the plants look along the way from each point they draw to the light for a block
##   in it (light_hidden in common.gdshaderinc): no light gets there.
## The animals and the player standing in them are drawn darker too (`shade` in
## sprite.gdshader).
## A few draws a frame where a real shadow (Effects, the "real" fire shadows setting)
## draws everything around the fire six times more.

const PixelView := preload("res://src/client/view/pixel_view.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const Mat := preload("res://src/shared/content/materials.gd")
const Trees := preload("res://src/shared/content/trees.gd")
const Placed := preload("res://src/shared/game/placed.gd")
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
## How thick an animal is across, as a share of how long it is drawn.
const ANIMAL_DEPTH := 0.4
## A trunk's, for one 6 texels across; a thicker one throws a wider shadow.
const TRUNK_WIDTH := 0.5
## How wide and how tall a campfire throws its shadow, in world units: its ring of
## stones and the logs on it (Effects._campfire_model, 11 and 3 of its 16 voxels a unit).
const CAMPFIRE_SIZE := Vector2(0.7, 0.2)
## Casters stand on the light's ground within this many world units up or down.
const SAME_GROUND := 0.6
## The far end of a wedge is at most this many times as wide as its foot.
const MAX_SPREAD := 5.0
## Frames between working out how dark the sprites in the shadows are.
const SHADE_EVERY := 4
## The torch's id among the lights, a unit no fire stands on (fires go by their unit).
const TORCH_ID := Vector3i(0, -1048576, 0)
## The light of a dark night and of the full moon as a share of a fire's brightest ring
## (fire_shadow.gdshader).
const NIGHT_LIGHT := Vector2(0.14, 0.6)
## Lights the shader knows of, the nearest to the player (`lights` in fire_shadow.gdshader).
const MAX_LIGHTS := 8
## The rings of a fire's light, as shares of its range, and how bright each is
## (LIGHT_RING_EDGES and LIGHT_RING_LEVELS in common.gdshaderinc).
const RING_EDGES := [0.2, 0.4, 0.6, 1.0]
const RING_LEVELS := [1.0, 0.55, 0.3, 0.14]
## Columns across a light's map (MAP_SIZE in fire_shadow.gdshader): a fire's light
## reaches 16 cells from it, the torch's 10.
const MAP := 32
## Rows of the lights' maps made a frame.
const MAP_ROWS := 8
## Levels a map holds (LIGHT_LEVELS in common.gdshaderinc), from BELOW under the
## light's ground up: what stands far higher or lower is not in a light's way.
const LEVELS := 16
const BELOW := 6
## Rows of a light's map in the atlas: two of the solid cells (a bit a level), then
## one a level of the cells' shapes (see light_blocks in common.gdshaderinc).
const MAP_ROWS_TALL := MAP * (2 + LEVELS)

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
## (fires, their light's strength and place among the lights, the trees around) and
## how many there are.
var _trunks_for := ""
var _trunks_count := 0
## The wedges of this frame, for the animals standing in them: [light id, foot,
## direction, length, width at the foot, width at the far end, who throws it]; the
## trunks' first, kept with their instances.
var _wedges := []
var _trunk_wedges := []
## What stands around each light, by the light's id (see _lights): a map of MAP by
## MAP columns from `origin` (the north-west column) over LEVELS levels from BELOW
## under the light's ground `level`, laid out as light_blocks in common.gdshaderinc
## (MAP wide, MAP_ROWS_TALL tall): {"origin": Vector2i, "level": int, "data":
## PackedByteArray, "chunks": the chunks kept around it when it was made} once made;
## "next" is the same, with "row", for one being made a few rows a frame.
var _maps := {}
## The maps of the lights the shaders know, side by side in their order, and the maps
## it holds now; where those lights are (light_spots in common.gdshaderinc).
var _atlas: Image
var _atlas_texture: ImageTexture
var _atlas_for := []
var _spots: Image
var _spots_texture: ImageTexture
var _spots_for := PackedFloat32Array()
## Sprites drawn darker now, and how dark (see _shade).
var _shaded := {}


## Height of the ground the player last stood on (see _player_ground).
var _ground_y := INF

## Frames left until the sprites' shades are worked out again, and the last ones.
var _shade_wait := 0
var _last_shades := {}
## The campfires placed, by their north-west cell: the middle of the ground they stand
## on, a Vector3. They throw a wedge like a body does, not the square column of a map
## (which looked like a cube); found again when a thing is placed or taken.
var _campfires := {}
var _campfires_known := false

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
	_atlas = Image.create_empty(MAP * MAX_LIGHTS, MAP_ROWS_TALL, false, Image.FORMAT_R8)
	_atlas_texture = ImageTexture.create_from_image(_atlas)
	RenderingServer.global_shader_parameter_set("light_blocks", _atlas_texture)
	_spots = Image.create_empty(MAX_LIGHTS, 2, false, Image.FORMAT_RGBAF)
	_spots_texture = ImageTexture.create_from_image(_spots)
	RenderingServer.global_shader_parameter_set("light_spots", _spots_texture)
	if game != null and game.actions != null:
		game.actions.cell_changed.connect(_on_cell_changed)
		game.placed.cell_changed.connect(_on_cell_changed)
		game.placed.added.connect(_on_placed)
		game.placed.removed.connect(_on_placed)


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
	var t := Time.get_ticks_usec()
	var mm := multimesh
	var n := 0
	var shades := {}
	if enabled and game.ready_to_play and game.effects.dark:
		var moon := clampf(game.sky.sky_light / 0.45, 0.0, 1.0)
		var night := lerpf(NIGHT_LIGHT.x, NIGHT_LIGHT.y, moon)
		material_override.set_shader_parameter("night", night)
		_ground_y = _player_ground()
		var lights := _lights()
		_update_maps(lights)
		n = _fire_trunks(lights)
		_wedges = _trunk_wedges.duplicate()
		for l: Dictionary in lights:
			n = _cast_all(l, n)
		_show_lights(lights)
		# The sprites move slowly: their shades are worked out every few frames.
		_shade_wait -= 1
		if _shade_wait <= 0:
			_shade_wait = SHADE_EVERY
			_last_shades = _shades(lights, night)
		shades = _last_shades
	else:
		_last_shades = {}
		_trunks_for = ""
		_show_spots([])
	_shade(shades)
	mm.visible_instance_count = n
	game.hud.perf.note("тени огня", t)


## The ground under the player: where they stand, or in a jump where they last stood
## (or lower, where the jump comes down), so the shadows by the torch and of the player
## stay on the ground while they are in the air.
func _player_ground() -> float:
	var player = game.player
	if player.body.on_ground or player.body.swimming:
		return player.position.y
	return minf(_ground_y, player.position.y)


## The player's place on the ground under them (see _player_ground).
func _player_feet() -> Vector3:
	var p: Vector3 = game.player.position
	return Vector3(p.x, _ground_y, p.z)


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
		key += "%s %.2f %d %d;" % [l.at, l.strength, l.index, trees]
	if key == _trunks_for:
		return _trunks_count
	var n := 0
	_wedges = []
	for l: Dictionary in lights:
		if not l.torch:
			n = _cast_trunks(l, n)
	_trunks_for = key
	_trunks_count = n
	_trunk_wedges = _wedges
	return n


## The chunks (as a rectangle of chunk keys, ends included) a light reaches.
func _chunks_lit(l: Dictionary) -> Rect2i:
	var at: Vector3 = l.at
	var r: float = l.range
	var k0 := Vector2i(floori((at.x - r) / CELL) >> WorldData.SHIFT, floori((at.z - r) / CELL) >> WorldData.SHIFT)
	var k1 := Vector2i(floori((at.x + r) / CELL) >> WorldData.SHIFT, floori((at.z + r) / CELL) >> WorldData.SHIFT)
	return Rect2i(k0, k1 - k0)


## Tells the shader where the lights nearest to the player are, and their maps.
func _show_lights(lights: Array) -> void:
	var at := PackedVector4Array()
	var strengths := PackedFloat32Array()
	at.resize(MAX_LIGHTS)
	strengths.resize(MAX_LIGHTS)
	var count := mini(lights.size(), MAX_LIGHTS)
	var now := []
	for i in count:
		var l: Dictionary = lights[i]
		at[i] = Vector4(l.at.x, l.at.y + l.height, l.at.z, l.range)
		strengths[i] = l.strength
		var m: Dictionary = _maps.get(l.id, {})
		now.append(m.data if m.has("data") else null)
	if now != _atlas_for:
		_atlas_for = now
		_atlas.fill(Color(0, 0, 0))
		for i in now.size():
			if now[i] != null:
				_atlas.blit_rect(Image.create_from_data(MAP, MAP_ROWS_TALL, false, Image.FORMAT_R8, now[i]),
					Rect2i(0, 0, MAP, MAP_ROWS_TALL), Vector2i(i * MAP, 0))
		_atlas_texture.update(_atlas)
		game.hud.perf.mark("тени")
	_show_spots(lights)
	var mat: ShaderMaterial = material_override
	mat.set_shader_parameter("lights", at)
	mat.set_shader_parameter("strengths", strengths)
	mat.set_shader_parameter("light_count", count)


## Tells the shaders where the lights with a map stand and where their maps lie
## (light_spots in common.gdshaderinc); none when `lights` is empty.
func _show_spots(lights: Array) -> void:
	var data := PackedFloat32Array()
	data.resize(MAX_LIGHTS * 8)
	for i in mini(lights.size(), MAX_LIGHTS):
		var l: Dictionary = lights[i]
		var m: Dictionary = _maps.get(l.id, {})
		if not m.has("data"):
			continue
		var j := i * 4
		data[j] = l.at.x
		data[j + 1] = l.at.y + l.height
		data[j + 2] = l.at.z
		data[j + 3] = l.range
		j += MAX_LIGHTS * 4
		data[j] = m.origin.x
		data[j + 1] = m.origin.y
		data[j + 2] = m.level - BELOW
		data[j + 3] = 2.0
	if data == _spots_for:
		return
	_spots_for = data
	_spots.set_data(MAX_LIGHTS, 2, false, Image.FORMAT_RGBAF, data.to_byte_array())
	_spots_texture.update(_spots)


## The lights that throw shadows, the nearest to the player first: {"id": the fire's
## unit or TORCH_ID, "at": ground under the light, "height", "range", "strength" 0..1,
## "torch": bool, "real": it throws a real shadow, "index": its place among the
## lights the shader knows (MAX_LIGHTS for none)}.
func _lights() -> Array:
	var out := []
	var p: Vector3 = game.player.position
	var effects = game.effects
	for f in effects.fires:
		var light: OmniLight3D = f.light
		var r := light.omni_range / PixelView.light_reach
		if p.distance_to(f.at) < r + VIEW_REACH:
			out.append({"id": f.unit, "at": f.at, "height": FIRE_HEIGHT, "range": r,
				"strength": light.shadow_opacity, "torch": false, "real": light.shadow_enabled})
	var torch: OmniLight3D = game.player.torch
	if torch.light_energy > 0.01 and game.player.torch_lit:
		# In a jump the torch goes up with the hand, its ground stays where it was.
		out.append({"id": TORCH_ID, "at": _player_feet() + Vector3(-PixelView.up.x, 0.0, -PixelView.up.y) * TORCH_AHEAD,
			"height": TORCH_HEIGHT + p.y - _ground_y,
			"range": torch.omni_range / PixelView.light_reach, "strength": clampf(torch.light_energy / 1.3, 0.0, 1.0),
			"torch": true, "real": false})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return p.distance_squared_to(a.at) < p.distance_squared_to(b.at))
	for i in out.size():
		out[i].index = mini(i, MAX_LIGHTS)
	return out


## Adds the shadows that move, thrown by light `l`, from instance `n` on: the player's
## and the animals', and the trunks' from the torch; returns the next free instance.
func _cast_all(l: Dictionary, n: int) -> int:
	# A fire with a real shadow (the "mixed" setting, see Effects.player_only) throws
	# the player's itself.
	if not l.torch and not l.real:
		n = _cast(l, _player_feet(), game.player.HEIGHT * CELL, PLAYER_WIDTH, n, game.player)
	var at: Vector3 = l.at
	var r2: float = l.range * l.range
	for c in game.wildlife.animals:
		# Most animals are far from every light; birds in the air throw none on the ground.
		if c.aloft() or Vector2(c.pos.x - at.x, c.pos.z - at.z).length_squared() >= r2:
			continue
		# The body is as long as its picture is wide, along the picture (an animal is drawn
		# from the side, facing the view), and ANIMAL_DEPTH of that across.
		var size: Vector2 = game.creatures.looks[c.kind][2]
		n = _cast(l, c.pos, size.y, size.x, n, c, size.x * ANIMAL_DEPTH)
	n = _cast_campfires(l, n)
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
					n = _cast(l, foot, 64.0, _girth(foot), n, null)
	return n


## How wide the trunk standing at `foot` is at its foot (see Trees.trunk_box).
func _girth(foot: Vector3) -> float:
	var col := Vector2i(floori(foot.x / CELL), floori(foot.z / CELL))
	var species: int = game.world.trees.get(col, -1)
	if species < 0 or species >= Trees.SPECIES.size():
		return TRUNK_WIDTH
	return TRUNK_WIDTH * Trees.trunk_box(species, col, 0).size.x / 6.0


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
## light `l`, as instance `n`; returns the next free instance. `who` is the caster (an
## animal, the player, null for a trunk), whom its own shadow does not darken. With a
## `depth`, `width` is a body's length along the picture and `depth` its thickness.
func _cast(l: Dictionary, foot: Vector3, height: float, width: float, n: int, who, depth := -1.0) -> int:
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
	if depth >= 0.0:
		# A body `width` long along the picture and `depth` across: as wide as it shows
		# to the light.
		width = width * absf(dir.cross(PixelView.right)) + depth * absf(dir.dot(PixelView.right))
	var x_axis := Vector3(dir.y, 0.0, -dir.x) * width * spread
	var z_axis := Vector3(dir.x, 0.0, dir.y) * length
	var t := Transform3D(Basis(x_axis, Vector3.UP, z_axis), foot + Vector3(0.0, 0.01, 0.0))
	multimesh.set_instance_transform(n, t)
	var r: float = l.range
	multimesh.set_instance_custom_data(n, Color(d / r, length / r, lh / r, 1.0 / spread))
	# A shadow that reaches the edge of the light ends with the light's own rings there.
	multimesh.set_instance_color(n, Color(l.strength, _index_color(l), 1.0 if height >= lh else 0.0, 1.0))
	_wedges.append([l.id, Vector2(foot.x, foot.z), dir, length, width, width * spread, who])
	return n + 1


## A light's place among those the shader knows, as the instance colour gives it.
static func _index_color(l: Dictionary) -> float:
	return (l.index + 0.5) / MAX_LIGHTS


## Makes the maps of the lights the shader knows when they have none, are out of date
## or (the torch) have been left behind, a few rows a frame.
func _update_maps(lights: Array) -> void:
	var w = game.world
	var known := {}
	for l: Dictionary in lights:
		if l.index >= MAX_LIGHTS:
			continue
		known[l.id] = true
		var level := floori(l.at.y / CELL + 0.01)
		var reach := ceili(l.range / CELL)
		var col := Vector2i(floori(l.at.x / CELL), floori(l.at.z / CELL))
		var m: Dictionary = _maps.get(l.id, {})
		_maps[l.id] = m
		if m.has("next"):
			continue
		var fresh: bool = m.has("data") and not m.get("stale", false) and m.level == level \
			and m.chunks == _chunks_kept(w, m.origin)
		if fresh:
			# The window must hold all the light reaches (but for its last column, at the
			# very edge of its light, on the side the window is a column short).
			var off: Vector2i = col - m.origin
			fresh = off.x >= reach - 1 and off.y >= reach - 1 and off.x <= MAP - reach and off.y <= MAP - reach
		if not fresh:
			var origin := col - Vector2i(MAP / 2, MAP / 2)
			var data := PackedByteArray()
			data.resize(MAP * MAP_ROWS_TALL)
			m.next = {"origin": origin, "level": level, "data": data, "row": 0,
				"chunks": _chunks_kept(w, origin), "light": Vector2(l.at.x, l.at.z) / CELL}
	for id in _maps.keys():
		if not known.has(id):
			_maps.erase(id)
	# The rows of the frame go to the nearest light's map first.
	var rows := MAP_ROWS
	for l: Dictionary in lights:
		var m: Dictionary = _maps.get(l.id, {})
		if rows <= 0:
			break
		if not m.has("next"):
			continue
		var next: Dictionary = m.next
		while rows > 0 and next.row < MAP:
			_map_row(w, next, next.row)
			next.row += 1
			rows -= 1
		if next.row >= MAP:
			_map_blockers(w, next)
			m.erase("next")
			m.erase("stale")
			next.erase("row")
			m.merge(next, true)


## How many of the chunks under a map from `origin` are kept: one that comes later
## makes the map anew.
func _chunks_kept(w, origin: Vector2i) -> int:
	var n := 0
	for kz in range(origin.y >> WorldData.SHIFT, ((origin.y + MAP - 1) >> WorldData.SHIFT) + 1):
		for kx in range(origin.x >> WorldData.SHIFT, ((origin.x + MAP - 1) >> WorldData.SHIFT) + 1):
			if w.has_chunk(Vector2i(kx, kz)):
				n += 1
	return n


## Fills row `row` of map `m`: which cells over each column are solid, and the shapes
## of those that slope or have corners cut off or filled in. Leaves let the light
## through, and so do trunks, which have shadows of their own.
func _map_row(w, m: Dictionary, row: int) -> void:
	w.refresh_shapes()
	var z: int = m.origin.y + row
	var base: int = m.level - BELOW
	var data: PackedByteArray = m.data
	var all: int = w.all_bits
	var layer := MAP * MAP
	var i := row * MAP
	var x: int = m.origin.x
	var x1 := x + MAP
	while x < x1:
		var c = w.chunk_at(x, z)
		var end := mini(x1, (x | WorldData.MASK) + 1)
		if c == null:
			i += end - x
			x = end
			continue
		while x < end:
			var col := ((z & WorldData.MASK) << WorldData.SHIFT) | (x & WorldData.MASK)
			var solid := _window(~(c.air[col] | c.water[col] | c.leaf[col] | c.logs[col]) & all, base)
			if base < 0:
				# Under the world is stone.
				solid |= (1 << mini(-base, LEVELS)) - 1
			data[i] = solid & 255
			data[layer + i] = solid >> 8
			var shaped := _window(c.sloped[col] | c.corner[col], base)
			while shaped != 0:
				var bit := shaped & -shaped
				shaped ^= bit
				var y := WorldData.level_of(bit)
				data[(2 + y) * layer + i] = c.shapes[((base + y) << 8) | col]
			i += 1
			x += 1


## The LEVELS bits of a column's mask `bits` from level `base` up.
static func _window(bits: int, base: int) -> int:
	return ((bits >> base) if base >= 0 else (bits << -base)) & ((1 << LEVELS) - 1)


## Marks the cells of map `m` that the things placed (chests, stations) stand in as
## solid; campfires have wedges of their own.
func _map_blockers(w, m: Dictionary) -> void:
	var data: PackedByteArray = m.data
	var base: int = m.level - BELOW
	for cell: Vector3i in w.blockers:
		var o: Vector2i = Vector2i(cell.x, cell.z) - m.origin
		var y: int = cell.y - base
		if o.x < 0 or o.y < 0 or o.x >= MAP or o.y >= MAP or y < 0 or y >= LEVELS:
			continue
		var box: AABB = w.blockers[cell]
		if box.end.y < 0.5 or _under_campfire(cell):
			continue
		var i: int = (y >> 3) * MAP * MAP + o.y * MAP + o.x
		data[i] = data[i] | (1 << (y & 7))


## A cell changed: the maps over it are made anew.
func _on_cell_changed(cell: Vector3i) -> void:
	for id in _maps:
		var m: Dictionary = _maps[id]
		if m.has("data") and not m.has("next") and cell.y >= m.level - BELOW and cell.y < m.level - BELOW + LEVELS \
				and Rect2i(m.origin, Vector2i(MAP, MAP)).has_point(Vector2i(cell.x, cell.z)):
			m.stale = true


func _on_placed(e: Dictionary) -> void:
	_campfires_known = false
	_on_cell_changed(e.cell)


## The campfires placed (see _campfires).
func _fires() -> Dictionary:
	if not _campfires_known:
		_campfires_known = true
		_campfires = {}
		for e: Dictionary in game.placed.things:
			if Placed.is_fire(e):
				_campfires[e.cell] = (Vector3(e.cell) + Vector3(1.0, 0.0, 1.0)) * CELL
	return _campfires


## True when cell `c` is one of the four a campfire stands on.
func _under_campfire(c: Vector3i) -> bool:
	var fires := _fires()
	return fires.has(c) or fires.has(c - Vector3i(1, 0, 0)) or fires.has(c - Vector3i(0, 0, 1)) \
		or fires.has(c - Vector3i(1, 0, 1))


## Adds the shadows thrown by light `l` from the campfires around it but the one it
## burns on, round and low like a body's, from instance `n` on; returns the next free one.
func _cast_campfires(l: Dictionary, n: int) -> int:
	var fires := _fires()
	if fires.is_empty():
		return n
	var at: Vector3 = l.at
	var r2: float = l.range * l.range
	for foot: Vector3 in fires.values():
		var away := Vector2(foot.x - at.x, foot.z - at.z)
		if away.length_squared() < 1.0 or away.length_squared() >= r2:
			continue
		# From the far side of the ring of stones, which the shadow starts behind.
		away = away.normalized() * CAMPFIRE_SIZE.x * 0.5
		n = _cast(l, foot + Vector3(away.x, 0.0, away.y), CAMPFIRE_SIZE.y, CAMPFIRE_SIZE.x, n, null)
	return n


## True when a block stands in the way from `p` (a body's middle over it) to light
## `l`, as the shaders see it (light_blocked in common.gdshaderinc), looked at every
## quarter of a cell; a sloping top counts up to half its cell.
func _blocked(l: Dictionary, p: Vector3) -> bool:
	var m: Dictionary = _maps.get(l.id, {})
	if not m.has("data"):
		return false
	var data: PackedByteArray = m.data
	var corner := Vector3(m.origin.x, m.level - BELOW, m.origin.y)
	var a := (p + Vector3(0.0, 0.3, 0.0)) / CELL - corner
	var d: Vector3 = (l.at + Vector3(0.0, l.height, 0.0)) / CELL - corner - a
	var steps := floori((d.length() - 0.4) * 4.0)
	var layer := MAP * MAP
	for k in range(1, steps):
		var q: Vector3 = a + d * (k / (d.length() * 4.0))
		var c := Vector3i(floori(q.x), floori(q.y), floori(q.z))
		if c.x < 0 or c.y < 0 or c.z < 0 or c.x >= MAP or c.z >= MAP or c.y >= LEVELS:
			continue
		var i := c.z * MAP + c.x
		if (data[(c.y >> 3) * layer + i] >> (c.y & 7)) & 1 == 0:
			continue
		if data[(2 + c.y) * layer + i] & 15 == 0 or q.y - c.y < 0.5:
			return true
	return false


# --- The animals and the player in the shadows ----------------------------------

## How bright each light's ring is at `d`, a share of its range.
static func _ring(d: float) -> float:
	for i in RING_EDGES.size():
		if d < RING_EDGES[i]:
			return RING_LEVELS[i]
	return 0.0


## How dark each sprite standing in a drawn shadow is drawn, by the sprite: what the
## light it is shaded from leaves of the light there (as fire_shadow.gdshader works it
## out for the ground).
func _shades(lights: Array, night: float) -> Dictionary:
	var out := {}
	var who := [[game.player, _player_feet(), game.player.sprite]]
	for a in game.wildlife.animals:
		# Birds up in the air or in a crown are above the shadows on the ground; most
		# animals are out of every light's range.
		if not a.near or a.aloft():
			continue
		var lit_at_all := false
		for l: Dictionary in lights:
			if Vector2(a.pos.x - l.at.x, a.pos.z - l.at.z).length_squared() < l.range * l.range:
				lit_at_all = true
				break
		if not lit_at_all:
			continue
		var sprite = game.creatures.sprite_of(a)
		if sprite != null:
			who.append([a, a.pos, sprite])
	for w: Array in who:
		var p: Vector3 = w[1]
		var all := 0.0
		var lit := []
		for l: Dictionary in lights:
			var d: float = p.distance_to(l.at + Vector3(0.0, l.height, 0.0)) / l.range
			var own: float = _ring(d) * l.strength
			if own <= 0.0:
				continue
			all += own
			# The player's own torch throws no shadow on them.
			if l.torch and w[0] == game.player:
				continue
			if _in_shadow(l, p, w[0]):
				lit.append(own)
		var shade := 1.0
		for own: float in lit:
			shade *= (night + all - own) / (night + all)
		if shade < 0.99:
			out[w[2]] = shade
	return out


## True when the ground at `p` is in a drawn shadow of light `l` that `who` does not
## throw itself.
func _in_shadow(l: Dictionary, p: Vector3, who) -> bool:
	if absf(p.y - l.at.y) > SAME_GROUND:
		return _blocked(l, p)
	var q := Vector2(p.x, p.z)
	for wedge: Array in _wedges:
		if wedge[0] != l.id or wedge[6] == who:
			continue
		var dir: Vector2 = wedge[2]
		var rel: Vector2 = q - wedge[1]
		var along := rel.dot(dir)
		if along < 0.0 or along > wedge[3]:
			continue
		var half: float = lerpf(wedge[4], wedge[5], along / wedge[3]) * 0.5
		if absf(rel.dot(Vector2(dir.y, -dir.x))) < half:
			return true
	return _blocked(l, p)


## Draws the sprites in `shades` that dark, and the rest as they are (sprite.gdshader
## reads the shade from the sprite's scale along z).
func _shade(shades: Dictionary) -> void:
	for sprite in _shaded.keys():
		if not shades.has(sprite):
			if is_instance_valid(sprite):
				sprite.scale.z = 1.0
			_shaded.erase(sprite)
	for sprite in shades:
		# Shades are kept a few frames, and an animal may be gone meanwhile.
		if not is_instance_valid(sprite):
			continue
		if absf(_shaded.get(sprite, 1.0) - shades[sprite]) > 0.01:
			sprite.scale.z = maxf(shades[sprite], 0.01)
			_shaded[sprite] = shades[sprite]
