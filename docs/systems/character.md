# The character: bag, strengths, skills, body, death, sprite

Status: ACTIVE. A Russian copy: [character_RU.md](character_RU.md).

**Purpose.** The one who plays: the bag and weight, what is worn, health, satiety, water, vigour and sleep,
warmth, stamina, skills, the price of actions, food, life statistics, death with a sack and respawn; the body
on cells (walking on slopes, jumps, water, ice, snow, wind); the player's sprite from PNG layers.

**Files**
- `src/shared/game/character.gd` — the character's rules (`in_hands`, `act`, `give`, `eat`, `wear`,
  `take_off`, `throw_away`, `die`, `revive`, `respawn_points` (with `find_respawns`: the last own bed —
  respawning lying in it, `Placed.lying_spot`, — then own and the team's campfires, `docs/systems/territory.md`),
  `to_dict` / `from_dict`); the signal `state_changed`. The death sack lies `SACK_DAYS` (2) game days: the
  fifth field of its record in `WorldData.drops` is the day (`Clock.now`) when it will vanish;
  `WorldActions.expire_sacks` (the session's step once per `Session.SACK_CHECK` s) removes it with its things
  from the loaded chunks (in a forgotten chunk — when it loads), and the character's `sack_ends` (beside
  `sacks`, in the save; for old sacks — for ever) remove the mark from maps even with no chunk
  (`_forget_old_sacks`, `forget_sack`). A sack taken not whole keeps its day. The death screen writes how long
  it will lie (`death.sack_days`). A cross at the sack's place: the sixth field of the sack's record is who
  died (`grave_of`: the player's name, the cause, the day, how long they lived, the `life` counters above 0).
  `going` — where the character is about to go (`Session.zones` makes the world there; request `prepare`).
- `src/client/game/trip.gd` — going far (user's pick 2026-11-16): `go(at, then)` asks the server to make the
  place ready (`prepare`), Main builds the chunks round it (`ChunkStreamer.set_focus`) and `then` runs once
  the chunks on its screen are built (`focus_built`) or after `MOST_MS` (20 s). The death screen's respawn
  buttons go this way (the button shows «Getting the place ready… N%»; the first point is built behind the
  screen already), and so do the test page's «Go» to a place (`Character.travel_to_column`) and «To the
  place of death» (`Settings.go_to_death`): the player goes on meanwhile.
  When the sack vanishes, `expire_sacks` returns where it lay and who died, and the session puts a cross there
  (`Placed.put_grave`: the first item with `grave`, at the base `core:grave`; in the sack's cell or the nearest
  free one within `Placed.GRAVE_REACH` (3) cells, a level above or below; no place — no cross). The cross's
  record (`grave`, cleaned by `Placed.grave_record`) goes into the save and to the copies as for signs; above
  the cross within `Placed.SIGN_READ` cells `sign_labels.gd` writes `DeathScreen.grave_text`: «Here lies
  «name»», the day and how long they lived, the cause, the distance walked and the two biggest life counters
  — in the player's language. A cross is not written on; one removed in build mode (`take_up`) vanishes,
  nothing goes into the bag. A death with an empty bag leaves no sack: the cross stands at once (`die`), beside
  the body. Fall damage (`_fall` in `update`): the height is counted from the level where the feet last stood
  (`Body.standing` — by the world, at the place the client sent, not by its word; a jump adds nothing), more
  than `Vitals.FALL_SAFE` (6) levels — `FALL_PER_LEVEL` (8 health) for each beyond (`Vitals.fall`, `hurt_by` "fall", «You
  crashed»); water under the landing place of 2 cells and deeper puts the fall out, of one — halves it
  (`Body.water_under`). A jump down faster than any fall (a teleport), the test's «jumps in the air» and
  `forget_fall` (respawn, `Player.teleport`) begin the count anew; on a leaning ladder (`Body.on_ladder`) there
  is no fall, the count goes from it. The test switch «Fall damage» (`Vitals.falls` off) makes every fall harmless; «Invulnerability» (`Vitals.harm` off,
  sent to a playtest server as `harm`, `Cheats.VITALS`) keeps health from going down at all.
  A plant that pricks (its `pricks`: a cactus, which is also `solid`) pricks a body touching it within
  `PRICK_REACH` cells or walking into it (`Body.bumped`): its `pricks` of health (`hurt_by` `plant:<id>`, the death
  screen «Pricked to death» with the plant's name), a push away from its root (`PRICK_KNOCK`, `PRICK_HOP`), and
  not again before `PRICK_PAUSE` (`_touch_spines`, asked of `Body.solid_near`); not while riding.
- `src/shared/game/inventory.gd` — the bag: `SLOTS` 16 (`base`), the first `HOTBAR` 8 — the bar below;
  stacks, weight (40 kg with no slowing, more with strength), sorting, moving into a chest, wear (`wear_tool`, `mend`); the signal
  `changed`. Quality (decision 181): a stack has a number 1–100 (`quality(s)`, `quality_at(i)`; `NORMAL` 50 —
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
  repaired). What is worn (`gear`: a body slot → an item, `WEAR_SLOTS` head, body, legs, feet, back) stays in
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
  `TELEPORT`; one who does not want to sleep, `Vitals.sleepy`, takes it into the bag, `Placed.take_up`); in
  the bag it does not work. On screen the sleeper lies on their side with closed eyes (the sheet's frame
  `sleep`, `Figure._lay_down`: its own column, drawn standing with the eyes shut and the legs pressed
  together, turned on its side), above them
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
  `DRINK_REACH` or a tap on water; `fresh_water` — a lake, a river, a swamp, not the sea), an empty vessel in
  the hand (`fills_to`) is filled there too; a full one (`drink`, `empties_to`) is drunk as food
  (`Character.eat`). A vessel of water (`holds`: a waterskin 60) keeps in its slot how much is missing
  (`Inventory.water_left`, `set_water`, `pour`; a blue strip on the slot, `water_share`): it is drunk in gulps
  as much as the thirst takes (`_drink_vessel`), emptied it becomes `empties_to`; topped up at water
  (`Inventory.vessel_for`). At the sea an empty one becomes its `fills_salty_to` (a waterskin of sea water,
  not drunk), boiled fresh at a campfire (recipes with `boils_off`: right in the waterskin half is lost, in a clay
  pot a tenth, `Crafting.water_out`). Under the open sky the rain fills the first empty or not full vessel of
  the bag (`_rain_into_bag`, `BAG_RAIN` a second in a downpour); rain catchers set down: [crafting.md](crafting.md). Body warmth `warmth` (0..`MAX`, comfortable `COMFORT` 50) and getting wet `wet` (0..1):
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
- `src/shared/game/body.gd` — the body on the grid: `step(at, delta, jump)` (a longer `delta` is walked in
  steps of `STEP_MOST` 0.05 s, so a fall never passes through a floor), slopes (the pace is along the ground: the run is shortened by the rise, `SLOPE_MOST`) and steps, water and
  swimming, the bark of a trunk thicker than its cell in the cells beside and across its corners
  (`WorldData._bark_touched`, an octagon as drawn), a plant that is `solid` (a cactus: a post `SOLID_HALF` cells
  round its root where Foliage draws it and `SOLID_HIGH` levels high, not jumped over; `Grass.solid_plant` finds
  it; `_find_posts` gathers those within `POST_REACH` columns once the body has gone a cell or `POSTS_FRESH`
  steps, so `_collides` asks only of them; one the body stands in already (`_in_plant`) lets it walk out), a leaning ladder (`_climb`: the body in the cell of a link of `WorldData.ladders`, or above the top
  link by less than `CLIMB_OVER`, does not fall; the joystick towards the ladder — up, away from it — down at
  the speed `CLIMB_SPEED`, sideways — along, above the top link towards the ladder — to step off at the edge;
  below on the ground «away from it» leads away by a step, a jump lets go at `LET_GO`; the server sets
  `climb` by the height the client sent, `Player._take_claim`), ice, deep snow and wind (`weather_pace`,
  `air_drift`), pushes (`knock`), trails; on a raft or in a boat (`vessel` — the share of a walking step,
  `Character.vessel_pace`: without `oars` in the bag `OARLESS` of it) the body keeps on the water's surface
  (`DECK` under it), goes only on water where the hull `HULL` fits (`floats`, `_sail`), faster with the
  swimming skill, an overload of the rower's bag slows half as strongly as a step (`LOAD_AFLOAT`); movement
  with inertia (`_row`): the vessel looks along `heading` (set by boarding, `ActionsBoat._set_off`, on the
  client `main._set_off`), turns to the stick no faster than `SAIL_TURN`, speeds up in `SAIL_SPEED_UP` s,
  without rowing it rolls and loses `SAIL_DRAG` of its speed per second, the keel damps sideways drift
  (`SAIL_KEEL`); wind drifts the vessel by its `windage` (`SAIL_WIND`, a light one — `SAIL_BREEZE` of that); a
  hull that hit the shore faster than `SAIL_BUMP` bounces (`SAIL_BOUNCE`), `bump` — at what speed (the knock
  in `steps.gd`); `afloat` — whether it holds; `flow` — a river's current (`Currents`, `Character.flow`)
  carries the vessel and the body in water by the share `SWIM_DEPTH` of itself that is in it. Where the body
  stands is held by the owner: on the client the player's node passes its place into `body.step` every frame.
- `src/server/player.gd` (inherits the shared one) — a player's character on the server, the one over whom
  the rules go: the body and hands are as the client sent them by the event `input`; over a socket the sent
  place is checked by the server's body (3А, [network.md](network.md)).
- `src/client/game/character.gd` (inherits the shared one) — the character's copy on the client: the bag,
  strengths, death from the server's events (`take`, `take_vitals`), the player's place, the hands (from
  `controls`), the lines under the clock, the death screen, `go_to_column` («Testing»); it runs no rules.
- `src/client/view/player.gd` — the player on screen: moves the body, draws the sprite by the body's state;
  `player.work` begins a stroke (`work_n` counts them, `work_at` — where it is turned: the server tells the
  other players about them).
- `src/client/view/others.gd` — other players on screen (С3.3): a figure `player.gd` for each of the server's
  snapshots `people` (drawn `DELAY` 0.1 s behind them, between the two nearest), the hands through
  `game.hands.look`, strokes by count, the name above the head in the interface's ordinary font (a Label in
  the HUD layer, set every frame at the screen's point above the head, `View.screen_of`, without smoothing)
  and above it a balloon with its chat line (6 s): light, with dark letters and a tail towards the name, so as
  not to confuse it with notices and signs (one's own line hangs so over one's own head, its tail to the head,
  `_own`); `person_gone` removes it. Players do not walk through each other: each game moves its own body out
  of the others on foot where it draws them (`parting` → `Body.parting` into the body's `nudge`, from `main.gd`
  before the step): by `PART_RATE` 20 of the overlap a second, at most `PART_MOST` 10 cells a second, round
  `PERSON_RADIUS` 0.4 cells each; one walking into another standing is held off, the other's game sees the
  overlap and steps aside, so walking on shoves them at about half the pace (`body_test` `_test_people`). The
  server only checks the places as for walking. It does not step with a body, the
  silhouette behind walls — only one's own. The light in another's hand (an item with `light` in their hands
  from the snapshot) burns as a flame in the place of the sprite's flame (`Effects.torch_flame`), and the
  `OTHER_LIGHTS` (3) nearest to the player also shine like one's own torch (`Sky.lamp_gain`,
  `Effects.torch_off`, two torches farther, for a swimming one shorter), with no shadows and always as new
  (how much is left to burn the server does not say); `server_test` checks, the shot `team-torches`.
  Walking on the ground (not swimming, not in a boat) they leave boot prints every `STRIDE` (0.55, as one's
  own in `main.gd`) through `tracks.gd`, and in deep snow tread the client's copy of the world
  (`WorldData.tread`), so their trail eases one's own walking as on the server; a move over `LEAP` (2 units:
  a teleport, a respawn) leaves none; `server_test` checks.
