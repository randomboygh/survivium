# Person panel, skills, light in the hand

Part of [The character: bag, strengths, skills, body, death, sprite](../character.md). The «Character» tab, skills, light in the hand.

- `src/client/ui/person_panel.gd` — the tab «Character» of the inventory window (the figure drawn big and turned, `figure_stage.gd` as on the
  «Character» tab of a new game,
  with what it holds and its shadow, the slots of what is worn and of the hands round it, an empty one with a faint grey
  picture of what goes there, `slot_<place>`, an empty hand bare, `hand_left` / `hand`, the skills' strips under it); `src/client/ui/level_up.gd` — the effect of a skill's new level;
  `src/client/ui/death_screen.gd`, `vitals_panel.gd`, `body_feedback.gd`, `vibration.gd` — the death screen,
  the strengths' strips, the screen's response to damage (and an icy blue frame growing while the body is cold, from
  `Vitals.COLD` to `CHILL_FULL` below `FREEZING`, breathing while it freezes; and below `LOW_HEALTH` a crimson vignette, heavy in the corners, and a red wash beating
  like a slow heart, faster the weaker: each beat the vignette jumps in `HEART_REACH` of the screen and eases back, and the
  picture darkens and hardens for that moment, grade `heart`), the phone's vibration: `Vibration.PATTERNS` holds each event's pulses,
  pauses and strength (the strength only in the Android build; the browser's Vibration API takes the pattern
  without it, Safari has none) and the step of the setting «Vibration» it needs (off, important only, usual,
  all; the default is all, and a saved choice is kept); `haptics.gd` (a child of the HUD) watches the character (a bite on the line, death, low health's heart,
  waking up), the season, team invitations, things made, picked up and fires lit near; the rest buzz where
  they happen (a strike, a felled tree, a shot that hits, a catch in `Controls._did`, a landing and water in
  `Steps`, thunder in `Nature` (the one heard is felt as a sharp pulse and a fading boom, at most once in 8 s, by its envelope in
  `src/client/audio/thunder_shape.gd`; the six variants are built by `tools/make_sounds.gd` from band loudness measured off
  recorded peals, `tools/sound/thunder_bands.py` → `thunder_bands.gd`, then held by a limiter so they are loud; `Vibration.rumble`; a flash whose bolt is on the screen is heard at once from the peal's peak, `ThunderShape.peak`, with the strike's pulse, so flash, roar and buzz come together), a thing set down in `Props._land`, a thing taken up in the build mode in `BuildMode` (`lift`), a figure of the blueprint laid or taken off or a ghost thing set in it there (`lay`, «usual», on the request's answer, `BuildMode._laid`), a block set by the blueprint or the brush in `Controls._did` (`block`, «all» only; the user's picks 2026-11-27), a warning beast in `Voices`, buttons in
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
