# Character animations review: state and what is left

Status (2026-11-19): thread «Поправить анимации персонажа» reviewed the default character's
animations one by one on the new chibi body. Done: the walk and the stand (#789), the outline under a
hand low in the frame (#790), the jump (#791), the swim (a breaststroke). Next, in this order: chop, dig, slash, reach, mow,
aim, eat, sleep, sit, row, gestures. Directions are shown in the order s, se, e, ne, n, nw, w, sw.

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
- Only the walk's frames leave the soles without an outline (`Figure._put_row`).

## How the frames are made

- `tools/art/player_art.gd` (PlayerArt): `HEAD`, the stand `BODY`, the arms from shoulder to hand
  (`SHOULDER`, `REST`, `ARMS`), the hands of each pose by view (`MOVES`), the works (`WORKS`), the side
  legs (`SIDE_LEGS`). `pose` and `frame_letters` build a frame from these.
- Frames drawn whole under the head: the walk (`tools/art/player_walk_art.gd`, copied from the reference)
  the jump (`tools/art/player_jump_art.gd`) and the swim (`tools/art/player_swim_art.gd`); `PlayerArt.whole_frame` picks them by column. A frame is
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

## The swim (done)

- The water is 0.9 cell (7.2 px) over the soles: the rows over the eyes show, the chin's row is the ripple,
  the rest tinted (a bog hides it). So the stroke is all under water; a hand raised to the chin merges
  with the face. Afloat the head has no stand `drop` in any direction, so the eyes stay over the water.
- `swim_review.py <data module> <q dir> <out.gif> <old q dir> [dirs] [title]` draws the water as the
  game does (`swim_a.py` the frames, `proto.render(..., head_up=1)` lifts a dropped head);
  `gen_swim_gd.py <module> <out.gd>` writes `player_swim_art.gd` from them.

## Next: chop

- Columns 14-17 (`WORKS` chop by view, 1 frame a second): a work with a held tool. Now the arm is drawn by
  `PlayerArt._arm` from `SHOULDER` to the hand at `WORKS` `r`, the axe (`ToolArt`, `held/axe.png`) at that
  hand turned by `a`. Drawn whole like the swim, `pose` still takes the hand and the axe from `WORKS`, so
  its `r` has to be where the drawn hand is; the held pictures are regenerated with the player's.
- To see the axe: `dump.gd` in the library (copy into `tools/`, run with
  `-- <dir> axe=<the axe's held picture under content/>:chop`, e.g. `content/tools/axe/sprites/held/axe.png` without `content/`, delete) saves the dressed sheet with the axe held;
  it reads the imported PNGs, so after a code change run `make_sprites.gd -- --all` and `--import` first.
