# The data model

Status: ACTIVE, checked against the code on 2026-11-09 (PR #457). The loader's code:
[systems/content.md](systems/content.md). A Russian copy: [DATA_MODEL_RU.md](DATA_MODEL_RU.md).

## What there already is and what there is not yet

**Implemented (PR #19, #161, #163–#178; the bundle system by decision 152 — PR #238–#248):** content is the
mods' data in YAML checked against schemas; a mod is a folder under `content/`, divided into **bundles**
(parts that can be switched on and off: each beast, plant, tool, station, biome); the bundles'
dependencies are derived from the records' references (hard and soft); a world remembers its set of
bundles; the «New world» → «Mods» screen switches mods and bundles on and off; patches of other
records; conversions of old saves.

**Not implemented:** mods' scripts, loading mods from outside `content/` (from a file or from a server),
giving mods to clients by a server, the editor, data for the weather and the generator. The bundle system
by the spec `bundles.md` (decision 152: kinds of links, the graph and the check of dead ends, wider
recipes, open stations and tools, the start and eras as data) is built; its rules are in
[specifications/BUNDLE_SYSTEM.md](specifications/BUNDLE_SYSTEM.md), here is a summary of what is in the
code. The word «bundle» means a part of a mod that can be switched; what the spec calls a bundle is a
record (an entity).

## Mods and bundles on disk

```
content/<mod>/mod.yaml            id, title, version, api (1), requires, wants
content/<mod>/README.md           how the mod is built (in Russian)
content/<mod>/<bundle>/bundle.yaml title, requires, wants
content/<mod>/<bundle>/data/<kind>.yaml   records
content/<mod>/<bundle>/{sprites,icons,models,textures,sounds}/   the bundle's assets
content/<mod>/common/             assets shared by the mod's bundles (Content.asset looks in the bundle, then here)
```

A mod with no bundle folders is one bundle named like the mod (`core`, `music`). A bundle's id is
`mod/bundle` (`animals/wolf`). The mods now (9 mods, 156 bundles; by name —
[generated/content-index.md](generated/content-index.md)): `core` (air, stone, water, soil, grass —
`Mat.KNOWN`; the campfire, rot, the human, the player's sprites, the start of a new world, eras, skills),
`resources` (7 bundles: wood, stone, soil, fibre, peat, salt, snow; cells of scree, sand, clay, peat, salt,
snow and ice), `materials` (20: copper, tin, bronze, iron, steel, silver, gold, platinum, coal, rope,
planks, brick, log wall, wattle, hewn stone, cloth, leather, resin, glass, bone glue; cells of planks,
brick, walls and ores), `tools` (40: tools, weapons, light, stations, chests, clothes and bags, a bed, a
boundary post, a ladder, a door, a window, furniture, a fireplace), `plants` (38: species of trees, shrubs,
grasses, flax, moss, mushrooms, roasted acorns; cells of log and leaves; `common/` — shared bark and
models), `animals` (18), `biomes` (28), `sounds` (nature, player, ui), `music` (notes).

## Records and ids

- A record is a dictionary with `id` and `title`; the id is `mod:name` (lower-case Latin letters, digits,
  `_`). A record in any bundle of a mod gets the mod's namespace: `wolf` in `animals/wolf` is
  `animals:wolf`; a reference with no namespace means the mod of the file where it is written (in a patch
  of another's record — the patch's mod). The loader adds the fields `mod` and `bundle` to records.
- A record with an id that another bundle already has replaces that one only with `replaces: true` (and
  loads after it); without it — an error. `patch: true` changes only the data of the fields; a key with `+`
  at the end (`diet+: [plants]`, `needs+: {materials:cord: 1}`) adds to a list or to amounts, including to
  the default value of an unwritten field. A patch of a record of a switched-off bundle is skipped.
- The meaning of the fields is described by a comment at the start of each YAML and by the schema `SCHEMAS`
  in `src/shared/content/content_schema.gd` (a part of `content.gd`; the types `bool`, `int`, `float`,
  `string`, `word` — a lower-case word, an open class: an item's `tool`, a station's `prop`, a mod may
  start its own, `color`, `vec3`, `enum`, `list`, `ref:<kind>`, `sound`, `amounts`, `shares`, `colors` —
  colours by the names of the keys `keys`, `entries` — a list of dictionaries with their own fields
  `fields`, each checked as a record: `camp: [{item: campfire, at: [-4, 4]}]`; `default`, `min` / `max`,
  `soft`). Every field that is a reference has a kind of link `rel` written (`Content.RELATIONS`: `drops`,
  `produces`, `consumes`, `requires_station`…) and, where the link gives an action, `via`
  (`Content.ACTIONS`: `dig`, `fell`, `gather`…): the content graph is built from them
  (`src/shared/content/content_graph.gd`). It goes from the start by the hands' rules and demands that
  every item and recipe be reachable and every plant grow somewhere; an item that a quest or trade gives is
  marked `source: special`. It also derives the era of every thing (the kind `eras`, section 9 of
  [specifications/BUNDLE_SYSTEM.md](specifications/BUNDLE_SYSTEM.md)): `era` is written at the item that
  opens a step; a thing with a written era earlier than the one in which it can be got is an error, a thing
  deeper than the `depth` of its era is a warning. The graph, the chains, the map of eras and what the
  checks found — [generated/content-graph.md](generated/content-graph.md),
  [generated/content-checks.md](generated/content-checks.md).
- The common fields of any record (`Content.COMMON`): `description` — the text for a player, `tags` — marks
  for reports and search, `provisional` — which numbers of the record are provisional (the names of its
  fields), `was` — the ids it had before: a save with an old id finds it (`Content.canon(kind, id)`, used by
  `Items.canon`, `Crafting.canon`, `Mat.remap`). An old id that a live record still bears, or named by two
  records, is an error.
- Where a record is from: `Content.origin(kind, id)` — the bundle where it is defined, who replaced it and
  who patched it; the registry of all records with categories, links and the result of the checks —
  [generated/content-index.md](generated/content-index.md) (`tools/content_report.gd`).
- Names against the rules (section 3 of [specifications/BUNDLE_SYSTEM.md](specifications/BUNDLE_SYSTEM.md):
  a recipe is named after the item or `<item>_from_<input>`, a tool `<material>_<thing>`, an ore
  `<metal>_ore`, a tag is a lower-case word) — warnings `Content.warnings`: the validator prints them but
  does not fail.

| Kind | Registry | What it describes | Now |
|---|---|---|---|
| `materials` | `materials.gd` (`Mat`) | cells: hardness (`hardness`, a gate by strength) and toughness (`toughness`, the time of a blow), roof, slopes, role, soil for the shader, what it gives and what digs it, the sounds of a step and a blow | 30 |
| `items` | `items.gd` | items: weight, stack, food, what it places, the tool class (`tool`), a weapon's range and projectile (`range`, `ammo`), the class of a thing on cells (`prop`; the square by the model's slice, 16 voxels — 2×2, 8 — one cell; placed facing the player) and its flags (`storage`, `fire`, `repairs`, `serves`, `place_tool`, `claims`, `steps` — the steps of a ladder, `door` — a door, `window` — a window, `fence` — a fence, with `door` a wicket or a gate, `hatch` — a hatch with `door`, `ladder` — a leaning ladder, `sign_lines`/`sign_width` — a sign: lines and signs in a line, `wall` — hung on a wall, `furniture` — furniture, not a station; `seat` — rest nearby is quicker, `keeps` — the share of the spoiling speed in storage), fuel, light, what is worn and where (`wear_on`: head, body, legs, feet, back) and how it looks on the figure (`look`) and how many cells a bag on the back gives (`bag_slots`), a raft or a boat (`vessel` — the share of a walking step on water, `oars` — what must be in the bag to row, `windage` — how the wind drifts it), a live trap (`trap` — to how many cells the bait in it calls beasts) and a beast caught in it (`alive`), how far fire scares beasts (`scares`), the sprite and animation in the hand, a special source (`source: special`), the era the item opens (`era`) | 217 |
| `recipes` | `crafting.gd` | what is made (`makes`, `count`) and what comes out on the side with a chance (`also`), what is spent (`needs`) and what must be in the bag without being spent (`keeps`), where (`at`), by which classes of tools (`tools`) and with what wear per product (`wear`), what kind of work it is (`process`: making, processing, smelting and firing, cooking), how much time | 162 |
| `creatures` | `ai_rules.gd`, `wildlife.gd` | mass, diet, speed, sight, hours of activity, flies / swims, a pack, a lair, favourite plants, biomes, voices, health (`health`) and a carcass (`carcass`) for hunting, a bite (`bite`) for attacks on people, a catch (`catch`) for fishing | 23 |
| `trees` | `trees.gd` | the shape of the trunk and crown, leaves, blossoming, bark, what felling gives | 20 |
| `bushes` | `bushes.gd` | the kind of shrub, berries, twigs, the item for planting | 6 |
| `plants` | `plants.gd` | plants on grass: the kind (`kind`), what they give when mown, where they grow, their own picture | 21 |
| `biomes` | `biomes.gd` | a climate window or relief, zone, top, the shares of trees and shrubs, chances, sand storms, the map's colour, shades of materials (`tints`) | 28 |
| `starts` | `starts.gd` | the start of a new world: the hands' abilities (`hand_power`, `hand_area`, `hand_swing`, `hand_reach`, `hand_mows`, `hand_slow`: `Tools.HAND`), the bag (`bag`) and a camp at the spawn point (`camp`: things with `prop` and a shift in cells); the engine takes `core:default`, bundles add to it by a patch (a chest) | 1 |
| `eras` | `eras.gd` | the eras of progress (in `core`): the order (`order`), to what depth to wait for the era's things (`depth`); a label that the graph checks, it forbids nothing in the game | 7 |
| `skills` | `skills.gd` | skills (decision 164): which work grows and speeds them (`role`: gather, chop, dig, craft, build, cook, hunt, fish, swim; the engine asks by role), the order in the window, the levels (`levels`), the points for the first (`first`) and the growth of the price (`growth`), the speedup at the last level (`speed`), points for a whole thing (`each`: a beast, a fish), the chance of an extra piece (`yield`), how much quality is added at the last level to what is gathered or to the ceiling of what is made (`quality`, points out of 100, decision 181), cheaper in strength (`effort`), care for the tool (`care`), an addition to the blow (`might`: hunting); the formulas — `docs/balance/GAME_BALANCE_DESIGN.md` | 10 |
| `sounds` | `content.gd`, `sound.gd` | a sound by name: variants, volume, loop | 56 |

## Bundle dependencies

- A reference to a record of another bundle (`needs: {materials:clay: 2}`) loads it earlier. A hard
  reference (the default) with no target in the set — the bundle drops out, the reason is in
  `Content.dropped[b]` (the screen shows «needs X»). A soft one (`soft: true`: the seed and log of a tree,
  the fruit of a shrub, a beast's favourite plants and biomes, what a plant gives, an item's repair, a
  material's bonus and mowing, an item's era) only sets the order: with no target the reference is removed,
  the game does without it (the validator in strict mode reports it all the same).
- `requires` (hard) and `wants` (only the order) in `mod.yaml` or `bundle.yaml` add what is not seen from
  the references. `Content.resolve` orders the set (the core first); roles do not link bundles; references
  to sounds do not either.

## Roles instead of ids

The engine asks for content by role, not by id: a tree and a shrub — by the shares of the column's biome
(`Biomes.tree`, `Biomes.bush`), some tree — `Trees.first(leaves)` (what the biomes grow most), a plant — by
`kind` (`Plants.of_kind`, empty — such a kind does not grow; `custom` — a plant with its own picture), a
station — by `prop` (`Items.with_prop`), a tool — by `tool`, a cell's material — by `role` (`Mat.BEACH`,
`BANK`, `SCREE`, `ORE`, `LOG`, `LEAVES`; -1 — there is none, the generator puts soil or stone), fuel — by
`fuel` (`Items.fuel_in`), what a tree or a shrub gives — by `log`, `twig`, `seed`, `fruit`. By id the code
names only the core's records (`Mat.GRASS`, `Placed.CAMPFIRE`). `items.tool` and `items.prop` are open
classes (the type `word`: a mod starts its own; the engine knows work in the world for six classes of
`Tools.WORLD_KINDS`, what a 2×2 thing does — by its flags); closed by the schema are `plants.kind` (11 kinds,
with the crop `crop`), `materials.role` (10), `biomes.where` (climate and 7 reliefs), `biomes.zone` (7 zones),
`skills.role` (9 works).

## Assets by convention

| Asset | Path in a bundle | Format | Who reads it |
|---|---|---|---|
| A material's texture | `textures/<id>.png` (bark — `textures/<bark>.png`) | 48×16: top, sides, bottom | `PixelTextures`, `Mat.texture_path` |
| A thing's model | `models/<model>.png` | a row of square slices by level, alpha 128 — a sheet | `VoxelModel.from_image` |
| An item's icon | `icons/<icon>.png` | 12×12 | `ItemIcons` |
| A creature's sprite | `sprites/creatures/<sprite>.png` | a row per side (`views`: 1 or 3), `frames` frames in a row (`walk` of them — a step, the last `hop` — hops of a flyer on the ground, after them `attack` — an attack) | `creatures.gd` |
| A plant's sprite | `sprites/plants/<sprite>.png` | frames 8×24 | `Foliage`, `Plants` |
| An item in the hand | `sprites/held/<sprite>.png` | a carrying frame + a frame of work each | `Figure` |
| A sound | `sounds/<name>.wav` or `<name>_N.wav` | wav | `Sound` |
| A translation | `lang/<code>.yaml` (and `content/<mod>/lang/`) | a dictionary «[key]: text»; a record's `title`/`description` are keys `[<mod>.<kind>.<id>]`, `….about` | `Lang` ([systems/lang.md](systems/lang.md)) |
| The player | `content/core/sprites/player/*.png`, `player.yaml`, `hands.png` | layers | `Figure` |
| Clothes on the figure | `sprites/worn/<look>.png` | a layer of the player's sheet | `Figure.dressed` |

The interface's pictures are `assets/ui/`. The assets are drawn by `tools/make_*` (see
[systems/testing.md](systems/testing.md)).

