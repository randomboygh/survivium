extends "res://src/client/ui/kit/window.gd"
## The content editor (stage 2, decision 186, 11А): every kind of the mods' records
## (Content.SCHEMAS), a kind's records found by name or id, and a record's fields as a
## form (RecordForm) whose changes are saved into one's own mod chosen on top (OwnMods,
## several, 3Б): into the record itself when it is that mod's, else as a patch of the
## other's (2А); «Undo» takes the last save back. A save is read into the game at once
## (ModReload.reload) and the mod joins the world being played (its bundles). A record's
## «Copy» makes a new record of the mod from it (ContentEdits.copy), «Delete» takes one's
## own record out, «Reset» one's patch of another's; the title and description are
## written in the game's language as the mod's phrases; a picture field's «PNG…» takes a
## picture from the device into the mod (PicturePick, ContentEdits.picture), a model's
## «Edit model» opens the voxel editor (VoxelEditor) and its save is written so. One column
## on every screen (12А). Opened from the main menu and the pause menu («Editor»);
## «Close» or Escape closes it. `game` is the Main node.

const ChoiceRows := preload("res://src/client/ui/kit/choice_rows.gd")
const RecordForm := preload("res://src/client/ui/editor/record_form.gd")
const Content := preload("res://src/shared/content/content.gd")
const ContentEdits := preload("res://src/shared/content/content_edits.gd")
const OwnMods := preload("res://src/shared/content/own_mods.gd")
const ModFiles := preload("res://src/shared/content/mod_files.gd")
const Mods := preload("res://src/shared/content/mods.gd")
const Lang := preload("res://src/shared/content/lang.gd")
const PicturePick := preload("res://src/client/ui/editor/picture_pick.gd")
const VoxelSheet := preload("res://src/client/ui/editor/voxel_sheet.gd")
const VOXEL_EDITOR := "res://src/client/ui/editor/voxel_editor.gd"

## The kinds in the order shown, each with its name.
const KINDS := [["items", "[editor_items]"], ["materials", "[editor_materials]"],
	["recipes", "[editor_recipes]"], ["creatures", "[editor_creatures]"], ["trees", "[editor_trees]"],
	["bushes", "[editor_bushes]"], ["plants", "[editor_plants]"], ["biomes", "[editor_biomes]"],
	["skills", "[editor_skills]"], ["eras", "[editor_eras]"], ["starts", "[editor_starts]"],
	["sounds", "[editor_sounds]"]]
## The most records listed at once: a search narrows the rest.
const MOST_LISTED := 120
## The widest and tallest the window's list grows on a big screen.
const MOST_WIDTH := 480
const MOST_HEIGHT := 600
const NAME_WIDTH := 112
const VALUE_WIDTH := 150

signal closed

## The own mod saves go into, and the writes that can be taken back: kept while the
## game runs, from one opening of the editor to the next.
static var mod := ""
static var edits := ContentEdits.new()

var game
## The kind shown and the record open in it ("" for the kind's list).
var kind := "items"
var record := ""
## The form of the record open, null on the list.
var form: RecordForm
var _choices := ChoiceRows.new(NAME_WIDTH, VALUE_WIDTH, Kit.SQUARE)
var _top: VBoxContainer
var _new_mod: HBoxContainer
var _new_mod_field: LineEdit
var _search: LineEdit
var _scroll: ScrollContainer
var _list: VBoxContainer
var _actions: HBoxContainer
var _save: Button
var _undo: Button
var _copy_row: HBoxContainer
var _copy_field: LineEdit
var _said: Label


func _init(g) -> void:
	game = g


func _ready() -> void:
	build("[editor]", 4)
	if not mod in OwnMods.list():
		mod = OwnMods.list()[0] if not OwnMods.list().is_empty() else ""
	_top = Kit.column(4)
	box.add_child(_top)
	_choices.add(_top, "[editor_mod]", OwnMods.list(), _mod_index, _set_mod,
		{"other": "[editor_no_mod]", "open": _toggle_new_mod, "open_icon": "plus", "open_tip": "[editor_new_mod]"})
	_new_mod = Kit.row(4)
	_new_mod_field = Kit.field("[editor_mod_id]", 0.0, 32)
	_new_mod_field.text_submitted.connect(func(_t: String) -> void: _make_mod())
	_new_mod.add_child(_new_mod_field)
	_new_mod.add_child(Kit.button("[editor_create]", _make_mod))
	_new_mod.visible = false
	_top.add_child(_new_mod)
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
	_said = UiStyle.label("", UiStyle.MUTED)
	_said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_said)
	_actions = Kit.row(4)
	_save = Kit.accent_button("[save]", save)
	_save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_actions.add_child(_save)
	_undo = Kit.button("[editor_undo]", undo)
	_undo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_actions.add_child(_undo)
	box.add_child(_actions)
	box.add_child(Kit.button("[close]", close))
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


func _mod_index() -> int:
	return OwnMods.list().find(mod)


