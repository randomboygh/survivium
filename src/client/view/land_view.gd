extends MeshInstance3D
## The borders of the land claimed (plan/design/territory-pvp.md, decision 101): thin
## strips over the ground inside the edges of a claim's squares near the player, in its
## owner's colour (Land.color, UiStyle.LAND_COLORS): the player's own land (and their
## team's) only while they paint it (Land.painting, a tap on their post), its squares
## shaded too; another's only while the player stands in it (Land.here; the user's
## asks 2026-11-02). Each corner lies on the ground there (within the claim's levels,
## at the centre's height over water). Built again when the land
## changes or the player walks REBUILD squares off. `game` is the Main node.

const WorldData := preload("res://src/shared/world/world_data.gd")
const Territory := preload("res://src/shared/game/territory.gd")
const LandShader := preload("res://shaders/land.gdshader")

const CELL := WorldData.CELL
## Squares round the player whose edges are drawn, and how far they walk before the
## lines are built again.
const REACH := 40
const REBUILD := 8
## How high over the ground the lines run, in cells.
const LIFT := 0.06
## How wide a border is, in cells (it runs inside the claim's edge), and how strong the
## shade over each square of one's own while painting.
const WIDTH := 0.3
const FILL := 0.3
const SIDES := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var game
var _lines := ImmediateMesh.new()
var _material := ShaderMaterial.new()
var _dirty := true
var _built_at := Vector2i(1 << 30, 0)


func _init(g) -> void:
	game = g
	mesh = _lines
	_material.shader = LandShader
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 16.0


func _ready() -> void:
	game.land.changed.connect(_on_changed)


func _on_changed() -> void:
	_dirty = true


func _process(_delta: float) -> void:
	if game.player == null or game.world == null:
		return
	var p: Vector3 = game.player.position
	var at := Vector2i(floori(p.x / CELL) >> 1, floori(p.z / CELL) >> 1)
	if not _dirty and maxi(absi(at.x - _built_at.x), absi(at.y - _built_at.y)) < REBUILD:
		return
	_dirty = false
	_built_at = at
	_build(at)


func _build(at: Vector2i) -> void:
	_lines.clear_surfaces()
	var land = game.land
	var squares: Dictionary = land.copy.squares
	var painting: bool = land.painting
	var started := false
	var mine := {}
	var here: Dictionary = land.here()
	for sq: Vector2i in squares:
		if maxi(absi(sq.x - at.x), absi(sq.y - at.y)) > REACH:
			continue
		var id: int = squares[sq]
		var claim: Dictionary = land.copy.claims.get(id, {})
		if claim.is_empty():
			continue
		if not mine.has(id):
			mine[id] = land.own(claim)
		var own: bool = mine[id]
		if own and not painting or not own and here.get("id", 0) != id:
			continue
		if not started:
			_lines.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			started = true
		var color: Color = land.color(claim)
		if own:
			var a := Vector2(sq * Territory.SQUARE)
			var s := float(Territory.SQUARE)
			_quad([a, a + Vector2(s, 0.0), a + Vector2(s, s), a + Vector2(0.0, s)], claim, Color(color.lightened(0.4), FILL))
		for d: Vector2i in SIDES:
			if squares.get(sq + d, 0) == id:
				continue
			var ends := _edge(sq, d)
			var inward := -Vector2(d) * WIDTH
			_quad([ends[0], ends[1], ends[1] + inward, ends[0] + inward], claim, Color(color, 0.9))
	if started:
		_lines.surface_end()


## The two corners (in cells, x and z) of side `d` of square `sq`.
static func _edge(sq: Vector2i, d: Vector2i) -> Array:
	var s := Territory.SQUARE
	var a := Vector2(sq * s)
	var b := a + Vector2(s, s)
	match d:
		Vector2i(1, 0):
			return [Vector2(b.x, a.y), Vector2(b.x, b.y)]
		Vector2i(-1, 0):
			return [Vector2(a.x, a.y), Vector2(a.x, b.y)]
		Vector2i(0, 1):
			return [Vector2(a.x, b.y), Vector2(b.x, b.y)]
	return [Vector2(a.x, a.y), Vector2(b.x, a.y)]


## A quad over the ground of `claim` through corners `c` (cells, in order round it), as
## two triangles.
func _quad(c: Array, claim: Dictionary, color: Color) -> void:
	var p: Array[Vector3] = []
	for v: Vector2 in c:
		p.append(_on_ground(v, claim))
	for i: int in [0, 1, 2, 0, 2, 3]:
		_lines.surface_set_color(color)
		_lines.surface_add_vertex(p[i])


## The point of the ground at corner `p` (cells) in world units, within the claim's
## levels; at the centre's height where there is none.
func _on_ground(p: Vector2, claim: Dictionary) -> Vector3:
	var y: float = game.world.ground_height(p.x - 0.01, p.y - 0.01)
	var top: float = claim.center.y + 8.0
	var low: float = claim.center.y - 8.0
	if y < 0.0 or y > top or y < low:
		y = claim.center.y
	return Vector3(p.x, y + LIFT, p.y) * CELL
