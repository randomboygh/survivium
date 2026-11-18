extends BoxContainer
## The tab «Персонаж» of «Новая игра» (WorldSetup), «Создать сервер» (HostScreen) and
## «Присоединиться» (JoinScreen), first of their tabs (plan/mvp.md, stage 3: a character
## always belongs to its world): the figure drawn big (FigurePreview, turned by a drag
## or a tap) beside its rows in landscape (`vertical` false) or over them upright, the
## rows `rows_width` wide (inset as the settings' rows unless the window's page is). The rows: the name the character goes by (ServerList's
## player name, kept as it is typed; on a server the others see it). The looks to choose
## (the build, the hair, the colours) come as rows under it.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const Kit := preload("res://src/client/ui/kit/kit.gd")
const FigurePreview := preload("res://src/client/ui/figure_preview.gd")
const ServerList := preload("res://src/client/net/server_list.gd")

signal name_changed(name: String)

var preview: FigurePreview
## The column of rows; a window adds its own under the name.
var rows: VBoxContainer
var name_field: LineEdit


func _init(rows_width: float, inset := true) -> void:
	add_theme_constant_override("separation", 10)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiStyle.slot())
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(frame)
	preview = FigurePreview.new()
	preview.tooltip_text = "[drag_to_turn_the_character]"
	frame.add_child(preview)
	rows = Kit.column(4)
	rows.custom_minimum_size.x = rows_width
	rows.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
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


## The name typed, its spaces at the ends gone ("" when none).
func character_name() -> String:
	return name_field.text.strip_edges()
