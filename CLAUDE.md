# Survivium: notes for contributors

Godot 4.5.1, GL Compatibility renderer, pure GDScript. The game runs in the browser (web export
without threads) and later on Android; a headless server comes with the MVP. Design and plans live
outside the repo, in the Claude project's `plan/` folder (`plan/README.md` is the index and the
decision log, `plan/mvp.md` the stages, `plan/backlog.md` the to-do list). User-facing text and the
README are in Russian; code, comments, commits and PRs are in English. Scripts are loaded with
`preload` consts, no `class_name`.

## Layers

```
src/shared/   the world model and the rules of play the server will run; loads nothing from src/client
  content/    mod loader and registries (content, yaml, materials, items, trees, bushes, plants,
              crafting, tools, ai_rules)
  world/      world_cells, world_data (extends it), land_layout, world_gen (extends it), world_store, voxel_raycast,
              grass, test_ground
  game/       rules: inventory, vitals, knowledge, craft_queue, workshop, world_actions, body, placed,
              clock, real_weather, storms, character, wildlife
src/client/   draws and reads input; main.gd, settings.gd, save_game.gd at the top
  world/      chunk_streamer, chunk_mesher (+ mesh_faces, slope_mesher, water_mesher, trunk_mesher), mesh_buffers,
              foliage, drifts, tracks, roof_map
  view/       pixel_view, camera_rig, sky, effects, fire_shadows, pixel_textures, voxel_model,
              voxel_props, player, figure, hands, sprite_sheet, draw_census, shader_warmup
  input/      controls, cursor, touch_stick, touch_button
  audio/      sound, nature, steps, voices, music
  game/       character (extends the shared one), gathering, props, creatures, markers
  ui/         hud, menus, windows, maps, panels, widgets, sound_marks, ui_style
content/      the mods: core (the base game), materials, sounds, tools, plants, animals; mod.yaml, then
              either data/<kind>.yaml, sprites/, icons/, models/, textures/, sounds/ or a folder per bundle
              (bundle.yaml and the same inside; common/ for assets the bundles share)
shaders/      3D shaders (include common.gdshaderinc), the colour grade, map and UI shaders
tests/        run_tests, save_test, progress_test, frame_test, browser_smoke.mjs, run_all.sh
tools/        validate, shot (+ shot/shots the table, shot/places the spots), map, profile, bench_*, build_info, make_sounds, make_sprites, make_models, make_icons,
              make_textures, art/, sound/
```

- A new script goes into the folder of its layer. What happens in the game (a rule the server must
  decide) goes into `src/shared/game/`; how it is drawn or asked for goes into `src/client/`.
  `run_tests.gd` fails if anything under `src/shared/` loads a script from `src/client/`. A rule takes
  the one acting as `who` (on the client `character.gd`: the body, the hands and the bag) and tells what
  it changed through signals the client's views connect to (`world_actions.gd`). Details and the
  table of systems: `plan/architecture/code-structure.md`.
- `main.gd` only builds the scene and runs the frame; the work lives in modules that get the Main
  node as `game`. New state goes into the module it belongs to; a new system is a new module.

## Modules

