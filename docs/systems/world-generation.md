# World generation

Status: ACTIVE. A Russian copy: [world-generation_RU.md](world-generation_RU.md).

**Purpose.** From a seed and settings to make a world without an edge: the layout of any window of columns
(height, water, top, biome, flags) and a chunk's cells in three stages. The result does not depend on the
order in which chunks are made (a test checks it), so far untouched chunks are forgotten and made again the
same.

**Files**
- `src/shared/world/currents.gd` — the rivers' currents (decision 178, answer 5А): `at(x, z)` — cells per
  second along the river (across the slope the layout's `side`), one way all along it, in the middle `SPEED`,
  at the bank the share `AT_BANK`; on a lake, in the sea, outside rivers and in a world with no layout of
  rivers (the test one) — zero; a column is laid out once (`lay_out` of three columns across) and stored.
  Which way a river runs is found once for the whole river (`_follow`): its middle line (`side` = 0, `_probe`,
  layouts of 2×2 columns) is followed both ways `STEP` cells a step, at most `TRACE` steps, through lakes and
  dry gaps under `DRY_GAP` steps, to its ends (`_trace_step`): the sea, where it dries up, or unknown; it runs
  towards the sea, then towards the unknown end, between ends of one kind down from the higher water, else by
  where the ends are (`_way`); with both ends unknown, the old rule (where the distance to the sea or a lake
  `LOOK` cells up and down the river falls). The way is kept by squares of `BLOCK` cells along the line, and a
  trace that comes to a kept square takes its way, so a river never turns back. The search runs `BUDGET_US`
  a frame, one river at a time; till it ends the river stands still (`budget_us` — more in tests and tools).
- `src/shared/world/land_layout.gd` — the layout from noises: slow noises on a lattice through `LATTICE`
  cells, the distances to the shore and a river; each row of a window in two passes, `_water_row` (relief, sea,
  lakes, rivers, deltas) then `_cover_row` (climate, ground, biome); continents, mountains with scree and snow above
  `WorldData.SNOW_LINE`, rivers by steps (rapids, waterfalls), deltas, lakes (no nearer than `LAKE_SHORE` to
  the sea: a low shore stays between a lake and the sea, a lake does not cut into the shallows deeper than
  it), the climate (warmth, moisture), caves (`_tunnels`, the number by the setting `caves`; with the setting
`cave_shape` 1 (new worlds; 0 — old ones, hollows of 3D noise with pits and slits for mouths) halls of two
tiers, lenses with a domed ceiling and a floor rising gently to the rim, joined by galleries three to five
cells wide, every hollow three cells tall or more: `WorldGen._halls`; the way in is a descent
(`_cut_descents`, `DESCENT_*`): a trench three cells wide from dry ground that sinks three levels in four
cells, turns into a tunnel `DESCENT_HEAD` cells tall and ends on a hall's floor, which is filled up to it, with
rubble sloping a level a cell from its sides, so whoever comes down walks back up; a gallery into a
mountain's side goes on down the same way; kinds of caves (biomes `where: cave`, `Biomes.CAVES` by tier): each
region of about `CAVE_REGION` cells of a tier, its edges bent by `CAVE_WOBBLE`, is one kind picked by `cave_share`
(`WorldGen.cave_kind(x, z, tier)`), and `_cave_kind_cells` gives its halls the kind's floor (`cave_floor`:
mycelium, on which `Grass._cave_floor` grows moss and mushrooms, glowing ones too), a pool of `pools` where the floor
dips deepest (lava; the hall's size over `pools_from` of `HALL_MOST`), still water to `flood` (at most
`FLOOD_HEADROOM` under the ceiling, its bits in `_hall_water`), blocks of `crystals` on the floor or under the
ceiling by `crystal_chance`, and `cave_walls` (deep rock) `CAVE_WALL` levels round its halls and in a thinning shell
beside them; with no cave bundle the caves are bare stone as before). Lava (`burns`) burns a body that stands
on it or walks into it and throws it back (`Character._touch_hot`), and a thing dropped on it burns up
(`WorldCells.add_drop`, a death's sack stays); lava and crystals (`light`) light the cave round them
(`GlowLights`, `Effects.lit`). Water is still, so nothing yet turns lava under water to stone; with the
  setting `relief` 1 (new worlds; 0 — old ones) ridges, gorges and outliers where it is cool and damp, mesas
  with striped walls and canyons where it is hot and dry (`_ranges_and_mesas`); with the setting `climate` 1
  (new worlds; 0 — old ones) warmth goes by climate zones: the slow noise of a zone (`n_zone`, `ZONE_SLOWER`
  times slower than the former warmth noise), which the former noise only stirs by `ZONE_SPREAD` (`_zoned`),
  so the biomes of one zone lie in patches side by side, and the cold ones far from the hot; with height it
  gets cold half as strongly; with the setting `landscape` 1 (new worlds; 0 — old ones, the stage 2 landscape)
  the noises of warmth, moisture and zones run `BIG_BIOMES` times slower with `BIG_BIOMES_OCTAVES` more octaves
  and their field bent by `WARP` cells (`_warp`, scaled with the window's step in `_sample`), so a biome takes
  minutes to walk across and its edges still wind; the river noises run `RIVER_LONGER` times slower (fewer,
  longer, straighter rivers), a river is 1 to `RIVER_WIDEST` times wider by the moisture of its land (`RIVER_DRY`..`RIVER_WET`: narrow through deserts and tundra, wide through forests, swamps and jungle), widens over `MOUTH_REACH_WIDE` cells before
  its mouth and its bed sinks a level every `RIVER_SINK` cells in from the bank, to `RIVER_DEEP`; lakes are
  fewer and bigger (`LAKES_WIDER`) and the land dries away from water more slowly (`WET_FADE_WIDE`), so no
  ring of another biome lies round every pond. Also with `landscape` 1: land of a climate biome with `by_water` within its
  `by_water_reach` cells of a lake (a low one in the plains, as lakes are laid) or of a river that carries water
  (`OASIS_FLOW` over the river noise's start; dry beds do not count) is that biome (a desert's oasis); a swamp's level
  open ground stands a level up in a hummock on the share `hummocks` of its columns; the plateau and the alpine
  meadow show their record's stone and `clay_as` patches (`_patches`, scree among them: the ground name `scree`). Also with
  `landscape` 1, volcanic land (`Biomes.VOLCANIC`, a biome `where: volcanic`; none without its bundle): where the region
  noise `n_volcano` (`VOLCANO_FREQ`, warped, the last of `window_noises`, `volcano_grid`) is over the record's
  `region_from` the land is that biome whatever the climate (never within `VOLCANO_CALM` of the world's middle, where
  the start is looked for, `_calm`), its ground the record's `ground` with `ground_below` and
  `ground_above` patches (basalt, black sand, ash; black sand by the sea); in each square of `CONE_GRID` cells a cone
  stands with the chance `cones` where the region noise at its middle is `CONE_INSIDE` higher (`_cone_at`, cached in
  `cones`): `cone_rise` levels over the land at its rim, `cone_reach` cells round (shrinking within `CONE_COAST` of
  the coast), its slope a power `CONE_POWER` of the distance, its crater (`crater_share` of the reach) `CRATER_DEPTH`
  under the rim and floored with `crater` (lava); the cuts `CONE` and `CRATER` keep rivers, lakes and cave mouths off
  it. Hot springs lie in the deepest hollows of the low patches, where the soil noise is under `springs_below`: a pool
  a level or two into the ground, on black sand, its water tinted by the record. With the setting `shores` 1 (new worlds; 0 — old ones) the low land by the coast lies `SHORE_LOW` levels lower, down to the sea's level, fading out `SHORE_FADE_FROM`..`SHORE_FADE_TO` cells inland, so it lies level with the water for tens of cells (the surf washes over it, see [chunks.md](chunks.md)); the shallows off it run `SHALLOWS_WIDE` cells, and a lake's shore rises a level every `LAKE_SHORE_RUN` cells. `SETTING_KEYS` lists the settings for the saves and menus. `DEFAULT_SETTINGS` — the settings of the «New world» screen. Ground by the
  water above the sea rises to its level (`_banks`), and farther goes down a level per column, up to
  `BANK_SLOPE` columns: the bank of a river above a rapid, going past land laid out lower, is a slope, not a
  wall of one column. Beyond its banks a river digs the land into a valley that rises a level a column; a
  river through land more than ten levels over its bed (a range's crest at a river's head, a plateau) runs in a
  canyon instead: its walls stay sheer and the land beyond keeps its height (dug into a valley, it left the
  walls standing as a stone ridge two columns thick).
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
  and crown (`trunk_box`, `height`, `fit`; a trunk always goes up into its crown, `LOWEST_POINT`), `place` / `grow` / `fill`, `bush_fits` / `place_bush`; the
  generator plants a shrub only where there is no drop down around (`bush_level`), otherwise on a lone mound
  or at the edge of a cliff it hangs over air. The client puts a shrub on the ground under its middle
  (`Foliage.bush_foot`): if beside it was dug and under it became a slope, the shrub goes down onto the slope.
  Felling is a rule of the game: `src/shared/game/felling.gd` (`fell`), see [interaction.md](interaction.md).
- `src/shared/world/test_ground.gd` — the test world, two of them (the world setting `slopes` 0 and 1, folders `test` and `test-o1`), listed last on «Load a world» in the developer mode (`WorldList.test_worlds`): sites of relief,
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
(tests, tools), `WorldGen.find_spawn(world, around)`. The spawn guess (`spawn_guess`) is the first good column of rings 16 cells apart out to `SPAWN_RINGS` (a biome a player may start in, any when no climate biome is loaded, a few levels over the sea, out of woods, rivers and rough land), found in `_init` or, with `spawn` false, a little at a time by `seek_spawn(budget_us)` (the map of «New world»). The biomes decide only where the start is, never the relief: switching a biome bundle off moves the start to the nearest meadow left, the land stays.

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
record's warmth window. A column's moisture is never below 0.2 (`m` in `_cover_row`: the noise gives
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
