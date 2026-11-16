extends "res://src/client/ui/kit/window.gd"
## The voxel model editor (stage 2 item 3, step 5, the user's pick 4А): an item's model
## painted level by level on a flat grid (SliceGrid) beside its 3D picture turning
## (VoxelPreview). Levels are added, copied up and taken out; the slice made wider or
## narrower; tools: paint, erase, fill, take a colour; the palette holds the model's own
## colours and the game's, a colour made lighter or darker, and a leaf switch (voxels the
## season tints). «Save» gives the PNG the game reads (VoxelSheet.png) to whoever opened
## it (`saved`), which writes it into one's own mod; «Undo» takes back a stroke. On a
## phone held upright the parts make one column, held sideways the grid stands beside
## the rest. Opened from a model field of the content editor.

const ChoiceRows := preload("res://src/client/ui/kit/choice_rows.gd")
const TwoTap := preload("res://src/client/ui/kit/two_tap.gd")
const TabRow := preload("res://src/client/ui/tab_row.gd")
const VoxelSheet := preload("res://src/client/ui/editor/voxel_sheet.gd")
const SliceGrid := preload("res://src/client/ui/editor/slice_grid.gd")
const VoxelPreview := preload("res://src/client/ui/editor/voxel_preview.gd")
const Lang := preload("res://src/shared/content/lang.gd")

## The game's colours to paint with: wood, stone, earth, leaves, metal, cloth, light.
const PALETTE := ["#3b2a1c", "#5c4128", "#8a6239", "#b48a56", "#d8b884", "#2e2e33", "#55565c", "#85878c",
	"#b8b9bc", "#e8e6df", "#2f4a22", "#4d7232", "#79a043", "#a9c95a", "#6b3b2a", "#a2552f", "#c98a43",
	"#e0c25a", "#7a2a26", "#b8443a", "#e07a5a", "#284a6e", "#4a7fb0", "#8fbfe0", "#4a3a5e", "#8a5fa0",
	"#d9a0c0", "#f3e7cc"]
## The most of the model's own colours shown before the game's.
const OWN_COLOURS := 12
## How much «Lighter» and «Darker» change a colour.
const SHADE_STEP := 0.12
## A colour's square in the palette, in UI px.
const SWATCH := 22
## The widest and tallest the grid grows.
const GRID_MOST := 384
const GRID_LEAST := 128
const PREVIEW_MOST := 200
const PREVIEW_LEAST := 72
const NAME_WIDTH := 72
const VALUE_WIDTH := 64

## The PNG of the model to write.
signal saved(png: PackedByteArray)
signal closed

var sheet: VoxelSheet
var grid := SliceGrid.new()
var preview := VoxelPreview.new()
## Whether the sheet changed since it was saved or opened.
var unsaved := false
var _title := ""
var _choices := ChoiceRows.new(NAME_WIDTH, VALUE_WIDTH, Kit.SQUARE)
var _ask := TwoTap.new(3.0)
var _body: BoxContainer
var _left: VBoxContainer
var _right: VBoxContainer
## The tools, the colour and the palette: under the grid upright, beside it sideways.
var _paint: VBoxContainer
var _tools: HBoxContainer
var _colour: Control
var _palette: GridContainer
var _actions: HBoxContainer
var _undo: Button
var _said: Label
var _wide := false


## The editor of `sheet`, under the title `title` (the item's name).
func _init(sheet_: VoxelSheet, title := "") -> void:
	sheet = sheet_
	_title = title
	grid.sheet = sheet
	grid.level = 0
	grid.painted.connect(_changed)
	grid.taken.connect(_taken)
	var own := sheet.colours()
	if not own.is_empty():
		grid.color = own[0]


