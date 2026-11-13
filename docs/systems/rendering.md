# The picture: projection, camera, light, shaders

Status: ACTIVE. A Russian copy: [rendering_RU.md](rendering_RU.md).

**Purpose.** Low resolution without smoothing (a texel = a pixel, the scale a whole number), an exact oblique
3/4 projection, light and colour correction by the world's clock, fires and shadows, particles, sprites,
voxel models of things.

**Files**
- `src/client/view/pixel_view.gd` — the low-resolution picture and the 3/4 view: `shear(pos)`, `view_ray`,
  `set_view(turn, tilt)`, `world_dir` / `screen_dir`, `light_range`, the safe area, layers (`LAYER_*`).
- `src/client/view/camera_rig.gd` — SubViewport and the camera: a turn by steps of 45° (holding turns it
  smoothly, releasing brings it to a step), a tilt by steps `TILT_STEP`: `STEEPER` (3) up and `LOWER` (4)
  down, a cell's wall 2..16 px at a top of 8 px (decision 150). The arrows and the keys `[` `]` turn the world
  towards the arrow. Left alone for `IDLE_TIME` (a minute: no key, tap or mouse, the player standing;
  `wake` from `main.gd`'s `_input`) the view itself slowly circles round the player (`drift_rate`, up to
  `DRIFT_RATE`, a turn in 1.5 minutes); any input brings it to the nearest step. Without sleep
  (`Vitals.SLEEPY`) the picture swims instead (`drowsiness` → `sway` of `grade.gdshader`: waves, a faint
  second image, darkening edges). After a glowing mushroom (`Vitals.visions`) it swims harder still
  (`visions` → `trip`: stronger waves and rings from the middle, the picture breathing, red and blue split
  apart, a colour-turned second image, colours running round the wheel, teal and violet edges; fades over
  the last `TRIP_FADE` seconds).
- `src/client/view/auto_quality.gd` — «Quality → Auto» (Graphics, on by default; a preset saved before it
  becomes Auto, a mix of one's own stays): Main calls `update` every frame of the game, it counts the frames on
  the clock in windows of 5 s (not the loading, the shader warm-up, the menu, the death screen, frames over
  250 ms, nor a game the tests and tools run: Main not the current scene) and moves the graphics settings
  along `STEPS` (high → fires' real shadows → sun rays → shadows on things (= medium) → ground fog → pixel
  1.25 → 1.5 → sun shadows → effects (= low)): two windows below 28 FPS (80 % of the cap if lower) a step
  down, a minute at 50 FPS (90 % of the screen rate or the FPS limit if lower) a try up; a slow window in the
  next 20 s takes the try back and sets `auto_ceiling`. Each step is told by a toast and in the F3 panel's
  full view. Any graphics setting by hand (`Settings.set_value`, a preset) turns it off.
- `src/client/view/crt.gd` — the setting «CRT» (Graphics): off, soft, old, cassette (`LOOKS`). The old screen
  is counted in the colour-correction pass (`grade.gdshader`, the parameters `crt_*`) by the screen's pixels
  (the shifts — by the screen's long side, the bend — by the diagonal, the mask's stripes are wider on a dense
  screen, so in portrait and in landscape it is the same), it has no pass of its own: scan lines with
  interlacing, the glow of bright pixels (8 samples of the world's picture with linear filtering,
  `crt_view`), split channels, the tube's curvature, a vignette, flicker, an aperture grille; the «old» one
  also has a rolling light band, the «cassette» — a jitter of lines, colour blurred along a line, a band of
  interference at the bottom and noise. The interface on top stays sharp. The picture's position on the
  screen for the curvature is given by `CameraRig.update` every frame (`Crt.frame`).
- `src/client/view/sky.gd` — light, colour correction, ground fog, puddles, weather on screen for
  `game.clock`; `light_side` (one of eight sides, with a margin).
- `src/client/view/effects.gd` — particles, campfires, the torch (an item with `light` in the hand, otherwise
  a weak glow). The light of a torch/lantern in the hand stands at the height of its flame
  (`Player.torch_height`, no higher than `HAND_TOP` 0.75 units), so that in a house two cells high it burns
  under the roof, not in it, and at the side of the hand that holds it (`Player.torch_side`, `torch_offset`;
  the drawn shadows go by it too). Rain is carried by the wind (`Effects.rain_lean`: in a storm the drops fly
  sideways farther than they fall), and the strokes of drops are tilted along the fall (`lean` in
  `particle.gdshader`). Under snow the grass at the joint with a torn-out cell spreads into it by separate
  texels (`GRASS_FRAY` in `world.gdshader`), with no white squares.
- `src/client/view/fire_shadows.gd` — the shadows from fire drawn on the ground; `sun_rays.gd` — rays among
  trees, glints, dust. The light of each tree is counted once per position of the sun (anew when the sun has
  turned by `TURN`) and several trees per frame within `WORK_US`; at a player's step by `MOVE` the ready light
  is only laid out anew. Before, everything was counted whole in a frame and in a forest gave «engine» freezes
  of 100–200 ms on a phone. The time goes into the log as the part «rays».
- `src/client/view/pixel_textures.gd` — the atlas of materials from the mods' textures, bark as virtual
  materials after the real ones, grass, shrubs, cloud noise; `tint` — the mean colour for maps and particles.
- `src/client/view/voxel_model.gd`, `voxel_props.gd` — the voxel models of things from
  `content/<mod>/models/<model>.png` (`VoxelModel.from_image`), in the code only a lump of a block, a sack and
  a bundle.
- `src/client/view/player.gd`, `figure.gd`, `hands.gd`, `sprite_sheet.gd` — the player's sprite (see
  [character.md](character.md)).
