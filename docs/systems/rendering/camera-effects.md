# Camera, quality, light and effects

Part of [The picture](../rendering.md). Files: the view, the camera, auto quality, CRT, sky, particles and effects.

**Files**
- `src/client/view/pixel_view.gd` — the low-resolution picture and the 3/4 view: `shear(pos)`, `view_ray`,
  `set_view(turn, tilt)`, `world_dir` / `screen_dir`, `light_range`, the safe area, layers (`LAYER_*`).
- `src/client/view/camera_rig.gd` — SubViewport and the camera: a turn by steps of 45° (holding turns it
  smoothly, releasing brings it to a step), a tilt by steps `TILT_STEP`: `STEEPER` (3) up and `LOWER` (4)
  down, a cell's wall 2..16 px at a top of 8 px (decision 150). The arrows and the keys `[` `]` turn the world
  towards the arrow. Left alone for `IDLE_TIME` (a minute: no key, tap or mouse, the player standing;
  `wake` from `main.gd`'s `_input`) the view itself slowly circles round the player (`drift_rate`, up to
  `DRIFT_RATE`, a turn in 1.5 minutes); any input brings it to the nearest step, and the next minute alone starts it again. Only a real move
  counts: a key or the stick held, the feet `IDLE_SLACK` along the ground from where they stood (not afloat or
  in a vessel), a mouse move of `IDLE_MOUSE` px or more; a body bobbing a hair at a time or a stray mouse event
  used to reset the minute for good. Without sleep
  (`Vitals.SLEEPY`) the picture swims instead (`drowsiness` → `sway` of `grade.gdshader`: waves, a faint
  second image, darkening edges). After a glowing mushroom (`Vitals.visions`) it swims harder still
  (`visions` → `trip`: stronger waves and rings from the middle, the picture breathing, red and blue split
  apart, a colour-turned second image, colours running round the wheel, teal and violet edges; fades over
  the last `TRIP_FADE` seconds).
- Culling boxes (`PixelView.sheared_box`, `box_views`): a node's `custom_aabb` holds what it draws once
  sheared in every view of `box_views`. At rest that is the view shown; on a step's glide the views on the way
  (`BOX_STEP` apart); while the turn is held or the view drifts, only `SPIN_AHEAD` (45°) ahead, fitted again
  (`_spin_on`) once the view gets there. Boxes for the whole way round grew each chunk's by its heights'
  shear all round (ground at 12–20 units): 356 chunk parts in view instead of 91 (134 with the window), twice
  the draw calls in the phone's browser. An animal's sprite is fitted again only when its height changes by
  `Creatures.FIT_SLACK` (the shear moves a box by its height alone).
