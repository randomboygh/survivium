# Fire shadows, materials, models, shaders

Part of [The picture](../rendering.md). Files: fire and sun shadows, the atlas, voxel models, shaders, shader globals.

- `src/client/view/fire_shadows.gd` — the shadows from fire drawn on the ground; `sun_rays.gd` — rays among
  trees, glints, dust. A shaft starts on the tree's middle plane (upright, through the trunk, across the sun's
  way) inside the crown's outline on it (a spruce's triangle), runs along the sun's light down to the ground
  (`_length`; drawn only where the ground it ends on or its middle shows in the picture, `_seen`, and `HIDDEN_KEPT` of the others, so a thick wood shows a few; which depends on the view, so a camera turn works the light out again), fading away over its lower part, and a fleck of sun lies where it meets the ground (in its crown's shadow, 0.7 of the shaft, crisp and ragged, stretched along the light, breathing with it, only where it shows; no other flecks; specks of dust glint along the shaft, `DUST_SPECKS`; new light never jumps in: it goes into the second of two sets of shafts and flecks and dissolves in texel by texel over `FADE` seconds while the old dissolves out, so a shaft in both stays as it was; the steps of light are dithered by the world's texels, `light_texel`, as `window_glow.gdshader` is, so the dither does not crawl as the camera moves), in bunches of 2–4 through one gap (one wide among narrow ones, bright beside pale), 3 to 13 pixels wide, slowly growing wider and paler and back in the shader; it is drawn at its own depth (lifted only `depth_lift`), so
  the leaves of its crown in front of it and the trees in front hide it: it shows coming out of the crown. `Sky._update_rays` shows them only under a clear sky (`RAYS_CLEAR`) and with the sun at a slant (`RAYS_SUN`, 20–48°, full 26–42°): a higher sun drops them under their own crowns, a lower one lays them along the ground. The light of each tree is counted once per position of the sun (anew when the sun has
  turned by `TURN`) within `WORK_US` a frame, a shaft at a time (`_plan`, `_shaft_step`, `_job_light`: a whole
  tree was 5–11 ms on a phone); `_length` looks along a shaft every `COARSE` units until it comes near the
  height of the tree's foot, then a unit at a time. A tree's light keeps its shafts and flecks as MultiMesh
  buffer data, so laying out copies whole trees whose box shows in the picture; at a player's step by `MOVE`
  the ready light is only laid out anew. Before, everything was counted whole in a frame and in a forest gave «engine» freezes
  of 100–200 ms on a phone. The time goes into the log as the part «rays».
- `src/client/view/pixel_textures.gd` — the atlas of materials from the mods' textures, bark as virtual
  materials after the real ones, grass, shrubs, cloud noise; `tint` — the mean colour for maps and particles.
- `src/client/view/voxel_model.gd`, `voxel_props.gd` — the voxel models of things from
  `content/<mod>/models/<model>.png` (`VoxelModel.from_image`), in the code only a lump of a block, a sack and
  a bundle.
- `src/client/view/player.gd`, `figure.gd`, `hands.gd`, `sprite_sheet.gd` — the player's sprite (see
  [character.md](../character.md)).
- `src/client/view/shader_warmup.gd` — the shader warm-up; `draw_census.gd` — the count of draw calls; `render_toggles.gd` — «Testing» → «Debug» → «What is drawn»: hides a part of the picture (a census group, everything drawn with one shader, the lights, the sun's shadow, fog, glow) until shown again or the world is left, to find which part draws a fault on a device (parts that come later, new chunks, are hidden as they come); its row «environment: background magenta» draws the background magenta (`Sky.magenta`) so a hole in the ground shows bright, also `tools/shot.gd --magenta`.
- `src/client/view/cave_layers.gd` — the cave view by layers for choosing cells (the same as the shaders
  hide), `src/client/world/solid_map.gd` — the map of solid cells around the player for the slice of rock
  with which the layers fill what is removed; `plan_view.gd` — the blueprint's ghost
  ([interaction.md](../interaction.md)); `land_view.gd` — the borders of plots ([territory.md](../territory.md)).
- `shaders/` — `common.gdshaderinc` (the shear, light, the roof, the slice, layers, shared functions),
  `world`, `water`, `grass`, `leaves`, `leaf_shadow` (the discs of crowns' shadow lie flat, a shrub's disc
  stands, turned to the light, like a sprite's shadow, so that its shadow at sunset begins at the shrub; a
  shrub drops its leaves and the shadow whole, by the world's column, and its back tufts are not moved back
  as in a crown, otherwise the shrub hangs over its shadow), `sprite` (people, animals, tumbleweeds; under
  the sun and the moon it casts its shadow as it is drawn, facing the camera, so the light lays the picture
  on the ground skewed, each row moved away from the light by its height, and it falls on slopes and walls
  like any real shadow; lit along the picture's width it leans back, `lean_shadow`, so the shadow is never
  thinner across the view than `LEAN_DEPTH` of the height; a fire's light still finds it turned to face
  the fire), `sprite_water`, `sprite_xray`,
  `particle`, `track`, `fire_shadow`, `sun_rays`, `grade` (colour correction), `map_ground` (the map),
  `cursor` (and the blueprint's ghost), `land` (the plots' borders).
- `project.godot`, the section `[shader_globals]`: the global parameters the code changes (`cut_height`,
  `snow_amount`, `wind`, `view_up`, `view_slope`, `rest_view`, `view_squash`, `light_side`, `wrap_size` and
  others). A global texture is set by `PixelTextures.set_global`, which keeps the one it replaces while
  that scene and the next `HOLD_SCENES` (2) run: Vulkan (Android) drew garbage after a new scene (rejoining a server, reloading mods) when the
  old one was freed at once. A global texture that changes during play is drawn again in place
  (`ImageTexture.update`), never made anew: the fires' heat map (`Effects.heat_map`) once made one for each fire
  that came, several in a row while joining a server with camps.
