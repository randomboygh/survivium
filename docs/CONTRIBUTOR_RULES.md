# Contributor rules and gotchas in full

Status: ACTIVE. The full text of the rules and gotchas that `CLAUDE.md` keeps in short form (moved here to keep
`CLAUDE.md` small: it is read at the start of every task). The rendering gotchas are in
[systems/rendering/pitfalls.md](systems/rendering/pitfalls.md), last section.

## Rules that must hold

- A new script goes into the folder of its layer. What happens in the game (a rule the server must
  decide) goes into `src/shared/game/`; how it is drawn or asked for goes into `src/client/`; what the
  client asks of a rule is a request of `src/shared/net/protocol.gd` done by `src/server/requests.gd`
  (`docs/systems/network.md`). `src/shared/` loads nothing from `src/client/` or `src/server/`
  (`run_tests.gd` fails otherwise); inside it, `content/` loads nothing else, `world/` and `net/` only
  `content/`; `src/server/` loads only `src/shared/`; the client loads `src/server/` only from
  `src/client/net/local_host.gd` (tested too).
- A rule takes the one acting as `who` (on the server `src/server/player.gd`, which extends
  `src/shared/game/character.gd`: the body, the hands, the bag; `src/client/game/character.gd` is the
  client's copy of it) and tells what it changed through signals the client's views connect to
  (`world_actions.gd`, `placed.gd`, `wildlife.gd`).
- The server trusts nothing a socket sends (`docs/security/`): a new request checks its args' types and
  bounds (slots, sizes, corners), reach and land rights, and goes into `Requests.PACED` if it takes the
  hands' time; a new `input` field is derived or clamped on the server; a new command gets its role in
  `Server.COMMANDS`; text a player typed goes through `Protocol.clean_text`. Each fix gets a check in
  `tests/unit/security_test.gd` or `server_test.gd` `_security`.
- `main.gd` only builds the scene and runs the frame; client modules get the Main node as `game`. New
  state goes into the module it belongs to; a new system is a new module. The rules over the world are
  run by the session (`src/shared/game/session.gd`, the server's tick): a rule that goes on in time is a
  step of the session, which `main.gd` calls, not code in `_process` (`docs/systems/session.md`).
- Content is data: numbers that describe content go into the YAML of a mod and the schema in
  `src/shared/content/content_schema.gd`, not into constants. The engine asks for content by role, never by
  id (`Items.with_prop`, `Plants.of_kind`, `Mat.of_role`, `Biomes.tree`); the only ids code names are
  core's (`Mat.GRASS`, `Placed.CAMPFIRE`). Details: `docs/DATA_MODEL.md`.
- Nothing map-sized or chunk-sized runs in one frame: chunks are generated a row at a time and meshed
  a column at a time through jobs run by `chunk_streamer.gd` within per-frame budgets
  (`tests/frame_test.gd` enforces it). The phone browser is about 10× slower than a desktop in
  GDScript; CI renders in software, so only the user's phone numbers count (stats panel, F3).
- New 3D shaders include `shaders/common.gdshaderinc` and shear VERTEX like the others; lights go at
  `PixelView.shear(pos)`, picking uses `PixelView.view_ray`; colour hints are `SRGB`/`SRGB_HINT`, not
  `source_color`, and fragment() ends with `COMPAT_ALBEDO` (Android draws with Vulkan; `docs/systems/rendering/rules.md`).
- Nothing sounds before the first tap or key (`Sound.unlocked`); sounds are asked for by bare name;
  keep the loops few (`docs/systems/audio.md`).
- Never delete or move a file only because nothing names it: data, assets and unit tests are found by
  path conventions (`content/<mod>/<bundle>/data/<kind>.yaml`, `sprites/`, `models/`, `tests/unit/`).
  Moving a script means changing every `preload` path; moving content changes ids and needs the
  rename maps (`Items.canon`, `Mods.RENAMED`, `Mat.RENAMED`) for old saves.

## Gotchas

Each in one line; the system's context doc has the detail.
- Rendering gotchas (shaders, lights, MultiMesh data, atlas limits, phone GPU artefacts, stencil, headless shader errors, mesh winding): `docs/systems/rendering/pitfalls.md`, last section.
- A static func named like a method of `Script` (`reload`, `get_class`, `is_tool`) is shadowed:
  `Mat.reload()` recompiles the script. Hence `Mods.rescan`.
- A server from the terminal: `godot --headless --path . -- --server [--port N] [--seed N | --world <dir>]`
  (from a PC build `Survivium.console.exe --headless -- --server` or `./Survivium.x86_64 …`)
  (`src/server/server_main.gd`, `docs/systems/network.md`); the test world is `--seed -1`. A client joins
  it with `-- --join ws://host:port [--name X]`, from the menu by «Мультиплеер» → «Присоединиться»
  (`?server=ws://host:port` in the browser opens that screen filled in). The server
  saves every 10 s and on `stop` (`src/server/server_store.gd`); Ctrl+C kills Godot at once, no hook.
- Big scripts are chains of parts by topic (decisions 145, 168; `world_actions.gd` ← `actions_*.gd`, `content_*`,
  `menu_*`, `hud_*`): a part calls only itself and earlier parts (else a parse error); callers preload the last.
- A lambda that uses `self`, connected to a signal of something the object holds, makes a cycle a
  RefCounted is never freed from: connect a method (`src/shared/game/character.gd`).
- `var i := expr` with a Variant `expr` is a parse error: type it. `typed_array = expr if c else []`
  is a runtime error that silently aborts the function. A self-typed return (`-> VoxelModel`) without
  `class_name` is a parse error that hangs the `make_*` tools: `--check-only` first.
- A player's text is a key (`"[bag_is_full]"`, a record's title `[<mod>.<kind>.<id>]`), never a phrase: a new
  key needs its English and Russian in `lang/en.yaml` and `ru.yaml` beside it (`python3 tools/lang_check.py
  --write en`, `--write ru`); internal texts (logs, console, F3) are plain English. The server sends
  `Lang.line(template, values)`, the client formats with `Lang.f` and takes the words by `Lang.t`, never
  `template % values` or glued pieces (`docs/systems/lang.md`).
- A mod's file is read only through `Content` (`real`, `text`, `file_exists`, `files_at`, `picture`, `sound`), never
  by `FileAccess` at `Content.ROOT`: on a server with other mods the file is one taken from it (decision 189,
  `Content.serve`). `hello` names the hash of the mods' files: a test's hello has six args.
- Never use -1 as "none" for world coordinates: negative ones are real.
- Tests of time-based behaviour wait by `Time.get_ticks_msec`, not frames. A per-frame flag computed
  before a state-changing update is stale in that frame.
- Material numbers follow the load order: a world's bundle set must not change; old saves go through
  `Mat.remap`.
- Audio buses live in `default_bus_layout.tres` (a bus added later is silent on the web);
  `tools/web_patch.py` patches the web audio loop and the garbage the engine makes each frame (time, names): re-check it on an engine upgrade.
- A JS snippet run from GDScript must be strict and must not touch `arguments` in a wrapper with named
  params: that makes an object per call.
- Web touch also arrives as mouse motion: `controls.input` treats it as a mouse only with no finger
  down and 1 s after the last touch.
- `tools/shot.gd` and `tools/profile.gd` save `user://settings.cfg`; the scene tests read their own
  `user://test_settings.cfg` (`Settings.path`), so a tool no longer changes what they play.
- A runtime error in a test aborts only its function: `run_tests` counts each as a failure and
  `run_all.sh` fails any log with `SCRIPT ERROR`.
