# The "Animals" mod

A Russian copy: [README_RU.md](README_RU.md).

Rabbit, squirrel, wildcat, deer, wolf, sparrow, fox, boar, bear, hedgehog, crow, owl, duck,
butterfly, perch and frog, fish for the fishing rod (the "Fish" bundle: roach, pike, salmon, cod, parrotfish) and
the spoils of carcasses (the "Game" bundle: meat, hides, bones and butchering recipes). Each beast is its own bundle: a folder with everything it needs (the kind's entry,
the picture, the voices), which can be switched off on the "New world" screen separately from the others ("Mods" →
"Animals"). The behaviour is not described by a single line: the cat (4 kg, meat) hunts the rabbit, squirrel and
sparrow and fears the wolf, the wolf (40 kg) looks for prey at night, the deer and rabbit graze and run from people,
the crow (flies, omnivorous) catches sparrows and frogs, and the sparrows scatter from it, the perch in the water is
out of the cat's reach, but not the owl's — all this is rules of `src/shared/game/wildlife.gd` and
`src/shared/content/ai_rules.gd` by the mass, diet, sight, speed, `human_wariness` and
environment (`flies`, `swims`) of each kind. From a burning campfire and a torch in the hand the beasts keep away
(`fire_wariness`, 0 for fish).

## What is in the folder

```
content/animals/
  mod.yaml                        id: animals, name, version, api
  README.md                       this file
  rabbit/                         the "Rabbit" bundle; likewise squirrel, cat, deer, wolf
    bundle.yaml                   title: "[animals.rabbit.bundle]"
    lang/en.yaml, ru.yaml ...     the texts of the bundle's keys in each language
    data/creatures.yaml           the kind animals:rabbit and its properties
    data/sounds.yaml              its voices: sound entries
    sprites/creatures/rabbit.png  the picture: three rows (side, front, back) of 7 frames
    sounds/rabbit_1.wav ...       the voice files
  sparrow/                        the "Sparrow" bundle with a README on how to make a creature (the former "Birds" mod)
  fox/, boar/, bear/, hedgehog/   likewise; all the beasts are drawn by tools/make_creatures.py
  crow/, owl/, duck/, butterfly/  flyers (flies); the sparrow, crow, owl and duck have frames: sitting, four flaps, two rests, a hop (the duck waddles); the duck also swims
  perch/, frog/                   swimmers (swims): live in open water; the frames are tail or paw strokes
  game/                           the "Game" bundle: small carcass, carcass, raw, roast and dried meat, hide, bone, fat, butchering, roasting and drying
  wool/                           the "Down" bundle: the tame rabbit's rabbit down, yarn from it and cloth at the loom
                                  (separate, so that the rabbit does not depend on the loom of "Tools")
  fish/                           the "Fish" bundle: roach, pike, salmon, cod, parrotfish, catfish — swim in the water of their biomes
                                  and are caught with the fishing rod of "Tools" (the catch field: which item the fish is in the bag), roast fish
                                  (at a campfire); the perch of the perch bundle is caught too (its item is here)
```

## How it works

- Taming: a rabbit is fed from the hand with a carrot or a turnip (`tame_food`; it does not run
  from the one holding food), after `tame_feeds` feedings it is tame and follows its owner; with the action button and an empty hand
  it is left in place or called again, with a knife once every `wool_days` days its down is sheared (`wool`). Two
  tame ones, left side by side and fed within a day, bring a young rabbit once every `breed_days` days, while there are
  fewer than `herd` of them. Tame ones are saved with the world.

- Hunting: `health: 26` — how many strikes of power 1 a beast withstands (a sword, a knife and other tools strike with their
  `power`, the Hunting skill adds up to half to it, hands strike with power 1; small game 3–5, big beasts 22–50, so that
  weapons from stone to steel differ: `docs/balance/GAME_BALANCE_DESIGN.md`); without `health` a beast cannot be
  struck (the butterfly, the sparrow). A wounded beast runs from the place
  of the strike, a killed one leaves on the ground what is named in `carcass`: `small_carcass` (a small carcass, butchered by hand)
  or `carcass` (a carcass, a knife is needed in the bag). The reference is soft: without the "Game" bundle the beast falls and leaves
  nothing.

- The namespace is the mod's: `rabbit` in any bundle of "Animals" is `animals:rabbit`. A reference to an
  entry of another mod is written in full (`plants:ears`).
