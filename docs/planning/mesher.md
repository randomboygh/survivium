# The new relief mesher: blocks, corners, rounding — state and what is left

Status: ACTIVE hand-off note (2026-11-17) of the thread «Переделать мешер на несколько видов блоков» for the
thread that implements it. No code is changed yet: this thread agreed the design with the user in pictures.

- Spec (Claude doc, Russian, the user's words): https://claude.ai/artifact/1q8gbPYdyqXoDE5bMxKjoT
- Pictures: project library `survivium-builds/mesher-blocks/` (`blocks-1-main.png` … `blocks-10-all.png`),
  the Python renderer that drew them in `src/` there (numpy z-buffer, 3/4 view, the game's 45° pitch).

## The user's picks (2026-11-16/17)

1. Natural relief is built from a few shapes, every slope 45° and one level high:
   cube; slope (4 turns); half-block cut by a vertical diagonal (4); the slope cut by a diagonal, big part
   «4а» and small part «4б» (8 each, 4 turns × mirror); chamfer corner «5» (one high corner, one plane, 4)
   and inner corner «6» (one low corner, 4). Any of them = the cell split by one diagonal into two triangles,
   each with heights 0/1 at its corners.
2. Corners (variant А): where two straight slopes meet the corner is a hip — outer 4б+4б in one cell, inner
   4а+4а (the crease through the odd corner); where the outline runs diagonally the corner is a chamfer (5, 6:
   crease past the odd corner). A diagonal slope is 5 and 6 in turn (steps of small flats, accepted).
3. Several diagonal cuts in a row make one straight 45° face; edges run only at 0°, 45°, 90° (a 2:1 edge stays a
   small staircase). A diagonal cliff is half-blocks.
4. No upside-down shapes (the 45° camera never sees their underside).
5. Only natural relief changes; build mode forms (ramp, upper, stairs) stay.
6. Edges by material (numbers in the mod's YAML, not in code): soft materials round every edge — vertical
   corners in plan, the brow on top, the foot — and on slopes also the diagonal hips; hard materials get a flat
   bevel of 1/4 block on every edge (outer and inner). Radii in blocks: sand 0.5, snow 0.5, peat 0.4,
   dirt/grass 0.35, scree 0.3, clay 0.25; bevel 0.25: stone, ores, ice, salt. Max 0.5.
7. Extras: a small heap (fillet) at the foot of soft cliffs; layered cliffs — each layer by its own material
   (clay over stone is inset and rounded, a narrow stone ledge stays); where soft meets hard on one level only
   the soft side rounds; grass follows the rounded brow; snow on stone: only the snow rounds.
8. Rounding is drawn only: cells, walking, digging, the server go by the shapes of 1–3.
9. Placed blocks: a new build-mode toggle «sharp / like natural», for the whole blueprint, remembered between
   visits; stored with the placed block in the world data (all players see it).

## What exists (read before changing)

- Shapes: `src/shared/world/world_data.gd` `update_shapes` → `update_slopes`, `update_corners`, `_update_deep`
  (a corner may drop two levels), shape byte per cell (NW 1, NE 2, SE 4, SW 8 = lowered corners), `make_patch`
  / `surface_patch` (curved surface over corner heights), `ground_height` (every step of every body), `form_top`
  for build forms. Users: `body.gd`, `placed.gd`, `growth.gd`, `world_gen.gd`, `materials.gd`, `drifts.gd`.
- Meshes: `src/client/world/slope_mesher.gd` (the curved patches), `chunk_mesher.gd` (40 KB, cubes and sides,
  `_side_tiles`), `form_mesher.gd` (build forms), `water_mesher.gd` (diagonal water edges, #706), shader
  `world.gdshader` (slopes use `screen_plane` texels and the foot shade of #449).
- Tests: `tests/unit/shapes_test.gd`, `body_test.gd` (`slopes`, `ground`), test world ground «Сочетания»
  (`test_ground.gd`, [relief-combos memory]) for shots.

## PRs (architecture picked by the user 2026-11-17: shapes shared, rounding client-only)

Recommended: shapes stay computed from the cells in shared `WorldData` (server and client agree, old saves
need no conversion); rounding and bevels are only client mesh geometry from material fields.

1. Shared shape rules: one-level corners, the split diagonal (hip / chamfer) as a shape bit, diagonal half-cells
   on staircase steps (decide: fill the empty cell beside two solid sides, as drawn, or cut the jutting one);
   `ground_height` on planar triangles; `shapes_test`, `body_test`; mesher draws flat planes; water edges
   agree.
2. Edges: material fields (e.g. `edge: round|bevel`, `edge_size`) in `content_schema.gd` and the YAMLs; bevel and
   rounding (2–3 segments, phone budget) on brows, vertical corners, feet, hips; foot heap; layers; snow.
3. Build-mode toggle «sharp / like natural» (bit beside `forms`, `pack_chunk`, `CELLS` over the network,
   remembered in settings, `[key]` texts en+ru).
4. Remove the curved patch code, docs (`docs/systems/world-data.md`, rendering pages), screenshots
   `survivium-builds/mesher/`, «Что нового» lines.
