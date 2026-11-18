extends "res://src/client/ui/kit/window.gd"
## The saved worlds (see WorldStore.list_worlds), the one saved last first: a row each
## with its seed, kind and day (and when it was saved, in the tooltip). Tapping a row picks that world
## (`chosen`); the square trash button beside it turns red on the first tap and deletes
## the world from the device on the second. The world being played cannot be deleted
## (its button is greyed). In developer mode (Settings.testing_unlocked) the test
## world comes first, saved or not (the one with slopes 1, shores 0); otherwise it is not shown. A test world's trash button resets it
## instead: two taps forget its save, so it is laid out anew (played, at once). "Назад" (or Escape) leaves. It covers the whole
## screen over a shade of the world behind, the panel in the middle. `game` is the
## Main node.

const TwoTap := preload("res://src/client/ui/kit/two_tap.gd")
const WorldStore := preload("res://src/shared/world/world_store.gd")
const Mods := preload("res://src/shared/content/mods.gd")
const WorldSetup := preload("res://src/client/ui/world_setup.gd")
const Lang := preload("res://src/shared/content/lang.gd")
const LandLayout := preload("res://src/shared/world/land_layout.gd")

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
	build("[load_game]", 8)
	_rows = Kit.column(4)
	# A finger dragged over the world buttons scrolls them too.
	_scroll = Kit.scroll(_rows, false)
	box.add_child(_scroll)
	# Across the panel, as wide as the rows over it.
	box.add_child(Kit.button("[back]", back, 0, ROW_H))
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
	var worlds := WorldStore.list_worlds().filter(func(w: Dictionary) -> bool: return w.seed != WorldStore.TEST_SEED)
	if game.settings.testing_unlocked:
		worlds = test_worlds() + worlds
	if worlds.is_empty():
		var none := Kit.caption("[no_saved_worlds_yet]")
		none.custom_minimum_size = Vector2(ROW_WIDTH + DELETE_WIDTH + 4, ROW_H)
		none.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		Kit.text_room(none)
		_rows.add_child(none)
	for w: Dictionary in worlds:
		var current: bool = w.seed == game.world_seed and w.settings == game.world_options and game.link.join_url == ""
		var row := Kit.row(4)
		_rows.add_child(row)
		var seed_value: int = w.seed
		var options: Dictionary = w.settings
		var pick := Kit.button(Lang.f("[seed_day]", [w.seed, _kind(w.settings), w.day]),
			func() -> void: chosen.emit(seed_value, options), ROW_WIDTH, ROW_H)
		if w.seed == WorldStore.TEST_SEED:
			pick.text = Lang.f("[test_world_day]", [w.day])
		if w.saved != "":
			pick.tooltip_text = Lang.f("[saved_played_min]", [w.saved.replace("T", " "), int(w.played / 60.0)])
		if not w.mods.is_empty():
			pick.tooltip_text += Lang.f("[mods]", [Mods.summary(Mods.expand(w.mods))])
		pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
		# Every row as wide as the widest, its delete button at the same place.
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if current:
			UiStyle.accent(pick)
		row.add_child(pick)
		var del := Kit.icon_button("trash", "[delete_the_world_tap_twice]", Callable(), DELETE_WIDTH)
		if w.seed == WorldStore.TEST_SEED:
			del.tooltip_text = "[reset_the_test_world_tap]"
			if w.dir == "":
				# Not made yet: nothing to reset.
				del.disabled = true
			else:
				_bins.guard(del, _reset.bind(options))
		elif current:
			# The world being played stays.
			del.tooltip_text = "[this_world_is_being_played]"
			del.disabled = true
		else:
			_bins.guard(del, _delete.bind(w.dir))
		row.add_child(del)
	var shown := mini(maxi(worlds.size(), 1), VISIBLE_ROWS)
	# As wide as its rows and the bar's room (Kit.scroll), however many there are.
	_scroll.custom_minimum_size.y = shown * (ROW_H + 4) - 4


## Deletes the world (on the trash's second tap).
func _delete(dir: String) -> void:
	WorldStore.new(dir).erase()
	print("world deleted: %s" % dir)
	_fill()
	fit.call_deferred()


## Forgets the test world's save (Settings.reset_test_world), on the second tap.
func _reset(options: Dictionary) -> void:
	print("test world reset")
	game.settings.reset_test_world(options)
	_fill()
	fit.call_deferred()


## The test world (slopes 1): its save where it has one, else a
## row to make it ("dir" empty, day 1). Their settings are the full set
## (LandLayout.SETTING_KEYS), as the game keeps a world's (SaveGame.choose_world).
static func test_worlds() -> Array:
	var saved := WorldStore.list_worlds().filter(func(w: Dictionary) -> bool: return w.seed == WorldStore.TEST_SEED)
	var out := []
	for slopes in [1]:
		var options := {}
		for k: String in LandLayout.SETTING_KEYS:
			options[k] = LandLayout.DEFAULT_SETTINGS[k]
		options.slopes = slopes
		var found := {}
		for w: Dictionary in saved:
			if int(w.settings.get("slopes", 0)) == slopes and found.is_empty():
				found = w
		if found.is_empty():
			found = {"dir": "", "seed": WorldStore.TEST_SEED, "settings": options, "mods": [], "day": 1, "saved": "",
				"played": 0.0}
		out.append(found)
	return out


## The name of the kind of world the settings match (see WorldSetup.KINDS), in the
## language in use, small.
static func _kind(settings: Dictionary) -> String:
	var now: Array = WorldSetup.OPTIONS.map(func(o: String) -> int: return settings.get(o, 1))
	for k: Array in WorldSetup.KINDS:
		if k[1] == now:
			return Lang.t(k[0]).to_lower()
	return Lang.t("[custom_world]")