- `src/client/view/shader_warmup.gd` — the shader warm-up; `draw_census.gd` — the count of draw calls.
- `src/client/view/cave_layers.gd` — the cave view by layers for choosing cells (the same as the shaders
  hide), `src/client/world/solid_map.gd` — the map of solid cells around the player for the slice of rock
  with which the layers fill what is removed; `plan_view.gd` — the blueprint's ghost
  ([interaction.md](interaction.md)); `land_view.gd` — the borders of plots ([territory.md](territory.md)).
- `shaders/` — `common.gdshaderinc` (the shear, light, the roof, the slice, layers, shared functions),
  `world`, `water`, `grass`, `leaves`, `leaf_shadow` (the discs of crowns' shadow lie flat, a shrub's disc
  stands, turned to the light, like a sprite's shadow, so that its shadow at sunset begins at the shrub; a
  shrub drops its leaves and the shadow whole, by the world's column, and its back tufts are not moved back
  as in a crown, otherwise the shrub hangs over its shadow), `sprite`, `sprite_water`, `sprite_xray`,
  `particle`, `track`, `fire_shadow`, `sun_rays`, `grade` (colour correction), `map_ground` (the map),
  `cursor` (and the blueprint's ghost), `land` (the plots' borders).
- `project.godot`, the section `[shader_globals]`: the global parameters the code changes (`cut_height`,
  `snow_amount`, `wind`, `view_up`, `view_slope`, `rest_view`, `view_squash`, `light_side`, `wrap_size` and
  others).

**Rules**
- A new 3D shader includes `shaders/common.gdshaderinc` and shears VERTEX like the others (in the default view
  `z -= y`, the camera looks straight down); fires are placed at `PixelView.shear(pos)`, the choice of a cell
  — through `PixelView.view_ray`. Its colour hints are `SRGB` (`uniform vec3 c SRGB = …`) or `SRGB_HINT` after other
  hints (`: filter_nearest SRGB_HINT`), never `source_color`, and its fragment() ends with `COMPAT_ALBEDO` (or
  `COMPAT_COLORS` if it sets EMISSION): on Android the Mobile renderer (Vulkan) draws, which takes colours as linear,
  and these make it see them as Compatibility does ([android.md](android.md)).
