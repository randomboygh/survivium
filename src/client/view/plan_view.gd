extends MeshInstance3D
## The blueprint's ghost (Plans, decision 163) near the player (user 2026-11-22; until then
## a frame round each cell): its blocks as they will stand built, see-through and tinted
## blue (PlanBlocks), the ground to dig out a red body seen through the ground and a fence
## a plain blue one (PlanGhost), each merged with no seams between its cells, hidden above
## the level cut. The red and the fence are built again when the blueprint changes or the
## player walks REBUILD cells off. `game` is the Main node,
## its `plans` the client's copy. The farming mode's marks (Plans.is_mark) are drawn
## flat on the ground they mark, a square round its top in the colour of the work and
## its sign inside: furrows to till, a sprout to sow, a drop to water, a cross to reap.
## The blueprint shows only in the build mode, the marks only in the farming mode
## (2026-11-07: hidden out of them).

const WorldData := preload("res://src/shared/world/world_data.gd")
const UiStyle := preload("res://src/client/ui/ui_style.gd")
const CursorShader := preload("res://shaders/cursor.gdshader")
const Plans := preload("res://src/shared/game/plans.gd")
const PlanGhost := preload("res://src/client/view/plan_ghost.gd")
const PlanBlocks := preload("res://src/client/view/plan_blocks.gd")
const GhostShader := preload("res://shaders/plan_ghost.gdshader")
const CutShader := preload("res://shaders/plan_through.gdshader")
const CutMulShader := preload("res://shaders/plan_cut_mul.gdshader")

const CELL := WorldData.CELL
## Cells round the player whose ghost is drawn, and how far they walk before it is
## built again.
const REACH := 32
const REBUILD := 6
## Marks' lines stand this far over the top (half a pixel, as the cursor's).
const INSET := 0.5 / 16.0
## The colours of the farming marks by work (a mark to sow is any other value).
const MARK_COLORS := {Plans.TILL: Color("#d9a866"), Plans.WATER: Color("#5fb4ff"), Plans.REAP: Color("#f6d27a")}
const SOW_COLOR := UiStyle.GOOD
## The sign of each work inside its square, lines between points of the top (x, z 0..1).
const MARK_SIGNS := {
	Plans.TILL: [[Vector2(0.3, 0.2), Vector2(0.3, 0.8)], [Vector2(0.5, 0.2), Vector2(0.5, 0.8)],
		[Vector2(0.7, 0.2), Vector2(0.7, 0.8)]],
	Plans.WATER: [[Vector2(0.5, 0.25), Vector2(0.3, 0.6)], [Vector2(0.5, 0.25), Vector2(0.7, 0.6)],
		[Vector2(0.3, 0.6), Vector2(0.5, 0.75)], [Vector2(0.7, 0.6), Vector2(0.5, 0.75)]],
	Plans.REAP: [[Vector2(0.25, 0.25), Vector2(0.75, 0.75)], [Vector2(0.75, 0.25), Vector2(0.25, 0.75)]],
	"": [[Vector2(0.5, 0.25), Vector2(0.5, 0.75)], [Vector2(0.25, 0.5), Vector2(0.75, 0.5)]],
}
## The square of a mark, inside the top of its cell (0..1).
const MARK_SQUARE := [Vector2(0.1, 0.1), Vector2(0.9, 0.1), Vector2(0.9, 0.9), Vector2(0.1, 0.9)]

var game
var _lines := ImmediateMesh.new()
var _material := ShaderMaterial.new()
var _ghost := MeshInstance3D.new()
var _built := ShaderMaterial.new()
var _dug := ShaderMaterial.new()
var _blocks: Node3D
var _dirty := true
var _built_at := Vector3i(1 << 30, 0, 0)
## Which of the two modes were on when it was built (bit 0 building, bit 1 farming).
var _modes := 0


func _init(g) -> void:
	game = g
	mesh = _lines
	_material.shader = CursorShader
	_material.set_shader_parameter("color", Color(1, 1, 1, 0.75))
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 16.0
	# Its depth first, then its colour over it (plan_ghost.gdshader).
	_built.shader = GhostShader
	_built.set_shader_parameter("strength", 0.0)
	var colour := ShaderMaterial.new()
	colour.shader = GhostShader
	_built.next_pass = colour
	# The ground to dig: its green taken out, then the red over it.
	_dug.shader = CutMulShader
	var red := ShaderMaterial.new()
	red.shader = CutShader
	_dug.next_pass = red
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.extra_cull_margin = 16.0
	add_child(_ghost)
	_blocks = PlanBlocks.new(g)
	_blocks.visible = false
	add_child(_blocks)


func _ready() -> void:
	game.plans.changed.connect(_on_changed)


func _on_changed(_cells: Array, _item: String) -> void:
	_dirty = true


func _process(_delta: float) -> void:
	if game.player == null:
		return
	var at := Vector3i((game.player.position / CELL).floor())
	var modes := (1 if game.build != null and game.build.on else 0) | (2 if game.farm != null and game.farm.on else 0)
	if modes != _modes:
		_modes = modes
		_dirty = true
	if not _dirty and maxi(maxi(absi(at.x - _built_at.x), absi(at.z - _built_at.z)), absi(at.y - _built_at.y)) < REBUILD:
		return
	_dirty = false
	_built_at = at
	_build(at)


func _build(at: Vector3i) -> void:
	_lines.clear_surfaces()
	var cells: Dictionary = game.plans.cells
	var building := _modes & 1 != 0
	var started := false
	if _modes & 2 != 0:
		for c: Vector3i in cells:
			if not Plans.is_mark(cells[c]) or not _near(c, at):
				continue
			if not started:
				_lines.surface_begin(Mesh.PRIMITIVE_LINES)
				started = true
			_mark(c, cells[c])
	if started:
		_lines.surface_end()
	_ghost.mesh = null
	if building:
		_ghost.mesh = PlanGhost.build(cells, game.plans.forms, game.world,
			func(c: Vector3i) -> bool: return _plain(cells[c]) and _near(c, at), _built, _dug)
	_blocks.visible = building
	visible = started or building


## Whether blueprint cell value `v` is drawn by PlanGhost: ground to dig, a fence.
static func _plain(v: String) -> bool:
	return v == Plans.CUT or not Plans.is_mark(v) and Plans.is_fence(v)


## Whether cell `c` is near enough cell `at` to be drawn.
static func _near(c: Vector3i, at: Vector3i) -> bool:
	return maxi(maxi(absi(c.x - at.x), absi(c.z - at.z)), absi(c.y - at.y)) <= REACH


## Draws farming mark `v` on ground cell `c`: its square round the top and its sign.
func _mark(c: Vector3i, v: String) -> void:
	_lines.surface_set_color(MARK_COLORS.get(v, SOW_COLOR))
	for i in 4:
		_lines.surface_add_vertex(_top(c, MARK_SQUARE[i]))
		_lines.surface_add_vertex(_top(c, MARK_SQUARE[(i + 1) % 4]))
	for e: Array in MARK_SIGNS.get(v, MARK_SIGNS[""]):
		_lines.surface_add_vertex(_top(c, e[0]))
		_lines.surface_add_vertex(_top(c, e[1]))


## Point `p` (x, z 0..1) of the top of cell `c`, a hair over it, in world units.
static func _top(c: Vector3i, p: Vector2) -> Vector3:
	return Vector3(c.x + p.x, c.y + 1, c.z + p.y) * CELL + Vector3(0, INSET, 0)