- Gestures (decision 183): `src/shared/game/gestures.gd` — the list `LIST` (wave, yes, no, point, here, bow,
  clap, sit: the wheel's words, the animation of `player.yaml`, seconds; «sit» — until movement), `make` (the
  request `gesture`, the name is checked against the list, "" — stop), `now_of` (a gesture ends by time, on
  movement, in water, in a boat, in sleep). The character stores `gesture`, `gesture_until`; the server sends
  the gesture in the `people` record (field 17). The figure (`player.gd`, `set_gesture`) plays its animation
  standing, above the head — the icon `UiStyle.icon("g_<name>")` for the first `Gestures.ICON_TIME` 2.5 s
  (for others — above the name); movement or work interrupt it. The gestures' frames are columns 48–59 of the
  sheet (`tools/art/player_art.gd`, `MOVES`, with `lean` — the body's tilt; `tools/make_sprites.gd` draws the
  layers, the marks of the hands and what is worn anew). A gesture with frames in
  `tools/art/player_gesture_art.gd` (GestureArt) is drawn whole instead, its rows reaching two columns past
  the box for a hand out beside the head: the wave (reviewed with the user 2026-11-20) raises the right hand
  by the face at the eyes' rows, two pixels square on a short shoulder, and moves it a pixel out and back;
  from the side the near hand is over the head by the ear (a hand in front of the body is drawn with the
  fists, over the head); the nod drops the head a pixel over the neck with the eyes shut (a frame's `eyes`,
  as in the blink), the body standing. The wheel of gestures —
  `src/client/ui/gesture_wheel.gd` (a button beside the chat in the top row, the key C, digits 1–8 in the
  wheel).
