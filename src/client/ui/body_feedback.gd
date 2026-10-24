extends Control
## How the screen answers what happens to the body (plan/design/ui.md, section 4): a
## hurt reddens the edges of the screen, shakes the camera the more the bigger it is
## (unless the setting «Тряска экрана» is off), buzzes the phone (Vibration) and puts "-N" over the player's head, a heal
## does the same in green, and food in amber with "+N" by the food icon. It watches the
## character's Vitals each frame, so it shows whatever changed them (hunger, water,
## animals, fire, food, bandages). A slow loss (hunger, drowning) is gathered and shown
## once it adds up to a whole point; the slow healing of a fed body shows nothing.
## Drawn under the rest of the interface, over the whole screen. `game` is the Main node.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const ItemIcons := preload("res://src/client/ui/item_icons.gd")
const Vibration := preload("res://src/client/ui/vibration.gd")
const Body := preload("res://src/shared/game/body.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")

## What a change of each kind looks like: frame and number colour, and icon.
const KINDS := {
	"hurt": [UiStyle.DANGER, "heart"],
	"heal": [UiStyle.GOOD, "heart"],
	"food": [UiStyle.ACCENT, "food"],
}
## A gain at least this big in one frame is shown (eating, a bandage); less is the slow
## healing of a fed body.
const SUDDEN := 0.5
## Seconds between two numbers of one kind, so a slow loss shows a number now and then.
const EVERY := 0.4
## Seconds the frame takes to fade, and how far (UI px) and how long a number rises.
const FADE := 1.0
const RISE := 14.0
const FLOAT_TIME := 1.1
## The frame: bands of UI pixels along the edges, each fainter inwards, over a faint
## wash of the whole screen.
const BANDS := [0.9, 0.65, 0.45, 0.28, 0.14]
const BAND := 5.0
const WASH := 0.12
## The camera shakes by a low-res pixel for each this many points of a hurt, up to
## SHAKE_MOST pixels.
const SHAKE_PER := 4.0
const SHAKE_MOST := 6.0

var game
## Health and satiety last frame (none yet: -1).
var _health := -1.0
var _satiety := -1.0
## Change not shown yet and seconds since the last number, by kind.
var _pending := {"hurt": 0.0, "heal": 0.0, "food": 0.0}
var _since := {"hurt": EVERY, "heal": EVERY, "food": EVERY}
## How strong the frame is now (0..1) and its colour.
var _frame := 0.0
var _frame_color := UiStyle.DANGER
## The numbers rising: {"node": HBoxContainer, "age": seconds}.
var _floats := []


func _init(g) -> void:
	game = g


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	var c = game.character
	if c == null:
		return
	var v = c.vitals
	if c.is_dead() or _health < 0.0:
		# Coming back to life is not a heal.
		_health = v.health
		_satiety = v.satiety
	else:
		_take("hurt", _health - v.health, 0.0)
		_take("heal", v.health - _health, SUDDEN)
		_take("food", v.satiety - _satiety, SUDDEN)
		_health = v.health
		_satiety = v.satiety
	for k in _pending:
		_since[k] += delta
		if _pending[k] >= 1.0 and _since[k] >= EVERY:
			_show(k, roundi(_pending[k]))
			_pending[k] = 0.0
			_since[k] = 0.0
	if _frame > 0.0:
		_frame = maxf(0.0, _frame - delta / FADE)
		queue_redraw()
	_move_floats(delta)


## Gathers `amount` of change of `kind`; a gain smaller than `least` in one frame is
## let go.
func _take(kind: String, amount: float, least: float) -> void:
	if amount > 0.0 and amount >= least:
		_pending[kind] += amount


## Shows a change of `n` points of `kind`: the frame, stronger for more, and its number.
func _show(kind: String, n: int) -> void:
	if n <= 0:
		return
	var strength := 0.6 + 0.4 * minf(n / 15.0, 1.0)
	if kind == "hurt" and n >= 2 and game.settings.values.shake:
		game.view.shake(clampf(n / SHAKE_PER, 1.0, SHAKE_MOST))
	if kind == "hurt" and n >= 2:
		Vibration.hurt(game, n)
	# A hurt is not hidden by a heal shown at the same time.
	if kind == "hurt" or _frame_color != UiStyle.DANGER or _frame < 0.15:
		_frame_color = KINDS[kind][0]
		_frame = maxf(_frame, strength)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 2)
	var icon := TextureRect.new()
	icon.texture = ItemIcons.picture(KINDS[kind][1])
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	row.add_child(icon)
	var label := UiStyle.label(("-%d" if kind == "hurt" else "+%d") % n, KINDS[kind][0])
	label.add_theme_color_override("font_outline_color", UiStyle.EDGE)
	label.add_theme_constant_override("outline_size", 4)
	row.add_child(label)
	add_child(row)
	# A number shown while others still rise stands above them.
	var young := _floats.filter(func(f: Dictionary) -> bool: return f.age < FLOAT_TIME * 0.5).size()
	_floats.append({"node": row, "age": 0.0, "lift": young * 12.0})
	_move_floats(0.0)


## Keeps the numbers over the player's head, rising and fading.
func _move_floats(delta: float) -> void:
	if _floats.is_empty():
		return
	var head: Vector3 = game.player.position + Vector3(0.0, Body.HEIGHT * WorldData.CELL + 0.25, 0.0)
	var at: Vector2 = (game.view.screen_of(head) - get_global_transform().origin) / get_global_transform().get_scale()
	for f in _floats.duplicate():
		f.age += delta
		var row: HBoxContainer = f.node
		if f.age >= FLOAT_TIME:
			_floats.erase(f)
			row.queue_free()
			continue
		var t: float = f.age / FLOAT_TIME
		row.reset_size()
		row.position = (at + Vector2(-row.size.x * 0.5, -row.size.y - f.lift - RISE * t)).floor()
		row.modulate.a = 1.0 if t < 0.6 else 1.0 - (t - 0.6) / 0.4


## The frame: bands along every edge of the whole screen (past the safe rect), the
## outer ones stronger.
func _draw() -> void:
	if _frame <= 0.0:
		return
	var s := get_global_transform().get_scale()
	var full := Rect2(-get_global_transform().origin / s, get_viewport_rect().size / s).grow(1)
	draw_rect(full, Color(_frame_color, WASH * _frame))
	for i in BANDS.size():
		var r := full.grow(-i * BAND)
		var col := Color(_frame_color, BANDS[i] * _frame)
		draw_rect(Rect2(r.position, Vector2(r.size.x, BAND)), col)
		draw_rect(Rect2(r.position.x, r.end.y - BAND, r.size.x, BAND), col)
		draw_rect(Rect2(r.position.x, r.position.y + BAND, BAND, r.size.y - 2 * BAND), col)
		draw_rect(Rect2(r.end.x - BAND, r.position.y + BAND, BAND, r.size.y - 2 * BAND), col)
