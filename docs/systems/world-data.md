# World data: cells, shapes, grass

Status: ACTIVE. A Russian copy: [world-data_RU.md](world-data_RU.md).

**Purpose.** To keep the world's cells by chunks and everything that stands and lies on them; to compute the
shapes of natural ground (curved slopes, corners cut along a curve) and to answer what meets a body.

**Files**
- `src/shared/world/world_cells.gd` — the cells in a `Chunk` by key (`chunk_at`, `chunk_key`; `>>` and `&`
  for negative coordinates); a missing chunk is read as air (below 0 — stone) and lets no bodies in. On the
  cells: trees, shrubs, `blockers` (the solid parts of things), `drops` (what lies), `grows` (what grows), the
  beds `fields` (chunk → the bed's cell → [the crop, days of growth, wet until] and for a wild sprout a fourth
  — the kind of tree; `field_at` / `set_field`; `set_cell` removes the entry, they are saved in `pack_chunk`
  «fields»), trails; `track_edits` / `note_edit`, `pack_chunk` / `unpack_chunk` for saving.
- `src/shared/world/world_data.gd` (inherits) — shapes: `update_shapes` (slopes and corners by column), the
  surfaces of slopes (`surface_patch`, `ground_height`), what meets a body (`blocks_body`, `blocks_part`,
  `ground_part`). Natural ground has the curved slopes of #722 (once called «old slopes»; the blocky relief of
  2026-11-16 with flat triangles, half-blocks, rounded edges and the soft slopes of the parked combined mesher
  was taken out on 2026-11-20, every world, old saves and servers included, is drawn and walked with these; the
  world setting `slopes` no longer counts and is kept only for the saves' folders, `o1`). A slope's top has its
  low sides' corners down (`_old_slope`, `RAMPS`; an inner corner where only a diagonal neighbour is lower; two
  opposite low sides or none stay a cube) and is a smooth bicubic patch
  (`surface_patch`, `make_patch`, `patch_height`); at a shore of water on its level (`shore_top`) an outer corner (one corner high) or an inner one (one corner low) rises along the diagonal across that corner instead of on a square (`PATCH_DIAG`, a 13th number, `diag_corner`, `_diag_height`: its sides keep their curves), so the water's line runs straight along a diagonal shore, not in stairs; a corner may go down two levels into the covered cell below
  (`_update_deep`, `_deep_corner`, kept in that cell's shape bits 0..3; without it a ramp's foot against a cliff shows a step; the cell going down may be any wild ground, so scree over stone goes down round like sand, not cut sharp, `_deepable`), cut and filled corners take a triangle half a cell along each side and a cell may have several
  (`update_corners`, `in_corner`, `touches_corner`, `corner_at`; never over an open cell, a cave under a thin roof, where the cut would open a hole, unless the three columns beside are open from the level under it up to the sky: an overhang's roof is cut like its top, the inside of a cave is not); `ground_height` and `body.gd` `_cell_top` follow the patch. `ground_height` is
  asked at every step of a beast and a body: it reads the cells and shapes of the column straight from the
  chunk and looks at the neighbouring columns only when the point is in a corner's triangle. The client draws
  slopes with `src/client/world/old_slope_mesher.gd` (the ground under a cut corner of a slope that goes down
  into the cell below follows the slope down, `cut_floor`), `MeshFaces` (curved cut pieces `OLD_CUT`,
  `corner_curve` by `Mat.corner_shape`, `_diag_wall`), the water's lips and foam, and the shaders
  (`corner_distance`, `in_cell_corners`). An outer corner whose one high corner has the column across it lower
  (a ridge two cells wide on the diagonal) stays a cube cut at its corners, a straight diagonal wall as stone
  is, not a peak per cell (`_old_slope`). A cut or fill that a fill or cut beside goes on from is drawn
  straight whatever the material's corner shape (`ChunkMesher._diag_shape`, `_cap_shape`; tops and foam by
  `MeshFaces.DIAG_STRAIGHT` and the foam's shape bits), so diagonal walls and waterlines run straight and only
  their ends are rounded.
- `src/shared/world/grass.gd` — what grows on top of a ground cell (tiers of grass: bare, low, ordinary by the
  ground patch, and by the slow `meadow_noise` (`MEADOW_FREQ`, `MEADOW_TALL`) tall meadows and dense lawns of low
  grass two to three chunks wide; rare fields of ears as wide (`EAR_FREQ`, `EAR_FIELD`) on flat lowland; flowers, moss, the
  mods' plants `Plants`: on open grass, in the shade of crowns, in the woods — that shade and the grass
  `WOODS_EDGE` cells round it, `_near_crown` —, on banks, near water at the ground's level (`_near_water`,
  `near_water`, `water_cover`: sedge on the banks); a frame `across` cards wide is one kind, its first
  column, which `foliage._column` draws as that many cards by `Plants.ACROSS`; fairy rings of the plant with
  `rings` on the open grass, one in that share of the `RING_GRID` squares, `fairy_ring`, `in_ring`), cloud noise
  for shadows. `solid_plant(w, x, y, z)` — a plant that stops a body (`Plants.SOLID`: its `solid`, a cactus) on
  the cell's top and its root where `Foliage._column` draws it (the same draws of the cell's random numbers);
  quick to say no off the ground and the biomes such plants grow in, and what it found is kept per cell while
  the cell, its shape and its turf stay (`_solid_seen`).
