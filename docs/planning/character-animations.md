# Character animations review: state and what is left

Status (2026-11-20): thread «Поправить анимации персонажа» reviewed the default character's
animations one by one on the new chibi body. Done: the walk and the stand (#789), the outline under a
hand low in the frame (#790), the jump (#791), the swim (#792), the chop (#796), the dig (#797), the
slash (accepted 2026-11-20 12:56 MSK, the PR after #799; then from the side the arm a pixel nearer and
a sheet for the sickle, 13:13 MSK; #801). The bow's shot (the work `aim`, the user's pick 2026-11-20 13:13
MSK: the Bow Attack of Puny Characters) is drawn in every direction and in the game, accepted
2026-11-20 17:56 MSK (PR #803). The animations left (reach, mow, eat, sleep and sit, row, gestures) went to threads of
their own on 2026-11-20 17:45 MSK: see «Threads working side by side». Directions are shown in the order
s, se, e, ne, n, nw, w, sw.

## Threads working side by side (from 2026-11-20 17:45 MSK)

The user asked for a thread for each animation left, each starting with a preview (the review GIF of its
first drawing): reach, mow, eat, sleep and sit (one thread), row, gestures. The bow stayed in the first
thread (PR #803, columns 34-37). What follows from several threads drawing at once:

- Every such PR changes the same pictures (the sheets in `content/core/sprites/player/` hold every
  column, a held thing's sheet every work), and git cannot merge pictures. After another animation's PR
  is merged: rebase on main, take either side of each picture in conflict, then draw them all again
  (`make_sprites.gd -- --all`, `--import`) and check that against main only your columns differ
  (`python3 colcheck.py origin/main` from the repo's root, in the library: the columns changed in each
  picture). The pictures are made only from the art's text, which git merges.
- A new animation's frames are a file of their own (`tools/art/player_<name>_art.gd`); in `PlayerArt` it
  adds only a case to `whole_frame` and to `frame_letters`. Its checks in `view_test.gd` are a block of
  their own, and in this doc it writes only its own section.
- In the library keep your files under the animation's name (`reach-all.gif`, the data module
  `reach_a.py`). The shared tools there are read again before a change: the last write wins.
- What the reviews of the works found holds for every animation: the rules below, and for a thing drawn
  with the figure «The bow» (no dark edge of its own beside the outline, a gap of one pixel or none).

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

## The reach (done)

- Columns 26-29 (`player.yaml` `works` reach: bare hands and every thing with no work of its own, the
  default `anim`: gathering, placing, building), drawn whole: `tools/art/player_reach_art.gd` (ReachArt),
  written by `gen_reach_gd.py <module> <out.gd>` (run with `python3 -I`) from the data module
  `reach_f.py` (`REACH`) in the library. Thread «Нарисовать анимацию «взять рукой»»; the user accepted
  the front on its third drawing and every direction on `reach-all.gif` (2026-11-20).
- The frames: 1 standing, the hand lifted to the waist; 2 a crouch with the arm stretched down along
  the leg, the hand a row over the ground; 3 still crouched, the arm short again, the hand a row
  higher; 4 standing, the hand brought up to the shoulder. The other arm hangs.
- The user's rules from it: the arm is pressed to the body in every frame, with no outline between
  them («Прижми руку к телу, убери между ним и рукой обводку»: the first drawing held the arm a pixel
  away); the arm stretches together with the crouch and is short again while crouched («Тянем руку
  вместе с приседанием, присев руку сокращаем»: the second drawing stretched it standing and kept it
  long crouched).
- Turned, from the side and from behind the body stands a row lower (`drop` 1) on legs of two rows, so
  a crouched arm has a row less: the hands are kept as high over the ground as from the front (a
  stretched arm of two rows, a short one of one, the other arm of one), not the arms as long, which
  would put the hand on the ground's row beside the foot. From the side the arm goes down and forward
  in front of the body (in frame 4 the hand is at the chest: under the chin it merged with the face);
  from behind the working arm is at the picture's right, behind the body.
- A frame has `a` -1, nothing turns: what the hand holds is drawn as carried at the hand's mark (a
  torch, a log, a stone). The old `WORKS` reach turned a torch the other way in the south-west and
  north-west rows of its sheet; now its `reach` frames are its carried picture in every direction.
- Checking: after `make_sprites.gd -- --all`, `--import` and `dump.gd`, `python3 vsgame.py reach_f
  REACH <dump dir> bare reach` prints `bad 0` in all eight directions. `reach_view.py`, `reach_zoom.py`
  and `reach_cmp.py` in the library draw a module's frames big, `reach_held.py` the game's frames with
  things held on one sheet. `view_test.gd` `_test_reach` keeps the crouch, the hand's way down and up,
  the arm against the body and the still legs.
- GIFs in the library: `reach-front-1.gif` to `reach-front-3.gif` (the front's three drawings),
  `reach-all.gif` (every direction, «было» main), `reach-tools.gif` (`tools_gif.py`: things held, as
  the game draws them).

## The slash (done)

- Columns 22-25 (`player.yaml` `works` slash; the swords, knives, spears, sickles, slings, bows and rods
  play it), drawn whole: `tools/art/player_slash_art.gd` (SlashArt), written by `gen_slash_gd.py <module>
  <out.gd>` (run with `python3 -I`) from a data module in the library, now `slash_p.py` (`SLASH`).
- The user's rules: front view first, the others after it is approved. Their latest (2026-11-20 11:41
  and 11:45 MSK): 1 the sword up at the shoulders; 2 higher; 3 the swing with its trail to halfway
  between the 7th and 8th GIFs' third frames (done as `PlayerArt.LOW`, crouched); 4 the sword not
  moving, the trail gone, the figure standing again (the hand keeps its pixel: the crouch only folds
  the chest's row). Earlier: the hand holding the sword never crosses to the right half of the picture
  (it looked as if the other hand held it); the trail only on frame 3; legs never move. On every
  direction (12:17 MSK): from the side the trail is the front's crescent at the side, not over the head
  (up behind the head, down behind and under to the blade in front), the arm with the sword not so far
  back, the raised sword's tip in the trail; from behind the trail hides behind the body. From the side
(13:13 MSK) on frames 1 and 2 the arm a pixel nearer the body (the sword over the back of the head's
outline, its tip in the trail's first pixels).
- The reference: Puny Characters (Shade, CC0, opengameart.org), `Character-Base/Warrior-Blue.png`, row 0
  is the front, columns 4-7: raised, raised, the smear (a white crescent), stopped. `cmp_ref.py` puts
  its frames beside ours.
- GIFs in the library: `slash-front-8.gif` (reference beside ours), `slash-front-9.gif`,
  `slash-front-10.gif` (the front, accepted 2026-11-20 12:02 MSK); `slash-all-11.gif`, every direction
  in this logic («было» the 4th iteration, `slash_e`, the last time the user saw them all; from the side
  then up behind the head and over in front of the face); `slash-all-12.gif` (`slash_o`: the side as the
  front, the trail behind the body from behind; «было» `slash_n`); `slash-tools-12.gif` (`tools_gif.py
  <dump dir> slash <out.gif> name=Подпись,...`: a row per held thing, a column per direction, as the
  game draws them).
- The trail (the user's pick: white, no outline, over the figure, only on frame 3): a frame's `trail`
  (`at` and rows in image pixels; in the data module `smear`), the letters `o`, `+`, `-` of
  `PlayerArt.INK`, drawn into the layer `player/trail.png` (`player.yaml` `trail`); `Figure._put_trail`
  draws it after the outline in the columns of the work the right hand's thing plays, for items with
  `trail: true` (swords, knives, sickles; the editor names the field): over the figure, or only into the
  frame's empty pixels where the thing is behind the body (`f` false). `work_proto.py` draws it so with
  `SMEAR=free` (or `outlined`, `none`).
- Checking: after `make_sprites.gd -- --all` and `--import`, `dump.gd` with the sword held
  (`content/tools/sword/sprites/held/sword.png`, given as `sword=` its path under `content/` and
  `:slash:trail`) and `SMEAR=free python3 vsgame.py slash_p SLASH <dump dir> sword slash` must print
  `bad 0` (without `:trail` and with `SMEAR=none` too). `variants_gif.py` makes the front's GIF,
  `work_review.py` every direction's, `igrid.py` and `asc.py` a frame's pixels.
- A rod out fishing is held as in the last frame (`Player.ROD_OUT` 3). The sickles have sheets
  (`ToolArt` `sickle`, a flint blade hooked over to the tip; copper and iron recoloured): their icon cut
  to 5 pixels (`held` `icon`) left a single pixel of the handle (the user, 13:13 MSK: «серп практически
  не видно»).
- Accepted by the user 2026-11-20 12:56 MSK on the 12th GIF; the side's arm and the sickle after it.
  Bows and slings play the slash until the aim is drawn.

## The bow (done)

- Columns 34-37 (`player.yaml` `works` aim; the wooden and the composite bow play it), drawn whole:
  `tools/art/player_aim_art.gd` (AimArt), written by `gen_aim_gd.py <module> <out.gd>` (run with
  `python3 -I`) from a data module in the library, now `aim_e.py` (`AIM`; `aim_a.py` has the frames, `aim_b`
  the back-turned view as the reference draws it, `aim_c` the grey arrowhead from the front, `aim_d` the
  back-turned bow as an arc and the pass that takes the doubled outline off, `aim_e` the turned view's
  string without its tail over the legs). A frame draws the bow too (`bow`: rows of `ToolArt.INK`
  letters from their corner's offset from the grip; in the data module `F(...)` builds it from the bow's
  rows at box row `btop`, its `g` or `grip` at the hand), since the string and the arrow change in each
  frame; `ToolArt.sheet` draws it for a shape with `bow` (the composite bow recoloured: `P` `Z`, `p` `z`).
  `two`: the other hand draws the string and shows no thing of its own; the bows have `hands: 2` (the
  validator wants an item's hands to be its work's).
- The reference: Puny Characters (Shade, CC0), `Character-Base/Archer-Green.png`, rows s, se, e, ne, n,
  columns 8-11: drawn (the arrow at the viewer from the front), loosed (the string still bent, the hand
  back), the string straight, the bow lowered (the body a row up). In the library
  `references/puny-archer-bow-attack.png`; `aim_ref.py`, `aim_zoom.py <module> <dirs> <out.png> [Z]` (ours
  over the reference), `aim_variants.py` (the front's GIF of the two orders).
- Two orders were offered (a decision card, 2026-11-20): A as in Puny (drawn, loosed, straight, lowered;
  the arrow would leave on the second frame) and B, recommended and drawn: nocked at the hips, drawn,
  loosed, down again, so the arrow leaves on the third frame as every work strikes (`Controls._did` flies
  it half the swing later for the aim). Our bow is light wood (`P`, `p`) with a dark inner edge (`K`): the
  icon's brown is lost over the bare skin.
- The user's review, 2026-11-20 (MSK): 16:39 «На кадрах 1 и 2 "северо-восток" нужно скруглить лук (там где
  у персонажа лицо), стрелу сделать линией (сейчас там какой-то черный полукруг в воздухе). На всех кадрах
  вида спереди сделать наконечник стрелы серым, как в виде сбоку»; 16:42 the order B picked on the card;
  16:55, on the arc drawn round the head (`aim_c`, `bow-all-3.gif`): «было нормально, верни. Просто закругли
  видимую часть лука (она там была прямой)» (they wrote «юго-запад», the view meant is the back-turned one);
  16:56 «А стрела в этом виде хорошо получилась»; 16:57 «А еще убери двойную линию обводки на некоторых
  видах»; 17:43, on `bow-all-4.gif`: «Тетива на виде "Юго-Восток" заходит на ноги - убери лишние 3
  пикселя»; 17:56, on `bow-all-5.gif`: «Все хорошо».
- The string never runs over the legs. Turned to the viewer (se) the crescent's lower end is under the
  frame's edge (box row 17 is never drawn), and the string went on to it across the hips and the left
  leg. `aim_e` takes three pixels off each frame: at rest the string ends beside the limb on the hips' row
  (box 9, 15); drawn, its lower half (from the hand down the belly and the leg) is gone, it goes from the
  bow's upper end to the hand. `aim_try5.py` has the variants looked at, `aim_closeup.py <new> <old> <dir>
  <out.png> <title>` draws one direction big, «стало» over «было», for a change too small for the GIF.
- So the rules for a thing drawn whole with the figure: no dark edge of its own (`K`, the arrowhead's `x`)
  where the figure's outline goes, or the outline reads two pixels thick; a dark letter stays only inside,
  between the wood and the skin or the string. `aim_d.peeled` takes such pixels off each frame as it is
  drawn (the default body), `dbl.py <module>` counts the 2x2 dark blocks left (70 in `aim_c`, none of the
  bow's in `aim_d`: the four left are the gap between the legs from behind), `lay.py <module> AIM <dir>`
  prints a frame as text in box coordinates with `!` for a doubled pixel. Two outlines side by side are
  the same fault: a gap of two empty pixels between the body and the thing turns dark whole, so the gap is
  one pixel or filled (turned away, the string runs between the body and the limb; drawn from the side the
  limb is a pixel thicker beside the arrow; drawn turned, the upper limb is two pixels wide).
- Turned away the bow stays where the reference has it, by the body's right side under the cheek, the
  hands as in `aim_b`; only its visible part is an arc (rows 10-16, the ends in by a pixel), and the arrow
  is a line two pixels a row from the near hand up and right through the bow, its head grey with a grey
  point. Drawn, the bow is a pixel higher and the light pixel of its upper end, which would touch the ear,
  is left out.
- From the front the bow's mark (`hands[0]`) is above the frame's neck, which `PlayerArt.pose` moves in no
  build: with the mark at the grip (x 6) the stocky build took the whole bow a pixel left.
- GIFs in the library: `bow-front-1.gif` (the front, A and B beside the reference), `bow-all-2.gif`
  (every direction, B; «было» the slash the bows played), `bow-all-3.gif` (`aim_c`), `bow-all-4.gif`
  (`aim_d`), `bow-tools-4.gif` (both bows as the game draws them), `bow-all-5.gif` and
  `bow-se-string-5.png` (`aim_e`, accepted).
- Checking: after `make_sprites.gd -- --all` and `--import`, `dump.gd` with the wooden bow
  (`content/tools/bow/sprites/held/wooden_bow.png`, given as `wooden_bow=` its path under `content/` and
  `:aim`) and `python3 vsgame.py aim_e AIM <dump dir> wooden_bow aim` must print `bad 0` (it does for
  `aim_e`); `tools_gif.py` shows both bows; `dump_forms.gd <out dir> <held png under content/> <work>`
  saves the sheet in every build (the bow was looked at in the thin, the normal and the stocky one).
  `view_test.gd` checks two of the review's rules on the wooden bow's sheet: no block of two by two dark
  pixels that the figure does not have without the bow, and no pixel of the string over the legs.

## The eat (under review)

- Columns 38-41 (`player.yaml` `works` eat; what is eaten or drunk plays it: an item's `anim: eat`), drawn
  whole: `tools/art/player_eat_art.gd` (EatArt), written by `gen_eat_gd.py <module> <out.gd>` (run with
  `python3 -I`) from a data module in the library, now `eat_b.py` (`EAT`; `eat_a.py` has the front's two
  variants).
- The user's pick (2026-11-20, a decision card on the front's GIF): A, the bite is a nod. The food raised
  to the chin on frame 2 stays where it is and the head comes a row down onto it on frame 3, the eyes shut
  (the chest's row folds away, the legs never move, the other arm hangs where it does standing). B was the
  head still and the food a row higher.
- The frames: 1 the food lifted to the belly, the elbow by the side (the arm a row shorter); 2 raised to
  the chin, the hand beside it; 3 the bite; 4 as 1 with the eyes shut, chewing. A frame's `eyes` "shut" is
  read by `PlayerArt.pose` for any work drawn whole.
- The food has no sheet: it is the item's icon cut down to 5 pixels (`Figure._small`), its middle at the
  hand's mark (`hands[0]`; `a` -1: as carried), in front of the body or behind it (`f`), the hand's digits
  (the fists' layer) over it. So the mark is where the food's middle goes, not where the hand is, and the
  hand is drawn beside the food, not across it. A 5 by 5 food is as tall as the torso.
- An icon is not mirrored with the figure, and `hold = size / 2` puts the middle of one of an even width a
  pixel left: in a west direction a 4-pixel icon (the apple, a mushroom) sits a pixel further from the body
  than in its east one, its stalk on the other side. The frames are drawn for both: from the side the hand
  reaches a pixel into the food (no gap in the west twin), turned the food's mark is between the two
  places. Mirroring the icons of the west rows in `Figure._put_things` would make them exact; not done,
  it would move every icon held in every animation.
- A pixel enclosed between the body, the hand and the food is outlined, a dark dot: keep the food against
  the body or the hand (from the side the hand goes under the chin).
- From behind (ne, n) the food is behind the body (`f` false): its mark is where the body hides it (n) or
  lets its edge show past the neck (ne); the elbow goes up to the shoulder's height and the nod shows.
- Light food (a flatbread, roasted meat) reads poorly over the bare skin: an icon has no outline of its own
  over the body. Not solved.
- Tools in the library: `eat_proto.py` (a frame with the icon as the game draws it, the west twin with the
  icon not mirrored; `icon_small.py` is `Figure._small` with Godot's rounding), `eat_sheet.py` (still
  frames, big), `eat_review.py` and `eat_all.sh` (the GIFs), `eat_vsgame.py <module> <attr> <dump dir>
  <sheet>=<icon's content path> ...` against `dump.gd` sheets made with `<sheet>=icon:<icon's content
  path>:eat`: it prints `bad 0` for the bare hands, the apple, the roasted meat and the flatbread.
- GIFs in the library: `eat-front-1.gif` and `eat-front-1-frames.png` (the front, A and B), `eat-all-2.gif`
  and `eat-all-2-meat.gif` (every direction; «было» is main's poses with the same food).
