# Character animations review: state and what is left

Status (2026-11-20): thread «Поправить анимации персонажа» reviewed the default character's
animations one by one on the new chibi body. Done: the walk and the stand (#789), the outline under a
hand low in the frame (#790), the jump (#791), the swim (#792), the chop (#796), the dig (#797). In
review: the slash (the front first). Next, in this order: reach, mow, aim, eat, sleep, sit, row, gestures. Directions are shown in the order s, se,
e, ne, n, nw, w, sw.

## How the user reviews

- One animation at a time. A GIF of it in all eight directions as the game plays it, big, and under each
  direction its frames in two rows, «стало» (new) and «было» (main). The model is
  `survivium-builds/character/anim/jump-all-3.gif` in the project library; pictures go to
  `survivium-builds/character/anim/` and are attached to the thread reply (a thread holds 24 attachments).
- The user pins comments on the GIF; apply them, render again, until they say it is good. Then one PR per
  animation, merged once CI is green.
- A design choice: the variants side by side (one direction is enough) and a decision card with a
  recommendation; meanwhile draw the recommended one in every direction.

## The user's rules for the drawing (2026-11-19)

- The proportions of the walk's reference (`survivium-builds/character/anim/references/`): bare arms
  and legs two pixels wide.
- An arm moves from its shoulder, and the shoulder starts right under the head: move those parts, not a
  hand alone. Recolouring pixels that are there is often enough; a move does not have to add pixels.
- Turned (se), from the side (e) and from behind (ne, n) the head sits a row lower (`BODY` `drop` 1), so
  the figure is as tall standing as walking. The west directions are the east ones mirrored.
- From behind the hand's lower two pixels are a tone darker (`ARMS` n `hand`).
- Only the walk's frames leave the soles without an outline (`Figure._put_row`). The frame's last row
  never has an outline under it (the feet stand on it): the user checked that it is so in every
  animation. Anything beside the feet keeps a pixel of outline between.
- In a work the legs never move: a crouch folds the chest's row away (the dig).

## How the frames are made

- `tools/art/player_art.gd` (PlayerArt): `HEAD`, the stand `BODY`, the arms from shoulder to hand
  (`SHOULDER`, `REST`, `ARMS`), the hands of each pose by view (`MOVES`), the works (`WORKS`), the side
  legs (`SIDE_LEGS`). `pose` and `frame_letters` build a frame from these.
- Frames drawn whole under the head: the walk (`tools/art/player_walk_art.gd`, copied from the reference)
  the jump (`tools/art/player_jump_art.gd`), the swim (`tools/art/player_swim_art.gd`) and the chop (`tools/art/player_chop_art.gd`); `PlayerArt.whole_frame` picks them by column. A frame is
  `bob` (the head's place, the stand's `drop` in it), `hips` (the waistband's row), `hands` (right, left:
  the hand's lowest pixel next to the body, less the bob; where what it holds goes) and `rows` (box rows
  10-17 in the letters of `PlayerArt.INK`, the hands' skin in the digits of `WalkArt.HANDS`: 4, 5, 6 the
  right hand light, shade, deep; 7, 8, 9 the left). Nothing may be drawn in a row where the head is: the
  shirt's layer is over the skin's. A new animation drawn so gets its own module and a case in
  `whole_frame` and in `frame_letters`.
- The body's forms (`FormsArt.body`) are transforms of any rows: stocky two pixels wider from the neck
  (the jump: from its first drawn row) to the waist, thin with one-pixel hands, a bust's shade, hips.
- The sheet's layout is `content/core/sprites/player.yaml`: idle 0-1, walk 2-7, jump 8-9, swim 10-13
  (5 a second), works 14-41, sleep 42, sit 43, row 44-47, gestures 48-59.
- Regenerate with `godot --headless --path . --script res://tools/make_sprites.gd -- --all` (about five
  minutes), then `--import`; check that only the animation's columns changed in the pictures.

## Tools in the library (`survivium-builds/character/anim/src/`)

- `quick.gd`: the default look's bare sheet drawn straight from PlayerArt in seconds (copy it into
  `tools/` as a temporary script, run it with `-- <dir>`, delete it): `bare.png` and `layout.json`.
  `forms_quick.gd` (`-- <out.png> <columns>`) draws every body form, `dressed_quick.gd` the plain clothes.
- `proto.py` with `stands_data.py` and `jump_data.py`: draws rows of letters under the head of a quick
  sheet, to try frames before writing them in the code; `jump_sheet.py` puts such frames into a sheet.
- `jump_review.py <q dir> <out.gif> <old q dir>`: the review GIF (the frames from `layout.json`).
- `dump.gd` (copy into `tools/`, run with `-- <dir> name=<held picture under content/>:<work>[:trail]`,
  delete) saves the dressed sheet with the thing held (`:trail` for a blade's trail); it reads the
  imported PNGs, so after a code change run `make_sprites.gd -- --all` and `--import` first.

## The swim (done)

- The water is 0.9 cell (7.2 px) over the soles: the rows over the eyes show, the chin's row is the ripple,
  the rest tinted (a bog hides it). So the stroke is all under water; a hand raised to the chin merges
  with the face. Afloat the head has no stand `drop` in any direction, so the eyes stay over the water.
- `swim_review.py <data module> <q dir> <out.gif> <old q dir> [dirs] [title]` draws the water as the
  game does (`swim_a.py` the frames, `proto.render(..., head_up=1)` lifts a dropped head);
  `gen_swim_gd.py <module> <out.gd>` writes `player_swim_art.gd` from them.

## The chop (done)

- Columns 14-17, drawn whole with the axe: `tools/art/player_chop_art.gd`, written by
  `gen_chop_gd.py <module> <out.gd>` from a data module (the last: `chop_k.py`, built on `chop_e.py`, the
  third review the user went back to). A frame: `rows` from box row `top` (a raised arm beside the head),
  `bob`, the hand's grip `r`, the axe's way `a`, `ccw`, `f`. `PlayerArt.pose` takes the hand and the axe
  from the frame (`WORKS` has no chop); the west is the east mirrored, the axe in the left hand there.
- Tools: `work_proto.py` renders a frame with the axe as the game does (checked pixel for pixel against
  `dump.gd`), `sheet.py` a still sheet, `work_review.py` the GIF; `OLDMOD=<module>:CHOP` shows the
  previous iteration as «было», which the user asked for. `chop_d.py` has `turn` and `stretch`.
- The user's rules from it: crouch on the strike (frame 3), upright on 4; the torso moves on frames 1-2;
  the edge toward the chop; the arm goes along the tool. A reference that helped: Irog's Axeman
  (CC-BY 4.0, opengameart.org/node/190386, in `survivium-builds/character/anim/references/chop/`);
  `chop_j.py` builds frames from a pose, the tool's way and the arm's length, if a later work wants that.

## The dig (done)

- Columns 18-21, drawn whole with the shovel: `tools/art/player_dig_art.gd`, written by
  `gen_dig_gd.py <module> <out.gd>` from `dig_h.py` (the fourth review, accepted 2026-11-20). A frame
  has `slide` too: the hand holds the shaft that far up its length (`ToolArt.turned`, capped so
  `ToolArt.SLIDE_LEFT` rows stay past the hand: the ice pick, auger and winter rod, which dig too, are
  held less far up; the hoe and the watering can have no sheet and turn their icon). The shovel's blade
  has a straight base now (`ToolArt.SHAPES` shovel, the user's note).
- The user's rules from it: three frames of the blade going deeper from the feet's level, then the
  toss, in every direction; the legs never move; the tool beside the feet, not over them; from the side
  and behind the tool not far forward of the body. `view.py <module> <attr> <dirs> <out.png>` in the
  library draws a module's frames big with the ground line.

## The slash (in review, 2026-11-20)

- Columns 22-25 (`player.yaml` `works` slash; the swords, knives, spears, sickles, slings, bows and rods
  play it), drawn whole: `tools/art/player_slash_art.gd` (SlashArt), written by `gen_slash_gd.py <module>
  <out.gd>` (run with `python3 -I`) from a data module in the library, now `slash_j.py` (`SLASH`).
- The user's rules: front view first, the others after it is approved. The blade goes along the user's
  pink arc (uploads `b041d53b…`, `f40d7e5b…`): from above the head's left side in the picture, down beside
  it, across the belly to the right hip; fast at first, slowing; NOT over the top; the last frame's blade
  30-45 degrees down (30 is `PlayerArt.LOW`); crouched on the strike; the hand never crosses to the
  right half of the picture (it looked as if the other hand held the sword); frames 3 and 4 must differ.
- The reference: Puny Characters (Shade, CC0, opengameart.org), `Character-Base/Warrior-Blue.png`, row 0
  is the front, columns 4-7: raised, raised, the smear (a white crescent), stopped; the hilt stays left
  of the belly's middle in the last two. `cmp_ref.py` puts its frames beside ours.
- Iteration 8 (`slash-front-8.gif`, front only, waiting for the user): 1 blade upright beside the head
  (box 0,7, bob -1), 2 blade `LOW_LEFT` from the chin, 3 crouched, the hand at box (6,13), the blade at
  the viewer (TOWARD) between the legs, a trail along the arc, 4 the same hand, the blade `LOW` right.
  The code now has iteration 11 (below), the front unchanged.
- The trail (the user's pick: white, no outline, over the figure, only on frame 3): a frame's `trail`
  (`at` and rows in image pixels; in the data module `smear`), the letters `o`, `+`, `-` of
  `PlayerArt.INK`, drawn into the layer `player/trail.png` (`player.yaml` `trail`); `Figure._put_trail`
  draws it after the outline in the columns of the work the right hand's thing plays, for items with
  `trail: true` (swords, knives, sickles). `work_proto.py` draws it with `SMEAR=free` (or `outlined`,
  `none`).
- Checking: after `make_sprites.gd -- --all` and `--import`, `dump.gd` with the sword held
  (`content/tools/sword/sprites/held/sword.png`, given as `sword=` its path under `content/` and
  `:slash:trail`) and `SMEAR=free python3 vsgame.py slash_k SLASH
  <dump dir> sword slash` must print `bad 0` (without `:trail` and with `SMEAR=none` too).
  `variants_gif.py` makes the review GIF, `igrid.py` a frame's pixel grid.
- Iteration 11 (`slash_k.py`, the draft `slash-all-9-draft.gif`, not shown yet: the user wants the
  front first): every direction in the front's logic. Turned (se) as the front; from the side (e) the
  arc edge on: upright behind the head, up forward in front of the face, straight forward on the strike
  (its trail a crescent in front of the head), down forward; from behind (ne, n) the front mirrored, the
  blade hidden in front of the body on the strike, only its tip past the left side at the stop. A rod
  out fishing is held as in the second frame (`Player.ROD_OUT` 1): at the strike it points at the
  viewer from the front and does not show. A sickle in the hand is its icon cut to 5 pixels (`held`
  `icon`): barely seen, its trail shows the swing.
- Left: the user's review of the front, then of every direction; then the PR (the WIP commits on the
  branch are squashed by the merge).
