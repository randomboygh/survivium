# Workshop, knowledge, quality, queue

Part of [Crafting, stations and things on cells](../crafting.md). One character's crafting, recipes known, quality, the queue, the registry of recipes.

- `src/shared/game/workshop.gd` — one character's crafting (`game.workshop`): `stations()`, `recipes()`,
  `why_not(r)`, `redye(i, dye)` (a thing of the bag dyed anew or washed at a dye vat near, see character.md), `start(r, times, dye)` (a dye picked in the «Краситель» row: `dye_why_not` — in the bag, a
  dye, the thing has `cloth`; one portion goes with each job's materials, `CraftQueue` job `dye`, and what is
  made is dyed, `Inventory.dye_of`), `cancel`, `update(delta)` (the finished and the by-product — into the bag,
  the wear of the recipe's tools by `wear`), `waits_for(r)` (what the work waits for: a station, a tool, a
  thing in the bag), `use_tool`, `repair`, `give_free(r)` (the test «Free items», `Rules.free_items`: the
  recipe's product into the bag without materials, the request `craft_free`; the crafting tab then shows all
  recipes and the button «Get» in the recipe's top right corner), `give_all()` (the switch turned on: one of
  every thing of the game into the bag, made wider for them by rows of 8 through `Inventory.grow`, the request
  `give_all [true]`) and `take_back_all()` (turned off: the bag back to its own slots, `give_all [false]`); the
  signals `changed`, `made`.
- `src/shared/game/knowledge.gd` — a recipe is known when all its materials have been in the bag (`look_at`,
  `knows`); the signal `learned`. A recipe that needs a tool of a class that no item in the world has (a world
  without part of the bundles) is not learned and not shown (`Crafting.possible`).
- `src/shared/game/quality.gd` — the quality of things (decision 181): a number 1–100 at a stack
  (`Inventory.quality`), 50 — as before quality. What is got by hands (`by_hand_of`: gathering, chopping,
  digging, hunting, wool, fishing) — from the strength and quality of the tool in the hand and the work's
  skill (`gathered`, a spread of ±5), the place does not matter; what is made — the mean quality of the
  materials `needs` (`of_materials` by the `took` of the queue's work), no better than the skill's ceiling
  (`skill_cap`: 50 without a skill, the skill's `quality` on top), of the best station near that does the
  recipe (`Workshop.quality_cap`, the item's field `quality_cap`: a campfire 70, a fireplace 90), and of the
  recipe (`quality_cap`: a wooden pickaxe and scythe — 30). What it gives: durability (`durability`,
  `Inventory.wear_tool`) and the warmth of clothes, the satiety, healing and water of food — `lasts` (×1.5 at
  100, ×0.6 at 10), the tempo of a stroke — `faster` (`tool_record`: `Player.tool`, `Controls.tool_record`). A
  crop stores the seed's quality as the fifth field of the bed, the harvest — near it (±8, `crop`), the
  Farming skill a little on top (`ActionsFarm.crop_quality`): better seeds give a better harvest. In the bag —
  a barely noticeable inner glow of the cell's background under the icon by grade: from the edges to the
  centre, smoothly fading, and the more noticeable the better the thing (`grade`: bad — reddish, plain —
  grey, ordinary — warm, good — greenish, excellent — golden; `HotbarSlot.grade`, `GRADE_TINTS`) and the chip
  «Quality» in the description (`FactChips.item_groups`, where durability, satiety and warmth are too — with
  quality).
- `src/shared/game/craft_queue.gd` — the queue: goes while the station is near; pause and cancel with a
  return; each work has its number (`serial`, saved), by it the by-products are decided.
- `src/shared/content/crafting.gd` — the registry of recipes: `get_recipe`, `missing` (what it spends and what
  it holds in the bag), `lacks_tool`, `why_not` («A tool is needed: …» by `Items.tool_title`), `take` (only
  `needs`), `outputs(r, n)` and `comes` (a by-product by chance from the work's number, with no random
  numbers), `canon` (old ids), `check` (each recipe's station is a station, wear only with a tool). Whether
  every recipe can be made from the start is decided by the content graph `content_graph.gd`
  ([content.md](../content.md)).
