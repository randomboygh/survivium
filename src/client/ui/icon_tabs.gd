extends VBoxContainer
## A column of small square tabs with pictures beside a window's cells (the kinds of
## items in the bag and the craft tab, the chests near): the chosen one lit amber, a
## tooltip naming each. `picked` gives the key of the tab tapped. Past six tabs (or as
## many as fit beside the cells, fit_height) the column scrolls as the hotbar does
## (ScrollColumn).

const TabRow := preload("res://src/client/ui/tab_row.gd")
const UiStyle := preload("res://src/client/ui/ui_style.gd")
const ItemIcons := preload("res://src/client/ui/item_icons.gd")
const Items := preload("res://src/shared/content/items.gd")
const ScrollColumn := preload("res://src/client/ui/scroll_column.gd")

signal picked(key: String)

## The width (and height) of a tab, in UI pixels.
const SIDE := 28

## The key of the tab chosen.
var chosen := ""
var _keys: Array = []
var _buttons := {}
var _lit := "-"
var _column: ScrollColumn


func _init() -> void:
	add_theme_constant_override("separation", 2)
	custom_minimum_size.x = SIDE
	_column = ScrollColumn.new(SIDE)
	add_child(_column)


## Shows as many tabs as fit `h` UI pixels of height beside the cells, the rest
## scrolling (ScrollColumn.fit_height).
func fit_height(h: float) -> void:
	_column.fit_height(h)


## Shows tabs `keys` with pictures `icons` and tooltips `tips` (key -> each); a chosen
## tab that is gone gives way to the first. True when that changed what is chosen.
func set_tabs(keys: Array, icons: Dictionary, tips: Dictionary) -> bool:
	var was := chosen
	if not keys.has(chosen):
		chosen = keys[0] if not keys.is_empty() else ""
	if keys != _keys:
		# The tabs kept stay as they are, lit or not (several kinds come at once when a
		# craft teaches a dozen recipes, and making and lighting every tab anew took a
		# frame's share): only the new ones are made, and the column is laid out once.
		_keys = keys.duplicate()
		var kept := {}
		var list := []
		for k in keys:
			var b: Button = _buttons.get(k)
			if b == null:
				b = TabRow.icon_button(icons.get(k), tips.get(k, ""), func() -> void: pick(k))
				b.custom_minimum_size = Vector2(SIDE, SIDE - 2)
			kept[k] = b
			list.append(b)
		_buttons = kept
		_column.set_items(list)
		_lit = "-"
	else:
		for k in keys:
			_buttons[k].icon = UiStyle.centred(icons.get(k))
	_light()
	return chosen != was


## Tooltip `tip` on tab `key`.
func set_tip(key: String, tip: String) -> void:
	if _buttons.has(key):
		_buttons[key].tooltip_text = tip


func pick(key: String) -> void:
	if _column.swiped:
		_column.swiped = false
		return
	select(key)
	picked.emit(key)


## Lights tab `key` without telling anyone.
func select(key: String) -> void:
	chosen = key
	_light()


func _light() -> void:
	if _lit == chosen:
		return
	_lit = chosen
	# Only the tabs whose light changes are styled again (each style set lays the
	# button out anew).
	for k in _buttons:
		var b: Button = _buttons[k]
		var on: bool = k == chosen
		if b.get_meta("lit", false) != on:
			TabRow.light(b, on)
			b.set_meta("lit", on)
	if _buttons.has(chosen):
		_column.reveal(_keys.find(chosen))


## The kinds of items (see Items.CATEGORIES) with «Все» ("") first, of those in
## `have` (kind -> true): the keys, pictures and names for set_tabs.
static func kinds(have: Dictionary) -> Array:
	var keys := [""]
	for k in Items.CATEGORIES:
		if have.has(k):
			keys.append(k)
	# Each category shows the picture of its first loaded item.
	var icons := {"": UiStyle.icon("all")}
	for k in Items.CATEGORIES:
		var first := Items.of_category(k)
		icons[k] = ItemIcons.of_item(first) if first != "" else UiStyle.icon("all")
	var names := {"": "[all]"}
	names.merge(Items.CATEGORIES)
	return [keys, icons, names]
