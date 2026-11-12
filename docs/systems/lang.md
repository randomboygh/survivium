# Languages

Status: ACTIVE. A Russian copy: [lang_RU.md](lang_RU.md).

**Purpose.** The game speaks ten languages (decisions 183, 186): English, Russian, Spanish, Portuguese,
French, German, Italian, Polish, Turkish, Ukrainian. English is the default, at the first start — the
device's language if it is on the list; the «Language» switch is the first in the settings, the «Game» tab.
Every text for a player is a key in square brackets (`"[bag_is_full]"`), both in the code and in the mods'
data; each language, English too, maps the key to its own text (decision 186, option Г).

**Files**
- `src/shared/content/lang.gd` — the list of languages (`LANGS`), the translation table (`Lang.Table`, a
  heir of `Translation`), `use(code)` sets the language, `of_device()`, `files`/`read`/`phrases` — the mods'
  `lang/` files, `line(template, values)` — a string with values for the server, `f(template, values)` — the
  same at once in the player's language (the client), `t(key)` — the text of a key or of a `line` string in
  code (without a language — English, `english()`), `is_key(s)` — whether it is a key, `drop()` — remove the
  table before exit; `seen(text)` — the tests' watchman (`watching`, `missed`, see «Tests»).
- `src/client/settings.gd` — `language` (the device's language by default), `use_language`, `set_language`;
  «Reset» does not touch the language; `Settings.language_override` is set by tests (`"ru"`).
- `src/client/ui/settings_menu.gd` — the «Language» row.
- `tools/lang_check.py` — which keys of the code and content are in a language's files: `--missing <code>` —
  the list of untranslated, `--write <code>` — append them to the files with an empty value (and remove the
  unneeded), `--strict en,ru` — an error if something is missing (CI, `lint`). Without keys it also looks for
  errors: a key glued with values through `%` or `+` (`glued`; exceptions — `GLUE_OK`, the server's internal
  texts), Russian text in code (except the languages' self-names and `RESERVED_NAMES`), a record's
  `title`/`description` that is not a key.

**Data.** A key is lower-case Latin letters, digits, `_` and `.` in square brackets. In code a key names the
phrase's meaning (`[bag_is_full]`); for a mod's record the key is by its name: the title
`[<mod>.<kind>.<id>]` (`[tools.items.stone_axe]`), the description — the same with `.about`, of a mod
(`mod.yaml`) — `[<mod>.mod]`, of a bundle (`bundle.yaml`) — `[<mod>.<bundle>.bundle]`, a tool class —
`[tool.<class>]`. A translation is `lang/<code>.yaml` beside the data: `content/core/lang/` — the interface,
the core and the tool classes, `content/<mod>/lang/` — a mod's description,
`content/<mod>/<bundle>/lang/` — the records and the bundle's description. The format is a flat dictionary
`"[key]": "text"`. The files are read through `Content._read`, so they come from `content_cache.bin` too. No
key in a language (or empty) — the English text (`Table.fallback`), no such either — the key itself, so a gap
is seen at once. A text that is not a key (a player's name, an inscription on a sign) is shown as is.

**Rules**
- The server does not translate: a rule gives a key or `Lang.line(template, [values])` — the string
  `"\u001e" + JSON [template, values…]`; the client unfolds it with the translation table (Label, Label3D,
  buttons — by themselves, through Godot's auto-translation) or `Lang.t` in code. The values that are keys
  are translated too (the names of things). JSON, not `str_to_var`: the string may be sent by someone else's
  server.
- A client template with values is `Lang.f(key, values)`, not `key % values`: the template is translated,
  then the values are put in. Do not glue pieces: languages have another word order; a variant with a piece
  and without — two keys.
- A text for a Label (a toast, a notice, a loading line) is a key or `Lang.line`, not a ready `Lang.f`: a
  Label translates itself, and the tests' watchman checks exactly what was given to the screen. The code that
  needs the words (to measure, to compare, to make lower-case) uses `Lang.t(key)`, not the key itself; a
  text's width or wrapped lines are measured only by `UiStyle.text_width` / `text_lines`, which do that
  (`tools/lint.py` fails a `get_string_size` elsewhere in `src/`); an ellipsis and percents — by a template `Lang.line("%s…", [key])`.
- A word with forms is several keys: numerals `[block_1]`, `[block_2]`, `[block_5]` (one, two, five), words
  of different gender — different keys (`[small_ui]`, `[small_map]`).
- Internal texts are written in English as plain text, not keys, and are not translated (decision 186, 3А):
  the server's logs and console (`print`, `push_warning`, `say` in `server_main.gd`, `playtest_host.gd`,
  `real_weather.gd`, the answers of the commands `Server.command` and `/test`, the security log
  `Server.flag`, `tunnel.gd`), the stats panel (`perf_panel.gd`, the marks `perf.mark` / `perf.note`), the
  freeze log (`freeze_log.gd`, `gl_watch.gd`), the loading lines `start_times.gd`, the analysis of draw calls
  (`draw_census.gd`), AI debugging (`ai_debug.gd`) and «Data for the test» (`SettingsMenu.report_text`). Keys
  are what a player sees: the reasons of a disconnection (`kick`, `close_after`), chat lines to players
  (`hear`), the server's messages that the console prints through `Lang.t`.
- A new key in code or a new record — the text in `en.yaml` and `ru.yaml` of the same place (`python3
  tools/lang_check.py --write en` and `--write ru`, then fill in), otherwise CI is red. The other eight
  languages are not required by CI (before translation a key goes in English), but `lang_check.py` without
  keys shows how many they lack; `--write <code>` appends them empty.
- A translation keeps the specifiers `%s`, `%d` in the same order as the English (`%` in Godot is only
  positional), otherwise `lang_check.py` gives an error for any language; `%%` may be moved (the Turkish
  `%%%d`).
- Quotes inside a translation are «guillemets» or “curly” by the language's custom, not ASCII `"`.

**Pitfalls**
- A scripted `Translation` in `TranslationServer` crashes the engine at exit: `Main._exit_tree` calls
  `Lang.drop()`, the tests do too.
- A `line` string cannot be compared with a key: tests compare `Lang.t(said)` with `Lang.t(expected)`.
- Long English words do not fit narrow strips: the skills' names are shorter, the strip cuts with «.».

**Tests.** `tests/unit/lang_test.gd` (lines, languages, `is_key`, number forms, the watchman); unit tests go
without a language, that is in English. The completeness of English and Russian — `tools/lang_check.py
--strict en,ru`. The tests' scenes play in Russian (`language_override`). The watchman of the untranslated:
the tests' scenes (`progress_test`, `save_test`, `server_test`, `frame_test`) set `Lang.watching`, and every
text given to toasts (`hud.toast`, `notice`), a line and the loading screen (`set_loading`, the strip's
caption, tips) is translated into Russian (`Lang.seen`); if a key or an English text without Cyrillic remains
in it, it goes into `Lang.missed`, and the test fails with a list of such lines.

**In more detail.** The translator's guide — [../TRANSLATION.md](../TRANSLATION.md) (a copy
[../TRANSLATION_RU.md](../TRANSLATION_RU.md)); decisions 183 and 186 in `plan/README.md`; screenshots in a
language — `tools/shot.gd -- --lang en`.
