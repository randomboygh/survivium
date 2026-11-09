extends "res://tests/unit/test_case.gd"
## The languages (Lang, decision 183): the server's lines with values put together in the
## reader's language, English read from the lang files, every phrase of the game in it.


func run() -> void:
	_test_lines()
	_test_english()
	_test_seen()


## A line keeps its template and values apart and is put together where it is shown.
func _test_lines() -> void:
	var l := Lang.line("Сломалось: %s (%d)", ["Каменный топор", 3])
	_check(l.begins_with(Lang.LINE) and Lang.t(l) == "Сломалось: Каменный топор (3)", "a line put together as written")
	_check(Lang.line("Готово") == "Готово", "a phrase without values stays a phrase")
	var nested := Lang.line("%s, %s", [Lang.line("%s (%d из %d)", ["Животные", 1, 19]), "Растения"])
	_check(Lang.t(nested) == "Животные (1 из 19), Растения", "a line inside a line")
	_check(Lang.t(Lang.LINE + "Object(Node,\"name\":\"x\")") == Lang.LINE + "Object(Node,\"name\":\"x\")",
		"a line that is not JSON is shown as it came and makes nothing")
	_check(Lang.f("%d мин", [5]) == "5 мин", "a template of the client's with values")


## English: the files read, every phrase of the code and the content in them, the
## TranslationServer turning phrases and lines into it; Russian back as written.
func _test_english() -> void:
	var en := Lang.phrases("en")
	_check(en.get("Волк", "") == "Wolf" and en.get("Сломалось: %s", "") == "Broke: %s", "English is read from core's and the bundles' files")
	Lang.use("en")
	_check(TranslationServer.get_locale() == "en" and tr("Настройки") == "Settings", "the TranslationServer speaks English")
	_check(Lang.t(Lang.line("Сломалось: %s", ["Каменный топор"])) == "Broke: Stone axe"
		and TranslationServer.translate(Lang.line("Сломалось: %s", ["Каменный топор"])) == "Broke: Stone axe",
		"a line in English, its value too, by Lang.t and by the server of translations")
	_check(Lang.f("%s · %d° · д. %d · %02d:%02d", ["Лето", 21, 3, 10, 5]) == "Summer · 21° · d. 3 · 10:05", "the clock in English")
	Lang.use("xx")
	_check(Lang.code == "en", "a language not listed is English")
	for l in Lang.LANGS:
		Lang.use(l[0])
		_check(Lang.code == l[0] and (tr("Настройки") == "Настройки") == (l[0] == Lang.SOURCE),
			"%s says «Настройки» in its own words" % l[0])
	Lang.use("de")
	_check(tr("Настройки") == "Einstellungen" and Lang.t(Lang.line("Сломалось: %s", ["Каменный топор"])) == "Kaputt: Steinaxt",
		"a line in German, its value too")
	Lang.use("ru")
	_check(tr("Настройки") == "Настройки" and Lang.t(Lang.line("Сломалось: %s", ["Нож"])) == "Сломалось: Нож", "Russian as written")
	Lang.drop()
	_check(Lang.of_device() in Lang.LANGS.map(func(l: Array) -> String: return l[0]), "a new player gets a language of the list")


## The scene tests' watch (Lang.seen): a text given to the screen that English would
## still show in Russian is kept, a phrase or a line of phrases is not.
func _test_seen() -> void:
	var was: bool = Lang.watching
	Lang.watching = true
	Lang.missed.clear()
	Lang.seen("Сумка полна")
	Lang.seen(Lang.line("Сломалось: %s", ["Каменный топор"]))
	Lang.seen(Lang.line("+%d %s", [2, "Каменный топор"]))
	Lang.seen(Crafting.amounts_text({"tools:stone_axe": 1}))
	_check(Lang.missed.is_empty(), "phrases and lines of phrases have their English: %s" % [Lang.missed])
	Lang.seen("+2 Каменный топор")
	Lang.seen("Материки и реки…")
	_check(Array(Lang.missed) == ["+2 Каменный топор", "Материки и реки…"],
		"a phrase glued to its values or cut is caught: %s" % [Lang.missed])
	Lang.missed.clear()
	Lang.watching = was
