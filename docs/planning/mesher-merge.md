# Old and new mesher merged: state and what is left

Status: DROPPED (2026-11-20): the user had the «new» (blocky) slopes taken out of the game and the code, so
the soft slopes and the merge built on them are gone too (code in git history before that PR). Below is history.
Earlier: PARKED by the user (2026-11-18): back to the old mesher. The world setting `slopes` 1 is
`WorldData.old_slopes` again (the old curved slopes, now a level a cell, no corners going down two levels);
`soft_slopes` is set by nothing and kept for this work. Parts 3-4 are in draft PR #742.
Earlier status: in a PR (2026-11-17). Threads «Совместить старый и новый мешер» (branch `claude/project-thread-swdhm6`)
and its part 2 (branch `claude/project-thread-dvxhsh`). Plan of the earlier mesher work: `docs/planning/mesher.md`.

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

## Done in part 2 (thread «Совместить старый и новый мешер, часть 2»)

- Test shapes: `diamond2`, `cone` rise a level every two rings (`(12|14 - m) / 4`), `slope2_diag` a level
  every two cells across the diagonal: their sides are true slopes, not half-block steps.
- Soft worlds: the tip of a ridge a cell wide (lower on three sides) ramps down to its end (`TIP_END`)
  instead of standing as a cube post (the posts at the ends of the diagonal ramps).
- Foam along diagonal slopes looks straight on the shots now; the steps left are where the outline itself
  steps.
- Tests: `old_shapes_test` checks the old slopes' code on a world switched to them by hand;
  `shapes_test._test_soft` (45° rule, ridge tips).
- Docs: `docs/systems/world-data.md`, `land_layout.gd`.

## Left

1. Decide (with the user) whether the old bicubic code and `old_slope_mesher.gd` are removed.
2. A `mesher_test` case for the floor under a cut (no flat lid) would be good.

## Tools (in the project library under notes/mesher-merge/, copied into a debug folder under tools, never committed)

- cells.gd, run with godot --headless --script on the copy, arguments x0 z0 x1 z1 slopes: prints
  each column's ground level, `~` if water on top, and the shape byte (bits 0..3 low corners NW NE SE SW,
  16<<k cut/fill).
- `dump.gd` + `render.py`: triangles of the test world's chunks, rendered with numpy (see
  `notes/edge-preview/`).
- Close shots: `ground-old-*-near` (pixel_scale 4) in `tools/shot/shots.gd`, crop and scale 3x with PIL.
