# Digging, felling, rafts

Part of [Hands and the world: digging, building, chopping, mowing, gathering](../interaction.md). Felling, the rules of the hands, rafts and boats.

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
  hull `Body.HULL` on water of one level, found just under the surface so the sea's water, flush with its cell's top, counts too, the surface no farther than `LAUNCH_DROP` from the feet) is put on
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
