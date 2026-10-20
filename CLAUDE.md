# Survivium: notes for contributors

Godot 4.5.1, GL Compatibility renderer, pure GDScript. The game runs in the browser (web export
without threads) and later on Android; a headless server comes with the MVP. Design and plans live
outside the repo, in the Claude project's `plan/` folder (`plan/README.md` is the index and the
decision log, `plan/mvp.md` the stages). User-facing text and the README are in Russian; code,
comments, commits and PRs are in English.

## Layout and dependencies

- `src/shared/` must not preload anything from `src/client/`: it is the world model the future
  server will run (data, generation, materials, trees, bushes, AI rules, raycast).
- The world has no edge. `world_data.gd` keeps the cells in `Chunk`s by key (`chunk_at`,
  `chunk_key`; use `>>`/`&` for negative coordinates); an absent chunk reads as air (stone below
  0) and blocks bodies. `world_gen.gd` makes everything from noise: slow noises (continents,
  rivers, lakes) on a world-wide lattice every `LATTICE` cells, distances to coast and river as
  value / gradient, settings from the setup screen (`DEFAULT_SETTINGS`). It makes each chunk in
  three stages, `TERRAIN` (cells of the chunk from a window with a 3-cell margin) → `PLANTED` (trees, needs TERRAIN on the 3×3 around)
  → `SHAPED` (slopes, corners, bushes; needs PLANTED on the 3×3 around); a mesh needs SHAPED. Stages
  are stepped a row or a tree at a time through `start`/`step` jobs, and the result does not depend
  on the order chunks are made in (`run_tests.gd` checks that). Everything is a hash of the column
  and the seed, so a chunk can be made at any time; `WorldData.track_edits` is off meanwhile, and
  generator writes skip SHAPED (`final`) chunks. Unedited chunks beyond `DROP_RANGE` are forgotten
  (`gen.forget`) and made again the same, regrowing the neighbours' trees that reach in.
  Saves (`world_store.gd`): one folder per world under `user://saves` with `world.json`, players and
  only the changed chunks (`WorldGen.pack`); a player's change that is not a cell goes through
  `WorldData.note_edit` so the chunk is kept and saved, and a saved chunk comes back SHAPED in place
  of its TERRAIN stage. `lay_out(x0, z0, w, h, step)` gives the layout of any window (maps, the setup screen,
  `find_place`). Texture maps over the world (roof, heat) wrap every `RoofMap.WRAP` cells
  (`wrap_size` shader global).
- `src/client/` draws and reads input. New 3D shaders include `shaders/common.gdshaderinc` and shear
  VERTEX like the others (oblique 3/4 view: `z -= y`, camera looks straight down); lights go at
  `PixelView.shear(pos)`, picking uses `PixelView.view_ray`. Details: `plan/architecture/rendering.md`.
- `content/<mod>/` holds the game data: `mod.yaml` and `data/<kind>.yaml` (materials, items,
  creatures, trees, bushes), lists of records with namespaced ids (`core:grass`). `src/shared/content.gd`
  reads and checks them against its schemas (`tools/validate.gd` runs the same checks in CI); the
  registries `materials.gd`, `items.gd`, `ai_rules.gd`, `trees.gd`, `bushes.gd` fill their static vars from
  them when their class loads, so code keeps using `Mat.GRASS`, `Trees.OAK`, `AiRules.SPECIES`.
  New numbers that describe content go into the YAML and the schema, not into constants.
