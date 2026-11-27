# Crafting, stations and things on cells

Status: ACTIVE. A Russian copy: [crafting_RU.md](crafting_RU.md).

**Purpose.** Which recipes a character knows, the queue of work at a station, the wear and repair of tools;
the things that stand on cells and are not cells: chests, workbenches, furnaces, forges, campfires, ladders,
doors and windows.

**Where to look.** This page is the overview; the files and the detail are split by topic into `crafting/`: read
only the page the change reaches.

| Topic | Page |
|---|---|
| One character's crafting, recipes known, quality, the queue, the registry of recipes. | [crafting/workshop.md](crafting/workshop.md) |
| `placed.gd`, models of things, the crafting panel. | [crafting/placed.md](crafting/placed.md) |
| Stations by flags, the size and turn of a thing. | [crafting/stations-size.md](crafting/stations-size.md) |
| Moving and turning, furniture, the snowman, openings with the wall mended. | [crafting/furniture-openings.md](crafting/furniture-openings.md) |

**Data.** The recipes are the kind `recipes` in the bundles of tools, materials and plants: `makes`, `count`,
`also` (by-products: `item`, `count`, `chance`), `needs` (spent when the work gets into the queue), `keeps`
(needed in the bag while the work goes, not spent), `at` (the station), `tools` (classes of tools, one each in
the bag), `wear` (how many blows the product takes off the tool of each class), `process` (`craft`, `refine`,
`smelt`, `cook` — for reports), `time`; the fields and examples — section 6 of
[BUNDLE_SYSTEM.md](../specifications/BUNDLE_SYSTEM.md). A station is looked up by role (`Items.with_prop`), the
campfire's fuel — by `fuel` (`Items.fuel_in`, how long it burns — `Items.fuel_time`); the models —
`models/<model>.png`. Wear and repair are on by default (`Rules.tool_wear`, the switch «Tool wear» on
«Testing» turns it off; the tools' durabilities and the skill's care — `docs/balance/GAME_BALANCE_DESIGN.md`).

**Limits.** The solid parts of a thing `Placed.read_footprints` reads from its voxel model (the bundle's PNG)
at loading the mods, without the client; a thing without a model is solid as a crate (`CRATE_BOX`).

**Tests.** `tests/unit/content_test.gd` (`crafting`: the queue and the works' numbers),
`tests/unit/actions_test.gd` (`placed`, `stairs_placed`, `furniture` — furniture, a seat and keeping,
`snowman_melts` — melting, a save, what a snowman leaves,
`openings` — windows, doors 2×2 and 2×3, `move_openings` — a door and a window moved along a wall, the
remembered blocks, the bag and ghost blocks, turned where it stands, taken back, an old save's door,
and `tests/unit/fences_test.gd` — a fence, a wicket and gates, a
hatch, a ladder; a fireplace, `station_flags` — a station of another class that replaces a workbench and is
placed with a knife, a crate of 4 places, repair by a flag; `recipe_fields` — a mould in the bag is not spent
and holds the work, a knife wears per product and breaks, a by-product by chance from the work's number),
`tests/unit/character_test.gd` (`wear`), `tests/unit/quality_test.gd` (stacks, heaps, what is made,
durability, the harvest, old saves), `tests/progress_test.gd` (with an empty bag: gathers, places stations and
makes every recipe), `tests/unit/graph_test.gd` and `tools/validate.gd` (the graph: every recipe is reachable
from the start with the gathering tools, with no closed circles). What comes of what and at which station —
`docs/generated/content-graph.md`, all recipes by processes — `content-recipes.md`.

**In more detail.** `plan/design/crafting.md`, `plan/design/first-hours.md`, the mod's README
`content/tools/`.
