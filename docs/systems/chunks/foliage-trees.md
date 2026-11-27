# Foliage, tree sprites, edge haze

Part of [Chunks on screen](../chunks.md). Grass, plants and crowns, standing trees, the fog at the edge, buffers.

- `src/client/world/foliage.gd` — the chunk's grass, plants and crowns as a MultiMesh, also by column. Along
  the foot of a pictured tree or stump standing on grass (`_foot_grass`) a row of tufts, now and then a
  mushroom, covers the picture's lower edge: as wide as the roots drawn (look.yaml `foot`, `FOOT_SIDE` more),
  `FOOT_STEP` pixels apart; each stands on the tree's axis and carries its place in its 4th custom float
  (`FOOT_MARK`), and `grass.gdshader` puts it aside and a few pixels in front of the foot in the camera's
  view, so the row is in front from every side the camera turns to. Its fog is taken `FOG_AHEAD` in front of
  the tree, as the tree's own (`fog_root`): on the axis `fog_at` takes the trunk's column top for ground, and the
  row stood bright over a fog.
- Stumps and the fall (trees PR 5): a felled pictured tree always leaves its foot's log (`Felling.fell`; struck
  again, `Felling.uproot` takes it for one log in half the blows), drawn by `TreeSprites` as a picture too
  (`Growth.stump_look`; TreeLooks `stumps`, `stump_frames`, `wood`: the approved stump at 3 sizes, 8 turns, summer
  and winter with snow on the cut; instance colour alpha `STUMP` / `STUMP_SNOW`, `tree.gdshader` `stump_colour`:
  bark as the trees', cut wood, snow and its outline 3 bits a sun); the chunk mesher leaves its log cell undrawn.
  A standing tree that is a stump after a chunk's rebuild falls (`TreeHits.fall`, `tree.gdshader` `falls`): it
  turns over about the stump's top away from the last blow in a second, bounces and fades out, its own MultiMesh
  of `1 + 2 *` modules instances (colour blue + `FALL_MINE`; the chunk's copy at the same foot until rebuilt is
  left out). It is drawn by the falling trees' copy of `tree.gdshader` (`main.tree_fall_mat`,
  `TreeSprites.falling`: the code with `FALLING` defined, built ahead by `ShaderWarmup`); the felling's code
  below is under `#ifdef FALLING`, so the chunks' trees draw without it: in their shader too, the Adreno 840
  (Android, Vulkan) drew no tree at all, standing or falling, though the shadows were there (v0.5.912 to
  v0.5.919: the shader took 30 varying slots there, of 28), and the copy alone drew nothing either (v0.5.926 to
  v0.5.929) till its own varyings were packed into one (`fall_tile`) and its sway left out (`tools/lint.py`
  `MAX_VARYINGS`, [pitfalls](../rendering/pitfalls.md)). The crown's module search (576 steps a vertex) is one loop counted in whole
  numbers, its length from a uniform (`FALL_SEARCH`, `fall_count`), which a compiler does not unroll. Instance 0
  draws the trunk and limbs (not leaves) turned on the screen in whole pixels (`INSTANCE_ID > 0` are the modules:
  `(0 - 1) / 2` is 0 on a GPU, so no trunk fell from v0.5.912 to v0.5.929): each pixel
  finds its texel by three shears (Paeth) and whole quarters undone, then the rows' squash (`fall_turn`,
  `fall_shear`, `FALL_ROOM`). The leaves fall as modules (the user's ask): pieces `FALL_MODULE` apart (`FALL_SHAPE`:
  squares, bricks or clumps, the user's pick clumps of 24; `fall_owner` gives a texel's module, edges jagged by
  `FALL_JAG`), each a billboard
  never turned nor resized that hangs on at the middle of its own leaves (found in the vertex from the frames, so a
  module the crown's edge cuts does not hang off), that point turned with the tree and kept on the ground: in each
  row of modules the first down stays on the ground's line, the next rest on it (`FALL_PILE`); each module falls on
  its own clock, up to `FALL_LAG / 2` before or after the trunk (`fall_angle` is `TreeHits.fall_at` again: keep the
  two alike; the fall's seconds come in `fall_ways` z), so they do not land all at once; lying, a module reaches
  back toward the stump no further than its lowest leaves came down along their arc and clears the stump's side
  (`FALL_CLEAR`, the stump's half width from the picture's foot row): a billboard stands up, so it is carried on
  the way it falls as it comes down, and its ring draws nothing further back (the user's ask: the crown lies only
  the way it fell, from where its bottom comes down); empty modules are
  not drawn; each module's ring (`FALL_OVERLAP`, drawn `FALL_RING_BACK` behind) fills the gaps as they move apart;
  lower on the screen is in front (`FALL_ORDER`). Its shadow is its first instance drawn again into the shadow maps
  only (a child sharing its MultiMesh, `tree_shadow.gdshader` with the same `falls` uniforms): the tree's whole
  picture standing across the light as a standing tree's, turned over about the stump's top as the tree is, kept
  over the ground and fading as it fades; the modules and the rows under the cut cast none (the stump casts its
  own), nor does the chunk's copy at the same foot. The wood it leaves (`Props.show_drops`) waits until it lands
  (`TreeHits.landing`, `DROPS_HOLD_MS` at most). A struck tree sheds leaves of its own shape and colours (`TreeHits.LEAF_SHAPES`,
  `particle.gdshader` `frames`/`rows`).
- Pieces of wood lying in the woods (`Growth.piece_look`): drawn as the stumps, instance colour alpha
  `TreeSprites.PIECE`; each of a piece's 16 views (8 turns, summer and winter) is cropped to itself (a fallen trunk
  seen end on is narrow), so its instance's custom data points to its table of views in the frames atlas (two
  texels a view: place; w, h, anchor) that `tree.gdshader` and `tree_shadow.gdshader` read in the vertex; a sprout's
  leaves are alpha 7 (the leaves' ramp). Its shadow is the camera's view of it laid flat over where it lies (`PIECE_HIGH` over the ground, a row a texel deep), and it takes no sun's shadow itself. The kinds'
  rows of views are packed one by one under the stumps; the frames atlas is then 4064 x 3852 (under 4096).
- `src/client/world/tree_sprites.gd`, `shaders/tree.gdshader` — standing trees of species drawn as pictures
  (`Growth.standing_look`): one upright picture per tree in the chunk's `trees` MultiMesh (the last of the
  plant parts), the frame of the side the camera rests at plus the tree's own turn, from one atlas of all
  such species (`setup` at the start; frames RGBA8 hold the leaf's normal, angle and bits or the bark's
  step under 8 suns of the day, their alpha what the texel is (`frame_code`: the codes under 128 stored 64 higher,
  as the import's `fix_alpha_border` gives a texel under alpha 20 a leaf's colour), the bare tree LA8 for autumn
  and winter with its twigs; under the frames a ramp
  row a species from `ramps_at`, its colours and where its snow lies, one texture unit less); lit by the sun in the shader as the
  approved drawing (bundles by normal, leaves by facing), the sun where it stands in the world seen from the side
  shown (turning the camera turns the lit side; looking toward the sun, the crown is in its shade and the bark is
  drawn a step darker, `wood_colour`). The bark is drawn with halftones and an even outline, worked out from a texel's
  four neighbours (`bark_look`): a bark texel beside a darker step takes half a step darker; a texel on the
  picture's edge with bark inside it takes one tone all round (`OUTLINE_LOW`, half a step over the darkest),
  whatever the light; a bark texel low on the picture (`BASE_RISE` over the foot) with nothing under it is the
  drawn outline where the tree or stump meets the ground and is not drawn. A standing tree sways in the wind module by
  module (the global `wind`, `SWAY_*`, `sway_texel`: the leaves cut into the falling crown's clumps, `fall_owner`, each
  moving its leaves by whole pixels on its own clock, more the higher; the bark stays), the picture widened by `SWAY_ROOM`;
  shots `wind-trees-breeze`, `wind-trees-storm`). Each picture is drawn up to `DEPTH_TIE` nearer the camera by its
  foot's hash: trees in one row across the screen stand at one depth, and their overlapping crowns would otherwise
  take turns row by row (stripes). The bark also takes the sun's shadow (the shadow map, as the ground: other
  crowns, hills) a bark step darker, never two under its own crown's drawn shade (the bare frame holds the step
  without it, `in_shade`; `sun_as` gives the sun's pass the colour the shaded step would get); the leaves and fronds
  too, as on the crown's shaded side (`leaf_steps`, `frond_steps`; a palm's leaf as the darkest it is drawn at any
  sun; a step darker was hardly seen, 2026-11-27). A crown takes the shadow as a round crown would, not as its flat
  picture through the trunk: by day each point of the picture looks the shadow up as if the picture leaned toward
  the sun by `CROWN_LEAN` of its half width at the top (in proportion to the height, none at the foot), slid back
  along the light to its own depth (Godot reads the sun's shadow at `VERTEX`, the picture is drawn at `POSITION`),
  so a neighbour's shadow climbs a crown higher (at 17:00 it reached only the lowest leaves) and the tree's own
  picture still casts nothing on it; not at night, when the lamps and fires, lighting the same `VERTEX`, are the
  light. A species'
  ramp row says the rule its leaves are lit by
  (`TreeLooks.rule`): the conifers' frames hold fronds instead of bundles (the crown's normal where the frond lies,
  its side axis, its halves, strokes, root third and tip; a pine cap's texels a normal each on the cap's ball),
  lit as the approved conifers (`frond_steps`); the willow's hold the leaves of its hanging strands (the module's
  normal, a strand's place across the module and down the strand, the cap's leaves, the far curtain seen through
  the gaps low in the crown), lit as the approved willow (`hanging_steps`); the palms' hold their leaves' steps
  drawn at the 8 suns, as the bark's (`palm_colour`, half steps, the soft outline half way to the darkest; a palm
  keeps its leaves, so its bare frame under a leaf holds the last two suns, and `TreeSprites` gives it the
  evergreens' year), their trunks' soft outline alpha 3; evergreens take a little of autumn's tint, as their leaf cards do. Autumn takes the leaf bundles from the crown's edge
  inward (each bundle's rank from the edge is in its frame); under half of them left, the bark is drawn from the
  bare tree, without the crown's shade. In winter a species' snow pictures (TreeLooks `snow`, and `snow_dry` for
  the crown of the trees that keep their dry leaves; packed into the `snow` atlas, where each lies from its frames
  in the ramp row) lie over the bare tree or the evergreen crown: a texel's two bytes say whether it is snow, its
  soft outline or a seam and how it is lit (a ball's or a cap's normal, or a frond's two steps), in the snow's
  6 steps (`shaders/tree_pictures.gdshaderinc`); it comes as the snow cover grows (`snow_amount`), a ball or a cap
  from its middle out, a frond's snow from the frond up. A tree
  keeping its dry leaves (`Foliage.KEEPS_LEAVES`) keeps its whole crown in its `dry` ramp under the snow caps; the
  trees of the hot zones (TreeLooks `evergreen`) and the palms keep their summer crown and take no snow. In spring a
  species with a `blossom` ramp blossoms on most of its leaves (`blossom_amount`), crosses of flowers on the lit
  side. Foliage and the trunk mesher leave such trees out;
  young trees and stumps stay theirs. Their ground shadows are the same instances drawn a second time
  (`shaders/tree_shadow.gdshader`, a node sharing the `trees` MultiMesh, shadows only, on
  `PixelView.LAYER_SUN_CASTER`) instead of Foliage's crown discs: each picture stands at its foot turned across
  the way the shadow falls (the shadow of a unit of height lands where `PixelView.light_dir` lays it, the same
  at every camera turn), the frame of the side the light looks at, so the shadow is the tree's own outline:
  the crown (thinning from its edge in autumn by the picture's rule), the trunk from the foot, a bare or dead
  tree's limbs. In the shadow pass it sinks along the light's ray by `SINK` and the most the picture reaches
  behind it across the camera's view (full from a knee row up, never more than `SINK_SHARE` of a point's height):
  its shadow on the ground stays where it falls, but the tree's own picture, standing behind it at any camera turn,
  does not take it (its shade is drawn), while the other trees' bark and leaves do.
- `src/client/world/edge_haze.gd`, `shaders/edge_fog.gdshader` — the fog above unbuilt chunks (see above).
- `src/client/world/mesh_buffers.gd` — growing vertex buffers; `drifts.gd` — snowdrifts; `tracks.gd` —
  footprints, kept in a map of the ground round the player (`print_map`, repeating every `Tracks.MAP` texels) that
  the ground's shaders read through `footprint()` before the light and the fog, so a fog hides a print as it hides
  the ground; every stride that leaves a print (the player's, the other players', the beasts') also treads the grass
  in `trample.gd` (`trample_map`, a quarter-unit texel: when, which way, how hard, the level), which `grass.gdshader`
  reads through `trodden()` to lay the tufts and the mods' plants over and lower; they stand up again over
  `Trample.LIFE` seconds. Both maps go to the renderer the frame a new print or trodden patch is laid (at most every
  `Tracks.SOON` seconds), so a print never lags the foot; clearing old ones waits for `FLUSH`; `roof_map.gd` — the roof map for shaders (wrapped through `RoofMap.WRAP`; g is `CROWN` under a crown plus `NO_PUDDLE` on a top that drains or slopes and `SLOPED` on a sloping top, `top_bits`) and beside it the map of
  the columns' biomes (`biome_map`: r the biome, g the column's `Chunk.frost`, the snow of the heights it lets lie) with the multipliers of the materials' colour by biomes (`biome_tints`,
  from the biomes' `tints`), and a coarse map of the land's height for the ground fog (`ground_low`: a texel per
  `RoofMap.LOW`² columns, the top three quarters of the way up their tops, so a pit or a trunk does not move it;
  `fog_at` in `common.gdshaderinc` measures low places by it and lays the fog's layer over the higher of it and the
  ground, so pits fill with fog and a hill's edge draws no straight seams). The same texture's g, b, a hold the colour
  of the water there (`RoofMap._water_tints`, read by `water_tint` in `water.gdshader`): the mean over the block's water
  columns of their biome's water tint times their body's (`SEA_TINT` for `WorldData.SEA_WATER`, `RIVER_TINT` for
  `WorldData.RIVER_WATER`, which the generator sets on rivers and canyon floors, `LAKE_TINT` else) and a slow noise
  (`VARY_*`) that shades one lake from the next; filtered between texels, so a river's mouth runs into the sea's colour
  over a few cells.
