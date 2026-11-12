# The "Biomes" mod

A Russian copy: [README_RU.md](README_RU.md).

Which land is where and what grows on it — data, not code. Each biome is its own bundle, which can be
switched off on the "New world" screen ("Mods" → "Biomes"): 28 biomes — meadow, alpine meadow, forest, forest steppe, taiga,
birch grove, pine wood, maple wood, floodplain, steppe, savanna, swamp, peat bog, salt flat, desert, jungle,
tropical beach, tropical sea, mangrove, tundra, stony tundra, ice waste, glacier,
rocks, red rocks, plateau, beach and sea. The generator still computes heights, rivers, mountains and caves itself from noises;
of the mod it asks which biome lies in a column, what its ground is and which trees and bushes
to plant with what chances. Without the bundle its land is bare grass on which nothing grows; without
the whole mod the landscape is the same, but empty and grey on the map.

## What is in the folder

```
content/biomes/
  mod.yaml                 id: biomes, name, version, api
  README.md                this file
  meadow/                  the "Meadow" bundle; likewise forest, taiga, swamp, desert, tundra,
    bundle.yaml            rock, plateau, beach, sea
    data/biomes.yaml       one biome entry
  maple_wood/, floodplain/ "Maple wood" (the red maple of "Plants") and "Floodplain" (willows and poplars by the water): windows
                           of the temperate zone
  ice_waste/, stony_tundra/ "Ice waste" (snow all year round — the ground `top: snow`, the "Snow" material
                           of "Resources", stone without it) and "Stony tundra" (dry tundra, stone on
                           half of the land): windows of the polar zone
  peat_bog/                "Peat bog": the wettest window of the northern zone, tussocks of grass among peat
                           (`clay_as: peat` — the "Peat" material of "Resources", soil without it)
  forest_steppe/, salt_flat/ "Forest steppe" (groves of birches and oaks in the grass between steppe and meadow) and "Salt flat"
                           (a salt crust `top: salt` — the "Salt" material of "Resources", sand without it, in the
                           driest window of steppe and desert): windows of the steppe zone
  savanna/, red_rocks/     "Savanna" (grass with sparse acacias of "Plants" and red clay, a hot window wetter than
                           the desert) and "Red rocks" (clay and stone in the hottest window of the desert): windows of the
                           hot zone
  alpine_meadow/, glacier/ "Alpine meadow" (where: alpine — open upper mountain slopes without forest) and "Glacier"
                           (where: glacier — mountain rocks in the cold: snow on the slopes, the ice of "Resources" in the walls):
                           the mountain zone, only in worlds with climate zones; where exactly is told by the warmth window
  jungle/, tropical_beach/, "Jungle" (the hottest and wettest window: kapok trees, palms and bananas of "Plants"),
  mangrove/, tropical_sea/ "Tropical beach" (where: beach with a warmth window — palms right on the sand, `trees_on`)
                           and "Mangrove" (where: swamp with a warmth window — mangroves on stilt roots in the silt),
                           "Tropical sea" (where: sea with a warmth window — turquoise water over white sand):
                           the tropical zone; a beach and a swamp with their own window are relief variants, only in worlds
                           with climate zones
  birch_grove/, pine_wood/, "Birch grove", "Pine wood", "Steppe": biomes added by whole bundles — a climate
  steppe/                  window inside meadow, taiga and desert, species and bushes of other bundles
    data/creatures.yaml    of "Plants" (birch, pine, rowan, dog rose, currant) and patches to the beasts
                           of "Animals" that live here (biomes+)
```

## How it works

