# Trees integration: handoff (2026-11-24, thread «Встроить новые деревья в игру»)

Goal (user 2026-11-24 18:54 MSK): put the approved new tree art (21 species, seasons, stumps, pieces) into the game.
The user wanted a plan and questions first; the plan is written and all 9 questions are answered. Copy this file into
the repo as `docs/planning/trees-integration.md` with the first PR.

- Plan (Claude Doc, Russian, rev 26): https://claude.ai/artifact/PW1BTb5oDVk6Ej27UgJCdn
- Mockup state, how to run it, measurements, game facts:
  `/mnt/project-files/survivium-builds/trees-redraw/HANDOFF.md`, sections «Round 23» and «Integration plan» (read the
  last one whole; the rounds above it only by `grep`).
- Example for question 1: `survivium-builds/trees-redraw/integration/01-forest-a-vs-b.png` (src next to it).

## Decisions (user 2026-11-24 20:12 MSK)

1. А (user 2026-11-24 20:27 MSK, after the example): the Python mockup exports layouts, the game assembles the tree.
   Rejected Б: port the generator to GDScript, every tree unique (about twice the work, won't match the approved
   sheets tree for tree, costs time at chunk load on the phone).
2. Saplings, bushes and other plants are redrawn later. Young trees grown from saplings keep their current look for now;
   the old crown code stays for them and for bushes.
3. А: autumn = the game's current autumn rule (tint, leaf fall) applied to the new leaves; show it in screenshots.
4. А: a stump always stays (also on level ground, unlike now); uprooting it gives a log; the tree falls away from the
   player in about 1 s.
5. А: log, fallen trunk and broken trunk with a sprout lie in forests as world pieces; the axe chops them into logs.
6. А: fan palm (new species) in oases instead of half the feather palms, plus a few in jungles; gives logs and twigs,
   no coconuts.
7. А: old worlds regrow their standing trees by the new rules on first load; places, species and stumps are kept.
8. Б: no dev switch; each part is visible to everyone as soon as it merges. So each group's PR brings that group's
   crown cells (LEAVES/LOG from the layouts) and the old-world regrowth for its species, and the group must look right
   in every season with the game's current rules until the seasons PR brings the approved snow and blossom.
9. А: exported data and pictures in `content/plants/<species>/`; the generator stays in survivium-builds, like the
   animals' (`survivium-builds/animals/anim/HANDOFF.md` is the model).

## Recommended design (question 1 = А)

- Export per species: 3 sizes (s = 0.42 / 0.68 / 1.0) x 4 variants (mirroring doubles them): module points, normals and
  module ids in ring order, core parts, limb polylines with radii, trunk and foot data, shadow parts; plus module atlases
  that store ramp steps (not colours) and per-leaf facing, blossom and snow flags, and the ramps.
- Client: camera-facing cards for modules, ribbons for limbs, trunk and stump pictures, a new shader lit by the live
  sun (band from n.L as in the mockup: base 4/3/2 over 0.64/0.36, palest over 0.8, contrast 1.3, quarter shade step).
  New shader files only: bushes use foliage.gd and a text-patched copy of leaves.gdshader (main.gd).
- Server: Growth places the LEAVES/LOG cells from the layout's parts; size class and variant come from the column hash
  and Growth.fit, so nothing new is saved.
- Mockup projection = the game's: render7.Tree.proj = (ox + x, oy + z - (y + cy)); depth squash broadleaf 1.0,
  conifer tiers 0.45 (= CONE_DEPTH), palms 0.9, stump faces and logs 0.6; SUN_R = (0.6, 0.75, -0.1).

## Next step: step 0 (no PR)

Export oak, spruce and birch (3 sizes, 1 variant each), draw them in the game with a throwaway assembler, and show
screenshots at the phone's portrait 2608x1200 beside the mockup sheets (all at once on one sheet, `tools/sheet.gd`).
Only after the user approves: PR 1. The variants beyond the approved trees are new seeds: show them all on a
sheet before they go in (the user asked 2026-11-24 20:24 MSK whether А keeps the random crown deformation, tier
spacing and tilt: yes, each variant is one seed of the same generator).

## PR order

1 broadleaf (14 species) -> 2 conifers (spruce, fir, larch, pine) -> 3 willow, feather palm, fan palm (new species
needs a species remap by names) -> 4 seasons (snow on bare trees, oak/linden/willow dry leaves, blossom 80% on cherry,
bird cherry, apple, rowan, acacia; no snow on palms, acacia, ceiba, mangrove) -> 5 felling, stumps, fall animation,
pieces -> 6 clean-up: old crown code out (bushes and young trees keep theirs), docs, tests.

## Gotchas

- The mockup drew each tree from one side only; the game's camera turns in 45° steps. Crowns and conifer tiers
  look right from any side, but limbs are spread left and right (trees22.py: heads = 0 or pi +- 0.35, sometimes
  -pi/2), so after a 90° turn they point at and away from the camera; fallen trunks and logs lie left-right only.
  The same for А and Б. Step 0 shows the trees from several camera turns and offers a fix (limbs spread all
  round, or the whole tree turns with the camera); the user was told 2026-11-24 ~20:30 MSK.
- The species index in saves follows load order and is NOT remapped: a new species shifts old worlds' trees (fix
  with a remap by names, like Mat.remap) before the fan palm lands.
- Felling from level ground now removes the whole trunk; a stump stays only when chopped from >= 2 levels up.
- Web shaders: at most 13 textures (lint); leaves.gdshader already has 11 samplers with common.gdshaderinc.
- Phone browser is 4-5x slower than a PC: nothing map- or chunk-sized in one frame (`frame_test`); count cards per
  chunk against today's 60-110 per broadleaf, ~150 per spruce.
- Crown cells are read by the cursor, twig and seed gathering, birds, shade plants, roof_map CROWN (leaf litter), the
  minimap and sun rays: keep them matching the drawn crown.
- Project rules: show the result first, the user approves, then integrate; every PR has «Что нового [вид]: …» and
  «What's new [kind]: …» lines; player texts are `[keys]` in en and ru; rebase on main, auto-merge on green, watch the
  build and release.

## Step 0: design worked out (thread «Встроить новые деревья в игру: шаг 0», 2026-11-24 ~21:00 MSK)

No code written yet; a successor builds it from this. Setup: Godot from github.com/godotengine/godot-builds/releases/
download/4.5.1-stable/Godot_v4.5.1-stable_linux.x86_64.zip -> ~/godot/godot, `--import` ~5 min; mockup run folder:
`sh survivium-builds/trees-redraw/round23/src/setup_run.sh /tmp/run23` after `pip install scipy`; build trees with
`all23.build(key, s)` (oak, birch: trees22.tree; spruce: trees22.conifer), `t.render(ground=KEY_G, shade=KEY_S)`, then
`outline23.outline(img, key)` for the approved wood outline.

Facts found (code, 2026-11-24):
- Projection: PixelView.PIXELS_PER_UNIT 16; the ortho camera looks straight down and shaders shear xz += view_up * slope
  * y, so screen px = (x, z - y) * 16 at turn 0: 1 mockup px = 1/16 world unit, mockup frame (x right, y up, z to the
  camera) = world (x east, y up, z south) at turn 0. Depth = world height: upright cards sort by z, flat cards by height.
- Light: Sky._aim_sun(az, el), to_sun = (-sin az cos el, sin el, cos az cos el); day path az = (t - 0.5) * 180 - 25,
  el = lerp(14, 55, -cos 2 pi t). The light turns with the view (lit sides and shadows stay put on the screen at every
  camera turn); global `sun_view` = (to_sun . right, to_sun . screen-up, to_sun.y), so the mockup-frame sun is
  L = (sun_view.x, sun_view.z, -sun_view.y) at any turn. SUN_R = az -99.5, el 51 never happens in the game (the eastern
  sun is low): for the "sun on the right" comparison stop Sky's processing after its colours settle and call
  _aim_sun(-99.5, 51); morning t 0.3 = az -61 el 26.7, noon az -25 el 55, evening t 0.7 = az 11 el 26.7.
  leaves.gdshader is lit by Godot (light(): bands on n . sun_view x LIGHT_COLOR / PI + ambient), not unshaded.
- The mockup trees are single-view designs, not only the limbs: crown parts are squashed in depth (oak's lobed shape:
  caps at x0 +-25 / +-15, z0 -5..10, rz ~ 0.55 rx; conifer tiers ZS 0.45), fronds are placed by screen origin
  (mod['org']), the foot is a picture. Placed fixed in the world, a 90 deg turn stacks the oak's lobes front to back and
  narrows the crown. Options to show: А (recommended) the whole tree turns with the camera (view-locked layout: every
  step shows the approved sheet, the mockup's draw order and culling stay exact, crown cells in the world get a round
  footprint); Б true 3D trees fixed in the world (round crowns rz = rx change the approved look, limbs all round, module
  order and culling per camera step).
