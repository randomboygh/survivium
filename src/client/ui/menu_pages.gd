extends "res://src/client/ui/menu_loading.gd"
## The main menu, part three (main_menu.gd): the pages of its panel and their buttons
## (the first page, «Одиночная игра», «Мультиплеер»), the screens opened over it (a new
## world, the saved worlds, joining and hosting, the settings, «Что нового»), playing the
## world asked for, and the panel laid out on the screen with the keyboard's focus.

const WorldStore := preload("res://src/shared/world/world_store.gd")
const GlWatch := preload("res://src/client/ui/gl_watch.gd")
## The menu's own screens are compiled when first opened, not at the game's start
## (StartTimes: compiling every script was most of the start).
const WORLD_SETUP := "res://src/client/ui/world_setup.gd"
const SETTINGS_MENU := "res://src/client/ui/settings_menu.gd"
const WORLD_LIST := "res://src/client/ui/world_list.gd"
const JOIN_SCREEN := "res://src/client/ui/join_screen.gd"
const HOST_SCREEN := "res://src/client/ui/host_screen.gd"
## The name's top as a share of the screen's height, and UI px between it and the column.
const TITLE_AT := 0.1
const GAP := 14
signal opened
signal closed

## Where the cancel button on the loading screen goes, kept over the restart it makes (and over
## the restart that loads another world): "single" (the page «Одиночная игра»),
## "worlds" (the list of worlds), "multi" (the page «Мультиплеер»), "" (the first page).
static var back_to := ""
## True while the menu or the loading screen takes the screen (the landscape may still
## be fading after that).
var is_open := false
## The panel's buttons and the page they are of: "top", "single" or "multi".
var _box: VBoxContainer
var _page := "top"
## A server can be made here: a computer, not a phone or the browser (a shot sets it).
var host_here := OS.has_feature("pc")
## Frames until the page shown says where its buttons are (the browser test taps them).
var _announce := 0
## Under the buttons of «Мультиплеер»: why «Создать сервер» is not here.
var _note: Label
## Buttons by name, and the names in order of the keyboard focus.
var _buttons := {}
var _order := []
var _focus := 0
## The settings, made when first opened (settings_menu).
var _settings: Control = null
## The screen open over the menu: WorldSetup, WorldList or JoinScreen.
var _setup: Control
## A world was asked for: the menu goes in once it is ready.
var _want_play := false
## The player has been in the world: Escape goes back there.
var _entered := false
var _fading := false
var _shown := false
var _fit_for := Rect2()
var _column: VBoxContainer
## Holds the panel's buttons: it scrolls when the page is taller than the room for it.
var _scroll: ScrollContainer
## Between the scroll and the buttons: room for its bar while it scrolls.
var _room: MarginContainer


