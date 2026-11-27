# The body and the players on screen

Part of [The character: bag, strengths, skills, body, death, sprite](../character.md). The body on the grid, the server's and the client's character, the player and other players on screen.

- `src/shared/game/body.gd` — the body on the grid: `step(at, delta, jump)` (a longer `delta` is walked in
  steps of `STEP_MOST` 0.05 s, so a fall never passes through a floor), slopes (the pace is along the ground: the run is shortened by the rise, `SLOPE_MOST`) and steps, water and
  swimming, the bark of a trunk thicker than its cell in the cells beside and across its corners
  (`WorldData._bark_touched`, an octagon as drawn), the trunk of a standing tree drawn as pictures (its cells stop
  nothing: `_trunk_touched` holds the middle of the feet `TreeLooks.FEET` pixels off the ring of the stump the tree
  leaves, its cut as drawn (look.yaml `cut`, measured by `tools/tree_feet.py`: an ellipse as wide across the picture
  and as deep along the way the camera looks, `view_up`: the client's `PixelView.up`, on the server from the INPUT's
  view, `Player.take_input`; its front on the axis), from the ground up to the cut and on up the trunk's cells,
  narrowing from the cut to the crown where the trunk is drawn narrower (look.yaml `taper`, `TreeLooks.ring_at`; the
  ring at the height of the feet where a step began, so a body falls past a narrowing trunk, not onto it); a stump
  holds it off the same ring up to its cut as drawn (`top`), which is stood on: a body coming down from above lands on
  it, one lower than a step is walked up onto (`_trunk_top` in `_ground_top`), and its figure is drawn in front of
  the stump's picture (`on_trunk`, `Player.place_sprite`, sprite.gdshader `depth_lift`); one inside (the camera
  turned) walks out, the server's `blocked(claim, from)` lets it; a step into a ring slides round it (`_round_trunk`,
  `TreeLooks.ring_out`), so passing a trunk never catches; `_find_trunks` gathers the trunks round the body's cell
  from `WorldData.tree_chunks` once it comes into another cell or `TRUNKS_FRESH` steps after, a step keeps those
  within `TRUNK_STEP` of where it began, and each is passed over by its `hold` circle before its ring is asked:
  `WorldData.trunk_look`, `trunk_hold`), a plant that is `solid` (a cactus: a post `SOLID_HALF` cells
  round its root where Foliage draws it and `SOLID_HIGH` levels high, not jumped over; `Grass.solid_plant` finds
  it; `_find_posts` gathers those within `POST_REACH` columns once the body has gone a cell or `POSTS_FRESH`
  steps, so `_collides` asks only of them; one the body stands in already (`_in_plant`) lets it walk out), a leaning ladder (`_climb`: the body in the cell of a link of `WorldData.ladders`, or above the top
  link by less than `CLIMB_OVER`, does not fall; the joystick towards the ladder — up, away from it — down at
  the speed `CLIMB_SPEED`, sideways — along, above the top link towards the ladder — to step off at the edge;
  below on the ground «away from it» leads away by a step, a jump lets go at `LET_GO`; the server sets
  `climb` by the height the client sent, `Player._take_claim`), ice, deep snow and wind (`weather_pace`,
  `air_drift`), pushes (`knock`), trails; on a raft or in a boat (`vessel` — the share of a walking step,
  `Character.vessel_pace`: without `oars` in the bag `OARLESS` of it) the body keeps on the water's surface
  (`DECK` under it), goes only on water where the hull `HULL` fits (`floats`, `_sail`), faster with the
  swimming skill, an overload of the rower's bag slows half as strongly as a step (`LOAD_AFLOAT`); movement
  with inertia (`_row`): the vessel looks along `heading` (set by boarding, `ActionsBoat._set_off`, on the
  client `main._set_off`), turns to the stick no faster than `SAIL_TURN`, speeds up in `SAIL_SPEED_UP` s,
  without rowing it rolls and loses `SAIL_DRAG` of its speed per second, the keel damps sideways drift
  (`SAIL_KEEL`); wind drifts the vessel by its `windage` (`SAIL_WIND`, a light one — `SAIL_BREEZE` of that); a
  hull that hit the shore faster than `SAIL_BUMP` bounces (`SAIL_BOUNCE`), `bump` — at what speed (the knock
  in `steps.gd`); `afloat` — whether it holds; `flow` — a river's current (`Currents`, `Character.flow`)
  carries the vessel and the body in water by the share `SWIM_DEPTH` of itself that is in it. Where the body
  stands is held by the owner: on the client the player's node passes its place into `body.step` every frame.
- `src/server/player.gd` (inherits the shared one) — a player's character on the server, the one over whom
  the rules go: the body and hands are as the client sent them by the event `input`; over a socket the sent
  place is checked by the server's body (3А, [network.md](../network.md)).
- `src/client/game/character.gd` (inherits the shared one) — the character's copy on the client: the bag,
  strengths, death from the server's events (`take`, `take_vitals`), the player's place, the hands (from
  `controls`), the lines under the clock, the death screen, `go_to_column` («Testing»); it runs no rules.
