# How to check changes

Status: ACTIVE. What is covered by what — [TEST_COVERAGE.md](TEST_COVERAGE.md); how CI is built —
[CI_PIPELINE.md](CI_PIPELINE.md); the details of tests and tools — [../systems/testing.md](../systems/testing.md).
A Russian copy: [TESTING_GUIDE_RU.md](TESTING_GUIDE_RU.md).

## Preparation

Godot 4.5.1 (`godot` on PATH or `GODOT=path`). After cloning and after new assets:

```
godot --headless --path . --import
```

Without the import the HUD scripts fail with null errors that look like code bugs.

## Levels of checks

| Level | Command | Time | When |
|---|---|---|---|
| 1. Seconds, no Godot | `python3 tools/lint.py && python3 tools/doc_index.py --check` | ~1 s | after any edit; can be a hook before a commit: `git config core.hooksPath tools/hooks` |
| 2. Compilation and data | `GODOT=… tests/run_all.sh parse validate report balance` | ~15 s | any edit of code or data |
| 3. Unit tests | `godot --headless --path . --script res://tests/run_tests.gd [-- topic …]` | 1–2 min (a topic — seconds) | an edit of rules, the generator, meshes, data |
| 4. Scenarios | `tests/run_all.sh save_test server_test frame_test progress_hunting progress_other` | 2–20 min | see the table below |
| 5. Everything | `GODOT=… tests/run_all.sh` | ~20–30 min on 4 cores | before a big PR; CI does it on every push |
| 6. Browser | only in CI (`smoke`) | 3 min | the client, shaders, export |

A unit-test topic is the file's name `tests/unit/<topic>_test.gd` without `_test.gd`: `-- graph properties`
runs two files. Each file prints its checks and seconds.

## What to run when a system changes

