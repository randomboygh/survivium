# The blueprint and tools

Part of [Hands and the world: digging, building, chopping, mowing, gathering](../interaction.md). The blueprint (plans) and what a tool can do.

- `src/shared/game/plans.gd` — the blueprint (decision 163, build mode 2026-11-06): ghost cells with a block
  or a fence link in each (`cells`; a fence is `is_fence`, drawn only by a line and a square of one link in
  height and thickness, `build` puts the link as a thing `Placed.put` facing the player, `_put_fence`) and the
  block's shape, if not a cube (`forms`: slope, steps — `WorldData.forms`; `PlanView` draws them with profile
  lines; a line, a plane or a square drawn with a form is a flight, `flight`: from the first corner one level high to the
  last at the height chosen — a line and a plane along the stroke (a plane all across its width), a square along both sides to the far corner — each column cubes under a slope or a
  step on top where it rises; an upturned slope mirrors it from the top, the first column hanging at the height,
  and its cells are not told as hanging, `sort` `hangs` (`hangs_by_shape`); with `BAND` in the form (32) the
  flight is a band one block thick: a column holds its top down to the level of the one before, the lowest
  cell where it rises the slope turned back (an upturned one under a slope, a slope over an upturned one) or,
  under stairs, a notch (`WorldData.FORM_NOTCH`), so the underside steps as the top does; a band hangs by its
  shape too; a room is of cubes, `FLIGHTS`), the figures `shape` (`KINDS`: «line» — a wall along the main direction of the stroke, «plane» — a
  floor in place of the top ground cell, «square» — walls along a rectangle with no opening, «cube» — floor,
  walls and ceiling, «flatten» — level the ground: natural ground above the level of the first cell (up to
  `FLAT_UP`) becomes a «dig out» ghost (`CUT`), pits under it (up to `FLAT_DOWN`) — a ghost of earth from the
  bag; buildings and trees are not touched; `build` first digs from above with the best tool of the bag
  (`best_tool`, its wear), then fills; height 1–6 (`MAX_HEIGHT`; for a plane — layers upward, for a cube — the
  whole height with floor and ceiling, not less than `MIN_ROOM` = 3), thickness 1–4 — for a line rows from the
  drawer, for a square inward; all figures except levelling are placed on top of the chosen surface), `sort`
  (which cells of the figure will stand, which are inside blocks or underground — not drawn, which lower ones
  hang over a void — uneven ground, told and drawn red but still drawn; none for a figure laid on a structure,
  `_on_structure`, as a ceiling over walls, whose middle the walls hold — the user's picks of 2026-11-27, 1А 2А;
  the client shows the same), `earthwork` (with `level`, the setting
  «Ground under a figure» = «level it», `build_level` 0, the default; item 11, the user's picks of 2026-11-26: a
  figure of blocks on uneven ground levels it as «flatten» at its level — under its footprint, a line's columns
  or the whole rectangle of a plane, a square or a cube, natural ground from its lowest level up to its top
  (the user's pick 2Б: the ground over the top stays) is a `CUT` ghost, the figure's own cells in it stay its blocks and `build` digs them first when no block takes
  their place at once (`_buried`, stone), dips under it are filled with soil when solid ground is at most
  `FLAT_DOWN` levels down (a deeper one is left and the figure hangs there), but not under a figure laid on a structure (`_on_structure`: under it a block players built or a ghost block, not of loose ground, that does not stand on the ground — a ceiling over walls, an upper floor, a roof; a paved path or a floor on the ground, or a dip filled before, is none), whose room stays open; a flight of slopes or stairs only
  has its dips filled, a fence takes the ground as it lies; `sort` takes it so the cells in the ground fit and
  those over soil do not hang), `draw` (draws or, with `erase`, erases the ghost in the whole box of the figure,
  `erase_box`; with `level` the box reaches `FLAT_DOWN` under the figure but takes only the earth's ghost there, `is_earth`;
  with `replace_it` — `replace`, idea 6 of 2026-11-26: in the box every block players built of another material,
  `replaceable` — not natural, not a tree's, no thing in it, becomes a ghost of the block in the hand keeping its
  form, and ghost blocks of another material there are repainted; `build` swaps such a block in one work, from
  the bottom, only with the new block in the bag and a tool for the old one, `best_tool` and its wear, the old
  block into the bag as dug, so no hole is left; soft built ground is taken in place as a floor's), `clear` (erases the ghost nearby), `build` (one cell: the
  lowest, then on a level one after another, 2026-11-26: the end of a row first, the fewest ghost cells beside it,
  then the nearest the cell this builder built last, `_last_built`, else the builder; on any level — the view's slice does not stop one building a ceiling from
  inside a house; a block from the bag — first the one in the hand; a floor replaces soft earth and gives it
  to the bag; with no blocks — waits), `to_list` / `from_list` (saved with the world, `"plans"`; JSON keeps a cell as `"(x, y, z)"` and a form as a
  float, `cell_of` reads them back), `take` /
  `take_all` (the client's copy, `Protocol.PLANS`, `PLAN_CELLS`). It is held by the session (`session.plans`),
  the hands' rules ask it through `actions.plans`; `WorldActions` is passed to `draw` / `build` as a
  parameter, with no reference cycle. `turn_form` turns the ghost of a lone slope or stairs a quarter: the
  whole column of ghost cells with forms over and under the cell (`column_of`, `formed_at`), within
  `PLAN_REACH` and by the right «build». Requests: `PLAN` [kind, from, to, height, thickness, erase, form, level, replace (both may be left out)],
  `PLAN_TURN` [cell], `PLAN_CLEAR`, `BUILD` (the action button of build mode, whatever is in the hand).
  Ghost things (the user's picks of 2026-11-26, 1А, 2А): doors, windows, hatches, furniture and stations, the
  campfire too (user 2026-11-27; a ghost is no station: it lets nothing be made, warms and burns nothing), drawn into the
  blueprint, `things` — records `{item, cell (north-west), turn, cells (each cell it fills,
  `Placed.volume_of`), wall (an opening's: the ghost blocks it took the place of, offset → block)}`, at most
  `MAX_THINGS`, indexed by cell (`thing_at`), told by the signal `thing_changed`; `put_thing` sets one of a
  thing in the bag where it would be set down (`Placed.ghost_spot`: as `put_spot`, but ghost blocks hold and
  back it as built ones do, other ghost things' cells are taken, an opening may stand in ghost blocks and takes
  them off into its `wall`); `move_thing` moves it the same way (`Placed.ghost_move_spot`; an opening along its
  wall, its own cell and turn + 2 turns it the other way round, `Placed.flip_spot`), `erase_thing` takes it
  off (its ghost wall back), and erasing by a box and `clear` take ghost things too; `build` sets them only
  when no block nearby can be built (`near_things`: the lowest, then the nearest; `_build_thing`,
  `Placed.put_ghost` — at its very cell and turn, from the bag at that moment; a door
  set into a ghost wall remembers the wall's blocks as its `cut`); a thing set down for real takes the ghost
  things off its cells (`drop_things_in`). Saved in `to_list` as dictionaries (`thing_record`, `_read_thing`;
  an older loader skips them), told to the copies by `GHOST_THING` / `GHOST_THING_GONE`. Requests
  `PLAN_THING` [item, aim, view turn, kept, face], `PLAN_THING_MOVE` [cell, to, turn, face], `PLAN_THING_TAKE`
  [cell].
  Undo and redo (`plan_history.gd`, the user's picks of 2026-11-26, 1А 2А): each player's request that changes
  the blueprint (`Requests.RECORDED`: `PLAN` drawing or erasing, `PLAN_TURN`, `PLAN_CLEAR`, `PLAN_THING`,
  `PLAN_THING_MOVE`, `PLAN_THING_TAKE`) is one step of their own history (`Requests.history`, `begin` / `end`
  round the request: the cells it touched, from the `changed` signal, with their item and form before and after,
  and the ghost things that went and came, from `thing_changed`), `PlanHistory.MAX` 50 steps, a new step drops the
  steps undone; building, farm marks and things set down at once are not in it. `PLAN_UNDO` / `PLAN_REDO` []
  put a cell back only where it is still as the step left it (a ghost built or changed by someone else meanwhile
  stays; no ghost goes on a block built meanwhile, `_fits`), only within `PLAN_REACH` and where the player may
  build; a step with nothing within reach stays, with a line to the player (answer -1). The link tells the
  client the counts (`PLAN_HISTORY` [undo, redo], `BuildMode.take_history`) to dim the bar's ↶ ↷. Kept while
  the player is in the world (a reload keeps it), not saved.
  The same holds the farm mode's marking: the values of `cells` that are `is_mark` (`TILL`, `WATER`, `REAP`
  or the id of what is sown and planted) lie on the top ground cell (`surface` looks for it in the column ±
  `FARM_UP` / `FARM_DOWN` from the level of the touch); `farm_columns` — a line along the main direction or a
  whole rectangle (`MAX_LINE`, `MAX_FLAT`), `mark_fits` / `farm_sort` — where the work is possible, `mark`
  (draws, replaces other marking, with `erase` erases it in the columns), `farm` — the mode's action button:
  the work of one mark nearby with a tool from the bag (the best hoe, a can with water, a sickle or hands — by
  `area`), on as many marked cells around as the tool takes; a «sow» mark on grass is dug first when the bag holds a hoe, else sown wild; done and
  impossible marks go, waiting ones (green crop, winter, no tool or seeds) stay, and the answer `{"idle"}`
  with a reason releases the button. The blueprint (`near`, `build`, `clear`, erasing by a box) does not
  touch the marking, and vice versa. Requests: `FARM` [work, from, to, square, erase], `FARM_WORK` (in
  `PACED`), `FARM_CLEAR`.
- `src/shared/content/tools.gd` — what a tool can do: a material says what digs it (`dig`), how hard it is
  (`hardness`: a gate — a pickaxe or axe needs strength not less) and how tough (`toughness`, with no field —
  as the hardness: a blow of a tool weaker than it lasts strength/toughness times longer, `swing_time`), an
  item says what tool it is (`tool`, an open class: the engine knows the work in the world for `WORLD_KINDS`,
  any other class there is hands and does not wear), strength (how much durability a blow takes: a tree falls
  when the blows have reached its `hits`, `hits_to` — how many), how many cells per swing (`area`), the swing
  time and reach; `ROLE_OF` / `role_of` — the skill each class of tool leads (one map for the rules and the
  character window); the model — `docs/balance/GAME_BALANCE_DESIGN.md`; bare hands are a tool with no item
  (`Tools.HAND`), their strength, swing, reach, which grass they cut and how many times slower they dig ground
  are the fields `hand_*` of the world's start (`content/core/data/starts.yaml`, a bundle's patch can change
  them); what is got with what — the functions `can_dig`, `can_chop` (an axe fells a tree and a bush),
  `can_dig_out` (a shovel digs a bush out), `can_knock` (a sword and a scythe knock berries down), `can_gather`
  (hands gather from trees and bushes), `mows`: both the hands' rules and the content graph ask them, so the
  check and the game do not diverge; the order of cells (around the touch, in front of the body outward, under
  the feet last), the brush shapes for blocks.
