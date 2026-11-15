# Rules of the picture

Part of [The picture](../rendering.md). The rules a change of the picture keeps.

**Rules**
- A new 3D shader includes `shaders/common.gdshaderinc` and shears VERTEX like the others (in the default view
  `z -= y`, the camera looks straight down); fires are placed at `PixelView.shear(pos)`, the choice of a cell
  — through `PixelView.view_ray`. Its colour hints are `SRGB` (`uniform vec3 c SRGB = …`) or `SRGB_HINT` after other
  hints (`: filter_nearest SRGB_HINT`), never `source_color`, and its fragment() ends with `COMPAT_ALBEDO` (or
  `COMPAT_COLORS` if it sets EMISSION, `COMPAT_MUL` if it is `blend_mul`: Mobile halves what a shader gives, so a
  multiply would darken by half more): on Android the Mobile renderer (Vulkan) draws, which takes colours as linear,
  and these make it see them as Compatibility does ([android.md](../android.md)).
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
