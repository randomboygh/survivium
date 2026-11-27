# The new relief mesher: blocks, corners, rounding — state and what is left

Status: DROPPED (2026-11-20): the blocky relief, its EdgeMesher, SlopeMesher and the setting «rounded terrain»
were taken out; every world has the curved («old») slopes. History only. Earlier: ACTIVE (2026-11-17). Design agreed in the thread «Переделать мешер на несколько видов блоков»;
implemented in the thread «Сделать новый мешер рельефа». Architecture picked by the user: shapes computed in
shared `WorldData` (server and client agree, no save conversion), rounding and bevels client-only.

## Progress

- PR 1 (shapes and walking): one-level corners only (`_update_deep` gone), corner heights 0/1 from the 2×2
  columns, `split_ne_sw` (hip/valley through the odd corner where a ramp goes on beside it, chamfer across
  it otherwise; not stored, computed from the shapes beside), planar `top_height` for walking and drawing,
  full-diagonal half-blocks (one corner per cell; a fill gives way where the ground beside is open round its
  facing corner, so a staircase gets one straight line of cuts), water lips the same, shaders
  (`corner_distance`, `in_cell_corners`) on the full diagonal. `Mat.corner_shape` and `CORNER_P` are kept,
  unused by the geometry, for PR 2. Merged as #722.
- Fix (user 2026-11-17: the small triangle walls must go): the ground under the lowest cut cell slopes on
  down in the cut (`WorldData._floor_slopes`, `SlopeMesher.slope_faces(only)`, drawn in the material above),
  so steep diagonal hills meet without walls.

- PR 2 part 1 (edges by material, branch `claude/project-thread-2ppwze`): material fields `edge`
  (sharp | round | bevel) and `edge_size` (the radii table), `edge_mesher.gd` (removed): per level one
  height function over the plan of pieces (whole cell / diagonal half): brows drop by the material's curve, feet
  heap up by the wall's curve, each cell draws its top on a grid (`GRID`, lines at 0, 1/8, 1/4, 3/4, 7/8, 1) and
  its walls to that height, so cells meet without seams; round edges get the curve's normals (smooth), bevels
  flat; placed blocks stay sharp (`wild_masks`). Test `mesher_test._test_edges`; shots `ground-edges-*`;
  pictures `survivium-builds/world/mesher-blocks/pr2/`. Geometry preview without the game (a tool that dumps a
  chunk's triangles, a numpy renderer): `survivium-builds/world/mesher-blocks/edge-preview/` in the project library.
  Done in the second thread: the light square outline inside the stone ring was the shader's rim (edge codes)
  along a whole cell's side where a filled half goes on at the same height (`_level_edges` drops them);
  layered cliffs: a soft layer over a hard one stands back 1/8 block (`LEDGE`), a ledge of the hard top stays
  (straight sides only; a diagonal side of a soft layer still stacks straight).
  Speed (found 2026-11-17: meshing was ~6x slower than main, CI `progress (other)` timed out at 1200 s). Thread
  «Ускорить мешер со скруглениями», PR #733 (supersedes #732). `tools/bench_mesh.gd` (16x16 chunks round the spawn;
  «again» meshes them a second time with the static caches warm, as after a while of play), in the cloud
  container, min of 3: main 1871 / 1850 ms, 663805 vertices; #732 ~10300 ms, 2281489; #733 ~4400 / ~3600 ms,
  1276112 (~2.3x cold, ~1.95x warm). The user asked for 1.5x before merging (2026-11-17).
  Done: covered cells only for ledges; whole tops on the `lines` the brows need; `_entry` caches per brows+feet the
  top shape, its lines, heights along the sides and the wall shapes; job caches of `segments`, `feet`, `_info`;
  `feet` builds the above level's brows itself (no `_ledge`), skips a bare level.
  Tried, not worth it: a key of the 3x3 cells' packed codes (`_code`) to skip `segments`: codes for ~147k cells a
  pass cost more than the segments, and cold only 25% of keys repeat; `_far` box tests before distances; filling
  UV2/colours with `fill`.
  Where the time is now (cold pass): `prepare` ~1.2 s (70k calls; `segments` ~0.5 s for 23k, a third of them end
  with nothing to round; `feet` ~0.35 s), `draw` ~1.4 s (new top shapes ~0.45 s for ~3.5k: eval ~70 us, triangles
  ~60 us each; emitting ~4 shapes a cell). Without walls ~0.2-0.3 s less, without feet ~0.7 s less. GDScript here
  costs ~50 ns an operation: the floor is the per-cell look at the 3x3 window.
  Merged as #733 at ~2.4x cold / ~1.9x warm (the user's pick, 2026-11-17; option B, edge codes kept in
  WorldData, waits for the phone's verdict on loading).
