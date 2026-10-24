extends RefCounted
## What the player's body sounds like: a step every stride on what the feet stand on
## (the material's `step`, snow when it lies on the open ground, a splash in shallow
## water), strokes when swimming, a jump, a landing as hard as the fall, a splash into
## deep water. `game` is the Main node; Sound runs it each frame.

const Mat := preload("res://src/shared/content/materials.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const Body := preload("res://src/shared/game/body.gd")

const CELL := WorldData.CELL
## World units walked from one step to the next (two a walk cycle of the figure).
const STRIDE := 1.0
## Seconds between strokes while swimming.
const STROKE := 0.75
## Falling this fast (cells a second) lands with a thud; MAX_FALL is the loudest.
const LAND_SPEED := 9.0
## Snow lying this deep sounds under the feet on the open ground.
const SNOW_UNDERFOOT := 0.35
## Ground that snow covers.
const SNOWY := ["core:grass", "core:dirt", "core:sand", "core:stone", "core:scree", "core:clay"]

var game
var _last := Vector3.INF
var _walked := 0.0
var _stroke := 0.0
var _was_on_ground := true
var _was_in_water := false
var _fall := 0.0


func _init(g) -> void:
	game = g


func update(delta: float) -> void:
	var player = game.player
	var body = player.body
	var p: Vector3 = player.position
	if _last == Vector3.INF or game.character.is_dead():
		_last = p
		return
	var moved := Vector2(p.x - _last.x, p.z - _last.z).length()
	_last = p
	var sound = game.sound
	if body.jumped:
		sound.play("jump", p)
	var in_water: bool = body.water_depth > 0.0
	if body.on_ground and not _was_on_ground and _fall > LAND_SPEED:
		var hard := clampf((_fall - LAND_SPEED) / (Body.MAX_FALL - LAND_SPEED), 0.0, 1.0)
		sound.play("splash" if in_water else "land", p, 0.5 + 0.5 * hard)
	elif in_water and not _was_in_water and _fall > LAND_SPEED:
		sound.play("splash", p)
	_fall = -body.velocity_y if not body.on_ground else 0.0
	_was_on_ground = body.on_ground
	_was_in_water = in_water
	if body.swimming:
		_stroke -= delta
		if moved > 0.0 and _stroke <= 0.0:
			_stroke = STROKE
			sound.play("swim", p)
		return
	if not body.on_ground:
		return
	_walked += moved
	if _walked < STRIDE:
		return
	_walked = 0.0
	var id := _underfoot(p, in_water)
	if id != "":
		sound.play(id, p)


## The step sound of what the feet at `p` stand on.
func _underfoot(p: Vector3, in_water: bool) -> String:
	if in_water:
		return "step_water"
	var c := Vector3i((p / CELL + Vector3(0.0, -0.1, 0.0)).floor())
	var m: int = game.world.get_cell(c.x, c.y, c.z)
	if m <= 0 or m >= Mat.COUNT:
		return ""
	var rec: Dictionary = Mat.RECORDS[m]
	if game.clock.snow > SNOW_UNDERFOOT and not game.chunks.indoor and rec.id in SNOWY:
		return "step_snow"
	return rec.step
