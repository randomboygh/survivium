# Hands and the world: digging, building, chopping, mowing, gathering

Status: ACTIVE. A Russian copy: [interaction_RU.md](interaction_RU.md).

**Purpose.** What the character's hands do to the world: dig cells, place blocks, chop and fell trees, mow
grass, break twigs, gather berries, plant, work with the action button on what is in front, pick up what
lies around. The rules are shared (the server checks them), input and hints are the client's.

**Files**
- `src/shared/game/felling.gd` — felling a tree: the trunk above the cut and its crown go, logs, twigs and
  seeds lie along the line of the fall (`Felling.fell`, called by `chop`).
- `src/shared/game/world_actions.gd` — the rules of the hands: `dig` / `dig_at`, `place_at` / `can_place`,
  `chop`, `fell`, `mow` / `mow_swing`, `act_in_front`, `place_in_front`, `swing_air`, gathering from bushes
  and trees, the spring regrowth. Signals: `cell_changed`, `cells_set` (all cells of a felled tree:
  `cell_changed` goes only for the lowest one in a column, but the clients' copies of the world need all of
  them), `looks_changed`, `drops_changed`, `taken`. One script, split by topic as a chain of inheritance
  (decision 168, like 145): each part extends the previous one and calls only itself and the earlier ones;
  outside, only `world_actions.gd` is known:
  `actions_base.gd` (state, the signal `cell_changed`, reach, `skilled`, `build_cell`, what the land's owner
  allows) ← `actions_gather.gd` (trees: `chop`, `fell`; gathering from bushes and trees, picking up from the
  ground, the signals `looks_changed`, `drops_changed`, `taken`) ← `actions_fight.gd` (`swing_air`, `strike`,
  `shoot`) ← `actions_water.gd` (`drink`, `fish`, `water_ahead`) ← `actions_dig.gd` (`dig_at`, `dig`, `mow`) ←
  `actions_build.gd` (`place_at`, `can_place`, `plant`) ← `actions_farm.gd` (farming: `farm_at` — a touch with
  a hoe turns grass or earth into a bed `Mat.BED`, a touch with a full watering can waters the bed
  (`Mat.BED_WET` for `WET_DAYS`; the can is a tool of the class `can`, its waterings are its `durability`,
  when empty it becomes `empties_to`), a ripe crop is reaped by hands and a sickle (`area` cells), a scythe
  only takes `mown`; hands do not dig a bed, a shovel does, and the crop is lost; `plant_at` for an item with
  `crop` sows on an empty bed, not in winter; `front_farm` / `farm_in_front` — the same with the action
  button, `front_kind` «till», «water», «reap»; `step_fields` / `grow_fields` — a step of the session once per
  `FIELD_TICK`: rain `Clock.rain` ≥ `RAIN_WETS` wets beds under the open sky, a wet one dries after a day, a
  crop on a wet bed grows in the warm seasons (`grow_days` days to ripe), in winter and under a block it
  dies; the stage is the picture's frame, its change sends `looks_changed`; the experience goes to the skill
  «Farming», role `farm`)
  ← `actions_nature.gd` (nature by itself, day by day in the warm seasons, decision 178, answers 1В and 2Б:
  `step_nature` — a step of the session, a row of a chunk's columns once per `NATURE_EVERY`, chunk after
  chunk; a chunk remembers how many warm days it has lived (`Chunk.grown`, saved; −1 — from today), and one
  that lags behind `Clock.warm_days` catches up in one pass with the chances of all the missed days (no more
  than `CATCH_UP_DAYS`); the chances are yearly, divided by `WARM_DAYS` (`chance_over`); `regrow_row`: bare
  natural earth next to grass grows over (`GRASS_BACK`, where the biome lays grass), a bush sets a like one
  beside it (`BUSH_SEED`, `BUSH_REACH`), a grown living tree drops a seed on open earth of the lattice with no
  trunks within `TREE_ROOM` (`TREE_SEED`, `TREE_REACH`) — a sapling (`sapling_of`: its own or one like it by
  the leaves; a bed's record `[sapling, days, 0, tree]`, the fourth field is the kind, `sapling_tree`) that
  grows like a planted one; on occupied ground — as everywhere)
  ← `actions_tame.gd` (taming from the hand, decision 178: `tended` — the animal in front within
  `TEND_REACH` whose kind has `tame_food`: a wild one if its food is in the hand, one's own tame one always;
  `tend_kind` — «feed», «shear», «stay», «follow»; `tend` with the action button before a blow: feeds (after
  `tame_feeds` feedings the animal is the feeder's, `Animal.owner` = `Player.id`), shears with a knife
  (`Tools.shears`, once per `wool_days`, the item `wool`), with an empty hand or a non-weapon — «Stay» here
  (`Animal.stay`) or «Call»; a knife with no wool ready hits; someone else's tame animal is not hit
  (`ActionsFight._wound`); `step_herds` — a step of the session once per `HERD_EVERY`: a pair of tame animals
  of one owner left together (`HERD_REACH`), fed by hand within `FED_DAYS`, brings a young one once per
  `breed_days` (`Wildlife.breed`) while there are fewer than `herd` of them there; the live trap, answer 3В:
  a thing whose item has `trap` keeps bait like a chest; `step_traps` once per `TRAP_EVERY` with the chance
  `TRAP_LURE` calls the nearest wild animal within `trap` cells whose kind has `trapped` and eats from a hand
  what lies in it (`Animal.bait` — goes to it, looking at nothing else); one that reaches `TRAP_NEAR` eats one
  bait and sits in it as the item `trapped` (`_catch`, `Wildlife.take`), one that has not come within
  `TRAP_COME` leaves; a full one is left alone. A live item (`alive`, `released_kind`) in the hand is
  `tend_kind` «release», `release` lets it out a cell ahead, tame and its own (`Wildlife.release`))
  ← `actions_boat.gd` (a raft and a boat, decision 178, answer 4Б: an item with `vessel` in the hand, with the
  action button facing open water (`launch_spot`: the water column ahead within `LAUNCH_REACH`, the whole
  hull `Body.HULL` on water of one level, the surface no farther than `LAUNCH_DROP` from the feet) is put on
  the water — leaves the bag and floats (`Vessels`), the character sits in it and rows (`Character.riding`,
  `vessel`, `seat` 0; `front_kind` «launch»); facing a vessel with a free seat — «board»: the first rows, the
  second rides (seat 1, `seat_at` — behind the rower); `step_boats` — a step of the session: the vessel
  follows the rower; once per `BOATS_EVERY` the seats are put in order (the rower left — the second starts
  rowing, no vessel — into the water), and from frozen water — to the nearest shore within `ASHORE_ROUND`;
  facing the shore (`ashore_spot`) — «ashore», the vessel stays at the shore; a touch of an empty vessel
  within `TAKE_REACH` — back into the bag (`take_vessel`, the request `vessel_take`); death leaves the vessel
  on the water; the button «Launch» in the bag window (the request `vessel_launch`, `launch_from_bag`) looks
  for water facing, then in eight directions (`launch_near`; the client greys the button out by its own copy
  when there is no water); every change of seat (sat down, got out, moved) at once sends the client
  `state_changed` (`_told`), otherwise the client for a moment still drew the character in the vessel on the
  shore; on screen one sitting in a vessel is the frame `sit`, a rower on the move — `row` (`player.gd`), the
  boat's oars (`oars` of the item) swing in time in `boats.gd` (`stroke`, `ROW_PERIOD`), at each stroke
  splashes at the blades and a plash (`_dip`), behind the stern of a moving vessel a wake (`Effects.wake`);
  currents, answer 5А: `_feel_flow` in `step_boats` gives a body in water or on a vessel the river's current
  there (the water looked up where the player is, `Body.depth_at`: the host's own body is never stepped on the server; `Character.flow`, `Body.flow`, `currents` — the session's `Currents`; to the client by the event
  `flow`); `step_drift` once per `DRIFT_EVERY` carries piles on a river's bed within `DRIFT_CHUNKS` chunks of
  the players while the water ahead is of the same level, ice holds)
  ← `world_actions.gd` (the action button `act_in_front` / `front_kind` / `front_choice`, `on_season`; a touch
  or click on a cell — `dig_at` in the same order as the button, only at the cell and not in front of the
  body (2026-11-11): a shot, the rod, drinking; an animal on the cell (`_tap_animal`: `tend` / `strike` with
  the direction to the cell); a bed (`farm_at`); with hands and a sword — `tap_choice`: food, including from a
  bush, tree or grass next to the cell (`TAP_RING`), otherwise the most valuable on the cell itself (seeds,
  then the rest); then the cell itself — a tree, grass, dig. A click with hands or a sword on a bush
  (`gathering.target_at`) goes the same way: `controls.tap` sends `DIG` to the bush's cell). A new rule of
  the hands goes into the part of its topic; if it calls a later part — into that part or lower down the
  chain.
- `src/shared/game/vessels.gd` — rafts and boats on water (decision 178, 4Б): a record `{id, item, at, turn}`,
  `launch`, `move` (the signal `changed` when it moved by `TELL_MOVE` or turned by `TELL_TURN`), `remove`
  (`gone`), `near`, `record` for the client, `to_list` / `from_list` — in the world's save (`vessels` in the
  meta); who sits where is with the characters. On the client `src/client/view/boats.gd`: the item's model on
  the water, one's own vessel under one's own body; a touch of an empty one — `gathering.gd` («Pick up into
  the bag»).
- `src/shared/game/plans.gd` — the blueprint (decision 163, build mode 2026-11-06): ghost cells with a block
  or a fence link in each (`cells`; a fence is `is_fence`, drawn only by a line and a square of one link in
  height and thickness, `build` puts the link as a thing `Placed.put` facing the player, `_put_fence`) and the
  block's shape, if not a cube (`forms`: slope, steps — `WorldData.forms`; `PlanView` draws them with profile
  lines), the figures `shape` (`KINDS`: «line» — a wall along the main direction of the stroke, «plane» — a
  floor in place of the top ground cell, «square» — walls along a rectangle with no opening, «cube» — floor,
  walls and ceiling, «flatten» — level the ground: natural ground above the level of the first cell (up to
  `FLAT_UP`) becomes a «dig out» ghost (`CUT`), pits under it (up to `FLAT_DOWN`) — a ghost of earth from the
  bag; buildings and trees are not touched; `build` first digs from above with the best tool of the bag
  (`best_tool`, its wear), then fills; height 1–6 (`MAX_HEIGHT`; for a plane — layers upward, for a cube — the
  whole height with floor and ceiling, not less than `MIN_ROOM` = 3), thickness 1–4 — for a line rows from the
  drawer, for a square inward; all figures except levelling are placed on top of the chosen surface), `sort`
  (which cells of the figure will stand, which are inside blocks or underground — not drawn, which lower ones
  hang over a void — uneven ground; the client shows the same), `draw` (draws or, with `erase`, erases the
  ghost in the whole box of the figure, `erase_box`), `clear` (erases the ghost nearby), `build` (one cell: the
  lowest, then the nearest in reach, on any level — the view's slice does not stop one building a ceiling from
  inside a house; a block from the bag — first the one in the hand; a floor replaces soft earth and gives it
  to the bag; with no blocks — waits), `to_list` / `from_list` (saved with the world, `"plans"`; JSON keeps a cell as `"(x, y, z)"` and a form as a
  float, `cell_of` reads them back), `take` /
  `take_all` (the client's copy, `Protocol.PLANS`, `PLAN_CELLS`). It is held by the session (`session.plans`),
  the hands' rules ask it through `actions.plans`; `WorldActions` is passed to `draw` / `build` as a
  parameter, with no reference cycle. Requests: `PLAN` [kind, from, to, height, thickness, erase],
  `PLAN_CLEAR`, `BUILD` (the action button of build mode, whatever is in the hand).
  The same holds the farm mode's marking: the values of `cells` that are `is_mark` (`TILL`, `WATER`, `REAP`
  or the id of what is sown and planted) lie on the top ground cell (`surface` looks for it in the column ±
  `FARM_UP` / `FARM_DOWN` from the level of the touch); `farm_columns` — a line along the main direction or a
  whole rectangle (`MAX_LINE`, `MAX_FLAT`), `mark_fits` / `farm_sort` — where the work is possible, `mark`
  (draws, replaces other marking, with `erase` erases it in the columns), `farm` — the mode's action button:
  the work of one mark nearby with a tool from the bag (the best hoe, a can with water, a sickle or hands — by
  `area`), on as many marked cells around as the tool takes; a «sow» mark on grass is dug first; done and
  impossible marks go, waiting ones (green crop, winter, no tool or seeds) stay, and the answer `{"idle"}`
  with a reason releases the button. The blueprint (`near`, `build`, `clear`, erasing by a box) does not
  touch the marking, and vice versa. Requests: `FARM` [work, from, to, square, erase], `FARM_WORK` (in
  `PACED`), `FARM_CLEAR`.
- `src/shared/content/tools.gd` — what a tool can do: a material says what digs it (`dig`), how hard it is
  (`hardness`: a gate — a pickaxe or axe needs strength not less) and how tough (`toughness`, with no field —
  as the hardness: a blow of a tool weaker than it lasts strength/toughness times longer, `swing_time`), an
  item says what tool it is (`tool`, an open class: the engine knows the work in the world for `WORLD_KINDS`,
  any other class there is hands and does not wear), strength (how much durability a blow takes: a tree falls
  when the blows have reached its `hits`, `hits_to` — how many), how many cells per swing (`area`), the swing
  time and reach; `ROLE_OF` / `role_of` — the skill each class of tool leads (one map for the rules and the
  character window); the model — `docs/balance/GAME_BALANCE_DESIGN.md`; bare hands are a tool with no item
  (`Tools.HAND`), their strength, swing, reach, which grass they cut and how many times slower they dig ground
  are the fields `hand_*` of the world's start (`content/core/data/starts.yaml`, a bundle's patch can change
  them); what is got with what — the functions `can_dig`, `can_chop` (an axe fells a tree and a bush),
  `can_dig_out` (a shovel digs a bush out), `can_knock` (a sword and a scythe knock berries down), `can_gather`
  (hands gather from trees and bushes), `mows`: both the hands' rules and the content graph ask them, so the
  check and the game do not diverge; the order of cells (around the touch, in front of the body outward, under
  the feet last), the brush shapes for blocks.
