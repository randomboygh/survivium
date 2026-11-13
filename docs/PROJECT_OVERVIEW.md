# Project overview

Status: ACTIVE, checked against the code on 2026-11-09 (client 0.2.457). A Russian copy:
[PROJECT_OVERVIEW_RU.md](PROJECT_OVERVIEW_RU.md).

## The game

Survivium is a meditative survival sandbox: a big procedural world of levels in 3D pixel art seen at 3/4,
one character, gathering, crafting, building, a living world with beasts and seasons, teams, territories
and PvP on a server. It runs in the browser and on PC (Windows, Linux) and Android; multiplayer goes
through its own authoritative server (the same executable, decision 153). The idea: `plan/design/overview.md`
and `plan/design/mvp-design.md` in the library; what is done by area — `README.md` in the root.

## State

- Stage 0 (the technical prototype) is closed, stage 1 (the MVP) is in progress, see `plan/mvp.md`. The
  browser build: https://randomboygh.github.io/survivium/ (built from `main`), the PC builds — the
  `pc-latest` release.
- Done: a world without an edge from noise (48 levels, mountains, caves, rivers, swamps, 28 biomes as data),
  time, seasons and 11 kinds of weather, a character with a bag, worn bags and clothes, strengths (satiety,
  water, vigour and sleep, body warmth and getting wet) and death, work by hands (dig, build, chop, mow,
  gather, plant, fish), crafting at stations with a queue, a campfire and a fireplace on fuel, food spoiling,
  light as a consumable that is brighter in the dark, beasts and fish (they attack by shared rules, fear
  fire, the hare can be tamed), ten skills (experience for useful work, speed, extra yield, durability of
  what is made), the quality of things 1–100 from materials, tool and skill, building (wall materials, a
  blueprint of a wall, a floor and a room built cell by cell, doors, windows, furniture, a fence, a wicket
  and a gate, hatches, a leaning ladder; a separate build mode with a palette, shapes, slopes and steps as a
  cell's shape and levelling of the ground), farming (farm mode, beds, watering, crops grow by seasons and
  moisture, sprouts from an acorn and a cone; plants overgrow and spread on their own), a raft and a boat
  with oars, river currents, signs, gestures, ten languages (English by default), light through windows and
  doors, the beasts redrawn (three kinds, walking, frames of rest and attack), the cave view by layers,
  sound and music from notes, saving by worlds, mods and bundles with hot reload on PC, debugging of the
  beasts' AI (F4); the server (a world session with a tick, WebSocket, saving, the host's commands, chat, a
  tunnel from the internet; single player goes through a server in the same process), teams, land plots with
  rights, PvP by the server's modes, the decay of abandoned land.
- In the data now: 30 cell materials, 217 items, 162 recipes, 20 species of trees, 6 shrubs, 21 plants on
  grass and in a bed, 23 creatures (with the human), 28 biomes, 7 eras, 10 skills; 9 mods, 167 bundles (the
  full list is [generated/content-index.md](generated/content-index.md)).
- Not there: the decay of buildings, an editor, NPCs; the experiment in crafting
  was cancelled (decision 181). What of this is planned — `plan/mvp.md` and `plan/backlog.md` in the library.

## Technology and limits

- Godot 4.5.1, the GL Compatibility renderer (WebGL 2), web export without threads, pure GDScript: scripts
  are connected by `preload` constants, `class_name` is not used, there are no autoloads or plugins.
- A phone browser is about 10 times slower than a computer, so nothing the size of a map or a chunk is done
  in one frame (jobs by columns and rows within a frame budget, `tests/frame_test.gd`).
- CI renders in software: its FPS means nothing, the numbers come only from the user's phone (F3).
- Everything that describes content is the mods' data (`content/<mod>/…/data/*.yaml`), not code constants;
  the code asks for content by role, not by id (except the ids of the core, `core:`).
- The rules of the game (`src/shared/`) are separate from the picture and input (`src/client/`), so that a
  server can run them.
- Language: the game speaks ten languages, English by default; every text a player reads is a key in
  square brackets that each language translates ([TRANSLATION.md](TRANSLATION.md)); the README and the
  documents in `docs/` are in English with Russian copies `_RU.md`, the documents in `plan/` are in Russian;
  code, comments, commits and PRs are in English.

## Where next

[ARCHITECTURE.md](ARCHITECTURE.md) — how the code is built, [SYSTEMS.md](SYSTEMS.md) — where each system
is, [DATA_MODEL.md](DATA_MODEL.md) — data and mods.