| Module | What it owns |
| --- | --- |
| `world_cells.gd`, `world_data.gd` | cells in `Chunk`s by key (`chunk_at`, `chunk_key`; `>>`/`&` for negative coordinates); an absent chunk reads as air (stone below 0) and blocks bodies; what stands and lies on the cells (trees, bushes, `blockers`, `drops`, `grows`, trails), `track_edits` / `note_edit` and `pack_chunk` / `unpack_chunk` for saving. `WorldData` extends it with the shapes of natural ground (`update_shapes`, slopes and corners a column at a time), slope surfaces (`surface_patch`, `ground_height`) and what a body meets (`blocks_body`, `blocks_part`, `ground_part`) |
| `land_layout.gd`, `world_gen.gd` | the layout of any window of columns from noise (`lay_out`: height, water, top, biome, flags; maps, the setup screen and `find_place` read it): slow noises on a lattice every `LATTICE` cells, distances to coast and river, `DEFAULT_SETTINGS` from the setup screen; mountains, scree and snow above `SNOW_LINE`, rivers in steps (rapids, falls), deltas, caves (`_tunnels`). `WorldGen` extends it and writes the cells: three stages per chunk, `TERRAIN` → `PLANTED` (trees, needs TERRAIN on the 3×3 around) → `SHAPED` (slopes, corners, bushes; needs PLANTED around), stepped a row or a tree at a time through `start`/`step` jobs; the result does not depend on the order chunks are made in (tested); unedited chunks beyond `DROP_RANGE` are forgotten (`forget`) and made again the same |
| `world_store.gd`, `save_game.gd` | one folder per world under `user://saves`: `world.json`, players, only the changed chunks (`WorldGen.pack`), map regions; modules keep their part of the player with `save.track(name, obj)` (`to_dict`/`from_dict`); autosave; a saved chunk comes back SHAPED |
| `chunk_streamer.gd` | generates and meshes chunks within `LOAD_RANGE`, frees beyond `UNLOAD_RANGE`; per-frame budgets (edits, then far chunks, then caps); the level cut and `_hiding_level`; `refit_boxes` per view |
| `chunk_mesher.gd`, `foliage.gd`, `mesh_buffers.gd` | the chunk meshes built a column at a time: cells, cut corners and caps (`build_cap`); the parts it calls per column extend `mesh_faces.gd` (the face tables, packed words and drawing primitives): `slope_mesher.gd` (slopes, `patch`), `water_mesher.gd` (surface, shore, falls), `trunk_mesher.gd` (bark); plants and crowns |
| `pixel_view.gd`, `camera_rig.gd` | the low-res picture and the oblique 3/4 view: `shear(pos)`, `view_ray`, `set_view(turn, tilt)`, `world_dir` / `screen_dir`, safe rect; the camera turns in 45° steps and tilts two steps each way (wall 4..12 px under an 8 px top) |
| `sky.gd`, `effects.gd`, `fire_shadows.gd` | light, colour grade, sun rays, ground fog, puddles, weather drawn for `game.clock`; `light_side` (one of eight, with a margin); particles, fires, the torch; fire shadows drawn on the ground |
| `clock.gd`, `real_weather.gd` | time of day, seasons, moon, the `WEATHERS` table, wind side, leaf fall; or the device's time and the real weather by IP + Open-Meteo |
| `controls.gd`, `cursor.gd`, `gathering.gd` | keys, mouse, touch; `hands` (an item in each hand, `active` the one in use), the hotbar (the bag's first `Inventory.HOTBAR` slots), brushes and strokes, the action button in front; what a tap gathers and its hint; the frame round the cells an action works on |
| `world_actions.gd`, `tools.gd` | what the hands do to the world: dig, build, chop, gather, plant, mow; each tool's rules |
| `body.gd`, `player.gd`, `figure.gd`, `hands.gd` | walking, jumping, swimming, snow, wind, trails; the player's sprite assembled from `content/core/sprites/` by `player.yaml` (layers, `hands.png` anchors, a sheet per held tool or the item's icon), built a part of a row a frame; `player.work` starts a swing |
| `character.gd` (shared + client) | the bag (`Inventory`) and the body's state (`Vitals`), action costs, eating, what a life did, death (the bag in a sack, the character lies dead until `death_screen.gd` respawns them) and the player's place, hands and screen on the client |
| `placed.gd`, `props.gd`, `voxel_props.gd` | things on 2×2 cells by their item's `prop` role: chests and their contents, workbenches, kilns, campfires (solid through `WorldData.blockers`), the drops on the ground; their voxel models read from `content/<mod>/models/<model>.png` (`VoxelModel.from_image`), only the block clod, the sack and the bundle made in code |
| `workshop.gd`, `crafting.gd`, `knowledge.gd`, `craft_queue.gd` | recipes known, the queue worked near its station, tool wear and repair (`game.workshop`); the window is `craft_panel.gd` |
| `wildlife.gd`, `creatures.gd`, `ai_rules.gd` | animals from their properties: come, wander, rest, flee, hunt; flocks follow their lead, flyers roost in crowns; drawn by `creatures.gd` |
| `minimap.gd`, `map_view.gd`, `markers.gd` | the map painted per chunk into regions of 32 chunks kept in the save (`map_ground.gdshader`); the full-screen map; the player's markers (teleport from the playtest page) |
| `main_menu.gd`, `world_setup.gd`, `world_list.gd` | the first screen over the live world of the saved seed; «Новый мир»; `main.restart()` reloads the scene; tests and tools set `main.skip_setup` |
| `settings.gd`, `settings_menu.gd` | saved settings and playtest switches (every module reads its values there); the pages of rows "name ‹ value ›" |
| `hud.gd`, `inventory_window.gd`, `ui_style.gd` and the rest of `ui/` | the HUD, the bag and craft window, menus, panels, the freeze log (`freeze_log.gd`, `gl_watch.gd`, `perf_panel.gd`) |
| `sound.gd`, `nature.gd`, `steps.gd`, `voices.gd`, `music.gd` | buses, volumes, the ear at the player turned with the camera, loops and spots, the animals' voices, music as scheduled notes |
| `shader_warmup.gd`, `draw_census.gd` | one of each kind of thing drawn under every mix of lights as the game starts; draw calls counted by what is drawn |

