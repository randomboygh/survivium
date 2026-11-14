# Beasts

Status: ACTIVE. A Russian copy: [wildlife_RU.md](wildlife_RU.md).

**Purpose.** The world's animals. A kind sets only properties; who is food and a threat to whom is derived by
shared rules. Beasts appear around people, roam, graze, rest outside their hours, flee from threats, hunt when
hungry; packs follow a leader, flyers roost in crowns, climbing walkers climb trees, swimmers keep to open
water, a kind with `biomes` appears only on its own land.

**Files**
- `src/shared/game/wildlife.gd` — the rules: `start(seed)`, `update(delta)`, `count(kind)`, `wanted(kind)`;
  `people` — all the players. Beasts belong to the ground: each chunk made to the end (`_made`: the stage
  `SHAPED`) in the square `SPAWN_REACH` of 80 cells around a player gets its own (`_settle_new` once per
  `SETTLE_EVERY` 1 s → `_populate_chunk`, nearest first, at most `SETTLE_MOST` 6 chunks a frame: after a
  teleport or a respawn the rest come in the next frames, not in one long one): of a kind — its `count` per square `ROAM` (`ROAM_CHUNKS` chunks),
  multiplied by the share of the kind's biomes in the chunk (2×2 points of the layout), the fractional part is
  rolled, in packs; no nearer than `START_AWAY` 8 units to people. While a chunk's ground is kept, its beasts
  live; with forgotten ground (`Session.DROP`) those that nobody sees leave too (`_leave`), and a chunk made
  again gets them again. The eaten, once per `RESPAWN_EVERY` 15 s, are refilled (`_plan_refill` notes each kind round each player, `_refill_some` does
  `REFILL_MOST` 2 of them a frame; `_refill` does all at once, for the tests): if a kind is
  fewer than the shares of the chunks around a player give, by more than `REFILL_SLACK` — new ones come
  farther than `NEAR` on made ground; if more — the extra invisible ones leave (`_thin`, frogs thin out like
  that after rain); a beast with no viewer (`near` off: not on the screen of any player — the rectangle that
  the client sent with its input, turned with the camera, no more than `NEAR` 28 units in each direction,
  without a screen the circle `NEAR`; `look_from` is called by the session before a step) walks by steps once
  per 0.1 s; the pushes of bodies by mass (`_jostle`: the beasts near on the ground are sorted from west to
  east and each is checked only with those within reach to the east; the body's radius is stored in
  `Animal.radius`; `_shove` takes the floor from the beast's last look, like `_move`; `pushes` for the
  player). A beast has a number `id` (by it the client's copy knows it). The signals `born`, `gone`,
  `stepped`; `moved` — the beasts that stepped in the last `update` (by them the server collects a snapshot,
  `PlayerLink._snap`). Deciding (`_decide`), a beast goes through only the kinds that are a threat, food or
  its own to it (`_cares`), by the lists of beasts by kinds (`_kin`: led by `_add` and `_remove`, rebuilt
  when the number of beasts is not the one they were collected for).
- Hunting: `in_front(at, dir)` — the beast on which a blow falls (the nearest on the ground within
  `STRIKE_REACH` ahead, point-blank — from any side, with `health` above 0), `hurt(a, power, from)` — a blow:
  the beast loses `power` (a weapon's blow with the addition of the Hunting skill, `SkillSet.blow`) of health
  and flees `HURT_FLEE` seconds from the place of the blow (even one that does not fear people), without
  health it is removed (`gone`). The blow is dealt by `WorldActions.strike` (the action button: a sword and a
  knife hit the beast ahead first, anything else in the hand — first only a beast point-blank,
  `STRIKE_CLOSE`, and a far one — when there is nothing else to do), it also puts the kind's carcass
  (`carcass`) on the ground. `WorldActions.shoot` shoots a weapon with `range` (a spear, a sling, a bow): one
  `ammo` from the bag at a time (a spear is thrown itself), where the player looks (by a tap on the ground —
  where it was tapped), at the first beast on the way within `range` cells and the angle `AIM_CONE` if a solid
  cell has not stood earlier; what was shot lies at once on the ground where it fell, and the client draws its
  flight from the answer (`shot`, `Props.fly_shot`). Other players see only the wounded beast and the fallen
  arrow.
- Fishing: `src/shared/game/fishing.gd` (`Fishing`, the session's step in `step_things`) — lines in the water.
  `WorldActions.fish`: a rod (the class `rod`, `Tools.can_fish`) without a line casts a float with the action
  button (by a tap on water — where it was tapped) into open water within `range` cells (`water_ahead`,
  farther from the shore by `CAST_OUT` cells, `_cast_out`), with one bait from the bag on the hook (the rod's
  `ammo`); with a line in the water — pulls it out (`_pull`). A fish is a real swimmer with the field `catch`
  (the kind `creatures`, the bundle «Fish» and the perch): once per `LURE_EVERY` with the chance `LURE_BAIT`
  (with bait) or `LURE_BARE` (without) the nearest within `LURE_REACH` of the float swims to it (`Animal.bait`,
  the state `bait`: fears nothing else), at the float it bites for `BITE` seconds (`Character.bite`); one
  pulled out during the bite leaves the world (`Wildlife.take`) and goes into the bag as the item `catch`, and
  the client draws its flight to the angler (`shot`); one not pulled out eats the bait and flees from the
  float. The line is reeled in by itself if the angler moved away (`WANDER`), put the rod away, fell asleep,
  died or the water froze; one cannot cast onto frozen water. The server tells the client about its line by
  the event `LINE`, the others — in `PEOPLE`; the action button stays pressed («Reel in», at a bite «Hook»),
  the figure holds the rod stretched out (the blow frame `slash`), `src/client/view/fishing_line.gd` draws the
  line from the rod's tip (`SpriteSheet.tips`) and the float, diving at a bite
  (`shaders/fishing_line.gdshader`).
- Fire (`_find_fires` once per `FIRE_EVERY` 0.5 s over `Placed.scarers`, the things and lights whose item
  `scares`, kept as they are put and taken; `_fire_near`): burning campfires and fireplaces, placed
  lights and light in people's hands keep beasts with `fire_wariness` from 0.5 away for the `scares` of their
  item (world units; a fleeing one keeps `FIRE_WARY` times farther): a beast in this circle flees from the
  fire as from a threat and does not choose a place for a walk inside it. A hungry (`BOLD_HUNGER`) pack of
  meat-eaters in winter comes up to a light in the hand, but not to a campfire. To fish (`fire_wariness: 0`)
  fire is indifferent. `Wildlife.placed` is given by the session.
- Tame ones (`ActionsTame`, decision 178): an `Animal` has an owner `owner` (`Player.id`, −1 — wild), a place
  `stay` (INF — follows the owner), `fed`, `fed_at`, `shorn_at`. A kind with `tame_food` does not flee from a
  person with this food in the hand. A tame one does not fear people, flees only from threat beasts and fire,
  otherwise `_keep_by_owner`: keeps within `TAME_FOLLOW` of the owner (`owner_of`) or roams within `TAME_ROAM`
  of a place; without an owner it stays in the game. It is not led away by `_leave`, `_thin`, not counted by
  `_count_near`; on forgotten ground it waits. `tamed_list` / `add_tamed` — saving (the world's field «tame»,
  only numbers for JSON; before `start` they wait in `_kept_tame`), `breed` — a young one, `release` — a tame
  one from a live trap, released from the hand. To clients a tame one is no different from a wild one (the
  button's captions — only in single player).
- Attacks (`_fights`, `_fight_step`, decision 178 item 3; the rules are shared, the kinds differ by
  properties): only a kind with `bite` (health per bite) goes at people — a boar, a bear, a wolf. One that
  does not fear people (`human_wariness` < 0.5) holds its place: to one who came nearer than `CLOSE` of its
  sight it stands and growls (`warn`, `WARN` s, the cry `alarm`, the attack frame, to the player «… threatens:
  step back»), if they did not leave — it charges (`charge`); one hit by it fights back (`_fights_back`, while
  health is above half), otherwise it flees. A meat-eater hunts a person (`hunting`) when awake and very hungry
  (`BOLD_HUNGER`), and its pack in sight is stronger than the person (`_strong_enough`: the pack's masses, in
  winter ×`WINTER_BOLD`, as prey — `AiRules.PREY_RATIO`, against the person's mass ×`PERSON_WITS`, less by
  wounds, ×`ARMED` with a weapon in the hand): three wolves in winter go at a wounded person, not at a
  healthy one, in summer they pass by. Point-blank (`BITE_REACH` beyond both bodies) the beast jumps (`bite`,
  `BITE_TIME`, the attack frames) and bites if the person is still near: `Vitals.wound(bite,
  "animal:<kind>")` (on the death screen «A beast mauled you»), a push `Body.knock`, «… attacks!», the signal
  `bit`; the next bite in `BITE_EVERY`. A defender falls behind after `DEFEND_BITES` bites or `DEFEND_RAGE`
  s, a hunter — when the prey is dead, unreachable or the rage (`HUNT_RAGE`, anew with each bite) has passed;
  after that `CALM` s it does not touch people. Fire (`_fire_near`) breaks off an attack; in water, in a boat
  (`riding`) and above a step a person is unreachable; a fence and a closed wicket, gate, door (a thing taller
  than a cell and a half, `_fenced`) are a wall for a beast: a pen keeps tame rabbits; tame ones do not
  attack. The rule `Rules.animal_attacks` (the switch «Beast attacks» on «Testing») turns it all off.
- Under ice: a fish (swims, does not fly and does not come ashore, `under_ice_swimmer`) in frozen water two or
  more cells deep swims under the ice (`under_ice`), appears there too; a duck and a frog — no.
- AI debugging (decision 184): an `Animal` has a cause `cause` — what it flees from (`person`, `fire`, `hurt`,
  `alarm` or a beast's kind), whom it hunts (a kind), `graze`, `lead`, `owner`; it is set by `_decide`.
  `mind(a)` — what is on a beast's mind (the state, the cause, and in a fight with a person `hunt_person` or
  `defend`, hunger, health, the goal, what it flees from or goes to, the leader, the owner, rage, calm, stands,
  wounded, sight, at what distance it fears people and growls, whether it thinks every step), `minds_near(at,
  reach)` — all near. The server sends them by the event `MINDS` once per `PlayerLink.MINDS_EVERY` 0.25 s
  within `MINDS_REACH` 30 units while the player asked (`AI_DEBUG`: in single player always, on a server only
  to the host — `Requests.may_debug`). `src/client/view/ai_debug.gd` (`AiDebug`, the switch «Beasts' AI
  debugging» in «Debug», F4) draws over the beasts a caption (what it does and why, hunger, health; the
  interface's letters, outlined, the size of the names over the people, on a layer under the HUD) and lines:
  to the goal (grey), from what it flees or whom it goes at (red, orange on a hunt, green to a float), to the
  leader (blue); a tap on a beast selects it (`pick`, the hands do nothing meanwhile): a detailed card and
  circles on the ground — sight (white), «fears people nearer than» (yellow), «growls nearer than» (red). The
  line shader is not warmed up beforehand (debugging). `reread()` — the kinds were reread (hot reload): the
  caches `_seen`, `_caring` anew, beasts of dropped kinds leave.
- `src/shared/content/ai_rules.gd` — the shared rules by properties: `reaches`, `is_food`, `is_threat`,
  `is_active`; `AiRules.SPECIES`.
- `src/client/net/remote_wildlife.gd` — the beasts' copy on the client from the server's events `animal`,
  `snap`, `animal_gone`, `step` ([network.md](network.md)): its own `Animal` with the fields the views read,
  the same signals. Over a socket (`smooth`) the snapshots come ~10 times a second and unevenly: a beast
  glides from the place where it is drawn to the new one in the time between two snapshots (`glide`, called by
  `Creatures` every frame; farther than `GLIDE_MOST` — at once); in one's own world a snapshot every frame is
  taken as is.
- `src/client/game/creatures.gd` — draws the copy's beasts: frame 0 at rest, the steps' frames by steps, the
  wings' frames in the air; it sets the picture anew when the server moved the beast (`Animal.fresh`).
- `src/client/audio/voices.gd` — the voices (`calls`) and the cry of fright (`alarm`);
  `src/client/world/tracks.gd` — tracks.

**Who uses it.** The world session (`session.gd`: creates, `start_wildlife` after the world is ready, the step
`step_wildlife` every frame from Main), `player_link.gd` (events for the client); the copy — `creatures.gd`,
`voices.gd`, tracks, `fire_shadows.gd` (the beasts' shadows by a fire); tests and `tools/shot.gd` write into
`main.session.wildlife`.

**Data.** The kind `creatures` (`health`, `carcass`, `bite`, `mass`, `diet`, `speed`, `sight`,
`human_wariness`, `fire_wariness`, `active`, `count`, `sprite`, `frames`, `walk`, `hop`, `attack`, `views`,
`flies`, `swims`, `ashore`, `hops`, `after_rain`, `flight`, `tints`, `flock`, `roost`, `likes`, `biomes`,
`calls`, `alarm`, taming: `tame_food`, `tame_feeds`, `wool`, `wool_days`, `breed_days`, `herd`, `trapped` — a
live item from a live trap) in the bundles `content/animals/<beast>/`; the picture is the bundle's
`sprites/creatures/<sprite>.png`: a row per side (`views`: 1 — from the side; 3 — side, front, back), in a
row `frames` frames — standing, `walk` frames of a step or wing strokes, the last `hop` of a flyer — hops on
the ground (crouched, in the air; a flyer without `hop` is a butterfly, `Wildlife.sits_still` — does not walk
on the ground and is not pushed: it either flies or sits in place with folded wings and now and then, each at
its own time, flaps them (`SIT_GAP`, `SIT_FLUTTER`, `SIT_FLAP_RATE`)), after them `attack` — an attack (a
dash to a bite, the first — while the beast warns), the others — of rest (drawn by `tools/make_creatures.py`
with `tools/creature_kit.py`, the sparrow — `tools/make_sparrow.py`, the crow, owl and duck —
`tools/make_birds.py`, the frog — `tools/make_frog.py`, fish — `tools/make_fish.py`, the hare —
`tools/make_rabbit.py`, the squirrel — `tools/make_squirrel.py`, the fox — `tools/make_fox.py`, the deer —
`tools/make_deer.py`, the boar — `tools/make_boar.py`, the bear — `tools/make_bear.py`, the wolf —
`tools/make_wolf.py`, the wild cat — `tools/make_cat.py`, the hedgehog — `tools/make_hedgehog.py`).
`creatures.gd` chooses the side by the movement on screen (`TURN_BIAS`), a step — by the path walked (a
flyer's hops — `HOP_STEP`), the frames of rest — now and then (`IDLE_GAP`, `IDLE_HOLD`, the last —
`IDLE_LONG`). The sun's shadow is cast by the sprite with its own frame, turned to the light
(`sprite.gdshader`); for a flying one (the frames of a flyer's strokes) the shadow is the frame of the same
stroke from the row «from the front», laid flat at mid-height, with the wings across the path (`flat_shadow`,
`shadow_uv`): the bird from above, not a profile stretched by the sun. The check is the shot `animal-shadows`.
An example of a beast by data and a picture alone: `content/animals/sparrow/README.md`.

**Limits.** A walker does not reach a swimmer and the other way round, a flyer reaches both. The column's
biome is taken from `gen.lay_out`. There is no diving; the beast's side on the client is derived from its
movement, the server does not know it. The voices are brought by a bundle as ready `.wav` (the synthesis — a
table in `tools/make_sounds.gd`).

**Tests.** `tests/unit/wildlife_test.gd` (`ai_relations`, `wildlife`, `climbers`, `biomes`, `swimmers`,
`fishing`, `birds`, `shore`, `jostle`, `hunting`, `fire`, `taming`, `attacks`; a pack waits for the ticks of
thinking, not for the order of random numbers).

**In more detail.** `plan/design/creatures-ai.md`; `plan/architecture/ai.md` — the idea of the behaviour
engine (the formulas are marked as a draft, in the code it is simpler).
