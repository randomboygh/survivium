extends RefCounted
## The languages of the game (decisions 183, 186). Every text a player reads is a key in
## square brackets, `"[bag_is_full]"` in the code and `title: "[tools.items.stone_axe]"` in
## a mod's data, and a language is a table of those keys put into it, `lang/<code>.yaml`:
## the interface's in `content/core/lang/`, each bundle's own beside its `data/`
## (`content/animals/wolf/lang/en.yaml`), so a mod brings its words with it. A file is a
## flat mapping `"[key]": "Phrase"`; what a language lacks is taken from English, and what
## English lacks shows as the key itself. Text that is no key shows as written.
##
## The client sets the language (`use`): Godot's TranslationServer then puts every
## Control's and Label3D's text through the table by itself, and the code puts the
## phrases it builds through `tr()` (or `Lang.t` in a static func). The server never
## translates: a phrase it builds with values in it goes out as a `line` (the template
## and the values, packed into one String), which the table turns into the reader's
## language wherever it is shown, the values that are phrases too (a thing's title).
## `tools/lang_check.py` lists what a language lacks.

const Content := preload("res://src/shared/content/content.gd")

## The languages a player may choose: [code, the language's own name]. The first one
## is the language of a new player whose device speaks none of them.
const LANGS := [
	["en", "English"],
	["ru", "[phrase]"],
	["es", "Español"],
	["pt", "Português"],
	["fr", "Français"],
	["de", "Deutsch"],
	["it", "Italiano"],
	["pl", "Polski"],
	["tr", "Türkçe"],
	["uk", "[phrase_n2]"],
]
## The language every other one falls back to.
const SOURCE := "en"
## What begins a `line`: the rest is JSON of [template, values...] (JSON, not var_to_str:
## a server's text must not make objects on the client).
const LINE := "\u001e"

## The language in use ("" before `use`).
static var code := ""
## The table in the TranslationServer.
static var _table: Translation = null
## The phrases read, by language: a new scene (the menu, a world) uses them again.
static var _read := {}
## While on (the scene tests), every text the screen is given to show (`seen`) is put
## into Russian, and the ones that keep a key or stay English are kept in `missed`: a
## phrase glued from pieces, built with `%` instead of `line`, written as text instead
## of a key, or missing from the language files.
static var watching := false
static var missed: Array[String] = []
static var _russian: Table = null
static var _key_in: RegEx = null
static var _latin: RegEx = null
static var _cyrillic: RegEx = null
## English, for code that puts a phrase into words with no language set (the server,
## the tests): read when first needed.
static var _english: Table = null


## The table of one language: the phrases it has (`words`), the rest from English
## (`fallback`), and the lines (LINE) taken apart and put together in it.
class Table extends Translation:
	var words := {}
	var fallback := {}

	func _get_message(src: StringName, _context: StringName) -> StringName:
		var s := String(src)
		if s.begins_with(LINE):
			return StringName(text_of(s))
		return StringName(_word(s))

	func _word(s: String) -> String:
		var out: String = words.get(s, "")
		if out == "":
			out = fallback.get(s, "")
		return out

	## Phrase `s` in this language, a `line` put together; `s` itself when the table
	## lacks it.
	func text_of(s: String) -> String:
		if not s.begins_with(LINE):
			var w := _word(s)
			return w if w != "" else s
		var json := JSON.new()
		if json.parse(s.substr(LINE.length())) != OK:
			return s
		var parts = json.data
		if not parts is Array or parts.is_empty() or not parts[0] is String:
			return s
		var values := []
		for i in range(1, parts.size()):
			var v = parts[i]
			values.append(text_of(v) if v is String else v)
		var template := text_of(parts[0])
		if values.is_empty():
			return template
		return template % values


## Puts the game into language `lang_code` (one of LANGS; anything else is English):
## reads its files and English's, and tells the TranslationServer.
static func use(lang_code: String) -> void:
	if not known(lang_code):
		lang_code = LANGS[0][0]
	if _table != null:
		TranslationServer.remove_translation(_table)
	code = lang_code
	_table = Table.new()
	_table.locale = lang_code
	_table.words = _phrases_once(lang_code)
	if lang_code != SOURCE:
		_table.fallback = _phrases_once(SOURCE)
	TranslationServer.add_translation(_table)
	TranslationServer.set_locale(lang_code)


static func known(lang_code: String) -> bool:
	for l in LANGS:
		if l[0] == lang_code:
			return true
	return false


## The language a new player gets: the device's, when it is one of LANGS, else the first.
static func of_device() -> String:
	var device := OS.get_locale_language()
	return device if known(device) else LANGS[0][0]


## The own name of language `lang_code`.
static func title(lang_code: String) -> String:
	for l in LANGS:
		if l[0] == lang_code:
			return l[1]
	return lang_code


## Reads the phrases again in the language in use (a hot reload of the mods, ModReload).
static func reread() -> void:
	_read = {}
	_english = null
	if code != "":
		use(code)


static func _phrases_once(lang_code: String) -> Dictionary:
	if not _read.has(lang_code):
		_read[lang_code] = phrases(lang_code)
	return _read[lang_code]


## Every phrase of language `lang_code`: the interface's, then every bundle's (all of
## them, so the titles of bundles not played show too).
static func phrases(lang_code: String) -> Dictionary:
	var out := {}
	for path in files(lang_code):
		out.merge(read(path), true)
	return out