| What changed | Required | Plus |
|---|---|---|
| only the interface (`src/client/ui/`, HUD), the UI kit (`src/client/ui/kit/`) | 1, 2, `run_tests -- ui` | screenshots (`tools/shot.gd`), `save_test` (opens every window and tab) |
| texts and languages (`lang/*.yaml`, `lang.gd`, a new key) | `python3 tools/lang_check.py --strict en,ru`, 1, `run_tests -- lang` | `save_test` (no raw `[key]` on screen), `tools/shot.gd -- <dir> --keys` after a big UI change |
| signs, gestures, chat (`placed.gd`, `gestures.gd`, `sign_window.gd`) | 1, 2, `run_tests -- signs net security view` | `server_test` |
| fences, gates, hatches, ladders | 1, 2, `run_tests -- fences actions plans` | `save_test` |
| rafts and boats (`actions_boat.gd`, `vessels.gd`, `boats.gd`) | 1, 2, `run_tests -- boat body` | `save_test` |
| farming, nature, growth (`actions_farm.gd`, `actions_nature.gd`, `farm_mode.gd`) | 1, 2, `run_tests -- farming clock` | `progress_other` |
| the mods' files a server sends, the mod cache, zip import (`mod_files.gd`, `content_host.gd`, `mod_fetch.gd`, `mod_cache.gd`, `mod_import.gd`) | 1, 2, `run_tests -- mod_files content net` | `server_test` |
| a mod's data, recipes, stations, tools, materials | 1, 2 (`validate`, `report` — after an edit run `tools/content_report.gd` without `--check`), `run_tests -- content graph bundle_system properties` | `progress_hunting progress_other` |
| hands, gathering, crafting, `world_actions.gd`, `workshop.gd`, `placed.gd` | 1, 2, `run_tests` | `progress_*`, `save_test` |
| building: blueprint, doors, windows, stairs, furniture (`plans.gd`, the things' flags in `placed.gd`) | 1, 2, `run_tests -- actions plans` | `save_test`, screenshots `build-*` |
| shaders, light, the cave view (`shaders/`, `src/client/view/`) | 1, 2, `run_tests -- view` | `frame_test`; screenshots under xvfb or `smoke` in CI: headless does not compile shaders |
| the generator, the world, chunks, meshes, the streamer | 1, 2, `run_tests -- generation mesher shapes store` | `frame_test` (alone, with no other processes), `save_test` |
| saves (`save_game.gd`, `world_store.gd`) | 1, 2, `run_tests -- store` | `save_test` |
| network, server, protocol, rights, anti-cheat | 1, 2, `run_tests -- net session security` | `server_test` ([../security/SECURITY_TESTING.md](../security/SECURITY_TESTING.md)) |
| beasts, weather, clock, territories, skills | 1, 2, `run_tests -- wildlife clock territory skills` | `progress_*` for hunting |
| what goes every frame (light, fires, shadows, beasts on screen) | 1, 2, `run_tests` | `frame_test` |
| CI, `tests/run_all.sh`, `tools/*.py` | 1 | a run in CI |

CI runs everything all the same; the table is so as not to wait for the extra locally.

## How to read the result

- `run_all.sh` prints each check's log under the line `=== name: N s, exit code` and at the end `All passed`
  or `Failed: …`. `exit 124` — the check did not fit its limit (`limit` in the script).
- A `SCRIPT ERROR` line in a log is a failure, even with code 0: a runtime error cuts off a test's function.
- `ERROR: content: _test…` in `run_tests` and RID leaks at exit — deliberately broken data and an old
  harmless noise of the engine.
- `LOGS=folder` saves each check's log.

## How to add a test

- **A rule of the game** — a function `_test_<what>()` in `tests/unit/<topic>_test.gd` (it inherits
  `tests/unit/test_case.gd`: `_check(condition, "what must be")`, a temporary mod `_write_file`/`_remove`,
  a world `_land(seed)`), a call in its `run()`. A new file — the topic's name in `FILES` in
  `tests/run_tests.gd` (otherwise `run_tests` fails). A test does not depend on order: it returns the active
  set of bundles and deletes its temporary mods (`content/_<name>/`).
- **A generative test** — `tests/unit/properties_test.gd`: random cases from pinned seeds, a check of what is
  always true; on a failure the seed and the step are printed.
- **A regression of a bug** — a test that fails on the old code, in the topic's file; in the description —
  what broke.
- **A scenario in the game** (`save_test`, `progress_test`, `frame_test`, `server_test`) — wait by
  `Time.get_ticks_msec()` *and* by the number of frames: on a busy machine a frame can take seconds.
- **A new check of data** — in the registry's `check()` (`src/shared/content/<kind>.gd`) or in
  `src/shared/content/content_graph.gd` (then — a description in `CHECK_TEXT` of `tools/content_report.gd`);
  `tools/validate.gd` collects them all.

## How to check the game's data

```
godot --headless --path . --script res://tools/validate.gd          # everything and each bundle separately
godot --headless --path . --script res://tools/content_report.gd    # regenerate the reports
```

`validate` checks the schemas (types, limits, required fields, amounts — whole from 1), the uniqueness and
the references of ids (hard and soft), that a recipe's station is a station, that an item has the tool class,
pictures, sounds, models, textures, the atlas, eras, and the content graph of the full set: everything is
reachable from the start, there are no blocking cycles, no item without a source, no recipe that cannot be
made, no era earlier than its path. Each bundle is loaded separately with what it cannot do without. A
message names the kind, the record's id and the field: `recipes: tools:axe.at: \`tools:rock\` is no station`.
Warnings (dead ends, twins, stations of one recipe, long chains, profitable circles) are printed and do not
fail. What was found, with an explanation and how to fix it — `docs/generated/content-checks.md`.

## Diagnostics

- `frame_test` failed on idle — the line prints the chunk's measure taken right before the measuring, the
  frame's median and the parts of the game (`player`, `sky`, `animals` …): one sees which part grew. The
  limit is the share of a chunk, but not less than `IDLE_FLOOR` / `NIGHT_FLOOR` ms (on GitHub's fast
  machines the share of a chunk is less than an idle frame). On a shared machine rerun it alone before
  blaming the code.
- `progress_test` failed — the first `FAIL:` is the cause; after it come `made: …` of all the unfinished
  recipes. A message about the camp draws a map around (`#` — a thing, `T` — a tree), about hunting — where
  the beast fell and where the nearest carcass is at the client and at the host.
- It hangs — an error in a script with `await`: everything in `run_all.sh` is under `timeout`.
- The pitfalls of the engine and tests — `CLAUDE.md`, the Gotchas section, and
  [../systems/testing.md](../systems/testing.md).
