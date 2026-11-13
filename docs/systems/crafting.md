# Crafting, stations and things on cells

Status: ACTIVE. A Russian copy: [crafting_RU.md](crafting_RU.md).

**Purpose.** Which recipes a character knows, the queue of work at a station, the wear and repair of tools;
the things that stand on cells and are not cells: chests, workbenches, furnaces, forges, campfires, ladders,
doors and windows.

**Files**
- `src/shared/game/workshop.gd` — one character's crafting (`game.workshop`): `stations()`, `recipes()`,
  `why_not(r)`, `start(r, times)`, `cancel`, `update(delta)` (the finished and the by-product — into the bag,
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
  ([content.md](content.md)).
- `src/shared/game/placed.gd` — things on cells by the item's class `prop` and its flags (below):
  `put_from_bag`, `take_up`, `put_out`, `light`, `feed`, `destroy`, `stations_near`, `burns`; a campfire burns
  on fuel: a record's `fuel` is the seconds of burning (no more than the item's `fuel_max`, a new one is
  placed with `fuel_start`, 0 — burns for ever), `feed` and `light` put one fuel from the bag (`fuel_for`: the
  shortest — a twig before a log; the seconds — the fuel's `fuel_time`), `step(delta, rain)` in the session's
  step burns it and puts out a burnt-down one, and under the open sky (`WorldData.roof_level`) — after
  `RAIN_OUT` seconds of a downpour or storm (`RAIN_HEAVY`, the count `wet`); an extinguished one keeps the
  remainder. The copies learn the remainder by the signal `fuel_changed` (the request `prop_fire` with `true`
  lights or adds, the event `prop_fuel` once per `FUEL_TELL` seconds of burning). A tap on a campfire opens it
  as a station; how much is left is seen by the fire itself: `Effects.fire_strength` by `fuel_share` (by the
  root of the share: one just lit is already lively) — a full one burns wide, high and very bright, with
  sparks and far light, one burning down — low dim tongues and short light (`Props` by `fuel_changed`); the
  «Crafting» tab at a campfire — the button «Add fuel» beside «Put out»/«Light», with a strip of the reserve
  below (`CraftPanel._draw_fuel`; unavailable at a burnt-out one, a full one or with no fuel in the bag, in
  the hint — how much longer to burn); solid through `WorldData.blockers`; a new world starts with the start
  camp at the spawn (`start_camp` by `Starts.START.camp`: a campfire, a chest — the patch of the chest's
  bundle; an occupied place — a tree, a slope, water — is replaced by the nearest level free one within
  `CAMP_REACH` cells, `camp_spot`: first at the spawn's level, then within `CAMP_RISE` levels, then at any;
  first only under the open sky, nothing `CAMP_SKY` levels over it or along the view's line south of it,
  `_open_above`, so no crown hides it).
  The button «Give tools» («Testing») gives `Items.best_kit`: the best tool of each class, light and the
  biggest bag for the back, put on at once. The signals `added`, `removed`, `lit_changed`, `fuel_changed`,
  `cell_changed`. Light (an item with `light` without `prop`: a torch, a candle, a lantern) is placed on one
  cell before oneself (`lights`, `put_light_from_bag`, `light_spot`, `take_light`; the button «Place» in the
  bag, the request `light_put`): not solid, burns down its `burns` seconds in place (`step`, the session's
  step), and one taken back by a tap carries the burnt part away into `Character.burning`; it goes out and
  vanishes if the cell was occupied or the ground under it was dug. The lights' records are in the same
  `to_list` and the signals `added`/`removed`, marked `light`.
- Signs (decision 183, the bundle `tools/signs`: a sign, a pointer, a board for a wall) — things with
  `sign_lines`: the text in the record (`text`, lines through `\n`; `Placed.sign_text` cleans each like
  `Protocol.clean_text` and cuts to `sign_lines` lines by `sign_width` characters), `write` and `turn_sign` (a
  quarter turn; a board on a wall is not turned) — by the right «build», the requests `sign_write`,
  `sign_turn`; a changed sign is placed anew (`_renew`: `removed`, `added`), so the copies and the save get it
  as an ordinary thing. A board (`wall`) is placed only at a wall (`ON_WALL`: a solid cell next to it at the
  same level) with its back to it (`wall_turn`). A taken sign carries the inscription away: `Placed.take_up`
  puts it into a bag cell as the sixth field (`Inventory.text_of`, `[id, n, worn, null, q, text]`), such a
  stack combines only with the same inscription, is not mixed in sorting, is saved, lies on the ground
  (`drop_data` with `text`) and in a chest; `_set_down` places the sign with this inscription. In the bag
  window the name has «· with an inscription». A tap on a sign opens the window `src/client/ui/sign_window.gd`
  (the line fields, «Save», «Turn», «Close»; without the right to build — only the text), the text above a
  sign is drawn by `src/client/view/sign_labels.gd` with a frame and the letters of notices (a panel on the
  interface layer above the sign's top on the screen) while the player is within `Placed.SIGN_READ` (3) cells;
  while the window is open there are no inscriptions. The line fields are shared input fields (`TextField.fit`:
  the caret, switching the tab; [ui.md](ui.md)). The test setting «Key log» («Debug», off by default) outputs
  under the window's buttons the page's log of keys (`KEYS_LOG`: who has the focus, keys, input).
- `src/client/game/props.gd`, `src/client/view/voxel_props.gd` — the models of things and fire on screen; a
  placed light is a model standing (`VoxelProps.standing`: a lying torch is put on its long side) and a little
  flame with light (`Effects.add_lamp`; real light only at the `LAMP_LIGHTS` 6 nearest to the view, the flames
  farther than `LAMP_FLAME_REACH` do not burn).
- `src/client/ui/craft_panel.gd`, `inventory_window.gd` — the «Crafting» tab (what it spends and what it holds
  in the bag, the station, tools with wear, time, by-product) and the bag window. What they ask of the rules
  (start, cancel, pause, repair, take/put out/destroy a station, the bag and chests) goes by requests
  `game.net`; a chest in a request is named by the thing's cell (`Placed.at`) — [network.md](network.md).
  They read the copy of the workshop `src/client/net/remote_workshop.gd` (the queue and pause from the event
  `shop`, the knowledge from `knowledge`; between events the copy counts the first work's time itself so that
  the strip goes, but does not finish the work) and the copy of things `remote_placed.gd` (chests from the
  event `chest`); the player's workshop itself runs on the server (`PlayerLink`), the things — in its session.

**Data.** The recipes are the kind `recipes` in the bundles of tools, materials and plants: `makes`, `count`,
`also` (by-products: `item`, `count`, `chance`), `needs` (spent when the work gets into the queue), `keeps`
(needed in the bag while the work goes, not spent), `at` (the station), `tools` (classes of tools, one each in
the bag), `wear` (how many blows the product takes off the tool of each class), `process` (`craft`, `refine`,
`smelt`, `cook` — for reports), `time`; the fields and examples — section 6 of
[BUNDLE_SYSTEM.md](../specifications/BUNDLE_SYSTEM.md). A station is looked up by role (`Items.with_prop`), the
campfire's fuel — by `fuel` (`Items.fuel_in`, how long it burns — `Items.fuel_time`); the models —
`models/<model>.png`. Wear and repair are on by default (`Rules.tool_wear`, the switch «Tool wear» on
«Testing» turns it off; the tools' durabilities and the skill's care — `docs/balance/GAME_BALANCE_DESIGN.md`).

**Stations by flags.** `prop` is an open class of a thing (the model, the solid parts), and what it does is
said by the item's flags: `storage` (keeps things, a chest: 16 places, a big chest: 40; such a thing is not a
station), `fire` (burns: is put out, lit with fuel, burns whoever touched the logs (`Placed.FLAMES_HALF` — the
same half-cell from the middle as `FIRE_BOXES`, plus the body's width) or bumped into them by a step
(`Body.bumped`): `Vitals.BURN`, the knock `Character.BURN_KNOCK`; one can warm up on the stones around; only
the logs in the middle are solid, cell by cell, `Placed.FIRE_BOXES`, the ring of stones is passable; a fire
with a model of its own is a hearth, `Placed.is_hearth`: the 2×1 fireplace of the bundle `tools/fireplace` is
solid by its model, does not burn, is placed cold (`fuel_start` 0), an extinguished one is taken into the bag,
the flame is drawn by `Effects.add_campfire(…, hearth)` in the middle of its cells, one cooks at it what one
cooks at a campfire (`serves`)), `repairs` (tools are repaired at it: a workbench), `serves` (replaces the
named stations: their recipes and repair), `place_tool` (placed only if the bag has a tool of this class).
`Placed` and `Workshop` ask the flags; a new station is only data: an item, a model, an icon, recipes.

**Size and turn.** A thing occupies a square of cells by the slice of its model (`Placed.sizes`: a slice of
16 voxels — 2×2, 8 — one cell) and is placed facing the player (`turn`: 0 — facing south, 1 — west, 2 —
north, 3 — east; stored in the save and goes to the copies); solid and occupied are only the cells where its
voxels are (`Placed.cells_of`), the model and boxes turn together (`Placed.turned`, `Props._model`). A ladder
is an item with `steps`: its solid parts are boxes by quarters of a cell (`WorldData.blockers` stores an array
for a cell), the body steps up the half-cell steps with no jump; it is placed over a void too, a tap takes it
back, it is not counted a station. A door is an item with `door`: the leaf is closed along the north edge of
its cell, a tap (`Protocol.PROP_OPEN`, `Placed.swing`, the plot's right «Open doors») turns it on a hinge in
the north-west corner to the west edge (`Placed.open_voxels`, as it is drawn); an open door is solid nowhere
(`opened_boxes` are empty: a thrown-back leaf would occupy a quarter of the opening that a body barely passes
and would stand into the one who opens), nothing is placed in its opening (`Placed._in_open_door`), with a
body in the opening it does not close; the copies learn from `PROP_OPENED`, the state `open` in the save. A
door two cells wide (2×2, 2×3) is double-leaf: the west leaf opens to the west edge, the east one on a hinge
in the north-east corner to the east. A window is an item with `window`: a frame with glass, solid, a tap
takes it (`Placed.is_part`), the light of the sun, moon and fires passes through it (`Placed.lets_light`), and
through a closed door — not; windows 1×1, 1×2, 2×1, 2×2, 3×2 (width × height); doors 1×2, 2×2, 2×3 and gates
3×3 (two leaves of a cell and a half each). **A fence** (stage 1, item 5; the bundle `tools/fence`) is an item
with `fence`: a post in the middle of the cell, rails to each neighbouring cell of its level where there is a
fence, a wicket or a gate (`Placed.joins`, `join` — the bits of the sides `Placed.SIDES`; a lone link — rails
across its face; the neighbours are rebuilt when a link is placed or taken, the signal `joined`, `Props`
draws the post and the model's north rail turned to each side); solid up to `Placed.FENCE_TOP` (2 cells —
above a jump), so a body neither passes nor jumps over, and beasts do not come in (`Wildlife._fenced`: a
thing higher than a cell and a half is a wall for a beast, a chest is still passable); a tap takes it in build
mode (`is_part`), it is built there by a blueprint, a line or a square (`Plans.is_fence`). A wicket (1) and a
gate (2) are doors with `fence`: a leaf of rails in the middle of the cell, of the same height of solidity,
an open one swings out to the south on a hinge at its edge (`Placed.swung_voxels`); a tap with a wicket on a
fence link in build mode puts it in its place, the links go into the bag (`Placed._swappable`). **A hatch**
(`tools/hatch`, 1×1 and 2×2) is a door with `hatch`: the lid at the top of its cell, a closed one is solid as
a floor; it is placed into a floor or a ceiling of built blocks (a tap on a block takes it out, `rest_of` →
`IN_FLOOR`: a solid cell next to it), an open one raises the lid on a hinge at the north edge into the cell
above it. **A leaning ladder** (`tools/ladder`) is an item with `ladder`: a link per cell at the back side of
its cell, not solid — its cell is in `WorldData.ladders` (cell → turn); it is placed on the ground or on the
link under it (`ON_LADDER`), a tap on a ladder with a ladder in build mode extends it from above with the same
turn; climbing — `Body._climb` ([character.md](character.md)). A thing higher than a cell (a door) is placed
only if there is air above it. A thing that occupies only a row of its square (a door or a window wider than
a cell, a fireplace) is placed into the cells right before the player (`_spot_in_front` aims at the middle of
its cells), and is tapped there too: `Placed.center` — the middle of the occupied cells (`Placed.middles` by
the turn), not of the square.

**Moving and turning** (2026-11-13, items 23–24 of the user's list). `Placed.movable`: a station, a chest,
furniture, a sign, a fireplace move (not a door, a window, a hatch, stairs, a fence, a ladder, a campfire, a
cross, a boundary post); `Placed.move(who, e, corner, turn)` — the request `PROP_MOVE` [cell, corner, turn]
(in `PACED`): the free place nearest to `corner` (`move_spot`: `_spot_at` with the thing's own cells free),
within `Tools.PLACE_REACH`, land rights at both ends, the hands' stamina (`act("place")`); the thing is taken
and placed anew with what it holds, burns and says, so the copies and the save get it as an ordinary thing
(`removed`, `added`); the same cell with a quarter more turns it. The build mode drags and turns it
([interaction.md](interaction.md)). On screen (`Props._arrive`) a thing set down while playing drops into
place from `DROP_HEIGHT` with dust of the ground under it (`Effects.dust`) and the sound `place` on landing
(lower for a 2×2 one); a thing gone and back on its cell within `RENEW_MS` was changed where it stands (a
sign written, `_renew`) and does not drop, a turned one hops; what comes with the world or on joining is still.

**Furniture** (decision 163, 7А; the bundle `tools/furniture`) — things with `furniture`: placed facing the
player, not counted stations (`Items.is_station`). A table and a rug — on 2×2 cells, a stool, a cupboard and
a barrel — on one (the cupboard two high), a wide cupboard — on two cells in width and two in height (48
places), a bed — bedding on 2×2 (`bedding` 2.5). In the inventory the divider above the cells of what it
keeps draws a scheme by its `prop` if `UiStyle.ICONS` knows it (a cupboard, a wide cupboard, a barrel),
otherwise a chest. A tap takes what keeps nothing (`Placed.is_part`). `seat`: one standing still on the thing
or near it (`Placed.SEAT_REACH`) gets stamina `seat` times faster (`Placed.seat_near` → `Vitals.rest_rate`,
set by `Character.update`). A cupboard and a barrel keep (`storage`); `keeps` — how many times slower food
spoils inside (`Placed.spoil`).

**Limits.** The solid parts of a thing `Placed.read_footprints` reads from its voxel model (the bundle's PNG)
at loading the mods, without the client; a thing without a model is solid as a crate (`CRATE_BOX`).

**Tests.** `tests/unit/content_test.gd` (`crafting`: the queue and the works' numbers),
`tests/unit/actions_test.gd` (`placed`, `stairs_placed`, `furniture` — furniture, a seat and keeping,
`openings` — windows, doors 2×2 and 2×3, and `tests/unit/fences_test.gd` — a fence, a wicket and gates, a
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
