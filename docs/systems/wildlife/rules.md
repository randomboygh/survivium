# The rules of the beasts

Part of [Beasts](../wildlife.md). `wildlife.gd` and its chain of parts.

- `src/shared/game/wildlife.gd` — the rules, a chain of parts (decision 168; each extends the one before, callers preload `wildlife.gd`): `wildlife_base.gd` (the numbers, `Animal`, the floor and the water under a point, the list), `wildlife_spawn.gd` (the chunks' animals, the refill, the tamed), `wildlife_move.gd` (fires, senses, flocks, walking, flying, trees, the jostle), `wildlife_fight.gd` (the blow that lands, the attacks on people), `wildlife.gd` (`update`, `_decide`, the AI's debug): `start(seed)`, `update(delta)`, `count(kind)`, `wanted(kind)`;
  `people` — all the players. Beasts belong to the ground: each chunk made to the end (`_made`: the stage
  `SHAPED`) in the square `SPAWN_REACH` of 80 cells around a player gets its own (`_settle_new` once per
  `SETTLE_EVERY` 1 s → `_populate_chunk`, nearest first, at most `SETTLE_MOST` 6 chunks a frame: after a
  teleport or a respawn the rest come in the next frames, not in one long one): of a kind — its `count` × `DENSITY` 0.1 (animals are ten times rarer than the data's counts say; `Wildlife.density`, the tests raise it) per square `ROAM` (`ROAM_CHUNKS` chunks),
  multiplied by the share of the kind's biomes in the chunk (2×2 points of the layout), the fractional part is
  rolled; a fish (`under_ice_swimmer`) is not thinned by `DENSITY` (only by `density` as a share of it) and its `count`
  lives on `FISH_WATER_CHUNKS` 16 chunks' worth of water two cells deep (`_water_share`, every second column;
  the sea's water counts `FISH_SEA` 0.2, a chunk with a pond or a river in it at least `FISH_WATER_LEAST`, a whole
  chunk), so every pond, lake and river has its schools whatever land lies round it; in packs; no nearer than `START_AWAY` 8 units to people. While a chunk's ground is kept, its beasts
  live; with forgotten ground (`Session.DROP`) those that nobody sees leave too (`_leave`), and a chunk made
  again gets them again. The eaten, once per `RESPAWN_EVERY` 15 s, are refilled (`_plan_refill` notes each kind round each player, `_refill_some` does
  `REFILL_MOST` 2 of them a frame; `_refill` does all at once, for the tests): if a kind is
  fewer than the shares of the chunks around a player give, by more than the slack (`REFILL_SLACK`, at least the kind's flock size) — new ones come
  farther than `NEAR` on made ground; if more — the extra invisible ones leave (`_thin`, frogs thin out like
  that after rain); a beast with no viewer (`near` off: not on the screen of any player — the rectangle that
  the client sent with its input, turned with the camera, no more than `NEAR` 28 units in each direction,
  without a screen the circle `NEAR`; `look_from` is called by the session every `Session.LOOK_EVERY` 0.1 s) walks by steps once
  per 0.1 s (`FAR_STEP`), once per 0.4 s (`OUT_STEP`) when it is farther than `OUT_MARGIN` 6 units past every screen
  (`out`), at most `FAR_MOST` 16 such steps an update (after a long frame all are due at once; the next update
  starts where this one stopped, and a step is at most `LONGEST_STEP` 0.5 s long), and thinks half as often (`FAR_THINK`; one coming into view thinks within `NEAR_THINK`); the pushes of bodies by mass (`_jostle`: the beasts near on the ground are sorted from west to
  east and each is checked only with those within reach to the east; the body's radius is stored in
  `Animal.radius`; `_shove` takes the floor from the beast's last look, like `_move`; `pushes` for the
  player). A beast has a number `id` (by it the client's copy knows it). The signals `born`, `gone`,
  `stepped`; `moved` — the beasts that stepped in the last `update` (by them the server collects a snapshot,
  `PlayerLink._snap`). Deciding (`_decide`), a beast goes through only the kinds that are a threat, food or
  its own to it (`_cares`), by the lists of beasts by kinds (`_kin`: dropped by every `_add` and `_remove`, rebuilt
  at the next ask, and also when the number of beasts is not the one they were collected for; a test that
  changes `animals` itself drops them too, `_kin_of = -1`).
- Hunting: `in_front(at, dir)` — the beast on which a blow falls (the nearest on the ground within
  `STRIKE_REACH` ahead, point-blank — from any side, with `health` above 0), `hurt(a, power, from, by,
  lands)` — a blow: the beast loses `power` (a weapon's blow with the addition of the Hunting skill,
  `SkillSet.blow`) of health and flees `HURT_FLEE` seconds from the place of the blow (even one that does not
  fear people), taking fright only when the blow meets it, `lands` seconds on (half the swing, `BLOW_AT` in
  `actions_fight.gd`, frame 3 of the slash; a shot's flight; at most `LANDS_MOST`): till then it goes on as it
  went, so it does not bolt before the blade reaches it; without health it is removed (`gone`) at once. The blow is dealt by `WorldActions.strike` (the action button: a sword and a
  knife hit the beast ahead first, anything else in the hand — first only a beast point-blank,
  `STRIKE_CLOSE`, and a far one — when there is nothing else to do), it also puts the kind's carcass
  (`carcass`) on the ground; a kind with frames of death (`death`, the boar, the fox, the deer) lies there itself until the carcass is
  taken (the user's rule, 2026-11-20) by a hand: a tap on it (`pick_up`, hit round its middle) or the action button
  before it («Pick up», `body_ahead`, `take_body`; the user's pick, 2026-11-21), which waits while it falls and takes it
  by a press, not held on from the blow that killed it (`Controls._front_body`); the pickup by the feet,
  `pick_up_near`, leaves a body, `is_body`, which a kill in melee would else take at once: its carcass is a drop of its own where the beast stood, turned the way it went,
  naming the kind (`body`, and `tint`), which no heap joins, and the client draws it as the beast on its last frame of
  death (`Creatures.show_bodies`, below). `WorldActions.shoot` shoots a weapon with `range` (a spear, a sling, a bow): one
  `ammo` from the bag at a time (a spear is thrown itself), where the player looks (by a tap on the ground —
  where it was tapped), at the first beast on the way within `range` cells and the angle `AIM_CONE` if a solid
  cell has not stood earlier; what was shot lies at once on the ground where it fell, and the client draws its
  flight from the answer (`shot`, `Props.fly_shot`; an arrow leaves as the bow is loosed, on the third frame of
  the shot, half the swing later). Other players see only the wounded beast and the fallen arrow. A blow or a
  shot that hits names the beast in the answer (`animal`, its id), and the client draws it flinching as the
  blow meets it, an arrow as it arrives (`Creatures.flinch`, see below).
- Climbers (`roost: trees`, the squirrel): at the trunk of the tree it ran to it notes the foot `foot` and its
  spot on the crown `crown` and goes up the trunk at `CLIMB_SPEED` 2 units/s (`_climb`, its paws going: the
  client shows its back going up and its front coming down); up there a person is as near to it as to its
  foot, so the crown's height does not take it out of their sight (it used to run down and up again on tall
  trees, flickering on the tops); once the threat is gone it sits `STAY_UP` 4–10 s and comes down the trunk
  the same way, back up if a threat comes again on the way.
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
  died or the water froze over its float. A rod's `lure` (items, 1 by default) multiplies the chance of a fish
  coming (`Line.lure`; the winter rod of the bundle `tools/ice_fishing` has 2). The server tells the client about its line by
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
- Depth: a fish (`dives`, the same as `under_ice_swimmer`) swims at a depth of its own, `Animal.dip` world units
  under the surface (or the ice), from `DIP` to `DEEPEST` cells and `BED_GAP` cells over the bed at least
  (`water_room`, kept as `Animal.room` by `_look_floor`); it goes toward `dip_to` at `DIVE_SPEED` (`_dive`, a step
  of `_move`). A new way takes a new depth `DIVE_CHANCE` of the times, a school keeps its lead's, a fright sends it
  down to the deepest, the float of a line brings it up. Only `pos.y` changes: the client works the depth out from
  the water over the fish (`Creatures._sink`) and gives it to the shaders as the sprite's scale along y past 1. The
  fish is drawn after the water by `sprite_water.gdshader` (`whole`, the sprite's `material_overlay`), in up to three
  steps more of the water's colour the deeper it is; its `sprite.gdshader` picture (`shadow_only`) only casts the
  shadow on the bed. Only a fish near the surface jumps (`WaterEffects.FISH_JUMP_DEPTH`). Under ice the fish shows
  faint (every other texel, tinted to the ice: `ice_amount`), darker but whole under clear ice, as is in an open hole.
  The shots `fish-depths`, `fish-ice`, `ice-holes`.
- Winter fishing (the user's ask of 2026-11-15): `src/shared/game/ice.gd` (`Ice`, the session's `ice`, a step of
  `step_things`) keeps the holes in the ice, `WorldData.ice_holes` (column → the day it was cut, -1 for a crust;
  saved in world.json as `ice_holes`, `Ice.to_saved`/`from_saved`). A tool of class `ice` (`Tools.cuts_ice`: the ice pick of stick and stone, the copper ice auger of power 2
  twice as fast; bundle `tools/ice_fishing`) cuts the column of frozen water ahead (`ActionsWater.ice_ahead`,
  `cut_ice`, through `act_in_front` and `dig_at`) in `HOLE_WORK` blows of power 1, where the water is `DEEP` cells
  deep at least (`Ice.why_not`); an open hole is open water: `WorldData.frozen_at` is false there, so the surface,
  the body (it falls in, gets wet, swims out onto the ice), the fish (`water_room`, `_floor`) and the line
  (`Fishing._holds`) see water. In a frozen world a rod is cast into the open hole nearest the tap or the body within
  `HOLE_REACH` cells (`_fish_hole`), the float in the middle of the hole. A hole skins over `SKIN_DAYS` after it
  was cut, one blow breaks the crust; the water thawed, the holes are gone; at most `MOST`, the oldest crusts go
  first. The server sends them by the event `ICE_HOLES` (`Ice.to_list`/`take_list`, checked; nothing over the
  loop, where the world is shared); `src/client/view/ice_view.gd` (`IceView`) gives the 8 nearest holes and the 4
  nearest burning fires to `water.gdshader` and the fish (`shaders/ice.gdshaderinc`): the ice is drawn with clear
  patches a little darker than the rest (`ice_clear`, a fifth or so), clear round a fire (`THAW_REACH`), an open hole as water with a rim
  of broken ice, a crust grey.
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