- `src/client/input/controls.gd` — keys, mouse, touches; `hands` (the item in each hand, `active` — the hand
  at work), the panel (the first `Inventory.HOTBAR` cells of the bag), brushes and strokes, the action button.
  One cannot build in the normal mode: a block or thing taken from the panel or the bag turns build mode on.
  It holds the modes' strokes like the rest (`_stroke` with `plan`), and what they mean is decided by
  `build_mode.gd` or `farm_mode.gd` (`mode()` — the one of the two that is on); `build_step` — one request
  `BUILD`, `farm_step` — `FARM_WORK`. Seeds and bushes too are planted only in farm mode. It calls the hands'
  rules not directly but by `game.net` requests (`Protocol.DIG`, `PLACE`, `PLAN`, `FRONT`, `PLANT_AT`, `EAT`),
  and by the answer plays the body's work (`_did`); so do `gathering.gd` (`GATHER`, `PICKUP`) and `props.gd`
  (`PROP_PUT`) — [network.md](network.md).
- `src/client/input/build_mode.gd` — build mode (`game.build`): entry from the bag («Build») or from a panel
  cell with a block or thing, exit (the hands return what they held), the palette (`palette`; the filters
  «All» / «Materials» / «Interior» are in the code but not shown yet), the shape, the kind of block (`form`:
  block, slope from below, slope from above, steps; raised from the player, `turns` — «turn», the key Y;
  `form_of` goes into `PLAN`), the height (its own for each figure, `heights`: floor 1, line and square 3,
  cube 5 — floor, 3 rows of walls, ceiling), the thickness, draw/erase, clear; on the action button «Build» or,
  when levelling, «Level»;
  the stroke (`start_stroke`, `show_stroke` — light cells will stand, red ones are inside blocks or over a
  void, when erasing a red box and the ghost in it above blueprints; `end_stroke` — `PLAN`);
  a thing (everything that is placed: `Items.is_interior`) is placed by a touch at once (`PROP_PUT_AT`,
  `Placed.put_at`: a door or window pressed on the side of a wall with no opening knocks the blocks out, they
  fall as if dug; blocks below the level of the player's feet are not knocked out, so a door on the floor
  stands on the floor); a touch of a placed thing takes it back (only in this mode); a thing that moves
  (`Placed.movable`: a station, a chest, furniture, a sign, a fireplace) is taken by a single tap only after
  `DOUBLE_TAP_MS` (`_tap_wait`), a second tap on it within that time turns it a quarter where it stands, and a
  finger or the mouse held on it and moved `DRAG_SHARE` of the screen drags it (a stroke with `prop`: `drag`
  each frame — the model is held up `Props.LIFT` over the free place nearest under the finger, `Placed.move_spot`
  as the server looks for it, its cells framed light or red; `release` — `PROP_MOVE`, `Placed.move`, or the
  model drops back, `Props.settle`); the action button is
  pressed once (`auto`) and builds the whole blueprint nearby, releases after the last cell or when the blocks
  run out. The settings are kept with the player (`"build"`).
