# Things on cells

Part of [Crafting, stations and things on cells](../crafting.md). `placed.gd`, models of things, the crafting panel.

- The code is a chain of parts (each calls only itself and the parts before it; callers preload `placed.gd`):
  `placed_kinds.gd` (constants, signals, what a kind is: `is_fire`, `is_door`, `is_opening`…, the models'
  shapes, the saved record) ← `placed_store.gd` (the things and lights set down and the cells they block,
  the index, saving, the start's camp, free ground) ← `placed_spots.gd` (where a thing fits: `put_spot`,
  walls, ghosts of the blueprint, a light's cell) ← `placed_build.gd` (set down, take up, move, openings cut
  into walls) ← `placed_fires.gd` (fires and fuel, rain, rain catchers, melting, spoiling, `step`) ←
  `placed.gd` (doors, signs, crosses, beds, seats).
- The index (`placed_store.gd`, GAME-2): the north-west cell → its things (`at`, `light_at`), the chunk of
  `INDEX_CHUNK` cells → its things (`near(lo, hi)`: those whose square may cover the columns, by `widest`), and
  the lists `fires`, `beds`, `seated`; kept by `put`, `put_light` and `_forget`, built anew in
  `read_footprints`. The rules asked every tick (`burning`, `seat_near`, `bed_under`, `nearest_bed`,
  `stations_near`, `_shut_door_on`, `_in_open_door`, `Warmth.fire_heat`) look only at those, not over every
  thing of the world; `things` keeps its order. A thing is never moved in place (a move is a remove and a
  `put`), so the index needs no other hook; `tests/unit/placed_index_test.gd` compares it with a look over all.
- `src/shared/game/placed.gd` — things on cells by the item's class `prop` and its flags (below):
  `put_from_bag`, `take_up`, `put_out`, `light`, `feed`, `destroy`, `stations_near`, `burns`; a campfire burns
  on fuel: a record's `fuel` is the seconds of burning (no more than the item's `fuel_max`, a new one is
  placed with `fuel_start`, 0 — burns for ever), `feed` and `light` put one fuel from the bag (`fuel_for`: the
  shortest — a twig before a log; the seconds — the fuel's `fuel_time`), `step(delta, rain)` in the session's
  step burns it and puts out a burnt-down one (the signal `burnt_down`: the session's `WorldActions.leave_ashes` drops the fire item's `ashes` on the cell south of it, ash for the grey dye; a fire put out by rain or a hand leaves none), and under the open sky (`WorldData.roof_level`) — after
  `RAIN_OUT` seconds of a downpour or storm (`RAIN_HEAVY`, the count `wet`); an extinguished one keeps the
  remainder. The copies learn the remainder by the signal `fuel_changed` (the request `prop_fire` with `true`
  lights or adds, the event `prop_fuel` once per `FUEL_TELL` seconds of burning). A tap on a campfire opens it
  as a station; how much is left is seen by the fire itself: `Effects.fire_strength` by `fuel_share` (by the
  root of the share: one just lit is already lively) — a full one burns wide, high and very bright, with
  sparks and far light, one burning down — low dim tongues and short light (`Props` by `fuel_changed`); the
  «Craft» tab at a campfire — the button «Add fuel» beside «Put out»/«Light», with a strip of the reserve
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
- Rain catchers (`rain_water`: a hide on posts `tools:rain_catcher` 240, a barrel `tools:rain_barrel` 120): a
  record's `water`, saved; `Placed.step` fills it under the open sky in the rain (`RAIN_CATCH` a second in a
  downpour, `_catch_rain`), the copies learn it by `water_changed` (the event `prop_water` each `WATER_TELL`). A tap
  (`prop_drink`, paced, the land's «chests» right) drinks a gulp with an empty hand or fills the empty vessel in
  hand or tops one up (`draw_water`); the hint shows how full it is; `Props._with_water` draws the water in the
  hollow of the model (the voxels each layer shuts in), in `WATER_STEPS` steps.
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
  the caret, switching the tab; [ui.md](../ui.md)). The test setting «Key log» («Debug», off by default) outputs
  under the window's buttons the page's log of keys (`KEYS_LOG`: who has the focus, keys, input).
- `src/client/game/props.gd`, `src/client/view/voxel_props.gd` — the models of things and fire on screen; a
  placed light is a model standing (`VoxelProps.standing`: a lying torch is put on its long side) and a little
  flame with light (`Effects.add_lamp`; real light only at the `LAMP_LIGHTS` 6 nearest to the view, the flames
  farther than `LAMP_FLAME_REACH` do not burn).
- `src/client/ui/craft_panel.gd`, `inventory_window.gd` — the «Craft» tab (what it spends and what it holds
  in the bag, the station, tools with wear, time, by-product) and the bag window. What they ask of the rules
  (start, cancel, pause, repair, take/put out/destroy a station, the bag and chests) goes by requests
  `game.net`; a chest in a request is named by the thing's cell (`Placed.at`) — [network.md](../network.md).
  They read the copy of the workshop `src/client/net/remote_workshop.gd` (the queue and pause from the event
  `shop`, the knowledge from `knowledge`; between events the copy counts the first work's time itself so that
  the strip goes, but does not finish the work) and the copy of things `remote_placed.gd` (chests from the
  event `chest`); the player's workshop itself runs on the server (`PlayerLink`), the things — in its session.