- What a bundle does not require, the game does not require: beasts have no references to others' entries, so each loads
  with one base. Dependencies are generally read from references: a hard reference (a recipe, an item of a material)
  to a bundle that is not in the set switches the bundle off with a reason; a soft one (`likes`, `seed`, `fruit`) is simply
  dropped — a sparrow without "Plants" lives, but looks for nothing. The field schema in
  `src/shared/content/content.gd` says which references are soft (`soft`).
- The pictures are pixel PNGs with a transparent background, frames of one size: a row for each side
  (`views`: 1 — side only, 3 — side, front and back; from the side the beast looks right, the game mirrors it to the left
  by itself, and picks the side by where the beast goes on the screen), in a row `frames` frames:
  the first is standing, the next `walk` are a step (for a walker and a swimmer they go by the distance covered, two
  steps per cycle), for a flyer — wing flaps in the air; the remaining ones are rest frames (tail, head to
  the grass, pecking), the game shows them now and then while the beast stands; for a flyer with `hop` the last `hop`
  frames are hops on the ground (crouched, in the air); with one frame the beast is not animated.
  They can be redrawn in any editor; any size. The sparrow is drawn by `tools/make_sparrow.py`, the crow, owl and duck by `tools/make_birds.py`,
  the frog by `tools/make_frog.py`, the fish by `tools/make_fish.py`
  (a dark outline around the whole beast; the duck waddles), the rabbit by `tools/make_rabbit.py`, the squirrel by `tools/make_squirrel.py`, the fox by `tools/make_fox.py`, the deer by `tools/make_deer.py`, the boar by `tools/make_boar.py`, the bear by `tools/make_bear.py`, the wolf by `tools/make_wolf.py`, the wildcat by `tools/make_cat.py`, the hedgehog by `tools/make_hedgehog.py`, the other beasts by
  `tools/make_creatures.py`: the picture is written there as text, a pixel is a letter, and the shadows, light and outline
  in a dark shade of its colour are laid by `tools/creature_kit.py`.
  What the bundle's folder lacks, the game looks for in the mod's `common/`.
- Environment: `flies: true` — flies (lands on the ground and, with `roost: trees`, on crowns), `swims: true` —
  lives in open water a little below the surface (the perch); with `ashore: true` it also comes out on the shore by its
  water (the duck, the frog). A flyer and a swimmer (the duck) swims away from a threat, takes off only if it is
  close, and flies low and not far: `flight` — how far at a time, in cells (28 by default).
  `hops: true` — moves over the ground in hops with rests (the frog: in a hop the second frame, at take-off and
  landing the third). `after_rain: true` — comes out only after rain, while puddles stand, and the
  more of them, the more it does (none in winter). `tints: ["#ffffff", "#f6d64a"]` — each beast of the kind is drawn
  in one of these colours (the picture is multiplied by it; draw such a one light). Beasts speed up and
  slow down smoothly, stand a while where they arrived, and push each other and the player apart by mass:
  the bear pushes the player aside, the player pushes the rabbit. A walker with `roost: trees` climbs (the squirrel):
  from a threat it runs to the nearest tree and climbs its trunk, sleeps in the crown, where it cannot be reached, and
  climbs down a few seconds after it is safe. A walker cannot reach a swimmer and vice versa, a flyer reaches all — this is how from masses and
  diets comes who catches whom.
- Where it lives: `biomes: [biomes:taiga, biomes:forest]` — the beast comes only onto the land of these biomes
  (soft references to the "Biomes" mod: without it or without the biome's bundle — everywhere). `flock: [3, 5]` — in a herd
  behind a leader (deer, boars, wolves in pairs), `likes: [plants:tuft]` — looks for places where this grows.
- Voices (`calls`, `alarm`) are entries of the bundle's `data/sounds.yaml` and files `sounds/<name>_N.wav` beside it
  (made by `tools/make_sounds.gd`, your own can be recorded too); the code asks for a sound by name without a prefix.
  The hoot "owl" lies with the owl: the night forest calls it by name, and without the owl's bundle it is silent.
- A new beast: a folder `content/animals/<name>/` with `bundle.yaml` (`title`), `data/creatures.yaml` and
  a picture `sprites/creatures/<sprite>.png`. For it to walk in a herd or sleep in trees, the fields
  `flock` and `roost` are enough (see the sparrow's README).
- Check: `godot --headless --path . --script res://tools/validate.gd` checks the fields, the references to
  sounds and that each kind has a picture; the validator also loads each bundle alone, with only
  what it cannot do without.
