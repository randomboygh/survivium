# Stage 2 item 4: more zones and creatures, a bigger world (hand-off, 2026-11-16)

Decision 186, item 4 (plan/mvp.md). The user's picks (2026-11-16, all «А»):

1. Creatures come last, after the sprite style is chosen in the thread «Перерисовать белку с нуля»;
   this work does not draw sprites itself.
2. Lava does not flow: it glows, lights the cave, burns on touch, burns things dropped on it, and water over
   it turns to stone.
3. Underground creatures are mostly peaceful; dangerous ones (spiders, centipedes) are rarer and deeper.
4. The bigger world is the default in new worlds (hidden WorldGen setting `landscape` 1); the «Биомы» slider
   still scales it. Everything new joins new worlds only (a world's bundle set is fixed).
5. Later ask: rivers 1–4× wider, the width by biome → by the land's moisture.

## Done

- #718 (merged): `landscape` 1: biomes ~4× wider (`BIG_BIOMES`, 2 octaves, domain warp `_warp`), rivers longer,
  wider by moisture (`RIVER_WIDEST/DRY/WET`), deeper (`RIVER_DEEP`), lakes wider. World dir suffix `l1`.
- #719 (merged): kinds of caves: biomes `where: cave` (`tier`, `cave_share`, `cave_floor`, `cave_walls`, `flood`,
  `pools`, `pools_from`, `crystals`, `crystal_chance`), `WorldGen.cave_kind` / `_cave_kind_cells`; bundles
  `resources/caves` (mycelium, crystal, deepstone, lava) and `biomes/*_cave`; material `glow` (shader bits).
  Also fixed main red after #718: the progress test builds a stone post at the camp for the notice board.
- #720 (merged): material fields `burns` (`Character._touch_hot`, `WorldCells.add_drop`) and `light`
  (`ChunkMesher.Job.glows` → `ChunkStreamer._apply_lit` → `Effects.lit`); mushroom lights by day underground.

- #723 (merged): oases, rocky desert, cacti, cattails, juniper, swamp hummocks and mist, highland scree.
- Step 3b: volcanic land (biome `where: volcanic`, bundles `biomes/volcanic`, `resources/volcanic`): rare regions
  by the noise `n_volcano` (about 4% of the land), basalt / black sand / ash, cones with lava craters, hot springs.

Pictures: `survivium-builds/world/zones/` in the project library (maps before/after, rivers, caves, cave lights).

## Left

- Water over lava → stone: water is static and players cannot pour it, so there is no trigger. Do it when water
  can flow or be poured (the generator never puts water over lava).
- Step 3, zones on the surface (new bundles, new worlds only):
  - Desert: today bare sand with rare shrubs. Cacti (a new tree `shape` "cactus": a green trunk with arms, no
    crown, or a bush look), oases (a lake ringed by palms and grass in a desert), rocky desert (stone_below).
  - Volcanic land: done in step 3b. Possible later: steam over hot springs, warmth by them, smoke from cones.
  - Swamp: hummocks, cattail/reeds, fog (`swamp`, `peat_bog`, `mangrove` exist).
  - Highlands: scree, low shrubs (`alpine_meadow`, `plateau`, `glacier` exist).
  Land animals live almost only in forest/meadow/taiga: step 4 adds per-zone ones.
- Step 4, creatures (after the sprite style): underground (bats, blind fish/crayfish, salamanders, moles; rare
  deep spiders/centipedes), swamp (herons, grass snakes), desert (lizards, scorpions, fennecs), mountains (goats,
  marmots), volcanic.

## How to look

- `tools/map.gd` top-down maps (`relief=1,climate=1,cave_shape=1,landscape=1`), `tools/cave_map.gd` cave kinds,
  `tools/shot.gd` shots `cave-mushroom/crystal/flooded/deep/lava`.
- The phone is ~10× slower: nothing map-sized in a frame.