- `src/client/input/farm_mode.gd` — farm mode (`game.farm`), made like build mode: entry from the bag
  («Garden» for seeds, a bush, a hoe, a can with water, a sickle) or from a panel cell with seeds or a bush;
  the work (`Plans.WORKS`: till, sow, water, reap — the hand takes what it is done with), the figure (line or
  square), draw/erase (the palette filters «All» / «Seeds» / «Bushes» are not shown yet), clear; a stroke on
  the ground — `FARM`; the action button (`auto`, «Work») does the marking nearby with the requests
  `FARM_WORK` and releases when there is nothing to do now. The settings are kept with the player
  (`"farm"`).
- `src/client/ui/farm_bar.gd` — the farm mode's panel: inherits `build_bar.gd` (the same palette, `mode` — whose
  mode), its own row of buttons (`_make_panel`, `_show_panel`): work | figure, draw/erase | clear, «Work» (on PC
  only), exit.
- `src/client/ui/build_bar.gd` — the mode's panel in place of the hotbar, in one row: buttons switched in a
  circle (the figure — `next_kind`, next to it «level»; the kind of block — `next_form` and «turn»; the
  figure's height and the walls' thickness — a plane has no thickness; draw/erase paired with «clear» — a
  second touch within 3 s), on PC the mode's action button (`_go`: an icon with no label, «Build» / «Work» in
  the hint, at work — paused and lit; calls `toggle_auto`, like F and the big action button on a touch
  screen, where there is none on the panel), exit; below it the palette, made as a hotbar without hands: the
  same frame, 40 px cells, arrows and finger scrolling (`_input`), the width of the hotbar (up to 10 cells,
  in portrait up to 6: its 4 + 2 hands); the clock under its right edge (`right_edge`). There are no filters
  yet: on entering the mode `filter` = «all».
