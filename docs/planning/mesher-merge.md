# Old and new mesher merged: state and what is left

Status: ACTIVE (2026-11-17). Thread «Совместить старый и новый мешер». Branch `claude/project-thread-swdhm6`
(work in progress, no PR yet). Plan of the earlier mesher work: `docs/planning/mesher.md`.

## What the user asked (2026-11-17, Russian, paraphrased)

Old mesher by default; take the best of the new one into it (Claude proposes what). Must do:
1. No slopes steeper than 45° in generation or mesher (45° or 90° only).
2. Update the test worlds for that.
3. Every diagonal of the relief straight, not a wave (test world, slopes 1, cell 197, -231, turn 270°).
4. No strange relief like the one-cell diagonal wall at 172, -211 (`zigzag`).
5. No corners sticking out on diagonal relief (196, -303, level 22, turn 270°).
6. No joins of smoothed and sharp (201, -318, turn 90°): never make them, or smooth the sharp edges too.
7. Diagonal planes flat; if a material's smoothing says otherwise, no sharp corners (138, -294, the `cone`).
Places are cells of the test world (`World: test`, settings `slopes: 1`); shots `ground-old-*` in
`tools/shot/shots.gd` (run with `--old-slopes`).

## Proposal posted (waiting for the user's pick)

From the new into the old: one level a cell (no deep corners), diagonal cut over the whole diagonal
(straight), corner cells as two flat triangles, no EdgeMesher (cliffs sharp, fast). Open question:
- А (recommended, being built): straight slopes flat 45°, bent soft at brow and foot for every material
  (`SlopeMesher.bend`, radius 0.5). In code: the world setting `slopes` 1 now means the NEW shapes drawn soft.
- Б: keep the old bicubic S-curve on straight ramps, flat triangles only on diagonals (needs seam work).
If the user picks Б: swap the ramp profile in `SlopeMesher` for soft worlds (the old bicubic code is still in
`world_data.gd` «Old slopes» section and `old_slope_mesher.gd`, now unreachable).

## Done on the branch

- `settings.gd`: «Новый мир» defaults to slopes 1 (`world_slopes` 1; a saved 0 is taken back once by the
  `old_slopes_default` marker). `LandLayout.DEFAULT_SETTINGS` keeps 0 so saves without the key stay as made.
- `WorldData.soft_slopes` (set by WorldGen for slopes 1; `old_slopes` is no longer set by anything).
  `ChunkMesher.Job.soft`: no EdgeMesher (`EdgeMesher._natural` false), `SlopeMesher.rounding` = `SOFT_RADIUS`
  0.5 for every natural material.
- 45° rule (soft worlds only, `update_slopes`): a low corner whose diagonal column drops two levels (open at
  y and y-1) stays up; a top left with two opposite corners down becomes a cube (then cut: a straight
  half-block wall). Inner corners (only the column across lower) are re-checked after all slopes: they go
  down only where both tops beside go down there too (`inner` list).
- Bug of the new mesher too (#729): a sloping floor under a cut drew its cube top and bottom as well (a flat
  lid over the slope: the dark sawtooth along diagonal slopes). Fixed in the cube face loop (`floor_k`).
- Cut walls over such a floor reach `CUT_SKIRT` 0.08 down into it (a hairline crack showed).
- Shore water also over a floor slope under a cut (the waterline stepped round the cut cells).
- Pictures: project library `survivium-builds/old-new-merge/` (`before-*` old vs new, `variant-a-*` first
  draft, `now-*` current).

## Left

1. Foam/waterline still notched a little along diagonal slopes in water (`ground-old-corner-near`), and the
   stepped foam round the 1-level diamonds in water (`ground-old-flat`): the water lips follow cells.
2. `diamond2` / `cone` (2–3 levels, rings a cell wide on the diagonal): the upper rings are now half-block
   cliffs (the 45° rule) and look stepped; decide with item 2 (test shapes): rings two cells wide on the
   diagonal make true 45° slopes. Same for `slope2_diag` (band of 1 should be two cells wide on the diagonal:
   `rise = clamp((px + pz - 9) / 2, 0, 2)`), pillars (now diamond-topped prisms).
3. The small notch at the foot end of `slope2` / `slope2_diag` in water (`now-seam.png`, bottom tips).
4. Test world (item 2): update `test_ground.gd` shapes and their doc comment.
5. Tests: `old_shapes_test` line ~71 expects `TestGround({"slopes":1}).world.old_slopes` (now false): change
   to `soft_slopes`; add a `shapes_test` case for the 45° rule (diagonal two lower → cube + cut) and a
   `mesher_test` case (floor under cut has no flat lid). Run `run_tests -- generation mesher shapes store`.
6. Docs: `docs/systems/world-data.md` (shapes, soft slopes), `land_layout.gd` comment on `slopes`,
   `world_setup.gd` labels (`[slopes_old]` text may need renaming, en+ru), `docs/planning/mesher.md`.
7. Decide (with the user) whether the old bicubic code and `old_slope_mesher.gd` are removed.
8. PR with «Что нового» lines, screenshots, merge on green CI.

## Tools (project library `notes/mesher-merge/`, copy into `tools/_dbg/`, never commit)

- `cells.gd`: `godot --headless --path . --script res://tools/_dbg/cells.gd -- x0 z0 x1 z1 slopes` prints
  each column's ground level, `~` if water on top, and the shape byte (bits 0..3 low corners NW NE SE SW,
  16<<k cut/fill).
- `dump.gd` + `render.py`: triangles of the test world's chunks, rendered with numpy (see
  `notes/edge-preview/`).
- Close shots: `ground-old-*-near` (pixel_scale 4) in `tools/shot/shots.gd`, crop and scale 3x with PIL.
