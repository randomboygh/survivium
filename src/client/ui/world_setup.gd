extends "res://src/client/ui/kit/window.gd"
## The first screen: the world to make. The seed (typed in or rolled with the dice),
## a kind of world that sets the rest at once, and the settings of WorldGen one by one
## as rows "name ‹ value ›" like the settings window, with a map of the land around
## the spawn drawn a few rows a frame as the choice changes. The mods of the new world
## are a page of their own, opened from the row «Моды», with a page per mod of several
## bundles, each left with "Назад" (or Escape). "Создать мир" (or Enter) keeps the choice in Settings and starts the world,
## "Назад" (or Escape) leaves it.
## It covers the whole screen over a shade of the world behind, the panel in the
## middle. `game` is the Main node.

const ChoiceRows := preload("res://src/client/ui/kit/choice_rows.gd")
const WorldGen := preload("res://src/shared/world/world_gen.gd")
const Mods := preload("res://src/shared/content/mods.gd")
const Lang := preload("res://src/shared/content/lang.gd")
const WorldStore := preload("res://src/shared/world/world_store.gd")
const Biomes := preload("res://src/shared/content/biomes.gd")
const TwoTap := preload("res://src/client/ui/kit/two_tap.gd")

## The names of the rows, as wide on every page (the mods' are the longest), so the
## panel keeps its size from page to page.
const NAME_WIDTH := 168
const VALUE_WIDTH := 84
const ARROW := 32
## The map: pixels each way and cells per pixel.
const MAP := 128
const MAP_STEP := 32
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
var _map: TextureRect
var _image: Image
var _texture: ImageTexture
## The world the map is drawn from and the next row to draw.
var _gen: WorldGen
var _map_row := 0
## The biomes of the bundles chosen (Biomes.tables), which the map is laid out with, and
## the bundles they are of.
var _biomes: Array = []
var _biomes_of: Array = []
var _start_button: Button
## Asks a second tap of «Создать мир» when it would make a saved world anew.
var _replace := TwoTap.new()
## Says that a world of this seed and these settings is saved, and what «Создать мир» does to it.
var _saved_note: Label
var _shown := false
## The height of the world's rows, the first page's: every page is given it (the
## longer ones scroll), so the panel does not change size from page to page.
var _rows_height := 0.0


func _init(g) -> void:
	game = g


func _ready() -> void:
	var outer := build("[new_world]", 8)
	_box = BoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	outer.add_child(_box)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiStyle.slot())
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(frame)
	_image = Image.create_empty(MAP, MAP, false, Image.FORMAT_RGB8)
	_image.fill(Color(0.1, 0.1, 0.12))
	_texture = ImageTexture.create_from_image(_image)
	_map = TextureRect.new()
	_map.texture = _texture
	_map.custom_minimum_size = Vector2(MAP, MAP)
	_map.stretch_mode = TextureRect.STRETCH_KEEP
	_map.tooltip_text = Lang.f("[the_land_around_the_start]", [(MAP * MAP_STEP)])
	frame.add_child(_map)
	var marker := Control.new()
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.draw.connect(func() -> void:
		var mid := (Vector2(MAP, MAP) * 0.5).floor()
		marker.draw_rect(Rect2(mid - Vector2(2, 2), Vector2(5, 5)), UiStyle.DARK_INK)
		marker.draw_rect(Rect2(mid - Vector2(1, 1), Vector2(3, 3)), UiStyle.ACCENT))
	_map.add_child(marker)
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
	_start_button = Kit.accent_button("[create_a_world]", _start, 0, 36)
	_start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(_start_button)
	_check_saved()
	show_fitted()


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
	if _page.begins_with("mod:"):
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
			_restart_map())
	_seed.text_submitted.connect(func(_t: String) -> void: _seed.release_focus())
	row.add_child(_seed)
	row.add_child(Kit.icon_button("dice", "[random_seed]", func() -> void:
		var v := randi_range(1, 999999999)
		_seed.text = str(v)
		game.settings.values.world_seed = v
		game.settings.save()
		_restart_map(), ARROW))
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
## When the panel is taller than the screen the rows scroll in less, so the buttons stay
## in sight.
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
	panel.reset_size()
	var over := panel.size.y + 2 * MARGIN - screen.y
	if over > 0.0:
		_scroll.custom_minimum_size.y = maxf(_rows_height - over, ARROW * 2)


func _start() -> void:
	if _seed.text.is_empty():
		_seed.text = str(game.settings.values.world_seed)
	# Over a saved world only on the second tap: it is made anew, the save gone.
	var fresh := _saved_note.visible
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
	_replace.disarm()
	if saved == _saved_note.visible:
		return
	_saved_note.visible = saved
	if is_inside_tree():
		fit()


# --- The map ----------------------------------------------------------------------

func _restart_map() -> void:
	_gen = null
	_map_row = 0
	_check_saved()


func _process(_delta: float) -> void:
	if not _shown:
		# Laid out by now; the browser test taps the button from this line.
		_shown = true
		print("world setup shown: start %s" % _start_button.get_global_rect())
	var t0 := Time.get_ticks_usec()
	if _gen != null and _map_row >= MAP:
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
		# Its spawn is looked for a little each frame (a seed far from good land took
		# seconds on a phone), the map drawn round it once found.
		_gen = WorldGen.new(game.settings.values.world_seed, 48, game.settings.world_options(), false)
		_map_row = 0
	if not _gen.seek_spawn(maxi(MAP_BUDGET_US - (Time.get_ticks_usec() - t0), 0)):
		Biomes.use(own)
		return
	var at: Vector3i = _gen.spawn_guess
	while _map_row < MAP and Time.get_ticks_usec() - t0 < MAP_BUDGET_US:
		var lay := _gen.lay_out(at.x - MAP / 2 * MAP_STEP, at.z + (_map_row - MAP / 2) * MAP_STEP, MAP, 1, MAP_STEP)
		for i in MAP:
			_image.set_pixel(i, _map_row, _gen.column_color(lay, i))
		_map_row += 1
	Biomes.use(own)
	_texture.update(_image)


## Up and down pick a row, left and right change it (right opens the mods from «Моды»),
## Enter makes the world, Escape leaves the mods page or the screen.
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
			if not _choices.key(event):
				return
	get_viewport().set_input_as_handled()
