# Pitfalls of the picture

Part of [The picture](../rendering.md). What goes wrong on the GPUs, the web and the light.

**Pitfalls**
- A `CPUParticles3D` made with emitting off draws all its `amount` instances from a buffer nothing wrote
  until it first emits: after a scene is made anew (single player, then a server) that memory holds the last
  scene's data, drawn as big coloured wedges and lines. Every emitter goes through `PixelView.blank_particles`
  after its `amount` is set (2026-11-15).
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
  screen (`step`, a combination per frame, each frame marked «warm-up» in the freeze log: in the browser the
  first combination builds ~120 programs and the next three ~11, 9 and 4, checked 2026-11-15); behind the menu the world is not drawn, so nothing is left for the
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
  rock, stone under soil; 0 for built blocks, whose sides stay straight both ways; from bit 14 — `glow` × 15, how
  brightly the material shines by itself: lava and crystals are lit in the dark, `GLOW_GAIN`); the size is a constant of the
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
- Global shader parameters survive a scene's restart too: a module that sends one only when its own state
  changes must send its starting value when made. `ChunkStreamer._init` turns `layer_view` off; left on from
  the last world (the player under a roof there), the new one drew the crowns in front of the player cut away
  and the trunks as the dark rock section (the empty solid map counts as solid, 2026-11-21).

## Gotchas moved from CLAUDE.md

One-line forms of the rules; the detail is above and in the other pages of this system.

- New 3D shaders include `shaders/common.gdshaderinc` and shear VERTEX like the others; lights go at
  `PixelView.shear(pos)`, picking uses `PixelView.view_ray`; colour hints are `SRGB`/`SRGB_HINT`, not
  `source_color`, and fragment() ends with `COMPAT_ALBEDO` (Android draws with Vulkan).
- Godot front faces wind clockwise; a hand-built mesh wound counter-clockwise is inside out.
- A `CPUParticles3D` made not emitting draws garbage from an unwritten buffer till it emits (seen after a
  scene switch): call `PixelView.blank_particles` after setting `amount`.
- MultiMesh instance data is half float on GLES3/web: new per-instance data goes in COLOR. Vertex
  COLOR is 8-bit. Packed float words stay below 2^23, or are read with `round()`, never `+ 0.5`
  (UV2.y of the world mesh reaches 2^24: `+ 0.5` turned an odd material into the next). `instance uniform` reads 0 in the web build.
- Phone GPUs flip pixels on texel edges and geometry lines: bias, overlap (`ChunkMesher.EPS`), no walls
  under 1 px; headless shows none of it.
- Nodes scaled 1/16 (voxel models) need `extra_cull_margin` × 16 or the shear culls them.
- A shader that stands a picture 1/slope taller (`stand_tall`) needs its culling box that much taller for the
  steepest of `box_views` (`TreeSprites.stand_box`); a MultiMesh's box does not follow a later change of its
  mesh's `custom_aabb`, so grow the node's box instead.
- Silhouettes and the player's x-ray go by the stencil values.
- Lights with shadows add in sRGB and cost a pass; Compatibility lights a mesh with at most 32 omni
  lights; `toon_light` returns 0 where ATTENUATION is 0.
- A new kind of light or a material shown only later goes into `shader_warmup.gd`, or its first draw
  compiles shaders mid-game (100 ms+ on a phone).
- The material atlas holds 63 materials and barks together (`PixelTextures.MOST_MATERIALS`,
  `material_bits[63]` in `world.gdshader`): the mesh packs the material in 6 bits, the sides' tile as
  flag bit 1, the underside's by a face looking down (`MeshFaces.pack`); 38 are used (30 materials and
  8 barks).
- Headless runs never compile shaders: a shader error (a varying named like a uniform or a local)
  shows only in a real render (`xvfb-run … --rendering-driver opengl3`) or the browser smoke test.
- Varyings are few on phone GPUs: Godot's Mobile renderer (Android) starts a shader's varyings at slot 14
  and refuses a shader past the GPU's limit, 28 on an Adreno 840 (`Too many varyings used in shader`, in the
  log only). Each varying is a slot (a float as a vec4), light()'s fragment-to-light ones too. `water.gdshader`
  with 16 compiled on the desktop and in the browser but drew the water plain grey on Android (#752; fixed by
  packing it into `swash`); `tree.gdshader` with the felling's 16 drew no tree there (v0.5.912 to v0.5.919),
  then its falling trees' copy no falling tree (to v0.5.929; packed into `fall_tile`). `tools/lint.py` holds
  every 3D shader to `MAX_VARYINGS` (14), all its `#ifdef` variants counted together. Pack a new value into an
  existing varying of the same interpolation instead of adding one.
- Samplers are few in the browser: every sampler a shader declares (its includes' too, used or
  not) takes a texture unit from 0, and the Compatibility renderer keeps the top ones for its own
  (`texunit:-3` in Godot's scene.glsl is the sun's shadow atlas). WebGL has 16 units, so
  `grass.gdshader` with a 14th sampler (`trample_map`, #754) shared unit 13 with the shadow atlas and
  the browser drew no grass at all, while the desktop (32 units) and Android (Vulkan) were fine.
  `tools/lint.py` holds every shader to `MAX_SAMPLERS` (13); declare a sampler only one shader reads
  in that shader, not in `common.gdshaderinc` (`roof_map_soft` is in `world.gdshader`).
- A sprite's sun shadow cast by a card that stands off the drawn one shades the picture itself: grazed by the
  light, points of it a little nearer the light lay a dither over the far half (a wide picture lit from behind
  over its face). Move such a card only along the light (that keeps its shadow on the ground) and below the
  picture: `sprite.gdshader` `lay_flat` lays the card turned by `side_spread` a pixel over the foot. The rows
  once leaned along `view_up` (`lean_shadow`, removed 2026-11-26) lifted the feet's shadow to the shoulders with
  the camera turned east or west. Things drawn as pictures (`Props._add_sprite`, the snowman) set
  `sun_shadow_free`.
- To move where a picture takes the sun's shadow, move `VERTEX` in the vertex and draw it by `POSITION`:
  Compatibility works the shadow's coordinates out in the vertex stage, so `LIGHT_VERTEX` cannot move them
  (and its scene shader of 4.5.1 has no `light_vertex` at all). The lamps light the moved `VERTEX` too
  (their rings by `light_xz`, set before the move): `tree.gdshader`'s crown lean (`CROWN_LEAN`) moves only by
  day, and slides back along the light to the point's own depth, so nothing that stood behind it in the light
  starts shading it.
- A picture that holds data, not colours, is imported with `process/fix_alpha_border` on (every `.import`, not
  committed): in an RGBA8 picture each texel under alpha 20 gets the colour of the nearest texel with more
  within 4 px, and the game (and an exported one) reads the import (`Content.picture`, `Content.live` off). The
  trees' frames lost their bark steps by the leaves so (#881-#888); their codes under 128 are now stored 64
  higher (`frame_code`). Keep a data texel's alpha 20 or more, or use LA8, which the import leaves alone.
