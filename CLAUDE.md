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
               the wind's side and the autumn leaf fall; or the device's time and calendar),
               real_weather (the real weather where the device is, by IP and Open-Meteo,
               pinned on the clock), storms (what a gale breaks and
               knocks off the trees and bushes around the player),
               character (the bag, the body's state, action costs, eating, what a life did, death and
               coming back),
               wildlife (the animals: they come, wander, rest, flee, hunt; flocks follow
               their lead, flyers fly between places and roost in the crowns)
src/client/    draws and reads input; main.gd, settings.gd, save_game.gd at the top
  world/       the chunks on screen: chunk_streamer, chunk_mesher, mesh_buffers, foliage, drifts,
               tracks, roof_map
  view/        the picture: pixel_view, camera_rig, sky, effects, fire_shadows, pixel_textures,
               voxel_model, voxel_props, player, figure, hands, sprite_sheet, sprite_art,
               draw_census (the draw calls counted by what is drawn, from «Отладка»),
               shader_warmup (the shaders of every mix of lights built as the game starts)
  input/       controls, cursor, touch_stick, touch_button
  audio/       sound: sound (buses, volumes, the ear, voices, loops), nature, steps, voices
               (the animals'), music (pieces made of notes)
  game/        game systems on this device: character (extends the shared one with the
               player's place, hands and screen), gathering, props (the placed things and the
               drops drawn), creatures (the animals drawn), markers (the player's map markers)
  ui/          hud, menus, windows, maps, panels and their widgets, sound_marks, ui_style
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
  value / gradient, settings from the setup screen (`DEFAULT_SETTINGS`); mountains with scree and
  snow above `WorldData.SNOW_LINE`, rivers climbing them in steps (rapids, waterfalls drawn by
  `ChunkMesher._falls`), deltas at the sea, caves in mountains' sides (`_tunnels`). It makes each chunk in
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
  VERTEX like the others (oblique 3/4 view: `z -= y` in the default view, camera looks straight down);
  lights go at `PixelView.shear(pos)`, picking uses `PixelView.view_ray`. The camera turns in 45°
  steps and tilts two steps each way, a wall 4..12 px under an 8 px top (`camera_rig.gd`,
  `PixelView.set_view`): the shear then runs up the image (`view_up`, `view_slope`, `view_squash`
  globals), upright quads face the camera through `face_view` (sprites and plants also through
  `stand_tall`, which keeps them their pixel height at any tilt), the open edges of cells are a light rim
  toward the sun or the moon and an outline away from it (`light_side`, one of eight sides kept with a
  margin by `sky.gd` so they never flicker), texels counted on the screen use `screen_plane`, screen directions go through
  `PixelView.world_dir` / `screen_dir`, and chunk culling boxes are refitted for every view on
  the way (`ChunkStreamer.refit_boxes`). Details: `plan/architecture/rendering.md`.
- `content/<mod>/` holds the game data: `mod.yaml` and `data/<kind>.yaml` (materials, items,
  creatures, trees, bushes, recipes, plants, sounds), lists of records with namespaced ids (`core:grass`). `src/shared/content/content.gd`
  reads and checks them against its schemas (`tools/validate.gd` runs the same checks in CI, and that
  every recipe can be made from what the world gives); the
  registries `materials.gd`, `items.gd`, `ai_rules.gd`, `trees.gd`, `bushes.gd`, `crafting.gd`, `plants.gd` fill their static vars from
  them when their class loads, so code keeps using `Mat.GRASS`, `Trees.OAK`, `AiRules.SPECIES`.
  New numbers that describe content go into the YAML and the schema, not into constants. Mods load
  in the order of `Content.MODS`; `content/birds/` (sparrows, see its README) is a creature added by
  data and a picture alone: a species' picture is `sprites/creatures/<sprite>.png` of its mod, a
  row of `frames` frames (`creatures.gd`), and how it behaves comes from its properties
  (`flies`, `flock`, `roost`, `likes` besides mass, diet and the rest).
- Sound (`src/client/audio/`, `game.sound`): a sound is a record of the `sounds` kind with its files
  in `content/<mod>/sounds/` (`<name>.wav`, or `<name>_N.wav` per variant, `Content.sound_files`),
  made by `tools/make_sounds.gd` from noise and tones (`tools/sound/synth.gd`; WAVs import as QOA).
  Who sounds is data: a material's `step` and `hit`, a creature's `calls` and `alarm`. Buses Music,
  Sounds > Nature, UI take the settings' volumes. Nothing sounds before the first tap or key
  (`Sound.unlocked`, the browser's autoplay rule); the files load a few a frame after it. One-off
  sounds go through `play(id, pos)` (`pos` INF: from no place) or `play_later`, loops through
  `loop` (everywhere) and `spot` (from a place); the world round the player is looked at every
  `Sound.TICK`, not every frame. The ear stands at the player and turns with the camera. Web
  export plays samples (no AudioStreamGenerator), so music is notes scheduled by `music.gd`;
  each sample playing makes garbage for the page (the engine's position worklet and its copy of
  the whole sample at every play, both patched by `tools/web_patch.py` after the export, and its
  volume and pitch calls every frame), so keep the loops few.
- Scripts are loaded with `preload` consts, no `class_name`.
- `main.gd` only builds the scene and runs the frame; the work lives in modules that get the Main
  node as `game`: `chunk_streamer.gd` (generates and meshes the chunks within `LOAD_RANGE` of the
  player, frees meshes beyond `UNLOAD_RANGE`, streaming budgets, caps, the level cut), `sky.gd`
  (the light, colour grade, sun rays, the fog on the ground, puddles, tints and weather drawn for `game.clock`, `src/shared/game/clock.gd`), `controls.gd` (keys, mouse, touch, edits: `hands` holds any item in each hand, `active`
  is the hand in use, the hotbar is the bag's first `Inventory.HOTBAR` slots, the brush, strokes, the action button in front; what the hands do to the world is `src/shared/game/world_actions.gd`, each tool's rules `src/shared/content/tools.gd`),
  `camera_rig.gd` (pixel view, camera, safe rect), `cursor.gd` (the frame round the cells an action works on), `fire_shadows.gd` (shadows of fires and the torch drawn on the ground), `props.gd` (draws the things placed on 2×2 cells, whose rules are `src/shared/game/placed.gd`: chests and what they hold, workbenches, kilns, campfires, solid through `WorldData.blockers`; and the items lying on the ground, `WorldData.drops`), crafting is `src/shared/game/workshop.gd` (recipes known, the crafting queue worked near its station, tool wear and repair; `game.workshop`; recipes in `src/shared/content/crafting.gd`; the window is `craft_panel.gd`, a tab of `inventory_window.gd`), `minimap.gd`
  (painted per chunk from the cells into regions of 32 chunks, kept in the save; the ground drawn
  through `shaders/map_ground.gdshader`, which rounds the explored land's corners), `map_view.gd` (the
  explored map full screen in a panel; a tap sets a marker, `src/client/game/markers.gd`, kept in the
  save and listed on the playtest page, which can teleport the player to one), `main_menu.gd` (the first screen, over the live world of the saved seed built behind it;
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
`Что нового [вид]: …` from the descriptions of the last merged PRs; the «Тестирование» page shows
the version and opens them («Что нового»), each with the icon of its kind. So every PR description
has at least one such line in Russian, for a player, not a programmer (a PR without one is left out
of the list). The kinds: `новое` (the default when the tag is left out), `улучшено`, `исправлено`,
`оптимизировано`, `ядро` (code moved, tools, tests); a PR that does several things has a line for each,
e.g. `Что нового [исправлено]: Костёр больше не гаснет под крышей.`

## Checks before every push

```
godot --headless --path . --import
godot --headless --path . --script res://tools/validate.gd
godot --headless --path . --script res://tests/run_tests.gd
timeout 300 godot --headless --path . --script res://tests/save_test.gd
timeout 600 godot --headless --path . --script res://tests/progress_test.gd
timeout 600 godot --headless --path . --script res://tests/frame_test.gd
```

`tests/run_all.sh` runs the same after `--import`: the first four side by side, each with its own
`user://` (`XDG_DATA_HOME`), then `frame_test` alone, since it measures frame times
(`GODOT=path` if `godot` is not on PATH; names as arguments run only those).

`frame_test.gd` plays scenarios headless (walk, dig, cut change, streaming) and fails when
chunk-sized work lands in one frame; CI runs it too. `progress_test.gd` starts a new world with an
empty bag and plays the way to every recipe through the game's own calls (taps, action button,
craft tab): gathers the materials, sets down the stations, makes everything; it fails on the
first thing it cannot get or make. Run it after any change to tools, materials, stations, recipes
or what the hands do; CI runs it on every push.

Run `--import` again after pulling new assets (fonts, textures), or HUD scripts fail with null
errors that look like code bugs. Wrap headless runs in `timeout`: a runtime error in an awaiting
script leaves Godot running. `--check-only --script res://x.gd` only parses.

CI (`.github/workflows/build.yml`) runs its jobs side by side on machines of their own: the tests,
`frame_test` alone, the web export, then `tests/browser_smoke.mjs` in headless Chrome as a desktop
and as a phone with DPR 3 and touch (`node tests/browser_smoke.mjs desktop|phone`); it fails on
SCRIPT ERROR / Parse Error and prints load timings and a screenshot. On a PR the browser test runs
only when the PR touches what the browser may show differently (the `web` pattern in the `changes`
job: `src/client/`, shaders, scenes, assets, sprites, the web save store, the export settings, the
test itself, CI) or has the label `smoke`; on main it always runs, and Pages are published only when
every job passed. A software-WebGL frame takes a second or more and each input event waits for
one, so keep the smoke test's events few. CI renders in software: its FPS means nothing, only the
user's phone numbers count (stats panel, F3).

Screenshots without a GPU: `xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver
opengl3 --resolution 1280x720 --script res://tools/shot.gd -- <dir> [shot names]` (slow, run in the
background). Shots share one world per run, so a shot that edits cells restores them. `tools/map.gd`
draws the land around the spawn from above; `tools/bench_*.gd` time generation, meshing and edits;
`tools/profile.gd` times each module of a frame headless and counts draw calls under xvfb (`-- spikes`
times one-off actions).
`tools/make_icon.py` draws the icon (`icon.png`, the browser tab's and the apps') and
`assets/web/` (the home screen icon and the link preview `og.png`, copied next to `index.html` by
CI; the `og:` tags are in `html/head_include`).

## Performance rule

Nothing map-sized or chunk-sized runs in one frame. Chunk meshes and plants are built a column of
cells at a time through `ChunkMesher` / `Foliage` jobs (a tall column a few cells a step), and
chunks are generated a row at a time through `WorldGen` jobs (a tree's crown a few points a step), all run by `chunk_streamer.gd` within per-frame budgets (edits first, then
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
- The first draw of a material under a mix of lights it was not drawn under before (no sun at
  dusk, the torch, a fire's shadow) compiles shaders: 100 ms and more on a phone, 10 s under
  software GL. `shader_warmup.gd` draws one of each kind of thing in the world under every mix
  once the world is ready; a new kind of light or a material that shows up only later goes
  there. `MESA_SHADER_DUMP_PATH=dir` (with `MESA_SHADER_CACHE_DISABLE=true`) under xvfb writes
  every shader compiled, so the file times tell what an action compiled. Freezes on the device
  are listed with what happened in their frame in «Отладка» → «Журнал фризов» (`freeze_log.gd`):
  the game's parts, the engine's own work before drawing («движок»), the drawing («отрисовка»)
  and the rest, in the browser split by the page's frame callback («ввод»: before the frame in
  it, the input events dispatched; «браузер»: between the callbacks, the page, its garbage
  collection, the compositor waiting for the GPU; «конец кадра»: after the drawing), the draw
  calls, and in the browser the shader programs built (after the warm-up, named by the shader's
  own uniforms and the variant's defines) and the data sent to the GPU, timed by wrapping WebGL2's
  calls in the page, the page's full garbage collections («мусор», a finalizer on an object no one
  holds, told frames after the pause, so it is put beside the last freeze, with the heap before and
  after where Chrome tells it; the young ones are invisible to it), and what ran in a long page
  frame («страница N мс: до, кадр, touchmove, звук, после», from the long-animation-frame entries;
  `gl_watch.gd`); an ordinary frame's parts head the list. Things that show up only later (particles, the lightning,
  lines of the interface) are drawn by `shader_warmup.gd` too, or their first draw is a freeze; the
  HUD is hidden behind the menu meanwhile, so the interface's go on the world's canvas. A JS snippet run from GDScript
  must be strict and must not touch `arguments` in a wrapper with named params: that makes an
  object per call (7.5 KB a frame from the WebGL wrapper alone).
- Compatibility lights each mesh with at most `rendering/limits/opengl/max_lights_per_object`
  omni lights (32 here; Godot's 8 made square chunk-sized edges in the light by a camp of fires):
  a chunk mesh is one object, so past the cap neighbouring chunks are lit by different lights.
- Audio buses live in `default_bus_layout.tres`: the web export plays sounds as Web Audio samples
  through a copy of the buses made at start, so a bus added by `AudioServer.add_bus` later is silent
  in the browser (fine on desktop, so only the browser shows it).
- Web touch: a moving finger also arrives as a real `InputEventMouseMotion`; `controls.input` treats
  mouse motion as a mouse only with no finger down and more than 1 s after the last touch. The
  joystick and `TouchButton` follow their own touch index so two thumbs work at once.
