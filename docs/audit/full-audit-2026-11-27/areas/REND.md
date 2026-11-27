# REND: chunks, meshers, view, props/creatures, shaders. Audit report

**What I read.** I read `chunk_streamer.gd` in full (1859 lines). I read these in part: `chunk_mesher.gd` (Job, holes, BUILT_*, the caps and faces helpers), `mesh_faces.gd` (constants, pack, `_wound`, `_add`), `mesh_buffers.gd`, and the function lists of `old_slope_mesher`, `water_mesher`, `trunk_mesher` and `form_mesher`. I also read parts of `foliage.gd` (the `_column` dispatch and the old crown paths), `tree_sprites.gd` (setup and the atlas), `solid_map.gd` (all of it), `edge_haze.update`, `effects.gd` (state, functions and `update`), `window_glow.gd`, `fire_shadows._process`, `cave_layers.gd`, `creatures.gd` (`_process`, `_frame`, `_build_looks`) and `props.gd` (update, `_recut`, sprites, fit).

**Shaders.** I counted every shader's samplers and varyings with the regexes of `tools/lint.py`. Lint reports 0 problems today. I compared the `light()` functions, ran a 5-line duplicate-window scan over all 29 files, and grepped the shared constants. Docs: the headings of `chunks.md`, `rendering/pitfalls.md` (varyings and samplers), `planning/archive/mesher.md` and `mesher-merge.md`. Tests: the header and scenarios of `frame_test.gd`, the test names of `view_test.gd` and `mesher_test.gd`.

**Not read in depth.** sky.gd (I only grepped its globals), camera_rig, pixel_view, figure/player, sun_rays, water_effects/air_effects/nature_effects, death_fx, tree_hits, plan_*, the bodies of `water_mesher` and `old_slope_mesher`, and the bulk of `grade`/`water`/`world`/`tree.gdshader`. Godot cannot run here, so every performance claim is from reading the code, not from measurement.

---

### REND-1 · High · Architecture
- **What:** `chunk_streamer.gd` is a god object with eleven distinct responsibilities. It has about 80 member vars and touches 28 distinct `game.*` members.
- **Where:** `src/client/world/chunk_streamer.gd:118-299` (state), `:331-1101` (scheduling), `:1106-1206` (haze and unload), `:1208-1346` (nodes), `:1348-1479` (edits), `:1483-1859` (cut, floors, layers, caps).
- **Evidence:** The responsibilities and where they live:
  1. Job scheduler with wall-clock budgets: `run_jobs` (172 lines, `:934-1101`), stash and patch, `kept`/`keep_queue`/`forget_queue`.
  2. Build order and lag detection: `wanted`, `next_chunk`, `_build_score`, `_way_score`, `_track_motion`, `_check_lag`, `lead`/`way`.
  3. Chunk node lifecycle: `_chunk_nodes` builds 9 nodes per chunk from 15 materials and meshes held on `main.gd:244-264`; `_apply_*`, `_free_chunk`, `refit_boxes`.
  4. A paint queue for the roof map and the HUD minimap: `_on_generated`, `_queue_paint`, `_paint`.
  5. Edit routing: `on_cell_changed`, `_remesh_around`, `regrow_cell`, `remesh_chunk`.
  6. The automatic level cut: `update_cut`, `_hiding_level`, `_sheer_below`, `_rises_behind`, `view_range`, `shift_cut`, `manual_level`.
  7. The build mode's cut of the floors (see REND-3).
  8. The view in layers and its solid map: `solid`, `_update_layers`, `_update_depth`.
  9. The caps of the cut: `update_caps`, `cap_cache`, `cap_order`.
  10. The edge haze.
  11. Detecting felled trees by diffing `_standing` between rebuilds, which starts the fall animation (`:1281-1288`).

  Three of its jobs write into other modules' state: `game.hud.perf.chunks` (3×), `game.hud.minimap.paint_chunk/touch`, and `game.get("effects").glows/.lit/.trees`.
- **Why it matters:** Every change to the cut, the build mode or streaming goes through one 1.9k-line file whose fields are shared by all eleven parts. Building-UX PRs keep adding fields here (REND-3).
- **Proposed refactoring:** Split it into three modules:
  - `chunk_jobs.gd`: scheduler, budgets, stash, patch and kept (with REND-2).
  - `chunk_nodes.gd`: nodes, apply, free, boxes and haze.
  - `view_cut.gd`: auto cut, manual cut, floors, layers, solid map, depth and caps. This one is about 380 lines with almost no shared state: it needs only `chunk_nodes.has` and `reach()`.

  The streamer stays as the facade the other modules call (`game.chunks.*`), so its callers do not change. The cut-off modules report what they did by signals (`chunk_shown`, `chunk_freed`, `tree_gone`); props, effects, the minimap and perf connect to them. This changes the structure, so it needs the owner's pick. An alternative is a chain of parts (`chunk_streamer.gd ← streamer_*.gd`), which decisions 145/168 allow.
