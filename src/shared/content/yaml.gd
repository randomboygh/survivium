extends RefCounted
## A reader for the part of YAML the content files use: block mappings and lists,
## flow lists `[a, b]` and mappings `{a: 1}`, plain and quoted scalars, comments.
## Not supported: anchors, tags, multi-line scalars (`|`, `>`), multiple documents.
## Godot has no YAML of its own, and this keeps the game, the server and the
## validator reading the same files on every platform, the browser included.
##
##   var yaml := Yaml.new()
##   var data = yaml.parse(text, "materials.yaml")
##   if yaml.error != "": push_error(yaml.error)

## "file:line: what went wrong" after a failed parse, empty after a good one.
var error := ""

var _source := ""
## Lines with content: [indent, text, line number].
var _lines: Array = []
var _at := 0


## Returns the document's value: a Dictionary, an Array, a scalar, or null for an
## empty document. Check `error` afterwards.
func parse(text: String, source := "") -> Variant:
	error = ""
	_source = source
	_lines = []
	_at = 0
	var number := 0
	for raw in text.split("\n"):
		number += 1
		var line := _strip_comment(raw.rstrip("\r"))
		if line.strip_edges() == "" or line.strip_edges() == "---":
			continue
		if line.begins_with("\t"):
			return _fail(number, "tabs are not allowed for indentation")
		var indent := line.length() - line.lstrip(" ").length()
		_lines.append([indent, line.strip_edges(), number])
	if _lines.is_empty():
		return null
	var value: Variant = _block(_lines[0][0])
	if error == "":
		if _at < _lines.size():
			return _fail(_lines[_at][2], "unexpected text at this indent")
	return value


## A block node whose lines are indented by `indent`.
func _block(indent: int) -> Variant:
	var first: Array = _lines[_at]
	if first[0] != indent:
		return _fail(first[2], "bad indent")
	if first[1].begins_with("- ") or first[1] == "-":
		return _list(indent)
	if _key_end(first[1]) >= 0:
		return _map(indent)
	# A single scalar on its own line.
	_at += 1
	return _scalar(first[1], first[2])


func _list(indent: int) -> Variant:
	var items := []
	while _at < _lines.size() and error == "":
		var line: Array = _lines[_at]
		if line[0] < indent:
			break
		if line[0] > indent:
			return _fail(line[2], "bad indent")
		if not (line[1].begins_with("- ") or line[1] == "-"):
			return _fail(line[2], "expected a list item")
		var rest: String = line[1].substr(1).strip_edges()
		if rest == "":
			_at += 1
			if _at < _lines.size() and _lines[_at][0] > indent:
				items.append(_block(_lines[_at][0]))
			else:
				items.append(null)
		elif _key_end(rest) >= 0:
			# A mapping starting on the item's line: its keys sit two columns in.
			var key_indent: int = indent + 2 + (line[1].length() - 1 - rest.length() - 1)
			_lines[_at] = [key_indent, rest, line[2]]
			items.append(_map(key_indent))
		else:
			_at += 1
			items.append(_scalar(rest, line[2]))
	return items


func _map(indent: int) -> Variant:
	var map := {}
	while _at < _lines.size() and error == "":
		var line: Array = _lines[_at]
		if line[0] < indent:
			break
		if line[0] > indent:
			return _fail(line[2], "bad indent")
		var split := _key_end(line[1])
		if split < 0:
			return _fail(line[2], "expected `key: value`")
		var key: String = _unquote(line[1].substr(0, split).strip_edges())
		if map.has(key):
			return _fail(line[2], "duplicate key `%s`" % key)
		var rest: String = line[1].substr(split + 1).strip_edges()
		_at += 1
		if rest == "":
			if _at < _lines.size() and _lines[_at][0] > indent:
				map[key] = _block(_lines[_at][0])
			elif _at < _lines.size() and _lines[_at][0] == indent and _lines[_at][1].begins_with("- "):
				# A list may sit at the key's own indent, as YAML allows.
				map[key] = _list(indent)
			else:
				map[key] = null
		else:
			map[key] = _scalar(rest, line[2])
	return map


