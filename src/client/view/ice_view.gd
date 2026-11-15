extends Node
## The ice of frozen water as the shaders draw it (shaders/ice.gdshaderinc, the user's ask
## of 2026-11-15): the holes cut in it near the player (WorldData.ice_holes, open or with a
## crust) and the fires that thaw the frost round them, given to the water's material and
## to the fish's (Creatures.fish_materials, which also take how much the water is iced
## over: a fish under the ice shows faint, clearer under clear ice and in a hole). Looked
## at every LOOK seconds and when the holes change (holes_changed), set only on a change.
## `game` is the Main node.

const PixelView := preload("res://src/client/view/pixel_view.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")

const CELL := WorldData.CELL
## Seconds between two looks.
const LOOK := 0.25
## Holes and fires given to the shaders at most (ice.gdshaderinc), the nearest the player.
const HOLES := 8
const THAWS := 4
## How far round a burning fire the frost on the ice is thawed, world units.
const THAW_REACH := 1.4

var game
var _wait := 0.0
var _holes := PackedVector4Array()
var _thaw := PackedVector4Array()
var _ice := -1.0
## The fish materials last given the ice (they are made again on a hot reload).
var _fish: Array[ShaderMaterial] = []


## The holes changed (Protocol.ICE_HOLES): looked at on the next frame.
func holes_changed() -> void:
	_wait = 0.0


func _process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0 or game.world == null or game.water_mat == null or game.player == null:
		return
	_wait = LOOK
	var ice: float = game.clock.ice() if game.clock != null else 0.0
	var holes := PackedVector4Array()
	var thaw := PackedVector4Array()
	if ice > 0.0:
		holes = _near_holes(game.player.position)
		thaw = _near_fires(game.player.position)
	holes.resize(HOLES)
	thaw.resize(THAWS)
	var fish: Array[ShaderMaterial] = game.creatures.fish_materials() if game.creatures != null else []
	var fresh := fish.size() != _fish.size() or (not fish.is_empty() and fish[0] != _fish[0])
	ice = snappedf(ice, 0.02)
	if not fresh and holes == _holes and thaw == _thaw and ice == _ice:
		return
	_fish = fish
	_holes = holes
	_thaw = thaw
	_ice = ice
	for m: ShaderMaterial in [game.water_mat] + fish:
		m.set_shader_parameter("ice_holes", holes)
		m.set_shader_parameter("ice_thaw", thaw)
	for m in fish:
		m.set_shader_parameter("ice_amount", ice)


## The holes nearest `at` (world units): their middles and 1 open, 0.5 crusted.
func _near_holes(at: Vector3) -> PackedVector4Array:
	var near: Array = []
	for col: Vector2i in game.world.ice_holes:
		var mid := Vector2(col.x + 0.5, col.y + 0.5) * CELL
		near.append([mid.distance_squared_to(Vector2(at.x, at.z)), mid, 1.0 if game.world.ice_holes[col] >= 0.0 else 0.5])
	near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var out := PackedVector4Array()
	for n: Array in near.slice(0, HOLES):
		out.append(Vector4(n[1].x, n[1].y, n[2], 0.0))
	return out


## The burning fires nearest `at`, and how far round each the frost is thawed.
func _near_fires(at: Vector3) -> PackedVector4Array:
	var out := PackedVector4Array()
	if game.effects == null:
		return out
	var near: Array = []
	for f: Dictionary in game.effects.fires:
		var p: Vector3 = f.at
		if f.get("fuel", 1.0) > 0.02:
			near.append([Vector2(p.x - at.x, p.z - at.z).length_squared(), p])
	near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for n: Array in near.slice(0, THAWS):
		out.append(Vector4(n[1].x, n[1].z, THAW_REACH, 0.0))
	return out
