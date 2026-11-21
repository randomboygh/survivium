# Survivium: notes for contributors

A meditative survival sandbox: a procedural world in 3D pixel art seen at 3/4, in the browser, on PC and on
Android, multiplayer through an authoritative server that is the same executable (decision 153; single player
runs it in the same process).
Godot 4.5.1, GL Compatibility renderer, web export without threads, pure GDScript: scripts are loaded
with `preload` consts and `extends "res://…"`, no `class_name`, no autoloads, no plugins.
The game speaks ten languages (English by default); every text a player reads is a key in square
brackets, `"[bag_is_full]"`, in the code and in the mods' data (`docs/systems/lang.md`, `docs/TRANSLATION.md`).
The README and the docs in `docs/` are in English, each with a Russian copy `<name>_RU.md` (a page with no
`_RU` copy is still in Russian only). In an ordinary PR only the English doc is changed; the `_RU` copies are
caught up by the weekly thread. Code, comments, commits and PRs are in English.

## Where things are

- `docs/INDEX.md` is the way into the docs of the code as it is: `PROJECT_MAP.md` (folders, where new things
  go), `SYSTEMS.md` (each system, its files, its doc in `docs/systems/`, its tests), `ARCHITECTURE.md`,
  `DATA_MODEL.md`, `DEPENDENCIES.md`, `DECISIONS.md`, `docs/testing/` (tests, CI). Generated, read only by
  `grep`: `docs/generated/code-index.md` (every script), `content-index.md`, `content-graph.md`,
  `content-recipes.md`, `content-checks.md`. `docs/audit/`, `docs/planning/`, `docs/reports/weekly-audits/` are
  dated history, not instructions (`OPEN_ISSUES.md` there lists open problems).
- Design, the decision log, the MVP stages and the backlog live outside the repo, in the Claude project's
  library `plan/` (`README.md` index and decisions, `mvp.md`, `backlog.md`, `design/`, `architecture/`);
  screenshots in `survivium-builds/`. A `plan/` doc marked PROPOSED or DRAFT describes intent, not code.

```
scenes/main.tscn   the one scene (Main, src/client/main.gd builds the modules and runs the frame)
src/shared/        content/ (mods), world/, game/ (rules, session), net/ (protocol): what the server runs
src/server/        the server: tick node, player, requests, sockets, saving, tunnel
src/client/        world/ view/ input/ game/ audio/ ui/ net/: drawing, input, sound, UI, copies of server state
content/<mod>/     the mods' data and assets, a folder per bundle
shaders/ assets/ tests/ tools/   3D shaders; pictures, fonts; headless tests; lint, validator, screenshots
```

## How to work on a task

1. Read this file, find the system in `docs/SYSTEMS.md`, read only its overview and the page the change reaches.
   Follow other systems only where the change reaches them (`python3 tools/doc_index.py uses <path>`).
2. Widen the search only for an unknown link, a regression risk or a doc that contradicts the code; then fix the
   doc in the same PR. Do not re-audit the project.
3. A change of the project's structure or architecture is laid out to the user with options and a
   recommendation first; everything else goes ahead.
4. Make the change, update the docs it touches (the system's doc, `SYSTEMS.md` for a new system, `PROJECT_MAP.md`
   for a new folder), run `python3 tools/doc_index.py` (after a change of content also `tools/content_report.gd`),
   then the checks.

## Rules that must hold

One line each; the full text is in `docs/CONTRIBUTOR_RULES.md` (read it before a change to the layers, requests,
`main.gd`, content kinds, audio or saves).

- Layers: rules the server decides in `src/shared/game/`; drawing and asking in `src/client/`; a client's ask is a
  request of `protocol.gd` done by `src/server/requests.gd`. `src/shared/` loads nothing from client or server;
  `src/server/` only `src/shared/`; the client loads `src/server/` only in `src/client/net/local_host.gd`.
- A rule takes the one acting as `who` and reports changes by signals.
- The server trusts nothing a socket sends (`docs/security/`): check types, bounds, reach and land rights; a
  request taking the hands' time goes into `Requests.PACED`; each fix gets a test in `security_test.gd`.
- `main.gd` only builds the scene and runs the frame; new state goes into its module; a rule over time is a step
  of the session (`docs/systems/session.md`).
- Content is data: numbers in the mod's YAML and `content_schema.gd`; code asks for content by role, not by id.
- Nothing map- or chunk-sized runs in one frame (`frame_test`); the phone browser is ~10× slower than a desktop.
- 3D shaders, lights, picking: `docs/systems/rendering/rules.md` first.
- Nothing sounds before the first tap or key; keep the loops few.
- Never delete or move a file only because nothing names it (paths are conventions); moving content needs rename maps.

## Bundles

A bundle is a switchable part of a mod (`content/animals/wolf/`, id `animals/wolf`); see `docs/DATA_MODEL.md`,
`docs/systems/content.md`. What the user's spec `plan/history/tasks/bundles.md` (decision 152) calls a bundle is a
record (`mod:name`); no technologies, eras are labels the content graph checks. Read
`docs/specifications/BUNDLE_SYSTEM.md` before changing content kinds, recipes, stations or tools;
`tests/unit/bundle_system_test.gd` must keep loading and playing.