- With a turn and a tilt the shear goes up the picture (the globals `view_up`, `view_slope`, `view_squash`);
  vertical squares look into the camera through `face_view` (sprites and plants also through `stand_tall`);
  the open edges of cells are a light rim towards the sun or moon and an outline away from it (`light_side`);
  the texels on screen are counted through `screen_plane`.
- The texture maps over the world (the roof, heat, biomes) wrap every `RoofMap.WRAP` cells (`wrap_size`).
- The colour of soil and water by biome (white sand, the turquoise water of the tropics, the yellow grass of a
  savanna) is `biome_tint(mat, xz)` in `common.gdshaderinc`: the column's biome from `biome_map`, the
  multiplier from `biome_tints` (a texel material × biome, in linear colour, divided by 4); at a border of
  biomes the column is taken with a random shift of a texel, so the colours pass by dithering. It is called by
  `world` (tiles), `grass` (blades) and `water`.
- A bevel (flag 4) lays the tile by the screen's texels (`rest_plane`), and the patterns of soil (patches,
  specks, bald spots, the biome's tint, snow) — by `gp` in `world.gdshader`: a world point shifted up the
  picture by the height above the level line under it. So on a bevel towards the camera the patterns are not
  stretched into stripes and stay a pixel to a texel; on every level line they jump, and the seam is hidden
  by a shadow by dithering towards the foot of each level — by it one also sees how many levels there are in a
  bevel. The shots: `steep-beach`, `steep-tropical`. «The screen» here is the view of the step at which the
  camera stands or to which it is nearest (the global `rest_view`, set by `PixelView.set_view`; `rest_plane`
  in `common.gdshaderinc`), not the shown one: while the camera turns or tilts between steps, the tile, the
  patterns and the shadow at the foot of the levels hold on the slope and do not crawl over it (before, they
  crawled); in the middle between steps the pattern jumps once to the view of the next step.
- Depth darkens from the sea's surface (the globals `sea_top` and `depth_steps.x`, «Darkening per level» on
  the page «Caves», 12 %): each level below the sea gets that much less of the sun's and sky's light, down to
  full black (`sea_bright` in `common.gdshaderinc`), in caves and in the sea's depth; the colour is dark, and
  the light of torches and campfires rises back (`lamp_gain` from `sea_undo` in `light()`), so below one sees
  only what they light. Compatibility counts ALBEDO as an sRGB colour and converts it into linear (Godot's
  polynomial `srgb_to_linear`), so a simple division by `sea_bright` does not return the brightness:
  `sea_undo` counts the multiplier through the same polynomial. There is no tick below the feet any more. A
  torch in the hand, campfires and placed fires burn the brighter the darker it is around (`Sky.lamp_gain`):
  the light around is `sky_light` multiplied by `Sky._sea_bright` in linear form (the power 2.2, as the colour
  darkens); by day there is no torch, and campfires and fires at `Effects.DAY_LAMP`, towards dusk
  (`DUSK_LIGHT` → `FULL_LIGHT`) full strength, towards full darkness (a moonless night, the depth of a cave)
  up to `DARK_GAIN` times brighter; under a roof no less than at dusk, so with depth the light only grows.
  «Under a roof» for the player is any roof overhead, however high the vault (`ChunkStreamer.indoor`), for
  campfires and fires — `WorldCells.roof_level` above their cell. A torch and a placed fire dim as they burn
  down (`Sky.charge_gain`, to the end `BURNT_GAIN`), a campfire — by the remaining fuel (`Effects`
  `fire.base`).
