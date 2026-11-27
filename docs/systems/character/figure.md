# The player's sprite

Part of [The character: bag, strengths, skills, body, death, sprite](../character.md). The sheet of the player's frames from PNG layers.

- `src/client/view/figure.gd` — the sheet of the player's frames from `content/core/sprites/` by `player.yaml`
  (layers, the marks of the hands `hands.png`, a sheet for each tool in the hand or the item's icon), built by
  a part of a row per frame; `hands.gd` — what in the hands is seen on the sprite; `sprite_sheet.gd` — the
  sheet of frames by data. The figure is a chibi (stage 3, the user's pick of 2026-11-19): 14×18 px with its
  outline in the 32×32 frame, a big head (rows 1–10, eyes 2×2: a pupil over the iris beside the eye's white),
  and under it the body in the proportions of the walk's reference (the stand redrawn to them, the user's
  pick of 2026-11-19): a neck, 8 px shoulders, a 6 px torso, bare arms of 2 px hanging by it, legs of 2 px,
  each as the reference draws it in the step it stands on; the head sits a row lower than the reference's and
  the legs are two rows, as in the walk (the front's were a row longer until the user's note of 2026-11-20:
  `PlayerArt.shortened` takes the row under the waistband off each leg of the front's frames drawn whole). The feet stand on the frame's
  bottom row with no outline under them. What is worn never shows over the head (`frame_letters` takes it off
  where the head is: a nod's chin over the collar). `tools/art/player_art.gd` draws it (`HEAD`, `HAIR`, the body standing `BODY`,
  `SIDE_LEGS`, the arms `SHOULDER`, `REST` and `ARMS`, the poses `MOVES` and `WORKS`); the design and its
  letters are in the library `survivium-builds/character/chibi/`. Seated (`sit`: afloat and the gesture,
  and the rowing on the same legs) the body is two rows lower, only the feet under it; from the side the
  legs go forward (`SIDE_LEGS` `sit`), turned a little a knee shows past the waistband (`SIT_KNEE`; the
  user's notes of 2026-11-20). The walk (six frames, 10 a second at
  `Body.SPEED`, the user's pick of 2026-11-19; it and the swim play as fast as the body really goes: the
  ground covered each frame, the player's and the others', eased over `GAIT_EASE` and kept between
  `GAIT_LEAST` and `GAIT_MOST`, `player.gd` `gait`) is the body of a reference copied pixel by pixel under our head
  (`tools/art/player_walk_art.gd`, from `survivium-builds/character/anim/references/`): legs of 2 px, the
  arms swinging against the legs, the body a pixel down at each step and a row shorter with both feet off
  the ground as the legs pass; from the side and from behind it stands a row lower than the reference, its
  feet on the frame's bottom row. A foot lifted has no outline under it either: `player.yaml` `soles` gives,
  by direction, the frame's bottom rows where `SpriteSheet.outline_rect` outlines nothing from above, in
  the walk's frames only (`Figure._put_row`): in the others a hand hanging low keeps its outline under it.
  The jump's two frames are drawn whole under the head the same way (`tools/art/player_jump_art.gd`,
  2026-11-19, after the user's note that an arm moves from its shoulder): rising, the shoulders go a row
  up with the arms and the legs are drawn up; falling, the arms go out to the sides (from the side
  forward) and the legs are straight, the figure a row up: every jump frame has the outline under its feet
  (the user's note of 2026-11-20). The swim's four frames too (`tools/art/player_swim_art.gd`, a
  breaststroke the user picked): the water is at the chin, so the whole stroke is under it, tinted; the hands
  come together in front of the chest, the arms sweep out from the shoulders, pull down and come back, the
  legs glide, kick apart and draw up; afloat the head is as high in every direction (no stand `drop`), so
  the eyes stay over the water. The chop's four frames too, with the axe (`tools/art/player_chop_art.gd`,
  reviewed with the user 2026-11-19): the axe up beside the head, the top, the strike crouched, upright
  again; the torso moves in the first two. The dig's four frames too, with the shovel
  (`tools/art/player_dig_art.gd`, reviewed with the user 2026-11-20): the hand holds the shaft halfway,
  the blade goes into the earth from the feet's level a pixel deeper in each of three frames (crouched on
  the third, the chest's row folded away: the legs never move), then the toss; from the front the shovel
  is at the right side, from the side and behind by the right foot, beside the feet with the outline
  between. The slash's four frames too, with a blade in one hand (`tools/art/player_slash_art.gd`,
  reviewed with the user 2026-11-20, first after the sword's swing of Puny Characters (Shade, CC0); the
  swords, knives, spears, sickles, slings and rods play it): the sword up beside the head at the
  shoulders, then raised higher; the swing (crouched, the chest's row folded away: the legs never move)
  along an arc down that side and under to the other, the blade about 30 degrees to the ground
  (`PlayerArt.LOW`, `LOW_LEFT`: `ToolArt.turned` lays any tool's upright shape along a line two pixels
  across for each one down); then standing again with the blade where it stopped. From the front the
  sword is at the right side (the picture's left) and the hand stays left of the belly's middle, so the
  blade never seems to be in the other hand; from the side it is the front's swing too: up behind the
  head (the hand by the chin), down behind and under to the blade forward and down, the same crescent of
  a trail; from behind the front is mirrored, the blade in front of the body hidden but for its tip past
  the left side. A frame may put the other hand behind the blade (`of`). A blade swung leaves a trail:
  the swing's frame draws one along the whole arc from the raised blade's tip (`trail` of the frame, the
  letters `o`, `+`, `-` of `PlayerArt.INK`, into the layer `player/trail.png`, `player.yaml` `trail`),
  and `Figure` puts it in the columns of the work the right hand's thing plays, for things with `trail`
  (swords, knives, sickles, also when held as an icon; `Hands.look`): over the figure and its outline
  where the hand holds the thing in front of the body, behind them (only where the frame is still empty)
  where the thing is behind it, as from behind; without it the tan wooden blade is lost over the skin. The slash strikes on its third frame as every
  work does (half the swing, `Controls`); a rod out fishing is held as in the last frame
  (`Player.ROD_OUT`). The bow's shot, the work `aim`, too (`tools/art/player_aim_art.gd`, reviewed with
  the user 2026-11-20 after the Bow Attack of Puny Characters; the bows play it): an arrow nocked, the
  string drawn back, loosed (the string straight, the drawing hand thrown back), the bow down again; from
  the front the bow is held across the body with its arrow at the viewer, from the side up in front of
  the face, turned away by the body's right side from under the cheek to the knee (the limb's arc, the
  string straight between its ends next to the body, the arrow a line from the near hand up through the
  bow), from behind hidden by the body. The bow
  changes with the string and the arrow in each frame, so a frame draws it whole (`bow`: rows of
  `ToolArt.INK` letters from their corner's offset from the grip), and `ToolArt.sheet` draws that for a
  shape with `bow` (the wooden bow, the composite one recoloured) instead of turning it; the other hand
  draws the string (`two`: it shows no thing of its own; the bows take two hands, `hands: 2`, as the work
  does in `player.yaml`). The bow has no dark edge of its own where the figure's outline goes (the two
  made a line two pixels thick): its dark letters only part its wood from the skin and from its string.
  Its string never runs over the legs: turned to the viewer the bow's lower end is under the frame's edge,
  and the string ends where it meets the limb on the hips' row (drawn, it goes from the upper end to the hand).
  From the front the bow's mark is above the frame's neck, which no build moves (`PlayerArt.pose`), so
  the bow held across the body stays in the middle of the stocky body too. The arrow leaves on the third frame:
  `Controls._did` flies the shot (`Props.fly_shot`) half the swing after the reply for the aim (a spear
  thrown or a fish pulled out still flies at once).
  The eat's four frames too (`tools/art/player_eat_art.gd`, reviewed with the user
  2026-11-20; what is eaten or drunk plays it): the food lifted to the belly, the elbow by the side;
  raised to the chin, the hand beside it; the bite, a nod (the head a row down onto the food, which stays
  where it was, the eyes shut: the frame's `eyes`; the chest's row folded away, the legs never move);
  lowered again, chewing with the eyes shut. The food is the icon in the hand as it is carried (`a` -1),
  its middle at the hand's mark and the hand's skin over it, so the frames draw the hand beside the food,
  not across it; turned and from the side it is before the face, from behind the body hides it (`f`
  false) and the elbow and the nod show the bite. An icon is not mirrored with the figure, so in a west
  direction one of an even width sits a pixel further from the body than in its east one.
  The mow's four frames too, with the scythe in both hands (`tools/art/player_mow_art.gd`, reviewed with
  the user 2026-11-20; the scythes play it): the snath rises from the hands to its far end and the blade
  hangs from there with its point at the ground (the user's note: the blade down, not up); the hands hold
  the snath at its middle, not at its end (the user's note), so its near end comes out two pixels past
  them and always shows past the far fist (the user's note): from the side over the waistband and then on
  the hip under the arm, from the front and turned past the fist's outline, from behind a pixel under the
  fists. The scythe is held out to one side, its
  far end goes a pixel up as the torso leans after it, then it is swung past the feet to the other side
  (crouched, the chest's row folded away) and the body stands again with the scythe where it stopped: the
  mower's right to their left in every view, so from the front and the side from the picture's left to
  its right (from the side from behind the back forward), from behind from the right to the left, where
  it ends behind the body with the left hand on it (`f` false). A scythe keeps its blade down wherever it
  is, which turning its shape does not give, so the frames draw it whole as the bow's do (`scythe`;
  `ToolArt.DRAWN` lists the shapes a frame draws, `ToolArt.drawn_by_frame`), and both hands hold it
  (`two`). The scythes leave a trail (`trail: true`): on the strike a shallow arc from where the blade
  was, over the feet's row and up to the blade, in front of the character (the user's note); from behind,
  pieces low on the ground behind the figure. In every view but the side one the scythe's mark is above
  the frame's neck, which no build moves: a stocky body's hands go a pixel out along the snath and the
  blade stays where it is drawn, whole in the frame. A
  work drawn so carries the way the tool points (`a`, `ccw`, `f`), where the hand holds it
  and how far up its length (`slide`: `ToolArt.turned` moves the head nearer the hand, the shaft's end
  past it, leaving `ToolArt.SLIDE_LEFT` rows beyond it, so a short thing is held as it is), so
  `PlayerArt.pose` takes them from the frame instead of `WORKS`; its west directions are the east ones
  mirrored with the tool. `PlayerArt.whole_frame` gives a column's frame drawn so.
  The reach's four frames are drawn whole too (`tools/art/player_reach_art.gd`, reviewed with the user
  2026-11-20; bare hands play it, and every thing with no work of its own: gathering, placing, building):
  the hand lifted to the waist; a crouch (the chest's row folded away: the legs never move) with the arm
  stretched down along the leg, the hand a row over the ground; still crouched, the arm short again;
  standing, the hand brought up to the shoulder. The arm lies against the body in every frame, with no
  outline between them, and stretches only together with the crouch (the user's rules). Turned, from the
  side and from behind the body stands a row lower, so the crouched arms are a row shorter and the hands
  are as high over the ground as from the front; from the side the arm goes down and forward in front of
  the body, from behind it is at the picture's right, behind the body. The frames turn nothing (`a` -1):
  what the hand holds is drawn as carried, at the hand's mark.
  The rowing's four frames are drawn whole too (`tools/art/player_row_art.gd`, reviewed with the user
  2026-11-20), played in time with the oars (`Boats.stroke`): a push stroke for a body facing the bow,
  the catch (the fists near the body), pushed (the body leaning a row down), the blades lifted (the fists
  low), back. The legs are the sit's (`PlayerArt._seated`), so sitting and rowing follow each other
  without a jump in every build. The fists stay on the handles' ends, where the oars have no grip of
  their own (`Boats._oar`), so a couple of pixels of each hand show over the handles wherever the hull
  and the bench leave them (the user's note): from the front by the chin, an outline between; from the
  side the near one in front of the bench; turned the far one out from behind the head on its oar (with
  the back turned, behind the head); from behind both by the head, the arms up from the shoulders.
- Looks (stage 3, PR 3 of the character editor): `src/shared/content/looks.gd` reads `player.yaml` `looks`
  (10 skin tones, 12 hair colours, 6 eye colours by place in their lists; 10 hair styles, 8 face options
  under the hair, 5 on the face, by id) and makes any look sound (`Looks.clean`: the server's check of a
  hello, a save). The character keeps it in `Character.looks` (saved in `character`, {} until given): the
  server gives a new character the looks of its hello (7th field, `ServerList.player_looks` from the
  «Персонаж» tab), single player `LocalHost.take_looks` after the save is read; a character met again keeps
  its own (it belongs to its world); bots look random. It reaches the own client in `YOU` (the state) and the
  others as field 18 of `PEOPLE`. `Figure.dressed(gear, looks)` puts `player/face/<face>.png`,
  `player/hair/<hair>.png` (none for bald) and `player/face/<on_face>.png` in the hair slot, drawn by
  `tools/art/player_looks_art.gd` (`HAIRS`, `FACES`, from the design `chibi_v7.py`). The colours are the
  shader's (`shaders/looks.gdshaderinc`, in `sprite`, `sprite_water`, `sprite_mirror` and the preview's
  `figure_preview.gdshader`): the pictures are drawn in the default look's colours, and `Figure.paint` sets
  pairs of whole sRGB colours to swap (the skin's three, the hair's three, the iris, and stubble, freckle,
  blush and scar made of them, `Figure.MADE`). No other picture of the figure, the clothes or the tools held
  may use those colours (`view_test`). The sheet is not recoloured on the CPU: 475 thousand pixels a layer
  take seconds on a phone. The «Персонаж» tab (`character_page.gd`) has a row for each.
- Body forms (PR 3b; no sex is picked, every form is for everyone): the looks' `build` (thin: arms a pixel
  wide; normal; stocky: the torso two pixels wider, the arms and the hanging hands a pixel further out) and
  `figure` (straight; bust: the shade `V` under it from the front, two pixels forward from the side; curvy:
  the bust and the thighs a pixel wider, the seat a pixel back). `tools/art/player_forms_art.gd` says what
  each draws otherwise, of the rows of any body drawn (`FormsArt.body`: the stand's and the walk's frames alike;
  stocky widens a frame drawn whole by the side of the picture each pixel is on, so `PlayerArt.pose` moves a
  hand's mark there with it, also a hand reaching across the middle); `make_sprites.gd`
  draws every layer, the hands' marks and the clothes again in each form and keeps a picture only where it
  differs from what the game takes instead:
  `player/forms/<build>_<figure>/<layer>.png`, else the build straight's, else the plain `player/<layer>.png`
  (`Figure._form_path`); clothes `worn/<look>/<build>_<figure>.png`, else `worn/<look>.png` (a mod's clothes
  drawn once fit every form roughly). `Figure.dressed(gear, looks)` names the form's layers
  `forms/<form>/<layer>`; a figure takes its form from them (`Figure.form_of`) for the fists and the hands'
  places (`Figure.anchors(form)`), so tools are held where its hands are.
