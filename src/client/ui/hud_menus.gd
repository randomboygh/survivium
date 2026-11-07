extends "res://src/client/ui/hud_layout.gd"
## The game screen's interface, part four (hud.gd): what its buttons open: the bag and a
## chest or a placed thing beside it, the statistics, the pause menu and its pages, the
## land and the team, the settings and «Тестирование», leaving for the main menu.

## The settings and the playtest page, compiled and made when first opened (settings_menu).
const SETTINGS_MENU := "res://src/client/ui/settings_menu.gd"


## Opens the bag with the chest by the spawn beside it.
func open_chest() -> void:
	for e: Dictionary in game.placed.things:
		if e.items != null and e.items == game.placed.chest_items:
			open_prop(e)


## Opens the bag at placed thing `e` (see Props.placed): a chest beside the bag, the
## craft tab at a station.
func open_prop(e: Dictionary) -> void:
	if Items.get_item(e.item).get("claims", false):
		tap_post(e)
		return
	if not bag.visible:
		toggle_bag()
	if e.items != null:
		bag.show_chest(e)
	else:
		bag.show_station(e)


## Opens or closes the bag over the running game.
func toggle_bag() -> void:
	bag.toggle()


## The bag opened or closed: the button lit while it is open, the HUD laid out again.
func _on_bag_shown() -> void:
	_bag_button.modulate = UiStyle.ACCENT if bag.visible else Color.WHITE
	_place()


func toggle_stats() -> void:
	perf.visible = not perf.visible
	_stats_button.modulate = UiStyle.ACCENT if perf.visible else Color.WHITE
	if perf.visible:
		perf.refresh()
	_place_top()
	_update_menu()


func toggle_menu() -> void:
	if _settings != null and _settings.visible:
		_settings.close()
		return
	_menu.visible = not _menu.visible
	_shade.visible = _menu.visible
	# Over the hotbar and the touch buttons.
	_shade.move_to_front()
	_menu.move_to_front()
	# A game on this device stops while the menu is open (a server game will not),
	# and is saved.
	get_tree().paused = _menu.visible
	if _menu.visible:
		game.save.flush()
	_update_menu()


## A tap on boundary post `e`: one's own turns painting the land on or off (taps on the
## ground then paint squares), another's says whose it is.
func tap_post(e: Dictionary) -> void:
	var land = game.land
	if not land.tap_post(e):
		var claim: Dictionary = land.copy.claim_at(e.cell)
		toast("Межевой столб «%s»" % claim.get("name", "") if not claim.is_empty() \
			else "Межевой столб без земли: её забросили. Заберите столб и поставьте снова")
		return


## Painting the land turned on or off (a tap on the post or its square, a post set down).
func _on_painting_toggled(on: bool) -> void:
	if on:
		toast("Разметка: нажмите на землю рядом со своей, чтобы закрасить участок, на свой — чтобы стереть; на столб или его участок — чтобы закончить")
	else:
		toast("Разметка закончена")


## While painting, how many squares are held and may be held, over the minimap.
func _show_land() -> void:
	var land = game.land
	minimap.set_note("%d/%d" % [land.used, land.budget] if land.painting else "", land.color(land.here()) if not land.here().is_empty() \
		else UiStyle.LAND_COLORS[land.my_color()])
	minimap.redraw()


## The player walked into a claim (or out of all): whose land it is.
func _on_land_entered(claim: Dictionary, own: bool) -> void:
	if claim.is_empty():
		toast("Ничейная земля")
	elif own:
		toast("Своя территория")
	else:
		var may: Array = game.land.may_here(claim)
		toast("Территория «%s»%s: %s" % [claim.get("name", ""), " заброшена" if int(claim.get("weak", 0)) > 0 else "",
			"можно " + ", ".join(may) if not may.is_empty() else "ничего нельзя"])


## Opens the inventory window on the tab «Команда» (on a server).
func open_team() -> void:
	person.close()
	if not bag.visible:
		toggle_bag()
	bag.show_tab("team")