## Version and changes

Every PR description has a Russian `Что нового [вид]: …` line and an English `What's new [kind]: …` line per
change (kinds: new, improved, fixed, optimized, core): `.github/pull_request_template.md` has the format and
how the version `<stage>.<PR>` and the changes list are built.

## Reading cheaply

Context is paid for at every later step: read only what the change reaches.

- A file over ~30 KB is not read whole: `grep -n` first, then a range of lines. Links between scripts:
  `python3 tools/doc_index.py uses <path>`.
- `docs/generated/*` only through `grep`, never whole (`content-graph.md` alone is 218 KB).
- A system's doc: `docs/systems/<x>.md` is a short overview, its pages are in `docs/systems/<x>/`; read the
  page the change reaches, by `grep -n '^#'` first.
- A search over more than ~5 files goes to the Explore subagent; only its answer comes back.
- Cut command output (`| tail -30`, `| grep`), keep logs in a file and `grep` them.
- Screenshots: several on one sheet (`tools/sheet.gd`).

## Checks

Before every push, the fast ones (`parse` needs `--import` first, and again after pulling new assets):

```
python3 tools/lint.py
python3 tools/doc_index.py --check
python3 tools/lang_check.py --strict en,ru
godot --headless --path . --import
godot --headless --path . --script res://tools/parse_check.gd 2>&1 | tail -30
```

Then only what the change reaches. CI runs the rest (label `full`: everything); do not wait for `progress_test`
locally unless the PR touches content or crafting, and leave `frame_test` to CI (too slow and noisy here).

| The change | Run |
|---|---|
| UI only | `run_tests`, screenshots |
| content data, recipes, stations, tools, materials, hands | + `validate`, `report`, `balance` (regenerate with `tools/content_report.gd`, `tools/balance_report.gd`, no `--check`), `progress_hunting`, `progress_other` |
| world, generator, chunks, meshes, every frame | `run_tests -- generation mesher shapes store`, `frame_test` (CI) |
| saves | `save_test` |
| network, server, protocol | `run_tests -- net session`, `server_test` |

`tests/run_all.sh [parse validate report balance run_tests save_test progress_hunting progress_other
server_test frame_test]` runs the Godot checks side by side (`GODOT=path`). Outside GitHub Actions it is quiet:
one line per check, failures with context, full logs in `logs/` (`LOGS=dir`; `VERBOSE=1` prints them whole). One
by hand: `timeout 300 godot --headless --path . --script res://tests/save_test.gd 2>&1 | tail -30` (always
`timeout`: a runtime error in an awaiting script leaves Godot running; `progress_test -- --part hunting|other`
1500 s; `--check-only --script res://x.gd` parses one script; `git config core.hooksPath tools/hooks` runs lint
and doc_index before each commit). Tests, CI, flaky checks: `docs/testing/`.

## Gotchas

One line each; the full list is in `docs/CONTRIBUTOR_RULES.md`, the rendering ones in `docs/systems/rendering/pitfalls.md`.

- A static func named like a `Script` method (`reload`, `get_class`) is shadowed: hence `Mods.rescan`.
- A server from the terminal: `godot --headless --path . -- --server [--port N] [--seed N | --world <dir>]`; a client:
  `-- --join ws://host:port`; test world `--seed -1` (`docs/systems/network.md`).
- Big scripts are chains of parts (`world_actions.gd` ← `actions_*.gd`, `hud_*`): a part calls only itself and
  earlier parts; callers preload the last.
- GDScript traps: a lambda using `self` connected to a signal makes a cycle (connect a method); `var i := expr`
  with a Variant is a parse error; `typed_array = expr if c else []` aborts silently; a self-typed return
  without `class_name` hangs the `make_*` tools (`--check-only` first).
- A player's text is a key `"[bag_is_full]"` with English and Russian in `lang/en.yaml`, `ru.yaml`
  (`python3 tools/lang_check.py --write en|ru`); logs and debug texts are plain English; never `template % values`
  (`docs/systems/lang.md`).
- A mod's file is read only through `Content`, never `FileAccess` at `Content.ROOT`; `hello` carries the mods' hash.
- Never use -1 as "none" for world coordinates. Tests of time wait by `Time.get_ticks_msec`, not frames.
- Material numbers follow the load order: a world's bundle set must not change (`Mat.remap`).
- Audio buses live in `default_bus_layout.tres`; `tools/web_patch.py` patches the web audio: re-check on an engine upgrade.
- Web: a JS snippet from GDScript must be strict and not touch `arguments`; touch also arrives as mouse motion.
- `tools/shot.gd` and `tools/profile.gd` save `user://settings.cfg`; scene tests use `user://test_settings.cfg`.
- A runtime error in a test aborts only its function: `run_all.sh` fails any log with `SCRIPT ERROR`.
- Rendering (shaders, lights, MultiMesh, atlas, phone GPUs, stencil, particles): `docs/systems/rendering/pitfalls.md`.