- **Effort:** L. **Risk:** medium. **Confidence:** high.

### REND-2 · High · Correctness
- **What:** The chunk job is a hidden state machine. It is spread over about 17 fields with sentinel values, and a positional 9-element `stashed` array saves and restores it.
- **Where:** `chunk_streamer.gd:190-236` (fields), `:858-889` (stash and unstash), `:1034-1073` (`job_part` -2, -1, 0..N), `:1056-1067` (`job_old` size 2→1→0 is the patch phase), `:804-842` (`_finish_part`), `:1146-1148`, `:1179-1182`, `:1404-1418`.
- **Evidence:** The phase is implied by combinations of fields:
  - `has_target` versus `job_mesh != null`
  - `job_edit`, `job_keep`, `job_ground`
  - `job_part == -2` ("ground shown, plants only")
  - `job_old.size()`
  - `plants_wait[key]`, which holds a ChunkMesher.Job
  - `bare[key]`

  `stashed = [job_key, job_mesh, job_plants, job_part, job_meshes, job_plant_parts, job_keep, job_budget, job_ground]` is restored by index (`stashed[0]`..`stashed[8]`). Each of the five drop paths has to reset `has_target` by hand next to `_drop_job()`: `:1147`, `:1181`, `:1415`, `:1455`, `:1474`.

  The earlier audit's client-world-2 ("a chunk whose job is dropped by an edit is lost") was a bug of exactly this kind. Its fix is the hand-written `pending_chunks.append(job_key)` at `:971-974`.
- **Why it matters:** Any new path can leave a chunk never built or built twice. This is the most edited file in streaming, and no unit test covers its state transitions (REND-17).
- **Proposed refactoring:** Write a `ChunkJob` RefCounted with `key`, `kind` (STREAM/EDIT/KEEP/PLANTS_ONLY), a `phase` enum (MESH, PATCH_MESH, PATCH_PLANTS, FINISH(i), GROUND_SHOWN, DONE), the budget and its parts. Then:
  - The stash holds the object, and `_drop_job` becomes `job = null`.
  - `has_target` becomes `job != null and job.kind == STREAM`.
  - Add a headless unit test that drives `run_jobs` with a fake world/session through edit-during-stream, unload-during-job and lag-then-plants.
- **Effort:** M. **Risk:** medium. **Confidence:** high.