- `src/client/view/player.gd` — the player on screen: moves the body, draws the sprite by the body's state;
  `player.work` begins a stroke (`work_n` counts them, `work_at` — where it is turned: the server tells the
  other players about them).
- `src/client/view/others.gd` — other players on screen (С3.3): a figure `player.gd` for each of the server's
  snapshots `people` (drawn `DELAY` 0.1 s behind them, between the two nearest), the hands through
  `game.hands.look`, strokes by count, the name above the head in the interface's ordinary font (a Label in
  the HUD layer, set every frame at the screen's point above the head, `View.screen_of`, without smoothing)
  and above it a balloon with its chat line (6 s): light, with dark letters and a tail towards the name, so as
  not to confuse it with notices and signs (one's own line hangs so over one's own head, its tail to the head,
  `_own`); `person_gone` removes it. Players do not walk through each other: each game moves its own body out
  of the others on foot where it draws them (`parting` → `Body.parting` into the body's `nudge`, from `main.gd`
  before the step): by `PART_RATE` 20 of the overlap a second, at most `PART_MOST` 10 cells a second, round
  `PERSON_RADIUS` 0.4 cells each; one walking into another standing is held off, the other's game sees the
  overlap and steps aside, so walking on shoves them at about half the pace (`body_test` `_test_people`). The
  server only checks the places as for walking. It does not step with a body, the
  silhouette behind walls — only one's own. The light in another's hand (an item with `light` in their hands
  from the snapshot) burns as a flame in the place of the sprite's flame (`Effects.torch_flame`), and the
  `OTHER_LIGHTS` (3) nearest to the player also shine like one's own torch (`Sky.lamp_gain`,
  `Effects.torch_off`, two torches farther, for a swimming one shorter), with no shadows and always as new
  (how much is left to burn the server does not say); `server_test` checks, the shot `team-torches`.
  Walking on the ground (not swimming, not in a boat) they leave boot prints every `STRIDE` (0.55, as one's
  own in `main.gd`) through `tracks.gd`, and in deep snow tread the client's copy of the world
  (`WorldData.tread`), so their trail eases one's own walking as on the server; a move over `LEAP` (2 units:
  a teleport, a respawn) leaves none; `server_test` checks.
- Gestures (decision 183): `src/shared/game/gestures.gd` — the list `LIST` (wave, yes, no, point, here, bow,
  clap, sit: the wheel's words, the animation of `player.yaml`, seconds; «sit» — until movement and with no icon
  over the head, `icon: false`), `make` (the
  request `gesture`, the name is checked against the list, "" — stop), `now_of` (a gesture ends by time, on
  movement, in water, in a boat, in sleep). The character stores `gesture`, `gesture_until`; the server sends
  the gesture in the `people` record (field 17). A tap on a seat (`Placed.is_seat`, an item with `seat`: the
  stool) is the request `sit_on` (`Character.sit_on`: the body put on it, `Placed.lying_spot`, and the gesture
  «sit» until it moves, facing the way the seat faces, `Placed.front_of`, its back to the seat's back; drawn
  `SITTING_FORWARD` towards the viewer so it shows in front of the seat). Other
  furniture that stores nothing does nothing at a tap; it is taken up in the build mode. The figure (`player.gd`, `set_gesture`) plays its animation
  standing, above the head — the icon `UiStyle.icon("g_<name>")` for the first `Gestures.ICON_TIME` 2.5 s
  (for others — above the name); movement or work interrupt it. The gestures' frames are columns 48–59 of the
  sheet (`tools/art/player_art.gd`, `MOVES`, with `lean` — the body's tilt; `tools/make_sprites.gd` draws the
  layers, the marks of the hands and what is worn anew). A gesture with frames in
  `tools/art/player_gesture_art.gd` (GestureArt) is drawn whole instead, its rows reaching two columns past
  the box for a hand out beside the head: the wave (reviewed with the user 2026-11-20) raises the right hand
  by the face at the eyes' rows, two pixels square on a short shoulder, and moves it a pixel out and back;
  from the side the near hand is over the head by the ear (a hand in front of the body is drawn with the
  fists, over the head); the nod drops the head a pixel over the neck with the eyes shut (a frame's `eyes`,
  as in the blink), the body standing; the shake turns the head an eighth one way and the other (a frame's
  `head`, a west way the east one flipped), a pixel aside the way the face turns in the first frame (a
  frame's `lean` moves only the head), only turning from the side; the point holds the right hand out level by the body's first row, the
  finger a pixel past it (forward from the side); the beckon holds the hand there without the finger and
  lifts it a pixel; the bow lowers the head a pixel and two with the body standing, the chest's second
  row folding at the bottom with the eyes shut, the head a pixel forward there when turned. The clap holds
  the hands, two pixels square, out beside the chest, then three pixels in each, met in its middle and
  edged with the skin's deepest shade; turned away only the forearms show. The wheel of gestures —
  `src/client/ui/gesture_wheel.gd` (a button beside the chat in the top row, the key C, digits 1–8 in the
  wheel).
