# Saving

Status: ACTIVE. A Russian copy: [saving_RU.md](saving_RU.md).

**Purpose.** To save the world on the device: only what the player changed (the generator makes the rest
again from the seed), the player, the clock, things on cells, the explored map; to open a saved world and to
convert the saves of old versions.

**Files**
- `src/shared/world/world_store.gd` — the world's files under `user://saves` (in a browser — IndexedDB): a
  folder per world (`world_dir(seed, options)`), `world.json` (the seed, settings, mods, levels, the clock,
  things, plots `territory`, blueprints `plans`; the fields — [../DATA_MODEL.md](../DATA_MODEL.md), «Saves»),
  `players/<name>.json` (the place and the modules' parts), `chunks/<cx>_<cz>.bin` (a changed chunk:
  `WorldGen.pack`, `store_var`, zstd), `map/<rx>_<rz>.bin` (a region of the map), `current.json` (which world
  to start from). A file is written beside and moved over: an interrupted write leaves the old one whole.
  `FORMAT` 1; `list_worlds`, `erase`.
- `src/client/save_game.gd` — when to write: once per `INTERVAL` (30 s) a few chunks per frame, and at once
  on the menu, loss of focus, exit; what to write is given by the shared systems (`to_dict` / `to_list`: the
  clock, things, the character, the bag, skills, plots, blueprints); the modules register the player's parts
  by `save.track(name, object)`. Choosing a world (`choose_world`, `switch_world`), restoring
  (`restore_player`, `restore_clock`). Off in tests and tools (`enabled`).
- `src/server/server_store.gd` — the same for a server without a window: writes the world every 10 s and on
  `stop`, with the commands, fights and players by their keys ([network.md](network.md)).
- `src/shared/content/mods.gd` — `of_world(meta)`: the bundles of a saved world by its `world.json` (shared
  code: the server opens worlds by the same).

**Conversions of old saves** (the mark `content` in `world.json`, now 9):
- before 2…8 — the mods split off the base (plants, tools, sounds, music, materials, resources, biomes,
  `Mods.SPLITS`) are added to the world's set; before 6 — the list of mods is expanded into bundles
  (`Mods.expand`, `Mods.RENAMED`);
- a supplementing bundle (only items, recipes, eras, the start and sounds: `Mods.additive`) enters a world
  with its mod, if the world did not know it and the world has what it needs (decision 4А, `Mods.of_world`).
  What the world knew is written by `known` in `world.json` (all the bundles at the moment of saving), so a
  bundle the player switched off stays off; a world saved before `known` knew the bundles
  `Mods.OLD_ADDITIVE`, and the torch — from the mark 9. A bundle with cells, trees, shrubs, plants, biomes or
  beasts does not enter an old world: it changes the ground and the material numbers;
- before 5 — the cells' material numbers by the old list `OLD_MATERIALS`, otherwise by `materials` from
  `world.json` (`Mat.remap`); the old ids of items and recipes — `Items.canon`, `Crafting.canon`,
  `Mat.RENAMED`; these functions look at the records' field `was` too (`Content.canon`).

**Limits.** A world's set of bundles changes only by the arrival of supplementing bundles; a bundle with
cells or beasts an old world will not see. A renamed record lists the old ids in its field `was` (no code
needed); renaming a bundle needs an entry in `Mods.RENAMED`. A saved chunk returns at once at the stage
SHAPED. A world's set of bundles is decided by shared code (`Mods.of_world`); the material numbers and old
ids are converted by the shared `world_store.gd` (`materials_of`, `OLD_MATERIALS`, `CONTENT`), the server will
convert them by it too.

**Tests.** `tests/unit/store_test.gd` (`save`), `tests/save_test.gd` (plays, saves, starts again; the world
remembers the known bundles; an old save without a torch and without a sword gets the torch, and the sword
not), `tests/unit/content_test.gd` (`old_worlds`: a supplementing bundle enters, a bundle with beasts and a
bundle without what it needs — do not, worlds of the marks `content` 1–9 open with all bundles),
`tests/unit/character_test.gd` (old ids in the bag).

**In more detail.** `plan/architecture/simulation.md` («Storing the world»), the decisions about saving in the
journal `plan/README.md`.
