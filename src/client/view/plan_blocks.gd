extends Node3D
## The blocks of the blueprint drawn as they will stand built (user 2026-11-22): the same
## textures, edges and forms as the world's built blocks (ChunkMesher, world.gdshader), but
## see-through and tinted cold blue. The blueprint's blocks are kept in a world of their own
## (`ghost`, chunks only where there are some), so the mesher merges them as it merges
## the world's: a wall of five blocks is one wall. A chunk is meshed again when a cell of
## it (or on its rim) changes, the nearest first, a column at a time for at most BUDGET
## a frame (a phone is 4–5 times slower: a chunk at once took ~10 ms on a desktop), and
## only the chunks round the player are drawn. Drawn twice: first only into depth, then its colour over that, so only the
## nearest faces show and none is tinted twice. PlanView shows it in the build mode.

const WorldData := preload("res://src/shared/world/world_data.gd")
const ChunkMesher := preload("res://src/client/world/chunk_mesher.gd")
const WorldShader := preload("res://shaders/world.gdshader")
const Plans := preload("res://src/shared/game/plans.gd")
const Items := preload("res://src/shared/content/items.gd")
const Mat := preload("res://src/shared/content/materials.gd")

const CELL := WorldData.CELL
const CHUNK := WorldData.CHUNK
## Chunks round the player's whose blueprint is drawn (2 a 5 × 5 square).
const RADIUS := 2
## How long a frame meshes for at most (µs), as the world's chunks (ChunkStreamer).
const BUDGET := 1500
## The tint over the blocks' own colours (rgb, how much of it) and how much they hide
## what is behind (alpha).
const TINT := Color(0.5, 0.75, 1.0)
const TINT_SHARE := 0.6
const ALPHA := 0.7

var game
## The blueprint's blocks in a world of their own, at their own cells.
var ghost: WorldData
## The drawn chunks by key (Vector2i), and those to mesh again.
var _meshes := {}
var _dirty := {}
## The chunk being meshed and its key.
var _job: ChunkMesher.Job
var _job_key := Vector2i.ZERO
var _depth: ShaderMaterial
var _colour: ShaderMaterial


func _init(g) -> void:
	game = g


func _ready() -> void:
	game.plans.changed.connect(_on_changed)
	_reset()


## A copy of the world's shader that draws see-through, tinted and with no mark in the
## stencil (it is not solid for the player's silhouette).
static func ghost_shader() -> Shader:
	var s := Shader.new()
	s.code = WorldShader.code \
		.replace("render_mode world_vertex_coords, cull_back;",
			"render_mode world_vertex_coords, cull_back, blend_mix, depth_draw_always;") \
		.replace("stencil_mode write, compare_always, 1;", "") \
		.replace("#include \"res://shaders/common.gdshaderinc\"\n", "#include \"res://shaders/common.gdshaderinc\"\n"
			+ "uniform vec4 ghost_tint;\nuniform float ghost_alpha = 1.0;\n") \
		.replace("\tCOMPAT_COLORS\n}", "\tALBEDO = mix(ALBEDO, ALBEDO * 0.4 + ghost_tint.rgb * 0.6, ghost_tint.a);\n"
			+ "\tEMISSION = mix(EMISSION, ghost_tint.rgb * 0.15, ghost_tint.a);\n\tALPHA = ghost_alpha;\n\tCOMPAT_COLORS\n}")
	return s


## The materials, from the world's (its material tables), once it has them.
func _materials() -> bool:
	if _colour != null:
		return true
	if game.world_mat == null:
		return false
	var shader := ghost_shader()
	_depth = ShaderMaterial.new()
	_colour = ShaderMaterial.new()
	for m: ShaderMaterial in [_depth, _colour]:
		m.shader = shader
		for p in ["corner_shapes", "material_bits"]:
			m.set_shader_parameter(p, game.world_mat.get_shader_parameter(p))
		m.set_shader_parameter("ghost_tint", Color(TINT.r, TINT.g, TINT.b, TINT_SHARE))
	_depth.set_shader_parameter("ghost_alpha", 0.0)
	_colour.set_shader_parameter("ghost_alpha", ALPHA)
	_depth.next_pass = _colour
	return true


