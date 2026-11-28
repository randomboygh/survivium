# Input and build mode

Part of [Hands and the world: digging, building, chopping, mowing, gathering](../interaction.md). Controls, build mode, farm mode and their panels.

- `src/client/input/look_swipe.gd` — in the first-person view (`CameraRig.first_person`) a finger or the mouse's
  left button pressed on the world and moved past `SLOP` turns the view (`CameraRig.look_by`, `SPEED` radians a
  short side of the screen); let go before moving, it is a tap where it was pressed; held still `HOLD` (0.35 s),
  a held tap. `Controls.unhandled_input` gives it the events first; `Controls._ray` takes the camera's rays.
- `src/client/input/controls.gd` — keys, mouse, touches; `hands` (the item in each hand, `active` — the hand
  at work), the panel (the first `Inventory.HOTBAR` cells of the bag), brushes and strokes, the action button.
  One cannot build in the normal mode: a block or thing taken from the panel or the bag turns build mode on.
  It holds the modes' strokes like the rest (`_stroke` with `plan`), and what they mean is decided by
  `build_mode.gd` or `farm_mode.gd` (`mode()` — the one of the two that is on); `build_step` — one request
  `BUILD`, `farm_step` — `FARM_WORK`. Seeds and bushes too are planted only in farm mode. It calls the hands'
  rules not directly but by `game.net` requests (`Protocol.DIG`, `PLACE`, `PLAN`, `FRONT`, `PLANT_AT`, `EAT`),
  and by the answer plays the body's work (`_did`); so do `gathering.gd` (`GATHER`, `PICKUP`) and `props.gd`
  (`PROP_PUT`) — [network.md](../network.md). A tap on a placed thing (a chest, a station, a door, a sign, a
  bed) acts as the press lifts over it, as a button does (`_prop_press`, `_lift_on_prop`: lifted away from
  it, or over the interface, it does nothing); the rest of the world's taps act as they land. Opened as the
  finger landed, the bag had the rest of the touch: its list kept the finger and did not glide to the chest,
  and the slot under the finger was chosen as it lifted (the user's report of 2026-11-27; `save_test`
  `_chest_by_touch`). A tap that comes as the press lifts (the first-person view's, `look_swipe.gd`) acts at once.
- `src/client/input/work_mode.gd` — what the build and the farming modes share (both extend it): the hands remembered on entry and given back on `leave`, the palette of the bag under a filter, the eraser, `auto`; a mode adds its hooks (`_filters`, `_in_palette`, `_show`, `_left`).
- The build mode is a chain of parts (each calls only itself and the parts before it; callers preload
  `build_mode.gd`): `build_palette.gd` (constants, the shared state, the palette and what is chosen, the
  eyedropper, the shape, form, height and thickness, undo and redo) ← `build_need.gd` (what the blueprint near
  needs, `short_of`, `auto`) ← `build_blueprint.gd` (the cells of a blueprint stroke, replacing, the double tap
  on the ghost of a slope) ← `build_aim.gd` (where a thing is aimed, beside one of its kind, the taps that turn
  and take things) ← `build_carry.gd` (`drag`, `second_finger`, `release`: things carried, shown only where they
  fit) ← `build_mode.gd` (`_left`, `update`, `start_stroke`). The text below names the mode as a whole.
- `src/client/input/build_mode.gd` — build mode (`game.build`): entry from the bag («Build») or from a panel
  cell with a block or thing, exit (the hands return what they held), the palette (`palette`; the filters
  «All» / «Materials» / «Interior» are in the code but not shown yet), the shape, the kind of block (`form`:
  block, slope from below, slope from above, steps, then the three as a band, `band`, `form_index`,
  `FORM_COUNT`; only for a line, a plane and a square, `forms_drawn` — the button is off for a room; a flight rises along the stroke, a stroke of one column away from the player,
  the key Y turns the next ones a quarter (`turn`, `turns`: not kept, back to 0 on entering), a double tap on
  the ghost of one drawn turns it (`_second_ghost_tap` within `GHOST_TAP_MS`, `PLAN_TURN`, `Plans.turn_form`;
  no «turn» button since 2026-11-26); `form_of` goes into `PLAN`), the height (its own for each figure, `heights`: floor 1, line and square 3,
  cube 5 — floor, 3 rows of walls, ceiling), the thickness, draw/erase, clear; on the action button «Build» or,
  when levelling, «Level»;
  the eyedropper (`picking`, `pick_at`, the user's picks of 2026-11-26: a panel button beside the eraser, on a
  PC the middle mouse button): the next tap takes what is there into the hand as if chosen on the palette — a
  thing set down or a ghost thing (its turn kept in `kept_turns`), else the nearest ghost block, else the block
  hit, natural ones too (`block_item`: `Items.placed_by`, else `Items.dug`); once something is taken it goes
  off, the eraser too; nothing there or none in the bag (`choose`'s nag) → it stays on for the next tap (6Б);
  replacing the material (`replacing`, idea 6 of 2026-11-26): the third state of the draw/erase button,
  `next_mode` — draw → erase → replace, a paint roller, no extra button so the panel stays one row on a phone; a
  stroke begins at the block or ghost under the finger, `_replace_stroke`, takes the box of the figure (a plane
  for «flatten»), lights the blocks it will mark, `replaced_cells`, and sends `PLAN` with the 9th flag;
  the stroke (`start_stroke`, `show_stroke` — light cells will stand, red ones are inside blocks or over a
  void, when erasing a red box and the ghost in it above blueprints; `end_stroke` — `PLAN`);
  a thing (everything that is placed: `Items.is_interior`) from the bag shows at once as the finger or the
  mouse presses over a surface (2026-11-26), hanging in the air (`Props.hold_new`, `_drag_new`) over the place
  aimed at (`Placed.put_spot`, as the server will look for it, turned best: a door or window in the plane of
  its wall by the face pressed, `face_of`, furniture with its back to a wall; a door or a window aimed over a
  wall's top, before its face or by it sticks to the nearest wall cell, `Placed._wall_near`, `WALL_SNAP` cells
  round, a floor's cell `FLOOR_FAR` farther (a door over a floor by a wall goes into the wall), a door down to
  the floor, and of the spots there with every column in the wall or in a gap (`_wall_cells`: never on the
  ground before a wall too short for it, nor on a bare floor, 2026-11-27) the one with most cells in the wall,
  then aimed at a gap the fewest blocks cut (a doorway is filled as it is left), `_wall_spot`, 2026-11-26; a gap
  in a wall, `_in_gap`, keeps the cell aimed at: wall cells on both sides along a row, each
  the end of a wall going that way, not of one across it, so the middle of a small room is no gap, 2026-11-27; a door stands on a floor, built or of the
  blueprint, never in it or down to the ground under it, `_floor_cell`, `_sunk`; with no wall near a door or a
  window is not set at all: only into a wall or a gap in one, never in the open, 2026-11-26), its cells shown red only where
  it does not fit (a door, a window, a hatch, a wicket or a gate, `shown_where_fits`, is not shown at all where
  it cannot go, no room or out of reach, `_spot_new`: a new one from the bag is hidden, one carried is held in
  its own place, `_hold_home`, and let go there nothing is asked and nothing said, no `[no_room_here]`; the
  user's ask 2026-11-27;
  2026-11-23: no body over a thing that fits; a door or a window held into a wall is drawn
  in the middle of the wall where it will be, in the opening it will cut: those blocks, `cut_cells`, are drawn as
  air in the build mode, `PlanThings.hold_hole`, `ChunkStreamer.set_holes`, `ChunkMesher.holes`, 2026-11-26;
  a door shut stands halfway between the wall's faces as a window does, `Placed.shut_voxels`; a ghost door or
  window of the blueprint in a wall built stands there too, so a tap on it takes it, `Controls.ghost_thing_at`,
  and it can be carried; the model held and the ghost things are culled by their sheared boxes, `Props.fit`,
  refitted on a camera turn, so none vanishes on high ground as the camera turns); it follows the finger and is set down where it
  is let go (a stroke with `put`; `PROP_PUT_AT` with the face, `Placed.put_at`: a door or window pressed on the
  side of a wall with no opening knocks the blocks out, they fall as if dug; blocks below the level of the
  player's feet are not knocked out, so a door on the floor stands on the floor); with the setting «Things from
  the bag» on «by blueprint» (`build_things` 0, the default; the user's pick of 2026-11-26, 2А) a door, a window,
  a hatch, furniture, a station or a campfire (`Props.ghostly`: all but lights; a campfire's ghost is
  `Effects.campfire_model`, `_by_blueprint`) is not set down but drawn into the blueprint as a ghost
  thing (`PLAN_THING`, `Plans.put_thing`): held, it hangs in the ghost look (`PlanThings.material`) over the
  place found as the server will find it (`Placed.ghost_spot`; the finger aims at ghost blocks as at built
  ones, `Controls.pick_planned`), «at once» sets it down as before; let go where no place was found (`spot`
  null, a tap looked for on release) a thing from the bag asks the server nothing, so nothing is said; a ghost thing under the finger
  (`Controls.ghost_thing_at`) tapped is taken off the blueprint after `DOUBLE_TAP_MS` (`PLAN_THING_TAKE`),
  tapped twice is turned (`turn_ghost`: a quarter, a door or a window the other way round), held is carried as
  a placed thing is (`_drag_ghost`, `PlanThings.hold`, `Placed.ghost_move_spot`) and let go moves there
  (`_release_ghost`, `PLAN_THING_MOVE`); a thing is aimed right under the finger, raised only `Props.LIFT` over the surface
  (2026-11-26: the lift over the finger, `FINGER_LIFT`, was taken off: a tap set things down over a wall's
  top or behind it), and once held `HOLD_MS` (or moved `_slop`, a
  `DRAG_SHARE` of the screen) a short buzz tells it is taken up (`Vibration` «lift»); a touch of a placed thing (found by
  the cells it fills under the finger, `Controls.placed_at`, not by a finger's radius on the screen as
  gathering finds it: a tap beside a door does not take the door, 2026-11-26)
  takes it back after `DOUBLE_TAP_MS` (`_tap_wait`; a second tap within that time turns it a quarter where it stands; only in this mode); a thing that moves (`Placed.movable`: a station, a chest,
  furniture, a sign, a fireplace) held the same way hangs in the air (a stroke with `prop`: `drag` each frame
  — the model is held up `Props.LIFT` over the free place nearest the place under the finger, with the «lift»
  buzz as for a new thing, `Placed.move_spot` as the
  server looks for it, its cells red where it does not fit; `release` — `PROP_MOVE`, `Placed.move`, or the model
  drops back, `Props.settle`); a door, a window or a hatch held so (`Placed.is_opening`, movable since
  2026-11-26) follows the wall under the finger as a new one does (`_drag_opening`: `_aimed`, `_aim`, `face_of`,
  `Placed.opening_spot`, held in the opening it would cut, `cut_cells`), and let go it moves
  there by `PROP_MOVE` [cell, the wall's cell, turn, face]: the server cuts the new cells and walls the old ones
  up with the blocks it had cut (`Placed.move_opening`, [crafting.md](../crafting.md)); tapped it goes back into
  the bag and leaves ghost blocks in its hole, and a double tap turns it the other way round in its wall
  (`turn_thing`: turn + 2, its kind's turn not kept); a double tap turns a thing (`turn_thing`) and keeps that turn for its kind
  (`kept_turns`): the next ones are set down turned so (`PROP_PUT_AT` with `true`, `Placed.put_spot` `kept`)
  until the bag holds none; a thing carried (new from the bag, set down and held, a ghost thing) is turned by a
  second finger (`second_finger` from `Controls.input`, `turn_carried`, its turn kept so too; the user's picks,
  2026-11-27, 7В): a tap of it within `SECOND_TAP_MS` a quarter clockwise, the two fingers twisted a quarter each
  `TWIST_STEP` (45°) their way, a light tick each; where the thing takes its turn by itself (a door or a window in
  a wall, a back to a wall) that turn wins, so it turns only in the open; a thing one cell big tapped with one of its kind in the hand sets the next down
  beside it (`_beside_kind`, `_beside`: the cell under the finger, else past the face the ray goes in by,
  `face_in`; held, it hangs there), and is taken only once the bag holds none; whatever comes into the bag
  while the build or farming mode is on (not while `auto` works, nor over a tool in the hand) has its palette slot chosen
  (`WorkMode._on_bag_changed`); a model held up never stays in the
  air: `update` drops it once the stroke is no longer on it (`Controls.dragging`), a second press releases the
  stroke first, on a touch screen the stroke ends with the last finger up, and while a finger is down only its
  own motion moves the stroke; the
  action button is
  pressed once (`auto`) and builds the whole blueprint nearby, releases after the last cell or when the blocks
  run out. The settings are kept with the player (`"build"`).
- `src/client/input/farm_mode.gd` — farm mode (`game.farm`), made like build mode: entry from the bag
  («Garden» for seeds, a bush, a hoe, a can with water, a sickle) or from a panel cell with seeds or a bush;
  the work (`Plans.WORKS`: till, sow, water, reap — the hand takes what it is done with), the figure (line or
  square), draw/erase (the palette filters «All» / «Seeds» / «Bushes» are not shown yet), clear; a stroke on
  the ground — `FARM`; the action button (`auto`; its word `button_name`: the work of the nearest mark — «Till», «Sow»,
  «Water», «Reap» — or the chosen work, «Stop» while it works) does the marking nearby with the requests
  `FARM_WORK` and releases when there is nothing to do now. The settings are kept with the player
  (`"farm"`).
- `src/client/ui/farm_bar.gd` — the farm mode's panel: inherits `build_bar.gd` (the same palette, `mode` — whose
  mode), its own row of buttons (`_make_panel`, `_show_panel`): work | figure, draw/erase | clear, «Work» (on PC
  only), exit.
- `src/client/ui/build_bar.gd` — the mode's panel in place of the hotbar, in one row: buttons switched in a
  circle (the figure — `next_kind`, next to it «level»; the kind of block — `next_form`, its hint telling that
  a double tap turns a lone slope's ghost, no «turn» button since 2026-11-26; the
  figure's height and the walls' thickness — a plane has no thickness; draw/erase paired with «clear» — a
  second touch within 3 s), on PC the mode's action button (`_go`: an icon with no label, «Build» / «Work» in
  the hint, at work — paused and lit; calls `toggle_auto`, like F and the big action button on a touch
  screen, where there is none on the panel), exit; below it the palette, made as a hotbar without hands: the
  same frame, 40 px cells, arrows and finger scrolling (`_input`), the width of the hotbar (up to 10 cells,
  in portrait up to 6: its 4 + 2 hands); the clock under its right edge (`right_edge`). There are no filters
  yet: on entering the mode `filter` = «all».
  What the blueprint needs (2026-11-26, the building UX's PR 5): `BuildMode.need` counts the ghost cells (one
  block of their item each, a slope too, digging none) and ghost things (one each) within `Plans.PLAN_REACH`
  of the player (`count_need`, again when the blueprint changes or the player walks `NEED_STEP` cells, at most
  every `CHECK_TIME`, once the blueprint and the bag have stayed `NEED_SETTLE` as they are; `short_of` compares
  the need with the bag's count taken with it, `_have`, so the ghosts do not blink red between the news of a cell
  built and of the bag, 2026-11-26); the palette puts those items first, the most needed first, also the ones the bag has none
  of (dimmed, ×0; a tap says they are not in the bag), with the need in the cell's top left (`HotbarSlot.tag`,
  `tag_color`: always pale as the bag's count, 2026-11-26; a shortage, `short_of`, tints the ghosts red; blocks are never short when building is free)
  and the need and the bag's count in the tip.
