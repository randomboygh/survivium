extends "res://src/client/ui/menu_pages.gd"
## The main menu (plan/design/ui.md, section 2; plan/architecture/server.md, «Меню и
## экраны»): the first screen, over a painted landscape coloured for the time of day of
## the device's clock (stars only at night). No world is made behind it: the world is
## loaded only once the player picks one. Its first page: «Продолжить» (only over a
## running world: closes the menu, back into it), «Одиночная игра»,
## «Мультиплеер», «Редактор», «Что нового», «Настройки», «Выход»; the first two open pages of their
## own in the same panel, with «Назад» at the bottom.
## «Одиночная игра»: "Играть" ("Продолжить" once the world has a save) loads the world
## played last, "Новый мир" opens WorldSetup over the menu and loads the world asked for,
## "Загрузить мир" lists the saved worlds to load one or delete it (WorldList); a world other than
## the one the scene was started for is loaded by a restart of the scene (Main.restart),
## which comes up on the loading screen at once. Joined to a server, each of them leaves
## it for a world of this device.
## «Мультиплеер»: «Присоединиться» opens JoinScreen (a link with `?server=` opens it
## at the start, its address filled in; a failed joining opens it again with why),
## «Создать сервер» opens HostScreen on a computer (on a phone or in the browser a tap
## says it is for a computer); joined, «Вернуться на сервер» and «Отключиться» come
## first. While a server made here runs, its button is «Сервер работает», and what
## would load other bundles under it (single player, joining another server,
## disconnecting) waits until it is stopped.
## «Что нового» opens the list of the recent changes of the build (SettingsMenu's
## "changes" page, «Назад» back to the menu). «Настройки» opens the settings page. The editor is not there yet, so its button is
## disabled, and "Выход" is disabled in the browser.
## The loading screen takes the place of the menu while the world loads: the map around
## the start painted in as its chunks are made, the seed over it, a tip under it, and at
## the bottom how far the loading has gone, in two lines (what is being done, the seconds
## and the per cent), with the cancel button (a cross), which starts the scene again on the page the
## loading was asked from (see `back_to`). The progress goes evenly: each part of the
## loading (start_world's steps, the chunks, the shaders built ahead, the first frames)
## takes the share of the strip it took of the time the last load (StartTimes.part_shares).
## Once the world's first frames are calm the painted landscape fades out and the game
## shows. Reopened over a running world (the pause menu, the death screen) the menu has
## no landscape and «Продолжить» goes straight back in. The game's interface is hidden
## while the menu is open; the menu takes the scale and the safe rect the interface was
## fitted to. In the developer mode (the easter egg: Settings.testing_unlocked) the build's
## number is written small under the name, by its right edge. `game` is the Main node.

const AiRules := preload("res://src/shared/content/ai_rules.gd")
const ShaderWarmup := preload("res://src/client/view/shader_warmup.gd")
## Seconds the painted landscape takes to fade once the world's first frames are calm.
const FADE := 1.2
## The sparrow on the name is the game's own (the animals mod's picture, facing right):
## sitting it is the first frame, in a hop it beats its wings with the others.
const SPARROW := "animals:sparrow"
## Seconds between two glints over the name.
const GLINT_EVERY := 4.0
const GLINT_SHADER := """
shader_type canvas_item;
uniform float glint = -1000.0;
varying vec2 local;
void vertex() { local = VERTEX; }
void fragment() {
	// A slanted band of light over the letters, not over their dark outline.
	float d = local.x + local.y * 0.6 - glint;
	float band = step(0.0, d) * step(d, 6.0) + 0.5 * step(6.0, d) * step(d, 9.0);
	float lit = step(0.35, dot(COLOR.rgb, vec3(0.3, 0.5, 0.2)));
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0, 0.96, 0.84), 0.7 * band * lit);
}
"""


## The build's version under the name, shown in the developer mode (see _ready).
var _version: Label


## The build's number, "0.3.513" (tools/build_info.py), "dev" in the editor.
static func version_text() -> String:
	return str(Protocol.build_info().get("version", "dev"))


func _init(g) -> void:
	game = g


