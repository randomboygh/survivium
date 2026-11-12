# The game's bundle system

Status: ACTIVE 2026-10-30, decision 152 (the user's answers 1А, 2В, 3А, 4А); built in stages 1–8 (PR
#238–#248), each section describes the code, the note «stage N» says by which stage it came. Checked against
the code and data on 2026-11-05 (PR #372): «Now» in the tables is what is in the data on that date. The spec is
`plan/history/tasks/bundles.md` in the project's library (ARCHIVED); the analysis of the spec, the audit of the
present data, the stages with files, checks and risks — `plan/architecture/bundle-system.md` there. How the
data is arranged now — [DATA_MODEL.md](../DATA_MODEL.md), the loader —
[systems/content.md](../systems/content.md). A Russian copy: [BUNDLE_SYSTEM_RU.md](BUNDLE_SYSTEM_RU.md).

The system is built by extending the present data model: mods, bundles, records by the `SCHEMAS`, the links and
dependencies from them stay, there is no second mechanism beside them. What the spec lacks is added: explicit
types of links, a graph with an exact check of dead ends, wider recipes, open stations and tools, the start and
the eras as data, reports from data.

## Stages

| Stage | What it adds | State |
|---|---|---|
| 1. Architecture | this document, decision 152 in the journal | done, PR #238 |
| 2. The data model | the shared fields `description`, `tags`, `provisional`; a type of link on every reference (`rel`, `via`); the explicit replacement `replaces`; warnings about names; a check of layers inside `src/shared/` | done, PR #239 |
| 3. The entity registry | a record's origin (`Content.origin`), renames as data (`was`), the report generator `tools/content_report.gd` and the entity registry, its freshness in CI | done, PR #240 |
| 4. Graph and checks | 4а: the start as data (the kind `starts`, the registry `Starts`: the bag and the camp of a new world, a chest — by the patch of its own bundle), the field type `entries` (nested records: the start's camp, later byproducts), the conditions of gathering as `Tools` functions (`can_chop`, `can_dig_out`, `can_knock`, `can_gather`), which the hands decide by too; 4б: the graph `content_graph.gd`, reachability with the gathering tools, depth, cycles, sources (`source: special`), warnings, the reports `content-graph.md` and `content-checks.md` | done: 4а — PR #241, 4б — PR #242 |
| 5. Recipes, stations, tools | 5а: the open classes `tool` and `prop` (the field type `word`), the station flags `storage`, `fire`, `repairs`, `serves`, `place_tool`, a tool class's name from data; 5б: the recipe fields `also`, `keeps`, `tools`, `wear`, `process`, the job's number in the queue, the recipe registry `content-recipes.md` | done: 5а — PR #243, 5б — PR #244 |
| 6. Eras | the kind `eras` and the registry `Eras` (eras 0–3 in `core`), the field `era` on the items that open a step, each thing's derived era in the graph, the error «era earlier than the path», the warning «long chain», the era in the registries, the map of eras with the branches of progress | done, PR #245 |
| 7. Integration | the hands and the graph on the same conditions; the hands' abilities in the start; supplementing bundles in old worlds; the whole chain of the reason on the «Mods» screen | done: 7а (old worlds, recipes with no tool, the chain of the reason) — PR #246, 7б (the hands' abilities in the start, the mods' READMEs) — PR #247 |
| 8. Acceptance | the scenarios «add with no code» on an example mod (`tests/unit/bundle_system_test.gd`), a measurement of data loading (`tools/bench_content.gd`, the line «Loading» in «Test data»), a lookup of a record by id with no scan | done, PR #248 |

Each stage is one or two PRs; after each, all the checks from `CLAUDE.md` pass, and the game does not change for
the player except what is approved (new lines of the crafting window, new recipes in old worlds). Content is
added after the system by eras, each with the user's consent.

## 1. Concepts and decisions

- **A mod** — a folder `content/<mod>/`; its id is the namespace of records.
- **A bundle** — a switchable part of a mod, a folder with `bundle.yaml` (`animals/wolf`); a world remembers its
  set of bundles. This is what the word means in the code, the saves and on the «Mods» screen, and stays so
  (**decision 1А**).
- **An entity** — what the spec calls a bundle: a data record with an `id`, a kind, a `title` (the key
  `[<mod>.<kind>.<id>]`) and the fields of its kind.
- **A link** — a record's field with a reference to another entity; the type of the link is written in the
  field's schema.
- **The graph** — the entities and links of the loaded set; built from data, not written by hand.
- **An era** — a step of progress from section 7 of the spec. There are no technologies and no research
  (**decision 2В**): recipes are learned by materials, as now, and the era is a label that the graph checks
  (section 9).
- Stations and tools are open classes and data flags; a new action in the world (butchering, ploughing,
  shooting) is added by code together with its mechanics (**decision 3А**, sections 7 and 8).
- A bundle that only supplements (items, recipes) enters an already created world by itself (**decision 4А**,
  section 14).

## 2. Storage

Unchanged:

```
content/<mod>/mod.yaml                      id, title, version, api, requires, wants
content/<mod>/<bundle>/bundle.yaml          title, requires, wants
content/<mod>/<bundle>/data/<kind>.yaml     entities
content/<mod>/<bundle>/{icons,models,sprites,textures,sounds}/
content/<mod>/lang/<code>.yaml, content/<mod>/<bundle>/lang/<code>.yaml   the keys' texts (docs/TRANSLATION.md)
content/<mod>/common/                       the mod's shared assets
```

A bundle is assembled around the main entity: an item, its recipes, its pictures (decisions 146 and 147: a
recipe lies with the station or tool it is made with). Nothing is moved. The new kinds `starts` (stage 4) and
`eras` (stage 6) lie in the same kind of files: `data/starts.yaml`, `data/eras.yaml`.

## 3. Ids and names

- An id is `mod:name`; the name is of lower-case Latin letters, digits and `_`, in English words. Inside one's
  own mod the prefix may be left out.
- An id is unique within a kind. The key of the shared registry is `kind/mod:name`: the item and the recipe of a
  stone axe are two entities with one id `tools:stone_axe` (already so now).
- Someone else's record can be replaced only explicitly: `replaces: true` (the whole record) or `patch: true`
  (some fields). A repeated id without that is a check error (stage 2).
- A rename is the field `was: [old ids]` in the record itself: old saves are converted with no code edit (stage
  3). The tables `Items.RENAMED`, `Crafting.RENAMED`, `Mat.RENAMED` stay for the conversions already made.

| What | The rule of the name | Examples |
|---|---|---|
| raw material | a noun; ore — `<metal>_ore` | `log`, `branch`, `fiber`, `clay`, `copper_ore` |
| a material | a noun or `<material>_<form>` | `planks`, `cord`, `brick`, `copper_bar` |
| a tool, weapon, armour | `<material>_<thing>`: `wooden_`, `stone_`, `copper_`… | `stone_axe`, `copper_sword` |
| a station | a noun; an improved one — `<feature>_<station>` | `workbench`, `kiln`, `forge` |
| a recipe | the item's id if it has one recipe; otherwise `<item>_from_<input>` | `stone_axe`, `charcoal_from_branch` |
| an era | one or two words | `primitive`, `bronze`, `iron` |
| a class of tool or station | one word | `axe`, `knife`, `hammer`, `loom` |
| a tag (`tags`) | a lower-case word | `primitive`, `metal` |

The names check only warns: the present ids do not change.

The spec's examples in our ids: `resource.fiber.plant` — `resources:fiber`; `resource.wood.log` —
`resources:log`; `resource.wood.plank` — `materials:planks`; `station.workbench.basic` — `tools:workbench`;
`world.tree.oak` — the tree `plants:oak`; `animal.boar` — the creature `animals:boar`; `tool.axe.stone` and
`recipe.tool.axe.stone` — the item and recipe `tools:stone_axe`.

## 4. Kinds of entities

| The spec's category | The record kind | Exists now (2026-11-05) | Not yet |
|---|---|---|---|
| A. World and environment | `materials` (cells), `trees`, `bushes`, `plants`, `biomes` | 28 cells: soils, stone, scree, peat, salt, snow, ice, the ores of six metals, walls; 20 species, 6 bushes, 14 plants, 28 biomes | — (the atlas holds 63 materials, 36 used) |
| B. Gathered resources | the `items` of the mod «Resources», the fruits and seeds of «Plants», the take from animals | twig, log, stone, flint, earth, sand, clay, fibre, peat, salt, snow, ice, ores; carcass, hide, bone | — |
| C. Processed materials | the `items` of the mod «Materials» | planks, rope, brick, charcoal, ingots of copper, tin, bronze, iron, steel, silver, gold, platinum, cloth, leather, resin, glass, bone glue | — |
| D. Tools | `items` with `tool` | axe, pickaxe, shovel, sword, scythe, knife, needle, rod, spear, sling, bow (wooden, stone, copper, bronze, iron, steel — by class) | — |
| E. Stations | `items` with `prop` | campfire, fireplace, workbench, kiln, forge, bloomery, anvil, loom, potter's wheel, drying rack; storages — chests, cupboards, a barrel | — |
| F. Plants and husbandry | `trees`, `bushes`, `plants`, the planting and sowing fields on items | sowing, planting bushes | crops' growth over time, trees from seeds |
| G. Animals | `creatures` | 22 kinds with behaviour from properties; hunting (`health`, `carcass`), fishing (`catch`) | animal husbandry |
| H. Food and medicine | `items` with `food`, `heal`, `drink`, `spoils`; cooking recipes | berries, mushrooms, meat, fish, flatbread, a bandage, water in vessels; spoilage | healing as a skill, a poultice |
| I. Clothes and armour, J. weapons and ammunition | `items` with `wear_on`, `warmth`, `look`, `bag_slots`; weapons — `range`, `ammo` | clothes by the body's slots, wearable bags; a spear, a sling, a bow | armour and damage to it |
| K. Building | block cells (`place`), things on cells (`prop` with the flags `steps`, `door`, `window`, `furniture`), the blueprint (`src/shared/game/plans.gd`) | walls, a floor, a stair, doors, windows, furniture, a fireplace (decision 163) | pitched roofs, gates, a hatch |
| L. Technologies | — | — | none (decision 2В); the steps of progress are the eras (stage 6) |
| M. Service | wear, repair, the queue, biomes, the start (`starts`, stage 4), skills (`skills`, decision 164) | exist | the drop table is a list inside a record |

The shared fields of all kinds (stage 2): `description` — a text for the player; `tags` — labels for reports and
search (they set no engine logic); `provisional` — which numbers of the record are preliminary (the spec,
sections 19 and 22). All three are optional; a report shows who lacks them.

An item's type is not written by hand: the category (tool, station, food, healing, planting, block, material)
is derived from the fields, as now (`Items.category`), and «raw or made» — from the graph (whether a recipe
makes it).

## 5. Links

The type of a link is written on every reference field in `SCHEMAS` (`rel`, the dictionary `Content.RELATIONS`)
and is read from the record that has the field to the record it names; where a link gives a hands' action, it
is written in `via` (`Content.ACTIONS`). The test does not let a reference with no type through (stage 2,
done).

| The spec's link | `rel` and `via` | Fields | Example |
|---|---|---|---|
| `harvests_into`, `drops` | `drops`: `dig`, `mow`, `fell`, `gather`, `dig_out` | `materials.item`, `bonus`, `mow_gives`; `plants.gives`; `trees.log`, `seed`, `twig`; `bushes.fruit`, `twig`, `item` | a spruce gives a log if felled with an axe |
| — (a change of state) | `becomes`: `mow` | `materials.mow` | mown grass becomes earth |
| `builds` | `builds`: `place` | `items.place` | a stone places a stone cell |
| `grows_from` (reverse) | `grows_into`: `plant`, `sow` | `items.plant`, `sow`, `crop` | a grain — into ears |
| `repairs` (reverse) | `repaired_with`: `repair` | `items.repair` | a stone axe is repaired with flint and rope |
| `feeds` (reverse) | `feeds_on` | `creatures.likes` | |
| `located_in`, `spawns_as` | `lives_in`; for a biome — `spawns` | `creatures.biomes`; `biomes.trees`, `bushes` | an oak grows in a forest |
| `produces` | `produces` | `recipes.makes` | |
| `consumes` | `consumes` | `recipes.needs` | |
| `requires_station` | `requires_station` | `recipes.at` | a stone axe — at a workbench |
| `requires_tool` | a class of tool, not a reference: in gathering — `materials.dig` and `hardness` with the hands' rules, in a recipe — `recipes.tools`, at a station — `items.place_tool` | | stone is dug by a pickaxe of strength 2, planks are made with an axe |
| not consumed | `requires` | `recipes.keeps` | a mould is needed in the bag and is not spent |
| a byproduct | `produces` | `recipes.also.item` | chips come out with the product |
| `replaces` (a station in place of a station) | `serves` | `items.serves` | an improved workbench does all a workbench does |
| `in_era` | `in_era` | `items.era` | a workbench opens the era of primitive tools |
| `crafted_by`, «where used» | a reverse walk of the graph, not stored | | |
| `unlocks` | none: a recipe is learned by the materials of `needs` (decision 9) | | |
| `ammo_for` (reverse) | `consumes` | `items.ammo` | a bow spends an arrow |
| `starts_with` | `starts_with` | `starts.bag`, `starts.camp.item` | a new world begins with a campfire |
| `equips`, `requires_power`, `powered_by` | entered in the dictionary, there are no reference fields (`wear_on` is a place on the body, not a reference) | | |

The conditions of gathering (which tool, what strength) the graph asks of the same functions the game plays by
(`Tools.can_dig` in `src/shared/content/tools.gd` and the like for chopping, digging out and gathering), and
does not rewrite them itself: the graph cannot diverge from the game.

## 6. Recipes (stage 5б, done)

```yaml
- id: stone_axe
  title: "[tools.recipes.stone_axe]"        # a shared field: a key, the text is in lang/<code>.yaml
  description: "[tools.recipes.stone_axe.about]"
  makes: stone_axe                           # the result
  count: 1
  also:                                      # byproducts, with a chance
    - {item: resources:chips, count: 1, chance: 0.5}
  needs: {resources:flint: 1, resources:branch: 2, materials:cord: 1}   # consumed
  keeps: {tools:mould: 1}                    # needed in the bag, not consumed
  at: workbench                              # the station; one that replaces it (serves) will do too
  tools: [knife]                             # classes of tools; it was a single field tool
  wear: 1                                    # the tool's wear per product, 0 — as now
  process: craft                             # craft, refine, smelt, cook — for the graph and reports
  time: 5
  provisional: [needs, time]                 # a shared field
```

The items `chips` and `mould` do not exist, they are here as an example.

- `needs` is always consumed (taken when the work is put in the queue), `keeps` and `tools` — never: they are
  checked while the work goes (`Workshop.waits_for`), the tool wears by `wear` per product when wear is on (the
  one in the bag first of its class).
- Alternative ingredients are a second recipe of the same result (`charcoal_from_branch`): explicit,
  checkable, seen in the crafting window. Groups like «any fuel» will come with the furnaces' fuel.
- An alternative station is the station's own field `serves`: an improved workbench with `serves: [workbench]`
  does all a workbench does, the recipes need no edit.
- The chance of a byproduct is computed deterministically from the job so that the server and the client
  agree: each job of the queue has its own number (`CraftQueue.serial`, saved with the player),
  `Crafting.comes` mixes the recipe's id, the job's number and the number of the `also` line into a number
  0..1 and compares it with the chance (`Crafting.outputs`).
- `process` (`craft` — making, `refine` — refining, `smelt` — smelting and firing, `cook` — cooking) sets
  nothing for the game; the recipe registry groups by it (who is in which process —
  [content-recipes.md](../generated/content-recipes.md)). A cooking recipe or one with an animal's carcass
  grows the skill Cooking or Hunting and gives a chance of an extra piece (`Workshop.yield_role`, decision
  164).
- The crafting window shows what is needed in the bag (in the hint «not consumed»), each class of tool with the
  wear per product and the byproducts with the chance. The graph counts `keeps` and `tools` as what the recipe
  requires, a byproduct as the recipe's product (the path `also`), in profitable circles — by its share;
  `Crafting.check` does not let `wear` without `tools` through.
- The opening of a recipe is as now, by materials (`knowledge.gd`); there are no fields `tech` and `unlock`
  (decision 2В).
- Quality (decision 181, `src/shared/game/quality.gd`): what is made gets the average quality of the `needs`
  materials, but not above the ceiling of the work's skill (Crafting or Cooking), of the station (the item's
  field `quality_cap`: a campfire 70, a fireplace 90, the rest 100) and of the recipe (`quality_cap`: a wooden
  pickaxe and scythe — 30).
- Fields with no mechanics (energy, a biome restriction, a skill as a recipe's condition) are not entered in
  advance: each will come with its own system, the type of link for it is already in the dictionary. Skills do
  not close recipes (decision 164, 5Б).

## 7. Stations (stage 5а, done)

A station is an item with `prop` that stores nothing and is not furniture (`Items.is_station`): it is placed
from the bag on a square of cells by the slice of its model (16 voxels — 2×2, 8 — one cell), facing the player
([systems/crafting.md](../systems/crafting.md), «Size and turn»). `prop` is an open word (the field type
`word`), the thing's class: the model and the solid parts are taken by it. A special behaviour is set by flags,
not by names:

| Flag | What it means | Now on |
|---|---|---|
| `storage: 16` | stores things; such a thing is not a station | a chest, a big chest, cupboards, a barrel |
| `fire: true` | burns, is put out, is lit with fuel (`fuel_max`, `fuel_start`), burns | a campfire, a fireplace (a hearth — with no burn) |
| `repairs: true` | tools are repaired at it | a workbench |
| `serves: [stations]` | replaces these stations (references to items): their recipes are made at it too, and repaired if repaired at them | a fireplace (a campfire) |
| `place_tool: hammer` | is placed only if a tool of this class is in the bag (the spec, section 6) | — |
| `claims: true` | the centre of the territory of whoever placed it and their team (`Territory`, [territory.md](../systems/territory.md)) | a boundary post |
| `steps`, `door`, `window`, `furniture`, `seat`, `keeps`, `bedding` | a stair, a door, a window, furniture (not a station), rest nearby faster, food in storage spoils slower, a bed (decisions 159, 163) | stairs, doors, windows, furniture, a bed |

The present stations got these flags, the behaviour did not change (`Placed`, `Workshop` ask the flags, nobody
names the classes by name except the conversion of old saves). A flag on an item with no `prop`, `serves` not on
a station, `place_tool` of a class that no item is — are `Items.check` errors; the graph knows that a station
with `serves` replaces those named, and `place_tool` is needed to place it. A new station (a drying rack, a
tanning rack, a loom, an anvil — they were made so) is only data: an item, a model, an icon, the recipe of the
station itself and the recipes at it. A station's solid parts are taken by its model. Fuel exists for a
campfire and a fireplace (the fuel's field `fuel`, `Items.fuel_in`); the furnaces' fuel and energy are the
mechanics of the content's eras.

## 8. Tools (stage 5а, done)

An item's `tool` is an open class (the field type `word`). The engine knows the work of six classes in the
world: `axe` chops trees and bushes and digs wooden cells, `pickaxe` — stone and ore by hardness, `shovel` —
soil and digs bushes out, `sword` — knocks berries down and cuts tall grass, `scythe` — mows in an arc, `rod` —
fishes (decision 154). Ranged weapons (a spear, a sling, a bow) are items with `range` and `ammo`, they hit
animals ([systems/wildlife.md](../systems/wildlife.md)). An unknown class (`knife`, `hammer`, `saw`, `needle`)
works in the world as hands (`Tools.of` gives hands, `Tools.WORLD_KINDS` — the nine known) and does not wear
there, and in recipes and at stations (`place_tool`) it is a requirement. A new action in the world is code
together with its mechanics; the class is already ready for it. The class's name in the hint «A tool is needed:
…» is taken from data (`Items.tool_title`): the key `[tool.<class>]`, its texts are in `content/core/lang/`, and
a mod's class in the `lang/` of that mod (decision 186); `Crafting.TOOL_NAMES` is gone.

Strength is how much durability a blow takes (a tree's `hits`, an animal's `health`); for cells `hardness` is a
gate (strength not less), `toughness` is the durability by which a weak tool's blow lasts longer
(`Tools.swing_time`); the swing speed, durability and repair are the item's fields; a skill changes the hand,
not the tool (`docs/balance/GAME_BALANCE_DESIGN.md`). The matrix «tool × object → what it gives» (result 7 of
the spec) is built by a report by the same rules, the tables of time and blows — `tools/balance_report.gd`.

## 9. The opening of recipes and eras (stage 6, decision 2В, done)

There are no technologies and no research. A recipe is learned as now: when all its materials have been in the
bag (decision 9). The spec's «opening through an item» is exactly the present rule; opening by an event will
come with its own mechanics, if needed.

An era is a landmark, not a lock: in the game it forbids nothing, progress is set by the chains themselves (of
what, with which tool, at which station). Eras are needed by data — by the check and the reports, where the
spec speaks of a «technological level» and a «technology tree».

- The kind `eras` (in `core`, `content/core/data/eras.yaml`; the registry `src/shared/content/eras.gd`): `id`,
  `title`, `description`, `order` (0, 1, 2…; two eras of one order are an `Eras.check` error), `depth` — within
  how many steps of making from the start the era's things are to be expected (0 — do not check; the numbers
  are preliminary, `provisional`).
- The field `era` (a soft reference to an era, the link `in_era`) is written on an item where the thing opens a
  step: a station, the first tool of a new material, a new material. For the rest the era is derived by the
  graph.
- The derived era (`ContentGraph.era`, by the same pass over paths as the depth): a recipe — the greatest of the
  eras of everything it requires (`needs`, `keeps`, `at`, `tools`); gathering from the world — the era of the
  earliest tool that can do it (by hands — the first); what the start places — the first; an item — the least of
  the eras of its sources, but not below the written `era`.
- The **error** `early_era`: the written era is lower than the one the paths to the item give («a thing of era 1
  requires a thing of era 3»); the message names what exactly holds it back.
- The **warning** `long_chain`: a thing deeper than its era's `depth` — a long chain for an early step (the
  spec, section 19).
- The report «Map of eras» in `docs/generated/content-graph.md` (in place of the technology tree, result 8 of
  the spec): by eras — what opens it (the written `era`) and what appears in it by kinds of items, and the
  scheme «Branches»: tools, stations and opening things by eras with arrows from what each comes directly out
  of. The era of items and recipes is in the registries `content-index.md` and `content-recipes.md`.

| Order | Id | Title (`title`) | `depth` |
|---|---|---|---|
| 0 | `foraging` | Survival without tools | 2 |
| 1 | `primitive` | Primitive tools | 6 |
| 2 | `bone_leather` | Wood, bone and leather | 8 |
| 3 | `bronze` | Pottery and early metalworking | 10 |
| 4 | `alloy` | Bronze | 13 |
| 5 | `iron` | Iron | 14 |
| 6 | `steel` | Steel | 15 |

The records are `content/core/data/eras.yaml` (2026-11-05: seven eras, 0–6). What opens each (in bold) and what
appears in it — the «Map of eras» in [content-graph.md](../generated/content-graph.md), written by
`tools/content_report.gd`, so the table here does not repeat the content. The steps of section 7 of the spec
after steel (gunpowder, electricity) have no records: they will appear with their own content, if the user
approves them. The marking can be corrected by one line `era` on an item.

## 10. Processes (section 5 of the spec)

| Process | The rule (code) | Data | Now |
|---|---|---|---|
| gathering | `src/shared/game/world_actions.gd`, `tools.gd`: dig, chop, fell, mow, gather, dig a bush out | the fields of materials, trees, bushes, plants | exists |
| hand crafting | `src/shared/game/workshop.gd` | a recipe with no `at` | exists |
| station production | `workshop.gd`, `src/shared/game/placed.gd` | a recipe with `at` | exists |
| smelting and firing | the same | `process: smelt` | exists, without the furnaces' fuel |
| building | `world_actions.place_at` (blocks), `placed.put_from_bag` (things), `plans.gd` (the blueprint) | `place`, `prop`, `place_tool`, `steps`, `door`, `window`, `furniture` | exists (decision 163); no roofs, gates and hatch |
| hunting and fishing | `src/shared/game/wildlife.gd`, `fishing.gd` | `health`, `carcass`, `catch`, `range`, `ammo` | exists |
| growing | `world_actions.plant` | `plant`, `sow`, `crop` | bushes and sowing exist, trees from seeds — no |
| animal husbandry | — | — | mechanics later |
| cooking | a recipe at a campfire or furnace | `process: cook` | exists |
| research | — | — | none (decision 2В) |
| repair | `workshop.repair` | `repair`, the flag `repairs` | exists |

Each process is its own rule in `src/shared/game/` with its own fields; the only thing they share is the graph.
If a plant and an animal come to have a common mechanic (for example, «gather a product once a season»), it is
moved into one rule and not copied into every record (section 12 of the spec).

## 11. The graph, the start and the checks (stage 4)

The module `content_graph.gd` in `src/shared/content/` (shared: the server checks mods with it too;
`ContentGraph.new()` builds the graph of the set loaded now):

- **nodes** — all the set's records, the classes of tools and stations, «hands»;
- **edges** — from the fields by the `rel` marks; the conditions of gathering are the `Tools` functions
  (`can_dig`, `can_chop`, `can_dig_out`, `can_gather`, `mows`), which the hands in `world_actions.gd` decide
  by too;
- **the start** — a record of the kind `starts` (`core:default`, the registry `Starts`): the bag (`bag`), the
  camp at the spawn (`camp`: a campfire; a chest is added by its bundle by the patch `camp+`) and the hands'
  abilities (`hand_power`, `hand_area`, `hand_swing`, `hand_reach`, `hand_mows`, `hand_slow`: `Tools.HAND`,
  stage 7б). A new world begins by the same record (`Placed.start_camp`, `Character.start_bag`), so the check
  and the game begin the same;
- **analysis** — reachability from the start with the gathering tools and stations; cycles (strongly
  connected components; a blocking one is one that cannot be entered from outside); the sources and consumers
  of each entity; depth and era; chains from raw material to product.

How the graph goes (done, stage 4б). The world gives all the biomes, the cells the generator lays (of the core
and of the roles; a trunk and a crown are a tree, it is chopped), a plant of each kind and the plants with a
picture of their own, the creatures with no biomes; a biome gives its trees (if the set has the roles of trunk
and crown) and bushes. An action on a world record gives the things of its fields with `via`, if a tool that
is already there can do it by the `Tools` rules (hands are always in the bag). A recipe is made when its
materials are there, a placed station (`placed/<item>`: an item with `prop` exists — it can be placed) and a
tool of the needed class; what is placed, planted and sown gives its cell, bush or plant. And so to a fixed
point. The depth: what the world and the start give by hands — 0, what is gathered by a tool — the depth of the
earliest tool that can do it, a product — 1 more than the deepest of the recipe's materials, station and tool.
Each reference field is written in `ContentGraph.LINKS` (what this link means for the graph): a new field with
no line there breaks `graph_test`.

Errors (they fail CI):

1. Unreachable from the start in the full set of bundles: an item, a recipe; a station or a class of tool that
   is referred to. The message names each path and what it lacks.
2. A blocking cycle. Repair, refining and reversible transformations are allowed: a cycle is looked for only
   among the unreachable (what lacks what), so a circle through reachable things blocks nothing.
3. An item has no source: no world, no recipe, no start. A special source (a quest, a purchase) is written
   explicitly: `source: special`.
4. The class of tool in a recipe belongs to no item; the recipe's station is not a station
   (`Crafting.check`).
5. A plant, bush or tree does not grow in the world: no biome grows it, it is not planted and not sown (or
   what it is planted with cannot be got); an animal has nothing growing that it eats (`likes`).
6. The written era is lower than the derived one (stage 6).
7. A silent repeat of an id (stage 2). The schema and broken references — as now.

Warnings (into the report, they do not fail CI): a dead-end thing (no recipe spends it, and it is needed for
nothing: now these are an acorn and a cone), a station with one recipe, two things with the same properties and
purpose, a refining cycle with profit (infinite resources; the other materials of a circle's recipes are not
counted), a cell that is not met in the world, a long chain for an early era (stage 6), a tag met once (a
probable typo, stage 2: `Content.warnings`). Each finding of the graph keeps the check and the records it is
about (`findings`): the registry sets the record's check result from them, and `content-checks.md` — a summary
with how to fix.

A world with part of the bundles (stage 7а, done): a recipe that needs a tool of a class that no item of the
world has is not learned and not shown (`Crafting.possible`; a recipe with a knife in a world without the
knife's bundle). A recipe's station is always in the world: `at` is a hard reference, without the station's
bundle the recipe's bundle drops out too. The check of each bundle on its own (already in `tools/validate.gd`)
sees to it that a world without other bundles works. The former `Crafting.reachable` counted a log, a stone and
ore as reachable without an axe and a pickaxe; since stage 4 it is gone, the validator goes through the graph,
and `tests/progress_test.gd` stays the check by playing.

## 12. Loading and registration

The order is as before: `Content` reads the bundles, `resolve` orders them and switches off the ones lacking
dependencies, the records are checked by the schema, patches are applied, references are checked, the
registries are filled in `Mods._refresh_registries` (since stage 4 the start's registry `Starts` too). The
graph is built only by the validator, the reports and the tests: the game on a phone does not need it, and
loading a world does not get dearer. The eras are needed only by the graph and the reports, they have no
registry in the game. A new kind of data is added as now: a schema in `SCHEMAS`, a registry with `refresh()`
(if the game needs the kind), a line in `_refresh_registries`, a check in `tools/validate.gd`.

What it costs (stage 8, `tools/bench_content.gd`, a PC with no screen): the 219 records of the present mods are
read in 41 ms and loaded in 14 ms; with an invented mod of 800 records (1019 in all) — 122 and 64 ms, that is,
it grows linearly, there is room for hundreds of records of the eras. A record's lookup by id is now by
pointer (by a scan a thousand records loaded in 105 ms). A phone is about ten times slower; its numbers are the
line «Loading» in «Test data» (`Content.read_ms`, `load_ms`). Since 2026-11-01 (the cold start, decision 155)
the parsed YAML is collected at export into `content_cache.bin` (`tools/content_cache.gd`, `Content.PARSED`),
and the build does not parse YAML on a phone ([systems/content.md](../systems/content.md), «What it costs»).

## 13. Reports from data (stages 3–6)

The generator `content_report.gd` in `tools/` writes reports from the loaded data into `docs/generated/`; CI
checks that they are fresh, like `code-index.md`:

- `content-index.md` — the entity registry: id, title, kind, category, era, sources, the number of links, the
  check's status (result 2 of the spec; replaces the present list of the same name that `tools/doc_index.py`
  writes, so that there are not two generators of one file; the era — since stage 6);
- `content-recipes.md` — the recipe registry by processes: what it makes and what by the way, what it spends
  and what is needed in the bag, the station and those that replace it, the tools with wear, the time, the
  depth, the era, the alternatives (result 3; done at stage 5б, the era — at stage 6);
- `content-graph.md` — the start, the items by depth, where each item comes from and goes to, the shared
  resources and what rests on them, what is gathered with what, the stations, the chains from raw material to
  product, the map of eras with the branches of progress, the mermaid scheme of recipes (results 4–8; done at
  stage 4, the map of eras — at stage 6);
- `content-checks.md` — the summary of the checks (what each finds, how to fix, how many found) and every
  finding (result 9; done at stage 4).

## 14. Old worlds and supplementing bundles (stage 7а, decision 4А, done)

A supplementing bundle is one that has only items, recipes, eras, the start and sounds (no cells, trees,
bushes, plants, biomes, animals; `Mods.additive`, by its records and by its patches). It enters an old world by
itself, where its mod is on, if the world has not seen it yet and the world has everything it needs:
`world.json` remembers (`known`) which bundles existed when it was saved, so a bundle switched off by the
player stays off. A world saved before `known` knew the supplementing bundles of the list `Mods.OLD_ADDITIVE`
(the torch — from the `content` mark 9). The ground and the numbers of materials do not change. There is no
hand-kept list in `src/client/save_game.gd` any more: the world's set by its `world.json` is decided by the
shared `Mods.of_world` (the server opens worlds with it too). A bundle with cells, trees or animals does not
enter an old world: it changes the ground and the numbers of materials.

A bundle that dropped out of a new world's set shows the whole reason on the «Mods» screen in a line under it:
for a workbench without fibre — «needs «Wood», and it needs «Fibre»» (`Mods.why`: what lacks it, what lacks
that one, down to the switched-off one).

## 15. What is added with no edit of the engine

| Add | How | Code |
|---|---|---|
| a new resource and its sources | an item + a field at the source (`gives`, `log`, `bonus`…) | no |
| one more source of an old resource | a field at the new object with a reference to the same id | no |
| a tool of a new class for recipes | an item with `tool: knife`, recipes with `tools: [knife]` | no |
| a station | an item with `prop` and flags, a model, an icon, recipes with `at` | no |
| a non-consumed item, a byproduct | `keeps`, `also` of a recipe | no |
| a recipe, an alternative recipe | a `recipes` record | no |
| a plant, bush, tree, animal with ready roles | a bundle with data and pictures | no |
| an era | an `eras` record, `era` on the things that open it | no |
| the start and the hands' abilities | a patch of the record `core:default`: `bag+`, `camp+`, `hand_*` | no |
| a new action in the world (butchering, ploughing, shooting, putting on) | a rule + a schema field | yes, with the mechanics |
| a new cell (ore, gravel) | a `materials` record with a texture; ore — `role: ore` and the share of veins `veins` | no (the atlas holds 63, 36 used) |

That the lines «with no code» really are added by data alone is checked by the acceptance test
`tests/unit/bundle_system_test.gd` (stage 8): the example mod «Flax» and «Loom», written by the READMEs — a new
resource and a seed with two sources (a bush: pluck by hand, dig out with a shovel; a byproduct in scutching),
one more source of the old fibre, a bush on a meadow by a biome patch, a knife of a new class, a station that
replaces the workbench, a recipe with a non-consumed shuttle, the knife's wear and a byproduct, an alternative
by hands, the era «Weaving», a start patch (fibre in the bag, the hands reach farther) — loads with no errors,
the graph reaches everything from the start and derives the eras, and in the game flax is pulled, scutched,
woven at the station, and at the station the workbench's recipe is made. Each bundle of the mod loads alone,
and without the workbench the station's bundle drops out with a reason. Trees and animals with ready roles are
checked by the bundles of the mods themselves (`validate.gd`: each bundle alone).

Step by step and with YAML examples (stage 7б): `content/core/README.md` — the start, the hands' abilities, an
era; `content/tools/README.md` — a tool of a new class, a station, a recipe and an alternative;
`content/resources/README.md` — a resource and one more source of an old resource.

## 16. Quality rules

1. **Compatibility.** Old saves open (`tests/save_test.gd`), the game is passed by the same way
   (`tests/progress_test.gd`); what the player sees changes only with the user's consent.
2. **No duplicates.** The new is built on the present mechanisms (kinds, schemas, references, patches, roles); a
   new mechanism only if the present does not fit, with a decision in the journal.
3. **One format.** Ids and names — by section 3; a reference is always by id, with the type of link in the
   schema.
4. **No dead ends and cycles.** Since stage 4 the graph checks every PR: everything is reachable from the start,
   there are no blocking cycles.
5. **References are checked.** The schema, broken references, the type of link on every reference, silent
   repeats — are errors.
6. **The game's data is not in code.** Numbers, lists and names of content live in YAML; the engine knows
   classes and flags, and by id names only the core's records.
7. **Extensibility and balance.** Preliminary numbers are marked `provisional`; balance is an edit of data; an
   alternative is one more recipe, not an exception in code.
8. **Decisions are written.** The journal `plan/README.md`, [DECISIONS.md](../DECISIONS.md), this document and
   the table of stages are updated in the same PR as the code.
9. **Tests after each stage.** All the checks from `CLAUDE.md` (since stage 3 also the freshness of the
   reports) and a new test that fails without the new code.

## 17. What the system does not do

- Technologies, points and a research tree (decision 2В).
- Scripts and rules in data: a new action in the world is code together with its mechanics (decision 3А).
- The mechanics of furnaces' fuel, energy, armour, animal husbandry: they come with their own eras of content
  (hunting, clothes, damage, shooting and several ores already exist).
- Mass content: the catalogue of an era is first approved by the user, then its bundles and recipes.
