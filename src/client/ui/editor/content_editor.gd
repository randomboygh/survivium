extends "res://src/client/ui/kit/window.gd"
## The content editor (stage 2, decision 186, 11А): every kind of the mods' records
## (Content.SCHEMAS), a kind's records found by name or id, and a record's fields as the
## game reads them (defaults filled in, patches applied), a field left at its default
## faded. One column on every screen (12А). Opened from the pause menu over the running
## world; «Close» or Escape closes it. This first part only shows; the forms that change
## a record and write it into one's own mod (OwnMods) come next.
## `game` is the Main node.

const ChoiceRows := preload("res://src/client/ui/kit/choice_rows.gd")
const Content := preload("res://src/shared/content/content.gd")
const Lang := preload("res://src/shared/content/lang.gd")
const Yaml := preload("res://src/shared/content/yaml.gd")

## The kinds in the order shown, each with its name.
const KINDS := [["items", "[editor_items]"], ["materials", "[editor_materials]"],
	["recipes", "[editor_recipes]"], ["creatures", "[editor_creatures]"], ["trees", "[editor_trees]"],
	["bushes", "[editor_bushes]"], ["plants", "[editor_plants]"], ["biomes", "[editor_biomes]"],
	["skills", "[editor_skills]"], ["eras", "[editor_eras]"], ["starts", "[editor_starts]"],
	["sounds", "[editor_sounds]"]]
## The fields every record has that are not the schema's, not shown as fields.
const HIDDEN := ["id", "title", "mod", "bundle"]
## The most records listed at once: a search narrows the rest.
const MOST_LISTED := 120
## The widest and tallest the window's list grows on a big screen.
const MOST_WIDTH := 480
const MOST_HEIGHT := 600
const NAME_WIDTH := 112
const VALUE_WIDTH := 150

signal closed

var game
## The kind shown and the record open in it ("" for the kind's list).
var kind := "items"
var record := ""
var _choices := ChoiceRows.new(NAME_WIDTH, VALUE_WIDTH, Kit.SQUARE)
var _top: VBoxContainer
var _search: LineEdit
var _scroll: ScrollContainer
var _list: VBoxContainer


func _init(g) -> void:
	game = g


func _ready() -> void:
	build("[content_editor]", 4)
	_top = Kit.column(4)
	box.add_child(_top)
	var names := []
	for k: Array in KINDS:
		names.append(k[1])
	_choices.add(_top, "[editor_kind]", names, _kind_index, _set_kind)
	_choices.refresh()
	_search = Kit.field("[editor_search]")
	_search.text_changed.connect(func(_t: String) -> void: _show_list())
	_top.add_child(_search)
	_list = Kit.column(2)
	_scroll = Kit.scroll(_list)
	box.add_child(_scroll)
	box.add_child(Kit.button("[close]", close))
	get_parent().resized.connect(fit)
	_show_list()
	show_fitted()


func close() -> void:
	closed.emit()
	queue_free()


## Back from a record to its kind's list, else closes.
func back() -> void:
	if record != "":
		_show_list()
	else:
		close()


func _kind_index() -> int:
	for i in KINDS.size():
		if KINDS[i][0] == kind:
			return i
	return 0


func _set_kind(i: int) -> void:
	kind = KINDS[i][0]
	_search.text = ""
	_show_list()


## The records of the kind shown, by title, those whose title or id holds the search.
func records() -> Array:
	var find := _search.text.strip_edges().to_lower() if _search != null else ""
	var out := []
	for r: Dictionary in Content.records(kind):
		var title := Lang.t(str(r.get("title", r.id)))
		if find == "" or title.to_lower().contains(find) or str(r.id).contains(find):
			out.append([title, r.id])
	out.sort_custom(func(a: Array, b: Array) -> bool: return a[0].naturalnocasecmp_to(b[0]) < 0)
	return out


## Shows the kind's list.
func _show_list() -> void:
	record = ""
	_top.visible = true
	_clear()
	var all := records()
	for r: Array in all.slice(0, MOST_LISTED):
		var b := Kit.button(r[0], _open.bind(r[1]))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.tooltip_text = r[1]
		_list.add_child(b)
	if all.is_empty():
		_list.add_child(Kit.note("[editor_nothing_found]"))
	elif all.size() > MOST_LISTED:
		_list.add_child(Kit.note(Lang.line("[editor_more_records]", [all.size() - MOST_LISTED])))
	_scroll.scroll_vertical = 0
	fit()


## Shows record `id` of the kind shown: where it comes from and its fields.
func _open(id: String) -> void:
	record = id
	_top.visible = false
	_clear()
	var rec := Content.find(kind, id)
	_list.add_child(Kit.button("[back]", _show_list))
	_list.add_child(Kit.title(Lang.t(str(rec.get("title", id)))))
	_list.add_child(Kit.note(id))
	var from := Content.origin(kind, id)
	_list.add_child(Kit.note(Lang.line("[editor_from_bundle]", [str(rec.get("bundle", rec.get("mod", "")))])))
	if not from.get("patched", []).is_empty():
		_list.add_child(Kit.note(Lang.line("[editor_patched_by]", [", ".join(from.patched)])))
	var schema: Dictionary = Content.schema(kind)
	for field: String in schema:
		if field in HIDDEN:
			continue
		var value: Variant = rec.get(field, schema[field].get("default"))
		var row := Kit.row(4)
		var name := UiStyle.label(field)
		name.custom_minimum_size.x = NAME_WIDTH
		name.clip_text = true
		row.add_child(name)
		var at_default: bool = schema[field].has("default") and var_to_str(value) == var_to_str(schema[field].default)
		var shown := UiStyle.label(_text(value), UiStyle.MUTED if at_default else UiStyle.INK)
		shown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		shown.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		row.add_child(shown)
		_list.add_child(row)
	_scroll.scroll_vertical = 0
	fit()


## A field's value as one line of text (the engine's types back to the data's).
static func _text(value: Variant) -> String:
	if value is Color:
		return "#" + value.to_html(false)
	if value is Vector3 or value is Vector3i or value is Vector2 or value is Vector2i:
		return str(value)
	if value is String and value == "":
		return "-"
	return Yaml.inline(value)


func _clear() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()


func layout(screen: Vector2) -> void:
	var width := minf(screen.x - 2 * MARGIN - UiStyle.PAD.x - UiStyle.PAD.z, MOST_WIDTH)
	_scroll.custom_minimum_size = Vector2(width, 0)
	panel.reset_size()
	var rest := panel.get_combined_minimum_size().y
	_scroll.custom_minimum_size.y = clampf(screen.y - 2 * MARGIN - rest, 80.0, MOST_HEIGHT)
