# Character animations review: state and what is left

Status (2026-11-19): thread «Поправить анимации персонажа» reviewed the default character's
animations one by one on the new chibi body. Done: the walk and the stand (#789), the outline under a
hand low in the frame (#790), the jump (#791). Next, in this order: swim, chop, dig, slash, reach, mow,
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
  and the jump (`tools/art/player_jump_art.gd`); `PlayerArt.whole_frame` picks them by column. A frame is
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

## Next: the swim

- Columns 10-13, `MOVES` swim by view: the arms reach out and pull back in turn, the legs kick.
- In the game the water comes up to the eyes (`tools/shot.gd` shot `fx-reflect-deep`, under xvfb); the
  body under it shows tinted in clear water and not at all in a bog, so the review GIF should draw the
  water line and the tint.
- To settle with the user: strokes moving from the shoulders as in the jump, and how much of the arms
  shows over the water.