## The buttons of `page` in the panel, the one to press first lit (and the keyboard on
## it).
func _fill_page(page: String) -> void:
	_page = page
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	_buttons.clear()
	_order.clear()
	_note = null
	var joined: bool = game.join_url != ""
	var on_server: bool = joined and not game.welcome.is_empty() and game.join_error == ""
	var lit := ""
	match page:
		"top":
			# Opened over a running world (the pause menu, the death screen): back into it.
			var resume: bool = _entered and settled
			if resume:
				_add_button(_box, "resume", "Продолжить", close)
			if game.hosted != null:
				# Its bundles are the server's while it runs.
				_add_button(_box, "single", "Одиночная игра", Callable(), "сервер")
			else:
				_add_button(_box, "single", "Одиночная игра", _fill_page.bind("single"))
			_add_button(_box, "multi", "Мультиплеер", _fill_page.bind("multi"))
			_add_button(_box, "editor", "Редактор", Callable(), "скоро")
			_add_button(_box, "changes", "Что нового", _open_changes)
			_add_button(_box, "settings", "Настройки", _open_settings)
			if OS.has_feature("web"):
				_add_button(_box, "quit", "Выход", Callable(), "вкладка")
				_buttons.quit.tooltip_text = "В браузере игра закрывается вместе с вкладкой"
			else:
				_add_button(_box, "quit", "Выход", func() -> void:
					game.save.flush()
					get_tree().quit())
			lit = "multi" if joined or game.hosted != null else "single"
			if resume:
				lit = "resume"
			if GlWatch.software():
				_slow_drawing()
			elif StartTimes.slow_code():
				_slow_code()
		"single":
			_caption("Одиночная игра")
			_add_button(_box, "play", "Продолжить", _play_single)
			_describe_world(_buttons.play)
			_add_button(_box, "new", "Новый мир", _new_world)
			_add_button(_box, "worlds", "Загрузить мир", _open_worlds)
			_add_button(_box, "back", "Назад", _fill_page.bind("top"))
			lit = "play"
		"multi":
			_caption("Мультиплеер")
			var hosting: bool = game.hosted != null
			if on_server:
				_add_button(_box, "server", "Вернуться на сервер", play.bind("multi"))
				if not hosting:
					# Out of one's land the character stays a while (Server.linger_of).
					var home: bool = game.land.own(game.land.here())
					_add_button(_box, "leave", "Отключиться", func() -> void:
						game.leave_server()
						game.restart.call_deferred(false), "уйдёт сразу" if home else "постоит 30 с")
			if hosting:
				_add_button(_box, "join", "Присоединиться", Callable(), "сервер")
			else:
				_add_button(_box, "join", "Присоединиться", open_join.bind(""))
			if host_here:
				_add_button(_box, "host", "Сервер работает" if hosting else "Создать сервер", open_host)
			else:
				# Not here, but it says where it is.
				_add_button(_box, "host", "Создать сервер", _host_elsewhere, "на ПК")
				_buttons.host.add_theme_color_override("font_color", Color(UiStyle.MUTED, 0.6))
				_buttons.host.add_theme_color_override("font_hover_color", Color(UiStyle.MUTED, 0.8))
			_add_button(_box, "back", "Назад", _fill_page.bind("top"))
			lit = "server" if on_server else ("host" if hosting else "join")
	UiStyle.accent(_buttons[lit])
	_buttons[lit].add_theme_color_override("font_focus_color", UiStyle.DARK_INK)
	_set_focus(_order.find(lit))
	if is_open:
		_fit()
		# Laid out in two frames: then the page says where its buttons are.
		_announce = 2


