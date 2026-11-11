extends Control
## The first part of the game screen's interface (hud.gd): its nodes and state, which every
## part uses (hud.gd's _ready builds the nodes), the small pieces it is built of (a panel,
## the hotbar's box and slots, a label of fixed width, an icon button, a menu button) and
## the pictures it draws itself (the bag's tab, the wind's arrow).
##
## The interface is one script split by topic (decision 168, as decision 145): hud_parts.gd
## <- hud_messages.gd <- hud_layout.gd <- hud_menus.gd <- hud.gd; each part extends the one
## before and calls only what it or an earlier part defines, and callers know only hud.gd.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const HotbarSlot := preload("res://src/client/ui/hotbar_slot.gd")
const Minimap := preload("res://src/client/ui/minimap.gd")
const MapView := preload("res://src/client/ui/map_view.gd")
const VitalsPanel := preload("res://src/client/ui/vitals_panel.gd")
const SleepScreen := preload("res://src/client/ui/sleep_screen.gd")
const PersonPanel := preload("res://src/client/ui/person_panel.gd")
const BodyFeedback := preload("res://src/client/ui/body_feedback.gd")
const InventoryWindow := preload("res://src/client/ui/inventory_window.gd")
const ChatBox := preload("res://src/client/ui/chat_box.gd")
const SignWindow := preload("res://src/client/ui/sign_window.gd")
const Protocol := preload("res://src/shared/net/protocol.gd")
const GestureWheel := preload("res://src/client/ui/gesture_wheel.gd")
const PersonCard := preload("res://src/client/ui/person_card.gd")
const BuildBar := preload("res://src/client/ui/build_bar.gd")
const FarmBar := preload("res://src/client/ui/farm_bar.gd")
const Lang := preload("res://src/shared/content/lang.gd")
const MARGIN := 8.0
const GAP := 4.0
const SLOT := 40
## The bag's tab on the hotbar: each slot of the bag a division of this many pixels, the
## free ones of this colour (see _fit_bag_meter).
const BAG_DIVISION := 6
const FREE_DIVISION := Color("#3a2c20")
## The warm gold a notice's panel is tinted (see notice).
const NOTICE_TINT := Color(1.0, 0.86, 0.55)
var game
## A refresh of the hotbar is asked for this frame (see _counts_later).
var _counts_due := false
var touch := false
var portrait := false
## The interface and the touch controls size settings, indices into UI_SIZES and
## CONTROL_SIZES.
var ui_size := 2
var control_size := 2
## The minimap size setting (an index into Minimap.SIDES) and whether the level buttons
## and the camera cross are shown (see set_corner).
var minimap_size := 1
var level_buttons := true
var camera_buttons := true
## The scale picked from the screen before the interface size setting (see fit).
var _screen_scale := 1.0

var _left: VBoxContainer
var _clock_icon: TextureRect
## An arrow by the weather icon where the wind blows while it is strong enough to
## slow walking against it.
var _wind: Control
var _wind_step := -1
var _clock: Label
## The season and the time, under the right end of the hotbar.
var _clock_panel: PanelContainer
var _toasts: VBoxContainer
## How wide a toast may be, in UI px: up to the buttons and the minimap on the right
## (see _place_top); a longer one wraps.
var _toast_room := 200.0
var perf: PanelContainer
var vitals: VitalsPanel
## The dimmed screen while the character sleeps (SleepScreen).
var sleep: SleepScreen
## The button on the clock that lies down to sleep.
var _sleep_button: Button
## The room the clock's row keeps for «zz» over its right end, and the button's size,
## the clock's height.
var _sleep_room: Control
const SLEEP_SIZE := Vector2(24, 18)
## The red frame and the numbers over the player when the body is hurt, healed or fed.
var feedback: BodyFeedback
var bag: InventoryWindow
## The chat on a server (hidden in single player), and its button.
var chat: ChatBox
## The window of a sign tapped (SignWindow), null while none is open.
var sign_window: Control = null
## The wheel of gestures (GestureWheel), null while closed, and its button.
var gesture_wheel: Control = null
var _gesture_button: Button
## The card of another player tapped, and of an invitation to a team.
var person: PersonCard
var _chat_button: Button
var _bag_button: Button
## The tab on the hotbar with how many slots are taken and the load (a tap opens the
## bag).
var _bag_meter: Button
var _top: HBoxContainer
var _stats_button: Button
var _test_button: Button
var _menu_button: Button
var _level: BoxContainer
var minimap: Minimap
var map_view: MapView
var _level_label: Button
## The arrows beside it, dimmed past the levels that may be looked at (see
## ChunkStreamer.view_range).
var _level_up: Button
## The blueprint's height buttons (shown while a wall or a room is drawn).
## The build mode's bar, in the hotbar's place while the mode is on (BuildBar).
var build_bar: BuildBar
## The farming mode's bar, in the hotbar's place while that mode is on (FarmBar).
var farm_bar: FarmBar
var _level_down: Button
## The camera buttons under the minimap: turn, tilt, and back to the default view
## (it shows the turn and the tilt).
var _camera: GridContainer
var _camera_reset: Button
## The text of the middle (and of the level), a label over the button so the text
## never makes it wider (see _fixed_label).
var _camera_label: Label
var _level_text: Label
var _camera_text := ""
## The colour last given to the level label's text (none yet: transparent).
var _level_ink := Color(0, 0, 0, 0)
var _bar: PanelContainer
var _hand_left
var _hand_right
var _slots := []
var _bar_row: HBoxContainer
var _prev_button: Button
var _next_button: Button
## The first hotbar slot shown and how many are shown.
var _first := 0
var _visible_slots := 8
## The finger dragging the hotbar slots along (-1 none), its x in the bar where the
## slots last moved, and whether it has moved far enough to be a drag, not a tap.
var _swipe := -1
var _swipe_x := 0.0
var _swiped := false
var stick
var _action: Button
var _jump: Button
var _keys: PanelContainer
var _tip: PanelContainer
var _tip_label: Label
var _loading: PanelContainer
var _loading_label: Label
var _menu: PanelContainer
var _settings: Control = null
## Dims the game behind the menu and keeps taps from reaching it.
var _shade: ColorRect
var _menu_buttons := {}