## Content

`content/<mod>/` holds the game data: `mod.yaml` and `data/<kind>.yaml` (materials, items, creatures,
trees, bushes, recipes, plants, sounds), lists of records with namespaced ids (`core:grass`), or, when the
mod is split, a folder per bundle (`content/animals/wolf/`: `bundle.yaml` with its title, then the same
`data/`, `sprites/`, `sounds/`... inside; `content/<mod>/common/` holds assets the bundles share,
`Content.asset` looks in the bundle, then there). A bundle is what the player switches on and off (ids
`animals/wolf`; a mod without bundle folders is one bundle named by the mod); the records keep the mod's
namespace (`animals:wolf`) and get `mod` and `bundle` fields. `src/shared/content/content.gd` reads and
checks them against its schemas; `tools/validate.gd` runs the same checks in CI, and that every recipe can
be made from what the world gives. The registries fill their static vars when their class loads, so code
keeps using `Mat.GRASS`, `Trees.OAK`, `AiRules.SPECIES`. New numbers that describe content go into the YAML
and the schema, not into constants. A bundle's dependencies follow from its references: a record that
names one owned by another bundle needs that bundle (`Content.deps`, `closure`), unless the schema marks
the field `soft` (a tree's `seed`, a bush's `fruit`, a creature's `likes`, a plant's `gives`, an item's
`repair`, a material's `bonus` and `mow_gives`): then the reference is dropped when its owner is off and
the game does without (`Content.strict` in the validator still reports it for the full set). `requires`
and `wants` in `mod.yaml` or `bundle.yaml` add to that; `resolve` orders a set (core first) and drops a
bundle whose hard dependency is missing (`Content.dropped[b]` names it; the setup screen shows «нужен X»).
A later record with the same id replaces an earlier one, `patch: true` changes only the fields given
(`field+` adds to a list); a patch of a record whose bundle is off is skipped. A world remembers its
bundles (`mods` in `world.json`, older lists expanded by `Mods.expand`), a new one takes the set switched
on at «Новый мир» (page «Моды», a row per mod, its own page per bundle); `mods.gd` activates a set and
refreshes every registry (material numbers follow the load order, so a world's set must not change; the
button to reread the data calls `Mods.rescan`, not `reload`, which `Script.reload` shadows). The engine asks for content by role, never by
id: a tree by its `land` (`Trees.pick`), a bush by what it grows `under` (`Bushes.pick`), a plant by its `kind`
(`Plants.of_kind`, "" when no mod gives one, and that kind does not grow), a station by its `prop`
(`Items.with_prop`), a tool by its `tool`, a cell material by its `role` (`Mat.BEACH`, `Mat.BANK`, `Mat.SCREE`,
`Mat.ORE`, `Mat.LOG`, `Mat.LEAVES`: -1 when no mod gives one, the generator lays dirt or stone instead, trees
need `trunk` and `crown`), fuel for a fire by `fuel` (`Items.fuel_in`), what a tree or bush gives by its
`log`, `twig`, `seed`, `fruit` fields (soft refs, "" gives nothing); the only ids code names are core's (`Mat.GRASS`,
`Placed.CAMPFIRE`). Core keeps only air, stone, water, dirt and grass (`Mat.KNOWN`), the campfire and the player;
the base items are `content/resources/` (wood, stone, soil, fiber bundles: log, branch, stone, flint, dirt, sand, clay,
fiber, with the scree, sand and clay cells) and `content/materials/` (copper, cord, planks, brick); tools' and plants'
cells live with them (planks and brick with materials, log and leaves with plants). Saves from before name the old
ids: `Items.canon`, `Crafting.canon` and `Mat.RENAMED` translate them as they load. How a material is drawn is data too: `priority`, `ground`, `drains` make `Mat.shader_bits`, uploaded to
`world.gdshader` as `material_bits`; its texture is `textures/<id>.png` of its mod (48×16: top, sides, underside;
`Mat.texture_path`, atlas by `PixelTextures`, whose average colour `tint` paints the maps and particles), drawn by
`tools/art/texture_art.gd` and written by `tools/make_textures.gd`. A world saves its material list (`materials` in
`world.json`) and `Mat.remap` translates the cells of an older one. A thing's voxel model is `models/<model>.png` of its mod, a row of square slices one
per level (alpha 128 marks a leaf), read by `VoxelModel.from_image`; its picture in the bag is `icons/<icon>.png`
(12×12, `ItemIcons`), the interface's own pictures are `assets/ui/`. `content/animals/sparrow/` (see its README) is a
creature added by data and a picture alone: a species' picture is `sprites/creatures/<sprite>.png` of
its bundle, a row of `frames` frames, and its behaviour comes from its properties (`flies`, `flock`,
`roost`, `likes`, mass, diet). Sounds are records of the `sounds` kind with files in
the `sounds/` of their bundle (`<name>.wav` or `<name>_N.wav` per variant), made by `tools/make_sounds.gd`
from `tools/sound/synth.gd`; code asks for a sound by its bare name (`play("chop")`, `Sound.resolve`: the
last loaded mod's record of that name, silence when none), a material's `step` and `hit` (patched onto
core's materials by the sounds mod), a creature's `calls` and `alarm` (its own mod's records) say who sounds. The player's pictures, the models and the icons were drawn by `tools/art/` and saved by
`tools/make_sprites.gd`, `tools/make_models.gd` and `tools/make_icons.gd`; they can be painted over by hand. Design: `plan/architecture/modding.md`.

## Rendering rules

New 3D shaders include `shaders/common.gdshaderinc` and shear VERTEX like the others (oblique 3/4
view: `z -= y` in the default view, the camera looks straight down); lights go at
`PixelView.shear(pos)`, picking uses `PixelView.view_ray`. With the camera turned or tilted the shear
runs up the image (`view_up`, `view_slope`, `view_squash` globals); upright quads face the camera
through `face_view` (sprites and plants also through `stand_tall`), the open edges of cells are a light
rim toward the sun or the moon and an outline away from it (`light_side`), texels counted on the screen
use `screen_plane`. Texture maps over the world (roof, heat) wrap every `RoofMap.WRAP` cells
(`wrap_size`). Details: `plan/architecture/rendering.md`.

## Sound rules

Nothing sounds before the first tap or key (`Sound.unlocked`, the browser's autoplay rule); the files
load a few a frame after it. One-off sounds go through `play(id, pos)` (`pos` INF: from no place) or
`play_later`, loops through `loop` (everywhere) and `spot` (from a place); the world round the player
is looked at every `Sound.TICK`, not every frame. Web export plays samples (no AudioStreamGenerator),
so music is notes scheduled by `music.gd`; each sample playing makes garbage for the page (patched by
`tools/web_patch.py` after the export), so keep the loops few.

## Performance rule

Nothing map-sized or chunk-sized runs in one frame. Chunk meshes and plants are built a column of
cells at a time through `ChunkMesher` / `Foliage` jobs, chunks are generated a row at a time through
`WorldGen` jobs, all run by `chunk_streamer.gd` within per-frame budgets. `tests/frame_test.gd`
enforces this. The phone browser is about 10× slower than a desktop in GDScript; CI renders in
software, so its FPS means nothing, only the user's phone numbers count (stats panel, F3). Notes:
`plan/architecture/performance.md`.

## Version and changes

The client's version is `<stage>.<PR>`: the stage is `application/config/version` in `project.godot`
(raised by hand when an MVP stage closes or the code is reshaped), the PR is the last one merged into main (`0.1.67` has
PR #67 in it). CI writes it with `tools/build_info.py` into `build_info.json` (not in git; a local run
shows `dev`), along with the lines `Что нового [вид]: …` from the descriptions of the last merged PRs;
«Тестирование» shows the version and opens them («Что нового»). So every PR description has at least
one such line in Russian, for a player, not a programmer. The kinds: `новое` (the default), `улучшено`,
`исправлено`, `оптимизировано`, `ядро` (code moved, tools, tests); a PR that does several things has
a line for each, e.g. `Что нового [исправлено]: Костёр больше не гаснет под крышей.`

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
`user://` (`XDG_DATA_HOME`), then `frame_test` alone, since it measures frame times (`GODOT=path` if
`godot` is not on PATH; names as arguments run only those). `frame_test.gd` plays scenarios headless
and fails when chunk-sized work lands in one frame; its timings are noisy on a busy machine, rerun it
alone before blaming code. `progress_test.gd` starts a new world with an empty bag and plays the way
to every recipe through the game's own calls; run it after any change to tools, materials, stations,
recipes or what the hands do. Run `--import` again after pulling new assets (fonts, textures), or HUD
scripts fail with null errors that look like code bugs. Wrap headless runs in `timeout`: a runtime
error in an awaiting script leaves Godot running. `--check-only --script res://x.gd` only parses.

CI (`.github/workflows/build.yml`) runs its jobs side by side: the tests, `frame_test` alone, the
web export, then `tests/browser_smoke.mjs` in headless Chrome as a desktop and as a phone (DPR 3,
touch); it fails on SCRIPT ERROR / Parse Error and prints load timings and a screenshot. On a PR the
browser test runs only when the PR touches what the browser may show differently (the `web` pattern
in the `changes` job) or has the label `smoke`; on main it always runs, and Pages are published only
when every job passed. A software-WebGL frame takes a second or more and each input event waits for
one, so keep the smoke test's events few.

Tools: screenshots without a GPU with `xvfb-run -a -s "-screen 0 1280x720x24" godot --path .
--rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot.gd -- <dir> [shot names]`
(slow, run in the background; the shots are the table in `tools/shot/shots.gd`, the spots and scenes they
stand in `tools/shot/places.gd`; shots share one world per run, so a shot that edits cells restores
them; `ground-*` shots use the test world). `tools/map.gd` draws the land around the spawn from above;
`tools/bench_*.gd` time generation, meshing and edits; `tools/profile.gd` times each module of a frame
headless and counts draw calls under xvfb (`-- spikes` times one-off actions); `tools/make_icon.py`
draws the icon and `assets/web/` (home screen icon, link preview; the `og:` tags are in
`html/head_include`).

## Gotchas

- A static func named like a method of `Script` (`reload`, `get_class`, `is_tool`...) is shadowed:
  `Mat.reload()` recompiles the script and resets its static vars instead of calling yours.
- A lambda that uses `self` keeps the object alive; connected to a signal of something the object
  holds (its bag, its queue) it makes a cycle a RefCounted is never freed from, with all it refers
  to (the world). Connect a method instead (see `src/shared/game/character.gd`).
- `var i := expr` is a parse error when `expr` is a Variant (a field of an untyped object); type such
  vars explicitly. `typed_array = expr if c else []` is a runtime error that silently aborts the
  function in game. Never use -1 as a "none" sentinel for world coordinates: negative ones are real.
- Tests of time-based behaviour wait by `Time.get_ticks_msec`, not frames: CI frames are very fast.
  A per-frame flag computed before a state-changing update is stale in that frame.
- Godot front faces wind clockwise; a hand-built mesh wound counter-clockwise is inside out.
- MultiMesh instance data is half float on GLES3/web: put new per-instance data in COLOR, not in a
  packed int. Vertex COLOR is 8-bit and clamps above 1. Packed float words must stay below 2^23 or
  `int(x + 0.5)` rounds to even: no flag bits above 256. `instance uniform` reads 0 in the web build.
- Phone GPUs flip pixels whose centres lie exactly on texel edges or geometry lines: `floor(world_pos
  * TEXELS)` on non-axis faces needs a sub-texel bias, geometry edges on the pixel-centre lattice need
  an overlap (`ChunkMesher.EPS`), walls under 1 px tall rasterize as flickering dashes. Headless shows
  none of it: render with ±eps nudges and diff the shots.
- Nodes scaled 1/16 (voxel models) need `extra_cull_margin` × 16 or the shear culls them.
- Silhouettes behind geometry use `render_mode depth_test_inverted`; the player's skips pixels the
  stencil marks low (1: grass, bushes, low props; tall world and crowns write 2).
- A light with shadows is drawn in a pass of its own and added in sRGB, not in linear light: it looks
  brighter over other light. Fires and the torch scale their energy for it (`Effects.SHADOW_ENERGY`)
  and cast shadows only at night; which things cast from which light goes by render layers
  (`PixelView.LAYER_*`, `shadow_caster_mask`). An omni light's dual-paraboloid shadow casts nothing in
  Compatibility; a cube shadow plus its pass cost ~+400 draw calls, so by default ("mixed") the nearest
  fire casts a real shadow from the player alone and the rest are drawn on the ground
  (`fire_shadows.gd`). `toon_light` must return 0 where ATTENUATION is 0, or the rings light whole chunks.
- Compatibility lights each mesh with at most `rendering/limits/opengl/max_lights_per_object` omni
  lights (32 here): a chunk mesh is one object, so past the cap neighbouring chunks are lit by
  different lights.
- The first draw of a material under a mix of lights it was not drawn under before compiles shaders:
  100 ms and more on a phone, 10 s under software GL. `shader_warmup.gd` draws one of each kind of
  thing under every mix once the world is ready; a new kind of light or a material that shows up only
  later goes there (the HUD is hidden behind the menu meanwhile, so interface items go on the world's
  canvas). `MESA_SHADER_DUMP_PATH=dir` (with `MESA_SHADER_CACHE_DISABLE=true`) under xvfb writes every
  shader compiled. Freezes on the device are listed with what happened in their frame in «Отладка» →
  «Журнал фризов» (`freeze_log.gd`, `gl_watch.gd`: the game's parts, the engine, the drawing, the
  browser's page and garbage collection, shader programs built, data sent to the GPU). A JS snippet run
  from GDScript must be strict and must not touch `arguments` in a wrapper with named params: that
  makes an object per call.
- Audio buses live in `default_bus_layout.tres`: the web export copies the buses at start, so a bus
  added by `AudioServer.add_bus` later is silent in the browser. The engine's web player loops a sound
  by starting it again when it ends, late; `tools/web_patch.py` makes the source node loop by itself
  and stops the engine copying the whole sample per play. Re-check the patch on an engine upgrade.
- `world.gdshader` reads `material_bits[]` per material (`Mat.shader_bits`, set by `main.gd`); its size is a
  shader constant, raise it when the mods together pass it (magenta patches otherwise).
- Web touch: a moving finger also arrives as a real `InputEventMouseMotion`; `controls.input` treats
  mouse motion as a mouse only with no finger down and more than 1 s after the last touch. The
  joystick and `TouchButton` follow their own touch index so two thumbs work at once.
- `tools/shot.gd` and `tools/profile.gd` save `user://settings.cfg`, which breaks a later local
  `frame_test`: delete it first.
