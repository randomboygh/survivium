# Survivium: notes for contributors

A meditative survival sandbox: a procedural world of levels in 3D pixel art seen at 3/4, played in
the browser (later Android, and multiplayer through an authoritative server that does not exist
yet). Godot 4.5.1, GL Compatibility renderer, web export without threads, pure GDScript: scripts are
loaded with `preload` consts and `extends "res://…"`, no `class_name`, no autoloads, no plugins.
User-facing text, the README and the docs in `docs/` are in Russian; code, comments, commits and PRs
are in English.

## Where things are

- `docs/INDEX.md` is the way into the documentation of the code as it is: `docs/PROJECT_MAP.md` (folders,
  key files, where new things go), `docs/SYSTEMS.md` (each system, its files, its context doc in
  `docs/systems/`, its tests), `docs/ARCHITECTURE.md`, `docs/DATA_MODEL.md`, `docs/DEPENDENCIES.md`,
  `docs/DECISIONS.md`. Every script with its description: `docs/generated/code-index.md`; every
  mod, bundle and record, with its links: `docs/generated/content-index.md`; what comes of what, how
  deep and in which era, every recipe, and what the content checks found: `content-graph.md`,
  `content-recipes.md`, `content-checks.md` there.
- Design, the decision log, the MVP stages and the backlog live outside the repo, in the Claude
  project's library, `plan/` (`plan/README.md` index and decisions, `plan/mvp.md`, `plan/backlog.md`,
  `plan/design/`, `plan/architecture/` for rendering, performance and modding in depth); screenshots
  in `survivium-builds/`. A `plan/` doc marked PROPOSED or DRAFT describes intent, not code.

```
scenes/main.tscn   the one scene: Main with src/client/main.gd, which builds the modules and runs the frame
src/shared/        the world and the rules of play the server will run: content/ (mod loader, registries),
                   world/ (cells, shapes, layout and generator, files on disk), game/ (rules)
src/client/        drawing, input, sound, UI and saving on this device: world/ view/ input/ game/ audio/ ui/
content/<mod>/     the mods' data and assets, a folder per bundle
shaders/ assets/   3D shaders (common.gdshaderinc), interface pictures, fonts, web icons
tests/ tools/      headless tests and the browser smoke test; validator, screenshots, benches, asset makers
```

## How to work on a task

1. Read this file, then find the system in `docs/SYSTEMS.md` and read only its `docs/systems/*.md`
   and the files it names. Follow other systems only where the change reaches them
   (`python3 tools/doc_index.py uses <path>` lists who loads a script).
2. Widen the search only for an unknown link, a regression risk or a doc that contradicts the code;
   then fix the doc in the same PR. Do not audit the whole project again: stage 0 (2026-10-30,
   `docs/audit/`) did it, and the docs are kept current with the code.
3. A change of the project's structure or architecture is laid out to the user with options and a
   recommendation first; everything else goes ahead.
4. Make the change, update the docs it touches (the system's context doc, `SYSTEMS.md` for a new
   system, `PROJECT_MAP.md` for a new folder), run `python3 tools/doc_index.py` (and, after a change
   of content, `tools/content_report.gd`), then the checks.

## Rules that must hold

- A new script goes into the folder of its layer. What happens in the game (a rule the server must
  decide) goes into `src/shared/game/`; how it is drawn or asked for goes into `src/client/`; what the
  client asks of a rule is a request of `src/shared/net/protocol.gd` done by `src/server/requests.gd`
  (`docs/systems/network.md`). `src/shared/` loads nothing from `src/client/` or `src/server/`
  (`run_tests.gd` fails otherwise); inside it, `content/` loads nothing else, `world/` and `net/` only
  `content/`; `src/server/` loads only `src/shared/`; the client loads `src/server/` only from
  `src/client/net/local_host.gd` (tested too).
- A rule takes the one acting as `who` (on the client `src/client/game/character.gd`: the body, the
  hands, the bag) and tells what it changed through signals the client's views connect to
  (`world_actions.gd`, `placed.gd`, `wildlife.gd`).
