# Survivium: notes for contributors

Godot 4.5.1, GL Compatibility renderer, pure GDScript. The game runs in the browser (web export
without threads) and later on Android; a headless server comes with the MVP. Design and plans live
outside the repo, in the Claude project's `plan/` folder (`plan/README.md` is the index and the
decision log, `plan/mvp.md` the stages). User-facing text and the README are in Russian; code,
comments, commits and PRs are in English.

## Layout and dependencies

```
src/shared/    the world model and the rules the server will run; loads nothing from src/client
  content/     mod loader and registries: content, yaml, materials, items, trees, bushes, plants,
               crafting (recipes), tools, ai_rules
  world/       world_data, world_gen, world_store, voxel_raycast, grass (what grows on a cell)
  game/        rules of play: inventory, vitals, knowledge, craft_queue, world_actions (dig,
               build, chop, gather, plant), body (walking, jumping, swimming on the cells,
               slowed by snow, head wind and blizzards in the open, carried by the wind in
               a jump; trails in the snow),
               placed (chests, stations, campfires on 2x2 cells), workshop (crafting),
               clock (time of day, seasons, moon phases, the weather and its WEATHERS table,
               the wind's side and the autumn leaf fall), storms (what a gale breaks and
               knocks off the trees and bushes around the player),
               character (the bag, the body's state, action costs, eating, what a life did, death and
               coming back),
               wildlife (the animals: they come, wander, rest, flee, hunt)
src/client/    draws and reads input; main.gd, settings.gd, save_game.gd at the top
  world/       the chunks on screen: chunk_streamer, chunk_mesher, mesh_buffers, foliage, drifts,
               tracks, roof_map
  view/        the picture: pixel_view, camera_rig, sky, effects, fire_shadows, pixel_textures,
               voxel_model, voxel_props, player, figure, hands, sprite_sheet, sprite_art
  input/       controls, cursor, touch_stick, touch_button
  game/        game systems on this device: character (extends the shared one with the
               player's place, hands and screen), gathering, props (the placed things and the
               drops drawn), creatures (the animals drawn)
  ui/          hud, menus, windows, maps, panels and their widgets, ui_style
```

- A new script goes into the folder of its layer. What happens in the game (a rule the server
  must decide) goes into `src/shared/`; how it is drawn or asked for goes into `src/client/`.
  `run_tests.gd` fails if anything under `src/shared/` loads a script from `src/client/`. The rules
  of play all live in `src/shared/game/`; the modules of `src/client/game/` draw what they do and
  bring them the player's input (`plan/architecture/code-structure.md`). A rule takes the one acting as `who` (on the client
  `character.gd`, which answers for the body, the hands and the bag) and tells what it changed
  through signals the client's views connect to (see `world_actions.gd`).
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
  creatures, trees, bushes, recipes, plants), lists of records with namespaced ids (`core:grass`). `src/shared/content/content.gd`
  reads and checks them against its schemas (`tools/validate.gd` runs the same checks in CI, and that
  every recipe can be made from what the world gives); the
  registries `materials.gd`, `items.gd`, `ai_rules.gd`, `trees.gd`, `bushes.gd`, `crafting.gd`, `plants.gd` fill their static vars from
  them when their class loads, so code keeps using `Mat.GRASS`, `Trees.OAK`, `AiRules.SPECIES`.
  New numbers that describe content go into the YAML and the schema, not into constants.
