extends "res://src/client/ui/kit/window.gd"
## «Новая игра»: two tabs joined as one (TabRow.tabs), «Персонаж» (CharacterPage: the
## character drawn big, turned by a drag, and its name; a character belongs to the world
## it is made in, plan/mvp.md stage 3) and «Мир», the world to make. The seed (typed in or rolled with the dice),
## a kind of world that sets the rest at once, and the settings of WorldGen one by one
## as rows "name ‹ value ›" like the settings window, with a map of the land round the
## middle of the world drawn a few rows a frame as the choice changes, the start a dot on
## it once found. The map is in a frame as large as the character's on «Персонаж»
## (FigureStage), with four arrows at its sides that move it 2/3 of its size that way:
## the part still in sight is moved, only the new strip is drawn. The map stays put whatever the mods: the land of a seed is the same
## with any biomes, only where the start is (in a biome a player may start in) moves. The mods of the new world
## are a page of their own, opened from the row «Моды», with a page per mod of several
## bundles, each left with "Назад" (or Escape). "Создать мир" (or Enter) keeps the choice in Settings and starts the world,
## "Назад" (or Escape) leaves it.
## It covers the whole screen over a shade of the world behind, the panel in the
## middle. Opened by «Создать сервер» for its «Новый мир…» (`with_character` false) it
## is «Новый мир», the world's rows only: the host's character is on that window's own
## tab. `game` is the Main node.

const ChoiceRows := preload("res://src/client/ui/kit/choice_rows.gd")
const WorldGen := preload("res://src/shared/world/world_gen.gd")
const Mods := preload("res://src/shared/content/mods.gd")
const Lang := preload("res://src/shared/content/lang.gd")
const WorldStore := preload("res://src/shared/world/world_store.gd")
const Biomes := preload("res://src/shared/content/biomes.gd")
const TwoTap := preload("res://src/client/ui/kit/two_tap.gd")
const TabRow := preload("res://src/client/ui/tab_row.gd")
const CharacterPage := preload("res://src/client/ui/character_page.gd")
const FigureStage := preload("res://src/client/ui/figure_stage.gd")
const FigurePreview := preload("res://src/client/ui/figure_preview.gd")

## The names of the rows, as wide on every page (the mods' are the longest), so the
## panel keeps its size from page to page.
const NAME_WIDTH := 168
const VALUE_WIDTH := 84
const ARROW := 32
## The map: cells per pixel of it, and screen pixels a pixel of it where its frame is
## wide enough (MAP_WIDE_FROM), else one.
const MAP_STEP := 32
const MAP_PIXELS := 2
const MAP_WIDE_FROM := 200
## The side of the arrows that move the map, at the middles of its frame's sides.
const MAP_ARROW := 22
## The part of the map an arrow moves it by.
const MAP_MOVE := 2.0 / 3.0
## The map where it is not drawn yet.
const MAP_BLANK := Color(0.1, 0.1, 0.12)
## Time the map may take a frame, in microseconds.
const MAP_BUDGET_US := 4000
const LEVELS := ["[few]", "[medium_amount]", "[many]"]
## The land's amounts are scales: they stop at their ends, the arrow there off.
const STOP := {"stop": true}
## Kinds of world and the settings each picks: size, water, mountains, rivers, biomes
## (caves are set apart from the kind).
const KINDS := [
	["[standard]", [1, 1, 1, 1, 1]],
	["[continent]", [2, 1, 1, 1, 1]],
	["[islands]", [0, 2, 1, 0, 1]],
	["[mountains]", [1, 1, 2, 1, 1]],
	["[plains]", [2, 0, 0, 2, 2]],
]
const OPTIONS := ["size", "water", "mountains", "rivers", "biomes"]

## `fresh`: a world of this seed and these settings was saved, and the player chose to
## make it anew (with the mods chosen now) in its place.
signal done(fresh: bool)
signal cancelled

