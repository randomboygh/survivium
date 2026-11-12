# Sound and music

Status: ACTIVE. A Russian copy: [audio_RU.md](audio_RU.md).

**Purpose.** Buses and volumes from the settings, the player's ear (it turns with the camera), one-off sounds
from a place or from the interface, loops (wind, rain) and sounds from places (fire, a river), the beasts'
voices, steps, quiet music from notes.

**Files**
- `src/client/audio/sound.gd` — `play(id, pos)` (`pos` = INF — from nowhere), `play_later`, `loop`
  (everywhere), `spot` (from a place), `work`, `resolve(id)`; the world around the player is looked over once
  per `Sound.TICK` (0.25 s), not every frame; several voices per world (`VOICES`), a repeat within `MIN_GAP`
  is not doubled.
- `src/client/audio/nature.gd` — weather, water, a campfire, birds by day, an owl at night, crickets; duller
  under a roof.
- `src/client/audio/steps.gd` — steps by what the feet stand on, a splash, strokes, a jump.
- `src/client/audio/voices.gd` — the beasts' voices (`calls`) and fright (`alarm`).
- `src/client/audio/music.gd` — music as notes by a schedule (dawn, new places, an evening by the campfire,
  the menu).
- `default_bus_layout.tres` — the buses; `tools/make_sounds.gd` + `tools/sound/synth.gd` — the synthesis of
  all `.wav`; `tools/web_patch.py` — the patch of the web build for sound.

**Data.** The kind `sounds` (`variants`, `volume`, `loop`), the files in the bundle's `sounds/`: `<name>.wav`
or `<name>_N.wav` per variant. The code asks for a sound by a bare name (`play("chop")`): `Sound.resolve` takes
the record of the last loaded mod with this name, none — silence. A sound lives at its owner (`chop` — at
wood, `swish` — at a sword, `bird` — at a sparrow); the game's own sounds are the mod `content/sounds/`
(bundles nature, player, ui), the notes — `content/music/`; a material's `step` and `hit`, a creature's
`calls` and `alarm` say who sounds. A reference to a sound does not link bundles.

**Rules**
- Nothing sounds before the first tap or key (`Sound.unlocked`, the browser's autoplay rule); the files load
  a few per frame after that.
- The web export plays samples (no AudioStreamGenerator), so music is notes; every playing sample gives
  garbage to the page, keep the loops few.

**Pitfalls**
- The interface's voices (`UI_VOICES`) are created at once in `Sound._init`, the world's voices — in `build`
  with the world: on PC sound is on from the start, and a click of a main-menu button before the world took a
  voice from an empty list — a release build crashed from it (in debug it is only a SCRIPT ERROR). A script
  error that is harmless in the editor can crash the game in a release export: check the PC build with sound
  (on Linux with no sound card the driver is Dummy, and `Sound.mute` silences everything — PulseAudio with
  `module-null-sink` is needed).
- The buses are only in `default_bus_layout.tres`: the web build copies them at start, a bus from
  `AudioServer.add_bus` later is mute in a browser.
- The engine's web player loops a sound by starting it again at its end, late; `tools/web_patch.py` makes the
  source node looped and stops the engine copying the whole sample at every start. On an engine upgrade
  re-check the patch.
- Every write of `volume_db` or `pitch_scale` of a sounding player in a browser passes the page the voice's
  name and arrays of volumes — garbage for the collector; so `_fade` writes a loop's volume only when it
  changes by more than `VOLUME_STEP_DB`. `tools/web_patch.py` also writes the engine's time without BigInt
  and finds the names of voices and of the browser's functions among those read earlier, making no new
  strings.

**Tests.** `tests/unit/view_test.gd` (`sound`), `tools/validate.gd` (every sound has files for all variants).

**In more detail.** The READMEs of the mods `content/sounds/` and `content/music/`, decisions 89 and 143 in
`plan/README.md`.
