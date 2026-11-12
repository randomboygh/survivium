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


## Opens the window of sign `e` (Placed.is_sign): its text to read or write.
func open_sign(e: Dictionary) -> void:
	if sign_window != null:
		sign_window.close()
	sign_window = SignWindow.new(game, e)
	sign_window.closed.connect(func() -> void: sign_window = null)
	add_child(sign_window)


## Opens the wheel of gestures, or closes it when open.
func toggle_gestures() -> void:
	if gesture_wheel != null:
		gesture_wheel.close()
		return
	gesture_wheel = GestureWheel.new(game)
	gesture_wheel.chosen.connect(make_gesture)
	gesture_wheel.closed.connect(func() -> void:
		gesture_wheel = null
		_gesture_button.modulate = Color.WHITE)
	add_child(gesture_wheel)
	_gesture_button.modulate = UiStyle.ACCENT


## The player makes gesture `name` (Gestures.LIST): their figure at once, the others
## through the server (Protocol.GESTURE).
func make_gesture(name: String) -> void:
	game.player.set_gesture(name)
	game.net.request(Protocol.GESTURE, [name])


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
		toast(Lang.line("[boundary_post]", [claim.get("name", "")]) if not claim.is_empty() \
			else "[a_boundary_post_with_no]")
		return


## Painting the land turned on or off (a tap on the post or its square, a post set down).
func _on_painting_toggled(on: bool) -> void:
	if on:
		toast("[marking_tap_the_ground_next]")
	else:
		toast("[marking_finished]")


## While painting, how many squares are held and may be held, over the minimap.
func _show_land() -> void:
	var land = game.land
	minimap.set_note("%d/%d" % [land.used, land.budget] if land.painting else "", land.color(land.here()) if not land.here().is_empty() \
		else UiStyle.LAND_COLORS[land.my_color()])
	minimap.redraw()


## The player walked into a claim (or out of all): whose land it is.
func _on_land_entered(claim: Dictionary, own: bool) -> void:
	if claim.is_empty():
		toast("[no_ones_land]")
	elif own:
		toast("[your_own_territory]")
	else:
		var may: Array = game.land.may_here(claim)
		var rights: String = Lang.f("[allowed]", [", ".join(may.map(Lang.t))]) if not may.is_empty() else Lang.t("[nothing_allowed]")
		toast(Lang.line("[territory_abandoned]" if int(claim.get("weak", 0)) > 0 else "[territory]",
			[claim.get("name", ""), rights]))


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
	var title := UiStyle.label("[pause]", UiStyle.ACCENT)
	title.add_theme_font_size_override("font_size", UiStyle.FONT_SIZE_BIG)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_menu_buttons["resume"] = _add_menu_button(box, "[continue]", toggle_menu)
	_menu_buttons["settings"] = _add_menu_button(box, "[settings]", open_settings.bind("settings"))
	_menu_buttons["test"] = _add_menu_button(box, "[testing]", open_settings.bind("test"))
	_menu_buttons["server"] = _add_menu_button(box, "[server_name]", _to_server)
	_menu_buttons["main"] = _add_menu_button(box, "[main_menu]", _to_main_menu)


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
	# Found by the easter egg of the main menu (Settings.testing_unlocked, not saved).
	_menu_buttons["test"].visible = game.settings.testing_unlocked
	# The window of the server made here (Main.hosted), the world going on meanwhile.
	_menu_buttons["server"].visible = game.menu != null and game.hosted != null
	_menu.reset_size()
	_menu.position = ((size - _menu.size) * 0.5).floor()


## Whether a tap at `screen_pos` (screen pixels) is on or within SAFE_ZONE of the
## buttons and panels on the screen: such a tap that just misses one is not a tap on
## the world (no digging, no «Слишком далеко»). A sign's window covers the whole screen:
## nothing under it is touched.
func covers(screen_pos: Vector2) -> bool:
	if sign_window != null:
		return true
	var room := SAFE_ZONE * scale.x
	for c: Control in [_top, _level, minimap, _camera, _bar, build_bar, farm_bar, _bag_meter, _clock_panel, vitals, stick, _action, _jump]:
		if c != null and c.is_visible_in_tree() and c.get_global_rect().grow(room).has_point(screen_pos):
			return true
	return false


## Whether the mouse pointer is over some control other than the hotbar (a window, a
## panel, a button), whose the wheel is: it turns the hotbar only over the world or the bar.
func wheel_taken() -> bool:
	var c := get_viewport().gui_get_hovered_control()
	return c != null and c != _bar and not _bar.is_ancestor_of(c)


## Screen rectangles of the controls, for the F3 debug line and the browser smoke test.
func debug_rects() -> Dictionary:
	var out := {}
	var items := {"stick": stick, "buttons": _action, "jump": _jump, "hotbar": _bar, "menu": _menu_button,
		"test": _test_button, "bag": _bag_button}
	for k in items:
		var c: Control = items[k]
		out[k] = c.get_global_rect() if c.is_visible_in_tree() else Rect2()
	# The "next" arrow of the season row while the playtest page is open.
	out["season"] = _settings.debug_rects().get("[season]", Rect2()) if _settings != null and _settings.visible else Rect2()
	return out


# --- Helpers -----------------------------------------------------------------------