var game
## The rows of the page shown (ChoiceRows of the kit).
var _choices := ChoiceRows.new(NAME_WIDTH, VALUE_WIDTH, ARROW)
## The page of rows shown: "world" (the seed and the land), "mods" or "mod:<id>" (its bundles).
var _page := "world"
var _box: BoxContainer
var _list: VBoxContainer
## The rows scroll when the panel is taller than the screen (a phone in landscape).
var _scroll: ScrollContainer
var _seed: LineEdit
## The map, in a frame as large as the figure's of «Персонаж» (layout), centred in its room.
var _map_room: CenterContainer
var _map_frame: PanelContainer
var _map: TextureRect
var _image: Image
var _texture: ImageTexture
## The map's size in its pixels, and screen pixels a pixel of it.
var _map_size := Vector2i(112, 112)
var _map_pixels := MAP_PIXELS
## The cell at the middle of the map (the middle of the world until an arrow moves it).
var _map_mid := Vector2i.ZERO
## The world the map is drawn from, and the parts of the map (in its pixels) still to draw,
## the first drawn first.
var _gen: WorldGen
var _todo: Array[Rect2i] = []
## The start, in cells, once it is found.
var _spawn_at := Vector2i.ZERO
var _spawn_found := false
var _marker: Control
## The biomes of the bundles chosen (Biomes.tables), which the map is laid out with, and
## the bundles they are of.
var _biomes: Array = []
var _biomes_of: Array = []
var _start_button: Button
## Asks a second tap of «Создать мир» when it would make a saved world anew.
var _replace := TwoTap.new()
## Says that a world of this seed and these settings is saved, and what «Создать мир» does to it.
var _saved_note: Label
## Whether that world is saved (the note shows it on «Мир»).
var _saved := false
var _shown := false
## The height of the world's rows, the first page's: every page is given it (the
## longer ones scroll), so the panel does not change size from page to page.
var _rows_height := 0.0
## The words of the button that makes the world: «Создать мир», or what the screen that
## opened this one does with it («Выбрать этот мир» for a server, HostScreen).
var finish := "[create_a_world]"
## Whether the screen has the tab «Персонаж» (see the top); set before it is shown.
var with_character := true
## The tabs (null without the character), the character's page, the tab shown (0
## «Персонаж», 1 «Мир»).
var _tabs: HBoxContainer = null
var _character: CharacterPage = null
var tab := 1


func _init(g) -> void:
	game = g


func _ready() -> void:
	var outer := build("[new_game]" if with_character else "[new_world]", 8)
	if with_character:
		_tabs = TabRow.tabs([["[character]", "", show_tab.bind(0)], ["[world_n3]", "", show_tab.bind(1)]], Kit.BUTTON_H)
		for b: Button in _tabs.get_children():
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		outer.add_child(_tabs)
		_character = CharacterPage.new(_choices.width(), true, true)
		outer.add_child(_character)
	_box = BoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	outer.add_child(_box)
	_map_room = CenterContainer.new()
	_box.add_child(_map_room)
	# The frame of the character's figure (UiStyle.stage), the map in its middle.
	_map_frame = PanelContainer.new()
	_map_frame.add_theme_stylebox_override("panel", UiStyle.stage())
	_map_room.add_child(_map_frame)
	var middle := CenterContainer.new()
	_map_frame.add_child(middle)
	_map = TextureRect.new()
	_map.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_map.stretch_mode = TextureRect.STRETCH_SCALE
	_map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	middle.add_child(_map)
	_size_map(_map_size, _map_pixels)
	_marker = Control.new()
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_marker.draw.connect(_draw_marker)
	_map.add_child(_marker)
	# The arrows at the middles of the frame's sides, pinned there with zero offsets and
	# growing inward (sized by the theme only in the tree).
	for a: Array in [["up", "[move_the_map_north]", Vector2i(0, -1), Control.PRESET_CENTER_TOP],
			["down", "[move_the_map_south]", Vector2i(0, 1), Control.PRESET_CENTER_BOTTOM],
			["prev", "[move_the_map_west]", Vector2i(-1, 0), Control.PRESET_CENTER_LEFT],
			["next", "[move_the_map_east]", Vector2i(1, 0), Control.PRESET_CENTER_RIGHT]]:
		var b := Kit.icon_button(a[0], a[1], _move_map.bind(a[2]), MAP_ARROW)
		b.focus_mode = Control.FOCUS_NONE
		_map.add_child(b)
		b.set_anchors_preset(a[3], true)
		var d: Vector2i = a[2]
		b.grow_horizontal = Control.GROW_DIRECTION_BOTH if d.x == 0 else (Control.GROW_DIRECTION_END if d.x < 0 else Control.GROW_DIRECTION_BEGIN)
		b.grow_vertical = Control.GROW_DIRECTION_BOTH if d.y == 0 else (Control.GROW_DIRECTION_END if d.y < 0 else Control.GROW_DIRECTION_BEGIN)
	_list = Kit.column(4)
	# Inset as the settings' rows (the kit's rule): BAR_GAP from the frame's sides.
	_scroll = Kit.scroll(_list)
	_box.add_child(_scroll)
	_choices.scroll = _scroll
	_choices.stepped.connect(_on_stepped)
	_build_rows()
	_choices.set_focus(1)
	_saved_note = Kit.note("[a_world_with_this_seed]", 0.0, UiStyle.DANGER)
	_saved_note.visible = false
	outer.add_child(_saved_note)
	var buttons := Kit.row(6)
	outer.add_child(buttons)
	buttons.add_child(Kit.button("[back]", back, 96, 36))
	_start_button = Kit.accent_button(finish, _start, 0, 36)
	_start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(_start_button)
	_check_saved()
	show_tab(0 if with_character else 1)
	show_fitted()