## The block blueprint cell `c` will be (Mat.AIR for none: ground to dig, a fence, a mark).
func block_of(c: Vector3i) -> int:
	var v: String = game.plans.cells.get(c, "")
	if v == "" or v == Plans.CUT or Plans.is_mark(v):
		return Mat.AIR
	var m := Mat.index(Items.get_item(v).get("place", ""))
	return m if m > 0 else Mat.AIR


## Every blueprint cell anew (on joining, a world loaded).
func _reset() -> void:
	ghost = WorldData.new(game.world.size_y)
	ghost.sea_level = game.world.sea_level
	for key: Vector2i in _meshes:
		_meshes[key].queue_free()
	_meshes.clear()
	_dirty.clear()
	_job = null
	_put(game.plans.cells.keys())


func _on_changed(cells: Array, _item: String) -> void:
	if cells.is_empty():
		_reset()
	else:
		_put(cells)


## Writes cells `cells` into the ghost world as the blueprint has them now and marks
## their chunks (and those beside a cell on a chunk's rim) to mesh again.
func _put(cells: Array) -> void:
	for c: Vector3i in cells:
		var m := block_of(c)
		var key := WorldData.chunk_key(c.x, c.z)
		if not ghost.has_chunk(key):
			if m == Mat.AIR:
				continue
			ghost.add_chunk(key)
		ghost.set_cell(c.x, c.y, c.z, m)
		ghost.set_form(c.x, c.y, c.z, int(game.plans.forms.get(c, 0)) if m != Mat.AIR else 0)
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				_dirty[WorldData.chunk_key(c.x + dx, c.z + dz)] = true


func _process(_delta: float) -> void:
	if not visible or game.player == null or not _materials():
		return
	var at := WorldData.chunk_key(floori(game.player.position.x / CELL), floori(game.player.position.z / CELL))
	for key: Vector2i in _meshes:
		_meshes[key].visible = absi(key.x - at.x) <= RADIUS and absi(key.y - at.y) <= RADIUS
	var t0 := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t0 < BUDGET and _work(at):
		pass


## All the chunks round the player meshed now (tools/shot.gd before a picture).
func finish() -> void:
	if game.player == null or not _materials():
		return
	var at := WorldData.chunk_key(floori(game.player.position.x / CELL), floori(game.player.position.z / CELL))
	while _work(at):
		pass


## Meshes a column of the chunk being meshed, or starts the nearest chunk round chunk
## `at` to mesh again; false when there is none.
func _work(at: Vector2i) -> bool:
	if _job != null:
		if ChunkMesher.step(_job, 1):
			_show(_job_key, ChunkMesher.finish(_job)[0])
			_job = null
		return true
	# The nearest chunk to mesh again.
	var best: Variant = null
	for key: Vector2i in _dirty:
		if absi(key.x - at.x) <= RADIUS and absi(key.y - at.y) <= RADIUS \
				and (best == null or (key - at).length_squared() < (best - at).length_squared()):
			best = key
	if best != null:
		_dirty.erase(best)
		if ghost.has_chunk(best):
			_job = ChunkMesher.start(ghost, best.x * CHUNK, best.y * CHUNK, CHUNK)
			_job_key = best
		else:
			_show(best, null)
		return true
	return false


## Shows `mesh` for chunk `key` of the ghost world (drops it when null: no blocks).
func _show(key: Vector2i, mesh: ArrayMesh) -> void:
	if mesh == null:
		if _meshes.has(key):
			_meshes[key].queue_free()
			_meshes.erase(key)
		return
	var mi: MeshInstance3D = _meshes.get(key)
	if mi == null:
		mi = MeshInstance3D.new()
		mi.material_override = _depth
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 16.0
		add_child(mi)
		_meshes[key] = mi
	mi.mesh = mesh
