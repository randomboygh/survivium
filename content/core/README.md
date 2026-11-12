# Mod "Core"

A Russian copy: [README_RU.md](README_RU.md).

What the engine does not work without: five cells (air, grass, earth, stone, water), the human, the campfire, the start
of a new world with the skills of the hands, and the eras of progress. Core is always on; the other mods lie beside it in the same
format and refer to its records (`core:stone`, `core:campfire`). The engine names by id only core's records,
everything else it looks up by roles and classes.

## What is in the folder

```
content/core/
  mod.yaml               id: core, name, version, api
  README.md              this file
  data/materials.yaml    the engine's five cells; the order sets the cell numbers, air first
  data/items.yaml        the campfire (prop: campfire, fire: true), rot, the cross in place of a vanished death bag
                         (grave: true); the header here also describes all the item fields
  data/creatures.yaml    the human (the player)
  data/starts.yaml       the start of a new world: the skills of the hands, the bag, the camp at the spawn point
  data/eras.yaml         the eras of progress 0–3
  data/skills.yaml       the character's nine skills (decision 164)
  sprites/               the character (player.yaml: layout of the sheets, the hands' work), the bundle in the hand
  icons/, textures/      icons of the campfire, rot and cross, textures of core's cells
  models/                the cross's model (grave.png, tools/make_models.gd -- grave)
```

Core has no bundle folders: it is a single entry in the world's set (`core`).

## The start and the hands

Each new world begins by the record `core:default` (`data/starts.yaml`), and the content check (the graph)
starts from the same one, so the game and the check begin alike:

- `bag` is what lies in the bag (`{resources:branch: 3}`), `camp` is what stands at the spawn point
  (`[{item: campfire, at: [-4, 4]}]`, that many cells east and south; the thing takes 2×2 cells);
- `hand_power`, `hand_area`, `hand_swing`, `hand_reach`, `hand_mows`, `hand_slow` are what empty hands can do:
  the power (what hardness they take), how many cells per swing, seconds per swing, how many cells they reach, which
  grass they cut and how many times slower they dig soft ground. The hands are a tool with no item
  (`Tools.HAND`), the other tools are items with `tool`.

A bundle changes the start by a patch, without touching core: `- {id: core:default, patch: true, camp+: [{item: mod:item,
at: [x, z]}]}` (this is how the chest of "Tools" gets into the camp), `bag+: {mod:item: 2}`, `hand_reach: 10`.

## How to add an era

An era is a step of progress, a label that the content graph checks: in the game it forbids nothing
(there are no technologies, decision 2В). An entry in the `data/eras.yaml` of any mod:

```yaml
- id: iron
  title: "[core.eras.iron]"           # a key; the text is in lang/<code>.yaml beside data/
  description: "[core.eras.iron.about]"
  order: 4        # the step's place: 0, 1, 2… without repeats
  depth: 12       # how many crafting steps from the start to expect for the era's things (0 — do not check)
  provisional: [depth]
```

Then `era: core:iron` on the items that open the step: a station, the first tool of a new material, a new
material. The graph derives the era of the other things itself: a recipe by the latest of what it requires, a yield by the
tool, a thing by the earliest path to it, but not earlier than the recorded one. It is an error if a thing is recorded in an
earlier era than it can be reached; a warning if the chain is longer than `depth`. The map of eras is `docs/generated/content-graph.md`.

## The check

`godot --headless --path . --script res://tools/validate.gd` (fields, links, each bundle alone, the graph),
`godot --headless --path . --script res://tools/content_report.gd` (reports in `docs/generated/`). What else
is added by data alone: `docs/specifications/BUNDLE_SYSTEM.md`, section 15.