## The things placed whose marks the minimap shows (see _update_marks), and whether
## they or the sacks changed since the marks were made.
var _marks_of: Object = null
var _marks_dirty := true
var _sacks_seen: Array[Vector3] = []
## The vessels last marked on the map: [item, where]… (see _update_marks).
var _vessels_seen: Array = []


func _panel(parent: Node) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p


## The hotbar frame is thinner than a panel so the slots sit close to its edge.
func _bar_box() -> StyleBox:
	var b := UiStyle.panel()
	b.content_margin_left = 4
	b.content_margin_top = 4
	b.content_margin_right = 4
	b.content_margin_bottom = 4
	return b


func _slot(parent: Node, action: Callable):
	var s = HotbarSlot.new(SLOT)
	s.pressed.connect(action)
	parent.add_child(s)
	return s


## The look of a big touch button: an octagon of `fill` with a lip of `shade`, pressed
## down while held; `ink` for its words.
func _octagon_look(b: Button, fill: Color, shade: Color, ink: Color) -> void:
	for state in ["normal", "hover", "disabled"]:
		b.add_theme_stylebox_override(state, UiStyle.octagon(fill, shade))
	for state in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, UiStyle.octagon(fill, shade, true))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, ink)


## Frames a helper button like the others but see-through inside, so it hides little
## of the world: the level and camera buttons.
func _see_through(b: Button) -> void:
	for state in ["normal", "hover", "disabled", "focus"]:
		b.add_theme_stylebox_override(state, UiStyle.frame())
	for state in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, UiStyle.frame(true))
	b.add_theme_color_override("font_outline_color", UiStyle.EDGE)
	b.add_theme_constant_override("outline_size", 4)
	b.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.3))


## A label over button `b`, filling it, its text centred and outlined like the
## see-through buttons': a long text spills over the frame instead of widening the
## button, so the buttons of the corner keep their size.
func _fixed_label(b: Button) -> Label:
	var l := UiStyle.label()
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Its two lines apart, the font's own lines touch.
	l.add_theme_constant_override("line_spacing", 4)
	l.add_theme_color_override("font_outline_color", UiStyle.EDGE)
	l.add_theme_constant_override("outline_size", 4)
	b.add_child(l)
	return l


func _icon_button(parent: Node, icon: String, tip: String, action: Callable) -> Button:
	var b := Button.new()
	b.icon = UiStyle.icon(icon) if icon != "" else null
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(40, 40)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_stylebox_override("normal", UiStyle.panel())
	b.add_theme_stylebox_override("hover", UiStyle.panel())
	if action.is_valid():
		b.pressed.connect(action)
	parent.add_child(b)
	return b


func _add_menu_button(parent: Node, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(200, 30)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(action)
	parent.add_child(b)
	return b


## The tab on the hotbar, in the clock's frame: a bar of a division a slot of the bag,
## all of BAG_DIVISION pixels whatever the bag (more of them for a bigger one), those
## taken filled (warmer the fuller the bag), the free ones a little lighter than the
## well, and over it the weight of the limit (red past it).
func _draw_bag_meter() -> void:
	var inv = game.character.inventory
	var c: Control = _bag_meter
	var taken := 0
	for s in inv.slots:
		if s != null:
			taken += 1
	var n: int = maxi(inv.slots.size(), 1)
	var inner := Rect2(Vector2(5, 4), c.size - Vector2(10, 8))
	c.draw_rect(inner, UiStyle.WELL)
	# From the left end, a pixel apart (_fit_bag_meter makes the tab as wide as they are).
	for i in n:
		var x0 := inner.position.x + i * (BAG_DIVISION + 1.0)
		var fill: Color = bar_shade(float(i + 1) / n) if i < taken else FREE_DIVISION
		c.draw_rect(Rect2(x0, inner.position.y, BAG_DIVISION, inner.size.y), fill)
	UiStyle.draw_weight(c, inner.grow_individual(-3, 0, -3, 0), inv.weight(), inv.weight_limit)
	c.tooltip_text = Lang.f("[bag_of_slots_taken_of]", [taken, inv.slots.size(), inv.weight(), inv.weight_limit])


## The fill of a division of the bag's bar at share `k` of the slots (0..1): the skills'
## brown, a little warmer towards the last slots.
static func bar_shade(k: float) -> Color:
	return PersonPanel.BAR_FILL.lerp(Color("#9a5a2a"), clampf(k, 0.0, 1.0) * 0.8)


func _draw_wind() -> void:
	var a := _wind_step * PI / 4.0
	var d := Vector2(roundf(cos(a)), roundf(sin(a)))
	var mid := (_wind.size * 0.5).floor() + Vector2(0.5, 0.5)
	var tip := mid + d * 4.0
	_wind.draw_line(mid - d * 5.0, tip, UiStyle.INK, 1.0)
	for side: float in [-1.0, 1.0]:
		var back := Vector2(roundf(cos(a + side * PI * 0.75)), roundf(sin(a + side * PI * 0.75)))
		_wind.draw_line(tip, tip + back * 3.0, UiStyle.INK, 1.0)


func _set_icon(rect: TextureRect, name: String) -> void:
	var t := UiStyle.icon(name)
	if rect.texture != t:
		rect.texture = t
