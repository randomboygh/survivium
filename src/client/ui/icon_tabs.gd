extends VBoxContainer
## A column of small square tabs with pictures beside a window's cells (the kinds of
## items in the bag and the craft tab, the chests near): the chosen one lit amber, a
## tooltip naming each. `picked` gives the key of the tab tapped.

const TabRow := preload("res://src/client/ui/tab_row.gd")
const UiStyle := preload("res://src/client/ui/ui_style.gd")
const ItemIcons := preload("res://src/client/ui/item_icons.gd")
const Items := preload("res://src/shared/content/items.gd")

signal picked(key: String)

## The width (and height) of a tab, in UI pixels.
const SIDE := 28

## The key of the tab chosen.
var chosen := ""
var _keys: Array = []
var _buttons := {}
var _lit := "-"


func _init() -> void:
	add_theme_constant_override("separation", 2)
	custom_minimum_size.x = SIDE


## Shows tabs `keys` with pictures `icons` and tooltips `tips` (key -> each); a chosen
## tab that is gone gives way to the first. True when that changed what is chosen.
func set_tabs(keys: Array, icons: Dictionary, tips: Dictionary) -> bool:
	var was := chosen
	if not keys.has(chosen):
		chosen = keys[0] if not keys.is_empty() else ""
	if keys != _keys:
		_keys = keys.duplicate()
		for b in get_children():
			b.queue_free()
		_buttons = {}
		_lit = "-"
		for k in keys:
			var b := TabRow.icon_button(icons.get(k), tips.get(k, ""), func() -> void: pick(k))
			b.custom_minimum_size = Vector2(SIDE, SIDE - 2)
			add_child(b)
			_buttons[k] = b
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
	for k in _buttons:
		TabRow.light(_buttons[k], k == chosen)


## The kinds of items (see Items.CATEGORIES) with «Все» ("") first, of those in
## `have` (kind -> true): the keys, pictures and names for set_tabs.
static func kinds(have: Dictionary) -> Array:
	var keys := [""]
	for k in Items.CATEGORIES:
		if have.has(k):
			keys.append(k)
	var icons := {"": UiStyle.icon("all"), "tools": ItemIcons.picture("pickaxe"), "stations": ItemIcons.picture("workbench"),
		"materials": ItemIcons.picture("cord"), "blocks": ItemIcons.of_item("core:brick"),
		"food": ItemIcons.picture("raspberry"), "plants": ItemIcons.picture("seeds")}
	var names := {"": "Все"}
	names.merge(Items.CATEGORIES)
	return [keys, icons, names]
