# Project map

Status: ACTIVE. The full list of scripts with their purposes: [generated/code-index.md](generated/code-index.md).
A Russian copy: [PROJECT_MAP_RU.md](PROJECT_MAP_RU.md).

## Folders

```
project.godot            engine settings: the main scene, the stage version, global shader parameters
export_presets.cfg       export presets: Web (html head_include with loading styles), Windows Desktop, Linux
default_bus_layout.tres  audio buses (the web build copies them at start: new buses only here)
scenes/main.tscn         the main scene: the Main node with src/client/main.gd; server.tscn — the scene of a server from the terminal (--server)
src/shared/              the world and the rules of play; the server runs them; loads nothing from src/client/
  content/               the mod loader (content, yaml, mods) and the registries of data kinds
  world/                 cells and chunks, ground shapes, the layout and the generator, saves on disk, grass, the test world
  game/                  rules and the session: bag, strength, warmth, skills, character, body, the hands' actions, felling, blueprint, things on cells, crafting, clock, weather, storms, beasts, fishing, commands, territory, fights
  net/                   the client–server protocol: kinds of requests, messages to bytes; loads only content/
src/server/              the server side: the node with the tick and generation under the tree's root (runner.gd), the player's character (player.gd), its link with events (player_link.gd), requests to the rules (requests.gd), the server over the network (server.gd: port, login, links, commands; server_main.gd — the root of the server scene, config.gd, console.gd, tunnel.gd — access from the internet through cloudflared, test_commands.gd — «/test»: bots and another world on any server; playtest_host.gd — the term of a test server; cheats.gd — cheats); loads only src/shared/
src/client/              the picture, input and sound of this device; main.gd, settings.gd, save_game.gd, mod_reload.gd
  world/                 chunks on screen: the streamer, meshes (cells, slopes, water, trunks), grass and crowns, snowdrifts, tracks, the roof map
  view/                  projection, camera, sky and light, fires and shadows, rays, textures, voxel models, the player and its sheet, other players, the cave view, blueprint, land marking, shader warm-up
  input/                 keys, mouse, touches, the cursor frame, joystick and buttons
  game/                  the client's parts of systems: the player's character, gathering, things and beasts on screen, map markers
  net/                   the connection to the server (connection.gd), the socket to a server over the network (socket.gd), the server inside the game (local_host.gd — the only one that loads src/server/), copies of the world (remote_gen.gd: chunks from the server), of the workshop, things on cells, the clock and beasts (mirror.gd, remote_*.gd), recent servers (server_list.gd)
  audio/                 buses, the ear, nature, steps, voices, music
  ui/                    HUD, menus, the bag and crafting windows, settings, maps, death, the freeze log, style
    kit/                 the UI kit: ready parts of windows (window, buttons, fields, «‹ ›» rows, two taps, the strip of cells)
shaders/                 3D shaders (the shared common.gdshaderinc), colour correction, the map, the interface
content/<mod>/           mods: mod.yaml, README, bundle folders with bundle.yaml, data/, sprites/, icons/, models/, textures/, sounds/, lang/ (translations); common/ shared assets
assets/                  the font, the splash, interface icons (ui/), the web page's icons (web/, not imported)
tests/                   headless tests (run_tests + unit/, save, progress, frame, server), the check in a browser, run_all.sh (all the checks)
tools/                   lint (lint.py), compiling all scripts (parse_check.gd), the pre-commit hook (hooks/), the validator, screenshots (shot + shot/), the map, benches, the profile, makers of pictures, sounds, icons; art/, sound/
.github/                 CI (workflows/build.yml), the test server (workflows/playtest.yml), the Godot setup (actions/godot), the PR template
docs/                    this documentation (audit/ — audit reports, planning/ — plans, balance/ — the balance model and tables, testing/ — how to check and CI,
                         security/ — the threat model, protocol defence, command rights, anti-cheat, security tests)
```

In detail by layers and links: [ARCHITECTURE.md](ARCHITECTURE.md); by systems: [SYSTEMS.md](SYSTEMS.md).

## Key files

