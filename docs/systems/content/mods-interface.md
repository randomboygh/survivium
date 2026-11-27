# Mods, graph, reports, interface

Part of [Mods, bundles and registries (code)](../content.md). The set of bundles, the content graph, reports and the calls the rest of the code uses.

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
- `Content.records_of(kind, bundles)` — records of a set not loaded (the loaded ones of it as they are, the others read from their files with defaults, no patches; the registries untouched: the map of «New world» by `Biomes.refresh(only)`), `Content.records(kind)`, `Content.find(kind, id)` (by a pointer `_at`, with no search),
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
  entered since (decision 4А); `Mods.missing(meta)` — what it lists that is not here (such a world is not
  opened, [saving.md](../saving.md)); `Mods.additive(b)` — a bundle has only items, recipes, eras, the start and
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