## «Продолжить» in two lines, like a row of «Загрузить мир»: the seed and the kind of
## world under the word, the day at the right of it (from the save: the world is not
## loaded yet, or from the clock when it is). Joined to a server it stays one line.
func _describe_world(b: Button) -> void:
	if game.join_url != "":
		return
	var test: bool = game.world_seed == WorldStore.TEST_SEED
	var kind: String = "площадки" if test else load(WORLD_LIST)._kind(game.world_options)
	b.text = Lang.f("%s\n%s · %s", [b.text, "тестовый мир" if test else Lang.f("зерно %d", [game.world_seed]), kind])
	b.custom_minimum_size.y = PLAY_H
	b.add_theme_constant_override("line_spacing", 4)
	var day := -1
	var sky: Variant = game.save.meta.get("sky")
	if game.clock.gen != null:
		day = game.clock.day
	elif game.save.has_save and sky is Dictionary and sky.has("day"):
		day = int(sky.day)
	if day < 0:
		return
	var l := UiStyle.label(Lang.f("день %d", [day]), UiStyle.DARK_INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	l.offset_left = -80
	l.offset_right = -10
	l.offset_top = 9
	b.add_child(l)


## The page's name over its buttons.
func _caption(text: String) -> void:
	var l := UiStyle.label(text, UiStyle.MUTED)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(WIDTH, 0)
	_box.add_child(l)


## The browser draws without the graphics card: why the game is slow, and how to turn
## the card on, under the buttons.
func _slow_drawing() -> void:
	_note = UiStyle.label(Lang.f("Браузер рисует без видеокарты (%s), поэтому игра идёт медленно. "
		+ "Включите в настройках браузера «Использовать графическое ускорение» (в Edge — edge://settings/system, "
		+ "в Chrome — chrome://settings/system) и перезапустите браузер.", [GlWatch.renderer()]), UiStyle.ACCENT)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(WIDTH, 0)
	_box.add_child(_note)


## The browser runs the game's code uncompiled (StartTimes.slow_code): how to fix it,
## under the buttons.
func _slow_code() -> void:
	_note = UiStyle.label(Lang.f("Браузер выполняет код игры без компиляции (скрипты собирались %d с), поэтому игра идёт "
		+ "медленно. Так бывает в Edge с режимом «Повышение безопасности в Интернете»: выключите его в "
		+ "edge://settings/privacy или добавьте этот сайт в исключения и перезагрузите страницу.",
		[roundi(StartTimes.scripts_ms() / 1000.0)]), UiStyle.ACCENT)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(WIDTH, 0)
	_box.add_child(_note)


## «Создать сервер» away from a computer: where it is, under the buttons.
func _host_elsewhere() -> void:
	if _note != null:
		return
	_note = UiStyle.label("Сервер запускают на компьютере: Survivium для Windows или Linux. "
		+ "С телефона и из браузера к нему присоединяются.", UiStyle.MUTED)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(WIDTH, 0)
	_box.add_child(_note)
	_fit()


func _add_button(parent: Node, key: String, text: String, action: Callable, tag := "") -> void:
	var b := Kit.button(text, Callable(), WIDTH, BUTTON_H)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if action.is_valid():
		b.pressed.connect(action)
		b.mouse_entered.connect(func() -> void: _set_focus(_order.find(key)))
		_order.append(key)
	else:
		b.disabled = true
	if tag != "":
		# What the button waits for or does, at its right edge.
		var l := UiStyle.label(tag, Color(UiStyle.MUTED, 0.6))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.offset_right = -10
		l.offset_bottom = -2
		b.add_child(l)
	parent.add_child(b)
	_buttons[key] = b


## Shows the menu over the game and hides the game's interface.
func open() -> void:
	is_open = true
	visible = true
	_screen.visible = true
	_want_play = false
	_show_loading(false)
	var test: bool = game.world_seed == WorldStore.TEST_SEED
	_map_seed.text = "тестовый мир" if test else Lang.f("зерно %d", [game.world_seed])
	if game.join_url != "":
		_map_seed.text = load(JOIN_SCREEN)._short(game.join_url)
	game.hud.visible = false
	_fill_page("top")
	_fit()
	opened.emit()


func close() -> void:
	if is_open:
		# The browser test waits for this line before it looks at the game's screen.
		print("main menu closed")
		StartTimes.mark("play")
	is_open = false
	_want_play = false
	_entered = true
	back_to = ""
	_show_loading(false)
	_screen.visible = false
	if _setup != null:
		_setup.queue_free()
		_setup = null
	if _settings != null:
		_settings.visible = false
	game.hud.visible = true
	visible = _backdrop.visible
	closed.emit()


## The painted landscape covers the whole window (see _draw_sky): nothing of the world
## shows.
func hides_world() -> bool:
	return _backdrop.visible and not _fading


## «Играть» of «Одиночная игра»: the world of this scene, or, joined to a server, this
## device's world by a restart that loads it at once.
func _play_single() -> void:
	if game.join_url != "":
		back_to = "single"
		game.leave_server()
		game.restart.call_deferred()
	else:
		play("single")


## Into the world: at once when it is ready, else the loading screen until it is (the
## world loaded first if it was not asked for yet); cancelling goes back to the page
## `from` (see back_to).
func play(from := "single") -> void:
	if settled:
		close()
		return
	back_to = from
	_want_play = true
	_show_loading(true)
	game.begin_world()


## The loading screen in place of the menu (`on`), or the menu back.
func _show_loading(on: bool) -> void:
	if on and not loading:
		_load_at = Time.get_ticks_msec()
		_part_at.clear()
		_shares = StartTimes.part_shares(PARTS)
		_progress = 0.0
		_phase_shown = ""
		_tip_clock = 0.0
		_tip.text = ""
		_tips_left.clear()
		if _setup != null:
			_setup.queue_free()
			_setup = null
		if _settings != null:
			_settings.visible = false
	loading = on
	_loading.visible = on
	_column.visible = not on and _setup == null and (_settings == null or not _settings.visible)
	if on:
		_fit()


## Opens the page the last loading was asked from (see back_to), after a cancel.
func go_back() -> void:
	var page := back_to
	back_to = ""
	match page:
		"single", "multi":
			_fill_page(page)
		"worlds":
			_fill_page("single")
			_open_worlds()


## The menu opened on the new world's setup (from the death screen).
func new_world() -> void:
	open()
	_new_world()


func _new_world() -> void:
	_show_screen(WORLD_SETUP, [game])
	_setup.cancelled.connect(_close_setup)
	_setup.done.connect(func() -> void:
		_close_setup()
		_go_to(game.settings.values.world_seed, game.settings.world_options(), "single"))


## Into the world of `seed_value` and `options`: the one this scene was started for at
## once, any other by a restart that loads it (from its save if it has one); cancelling
## goes back to `from`.
func _go_to(seed_value: int, options: Dictionary, from: String) -> void:
	if seed_value == game.world_seed and options == game.world_options and game.join_url == "":
		play(from)
	else:
		back_to = from
		game.save.switch_world(seed_value, options)
		game.leave_server()
		game.restart.call_deferred()


func _open_worlds() -> void:
	_show_screen(WORLD_LIST, [game])
	_setup.cancelled.connect(_close_setup)
	_setup.chosen.connect(func(seed_value: int, options: Dictionary) -> void:
		_close_setup()
		_go_to(seed_value, options, "worlds"))


## «Присоединиться» over the menu, the address `url` in its field (the last server's
## when ""), `error` saying why joining failed.
func open_join(url: String, error := "") -> void:
	_page = "multi"
	_show_screen(JOIN_SCREEN, [game, url, error])
	_setup.cancelled.connect(func() -> void:
		_close_setup()
		_fill_page("multi"))
	_setup.chosen.connect(func(address: String, name: String, password: String) -> void:
		back_to = "multi"
		game.join_server(address, name, password))


## «Создать сервер» over the menu: its settings, or the server running.
func open_host() -> void:
	_page = "multi"
	_show_screen(HOST_SCREEN, [game])
	_setup.cancelled.connect(func() -> void:
		_close_setup()
		_fill_page("multi"))
	_setup.play.connect(func() -> void:
		_close_setup()
		play("multi"))


## Joining the server failed, or the connection to it was lost: the menu opens on
## «Присоединиться» saying why.
func join_failed(why: String) -> void:
	open()
	_fill_page("multi")
	open_join(game.join_url, why)


## Puts the screen of script `path`, made with `args`, over the menu in place of the
## column and of any screen up before it; the caller connects its signals to _setup.
func _show_screen(path: String, args: Array) -> void:
	if _setup != null:
		_setup.queue_free()
	_column.visible = false
	_setup = load(path).new.callv(args)
	_screen.add_child(_setup)


func _close_setup() -> void:
	if _setup != null:
		_setup.queue_free()
		_setup = null
	_column.visible = not loading
	_fit()


func _open_settings() -> void:
	_column.visible = false
	settings_menu().open("settings")
	_settings.fit(_screen.size)


## «Что нового» over the menu; «Назад» closes it.
func _open_changes() -> void:
	_column.visible = false
	settings_menu().open("changes", "")
	_settings.fit(_screen.size)


## The settings over the menu, made the first time they are asked for.
func settings_menu() -> Control:
	if _settings == null:
		_settings = load(SETTINGS_MENU).new(game)
		_settings.closed.connect(func() -> void:
			_column.visible = not loading
			_fit())
		_screen.add_child(_settings)
	return _settings


## The menu's column in the middle of the screen, a little below the centre on a tall
## one; the loading card in the middle, its map as large as fits (none on a very short
## screen).
func _fit() -> void:
	var hud: Control = game.hud
	_fit_for = Rect2(hud.position, hud.size * hud.scale)
	scale = hud.scale
	position = hud.position
	size = hud.size
	_screen.size = size
	_backdrop.size = size
	_backdrop.queue_redraw()
	# The name at a fixed height of the screen; the column in the middle of the room under
	# it, its top no higher than the name's bottom, so pages of any height leave the name
	# where it is. A page too tall for that (a landscape screen, a large interface) puts
	# the name beside the column where the width allows, or at the very top; what still
	# does not fit scrolls in the panel.
	_title.reset_size()
	_fx.size = size
	# No scrolling (and no bar) unless the page needs it: the scroll as tall as the buttons.
	UiStyle.bar_room(_room, false)
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size.y = 0.0
	var box_h := _box.get_combined_minimum_size().y
	_column.reset_size()
	var c := _column.size
	var t := _title.size
	var least := _title_least_top()
	var top := maxf(least, size.y * TITLE_AT) + t.y + GAP
	# The most the column may take in height; less than it needs: the buttons scroll.
	var high := c.y
	var beside := false
	if top + c.y <= size.y - MARGIN:
		_title_at = Vector2((size.x - t.x) * 0.5, top - t.y - GAP)
		_column.position = Vector2((size.x - c.x) * 0.5, top + (size.y - MARGIN - top - c.y) * 0.45)
	elif t.x + GAP * 2 + c.x + 16 + 2 * MARGIN <= size.x:
		# Side by side, the pair in the middle of the screen (room for a scroll bar).
		high = minf(c.y, size.y - 2 * MARGIN)
		var left := (size.x - t.x - GAP * 2 - c.x) * 0.5
		_title_at = Vector2(left, (size.y - t.y) * 0.5)
		_column.position = Vector2(left + t.x + GAP * 2, (size.y - high) * 0.5)
		beside = true
	else:
		_title_at = Vector2((size.x - t.x) * 0.5, least)
		top = least + t.y + GAP
		_column.position = Vector2((size.x - c.x) * 0.5, top)
		high = minf(c.y, size.y - MARGIN - top)
	if high < c.y:
		_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		_scroll.custom_minimum_size.y = maxf(box_h - (c.y - high), 40.0)
		UiStyle.bar_room(_room, true, _scroll)
		_column.reset_size()
		if not beside:
			_column.position.x = (size.x - _column.size.x) * 0.5
	_title_at = _title_at.floor()
	_title.position = _title_at
	_column.position = _column.position.floor()
	if loading:
		for side: int in MAP_SIZES:
			_set_map_side(side)
			_loading.reset_size()
			if _loading.get_combined_minimum_size().y <= size.y - 2 * MARGIN:
				break
		_loading.reset_size()
		_loading.position = ((size - _loading.size) * 0.5).floor()
	if _settings != null and _settings.visible:
		_settings.fit(size)
	_screen.queue_redraw()


func _set_focus(i: int) -> void:
	if i < 0:
		return
	_focus = posmod(i, _order.size())
	# The keyboard's button in sight when the page scrolls.
	if _scroll != null and _buttons.has(_order[_focus]):
		_scroll.ensure_control_visible(_buttons[_order[_focus]])
	_screen.queue_redraw()


## A small accent arrow left of the button the keyboard is on (not with touch).
func _draw_focus() -> void:
	if game.controls.touch or not _column.visible:
		return
	var b: Button = _buttons[_order[_focus]]
	var at: Vector2 = _screen.get_global_transform().affine_inverse() * b.global_position
	var y := floorf(at.y + b.size.y * 0.5)
	var x := at.x - 10
	for i in 4:
		_screen.draw_rect(Rect2(x + i, y - 3 + i, 1, 7 - 2 * i), UiStyle.ACCENT)
