# Chunks on screen

Status: ACTIVE. A Russian copy: [chunks_RU.md](chunks_RU.md).

**Purpose.** To build the meshes of the chunks that the server's session generated around the player
([session.md](session.md)) within the frame's budget, to hold the slice of levels and the caps above the
slice, to free the far meshes.

**Files**
- `src/client/world/chunk_streamer.gd` — the queue and the budgets: first those near the spawn (before the
  game), then within `reach()` by the screen (no less than `LOAD_RANGE` = `Session.ZONE`, 5 chunks; a window
  wider than a phone's — farther, `Session.reach_for` from half the screen, up to `Session.ZONE_MOST` 10; the
  caps above the slice — by as much): first the chunk nearest to the screen, as it is seen from the player
  and from the point where they will come in `LOOK_AHEAD` (1.5 s) of the path (`lead`, `_track_motion`, no
  further than `LEAD_MOST`; `_screen_score` — by how many screens the chunk is beyond the screen's edge, the
  screen's size — the camera, `_screen_half`), so what is seen ahead is built earlier, and what is not seen
  at the side and behind — last; each — when the session has made it (`WorldGen.needed` is empty; otherwise
  the chunk goes back into the queue, falls into `waiting`, and `next_chunk` takes another in the same frame
  until the generator has made something (`made`): over the network the ring at `LOAD_RANGE` never comes, and
  waiting for it held the near chunks at the sides of a narrow screen); **ground first**: a new chunk on
  screen (`job_ground`) shows the ground and water as soon as their mesh is built (`_apply_ground`), and
  builds the grass, shrubs and crowns after (`job_part` −2) and shows them at the end (`_apply_plants`); such
  a chunk lies in `bare` to the end (if its building was interrupted — in the queue again); **lag**: while
  there is a chunk without ground on screen (`lagging`, `_check_lag`), the building of such a chunk and the
  generation near the player take up to `LAG_BUDGET_US` (16 ms) of the frame instead of 9 ms — the FPS on a
  run sags, there are fewer voids; **the haze at the edge** (the setting «Haze at the edge», key `edge_mist`,
  on by default, `set_haze`): `edge_haze.gd` covers the chunks on screen without ground with a haze of the
  sky's background colour (lighter by day), which for `EdgeHaze.FADE` goes onto the built neighbouring chunks
  and melts; one mesh of quads at the player's height (the cursor's shader), rebuilt only when the set of
  empty chunks or the level changes, and the chunks are not even looked over while `nodes_changes` (the
  changes of `chunk_nodes`), the screen and the level stay and the player is within `LOOK_AGAIN` 0.5; edits are built first (a new edit in a chunk that is already being
  rebuilt for an edit does not start it anew: the building goes to the end, the chunk stands in the queue once
  more — otherwise with frequent digging on a phone the relief was not updated); an edit does not wait for a
  chunk that is being built by the stream (or for the sake of `kept`): it is put aside (`stashed`) and
  continues from the same place when the edits are built; while edits wait, the frame gives them the whole
  budget of edits (`job_budget`), and the generation of far chunks — one step (`gen_budgets`) — otherwise at a
  new place a felled tree stood for seconds while a far chunk was being finished and the world made; **a
  partial rebuild**: each chunk within `KEEP_CHUNKS` (`LOAD_RANGE`) of the player keeps the finished jobs of
  the mesh and plants (`kept`, about 0.25 MB per chunk, up to ~40 MB in all; the far ones are forgotten when
  the player leaves; the chunks within `REFILL_CHUNKS` (1) that have none — built while the player was far —
  are rebuilt in idle, `keep_queue`, within the stream's budget and yielding to edits); an edit in such a
  chunk builds only the columns around the changed cells (`dirty_rects`; by how much around —
  `ChunkMesher.reach`: 3 at the ground, 1 for cells in the air, of a crown and a trunk above the ground) and
  glues them into the saved (`ChunkMesher.patch`, then a step later `Foliage.patch` — the plants also build
  the trunks of trees whose crown can reach the plot, `Foliage.part_columns`), the shadows of the chunk's
  trees are counted anew; `remesh_chunk` builds the chunk whole. The result equals a full rebuild buffer to
  buffer (`mesher_test` `_test_patch`); farther than `reach() + UNLOAD_EXTRA` (3) the meshes are freed (the
  cells farther than `Session.drop()` are forgotten by the session). The session's generation goes before the
  client's frame within the budgets given by `gen_budgets()` (loading and pause — `load_budget`, otherwise
  `EDIT_BUDGET_US` near the player and `STREAM_BUDGET_US` farther), and `run_jobs(spent)` subtracts what was
  spent from its budget (the frame's total price is the same) and counts it in `budget_us`; `build_chunk` /
  `build_around` call `session.make_chunk` whole (`_whole`: the maps are painted at once; `build_around`
  first sends the server the body — `mirror.send_input`, so that the session makes and forgets around the new
  place); the signal `WorldGen.made` → `_on_generated` (the roof map and the minimap); `take_work()` gives its
  «meshes» together with the kinds of the session's work; the slice of levels (`update_cut`, `_hiding_level`;
  under a roof, in a ravine and behind a hill the layers are turned on instead of the slice, how they look is
  decided by the shaders, see rendering.md), the caps (`update_caps`, the level — `cap_level`), `solid`
  (`solid_map.gd`, the map of solid cells for the slice of rock in layers), `refit_boxes` for the camera's
  turn, `on_cell_changed` / `remesh_chunk`.
