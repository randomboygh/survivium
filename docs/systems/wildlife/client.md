# Shared rules, copy and drawing

Part of [Beasts](../wildlife.md). Rules by properties, the client's copy, drawing, voices.

- `src/shared/content/ai_rules.gd` — the shared rules by properties: `reaches`, `is_food`, `is_threat`,
  `is_active`; `AiRules.SPECIES`.
- `src/client/net/remote_wildlife.gd` — the beasts' copy on the client from the server's events `animal`,
  `snap`, `animal_gone`, `step` ([network.md](../network.md)): its own `Animal` with the fields the views read,
  the same signals. Over a socket (`smooth`) the snapshots come ~10 times a second and unevenly: a beast
  glides from the place where it is drawn to the new one in the time between two snapshots (`glide`, called by
  `Creatures` every frame; farther than `GLIDE_MOST` — at once); in one's own world a snapshot every frame is
  taken as is.
- `src/client/game/creatures.gd` — draws the copy's beasts: frame 0 at rest, the steps' frames by steps, the
  wings' frames in the air; it sets the picture anew when the server moved the beast (`Animal.fresh`); a beast off every screen (`near`
  off) changes its picture only then. A beast struck flinches as the blow meets it (frames 3–4 of the swing):
  its picture jerks `FLINCH_UP` pixels up, down again over `FLINCH_JERK`, and `FLINCH_PX` pixels along the
  screen away from the one who struck, then shakes back (`FLINCH_HZ`, `FLINCH_DAMP`) and stands still after
  `FLINCH_TIME`. Meanwhile it flashes red, drawn by `sprite.gdshader` and never into the frames: wholly for
  `FLASH_HOLD`, then fading in `PixelView.FLASH_STEPS` steps till `FLASH_TIME` (`flash_step`); the step rides in
  the sprite's scale along z with the fire shadows' shade, never under 1, the culling box even about z
  (`PixelView.flash_sprite`, `shade_sprite`, `_fit`). One's own blow: `flinch` from `Controls._did` (the answer's `animal`, at `STRIKE` of the
  swing or when the shot flies past it); another player's: `struck_at` from `Others`, by the point of their
  work, as the trees' `TreeHits` (nothing new over the net): the beast drawn within `FLINCH_SLACK` of the
  point where blows land on it (`BLOW_HEIGHT` over its feet) whose striker stood within `STRIKE_REACH` of
  it; a point in a solid cell (a trunk, the ground dug) is no blow. Only the flinching ones are walked each
  frame. Shots `strike-deer`, `strike-boar`.
- `src/client/audio/voices.gd` — the voices (`calls`) and the cry of fright (`alarm`);
  `src/client/world/tracks.gd` — tracks.
