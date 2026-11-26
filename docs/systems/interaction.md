# Hands and the world: digging, building, chopping, mowing, gathering

Status: ACTIVE. A Russian copy: [interaction_RU.md](interaction_RU.md).

**Purpose.** What the character's hands do to the world: dig cells, place blocks, chop and fell trees, mow
grass, break twigs, gather berries, plant, work with the action button on what is in front, pick up what
lies around. The rules are shared (the server checks them), input and hints are the client's.

**Files**
- `src/shared/game/felling.gd` — felling a tree: the trunk above the cut and its crown go, logs, twigs and
  seeds lie along the line of the fall (`Felling.fell`, called by `chop`). A piece of wood lying in the woods
  (`Growth.piece_look`) is chopped up in half its species' blows: its log cell goes, the logs and twigs its kind
  gives (TreeLooks `pieces`: `logs`, `twigs`) lie along it (`Felling.cut_piece`).
- `src/shared/game/world_actions.gd` — the rules of the hands: `dig` / `dig_at`, `place_at` / `can_place`,
  `chop`, `fell`, `mow` / `mow_swing`, `act_in_front`, `place_in_front`, `swing_air`, gathering from bushes
  and trees, the spring regrowth. Signals: `cell_changed`, `cells_set` (all cells of a felled tree:
  `cell_changed` goes only for the lowest one in a column, but the clients' copies of the world need all of
  them), `looks_changed`, `drops_changed`, `taken`. One script, split by topic as a chain of inheritance
  (decision 168, like 145): each part extends the previous one and calls only itself and the earlier ones;
  outside, only `world_actions.gd` is known:
  `actions_base.gd` (state, the signal `cell_changed`, reach, `skilled`, `build_cell`, what the land's owner
  allows) ← `actions_gather.gd` (trees: `chop`, `fell`; gathering from bushes and trees, picking up from the
  ground (a beast's body before the feet by the action button: `body_ahead`, `take_body`), the signals `looks_changed`, `grass_changed` (one grass cell cut short: the client redraws only it, first), `spores` (a puffball's puff), `drops_changed`, `taken`) ← `actions_fight.gd` (`swing_air`, `strike`,
  `shoot`) ← `actions_water.gd` (`drink`, `fish`, `water_ahead`) ← `actions_dig.gd` (`dig_at`, `dig` — a dug cell also gives the `root` of a plant on it (madder) and its material's `finds`, a find with `found_in` only in those biomes (`found_here`); `leave_ashes` — what a burnt-down fire leaves; `mow`; `in_season(ids, cell)` — the plants there now: none with `winter` off in winter, none with `after_rain` where `Clock.shroom_size` is 0; `tread(who)`, called by `Session.step_players` — a plant with `crush` on the grass cell a player steps onto is crushed: spores, `crush` seconds of visions, the hint `[spores_in_the_eyes]`; `water_holds`: until water has physics, the ground under water and in the one-cell strip beside it at its level or lower is not dug, by hand, the button or a blueprint, with the hint `[water_holds_this_ground]`) ←
  `actions_build.gd` (`place_at`, `can_place`, `plant`) ← `actions_farm.gd` (farming: `farm_at` — a touch with
  a hoe turns grass or earth into a bed `Mat.BED`, a touch with a full watering can waters the bed
  (`Mat.BED_WET` for `WET_DAYS`; the can is a tool of the class `can`, its waterings are its `durability`,
  when empty it becomes `empties_to`, a watering takes its `water_swing` seconds), a ripe crop is reaped by hands and a sickle (`area` cells), a scythe
  only takes `mown`; hands do not dig a bed, a shovel does, and the crop is lost; `plant_at` for an item with
  `crop` sows on an empty bed, not in winter (its `sow_swing` seconds), or wild on grass or bare earth a hoe
  would till (`wild_crop`; `plant_spot` takes a free bed in front first): the ground stays, the record lives
  on it, a can and rain wet it like a bed, the crop keeps `WILD_QUALITY` (0.5) of its seed's quality, and when
  its sprout first grows on only `WILD_SPROUTS` (0.3) come up (`wild_sprouts`), the rest are lost; reaped or
  in winter its record goes; `front_farm` / `farm_in_front` — the same with the action
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
  natural earth next to grass grows over (the biome's `grass_back`, where the biome lays grass), a bush sets a
  like one beside it (the bush's `seeding`, `seed_reach`, `seed_tries`), a grown living tree drops a seed on open
  earth of the lattice with no trunks within its `seed_room` (the tree's `seeding`, `seed_reach`, `seed_tries`;
  all content data, the chances by record cached for the row) — a sapling (`sapling_of`: its own or one like it by
  the leaves; a bed's record `[sapling, days, 0, tree]`, the fourth field is the kind, `sapling_tree`) that
  grows like a planted one; on occupied ground — as everywhere)
  ← `actions_tame.gd` (taming from the hand, decision 178: `tended` — the animal in front within
  `TEND_REACH` whose kind has `tame_food`: a wild one if its food is in the hand, one's own tame one always;
  `tend_kind` — «feed», «shear», «stay», «follow»; `tend` (the kind's `tend_swing` seconds) with the action button before a blow: feeds (after
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
  `vessel`, `seat` 0; `front_kind` «launch»); facing a vessel with a free seat (the item's `seats`,
  `Vessels.seats`) — «board»: the first rows, the others ride (seat 1, `seat_at` — behind the rower); a launch,
  a boarding and a step ashore take the item's `board_swing` seconds; `step_boats` — a step of the session: the vessel
  follows the rower; once per `BOATS_EVERY` the seats are put in order (the rower left — the second starts
  rowing, no vessel — into the water), and from frozen water — to the nearest shore within `ASHORE_ROUND`;
  facing the shore (`ashore_spot`) — «ashore», the vessel stays at the shore; a touch of an empty vessel
  within `TAKE_REACH` — back into the bag (`take_vessel`, the request `vessel_take`); death leaves the vessel
  on the water; the button «Launch» in the bag window (the request `vessel_launch`, `launch_from_bag`) looks
  for water facing, then in eight directions (`launch_near`; the client greys the button out by its own copy
  when there is no water); every change of seat (sat down, got out, moved) at once sends the client
  `state_changed` (`_told`), otherwise the client for a moment still drew the character in the vessel on the
  shore; on screen one sitting in a vessel is the frame `sit`, a rower on the move — `row` (`player.gd`; its
  frames drawn whole, the fists on the oars' handles: `tools/art/player_row_art.gd`), the
  boat's oars (`oars` of the item) swing in time in `boats.gd` (`stroke`, `ROW_PERIOD`), at each stroke
  splashes at the blades and a plash (`_dip`), behind the stern of a moving vessel a wake (`Effects.wake`);
  currents, answer 5А: `_feel_flow` in `step_boats` gives a body in water or on a vessel the river's current
  there (the water looked up where the player is, `Body.depth_at`: the host's own body is never stepped on the server; `Character.flow`, `Body.flow`, `currents` — the session's `Currents`; to the client by the event
  `flow`); `step_drift` once per `DRIFT_EVERY` carries piles on a river's bed within `DRIFT_CHUNKS` chunks of
  the players while the water ahead is of the same level, ice holds)
  ← `world_actions.gd` (the action button `act_in_front` / `front_kind` / `front_choice`, `on_season`; a beast's
  body lying before the feet is taken, «take», «Pick up», after an animal to strike and before a shot; a touch
  or click on a cell — `dig_at` in the same order as the button, only at the cell and not in front of the
  body (2026-11-11): a shot, the rod, drinking; an animal on the cell (`_tap_animal`: `tend` / `strike` with
  the direction to the cell); a bed (`farm_at`); with hands and a sword — `tap_choice`: food, including from a
  bush, tree or grass next to the cell (`TAP_RING`), otherwise the most valuable on the cell itself (seeds,
  then the rest); grass with plants on it (flowers, herbs, nettles, mushrooms) ranks half a step above bare
  grass (`_mow_rank`), so plants are picked before the fibre of the ground, by a tap and by the action button;
  where snow lies `SNOW_GATHER` deep (`Clock.snow`, `WorldCells.peak_snow`) or the ground is snow, bare hands
  gather a handful of it instead of the fibre (`snow_gathered`: the item of the material with the role `snow`,
  open sky, nothing standing there; the grass stays, the snow is not used up);
  then the cell itself — a tree, grass, dig. A click with hands or a sword on a bush
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
  lines; a line, a plane or a square drawn with a form is a flight, `flight`: from the first corner one level high to the
  last at the height chosen — a line and a plane along the stroke (a plane all across its width), a square along both sides to the far corner — each column cubes under a slope or a
  step on top where it rises; an upturned slope mirrors it from the top, the first column hanging at the height,
  and its cells are not told as hanging, `sort` `hangs` (`hangs_by_shape`); with `BAND` in the form (32) the
  flight is a band one block thick: a column holds its top down to the level of the one before, the lowest
  cell where it rises the slope turned back (an upturned one under a slope, a slope over an upturned one) or,
  under stairs, a notch (`WorldData.FORM_NOTCH`), so the underside steps as the top does; a band hangs by its
  shape too; a room is of cubes, `FLIGHTS`), the figures `shape` (`KINDS`: «line» — a wall along the main direction of the stroke, «plane» — a
  floor in place of the top ground cell, «square» — walls along a rectangle with no opening, «cube» — floor,
  walls and ceiling, «flatten» — level the ground: natural ground above the level of the first cell (up to
  `FLAT_UP`) becomes a «dig out» ghost (`CUT`), pits under it (up to `FLAT_DOWN`) — a ghost of earth from the
  bag; buildings and trees are not touched; `build` first digs from above with the best tool of the bag
  (`best_tool`, its wear), then fills; height 1–6 (`MAX_HEIGHT`; for a plane — layers upward, for a cube — the
  whole height with floor and ceiling, not less than `MIN_ROOM` = 3), thickness 1–4 — for a line rows from the
  drawer, for a square inward; all figures except levelling are placed on top of the chosen surface), `sort`
  (which cells of the figure will stand, which are inside blocks or underground — not drawn, which lower ones
  hang over a void — uneven ground; the client shows the same), `earthwork` (with `level`, the setting
  «Ground under a figure» = «level it», `build_level` 0, the default; item 11, the user's picks of 2026-11-26: a
  figure of blocks on uneven ground levels it as «flatten» at its level — under its footprint, a line's columns
  or the whole rectangle of a plane, a square or a cube, natural ground from its lowest level up to its top
  (the user's pick 2Б: the ground over the top stays) is a `CUT` ghost, the figure's own cells in it stay its blocks and `build` digs them first when no block takes
  their place at once (`_buried`, stone), dips under it are filled with soil when solid ground is at most
  `FLAT_DOWN` levels down (a deeper one is left and the figure hangs there); a flight of slopes or stairs only
  has its dips filled, a fence takes the ground as it lies; `sort` takes it so the cells in the ground fit and
  those over soil do not hang), `draw` (draws or, with `erase`, erases the ghost in the whole box of the figure,
  `erase_box`; with `level` the box reaches `FLAT_DOWN` under the figure but takes only the earth's ghost there, `is_earth`;
  with `replace_it` — `replace`, idea 6 of 2026-11-26: in the box every block players built of another material,
  `replaceable` — not natural, not a tree's, no thing in it, becomes a ghost of the block in the hand keeping its
  form, and ghost blocks of another material there are repainted; `build` swaps such a block in one work, from
  the bottom, only with the new block in the bag and a tool for the old one, `best_tool` and its wear, the old
  block into the bag as dug, so no hole is left; soft built ground is taken in place as a floor's), `clear` (erases the ghost nearby), `build` (one cell: the
  lowest, then on a level one after another, 2026-11-26: the end of a row first, the fewest ghost cells beside it,
  then the nearest the cell this builder built last, `_last_built`, else the builder; on any level — the view's slice does not stop one building a ceiling from
  inside a house; a block from the bag — first the one in the hand; a floor replaces soft earth and gives it
  to the bag; with no blocks — waits), `to_list` / `from_list` (saved with the world, `"plans"`; JSON keeps a cell as `"(x, y, z)"` and a form as a
  float, `cell_of` reads them back), `take` /
  `take_all` (the client's copy, `Protocol.PLANS`, `PLAN_CELLS`). It is held by the session (`session.plans`),
  the hands' rules ask it through `actions.plans`; `WorldActions` is passed to `draw` / `build` as a
  parameter, with no reference cycle. `turn_form` turns the ghost of a lone slope or stairs a quarter: the
  whole column of ghost cells with forms over and under the cell (`column_of`, `formed_at`), within
  `PLAN_REACH` and by the right «build». Requests: `PLAN` [kind, from, to, height, thickness, erase, form, level, replace (both may be left out)],
  `PLAN_TURN` [cell], `PLAN_CLEAR`, `BUILD` (the action button of build mode, whatever is in the hand).
  Ghost things (the user's picks of 2026-11-26, 1А, 2А): doors, windows, hatches and furniture drawn into the
  blueprint, `things` — records `{item, cell (north-west), turn, cells (each cell it fills,
  `Placed.volume_of`), wall (an opening's: the ghost blocks it took the place of, offset → block)}`, at most
  `MAX_THINGS`, indexed by cell (`thing_at`), told by the signal `thing_changed`; `put_thing` sets one of a
  thing in the bag where it would be set down (`Placed.ghost_spot`: as `put_spot`, but ghost blocks hold and
  back it as built ones do, other ghost things' cells are taken, an opening may stand in ghost blocks and takes
  them off into its `wall`); `move_thing` moves it the same way (`Placed.ghost_move_spot`; an opening along its
  wall, its own cell and turn + 2 turns it the other way round, `Placed.flip_spot`), `erase_thing` takes it
  off (its ghost wall back), and erasing by a box and `clear` take ghost things too; `build` sets them only
  when no block nearby can be built (`near_things`: the lowest, then the nearest; `_build_thing`,
  `Placed.put_ghost` — at its very cell and turn, from the bag at that moment; a door
  set into a ghost wall remembers the wall's blocks as its `cut`); a thing set down for real takes the ghost
  things off its cells (`drop_things_in`). Saved in `to_list` as dictionaries (`thing_record`, `_read_thing`;
  an older loader skips them), told to the copies by `GHOST_THING` / `GHOST_THING_GONE`. Requests
  `PLAN_THING` [item, aim, view turn, kept, face], `PLAN_THING_MOVE` [cell, to, turn, face], `PLAN_THING_TAKE`
  [cell].
  Undo and redo (`plan_history.gd`, the user's picks of 2026-11-26, 1А 2А): each player's request that changes
  the blueprint (`Requests.RECORDED`: `PLAN` drawing or erasing, `PLAN_TURN`, `PLAN_CLEAR`, `PLAN_THING`,
  `PLAN_THING_MOVE`, `PLAN_THING_TAKE`) is one step of their own history (`Requests.history`, `begin` / `end`
  round the request: the cells it touched, from the `changed` signal, with their item and form before and after,
  and the ghost things that went and came, from `thing_changed`), `PlanHistory.MAX` 50 steps, a new step drops the
  steps undone; building, farm marks and things set down at once are not in it. `PLAN_UNDO` / `PLAN_REDO` []
  put a cell back only where it is still as the step left it (a ghost built or changed by someone else meanwhile
  stays; no ghost goes on a block built meanwhile, `_fits`), only within `PLAN_REACH` and where the player may
  build; a step with nothing within reach stays, with a line to the player (answer -1). The link tells the
  client the counts (`PLAN_HISTORY` [undo, redo], `BuildMode.take_history`) to dim the bar's ↶ ↷. Kept while
  the player is in the world (a reload keeps it), not saved.
  The same holds the farm mode's marking: the values of `cells` that are `is_mark` (`TILL`, `WATER`, `REAP`
  or the id of what is sown and planted) lie on the top ground cell (`surface` looks for it in the column ±
  `FARM_UP` / `FARM_DOWN` from the level of the touch); `farm_columns` — a line along the main direction or a
  whole rectangle (`MAX_LINE`, `MAX_FLAT`), `mark_fits` / `farm_sort` — where the work is possible, `mark`
  (draws, replaces other marking, with `erase` erases it in the columns), `farm` — the mode's action button:
  the work of one mark nearby with a tool from the bag (the best hoe, a can with water, a sickle or hands — by
  `area`), on as many marked cells around as the tool takes; a «sow» mark on grass is dug first when the bag holds a hoe, else sown wild; done and
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
- `src/client/input/look_swipe.gd` — in the first-person view (`CameraRig.first_person`) a finger or the mouse's
  left button pressed on the world and moved past `SLOP` turns the view (`CameraRig.look_by`, `SPEED` radians a
  short side of the screen); let go before moving, it is a tap where it was pressed; held still `HOLD` (0.35 s),
  a held tap. `Controls.unhandled_input` gives it the events first; `Controls._ray` takes the camera's rays.
- `src/client/input/controls.gd` — keys, mouse, touches; `hands` (the item in each hand, `active` — the hand
  at work), the panel (the first `Inventory.HOTBAR` cells of the bag), brushes and strokes, the action button.
  One cannot build in the normal mode: a block or thing taken from the panel or the bag turns build mode on.
  It holds the modes' strokes like the rest (`_stroke` with `plan`), and what they mean is decided by
  `build_mode.gd` or `farm_mode.gd` (`mode()` — the one of the two that is on); `build_step` — one request
  `BUILD`, `farm_step` — `FARM_WORK`. Seeds and bushes too are planted only in farm mode. It calls the hands'
  rules not directly but by `game.net` requests (`Protocol.DIG`, `PLACE`, `PLAN`, `FRONT`, `PLANT_AT`, `EAT`),
  and by the answer plays the body's work (`_did`); so do `gathering.gd` (`GATHER`, `PICKUP`) and `props.gd`
  (`PROP_PUT`) — [network.md](network.md).
- `src/client/input/work_mode.gd` — what the build and the farming modes share (both extend it): the hands remembered on entry and given back on `leave`, the palette of the bag under a filter, the eraser, `auto`; a mode adds its hooks (`_filters`, `_in_palette`, `_show`, `_left`).
- `src/client/input/build_mode.gd` — build mode (`game.build`): entry from the bag («Build») or from a panel
  cell with a block or thing, exit (the hands return what they held), the palette (`palette`; the filters
  «All» / «Materials» / «Interior» are in the code but not shown yet), the shape, the kind of block (`form`:
  block, slope from below, slope from above, steps, then the three as a band, `band`, `form_index`,
  `FORM_COUNT`; only for a line, a plane and a square, `forms_drawn` — the button is off for a room; a flight rises along the stroke, a stroke of one column away from the player,
  the key Y turns the next ones a quarter (`turn`, `turns`: not kept, back to 0 on entering), a double tap on
  the ghost of one drawn turns it (`_second_ghost_tap` within `GHOST_TAP_MS`, `PLAN_TURN`, `Plans.turn_form`;
  no «turn» button since 2026-11-26); `form_of` goes into `PLAN`), the height (its own for each figure, `heights`: floor 1, line and square 3,
  cube 5 — floor, 3 rows of walls, ceiling), the thickness, draw/erase, clear; on the action button «Build» or,
  when levelling, «Level»;
  the eyedropper (`picking`, `pick_at`, the user's picks of 2026-11-26: a panel button beside the eraser, on a
  PC the middle mouse button): the next tap takes what is there into the hand as if chosen on the palette — a
  thing set down or a ghost thing (its turn kept in `kept_turns`), else the nearest ghost block, else the block
  hit, natural ones too (`block_item`: `Items.placed_by`, else `Items.dug`); once something is taken it goes
  off, the eraser too; nothing there or none in the bag (`choose`'s nag) → it stays on for the next tap (6Б);
  replacing the material (`replacing`, idea 6 of 2026-11-26): the third state of the draw/erase button,
  `next_mode` — draw → erase → replace, a paint roller, no extra button so the panel stays one row on a phone; a
  stroke begins at the block or ghost under the finger, `_replace_stroke`, takes the box of the figure (a plane
  for «flatten»), lights the blocks it will mark, `replaced_cells`, and sends `PLAN` with the 9th flag;
  the stroke (`start_stroke`, `show_stroke` — light cells will stand, red ones are inside blocks or over a
  void, when erasing a red box and the ghost in it above blueprints; `end_stroke` — `PLAN`);
  a thing (everything that is placed: `Items.is_interior`) from the bag shows at once as the finger or the
  mouse presses over a surface (2026-11-26), hanging in the air (`Props.hold_new`, `_drag_new`) over the place
  aimed at (`Placed.put_spot`, as the server will look for it, turned best: a door or window in the plane of
  its wall by the face pressed, `face_of`, furniture with its back to a wall; a door or a window aimed over a
  wall's top, before its face or by it sticks to the nearest wall cell, `Placed._wall_near`, `WALL_SNAP` cells
  round, a door down to the floor, and of the spots there the one with most cells in the wall, `_wall_spot`,
  2026-11-26; a gap in a wall, `_in_gap`, keeps the cell aimed at), its cells shown red only where
  it does not fit (2026-11-23: no body over a thing that fits; a door or a window held into a wall hangs
  `WALL_OUT` before its face, on the side the camera sees, `out_of_wall`: in the wall the blocks it will cut would hide
  it); it follows the finger and is set down where it
  is let go (a stroke with `put`; `PROP_PUT_AT` with the face, `Placed.put_at`: a door or window pressed on the
  side of a wall with no opening knocks the blocks out, they fall as if dug; blocks below the level of the
  player's feet are not knocked out, so a door on the floor stands on the floor); with the setting «Things from
  the bag» on «by blueprint» (`build_things` 0, the default; the user's pick of 2026-11-26, 2А) a door, a window,
  a hatch or furniture (`Props.ghostly`, `_by_blueprint`) is not set down but drawn into the blueprint as a ghost
  thing (`PLAN_THING`, `Plans.put_thing`): held, it hangs in the ghost look (`PlanThings.material`) over the
  place found as the server will find it (`Placed.ghost_spot`; the finger aims at ghost blocks as at built
  ones, `Controls.pick_planned`), «at once» sets it down as before; a ghost thing under the finger
  (`Controls.ghost_thing_at`) tapped is taken off the blueprint after `DOUBLE_TAP_MS` (`PLAN_THING_TAKE`),
  tapped twice is turned (`turn_ghost`: a quarter, a door or a window the other way round), held is carried as
  a placed thing is (`_drag_ghost`, `PlanThings.hold`, `Placed.ghost_move_spot`) and let go moves there
  (`_release_ghost`, `PLAN_THING_MOVE`); on a touch screen a tap aims right under the finger (2026-11-26: a tap set it down
  `FINGER_LIFT` up, over a wall's top or behind it), and once carried the place
  aimed at is `FINGER_LIFT` over the finger (`_lifted`, `HudLayout.touch_px`: about 0.7 cm; no line is drawn
  to it, the user's pick of 2026-11-26), and once held `HOLD_MS` (or moved `_slop`, a
  `DRAG_SHARE` of the screen) a short buzz tells it is taken up (`Vibration` «lift»); a touch of a placed thing
  takes it back after `DOUBLE_TAP_MS` (`_tap_wait`; a second tap within that time turns it a quarter where it stands; only in this mode); a thing that moves (`Placed.movable`: a station, a chest,
  furniture, a sign, a fireplace) held the same way hangs in the air (a stroke with `prop`: `drag` each frame
  — the model is held up `Props.LIFT` over the free place nearest the place aimed at, on a touch screen
  `FINGER_LIFT` over the finger with the «lift» buzz as for a new thing, `Placed.move_spot` as the
  server looks for it, its cells red where it does not fit; `release` — `PROP_MOVE`, `Placed.move`, or the model
  drops back, `Props.settle`); a door, a window or a hatch held so (`Placed.is_opening`, movable since
  2026-11-26) follows the wall under the finger as a new one does (`_drag_opening`: `_aimed`, `_aim`, `face_of`,
  `Placed.opening_spot`, held `out_of_wall` before the wall by `Props.hold_at`'s `out`), and let go it moves
  there by `PROP_MOVE` [cell, the wall's cell, turn, face]: the server cuts the new cells and walls the old ones
  up with the blocks it had cut (`Placed.move_opening`, [crafting.md](crafting.md)); tapped it goes back into
  the bag and leaves ghost blocks in its hole, and a double tap turns it the other way round in its wall
  (`turn_thing`: turn + 2, its kind's turn not kept); a double tap turns a thing (`turn_thing`) and keeps that turn for its kind
  (`kept_turns`): the next ones are set down turned so (`PROP_PUT_AT` with `true`, `Placed.put_spot` `kept`)
  until the bag holds none; a thing one cell big tapped with one of its kind in the hand sets the next down
  beside it (`_beside_kind`, `_beside`: the cell under the finger, else past the face the ray goes in by,
  `face_in`; held, it hangs there), and is taken only once the bag holds none; whatever comes into the bag
  while the build or farming mode is on (not while `auto` works, nor over a tool in the hand) has its palette slot chosen
  (`WorkMode._on_bag_changed`); a model held up never stays in the
  air: `update` drops it once the stroke is no longer on it (`Controls.dragging`), a second press releases the
  stroke first, on a touch screen the stroke ends with the last finger up, and while a finger is down only its
  own motion moves the stroke; the
  action button is
  pressed once (`auto`) and builds the whole blueprint nearby, releases after the last cell or when the blocks
  run out. The settings are kept with the player (`"build"`).
- `src/client/input/farm_mode.gd` — farm mode (`game.farm`), made like build mode: entry from the bag
  («Garden» for seeds, a bush, a hoe, a can with water, a sickle) or from a panel cell with seeds or a bush;
  the work (`Plans.WORKS`: till, sow, water, reap — the hand takes what it is done with), the figure (line or
  square), draw/erase (the palette filters «All» / «Seeds» / «Bushes» are not shown yet), clear; a stroke on
  the ground — `FARM`; the action button (`auto`; its word `button_name`: the work of the nearest mark — «Till», «Sow»,
  «Water», «Reap» — or the chosen work, «Stop» while it works) does the marking nearby with the requests
  `FARM_WORK` and releases when there is nothing to do now. The settings are kept with the player
  (`"farm"`).
- `src/client/ui/farm_bar.gd` — the farm mode's panel: inherits `build_bar.gd` (the same palette, `mode` — whose
  mode), its own row of buttons (`_make_panel`, `_show_panel`): work | figure, draw/erase | clear, «Work» (on PC
  only), exit.
- `src/client/ui/build_bar.gd` — the mode's panel in place of the hotbar, in one row: buttons switched in a
  circle (the figure — `next_kind`, next to it «level»; the kind of block — `next_form`, its hint telling that
  a double tap turns a lone slope's ghost, no «turn» button since 2026-11-26; the
  figure's height and the walls' thickness — a plane has no thickness; draw/erase paired with «clear» — a
  second touch within 3 s), on PC the mode's action button (`_go`: an icon with no label, «Build» / «Work» in
  the hint, at work — paused and lit; calls `toggle_auto`, like F and the big action button on a touch
  screen, where there is none on the panel), exit; below it the palette, made as a hotbar without hands: the
  same frame, 40 px cells, arrows and finger scrolling (`_input`), the width of the hotbar (up to 10 cells,
  in portrait up to 6: its 4 + 2 hands); the clock under its right edge (`right_edge`). There are no filters
  yet: on entering the mode `filter` = «all».
  What the blueprint needs (2026-11-26, the building UX's PR 5): `BuildMode.need` counts the ghost cells (one
  block of their item each, a slope too, digging none) and ghost things (one each) within `Plans.PLAN_REACH`
  of the player (`count_need`, again when the blueprint changes or the player walks `NEED_STEP` cells, at most
  every `CHECK_TIME`, once the blueprint and the bag have stayed `NEED_SETTLE` as they are; `short_of` compares
  the need with the bag's count taken with it, `_have`, so the ghosts do not blink red between the news of a cell
  built and of the bag, 2026-11-26); the palette puts those items first, the most needed first, also the ones the bag has none
  of (dimmed, ×0; a tap says they are not in the bag), with the need in the cell's top left (`HotbarSlot.tag`,
  `tag_color`: always pale as the bag's count, 2026-11-26; a shortage, `short_of`, tints the ghosts red; blocks are never short when building is free)
  and the need and the bag's count in the tip.
- `src/client/input/cursor.gd` — the frame around the cells over which work will happen; `show_boxes` — whole
  cells as see-through bodies over everything (light: white, red), merged with no faces between their cells and a
  light rim one pixel wide along their edges (`PlanGhost.bodies`, `plan_through.gdshader`), above the blueprint's
  ghost.
- `src/client/view/plan_view.gd` — the blueprint's ghost near the player (2026-11-22, until then frames round
  its cells): its blocks as they will stand built (`plan_blocks.gd`: the blocks in a world of their own,
  `ChunkMesher` meshing it a chunk at a time, `COLUMNS` columns a frame, the chunks round the player drawn by a copy
  of `world.gdshader` made see-through and tinted cold blue, first only into depth so only the nearest faces show);
  the ground to dig out a red body seen through the ground (its green taken out by `plan_cut_mul.gdshader`, then
  `plan_through.gdshader`) and a fence a plain blue body (`plan_ghost.gd`, `plan_ghost.gdshader`); its ghost things
  as their models in the blocks' look (`plan_things.gd`, `game.plan_view.things`: `Props.model_mesh`,
  `PlanBlocks.ghost_material`; a door or a window to be cut into a built wall hangs before its face,
  `BuildMode.out_of_wall`; `hold` / `settle` while the build mode carries one); the ghosts of what the bag is short
  of for the blueprint near (`BuildMode.short_blocks`, `short_of`) tinted `PlanBlocks.SHORT_TINT`, a soft red milder
  than the red of digging (the shader's `ghost_short` bits by material; things get a second material); the farm
  marking — a square on the cell's top face in the colour of the work and a sign inside (furrows, a sprout, a drop,
  a cross). The blueprint is seen only in build mode, the marking only in farm mode.

- `src/client/game/gathering.gd` — what a touch gathers and the hint for it, picking up near the player (a
  beast's body lying is hit round its middle, `BODY_UP`, `BODY_GROW` px farther).
- `src/client/game/character.gd` — the character's copy on the client; `who` for what the client reads from the
  rules itself (the cursor frame, hints). The rules over the world go on the server, where `who` is
  `src/server/player.gd`.
- `src/client/game/props.gd` — what lies on the ground and its flight into the bag (connected to the signals). What lies in a chunk is one mesh (`show_drops`); a thing taken up is folded away in it (its vertices put at one point, `_fold_taken`), the mesh is made again only when something new lies there.
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
`anim`, `hands`, `trail` (kind `items`); materials with `dig`, `hardness`, `item`, `bonus`, `mow`, `mow_gives` (kind
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
`tests/unit/actions_test.gd` (`felling`, `front_choice`, `snow_gathered`, `world_actions`, `stairs_placed`, `placed`,
`start_camp`, `lights`, `drinking`, `furniture`, `openings`),
`tests/unit/plans_test.gd` (the blueprint's shapes, building by cells from the bag, erasing, saving, ghost
things: set, moved, turned, taken off, saved, built after the blocks, `_test_ghost_things`),
`tests/unit/content_test.gd` (`tools`), `tests/progress_test.gd` (the whole way of the game from bare hands to
all recipes through the same calls). After an edit of tools, materials, stations, recipes or hands —
`progress_test` is a must.

**More.** `plan/design/character.md` («Interaction with the world»), `plan/design/ui.md` (controls).
