# The "Sparrow" bundle

A Russian copy: [README_RU.md](README_RU.md).

Adds sparrows to the world. It is an example of how a new creature gets into the game through a mod bundle:
data and one picture, no code. It used to be a separate "Birds" mod; with the division of mods into bundles
the sparrow is a folder in the "Animals" mod (`content/animals/sparrow/`), like every beast. All of the sparrow's behaviour is derived from its properties by rules
common to all creatures (`src/shared/game/wildlife.gd`, `src/shared/content/ai_rules.gd`).

## What is in the folder

```
content/animals/sparrow/
  bundle.yaml                     the bundle's name
  data/creatures.yaml             the "Sparrow" kind and its properties
  data/sounds.yaml                chirping: the sound entry
  sprites/creatures/sparrow.png   the picture: 3 rows-of-sides of 9 frames of 14×11
  sounds/sparrow_1.wav ...        the chirping files
  README.md                       this file
```

## How it is made, step by step

1. **The bundle folder.** `content/animals/sparrow/` in the "Animals" mod (`content/animals/mod.yaml`:
   `id: animals`, name, version, `api: 1`; the base game lies in the same format in `content/core`).
   `bundle.yaml` has one field, `title`. Your own mod is made the same way: a folder with `mod.yaml` beside the
   others and in it a folder for each thing.
2. **Dependencies.** The game finds all folders with `mod.yaml` in `content/` and the bundles in them by itself, and reads what
   needs what from the references: `likes: [plants:ears]` puts the sparrow after "Plants". This reference is
   soft (the field is marked so in the schema): without "Plants" the sparrow lives, it just looks for nothing, and without
   trees (`roost: trees` is a role, not a reference) it sleeps on the ground. A hard reference (a recipe for an item
   of a switched-off bundle) would switch the bundle off together with what it lacks. An entry of another mod
   can be replaced by id or have separate fields changed by an entry with `patch: true` (`diet+: [plants]`
   adds to the list). On the "New world" screen a bundle can be switched off for a new world; the world remembers
   what it was created with.
3. **The creature's kind.** `data/creatures.yaml` is a list of entries, as in the base game. The id is written without
   a namespace (`sparrow`), and the game makes `animals:sparrow` of it by itself. The fields:
   - `mass: 0.03`, `diet: [plants]` — light and herbivorous: a cat (4 kg) and a wolf see prey in it, and it
     sees a threat in them and flies away. Nobody wrote "the cat catches the sparrow".
   - `speed`, `sight`, `human_wariness: 0.8` — fast, sharp-eyed, afraid of people.
   - `active: day` — feeds by day, rests at night.
   - `count: 18` — how many sparrows stay around the players (about 3 flocks).
   - `flies: true` — flies: it hops and pecks on the ground, sometimes flies to another place,
     takes off from a threat, lands on the ground or on a tree; in the air and in a tree those who walk
     cannot reach it.
   - `flock: [4, 8]` — keeps in a flock of 4 to 8: all follow the first (the leader), land
     beside it, and the fright of one raises the whole flock.
   - `roost: trees` — sleeps and sometimes lands on trees, in the crown.
   - `likes: [plants:ears]` — is drawn to fields of ears: choosing where to fly, it looks for a place
     where they grow. A reference to a plant of the "Plants" mod (the ears bundle, `content/plants/ears/data/plants.yaml`).
   - `sprite: sparrow`, `frames: 9`, `walk: 4`, `hop: 2`, `views: 3` — the picture, how many frames
     in a row, how many of them are wing flaps, how many of the last ones are hops on the ground, and how many rows-of-sides.
   - `calls: sparrow`, `alarm: sparrow` — chirping: the entry of the bundle's `data/sounds.yaml` and the files
     `sounds/sparrow_1.wav` ... (the code asks for a sound by name without the prefix).
4. **The picture.** `sprites/creatures/sparrow.png`: frames of 14×11 (the sparrow itself is about 11×8), a row per
   side — from the side (the bird looks right), from the front (flying or walking toward the camera), and from behind;
   the game mirrors it to the left by itself, so there are four sides. Frame 0 sits, frames 1–4 are a flap of broad wings (up,
   spread, down, rising), which the game alternates in flight, frames 5 and 6 peck (tail up,
   head to the ground), which the game shows now and then while the sparrow sits, frames 7 and 8 are a hop on the
   ground (crouched, in the air), with which it hops when it walks. It is drawn by
   `tools/make_sparrow.py` after the 16×16 sparrow the author sent: a dark outline
   around the whole bird, a chestnut back, a peach breast, a yellow stripe on the wing. It can be
   redrawn in any editor, keeping the size 126×33.
5. **Check.** `godot --headless --path . --script res://tools/validate.gd` checks
   the fields against the schema (type, range, references such as `plants:ears`), that the picture exists and divides into
   frames, and that the bundle loads alone, with one base. The test `tests/unit/wildlife_test.gd` (`_test_birds`) checks that sparrows come in flocks,
   take off from a person all together, land farther away, cannot be caught by a cat in the air and spend the night
   in the crowns.

## What had to be added to the engine once

New creature properties appeared in the schema (`SCHEMAS.creatures` in `content.gd`) and in the common
rules, so any kind of any mod can use them: `flies`, `flock`, `roost`,
`likes`, `frames`. For example, `flock: [3, 6]` on deer gives herds, and `likes` on hares gives
favourite meadows. The next birds (crow, owl, duck) and the butterfly are made with data alone and a
picture; for the fish and the frog `swims` (lives in open water) was likewise added once, for the
squirrel — climbing trees (`roost: trees` on a walker), for all — `biomes` (where the beast lives), and the
walking frames of walking beasts the game flips by itself by steps.
