# Architecture

Status: ACTIVE, checked against the code of `main` on 2026-11-09 (PR #457). Only what exists is here; the
ideas (the editor, mods' scripts) are in the library, `plan/architecture/`. A Russian copy:
[ARCHITECTURE_RU.md](ARCHITECTURE_RU.md).

## Layers

```mermaid
graph TD
  client["src/client/ — picture, input, sound, UI, saving on the device"]
  server["src/server/ — the server side: the player's character, its requests and events"]
  net["src/shared/net/ — the protocol: kinds of requests, messages to bytes"]
  game["src/shared/game/ — the rules of play"]
  world["src/shared/world/ — the world, the generator, the world's files"]
  content["src/shared/content/ — the mod loader and registries"]
  data["content/ — the mods' data and assets"]
  client -. only net/local_host.gd .-> server
  client --> net
  client --> game
  client --> world
  client --> content
  server --> net
  server --> game
  net --> content
  game --> world
  game -. protocol.gd .-> net
  game --> content
  world --> content
  content -. reads .-> data
```

- `src/shared/` is what the server runs. It loads nothing from `src/client/` and `src/server/`: `_test_layers`
  in `tests/unit/content_test.gd` checks it, a violation fails CI.
- Inside `src/shared/`: `content/` loads no other folder of `src/`, `world/` loads only `content/`, `net/`
  only `content/`, `game/` — `content/`, `world/` and `net/protocol.gd` (a sign's text is cleaned by
  `Protocol.clean_text`, PR #452). The same `_test_layers` checks this (it has no ban for `game/`).
- `src/server/` loads only `src/shared/`; the client loads `src/server/` only from
  `src/client/net/local_host.gd` — the server inside the game for single player (decision 153). What the
  client asks of the rules goes as protocol requests through `game.net`; the player's character and
  workshop live on the server, the client holds their copies by the server's events
  ([systems/network.md](systems/network.md)).
- The folders of `src/client/` refer to each other freely (with no `preload` cycles): the shared UI style
  (`ui/ui_style.gd`) is needed by input and the picture, the projection (`view/pixel_view.gd`) — by the
  meshes.
- Scripts are connected by a `preload("res://…")` constant with the full path, with no `class_name`; a base
  script is extended by `extends "res://…"`. When a file is moved only the paths change.
- Everything `main.gd` loads through `preload` is compiled at every start before the menu (this is most of
  the start, `start_times.gd`). So screens that are not opened at once load by path on first opening:
  `load(CONST_PATH)` instead of `preload` (2026-11-01: the settings `hud.settings_menu()` and
  `main_menu.settings_menu()`, choosing and creating a world, «Join», «Create a server», the server
  `local_host.gd`, the test world's plan: it is asked for by `WorldStore.TEST_SEED`). A new such screen is
  made the same way.

The graph by folders from the code: [DEPENDENCIES.md](DEPENDENCIES.md).

## Entry points

| Entry | What it starts |
|---|---|
| `scenes/main.tscn` (the main scene in `project.godot`) | `src/client/main.gd` — the game |
| `godot --headless --path . -- --server [--port N] [--seed N \| --world <folder>]` (from a PC build — `Survivium.console.exe --headless -- --server`) | `scenes/server.tscn` with `src/server/server_main.gd` — a server without a window ([systems/network.md](systems/network.md)) |
| `godot --headless --path . --script res://tests/<name>.gd` | the tests, each `extends SceneTree` |
| `godot … --script res://tools/<name>.gd` | tools: the validator, screenshots, the map, benches, asset makers |
| `python3 tools/<name>.py` | the build's version, the patch of the web build, Pillow drawing tools, the document index |
| `.github/workflows/build.yml` | CI: lint, checks, tests, the freeze test, web, PC and Android export, the check in Chrome, publishing to Pages and to a GitHub release per merge (and the rolling `android-latest`, `pc-latest`) ([testing/CI_PIPELINE.md](testing/CI_PIPELINE.md)) |

The tests and tools start the same scene: they create `main.tscn`, set `main.skip_setup = true` (no «New
world» menu) and, when needed, `save_root` (their own saves).

## Main and the modules

`main.gd` only builds the scene and runs the frame; the work lives in modules. A client module gets the Main
node as `game` (`Controls.new(self)`, `ChunkStreamer.new(self)`…) and through it sees its neighbours
(`game.world`, `game.clock`, `game.settings`). Main does not know the shared modules: they are handed only
what they need (`Workshop.new(character, placed, rules)`). The rules over the world are held by the session
(`src/shared/game/session.gd`): it makes `WorldActions`, `Storms` and `Wildlife`, takes in characters and
makes the tick (every frame of the server node: in the game it is the client's frame, on a server without a
window up to 60 times a second, `FPS` in `src/server/server_main.gd`), and orders the world (generation
around the players within a budget, forgetting far chunks); it is run by the server node
`src/server/runner.gd` under the tree's root, before Main in every frame
([systems/session.md](systems/session.md)). The session runs on the server inside the game; the client's
views read the copies (`game.character`, `game.workshop`, `game.placed`, `game.clock`, `game.wildlife`) that
`src/client/net/mirror.gd` feeds with the protocol's events ([systems/network.md](systems/network.md)).

The order of building (`_ready`, then `start_world`): input and settings → sound → saving (choosing a world)
→ `Mods.activate` (the world's set of bundles) → camera, the chunk streamer, sky, clock, real weather →
things on cells, character, gathering, hands, workshop, markers → interface and menus → the generator
(`WorldGen` or `TestGround`) with the save's map of materials → the world and the session (beasts, the
hands' actions, storms; the character enters it with the workshop), the host with the server node under the
tree's root → the scene, the player.

The frame: the server node (before Main): the session's steps — the clock, characters and workshops, beasts,
storms — and generation of chunks within the client's budget; Main's `_process`: while the world is not
ready, the near chunks are finished (then the spawn, things, beasts, shader warm-up) → the clock's copy and
the sky → the tick's events (`host.flush`), the player's body, input, gathering, hands, `input` to the
server → tracks, autosave → the slice of levels, chunk meshes (minus the generation time), roofs, budgets to
the node for the next frame → the roof map and the minimap → camera, warm-up, the freeze log → HUD and the
death screen. The time of each step is noted by `perf.note` / `perf.add` (the F3 panel). The menu's pause
stops Main and the session's steps but not the node: the world keeps being finished
(`_build_while_paused`).

## How the rules talk to the picture

- A rule gets the one acting as `who` (on the client — `src/client/game/character.gd`: body, hands, bag,
  messages to the player) and asks it only for what it needs.
- What changed, the rule tells by signals, and the client connects its views to them:
  `WorldActions.cell_changed` / `looks_changed` / `drops_changed` / `taken` → chunks and things on the
  ground; `Placed.added` / `removed` / `lit_changed` / `fuel_changed` / `cell_changed` → `props.gd`, fires,
  chunks; `Wildlife.born` / `gone` / `stepped` → `creatures.gd`, tracks, voices; `Inventory.changed`,
  `Workshop.changed` / `made`, `Knowledge.learned`, `SkillSet.leveled`, `Clock.season_changed`,
  `Character.state_changed` → the interface and sound. On the server `player_link.gd` is connected to them
  and sends events to the client; the copies on the client (`src/client/net/remote_*.gd`) give the views the
  same signals.
- The rules the host sets for everyone (free building, wear, instant crafting) are read by the rules from
  the shared object `rules.gd`; in single player `settings.gd` fills it, on a server — the `[rules]` section
  of its config (`src/server/config.gd`).
- A signal is connected by a method, not by a lambda with `self`: a lambda holds the object, and a
  RefCounted is not freed (see `src/shared/game/character.gd`).

## Work by frames

Nothing the size of a map or a chunk is done in one frame:
- the generator makes a chunk in three stages (`TERRAIN` → `PLANTED` → `SHAPED`), each as a job by a row or
  a tree (`WorldGen.start` / `step`);
- chunk meshes and plants are built by a column of cells (`ChunkMesher`, `Foliage`);
- generation is run by the session (`Session.make_chunks`) before the frame, meshes — by
  `chunk_streamer.gd` within the frame's budgets minus generation (edits, then far chunks, then roofs);
- autosave writes a chunk a frame, the minimap paints a chunk, the shader warm-up goes by a step.

A violation is caught by `tests/frame_test.gd`. Details of the budgets: `plan/architecture/performance.md`.

## Data and content

The code asks for content by role (`Items.with_prop("workbench")`, `Plants.of_kind("ears")`,
`Mat.of_role("ore", …)`, `Biomes.tree(b, roll)`), not by id; only the core's records are named by id
(`Mat.GRASS`, `Placed.CAMPFIRE`). The registries fill their static variables when the class loads and are
rebuilt by `Mods.activate` / `refresh`. In detail: [DATA_MODEL.md](DATA_MODEL.md).

The game's text: every text for a player is a key `[…]` (decision 186); the translations lie in
`lang/<code>.yaml` in a mod and a bundle, the server sends a key or `Lang.line`, the client translates it
itself (decision 183, [systems/lang.md](systems/lang.md)). When run from the project folder,
`content_watch.gd` notices the changed files of mods, and the module `mod_reload.gd` rereads the registries,
pictures and sounds (decision 184, [systems/content.md](systems/content.md)).

## Saving

Each shared system gives and takes its own state itself (`to_dict` / `from_dict`, `to_list`); the client's
`save_game.gd` decides when to write and registers the player's parts by `save.track(name, object)`; the
files are written and old saves converted by the shared `world_store.gd` (`materials_of`, `CONTENT`). In
detail: [systems/saving.md](systems/saving.md).

## How to extend

1. A new system is a new module in the folder of its layer; Main creates it and, if needed, calls it in the
   frame. A rule that goes on in time (for all players) is a step of the session (`session.gd`), not
   `_process`.
2. A rule goes into `src/shared/game/`; its view and input — into `src/client/`; the link is the rule's
   signals.
3. New numbers of content are a schema field in `src/shared/content/content_schema.gd` and the mod's YAML,
   not a constant.
4. A new station or class of tool is only data: `items.prop` and `items.tool` are open classes, what a thing
   does is said by its flags (decision 152, [specifications/BUNDLE_SYSTEM.md](specifications/BUNDLE_SYSTEM.md));
   work in the world exists only for the nine classes of `Tools.WORLD_KINDS`. The closed roles
   (`plants.kind`, `materials.role`, `biomes.where`, `biomes.zone`) need code for a new value.
5. Work the size of a chunk is a job by parts within the budget of `chunk_streamer.gd`.
6. A text for a player is a key `[…]`; a new key or record needs its English and Russian in `lang/en.yaml`
   and `ru.yaml` beside it (`tools/lang_check.py --write en`, `--write ru`).
7. After an edit — the checks from `CLAUDE.md`; rules, stations, recipes, tools — `progress_test` too.

The decisions this rests on, with reasons: [DECISIONS.md](DECISIONS.md).
