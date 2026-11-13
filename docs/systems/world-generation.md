# World generation

Status: ACTIVE. A Russian copy: [world-generation_RU.md](world-generation_RU.md).

**Purpose.** From a seed and settings to make a world without an edge: the layout of any window of columns
(height, water, top, biome, flags) and a chunk's cells in three stages. The result does not depend on the
order in which chunks are made (a test checks it), so far untouched chunks are forgotten and made again the
same.

**Files**
- `src/shared/world/currents.gd` — the rivers' currents (decision 178, answer 5А): `at(x, z)` — cells per
  second along the river (across the slope the layout's `side`) to the sea or a lake (where the distance to
  them in `LOOK` cells up and down the river falls), in the middle `SPEED`, at the bank the share `AT_BANK`;
  on a lake, in the sea, outside rivers and in a world with no layout of rivers (the test one) — zero; a
  column is laid out once (`lay_out` of three columns across) and stored. Where a river comes to the sea and
  turns away, it may flow from that place both ways or converge to it.
- `src/shared/world/land_layout.gd` — the layout from noises: slow noises on a lattice through `LATTICE`
  cells, the distances to the shore and a river; continents, mountains with scree and snow above
  `WorldData.SNOW_LINE`, rivers by steps (rapids, waterfalls), deltas, lakes (no nearer than `LAKE_SHORE` to
  the sea: a low shore stays between a lake and the sea, a lake does not cut into the shallows deeper than
  it), the climate (warmth, moisture), caves (`_tunnels`, the number by the setting `caves`; with the setting
`cave_shape` 1 (new worlds; 0 — old ones, hollows of 3D noise with pits and slits for mouths) halls of two
tiers, lenses with a domed ceiling and a floor rising gently to the rim, joined by galleries three to five
cells wide, every hollow three cells tall or more: `WorldGen._halls`; the way in is a descent
(`_cut_descents`, `DESCENT_*`): a trench three cells wide from dry ground that sinks three levels in four
cells, turns into a tunnel `DESCENT_HEAD` cells tall and ends on a hall's floor, which is filled up to it, with
rubble sloping a level a cell from its sides, so whoever comes down walks back up; a gallery into a
mountain's side goes on down the same way); with the
  setting `relief` 1 (new worlds; 0 — old ones) ridges, gorges and outliers where it is cool and damp, mesas
  with striped walls and canyons where it is hot and dry (`_ranges_and_mesas`); with the setting `climate` 1
  (new worlds; 0 — old ones) warmth goes by climate zones: the slow noise of a zone (`n_zone`, `ZONE_SLOWER`
  times slower than the former warmth noise), which the former noise only stirs by `ZONE_SPREAD` (`_zoned`),
  so the biomes of one zone lie in patches side by side, and the cold ones far from the hot; with height it
  gets cold half as strongly. `DEFAULT_SETTINGS` — the settings of the «New world» screen. Ground by the
  water above the sea rises to its level (`_banks`), and farther goes down a level per column, up to
  `BANK_SLOPE` columns: the bank of a river above a rapid, going past land laid out lower, is a slope, not a
  wall of one column.
- A body walks out of whatever it falls into (it climbs one level, `tools/escape_map.gd` checks a patch):
  ravines (`_ravine`) are `RAVINE_DEPTH` deep on a floor `RAVINE_FLOOR` wide and come up their sides in
  terraces of one level, by the distance from the noise's zero line (`_across`: the noise over its slope); a
  gorge (relief 1) goes down to its floor in such terraces too (`GORGE_*`); a swamp's pools and mires lie only
  on ground at the sea's level; a hollow of a few columns two levels or more below all round, with no way out
  within `PIT_REACH` columns, rises to a level under its lowest rim (`_fill_pits`, before the banks); a
  hollow among mesas walled round by a higher tier, or the lowland ringed by mesas, rises to the lowest tier
  round it (`_mesa_wall`: eight rays to `MESA_HOLLOW` cells over the tiers of every second column, kept in
  `mesa_tiers`). What is left: now and then a slot of a mesa's tier a couple of cells long, joined to the
  rest only across a corner.
- `src/shared/world/world_gen.gd` (inherits the layout) — writes the cells: `TERRAIN` (stone, ore, soil, top,
  water, caves) → `PLANTED` (trees by biome; needs TERRAIN on 3×3 around) → `SHAPED` (slopes, corners,
  shrubs; needs PLANTED around); the jobs `start` / `step` by a row or a tree; `find_spawn`, `pack` / a saved
  chunk comes at once SHAPED, `forget`.
- `src/shared/content/biomes.gd` — a column's biome by climate (`pick(t, m)`: the narrowest window first) or
  by relief (`where`: sea, beach, rock, plateau, swamp), its top, the shares of trees and shrubs, chances;
  `Biomes.NONE` — bare grass.
- `src/shared/content/trees.gd`, `bushes.gd` — the registries of species of trees and kinds of shrubs (the
  mods' data).
- `src/shared/world/growth.gd` — how a tree and a shrub grow into the world's cells: the shape of the trunk
  and crown (`trunk_box`, `height`, `fit`), `place` / `grow` / `fill`, `bush_fits` / `place_bush`; the
  generator plants a shrub only where there is no drop down around (`bush_level`), otherwise on a lone mound
  or at the edge of a cliff it hangs over air. The client puts a shrub on the ground under its middle
  (`Foliage.bush_foot`): if beside it was dug and under it became a slope, the shrub goes down onto the slope.
  Felling is a rule of the game: `src/shared/game/felling.gd` (`fell`), see [interaction.md](interaction.md).
- `src/shared/world/test_ground.gd` — the test world (opened from the «Testing» page): sites of relief,
  biomes, plants (a garden — pens of trees of 15 cells, east of it fields of ears), «Camp», «Star cave»
  (`TestGround.STAR_*`), a two-storey brick «House» (`HOUSE_*`: walls and floors — cells from `extras`, the
  door, windows, the ladder, furniture and lanterns — `plan_things`, put by `Placed.put_plan` only in a new
  test world), «Descent» and «Descent at 45°» (`DESCENT*`: steps 5×1 to the world's bottom, an entrance
  10×10×10) and «Beach» (`BEACH*`: gentle sand into a sea as deep as the bottom); it replaces `WorldGen` at
  `TestGround.SEED`.

**Interface.** `WorldGen.new(seed, 48, options)`, `lay_out(x0, z0, w, h, step)`, `find_place(what, near)`,
`column_color(lay, j)` (maps), `start(key, stage)` / `step(job, n)`, `stage_of(key)`, `missing(key, reach,
stage)`, `needed(key)` (what else is needed for a chunk to be built: the terrain within 2, trees within 1,
SHAPED itself), the signal `made(key, stage)` (a job finished), `forget(key)`, `generate_area(from, to)`
(tests, tools), `WorldGen.find_spawn(world, around)`.

**Who uses it.** `session.gd` (orders the stages around the players within a budget, forgets the far ones —
[session.md](session.md)), `chunk_streamer.gd` (`needed`, `made`), the maps (`minimap.gd`, `map_view.gd`,
`world_setup.gd`), beasts (`gen.lay_out`: the column's biome for a kind with `biomes`), `clock.gd` (weather by
place), `tools/map.gd`, benches.

**Data.** Biomes are the kind `biomes` (`content/biomes/<biome>/data/biomes.yaml`); species and shrubs —
`trees`, `bushes` (the «Plants» mods); materials by roles (`beach`, `bank`, `scree`, `snow`, `peat`, `salt`,
`ice`, `ore`, `trunk`, `crown`; no role — soil or stone is put). A biome's soil is `top`, and where the soil
noise is above `clay_above` — `clay_as` (clay, peat…): the soils' names are turned into materials by
`gen.grounds` (`Biomes.top`, `Biomes.clay_as`). The noises and relief are code (`land_layout.gd`), not moved
into data.

**Limits.** Worlds of old seeds after a change of biomes are laid out differently (accepted, decision 146);
the settings `relief` and `climate` are stored in the world so that old worlds do not change. A biome's zone
(`zone` in the record) is only a label for the map and reports: which zone lies where is decided by the
record's warmth window. A column's moisture is never below 0.2 (`m` in `_layout_row`: the noise gives
0.4–1.0, nearness of water takes it down to 0.2), so windows drier than 0.2 are empty; the shares of biomes
on the world's map — by a script over `gen.lay_out` with a step (like `tools/map.gd`). With `climate` 1 the
mountain zone is relief biomes: the rocks of mountains in the warmth window of the biome `glacier` — a glacier
(snow on slopes, ice in walls), open slopes up to `ALPINE_BELOW` levels under the line of rocks without a
forest in the window `alpine` — an alpine meadow; a dry channel in a land under snow (an icy waste) — snow,
not sand. A relief record (`beach`, `swamp`…) with its own warmth or moisture window is its variant
(`Biomes.VARIANTS`, `Biomes.relief`): with `climate` 1 a shore and a swamp in this window take it (a tropical
shore, mangroves), an open sea — the sea's variant (a tropical sea; lakes and rivers stay the sea). A chunk
stores the biome of each column (`Chunk.biome`, `WorldData.biome_at`): `_fill_row` writes it from the layout,
it is saved and goes to the client with the chunk; a chunk saved earlier has it laid out again by a row per
step (`_biome_row`). By it the client paints the soil and water (the biome's `tints`), and plants with a list
`biomes` grow only there. The rules ask for the biome through `WorldGen.biome_of(x, z)`: from the chunk, and
without it — by the layout of one column (the same, generation_test checks it). Trees grow on grass and on
the soils from the biome's `trees_on` (`Biomes.tree_grounds`: palms on sand; a palm's crown is one flat round
tier of points on the top, `Growth._palm`, the client draws it as a tier of a spruce, `Foliage._fronds`). A
chunk is made only by stages and in pieces: no generation of a whole chunk in a frame
(`tests/frame_test.gd`).

**Tests.** `tests/unit/generation_test.gd` (`generation`: independence from order; `mountains`, `caves`,
`cave_shape`, `relief`, `trees`, `bushes`, `custom_plants`), `tools/bench_gen.gd`, `tools/map.gd` (the map from
above), `tools/cave_map.gd` (the caves of a patch: from above and in slices from the side),
`tools/escape_map.gd` (the places of a patch a body falls into and cannot walk out of: a list of pits and a
picture; `cave_shape` checks a patch with it).

**In more detail.** `plan/design/landscape.md`, `plan/design/world.md`, `plan/design/trees.md`,
`plan/architecture/performance.md`; the decisions about relief in the journal `plan/README.md`.