- `src/shared/world/voxel_raycast.gd` — a ray through the grid of cells (Amanatides & Woo), for choosing a
  cell.

**Interface.** `get_cell` / `set_cell` / `set_material`, `is_natural`, `in_bounds`, `add_tree`, `remove_tree`,
`add_bush`, `add_drop` / `heap_drop` / `take_drop`, `tread` / `trail`, `column_masks`, `padded`, `biome_at`
(the column's biome from `Chunk.biome`, `NO_BIOME` without it), `peak_snow(y, x, z)` (the snow lying all year at
height `y` in a column: over `SNOW_LINE`, times the column's `Chunk.frost`, none in a desert's hills); `is_solid`, `blocks_body`, `ground_height`,
`surface_height`, `corner_cuts`; `Grass.kinds`, `plants_on`, `has_tall`; `VoxelRaycast.cast`. Constants:
`CELL` (0.5 of a world unit, 8 px), `CHUNK` (16), `SNOW_LINE` (18).

**Who uses it.** Everything that touches the world: the generator writes, the meshes read, the rules
(`world_actions`, `body`, `wildlife`, `placed`) read and change. `world_data.gd` has 37 dependent files.

**Limits and pitfalls**
- Never use -1 as «none» for world coordinates: negative coordinates are real.
- A chunk is 16×16 cells for the whole height (48 levels); a chunk's serialization is `pack_chunk` /
  `unpack_chunk`, the format changes only with a conversion of old saves.
- The shapes are recomputed by columns and only for natural ground (`set_natural`). A placed block is a cube,
  or a shape of build mode (`forms`, `form_chunks`: `FORM_RAMP` a bevel from below, `FORM_UPPER` a bevel from
  above, `FORM_STAIRS` steps in two half-levels; bits 2..3 — the side of the rise N, E, S, W): `set_form` /
  `form_at`, any `set_cell` returns a cube; they are saved in `pack_chunk` («forms»), over the network — in
  `CELLS` (`material | shape << 8`). The body and `ground_height` go by them through `form_top`.

**Tests.** `tests/unit/shapes_test.gd` (`corners`, `shapes`, diagonal ridges and shores, with the mesher's
patches), `tests/unit/body_test.gd` (`raycast`, `slopes`,
`steps`, `ground`), `tests/unit/generation_test.gd`.

**In more detail.** `plan/architecture/simulation.md` (the section «Storing the world»),
`plan/design/landscape.md`.