### REND-3 · Medium · Layering
- **What:** Build-mode UI state lives in the streamer and the mesher: the floor cut from the building-UX PRs (user's picks of 2026-11-26/27) and the blueprint holes. A getter that runs every frame writes to it.
- **Where:**
  - Fields `build_floor`, `floors_on`, `build_cut`, `_natural_only`, `BUILT_CAPS`: `chunk_streamer.gd:256-271`.
  - `build_level`, `floors_range`, `floor_height`, `by_floors`, `shift_cut`, `can_shift`: `:1637-1741`.
  - `cap_level` encodes "built" as `+ 1<<16`, and `update_caps` decodes it with `want % BUILT_CAPS` and `want >= BUILT_CAPS`: `:1780-1786`, `:1846`.
  - The static global `ChunkMesher.holes`: `chunk_mesher.gd:25-29`, written by `set_holes` (`chunk_streamer.gd:1370-1382`) from `plan_things.gd:217-218`.
  - Readers of the floor state: `hud.gd:536-543` (`floors_on`, `build_floor`), `props.gd:467`, `controls.gd:729` (`build_cut`), and `top_level()` in five places in `controls.gd` and `plan_blocks.gd:230`.
- **Evidence:** `build_level()` is called from `update_cut` every frame. It reads `game.build.on`, `game.build.height` and `game.view.first_person`, and it also resets `build_floor = 0; floors_on = false` (`:1638-1641`).

  `holes` is a static Dictionary that `_open_holes`/`_hole_cands` read during a job's prepare steps (`chunk_mesher.gd:173-200`). A `set_holes` between two of a job's `PREP_STEPS` would make one chunk's padded copy inconsistent. This is unverified: confirming it needs a test that changes the holes mid-job. The static also outlives the world.

  The floor logic is checked only inside `tests/frame_test.gd:862-897`, which is CI-only and a performance test.
- **Why it matters:** Each building-UX tweak touches the streamer, the HUD, props and controls together. The mesher depends on blueprint UI state through a global. The int-encoded "built" cap level is easy to misuse.
- **Proposed refactoring:**
  - Move the floors state into a small `floor_cut.gd`, owned by the build mode or the view. It publishes one value, `build_cut`, which the streamer reads.
  - Key the caps by `Vector2i(level, built)`.
  - Copy `holes` into `Job` at `start`/`start_rect` (a `job.holes` field) instead of reading the static.
  - Move the floors checks into a unit test in `view_test`.
- **Effort:** M. **Risk:** low. **Confidence:** high.

### REND-4 · Medium · Performance
- **What:** The tree-picture atlas is 4096 wide and grows downward without any guard. By my estimate it is already at about 94% of a 4096 texture height.
- **Where:** `src/client/world/tree_sprites.gd:28` (`ATLAS_W := 4096`), `:151-161` (height = shelves + ramp rows + 2 rows per piece kind), `:213-231` (`_shelves`).
- **Evidence:** I re-ran `setup`'s shelf packing in Python over the PNG headers of the 21 species, with frames, then stumps, then the 63 piece-kind regions. The frames atlas comes out at 3704 rows of shelves plus 22 ramp rows plus 126 table rows, about **3852 × 4096 RGBA8 (about 63 MB)**. The `bare` LA8 atlas adds about 3704 × 4096 (about 30 MB), and the `snow` atlas is extra. No code checks the height against `RenderingServer`'s maximum texture size: a grep for `4096` and `max_texture` finds nothing relevant.
- **Why it matters:** One or two more species, or taller pictures, pass 4096. GPUs limited to 4096 (some WebGL2 and older phones) then fail to create the texture, and every pictured tree disappears. Nothing in CI would catch it. The memory is also large for a phone browser.
- **Proposed refactoring:**
  - Add a `push_error` in `setup` and a `view_test` assertion when the height is over 4096.
  - Then either pack into pages (a second atlas texture costs a sampler; see REND-7, `tree.gdshader` is at 13 of 13) or a texture array, or pack the stumps and pieces into the `bare` atlas's free width.
- **Effort:** S for the guard, M for paging. **Risk:** low. **Confidence:** medium (the height is from my reimplementation, not from a run).

### REND-5 · Medium · Duplication
- **What:** At least 13 pairs of magic numbers or encodings are copied between GDScript and the shaders, each kept in sync only by a comment. No test compares them.
- **Where (each pair):**
  1. UV2 word: `NO_MATERIAL 63`, `×64` edges, `×16384` flags: `mesh_faces.gd:59,173-177` and `world.gdshader:67,110,198,322-345`.
  2. Face flag bits `SIDE_TILE 1/OPEN_TOP 2/SLOPE 4/DIAG 8/DIAG_CORNER 64/DIAG_STRAIGHT 512`, corner `>>4 &3`, code `>>7 &3`: `mesh_faces.gd:75-83` and literals at `world.gdshader:291,553-561`.
  3. Material word shifts `GROUND_SHIFT 5/FRAY 8/SIDE_FRAY 11/GLOW 14`, `DRAINS 16`, `TRUNK 128`: `materials.gd:43-47` and `world.gdshader:73-84`.
  4. Core material ids `GRASS=1, DIRT=2, STONE=3`: `world.gdshader:70-72`. `GRASS_MATERIAL=1, WATER_MATERIAL=4`: `common.gdshaderinc:428-429`. These are ids named in code and depend on load order.
  5. Terrain atlas `TILES 16/ROWS 12`: `pixel_textures.gd:15-16` and `ATLAS_COLUMNS/ROWS` in `common.gdshaderinc:161-162`.
  6. Solid map `SIZE 64/LEVELS 32`: `solid_map.gd:12-13` and the literals `64.0`/`32.0` at `common.gdshaderinc:493,555`.
  7. `SWASH_REACH 8`: `water_mesher.gd:556` and `common.gdshaderinc:1105`.
  8. Prints map `MAP 768`, `LIFE[8]`: `tracks.gd:28,34` and `PRINT_MAP`/`PRINT_LIFE` in `common.gdshaderinc:809,813`.
  9. Fire light maps `MAP 32/LEVELS 16/MAX_LIGHTS 8`, `RING_EDGES/RING_LEVELS`: `fire_shadows.gd:57-70` and `common.gdshaderinc:173-175,902-904`. The comment at `fire_shadows.gd:63` names `MAP_SIZE in fire_shadow.gdshader`, which does not exist.
  10. `WOOD_AT 28`: `tree_sprites.gd:40` and `tree.gdshader:103`.
  11. `FALL_MINE 512` in three places: `tree_hits.gd:84`, `tree.gdshader:215` and `tree_shadow.gdshader:44`.
  12. Tree instance kinds `STUMP -1/STUMP_SNOW -2/PIECE -3`: `tree_sprites.gd:43-49` and the bare thresholds `COLOR.a < -1.5`, `< -2.5`, `> -0.5` at `tree.gdshader:375-376,388,396`.
  13. The layer-view algorithm itself: `cave_layers.gd:27-47` (`share`, `layer_share`) mirrors `common.gdshaderinc:515-531` (`layer_alpha`) for picking.

  Built-cell blue `BUILT_BLUE 0` (`chunk_mesher.gd:756`) and the `sea_top`/`build_cut` globals are smaller cases of the same thing.
- **Why it matters:** Changing one side silently breaks the picture. `content_test.gd:92` checks the material word's values, but nothing checks that the shader decodes them the same way.
- **Proposed refactoring:** Add a unit test that parses `const (int|float) NAME = N;` from the shader code and compares it with the GDScript constants for the pairs above. `view_test.gd:2373` already reads `TreeShader.code`. For item 13, a test that samples `CaveLayers.share` on a grid against a hand-written copy of the GLSL formula. Longer term, a `tools/` generator could write a `shared_consts.gdshaderinc` from the GDScript constants.
- **Effort:** S for the test, M for the generator. **Risk:** low. **Confidence:** high.

### REND-6 · Medium · Duplication
- **What:** `tree.gdshader` and `tree_shadow.gdshader` repeat the same instance decoding block, even though both already include `tree_pictures.gdshaderinc`.
- **Where:** `shaders/tree.gdshader:358-400` and `shaders/tree_shadow.gdshader:55-100`. The writing side is `tree_hits.gd:139` (`mine[14] += FALL_MINE`, a bare index into the 16-float instance stride).
- **Evidence:** My duplicate-window scan found 10 identical 5-line windows between the two files and almost none elsewhere. The repeated code covers:
  - the `INSTANCE_CUSTOM`/`COLOR` unpack (`ax`, `ay`, `mine`, `row`, `own`)
  - the piece-table `texelFetch` decode (`p0`/`p1` → `c`, `ax`, `ay`)
  - the `falls[]` search loop
  - the side choice from `rest_view`
- **Why it matters:** A change to the instance layout written by `TreeSprites.build` or `TreeHits` has to be made in three places. The felling work has already hit Adreno varying limits twice in this code (pitfalls.md:129-136).
- **Proposed refactoring:** Move `decode_instance(...)`, `piece_cell(...)`, `fall_of(foot)` and `FALL_MINE` into `tree_pictures.gdshaderinc`. Give the instance-buffer offsets names (`TreeSprites.COLOR_B := 14`).
- **Effort:** S. **Risk:** low (this is a shader change, so it needs a real render: `xvfb` or the browser smoke test). **Confidence:** high.

### REND-7 · Medium · Performance
- **What:** Three shaders have no texture-unit headroom left and one has no varying headroom. Part of the cause is that `common.gdshaderinc` declares 10 global samplers, so every shader that includes it starts at 10 of 13.
- **Where:** `shaders/common.gdshaderinc:88,117,120,123,130,134,137,807,900,901`. Lint limits: `tools/lint.py:40,52`.
- **Evidence:** Counted with lint's own regexes:

  | Shader | Samplers (max 13) | Varying slots (max 14) |
  |---|---|---|
  | grass | **13** | **13** |
  | tree | **13** | **13** |
  | tree_shadow | **13** | 6 |
  | water | 10 | **14** |
  | world | 12 | 8 |
  | sprite, sprite_mirror, sprite_water, sprite_xray, leaves, particle, edge_fog | 11 | ≤7 |
  | cursor, land, fishing_line, plan_cut_mul, plan_ghost, plan_through, fire_shadow, leaf_shadow, sun_rays, window_glow | 10 | ≤6 |
  | grade (canvas) | 3 | – |

  `solid_map`, `heat_map`, `biome_tints`, `print_map` and `light_blocks` are reached only through functions in `common`. Even so, the one-line `plan_*` and `cursor` shaders declare them all.

  On the `#ifdef` question: only `tree.gdshader` uses variants, one define (`FALLING`, 16 `#if` blocks). That define is created by `TreeSprites.falling` with a string `replace` and guarded by `view_test._test_tree_shaders`. There is no variant explosion.
- **Why it matters:** No feature can add a texture to grass or trees, or a varying to water, without packing something first. Both limits have already caused shipped bugs (#752, #754, v0.5.912-929).
- **Proposed refactoring:** Split `common.gdshaderinc` into a core part (no samplers, or only `roof_map`/`cloud_noise`) plus feature includes (`layers.gdshaderinc` with `solid_map`, `lights.gdshaderinc` with `light_blocks`/`light_spots`, `prints.gdshaderinc`, `heat.gdshaderinc`), so each shader declares only what it calls. Or pack `heat_map` and `print_map` into channels of one texture. Lint keeps enforcing the limits.
- **Effort:** M. **Risk:** medium (needs real renders on web and Android). **Confidence:** high.

### REND-8 · Medium · Performance
- **What:** Animals have one ShaderMaterial per species × tint × view × frame (×2 for fish), and swap `material_override` on every frame change. The species "look" is a 13-slot positional Array.
- **Where:** `src/client/game/creatures.gd:260-305` (`_build_looks`), `:189-195` (the look tuple's doc), `:348-352`, `:396-497`, `:508-515`. Props use the same pattern: `props.gd:440-450` (`_sprite_look` keyed by `"%s/%d/%d"`), and `props.gd:466-477` rebuilds that key with string formatting for every sprite thing on a camera turn.
- **Evidence:** In `_build_looks`, `for tint ... for v in views: for f in frames: var m := PlayerScript.sprite_material(...)`. The look itself is `looks[kind] = [mesh, variants, body, frames, walk, views, hop, attack, overs, run, hurt, death, idle_anim]`. There are 31 uses of `k[3]`..`k[12]` / `looks[a.kind][n]` in the file. `a.state == "bite"` and `in RUNS` are string state checks in `_frame`. `_process` calls `wildlife.has_method("glide")` every frame (`:318`).
- **Why it matters:** There are hundreds of materials per species: more shader-uniform buffers, longer warm-up (ShaderWarmup), and a material swap on each frame change. The positional tuple is fragile: adding a slot shifts every index.
- **Proposed refactoring:**
  - Replace the tuple with a `Look` record (an inner class).
  - Use one material per tint with `frame_uv` as an `instance uniform` (check that the Compatibility renderer supports it on web), or a per-instance custom value.
  - Do the `has_method` check once in `watch()`.
- **Effort:** M. **Risk:** medium (the picture is only verifiable by screenshot). **Confidence:** medium.

### REND-9 · Medium · Correctness
- **What:** `WindowGlow.update` can erase from `windows` while iterating over it.
- **Where:** `src/client/view/window_glow.gd:86-91` (`for cell in windows: ... _show(cell, w)`) and `:137-139` (`_show`: `if not is_instance_valid(node): windows.erase(cell); return`).
- **Evidence:** The erase happens inside the `for` over the same Dictionary whenever a window's node was freed before `remove` was called (a thing removed and freed in the same frame).
- **Why it matters:** In Godot 4, erasing from a Dictionary during iteration can skip entries or raise an iteration error. A window would then stay stale, or `run_all.sh` would fail on a `SCRIPT ERROR`.
- **Proposed refactoring:** Collect the dead cells in a local array and erase them after the loop. Add a `view_test` case that frees a window node before `remove`.
- **Effort:** S. **Risk:** low. **Confidence:** medium (unverified at runtime).

### REND-10 · Medium · Size
- **What:** `effects.gd` (1236 lines) holds about eight unrelated effects, and its sub-modules call its private helpers.
- **Where:** `src/client/view/effects.gd`; `_ready` alone is 147 lines (`:192-339`). The private calls: `air_effects.gd:527` (`fx._curve`), `water_effects.gd:138` (`fx._curve`), `nature_effects.gd:110` (`fx._brightness`), `nature_effects.gd:220` (`fx._blow`).
- **Evidence:** What lives in the file:
  1. Weather emitters: rain, downpour, hail, snowfall, blizzard, sand.
  2. Wind leaves: leaves, gale, and torn (with a crown search over 40×56 columns, `_place_torn` `:992`).
  3. Ambient particles: fireflies (`_place_fireflies`), pollen.
  4. Campfires and their lights: `add_campfire`, `fire_strength`, the heat map, `pick_shadow_fires`, torch flames, `torch_off`.
  5. Placed lamps: `add_lamp`, and `_light_lamps` choosing the `LAMP_LIGHTS` nearest.
  6. Lightning: `strike`, `_bolt_line`.
  7. One-shot particles: `burst`, `puff`, `dust`, `wake`, `level_sparks`, `sack_glow`.
  8. Light anchoring to the sheared world: `anchor`, `move_anchor`, `reanchor` (120 lines).

  On top of these it builds the campfire model, holds the particle-factory helpers (`_emitter`, `_ramp`, `_curve`, `_blow`, `_brightness`, `_fogged`), and hosts 8 child modules (`glows`, `lit`, `wisps`, `windows`, `air`, `water`, `nature`, `trees`).
- **Why it matters:** Any effects change means reading this whole file. The private helpers are an API in practice but not by name.
- **Proposed refactoring:** Move the helpers to a public `particle_kit.gd` (static). Then split out `weather_fx.gd` (1-3), `fire_lights.gd` (4, 5, 8) and `spark_fx.gd` (6, 7). `effects.gd` stays as the hub that `main` builds.
- **Effort:** M. **Risk:** low. **Confidence:** high.

### REND-11 · Medium · Coupling
- **What:** Rendering modules reach into other modules' internals through `game.*` chains and private fields, and the felling animation is started as a side effect of re-meshing.
- **Where:**
  - `chunk_streamer.gd:1086,1158,1174` write `game.hud.perf.chunks`.
  - `:797,1354` call `game.hud.minimap.paint_chunk/touch`.
  - `:1192-1195,1295-1298,1306-1316` use `game.get("effects")` and then `.glows/.lit/.trees`.
  - `:1255` reads `game.props.drop_nodes`.
  - `:1328-1329` calls `game.plan_view.things.refit_boxes`.
  - `:1281-1288` decides that a tree was felled by diffing `_standing` and calls `fx_trees().fall`.
  - `props.gd` reads `game.chunks.chunk_nodes` (4 places).
  - `sky.gd` reads `game.effects.wisps.update/world`.
  - `tracks.gd:79` writes `trample._window`.
  - `others.gd:355` calls `f._animate`.
  - `chunk_mesher.gd:1187` calls `w._shape` (WorldData's private).
- **Evidence:** Grepping `game\.[a-z_]+\.[a-z_]+\.[a-z_]+` finds 20 or more three-level chains in the area.
- **Why it matters:** The coupling is not visible from signatures, so a rename in the HUD, effects or props breaks the streamer. A chunk rebuilt for any other reason can replay a fall if `_standing` gets out of step.
- **Proposed refactoring:** The streamer emits `chunk_shown(key)`, `chunk_freed(key)`, `glows_found(key, spots, mats)` and `trees_shown(key, standing)`. Effects, props, the minimap and perf connect to them. Felling should be reported by the session (a cell change with a reason), not inferred from meshes. Make `WorldData._shape` public, or use its public accessor.
- **Effort:** M. **Risk:** low. **Confidence:** high.

### REND-12 · Medium · Performance
- **What:** The mesher's hot path is untyped and allocates Arrays per face.
- **Where:**
  - Untyped `buf`: 20 functions in `chunk_mesher.gd`, 21 in `water_mesher.gd`, 13 in `old_slope_mesher.gd`, 12 in `trunk_mesher.gd`, 7 in `mesh_faces.gd`, 2 in `form_mesher.gd`.
  - Untyped `w`: 23 functions in `chunk_mesher.gd`, 29 in `foliage.gd`.
  - The `Job` class's `var w`, `var solid`, `var water` are untyped: `chunk_mesher.gd:37,45-46`.
  - Only one parameter in all of `src/client/world` is typed `buf: MeshBuffers` or `w: WorldData`.
  - `MeshBuffers.quad`/`tri` take `Array`s: `mesh_buffers.gd:15-45`.
  - Callers build literal arrays per face: `mesh_faces.gd:327-335` (`_add`: `pts`, `uvs`) and `chunk_mesher.gd:1217` (`[base + corners[0], ...]`).
- **Evidence:** See the grep counts above. Every `buf.quad(...)` call is dynamically dispatched and allocates 2-3 Arrays.
- **Why it matters:** Meshing is the main budgeted cost (`run_jobs`), and the phone runs GDScript about 10× slower. Typed calls and no per-face allocation are the cheapest wins.
- **Proposed refactoring:**
  - Type `buf: MeshBuffers` (already preloaded in `mesh_faces.gd:11`).
  - Type `w` where a WorldData preload makes no cycle (check with `--check-only`).
  - Add `quad4(a, b, c, d, n, uv0..uv3, color, packed)` without Arrays.
  - Measure with `tools/profile.gd` and the `frame_test` chunk cost before and after.
- **Effort:** M. **Risk:** low. **Confidence:** medium (the gain is not measured).

### REND-13 · Medium · Performance
- **What:** Turning the camera refits the culling box of every shown node in one frame, twice per turn. It is not budgeted and `frame_test` does not cover it.
- **Where:** `chunk_streamer.gd:1321-1329` (`refit_boxes`: 9 nodes per chunk plus the caps, plus `props.refit_boxes` over all props and drops at `props.gd:1112-1120`, plus `plan_things`). Called from `camera_rig.gd:205,216,362,397,524`.
- **Evidence:** The reach is `Session.ZONE` 5, so 11×11 = 121 chunks, up to `ZONE_MOST` 10 (21×21) on large windows. Each `_fit_box` calls `PixelView.sheared_box` over all `box_views`.
- **Why it matters:** This is a possible hitch on every camera turn on a phone. Unverified: `frame_test` has no turn scenario.
- **Proposed refactoring:** Add a camera-turn scenario to `frame_test`. If it is slow, fit boxes once for the union of all 8 turns at build time (looser culling, no refit), or spread the refit over frames nearest first, as `update_caps` does.
- **Effort:** S for the test, M for the fix. **Risk:** low. **Confidence:** medium.

### REND-14 · Low · Performance
- **What:** Shader parameters are set every frame whether or not they changed.
- **Where:**
  - `sky.gd`: about 25 `global_shader_parameter_set` calls in `_update_light`, `_update_fog` and `_update_weather` (`:224-235`, `:407-417`, `:535-558`), including values that are constant for a world: `snow_line` (`:536`), `fog_sea` (`:417`).
  - `effects.gd:646` sets `lean` on rain and downpour, and `:680-682` sets `light` on every weather emitter's material every frame, even when the emitter is not emitting.
  - `fire_shadows.gd:187-201` allocates a Dictionary and an Array and runs `_trunk_wedges.duplicate()` every frame at night.
- **Evidence:** See the lines above. `chunk_streamer._update_depth` (`:1761-1765`) already shows the right pattern: it caches the last value and only sets on a change.
- **Why it matters:** Each global set dirties the global uniform buffer, which is then re-uploaded every frame (in the Compatibility renderer). This is per-frame cost on the phone. The size is unmeasured; WA-032 covers idle headroom in general.
- **Proposed refactoring:** Add a tiny `GlobalParams.set_if_changed(name, v)` helper. Set the per-world constants once in `prepare`.
- **Effort:** S. **Risk:** low. **Confidence:** medium.

### REND-15 · Low · Dead code
- **What:** The names still say "old slopes" although the old slopes are now the only ones. The "slopes" world option is vestigial, and the planning docs are stale.
- **Where:**
  - `old_slope_mesher.gd:1-6` (the header says these are the only slopes since 2026-11-20).
  - `OldSlopes` consts: `chunk_mesher.gd:16`, `water_mesher.gd:7`.
  - `OLD_CUT`: `mesh_faces.gd:91`.
  - The option itself: `land_layout.gd:72,75` (`"slopes": 0`), `world_store.gd:63-80` (the comment says "with the new slopes and with the old ones"; the value only names the save folder).
  - `world_list.gd:133` (`for slopes in [1]`), `settings.gd:215,223,421-423`.
  - `docs/planning/archive/mesher-merge.md` "Left 1" (still asks whether to remove `old_slope_mesher`) and its mention of `old_shapes_test`, which does not exist in `tests/`.
- **Evidence:** No `SlopeMesher`/`EdgeMesher` code is left: the new-slope meshers were deleted cleanly. A grep finds `slopes` read in `src/shared/world` only in the option tables and the folder name.
- **Why it matters:** A reader sees two slope systems where there is one. The world option costs a menu path and a settings migration.
- **Proposed refactoring:**
  - Rename `old_slope_mesher.gd` to `slope_mesher.gd` (`Slopes`) and `OLD_CUT` to `CUT_QUARTER`.
  - Mark `mesher.md`/`mesher-merge.md` DONE.
  - Retiring the `slopes` option changes the test world's save folder (`test-o1`), so it needs the owner's pick and a rename map.
- **Effort:** S. **Risk:** low. **Confidence:** high.

### REND-16 · Low · Dead code
- **What:** Two tree art paths are still alive. The leaf-cluster crowns are now only a fallback for young trees and for trunk heights that have no picture look. The "species without pictures" branch is never taken with the shipped content.
- **Where:** The fallback gate is `foliage.gd:415-417` (`Growth.standing_look(w, tree[0]) >= 0` → return). The fallback crowns are `_spruce` `:670`, `_broad` `:755` (117 lines), `_strands` `:872`, `_fronds` `:899`, and `_cone_shadow`/`_tree_shadows` (about 400 lines in all). `growth.gd:150` (`if s.pictures.is_empty(): return -1`). `tree_sprites.gd:86-89`.
- **Evidence:** All 21 species under `content/plants/*/data/trees.yaml` have a `tree/look.yaml` with pictures. `standing_look` returns -1 for `young_at(...)` or when no look matches the trunk height.
- **Why it matters:** This is about 400 lines of foliage plus `leaves.gdshader` (336 lines) and the `LEAF_ROWS`/`BLOSSOM_ROW` atlas rows, kept only for saplings and young trees. A mod tree without pictures still relies on it, so it is not dead, but its purpose should be stated.
- **Proposed refactoring:**
  - Document in `foliage.gd` and `chunks.md` that these paths serve young trees only.
  - Add a test that a grown tree of each shipped species gets a look (`standing_look >= 0` for every trunk height the growth produces), so a missing look is caught rather than silently drawn in the old style.
  - Remove the old paths once young trees get pictures.
- **Effort:** S (test and docs). **Risk:** low. **Confidence:** high.

### REND-17 · Medium · Tests
- **What:** Several risky parts of the picture and the streamer have no automated check.
- **Where:** `tests/frame_test.gd`, with the scenarios at `:157-576`; `tests/unit/view_test.gd` (41 tests); `tests/unit/mesher_test.gd` (8 tests).
- **Evidence:** What `frame_test` covers: streaming while walking, digging, filling, cut changes, jumping in a cave, landing, the action button, crafting, mowing, idle, and night. It has no scenario for:
  - camera turn or tilt (REND-13)
  - storm or torn leaves (`_place_torn` crown search)
  - first person
  - a base with many props or lamps, or a build-cut step over many props (`props._recut` walks all of `game.placed.things`, `props.gd:351-361`)

  The floors logic and the streamer's state transitions (REND-2, REND-3) are checked only inside `frame_test`, which CLAUDE.md leaves to CI. No test covers:
  - the GDScript↔shader constants (REND-5)
  - the atlas height (REND-4)
  - the full `CaveLayers.share` ↔ `layer_alpha` equivalence

  These are verifiable only by screenshots: the cut caps and section rim, the layer dither, the tree pictures with snow, stumps and pieces, the surf, falls and swash, the build-floor cut of things, and the sprite views.
- **Why it matters:** Regressions in these areas show up on a phone or in a playtest, not in CI.
- **Proposed refactoring:** Add the unit tests named in REND-2, 3, 4 and 5. Add `frame_test` scenarios for a camera turn, a storm, and the build cut with about 200 placed things. Add a screenshot sheet for the "picture-only" list in `tools/shot` places.
- **Effort:** M. **Risk:** low. **Confidence:** high.

### REND-18 · Low · Docs
- **What:** `docs/systems/chunks.md` is not the short overview the project's rules ask for.
- **Where:** `docs/systems/chunks.md` (32,508 bytes; line 98 is a single paragraph of more than 4 KB about the water mesher).
- **Evidence:** CLAUDE.md says "`docs/systems/<x>.md` is a short overview, its pages are in `docs/systems/<x>/`". `chunks.md` has no pages folder and holds mesher-level detail.
- **Why it matters:** Every task in this area pays about 8k tokens to read the overview, against the "Reading cheaply" rule.
- **Proposed refactoring:** Split it into `chunks.md` (a 1-2 KB overview) plus `chunks/streamer.md`, `chunks/meshers.md`, `chunks/water.md`, `chunks/cut.md`.
- **Effort:** S. **Risk:** low. **Confidence:** high.

---

## Healthy
- **Shader limits are enforced.** `tools/lint.py` counts the samplers and varyings of every shader, includes and variants counted, and the pitfalls doc explains why. Keep it; REND-7 is about headroom, not about the check.
- **Sprite shaders are already factored.** `sprite`, `sprite_mirror`, `sprite_water` and `sprite_xray` share `face_view`/`stand_tall`/`shear` from `common`, and the only cross-file copy is the tree pair in REND-6.
- **The `FALLING` variant is guarded.** It is a single define, created and tested in `view_test._test_tree_shaders`. There is no variant explosion.
- **Budgets are wall-clock and measured.** `run_jobs` budgets and `budget_us`, with `frame_test` judging budgeted and unbudgeted time separately, are a sound design worth keeping through any split.
- **The mesher layering is clean.** `mesh_faces.gd` is the shared base for constants and primitives, `MeshBuffers` is the single emitter, and each special mesher extends the base. No new-slope or edge-mesher code was left behind.
- **Per-world reset is handled.** `MeshFaces.forget()` after a `Mods.activate` re-reads the material numbers; `ChunkStreamer._init` resets the layer globals.
- **Expensive per-frame scans are throttled.** `EdgeHaze.update` skips its scan when nothing changed (WA-036). `SolidMap` rebuilds a few rows a frame and uploads once per frame.
- **Trees draw in one call per chunk.** `TreeSprites` uses one MultiMesh per chunk, and the shadow node shares that MultiMesh.

## Not covered
- The bodies of `sky.gd`, `camera_rig.gd`, `pixel_view.gd`, `figure.gd`/`player.gd`, `sun_rays.gd`, `death_fx.gd`, `tree_hits.gd` and `water_effects`/`air_effects`/`nature_effects`. I only grepped them for per-frame sets and private access.
- The bodies of `water_mesher.gd`, `old_slope_mesher.gd` and `form_mesher.gd`. I only checked their function lists and shared helpers; `trunk_mesher._facing` repeats `mesh_faces._wound` for quads, which is minor.
- The bulk of `grade.gdshader` (761 lines), `water.gdshader` (773 lines) and `world.gdshader`.
- Whether chunk unloading leaks. `_free_chunk` frees its nodes and caps, and meshes and MultiMeshes are reference counted; I did not check the RID lifetime of `fire_shadows`/`glow_lights` per-chunk spots beyond `set_spots(key, empty)`.
- Runtime confirmation of REND-4 (atlas height), REND-9 (the Dictionary erase), REND-12 and REND-13 (costs). Godot was not available.
