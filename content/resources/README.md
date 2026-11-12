# Mod "Resources"

A Russian copy: [README_RU.md](README_RU.md).

What the world gives as it is: log and branch, stone and flint, earth, sand and clay, fiber. Before,
these items lay in core (`content/core`), and the code itself decided what falls from a tree and what lights a
campfire; now it is a separate mod of data, a bundle for each, and who gives what is told by the trees,
bushes and cells themselves. What is made of resources (planks, brick, cord) lies in "Materials".

## What is in the folder

```
content/resources/
  mod.yaml              id: resources, name, version, api
  README.md             this file
  wood/                 "Wood": log and branch (fuel: true — they light and feed a campfire) and the campfire recipe
  stone/                "Stone": stone (placed as core's stone cell), flint and scree (role: scree) with a texture
  soil/                 "Soil": earth (placed as core's soil cell), sand (role: beach) and clay (role: bank)
                        with textures, a bed — earth dug with a hoe (role: bed), and a wet bed (role: bed_wet)
  fiber/                "Fiber"
  snow/                 "Snow": snow lying all year round (role: snow), the ground of the ice waste and glaciers, and ice
                        (role: ice) of the glacier walls, with textures; snow is dug with a shovel, ice is split with a pickaxe
  peat/                 "Peat": the brown ground of peat bogs (role: peat) with a texture; dug with a shovel, peat
                        lights a campfire (fuel)
  salt/                 "Salt": the white crust of salt flats (role: salt) with a texture; dug with a shovel and gives salt
```

Each bundle is a folder with `bundle.yaml` (`title`) and its own `data/<kind>.yaml`, `icons/`, `models/`,
`textures/`; it can be turned off separately on the "New world" screen ("Mods" → "Resources").

## How it works

- Who gives a resource is written at the source, not in the code: a tree species names what lies from the
  felled trunk (`log`), what is broken from the crown by hand, knocked down by wind and dropped by the felled crown
  (`twig`) and what else remains (`seed`); a bush has its own branches (`twig`), berries (`fruit`) and itself for
  planting (`item`); a cell has what a dug one gives (`item`), what it sometimes gives on top (`bonus`) and what a
  cut layer gives (`mow_gives`). That is why a log falls from any tree that names it, an acorn
  only from an oak, and a branch from both a tree and a bush. All these links are soft: without the "Wood" bundle
  a tree falls silently, without "Soil" dug earth gives nothing.
- A campfire is lit and fed by any item with `fuel: true`; `fuel_time` is how many seconds it burns on one
  piece (branch 300, log 1200, peat 600; without the field 120). A mod can add other fuel.
  The campfire itself is a thing of core, and its recipe (branches and fiber) lies in the "Wood" bundle.
- The cells of stone and soil are core's (`core:stone`, `core:dirt`): the items stone and earth place them,
  while scree, sand and clay are cells of this mod with roles for the generator (without them, soil on the beach and stone on
  the scree). The textures are `textures/<id>.png` (48×16: top, sides, bottom; see the README of "Materials").
- A new resource: a folder `content/resources/<name>/` with `bundle.yaml`, `data/items.yaml` and, if it is a cell,
  `data/materials.yaml` and a texture; then name it in the `log`/`twig`/`seed` of a tree, the `twig`/`fruit` of a bush
  or the `item`/`bonus` of a cell of the mod that gives it. Without a source the check will say "no source";
  a thing given by a quest or trade writes `source: special`.
- Another source of an old resource is one field on a new object in its mod, with a link to the same id:
  a bush with `twig: resources:branch`, a cell with `bonus: resources:flint`. No code is needed, and the resource
  does not move: both sources lead to one thing, and the graph shows them all
  (`docs/generated/content-graph.md`, "from where and to where").
- The check: `godot --headless --path . --script res://tools/validate.gd`.
