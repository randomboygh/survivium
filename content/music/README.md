# Mod "Music"

A Russian copy: [README_RU.md](README_RU.md).

Three notes of the first octave: a pluck (`note_pluck`), a bell (`note_bell`) and a long tone (`pad`).
Music as a record does not exist in the game: `src/client/audio/music.gd` assembles it on the fly from these notes,
playing them at other pitches (dawn, a new place, an evening by the campfire, the main menu: each has its own
mode and tempo). Turn the mod off on the "New world" screen, and the game keeps its sounds but has no music.

## What is in the folder

```
content/music/
  mod.yaml            id: music, name, version, api
  data/sounds.yaml    records of the notes (id, title, loop for the long tone)
  sounds/<id>.wav     the notes themselves, built by tools/make_sounds.gd from tones
  README.md           this file
```

Your own instruments are files with the same names in another mod loaded later: the code asks for a note by
name (`note_pluck`), and the last one is taken. Before, the notes lay in the "Sounds" mod together with all
the sounds of the game; now each sound lives with its owner (a hit on a trunk with the wood of "Plants", a swing with the sword,
voices with the animals), "Sounds" is nature, the player and the interface as three bundles, and "Sounds" in old worlds means
both them and "Music" (`Mods.RENAMED`).