- Scripts are loaded with `preload` consts, no `class_name`.
- `main.gd` only builds the scene and runs the frame; the work lives in modules that get the Main
  node as `game`: `chunk_streamer.gd` (generates and meshes the chunks within `LOAD_RANGE` of the
  player, frees meshes beyond `UNLOAD_RANGE`, streaming budgets, caps, the level cut), `sky.gd`
  (the light, colour grade, sun rays, morning mist, tints and weather drawn for `game.clock`, `src/shared/game/clock.gd`), `controls.gd` (keys, mouse, touch, edits: `hands` holds any item in each hand, `active`
  is the hand in use, the hotbar is the bag's first `Inventory.HOTBAR` slots, the brush, strokes, the action button in front; what the hands do to the world is `src/shared/game/world_actions.gd`, each tool's rules `src/shared/content/tools.gd`),
  `camera_rig.gd` (pixel view, camera, safe rect), `cursor.gd` (the frame round the cells an action works on), `fire_shadows.gd` (shadows of fires and the torch drawn on the ground), `props.gd` (draws the things placed on 2×2 cells, whose rules are `src/shared/game/placed.gd`: chests and what they hold, workbenches, kilns, campfires, solid through `WorldData.blockers`; and the items lying on the ground, `WorldData.drops`), crafting is `src/shared/game/workshop.gd` (recipes known, the crafting queue worked near its station, tool wear and repair; `game.workshop`; recipes in `src/shared/content/crafting.gd`; the window is `craft_panel.gd`, a tab of `inventory_window.gd`), `minimap.gd`
  (painted per chunk from the cells into regions of 32 chunks), `map_view.gd` (the explored map
  full screen), `main_menu.gd` (the first screen, over the live world of the saved seed built behind it;
  "Новый мир" opens `world_setup.gd` over it and `main.restart()` reloads the scene for another
  world; tests and tools set `main.skip_setup` to start without it),
  `settings.gd` (saved settings, playtest switches; every module reads its values from there),
  `settings_menu.gd` (the settings and playtest pages, rows of "name ‹ value ›"), `save_game.gd`
  (picks the world played last, puts the player, clock and props back, autosaves; modules keep
  their part of the player with `save.track(name, obj)`), `character.gd` (the player's character: it extends `src/shared/game/character.gd`, which holds the
  bag and the body, `Inventory` and `Vitals`, action costs, death: the bag in a sack, the character
  lies dead, kept in the save, until `death_screen.gd` brings them back at a respawn point), `gathering.gd` (what a tap
  gathers: the nearest thing on the ground, bush or placed thing to the finger, and its hint; things
  taken up by themselves near the player; the rules are `world_actions.gd`, what grows on grass
  `src/shared/world/grass.gd`), `hands.gd` (what the player is drawn holding in each
  hand). The player's sprite (`figure.gd`) is put together from the core mod's pictures, laid out
  by `content/core/sprites/player.yaml`: the bare figure in layers with the hands moving through
  every animation (idle, walk, jump, swim, the works an item's `anim` names), `player/hands.png`
  marking where each hand is in each frame and the way what it holds points, and a sheet per tool
  held (`held/<item sprite>.png`) put at the hand; a thing without one is its icon, made small and
  turned with the hand; drawn for the right hand in use, the left one is the opposite direction
  mirrored; built a part of a row a frame; swings start with `player.work`. The pictures were drawn
  by `tools/art/` (the poses, the tools' turns) and saved by `tools/make_sprites.gd`; they can be
  painted over by hand.
  New state goes into the module it belongs to, not into `main.gd`; a new system is a new module.

## Version and changes

The client's version is `<stage>.<PR>`: the stage is `application/config/version` in
`project.godot` (raise it by hand when an MVP stage closes), the PR is the last one merged into
main, so `0.1.67` is the build with PR #67 in it. CI writes it with `tools/build_info.py` into
`build_info.json` (not in git; a local run shows `dev`), along with the lines
`Что нового: …` from the descriptions of the last merged PRs; the «Тестирование» page shows the
version and opens them («Что нового»). So every PR description has one such line in Russian,
for a player, not a programmer (a PR without one is left out of the list).

## Checks before every push

```
godot --headless --path . --import
godot --headless --path . --script res://tools/validate.gd
godot --headless --path . --script res://tests/run_tests.gd
timeout 300 godot --headless --path . --script res://tests/save_test.gd
timeout 600 godot --headless --path . --script res://tests/progress_test.gd
timeout 600 godot --headless --path . --script res://tests/frame_test.gd
```

`frame_test.gd` plays scenarios headless (walk, dig, cut change, streaming) and fails when
chunk-sized work lands in one frame; CI runs it too. `progress_test.gd` starts a new world with an
empty bag and plays the way to every recipe through the game's own calls (taps, action button,
craft tab): gathers the materials, sets down the stations, makes everything; it fails on the
first thing it cannot get or make. Run it after any change to tools, materials, stations, recipes
or what the hands do; CI runs it on every push.

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
draws the land around the spawn from above; `tools/bench_*.gd` time generation, meshing and edits;
`tools/profile.gd` times each module of a frame headless and counts draw calls under xvfb (`-- spikes`
times one-off actions).

## Performance rule

Nothing map-sized or chunk-sized runs in one frame. Chunk meshes and plants are built a column of
cells at a time through `ChunkMesher` / `Foliage` jobs, and chunks are generated a row at a time
through `WorldGen` jobs, all run by `chunk_streamer.gd` within per-frame budgets (edits first, then
far chunks, then caps). `tests/frame_test.gd` enforces this. The phone browser is about 10x slower than a desktop in
GDScript. Notes: `plan/architecture/performance.md`.

## Gotchas

- A static func named like a method of `Script` (`reload`, `get_class`, `is_tool`...) is shadowed: `Mat.reload()`
  recompiles the script and resets its static vars instead of calling yours.
- A lambda that uses `self` keeps the object alive; connected to a signal of something the object
  holds (its bag, its queue) it makes a cycle a RefCounted is never freed from, with all it refers
  to (the world). Connect a method instead (see `src/shared/game/character.gd`).
- `var i := expr` is a parse error when `expr` is a Variant (e.g. a field of an untyped object); type
  such vars explicitly.
- Godot front faces wind clockwise; a hand-built mesh wound counter-clockwise is inside out.
- MultiMesh instance data is half float on GLES3/web: put new per-instance data in COLOR, not in a
  packed int. Vertex COLOR is 8-bit and clamps above 1.
- Silhouettes behind geometry use `render_mode depth_test_inverted`; the player's skips pixels the stencil
  marks low (1: grass, bushes, low props; tall world and crowns write 2).
- A light with shadows is drawn in a pass of its own and added in sRGB, not in linear light: it looks
  brighter over other light. Fires and the torch scale their energy for it (`Effects.SHADOW_ENERGY`) and
  cast shadows only at night; which things cast from which light goes by render layers
  (`PixelView.LAYER_*`, `shadow_caster_mask`). An omni light's dual-paraboloid shadow casts nothing in
  Compatibility; a cube shadow plus its pass cost ~+400 draw calls, so by default ("mixed") the nearest
  fire casts a real shadow from the player alone (`shadow_caster_mask`) and the rest are drawn on the
  ground (`fire_shadows.gd`); all real is a setting.
- Web touch: a moving finger also arrives as a real `InputEventMouseMotion`; `controls.input` treats
  mouse motion as a mouse only with no finger down and more than 1 s after the last touch. The
  joystick and `TouchButton` follow their own touch index so two thumbs work at once.
