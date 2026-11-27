# Chunks on screen

Status: ACTIVE. A Russian copy: [chunks_RU.md](chunks_RU.md).

**Purpose.** To build the meshes of the chunks that the server's session generated around the player
([session.md](session.md)) within the frame's budget, to hold the slice of levels and the caps above the
slice, to free the far meshes.

**Where to look.** This page is the overview; the files and the detail are split by topic into `chunks/`: read
only the page the change reaches.

| Topic | Page |
|---|---|
| The queue and budgets of chunk building, the chunk's mesh. | [chunks/streamer-mesher.md](chunks/streamer-mesher.md) |
| Grass, plants and crowns, standing trees, the fog at the edge, buffers. | [chunks/foliage-trees.md](chunks/foliage-trees.md) |

**Interface.** `ChunkStreamer.prepare(gen)`, `build_near(n)`, `run_jobs(spent)`, `gen_budgets()`,
`take_work()`, `set_focus(at)` (the chunks are built round `at`: where the player comes back behind the death
screen, or where `Trip` goes; the chunks on its screen at the lag budget, `focus_built()` — their share built), `update_cut(delta)`, `update_caps()`, `refit_boxes()`, `on_cell_changed(cell)`,
`remesh_chunk(key)`, `set_holes(cells)`; `ChunkMesher.start` / `start_rect` / `step` / `finish` / `patch` / `reach`,
`Foliage.start` / `start_part` / `part_columns` / `step` / `finish` / `patch`.

**Depends on.** `Session` (zones, budgets, `make_chunk`, `forget_far`), `WorldGen` (`needed`, `made`),
`WorldData` (cells, shapes), `PixelView` (the shear and the culling boxes), `PixelTextures` (the atlas, bark),
the registries of materials, trees, shrubs, plants.

**The rule of performance.** Nothing the size of a map or a chunk is done in a frame: meshes and plants are
built by column, generation — by a row or a tree (in the session, before the frame), all within the budgets
of the streamer's frame (the session's generation, edits, then far chunks, then caps). A phone browser is
about 10 times slower than a computer in GDScript. `tests/frame_test.gd` checks this by scenarios; its
timings are noisy on a busy machine, before blaming the code run it alone.

**Pitfalls**
- Front faces in Godot wind clockwise; a counter-clockwise mesh is inside out.
- The edges of geometry on the grid of pixel centres need overlapping (`ChunkMesher.EPS`), walls under 1 px
  on screen rasterize as a flickering dotted line; headless will not show it — render with ±eps and compare
  the shots.
- A curve moved `EPS` past its line turns its ends off the cell's sides: `MeshFaces._piece` draws the thin
  wedge from each end back to the middle of its side, or the ground below shows through in single pixels
  (on a magenta background: `tools/shot.gd --magenta`; dark ones where a shaded wall lies below).
- MultiMesh instance data on GLES3 / web is half float: new instance data goes into COLOR, not into a packed
  int. The vertex COLOR is 8-bit and is clipped above 1. Keep packed float words below 2^23 (otherwise
  `int(x + 0.5)` rounds to even): no flag bits above 256.
- A material's number in the mesh is 6 bits: materials and barks together no more than 63
  (`PixelTextures.MOST_MATERIALS`, now 36; see [content.md](content.md)).
- The Compatibility renderer lights an object by no more than `max_lights_per_object` (32) fires: a chunk's
  mesh is one object, beyond the limit neighbouring chunks are lit by different fires.

**Tests.** `tests/unit/mesher_test.gd` (`mesher`, `cap`, `patch`: trees in a forest, taiga and jungle felled
one by one, a dug cell — the glue equals a full rebuild), `tests/unit/view_test.gd` (`edge_haze`: the fog is whole
over a missing chunk at once, dissolves over a built one, and its quad), `tests/frame_test.gd` (the step's limit — with `LAG_BUDGET_US`, and `JUMP_BUDGET_US` for the frames just after a jump while the screen lags), `tools/bench_mesh.gd`,
`tools/bench_edit.gd`, `tools/bench_turn.gd`, `tools/profile.gd`.

**In more detail.** `plan/architecture/performance.md`, `plan/architecture/rendering.md`.