## Position of the `:` that ends a mapping key on `line`, -1 for none. The colon
## must be followed by a space or end the line, and lie outside quotes and flow
## collections.
func _key_end(line: String) -> int:
	if line.begins_with("[") or line.begins_with("{"):
		return -1
	var quote := ""
	for i in line.length():
		var c := line[i]
		if quote != "":
			if c == quote:
				quote = ""
		elif c == "\"" or c == "'":
			if i == 0:
				quote = c
		elif c == ":" and (i + 1 == line.length() or line[i + 1] == " "):
			return i
	return -1


## A scalar or a flow collection written on one line.
func _scalar(text: String, number: int) -> Variant:
	if text.begins_with("[") or text.begins_with("{"):
		var pos := [0]
		var value: Variant = _flow(text, pos, number)
		if error == "":
			_skip_spaces(text, pos)
			if pos[0] != text.length():
				return _fail(number, "text after a flow collection")
		return value
	if text.begins_with("\"") or text.begins_with("'"):
		if text.length() < 2 or text[text.length() - 1] != text[0]:
			return _fail(number, "unterminated string")
		return _unquote(text)
	return _plain(text)


func _flow(text: String, pos: Array, number: int) -> Variant:
	_skip_spaces(text, pos)
	if pos[0] >= text.length():
		return _fail(number, "unterminated flow collection")
	var c := text[pos[0]]
	if c == "[":
		pos[0] += 1
		var items := []
		while true:
			_skip_spaces(text, pos)
			if pos[0] >= text.length():
				return _fail(number, "unterminated `[`")
			if text[pos[0]] == "]":
				pos[0] += 1
				return items
			items.append(_flow(text, pos, number))
			if error != "":
				return null
			_skip_spaces(text, pos)
			if pos[0] < text.length() and text[pos[0]] == ",":
				pos[0] += 1
			elif pos[0] >= text.length() or text[pos[0]] != "]":
				return _fail(number, "expected `,` or `]`")
	if c == "{":
		pos[0] += 1
		var map := {}
		while true:
			_skip_spaces(text, pos)
			if pos[0] >= text.length():
				return _fail(number, "unterminated `{`")
			if text[pos[0]] == "}":
				pos[0] += 1
				return map
			var key: Variant = _flow_scalar(text, pos, number, true)
			if error != "":
				return null
			_skip_spaces(text, pos)
			if pos[0] >= text.length() or text[pos[0]] != ":":
				return _fail(number, "expected `:` in a flow mapping")
			pos[0] += 1
			if map.has(str(key)):
				return _fail(number, "duplicate key `%s`" % key)
			map[str(key)] = _flow(text, pos, number)
			if error != "":
				return null
			_skip_spaces(text, pos)
			if pos[0] < text.length() and text[pos[0]] == ",":
				pos[0] += 1
			elif pos[0] >= text.length() or text[pos[0]] != "}":
				return _fail(number, "expected `,` or `}`")
	return _flow_scalar(text, pos, number, false)


func _flow_scalar(text: String, pos: Array, number: int, key: bool) -> Variant:
	var c := text[pos[0]]
	if c == "\"" or c == "'":
		var close := text.find(c, pos[0] + 1)
		if close < 0:
			return _fail(number, "unterminated string")
		var s := text.substr(pos[0], close - pos[0] + 1)
		pos[0] = close + 1
		return _unquote(s)
	var start: int = pos[0]
	while pos[0] < text.length():
		var d := text[pos[0]]
		# A key ends at a `:` before a space or the end, so `core:fiber: 1` keeps its namespace.
		if d == "," or d == "]" or d == "}" or (key and d == ":" and (pos[0] + 1 >= text.length() or text[pos[0] + 1] in " ,}")):
			break
		pos[0] += 1
	var word := text.substr(start, pos[0] - start).strip_edges()
	if word == "":
		return _fail(number, "empty value in a flow collection")
	return _plain(word)


func _skip_spaces(text: String, pos: Array) -> void:
	while pos[0] < text.length() and text[pos[0]] == " ":
		pos[0] += 1


## A plain (unquoted) scalar: null, bool, int, float or a string.
static func _plain(word: String) -> Variant:
	match word:
		"null", "~":
			return null
		"true", "True", "yes", "on":
			return true
		"false", "False", "no", "off":
			return false
	if word.is_valid_int():
		return word.to_int()
	if word.is_valid_float() and not word.begins_with("."):
		return word.to_float()
	return word


static func _unquote(s: String) -> String:
	if s.length() >= 2 and s[0] == "\"" and s[s.length() - 1] == "\"":
		return s.substr(1, s.length() - 2).c_unescape()
	if s.length() >= 2 and s[0] == "'" and s[s.length() - 1] == "'":
		return s.substr(1, s.length() - 2).replace("''", "'")
	return s


