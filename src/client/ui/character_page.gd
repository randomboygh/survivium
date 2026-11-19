extends BoxContainer
## The tab «Персонаж» of «Новая игра» (WorldSetup), «Создать сервер» (HostScreen) and
## «Присоединиться» (JoinScreen), first of their tabs (plan/mvp.md, stage 3: a character
## always belongs to its world): the figure drawn big (FigureStage, as on the inventory's
## «Персонаж»: turned by a drag, a tap or its arrows, `set_wide` on a wide screen) beside
## its rows in landscape (`vertical` false) or over them upright, the rows `rows_width`
## wide (inset as the settings' rows unless the window's page is; in a scroll of their
## own with `scrolls`, the window sizing it, `scroll`). The rows: the name the
## character goes by (ServerList's player name, kept as it is typed; on a server the
## others see it), then the looks (Looks: the body's build and figure, the hair style and
## colour, the skin, the eyes, the face and what is worn on it), «name ‹ value ›» rows of
## the kit (ChoiceRows) that show on the figure at once and are kept on the device as the
## name is (ServerList.player_looks). A new character takes them; one met again in its
## world keeps its own.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const Kit := preload("res://src/client/ui/kit/kit.gd")
const FigurePreview := preload("res://src/client/ui/figure_preview.gd")
const FigureStage := preload("res://src/client/ui/figure_stage.gd")
const ServerList := preload("res://src/client/net/server_list.gd")
const ChoiceRows := preload("res://src/client/ui/kit/choice_rows.gd")
const Looks := preload("res://src/shared/content/looks.gd")
const Figure := preload("res://src/client/view/figure.gd")

## The width of the looks rows' names.
const NAME_WIDTH := 96.0

signal name_changed(name: String)
## A look was picked (Looks).
signal looks_changed(looks: Dictionary)

var stage: FigureStage
var preview: FigurePreview
## The column of rows; a window adds its own under the name.
var rows: VBoxContainer
## The rows' own scroll (`scrolls`, «Новая игра»: they scroll in less on a short screen,
## WorldSetup.layout), else null.
var scroll: ScrollContainer = null
var name_field: LineEdit
## The looks picked (Looks.clean) and their rows (`key` steps them).
var looks := {}
var choices: ChoiceRows


func _init(rows_width: float, inset := true, scrolls := false) -> void:
	add_theme_constant_override("separation", 10)
	stage = FigureStage.new()
	add_child(stage)
	preview = stage.preview
	rows = Kit.column(4)
	rows.custom_minimum_size.x = rows_width
	rows.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if scrolls:
		# Inset as the settings' rows (Kit.scroll), the bar's room beside them.
		scroll = Kit.scroll(rows)
		add_child(scroll)
	else:
		add_child(UiStyle.inset(rows) if inset else rows)
	rows.add_child(Kit.caption("[name]"))
	name_field = Kit.field("[how_others_will_see_you]", 0.0, 0, Kit.FIELD_H)
	name_field.max_length = ServerList.NAME_MAX
	name_field.text = ServerList.player_name()
	name_field.text_changed.connect(func(t: String) -> void:
		ServerList.set_player_name(t.strip_edges())
		name_changed.emit(t.strip_edges()))
	name_field.text_submitted.connect(func(_t: String) -> void: name_field.release_focus())
	rows.add_child(name_field)
	looks = Looks.clean(ServerList.player_looks())
	choices = ChoiceRows.new(NAME_WIDTH, maxf(rows_width - NAME_WIDTH - 2 * Kit.SQUARE - 6, 60.0))
	choices.scroll = scroll
	rows.add_child(Kit.gap(4))
	_style_row("[body_build]", "build")
	_style_row("[body_figure]", "figure")
	_style_row("[hairstyle]", "hair")
	_colour_row("[hair_colour]", "hair_colour")
	_colour_row("[skin]", "skin")
	_colour_row("[eyes]", "eyes")
	_style_row("[face]", "face")
	_style_row("[on_face]", "on_face")
	choices.refresh()
	_show_looks()


## A row of the options of Looks field `field` (build, figure, hair, face, on_face), by
## their names.
func _style_row(title: String, field: String) -> void:
	var ids := Looks.ids(field)
	var styles: Dictionary = Looks.data().get(field, {})
	var names := ids.map(func(id: String) -> String: return str(styles.get(id, "[look_none]")) if id != "" else "[look_none]")
	choices.add(rows, title, names, func() -> int: return ids.find(looks[field]), _pick.bind(field, ids))


## A row of the colours of Looks field `field` (skin, hair_colour, eyes): their names,
## or their numbers where they have none (the skin).
func _colour_row(title: String, field: String) -> void:
	var all: Array = Looks.data().get(field, [])
	var names := []
	for i in all.size():
		names.append(str(all[i].get("name", i + 1)) if all[i] is Dictionary else str(i + 1))
	choices.add(rows, title, names, func() -> int: return looks[field], _pick.bind(field, []))


## Row `field` stepped to its option `i` (of `ids` for a style, a place for a colour).
func _pick(i: int, field: String, ids: Array) -> void:
	looks[field] = ids[i] if not ids.is_empty() else i
	looks = Looks.clean(looks)
	ServerList.set_player_looks(looks)
	_show_looks()
	looks_changed.emit(looks)


## The figure drawn for a wide screen (`wide`: a phone on its side, a PC) or an upright
## one, as big as the inventory draws it there.
func set_wide(wide: bool) -> void:
	stage.set_wide(wide)


## The figure in the looks picked.
func _show_looks() -> void:
	preview.dress(Figure.dressed({}, looks))
	preview.paint(looks)


## Up and down pick a looks row, left and right change it; with none picked left and
## right turn the figure. Whether `event` was taken.
func key(event: InputEvent) -> bool:
	if not (event is InputEventKey and event.pressed) or name_field.has_focus():
		return false
	if choices.focus < 0 and event.physical_keycode in [KEY_LEFT, KEY_RIGHT]:
		preview.turn(1 if event.physical_keycode == KEY_RIGHT else -1)
		return true
	if choices.focus == 0 and event.physical_keycode in [KEY_UP, KEY_W]:
		# Above the first row: left and right turn the figure again.
		choices.focus = -1
		for r in choices.rows:
			r.name.add_theme_color_override("font_color", UiStyle.INK)
		return true
	return choices.key(event)


## The name typed, its spaces at the ends gone ("" when none).
func character_name() -> String:
	return name_field.text.strip_edges()
