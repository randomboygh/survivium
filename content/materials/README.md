# The "Materials" mod

A Russian copy: [README_RU.md](README_RU.md).

What is mined from veins and made from resources: copper, tin, iron, silver, gold and platinum ore, their ingots, bronze, steel, charcoal, cord, planks,
brick, cloth, tar, glass, leather and bone glue, wall blocks (log wall, wattle, cut stone), one bundle for each.
They used to lie in the base game and in "Tools", and sand, clay and scree are here; since 2026-10-25 what the
world gives as it is belongs to the "Resources" mod (`content/resources`), and here is what is made from it.
Switch a bundle off on the "New world" screen ("Mods" → "Materials") and the world goes without it: without "Copper"
there are no veins in the stone and nothing to cast ingots from, without "Charcoal" there is nothing to smelt with, without "Cord" there is nothing to bind the tools of "Tools" with (they switch off with the caption
"needed").

## What is in the folder

```
content/materials/
  mod.yaml                 id: materials, name, version, api
  README.md                this file
  copper/                  "Copper": ore as a cell (role: ore) with a texture and as an item with a picture; ingot
                           (item and model); the ingot recipe (ore and charcoal in the forge) is in "Tools", at the forge
  charcoal/                "Charcoal": wood charcoal, an item with a model, used to smelt and to light a campfire (fuel);
                           the recipe (a log in the kiln) is in "Tools", at the kiln
  cord/                    "Cord": an item and a recipe (from the fibre of "Resources", by hand)
  planks/                  "Planks": an item and a cell with a texture; the recipe (from a log at the workbench) is in "Tools"
  brick/                   "Brick": an item and a cell with a texture; the recipe (from clay in the kiln) is in "Tools"
  log_wall/                "Log wall": a wall and floor block, an item and a cell with a texture; the recipe: a log with an axe, no station
  wattle/                  "Wattle": an early wall block made of branches by hand, taken apart by hand
  cut_stone/               "Cut stone": a wall and floor block, two stones with a pickaxe at the workbench of "Tools"
  cloth/                   "Cloth": an item; recipes at the loom: coarse from cord is in "Tools", at the loom,
                           linen from thread is in "Plants", at the flax; the tar torch is made from it
  tar/                     "Tar": an item (fuel) and a recipe: logs in the burning kiln, in a clay pot, charcoal as a by-product
  glass/                   "Glass": an item and a recipe: sand with charcoal in the forge
  tin/                     "Tin": ore as a cell (role: ore, veins: 0.5 — half as common as copper, hardness 3 — needs a
                           copper pickaxe) with a texture and as an item; an ingot and its recipe (ore with charcoal in the forge)
  bronze/                  "Bronze": a crucible (raw on the potter's wheel, fired in the kiln) and a bronze ingot: copper,
                           tin and charcoal in the forge, the crucible in the bag; bronze tools are in the bundles of their kinds
  iron/                    "Iron": ore as a cell (role: ore, veins: 0.6, hardness 4 — needs a bronze pickaxe),
                           a bloom (ore with charcoal in the bloomery) and an ingot (bloom with charcoal in the forge)
  leather/                 "Leather": an item and a recipe: a hide with fat from "Animals" on the drying rack of "Tools"
  bone_glue/               "Bone glue": an item and a recipe: bones from "Animals" on a campfire, in a clay pot
  steel/                   "Steel": a steel ingot from iron with charcoal in a crucible, in the bloomery
  silver/, gold/,          "Silver", "Gold", "Platinum": rare ores as cells (role: ore; veins 0.3, 0.2, 0.12;
  platinum/                all three are taken by a bronze pickaxe), ingots (all smelted in
                           the forge, platinum for longer and with double charcoal) and blocks of three ingots at the anvil
```

There can be any number of ores: the generator hands out veins among all materials with `role: ore` by their
`veins` shares (in blocks of 8×8×8 cells, by the world seed). The recipes of tar, glass, tin, bronze, iron, steel and the precious metals lie with them, not with the stations: this way the kiln, forge and
bloomery do not depend on bundles
that can be switched off (tar also needs the pot of the potter's wheel).

Each bundle is a folder with `bundle.yaml` (`title`) and its own `data/<kind>.yaml`, `icons/`, `models/`,
`textures/`.

## Textures are PNG

A material's texture is a picture of three 16×16 squares in a row: the top of the cell, its sides and its bottom. A pixel is a
texel on a face; a world cell takes 8×8 texels, so the picture covers 2×2 cells and
repeats further. A texture can be drawn in any editor. The average colour of the top becomes the
material's colour on the minimap, on the map and in the particles when digging.

The prototype's textures are drawn by code (`tools/art/texture_art.gd`) and written into the mods by the command
`godot --headless --path . --script res://tools/make_textures.gd -- [material ...]` (with no names —
all of them; a hand-drawn texture is overwritten, so name what to redo).

## How it works

- The generator asks for a material **by role**, not by name: `ore` — veins in stone (here), `beach` —
  beaches, riverbeds and deserts, `bank` — banks, swamps and tundra clay, `scree` — the slopes of high mountains
  (sand, clay and scree are in "Resources"). No mod with such a role — soil lies on the beach, and stone on the scree and
  in the veins. Two entries of one role — the last one loaded applies, so a mod with "Granite
  chips" `role: scree` will replace the scree without a code change. The tree roles (`trunk`, `crown`) belong to the
  materials of the "Plants" mod.
- How a material is drawn is data too: `priority` (0..15) — which of the neighbours on a slope reaches onto
  which (more — on top), `ground` (`soil`, `sand`, `rock`) — the shades of the ground and the surface noise,
  `drains: true` — puddles after rain do not stand on it (sand). The world shader receives a table of these
  fields for all materials when the world loads.
- `item` — what the cell yields (an item of its own bundle or of another mod, the reference is soft), `dig` — what it is dug with (`hand`,
  `shovel`, `axe`, `pickaxe`), `hardness` — how many pickaxe strikes, `bonus` and `bonus_chance` — what
  sometimes drops on top. `hotbar` — a place on the build bar, if the material is placed. `step` and `hit` —
  the names of sounds: the knock on planks (`knock`) lies in the planks bundle, the step and the hit on stone are in the "Player" bundle of the "Sounds" mod (no entry with such a name in the loaded mods — silence).
- Material numbers in the world's cells follow the load order of the mods, and the world remembers its set of mods and
  its list of materials (`materials` in `world.json`); when an old world is opened the numbers are converted.
- A new material: a bundle folder with `bundle.yaml`, an entry in `data/materials.yaml` (with `role`, if the generator
  places it), an item in `data/items.yaml` with `place`, if it is placed, and `textures/<id>.png`.
  Check: `godot --headless --path . --script res://tools/validate.gd` (fields, references, the texture is
  in place, the bundle loads alone with only what it cannot do without).
