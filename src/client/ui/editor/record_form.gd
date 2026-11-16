extends VBoxContainer
## The form of one record in the content editor (content_editor.gd), made from its kind's
## schema (Content.schema): a row per field, its name on the left (in the game's language,
## FieldNames; under the row a line on what it does and the YAML's name) and what
## changes it on the right — a switch for a bool, a row of values with arrows for a
## choice of a few (an enum, a whole number in a short range), a text field for the rest
## (a number, a word, an id, or a list or mapping written as YAML on one line:
## `[a, b]`, `{core:fiber: 2}`). A field left at its default is faded, one with a wrong
## value red. `values` gives every field's value as the data holds it; `errors` checks
## them as the loader would (ContentEdits.check). On top, the title and the description
## as the player reads them, in the game's language (`texts_changed`: they are written as
## phrases of the mod, ContentEdits.save).

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const Kit := preload("res://src/client/ui/kit/kit.gd")
const ChoiceRows := preload("res://src/client/ui/kit/choice_rows.gd")
const Content := preload("res://src/shared/content/content.gd")
const ContentEdits := preload("res://src/shared/content/content_edits.gd")
const Yaml := preload("res://src/shared/content/yaml.gd")
const Lang := preload("res://src/shared/content/lang.gd")
const FieldNames := preload("res://src/client/ui/editor/field_names.gd")

## The fields not in the form: the id, the title and description (texts on top), the
## loader's own.
const HIDDEN := ["id", "title", "description", "mod", "bundle"]
## The texts on top, each with its name.
const TEXTS := [["title", "[editor_title]"], ["description", "[editor_about]"]]
## A whole number whose range holds no more values than this is a row of values.
const MOST_STEPS := 32
## The width of the value between the arrows of a row of values.
const VALUE_WIDTH := 120.0
## The types written as YAML on one line.
const WRITTEN := ["list", "amounts", "shares", "entries", "vec3", "colors"]

## A field's value was changed.
signal edited
## A picture is wanted for picture field `field` (ContentEdits.PICTURES): its button was tapped.
signal picture_wanted(field: String)

## The tallest a picture's preview is drawn, in UI px.
const PREVIEW_H := 48.0

var kind: String
## The record as loaded (defaults filled in, patches applied).
var rec: Dictionary
## Field -> [its type, its name Label, the control that holds its value].
var fields := {}
## Text ("title", "description") -> [its name Label, its LineEdit, the text as it was].
var texts := {}
var _choices: ChoiceRows
## The values picked on the rows of values, by field.
var _picked := {}


func _init(kind_: String, rec_: Dictionary, name_width: float) -> void:
	kind = kind_
	rec = rec_
	add_theme_constant_override("separation", 2)
	_choices = ChoiceRows.new(name_width, VALUE_WIDTH, Kit.SQUARE)
	for t: Array in TEXTS:
		_phrase(t[0], t[1], name_width)
	var schema: Dictionary = Content.schema(kind)
	for field: String in schema:
		if field in HIDDEN:
			continue
		var spec: Dictionary = schema[field]
		var value: Variant = ContentEdits.data_of(rec.get(field, spec.get("default")))
		var steps := _steps(spec)
		if spec.type == "bool":
			_switch(field, value == true, name_width)
		elif not steps.is_empty():
			_picked[field] = steps.find(str(value))
			_choices.add(self, FieldNames.of(kind, field)[0], steps, func() -> int: return _picked[field],
				func(i: int) -> void:
					_picked[field] = i
					_mark(field)
					edited.emit(), {"stop": spec.type == "int"})
			fields[field] = ["choice", _choices.rows[-1].name, steps]
		else:
			_text(field, value, spec, name_width)
		if ContentEdits.PICTURES.has("%s.%s" % [kind, field]):
			_picture(field, name_width)
		_about(field)
		_mark(field)
	_choices.refresh()


## The values a field is picked from on a row of values, [] for a field written.
static func _steps(spec: Dictionary) -> Array:
	if spec.type == "enum":
		return spec.values.duplicate()
	if spec.type == "int" and spec.has("min") and spec.has("max") and spec.max - spec.min < MOST_STEPS:
		return range(spec.min, spec.max + 1).map(func(i: int) -> String: return str(i))
	return []


func _switch(field: String, on: bool, name_width: float) -> void:
	var row := Kit.row(4)
	var name := _name(FieldNames.of(kind, field)[0], name_width)
	row.add_child(name)
	var sw := Kit.check("", on)
	sw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sw.toggled.connect(func(_on: bool) -> void:
		_mark(field)
		edited.emit())
	row.add_child(sw)
	add_child(row)
	fields[field] = ["bool", name, sw]


