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
  is no fall, the count goes from it. The test switch «Fall damage» (`Vitals.falls` off) makes every fall harmless.
- `src/shared/game/inventory.gd` — the bag: `SLOTS` 16 (`base`), the first `HOTBAR` 8 — the bar below;
  stacks, weight (40 kg with no slowing), sorting, moving into a chest, wear (`wear_tool`, `mend`); the signal
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
  the back (`wear_on: back`, `bag_slots`) adds cells after `base` and itself lies in the first `base` (it does
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
  `sleep`, `Figure._lay_down`), above them small letters «z» rise, grow and melt in turn (`player.gd` `snore`,
  `_snore`); one wakes up by oneself when rested by day, from a wound or in water. While all sleep, the night
  goes `Session.SLEEP_SPEED` times faster. `fatigue` off — the test switch «Fatigue»: energy does not fall,
  work and swimming spend no strength (`spend`, `can`), one cannot drown. A poultice (`heal` with `heal_time`,
  the «Plants» bundle `plants/moss`: moss and a bandage by a campfire): `Vitals.mend` returns its health
  little by little over `heal_time` seconds (`mending`, `mend_rate`, in the save) — to the hungry and the
  frozen too; a second is not laid while the first is healing. A bandage (`heal` without `heal_time`) heals at
  once. Water `water` falls by `THIRST_PER_DAY` per game day (in heat `THIRST_HOT` times faster); below
  `THIRSTY` — like hunger (no healing, rest twice as slow, stamina up to `HUNGRY_CAP`), at zero it wounds
  (`hurt_by` "thirst", «You died of thirst»). `drink(amount)`; `thirst` off — the test switch «Thirst». One
  drinks at fresh water with an empty hand (`WorldActions.drink`: the action button facing water within
  `DRINK_REACH` or a tap on water; `fresh_water` — a lake, a river, a swamp, not the sea), an empty vessel in
  the hand (`fills_to`) is filled there too; a full one (`drink`, `empties_to`) is drunk as food
  (`Character.eat`). Body warmth `warmth` (0..`MAX`, comfortable `COMFORT` 50) and getting wet `wet` (0..1):
  `warm(days, feel, …)` pulls the warmth to what follows from the felt temperature (between `COMFY_LOW` and
  `COMFY_HIGH` — comfortable), below `COLD` there is no healing, rest is twice as slow, stamina up to
  `HUNGRY_CAP`; below `FREEZING` frost wounds (`hurt_by` "cold"); above `HOT` stamina up to `HOT_CAP`. Rain and
  snow wet, water — through at once, it dries in air, under a roof faster, by a fire fastest. `cold` off — the
  test switch «Cold and heat».
- `src/shared/game/warmth.gd` — how many degrees where the body stands: `air` (the middle of the biome's
  `warmth` window between `COLDEST` and `WARMEST`, the season `SEASON`, night `NIGHT`, rain/snow/wind without a
  roof), `fire_heat` (a burning campfire within `FIRE_REACH`, weaker as the fuel runs out), `clothes` (the sum
  of the `warmth` of what is worn), `feel` (fire, clothes — wet by half, a wet body −`WET_CHILL`, a roof
  +`ROOF`, in water colder than air). Counted by the character's step (`_warm`); the strip with a thermometer
  and a drop in `vitals_panel.gd`.
- `src/shared/game/body.gd` — the body on the grid: `step(at, delta, jump)`, slopes and steps, water and
  swimming, a leaning ladder (`_climb`: the body in the cell of a link of `WorldData.ladders`, or above the top
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
  not to confuse it with notices and signs; `person_gone` removes it. It does not step with a body, the
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
  (for others — above the name); movement or work interrupt it. The gestures' frames are columns 46–57 of the
  sheet (`tools/art/player_art.gd`, `MOVES`, with `lean` — the body's tilt; `tools/make_sprites.gd` draws the
  layers, the marks of the hands and what is worn anew). The wheel of gestures —
  `src/client/ui/gesture_wheel.gd` (a button beside the chat in the top row, the key C, digits 1–8 in the
  wheel).
- `src/client/view/figure.gd` — the sheet of the player's frames from `content/core/sprites/` by `player.yaml`
  (layers, the marks of the hands `hands.png`, a sheet for each tool in the hand or the item's icon), built by
  a part of a row per frame; `hands.gd` — what in the hands is seen on the sprite; `sprite_sheet.gd` — the
  sheet of frames by data.
- `src/client/ui/person_panel.gd` — the character in the inventory window (the slots of what is worn and of
  the hands, cells, the skills' strips); `src/client/ui/level_up.gd` — the effect of a skill's new level;
  `src/client/ui/death_screen.gd`, `vitals_panel.gd`, `body_feedback.gd`, `vibration.gd` — the death screen,
  the strengths' strips, the screen's response to damage, the phone's vibration.

**Skills** (decision 164). Nine skills are a mod's data (`content/core/data/skills.yaml`, the kind `skills`,
the registry `src/shared/content/skills.gd`): Gathering, Chopping, Digging, Crafting, Building, Cooking,
Hunting, Fishing, Swimming; the engine asks for a skill by the work's role (`Skills.of_role`). What the
character has learned is `SkillSet` (`src/shared/game/skill_set.gd`, `Character.skills`): points by the
skill's id, 10 levels, the first for `first` (120) points, each next `growth` (1.45) times dearer (the tenth —
about three hours of pure work). The points are seconds of useful work: a rule gives a stroke that did
something (`WorldActions.skilled`: digging, chopping, mowing and gathering, building, a blow at a beast), a
recipe by its time (`Workshop`, `gain_recipe`: the same recipe in a row gives less and less, `REPEAT_FADE`),
swimming by the time on the way (`Character.update`), a whole thing by `each` (a hunted beast, a caught fish).
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
The character window (`person_panel.gd`) draws a strip per skill: a division per level (only the skill: a
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

**Data.** Items (`food`, `spoils`, `rots_to`, `drink`, `empties_to`, `fills_to`, `bedding`, `warmth`, `heal`,
`heal_time`, `weight`, `stack`, `light`, `burns`, `sprite`, `anim`, `hands`; for food `heal` and `drink` are on
top of satiety: roast heals and quenches a little, `Character.eat`); the creature `core:human`; clothes on the
figure — `Figure.dressed(gear)`: the bare layers of `player.yaml` `naked` (body, loincloth, hair), between
them the pictures of what is worn `sprites/worn/<look>.png` of the thing's bundle (the field `look`): legs,
feet, the body under the hair, the head on top; they are drawn by `tools/make_sprites.gd` (`WORN`: the shape
`PlayerArt.SHAPES` and three colours). What other players wear comes as the 14th field of `PEOPLE`. The
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
