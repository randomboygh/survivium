# Translating Survivium

Status: ACTIVE. How the game's text is translated: adding a language, translating the game and a mod,
and what is never translated. The code side is in [systems/lang.md](systems/lang.md) (in Russian);
a Russian copy of this guide is [TRANSLATION_RU.md](TRANSLATION_RU.md).

## How it works

- The game speaks ten languages (decision 183): English (the default), Russian, Spanish, Portuguese,
  French, German, Italian, Polish, Turkish, Ukrainian. On the first start it takes the device's language
  when it is on the list; «Settings» → «Game» → «Language» changes it.
- Every phrase is its own key. Today the source language is Russian: the text in the code and the `title` /
  `description` of a record in the YAML is the key, and each language maps it to its own text. (Decision 186
  makes English the source language later on; this guide will change with it.)
- A translation is a flat YAML mapping in a `lang/<code>.yaml` file beside what it translates:

  ```yaml
  "Новый мир": "New world"
  "Сумка: занято %d из %d ячеек": "Bag: %d of %d slots taken"
  ```

  | What | Where its translations live |
  |---|---|
  | the interface and the core rules (all phrases of `src/`) | `content/core/lang/<code>.yaml` |
  | a mod's manifest (`mod.yaml`: its title and description) | `content/<mod>/lang/<code>.yaml` |
  | a bundle's records and manifest (items, creatures, recipes...) | `content/<mod>/<bundle>/lang/<code>.yaml` |

- A missing or empty translation shows the English one; with no English either, the Russian key.

## Translating the game into a language that is already on the list

1. List what the language lacks: `python3 tools/lang_check.py --missing de` (JSON: phrase → file).
2. Add the missing phrases to the files, empty: `python3 tools/lang_check.py --write de`.
3. Fill the empty values. Keep every `%s`, `%d`, `%.1f` of the key, in the same order (Godot's `%` is
   positional only); `%%` (a percent sign) may move. Use the language's own quotes («», “”, „“), never ASCII
   `"` inside a value.
4. Check: `python3 tools/lang_check.py` (exit 1 on a broken file or a wrong `%`). See it in the game:
   `tools/shot.gd -- --lang de` takes screenshots in that language.

CI requires English to be complete (`--strict en`); the other languages may lag, and what they lack
shows in English.

## Adding a new language

1. Add the language to `Lang.LANGS` in `src/shared/content/lang.gd` (its code and its own name, as the
   «Language» row shows it) and to `LANGS` in `tools/lang_check.py`.
2. `python3 tools/lang_check.py --write <code>` makes the empty files everywhere; fill them as above.
3. The pixel font must have the language's letters (`assets/fonts/`); check the screenshots.

## Translating a mod

A mod (or a bundle of it) brings its own translations: put `lang/<code>.yaml` beside its `mod.yaml` or
`bundle.yaml`, with the `title` and `description` of every record and of the manifest as keys.
`python3 tools/lang_check.py --write en` writes the empty files for a mod in `content/` too. A mod
without translations shows its own text in every language.

The mods of a PC build are plain files in `content/` beside the program (decision 186), so a translation
can be edited there and is picked up at once (hot reload).

## What is never translated

Internal texts are written in English and stay so (decision 186): the server's log, console and command
replies, the security log, the stats panel (F3) and its marks, the freeze log, the loading times, the draw
census, the AI debug and «Test data». `lang_check.py` takes only Russian strings as phrases, so English
ones are not asked for.

## Rules for code that shows text

- The server never translates: it sends a phrase or `Lang.line(template, [values])`; the client turns it
  into the player's language.
- On the client a template with values is `Lang.f(template, values)`, never `template % values` or pieces
  glued together: the word order differs between languages. A variant with and without a piece is two
  phrases.
- Text given to a Label (toasts, notices, loading line) is a phrase or a `Lang.line`: the Label translates it
  itself.
- A new phrase needs its English in the same commit: `python3 tools/lang_check.py --write en`, then fill it.