## The files of language `lang_code`: core's interface first, then each mod's own (its
## title and its bundles' manifests, `content/<mod>/lang/`) and each bundle's.
static func files(lang_code: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dirs := ["core"]
	for m in Content.available():
		if not m in dirs:
			dirs.append(m)
	for b in Content.all_bundles():
		if not b in dirs:
			dirs.append(b)
	for d in dirs:
		var path := "%s/%s/lang/%s.yaml" % [Content.ROOT, d, lang_code]
		if Content.file_exists(path):
			out.append(path)
	return out


## The phrases of one file: {key: phrase}, the empty ones left out. Read the way the
## content is (Content._read: parsed when the game was built, content_cache.bin).
static func read(path: String) -> Dictionary:
	var data: Variant = Content._read(path)
	var out := {}
	if data is Dictionary:
		for k in data:
			if data[k] is String and data[k] != "":
				out[str(k)] = data[k]
	return out


## Template `template` with `values`, for a reader in another language: the server's
## phrases with numbers or names in them. With no values the template itself.
static func line(template: String, values: Array = []) -> String:
	if values.is_empty():
		return template
	return LINE + JSON.stringify([template] + values)


## Template `template` with `values` in the language in use: the template and the
## values that are phrases translated (the client's own phrases with numbers in them).
static func f(template: String, values: Array) -> String:
	var out := []
	for v in values:
		out.append(t(v) if v is String else v)
	return t(template) % out


## `s` (a phrase or a line) in the language in use; for code with no `tr()` (a static
## func) and for text drawn by hand.
static func t(s: String) -> String:
	if s == "":
		return s
	if _table != null:
		return (_table as Table).text_of(s)
	return english().text_of(s)


## The English table, for putting phrases into words with no language set.
static func english() -> Table:
	if _english == null:
		_english = Table.new()
		_english.words = _phrases_once(SOURCE)
	return _english


## A player's text as shown (a chat line, a sign's words): each line of it that is a
## whole key is put into the language in use, the rest stays as written. The bots of a
## playtest speak and write in keys, so each reader gets the words in their own language.
static func written(text: String) -> String:
	if not text.contains("["):
		return text
	var lines := text.split("\n")
	for i in lines.size():
		if is_key(lines[i]):
			lines[i] = t(lines[i])
	return "\n".join(lines)


## Whether `s` is a key: a word of small Latin letters, digits, `_` and `.` in square
## brackets, `[bag_is_full]`.
static func is_key(s: String) -> bool:
	if s.length() < 3 or not s.begins_with("[") or not s.ends_with("]"):
		return false
	for i in range(1, s.length() - 1):
		var c := s.unicode_at(i)
		if not ((c >= 97 and c <= 122) or (c >= 48 and c <= 57) or c == 95 or c == 46):
			return false
	return true


## Text `s` (a phrase or a line, as given to a Label) goes on the screen: while
## `watching`, kept in `missed` when Russian would still show a key in it, or English (a
## word of three Latin letters and no Cyrillic one).
static func seen(s: String) -> void:
	if not watching or s == "":
		return
	if _russian == null:
		_russian = Table.new()
		_russian.words = phrases("ru")
		_russian.fallback = phrases(SOURCE)
		_key_in = RegEx.create_from_string("\\[[a-z0-9_.]+\\]")
		_latin = RegEx.create_from_string("[A-Za-z]{3}")
		_cyrillic = RegEx.create_from_string("[\\x{0400}-\\x{04FF}]")
	var shown := _russian.text_of(s)
	var english := _latin.search(shown) != null and _cyrillic.search(shown) == null
	if (_key_in.search(shown) != null or english) and not s in missed:
		missed.append(s)


## The texts under `node` that the screen shows with a key (or a `line`) still in them, in
## the language in use, as "<node>: <text shown>": a key put as a value into a template
## that is no key (`"PvP: %s" % key`), a key given to a node that does not translate, a
## key no language file has. Hidden nodes are skipped. While `watching` (the scene
## tests) each one goes into `missed` too.
static func keys_shown(node: Node) -> Array[String]:
	if _key_in == null:
		_key_in = RegEx.create_from_string("\\[[a-z0-9_.]+\\]")
	var out: Array[String] = []
	var todo: Array[Node] = [node]
	while not todo.is_empty():
		var n: Node = todo.pop_back()
		# Walked from the top, so a node hidden hides what it holds.
		if (n is CanvasItem or n is Node3D or n is CanvasLayer or n is Window) and not n.visible:
			continue
		for text in _texts_of(n):
			var shown := n.atr(text) if text.begins_with("[") or text.begins_with(LINE) else text
			if shown.contains(LINE) or _key_in.search(shown) != null:
				var what := "%s: %s" % [n.name, shown]
				if not what in out:
					out.append(what)
				if watching and not what in missed:
					missed.append(what)
		todo.append_array(n.get_children())
	return out


## The texts node `n` shows (its words, its tabs' and items' titles, its tip).
static func _texts_of(n: Node) -> Array[String]:
	var out: Array[String] = []
	if n is Label or n is Button or n is RichTextLabel or n is Label3D:
		out.append(n.text)
	if n is LineEdit or n is TextEdit:
		out.append(n.placeholder_text)
	if n is OptionButton:
		for i in (n as OptionButton).item_count:
			out.append((n as OptionButton).get_item_text(i))
	if n is TabBar:
		for i in (n as TabBar).tab_count:
			out.append((n as TabBar).get_tab_title(i))
	if n is Control:
		out.append((n as Control).tooltip_text)
	return out.filter(func(t: String) -> bool: return t != "")


## Takes the table out of the TranslationServer: called as the game ends (Main leaving
## the tree), since a scripted table left there when the scripts are gone crashes the
## engine on the way out.
static func drop() -> void:
	if _table != null:
		TranslationServer.remove_translation(_table)
		_table = null
