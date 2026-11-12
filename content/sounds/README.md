# Mod "Sounds"

A Russian copy: [README_RU.md](README_RU.md).

Sounds whose owner is the game itself, in three bundles: "Nature" (wind, rain, hail, blizzard, water,
fire, crickets, thunder, owl), "Player" (steps on grass, earth, stone, snow and water, a stroke, a jump,
a landing, a splash, digging, a hit on stone, a block placed, pickup, crafted, food, fire lit)
and "Interface" (button, tab, window). Each is turned off separately on the "New world" screen. The sounds
of things lie with the things: a hit on a trunk and the rustle of foliage with the wood of "Plants", a knock on planks with
the planks, a swing with the sword, mowing with the scythe, a step on sand with the soil, the voices and singing of birds with the animals,
the notes of the music in the "Music" mod.

## What is in the folder

```
content/sounds/
  mod.yaml                  id: sounds, name, version, api
  nature/ player/ ui/       bundle: bundle.yaml (title), data/sounds.yaml (records), sounds/<id>.wav
                            or <id>_1.wav, <id>_2.wav ... — as many as variants
  README.md                 this file
```

## How it works

- A sound record: `id`, `title`, `variants` (how many files; a random one sounds each time), `volume`,
  `loop`. The files are built by `tools/make_sounds.gd` from noise and tones (`tools/sound/synth.gd`); any can be
  replaced with your own file of the same name.
- The code asks for a sound by name without the mod's prefix (`play("rain")`, `Sound.resolve`): a record
  with that name from any loaded bundle will do, the last in load order; if there is none, silence.
  Materials name their sounds in `step` and `hit`, creatures in `calls` and `alarm`; a reference to a sound
  binds no one to anyone, a turned-off bundle is just silence in its place.
- Worlds and settings where "Sounds" was a single mod get its three bundles and "Music" (`Mods.RENAMED`).
