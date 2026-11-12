# Mod "Tools and crafting"

A Russian copy: [README_RU.md](README_RU.md).

Bags for the back (a wicker satchel +8 cells, a leather bag +16, a canvas backpack +24: `wear_on: back`,
`bag_slots`). Clothes of fiber made by hand (a wicker hat, a grass cape, leg wraps, bast shoes: `wear_on`
head/body/legs/feet and `warmth`, how many degrees warmer one is in it) and warm clothes of hides and leather, sewn
with a needle at the workbench (a fur hat, a fur coat, leather trousers, mukluks). A waterskin of leather: an empty one (`fills_to`)
is filled at fresh water, a full one (`drink`, `empties_to`) is drunk from. Bedding (a grass mat, a fur
sleeping bag: placed on the ground like stations, `prop: bed`; a touch lies down in it and sleeps, and then
`bedding` — in sleep one rests that many times faster). Farming: a hoe (stone, copper, iron;
`tool: hoe`, `area` cells per swing) digs grass and earth into a bed, a watering can (an empty one is filled at fresh
water, a full one is `tool: can`, `durability` waterings, `empties_to`) waters a bed, a sickle (`tool: sickle`) reaps
ripe crops from several beds per swing. Stone, wooden, copper, bronze, iron and steel axe, pickaxe, shovel, sword and scythe, torch and tar
torch, lantern, stations (workbench, kiln, forge, loom, potter's wheel, bloomery, anvil, chest), a clay pot and their recipes, a bundle per item: turn off the sword on the "New world" screen and there will be no swords in the world,
turn off the whole mod and the world is left with bare hands: one can dig soft ground, break branches and twist
a rope, but not chop trees or put things into a chest. Before, all this lay in core
(`content/core`), and the models of things on the ground and of stations were drawn by the client's code.

## What is in the folder

```
content/tools/
  mod.yaml                      id: tools, name, version, api
  axe/ pickaxe/ shovel/ sword/ knife/ spear/ sling/ leather_sling/ bow/ composite_bow/ needle/ scythe/ fishing_rod/ torch/ tar_torch/ lantern/
  candle/ workbench/ kiln/ forge/ loom/ potters_wheel/ drying_rack/ bloomery/ anvil/ chest/ big_chest/
  wicker_bag/ leather_bag/ canvas_backpack/
  hoe/ sickle/ watering_can/    farming: hoe, sickle, watering can
  boats/                        a raft (by hand from logs and rope) and a boat with oars (at the workbench): `vessel`, `oars`
  trap/                         a live trap (by hand from branches and rope): the bait in it calls an animal (`trap`), the caught one is a live item (`alive`)
  stairs/ door/ window/ furniture/ fireplace/   building: a staircase, doors 1×2, 2×2, 2×3, windows 1×1, 1×2, 2×1, 2×2, 3×2,
                                furniture (a table, a stool, a bed, a cupboard, a wide cupboard, a barrel, a rug), a fireplace
                                a bundle per item:
    bundle.yaml                 title
    data/items.yaml             the item(s): a tool (tool, power, swing, reach, durability, repair) or a station (prop)
    data/recipes.yaml           its recipes; the axe also has the planks of "Materials", the kiln has brick and charcoal, the forge a copper ingot,
                                the potter's wheel a raw pot and its firing in the kiln, the tar torch its own bundle (the plain torch
                                does not depend on cloth and tar)
    data/sounds.yaml            the sword has a swing (swish), the scythe has mowing (mow)
    data/starts.yaml            the chest has: a patch of core's start (camp+) — a chest at the spawn point of a new world
    sprites/held/<sprite>.png   how the tool lies in the character's hands (a sheet of frames, see the README of core)
    models/<model>.png          the voxel model of the item on the ground or of the station
    icons/<icon>.png            the picture in the bag
  README.md                     this file
```

## Models of things: PNG slices

A model is a picture of square slices in a row, one per level from bottom to top; a slice's width equals the
picture's height (16 for a thing on the ground, 16 for a station of 2×2 cells; each cell is 8 voxels).
A slice's pixel is a voxel in that place (x to the right, z down), the pixel's color is the voxel's color, transparent is
empty, semi-transparent (alpha 128) is foliage tinted by the season. For a thing on the ground the middle of the
slice is its center, for a station the slice's corner is the north-west corner of its cells, the front faces south. A model
can be drawn in any editor; any size will do as long as the slices are square.

The prototype's models are drawn by code (`tools/art/voxel_art.gd`) and written into the mods by the command
`godot --headless --path . --script res://tools/make_models.gd -- [model ...]` (without names —
all of them; a hand-drawn model is overwritten, so name what to redo).

## How it works

- The engine knows the work in the world of six `tool` classes (axe, pickaxe, shovel, sword, scythe, rod — a fishing rod: what is
  dug, chopped and fished with what is in `src/shared/content/tools.gd`); any other class (hammer) is for recipes and stations, in the world
  it is like hands. A knife (knife) in the world is also like hands, but, like a sword, it first strikes the animal in front of one (`Tools.hunts`; other hands only an animal at point-blank range),
  and in the bag it butchers carcasses (the "Butcher a carcass" recipe of the "Animals" mod asks for the class knife). A needle (needle) in the world
  does nothing, in the bag it sews leather (a leather sling). A strike at an animal
  takes the tool's `power` off it (hands — 1). A spear (spear), a sling (sling) and a bow (bow) with `range` (in cells)
  shoot: the action button — where the character looks, a touch on the ground — where it was touched; `ammo` is with what
  (one from the bag per shot; without it the weapon itself is thrown). What is shot lies where it fell. The item class `prop` is also an open word (workbench, kiln, forge, chest), and what the item does
  is told by flags: `storage: 16` — stores things (a chest), `repairs: true` — things are repaired at it (the workbench), `fire: true` —
  burns (the campfire; `fuel_max` is how many seconds of fuel fit in it, `fuel_start` how many a new one has,
  without them it burns forever), `serves` — replaces the named stations, `place_tool` — is placed with a tool of this class
  in the bag. A new station of another mod is data alone; with `serves: [tools:workbench]` everything that
  is done at the workbench is done at it.
- A recipe, besides what it spends (`needs`), can require an item in the bag without spending it (`keeps: {mould: 1}`),
  tool classes (`tools: [axe]`, as with planks: one of each in the bag) with wear per product
  (`wear: 1`), give a by-product with a chance (`also: [{item: chips, count: 1, chance: 0.5}]`) and name its
  work (`process`: `craft`, `refine` — planks, `smelt` — brick, charcoal, ingot, `cook`). All the recipes with
  these fields are in `docs/generated/content-recipes.md`.
- The chest at the spawn point is placed by the start of a new world (`content/core/data/starts.yaml`, the record
  `core:default`): the chest bundle appends it to the camp by the patch `camp+`. Turn off the chest and a new world
  will begin with one campfire.
- What a bundle needs is derived from the links of its recipes: `at: workbench` is the workbench bundle (without it
  a pickaxe cannot be made, and its bundle is turned off with the note "needs “Workbench”"), branch, log, flint,
  stone and clay are "Resources" (`resources:`), rope, planks and brick are "Materials" (`materials:`).
  The recipes of planks, brick, charcoal and ingot lie with the axe, kiln and forge, because they are made with them and at them;
  the flatbread of "Plants" is baked in the kiln, so the spikelet bundle requires the kiln bundle.
- Chains as in Terraria: raw material → material → item. Log → planks → wooden pickaxe, shovel, sword,
  scythe; flint and branch with rope → stone ones; clay → brick → forge; log → charcoal (kiln); copper
  ore (pickaxe) and charcoal → copper ingot (forge) → copper axe, pickaxe, shovel, sword and scythe from ingots
  and planks at the workbench (power 3, a faster swing, durability 300, repaired with an ingot); tin ore (copper
  pickaxe) → tin ingot, copper + tin in a crucible → bronze → bronze tools (power 4 — for iron
  ore, durability 500–550); iron ore (bronze pickaxe) → bloom (bloomery) → iron ingot
  (forge) → anvil (workbench) → iron tools at the anvil (power 5, durability 800); iron with
  charcoal in a crucible (bloomery) → steel → steel tools at the anvil (power 6, durability 1200);
  the recipes of tin, bronze, iron and steel are in "Materials", with the ingots themselves.
- A torch (`torch/`) is tied by hand from a branch and two fibers. In either hand it shines in the dark (the field
  `light` — by how many world units), keeps away animals that fear fire (`scares` — by how many
  world units; the same with the campfire, fireplace, candle and lantern), and is used up like food or fuel: in a stack (up to 5) they lie whole,
  one taken in hand burns for 6 minutes (`burns` — seconds; `durability` is not allowed on a shining item, it does not
  wear out and is not repaired), when burnt out it vanishes from the stack and the next one lights; one put away from the hand
  waits with what it has left (a bar on the hand, time in the bag; 20 s before the end of the last — "burning out");
  swimming, one holds it above the water; with the "Place" button in the bag it is put on the cell in front, where it
  burns its time out (a candle and a lantern likewise), a touch takes it back with what is left; two torches, one in each hand, shine farther and both burn; the fire burns at the brightest point of its sheet in the hand. Without a torch there is only a faint
  glow around the player at night.
- A new tool: its own folder with `bundle.yaml`, an entry in `data/items.yaml` with `tool`, `sprite` and
  `anim` (the character's work from `content/core/sprites/player.yaml`), a sheet `sprites/held/<sprite>.png`,
  a model `models/<model>.png`, a picture `icons/<icon>.png` and a recipe. The tool class is any word:
  `tool: knife` is a knife for recipes (`tools: [knife]`), in the world it is like hands; knives of different mods fit
  one recipe. In a world with no knife at all a recipe with a knife is not shown.
- A new station: an item with the class `prop` (`prop: loom`), flags (what it stores, whether it burns, whether things are repaired
  at it, which stations it replaces, with which tool it is placed), a model of 2×2 cells and a recipe, and
  the recipes made at it name it in `at`:

  ```yaml
  - id: loom
    title: "[tools.items.loom]"   # a key; "Loom" is in lang/en.yaml, the Russian one in lang/ru.yaml
    weight: 12
    stack: 1
    model: loom
    icon: loom
    prop: loom
    serves: [tools:workbench]   # optional: everything that is done at the workbench is done at it too
  ```
- A new recipe or a second way to the same item is one more entry of `data/recipes.yaml` (this is how
  alternatives are made, rather than exceptions in the code):

  ```yaml
  - id: cloth
    title: "[tools.recipes.cloth]"
    makes: cloth
    count: 1
    needs: {resources:fiber: 4}
    at: loom
    tools: [knife]                  # a tool class in the bag, one of each
    keeps: {mould: 1}               # in the bag, not spent
    wear: 1                         # the tools' wear per product
    also: [{item: resources:fiber, count: 1, chance: 0.25}]   # a by-product
    process: craft
    time: 4
  ```

  The era of the recipe and the item is derived by itself (the README of core, "How to add an era").
- The check: `godot --headless --path . --script res://tools/validate.gd` (fields, links, sheets and models
  in place, each bundle alone, the graph: everything reachable from the start, no dead ends and cycles),
  `tests/progress_test.gd` (all recipes reachable in a new world), the reports
  `godot --headless --path . --script res://tools/content_report.gd` (the recipe will appear in
  `docs/generated/content-recipes.md`).
