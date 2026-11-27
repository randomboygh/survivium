# Bag, vitals, warmth

Part of [The character: bag, strengths, skills, body, death, sprite](../character.md). The bag, health and the other vitals, warmth.

- `src/shared/game/inventory.gd` — the bag: `SLOTS` 16 (`base`), the first `HOTBAR` 8 — the bar below;
  stacks, weight (40 kg with no slowing, more with strength), sorting, moving into a chest, wear (`wear_tool`, `mend`); the signal
  `changed`. A rule giving something it must not lose (a craft's result, a door's wreath, dug ground, bait, a catch)
  calls `Inventory.give_or_lay(who, …)`: what does not fit is laid at the feet. Quality (decision 181): a stack has a number 1–100 (`quality(s)`, `quality_at(i)`; `NORMAL` 50 —
  what was before quality and at old saves), the cell's fifth field `[id, n, wear, things or null, quality]`
  only when it is not 50 (`stack` builds the cell, `held(s)` — the chest's things); stacks of one thing merge
  with the mean by number (`blend`, in `add`, `put_into`, `sort`), `remove` writes the quality of what was
  taken into `took`, `drop_data` puts it on the ground (`{"n", "worn", "q"}`, heaps merge the same way —
  `WorldData.heap_drop`), `tool_quality(id)` — the quality of the tool at work (the stack that wears first),
  `gear_quality()` — of what is worn. Food spoiling (`spoil(days, rate)`): food with `spoils` (game days) has
  in the cell's third field how much it has spoiled (out of `ROTTEN`), stacks merge at any age with the mean;
  time accumulates and lies by steps `SPOIL_STEP`, `changed` — once per `TELL_AGE`; spoiled food becomes
  `rots_to` (`core:rot`, «Rot»). In winter and under a roof slower (`spoil_rate`: `WINTER_RATE`, `ROOF_RATE`);
  the bag is spoiled by the character's step, chests — by `Placed.spoil` in the session's step.
  `freshness(i)` — the strip on a cell and «Freshness» in the description; `worn(i)` of food is 0 (it is not
  repaired). What is worn (`gear`: a body slot → an item, `WEAR_SLOTS` head, body, legs, feet, back, and for looks only neck, wrists and
  ornament: a feather in the hair) stays in
  its own cell, like a tool in the hand (`worn_slot(on)` — the first stack of this thing without things
  inside, `worn_on(i)` — what a cell is worn as; in the window and the hotbar the mark «W»): `wear(i)` puts it
  on, the former in this slot is taken off; `take_off(slot)` takes it off, the thing lies where it lay. A
  thing that left the bag (`take_slot`, `put_into`, `move_slot`, including an exchange from a chest) is taken
  off by itself (`_leave`/`_left`); `move_all` does not touch what is worn, `sort` moves it with the rest
  (except the bag on the back), it stays worn; `remove` (recipes) does not take the bag off the back. A bag on
  the back (`wear_on: back`, `bag_slots`) adds cells after `base` (`grow(n)` makes `base` `n` wider for the
  playtest's free items, `grown`, saved; narrowed, what the cells taken away held goes into free ones) and itself lies in the first `base` (it does
  not put itself into its own cells); taken off, it carries its things away in itself (like a taken chest,
  `contents`) and returns them when it is put on again; the weight does not change: `stack_weight` counts the
  things of bags lying in the bag too, to any depth. Saved in `to_dict` (`gear`); an old save where what was
  worn lay separately puts it into a free cell (`from_dict`), and without a free one it is carried separately
  (`apart()`: weighs itself, is taken off into a free cell). At death what is worn stays on the character
  (`take_all` takes the rest). A bag or a chest lying in a cell (not a bag on the back) is opened by `open(k)`
  as a separate bag (`room_of`: `bag_slots` or `storage`, a chest with things is not taken), `close(k, bag)`
  puts its things back into the cell's `contents`.
- `src/shared/game/vitals.gd` — health, satiety, water, vigour, stamina (0..`MAX`), the price of actions
  (`spend`, `can`). Vigour `energy` falls by `TIRE_PER_DAY` per game day of being awake; below `SLEEPY` — like
  hunger (stamina up to `HUNGRY_CAP`, rest slower), at zero the body goes slowly (`speed_factor`), does not
  wound. `sleep(on)` (one can fall asleep below `SLEEP_BELOW`); asleep (`asleep`) vigour grows by
  `SLEEP_GAIN` × `sleep_rate`, stamina and healing twice as fast. `Character.sleep` (the request `sleep`, not
  in water; not on a bed — the body lies down on the nearest within `BED_REACH` cells, `Placed.nearest_bed`),
  `Character.sleep_rate` (a roof `ROOF_SLEEP`, × the `bedding` of the bed one lies on: `Placed.bed_under`).
  A bed (`prop: bed`, an item with `bedding`) is placed on the ground, like a station; a tap on it is the
  request `lie_in` (`Character.lie_in`: fall asleep and lie on it, `Placed.lying_spot`, to the client —
  `TELEPORT`; one who does not want to sleep, `Vitals.sleepy`, is told so; a bed that is furniture, the
  wooden bed, is a bed before a part of the house, `Gathering.gather`); in
  the bag it does not work. On screen the sleeper lies on their side with closed eyes (the sheet's frame
  `sleep`, `Figure._lay_down`: its own column, drawn standing with the eyes shut and the legs pressed
  together, turned on its side; in a bed it lies along it, its head to the bed's head, `Placed.head_of`, a row
  of the column for each way: on its side head west or east, upright head north, upside down head south;
  `Player.bed_head`, set by Main from `Placed.bed_under`; on the ground head to the screen's left), above them
  small letters «z» rise, grow and melt in turn (`player.gd` `snore`, `_snore`); one wakes up by oneself
  when rested by day, from a wound or in water. While all sleep, the night
  goes `Session.SLEEP_SPEED` times faster. `fatigue` off — the test switch «Fatigue»: energy does not fall,
  work and swimming spend no strength (`spend`, `can`), one cannot drown. A poultice (`heal` with `heal_time`,
  the «Plants» bundle `plants/moss`: moss and a bandage by a campfire): `Vitals.mend` returns its health
  little by little over `heal_time` seconds (`mending`, `mend_rate`, in the save) — to the hungry and the
  frozen too; a second is not laid while the first is healing. A bandage (`heal` without `heal_time`) heals at
  once. Visions (`visions` of an item, the glowing mushroom of `plants/mushrooms`): `Vitals.see_visions` adds
  its seconds (`visions`, up to `VISIONS_MAX`, in the save; eaten even when full), they run out in real
  seconds and end with death; the client gets their whole seconds as the 11th field of `VITALS` and the
  picture swims and shifts colour (`CameraRig.visions` → `trip` of `grade.gdshader`). Calm (`calm` of an item, the
  primrose tea of `plants/evening_primrose`, drunk thirsty or not): `Vitals.calm_down` adds its seconds (up to
  `CALM_MAX`, in the save); asleep in it, sleep rests `CALM_SLEEP` times faster. Golden health (`fortify` and
  `fortify_time` of an item: roasted meat 20 for 10 min, roasted fish and primrose tea 10; asleep by a fire
  `Character.FIRE_SLEEP_GOLD` for `FIRE_SLEEP_TIME`): `Vitals.fortify` tops `extra` up to the amount (at most
  `EXTRA_MAX`, two meals do not add up) and makes it last `extra_time` seconds (both in the save); a wound
  takes it first (`_hurt`), it is gone when its time runs out or at death. The most health `Vitals.most` is
  `MAX` plus the cells the skills add (`SkillSet.health_bonus`, set each frame by `Character.update` →
  `Vitals.set_most`); healing reaches `most`, a save keeps health up to `MAX + MOST_ADDED` until the skills cut
  it back. `VITALS` carries `most` and `extra` as its 12th and 13th fields; the HUD draws health as cells of
  `Vitals.CELL`, golden ones after the red (`docs/systems/ui/hud.md`). Asleep inside a fairy ring
  (`Character.in_fairy_ring`, `Grass.fairy_ring`) sleep rests `RING_SLEEP` times faster and leaves at least
  `RING_DREAMS` seconds of visions. Water `water` falls by `THIRST_PER_DAY` per game day (in heat `THIRST_HOT` times faster); below
  `THIRSTY` — like hunger (no healing, rest twice as slow, stamina up to `HUNGRY_CAP`), at zero it wounds
  (`hurt_by` "thirst", «You died of thirst»). `drink(amount)`; `thirst` off — the test switch «Thirst». One
  drinks at fresh water with an empty hand (`WorldActions.drink`: the action button facing water within
  `DRINK_REACH` with air over it up to the body's level, so not a cave lake under the ground, `water_ahead`, or a tap on water; `fresh_water` — a lake, a river, a swamp, not the sea; `water_first`: a tree or a
  bush to gather in front, no farther than the water, comes first, and the sea is only called salty, `salty_ahead`,
  once there is nothing to gather), an empty vessel in
  the hand (`fills_to`) is filled there too; a full one (`drink`, `empties_to`) is drunk as food
  (`Character.eat`). A vessel of water (`holds`: a waterskin 60) keeps in its slot how much is missing
  (`Inventory.water_left`, `set_water`, `pour`; a blue strip on the slot, `water_share`): it is drunk in gulps
  as much as the thirst takes (`_drink_vessel`), emptied it becomes `empties_to`; topped up at water
  (`Inventory.vessel_for`). At the sea an empty one becomes its `fills_salty_to` (a waterskin of sea water,
  not drunk), boiled fresh at a campfire (recipes with `boils_off`: right in the waterskin half is lost, in a clay
  pot a tenth, `Crafting.water_out`). Under the open sky the rain fills the first empty or not full vessel of
  the bag (`_rain_into_bag`, `BAG_RAIN` a second in a downpour); rain catchers set down: [crafting.md](../crafting.md). Body warmth `warmth` (0..`MAX`, comfortable `COMFORT` 50) and getting wet `wet` (0..1):
  `warm(days, feel, …)` pulls the warmth to what follows from the felt temperature (between `COMFY_LOW` and
  `COMFY_HIGH` — comfortable), below `COLD` there is no healing, rest is twice as slow, stamina up to
  `HUNGRY_CAP`; below `FREEZING` frost wounds (`hurt_by` "cold"); above `HOT` stamina up to `HOT_CAP`. Rain and
  snow wet, water — through at once, it dries in air, under a roof faster, by a fire fastest. `cold` off — the
  test switch «Cold and heat». Warmth and the spoiling of food are worked out every `Character.WARM_EVERY`
  (0.5 s) with the days gone since.
- `src/shared/game/warmth.gd` — how many degrees where the body stands: `air` (the middle of the biome's
  `warmth` window between `COLDEST` and `WARMEST`, the season `SEASON`, the hour `daily` (warmest at `WARMEST_AT` of the sun's time, about 15:00, coldest at sunrise,
  `DAY_SWING` degrees apart, less under clouds), rain/snow/wind without a
  roof; «Testing» → «World» → «Temperature» pins `Clock.air_pin` in place of the biome and season, the same
  everywhere, still cooled by night and weather, on the server's
  clock: `Settings.AIR_TEMPS`, cheat `air_temp`; «Wind strength» and «Wind direction» next to it pin `Clock.wind_pin` and `Clock.wind_dir_pin` the same way, cheats `wind`, `wind_dir`), `fire_heat` (a burning campfire within `FIRE_REACH`, weaker as the fuel runs out), `clothes` (the sum
  of the `warmth` of what is worn), `feel` (fire, clothes — wet by half, a wet body −`WET_CHILL`, a roof
  +`ROOF`, in water colder than air). Counted by the character's step (`_warm`); the strip with a thermometer
  and a drop in `vitals_panel.gd`.
