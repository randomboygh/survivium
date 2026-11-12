# Translating Survivium

Status: ACTIVE. How the game's text is translated: keys, adding a language, translating the game and a
mod, and what is never translated. The code side is in [systems/lang.md](systems/lang.md) (in Russian);
a Russian copy of this guide is [TRANSLATION_RU.md](TRANSLATION_RU.md).

## How it works

- The game speaks ten languages (decision 183): English (the default), Russian, Spanish, Portuguese,
  French, German, Italian, Polish, Turkish, Ukrainian. On the first start it takes the device's language
  when it is on the list; «Settings» → «Game» → «Language» changes it.
- Every text a player reads is a **key** in square brackets (decision 186): small Latin letters, digits,
  `_` and `.` — `"[bag_is_full]"`, `"[small_map]"`. The code and the mods' data hold only keys; each
  language, English too, maps a key to its own text. Text that is no key (a player's name, a sign's words)
  shows as written.
- A translation is a flat YAML mapping in a `lang/<code>.yaml` file beside what it translates:

  ```yaml
  "[new_world]": "New world"
  "[bag_slots_taken]": "Bag: %d of %d slots taken"
  ```

  | What | Where its translations live |
  |---|---|
  | the interface and the core rules (all keys of `src/`), the tool classes `[tool.<class>]` | `content/core/lang/<code>.yaml` |
  | a mod's manifest (`mod.yaml`: its title and description) | `content/<mod>/lang/<code>.yaml` |
  | a bundle's records and manifest (items, creatures, recipes...) | `content/<mod>/<bundle>/lang/<code>.yaml` |

- A key a language lacks (or leaves empty) shows in English; a key English lacks shows as the key itself,
  `[bag_is_full]`, so a gap is seen at once.
- English and Russian must be complete (CI, `--strict en,ru`); the other languages may lag.

## The keys of a mod's data

A record's `title` and `description` are keys too, named after the record:

| Field | Key |
|---|---|
| a record's title | `[<mod>.<kind>.<id>]` — `[tools.items.stone_axe]`, `[animals.creatures.wolf]` |
| a record's description | the same with `.about` — `[tools.items.stone_axe.about]` |
| a mod's title (`mod.yaml`) | `[<mod>.mod]`, its description `[<mod>.mod.about]` |
| a bundle's title (`bundle.yaml`) | `[<mod>.<bundle>.bundle]`, its description `….about` |

`<kind>` is the data file's name (`items`, `recipes`, `creatures`...). A recipe and the item it makes have
two keys, usually with the same text. A tool class (`tool: knife`) is named in hints by `[tool.knife]`;
a mod that brings a class of its own brings that key in its `lang/` too.

## Words with forms

One English word may be two in another language (a word's gender, a number's form): they are two keys,
`[small_ui]` and `[small_map]` («мелкий» and «маленькая» in Russian), both «small» in English. A noun
counted by a number has three keys, for one, two and five: `[block_1]`, `[block_2]`, `[block_5]` (Russian
«блок», «блока», «блоков»). A language with two forms fills `_2` like `_5`.

## Translating the game into a language that is already on the list

1. List what the language lacks: `python3 tools/lang_check.py --missing de` (JSON: key → file). The
   English (`en.yaml`) beside each file gives the text to translate, the Russian (`ru.yaml`) a second
   reading of its meaning.
2. Add the missing keys to the files, empty: `python3 tools/lang_check.py --write de`.
3. Fill the empty values. Keep every `%s`, `%d`, `%.1f` of the English, in the same order (Godot's `%` is
   positional only); `%%` (a percent sign) may move. Use the language's own quotes («», “”, „“), never ASCII
   `"` inside a value.
4. Check: `python3 tools/lang_check.py` (exit 1 on a broken file or a wrong `%`). See it in the game:
   `tools/shot.gd -- --lang de` takes screenshots in that language.

## Adding a new language

1. Add the language to `Lang.LANGS` in `src/shared/content/lang.gd` (its code and its own name, as the
   «Language» row shows it) and to `LANGS` in `tools/lang_check.py`.
2. `python3 tools/lang_check.py --write <code>` makes the empty files everywhere; fill them as above.
3. The pixel font must have the language's letters (`assets/fonts/`); check the screenshots.

## Translating a mod

A mod (or a bundle of it) brings its own translations: `lang/<code>.yaml` beside its `mod.yaml` or
`bundle.yaml`, with the keys of its records and of its manifest, English first.
`python3 tools/lang_check.py --write en` writes the empty files for a mod in `content/` too. A title that
is plain text instead of a key shows as written in every language (the check counts it as a problem for
the mods in this repo).

The mods of a PC build are plain files in `content/` beside the program (decision 186), so a translation
can be edited there and is picked up at once (hot reload).

## What is never translated

Internal texts are written in English as plain text, not keys, and stay so (decision 186): the server's
log, console and command replies, the security log, the stats panel (F3) and its marks, the freeze log,
the loading times, the draw census, the AI debug and «Test data».

## Rules for code that shows text

- A text for a player is a key: `"[bag_is_full]"`, never a phrase in English or Russian (the check fails
  on Russian text in the code). A new key goes into `content/core/lang/en.yaml` and `ru.yaml` in the same
  commit: `python3 tools/lang_check.py --write en` and `--write ru`, then fill them.
- The server never translates: it sends a key or `Lang.line(key, [values])`; the client turns it into the
  player's language. A value that is a key (an item's title) is translated too.
- On the client a key with values is `Lang.f(key, values)`, never `key % values` or pieces glued
  together: the word order differs between languages. A variant with and without a piece is two keys.
- Text given to a Label (toasts, notices, loading line) is a key or a `Lang.line`: the Label translates it
  itself. Code that needs the words (to measure, to lower a letter) takes `Lang.t(key)`.
- To change an English text, change only `en.yaml`: the key stays, and so do the other translations
  (check them against the new meaning).
