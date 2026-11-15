# The picture: projection, camera, light, shaders

Status: ACTIVE. A Russian copy: [rendering_RU.md](rendering_RU.md) (it may trail this page: it is caught up weekly).

This page is the overview; the detail is split by topic into `rendering/`. Read the overview, then only the
page the change reaches (`grep -n '^#' docs/systems/rendering/<page>.md` first if it is long).

**Purpose.** Low resolution without smoothing (a texel = a pixel, the scale a whole number), an exact oblique
3/4 projection, light and colour correction by the world's clock, fires and shadows, particles, sprites,
voxel models of things.

**Where to look**

| Topic | Page | Key files |
|---|---|---|
| The view, camera, auto quality, CRT, sky, particles and effects | [rendering/camera-effects.md](rendering/camera-effects.md) | `src/client/view/pixel_view.gd`, `camera_rig.gd`, `sky.gd`, `effects.gd` |
| Fire and sun shadows, the material atlas, voxel models, shaders and globals | [rendering/shadows-shaders.md](rendering/shadows-shaders.md) | `fire_shadows.gd`, `pixel_textures.gd`, `shaders/` |
| Rules a change of the picture keeps (new shaders, the shear, the cave view, the slice) | [rendering/rules.md](rendering/rules.md) | `shaders/common.gdshaderinc`, `cave_layers.gd` |
| Pitfalls: GPUs, the web, lights, the material atlas, and the gotchas moved from CLAUDE.md | [rendering/pitfalls.md](rendering/pitfalls.md) | `world.gdshader`, `chunk_mesher.gd` |

**Tests.** `tests/unit/view_test.gd` (`pixel_view`, `sprite_sheet`, `tracks`, `hidden`, `camera_spin`, `auto_quality`),
the screenshots `tools/shot.gd` (the table `tools/shot/shots.gd`, the places `tools/shot/places.gd`),
`tools/profile.gd` (draw calls under xvfb), `tests/browser_smoke.mjs`.

**In more detail.** `plan/architecture/rendering.md` (the main document of rendering), `plan/design/visual.md`,
the screenshots by topic in `survivium-builds/`.
