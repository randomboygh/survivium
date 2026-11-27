# Data of the kind creatures

Part of [Beasts](../wildlife.md). The kind `creatures` and its fields.

**Data.** The kind `creatures` (`health`, `carcass`, `bite`, `mass`, `diet`, `speed`, `sight`,
`human_wariness`, `fire_wariness`, `active`, `count`, `sprite`, `frames`, `walk`, `hop`, `attack`, `run`, `hurt`,
`death`, `idle_anim`, `views`,
`flies`, `swims`, `ashore`, `hops`, `walks`, `after_rain`, `winter` (false: not about in winter, `wanted` 0 then, those about leave out of sight: butterflies, ducks), `flight`, `tints`, `flock`, `roost`, `likes`, `loves` (of those, the ones it goes for first, oftener (`LOVE_CHANCE`) and farther (`LOVE_REACH`), standing on them `LOVE_LINGER` times longer: a rabbit on clover), `biomes`,
`calls`, `alarm`, taming: `tame_food`, `tame_feeds`, `tend_swing`, `wool`, `wool_days`, `breed_days`, `herd`, `trapped` — a
live item from a live trap) in the bundles `content/animals/<beast>/`; the picture is the bundle's
`sprites/creatures/<sprite>.png`: a row per side (`views`: 1 — from the side; 3 — side, front, back), in a
row `frames` frames — standing, `walk` frames of a step or wing strokes, the last `hop` of a flyer — hops on
the ground (crouched, in the air; a flyer without `hop` is a butterfly, `Wildlife.sits_still` — does not walk
on the ground and is not pushed: it either flies or sits in place with folded wings and now and then, each at
its own time, flaps them (`SIT_GAP`, `SIT_FLUTTER`, `SIT_FLAP_RATE`)), after them `attack` — an attack (a
dash to a bite, the first — while the beast warns), then `run`, `hurt` and `death`, the others (after the step) — of
rest (drawn by `tools/make_creatures.py`
with `tools/creature_kit.py`, the frog — `tools/make_frog.py`, fish — `tools/make_fish.py`, the boar,
the fox, the black grouse, the deer and the hare — `tools/make_sprites.gd` from `tools/art/boar_art.gd`, `tools/art/fox_art.gd`,
`tools/art/grouse_art.gd`, `tools/art/deer_art.gd` and `tools/art/rabbit_art.gd` (the user's references,
the way the player is drawn), the sparrow, the crow, the owl, the duck and the squirrel — also `tools/make_sprites.gd`,
from `tools/art/sparrow_art.gd`, `tools/art/crow_art.gd`, `tools/art/owl_art.gd`, `tools/art/duck_art.gd` and
`tools/art/squirrel_art.gd` (drawn by hand in the same style), the bear — also `tools/make_sprites.gd`, from `tools/art/bear_art.gd`
(the user's reference at x1), the wolf —
`tools/make_wolf.py`, the wild cat — `tools/make_cat.py`, the hedgehog — `tools/make_hedgehog.py`).
`creatures.gd` chooses the side by the movement on screen (`TURN_BIAS`), a step — by the path walked (a
flyer's hops — `HOP_STEP`; a flyer with `walks`, the black grouse, steps on the ground through its `hop` frames by the
path walked as a walker does, with no sitting frame between), the frames of rest — now and then (`IDLE_GAP`, `IDLE_HOLD`, the last —
`IDLE_LONG`; with `idle_anim` they play through in order, `IDLE_FRAME` each). After the attack frames come, for a
kind drawn with them (the boar, the fox, the deer; the fox and the deer have no attack frames), `run` frames of a gallop, by the path walked (a round of them is `RUN_ROUND` rounds
of the walk) while it flees, hunts or charges (`RUNS`), `hurt` frames played as a blow lands (`HURT_FRAME` each,
with the flinch) and `death` frames. A killed one (its carcass naming it, see Hunting) is a `Body`: `Props.show_drops`
hands the chunk's drops to `show_bodies`, which draws each body instead of its item's model; the carcass comes
before the beast's going (the drops are sent first), so a new body waits for the nearest beast of its kind within
`BODY_REACH` to go (`BODY_WAIT` at most, the beast gone first waits as long for its body in `_fallen`), takes its
sprite, holds its frame till the blow that killed it lands (a blow still in `_blows`; else it waits `BLOW_WAIT`
for the reply naming the blow, which comes after the going: `felled`, from `Controls._did`) and plays its death
(`DEATH_FRAME` each), flashed red as that blow lands as a flinch is (`flash_step`); then it lies on the last frame, turned to the camera by the way it went, till the carcass is
taken. One in a chunk coming in view (`came`) lay there before: dead at once. The sun's shadow is cast by the sprite with its own frame as it is drawn, skewed
by the sun (`sprite.gdshader`: a lying body's shadow lies along it, lit along it the width turns, `side_spread`, shots `sprite-shadow-*`); for a flying one (the frames of a flyer's strokes) the shadow is the frame of the same
stroke from the row «from the front», laid flat at mid-height, with the wings across the path (`flat_shadow`,
`shadow_uv`): the bird from above, not a profile stretched by the sun. The check is the shot `animal-shadows`.
An example of a beast by data and a picture alone: `content/animals/sparrow/README.md`.
