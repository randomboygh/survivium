extends Control
## What a campfire has left to burn, as a small bar over it: shown once the player has
## stood by a fire that burns on fuel (Placed.fuel_share) for STAY seconds, and gone as
## they walk off. Drawn by the HUD under the rest of the interface, over the whole screen.
## `game` is the Main node.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const Items := preload("res://src/shared/content/items.gd")
const Placed := preload("res://src/shared/game/placed.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")

## How near (world units, from the fire's middle) the player stands by it, and for how
## many seconds, before the bar shows; how fast it fades in and out (per second).
const NEAR := 3.0 * WorldData.CELL
const STAY := 2.0
const FADE := 4.0
## The bar's size in UI pixels, and how high over the fire's middle (world units) it is.
const SIZE := Vector2(24, 4)
const LIFT := 1.6 * WorldData.CELL
const FLAME := Color(1.0, 0.62, 0.2)
const LOW := Color(0.85, 0.3, 0.15)
const EMPTY := Color(0.1, 0.08, 0.07, 0.8)

var game
## The fire the player stands by, seconds they have stood there, and how much of the bar
## shows (0..1).
var _fire := {}
var _stood := 0.0
var _shown := 0.0


func _init(g) -> void:
	game = g


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	var near := _fire_near()
	if not is_same(near, _fire):
		_fire = near
		_stood = 0.0
	if not _fire.is_empty():
		_stood += delta
	var want := 1.0 if not _fire.is_empty() and _stood >= STAY else 0.0
	var was := _shown
	_shown = move_toward(_shown, want, FADE * delta)
	if _shown > 0.0 or was > 0.0:
		queue_redraw()


## The fire on fuel nearest the player within NEAR, {} for none.
func _fire_near() -> Dictionary:
	if game.player == null or game.placed == null:
		return {}
	var at: Vector3 = game.player.position
	var best := {}
	var best_d := NEAR
	for e: Dictionary in game.placed.things:
		if not Placed.is_fire(e) or Items.get_item(e.item).get("fuel_max", 0.0) <= 0.0:
			continue
		var d := Placed.center(e).distance_to(at)
		if d <= best_d:
			best_d = d
			best = e
	return best


func _draw() -> void:
	if _shown <= 0.0 or _fire.is_empty():
		return
	var t := get_global_transform()
	var at: Vector2 = (game.view.screen_of(Placed.center(_fire) + Vector3(0.0, LIFT, 0.0)) - t.origin) / t.get_scale()
	var box := Rect2((at - SIZE * 0.5).floor(), SIZE)
	var share := Placed.fuel_share(_fire)
	var a := _shown
	draw_rect(box.grow(1), Color(UiStyle.EDGE, a))
	draw_rect(box, Color(EMPTY, EMPTY.a * a))
	if share > 0.0 and _fire.lit:
		var fill := Rect2(box.position, Vector2(maxf(1.0, roundf(box.size.x * share)), box.size.y))
		draw_rect(fill, Color(FLAME if share > 0.2 else LOW, a))