- `src/client/input/cursor.gd` — the frame around the cells over which work will happen; `show_boxes` — whole
  cells (light and red), above the blueprint's ghost.
- `src/client/view/plan_view.gd` — the blueprint's ghost: blue lines along the edges of the cells near the
  player (the cursor frame's shader); the farm marking — a square on the cell's top face in the colour of the
  work and a sign inside (furrows, a sprout, a drop, a cross). The blueprint is seen only in build mode, the
  marking only in farm mode.

- `src/client/game/gathering.gd` — what a touch gathers and the hint for it, picking up near the player.
- `src/client/game/character.gd` — the character's copy on the client; `who` for what the client reads from the
  rules itself (the cursor frame, hints). The rules over the world go on the server, where `who` is
  `src/server/player.gd`.
- `src/client/game/props.gd` — what lies on the ground and its flight into the bag (connected to the signals).
  New things in a chunk are drawn when the neighbouring chunks in which the cells themselves changed have been
  rebuilt (`ChunkStreamer.edited`, they go first in the queue; neighbours touched only by an edge are not
  waited for; `drops_rebuilt` from `ChunkStreamer`, no longer than `DROPS_HOLD_MS`): the logs of a felled
  tree and what was dug appear together with the tree or cell vanishing.

**The `who` contract** (the shared `src/shared/game/character.gd` and its heirs). `inventory`, `position`,
`held_back`, `feet()`, `facing_step()`, `moving()`, `overlaps_cell(cell)`, `held()`, `tool()`, `brush()`,
`act(action)` (pays with stamina, false — no strength), `give(id, n, worn)`, `use_tool()` (wear),
`nag(reason, text)`, `say(text)`, `note(stat, n)` (life statistics), `is_dead()`, `sacks` (where the sacks lie
after death). A swing that did something returns `{"swing", "work", "time", "at"}`, an empty one — `{}` or only
`{"swing"}`.

**Data.** Farming: materials of the roles `bed` / `bed_wet` (the bundle `resources/soil`), items with `crop`
(grain), plants of the kind `crop` (`grows: field`, `grow_days`, `mown`, the frames of the stages; wheat — the
bundle `plants/ears`, turnip, carrot, peas — `plants/turnip`, `plants/carrot`, `plants/peas`, sowing flax —
`plants/flax`; their seeds are found by cutting wild plants: the field `finds`, `Plants.harvest`), saplings of
the kind `sapling` (`tree` — the species it grows into; an acorn and a cone — their `crop`): planted on open
ground on the lattice of trees (odd x, z, `sapling_spot`, `can_root`: not closer than `SAPLING_GAP` to a tree
or sapling), they grow in the warm seasons without watering (a can does not water a bed with a sapling: the
third field of its record is the mark of a little tree, not wetness; `can_water`, `wet`): a sprout and a shoot
(frames `across` cards wide, `foliage._crop` puts them on one root with a shift in the 4th field:
`grass.gdshader`), from the share `young` of the term — a small tree (`grow_young`, `Growth.place_young`; the
trunk is thin, `Growth.YOUNG_GIRTH`, by the sapling's record under it: `Growth.young_at`; a felled one gives
only twigs: `young_tree`, `Felling.fell(…, young)`), a grown one becomes a tree (`grow_tree`: the little tree
is removed by `Felling.clear`, then `Growth.place`) if there is room above it; a hoe (`tools/hoe`, class
`hoe`), a sickle (`tools/sickle`, class `sickle`), a watering can (`tools/watering_can`, class `can`); beds —
`WorldData.fields`. Items with `tool`, `power`, `area`, `reach`, `swing`, `mows`, `durability`, `repair`,
`anim`, `hands` (kind `items`); materials with `dig`, `hardness`, `item`, `bonus`, `mow`, `mow_gives` (kind
`materials`); trees and bushes — what they give (`log`, `twig`, `seed`, `fruit`). Building takes blocks from the
bag (free — a switch of «Testing»; digging, mowing and reaping give their own even then).

**Pitfalls.** A network game's client takes a cell from the server (`Protocol.CELLS`) through
`Mirror.take_cell`: a watered or dried bed keeps its crop (`set_cell` erases the `fields` record). A finger
touch in the browser also arrives as `InputEventMouseMotion`: `controls.input` treats mouse movement as a mouse
only when there is no finger and more than 1 s has passed since the touch. The joystick and `TouchButton`
follow their own touch index so that two fingers work.

**Tests.** `tests/unit/boat_test.gd` (launching, moving on water, two in a boat, the shore, a vessel at the
shore and into the bag, oars, saving, ice, death),
`tests/unit/farming_test.gd` (a bed, sowing, watering, rain, growth, winter, harvest, saving),
`tests/unit/actions_test.gd` (`felling`, `front_choice`, `world_actions`, `stairs_placed`, `placed`,
`start_camp`, `lights`, `drinking`, `furniture`, `openings`),
`tests/unit/plans_test.gd` (the blueprint's shapes, building by cells from the bag, erasing, saving),
`tests/unit/content_test.gd` (`tools`), `tests/progress_test.gd` (the whole way of the game from bare hands to
all recipes through the same calls). After an edit of tools, materials, stations, recipes or hands —
`progress_test` is a must.

**More.** `plan/design/character.md` («Interaction with the world»), `plan/design/ui.md` (controls).