## Shows tab `i`: 0 «Персонаж», 1 «Мир» (the world's rows); its tab lit.
func show_tab(i: int) -> void:
	tab = i if _tabs != null else 1
	if _tabs != null:
		_character.visible = tab == 0
		for j in _tabs.get_child_count():
			TabRow.light(_tabs.get_child(j), j == tab)
	_box.visible = tab == 1
	_saved_note.visible = tab == 1 and _saved
	if is_inside_tree():
		fit()


## Fills the list with the rows of `_page`: the seed, the kind of world and the land's
## settings with the row «Моды» last, or the mods, or the bundles of one mod.
func _build_rows() -> void:
	for row in _list.get_children():
		_list.remove_child(row)
		row.queue_free()
	_choices.clear()
	var s = game.settings
	if _page != "world":
		_mod_rows(s)
		_choices.refresh()
		return
	_seed_row()
	# "Свой" is what the rows below make, not a choice of its own.
	_add_row("[world_type]", KINDS.map(func(k: Array) -> String: return k[0]) + ["[custom]"],
		_kind, func(i: int) -> void:
			if i < KINDS.size():
				for j in OPTIONS.size():
					s.values["world_" + OPTIONS[j]] = KINDS[i][1][j]
				s.save(), {"skip": KINDS.size()})
	_add_row("[continents]", ["[small_continents]", "[medium_continents]", "[huge]"], _getter("size"), _setter("size"), STOP)
	_add_row("[water]", LEVELS, _getter("water"), _setter("water"), STOP)
	_add_row("[mountains]", LEVELS, _getter("mountains"), _setter("mountains"), STOP)
	_add_row("[rivers_and_lakes]", LEVELS, _getter("rivers"), _setter("rivers"), STOP)
	_add_row("[biomes]", ["[small_biomes]", "[normal_biomes]", "[large_biomes]"], _getter("biomes"), _setter("biomes"), STOP)
	_add_row("[caves]", LEVELS, _getter("caves"), _setter("caves"), STOP)
	# Buildings outside anyone's land decay where nobody comes (Decay.on); kept by the world.
	_add_row("[building_decay]", ["[off]", "[on]"], _getter("decay"), _setter("decay"))
	_mods_row()
	_choices.refresh()


## The rows of the mods page, one per mod besides the base game («выкл», «вкл» or how
## many of its bundles are on, with a button to its page when it has several), or of a
## mod's page, one per bundle (under one left out for want of another, which, and what
## that one wants in turn: _why_line). A world is made with what is switched on and keeps
## it (a saved world's set cannot change here).
func _mod_rows(s) -> void:
	var state: Dictionary = Mods.resolve(s.world_mods_on())
	var on: Array = state.order
	if _page == "mods":
		for mod: String in Mods.available():
			if mod != "core":
				_whole_mod_row(s, mod, on, Mods.bundles(mod).size() > 1)
		return
	var mod := _page.trim_prefix("mod:")
	# First the mod as a whole, as on the mods page: it switches all its bundles.
	_whole_mod_row(s, mod, on, false)
	# The bundles by their names, so the player reads a list, not the folders' order.
	var bundles: Array = Mods.bundles(mod).duplicate()
	bundles.sort_custom(func(a: String, b: String) -> bool: return Mods.title(a).naturalnocasecmp_to(Mods.title(b)) < 0)
	for bundle: String in bundles:
		var b := bundle
		_add_row(Lang.t(Mods.title(bundle)), ["[off]", "[on]"],
			func() -> int: return 1 if b in on else 0,
			func(i: int) -> void: s.set_world_mod(b, i == 1), {"direct": true})
		_why_line(Mods.why(bundle, state.dropped))