- Scripts are loaded with `preload` consts, no `class_name`.
- `main.gd` only builds the scene and runs the frame; the work lives in modules that get the Main
  node as `game`: `chunk_streamer.gd` (generates and meshes the chunks within `LOAD_RANGE` of the
  player, frees meshes beyond `UNLOAD_RANGE`, streaming budgets, caps, the level cut), `sky.gd`
  (time, seasons, weather, light, colour grade), `controls.gd` (keys, mouse, touch, edits),
  `camera_rig.gd` (pixel view, camera, safe rect), `props.gd` (chest, campfire), `minimap.gd`
  (painted per chunk from the cells into regions of 32 chunks), `map_view.gd` (the explored map
  full screen), `main_menu.gd` (the first screen, over the live world of the saved seed built behind it;
  "Новый мир" opens `world_setup.gd` over it and `main.restart()` reloads the scene for another
  world; tests and tools set `main.skip_setup` to start without it),
  `settings.gd` (saved settings, playtest switches; every module reads its values from there),
  `settings_menu.gd` (the settings and playtest pages, rows of "name ‹ value ›"), `save_game.gd`
  (picks the world played last, puts the player, clock and props back, autosaves; modules keep
  their part of the player with `save.track(name, obj)`), `character.gd` (the bag and the body:
  `Inventory` and `Vitals` from `src/shared/`, action costs, death), `gathering.gd` (picking up
  drops, berries and branches off bushes by a tap near them).
  New state goes into the module it belongs to, not into `main.gd`; a new system is a new module.

## Checks before every push

```
godot --headless --path . --import
godot --headless --path . --script res://tools/validate.gd
godot --headless --path . --script res://tests/run_tests.gd
timeout 300 godot --headless --path . --script res://tests/save_test.gd
timeout 600 godot --headless --path . --script res://tests/frame_test.gd
```

`frame_test.gd` plays scenarios headless (walk, dig, cut change, streaming) and fails when
chunk-sized work lands in one frame; CI runs it too.

Run `--import` again after pulling new assets (fonts, textures), or HUD scripts fail with null
errors that look like code bugs. Wrap headless runs in `timeout`: a runtime error in an awaiting
script leaves Godot running. `--check-only --script res://x.gd` only parses.

CI (`.github/workflows/build.yml`) also exports the web build and runs `tests/browser_smoke.mjs` in
headless Chrome (desktop and a phone with DPR 3 and touch); it fails on SCRIPT ERROR / Parse Error
and prints load timings and a screenshot. CI renders in software: its FPS means nothing, only the
user's phone numbers count (stats panel, F3).

Screenshots without a GPU: `xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver
opengl3 --resolution 1280x720 --script res://tools/shot.gd -- <dir> [shot names]` (slow, run in the
background). Shots share one world per run, so a shot that edits cells restores them. `tools/map.gd`
draws the land around the spawn from above; `tools/bench_*.gd` time generation, meshing and edits.

## Performance rule

Nothing map-sized or chunk-sized runs in one frame. Chunk meshes and plants are built a column of
cells at a time through `ChunkMesher` / `Foliage` jobs, and chunks are generated a row at a time
through `WorldGen` jobs, all run by `chunk_streamer.gd` within per-frame budgets (edits first, then
far chunks, then caps). `tests/frame_test.gd` enforces this. The phone browser is about 10x slower than a desktop in
GDScript. Notes: `plan/architecture/performance.md`.

## Gotchas

- A static func named like a method of `Script` (`reload`, `get_class`...) is shadowed: `Mat.reload()`
  recompiles the script and resets its static vars instead of calling yours.
- `var i := expr` is a parse error when `expr` is a Variant (e.g. a field of an untyped object); type
  such vars explicitly.
- Godot front faces wind clockwise; a hand-built mesh wound counter-clockwise is inside out.
- MultiMesh instance data is half float on GLES3/web: put new per-instance data in COLOR, not in a
  packed int. Vertex COLOR is 8-bit and clamps above 1.
- Silhouettes behind geometry use `render_mode depth_test_inverted`.
- Web touch: a moving finger also arrives as a real `InputEventMouseMotion`; `controls.input` treats
  mouse motion as a mouse only with no finger down and more than 1 s after the last touch. The
  joystick and `TouchButton` follow their own touch index so two thumbs work at once.