func _text(field: String, value: Variant, spec: Dictionary, name_width: float) -> void:
	var row := Kit.row(4)
	var name := _name(FieldNames.of(kind, field)[0], name_width)
	row.add_child(name)
	var hint := ""
	if spec.has("min") or spec.has("max"):
		hint = "%s…%s" % [spec.get("min", ""), spec.get("max", "")]
	var f := Kit.field(hint)
	f.text = value if value is String else Yaml.inline(value)
	f.text_changed.connect(func(_t: String) -> void:
		_mark(field)
		edited.emit())
	row.add_child(f)
	add_child(row)
	fields[field] = ["text", name, f]


func _phrase(field: String, title: String, name_width: float) -> void:
	var row := Kit.row(4)
	var name := _name(title, name_width)
	row.add_child(name)
	var was := Lang.t(str(rec.get(field, "")))
	if field == "title" and was == str(rec.get("id", "")):
		was = ""
	var f := Kit.field()
	f.text = was
	f.text_changed.connect(func(t: String) -> void:
		name.add_theme_color_override("font_color", UiStyle.ACCENT if t.strip_edges() != was else UiStyle.INK)
		edited.emit())
	row.add_child(f)
	add_child(row)
	texts[field] = [name, f, was]


## The texts changed ({"title": …, "description": …}), as written, in the game's language.
func texts_changed() -> Dictionary:
	var out := {}
	for field: String in texts:
		var now: String = (texts[field][1] as LineEdit).text.strip_edges()
		if now != texts[field][2]:
			out[field] = now
	return out


## A picture field's row of its own: the picture as it is (a preview, nearest pixels) and
## «PNG…», which asks for another (`picture_wanted`).
func _picture(field: String, name_width: float) -> void:
	var row := Kit.row(4)
	var room := Control.new()
	room.custom_minimum_size.x = name_width
	row.add_child(room)
	var img := Content.picture(ContentEdits.picture_path(kind, rec, field))
	if img != null:
		var view := TextureRect.new()
		view.texture = ImageTexture.create_from_image(img)
		view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		var h := minf(PREVIEW_H, img.get_height() * maxf(1.0, floorf(PREVIEW_H / img.get_height())))
		view.custom_minimum_size = Vector2(minf(img.get_width() * h / img.get_height(), PREVIEW_H * 2.5), h)
		view.tooltip_text = "%d×%d" % [img.get_width(), img.get_height()]
		row.add_child(view)
	var b := Kit.button("[editor_pick_png]", func() -> void: picture_wanted.emit(field))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(b)
	add_child(row)


## The line under field `field`'s row: what it does, and its name in the YAML.
func _about(field: String) -> void:
	var about: String = FieldNames.of(kind, field)[1]
	var text := field if about == "" else "%s · %s" % [Lang.t(about), field]
	var l := UiStyle.label(text, UiStyle.MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	add_child(l)


func _name(field: String, width: float) -> Label:
	var l := UiStyle.label(field)
	l.custom_minimum_size.x = width
	l.clip_text = true
	l.tooltip_text = field
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	return l


## Every field's value as the data holds it; a text that does not read is left as text
## (`errors` names it).
func values() -> Dictionary:
	var out := {}
	for field: String in fields:
		out[field] = value(field)
	return out


## Field `field`'s value as the data holds it.
func value(field: String) -> Variant:
	var f: Array = fields[field]
	var spec: Dictionary = Content.schema(kind)[field]
	match f[0]:
		"bool":
			return (f[2] as Button).button_pressed
		"choice":
			var s: String = f[2][maxi(_picked[field], 0)]
			return s.to_int() if spec.type == "int" else s
	var text: String = (f[2] as LineEdit).text.strip_edges()
	match spec.type:
		"int":
			return text.to_int() if text.is_valid_int() else text
		"float":
			return text.to_float() if text.is_valid_float() else text
	if spec.type in WRITTEN or (text.begins_with("[") or text.begins_with("{")):
		if text == "":
			return spec.get("default", [])
		var yaml := Yaml.new()
		var v: Variant = yaml.parse(text)
		return v if yaml.error == "" else text
	return text


## The names of the fields whose values are wrong for mod `mod`'s data, each lit red.
func errors(mod: String) -> Array:
	var out := []
	for field: String in fields:
		var why := ContentEdits.check(kind, field, value(field), mod)
		if why != "":
			out.append(field)
			(fields[field][1] as Label).add_theme_color_override("font_color", UiStyle.DANGER)
			(fields[field][1] as Label).tooltip_text = why
	return out


## Fades a field at its default, lights one changed from the record.
func _mark(field: String) -> void:
	var l: Label = fields[field][1]
	var spec: Dictionary = Content.schema(kind)[field]
	var v: Variant = value(field)
	var was: Variant = ContentEdits.data_of(rec.get(field, spec.get("default")))
	var color := UiStyle.INK
	if var_to_str(v) != var_to_str(was):
		color = UiStyle.ACCENT
	elif spec.has("default") and var_to_str(v) == var_to_str(ContentEdits.data_of(spec.default)):
		color = UiStyle.MUTED
	l.add_theme_color_override("font_color", color)
	l.tooltip_text = field
