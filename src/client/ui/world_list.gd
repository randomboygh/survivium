extends "res://src/client/ui/kit/window.gd"
## The saved worlds (see WorldStore.list_worlds), the one saved last first: a row each
## with its seed, kind and day (and when it was saved, in the tooltip). Tapping a row picks that world
## (`chosen`); the square trash button beside it turns red on the first tap and deletes
## the world from the device on the second. The world being played cannot be deleted
## (its button is greyed). The test world's trash button resets it instead: two taps
## forget its save, so it is laid out anew (played, at once). "Назад" (or Escape) leaves. It covers the whole
## screen over a shade of the world behind, the panel in the middle. `game` is the
## Main node.

const TwoTap := preload("res://src/client/ui/kit/two_tap.gd")
const WorldStore := preload("res://src/shared/world/world_store.gd")
const Mods := preload("res://src/shared/content/mods.gd")
const WorldSetup := preload("res://src/client/ui/world_setup.gd")
const Lang := preload("res://src/shared/content/lang.gd")

const ROW_WIDTH := 226
const ROW_H := 36
## The trash button is square.
const DELETE_WIDTH := ROW_H
## Rows shown before the list scrolls.
const VISIBLE_ROWS := 5

signal chosen(seed_value: int, options: Dictionary)
signal cancelled

var game
var _rows: VBoxContainer
var _scroll: ScrollContainer
## The trash buttons: two taps each.
var _bins := TwoTap.new()


func _init(g) -> void:
	game = g


func _ready() -> void:
	build("Загрузить мир", 8)
	_rows = Kit.column(4)
	# A finger dragged over the world buttons scrolls them too.
	_scroll = Kit.scroll(_rows, false)
	box.add_child(_scroll)
	# Across the panel, as wide as the rows over it.
	box.add_child(Kit.button("Назад", back, 0, ROW_H))
	_fill()
	show_fitted()


func back() -> void:
	cancelled.emit()


## One row per saved world.
func _fill() -> void:
	for c in _rows.get_children():
		c.queue_free()
		_rows.remove_child(c)
	_bins.disarm()
	var worlds := WorldStore.list_worlds()
	if worlds.is_empty():
		var none := Kit.caption("Сохранённых миров пока нет")
		none.custom_minimum_size = Vector2(ROW_WIDTH + DELETE_WIDTH + 4, ROW_H)
		none.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_rows.add_child(none)
	for w: Dictionary in worlds:
		var current: bool = w.seed == game.world_seed and w.settings == game.world_options and game.join_url == ""
		var row := Kit.row(4)
		_rows.add_child(row)
		var seed_value: int = w.seed
		var options: Dictionary = w.settings
		var pick := Kit.button(Lang.f("зерно %d\n%s · день %d", [w.seed, _kind(w.settings), w.day]),
			func() -> void: chosen.emit(seed_value, options), ROW_WIDTH, ROW_H)
		if w.seed == WorldStore.TEST_SEED:
			pick.text = Lang.f("Тестовый мир\nплощадки · день %d", [w.day])
		pick.tooltip_text = Lang.f("Сохранён %s, в игре %d мин", [w.saved.replace("T", " "), int(w.played / 60.0)])
		if not w.mods.is_empty():
			pick.tooltip_text += Lang.f("\nМоды: %s", [Mods.summary(Mods.expand(w.mods))])
		pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
		# Every row as wide as the widest, its delete button at the same place.
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if current:
			UiStyle.accent(pick)
		row.add_child(pick)
		var del := Kit.icon_button("trash", "Удалить мир (нажать дважды)", Callable(), DELETE_WIDTH)
		if w.seed == WorldStore.TEST_SEED:
			del.tooltip_text = "Вернуть тестовый мир к началу (нажать дважды)"
			_bins.guard(del, _reset)
		elif current:
			# The world being played stays.
			del.tooltip_text = "Мир сейчас в игре"
			del.disabled = true
		else:
			_bins.guard(del, _delete.bind(w.dir))
		row.add_child(del)
	var shown := mini(maxi(worlds.size(), 1), VISIBLE_ROWS)
	_scroll.custom_minimum_size = Vector2(ROW_WIDTH + DELETE_WIDTH + 4, shown * (ROW_H + 4) - 4)


## Deletes the world (on the trash's second tap).
func _delete(dir: String) -> void:
	WorldStore.new(dir).erase()
	print("world deleted: %s" % dir)
	_fill()
	fit.call_deferred()


## Forgets the test world's save (Settings.reset_test_world), on the second tap.
func _reset() -> void:
	print("test world reset")
	game.settings.reset_test_world()
	_fill()
	fit.call_deferred()


## The name of the kind of world the settings match (see WorldSetup.KINDS), in the
## language in use, small.
static func _kind(settings: Dictionary) -> String:
	var now: Array = WorldSetup.OPTIONS.map(func(o: String) -> int: return settings.get(o, 1))
	for k: Array in WorldSetup.KINDS:
		if k[1] == now:
			return Lang.t(k[0]).to_lower()
	return Lang.t("свой")
