# Mods, bundles and registries (code)

Status: ACTIVE. The data model (kinds, ids, roles, saves): [../DATA_MODEL.md](../DATA_MODEL.md). Here is the
code of the loader and the registries. A Russian copy: [content_RU.md](content_RU.md).

**Purpose.** To find mods and bundles under `content/`, to choose a world's set with dependencies, to read
YAML, to check records against schemas, to apply patches and to fill the registries through which the rest of
the code sees content.

**Files**
- `src/shared/content/content.gd` — the mods' data; one script divided by topic into a chain of inheritance
  (decision 168, like 145): each part extends the previous one and calls only its own and the earlier ones,
  from outside only `content.gd` is known (`Content.records`, `Content.SCHEMAS` — everything through it).
  - `content_schema.gd` — `SCHEMAS` of all kinds, the common fields `COMMON`, the dictionary of links
    `RELATIONS` and actions `ACTIONS`, `MOD_SCHEMA`, `BUNDLE_SCHEMA`; `schema`, `refs` / `target` / `named`
    (a kind's reference fields and what a record names by them), `qualify`.
  - `content_fields.gd` — reading a YAML file (from the build's cache `PARSED` or by parsing), checking a
    record's fields against the schema and conversion into the engine's types (`_check_fields`, `_convert`),
    `problems`.
  - `content_mods.gd` — the mods and bundles on disk, read once (`universe`, `_scan`), `resolve` (the order
    and the dropped bundles), `closure`, `deps`, `BUNDLES`, `loaded`, `dropped`.
  - `content.gd` — loading a set (`load_all`), replacements (`replaces`) and patches, checking references (and
    inside `entries`), warnings about names, `records` / `find` / `canon` / `origin`, `asset`, `sound_files`.
- `src/shared/content/yaml.gd` — our own parsing of the part of YAML the data needs (keys with `:` inside,
  `{core:fiber: 1}`).
- Where the mods lie (decision 186): `Content.ROOT` — the folder `content/` beside the program in the built
  game on PC (Windows, Linux), if it has `core/mod.yaml` (`Content.find_root`, `Content.beside()`), otherwise
  the built-in copy `res://content` (`BUILT_IN`; the editor, the browser, a phone, a build without the
  folder). CI puts all the mods as open files (YAML, PNG, WAV, without `.import`) into `content/` beside the
  exe in the PC archives (`.github/workflows/build.yml`, the job `pc`); one's own mods — separate folders in
  the same place, an update replaces only the built-in ones. From there pictures and sounds are read from
  files (`Content.picture`, `Content.sound`, `Content.exists`; the player's drawings — `Figure.SPRITES`), the
  parsed YAML is taken from `content_cache.bin` while the file's text has not changed, and hot reload works in
  the built game too. The check is `content_test.gd` `_test_content_beside` (a copy of the mods in `user://`).
- Hot reload (decision 184): `src/shared/content/content_watch.gd` (`ContentWatch`) watches the files of
  `content/` (YAML, PNG, WAV) by `BUDGET` files and folders per step and at the end of a pass says whether a
  file changed, appeared or vanished (the first pass only remembers the time); it works where the files lie
  by themselves — the game run by the editor's engine from the project folder or the built game on PC with
  the mods beside it (`can_watch`), not the built-in copy and not the browser. `src/client/mod_reload.gd`
  (`ModReload`, Main's module `mod_reload`) steps the watch every frame (except headless: tests and tools
  reread by themselves) and rereads: `Mods.rescan(true)`, translations (`Lang.reread`), models
  (`VoxelProps.forget`), icons (`ItemIcons.forget`), the session's rules (`Session.reread`: the things'
  tracks, `Wildlife.reread`), sounds (`Sound.read_records`), the beasts' pictures (`Creatures.relook`), things
  on the ground and on cells (`Props.remodel`), the bag and crafting. The button «Reread the mods' data» in
  «Debug» does the same at once; the server — by the command `reload` (`Server.reload_mods`). After it
  `Content.live`: pictures and sounds are read from files (`Content.picture`, `Content.sound`), not from the
  import made at start. The cells' materials, if their list changed, stay as they were (`Mods.cells_kept`):
  new ones — in a new world; biomes and relief — for new chunks.
- `src/shared/content/mods.gd` — the game's set of bundles: `activate`, `rescan` (`live` — hot reload),
  `expand` (old lists), `RENAMED`; the set of a saved world `of_world` (the mods split off the base,
  `SPLITS`; supplementing bundles, `additive`, `OLD_ADDITIVE`); `why` (why a bundle dropped, the whole chain);
  the names for the «Mods» screen.
- `src/shared/content/content_graph.gd` — the content graph (`ContentGraph`): the paths by which things appear
  (the world, the start, an action with a tool by the rules of `Tools`, a recipe, a station, planting),
  reachability from the start with depth (`reached`) and era (`era`: by the same pass `_settle`, no earlier
  than the one written at the item), `basis(key, by_era)` — what a thing comes out of; errors (no source,
  cannot be got, a recipe cannot be made, does not grow, no fodder, a closed circle, an era earlier than the
  path) and warnings (a dead end, a station of one recipe, twins, a profitable circle, a material is not
  met, a long chain for the era). Only the validator, reports and tests build it, the game does not.
- `tools/content_report.gd` — reports from the loaded data: the registry of entities
  `docs/generated/content-index.md` (with the era of items and recipes), the graph `content-graph.md` (with
  the map of eras and the branches of progress), the registry of recipes `content-recipes.md`, the checks
  `content-checks.md`; `-- --check` for CI.
- The registries (fill static vars at class loading and in `refresh`): `materials.gd` (`Mat`), `items.gd`,
  `crafting.gd`, `trees.gd`, `bushes.gd`, `plants.gd`, `biomes.gd`, `ai_rules.gd`, `starts.gd` (the start of a
  new world: `Starts.START` — the hands' abilities, the bag, the camp; `check`), `eras.gd` (the eras in order:
  `Eras.ERAS`, `rank`, `title`, `check` — two eras of one order), `skills.gd` (skills: `Skills.ALL` in order,
  `of_role`, `need`, `level_at`, `progress`); `tools.gd` — the tools' rules over `Items` and `Mat` (with no kind
  of data of its own; the hands `HAND` it collects from the fields `hand_*` of the start in `refresh`): what is
  got with what (`can_dig`, `can_chop`, `can_dig_out`, `can_knock`, `can_gather`, `mows`), work in the world
  of the nine classes `WORLD_KINDS` (with the rod `rod`, the hoe `hoe`, the sickle `sickle`, the can `can`)
  (any other class there — the hands), `holds(inv, class)`, `held_of(inv, class)`.

**Interface**
- `Content.records(kind)`, `Content.find(kind, id)` (by a pointer `_at`, with no search),
  `Content.record_count()`, `Content.schema(kind)` (a kind's fields and the common ones), `Content.refs(kind)`
  (the reference fields, and the fields of records inside `entries` like `camp.item`), `Content.named(r,
  key)`, `Content.canon(kind, id)` (an old id from `was` — into the present one), `Content.origin(kind, id)`
  (who defined, replaced, patched), `Content.asset(rec, "sprites/x.png")` (the bundle, then the mod's
  `common/`), `Content.problems`, `Content.warnings` (names against the rules), `Content.loaded`,
  `Content.dropped[b]` (why it dropped), `Content.read_ms` / `load_ms` (how long the last reading of
  `content/` and the last loading of a set took: the line «Loading» in «Data for the test»).
- `Content.all_bundles()`, `available()`, `bundles_of(mod)` (from the scan of `content/`, not from disk: a new
  folder is seen by `refresh`), `mod_of(b)`, `deps(b)`, `closure(b)`, `resolve(set)` (Kahn's order: of the
  ready ones the one standing earlier in the scan goes first). `Content.generation` grows with each loading;
  `Mods.activate` rebuilds the registries if they were built from another loading (after a direct
  `Content.refresh`).
- `Mods.activate(bundles)` — make a world's set the current one and rebuild the registries; `Mods.rescan()` —
  reread `content/` (a button on «Testing»); `Mods.expand(list)` — old mod ids into bundles;
  `Mods.of_world(meta)` — a world's bundles by its `world.json`, with the supplementing ones that have
  entered since (decision 4А); `Mods.additive(b)` — a bundle has only items, recipes, eras, the start and
  sounds; `Mods.why(b, dropped)` — what a bundle lacks and what the one before it, switched off, lacks.
- The registries: `Mat.GRASS` and others (only the core), `Mat.of_role`, `Mat.index`, `Mat.remap`;
  `Items.get_item`, `with_prop`, `with_tool`, `tool_title` (the key of a tool class `[tool.<class>]`),
  `is_station`, `most_storage`, `of_category`, `fuel_in`, `canon`; `Crafting.get_recipe`, `canon`, `outputs`
  (what the work number n gives: the product and the by-product by chance), `possible` (each class of the
  recipe's tools has an item in the world; otherwise the recipe is not learned and not shown); `Trees.first`,
  `Trees.any`; `Bushes.first`; `Plants.of_kind`; `Biomes.pick`, `tree`, `bush`; `AiRules.SPECIES`, `is_food`,
  `is_threat`; `Starts.START` (`hand_*`, `bag`, `camp`); `Tools.HAND`.
- `ContentGraph.new()` — the graph of the set loaded now: `reached` (the key «kind/id» → depth), `how` (the
  path of this depth), `sources`, `uses`, `basis(key)` (what a thing is got from), `able(way)` / `by_hand(way)`
  (what does the path's action), `errors`, `warnings`, `findings` (the check, the text, the records),
  `cycles()`.

**Who uses it.** Almost everything: `materials.gd` and `items.gd` are loaded by over 40 files, `content.gd` —
about 20 (2026-11-05; the exact list — `python3 tools/doc_index.py uses <path>`). An edit of a schema or a
registry touches the generator, meshes, rules and UI.

**Data.** `content/<mod>/mod.yaml`, `content/<mod>/<bundle>/bundle.yaml`, `data/<kind>.yaml`. The meaning of
the fields is a comment at the start of each YAML and the schema in `content.gd`.

**How to add**
- A field: a row in `SCHEMAS[kind]` (type, `default`, `min`/`max`, `soft` for a soft reference; for a
  reference — the kind of link `rel` from `RELATIONS` and, if the link gives an action, `via` from `ACTIONS`,
  otherwise the test will not pass), reading in the registry, a comment in YAML, a check in
  `tests/unit/content_test.gd`.
- A kind of data: a schema in `SCHEMAS`, a new registry with `refresh()`, its call in
  `Mods._refresh_registries`, a check in `tools/validate.gd`; every reference field is a row in
  `ContentGraph.LINKS` (what this link means for the graph), otherwise `graph_test` will not pass.
- An item that a quest or trade gives, not the world or a recipe: `source: special`, otherwise the graph will
  say «no source».
- A bundle with ready roles is only data and assets, no code is needed (an example: `content/animals/sparrow/`).
- A bundle with only items, recipes, eras, the start and sounds will enter old worlds with its mod by itself
  (`Mods.of_world`); a new bundle that becomes supplementing is not appended to `OLD_ADDITIVE`: this list is
  what the worlds saved before the list `known` knew.

**What it costs.** The mods' data is read at the game's start, before the menu: parsing YAML (`read_ms`) and
loading the set (`load_ms`: dependencies, schemas, patches, references), the registries — a couple of
milliseconds. `tools/bench_content.gd [bundles]` measures this on the present data and with an invented mod
added. On a PC without a screen on 2026-10-30: 219 records — reading 41 ms, loading 14 ms, the graph 20 ms;
1019 records — 122, 64 and 275 ms (the graph is built only by the validator and reports). A phone's browser is
about ten times slower; what comes out on a phone is seen in «Data for the test». The search of a record by id
goes by a pointer: by search the loading of a thousand records took 105 ms. The parsed YAML is collected
beforehand: before every export CI runs `tools/content_cache.gd`, it puts into `res://content_cache.bin`
(`Content.PARSED`, not in git, into the export by `include_filter`) the values of all the files by the md5 of
their text; `Content._read` takes a file from there if its text has not changed, otherwise parses it as
before (in the editor and tests the file is absent). The bundle's `data/` files are learned by one listing of
the folder. In the container's browser on 2026-11-01 on 419 records the reading became 64 ms instead of 774
(`cached_files` / `parsed_files` — in «Loading»).

**Pitfalls**
- A record with the id of another's record without `replaces: true` is an error: another's cannot be silently
  replaced. A replacement is a whole record: the fields it does not write get default values, not taken from
  the replaced one.
- A static function named like a method of `Script` (`reload`, `get_class`, `is_tool`) is shadowed:
  `Mat.reload()` recompiles the script. Hence `Mods.rescan`, not `reload`.
- `const X := Mat.GRASS` is a parse error: the materials' numbers are known only after loading.
- The materials' numbers go in the order of loading: a world's set of bundles cannot be changed, an old world
  is converted by `Mat.remap` by the list `materials` from `world.json`.
- A reference without a namespace means the mod of the file where it is written: in a patch of another's
  record — the patch's mod (`Content._qualified` appends it before merging), not the record's mod.
- A return typed with one's own script (`-> VoxelModel`) without `class_name` is a parse error on which the
  `make_*` tools silently hang; `--check-only` first.
- The material atlas holds 63 materials and the different barks together (`PixelTextures.MOST_MATERIALS`: a
  material's number is 6 bits in the mesh, the sides' tile is a flag bit, the underside's by the normal, see
  `MeshFaces.pack`; the texture `material_data` of 64 texels for `world.gdshader`); 36 are used (28 materials and 8
  barks, 2026-11-05). More — fails `validate.gd`.

**Tests.** `tests/unit/content_test.gd` (`yaml`, `content`, `schemas` — the kind of link at every reference,
`mods` — and the chain of the cause of a dropped bundle, `old_worlds` — supplementing bundles and worlds of
the marks `content` 1–9, `parsed_cache` — parsed YAML from `content_cache.bin`, `records` — the common fields,
replacements, warnings, `renames` — `was` and the records' origin, `starts` — the start, its patch and the
fields of `entries`, `items`, `tools`, `crafting` — and a recipe without a tool in the world,
`recipe_mistakes` — the recipes' errors by id and field, `layers` — and the layers inside `src/shared/`),
`tests/unit/properties_test.gd` (the graph of recipes on random sets of bundles), `tests/unit/graph_test.gd`
(the graph: the full set with no errors, the depth of what is got with a tool, the spec's dead ends of
section 18 on the test mod's bundles, circles, twins, a profitable circle, a station instead of a station,
what a recipe holds in the bag, the classes of its tools and the by-product; the eras of the full set and of
the test mod: the derived era, an era earlier than the path, a long chain, two eras of one order),
`tests/unit/bundle_system_test.gd` (the acceptance of the bundle system: an example mod written by the README
— flax with two sources, a knife of a new class, a loom instead of a workbench, a recipe with a by-product
and a non-consumed one, an alternative by hands, an era — passes loading, the graph and the game; each bundle
alone), `tools/content_report.gd -- --check` (the reports are fresh), `tools/validate.gd` (each bundle
separately, the graph of the full set, sounds, pictures in hands, icons, textures, models, the creatures'
sheets; strict mode: a soft reference into the void is an error too; the warnings about names and the graph it
prints without failing), `tests/progress_test.gd` (all recipes are reachable by the game).

**Known problems.** The roles are closed lists (`plants.kind`, `materials.role`, `biomes.where`,
`biomes.zone`, `skills.role`), a new role needs code; the classes of tools and of 2×2 things (`items.tool`,
`items.prop`) have been open since stage 5а. The beasts' voices are synthesised by a table in
`tools/make_sounds.gd`, a bundle brings only ready `.wav`.

**In more detail.** `plan/architecture/modding.md`; decisions 140, 142, 143, 146 in `plan/README.md`; each
mod's README.