- PR 2 part 2a (slopes): SlopeMesher bends the slopes of natural ground of a round material: `bend` maps the plain
  height so the top lies level within `edge_size` of the brow and the foot, only where flat ground goes on past
  the corner (`corner_bends`, flags per lattice corner so the cells round it agree; a long slope stays straight);
  hips/valleys on the diagonal rounded, fading out at the cell's sides (`_plain`), so a hip down several levels
  shows soft lenses pinched at the corners (accepted: the straight cells beside meet it there). Hard (bevel)
  slopes stay flat: a one-sided bevel cannot lie level at the cell's edge. Bench: ~4.6 s cold, ~3.8 s warm,
  1475620 vertices (+16% over #733). Test `mesher_test._test_bent_slopes`; preview tool
  `survivium-builds/world/mesher-blocks/edge-preview/slope_preview.gd` in the project library.
- PR 2 part 2b (corners in plan, thread «Скруглить рельеф по материалам, часть 3»): EdgeMesher rounds a convex
  square corner of a level's plan (a cliff's lower levels under a chamfered top, diamond tips of halves): the
  brows stop at the arc's tangent points, a corner record takes the corner (`_add_corners`), points cut off move
  onto the arc / the bevel's cut (`_project`) in the top and the walls (normals from the arc), the ground below
  fills the strip under a cut corner (`_floor`), the heaps below follow the arc. Corners of 135° (a side meeting
  a diagonal, most corners of natural ground after PR 1): the arc would cut ~0.03 block, so only the top rounds
  there (no mitre), the walls keep their corner; a bevel keeps its mitre there. Inner corners: no fillet (they are
  135° too after PR 1, and the foot heap already fills them). Bench (this container, slower than before: main
  ~7.1-7.5 s cold / ~6.5-7.6 warm): ~10.7-10.9 cold / ~8.2-8.5 warm, 1692905 vertices (+15%). Test
  `mesher_test._test_plan_corners`.
  Left: the remaining `corners` field / `CORNER_P` / shader `corner_shapes` go in PR 4.
- Spec (Claude doc, Russian, the user's words): https://claude.ai/artifact/1q8gbPYdyqXoDE5bMxKjoT
- Pictures: project library `survivium-builds/world/mesher-blocks/` (`blocks-1-main.png` … `blocks-10-all.png`),
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
- Meshes: `slope_mesher.gd` (removed) (the curved patches), `chunk_mesher.gd` (40 KB, cubes and sides,
  `_side_tiles`), `form_mesher.gd` (build forms), `water_mesher.gd` (diagonal water edges, #706), shader
  `world.gdshader` (slopes use `screen_plane` texels and the foot shade of #449).
- Tests: `tests/unit/shapes_test.gd`, `body_test.gd` (`slopes`, `ground`), test world ground «Сочетания»
  (`test_ground.gd`, [relief-combos memory]) for shots.

## Proposed PRs (architecture — confirm with the user first, CLAUDE.md step 3)

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

## Two switches (the user's pick 2026-11-17, after #735)

1. Done, #736: graphics setting «rounded terrain» (`rounded_ground`, per player, `ChunkMesher.rounded`): off, no
   EdgeMesher and no bent slopes (natural ground sharp, ~3x quicker to build: bench 2.3 s vs 7.1 s). #737:
   `progress_test` runs with it off (main's `progress (other)` passed 1200 s after #735).
2. Done (this PR, branch claude/project-thread-b9qmtf): old slopes (before #722) as a world setting, both codes
   side by side. `slopes` in `LandLayout.DEFAULT_SETTINGS` (0 new, the default and what older saves get; 1 old),
   row «Склоны: Новые / Старые» on «Новый мир», `WorldData.old_slopes` set by `WorldGen`. Unlike the plan the
   world's folder gets `o1` (as every other setting: one seed with both slopes is two worlds) and a world with old
   slopes has no EdgeMesher at all (`job.rounded` off): it looks as before #722. Old code restored in
   `world_data.gd` (an «Old slopes» section, dispatch in `update_slopes`, `update_corners`, `ground_height`,
   `surface_height`, `corner_heights`, `in_corner`/`touches_corner` `old` flag, `in_cuts`), `body.gd`,
   `foliage.gd`, `old_slope_mesher.gd` (the old `slope_mesher.gd` whole), `mesh_faces.gd` (`OLD_CUT`,
   `_old_curve`, `_old_diag_wall`, `quarter_kind`), `chunk_mesher.gd`, `water_mesher.gd`, shader global
   `old_slopes`. Test `old_shapes_test` (the old shapes_test). Shots `tools/shot.gd -- --old-slopes`, pictures
   in survivium-builds/world/old-slopes/.