func _ready() -> void:
	build(Lang.line("[voxel_title]", [_title]) if _title != "" else "[voxel_editor]", 4)
	_body = BoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	box.add_child(_body)
	_left = Kit.column(4)
	_right = Kit.column(4)
	_body.add_child(_left)
	_body.add_child(_right)
	preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_left.add_child(preview)
	var levels := Kit.column(4)
	_left.add_child(levels)
	_choices.add(levels, "[voxel_level]", _level_names(), func() -> int: return grid.level, _set_level, {"stop": true})
	_choices.add(levels, "[voxel_size]", _sizes(), _side_index, _set_side, {"stop": true})
	_choices.add(levels, "[voxel_leaf]", ["[off]", "[on]"], func() -> int: return int(grid.leafy),
		func(i: int) -> void: grid.leafy = i == 1)
	var level_row := TabRow.split([
		[UiStyle.icon("plus"), "[voxel_add_level]", add_level.bind(false)],
		["[voxel_copy_up]", "[voxel_copy_up_tip]", add_level.bind(true)],
		[UiStyle.icon("minus"), "[voxel_remove_level]", remove_level],
	])
	for b: Button in level_row.get_children():
		b.custom_minimum_size.y = Kit.BUTTON_H
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	levels.add_child(level_row)
	_tools = TabRow.tabs([
		[UiStyle.icon("build_draw"), "[voxel_paint]", set_tool.bind(SliceGrid.Tool.PAINT)],
		[UiStyle.icon("build_erase"), "[voxel_erase]", set_tool.bind(SliceGrid.Tool.ERASE)],
		[UiStyle.icon("voxel_fill"), "[voxel_fill]", set_tool.bind(SliceGrid.Tool.FILL)],
		[UiStyle.icon("voxel_take"), "[voxel_take]", set_tool.bind(SliceGrid.Tool.TAKE)],
	], Kit.BUTTON_H)
	for b: Button in _tools.get_children():
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_right.add_child(grid)
	_paint = Kit.column(4)
	_right.add_child(_paint)
	_paint.add_child(_tools)
	var shade := Kit.row(4)
	_colour = Kit.swatch(grid.color, Kit.BUTTON_H)
	shade.add_child(_colour)
	var darker := Kit.button("[voxel_darker]", shade_colour.bind(-SHADE_STEP))
	darker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shade.add_child(darker)
	var lighter := Kit.button("[voxel_lighter]", shade_colour.bind(SHADE_STEP))
	lighter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shade.add_child(lighter)
	_paint.add_child(shade)
	_palette = GridContainer.new()
	_palette.add_theme_constant_override("h_separation", 2)
	_palette.add_theme_constant_override("v_separation", 2)
	_paint.add_child(_palette)
	_said = UiStyle.label("", UiStyle.MUTED)
	_said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_said.visible = false
	box.add_child(_said)
	_actions = Kit.row(4)
	var save_b := Kit.accent_button("[save]", save)
	save_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_actions.add_child(save_b)
	_undo = Kit.button("[editor_undo]", undo)
	_undo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_actions.add_child(_undo)
	var close_b := Kit.button("[close]")
	close_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_b.pressed.connect(func() -> void:
		if not unsaved or _ask.ask(close_b):
			close())
	_actions.add_child(close_b)
	box.add_child(_actions)
	set_tool(SliceGrid.Tool.PAINT)
	_fill_palette()
	_refresh()
	show_fitted()


func close() -> void:
	closed.emit()
	queue_free()


func back() -> void:
	close()


## The slice sides offered: every even one.
func _sizes() -> Array:
	var out := []
	for s in range(VoxelSheet.SIDE_MIN, VoxelSheet.SIDE_MAX + 1, 2):
		out.append(str(s))
	return out


func _side_index() -> int:
	return _sizes().find(str(sheet.side))


func _set_side(i: int) -> void:
	if sheet.resize(int(_sizes()[i])):
		_changed()
		fit()


func _set_level(i: int) -> void:
	grid.level = clampi(i, 0, sheet.levels - 1)
	_refresh()


## Puts a level above the one shown (a copy of it when `copy`) and shows it.
func add_level(copy: bool) -> void:
	if not sheet.add_level(grid.level, copy):
		say(Lang.line("[voxel_levels_most]", [VoxelSheet.LEVELS_MAX]))
		return
	grid.level += 1
	_changed()


## Takes the level shown out.
func remove_level() -> void:
	if sheet.remove_level(grid.level):
		grid.level = clampi(grid.level, 0, sheet.levels - 1)
		_changed()


func set_tool(t: int) -> void:
	grid.tool = t
	var buttons := _tools.get_children()
	for i in buttons.size():
		TabRow.light(buttons[i], i == t)


## Paints with `c` from now on (and as a leaf when `is_leaf`), the paint tool chosen.
func set_colour(c: Color, is_leaf: Variant = null) -> void:
	grid.color = VoxelSheet.exact(Color(c, 1.0))
	if is_leaf != null:
		grid.leafy = is_leaf
	if grid.tool != SliceGrid.Tool.FILL:
		set_tool(SliceGrid.Tool.PAINT)
	(_colour.get_child(0) as ColorRect).color = grid.color
	_choices.refresh()


func _taken(c: Color, is_leaf: bool) -> void:
	set_colour(c, is_leaf)