## Numbers during play

- A cell's material is a number in the order of loading (`core:air` = 0). So a world's set of bundles
  cannot be changed (only supplementing bundles, with no cells, enter an old world); the world stores the
  list `materials` and is converted by `Mat.remap`.
- The atlas: materials and different barks together are no more than 63 (`PixelTextures.MOST_MATERIALS`, 6
  bits of material in the mesh, a texel per material in the shader's `material_data`). 36 are used now: 28 materials and 8
  different barks.
- The registries are rebuilt by `Mods.activate(the world's set)` at the start of a world.

## Saves

`world.json`: `format` (1), `seed`, `settings` (the generator), `mods` (the world's bundles), `known` (all
the bundles there were at saving: a supplementing bundle the world did not know enters it,
`Mods.of_world`), `content` (the mark of the content's version, now 9), `materials` (ids in the order of
numbers), `levels`, `created`, `saved`, `played`, `sky` (the clock), `placed` (things on cells),
`territory` (plots), `plans` (blueprints); a server's world also has `teams`, `fights` and `next_player`.
`players/<name>.json`: `position` and the parts of modules (`inventory`, `vitals`, `character`,
`knowledge`, `crafting`, `skills`, `hands`, `markers`). Chunks are `chunks/<cx>_<cz>.bin`, the map is
`map/<rx>_<rz>.bin`. Conversions of old versions: [systems/saving.md](systems/saving.md).

**In more detail.** `plan/architecture/modding.md` (how mods are built; the history of the steps —
`plan/history/modding.md`), the mods' READMEs.