- `src/client/world/chunk_mesher.gd` — the chunk's mesh by column: cells, bevelled corners, caps
  (`build_cap`; above a cell into which a slope from above goes by a «deep» corner there is no cap: otherwise
  it is seen above the slope as a black triangle; the caps lie `CAP_SINK` below the cells' top, otherwise their
  edge shows through the neighbouring slope as a black diagonal gap); it calls the parts that inherit
  `mesh_faces.gd` (the tables of faces, packed words, drawing primitives): `slope_mesher.gd` (slopes,
  `patch`), `water_mesher.gd` (the surface, the shore, waterfalls), `trunk_mesher.gd` (the bark of trunks),
  `form_mesher.gd` (built blocks that are not a cube — `WorldData.forms`: a bevel from below, a bevel from
  above, steps; a shape is described as rising to the north and turned; a face on a cell's side is not drawn
  at a covering neighbour; a cube next to a shape draws a face towards it if that side of the shape is not
  whole, `covers_side`; the cells at the shapes are candidates, `_take_forms`).
- `src/client/world/foliage.gd` — the chunk's grass, plants and crowns as a MultiMesh, also by column.
- `src/client/world/edge_haze.gd` — the haze above unbuilt chunks (see above).
- `src/client/world/mesh_buffers.gd` — growing vertex buffers; `drifts.gd` — snowdrifts; `tracks.gd` —
  footprints, kept in a map of the ground round the player (`print_map`, repeating every `Tracks.MAP` texels) that
  the ground's shaders read through `footprint()` before the light and the fog, so a fog hides a print as it hides
  the ground; `roof_map.gd` — the roof map for shaders (wrapped through `RoofMap.WRAP`) and beside it the map of
  the columns' biomes (`biome_map`) with the multipliers of the materials' colour by biomes (`biome_tints`,
  from the biomes' `tints`).

**Interface.** `ChunkStreamer.prepare(gen)`, `build_near(n)`, `run_jobs(spent)`, `gen_budgets()`,
`take_work()`, `set_focus(at)`, `update_cut(delta)`, `update_caps()`, `refit_boxes()`, `on_cell_changed(cell)`,
`remesh_chunk(key)`; `ChunkMesher.start` / `start_rect` / `step` / `finish` / `patch` / `reach`,
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
- MultiMesh instance data on GLES3 / web is half float: new instance data goes into COLOR, not into a packed
  int. The vertex COLOR is 8-bit and is clipped above 1. Keep packed float words below 2^23 (otherwise
  `int(x + 0.5)` rounds to even): no flag bits above 256.
- A material's number in the mesh is 6 bits: materials and barks together no more than 63
  (`PixelTextures.MOST_MATERIALS`, now 36; see [content.md](content.md)).
- The Compatibility renderer lights an object by no more than `max_lights_per_object` (32) fires: a chunk's
  mesh is one object, beyond the limit neighbouring chunks are lit by different fires.

**Tests.** `tests/unit/mesher_test.gd` (`mesher`, `cap`, `patch`: trees in a forest, taiga and jungle felled
one by one, a dug cell — the glue equals a full rebuild), `tests/unit/view_test.gd` (`edge_haze`: the haze's
quads and their edges), `tests/frame_test.gd` (the step's limit — with `LAG_BUDGET_US`), `tools/bench_mesh.gd`,
`tools/bench_edit.gd`, `tools/bench_turn.gd`, `tools/profile.gd`.

**In more detail.** `plan/architecture/performance.md`, `plan/architecture/rendering.md`.
