extends ScrollContainer
## The tab «Земля» of the inventory window (InventoryWindow), shown while the player
## stands on land claimed (Land.here; the user's asks 2026-11-02). On their own land:
## what they let their team and the others do on all of it, a row for each of
## Territory.ACTIONS with «можно» / «нельзя» for each, lit in the land's colour
## (Land.set_rights, a tap turns one over at once), and at the bottom the colour of
## their land (UiStyle.LAND_COLORS: the borders on the ground and the maps, these
## buttons); «Забрать столб» is a button in the window's head by the cross
## (`head_buttons`, as a chest's or a station's). On their team's land the same rights,
## shown only; on another's, its name and what the player may do there. It scrolls when
## the screen is lower than it (InventoryWindow sets its height), its rows inset as the
## settings' (UiStyle.inset). `game` is the Main node.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const DragScroll := preload("res://src/client/ui/drag_scroll.gd")
const TabRow := preload("res://src/client/ui/tab_row.gd")
const Territory := preload("res://src/shared/game/territory.gd")
const Protocol := preload("res://src/shared/net/protocol.gd")

## The width of each button of the rights; the names take the rest.
const CELL_WIDTH := 84

var game
## What is shown, to build it again only when that changes.
var _shown := ""
var _box: VBoxContainer
## Called when what it shows changed, to lay the window out again.
var on_layout := Callable()
## The buttons for the window's head (InventoryWindow puts them by the cross): «Забрать
## столб» on one's own land.
var head_buttons: HBoxContainer
## The centre of the claim whose post «Забрать столб» takes.
var _post := Vector3i.ZERO


func _init(g) -> void:
	game = g
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 4)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(UiStyle.inset(_box))
	DragScroll.attach(self)
	head_buttons = HBoxContainer.new()
	head_buttons.add_theme_constant_override("separation", 4)
	head_buttons.visible = false
	var take := TabRow.icon_button(UiStyle.icon("take"), "Забрать столб в сумку", func() -> void: _take_post(_post))
	take.custom_minimum_size = Vector2(30, 30)
	head_buttons.add_child(take)


## The height the page would take whole.
func full_height() -> float:
	return get_child(0).get_combined_minimum_size().y


func _ready() -> void:
	game.land.changed.connect(refresh)


## Builds the page again for the land the player stands in (when it is shown and what
## it shows changed).
func refresh() -> void:
	if not is_visible_in_tree():
		return
	var land = game.land
	var claim: Dictionary = land.here()
	head_buttons.visible = not claim.is_empty() and claim.by == land.me()
	_post = claim.get("center", Vector3i.ZERO)
	var key := str([claim.get("id", 0), claim.get("name", ""), land.copy.rights_of(claim.get("by", 0)),
		land.copy.color_of(claim.get("by", 0)), land.own(claim), claim.get("weak", 0)])
	if key == _shown:
		return
	_shown = key
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	if claim.is_empty():
		_note("Вы не на размеченной земле")
		_laid()
		return
	var mine: bool = claim.by == land.me()
	var color: Color = land.color(claim)
	if not land.own(claim):
		_box.add_child(UiStyle.label("Земля «%s»" % claim.name, color))
		var may: Array = land.may_here(claim)
		if int(claim.get("weak", 0)) > 0:
			_note("Земля заброшена: хозяева давно не заходили, охрана ослабла")
		_note("Здесь можно: " + ", ".join(may) if not may.is_empty() else "Здесь ничего нельзя")
		_laid()
		return
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	_box.add_child(head)
	_cell(head, "", 0, true)
	_cell(head, "Команда", CELL_WIDTH)
	_cell(head, "Остальные", CELL_WIDTH)
	var r: Array = land.copy.rights_of(claim.by)
	for i in Territory.ACTIONS.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		_box.add_child(row)
		var what := UiStyle.label(Territory.TITLES[Territory.ACTIONS[i]])
		what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		what.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		what.clip_text = true
		row.add_child(what)
		for who in 2:
			var on: bool = int(r[who]) & (1 << i) != 0
			var b := TabRow.small_button("можно" if on else "нельзя", _flip.bind(who, i))
			b.custom_minimum_size = Vector2(CELL_WIDTH, 30)
			if on:
				UiStyle.tint(b, color)
			b.disabled = not mine
			row.add_child(b)
	if mine:
		_note("Права и цвет — на всей вашей земле. Двери и ручные звери появятся позже.")
		_colors(land.my_color())
	else:
		_note("Права задаёт тот, кто поставил столб.")
	_laid()


func _laid() -> void:
	if on_layout.is_valid():
		on_layout.call_deferred()


## The row of colours to pick from, the one picked framed.
func _colors(picked: int) -> void:
	var gap := Control.new()
	gap.custom_minimum_size.y = 6
	_box.add_child(gap)
	_box.add_child(UiStyle.label("Цвет земли", UiStyle.MUTED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_box.add_child(row)
	for i in UiStyle.LAND_COLORS.size():
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(30, 30)
		b.tooltip_text = "Цвет вашей земли"
		UiStyle.tint(b, UiStyle.LAND_COLORS[i])
		if i == picked:
			b.icon = UiStyle.icon("check")
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.pressed.connect(game.land.set_color.bind(i))
		row.add_child(b)


## Turns over right `bit` for the team (`who` 0) or the others (1).
func _flip(who: int, bit: int) -> void:
	var r: Array = game.land.my_rights().duplicate()
	r[who] = int(r[who]) ^ (1 << bit)
	game.land.set_rights(r[0], r[1])


func _take_post(cell: Vector3i) -> void:
	game.net.request(Protocol.PROP_TAKE, [cell]).then(func(v: Variant) -> void:
		if not (v is bool and v):
			game.hud.toast("Подойдите к столбу, чтобы забрать его"))


func _note(text: String) -> void:
	var l := UiStyle.label(text, UiStyle.MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(80, 0)
	_box.add_child(l)


func _cell(row: Node, text: String, width: int, fill := false) -> void:
	var l := UiStyle.label(text, UiStyle.MUTED)
	l.custom_minimum_size = Vector2(width, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if fill:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
