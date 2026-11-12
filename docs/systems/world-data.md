# World data: cells, shapes, grass

Status: ACTIVE. A Russian copy: [world-data_RU.md](world-data_RU.md).

**Purpose.** To keep the world's cells by chunks and everything that stands and lies on them; to compute the
shapes of natural ground (slopes, bevelled corners) and to answer what meets a body.

**Files**
- `src/shared/world/world_cells.gd` — the cells in a `Chunk` by key (`chunk_at`, `chunk_key`; `>>` and `&`
  for negative coordinates); a missing chunk is read as air (below 0 — stone) and lets no bodies in. On the
  cells: trees, shrubs, `blockers` (the solid parts of things), `drops` (what lies), `grows` (what grows), the
  beds `fields` (chunk → the bed's cell → [the crop, days of growth, wet until] and for a wild sprout a fourth
  — the kind of tree; `field_at` / `set_field`; `set_cell` removes the entry, they are saved in `pack_chunk`
  «fields»), trails; `track_edits` / `note_edit`, `pack_chunk` / `unpack_chunk` for saving.
- `src/shared/world/world_data.gd` (inherits) — shapes: `update_shapes` (slopes and corners by column), the
  surfaces of slopes (`surface_patch`, `ground_height`), what meets a body (`blocks_body`, `blocks_part`,
  `ground_part`). `ground_height` is asked at every step of a beast and a body: it reads the cells and shapes
  of the column straight from the chunk (the rules `corner_fills`, `corner_cuts`, `slope_mask` are the same)
  and looks at the neighbouring columns only in the corner's triangle.
- `src/shared/world/grass.gd` — what grows on top of a ground cell (tiers of grass, flowers, ears, moss, the
  mods' plants `Plants`), cloud noise for shadows.
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

**Tests.** `tests/unit/shapes_test.gd` (`corners`, `shapes`), `tests/unit/body_test.gd` (`raycast`, `slopes`,
`steps`, `ground`), `tests/unit/generation_test.gd`.

**In more detail.** `plan/architecture/simulation.md` (the section «Storing the world»),
`plan/design/landscape.md`.
