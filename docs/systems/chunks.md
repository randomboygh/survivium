# Chunks on screen

Status: ACTIVE. A Russian copy: [chunks_RU.md](chunks_RU.md).

**Purpose.** To build the meshes of the chunks that the server's session generated around the player
([session.md](session.md)) within the frame's budget, to hold the slice of levels and the caps above the
slice, to free the far meshes.

**Files**
- `src/client/world/chunk_streamer.gd` — the queue and the budgets: first those near the spawn (before the
  game), then within `reach()` by the screen (no less than `LOAD_RANGE` = `Session.ZONE`, 5 chunks; a window
  wider than a phone's — farther, `Session.reach_for` from half the screen, up to `Session.ZONE_MOST` 10; the
  caps above the slice — by as much) in the order of `_build_score` (user 2026-11-15: from the player outwards,
  along the way first): the chunks on the screen, as it is seen from the player and from the point where they
  will come in `LOOK_AHEAD` (1.5 s) of the path (`lead`, `_track_motion`, no further than `LEAD_MOST`;
  `_on_screen`, `_screen_score`, the screen's size — the camera, `_screen_half`), before the rest; within each,
  `_way_score`, from the middle of the player's chunk: the row of chunks along the player's way (`way`, the direction of `lead` once it is longer
  than `WAY_FROM`, taken again after a turn of about 20°, `WAY_TURN`) from the player's onwards, ahead before
  behind, then the rows beside it, one row further each time (before the player has moved — ring by ring
  round it); walking fast builds a narrow strip ahead, stopping fills in the sides nearest first. The score is
  worked out afresh for each pick (`next_chunk`, `wanted`), as the screen moves; each — when the session has made it (`WorldGen.needed` is empty; otherwise
  the chunk goes back into the queue, falls into `waiting`, and `next_chunk` takes another in the same frame
  until the generator has made something (`made`): over the network the ring at `LOAD_RANGE` never comes, and
  waiting for it held the near chunks at the sides of a narrow screen); **ground first**: a new chunk on
  screen (`job_ground`) shows the ground and water as soon as their mesh is built (`_apply_ground`), and
  builds the grass, shrubs and crowns after (`job_part` −2) and shows them at the end (`_apply_plants`); such
  a chunk lies in `bare` to the end (if its building was interrupted — in the queue again); while the
  screen lags (below) its plants wait (`plants_wait`, with the mesh job kept for patching), the next hole gets
  its ground sooner, and they are built once the screen has its ground; **lag**: while
  there is a chunk without ground on screen (`lagging`, `_check_lag`), the building of such a chunk and the
  generation near the player take up to `lag_budget()` of the frame instead of 9 ms: `LAG_BUDGET_US` (16 ms),
  for `JUMP_SECONDS` (3 s) after a jump of more than a chunk (a teleport, a respawn) `JUMP_BUDGET_US` (30 ms) —
  the FPS on a run sags, there are fewer voids; once a chunk of the screen is made, the generation takes half
  of it, so the first ground comes before the last of the screen is made; a jump drops the chunk being built
  off the new screen (it went on a step a frame), and the maps are painted with what is left of a lagging
  frame (`paint_queue`, before: one chunk a frame held the ground back for some 240 frames after a
  teleport); and the frame goes to the screen alone: a chunk off the screen is not
  started (`_ready_on_screen`), a chunk on it already started gets the lag budget at once, and the session
  makes only the first `WANTED_MOST` (4) pending chunks of the order it has not made (`wanted()` →
  `Session.wanted`, `wanted_only`; at other times they go first); walking into new
  land a phone (4–5× slower than a PC here) needs about a second of building a second for the whole zone and
  has a third of it (2026-11-15), so the sides of the zone wait until the player stops; **the fog at the edge** (the setting «Fog at the edge», key `edge_mist`,
  on by default, `set_haze`; user 2026-11-16, before a haze of the sky's colour): `edge_haze.gd` covers the
  chunks on screen without ground with a dense white fog (towards the background at night, `NIGHT_KEEP`), its rim torn by
  noise, with no clouds; it lies along the camera's rays that end on a chunk not built (user 2026-11-16): one quad on the
  plane of the ground (`plane_y`: the land round about, the mean of the ground at the middles of the 5×5 chunks round
  the player, eased over `GROUND_EASE` 1 s; at the sea's top the fog of far chunks hid the land built near) drawn over
  everything, so a jump does not move it; the shader (`shaders/edge_fog.gdshader`) keeps it whole over a missing chunk's square and `DENSE`
  (0.5) past it, thinning over `REACH` (3, squared) only into the built chunks beside, from a corner round (the 3×3 chunks round each pixel,
  by distance to their squares; the noise only scales fog that is there, so none shows where there is none); a missing chunk's fog is whole at once, a built one's dissolves over `DISSOLVE` (1.2 s),
  melting by dithering
  (`bayer4`); how much fog each chunk has (`amounts`) is a texel of a `GRID`² (32) texture round the player, written only
  while something changes; the quad covers the chunks with fog and one round them, made again only when that rect or the
  plane changes; its shader is built ahead (`haze_material`, ShaderWarmup); the chunks are not even looked over while
  `nodes_changes` (the changes of `chunk_nodes`) and the screen stay and the screen's middle (the camera's) moved less
  than `LOOK_AGAIN` 0.5; edits are built first (a new edit in a chunk that is already being
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
- `src/client/world/chunk_mesher.gd` — the chunk's mesh by column: cells, cut corners (a top drawn in
  quarters, `MeshFaces.quarter_kind`; the half of a side by a cut corner is gone, a curved wall instead), caps
  (`build_cap`; none over a sloping top; the caps lie `CAP_SINK` below the cells' top, otherwise their
  edge shows through the neighbouring slope as a black diagonal gap); it calls the parts that inherit
  `mesh_faces.gd` (the tables of faces, packed words, drawing primitives): `old_slope_mesher.gd` (the curved
  slopes, see `docs/systems/world-data.md`; `patch_grid` for the water over a shore), `water_mesher.gd` (the surface, half a cell under its cell's top but up to the top in the sea's level, so the sea lies flush with the sand at its level while lakes and rivers keep a bank (`WorldData.water_top`, `MeshFaces.water_top` with `sea_level` set from the world when a job starts; the bodies, boats, fishing and wildlife take the same height), the shore (`shore_water`; water flush with the land, a lake or river at the sea's level, covers a shore's slope up to the land's top, but on an inner corner on the diagonal (see `WorldData.PATCH_DIAG`) it stops on the diagonal through the corners beside, past which the ground lies level at the surface, its squares split as the ground's are (`OldSlopes.crease_flip`); its foam runs along the diagonal as wide as along a straight shore's land, and round an outer corner's high corner (corner shape 3 of the foam bits, `water.gdshader`), so a shore turning from straight to diagonal keeps one line of land and foam), waterfalls: `falls` keeps a key per fall in the job's `water_falls`, `fall_faces` draws them after the plain water rows, also in `patch`, so the foam and spray lie over the pool whichever of its cells came later; each fall is a sheet in the water's own colour and clearness, foam on the pool spilling `FOAM_OUT` / `FOAM_SIDE` over the open water beside with a ragged edge that tears and mends, and an upright quad of drops and dithered mist at its foot that `water.gdshader` turns to the camera like the plants; a water cell's side under the open sky is not drawn, the sheet covers it; where a step runs diagonally its lip is straight: the upper water's corners with air on three sides are cut along the diagonal, as the bed under them is, the air cells whose three neighbours round a corner are the upper water get that corner of water (`lip_cuts`, `lip_fills`, `lip_fill`; such air cells are mesh candidates), and the water falls over the diagonal in a sheet of its own (`_diag_fall`, with its foam and spray) while the falls over the sides leave out the halves the diagonal covers (`trims`); the surf: over land whose top is at the sea's level within `SWASH_REACH` cells of the sea's waterline a thin sheet follows the top (its slope's where it slopes, never under the water's surface; `swash`, vertex alpha `SWASH_ALPHA`), each point carrying its distance from the waterline from `swash_map` (a chamfer distance over the job's columns, worked out in the copy step, empty where no sea is near); `water.gdshader` runs the sea on up it (`surf_wave` in `common.gdshaderinc`: a ragged band up to `SWASH_BASE` 2 cells it always covers, so the waves never meet the sea's own water in a straight line, and waves up to `SWASH_REACH` 8 cells) in waves of the shallows' colour whose front is the foam line round the water (the sea's water in its top level draws no shore foam of its own, vertex alpha `SURF_ALPHA`, `surf_here`), leaving a line and lace of foam where each reached that dissolve before the next, and wet sand, none under ice; the surf also covers a cut top's whole square and the filled corners of the sea's water (`swash_fills`), and land at the sea's level slopes down into the sea like the rest of the sand: `swash_map` gives such a slope beside the sea's water (also across a corner) `SWASH_UNDER` 0, so the waterline runs through it, straight along a diagonal shore; `shore_water` leaves it out and `_swash_under` lays one flat sheet over it at the water's surface (green `SWASH_UNDER_G`), which `water.gdshader` draws as the sea behind the waterline and as the surf beyond; the fills beside such a slope get no sheet; the sea's water at its top level keeps its shore foam along walls rising out of it (only those sides' bits are kept); the plankton lights its foam on glowing nights), `trunk_mesher.gd` (the bark of trunks; a log of a tree's column is bark even with ground on up to three
  sides, as a foot against a river's bank, and the ground beside it draws its face towards it; its top log under air, as a
  stump left by felling, gets a cut top, not a block of wood; the cut's UV is cells from its middle, by which
  `world.gdshader` centres the rings of the end grain on it),
  `form_mesher.gd` (built blocks that are not a cube — `WorldData.forms`: a bevel from below, a bevel from
  above, steps, the notch under a step of a band of stairs; a shape is described as rising to the north and turned; a face on a cell's side is not drawn
  at a covering neighbour; a cube next to a shape draws a face towards it if that side of the shape is not
  whole, `covers_side`; the cells at the shapes are candidates, `_take_forms`).
- `src/client/world/foliage.gd` — the chunk's grass, plants and crowns as a MultiMesh, also by column.
- `src/client/world/tree_sprites.gd`, `shaders/tree.gdshader` — standing trees of species drawn as pictures
  (`Growth.standing_look`): one upright picture per tree in the chunk's `trees` MultiMesh (the last of the
  plant parts), the frame of the side the camera rests at plus the tree's own turn, from one atlas of all
  such species (`setup` at the start; frames RGBA8 hold the leaf's normal, angle and bits or the bark's
  step under 8 suns of the day, the bare tree LA8 for autumn and winter); lit by the sun in the shader as the
  approved drawing (bundles by normal, leaves by facing). Foliage and the trunk mesher leave such trees out;
  young trees and stumps stay theirs.
- `src/client/world/edge_haze.gd`, `shaders/edge_fog.gdshader` — the fog above unbuilt chunks (see above).
- `src/client/world/mesh_buffers.gd` — growing vertex buffers; `drifts.gd` — snowdrifts; `tracks.gd` —
  footprints, kept in a map of the ground round the player (`print_map`, repeating every `Tracks.MAP` texels) that
  the ground's shaders read through `footprint()` before the light and the fog, so a fog hides a print as it hides
  the ground; every stride that leaves a print (the player's, the other players', the beasts') also treads the grass
  in `trample.gd` (`trample_map`, a quarter-unit texel: when, which way, how hard, the level), which `grass.gdshader`
  reads through `trodden()` to lay the tufts and the mods' plants over and lower; they stand up again over
  `Trample.LIFE` seconds. Both maps go to the renderer the frame a new print or trodden patch is laid (at most every
  `Tracks.SOON` seconds), so a print never lags the foot; clearing old ones waits for `FLUSH`; `roof_map.gd` — the roof map for shaders (wrapped through `RoofMap.WRAP`; g is `CROWN` under a crown plus `NO_PUDDLE` on a top that drains or slopes and `SLOPED` on a sloping top, `top_bits`) and beside it the map of
  the columns' biomes (`biome_map`: r the biome, g the column's `Chunk.frost`, the snow of the heights it lets lie) with the multipliers of the materials' colour by biomes (`biome_tints`,
  from the biomes' `tints`), and a coarse map of the land's height for the ground fog (`ground_low`: a texel per
  `RoofMap.LOW`² columns, the top three quarters of the way up their tops, so a pit or a trunk does not move it;
  `fog_at` in `common.gdshaderinc` measures low places by it and lays the fog's layer over the higher of it and the
  ground, so pits fill with fog and a hill's edge draws no straight seams). The same texture's g, b, a hold the colour
  of the water there (`RoofMap._water_tints`, read by `water_tint` in `water.gdshader`): the mean over the block's water
  columns of their biome's water tint times their body's (`SEA_TINT` for `WorldData.SEA_WATER`, `RIVER_TINT` for
  `WorldData.RIVER_WATER`, which the generator sets on rivers and canyon floors, `LAKE_TINT` else) and a slow noise
  (`VARY_*`) that shades one lake from the next; filtered between texels, so a river's mouth runs into the sea's colour
  over a few cells.

**Interface.** `ChunkStreamer.prepare(gen)`, `build_near(n)`, `run_jobs(spent)`, `gen_budgets()`,
`take_work()`, `set_focus(at)` (the chunks are built round `at`: where the player comes back behind the death
screen, or where `Trip` goes; the chunks on its screen at the lag budget, `focus_built()` — their share built), `update_cut(delta)`, `update_caps()`, `refit_boxes()`, `on_cell_changed(cell)`,
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
over a missing chunk at once, dissolves over a built one, and its quad), `tests/frame_test.gd` (the step's limit — with `LAG_BUDGET_US`), `tools/bench_mesh.gd`,
`tools/bench_edit.gd`, `tools/bench_turn.gd`, `tools/profile.gd`.

**In more detail.** `plan/architecture/performance.md`, `plan/architecture/rendering.md`.