func _ready() -> void:
	theme = UiStyle.theme()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop = Control.new()
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.draw.connect(_draw_sky)
	add_child(_backdrop)
	_motion = Control.new()
	_motion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_motion.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_motion.draw.connect(_draw_motion)
	_backdrop.add_child(_motion)
	_screen = Control.new()
	_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	_screen.draw.connect(_draw_focus)
	add_child(_screen)

	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 6)
	_screen.add_child(_column)
	var title := UiStyle.label(Protocol.game_name().to_upper(), UiStyle.ACCENT)
	title.add_theme_font_size_override("font_size", TITLE_SIZE)
	title.add_theme_color_override("font_outline_color", UiStyle.EDGE)
	title.add_theme_constant_override("outline_size", 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var glint := ShaderMaterial.new()
	glint.shader = Shader.new()
	glint.shader.code = GLINT_SHADER
	title.material = glint
	# Fixed at the top of the screen, not in the column: the pages differ in height.
	_screen.add_child(title)
	_title = title
	# The build's version under the name, once the easter egg has opened the playtest
	# switches (Settings.testing_unlocked): which build a screenshot or a report is of.
	_version = UiStyle.label(version_text(), UiStyle.MUTED)
	_version.add_theme_color_override("font_outline_color", UiStyle.EDGE)
	_version.add_theme_constant_override("outline_size", 4)
	_version.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_version.visible = false
	title.add_child(_version)
	_sparrow = Control.new()
	_sparrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sparrow.draw.connect(_draw_sparrow)
	_take_sparrow(AiRules.SPECIES.get(SPARROW, {}))
	title.add_child(_sparrow)
	_sparrow_hit = Control.new()
	_sparrow_hit.mouse_filter = Control.MOUSE_FILTER_STOP
	_sparrow_hit.gui_input.connect(_on_sparrow_input)
	title.add_child(_sparrow_hit)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_column.add_child(panel)
	# The buttons scroll when a page is taller than the screen (_fit: a landscape phone
	# with a large interface).
	_box = Kit.column(6)
	_room = MarginContainer.new()
	_room.add_child(_box)
	_scroll = Kit.scroll(_room, false)
	panel.add_child(_scroll)
	_fill_page("top")

	_build_loading()
	_fx = Control.new()
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.draw.connect(_draw_fx)
	_screen.add_child(_fx)
	visible = false
	_screen.visible = false


func _process(delta: float) -> void:
	_settle()
	var hud: Control = game.hud
	var rect := Rect2(hud.position, hud.size * hud.scale)
	if rect != _fit_for or scale != hud.scale:
		_fit()
	if _backdrop.visible:
		_time += delta
		_update_sky()
		_motion.queue_redraw()
	if settled and _backdrop.visible and not _fading and (not is_open or _want_play):
		_fading = true
		var tw := _backdrop.create_tween()
		tw.tween_property(_backdrop, "modulate:a", 0.0, FADE)
		tw.tween_callback(func() -> void:
			_backdrop.visible = false
			visible = is_open)
	if not is_open:
		return
	_update_loading(delta)
	_title.visible = _column.visible
	_version.visible = game.settings.testing_unlocked
	if _version.visible:
		_version.position = Vector2(_title.size.x - _version.size.x, _title.size.y)
	_fx.visible = _column.visible
	if _column.visible:
		_move_sparrow(delta)
		_update_fx(delta)
		_title.material.set_shader_parameter("glint", fmod(_time, GLINT_EVERY) * 120.0 - 20.0)
	if settled and _want_play:
		_keep_part_times()
		close()
		return
	if _announce > 0:
		_announce -= 1
		if _announce == 0 and _page != "top" and _column.is_visible_in_tree():
			var rects := []
			for k: String in _order:
				rects.append("%s %s" % [k, _buttons[k].get_global_rect()])
			print("menu page %s: %s" % [_page, ", ".join(rects)])
	if not _shown and _column.is_visible_in_tree():
		# Laid out by now; the browser test taps the buttons from this line.
		_shown = true
		# The menu shown only after a world (a scene started again straight into one, the
		# menu opened from the game) is not a step of the loading.
		if not game.world_started:
			StartTimes.mark("menu")
		print("main menu shown: single %s, multi %s, sparrow %s" % [_buttons.single.get_global_rect(),
			_buttons.multi.get_global_rect(), _sparrow_hit.get_global_rect()])
	_screen.queue_redraw()


## Up and down pick a button, Enter presses it, Escape goes back a page, from the first
## one back into the world; on the loading screen Escape cancels it. Every key stops
## here while the menu is open, so the game behind it gets none.
func _unhandled_input(event: InputEvent) -> void:
	if not is_open or not (event is InputEventKey):
		return
	get_viewport().set_input_as_handled()
	if not event.pressed or event.echo:
		return
	if loading:
		if event.physical_keycode == KEY_ESCAPE:
			cancel_loading()
		return
	if not _column.visible:
		return
	match event.physical_keycode:
		KEY_UP, KEY_W:
			_set_focus(_focus - 1)
		KEY_DOWN, KEY_S:
			_set_focus(_focus + 1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_buttons[_order[_focus]].pressed.emit()
		KEY_ESCAPE:
			if _page != "top":
				_fill_page("top")
			elif _entered:
				play()