## The row of mod `mod` as a whole: on when all its bundles are (of those switched on,
## `on`), "2 из 6" when some are; its switch turns all of them on or off; with `open`, a
## button opens its page of bundles.
func _whole_mod_row(s, mod: String, on: Array, open: bool) -> void:
	var mine: Array = Mods.bundles(mod)
	var lit: int = mine.filter(func(b: String) -> bool: return b in on).size()
	var opts := {"direct": true,
		"show": Lang.f("[of_n2]", [lit, mine.size()]) if lit > 0 and lit < mine.size() else ""}
	if open:
		opts.open = _show_page.bind("mod:" + mod)
	_add_row(Mods.mod_title(mod), ["[off]", "[on]"],
		func() -> int: return 1 if lit == mine.size() else 0,
		func(i: int) -> void: s.set_world_mod(mod, i == 1), opts)


## A line under the row of a bundle left out for want of another: what it needs, and what
## that one needs in turn, to the one switched off («нужен «Дерево», а ему «Волокно»»).
func _why_line(chain: Array) -> void:
	if chain.is_empty():
		return
	var parts: PackedStringArray = []
	for need: String in chain:
		parts.append(Lang.f("[needs]" if parts.is_empty() else "[and_it_needs]", [Mods.title(need)]))
	var label := UiStyle.label(", ".join(parts), UiStyle.MUTED)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Indented, and further from the next row than from its own.
	var box := MarginContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("margin_left", 12)
	box.add_theme_constant_override("margin_bottom", 10)
	box.add_child(label)
	_list.add_child(box)


## Shows page `page` (see _page) and fits the panel to its rows.
func _show_page(page: String) -> void:
	_page = page
	_build_rows()
	_choices.set_focus(1 if _page == "world" else 0)
	if is_inside_tree():
		fit()


## "Назад": a mod's page goes back to the mods, the mods page to the world's rows, the
## world's rows leave the screen.
func back() -> void:
	if tab == 0:
		cancelled.emit()
	elif _page.begins_with("mod:"):
		_show_page("mods")
	elif _page == "mods":
		_show_page("world")
	else:
		cancelled.emit()


func _getter(option: String) -> Callable:
	return func() -> int: return game.settings.values["world_" + option]


func _setter(option: String) -> Callable:
	return func(i: int) -> void:
		game.settings.values["world_" + option] = i
		game.settings.save()


## The kind of world the settings match, or "Свой" after the last kind.
func _kind() -> int:
	var now: Array = OPTIONS.map(func(o: String) -> int: return game.settings.values["world_" + o])
	for i in KINDS.size():
		if KINDS[i][1] == now:
			return i
	return KINDS.size()


func _seed_row() -> void:
	var row := Kit.row(2)
	_list.add_child(row)
	var label := _choices.name_label("[seed_n2]")
	row.add_child(label)
	_seed = Kit.field("", VALUE_WIDTH + ARROW + 2, 10, ARROW)
	_seed.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_seed.text = str(game.settings.values.world_seed)
	_seed.text_changed.connect(func(t: String) -> void:
		var digits := ""
		for ch in t:
			if ch >= "0" and ch <= "9":
				digits += ch
		if digits != t:
			_seed.text = digits
			_seed.caret_column = digits.length()
		if not digits.is_empty():
			game.settings.values.world_seed = int(digits)
			game.settings.save()
			_restart_map(true))
	_seed.text_submitted.connect(func(_t: String) -> void: _seed.release_focus())
	row.add_child(_seed)
	row.add_child(Kit.icon_button("dice", "[random_seed]", func() -> void:
		var v := randi_range(1, 999999999)
		_seed.text = str(v)
		game.settings.values.world_seed = v
		game.settings.save()
		_restart_map(true), ARROW))
	_choices.add_custom(label)