## Cuts a `# comment` that is not inside quotes.
static func _strip_comment(line: String) -> String:
	var quote := ""
	# The last character outside quotes that is not a space: a quote opens a quoted
	# scalar only where a value starts (after `:`, `-`, `[`, `{`, `,` or at the start), so
	# an apostrophe inside a plain value (`Wolf's den  # note`) leaves the comment cut.
	var last := ""
	for i in line.length():
		var c := line[i]
		if quote != "":
			if c == quote:
				quote = ""
				last = c
		elif (c == "\"" or c == "'") and last in ["", ":", "-", "[", "{", ","]:
			quote = c
		elif c == "#" and (i == 0 or line[i - 1] == " "):
			return line.substr(0, i)
		elif c != " " and c != "\t":
			last = c
	return line


func _fail(number: int, what: String) -> Variant:
	if error == "":
		error = "%s:%d: %s" % [_source, number, what]
	return null


## Writes `value` as YAML that `parse` reads back to the same value: a list of mappings
## (a data file) as block items, a mapping's keys in the order they were added, short
## lists and mappings of scalars on one line (`[a, b]`, `{core:fiber: 1}`), strings
## quoted where a plain word would read back as something else. `head` goes first as
## `# ` comment lines.
static func write(value: Variant, head := "") -> String:
	var out := PackedStringArray()
	for line in head.split("\n", false):
		out.append(("# " + line).strip_edges(false, true))
	_write_block(value, 0, out)
	return "\n".join(out) + "\n"


static func _write_block(value: Variant, indent: int, out: PackedStringArray) -> void:
	var pad := " ".repeat(indent)
	if value is Array:
		if value.is_empty():
			out.append(pad + "[]")
		for item: Variant in value:
			if item is Dictionary and not item.is_empty() and not _flat(item):
				# The first key on the item's line, the rest two columns in.
				var lines := PackedStringArray()
				_write_block(item, indent + 2, lines)
				lines[0] = pad + "- " + lines[0].substr(indent + 2)
				out.append_array(lines)
			elif _flat(item):
				out.append(pad + "- " + inline(item))
			else:
				out.append(pad + "-")
				_write_block(item, indent + 2, out)
	elif value is Dictionary:
		if value.is_empty():
			out.append(pad + "{}")
		for key: Variant in value:
			var v: Variant = value[key]
			var k := pad + _word(str(key), true) + ":"
			if _flat(v):
				out.append(k + " " + inline(v))
			else:
				out.append(k)
				_write_block(v, indent + 2, out)
	else:
		out.append(pad + inline(value))


## Whether `v` goes on one line: a scalar, or a short list or mapping of scalars.
static func _flat(v: Variant) -> bool:
	if v is Array or v is Dictionary:
		if v.is_empty():
			return true
		for x: Variant in (v.values() if v is Dictionary else v):
			if x is Array or x is Dictionary:
				return false
		return inline(v).length() <= 100
	return true


static func inline(v: Variant) -> String:
	if v is Array:
		var parts := PackedStringArray()
		for x: Variant in v:
			parts.append(inline(x))
		return "[" + ", ".join(parts) + "]"
	if v is Dictionary:
		var parts := PackedStringArray()
		for k: Variant in v:
			parts.append(_word(str(k), true) + ": " + inline(v[k]))
		return "{" + ", ".join(parts) + "}"
	if v == null:
		return "null"
	if v is bool:
		return "true" if v else "false"
	if v is int:
		return str(v)
	if v is float:
		var s := str(v)
		# A whole float keeps its point, so that it reads back a float.
		return s if s.contains(".") or s.contains("e") or s.contains("inf") or s.contains("nan") else s + ".0"
	return _word(str(v), false)


## A string as a plain word when it reads back as itself, else in double quotes.
static func _word(s: String, key: bool) -> String:
	var plain := s != "" and s == s.strip_edges() and _plain(s) is String
	if plain:
		for bad in [": ", " #", ",", "[", "]", "{", "}", "\"", "'", "\n", "\t"]:
			if s.contains(bad):
				plain = false
				break
	if plain and (s[0] in "-?&*!|>%@`#" or s.ends_with(":")):
		plain = false
	return s if plain else "\"" + s.c_escape() + "\""