- `src/client/view/figure.gd` — the sheet of the player's frames from `content/core/sprites/` by `player.yaml`
  (layers, the marks of the hands `hands.png`, a sheet for each tool in the hand or the item's icon), built by
  a part of a row per frame; `hands.gd` — what in the hands is seen on the sprite; `sprite_sheet.gd` — the
  sheet of frames by data. The figure is a chibi (stage 3, the user's pick of 2026-11-19): 14×18 px with its
  outline in the 32×32 frame, a big head (rows 1–10, eyes 2×2: a pupil over the iris beside the eye's white),
  and under it the body in the proportions of the walk's reference (the stand redrawn to them, the user's
  pick of 2026-11-19): a neck, 8 px shoulders, a 6 px torso, bare arms of 2 px hanging by it, legs of 2 px,
  each as the reference draws it in the step it stands on; turned (south-east), from the side and from behind
  the head sits a row lower and the body is a row shorter, as in the walk. The feet stand on the frame's
  bottom row with no outline under them. What is worn never shows over the head (`frame_letters` takes it off
  where the head is: a nod's chin over the collar). `tools/art/player_art.gd` draws it (`HEAD`, `HAIR`, the body standing `BODY`,
  `SIDE_LEGS`, the arms `SHOULDER`, `REST` and `ARMS`, the poses `MOVES` and `WORKS`); the design and its
  letters are in the library `survivium-builds/character/chibi/`. Seated (`sit`: afloat and the gesture,
  and the rowing on the same legs) the body is two rows lower, only the feet under it; from the side the
  legs go forward (`SIDE_LEGS` `sit`), turned a little a knee shows past the waistband (`SIT_KNEE`; the
  user's notes of 2026-11-20). The walk (six frames, 10 a second,
  the user's pick of 2026-11-19) is the body of a reference copied pixel by pixel under our head
  (`tools/art/player_walk_art.gd`, from `survivium-builds/character/anim/references/`): legs of 2 px, the
  arms swinging against the legs, the body a pixel down at each step and a row shorter with both feet off
  the ground as the legs pass; from the side and from behind it stands a row lower than the reference, its
  feet on the frame's bottom row. A foot lifted has no outline under it either: `player.yaml` `soles` gives,
  by direction, the frame's bottom rows where `SpriteSheet.outline_rect` outlines nothing from above, in
  the walk's frames only (`Figure._put_row`): in the others a hand hanging low keeps its outline under it.
  The jump's two frames are drawn whole under the head the same way (`tools/art/player_jump_art.gd`,
  2026-11-19, after the user's note that an arm moves from its shoulder): rising, the shoulders go a row
  up with the arms and the legs are drawn up; falling, the arms go out to the sides (from the side
  forward) and the legs are straight. The swim's four frames too (`tools/art/player_swim_art.gd`, a
  breaststroke the user picked): the water is at the chin, so the whole stroke is under it, tinted; the hands
  come together in front of the chest, the arms sweep out from the shoulders, pull down and come back, the
  legs glide, kick apart and draw up; afloat the head is as high in every direction (no stand `drop`), so
  the eyes stay over the water. The chop's four frames too, with the axe (`tools/art/player_chop_art.gd`,
  reviewed with the user 2026-11-19): the axe up beside the head, the top, the strike crouched, upright
  again; the torso moves in the first two. The dig's four frames too, with the shovel
  (`tools/art/player_dig_art.gd`, reviewed with the user 2026-11-20): the hand holds the shaft halfway,
  the blade goes into the earth from the feet's level a pixel deeper in each of three frames (crouched on
  the third, the chest's row folded away: the legs never move), then the toss; from the front the shovel
  is at the right side, from the side and behind by the right foot, beside the feet with the outline
  between. The slash's four frames too, with a blade in one hand (`tools/art/player_slash_art.gd`,
  reviewed with the user 2026-11-20, first after the sword's swing of Puny Characters (Shade, CC0); the
  swords, knives, spears, sickles, slings and rods play it): the sword up beside the head at the
  shoulders, then raised higher; the swing (crouched, the chest's row folded away: the legs never move)
  along an arc down that side and under to the other, the blade about 30 degrees to the ground
  (`PlayerArt.LOW`, `LOW_LEFT`: `ToolArt.turned` lays any tool's upright shape along a line two pixels
  across for each one down); then standing again with the blade where it stopped. From the front the
  sword is at the right side (the picture's left) and the hand stays left of the belly's middle, so the
  blade never seems to be in the other hand; from the side it is the front's swing too: up behind the
  head (the hand by the chin), down behind and under to the blade forward and down, the same crescent of
  a trail; from behind the front is mirrored, the blade in front of the body hidden but for its tip past
  the left side. A frame may put the other hand behind the blade (`of`). A blade swung leaves a trail:
  the swing's frame draws one along the whole arc from the raised blade's tip (`trail` of the frame, the
  letters `o`, `+`, `-` of `PlayerArt.INK`, into the layer `player/trail.png`, `player.yaml` `trail`),
  and `Figure` puts it in the columns of the work the right hand's thing plays, for things with `trail`
  (swords, knives, sickles, also when held as an icon; `Hands.look`): over the figure and its outline
  where the hand holds the thing in front of the body, behind them (only where the frame is still empty)
  where the thing is behind it, as from behind; without it the tan wooden blade is lost over the skin. The slash strikes on its third frame as every
  work does (half the swing, `Controls`); a rod out fishing is held as in the last frame
  (`Player.ROD_OUT`). The bow's shot, the work `aim`, too (`tools/art/player_aim_art.gd`, reviewed with
  the user 2026-11-20 after the Bow Attack of Puny Characters; the bows play it): an arrow nocked, the
  string drawn back, loosed (the string straight, the drawing hand thrown back), the bow down again; from
  the front the bow is held across the body with its arrow at the viewer, from the side up in front of
  the face, turned away by the body's right side from under the cheek to the knee (the limb's arc, the
  string straight between its ends next to the body, the arrow a line from the near hand up through the
  bow), from behind hidden by the body. The bow
  changes with the string and the arrow in each frame, so a frame draws it whole (`bow`: rows of
  `ToolArt.INK` letters from their corner's offset from the grip), and `ToolArt.sheet` draws that for a
  shape with `bow` (the wooden bow, the composite one recoloured) instead of turning it; the other hand
  draws the string (`two`: it shows no thing of its own; the bows take two hands, `hands: 2`, as the work
  does in `player.yaml`). The bow has no dark edge of its own where the figure's outline goes (the two
  made a line two pixels thick): its dark letters only part its wood from the skin and from its string.
  Its string never runs over the legs: turned to the viewer the bow's lower end is under the frame's edge,
  and the string ends where it meets the limb on the hips' row (drawn, it goes from the upper end to the hand).
  From the front the bow's mark is above the frame's neck, which no build moves (`PlayerArt.pose`), so
  the bow held across the body stays in the middle of the stocky body too. The arrow leaves on the third frame:
  `Controls._did` flies the shot (`Props.fly_shot`) half the swing after the reply for the aim (a spear
  thrown or a fish pulled out still flies at once).
  The eat's four frames too (`tools/art/player_eat_art.gd`, reviewed with the user
  2026-11-20; what is eaten or drunk plays it): the food lifted to the belly, the elbow by the side;
  raised to the chin, the hand beside it; the bite, a nod (the head a row down onto the food, which stays
  where it was, the eyes shut: the frame's `eyes`; the chest's row folded away, the legs never move);
  lowered again, chewing with the eyes shut. The food is the icon in the hand as it is carried (`a` -1),
  its middle at the hand's mark and the hand's skin over it, so the frames draw the hand beside the food,
  not across it; turned and from the side it is before the face, from behind the body hides it (`f`
  false) and the elbow and the nod show the bite. An icon is not mirrored with the figure, so in a west
  direction one of an even width sits a pixel further from the body than in its east one.
  The mow's four frames too, with the scythe in both hands (`tools/art/player_mow_art.gd`, reviewed with
  the user 2026-11-20; the scythes play it): the snath rises from the hands to its far end and the blade
  hangs from there with its point at the ground (the user's note: the blade down, not up); the hands hold
  the snath at its middle, not at its end (the user's note), so its near end comes out two pixels past
  them and always shows past the far fist (the user's note): from the side over the waistband and then on
  the hip under the arm, from the front and turned past the fist's outline, from behind a pixel under the
  fists. The scythe is held out to one side, its
  far end goes a pixel up as the torso leans after it, then it is swung past the feet to the other side
  (crouched, the chest's row folded away) and the body stands again with the scythe where it stopped: the
  mower's right to their left in every view, so from the front and the side from the picture's left to
  its right (from the side from behind the back forward), from behind from the right to the left, where
  it ends behind the body with the left hand on it (`f` false). A scythe keeps its blade down wherever it
  is, which turning its shape does not give, so the frames draw it whole as the bow's do (`scythe`;
  `ToolArt.DRAWN` lists the shapes a frame draws, `ToolArt.drawn_by_frame`), and both hands hold it
  (`two`). The scythes leave a trail (`trail: true`): on the strike a shallow arc from where the blade
  was, over the feet's row and up to the blade, in front of the character (the user's note); from behind,
  pieces low on the ground behind the figure. In every view but the side one the scythe's mark is above
  the frame's neck, which no build moves: a stocky body's hands go a pixel out along the snath and the
  blade stays where it is drawn, whole in the frame. A
  work drawn so carries the way the tool points (`a`, `ccw`, `f`), where the hand holds it
  and how far up its length (`slide`: `ToolArt.turned` moves the head nearer the hand, the shaft's end
  past it, leaving `ToolArt.SLIDE_LEFT` rows beyond it, so a short thing is held as it is), so
  `PlayerArt.pose` takes them from the frame instead of `WORKS`; its west directions are the east ones
  mirrored with the tool. `PlayerArt.whole_frame` gives a column's frame drawn so.
  The reach's four frames are drawn whole too (`tools/art/player_reach_art.gd`, reviewed with the user
  2026-11-20; bare hands play it, and every thing with no work of its own: gathering, placing, building):
  the hand lifted to the waist; a crouch (the chest's row folded away: the legs never move) with the arm
  stretched down along the leg, the hand a row over the ground; still crouched, the arm short again;
  standing, the hand brought up to the shoulder. The arm lies against the body in every frame, with no
  outline between them, and stretches only together with the crouch (the user's rules). Turned, from the
  side and from behind the body stands a row lower, so the crouched arms are a row shorter and the hands
  are as high over the ground as from the front; from the side the arm goes down and forward in front of
  the body, from behind it is at the picture's right, behind the body. The frames turn nothing (`a` -1):
  what the hand holds is drawn as carried, at the hand's mark.
- Looks (stage 3, PR 3 of the character editor): `src/shared/content/looks.gd` reads `player.yaml` `looks`
  (10 skin tones, 12 hair colours, 6 eye colours by place in their lists; 10 hair styles, 8 face options
  under the hair, 5 on the face, by id) and makes any look sound (`Looks.clean`: the server's check of a
  hello, a save). The character keeps it in `Character.looks` (saved in `character`, {} until given): the
  server gives a new character the looks of its hello (7th field, `ServerList.player_looks` from the
  «Персонаж» tab), single player `LocalHost.take_looks` after the save is read; a character met again keeps
  its own (it belongs to its world); bots look random. It reaches the own client in `YOU` (the state) and the
  others as field 18 of `PEOPLE`. `Figure.dressed(gear, looks)` puts `player/face/<face>.png`,
  `player/hair/<hair>.png` (none for bald) and `player/face/<on_face>.png` in the hair slot, drawn by
  `tools/art/player_looks_art.gd` (`HAIRS`, `FACES`, from the design `chibi_v7.py`). The colours are the
  shader's (`shaders/looks.gdshaderinc`, in `sprite`, `sprite_water`, `sprite_mirror` and the preview's
  `figure_preview.gdshader`): the pictures are drawn in the default look's colours, and `Figure.paint` sets
  pairs of whole sRGB colours to swap (the skin's three, the hair's three, the iris, and stubble, freckle,
  blush and scar made of them, `Figure.MADE`). No other picture of the figure, the clothes or the tools held
  may use those colours (`view_test`). The sheet is not recoloured on the CPU: 475 thousand pixels a layer
  take seconds on a phone. The «Персонаж» tab (`character_page.gd`) has a row for each.
- Body forms (PR 3b; no sex is picked, every form is for everyone): the looks' `build` (thin: arms a pixel
  wide; normal; stocky: the torso two pixels wider, the arms and the hanging hands a pixel further out) and
  `figure` (straight; bust: the shade `V` under it from the front, two pixels forward from the side; curvy:
  the bust and the thighs a pixel wider, the seat a pixel back). `tools/art/player_forms_art.gd` says what
  each draws otherwise, of the rows of any body drawn (`FormsArt.body`: the stand's and the walk's frames alike;
  stocky widens a frame drawn whole by the side of the picture each pixel is on, so `PlayerArt.pose` moves a
  hand's mark there with it, also a hand reaching across the middle); `make_sprites.gd`
  draws every layer, the hands' marks and the clothes again in each form and keeps a picture only where it
  differs from what the game takes instead:
  `player/forms/<build>_<figure>/<layer>.png`, else the build straight's, else the plain `player/<layer>.png`
  (`Figure._form_path`); clothes `worn/<look>/<build>_<figure>.png`, else `worn/<look>.png` (a mod's clothes
  drawn once fit every form roughly). `Figure.dressed(gear, looks)` names the form's layers
  `forms/<form>/<layer>`; a figure takes its form from them (`Figure.form_of`) for the fists and the hands'
  places (`Figure.anchors(form)`), so tools are held where its hands are.
- `src/client/ui/person_panel.gd` — the tab «Character» of the inventory window (the figure drawn big and turned, `figure_stage.gd` as on the
  «Character» tab of a new game,
  with what it holds and its shadow, the slots of what is worn and of the hands round it, the skills' strips under it); `src/client/ui/level_up.gd` — the effect of a skill's new level;
  `src/client/ui/death_screen.gd`, `vitals_panel.gd`, `body_feedback.gd`, `vibration.gd` — the death screen,
  the strengths' strips, the screen's response to damage (and an icy blue frame growing while the body is cold, from
  `Vitals.COLD` to `CHILL_FULL` below `FREEZING`, breathing while it freezes; and below `LOW_HEALTH` a crimson vignette, heavy in the corners, and a red wash beating
  like a slow heart, faster the weaker: each beat the vignette jumps in `HEART_REACH` of the screen and eases back, and the
  picture darkens and hardens for that moment, grade `heart`), the phone's vibration: `Vibration.PATTERNS` holds each event's pulses,
  pauses and strength (the strength only in the Android build; the browser's Vibration API takes the pattern
  without it, Safari has none) and the step of the setting «Vibration» it needs (off, important only, usual,
  all); `haptics.gd` (a child of the HUD) watches the character (a bite on the line, death, low health's heart,
  waking up), the season, team invitations, things made, picked up and fires lit near; the rest buzz where
  they happen (a strike, a felled tree, a shot that hits, a catch in `Controls._did`, a landing and water in
  `Steps`, thunder in `Nature` (the one heard is felt as a sharp pulse and a fading boom, at most once in 8 s, by its envelope in
  `src/client/audio/thunder_shape.gd`; the six variants are built by `tools/make_sounds.gd` from band loudness measured off
  recorded peals, `tools/sound/thunder_bands.py` → `thunder_bands.gd`, then held by a limiter so they are loud; `Vibration.rumble`; a flash whose bolt is on the screen is heard at once from the peal's peak, `ThunderShape.peak`, with the strike's pulse, so flash, roar and buzz come together), a thing set down in `Props._land`, a warning beast in `Voices`, buttons in
  `Sound`, a full bag and a broken tool in the client's `Character.say`, chat lines in `ChatBox.hear`).

**Skills** (decision 164). Twelve skills are a mod's data (`content/core/data/skills.yaml`, the kind `skills`,
the registry `src/shared/content/skills.gd`): Gathering, Chopping, Digging, Crafting, Building, Cooking,
Hunting, Fishing, Swimming, Farming, Hardiness, Strength; the engine asks for a skill by the work's role (`Skills.of_role`). What the
character has learned is `SkillSet` (`src/shared/game/skill_set.gd`, `Character.skills`): points by the
skill's id, 10 levels, the first for `first` (120) points, each next `growth` (1.45) times dearer (the tenth —
about three hours of pure work). The points are seconds of useful work: a rule gives a stroke that did
something (`WorldActions.skilled`: digging, chopping, mowing and gathering, building, a blow at a beast), a
recipe by its time (`Workshop`, `gain_recipe`: the same recipe in a row gives less and less, `REPEAT_FADE`),
swimming by the time on the way (`Character.update`), a whole thing by `each` (a hunted beast, a caught fish).
Hardiness (role `endure`) grows by `each` (4) points for every health lost (`Vitals.suffered`, golden too) and
`Character.ENDURE_HARDSHIP` a second hungry, thirsty, cold or hot (`Character._endure`); its `health` (50) adds
a cell of `Vitals.CELL` to the most health every second level (`SkillSet.health_bonus`).
Strength (role `carry`) grows by a point a second of walking with at least `Character.CARRY_FROM` (70%) of the
carrying limit on the back, `CARRY_OVER` (2) past it; its `carry` (60) adds an even share, 6 kg a level, to
the limit (`SkillSet.carry_bonus`): 40 kg at none, 100 kg at the last. `Character._on_skills_changed` sets
`Inventory.weight_limit` whenever the points change, on the server and on a client's copy (told by `SKILLS`),
so the limit needs no field of its own on the wire or in the save.
Digging out a block placed by a player and placing it again where such a one was dug out give no experience
(`WorldActions._built`, `_undone`, not in the save). A skill makes the hand better, not the tool (the balance
model `docs/balance/GAME_BALANCE_DESIGN.md`): the time of a stroke and of a recipe × `pace` (down to 1 / (1 +
`speed`) at the last: with `speed` 1, by default, twice as fast), the speed in water × `boost` (swimming at
the last — twice) (`Body.swim_scale`); the price of a stroke in strength × (1 − `effort` × the share of
levels) (`Character.act(action, role)` → `Vitals.spend`); a stroke with the chance `care` × the share does not
wear the tool (`Workshop.use_tool`, the tool's role — `Tools.ROLE_OF`); a blow at a beast × (1 + `might` × the
share), rounded (`SkillSet.blow`; `might` only for Hunting, the number of blows at a tree and a cell a skill
does not change). The test «Player speed» (`Settings.player_speed`) speeds up both the step (`Body.speed_scale`,
in water too) and work: `Character.haste` divides the time of a stroke (`Requests._do` shortens the rule's
answer, the client's own strokes — `Controls._hasted`) and of a recipe (`Workshop.time_of`, `_pace`). One more
thing with a chance up to `yield` (`SkillSet.extra`): gathering (berries, seeds and twigs from trees, mowing),
chopping (a log at the stump), fishing (a second fish), cooking and butchering a carcass (`Workshop.yield_role`:
a recipe of cooking or with a beast's carcass, `AiRules.CARCASSES`). A skill decides quality too (decision
181, `src/shared/game/quality.gd`): what is got (gathering, chopping, digging, hunting, fishing, reaping) is
better by the skill's `quality` at the last level (`SkillSet.quality_most`, 30 by default), what is made is no
better than the ceiling `Quality.skill_cap` (50 without a skill, for Crafting and Cooking up to 100). A reserve
of blows of a skilled hand (negative wear) stays at the things of old saves, new ones do not get it. The sum
of levels gives the reserve of territory cells (`Territory.skilled`, `docs/systems/territory.md`). It is stored
as the part `skills` of the player's save; the server sends the client `Protocol.SKILLS` no more often than
`PlayerLink.SKILLS_EVERY` and at once on a new level, the copy on the client (`SkillSet.take`) says `leveled`.
The tab «Character» of the inventory window (`person_panel.gd`) draws a strip per skill: a division per level (only the skill: a
tool's strength is in the item's chips, not on the scale), a thin line shows the way to the next; the hint —
the level, what it gives now (faster, cheaper in strength, an extra piece, a blow, the durability of things,
care), the tool in the hand that the skill leads, the description. The time in the crafting window is with the
skill (`Workshop.time_of`). A new level (`src/client/ui/level_up.gd`, choice 7А with a notice in the corner):
the screen's edges briefly glow gold (`BodyFeedback.glow`), golden stars rise round the player
(`Effects.level_sparks`), `level_up` sounds (`sounds/ui`), in the list of notices at the top left — «★
Chopping: a new level» with the level and the speedup (`Hud.notice`). The first points that come from the
server at login do not raise a level. The test setting «Skill growth» (×1, ×2, ×20, ×200, `Settings.skill_rate`)
multiplies all points (`SkillSet.rate`).

**Light in the hand.** A torch, a candle, a lantern (an item with `light`) are consumables, like food: in the
bag a stack of whole ones, one taken into the hand burns `burns` seconds (`Character.burning`: how much each lit
one has burnt, in the save `character`), burnt down it is removed from the stack, and the next is lit; one put
away waits as much as it has left. Light has no wear (`durability`), the bag drops it at old saves. The
character's copy on the client learns about burning once per `BURN_TELL` seconds and at burning down; the hand
on the panel shows the remainder by a strip (`HotbarSlot.fill`), the bag — by time.

Stamina (`Vitals`): work priced from `WORK_COST` makes the body busy for `BUSY` seconds, rest at that time is
`WORK_REST` of `REST`: strength is spent on work, not on time (a steel axe tires in 15 s in a row, a stone one
in 88, hands in the ground — never).

**Data.** Items (`food`, `spoils`, `rots_to`, `drink`, `empties_to`, `fills_to`, `fills_salty_to`, `holds`, `bedding`, `warmth`, `heal`,
`heal_time`, `weight`, `stack`, `light`, `burns`, `sprite`, `anim`, `hands`, `trail`; for food `heal` and `drink` are on
top of satiety: roast heals and quenches a little, `Character.eat`); the creature `core:human`; clothes on the
figure — `Figure.dressed(gear)`: the bare layers of `player.yaml` `naked` (body, loincloth, hair), between
them the pictures of what is worn `sprites/worn/<look>.png` of the thing's bundle (the field `look`): legs,
feet, the body under the hair, the head on top; they are drawn by `tools/make_sprites.gd` (`WORN`: the shape
`PlayerArt.SHAPES` and three colours). What other players wear comes as the 14th field of `PEOPLE`, their
looks as the 19th (index 18). The
figure's layers and works — `content/core/sprites/player.yaml`, the tools' sheets in the hand —
`sprites/held/` of the tool's bundle. The parts `inventory`, `vitals`, `character` (from the server's
character, `game.host.player`), `hands` (from the client) are saved.

**Pitfalls.** Connect the bag's and queue's signals by a method, not by a lambda with `self` (a cycle of
references, the RefCounted is not freed — see the comment in `src/shared/game/character.gd`). `var i := expr`
where `expr` is a Variant (a field of an untyped object) is a parse error: type it explicitly; `typed_array =
expr if c else []` is a runtime error that silently cuts off the function.

**Tests.** `tests/unit/skills_test.gd` (levels, experience for work, crafting, land),
`tests/unit/character_test.gd` (`inventory`, `wear`, `gear` (bags on the back), `torch`, `spoil`, `vitals`,
`warmth`, `thirst`, `sleep`, `changes`, `death`, `fall`, `sack_ends`, `graves`, `bed_respawn`, `poultice`),
`actions_test.gd` (`drinking`), `tests/unit/body_test.gd` (`walking_rules`, `water`, `bog`, `slopes`, `steps`,
`ground`), `tests/save_test.gd`, `tools/sheet.gd` (the sheet of frames to PNG).

**In more detail.** `plan/design/character.md`, `plan/design/ui.md` (the bag, death).