## The row «Моды»: how many of the mods besides the base game are on, and an arrow
## that opens their page.
func _mods_row() -> void:
	var row := Kit.row(2)
	_list.add_child(row)
	var label := _choices.name_label("[mods_n2]")
	row.add_child(label)
	var value := UiStyle.label()
	value.custom_minimum_size = Vector2(VALUE_WIDTH + ARROW + 2, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var all: int = Mods.all().filter(func(b: String) -> bool: return Mods.mod_of(b) != "core").size()
	var on: int = game.settings.world_mods().filter(func(b: String) -> bool: return Mods.mod_of(b) != "core").size()
	value.text = Lang.f("[of_n2]", [on, all]) if on < all else "[all_n2]"
	row.add_child(value)
	var index := _choices.add_custom(label, _show_page.bind("mods"))
	row.add_child(Kit.icon_button("next", "[choose_the_mods_of_the]", func() -> void:
		_choices.set_focus(index)
		_show_page("mods"), ARROW))


## A row "name ‹ value ›" of `values` read by `getter` and set by `setter` (ChoiceRows'
## options `opts`: a mod's row shows "2 из 6" for its value, opens its bundles' page by
## an extra button, and its arrows go straight to off or on).
func _add_row(name: String, values: Array, getter: Callable, setter: Callable, opts := {}) -> void:
	_choices.add(_list, name, values, getter, setter, opts)


## After a row was stepped: the map of the new land, or a mods' page made anew (what a
## mod's switch did to the others shows only on rows made anew).
func _on_stepped(i: int) -> void:
	if _page == "world":
		_restart_map()
	else:
		# A biome switched on or off shows on the map.
		_restart_map()
		# The page stays where it was scrolled to: the rows made anew are not laid out
		# yet, and keeping the focused one in sight would take the list to its top.
		var at := _scroll.scroll_vertical
		_build_rows()
		_choices.scroll = null
		_choices.set_focus(i)
		_choices.scroll = _scroll
		fit()
		_scroll.scroll_vertical = at
		_keep_scroll(at)


## Scrolls the list back to `at` once the rows made anew are laid out (a shorter list
## for a frame would have pulled it up).
func _keep_scroll(at: int) -> void:
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = at


## Side by side on a wide screen, the map over the rows on a tall one; centred. Every
## page has the same room, as wide as a row with a scroll bar beside it and as tall as
## the world's rows: a longer page (the mods) scrolls in it, and the panel never jumps.
## «Персонаж» is as large as «Мир», the figure where the map is: the map in a frame as
## large as the figure's, both tabs as tall as the taller. When the panel is taller than
## the screen the rows of either tab scroll in less, so the buttons stay in sight.
func layout(screen: Vector2) -> void:
	_box.vertical = screen.x < screen.y
	if _rows_height <= 0.0 or _page == "world":
		_list.reset_size()
		_rows_height = _list.get_combined_minimum_size().y
	# The rows keep BAR_GAP from each side (UiStyle.inset), and the bar its own width
	# beside them when shown: given always, the panel is as wide with it as without.
	var bar := 2 * UiStyle.BAR_GAP + _scroll.get_v_scroll_bar().get_combined_minimum_size().x
	_scroll.custom_minimum_size = Vector2(_choices.width() + bar, _rows_height)
	# The note wraps as wide as the rows, never wider.
	_saved_note.custom_minimum_size.x = _scroll.custom_minimum_size.x
	_box.custom_minimum_size.y = 0.0
	var tall := 0.0
	if _character != null:
		# The figure as big as the inventory draws it on this screen, the map in a room
		# as wide: side by side, the rows stand in one place on either tab.
		_character.set_wide(not _box.vertical)
		_character.vertical = _box.vertical
		_character.custom_minimum_size.y = 0.0
		# The rows as wide as the world's, their bar's room given always; all of them
		# shown unless the screen is short (below).
		_character.scroll.custom_minimum_size = Vector2(_scroll.custom_minimum_size.x,
			_character.rows.get_combined_minimum_size().y)
		tall = _character.get_combined_minimum_size().y
	_fit_map()
	var world := _box.get_combined_minimum_size().y
	# The room a tab has: the screen's, less the panel round the tab shown.
	panel.reset_size()
	var shown: Control = _character if _character != null and _character.visible else _box
	var room := screen.y - 2 * MARGIN - panel.size.y + shown.get_combined_minimum_size().y
	tall = minf(maxf(tall, world), room)
	if world > tall:
		_scroll.custom_minimum_size.y = maxf(_rows_height - (world - tall), ARROW * 2)
	_box.custom_minimum_size.y = tall
	if _character != null:
		var over := _character.get_combined_minimum_size().y - tall
		if over > 0.0:
			_character.scroll.custom_minimum_size.y = maxf(_character.scroll.custom_minimum_size.y - over, ARROW * 2)
		_character.custom_minimum_size.y = tall


func _start() -> void:
	if _seed.text.is_empty():
		_seed.text = str(game.settings.values.world_seed)
	# Over a saved world only on the second tap: it is made anew, the save gone.
	var fresh := _saved
	if fresh and tab != 1:
		# The note is on «Мир»: it is shown before the second tap is asked.
		show_tab(1)
	if fresh and not _replace.ask(_start_button):
		return
	game.settings.save()
	done.emit(fresh)


## Whether a world of the seed and settings chosen is saved: then the note says that
## «Создать мир» makes it anew in its place (its mods as chosen now), on a second tap.
## Else creating it would only open that save, mods and all.
func _check_saved() -> void:
	var dir := WorldStore.world_dir(int(game.settings.values.world_seed), game.settings.world_options())
	var saved := FileAccess.file_exists(dir + "/" + WorldStore.WORLD)
	# A world hosted on this device: its players' characters go too (its access stays,
	# SaveGame.replace_world).
	var key := "[a_hosted_world_with_this]" if saved and WorldStore.was_hosted(dir) else "[a_world_with_this_seed]"
	_replace.disarm()
	if saved == _saved and key == _saved_note.text:
		return
	_saved = saved
	_saved_note.text = key
	_saved_note.visible = saved and tab == 1
	if is_inside_tree():
		fit()


# --- The map ----------------------------------------------------------------------

## The map's frame as large as the character's (FigureStage, as large on either tab; as
## drawn for an upright or a wide screen without «Персонаж»), the map filling it in whole
## pixels of MAP_PIXELS screen pixels (one in a narrow frame): drawn anew when its size changes.
func _fit_map() -> void:
	var outer: Vector2
	if _character != null:
		outer = _character.stage.get_combined_minimum_size()
	else:
		var px: int = FigureStage.PIXELS if _box.vertical else FigureStage.PIXELS_WIDE
		outer = Vector2(FigureStage.CROP.size.x, FigureStage.CROP.size.y + FigurePreview.STAND_BELOW) * px \
			+ UiStyle.stage().get_minimum_size()
	_map_frame.custom_minimum_size = outer
	var inner := outer - _map_frame.get_theme_stylebox("panel").get_minimum_size()
	var pixels := MAP_PIXELS if inner.x >= MAP_WIDE_FROM else 1
	var size := Vector2i(inner / pixels)
	if size != _map_size or pixels != _map_pixels:
		_size_map(size, pixels)
		_restart_map()


## A map `size` of its pixels, each `pixels` screen pixels, blank.
func _size_map(size: Vector2i, pixels: int) -> void:
	_map_size = size
	_map_pixels = pixels
	_image = Image.create_empty(size.x, size.y, false, Image.FORMAT_RGB8)
	_image.fill(MAP_BLANK)
	_texture = ImageTexture.create_from_image(_image)
	_map.texture = _texture
	_map.custom_minimum_size = Vector2(size * pixels)
	_map.tooltip_text = Lang.f("[the_land_round_the_middle]", [size.x * MAP_STEP])


## The map drawn anew round its middle (another seed takes it back to the world's middle).
func _restart_map(to_middle := false) -> void:
	_gen = null
	_todo.clear()
	if to_middle:
		_map_mid = Vector2i.ZERO
	_spawn_found = false
	if _marker != null:
		_marker.queue_redraw()
	_check_saved()


## The map moved MAP_MOVE of its size towards `dir` (x east, y south): what stays in sight
## is moved over, the strip come into sight is drawn (and the parts not drawn yet go along).
func _move_map(dir: Vector2i) -> void:
	var by := Vector2i(roundi(_map_size.x * MAP_MOVE) * dir.x, roundi(_map_size.y * MAP_MOVE) * dir.y)
	_map_mid += by * MAP_STEP
	var old := _image.duplicate() as Image
	_image.fill(MAP_BLANK)
	_image.blit_rect(old, Rect2i(Vector2i.ZERO, _map_size), -by)
	_texture.update(_image)
	var whole := Rect2i(Vector2i.ZERO, _map_size)
	var todo: Array[Rect2i] = []
	for r in _todo:
		var moved := Rect2i(r.position - by, r.size).intersection(whole)
		if moved.has_area():
			todo.append(moved)
	# The strip come into sight, on the side moved towards.
	var strip := whole
	if dir.x > 0:
		strip = Rect2i(_map_size.x - by.x, 0, by.x, _map_size.y)
	elif dir.x < 0:
		strip = Rect2i(0, 0, -by.x, _map_size.y)
	elif dir.y > 0:
		strip = Rect2i(0, _map_size.y - by.y, _map_size.x, by.y)
	elif dir.y < 0:
		strip = Rect2i(0, 0, _map_size.x, -by.y)
	todo.push_front(strip)
	_todo = todo
	_marker.queue_redraw()


## The cell at the map's top left corner.
func _map_corner() -> Vector2i:
	return _map_mid - _map_size / 2 * MAP_STEP


## The start, clamped to the map's edge when it is out of sight (it shows which way it is).
func _draw_marker() -> void:
	if not _spawn_found:
		return
	var px := Vector2(_spawn_at - _map_corner()) / MAP_STEP
	px = px.clamp(Vector2(1, 1), Vector2(_map_size) - Vector2(2, 2)).floor()
	var at := (px + Vector2(0.5, 0.5)) * _map_pixels
	_marker.draw_rect(Rect2(at - Vector2(3, 3), Vector2(6, 6)), UiStyle.DARK_INK)
	_marker.draw_rect(Rect2(at - Vector2(2, 2), Vector2(4, 4)), UiStyle.ACCENT)


func _process(_delta: float) -> void:
	if not _shown:
		# Laid out by now; the browser test taps the button from this line.
		_shown = true
		print("world setup shown: start %s" % _start_button.get_global_rect())
	var t0 := Time.get_ticks_usec()
	if _gen != null and _todo.is_empty() and not _gen.seeking:
		return
	# The land of the bundles chosen: their biomes in place of those the world behind
	# plays with, for this frame's rows only.
	var own := Biomes.tables()
	if _gen == null:
		var bundles: Array = game.settings.world_mods()
		if bundles != _biomes_of:
			_biomes_of = bundles
			Biomes.refresh(bundles)
			_biomes = Biomes.tables()
	Biomes.use(_biomes)
	if _gen == null:
		# Its spawn is looked for a little each frame once the map is drawn (a seed far
		# from good land took seconds on a phone).
		_gen = WorldGen.new(game.settings.values.world_seed, 48, game.settings.world_options(), false)
		_todo = [Rect2i(Vector2i.ZERO, _map_size)]
	# Round the middle of the world, where the search for the start begins, not round the
	# start: the start moves with the biomes chosen (a meadow nearer or farther), the land
	# does not, and a map round it seemed to move the world. The arrows move it on.
	var corner := _map_corner()
	var drew := false
	while not _todo.is_empty() and Time.get_ticks_usec() - t0 < MAP_BUDGET_US:
		# A few rows of the first part at once, about a map's width of columns (a narrow
		# strip of a move sideways would take many small windows).
		var r: Rect2i = _todo[0]
		var rows := clampi(_map_size.x / r.size.x, 1, r.size.y)
		var lay := _gen.lay_out(corner.x + r.position.x * MAP_STEP, corner.y + r.position.y * MAP_STEP,
			r.size.x, rows, MAP_STEP)
		for j in rows:
			for i in r.size.x:
				_image.set_pixel(r.position.x + i, r.position.y + j, _gen.column_color(lay, j * r.size.x + i))
		drew = true
		if rows < r.size.y:
			_todo[0] = Rect2i(r.position.x, r.position.y + rows, r.size.x, r.size.y - rows)
		else:
			_todo.pop_front()
	if drew:
		_texture.update(_image)
	if _todo.is_empty() and _gen.seeking and _gen.seek_spawn(maxi(MAP_BUDGET_US - (Time.get_ticks_usec() - t0), 0)):
		var at: Vector3i = _gen.spawn_guess
		_spawn_at = Vector2i(at.x, at.z)
		_spawn_found = true
		_marker.queue_redraw()
	Biomes.use(own)


## On «Мир» up and down pick a row, left and right change it (right opens the mods from
## «Моды»); on «Персонаж» the same with the looks' rows, and left and right turn the
## figure while none is picked (CharacterPage.key). Enter makes the world, Escape leaves the mods page or the screen.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	match event.physical_keycode:
		KEY_ENTER, KEY_KP_ENTER:
			if not event.echo:
				_start()
		KEY_ESCAPE:
			if not event.echo:
				back()
		_:
			if not (_character.key(event) if tab == 0 else _choices.key(event)):
				return
	get_viewport().set_input_as_handled()