func _set_mod(i: int) -> void:
	mod = OwnMods.list()[i]
	_update_actions()


func _toggle_new_mod() -> void:
	_new_mod.visible = not _new_mod.visible
	if _new_mod.visible:
		_new_mod_field.grab_focus()
	fit()


## Makes the own mod whose id is in the field and chooses it.
func _make_mod() -> void:
	var id := _new_mod_field.text.strip_edges().to_lower()
	if not OwnMods.valid_id(id) or id in Mods.available():
		say("[editor_bad_mod_id]")
		return
	var error := OwnMods.make(id, id.capitalize())
	if error != "":
		printerr("editor: ", error)
		say("[editor_bad_mod_id]")
		return
	mod = id
	_new_mod_field.text = ""
	_new_mod.visible = false
	_choices.rows[0].values = OwnMods.list()
	_choices.refresh()
	say(Lang.line("[editor_mod_made]", [id]))
	fit()


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


## Tells under the list what happened.
func say(text: String) -> void:
	_said.text = text
	_said.visible = text != ""
	fit()


## Shows the kind's list.
func _show_list() -> void:
	record = ""
	form = null
	_top.visible = true
	_clear()
	var all := records()
	for r: Array in all.slice(0, MOST_LISTED):
		var b := Kit.button(r[0], open.bind(r[1]))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.tooltip_text = r[1]
		_list.add_child(b)
	if all.is_empty():
		_list.add_child(Kit.note("[editor_nothing_found]"))
	elif all.size() > MOST_LISTED:
		_list.add_child(Kit.note(Lang.line("[editor_more_records]", [all.size() - MOST_LISTED])))
	_scroll.scroll_vertical = 0
	_update_actions()
	fit()


## Opens record `id` of the kind shown as a form, with where it comes from.
func open(id: String) -> void:
	record = id
	_top.visible = false
	_clear()
	var rec := Content.find(kind, id)
	_list.add_child(Kit.button("[back]", _show_list))
	_list.add_child(Kit.title(Lang.t(str(rec.get("title", id)))))
	_list.add_child(Kit.note(id))
	_record_actions(id)
	var from := Content.origin(kind, id)
	_list.add_child(Kit.note(Lang.line("[editor_from_bundle]", [str(rec.get("bundle", rec.get("mod", "")))])))
	if not from.get("patched", []).is_empty():
		_list.add_child(Kit.note(Lang.line("[editor_patched_by]", [", ".join(from.patched)])))
	form = RecordForm.new(kind, rec, NAME_WIDTH)
	form.edited.connect(_update_actions)
	form.picture_wanted.connect(_pick_picture)
	form.model_wanted.connect(edit_model)
	_list.add_child(form)
	_update_actions()
	fit()


## Saves the fields changed in the form into the chosen own mod and reads the mods again.
func save() -> void:
	if form == null or mod == "":
		return
	var bad := form.errors(mod)
	if not bad.is_empty():
		say(Lang.line("[editor_fix_fields]", [", ".join(bad)]))
		return
	var fields := ContentEdits.changed(kind, form.rec, form.values())
	var texts := form.texts_changed()
	if fields.is_empty() and texts.is_empty():
		say("[editor_nothing_changed]")
		return
	var error := edits.save(mod, kind, record, fields, texts)
	if error != "":
		printerr("editor: ", error)
		say("[editor_not_saved]")
		return
	_apply()
	say(Lang.line("[editor_saved]", [fields.size() + texts.size(), mod]))


## Asks the device for a PNG for picture field `field` of the record open.
func _pick_picture(field: String) -> void:
	if mod == "":
		say("[editor_make_a_mod_first]")
		return
	if not PicturePick.can_pick():
		say("[editor_cannot_pick]")
		return
	PicturePick.pick(set_picture.bind(field))


## Opens the voxel editor on model field `field` of the record open (its model, or an
## empty one), this window hidden while it is open; its «Save» writes the model into the
## chosen mod (`set_picture`). Returns the voxel editor.
func edit_model(field: String) -> Control:
	if mod == "":
		say("[editor_make_a_mod_first]")
		return null
	var rec := Content.find(kind, record)
	var img := Content.picture(ContentEdits.picture_path(kind, rec, field))
	# A thing placed on cells has its slices' corner at the cell's; one lying, its middle.
	var sheet: VoxelSheet = VoxelSheet.of(img, str(rec.get("prop", "none")) == "none")
	var voxels: Control = load(VOXEL_EDITOR).new(sheet, Lang.t(str(rec.get("title", record))))
	voxels.saved.connect(func(png: PackedByteArray) -> void:
		var ok := set_picture(png, "%s.png" % record, field)
		voxels.say(Lang.line("[voxel_saved]", [mod]) if ok else _said.text))
	voxels.closed.connect(func() -> void:
		visible = true
		fit())
	visible = false
	get_parent().add_child(voxels)
	return voxels