## Makes the colour painted lighter (`by` > 0) or darker.
func shade_colour(by: float) -> void:
	var c := grid.color
	set_colour(c.lightened(by) if by > 0.0 else c.darkened(-by))


## The palette's squares: the model's own colours first, then the game's not among them.
func _fill_palette() -> void:
	for c in _palette.get_children():
		_palette.remove_child(c)
		c.queue_free()
	var shown: Array[Color] = []
	for c in sheet.colours().slice(0, OWN_COLOURS):
		shown.append(c)
	for h: String in PALETTE:
		var c := Color(h)
		if not shown.has(c):
			shown.append(c)
	for c in shown:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(SWATCH, SWATCH)
		b.tooltip_text = "#" + c.to_html(false)
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			var s := StyleBoxFlat.new()
			s.bg_color = c
			s.border_color = UiStyle.ACCENT if state.begins_with("hover") else UiStyle.DARK_INK
			s.set_border_width_all(2)
			b.add_theme_stylebox_override(state, s)
		b.pressed.connect(set_colour.bind(c))
		_palette.add_child(b)


## Takes the last stroke or change back.
func undo() -> void:
	if sheet.undo():
		grid.level = clampi(grid.level, 0, sheet.levels - 1)
		_changed()


## Gives the model's PNG to be written.
func save() -> void:
	if sheet.count() == 0:
		say("[voxel_empty]")
		return
	saved.emit(sheet.png())
	unsaved = false
	_ask.disarm()


## Tells under the parts what happened.
func say(text: String) -> void:
	_said.text = text
	_said.visible = text != ""
	fit()


func _changed() -> void:
	unsaved = true
	_refresh()


## Shows the sheet anew: the grid, the picture, the rows' values.
func _refresh() -> void:
	_choices.rows[0].values = _level_names()
	_choices.refresh()
	grid.queue_redraw()
	preview.show_sheet(sheet, grid.level)
	if _undo != null:
		_undo.disabled = sheet.history.is_empty()


func _level_names() -> Array:
	var names := []
	for i in sheet.levels:
		names.append("%d/%d" % [i + 1, sheet.levels])
	return names


## Upright (taller than wide): one column, the picture and the rows over the grid, the
## tools and the palette under it; sideways: three, the picture and the rows, the grid,
## the tools and the palette. The grid takes the room left, square.
func layout(screen: Vector2) -> void:
	var room := screen - Vector2.ONE * 2 * MARGIN - Vector2(UiStyle.PAD.x + UiStyle.PAD.z, UiStyle.PAD.y + UiStyle.PAD.w)
	_wide = screen.x > screen.y * 1.15
	_body.vertical = not _wide
	var at := _right if not _wide else _body
	if _paint.get_parent() != at:
		_paint.get_parent().remove_child(_paint)
		at.add_child(_paint)
	# The title, the actions and what is said, with the gaps between.
	var bottom := Kit.BUTTON_H + 4 + _actions.get_combined_minimum_size().y + 4 + 6
	if _said.visible:
		bottom += _said.get_combined_minimum_size().y + 4
	var rows := (_left.get_child(1) as Control).get_combined_minimum_size()
	var side: float
	if _wide:
		var columns := 6
		_palette.columns = columns
		var paint_w := maxf(columns * (SWATCH + 2) - 2, _tools.get_combined_minimum_size().x)
		var p := clampf(room.y - bottom - rows.y - 4, PREVIEW_LEAST, PREVIEW_MOST)
		preview.custom_minimum_size = Vector2(p, p)
		side = minf(room.y - bottom, room.x - maxf(p, rows.x) - paint_w - 12)
	else:
		var width := minf(room.x, GRID_MOST)
		_palette.columns = maxi(1, int((width + 2) / (SWATCH + 2)))
		var under := _tools.get_combined_minimum_size().y + Kit.BUTTON_H + _palette_height(width) + 12
		var left := room.y - bottom - rows.y - under - 8
		var p := clampf(left * 0.35, PREVIEW_LEAST, PREVIEW_MOST)
		preview.custom_minimum_size = Vector2(p, p)
		side = minf(width, left - p)
	side = clampf(side, GRID_LEAST, GRID_MOST)
	grid.custom_minimum_size = Vector2(side, side)
	_right.custom_minimum_size.x = side
	panel.reset_size()


## How tall the palette is laid `width` across.
func _palette_height(width: float) -> float:
	var columns := maxi(1, int((width + 2) / (SWATCH + 2)))
	var count := _palette.get_child_count() if _palette != null else PALETTE.size()
	return ceilf(float(count) / columns) * (SWATCH + 2)
