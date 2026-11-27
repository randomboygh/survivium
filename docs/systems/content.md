# Mods, bundles and registries (code)

Status: ACTIVE. The data model (kinds, ids, roles, saves): [../DATA_MODEL.md](../DATA_MODEL.md). Here is the
code of the loader and the registries. A Russian copy: [content_RU.md](content_RU.md).

**Purpose.** To find mods and bundles under `content/`, to choose a world's set with dependencies, to read
YAML, to check records against schemas, to apply patches and to fill the registries through which the rest of
the code sees content.

**Where to look.** This page is the overview; the files and the detail are split by topic into `content/`: read
only the page the change reaches.

| Topic | Page |
|---|---|
| `content.gd` and the YAML parser. | [loader](./content/loader.md) |
| The set of bundles, the content graph, reports and the calls the rest of the code uses. | [mods-interface](./content/mods-interface.md) |

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
- A mod's file is read only through `Content` (`picture`, `sound`, `text`, `exists`, `file_exists`,
  `files_at`, `dirs_at`): on a server with other files its path `Content.ROOT/…` names a file kept elsewhere
  (`Content.real`), and `FileAccess` or `load` on the path itself would read the game's own file or nothing.
- A record with the id of another's record without `replaces: true` is an error: another's cannot be silently
  replaced. A replacement is a whole record: the fields it does not write get default values, not taken from
  the replaced one.
- A static function named like a method of `Script` (`reload`, `get_class`, `is_tool`) is shadowed:
  `Mat.reload()` recompiles the script. Hence `Mods.rescan`, not `reload`.
- `const X := Mat.GRASS` is a parse error: the materials' numbers are known only after loading.
- The materials' numbers go in the order of loading: a world's set of bundles cannot be changed, an old world
  is translated chunk by chunk by the orders kept in `world.json` `numberings` (materials, trees, bushes,
  biomes; `src/shared/world/numbering.gd`, see `docs/systems/saving.md`).
- A reference without a namespace means the mod of the file where it is written: in a patch of another's
  record — the patch's mod (`Content._qualified` appends it before merging), not the record's mod.
- A return typed with one's own script (`-> VoxelModel`) without `class_name` is a parse error on which the
  `make_*` tools silently hang; `--check-only` first.
- The material atlas holds 63 materials and the different barks together (`PixelTextures.MOST_MATERIALS`: a
  material's number is 6 bits in the mesh, the sides' tile is a flag bit, the underside's by the normal, see
  `MeshFaces.pack`; `uniform int material_bits[63]` in `world.gdshader`); 42 are used (34 materials and 8
  barks, 2026-11-16). More — fails `validate.gd`.

**Tests.** `tests/unit/editor_test.gd` (writing YAML back, one's own mods), `tests/unit/content_test.gd` (`yaml`, `content`, `schemas` — the kind of link at every reference,
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

**In more detail.** `plan/architecture/modding.md`; decisions 140, 142, 143, 146 in `plan/decisions.md`; each
mod's README.
