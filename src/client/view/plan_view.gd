extends MeshInstance3D
## The blueprint's ghost (Plans, decision 163): one-pixel lines in the cold blueprint
## colour round each ghost cell near the player, a grid of cells with the edges deep
## inside the ghost left out. Drawn
## with the cursor's shader (over everything, hidden above the level cut). Built again
## when the ghost changes or the player walks REBUILD cells off. `game` is the Main node,
## its `plans` the client's copy.

const WorldData := preload("res://src/shared/world/world_data.gd")
const UiStyle := preload("res://src/client/ui/ui_style.gd")
const CursorShader := preload("res://shaders/cursor.gdshader")
const Forms := preload("res://src/client/world/form_mesher.gd")

const CELL := WorldData.CELL
## Cells round the player whose ghost is drawn, and how far they walk before it is
## built again.
const REACH := 32
const REBUILD := 6
## Lines run this far inside the cell's edges (half a pixel, as the cursor's).
const INSET := 0.5 / 16.0
## The twelve edges of a cell, each as its two corners (0/1 per axis).
const EDGES := [
	[Vector3i(0, 0, 0), Vector3i(1, 0, 0)], [Vector3i(0, 1, 0), Vector3i(1, 1, 0)],
	[Vector3i(0, 0, 1), Vector3i(1, 0, 1)], [Vector3i(0, 1, 1), Vector3i(1, 1, 1)],
	[Vector3i(0, 0, 0), Vector3i(0, 1, 0)], [Vector3i(1, 0, 0), Vector3i(1, 1, 0)],
	[Vector3i(0, 0, 1), Vector3i(0, 1, 1)], [Vector3i(1, 0, 1), Vector3i(1, 1, 1)],
	[Vector3i(0, 0, 0), Vector3i(0, 0, 1)], [Vector3i(1, 0, 0), Vector3i(1, 0, 1)],
	[Vector3i(0, 1, 0), Vector3i(0, 1, 1)], [Vector3i(1, 1, 0), Vector3i(1, 1, 1)],
]

## The lines that show the form of a ghost cell that is not a cube (Plans.forms), for
## the form rising north (see Forms.turn): a ramp's diagonal on both sides, an upturned
## ramp's, the steps of stairs.
const FORM_LINES := {
	WorldData.FORM_RAMP: [[Vector3(0, 1, 0), Vector3(0, 0, 1)], [Vector3(1, 1, 0), Vector3(1, 0, 1)]],
	WorldData.FORM_UPPER: [[Vector3(0, 0, 0), Vector3(0, 1, 1)], [Vector3(1, 0, 0), Vector3(1, 1, 1)]],
	WorldData.FORM_STAIRS: [[Vector3(0, 0.5, 1), Vector3(0, 0.5, 0.5)], [Vector3(0, 0.5, 0.5), Vector3(0, 1, 0.5)],
		[Vector3(1, 0.5, 1), Vector3(1, 0.5, 0.5)], [Vector3(1, 0.5, 0.5), Vector3(1, 1, 0.5)],
		[Vector3(0, 1, 0.5), Vector3(1, 1, 0.5)], [Vector3(0, 0.5, 0.5), Vector3(1, 0.5, 0.5)]],
}

var game
var _lines := ImmediateMesh.new()
var _material := ShaderMaterial.new()
var _dirty := true
var _built_at := Vector3i(1 << 30, 0, 0)


func _init(g) -> void:
	game = g
	mesh = _lines
	_material.shader = CursorShader
	_material.set_shader_parameter("color", Color(UiStyle.COLD, 0.75))
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 16.0


func _ready() -> void:
	game.plans.changed.connect(_on_changed)


func _on_changed(_cells: Array, _item: String) -> void:
	_dirty = true


func _process(_delta: float) -> void:
	if game.player == null:
		return
	var at := Vector3i((game.player.position / CELL).floor())
	if not _dirty and maxi(maxi(absi(at.x - _built_at.x), absi(at.z - _built_at.z)), absi(at.y - _built_at.y)) < REBUILD:
		return
	_dirty = false
	_built_at = at
	_build(at)


func _build(at: Vector3i) -> void:
	_lines.clear_surfaces()
	var cells: Dictionary = game.plans.cells
	var started := false
	for c: Vector3i in cells:
		if maxi(maxi(absi(c.x - at.x), absi(c.z - at.z)), absi(c.y - at.y)) > REACH:
			continue
		for e: Array in EDGES:
			if hidden_edge(cells, c, e[0], e[1]):
				continue
			if not started:
				_lines.surface_begin(Mesh.PRIMITIVE_LINES)
				started = true
			_lines.surface_add_vertex(corner(c, e[0]))
			_lines.surface_add_vertex(corner(c, e[1]))
		var form: int = game.plans.forms.get(c, 0)
		for e: Array in FORM_LINES.get(form & 3, []):
			if not started:
				_lines.surface_begin(Mesh.PRIMITIVE_LINES)
				started = true
			_lines.surface_add_vertex(point(c, Forms.turn(e[0], form >> 2 & 3)))
			_lines.surface_add_vertex(point(c, Forms.turn(e[1], form >> 2 & 3)))
	if started:
		_lines.surface_end()
	visible = started


## Whether the edge from corner `a` to corner `b` of ghost cell `c` lies inside the
## ghost: the two cells beside `c` across it are ghost cells too.
static func hidden_edge(cells: Dictionary, c: Vector3i, a: Vector3i, b: Vector3i) -> bool:
	var along := 0 if a.x != b.x else (1 if a.y != b.y else 2)
	for axis in 3:
		if axis == along:
			continue
		var d := Vector3i.ZERO
		d[axis] = 1 if a[axis] == 1 else -1
		if not cells.has(c + d):
			return false
	return true


## Point `v` (0..1 per axis) of cell `c`, kept a line's inset inside it, in world units.
static func point(c: Vector3i, v: Vector3) -> Vector3:
	var p := Vector3(c) * CELL
	for axis in 3:
		p[axis] += lerpf(INSET, CELL - INSET, v[axis])
	return p


## The corner `k` (0/1 per axis) of cell `c`, a line's inset inside it, in world units.
static func corner(c: Vector3i, k: Vector3i) -> Vector3:
	var p := Vector3(c) * CELL
	for axis in 3:
		p[axis] += CELL - INSET if k[axis] == 1 else INSET
	return p
