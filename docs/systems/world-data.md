# World data: cells, shapes, grass

Status: ACTIVE. A Russian copy: [world-data_RU.md](world-data_RU.md).

**Purpose.** To keep the world's cells by chunks and everything that stands and lies on them; to compute the
shapes of natural ground (slopes, half-blocks cut along a diagonal) and to answer what meets a body.

**Files**
- `src/shared/world/world_cells.gd` — the cells in a `Chunk` by key (`chunk_at`, `chunk_key`; `>>` and `&`
  for negative coordinates); a missing chunk is read as air (below 0 — stone) and lets no bodies in. On the
  cells: trees, shrubs, `blockers` (the solid parts of things), `drops` (what lies), `grows` (what grows), the
  beds `fields` (chunk → the bed's cell → [the crop, days of growth, wet until] and for a wild sprout a fourth
  — the kind of tree; `field_at` / `set_field`; `set_cell` removes the entry, they are saved in `pack_chunk`
  «fields»), trails; `track_edits` / `note_edit`, `pack_chunk` / `unpack_chunk` for saving.
- `src/shared/world/world_data.gd` (inherits) — shapes: `update_shapes` (slopes and corners by column), the
  surfaces of slopes (`top_height`, `split_ne_sw`, `ground_height`), what meets a body (`blocks_body`,
  `blocks_part`, `ground_part`). Natural ground is built of a few shapes (the user's design, decision of
  2026-11-16, `docs/planning/mesher.md`): a cube; a sloping top whose corners are at full height or one level
  down (`slope_mask`: both corners of a side one level lower go down, a corner with only the column across it
  lower too where both columns beside may slope; all four down stays a cube), drawn as two flat triangles split
  along one diagonal — a hip or a valley where a ramp goes on beside the odd corner, a chamfer across it
  where the outline runs diagonally (`split_ne_sw`, computed from the shapes beside, not stored); and
  half-blocks: a cell cut (`corner_cuts`) or an open cell filled (`corner_fills`) at one corner at most, the
  whole half beyond the diagonal across it, so several in a row make one straight 45° face. A fill gives way
  where the ground beside is open round its own corner facing it (it is cut there), else the two would make a
  saw. A slope is cut only at a low corner where the ground drops more than a level beside; the ground under the lowest cut cell then slopes on down in the cut as an open top would (`_floor_slopes`, its low corners kept in its shape), so a steep diagonal slope has no step at the cut. `ground_height` is
  asked at every step of a beast and a body: it reads the cells and shapes of the column straight from the
  chunk (the rules `corner_fills`, `corner_cuts`, `slope_mask` are the same) and looks at the neighbouring
  columns only when the column has cut or filled corners.
- Soft slopes (`WorldData.soft_slopes`, set by nothing now: the combined mesher was parked by the user on
  2026-11-18, `docs/planning/mesher-merge.md`; checked by `shapes_test`): the blocky relief's shapes with the old
  slopes' look. No slope is steeper than 45°: a corner whose diagonal column drops two levels stays up, a top left
  with two opposite corners down is a cube (its corner cut instead, a straight wall on the diagonal), an inner
  corner goes down only where the tops beside go down there too; the tip of a ridge a cell wide ramps down to its
  end (`TIP_END`) instead of standing as a post. The client draws them without EdgeMesher (`Job.soft`): every
  natural slope bends level at its brow and foot by `SlopeMesher.SOFT_RADIUS`, cliffs stay sharp.
- Old slopes, a world setting and the default of «Новый мир» (`slopes` 1 in `LandLayout.DEFAULT_SETTINGS`, the
  row «Склоны: Старые», `WorldData.old_slopes` set by `WorldGen`; the world's folder gets `o1`; checked by
  `old_shapes_test`): the shapes of before the blocky relief (#722). A slope is a smooth bicubic patch
  (`surface_patch`, `make_patch`, `patch_height`), a corner may go down two levels into the covered cell below
  (`_update_deep`, `_deep_corner`, kept in that cell's shape bits 0..3; taken out by #743 and brought back by the
  user on 2026-11-18: without it a ramp's foot against a cliff shows a step), cut and filled corners take a triangle half a cell along each side and a cell may have several
  (`_old_update_corners`, `_old_in_corner`, `corner_at`); `ground_height` and `body.gd` `_cell_top` follow the patch. The client draws them with
  `src/client/world/old_slope_mesher.gd` (the old `slope_mesher.gd`), `MeshFaces.old_slopes` (curved cut
  pieces `OLD_CUT`, `_old_curve` by `Mat.corner_shape`, `_old_diag_wall`), the water's lips and foam, and the
  shader global `old_slopes` (`corner_distance`, `in_cell_corners`); no rounded edges (EdgeMesher off).
- `src/shared/world/grass.gd` — what grows on top of a ground cell (tiers of grass, flowers, ears, moss, the
  mods' plants `Plants`: on open grass, in the shade of crowns, in the woods — that shade and the grass
  `WOODS_EDGE` cells round it, `_near_crown` —, on banks; a frame `across` cards wide is one kind, its first
  column, which `foliage._column` draws as that many cards by `Plants.ACROSS`; fairy rings of the plant with
  `rings` on the open grass, one in that share of the `RING_GRID` squares, `fairy_ring`, `in_ring`), cloud noise
  for shadows.
- `src/shared/world/voxel_raycast.gd` — a ray through the grid of cells (Amanatides & Woo), for choosing a
  cell.

**Interface.** `get_cell` / `set_cell` / `set_material`, `is_natural`, `in_bounds`, `add_tree`, `remove_tree`,
`add_bush`, `add_drop` / `heap_drop` / `take_drop`, `tread` / `trail`, `column_masks`, `padded`, `biome_at`
(the column's biome from `Chunk.biome`, `NO_BIOME` without it); `is_solid`, `blocks_body`, `ground_height`,
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

**Tests.** `tests/unit/shapes_test.gd` (`corners`, `shapes`), `tests/unit/old_shapes_test.gd` (the same for old
slopes, with the mesher's patches), `tests/unit/body_test.gd` (`raycast`, `slopes`,
`steps`, `ground`), `tests/unit/generation_test.gd`.

**In more detail.** `plan/architecture/simulation.md` (the section «Storing the world»),
`plan/design/landscape.md`.