- A biome lies either **by climate** or **by relief**. A climatic one (`where: climate`, the
  default) has a window of warmth `warmth` and moisture `moisture` (0..1 each; warmth falls toward the north and with height,
  moisture — away from the sea and rivers): a column takes the one of the fitting biomes whose window is narrowest (smaller in
  area), on a tie — the one loaded earlier. So "Meadow" with a window over the whole field is the fallback, while "Forest"
  (moisture from 0.7) and "Desert" (warmth from 0.66, moisture up to 0.56) cut their edges out of it. Relief
  biomes (`where: sea`, `beach`, `rock`, `plateau`, `swamp`) are laid out by the generator itself — where there is water,
  where the surf is, where the bare rock of mountains is, where a high plateau is, where low wet land is — and it takes for them the
  entry with that `where`; one entry per relief.
- The ground on top is `top`: `grass`, `dirt`, `stone`, `sand` (the material of role `beach`, the sand of "Resources")
  or `clay` (of role `bank`). `stone_below` and `clay_above` are thresholds of the soil noise (-1..1), below and above
  which stone and clay show through (tundra); `dunes` — by how many cells dunes raise the land
  (desert).
- What grows: `trees` — shares of species at the nodes of the tree lattice (`{plants:oak: 0.85, plants:spruce:
  0.15}`; the remainder of the share up to one is empty), `tree_chance` — the chance of a tree at a node, `groves` — the chance
  where the forest noise is high (meadow groves); `bushes` — shares of bushes, `bush_sparsity` — one bush attempt
  per that many cells (0 — no bushes). Species and bushes are entries of "Plants", the references to them are soft: without
  the species' bundle its share grows nothing, the biome is not switched off. On the wooded slopes of mountains the generator
  plants the biome's species, and if it named none — any loaded one.
- `zone` — the biome's climate zone: `polar` (tundra), `north` (taiga, pine wood), `temperate` (meadow, forest,
  birch grove, maple wood, floodplain), `steppe` (steppe), `hot` (desert), `tropic`, `mountain`. In new
  worlds warmth goes by zones (a slow zone noise which the fine warmth noise only stirs), so
  biomes of one zone lie in patches side by side, and tundra does not neighbour desert; the zone itself is a label of where
  the biome lies, its `warmth` window decides.
- `spawn: true` — the game can be started here (if no biome has it, any
  climatic one fits); `sandstorms: true` — sandstorms instead of rain (the weather of `clock.gd`); `color` —
  the colour on the map and the minimap; `tints` — the colours of the biome's ground and water instead of their own, by the names of the
  `top` and `water` fields (`{sand: "#e6dcbe", water: "#4cc6bc"}` for the tropical beach, `{grass: "#a39a4a"}` for the savanna):
  the client tints the texture toward them, and at the border of biomes the colours change by pixels.
- Which beasts live in a biome is told by the beast (`biomes` of the "Animals" entry), and the biome can
  add itself to its list with a patch: `data/creatures.yaml` with `- id: animals:fox`, `patch: true`,
  `biomes+: [biomes:steppe]` (the reference is full, because the patch lives in an "Animals" entry); without
  the beast's bundle the patch is skipped, so the biome requires nothing.
- The test world ("Testing") lays all loaded climatic biomes in strips in the order of
  loading (the swamp as the fourth strip, the beach last), in each two columns of the trees and bushes
  that the biome grows most and least, so a new biome is visible there too; its beasts come
  to their strip by themselves.

## How to add a biome

A folder `content/biomes/<name>/` with `bundle.yaml` (`title`) and `data/biomes.yaml` with one entry: a climate
window narrower than the meadow's, its own shares of trees and bushes. It can also be from your own mod (a `jungle` entry in
`data/biomes.yaml` of the mod `mymod` — the biome `mymod:jungle`), and a patch can fix someone else's (`patch: true`,
`trees: {plants:birch: 0.5}`). Check: `godot --headless --path . --script res://tools/validate.gd`
(fields, references, the window is not empty, one entry per relief); the layout map is drawn by
`tools/map.gd -- map.png 4096 8`. Worlds of old seeds with another set of biomes will lie differently: a column's biome
is computed at generation, and the saved chunks stay as they were.