| File | Why it matters |
|---|---|
| `src/client/main.gd` | builds the scene and all modules, runs the frame; modules get Main as `game` |
| `src/shared/content/content.gd` | the mods' data: the schemas of all kinds (`content_schema.gd`), reading and checking fields (`content_fields.gd`), mods and bundles on disk, dependencies (`content_mods.gd`), loading a set and patches |
| `src/shared/content/materials.gd`, `items.gd` | the most used registries (over 40 dependent files, `python3 tools/doc_index.py uses <path>`) |
| `src/shared/world/world_data.gd` | the world, its cells and shapes (over 50 dependents) |
| `src/shared/world/world_gen.gd` | the generator by stages and jobs |
| `src/client/world/chunk_streamer.gd` | what is built and when in a frame: budgets, the slice of levels |
| `src/shared/game/world_actions.gd` | everything the hands do to the world (parts by topic — `actions_*.gd`, see [systems/interaction.md](systems/interaction.md)) |
| `src/shared/game/session.gd` | the world session: the rules over the world, players, the tick (what the server runs) |
| `src/shared/net/protocol.gd` | the protocol: kinds of the client's requests to the rules and messages to bytes |
| `src/client/save_game.gd` | when and what is saved (conversions of old saves — `world_store.gd`) |
| `shaders/common.gdshaderinc` | shared shader code: the 3/4 shear, light, the roof |
| `tests/run_all.sh`, `.github/workflows/build.yml` | all the checks locally and in CI |

## Where to put new things

| What | Where |
|---|---|
| A rule of the game (what the server decides) | `src/shared/game/` (world data — `src/shared/world/`, loading data — `src/shared/content/`) |
| A new client request to a rule | the kind and args in `src/shared/net/protocol.gd`, a branch in `src/server/requests.gd`, a `game.net.request` call on the client ([systems/network.md](systems/network.md)) |
| How to show, ask for or sound it | the layer's folder in `src/client/` |
| A new system | a new module script; Main creates it and passes itself as `game`; a row in [SYSTEMS.md](SYSTEMS.md) |
| Numbers and records of content | the mod's YAML and the schema in `content_schema.gd`, not code constants ([DATA_MODEL.md](DATA_MODEL.md)) |
| A new creature, plant, tool, biome | a bundle folder in its mod (`content/animals/<name>/` …), see the mod's README |
| A 3D shader | `shaders/`, with `#include "res://shaders/common.gdshaderinc"` ([systems/rendering.md](systems/rendering.md)) |
| A test of a rule | `tests/unit/<topic>_test.gd` and the topic's name in `FILES` in `tests/run_tests.gd`; a generative one — `tests/unit/properties_test.gd` ([testing/TESTING_GUIDE.md](testing/TESTING_GUIDE.md)) |
| A development tool | `tools/` (drawing tools — `tools/art/`, sound — `tools/sound/`) |
| A window or an interface element | from the parts of the kit `src/client/ui/kit/` ([systems/ui.md](systems/ui.md), «UI kit»); a new shared part goes into the kit and into the «Interface gallery» |
| An interface picture | `assets/ui/` |
| A document about the code | `docs/` (a system — `docs/systems/`) |
| Game design, a decision, a task | the library: `plan/design/`, the journal in `plan/README.md`, `plan/backlog.md` |
| A screenshot | the library: `survivium-builds/<topic>/` and a row in its README |

New top-level folders are not created without need.

## What not to read without need

- `.godot/`, `*.import`, `*.uid`, `build/`, `build_info.json`: caches and the build, not in git.
- `content/**/sounds/*.wav`, `content/**/*.png`, `assets/`: binary assets; `tools/make_*` make them.
- `tools/art/*.gd`, `tools/make_plant_art.py`, `tools/make_creatures.py` (+ `creature_kit.py`), `tools/make_sparrow.py`, `tools/make_birds.py`, `tools/make_frog.py`, `tools/make_fish.py`, `tools/make_rabbit.py`, `tools/make_squirrel.py`, `tools/make_fox.py`, `tools/make_deer.py`, `tools/make_boar.py`, `tools/make_bear.py`, `tools/make_wolf.py`, `tools/make_cat.py`, `tools/make_hedgehog.py`: asset drawing tools, big tables of pixels.
- `src/shared/world/test_ground.gd`: the test world's sites, needed only for them.
- `tools/shot/places.gd`, `tools/shot/shots.gd`: the places and the table of screenshots.
- `assets/fonts/PressStart2P.ttf`, `assets/fonts/OFL.txt`: the font and its licence.
- In the library: `plan/history/` (the history of closed topics), `survivium-builds/` (pictures), `uploads/`.
