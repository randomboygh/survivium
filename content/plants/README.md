# The "Plants" mod

A Russian copy: [README_RU.md](README_RU.md).

Oak, spruce, birch, pine, willow, apple, rowan, maple, linden, poplar, larch, fir, cherry,
bird cherry and the dead tree, bushes (shrub, raspberry, blueberry, currant, rosehip),
herbs (grass, tall grass, flowers, herbs, ears, reeds, nettle, fern, clover, cranberry, flax), moss and
mushrooms, their seeds, berries and fruits, grain and what is made of all this: flour, flatbread, bandage, roasted
mushrooms and acorns, linen thread and cloth. It used to be part of the base game (`content/core`), and the code knew every species by
name; now it is a separate mod of data alone. Each tree, bush and plant is its own bundle,
which can be switched off on the "New world" screen; switch them all off and the world goes without trees, bushes and
herbs: bare, but alive (the sparrows of "Animals" will remain, but without ears they have nowhere to feed, and without crowns they sleep on the ground).

## What is in the folder

```
content/plants/
  mod.yaml              id: plants, name, version, api
  README.md             this file
  wood/                 the "Wood" bundle: log and foliage — the materials of the trunk cell (role: trunk) and the crown
                        (role: crown), their textures (48×16: top, sides, bottom; see the README of "Materials") and a patch
                        to the base game's log item saying what it places
  oak/, spruce/         "Oak", "Spruce": a species (data/trees.yaml), its seed (acorn, cone) with an icon and a model;
                        the cone is kindling (fuel)
                        bundle.yaml: requires: [wood] — the trunk and crown are roles, and roles do not bind
  birch/, pine/,        "Birch", "Pine", "Willow", "Apple", "Rowan": a species with its own bark (bark —
  willow/, apple/,      textures/<name>_bark.png, 48×16 like a material's), for the apple and rowan the fruit is an item
  rowan/                of the bundle (seed: a felled tree leaves it and it is picked by hand in autumn); the pine
                        gives the cone of "Spruce" (a soft reference)
  maple/, linden/,      "Maple", "Linden", "Poplar", "Larch" (needles, turns yellow and bare in winter), "Fir",
  poplar/, larch/,      "Cherry" and "Bird cherry" (bloom in spring, blossom), "Dead tree" (dead: bare
  fir/, cherry/,        branches all year round); only the cherry and the dead tree have their own bark, the grey bark
  bird_cherry/,         common/textures/grey_bark.png is shared by the linden, poplar, fir and bird cherry, the maple and
  deadwood/             larch have the log's bark
  red_maple/            "Red maple": a maple with a crimson crown all year round (the "Maple wood" biome)
  acacia/               "Acacia": a flat umbrella crown on a thin crooked trunk (the "Savanna" biome)
  palm/, ceiba/,        "Palm" (shape: palm — a tuft of hanging leaves on a tall bare trunk, drops
  mangrove/             coconuts), "Ceiba" (a jungle giant with buttress roots), "Mangrove" (stilt roots,
                        the `stilts` field): the tropical zone
  shrub/, raspberry/,   "Shrub", "Raspberry", "Blueberry", "Currant", "Rosehip", "Banana": a bush (data/bushes.yaml), its
  blueberry/, currant/, berries and a bush for planting; the bush model is shared — common/models/bush.png
  rosehip/, banana/
  fern/, nettle/,       "Fern", "Nettle", "Cranberry", "Clover": plants with their own picture (kind: custom,
  cranberry/, clover/   sprites/plants/<name>.png — frames of 8×24, the fern's and the clover's 16×24, two cards wide): the
                        fern in the woods (under the crowns and round them), the nettle in patches on meadows (both give
                        fibre), the cranberry by the water (a berry), clover in wide fields on meadows (hares and deer graze it)
  grass/                "Grasses": grass, tall grass, flowers, herbs (four kinds of one grass) and grass seeds
  ears/                 "Ears": ears, grain, flour and flatbread (the flour and flatbread recipes are in the kiln), wheat — a crop
                        (kind: crop) from grain on a garden bed, a picture per frame for each growth stage
  turnip/, carrot/,     "Turnip", "Carrot", "Peas": crops (kind: crop) from seeds on a garden bed, a picture per frame for
  peas/                 each stage; seeds are sometimes found when cutting tall grass, herbs and flowers (the `finds` patch),
                        the ripe ones give a harvest and seeds
  reeds/                "Reeds"
  flax/                 "Flax": wild flax in glades on meadows, in the floodplain and forest steppe (kind: custom, the biomes field),
                        its stalks, linen thread (by hand) and linen cloth from it at the loom
                        of "Tools" (twice as much as from cord); flax seeds (sometimes from a cut
                        wild one) are sown on a garden bed and grow into sown flax (kind: crop, it is mown with a scythe too)
  monstera/             "Monstera": the broad cut leaves of the undergrowth of jungle and mangrove (kind: custom, biomes)
  moss/                 "Moss": moss and a bandage from it
  roasted_acorns/       "Roasted acorns": the acorns of "Oak", baked on a campfire in a pot of "Tools"; its own
                        bundle, so that the oak does not depend on the potter's wheel
  mushrooms/            "Mushrooms": mushrooms and glowing mushrooms, roasted mushrooms at a campfire
  common/models/        models shared by bundles (for now the bush)
  common/textures/      textures shared by bundles (grey bark)
```

Each bundle is a folder with `bundle.yaml` (`title`) and its own `data/<kind>.yaml`, `icons/`, `models/`,
`textures/`; it can be switched off separately on the "New world" screen ("Mods" → "Plants"). What the bundle's
folder lacks, the game looks for in the mod's `common/`.