- `src/client/view/auto_quality.gd` — «Quality → Auto» (Graphics, on by default; a preset saved before it
  becomes Auto, a mix of one's own stays): Main calls `update` every frame of the game, it counts the frames on
  the clock in windows of 5 s (not the loading, the shader warm-up, the menu, the death screen, frames over
  250 ms, nor a game the tests and tools run: Main not the current scene) and moves the graphics settings
  along `STEPS` (high → fires' real shadows → sun rays → shadows on things (= medium) → ground fog → pixel
  1.25 → 1.5 → sun shadows → effects (= low)): two windows below 28 FPS (80 % of the cap if lower) a step
  down, a minute at 50 FPS (90 % of the screen rate or the FPS limit if lower) a try up; a slow window in the
  next 20 s takes the try back and sets `auto_ceiling`. Each step is told by a toast and in the F3 panel's
  full view. Any graphics setting by hand (`Settings.set_value`, a preset) turns it off.
- `src/client/view/crt.gd` — three settings of «Graphics», any mix of them works: «Screen effect» (key `crt`: off,
  soft CRT, old CRT, VHS tape; `LOOKS`), «Palette» (key `palette`: none, NES, 1 bit, CGA; `PALETTES`) and «Pixel size»
  (key `retro_pixel`: 1×, 2×, 4×; `PIXELS`). Saved screen effects 4..6 of the first build (#726) turn into a palette
  with 2× pixels (`Settings.load`). All of it is counted in the colour-correction pass (`grade.gdshader`), with no pass of
  its own; the interface on top stays sharp.
  The old screen (parameters `crt_*`) goes by the screen's pixels
  (the shifts — by the screen's long side, the bend — by the diagonal, the mask's stripes are wider on a dense
  screen, so in portrait and in landscape it is the same): scan lines with
  interlacing, the glow of bright pixels (8 samples of the world's picture with linear filtering,
  `crt_view`), split channels, the tube's curvature, a vignette, flicker, an aperture grille; the «old» one
  also has a rolling light band, the «cassette» — a jitter of lines, colour blurred along a line, a band of
  interference at the bottom and noise. The picture's position on the
  screen for the curvature is given by `CameraRig.update` every frame (`Crt.frame`).
  Big pixels (`retro_px`) lie on the world's grid (`view_origin`, `big_pixel`, so they do not crawl as the view
  glides); without the tube each is one filtered tap of `crt_view` at its middle (its middle four averaged), under
  the tube its first pixel. A palette (`retro`) brings the colour to it after the grade, before the tube's lines,
  with a 4×4 ordered dither by big pixels: NES — 55 colours, the colour made richer (×1.6) and looked up in
  `assets/nes_lut.png` (a 32³ grid of the nearest by eye, made by `tools/make_nes_lut.py`); 1 bit — black and white,
  the brightness stretched and put in five steps (black, three patterns, white) so a surface keeps one even
  pattern; CGA — black, cyan, magenta, white, the two nearest colours mixed by the dither in the same five steps.
  For 1 bit and CGA the night's darks are lifted by a gamma (`retro_lift`, set by `Sky._update_grade` from
  `sky_light`), else the world is all black outside a fire's light.
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
- `src/client/view/air_effects.gd`, `water_effects.gd`, `nature_effects.gd` (held by `Effects.air`, `.water`,
  `.nature`, made by `Main`, stepped by `Sky`) — the small effects, each by its setting in «Эффекты» (`effects`
  weather and fire, `water_fx` 0/1/2, `nature_fx`, `body_fx`, `heat_fx`, `drops_fx`; off on «низкое», mirroring
  and heat off on «среднее», `Settings.QUALITIES`, `AutoQuality.STEPS`) and hidden one by one in «Что рисуется»
  (their `parts()`). AirEffects: the air trembling over the nearest fires (stronger, higher and wider the more wood is left, `fire.fuel` from `Effects.fire_strength`) and over hot ground at a clear noon, only over sand or the sea (`hot_ground`, from 30° of air; global `heat_ground`: the ground's texels move in rows by the world, `heat_wobble` in `world.gdshader` and `water.gdshader`, and what stands over it sways along, `heat_sway`: sprites by their rows, plants, crowns and things of voxels by their vertices, most at the foot) and drops of
  rain running down the screen's edges (`grade.gdshader` `heat_spots`, `heat_haze`, `drop_state`: when they stop the drops there run off within
  `DRY_RUN` even if new ones start; a jump in the water, under `SWIM_LEFT` s out of it, still counts as a swim), a rainbow after rain (`_rainbow`, grade `rainbow`, `rainbow_at`: six bands of whole pixels on the screen's own grid, away from the sun, turned with the view, high with a low sun and low and fainter at noon, a lighter sky inside and a faint second bow; it comes as the rain thins while `Sky.after_rain` lasts, with clouds under `RAINBOW_CLOUDS`, outdoors, by day; no setting, hidden only in «Что рисуется»), snow on the screen (`frost_state`, `screen_snow`: flakes stick to the edges and melt while it snows
  outside, frost creeps in from the edges, deepest in the corners, below `FROST_FROM` degrees; the hotbar gathers snow, `hotbar_snow`;
  by the same setting as the drops; drops and snow are placed on the screen's own grid, `screen_shift` from `CameraRig.update`,
  so they do not glide or jitter with the picture; the wind across the view, `glass_wind` from `AirEffects._glass_wind`, runs the drops aslant and slides lying flakes aside by up to `GLASS_LANES` lanes or cells), breath steaming in
  a frost (puffs from a pool, `Creatures.muzzle`), the sun's path on the water at sunrise and sunset and the
  moon's at night (`water.gdshader` `sun_path`, `Sky.sun_height`; only where the light reaches the water:
  `sun_reaches` looks along it for cloud shadow, ground and tree crowns in the roof map; glints fade in and out
  each on its own clock). Snow on tops glitters a texel at a time in the sun's or the moon's light as the camera
  moves or turns, slowly when it stands (`world.gdshader` `glint`, passed from fragment to light, so none in shadow). In clear sun (`snow_sun`, Sky: daylight with no overcast) snow is lighter and softer: its tones closer together and less blue (`snow_color`), its hollows and slope steps shaded less, and light() lifts its shadows and the slopes turned from the sun part of the way to sunlit flat ground (`snow_lit`, `SNOW_BOUNCE`), tinted turquoise blue (`SNOW_BOUNCE_TINT`, and `snow_shade` for the dark texels of slope steps and drifts). Snowdrifts (`drifts.gd`: one mound, a ridge of two or a heap of three, leaning downwind, 0.9 to 6 units long, mostly small, big ones only where the ground round them is level, `_flat_radius`) get their normal set straight up in vertex(): the MultiMesh's flattening scale squashed it, so they took no snow and the light of a slope turned away; in clear sun their foot is shaded on the east and west sides only (`DRIFT_FOOT`) so a white mound still shows on white snow. WaterEffects: rings and splashes (fish jumping,
  a shot landing, wading, a fall into the water), steam over open water on cold mornings, fires and torches
  glittering on the water towards the viewer (`fire_glints`, looked at 5 times a second, every frame while a torch is carried), and the figures by the water mirrored in it
  (`sprite_mirror.gdshader`: the sprite upside down, drawn after the water and over the body's part under it
  (priority 2) with no depth test, kept to the water and the half of a shore's cell next to it (`SHORE_WET`) by the roof map's columns; a figure is
  mirrored with open water within `MIRROR_LOOK` cells round its feet, a swimmer too; its box fitted with `PixelView.sheared_box`; the water only tints its hue and the sky's light is taken to the power 1.6, so at night it is never brighter than the figure). NatureEffects: dandelion fluff,
  midges by the water at sunset and over one standing still (faint single pixels pulled back to a slowly wandering middle, `_midge_drift`, so they dart to and fro across it), dragonflies over the water, dust or snow from
  under the feet.
- `src/client/view/wisps.gd` (held by `Effects.wisps`, moved by `Sky`) — will-o'-the-wisps: on nights out of winter up
  to `WISPS` pale flickering emitters wander over the murky water of swamps and bogs (`WorldCells.murk`) near
  the view; one the player comes within `SHY` of slips away fading. `Effects.puff` — the spores of a picked
  or crushed puffball (a plant's `puff`; `WorldActions.spores`, the event `spores` from a server), at once.
- Curious plants (`grass.gdshader`): a custom plant with `looks` brings its other look as the second half of its
  frames; `PixelTextures.build_plants` writes a row under the plants (`looks_texel`: red shy, green night, blue
  the shift, alpha 1 for `after_rain`) and the vertex shader swaps the column — shy while the player stands within `SHY_REACH`, night
  past a `night_glow` of its own; an `after_rain` plant (a puffball) grows in four steps by the global `shrooms` (`Clock.shrooms`, set by `Sky`), its column sooner or later by the same sum as `Clock.shroom_size`. Texels of a custom picture with an alpha of 200..240 glint by day (dew).
  The second texel of each custom column in that row (`sway_texel`) is the plant's `sway` (0..2 as red × 2): the tips of every custom plant, crop and sapling sway in the wind like a grass tuft's times it (0 for a cactus or a puffball); moss and mushrooms of the engine stay still.
  Trodden grass (`trodden()`, the map `trample_map` of `src/client/world/trample.gd`, stamped by every stride that leaves a print): a plant that sways (tip above 0) lies over up to 5 pixels the way it was pushed (forward in the middle of a path, aside at its edge), up to 64% lower in steps, sways less, lies flat for `TRAMPLE_HOLD` and stands up again by `TRAMPLE_LIFE`; the shot `trample` (`tread` legs) shows it.
  The surf and a trail along the way a swimmer swam, fading as it ages (`wake_trail`, `wake_now`, from `WaterEffects`; the glow makes the water opaque so the open sea shines as bright as the surf) glow blue on rare warm nights in
  bays of plankton (`sea_glow`, set by `Sky` from the night, one in `SEA_GLOW_NIGHTS` (`Sky.glowing_night`), and
  the season, `water.gdshader`). The plankton glows only in the sea, not in lakes, ponds or rivers: the sea's water cells carry `WorldData.SEA_WATER` from the generator (the layout's `OCEAN`), the mesher gives them vertex alpha `SEA_ALPHA` (plain rows: `SEA_TILE` over the depth in the key), and the shader's `sea_here` lets it glow only there.
- `src/client/view/glow_lights.gd` (held by `Effects.glows`) — small teal pools of light round the glowing
  mushrooms at night: `Foliage` notes where each glowing mushroom stands (`Job.glows`, kept through a patch),
  `ChunkStreamer` hands them over per chunk, and every `PICK_EVERY` s the `LIGHTS` (4) groups nearest the
  view get a short light (`REACH` 1.6 units, one per group `APART`; each group its own pale brightness within `ENERGY`, 2–4 times dimmer than at first); the others glow only on their own
  (`grass.gdshader`). Off by day and under snow, like the caps, except below the sea's surface (`sea_top`, set
  by `ChunkStreamer._apply_plants`), where they fade in over 4 levels by day too, as `dark_glow` does. A second
  set, `Effects.lit` (`lit` true), lights the cells that cast light (materials with `light`: lava, crystals)
  always, each light in its material's colour (`Mat.lights`), `LIT_REACH` 3.2, `LIT_ENERGY`, `LIT_APART`: the
  mesher notes such cells that show to the air (`ChunkMesher.Job.glows`/`glow_mats`, kept through a patch) and
  `ChunkStreamer._apply_lit` hands them over.
- `src/client/view/window_glow.gd` (held by `Effects.windows`) — windows lit from inside: `Props` hands over each
  window placed (an item with `window`) with its voxel model; every `PICK_EVERY` s the lit fires and lights set
  down under a roof (`Effects.roofed`) within their reach of a window (and `HEIGHT` up or down) give it a target
  glow, more the darker the sky (`DUSK`..`NIGHT` of `Sky.sky_light`), and the glow eases to it. A glowing window
  gets a child mesh of its glass alone (voxels bluer than the frame, `GLASS_BLUE`) with its own copy of the
  material (`window_glow.gdshader`, warm colour mixed over the glass, flickering with fires): only the faces
  looking away from the lights glow, so it shows from outside. A window that does not glow draws nothing; the
  base material is drawn ahead in `ShaderWarmup`.