- The slice of levels (`cut_height`, set by `ChunkStreamer.update_cut` at once, without delay) is only the one
  chosen by the level buttons (`manual_level`): the levels above it melt as a ghost, a step per level, and
  darker (`cut_dither`, `depth_fade`), around the player a clean window with an edge melting by dithering
  (`WINDOW_IN`..`WINDOW_OUT`). The shaders hide only through the shared functions of `common.gdshaderinc`:
  `above_cut` / `cut_hides` and `gone_above` (small things: grass, particles, rays — by the same ghost as the
  ground: the slice removes nothing from the surface).
- The cave view is one — layers (`src/client/view/cave_layers.gd`; decision 168: the «slice of levels», the
  «cut by the camera» and the «sphere» were removed together with the setting «Cave view» `cave_mode`, saved
  old values are not read, everyone has layers). Where an automatic slice would cut the view (under a roof;
  where the ground hides the player's body from the camera: in a pit, in a ravine across the gaze or slantwise
  to it (the far wall is looked for behind the player straight and at both diagonals), behind a sheer wall; but not in a gorge along the gaze, where walls at the sides hide nothing), nothing is cut:
  `ChunkStreamer.update_cut` turns on the global `layer_view` (on and the cell of the player's feet), and
  `cut_hides` / `gone_above` hide by dithering (`layer_alpha`, `bayer4` by the texels of the screen's plane)
  only a quarter of the view at the side: what is before the player and not below the line (`layer_line` of
  levels above the feet: 0 feet, +1 belt, +2 head) — by vertical slices of a cell across the camera's gaze
  and by levels from the line upward, the lesser is taken; behind the player (and the ceiling above them) and
  below the line everything is seen. The first layers are drawn with the density `layer_density`, the next
  melt by the «stretch» of layers (`layer_fade`: x, y — the slices ahead, z, w — the levels from above; the
  test settings «Caves», by default the line +2, ahead the first 2 and the stretch 2, from above the first −2
  and the stretch 4, density 100 %, darkening 12 % per level). A face of the world is counted as the cell it
  covers (a point a little inward along the normal). Where the layers removed a face's texel, and behind it
  along the gaze's ray go only solid cells removed at the same texel, up to a solid cell that the layers leave
  (it has no face there) — instead of a hole into the background a slice of rock is drawn in a dark colour
  (`layer_fills` by `solid_map` — a bit map of 64×64 columns × 32 levels around the player,
  `src/client/world/solid_map.gd`, led by `ChunkStreamer.update_cut` while layers are on; the changed cells go
  into the texture with one `flush` per frame; the colour is one dark one, `SECTION` in `world.gdshader`, a
  little lighter than the background, with no colour of the material; at the edges where the slice ends — the
  material of the cut cell, melting by dithering for `SECTION_RIM` texels, `section_rim`: a cell's edge is
  counted the edge of the slice if the neighbouring cell is open, left by the layers or the gaze's ray from it
  goes out into the void, `layer_fills`). If the ray goes out into the void earlier, the face is removed and
  one sees what is behind it. The background under any slice is the dark colour of the slice of rock
  (`sky.gd`). The «first layers» can be less than zero too (`CaveLayers.FIRSTS` from −4): then the layers
  begin to melt earlier than the first. The choice of cells passes through the cells drawn at less than
  `Controls.PICK_SHARE` (`CaveLayers.share`, `VoxelRaycast.cast(..., skip)`).

**Pitfalls**
- Phone GPUs flip pixels whose centres lie exactly on the edges of texels or lines of geometry:
  `floor(world_pos * TEXELS)` on non-axial faces needs a shift by a part of a texel; headless does not see it
  — render with ±eps and compare the shots.
- Nodes scaled 1/16 (voxel models) need `extra_cull_margin` × 16, otherwise the shear culls them.
- Silhouettes behind geometry are `render_mode depth_test_inverted`; the player's silhouette is seen only
  where the stencil marks solid (1: the world, sprites) or nothing (0), not low (2: grass, shrubs, low
  things) and not crowns (3: they are cleared around the player); a trunk is cleared above the player, except
  the butt (the faces' vertex alpha says which cell of the trunk it is).
- Light with shadows is drawn by a separate pass and added in sRGB, not in linear light: on top of other
  light it is brighter. Fires and the torch scale the energy (`Effects.SHADOW_ENERGY`) and give shadows only
  at night; what casts a shadow from which light is decided by the layers (`PixelView.LAYER_*`,
  `shadow_caster_mask`). The shadow of a point light dual-paraboloid does not work in Compatibility; a cube
  shadow with a pass costs ~+400 draw calls, so by default («mixed») a real shadow is given by the nearest
  fire and only from the player, the others are drawn on the ground (`fire_shadows.gd`). The drawn shadows
  are counted by the map of cells around each fire (`FireShadows._maps`): blocks and placed things
  (`WorldData.blockers`) hold the light for the thing's whole height (a door of two or three cells), windows
  (`Placed.lets_light`, an item with `window`) let it through; an open door is not solid and lets light
  through, and the maps are redone when it opens and closes (`Placed.opened`). So the campfires, the torch in
  the hand and the placed fires (lanterns, candles, `Effects.lamps`, those that shine now) are counted: they
  never have a real shadow, and without a map their light went through walls. The fire's shadows from trunks
  are remembered by chunk and dropped when a trunk is felled: a felled tree stays in `WorldData.trees` (a
  stump), so the key includes the log columns of trees too (`_fire_trunks`, `_standing`). A window casts no
  shadow either from the sun and moon or from fires with a real shadow (`Props`, `cast_shadow` off).
  `toon_light` must return 0 where ATTENUATION is 0, otherwise rings light whole chunks. Light falling almost
  along a face (the cosine below `LIGHT_GRAZE` 0.05: a lantern in a pit a little above its edge) is counted
  the farther the flatter it is, and fades in rings with dithering; before, such a face was lit by an even
  disc with a sharp edge (the shot `ground-lantern-pit`). `shadow_enabled`, `omni_range` and
  `shadow_caster_mask` of fires and the torch are written only on a change (`Sky._update_torch`,
  `Effects.pick_shadow_fires`): each write re-links the light and marks its cube shadow for redrawing;
  `light_energy` may be written every frame.
- No more than `rendering/limits/opengl/max_lights_per_object` (32) point fires per object; a chunk's mesh is
  one object.
- A fire or torch with a real shadow itself lights only the ground, the world's walls and grass (the layer
  `PixelView.LAYER_GROUND`: the chunks' meshes, the caps of the layer view, tufts of grass); everything else
  is lit by its twin without a shadow — a child light `Twin` (`PixelView.real_shadow`, `twin_follow`; the
  twin's brightness is as of a fire without a shadow). Light with a shadow draws its own by a separate pass,
  and for each kind of thing the renderer assembled the shaders under it anew: on a phone ~50 programs of
  150–600 ms stopped the game at dusk (2026-11-08). Now there are a few, only for ground, walls and grass (in
  software GL 21.7 → 5.6 s); the fire's shadow does not fall on foliage and trees. Things on the ground
  (placed, lamps, what lies, boats) and beasts stand on the layer `PixelView.LAYER_THINGS`: with the setting
  «Shadow on things» (on by default, `PixelView.shadow_on_things`) light with a shadow lights them too, and
  the player's shadow falls on them; their shaders of the shadow pass are assembled by the warm-up at loading
  (`ShaderWarmup`: the faces `world_mat`/`low_mat` and the player's figure on this layer).
- The first drawing of a material under a new combination of fires compiles shaders: on a phone 100 ms and
  more, in software GL 10 s. `shader_warmup.gd` draws one of each kind under the combinations of fires
  (without fire, fire without a shadow, and fire with a shadow — by the setting of fire shadows, with the
  layers that cast a shadow; everything under the sun with a shadow by the setting; the sun in the game does
  not go out — at night its brightness is 0, but the shaders are the same). All this is behind the loading
  screen (`step`, a combination per frame); behind the menu the world is not drawn, so nothing is left for the
  first frames of the game. In the game (`update`, `main.shaders`) only what the settings asked for (the sun's
  shadow, fire shadows), one kind at a time once per `PACE`. A new kind of fire or a material that appears
  later is added there (the HUD is hidden by the menu at that time, so the interface's elements are on the
  world's canvas). Without the menu (`skip_setup`) the world is drawn during loading, and the warm-up is
  shorter. `update` does not go while `step` goes: until 2026-11-08 with the menu open it went alongside,
  turned the hidden kind into «draw once», and in the browser only the first combination was assembled; the
  rest (without fire, fire's shadow) were assembled in the game — the first camera turn by day cost 140–440 ms
  on a phone. Without the menu (tests, tools, xvfb) this is not seen: the check is the web build in headless
  Chrome with a wrapper of `linkProgram`. `MESA_SHADER_DUMP_PATH=dir` (with `MESA_SHADER_CACHE_DISABLE=true`)
  under xvfb writes each assembled shader; the engine on PC stores the assembled programs in
  `user://shader_cache` — for a measurement take a clean `XDG_DATA_HOME`.
- The unlit (unshaded: particles, the cursor, the fishing line, tracks, rays, captions) without a shadow of
  its own is moved by `PixelView.unlit` to the layer `LAYER_UNLIT` as soon as it enters the tree
  (`SceneTree.node_added`), and for fires and torches (OmniLight3D) it sets `light_cull_mask = LIT_BY_FIRES`
  without this layer and without the shadow discs under crowns: the light does not change it, but the engine
  assembled its shaders anew under each combination of fires (on 2026-11-06 −10 programs of ~150, a quarter
  of what the warm-up built itself). A new unlit kind with a shadow stays on layer 1.
- `instance uniform` in the web build reads as 0.
- `world.gdshader` reads `material_bits[]` and `corner_shapes[]` by material (`Mat.shader_bits`, set by
  `main.gd`: priority, `DRAINS`, the kind of patches, `TRUNK`, from bit 8 — `fray`, by how many texels the
  joint with a material tears into tatters in both directions, like salt; from bit 11 — `side_fray`, by how
  many texels the material reaches into another on the sides of cells, in lumps and then specks: ore in the
  rock, stone under soil; 0 for built blocks, whose sides stay straight both ways); the size is a constant of the
  shader (63 = `PixelTextures.MOST_MATERIALS`), raise it together with the atlas.
- In the mesh's UV2.x is the number of the material (6 bits, 63 — the vertex's colour), not of the tile: the
  sides' tile is set by bit 1 of the flag, the underside's — by a face looking down (`MeshFaces.pack`); the
  neighbours in UV2.y are materials too: on a top the tops beside, on a wall the cells beside it on its
  plane whose own side shows (above, below, along: `ChunkMesher._side_tiles`). The atlas is 16×12 tiles (`ATLAS_COLUMNS`, `ATLAS_ROWS` in
  `common.gdshaderinc`, `PixelTextures.TILES`, `ROWS`).
- Static variables survive a scene's restart, and another world may load other bundles with other numbering
  of materials: `main._ready` after `Mods.activate` calls `PixelTextures.forget()` and `MeshFaces.forget()`,
  and the atlas is built before `RoofMap.prepare` and the maps (the biomes' tones and the map's colours are
  taken from the atlas's mean colours; with the old ones the sand came out violet).

**Tests.** `tests/unit/view_test.gd` (`pixel_view`, `sprite_sheet`, `tracks`, `hidden`, `camera_spin`, `auto_quality`),
the screenshots `tools/shot.gd` (the table `tools/shot/shots.gd`, the places `tools/shot/places.gd`),
`tools/profile.gd` (draw calls under xvfb), `tests/browser_smoke.mjs`.

**In more detail.** `plan/architecture/rendering.md` (the main document of rendering), `plan/design/visual.md`,
the screenshots by topic in `survivium-builds/`.