## How it works

- The engine asks for plants **by role, not by name**. Which species and which bush grow where is told
  not by the tree but by the biome — an entry of the "Biomes" mod (`content/biomes/`): the meadow has `trees: {plants:oak: 0.8,
  plants:spruce: 0.2}`, the taiga has `bushes: {plants:blueberry: 0.6, plants:shrub: 0.4}`; the references are soft,
  so without the species' bundle its share is simply empty. A grass has a kind `kind`: `tuft`, `tall_grass`,
  `flowers`, `herbs`, `ears`, `reeds`, `moss`, `mushrooms`, `glow_mushrooms`; where each kind grows
  (meadows, fields, banks, the shade of crowns) is decided by the grass rules `src/shared/world/grass.gd`, and how it is drawn is
  up to the client. A kind with no entry does not grow in the world. The tenth kind is `custom`: a plant with its own picture
  (`sprite`, a row of `frames` frames of 8×24 in the bundle's `sprites/plants/`, or wider with `across`: a frame of
  `across` such columns drawn as that many cards side by side), which says itself where it
  grows (`grows`: `meadow` — open grass, `shade` — the shade of crowns, `woods` — that shade and the open grass a few
  cells round the crowns, `bank` — by the water), what share of such land it takes (`cover`), whether it grows in
  patches (`clumps` — a noise threshold, no field — everywhere) and how wide they are (`clump_size`, in cells, 10 if
  not given), and in which biomes (`biomes`, none — in any);
  there can be any number of such plants, they grow side by side (fern, nettle, cranberry, clover).
- A tree's trunk is drawn with the log of "Wood", and a species with a `bark` field with its own texture
  (`textures/<bark>.png`, 48×16 like a material's: end, bark, bottom); the cell stays the same (a log),
  so it is chopped and yields the same. Bark is not a material: materials together with barks can be no
  more than 21 (room in the atlas; a species with a shared bark from `common/` takes no room), the validator checks it.
- What the crown looks like is also the species' data: `shape` — the form (round, of caps, column, weeping,
  an umbrella on a bare trunk, a cone in tiers, palm), `leaf` — the pattern of the foliage (pointed leaves, curly balls,
  big round overlapping leaves, needles), `blossom` — the spring bloom colour, `dead` — a dead tree.
  The fields are described in `oak/data/trees.yaml`. The crown's shadow falls as a patch from each cap, a dead tree has no shadow.
- So the mod can not only be switched off but **replaced**: a mod with a birch and a pine and its own biome
  (or a patch of shares in someone else's) will give other forests with no code change; a tree with no biome that named it
  grows only in mountain forests, where the generator plants any species.
- The trunk and crown are cell materials of this mod with the roles `trunk` and `crown` (`data/materials.yaml`):
  without them trees do not grow, and a mod with another species can give them its own. The log as an item is
  an entry of "Resources" (`resources:log`); the "Wood" bundle appends to it by a patch what it places
  (`place: plants:log`), and a species says what is left of it (`log`, `twig`, `seed`), a bush — its own
  twigs (`twig`). What a bundle needs the game derives from its references: grass and campfire are base game entries,
  fibre is of "Resources" (`resources:fiber`), the kiln for the flatbread is of the "Tools and crafting" mod (so "Ears" without it
  switches off with the caption "needed"). Grain is an item of the "Ears" bundle: it is sown on a garden bed
  (`crop: wheat`) and grows into wheat — a crop (`kind: crop`, `grows: field`): it grows `grow_days` days on a wet
  bed in spring, summer and autumn, and dies in winter; the ripe one is reaped by hand, with a sickle and a scythe (`mown: true`), and gives `gives`.
  The acorn of "Oak" and the cone of "Spruce" are planted (`crop`) and grow into a sprout (`kind: sapling`, `tree` — the species): on open
  ground one cell away from trees, in spring, summer and autumn without watering; the sprout, a shoot, from the `young` share of its time is
  a small tree (chopped into twigs), and when grown it becomes a tree. A frame can be wider than a cell: `across: 2`
  — the picture is two cards side by side (frames of 16 px, the oak and spruce sprouts), drawn as one picture.
  A plant's `finds` are items that are found now and then when it is cut (the item and the probability of one per
  plant, separate from `chance`): this is how turnip seeds turn up in tall grass.
- What a tree leaves when it is felled (`seed: acorn`), what a bush gives (`fruit`, `item`) and a grass
  (`gives`) are items of the same bundle, so they are written without a prefix (the namespace is the mod's:
  `acorn` is `plants:acorn`). Such references are soft: without their bundle they are simply dropped.
- A new species: a folder `content/plants/<name>/` with `bundle.yaml` (`title`, `requires: [wood]`) and
  `data/trees.yaml` (and a share in the `trees` of some biome, see the README of "Biomes"; a species that no
  biome named grows only in mountain forests and on the "New world" screen — so for now the birch,
  pine, willow, apple and rowan, until their biomes are ready); a new bush is `data/bushes.yaml` and a share in
  `bushes`; a new plant on grass is an entry with one of the nine `kind` (two entries of one kind —
  the last one grows) or `kind: custom` with its own picture. Where the code says "oak" or "raspberry"
  (the test world, screenshots, tests: `Trees.first`, `Bushes.first`), it takes the species that the biomes
  give the most — not the first alphabetically. Check:
  `godot --headless --path . --script res://tools/validate.gd` checks the fields, the references and that each
  bundle loads alone, with only what it cannot do without; `tests/progress_test.gd` — that all
  recipes can be made in a new world.