- Mockup paint order (render7.Tree.render): ground shadow, wood (Based.draw_trunk: foot picture lit by columns + the
  skeleton z-buffered with bark texture for r >= 3.5 and the crown's shade), core = parts' outline at k 0.92 in
  ramp[1], then modules in list order (parts by y0 + z0, rings bottom->top, each ring by z), skipping t.skipped (no
  visible pixel), then outline23 'step' (one bark step darker where wood meets the ground). Live modules must keep this
  order: plain depth would put a lower front ring over the ring above it (the mockup does the opposite).
- Module light (render17/render7.module_pixels, module5/module123.tones): d = n . L, base 4 / 3 / 2 over d1 0.64 /
  d2 0.36; per leaf f = scale * dot((cos a, sin a), light2), light2 = norm(L.x, L.z - L.y), top leaves f = max(f, 0.5)
  (dots: scale = min(1, rad / 4), no top rule); t = (BODY or HEART ? 0 : -1) + (f > 0.2 ? 1 : f > -0.5 ? 0 : -1), +1
  more on a lit heart pixel with f > 0.45 (module5: BODY with depth >= 1; module123: HEART); shade 'quarter' when
  base is 2: t = flat + 0.75 lt for lt < 0; a disc pixel without a leaf t = -1; c = base + t, at most 5 when d < dp 0.8,
  clip 0..6, a fractional c mixes two ramp colours. Anchor: X0 = round(sx) - cx (cx = S-1-C0 when flipped), Y0 =
  round(sy) - C1 with module5 S 30, C (13, 14); proj = (ox + x, oy + z - (y + cy)); limbs and feet use proj_abs =
  (ox + x, oy + z - y), trunk base (BX, h0, 0).

Step-0 assembler (throwaway, uncommitted), as planned here:
- export0.py in the run folder: per tree (oak, birch, spruce x 0.42 / 0.68 / 1.0) render the full mockup for each sun
  (R, morning, evening; geometry and t.skipped do not depend on the sun: set t.L, t.light2, clear t._tones, re-render)
  -> base sprite per sun = final image without the live modules (wood + core, outline included; conifers: fronds baked
  in too, their light is PR 2) as RGBA with keys made transparent; live modules of broadleaf: rounded screen offset,
  normal, atlas tile, rank (drawn order); module atlas RGBA (R leaf angle, G scale, B flags leaf/top/body/heart/disc).
- Game: one ArrayMesh per tree of quads (VERTEX = screen px offset from the trunk's projected origin, UV = atlas px,
  NORMAL = module normal, COLOR = kind / rank), shader world_vertex_coords + unshaded + common.gdshaderinc: snap the
  trunk's sheared position to whole px in the screen axes (right = (-view_up.y, view_up.x), down = -view_up), lay the
  quads along them (view-locked = option А), depth flattened on the upright plane through the trunk (height for the
  pixel's screen row / view_slope, clamped >= ground + 0.02) + layer (base 0, modules 0.1 + rank * 0.002); colour x a day
  factor from the sun's energy and colour (1 at noon). Ground shadow: shadow-only ellipsoids per crown part + a trunk
  cylinder on PixelView.LAYER_SUN_CASTER, sheared, view-locked. For Б's demo: bare trees with world-fixed limb ribbons
  from t._samples() (p, r, tan, l, j).
- Shots: shot.gd with a temporary key after `clearing` (places.clearing flattens 60 x 48 cells and plants an oak and a
  spruce: remove them with w.remove_tree); phone portrait `xvfb-run -a -s "-screen 0 1200x2608x24" godot --path .
  --rendering-driver opengl3 --resolution 1200x2608 --script res://tools/shot.gd -- <dir> --phone <shots>`; the low-res
  picture is ~172 x 373 px, so one species' three sizes fit one shot stacked north->south (thick north, ~11 cells to the
  medium, ~6 to the thin); hide grass (main.render_toggles.set_hidden("chunks: grass", true)). Sheets: per species
  mockup | game sun R | morning | evening; turns 0/45/90/135/180 for А and the bare trees fixed in the world (Б's
  problem); attach at most 6 pictures a message.

## Step 0: done (thread «Встроить новые деревья в игру: шаг 0, часть 2», 2026-11-24 ~21:30 MSK)

Shown to the user: oak, birch, spruce (3 sizes) in the game on the phone (1200x2608 portrait, grass hidden) beside
the approved mockup, at the mockup's sun R, morning (t 0.3) and evening (t 0.7); camera turns 0/45/90/135/180 for А
and Б; a grove of all nine at noon. Pictures: `survivium-builds/trees-redraw/integration/step0/` (sheets, phone
shots). Waiting for the user's pick А / Б (asked in the thread), then PR 1 in a new thread.

How it was done (throwaway, nothing committed; sources in `integration/step0/src/`):
- mockup/export0.py (run from the round-23 run folder): `TR.tree` / `TR.conifer` on a 1000x760 canvas (room for the
  low suns' shadows), per sun: `t.L`, `t.light2`, `t._tones = {}` then `t.render(ground=KEY_G, shade=KEY_S)` +
  `outline23.outline`; sprite = keys transparent, `t.shadow()` saved as a mask; meta.json has ox, oy, bx -2, boxes.
  Re-rendering with another sun is exact (checked). An oak takes ~40 s a sun (core and shadow are canvas-sized).
- mockup/export0b.py: option Б = the approved tree fixed in the world: `inside` wrapped by the inverse turn about the
  trunk (BX, z 0), limbs wrapped (RotLimb), modules' p and n turned and the paint order rebuilt (a patched
  render12._place records each module's part and ring; parts by y0 + z0', rings bottom->top, ring by z'); the turn-0
  rebuild equals the approved picture exactly. Turn n: right = (cos a, -sin a), toward the camera = (sin a, cos a)
  (PixelView.view_of). export0c.py: the spruce with conifer21.ZS = 1 (its tiers as round as the game's view sees them).
- game/: `tools/trees0/` (trees0.gd places the pictures, shots0.gd builds shots `t0s-/t0t-/t0g-` from their names,
  tree0.gdshader = face_view + stand_tall + shear, the rows under the foot lying on the ground (+0.03), the foot
  snapped to whole screen pixels, unshaded x `day`; tree0_shadow.gdshader = the mockup's shadow mask as a
  shadow-only sheet) and hooks.diff (Sky.pin_sun holds the sun at the mockup's az/el; Places.skip_trees; shot.gd
  calls). Apply with `git apply`, then `xvfb-run ... tools/shot.gd -- <dir> --phone t0s-oak_1.00-r ...`.
- sheets/: lowres.py gets the game's low-res frame back from a phone shot (portrait: 171x372, scale exactly 7),
  findtree.py / sheets0.py cut the trees out by matching the sun-R sprite.

Facts learned:
- The game's colour grade moves the mockup's colours a little (darks darker, lights lighter: 18,38,47 -> 9,32,47;
  189,222,130 -> 198,226,132); everything else matches pixel for pixel.
- A shadow-only sheet lying on the ground casts nothing (bias): held 2 units up and moved toward the sun by
  lift * (L.x, L.z) / L.y it lands where the mockup's shadow lies. A crown's shadow in PR 1 can be this mask (exact)
  instead of ellipsoids.
- The shot tool's clearing leaves holes in the ground (patched chunks; also in the stock `clearing` shot with
  `--magenta`): remesh_chunk over the clearing and wait for dirty_chunks to empty.
- Phone portrait shows 10.7 x 23 units; a 1.0 spruce (166 px) or birch (155 px) needs its foot in the lower half.
- Day factor used: (sun colour x energy x to_sun.y + ambient) / noon's, in linear, back with ^(1/2.2); sun R = 1.
- Under Б the approved shapes break: a 90 deg turn makes the oak's and birch's crowns narrow and tall (rz ~0.55 rx),
  the oak's lobes stand one behind another, limbs point at the camera; the spruce drawn by the game's view (ZS 1)
  is ~25 % taller on the screen with its tiers' undersides showing.

## Decision after step 0: Б (user 2026-11-24 22:16 MSK)

User's words: «1. Б. Кроны и ветви перерисовываем так, чтобы объем дерева сохранялся с любой стороны». Trees stand
fixed in the world and the camera's turns show their other sides; the crowns and limbs are redrawn so the tree keeps
its volume from any side. This puts a redraw round (mockup, no game code) before PR 1:
- Broadleaf crowns round in depth: parts with rz = rx and the caps' z0 no longer squashed (the oak's lobes at
  x0 +-25 / +-15 get matching depth offsets so the crown is full from every side, not a fan); limbs spread all round
  (skeleton17's heads now 0 / pi +- 0.35 and sometimes -pi/2: give them azimuths round the trunk), forks likewise.
- Conifers: tiers drawn by the game's view (conifer21.ZS 1, export0c.py) are ~25 % taller on the screen with the
  tiers' undersides showing; keep them round and decide with the user whether to keep that look or flatten the
  tiers' cones in 3D so the screen height stays near the approved one.
- Also single-view today: palms (ZS 0.9), willow strands, stump faces and logs (FACE_ZS 0.6), fallen trunks (lie
  left-right only), broken trunks.
- Show every redrawn species from turns 0/45/90/135/180 (export0b.py's turn: inside wrapped, limbs RotLimb, modules
  re-ordered per view) beside the approved sheet, for the user's approval; then the integration.
- Integration under Б (replaces the view-locked plan above): modules as cards at world-fixed 3D points, the light per
  module from its world normal against the view-locked sun (d = n . L with L turned with the view), paint order per
  camera step (parts by y0 + z0', rings bottom->top, ring by z'), culling per step (8 steps, or the union),
  limbs as world-fixed ribbons, the foot picture as it is (round), shadows from 3D casters or a mask per step.

## Round 24: redraw for Б (thread «Перерисовать кроны для вида с любой стороны», 2026-11-24 ~22:40 MSK)

Finding: the approved mockups draw every tree in a "squashed frame" (depth toward the camera x 0.55 for broadleaf crowns,
render7 rz ~ 0.55 rx and limbs' fork z x 0.6; conifer tiers ZS 0.45; palms 0.9; stump faces 0.6). Read as 3D (z / squash)
the single-part crowns and the conifer tiers are already round. A camera turn = p' = S Rot(n) S^-1 p (normals by the
inverse transpose, S = diag(1, 1, zs)): drawn so, the tree stands in the world (its caps and limbs turn), is full from
every side and keeps the approved height and width; turn 0 of an unchanged tree is pixel-identical (checked: spruce).
With S_out = 1 (the game's true depth) crowns come out 7-26 % taller, the spruce 21 %, shadows 1.5-2x.
Shown 2026-11-24 ~22:40 MSK: round24/123-125 (oak, birch, apple, linden, spruce: approved | A approved depth at turns
0/45/90/135/180 | Б true depth); asked «1. А (recommended) approved depth / Б true depth»; working on А meanwhile.
Redraw under А: lobed crowns get a cap where the 3D ring had a hole (oak: back, 'lobed3d'; maple/ceiba: back left,
'lobed2_3d'), main limbs at 2-3 azimuths all round (skeleton24), conifers re-pick each branch's frond per view
(conifer24: _geometry / _pick split, same noise state), the rest unchanged. Code: survivium-builds/trees-redraw/
round24/src (turn24.py maps/turn, shapes24.py use3d(), conifer24.py, look24.py build/views/grid2); run folder =
round23 setup_run.sh + step0 mockup/*.py + round24/src/*.py. Integration under А: as «Integration under Б» plus the
per-view squash of each tree's offsets about its foot (vertex shader), normals by the inverse transpose.
Round 24 shown 2026-11-24 ~23:10 MSK: all 21 species (s 1.0) approved | А turns 0/45/90/135/180, round24/126-131
(batch24.py <keys> 1.0 4 -> ../out24/b_<key>_1.00.npz, bsheet24.py <out> <keys> <title>); widths/heights within
±5 % except caps apart (maple, ceiba 10-15 % narrower at 45-135) and deadwood (limbs all round: bushier top at 0).
Asked «2. caps apart narrower at 90: А leave (recommended) / Б spread the caps evenly». Willow and palms turn with
kinds24.py (willow_turn rebuilds willow22's order; palm_turn: leaf phi -= 45 n, trunk lean turned, scale texture
phase turned). NEXT (successor thread): stumps, logs (FACE_ZS 0.6), fallen trunks (lie left-right only: need any
azimuth, end faces when seen end-on), broken trunks with a sprout: round23/src stump23.py, logs23.py, broken23.py,
sprout23.py, pieces_sheet23.py; same turn sheets (approved | 0..180); then wait for the user's answers to 1 and 2
and the OK, then PR 1 (integration under А).
User's picks 2026-11-24 23:02 MSK «1. А 2. А»: depth А (each tree drawn with its approved depth squash at every
turn; integration = per-view squash of offsets about the foot), caps apart left as they are (narrower at 45-135).

## Round 24: pieces turned, answers 1А 2А (thread «Повернуть пни и брёвна в мире», 2026-11-24 ~23:15 MSK)

User 2026-11-24 23:02 MSK «1. А 2. А»: integrate under А (each tree drawn with its approved depth squash per camera
step: the per-view squash of the offsets about the foot in the vertex shader, normals by the inverse transpose);
maple/ceiba caps apart stay as drawn. The pieces (stumps, logs, fallen trunks, broken trunks with a sprout) turned the
same way and shown (survivium-builds/trees-redraw/round24/132-137, all 21 species x 8 turns, 0 = approved pixel for
pixel; how-to in HANDOFF «Round 24 — answers 1А 2А; pieces turned»). Waiting for the user's OK on them and one pick
(broken trunk from its high side: А splinters hide the break, recommended / Б keep it visible).
For PR 5 (pieces): logs and fallen trunks are true 3D tube scenes (pieces24.turn_scene takes any angle), so a piece can
lie at any azimuth: export pictures per angle (8 camera steps x the piece's azimuth quantised, e.g. 16 per piece) or
draw the tubes in the game; stumps keep their foot picture (round) and turn only the end grain (a level disc: a world-
fixed decal under А's squash); broken trunks turn the break plane, splinters, sprout (stumps24.Broken24).
PR 1 (broadleaf) does not depend on the pieces and can start now (decisions 1-9 + Б + А above).

## Pieces approved; NEXT: roots that turn (user 2026-11-24 23:47 MSK)

User: «1. А  Все хорошо, но корни у пней (и деревьев) тоже нужно поворачивать». So: the pieces (round24/132-137) are
APPROVED with 1А (the broken trunk's near splinters hide the break from its high side, as drawn). Before PR 1 the
feet get redrawn so their roots turn with the camera, for the trees and the stumps (successor thread).
What the foot is today (bases22.py, round 22 trunks): a 2D relief map cut 1:1 from the references (BASES '122' wide
flare + roots lying on the ground `rg`, '123' barrel with no roots, '124' straight trunk with two root stubs at the
sides and a lit tap root toward the viewer), resampled per tree by Based._vgeom (kx, ky), lit per column by
render7._barrel_normal (trunk_band) and _root_normal (root_band for rg pixels); drawn by Based.draw_trunk (122:
render7/16's own draw_trunk), then the skeleton z-buffered over it. The same picture at every turn (view-locked), the
trunk's bark texture too. Foot by size: thin 124, medium 123, thick 122 (bases22.foot_for, splits 0.55 / 0.84).
Suggested approach (to show the user first): the feet as 3D pieces drawn like logs23.Scene (z-buffered tubes, bark
relief rows along the length, the trees' light bands, outline23 'step'): 122 = the flared base as a surface of
revolution + 5-7 roots as tapering, slightly curved tubes going out and down into the ground at azimuths all round
(the front ones placed and sized after the reference's so turn 0 stays close to the approved foot); 124 = the two
stubs + the tap root as tubes at their turn-0 azimuths (left, right, front) plus 1-2 more at the back; 123 = a
barrel (surface of revolution): nothing turns but its bark plates (say so). Turn n = the foot turned about the trunk's
axis with the tree (turn24 / conifer24 / stumps24.Stump24; sun view-locked). Turn 0 will not be pixel-identical to
the approved picture: show approved | new turn 0 | 45..315 for the three feet close up, then all 21 species' trees
(round24 sheets 126-131 again) and stumps (132) with the new feet. Then the user's OK, then PR 1 under А with these
feet (roots = world-fixed tubes/ribbons in the game, or a foot picture per camera step).

## Round 25: roots that turn, SHOWN, waiting for the OK (thread «Поворачивать корни деревьев и пней», 2026-11-25 ~00:35 MSK)

Done as a mockup (survivium-builds/trees-redraw/round25/, sheets 138-143, tools round25/src/feet25.py; details in
HANDOFF «Round 25»). Each foot = a view-locked body (the trunk's lowest part, round, the same from every side: 122 =
the reference's drawing stage before its roots, 124 = the cut without its stubs and tap root, 123 barrel unchanged as
it has no roots) + 3D roots (tapering Bezier tubes in the foot's own squash, fitted from the reference's base oval:
122 zs 0.31, 124 zs 0.53) whose azimuths turn with the camera. The foot is drawn at the reference's scale and resampled
per tree like the approved block, so turn 0 stays close to the approved picture (not pixel-identical) and small trees
keep the approved look. Roots: the tree's bark along them, the trees' light steps, the trunk's cast shadow and the
crown's shadow, the trees' outline rule. Palms' root nubs turn too (turn 0 pixel-identical). Stumps: cut from the tree
with the turned foot; the face keeps the trunk's width at every turn (roots off the trunk are not counted).
Asked the user: 1) the thick foot's front roots: А keep as long as the reference's (recommended) / Б shorten; + the OK.
NEXT after the OK: PR 1 (broadleaf trees, integration under А) in a new thread. For the game: per camera step the foot
is foot_block at that step's angle (a small map at the reference's scale: relief, light step, kind per pixel),
resampled per tree like today's single foot picture, so 8 small maps per foot kind ('122', '124'); '123' one map.

## Feet approved; NEXT: PR 1 (user 2026-11-25 00:42 MSK)

User: «1. А  Все хорошо»: the turning feet (round25/138-143) are APPROVED with 1А (the thick foot's front roots stay as
long as the reference's). Every redraw before PR 1 is now approved: crowns and limbs from every side (round 24, squash
per view А), pieces (round 24, 1А), feet (round 25). NEXT, in a new thread: PR 1 = the 14 broadleaf species in the
game, integration under Б («Decision after step 0: Б»: world-fixed modules, light per module against the view-locked
sun, paint order and culling per camera step, limbs as world-fixed ribbons) with these feet: per camera step the foot
is feet25.foot_block at that step's angle (relief, light step, kind per pixel at the reference's scale), resampled per
tree like today's single foot picture (122 and 124 turn, 123 one map). Mockup sources: round24/src, round25/src
(feet25.py) on the round 23 run folder (HANDOFF «Round 24», «Round 25»). PR order, gotchas: sections above.

## PR 1 in progress (thread «Встроить лиственные деревья в игру (PR 1)», state 2026-11-25)

- Code on branch claude/project-thread-0rm2ey: `tree_looks.gd` (reads content/plants/<key>/tree/look.yaml),
  Growth `_pictured` / `_offsets` (crown points cached in the look) / `look_index` / `standing_look` (trunk height +
  leaves over the trunk round the nearest crown points, `_probes`, so a stump cut at a smaller look's trunk is no
  tree) / `outgrown` / `regrow`; `tree_sprites.gd` + `shaders/tree.gdshader` (frames RGBA8 + bare LA8, lit
  view-locked like the mockup, TONE 0.8, shakes under the axe like leaves.gdshader); chunk_streamer `trees`
  MultiMesh; Foliage / trunk mesher skip standing pictured trees; old saves: `WorldCells.TREE_LOOKS` ("looks" in
  pack_chunk) + `WorldGen.Job.regrow` (stumps and young trees stay; chunk marked unsaved).
- All 14 species packed (atlas 3760x1992, ~43 MB video memory). Deadwood: crown cells from the crown volume
  (the old game's dead crowns had leaf cells too), trunk from the crown's bottom.
- Mockup -> game tools: survivium-builds/trees-redraw/integration/pr1/src/ (export_pr1.py -> npz per look,
  pack_pr1.py -> frames.png, bare.png (LA), look.yaml).
- Review shots: `tools/shot.gd -- /tmp/shots --phone pics-<tree>[-v][-t][-c][-h][-s]` (x-ray off, player south of
  the thick tree; `main.view.wake()` per shot stops the idle camera drift in long runs). Sheets 144-147 in
  integration/pr1/.
- Tests: generation `_test_pictured`, `_test_regrow`; store `_test_regrow_saved`; full unit run, save_test,
  server_test green.
- Known, later PRs: ground shadows are still the game's (from crown cells); snow/blossom PR 4; stumps, fall,
  pieces PR 5; young trees stay old.

### PR 1: user's fixes before the PR (2026-11-25 03:14 MSK)

User on sheets 144-147: «Что случилось с высотой деревьев? Почему кроны оторвались от стволов? Что за дыры в кронах
осенних деревьев? (Нужно просто скрывать модули начиная с краев кроны)».
- Height (checked 2026-11-25): the game draws each look pixel for pixel as the approved mockup (cmp_pr1.py), but the
  new thick trees are ~1.5x taller than the old game trees (old thick oak 77 px, linden 87, birch 98, ceiba 112;
  new 124 / 144 / 159 / 184): the old ones had a wide low crown on a short thick trunk. The plan's estimate
  («the game's trees ~ the mockup's medium..thick») was wrong: they are ~ the mockup's thin size. Sheets 148 (old
  game | new game | mockup) and 149 (options) in integration/pr1/; opts.py / sheet148.py in its src/ (render a
  species at other sizes / bole factors). Asked on a card: А as now, Б one size smaller (thick = 0.68), В Б + bare
  trunk under the crown x0.6 (only egg/ellipsoid/hemi shapes: lobed ones ignore bk), Г two sizes smaller (thick 0.5,
  recommended: old heights, the approved proportions). Old-tree shots: OLD_TREES=1 env in places.pictured (debug
  hack, not to commit), WORLD_CROWN=1 draws the world's crown cells the old way (debug, not to commit).
- Autumn: frames now carry each module's edge rank 0..3 = floor(4 r^2), r = the module's visible centroid's distance
  from the crown's centroid over the crown's reach that way (72 angle bins, widest of a bin and its neighbours). Bits
  (export_pr1 header): leaf A = 128 | body | heart<<1 | rank<<2 | share<<4, share = the leaf's light share in 7ths,
  0 = a leaf on top (whose share is always whole: only 122/blade/round leaves are on top, the dots' shares are
  1, 4, 5, 6, 7), B = 8-bit angle, R, G = 8-bit octa normal; the module's disc (no leaf) is body 0 + heart 1 (a heart
  is always body). Tested: a 7-bit angle (rank's low bit in B) cost 137 wrong pixels on the thick oak at dawn (leaf
  angles cluster at thresholds), 7-bit normals ~350; this layout = the old fidelity (oak 1.00 turn 0: 21 px at
  dawn, 0 at noon). Core: R = 255 r^2. The shader hides a bundle when (rank + hash) / 4 > leaves left, the core
  when its r^2 > left - 0.08, and draws the wood from the bare frames once under half the leaves are left (the
  summer frames' wood has the crown's shade: a dark band across the bare trunk in winter). reenc_pr1.py re-encodes
  the leaf pixels of an export in ~1 min a look (checks masks, normals, angles) instead of a 70-min export.
- «Lobed shapes ignore bk» above was wrong: opts.py patched SP.SPEC before E.build, and shapes24.use3d resets the
  lobed species' SPEC from its first copy. Patch SPEC after use3d (export_pr1.build does).
- User 2026-11-25 03:57 MSK (in words, instead of the card): «Давай опустим кроны новых деревьев примерно на 20%
  высоты дерева». Done in export_pr1.drop/build: the shape's cy (bare trunk under the crown) shorter by 20% of the
  tree's height, but no lower than keeps 12% of the new height (and 6 px) of trunk seen under the crown at the
  trunk's middle (SEEN table: measured on the approved exports, both variants, all 8 turns); under 2 px = unchanged;
  deadwood (no crown) unchanged. Result per size thin/medium/thick: linden, birch, acacia, ceiba, rowan ~20% (thin
  12-20%), mangrove 7/18/19%, maple 4/10/14%, red maple 0/11/15%, oak 0/4/5%, apple 0/6/9%, cherry 0/0/4%, poplar
  0/0/6%, bird cherry 0/0/7%. Before/after sheets 150-151 (integration/pr1/). Re-export to /home/user/out_pr1c.
- Shots: the 3 sizes stood 14 and 8 cells apart in places.pictured, so a lower tree's crown covered the trunk of the
  one behind it (looked like crowns cut off their trunks): spaced further apart.
- Maple / red maple: the game drew their leaf outlines half a step lighter than the approved mockup (module_maple
  OUT_EXTRA 0.5, the user's -1.5 pick) since the first export: ~40% of maple pixels. Now code 2 / 3 in the leaf's
  bits 4..6 = a maple outline (not on top / on top), t0 = -1.5 in the shader and decode_pr1; checked 0 differing px.
  Remaining differences on every species are modules whose n.L sits at a light threshold (8-bit normal) at one of
  the 8 sample suns: they change step a moment earlier or later in the day.
- Re-export done 2026-11-25 (/home/user/out_pr1c, packed into content/plants/*/tree/), shots tools/shot.gd
  `pics-<tree>[-f<leaf fall x100>]` (new -f), places.pictured spaces the sizes 15 and 11 cells apart, either variant
  unless -v. Sheets integration/pr1/150-151 (mockup before/after lowering), 152-153 summer in game, 154 light and
  camera turns, 155 autumn steps (80/58/35/17% leaves left) and winter; shown 2026-11-25 ~06:10 MSK, waiting for the
  user's OK to open PR 1.
- Acacia thick/thin looks had no crown cells (its flat crown is thinner than a cell): pack_pr1.crown_grid now
  samples 8 heights a cell when no cell middle is inside.
- Lowered crowns broke Growth.standing_look for acacia (generation_test «stump 7»): a flat crown's points
  (Growth._offsets: every other level by the foot's parity, even dx/dz, turned by TreeLooks.to_own) may all sit
  under the look's `trunk`, so no probe and the tree read as crowned at any cut. pack_pr1.probe_cap(grid) replays
  the probes over 8 turns x 2 parities and caps `trunk` at the lowest top level + 1; the looks of a variant are
  then kept apart downward (smaller look lower). generation 112/0.
- mesher_test «forest: a dug top patched into the chunk: grass (611, whole 609)» with the new crown cells: an old
  bug the new layout exposed. A felled crown 2-3 columns outside a chunk took the near-crown test of that chunk's
  ferns (`grows: woods`, Grass._near_crown, WOODS_EDGE 3) with it, but ChunkMesher.reach gave its leaf cells 1, so
  the chunk was not patched and kept the ferns. Fixed: reach = Grass.WOODS_EDGE where a column lost its last leaf
  or got its first (chunks.md, chunk_streamer comment).
- store_test «an old tree of a saved chunk grows again» failed (its rng was unseeded, so flaky, but the cause is
  real): with the lower crowns the looks' trunks (e.g. birch 4/5/6, linden 4/5/6) overlap the old trees' trunks
  (birch [5, 6], linden [3, 4]), so Growth.regrow's «already of its look» test (standing_look) took many old trees
  for pictured ones and left their old crowns. Now version-based: look.yaml may say `since` (the TREE_LOOKS its
  pictures came with; 1 when absent, PR 1 writes none), Growth.outgrown(trees, chunk's looks) picks the species
  pictured since later looks, and regrow no longer asks standing_look. PR 2 (conifers): TREE_LOOKS = 2 and its
  look.yaml files `since: 2` (pack script), or chunks saved by PR 1 would grow their broadleaf trees again.
- 2026-11-25 ~06:45 MSK: all checks green (lint, doc_index, lang, import, parse 367; generation 112, mesher 28,
  shapes 33, store 20; save_test 120; server_test 193), committed and pushed f3bd66c on claude/project-thread-0rm2ey.
  PR body draft: planning/trees-pr1-body.md. Next: the user's OK on sheets 150-155, then open the PR (assign
  randomboygh, request review, auto-merge on green, watch CI/release/deploy).
- 2026-11-25 11:54 MSK the user approved («Все хорошо»): PR #881 opened (https://github.com/randomboygh/survivium/pull/881),
  assigned randomboygh; the repo has auto-merge off, so it is merged by hand (squash) once CI is green.
- 2026-11-25 12:13 MSK: CI green on f3bd66c, PR #881 merged (squash, cafef69). Watching the main build / release /
  deploy. Next: PR 2 (conifers), when the user says.
- Main run 45583198626 (cafef69): progress (other) failed with the known flake «a tree at (633, -775) does not fall
  to the axe»; its prints show the server's hand empty («hand ,») through all 120 swings, so the blows never
  reached the tree (not the trees' change; the same commit passed on the PR). Re-ran the failed jobs once
  (2026-11-25 12:43 MSK); release/deploy follow it. If it recurs: why main.host.player.held() stays empty after
  controls.put_in_hand in tests/progress_test.gd _fell.
- Re-run green; release v0.4.881 (APK, Windows, Linux; en/ru notes) and the Pages deploy done 2026-11-25 12:58 MSK.
  PR 1 finished. Next: PR 2 (conifers), when the user says.

## PR 2 (conifers): start here (user 2026-11-25 13:15 MSK «Доделываем остальные»: PRs 2-6 in order)

Rules as for PR 1: show in-game phone sheets first, the user's OK, only then the PR; merge by hand (squash) on green
(the repo has auto-merge off); a main «tree does not fall to the axe» progress failure gets one re-run (its prints
showed the server's hand empty, see above). Reply in Russian. Near ~150k context write state here and hand off.

1. Mockup: the approved conifers are round21/src/conifer21.py (defaults: wide 1.5, tiers_k 1.5, pine style 'out',
   TOP_DROOP, PINE_* trunk; HANDOFF «Round 21 — result»), turned per view by round24 conifer24 (fronds re-picked per
   view from the same 3D branches, tiers' depth squash 0.45), feet by round25 feet25.py (124 tap root for thin
   trees...). Run folder: round23/src/setup_run.sh + step0 src/mockup/*.py + round24/src/*.py + round25 + this
   PR's integration/pr1/src/*.py (export_pr1.py, pack_pr1.py, decode_pr1.py, chk_pr1.py, reenc_pr1.py, gsheet.py).
2. Export: export_pr1.build(key, s, v) goes through trees22.tree / all23 / shapes24 (they draw all 21 species, so
   spruce/fir/larch/pine should build; check). Check leaf_layer's encoding for frond modules (style of the 124
   fronds: share codes, `top`, outline t0) against decode_pr1 / chk_pr1 pixel for pixel, as for the maples (PR 1
   found the maple outline half a step off only by this check). drop(): the 20% crown lowering was the user's ask
   for the broadleaf crowns; conifer tiers start low, so compare heights with the old game conifers first and ask
   before lowering anything. Export takes ~70 min for 14 species (8 workers); reenc_pr1.py re-encodes leaf bits.
3. Pack: pack_pr1.py with `since: 2` written into the conifers' look.yaml (TreeLooks `since`), and
   WorldCells.TREE_LOOKS = 2 in the same PR, or chunks saved by PR 1 grow nothing / the old conifers stay old.
   probe_cap keeps standing_look able to tell stumps (check generation_test «stump N» for each conifer).
4. Game: trees.yaml `picture: tree/look.yaml` for spruce, fir, larch, pine (Growth.grow takes _pictured before the
   shape's _conifer once `pictures` is set); larch drops its needles (bare frames in winter: check tree.gdshader's
   season path for a needle tree); snow on conifers is PR 4. Atlas: tree_sprites packs every pictured species into
   one atlas (ATLAS_W 4096, PR 1 = 3760x1992, ~43 MB video memory): 4 more species may need a second row band or a
   smaller cell; check the phone budget (rendering pitfalls doc).
5. Tests: generation (_test_pictured, stumps), mesher _test_patch («taiga» exercises conifer crowns), store, save,
   server; then shots `tools/shot.gd -- <dir> --phone pics-spruce[-v][-t][-c][-h][-s][-f]` and sheets with gsheet.py.

## PR 2 (conifers): state (2026-11-25, thread «Доделываем остальные»)

- Branch `claude/project-thread-t83h65` (not pushed until the user's OK). Tools: integration/pr2/src/
  (export_pr2.py: build/frond_bits/frond_layer/bare_twigs/frames; decode_pr2.py: numpy of tree.gdshader frond_step;
  chk_pr2.py <npz> <key> <s> <v>: pixel check vs the mockup; pack_pr2.py <export dir> <repo>). Export of the 4
  conifers ~35 min on 4 cores (`python3 export_pr2.py <out> [keys] [workers] [sizes]`), run from the run folder's src.
- Frond G-buffer: R,G octa crown normal (pine caps: the cap's ball normal per texel), B the side axis angle
  (256 = full turn), A = 128 | pos | stroke<<1 | rank<<2 | root<<4 | tip<<5 | deep<<6; the core mass a == 1 as PR 1.
  Ramp row texel 11 red = rule (TreeLooks.MODULES 0 / FRONDS 1). Differences vs mockup only at band thresholds
  (8-bit normals), as PR 1.
- Heights: spruce/fir/larch match the old game; the pine is ~20-35% lower than the old pine (approved mockup kept;
  asked the user). No 20% crown drop for conifers (tiers start low).
- Trunk cells: the drawn trunk's top (conifer trunk runs up inside the crown, like Growth._conifer), capped by
  probe_cap, decreasing by size: spruce 9/14/18, fir 8/12/17, larch 8/12/17, pine v0 6/10/11, v1 7/8/11.
- Larch bare frames = winter23.twig2 without snow lumps (snow on conifers is PR 4). Evergreens: autumn tint mixed
  0.15 (info.y 0.6), as leaves.gdshader.
- Atlas with conifers ~3880x2522 (~56 MB video memory RGBA8 + LA8; PR 1 alone ~38 MB): not optimized yet; PR 6
  could split per climate or halve cells if phones suffer.
- Tests: generation 123/0 (new _test_regrow_conifer; the crowns' broad-leaves-and-needles check replaced by «the
  strips' pictured trees stand as their looks»), mesher 28/0, shapes 33/0, store 20/0, save 120/0, server 193/0,
  validate, report, lint, doc_index, lang_check, parse 367.
- Shots: tools/shot.gd -- <dir> --phone pics-<tree>... and new presets taiga, pine-wood. Old-game shots for «было»:
  stash the 4 trees.yaml `picture:` lines. Sheets integration/pr2/156 (old | new), 157 (light, camera turns),
  158 (larch autumn 80/58/35/17% = f0/f50/f70/f85, winter, evergreens' autumn/winter, fir spring), 159 (taiga,
  pine wood old | new). PR body draft: planning/trees-pr2-body.md.
- 2026-11-25 15:04 MSK the user (on sheets 156-159): «Сосну выше, ярусов больше ... для средней плюс один ярус, для
  высокой - плюс два». Done in integration/pr2/src/pine_pr2.py (installed by export_pr2.build): the approved pine
  stays under its top umbrella (same draws), the trunk goes on up a tier per added tier (step = the mean gap under
  the top umbrella x STEP_K 1.3: x1.0 merged the tiers into one lump), the old top umbrella becomes a ring on limbs
  (reach x0.9 of the top ring's), the top umbrella on the new top: heights 63 / 115 / 165 px (were 63 / 87 / 112).
  Mockup sheet integration/pr2/160; the pine re-exported (old npz kept in /home/user/out_pr2_pine_old, scratch).
- For PR 6 (found while checking the taller pine, not fixed): tree_sprites.quad_mesh's custom_aabb is 13 units
  tall, enough for the tallest look (166 px = 10.4 units) only while view_slope >= ~0.87; steeper tilts make the
  pictures 1/slope taller in the world (stand_tall), so the chunk boxes (_fit_box shears them) can cull the tops of
  trees whose chunk lies just south of the screen. Refit the box by the slope (refit_boxes runs on every tilt).
- 15:22 MSK the user: «Ярусы еще сильнее разнести друг от друга по вертикали»: the added tiers now stand STEP_K x the
  approved gap apart over the approved top ring (sheet 161: А x1.6 = 63/134/189 px, Б x2 = 63/152/213 px; asked,
  А recommended). А exported, packed (pine block 1016x932, trunks v0 6/10/11, v1 7/8/15), in game sheets 162-163,
  committed 8b05c55 with TreeSprites.tallest (quad_mesh box as tall as the tallest look). Waiting for А/Б + OK.
- 15:58 MSK the user: «Нужны более плоские ярусы. То есть один ярус - несколько веток с зонтиками на примерно одной
  высоте, следующий ярус - тоже несколько веток на одной высоте, верхушка - тоже самое». pine_pr2.py rewritten: the
  pine's crown is whorls (3-4 limbs at one height, each an umbrella of 2-3 twigs rising 5-20 deg; the top a narrower
  whorl), lowest tier where the approved lowest ring was, tiers evenly up to the sheet-161-А top (thin 2 tiers,
  medium 3, thick 4; heights 63/134/189). Whorls drawn with conifer21's 0.45 squash still read as tall ellipses, so
  the pine has its own depth squash ZS_PINE (squash(key) sets C.ZS/VIEW/SUP per conifer in export_pr2.build; pack
  reads C.ZS for the crown cells): sheet 164 А 0.2 (recommended) / Б 0.3. А exporting (all 3 pine sizes; the
  sheet-162 ×1.6 npz kept in /home/user/out_pr2_pine_a16).
- 16:13 MSK the user picked Б (ZS_PINE 0.3, «ярусы глубже»). The А export was stopped; pine_pr2.py ZS_PINE = 0.3
  (library copy updated); the pine re-exporting into /home/user/out_pr2/pine (scratch; all 3 sizes), then
  chk_pr2, pack_pr2 pine, import, run_tests generation store mesher shapes, phone shots (pics-pine, -v1, -h30, -h70,
  -c2, -c5, -s3, pine-wood) as sheets 165+, the user's OK, then the PR (body: planning/trees-pr2-body.md, its pine
  bullet to be rewritten for the whorls and squash 0.3).
- Б exported (chk_pr2: 0.75% / 0.73% of pixels a band step off, none missing, bare exact), packed (pine block
  1024x902; pictures up to 82 / 153 / 213 px over the ground; trunks 7/9/10 both variants), generation/mesher/shapes/
  store 204/0, lint, doc_index, lang, parse 367. tools/shot/shots.gd: `pics-<tree>-n<cells>` steps the player north
  (pics-pine-n8 shows the thick pine whole). In-game sheets integration/pr2/165 (было 162 | стало, thick whole) and
  166 (morning, evening, winter, camera 90/225, pine wood) posted 2026-11-25 ~16:45 MSK; waiting for the OK.
  Committed locally 8897f5a (push with the PR, after the OK; the classifier refused a push before it).
- 17:07-17:12 MSK the user (on 165-166): «Ярусы должны быть разного диаметра, расстояние между ними тоже разное /
  Ветви должны быть вокруг ствола, не только спереди / Стволы у маленькой и средней тоже должны быть с рельефной
  корой»; «... не видно ни на одном ракурсе, как ствол перекрывает задние ветви с зонтиками»; and a comment on 166's
  pine wood: «Тени на стволах мы еще не делали? Сейчас стволы очень яркие». Done in pine_pr2.py: the gaps between
  tiers GAP_SPREAD 0.8-1.2 x their mean and the reaches of the tiers under the top REACH_SPREAD 0.62-1.08, each spread
  evenly and shuffled by the tree's rng (0.65-1.35 merged a close pair into one clump; the thin pine draws nothing
  new, unchanged); the trunk drawn over the fronds behind its axis (trunk_front: the trunk is the nearest wood there
  and the frond on top has its middle > BEHIND 1.5 px behind; render wrapper on trees22.CTree + export_pr2.frond_layer
  clears those pixels; _wood caches the skeleton's z-buffer per turn); the trunk's bark relief down to RELIEF_R 1.5 px
  (others 3.5; each size's own base texture). Mockup sheet integration/pr2/167; the Б export kept in
  /home/user/out_pr2_pine_b (scratch); re-exporting.
- Trunk shadows (answer to the comment): tree pictures get only their own crown's baked shade (tree.gdshader has
  shadows_disabled), so in a dense wood the ground is shaded and trunks stay lit. Decision card posted: А a PR after
  PR 2 where bark takes the shadow map (a step darker in shadow; recommended), Б a dense-wood darkening, В as is.
- Exported (chk_pr2 0.74-0.78% band steps, none missing, bare exact), packed (pine block 1088x910; pictures up to
  82 / 157 / 212 px; trunks v0 7/12/14, v1 7/8/18), generation/mesher/shapes/store 204/0, lint. In-game sheets
  integration/pr2/168 (165 | now, thick whole) and 169 (light, turns, winter, pine wood) posted ~17:50 MSK; waiting
  for the OK. Committed locally acd4ff0 (ahead 2, push with the PR). PR body pine bullet updated.
- 2026-11-25 19:06 MSK the user picked А on the trunk-shadow card: a separate PR right after PR 2 (before PR 3):
  bark of every pictured tree takes the sun's shadow map as the ground does, one step darker where in shadow (the
  tree's own baked crown shade and the map's shadow are the same «in shade» step, not two). Read
  docs/systems/rendering/rules.md first; tree.gdshader has shadows_disabled today.
- 19:06 MSK the user OK'd the pine («Все хорошо»): PR #882 opened 2026-11-25 ~19:10 MSK (branch pushed, acd4ff0),
  assigned, watched; merge by hand (squash) on green, then release/deploy. Next: the trunk-shadow PR (user's А),
  then PR 3 (willow + palms).

## PR 2 merged; NEXT: trunk shadows PR, then PR 3 (2026-11-25 ~19:30 MSK)

- PR #882 (conifers) merged 2026-11-25 19:29 MSK (squash 9edbd34) after green CI; main's build/release/deploy
  watched by the PR 2 thread.
- Main's first run failed in `run_tests` only (the tree was identical to the PR branch whose CI passed: a flake;
  which check is unknown, because `get_job_logs` returns at most ~5000 lines and server_test's warnings filled
  them, and the proxy blocks the logs artifact's blob download); one re-run of the failed jobs went green, release
  v0.4.882 published and deployed 2026-11-25 20:07 MSK. PR 2 is done.
- NEXT (user's pick 19:06 MSK, card «Как затенять стволы тенями соседних деревьев?» → «Тень соседей на коре»): a
  separate PR right after PR 2, before PR 3. The user's comment that started it (sheet 166, pine wood): «Тени на
  стволах мы еще не делали? Сейчас стволы очень яркие» — in a dense wood the ground lies in the canopy's shadow
  but every trunk stays sunlit.
  - Today: tree.gdshader is `render_mode ... shadows_disabled`; a picture's bark pixels carry 2-bit steps for 8
    suns (a == 2), baked with the tree's OWN crown shade (render16 `_crown_shade_px`); fronds/leaves have their
    own rules. Neighbours' shadows never reach a picture.
  - Wanted: bark (wood pixels, maybe the bare frames' twigs too) takes the sun's shadow map where it stands, like
    the ground (common.gdshaderinc toon light: `attenuation`, sun_shadowed, compat_sun; Compatibility draws the
    sun in a pass of its own), and is one bark step darker in shadow. The own crown's baked shade and the map's
    shadow are the same «in shade» step (not two steps), and the tree's own shadow caster must not shade its own
    bark twice (or acne on the upright quad: check how trees cast shadows first). Phone cost matters (~10x slower).
  - Read docs/systems/rendering/rules.md and pitfalls.md first; shaders with a real shadow compile in game
    (ShaderWarmup), web ≤13 textures. Show in-game sheets (pine wood, taiga, a broadleaf wood, morning/noon/evening)
    before the PR, as for PRs 1-2.
- Then PR 3 (willow + feather/fan palm, the fan palm a new species), PR 4 seasons, PR 5 felling, PR 6 clean-up (see
  «PR order» and the PR 6 note on the tree box vs steep tilts above).

## Trunk shadows + world-fixed sun: state (thread «Затенять стволы тенями соседних деревьев», 2026-11-25 ~20:10 MSK)

- Branch `claude/project-thread-p0xqf3` (not pushed yet), on main 9edbd34. Changed: `shaders/tree.gdshader`,
  `docs/systems/chunks.md` (tree pictures paragraph), `tools/shot/shots.gd` + `tools/shot.gd` (new shot names
  `wood-<biome>[-h<time x100>][-c<turn>][-s<season>][-f<leaf fall x100>]`, grass hidden). Lint/doc_index/lang/parse OK.
- The user's later asks (16:39 UTC, relayed by the coordinator) folded in: «нет теней от солнца на стволе (с любой
  стороны освещён, если вращать камеру)», «если солнце светит спереди, а камера смотрит сзади, всё должно быть в
  тени». Told the user: this PR = light on the trees; NEXT PR in this task = tree shadows on the ground by the new
  shapes; stumps/felling stay PR 5; trunk collisions = a separate thread (coordinator).
- What the shader does now:
  1. Sun fixed in the world: L = the sun in the frame of the drawing shown (the camera's REST view: x right,
     y up, z toward the camera); the tree's own turn does not enter (the frame is what the camera sees). The old
     code used the world sun as frame coords, so every turn was lit the same.
  2. Back sun (L.z < 0): the bark's 8 drawn suns are all on the viewer's side, so L is mirrored (|L.z|) and the
     bark drawn a step darker (`in_shade`), crossfaded over SIDE_BLEND 0.08 of L.z. Leaves/fronds use normals,
     any L works (looking toward the sun the crown is dark with a lit rim).
  3. `shadows_disabled` removed: in light(), bark texels (varying `bark_shade` >= 0) with ATTENUATION < 0.5 get
     `sun_as(lit, ALBEDO, bark_shade)` = the sun light that makes the final colour equal the shaded step drawn
     (Compatibility adds the sun pass in sRGB: inverted exactly; Mobile emulated like compat_sun). Leaves ignore
     the map (their own light). Shaded step = clamp(open-1, max(s-1,0), s): `open` = the bare frame's step
     (no crown shade baked), `s` = the drawn step -> one shade, never two.
- Shown 2026-11-25 ~20:10 MSK: sheets integration/shadows/170-174 (pine wood, taiga, broadleaf+birch, solitary,
  camera turns; before|after; tool integration/shadows/src/pair_sheet.py). User OK 2026-11-25 21:58 MSK («Все
  хорошо») -> PR #884 opened (commit 54d37fa), assigned, subscribed; merge by hand (squash) on green CI.
- Mobile renderer checked locally: `apt-get install mesa-vulkan-drivers` (lavapipe), then shot.gd with
  `VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json ... --rendering-driver vulkan --rendering-method mobile`.
- Checks: before/after diffs at c0 change only bark (+ sun-ray/see-through animation noise); frame times on
  llvmpipe no visible change; ask the user to check phone FPS after release.
- PR #884 MERGED 2026-11-25 22:05 MSK (squash 397ff88); main green, release v0.4.884 + Pages deploy 22:28 MSK.
  Asked the user to check phone FPS in a dense wood.

## Ground shadows PR: start here (next thread, written 2026-11-25 ~22:10 MSK)

- The user's ask (2026-11-25 19:39 MSK, message cmsg_01VncajcXfgWeRUmc4TVqycgBF3CDB8q63r1DMwukhp43y): «тени от
  деревьев на земле». Told the user it is the next PR right after #884 (stumps/felling stay PR 5; trunk collisions
  are a separate thread). Same flow as #884: in-game phone sheets first (mockup vs game; morning/noon/evening;
  summer/autumn/winter; a camera turn), the user's OK, then PR, merge on green, release.
- Today (main 397ff88): pictured trees' ground shadows are the old system: flat shadow-only discs, one per crown
  level, an ellipse round the level's crown points (look.yaml `crown` bit grids -> Foliage._crown_levels ->
  `_tree_shadows` / `_cone_shadow` for tiers) drawn by leaf_shadow.gdshader on PixelView.LAYER_SUN_CASTER
  (ragged edge, shrinks with leaves_left, discards when no leaves: a bare tree casts NOTHING). No trunk or limb
  shadow (the trunk mesher skips pictured trees; the trees MultiMesh has cast_shadow OFF).
- The approved mockup (round23/113 etc.; render7 `t.shadow()` = shadow-only ellipsoids per crown part + a trunk
  cylinder): one soft-edged blob following the crown's outline, offset from the sun, plus a trunk strip from the foot.
- Recommended design (not tried yet):
  1. A silhouette card per pictured tree: a second MultiMesh beside the chunk's `trees` (same instance data,
     `cast_shadow = SHADOWS_ONLY`, layer LAYER_SUN_CASTER, new shaders/tree_shadow.gdshader). The quad stands on
     the foot turned to the light as leaf_shadow's bush disc is (`to = INV_VIEW_MATRIX[2].xz` in the ortho light
     pass); its picture = the frame of the side nearest the sun (the step of the light's direction + the tree's
     own turn, as tree.gdshader's vertex picks `side`), alpha = leaves by the same autumn rule (leaves_left + the
     bundle's edge rank) or wood from bare_frames, so a bare tree casts its trunk and limbs.
  2. Push that card away from the sun by the trunk's radius (+ bias): the tree's own bark must not take its own
     card's shadow (its shade side is drawn already; in_shade would darken it twice).
  3. Keep the crown discs for a high sun (an upright card's shadow shrinks to a strip at noon): discs = footprint
     at noon, card = the side silhouette stretched at low sun. If the blob is too round, several discs per level
     (clusters of the level's points) instead of one bounding ellipse.
  4. Check acne at the foot, cost (one more instance per tree, shadow pass only, discard = no early z;
     frame_test in CI), web <= 13 textures, ShaderWarmup of the new material, Mobile (lavapipe recipe above).


## Ground shadows PR: state (thread «Сделать тени деревьев на земле по новой форме», 2026-11-25 ~23:00 MSK)

- Branch `claude/project-thread-fpicrn` off main 397ff88; not pushed until the user's OK (task order: show, OK, PR).
- Done (differs from the recommended design above):
  - `shaders/tree_shadow.gdshader` on a 2nd MultiMeshInstance3D per chunk (`tree_shade`, chunk node index 8, after
    `trees`; it SHARES `trees.multimesh`, so `_apply_plants` fills both), cast_shadow SHADOWS_ONLY, layer
    LAYER_SUN_CASTER, material `main.tree_shadow_mat` (TreeSprites.dress). Vertex: the picture stands at its foot
    ACROSS the way the shadow falls (`falls` = (0,-1) - sun_xz / sun_view.z = PixelView.light_dir's w, world-fixed;
    sun_xz rebuilt from sun_view as tree.gdshader does), frame = the side the light looks at (step of
    atan(-along) + the tree's own turn), sheared (`shear`), and in the shadow pass sunk along the light ray by
    min(0.4, 0.75 x height): the shadow on the ground stays, the tree's own bark no longer takes it (Compatibility
    computes shadow coords in the vertex shader, so LIGHT_VERTEX can't bias the receiver). Fragment: leaves by
    leaves_left + edge rank + hash (tree.gdshader's autumn rule), core a==1 by r, else bare_frames wood, discard.
  - Point 3 dropped: NO discs for pictured trees. The game's sun keeps |w| >= ~1.6 all day (morning t0.3
    (-1.74,-1.97), noon (-0.29,-1.63), evening t0.7 (0.38,-2.95)), so the upright card never shrinks to a strip.
    `Foliage.step` skips `_tree_shadows` for trunks with `Growth.standing_look >= 0` (the same test that skips
    their crowns); young trees, palms (leaf clusters), stumps keep their discs.
  - draw_census parts += "trees", "tree shadows"; generation_test `_test_pictured_shadow` (pictured species
    casts 0 discs, a leaf-cluster species > 0; Growth.place needs a seeded rng); docs chunks.md,
    rendering/shadows-shaders.md; shots `pics-...-o` (was -x0; -x went to #883's collide/xray) hide the trees
    (RenderToggles "chunks: trees") to show the shadows alone (main has no "trees" census part: hide "shader: tree.gdshader" there).
- Checked: lint, doc_index --check, parse_check 367/0, generation 125/0, mesher 28/0; Mobile (Vulkan lavapipe)
  shots match; ShaderWarmup picks the new node up (59 -> 60 kinds); web samplers 9 (frames, bare_frames + 7).
- Look: the new shadows are the trees' outlines attached at the foot by the trunk strip; ~2x the area of the old
  discs (old ones were narrower than the crown); a true 3D crown at this sun would cast even a little longer.
  Bare winter trees and deadwood now cast limb shadows (before: nothing). In woods nearly no change.
- Profile (tools/profile.gd --phone, software GL, before | after): day 201 | 198 ms a frame, calls 264 | 295;
  forest 150 | 112 ms, calls 173 | 191 (one more shadow-pass call per chunk with pictured trees, far fewer
  disc instances); game code unchanged (~3.4 ms). Fast checks + run_tests generation mesher shapes store green;
  committed locally af9ff98 (not pushed).
- Shown 2026-11-25 ~23:00 MSK: integration/ground-shadows/175-180 (175 light + mockup strip, 176 conifers,
  177 seasons, 178 camera turns, 179 woods, 180 shadows alone), with a decision card: length А = by the game's
  sun as now (recommended) / Б = about half as long, like the mockup's hand-drawn shadow.
- Next after the OK: commit, PR (Что нового [улучшено] x2 + [ядро] for x0 shots; What's new lines), merge on
  green, release; then PR 3 (willow + palms).
- Tooling lessons: a 2nd git worktree needs every `*.import` file copied from the main checkout (else shot.gd
  renders magenta, fonts fail); concurrent Godot runs need separate XDG_DATA_HOME; befores = worktree
  /home/user/survivium-main at main.

## Ground shadows PR #885 MERGED; crown shadows next (2026-11-25 ~23:40 MSK)

- User picked length А (by the game's sun) 23:21 MSK; PR #885 (one commit, rebased on #883) CI green after one
  re-run of `frames` (the "back to the surface" step timed 29 ms of chunk work on a slow runner, main 19 ms);
  MERGED by hand (squash 4cf289d) ~23:36 MSK. Main's run waited behind #883's re-run; release v0.4.885 = see below.
- User asked 23:21 MSK «А тени от деревьев на кроны деревьев будут сделаны?», agreed 23:23 MSK («Да, хорошо») to a
  SEPARATE PR right after #885, shown with sheets first. Work on local branch `crowns` (commit e660755 + edits),
  NOT pushed; after the OK: `git checkout -B claude/project-thread-fpicrn origin/main`, cherry-pick, new PR.
- Crown shadows design (tree.gdshader + tree_shadow.gdshader):
  - Leaves/fronds also get a `shaded` colour (varying renamed from bark_shade): leaf_steps()/frond_steps() return
    vec2 (x lit, y in a shadow: a bundle as on the crown's shaded side d=-1, base 2, cap 5, the quarter-light
    rule; fronds' band capped at 2). light(): `shaded.r >= 0 && ATTENUATION < 0.5` -> sun_as(lit, ALBEDO, shaded).
  - No self-shadow: the caster picture's sink is per tree, `deep = SINK + half_w * |right . along| / |falls|`
    (half_w = the frame's widest half from the axis, in units), reached at a KNEE row: quad rows -1 foot, 0 knee
    (height min(deep / SINK_SHARE, top)), 1 top; sink = min(deep, SINK_SHARE x height) so the ground shadow is
    unchanged (no point sinks below the ground). tree_sprites.gd quad_mesh doc mentions the 3 rows.
  - Shots (cb = #885 head, ca = crowns): single trees change a little (evening oak: middle oak shades the top oak's
    lower crown; spruce/pine: tiers shaded by the neighbour); woods change a lot (pine wood at morning nearly all
    in shade). Turned views (c2/c4): no self-split; a root that #885 self-shadowed at 90° is now lit.
    Vulkan Mobile matches GL (only near-black rounding).
- Shown 2026-11-25 ~23:55 MSK: integration/crown-shadows/181 (single trees, variant А), 182 (woods, А), 183 (before | А | Б).
  А = a leaf in a shadow as on the crown's shaded side; Б = a step darker, never darker than the shaded side (as the
  bark). User picked Б 23:59 MSK. Final code: leaf_steps/frond_steps return vec2(lit, max(lit - 1, shaded side)).
- PR #886 «Tree crowns take the shadows of the trees around them» opened 2026-11-26 00:05 MSK on the restarted
  branch claude/project-thread-fpicrn (one commit 017a568 on main 4cf289d); merge by hand (squash) on green, then
  release v0.4.886. Profile (software GL, phone): forest 107 | 110 ms, day 111 | 107 ms (noise), calls same.
- NEXT after #886: PR 3 (willow + palms), start from «PR 2 (conifers): start here» pattern and HANDOFF.
- #886 MERGED (squash 14ba194) 2026-11-26 ~00:08 MSK; main's `frames` failed («back to the surface» 30–32 ms of
  budgeted work > 26.3, a chunk 29.3 ms), passed on one re-run: v0.4.886 released + deployed 00:46 MSK.
  Root cause (reproduced locally, not the trees): the cave is found round where frame_test's first walk ended,
  so on a slow runner it can lie > 8 chunks (reach + UNLOAD_EXTRA) from the start; the start's chunks unload and
  after the teleport back the streamer rightly takes JUMP_BUDGET_US (30 ms). Fix: frame_test PR #887 judges the
  frames just after a jump while the screen lags by the jump budget (`_jump_budget`), row in TEST_COVERAGE.md.
- PR #887 (frame_test jump budget) green on a slow runner (a chunk 28.9 ms) and MERGED 2026-11-26 00:59 MSK
  (squash 6f32122); main's run gives v0.4.887. PR 3 (willow + palms) already runs in its own thread «Встроить иву и пальмы в игру (PR 3)».

## PR 3 (willow + palms): state (thread «Встроить иву и пальмы в игру (PR 3)», 2026-11-26 ~01:30 MSK)

- Branch `claude/project-thread-t73ws8` from main 6f32122 (#887). Not pushed until the user's OK.
- Tools: integration/pr3/src/ (export_pr3.py, decode_pr3.py: numpy model of the shader rules, `python3 decode_pr3.py
  <exp> <key> <s> <v> [turns]` prints per sun (missing px, px off > 2, px); pack_pr3.py <exp> <repo> [keys]). Run
  folder /home/user/run = setup_run.sh + step0 mockup + round24 + round25 + pr1 + pr2 + pr3 src.
- Willow: rule `hanging` (live, tree.gdshader hanging_steps): R,G module normal, B cap blade way or strand dx+32 |
  place<<6, A code 0 cap / 1 strand / 2 far-curtain strand in the voids (base 2). Checked exact vs mockup except
  ~300 px at sun 4 where one module's n.L = 0.641 vs D1 0.64 (8-bit normal, as PR 1).
- Palms: rule `palms` (baked, as bark): 8 suns x 4 bits half steps in R,G,B + bare L (palms keep their leaves:
  TreeSprites._year_kind gives rule PALMS the evergreen year, so the bare texel under a leaf is free); A 128 | soft
  outline; trunk A 2 wood / 3 soft outline (mix half way to bark step 0). Checked pixel-exact at all 8 suns.
- Fan palm = new bundle content/plants/fan_palm (no seed; logs + twigs); old worlds never get it (Mods.of_world: a
  bundle with trees never joins an old world), so no species remap is needed (the plan's gotcha was wrong). Oasis
  palm 0.3 + fan_palm 0.3 (was palm 0.6); jungle palm 0.22 + fan_palm 0.08 (was 0.3).
- TREE_LOOKS = 3, look.yaml `since: 3`. tools/tree_feet.py counts alpha 3 as bark.
- Exported (/home/user/out_pr3, ~25 min on 4 cores), packed, tree_feet written, imported. Willow trunks 6/8/10,
  palm 7/9/12, fan palm 2/3/5 cells. Shots: /tmp/sh (old ones with the 3 `picture:` lines, fan_palm bundle and the
  biome shares reverted). Sheets integration/pr3/184 (было|стало), 185 (light, turns), 186 (seasons), 187 (jungle,
  floodplain) shown 2026-11-26 ~02:00 MSK with questions (palms evergreen; oasis shot found no palms). Not committed yet.
- Main after #887 green at once: v0.4.887 released + deployed 2026-11-26 01:17 MSK. Shadows thread done.
- User OK 2026-11-26 01:31 MSK («Ок»; palms evergreen = А by default). Checks green; PR #888 opened (branch
  claude/project-thread-t73ws8, dd47a4c), assigned, watched. Merge by hand (squash) on green, then release/deploy.
  Next after #888: PR 4 (seasons: snow, blossom, dry leaves).
- #888 MERGED 2026-11-26 ~01:53 MSK (squash c89254e) on green CI. Watching main's build/release/deploy.

- 2026-11-26 ~02:08 MSK: PR #888 merged (squash c89254e), main CI green, released v0.4.888 and deployed. PR 3 DONE. Next: PR 4 (seasons), only when the user says.

## PR 4 (seasons: snow, dry leaves, blossom): state (thread «Встроить снег и цветение деревьев (PR 4)», 2026-11-26 ~03:00 MSK)

- Branch `claude/project-thread-4mlv6y` from main ec2bf79 (#889). Not pushed until the user's OK.
- Tools: integration/pr4/src/ `export_pr4.py <out> [keys] [workers] [sizes]` (per look an npz: ox, oy, box, `bare`
  the twigged bare tree as bare16 at 8 turns, `snow`, `snow_dry` uint16 codes; ~1.5 h for 16 species on 4 cores) and
  `pack_pr4.py <exp> <repo> [keys]` (re-runnable: re-lays every cell with even heights, writes bare.png with twigs,
  snow.png / snow_dry.png LA8 = low byte, high byte; look.yaml keys `snow`, `snow_dry`, `dry` (winter23.dry_ramp),
  `blossom` (spring23.BLOOM), `evergreen: true` for acacia, ceiba, mangrove, palm, fan_palm). Run folder
  /home/user/run as PR 3 (round23 src: bare23, winter23, spring23).
- Snow code: see the header of shaders/tree_snow.gdshaderinc (kind 2 bits, mode bit, ball/cap octa normal 5+5 bits
  + shade 2 bits + cap bit, or a frond's two tones + side bit; code 1 = a leaf under the snow's edge a step darker).
  Codes fitted over FIT_SUNS: ~4-5% px a step off at a given sun (the 10-bit limit), the export prints them (`bad`).
- tree.gdshader was at 13 samplers (lint max): the ramps texture is gone, the ramp rows lie under the frames atlas
  (`TreeSprites.ramps_at`), RAMP_W 28 (DRY_AT 12, BLOSSOM_AT 19, SNOW_AT 26 = where the species' snow lies in the
  `snow` atlas from its frames, two bytes each, x 32768 none); `snow_frames` is the freed unit.
- Atlas places must be even (instance data are half floats on some GPUs): PR 1-3 packs had odd cell y's, pack_pr4
  makes every cell height even for all 21 species (pictures checked identical after the re-lay).
- Year: KEEPS_LEAVES trees (oak, linden, willow) show the whole crown in the `dry` ramp with snow_dry caps; GOES_BARE
  trees the bare tree with twigs + snow balls once leaves_left <= 0.1; conifers snow on fronds; larch bare + lumps;
  deadwood lumps on its limbs; hot species evergreen (no snow). Snow comes in 3x3 texel blocks as snow_amount grows
  (0.05..0.6). Blossom: look.yaml `blossom` ramp, 80% of leaf modules by hash < blossom_amount * 0.8, crosses.
  trees.yaml `blossom` colours added for apple, rowan, acacia (young trees, Foliage).
- Shots: `pics-<tree>-s3-d1|d0` (trees keeping dry leaves / going bare), `-w<snow x100>`.
- 2026-11-26 ~03:25 MSK: exported all 16 species (96 looks, /home/user/out_pr4), packed all 21, tree_feet --check OK,
  Mobile (Vulkan lavapipe) renderer checked. Partial snow: balls grow from the middle (normal z >= sqrt(1-g^2)), frond
  snow from the frond up (FROND_DEEP 4); the first 3x3-block hash looked like noise. Phone sheets
  integration/pr4/188-193 shown, waiting for the user's OK; then checks, commit, PR (body drafted in the thread).
- 2026-11-26 ~03:50 MSK: FOUND a bug from PR 1: the PNG import's fix_alpha_border (default ON, .import gitignored)
  gives RGBA8 texels with alpha < 20 a nearby leaf's RGB, so the bark (alpha 2), dark mass (1) and palm outline (3)
  near leaves lost their steps in game (Content.live is false: local shots read the import too). Fix in this PR:
  pack_pr4 stores codes 1-3 as 65-67, shaders read `frame_code(g)` (a < 128 ? a & 63 : a), tree_feet BARK (2, 3, 66,
  67); include renamed shaders/tree_pictures.gdshaderinc. Verified: import keeps every drawn texel now; summer frames of
  all 21 species identical to main except the alpha codes. Sheet integration/pr4/194 (bark before/after).
- 2026-11-26 ~03:45 MSK: user OK («Все хорошо», 03:35 MSK). Rebased on main 8423742 (#890; pitfalls.md conflict merged),
  checks green, pushed; PR #892 opened (fe7c9d0), assigned, watched. Sheets 188-193 re-shot with the bark fix, 194 the
  bark before/after. Next: merge by hand (squash) on green CI, watch release/deploy; then PR 5 (felling/stumps) only
  when the user says.
- 2026-11-26 ~04:00 MSK: PR #892 CI green (all 13 jobs, progress too), MERGED by hand (squash 00a8b06). Watching main run
  45732760184 (release v0.4.892 + deploy). PR 4 DONE once deployed. Next: PR 5 (felling, stumps, logs, fallen and
  broken trunks: round 23 step 3 + round 24 pieces + round 25 feet) only when the user says.
- 2026-11-26 04:31 MSK: main run 45732760184 failed `tests` once (run_tests; its FAIL line hidden behind >5000 lines
  of server_test in the log, artifacts unreachable; main == the green PR head, local run_tests 7783/0); one rerun
  passed, release v0.4.892 published (APK/Windows/Linux) and the site deployed 04:31 MSK. PR 4 DONE.

## PR 5 (stumps, felling, fall): state (thread «Встроить пни и новую рубку деревьев (PR 5)», 2026-11-26 ~04:40 MSK)

- Split: PR 5 = stumps + felling rules + fall; the world pieces (log, fallen trunk, broken trunk with a sprout lying
  in forests, decision 5А) = a separate PR after it (not started).
- Branch `claude/project-thread-fca6fc` (WIP commit pushed, no PR yet). Run folder /home/user/run as before + pr5 src.
- Export: integration/pr5/src/export_pr5.py <out> (stump23/stumps24 + feet25, 3 sizes, 8 turns, summer + winter snow
  layer, 8 suns; classified by colour: codes 2 bark, 3 palm soft outline, 4 cut wood (3 bits a sun, 6 = resin), 5 snow,
  6 snow outline; stored alpha +64; ~7 min on 4 cores, 0 unknown colours; palms ~100 texels change kind across suns) ->
  /home/user/out_pr5; pack_pr5.py <out> <repo> writes content/plants/<k>/tree/stumps.png (a row a size: 8 summer turns
  then 8 winter, cells even) and look.yaml lines (wood, stump_frames, stump_snow, stumps).
- Game: TreeLooks reads them; Growth.stump_look (one log cell on its foot, size = look_index at scale 1); TreeSprites
  packs stumps after the trees in the frames atlas (RAMP_W 36, WOOD_AT 28), instances colour alpha STUMP -1 /
  STUMP_SNOW -2 (winter row from snow_amount 0.3); tree.gdshader stump branch (wood_colour, stump_colour);
  tree_shadow casts them; chunk_mesher skips their log cell. Felling: pictured species keep the foot log always (cut at
  max(cut, foot+1)); chopping a 1-cell stump = Felling.uproot (one log; half the hits); Felling.clear ignores stumps as
  "other trunks" (left crown pieces floating as old foliage before). Old taller stumps stay in cells.
- Fall: chunk_streamer compares the chunk's standing trees before/after a rebuild (TreeSprites.build's 3rd element);
  standing -> stump calls TreeHits.fall: a one-instance MultiMesh under game.world_root (custom_aabb round the foot!),
  tree.gdshader `falls`/`fall_ways`: turns about the stump top (FALL_CUT 0.5) away from the last blow's `from`, t^2 over
  1 s, bounce, fade 0.4 s.
- Shots: `stumps-g<0..2>[-s3-w80][-f<n frames>]` (tools/shot.gd + places.stumps). Sheets integration/pr5/195 summer,
  196 winter, 197 fall (8 frames 0.2 s apart). Known: falling picture's trunk base overlaps the stump's face a little
  (cut 8 px vs the stump's height); orange snow-free squares in the winter shot (probably the shot's crown clearing).
- TODO: user's OK; tests (generation stump tests, progress _fell, store/save, security?), docs (systems page for
  trees/felling, docs/planning copy), «Что нового», PR, merge, release; tell the coordinator on merge (building-UX waits).
- 2026-11-26 ~04:50 MSK: sheets 195-197 shown with one question (fall overlap: А as is, recommended / Б cut higher).
  run_tests 7783/0, save_test 120/0, server_test 193/0 green on 2d7cbf0 + Felling.clear stump fix (committed).
  Still to do: a generation/unit test for the stump rule and uproot, progress_test other (felling) locally or CI, docs.
