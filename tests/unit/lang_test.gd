extends "res://tests/unit/test_case.gd"
## The languages (Lang, decisions 183, 186): every phrase a key, the server's lines with
## values put together in the reader's language, the languages read from the lang files,
## English with no language set, every key of the game in English and Russian.


func run() -> void:
	_test_lines()
	_test_languages()
	_test_keys()
	_test_seen()


## A line keeps its template and values apart and is put together where it is shown;
## with no language set, in English.
func _test_lines() -> void:
	var l := Lang.line("[broke]", ["[tools.items.stone_axe]"])
	_check(l.begins_with(Lang.LINE) and Lang.t(l) == "Broke: Stone axe", "a line put together in English: %s" % Lang.t(l))
	_check(Lang.line("[settings]") == "[settings]", "a phrase without values stays a phrase")
	var nested := Lang.line("%s, %s", [Lang.line("%s (%d of %d)", ["[animals.mod]", 1, 19]), "[plants.mod]"])
	_check(Lang.t(nested) == "Animals (1 of 19), Plants", "a line inside a line: %s" % Lang.t(nested))
	_check(Lang.t(Lang.LINE + "Object(Node,\"name\":\"x\")") == Lang.LINE + "Object(Node,\"name\":\"x\")",
		"a line that is not JSON is shown as it came and makes nothing")
	_check(Lang.f("[min]", [5]) == "5 min", "a template of the client's with values: %s" % Lang.f("[min]", [5]))
	_check(Lang.t("Аня") == "Аня" and Lang.t("[no_such_key_anywhere]") == "[no_such_key_anywhere]",
		"text that is no key shows as written, a key no file has as the key")


## Russian and the others: the files read, the TranslationServer turning keys and lines
## into them; a language lacking a key takes the English.
func _test_languages() -> void:
	var ru := Lang.phrases("ru")
	_check(ru.get("[animals.creatures.wolf]", "") == "Волк" and ru.get("[broke]", "") == "Сломалось: %s",
		"Russian is read from core's and the bundles' files")
	Lang.use("ru")
	_check(TranslationServer.get_locale() == "ru" and tr("[settings]") == "Настройки", "the TranslationServer speaks Russian")
	_check(Lang.t(Lang.line("[broke]", ["[tools.items.stone_axe]"])) == "Сломалось: Каменный топор"
		and TranslationServer.translate(Lang.line("[broke]", ["[tools.items.stone_axe]"])) == "Сломалось: Каменный топор",
		"a line in Russian, its value too, by Lang.t and by the server of translations")
	Lang.use("xx")
	_check(Lang.code == "en", "a language not listed is English")
	for l in Lang.LANGS:
		Lang.use(l[0])
		_check(Lang.code == l[0] and (tr("[settings]") == "Settings") == (l[0] == Lang.SOURCE),
			"%s says «Settings» in its own words" % l[0])
	Lang.use("de")
	_check(tr("[settings]") == "Einstellungen" and Lang.t(Lang.line("[broke]", ["[tools.items.stone_axe]"])) == "Kaputt: Steinaxt",
		"a line in German, its value too")
	(Lang._table as Lang.Table).words.erase("[settings]")
	_check(tr("[settings]") == "Settings", "a key the language lacks shows in English")
	Lang.reread()
	Lang.drop()
	_check(Lang.of_device() in Lang.LANGS.map(func(l: Array) -> String: return l[0]), "a new player gets a language of the list")


## What a key is (Lang.is_key), and a word counted in three forms (one, two, five).
func _test_keys() -> void:
	_check(Lang.is_key("[bag_is_full]") and Lang.is_key("[tools.items.stone_axe]") and not Lang.is_key("[Bag]")
		and not Lang.is_key("bag") and not Lang.is_key("[]") and not Lang.is_key("[a b]"), "a key is small words in brackets")
	Lang.use("ru")
	_check(Lang.t("[block_1]") == "блок" and Lang.t("[block_2]") == "блока" and Lang.t("[block_5]") == "блоков",
		"Russian counts in three forms")
	Lang.drop()


## The scene tests' watch (Lang.seen): a text given to the screen that Russian would
## still show as a key or in English is kept, a phrase or a line of phrases is not.
func _test_seen() -> void:
	var was: bool = Lang.watching
	Lang.watching = true
	Lang.missed.clear()
	Lang.seen("[the_bag_is_full]")
	Lang.seen(Lang.line("[broke]", ["[tools.items.stone_axe]"]))
	Lang.seen(Lang.line("+%d %s", [2, "[tools.items.stone_axe]"]))
	Lang.seen(Crafting.amounts_text({"tools:stone_axe": 1}))
	_check(Lang.missed.is_empty(), "phrases and lines of phrases have their Russian: %s" % [Lang.missed])
	Lang.seen("+2 [tools.items.stone_axe]")
	Lang.seen("Continents and rivers…")
	_check(Array(Lang.missed) == ["+2 [tools.items.stone_axe]", "Continents and rivers…"],
		"a key glued to its values, or text that is no key, is caught: %s" % [Lang.missed])
	Lang.missed.clear()
	Lang.watching = was