- `main.gd` only builds the scene and runs the frame; client modules get the Main node as `game`. New
  state goes into the module it belongs to; a new system is a new module. The rules over the world are
  run by the session (`src/shared/game/session.gd`, the server's tick): a rule that goes on in time is a
  step of the session, which `main.gd` calls, not code in `_process` (`docs/systems/session.md`).
- Content is data: numbers that describe content go into the YAML of a mod and the schema in
  `src/shared/content/content.gd`, not into constants. The engine asks for content by role, never by
  id (`Items.with_prop`, `Plants.of_kind`, `Mat.of_role`, `Biomes.tree`); the only ids code names are
  core's (`Mat.GRASS`, `Placed.CAMPFIRE`). Details: `docs/DATA_MODEL.md`.
- Nothing map-sized or chunk-sized runs in one frame: chunks are generated a row at a time and meshed
  a column at a time through jobs run by `chunk_streamer.gd` within per-frame budgets
  (`tests/frame_test.gd` enforces it). The phone browser is about 10× slower than a desktop in
  GDScript; CI renders in software, so only the user's phone numbers count (stats panel, F3).
- New 3D shaders include `shaders/common.gdshaderinc` and shear VERTEX like the others; lights go at
  `PixelView.shear(pos)`, picking uses `PixelView.view_ray` (`docs/systems/rendering.md`).
- Nothing sounds before the first tap or key (`Sound.unlocked`); sounds are asked for by bare name;
  keep the loops few (`docs/systems/audio.md`).
- Never delete or move a file only because nothing names it: data, assets and unit tests are found by
  path conventions (`content/<mod>/<bundle>/data/<kind>.yaml`, `sprites/`, `models/`, `tests/unit/`).
  Moving a script means changing every `preload` path; moving content changes ids and needs the
  rename maps (`Items.canon`, `Mods.RENAMED`, `Mat.RENAMED`) for old saves.

## Bundles

A bundle is a switchable part of a mod (`content/animals/wolf/`, id `animals/wolf`); its mechanics are
in `docs/DATA_MODEL.md` and `docs/systems/content.md`. The bundle system of the user's spec `bundles.md`
(decision 152) keeps that meaning: what the spec calls a bundle is a record (`mod:name`). No
technologies: eras are labels the content graph checks. It is built (stages 1–8); its rules are in
`docs/specifications/BUNDLE_SYSTEM.md`, read it before changing content kinds, recipes, stations or tools, and
`tests/unit/bundle_system_test.gd` is a mod written by the mods' READMEs that must keep loading and playing.

## Version and changes

The client's version is `<stage>.<PR>`: the stage is `application/config/version` in `project.godot`
(raised by hand when an MVP stage closes or the code is reshaped), the PR the last one merged into
main. CI writes it with `tools/build_info.py` into `build_info.json` (not in git), along with the lines
`Что нового [вид]: …` from the descriptions of the last merged PRs, shown on «Тестирование». So every
PR description has at least one such line in Russian, for a player, not a programmer. The kinds:
`новое` (the default), `улучшено`, `исправлено`, `оптимизировано`, `ядро` (code moved, tools, tests,
docs); a PR that does several things has a line for each.

## Checks before every push

```
godot --headless --path . --import
godot --headless --path . --script res://tools/validate.gd
godot --headless --path . --script res://tools/content_report.gd -- --check
godot --headless --path . --script res://tests/run_tests.gd
timeout 300 godot --headless --path . --script res://tests/save_test.gd
timeout 1200 godot --headless --path . --script res://tests/progress_test.gd
timeout 600 godot --headless --path . --script res://tests/frame_test.gd
timeout 300 godot --headless --path . --script res://tests/server_test.gd
python3 tools/doc_index.py --check
```

`tests/run_all.sh` runs the godot ones after `--import`: the first six side by side, each with its own
`user://` (`XDG_DATA_HOME`), then `frame_test` alone, since it measures frame times (`GODOT=path` if
`godot` is not on PATH; names as arguments run only those). `frame_test` timings are noisy on a busy
machine: rerun it alone before blaming code. Run `progress_test` after any change to tools, materials,
stations, recipes or what the hands do. Run `--import` again after pulling new assets, or HUD scripts
fail with null errors that look like code bugs. Wrap headless runs in `timeout`: a runtime error in an
awaiting script leaves Godot running. `--check-only --script res://x.gd` only parses. CI
(`.github/workflows/build.yml`) runs the same plus the web export and the browser smoke test; details,
screenshots and the other tools: `docs/systems/testing.md`.

## Gotchas

Each in one line; the system's context doc has the detail.

- A static func named like a method of `Script` (`reload`, `get_class`, `is_tool`) is shadowed:
  `Mat.reload()` recompiles the script. Hence `Mods.rescan`.
- A server from the terminal: `godot --headless --path . -- --server [--port N] [--seed N | --world <dir>]`
  (from a PC build `Survivium.console.exe --headless -- --server` or `./Survivium.x86_64 …`)
  (`src/server/server_main.gd`, `docs/systems/network.md`); the test world is `--seed -1`. A client joins
  it with `-- --join ws://host:port [--name X]`, from the menu by «Мультиплеер» → «Присоединиться»
  (`?server=ws://host:port` in the browser opens that screen filled in). The server
  saves every 10 s and on `stop` (`src/server/server_store.gd`); Ctrl+C kills Godot at once, no hook.
- A lambda that uses `self`, connected to a signal of something the object holds, makes a cycle a
  RefCounted is never freed from: connect a method (`src/shared/game/character.gd`).
- `var i := expr` with a Variant `expr` is a parse error: type it. `typed_array = expr if c else []`
  is a runtime error that silently aborts the function. A self-typed return (`-> VoxelModel`) without
  `class_name` is a parse error that hangs the `make_*` tools: `--check-only` first.
- Never use -1 as "none" for world coordinates: negative ones are real.
- Tests of time-based behaviour wait by `Time.get_ticks_msec`, not frames. A per-frame flag computed
  before a state-changing update is stale in that frame.
- Godot front faces wind clockwise; a hand-built mesh wound counter-clockwise is inside out.
- MultiMesh instance data is half float on GLES3/web: new per-instance data goes in COLOR. Vertex
  COLOR is 8-bit. Packed float words stay below 2^23. `instance uniform` reads 0 in the web build.
- Phone GPUs flip pixels on texel edges and geometry lines: bias, overlap (`ChunkMesher.EPS`), no walls
  under 1 px; headless shows none of it (`docs/systems/rendering.md`).
- Nodes scaled 1/16 (voxel models) need `extra_cull_margin` × 16 or the shear culls them.
- Silhouettes and the player's x-ray go by the stencil values (`docs/systems/rendering.md`).
- Lights with shadows add in sRGB and cost a pass; Compatibility lights a mesh with at most 32 omni
  lights; `toon_light` returns 0 where ATTENUATION is 0 (`docs/systems/rendering.md`).
- A new kind of light or a material shown only later goes into `shader_warmup.gd`, or its first draw
  compiles shaders mid-game (100 ms+ on a phone).
- The material atlas holds 63 materials and barks together (`PixelTextures.MOST_MATERIALS`,
  `material_bits[63]` in `world.gdshader`): the mesh packs the material in 6 bits, the sides' tile as
  flag bit 1, the underside's by a face looking down (`MeshFaces.pack`); 21 are used.
- Material numbers follow the load order: a world's bundle set must not change; old saves go through
  `Mat.remap`.
- Audio buses live in `default_bus_layout.tres` (a bus added later is silent on the web);
  `tools/web_patch.py` patches the web audio loop: re-check it on an engine upgrade.
- A JS snippet run from GDScript must be strict and must not touch `arguments` in a wrapper with named
  params: that makes an object per call.
- Web touch also arrives as mouse motion: `controls.input` treats it as a mouse only with no finger
  down and 1 s after the last touch.
- `tools/shot.gd` and `tools/profile.gd` save `user://settings.cfg`, which breaks a later local
  `frame_test`: delete it first.