## Writes picture `bytes` for picture field `field` of the record open into the chosen mod.
## Whether it was written.
func set_picture(bytes: PackedByteArray, file: String, field: String) -> bool:
	if record == "" or mod == "":
		return false
	if not ModFiles.may_be(bytes, "png"):
		say(Lang.line("[editor_bad_png]", [ModFiles.PICTURE_MAX]))
		return false
	var error := edits.picture(mod, kind, record, field, bytes)
	if error != "":
		printerr("editor: ", error)
		say("[editor_not_saved]")
		return false
	_apply()
	say(Lang.line("[editor_picture_set]", [file]))
	return true


## The record's own buttons: «Copy» (with its row for the new id, hidden), «Delete» for
## the chosen mod's own record, «Reset» for its patch of another's.
func _record_actions(id: String) -> void:
	var row := Kit.row(4)
	var copy := Kit.button("[editor_copy]", _toggle_copy)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(copy)
	if mod != "" and ContentEdits.owns(mod, kind, id):
		var b := Kit.button("[editor_delete]", delete)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	elif mod != "" and OwnMods._find(OwnMods.records(mod, kind), id) >= 0:
		var b := Kit.button("[editor_reset]", delete)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	_list.add_child(row)
	_copy_row = Kit.row(4)
	_copy_field = Kit.field("[editor_new_id]", 0.0, 32)
	_copy_field.text_submitted.connect(func(_t: String) -> void: copy_record())
	_copy_row.add_child(_copy_field)
	_copy_row.add_child(Kit.button("[editor_create]", copy_record))
	_copy_row.visible = false
	_list.add_child(_copy_row)


func _toggle_copy() -> void:
	if mod == "":
		say("[editor_make_a_mod_first]")
		return
	_copy_row.visible = not _copy_row.visible
	if _copy_row.visible:
		_copy_field.grab_focus()
	fit()


## Makes a copy of the record open under the id in the field, in the chosen mod, and opens it.
func copy_record() -> void:
	var name := _copy_field.text.strip_edges().to_lower()
	var id := "%s:%s" % [mod, name]
	if mod == "" or not OwnMods.valid_id(name) or not Content.find(kind, id).is_empty():
		say("[editor_bad_record_id]")
		return
	var error := edits.copy(mod, kind, record, name)
	if error != "":
		printerr("editor: ", error)
		say("[editor_bad_record_id]")
		return
	record = id
	_apply()
	say(Lang.line("[editor_copied]", [id]))


## Takes the record open out of the chosen mod: its own record (back to the list), or its
## patch of another's (the record as its mod has it).
func delete() -> void:
	var own := ContentEdits.owns(mod, kind, record)
	var error := edits.delete(mod, kind, record)
	if error != "":
		printerr("editor: ", error)
		say("[editor_not_saved]")
		return
	if own:
		record = ""
	_apply()
	if own:
		_show_list()
	say("[editor_deleted]" if own else "[editor_reset_done]")


## Takes the last save back and reads the mods again.
func undo() -> void:
	if edits.history.is_empty():
		return
	var error := edits.undo()
	if error != "":
		printerr("editor: ", error)
	_apply()
	say("[editor_undone]")


## Reads the mods again with the chosen one in the world's set, and shows the record anew.
func _apply() -> void:
	join(mod)
	if game != null and game.mod_reload != null:
		game.mod_reload.reload()
	else:
		Mods.rescan(true)
	var problems := Array(Content.problems).filter(func(p: String) -> bool: return p.contains(mod))
	if record != "" and Content.find(kind, record).is_empty():
		_show_list()
	elif record != "":
		open(record)
	if not problems.is_empty():
		say(Lang.line("[editor_mod_problems]", [problems[0]]))


## Own mod `id`'s bundles join the bundles loaded and the world being played, so its
## records and patches are read (Mods.of_world keeps them with the world's save).
func join(id: String) -> void:
	ModFiles.read_extra()
	Content.refresh()
	var have: Array = Content.BUNDLES
	var on := Mods.all().filter(func(b: String) -> bool: return b in have or Mods.mod_of(b) == id)
	Content.BUNDLES = on
	if game != null and not game.world_mods.is_empty():
		game.world_mods = Mods.all().filter(func(b: String) -> bool: return b in game.world_mods or Mods.mod_of(b) == id)


func _update_actions() -> void:
	_actions.visible = form != null or not edits.history.is_empty()
	_save.visible = form != null
	_save.disabled = mod == ""
	_save.tooltip_text = "" if mod != "" else "[editor_make_a_mod_first]"
	_undo.disabled = edits.history.is_empty()


func _clear() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()


func layout(screen: Vector2) -> void:
	var width := minf(screen.x - 2 * MARGIN - UiStyle.PAD.x - UiStyle.PAD.z, MOST_WIDTH)
	_scroll.custom_minimum_size = Vector2(width, 0)
	_said.custom_minimum_size.x = width
	panel.reset_size()
	var rest := panel.get_combined_minimum_size().y
	_scroll.custom_minimum_size.y = clampf(screen.y - 2 * MARGIN - rest, 80.0, MOST_HEIGHT)