## Opens the settings or the playtest page in place of the pause menu.
func open_settings(page: String) -> void:
	_menu.visible = false
	settings_menu().move_to_front()
	_settings.open(page)
	_settings.fit(size)


## The «Тестирование» buttons come out: the easter egg of the main menu found them.
func unlock_testing() -> void:
	_test_button.visible = true
	_place()


## The flask button: the playtest page over the running game, without the pause.
func toggle_test() -> void:
	if _settings != null and _settings.visible and _settings.page == "test":
		_settings.close()
	else:
		open_settings("test")


## The window of the server made here, over the main menu (the world goes on).
func _to_server() -> void:
	toggle_menu()
	game.menu.open()
	game.menu.open_host()


## Leaves the pause for the main menu over the running world.
func _to_main_menu() -> void:
	toggle_menu()
	game.menu.open()


func _build_menu() -> void:
	_shade = ColorRect.new()
	_shade.color = Color(0, 0, 0, 0.4)
	_shade.visible = false
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_shade)
	_menu = _panel(self)
	_menu.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_menu.add_child(box)
	var title := UiStyle.label("Пауза", UiStyle.ACCENT)
	title.add_theme_font_size_override("font_size", UiStyle.FONT_SIZE_BIG)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_menu_buttons["resume"] = _add_menu_button(box, "Продолжить", toggle_menu)
	_menu_buttons["settings"] = _add_menu_button(box, "Настройки", open_settings.bind("settings"))
	_menu_buttons["test"] = _add_menu_button(box, "Тестирование", open_settings.bind("test"))
	_menu_buttons["server"] = _add_menu_button(box, "Сервер", _to_server)
	_menu_buttons["main"] = _add_menu_button(box, "Главное меню", _to_main_menu)


## The settings and the playtest page, made the first time they are opened.
func settings_menu() -> Control:
	if _settings == null:
		_settings = load(SETTINGS_MENU).new(game)
		_settings.closed.connect(func() -> void:
			if get_tree().paused:
				_menu.visible = true
				_update_menu())
		add_child(_settings)
	return _settings


func _update_menu() -> void:
	if not _menu.visible:
		return
	# Tests and tools play without the main menu.
	_menu_buttons["main"].visible = game.menu != null
	# Found by the easter egg of the main menu (Settings «testing_unlocked»).
	_menu_buttons["test"].visible = game.settings.values.testing_unlocked
	# The window of the server made here (Main.hosted), the world going on meanwhile.
	_menu_buttons["server"].visible = game.menu != null and game.hosted != null
	_menu.reset_size()
	_menu.position = ((size - _menu.size) * 0.5).floor()


## Whether a tap at `screen_pos` (screen pixels) is on or within SAFE_ZONE of the
## buttons and panels on the screen: such a tap that just misses one is not a tap on
## the world (no digging, no «Слишком далеко»).
func covers(screen_pos: Vector2) -> bool:
	var room := SAFE_ZONE * scale.x
	for c: Control in [_top, _level, minimap, _camera, _bar, build_bar, farm_bar, _bag_meter, _clock_panel, vitals, stick, _action, _jump]:
		if c != null and c.is_visible_in_tree() and c.get_global_rect().grow(room).has_point(screen_pos):
			return true
	return false


## Screen rectangles of the controls, for the F3 debug line and the browser smoke test.
func debug_rects() -> Dictionary:
	var out := {}
	var items := {"stick": stick, "buttons": _action, "jump": _jump, "hotbar": _bar, "menu": _menu_button,
		"test": _test_button, "bag": _bag_button}
	for k in items:
		var c: Control = items[k]
		out[k] = c.get_global_rect() if c.is_visible_in_tree() else Rect2()
	# The "next" arrow of the season row while the playtest page is open.
	out["season"] = _settings.debug_rects().get("Сезон", Rect2()) if _settings != null and _settings.visible else Rect2()
	return out


# --- Helpers -----------------------------------------------------------------------
