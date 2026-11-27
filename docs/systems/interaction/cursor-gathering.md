# Cursor, plan view, gathering

Part of [Hands and the world: digging, building, chopping, mowing, gathering](../interaction.md). The cursor frame, the blueprint's ghost, gathering and props.

- `src/client/input/cursor.gd` — the frame around the cells over which work will happen; `show_boxes` — whole
  cells as see-through bodies over everything (light: white, red), merged with no faces between their cells and a
  light rim one pixel wide along their edges (`PlanGhost.bodies`, `plan_through.gdshader`), above the blueprint's
  ghost.
- `src/client/view/plan_view.gd` — the blueprint's ghost near the player (2026-11-22, until then frames round
  its cells): its blocks as they will stand built (`plan_blocks.gd`: the blocks in a world of their own,
  `ChunkMesher` meshing it a chunk at a time, `COLUMNS` columns a frame, the chunks round the player drawn by a copy
  of `world.gdshader` made see-through and tinted cold blue, first only into depth so only the nearest faces show);
  the ground to dig out a red body seen through the ground (its green taken out by `plan_cut_mul.gdshader`, then
  `plan_through.gdshader`) and a fence a plain blue body (`plan_ghost.gd`, `plan_ghost.gdshader`); its ghost things
  as their models in the blocks' look (`plan_things.gd`, `game.plan_view.things`: `Props.model_mesh`,
  `PlanBlocks.ghost_material`; a door or a window to be cut into a built wall stands in it, in the opening it will
  cut, its blocks drawn as air, `_show_holes`; `hold` / `settle` while the build mode carries one); the ghosts of what the bag is short
  of for the blueprint near (`BuildMode.short_blocks`, `short_of`) tinted `PlanBlocks.SHORT_TINT`, a soft red milder
  than the red of digging (the shader's `ghost_short` bits by material; things get a second material); the farm
  marking — a square on the cell's top face in the colour of the work and a sign inside (furrows, a sprout, a drop,
  a cross). The blueprint is seen only in build mode, the marking only in farm mode. The blocks cut by the level cut
  or the build cut of the floors show their tops at the cut (`PlanBlocks._caps`: `ChunkMesher.build_cap` of the
  ghost world, white, in the ghost's look), as a built wall's dark caps do.
- The build cut of the floors (2026-11-27, the building UX's PR 9): entering build mode cuts nothing, all floors
  show as out of it, until a level button is pressed (`ChunkStreamer.floors_on`; the first press down shows the
  player's floor, up the one above; the level label, R, turns it off again; the user's pick, 2026-11-27). Then the
  level buttons (and Q / E) step by floors as tall as the shape drawn (`ChunkStreamer.build_floor`, `build_level`; anywhere in the world,
  `floors_range`; `can_shift`), and on each floor, the player's too, its floor and one row of walls show, all built
  above them is left out (the cut at the level of the feet on that floor; the user's pick, 2026-11-27); the label
  reads «Этаж N» (`[floor_n]`, 1 the player's floor). Only what is built is cut (`build_cut`, see
  `docs/systems/rendering/rules.md`); natural ground, trees, plants and creatures stay, and the cut that follows
  the player (under a roof, in a pit: the layers) looks only at natural ground there (`_natural_only`, `_roof`;
  `indoor` still counts any roof) and only on the player's own floor. A finger passes through the built cells
  above (`Controls.pick` skips them), and the requests that take the cut get `ChunkStreamer.top_level`. Leaving
  build mode (or the first-person view) brings the ordinary cut back. Under a building (a floor below its own) the
  ground it stood on or in shows a dark section, not a hole (`ChunkMesher._uncovered`, the user's ask,
  2026-11-27). A placed thing standing across the cut is
  drawn cut there, closed by dark caps as the walls (`Props._cut_model`, `VoxelModel.cut_below`, `capped`), not
  hollow, its whole model only casting the shadow (`WholeShadow`); a window's glow is left out above it too.

- `src/client/game/gathering.gd` — what a touch gathers and the hint for it, picking up near the player (a
  beast's body lying is hit round its middle, `BODY_UP`, `BODY_GROW` px farther).
- `src/client/game/character.gd` — the character's copy on the client; `who` for what the client reads from the
  rules itself (the cursor frame, hints). The rules over the world go on the server, where `who` is
  `src/server/player.gd`.
- `src/client/game/props.gd` — what lies on the ground and its flight into the bag (connected to the signals). What lies in a chunk is one mesh (`show_drops`); a thing taken up is folded away in it (its vertices put at one point, `_fold_taken`), the mesh is made again only when something new lies there.
  New things in a chunk are drawn when the neighbouring chunks in which the cells themselves changed have been
  rebuilt (`ChunkStreamer.edited`, they go first in the queue; neighbours touched only by an edge are not
  waited for; `drops_rebuilt` from `ChunkStreamer`, no longer than `DROPS_HOLD_MS`): the logs of a felled
  tree and what was dug appear together with the tree or cell vanishing.
