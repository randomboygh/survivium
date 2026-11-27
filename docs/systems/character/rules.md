# The character's rules, death, going far

Part of [The character: bag, strengths, skills, body, death, sprite](../character.md). The character's rules, the death screen's look, going far.

- `src/shared/game/character.gd` — the character's rules (`in_hands`, `act`, `give`, `eat`, `wear`,
  `take_off`, `throw_away`, `die`, `revive`, `respawn_points` (with `find_respawns`: the last own bed —
  respawning lying in it, `Placed.lying_spot`, — then own and the team's campfires, `docs/systems/territory.md`),
  `to_dict` / `from_dict`); the signal `state_changed`. The death sack lies `SACK_DAYS` (2) game days: the
  fifth field of its record in `WorldData.drops` is the day (`Clock.now`) when it will vanish;
  `WorldActions.expire_sacks` (the session's step once per `Session.SACK_CHECK` s) removes it with its things
  from the loaded chunks (in a forgotten chunk — when it loads), and the character's `sack_ends` (beside
  `sacks`, in the save; for old sacks — for ever) remove the mark from maps even with no chunk
  (`_forget_old_sacks`, `forget_sack`). A sack taken not whole keeps its day. The death screen writes how long
  it will lie (`death.sack_days`). A cross at the sack's place: the sixth field of the sack's record is who
  died (`grave_of`: the player's name, the cause, the day, how long they lived, the `life` counters above 0).
  `going` — where the character is about to go (`Session.zones` makes the world there; request `prepare`).
- `src/client/view/death_fx.gd` — a death's look behind the death screen (user's picks 2026-11-23): the body
  lies where it fell as asleep (`Player.dead`, no letters «z»), and one look of `DeathFx.LOOKS` is picked at
  random at each death, never the one before: a light rising over the body, dust blown off it (the body goes,
  `Player.dissolve` → `sprite.gdshader` `dissolve`), sepia with a closing vignette, flowers coming up round it,
  a ghost rising, rings running out over the ground, night falling but for a warm patch, moths, falling leaves,
  snow, a constellation of a figure over it, fog creeping in. The grade does the world's part
  (`grade.gdshader` `death_*`: `death_look` 1-based, `death_mix`, `death_time`, `death_at` the body in world
  pixels, `death_light`), the control draws the small things over the picture, a pixel of the low-res image
  each (`CameraRig.origin_px`, `view_scale`). At the moment of death the world slows (`SLOWEST` → 1 over
  `SLOW_FOR`, only in one's own world with no one else in it: `Engine.time_scale`), the world's sounds and the
  music are muffled while it lies dead (`Sound.hush`), the sound `death` plays and the look's own
  `death_<look>` after `LOOK_SOUND_AT`; the clock is the real one. On coming back it fades out (`FADE_OUT`).
  The death screen's red shade is drawn only without a look. Shots `death-<look>` (`death_look`, `death_step`
  a frame).
- `src/client/game/trip.gd` — going far (user's pick 2026-11-16): `go(at, then)` asks the server to make the
  place ready (`prepare`), Main builds the chunks round it (`ChunkStreamer.set_focus`) and `then` runs once
  the chunks on its screen are built (`focus_built`) or after `MOST_MS` (20 s). The death screen's respawn
  buttons go this way (the button shows «Getting the place ready… N%»; the first point is built behind the
  screen already), and so do the test page's «Go» to a place (`Character.travel_to_column`) and «To the
  place of death» (`Settings.go_to_death`): the player goes on meanwhile.
  When the sack vanishes, `expire_sacks` returns where it lay and who died, and the session puts a cross there
  (`Placed.put_grave`: the first item with `grave`, at the base `core:grave`; in the sack's cell or the nearest
  free one within `Placed.GRAVE_REACH` (3) cells, a level above or below; no place — no cross). The cross's
  record (`grave`, cleaned by `Placed.grave_record`) goes into the save and to the copies as for signs; above
  the cross within `Placed.SIGN_READ` cells `sign_labels.gd` writes `DeathScreen.grave_text`: «Here lies
  «name»», the day and how long they lived, the cause, the distance walked and the two biggest life counters
  — in the player's language. A cross is not written on; one removed in build mode (`take_up`) vanishes,
  nothing goes into the bag. A death with an empty bag leaves no sack: the cross stands at once (`die`), beside
  the body. Fall damage (`_fall` in `update`): the height is counted from the level where the feet last stood
  (`Body.standing` — by the world, at the place the client sent, not by its word; a jump adds nothing), more
  than `Vitals.FALL_SAFE` (6) levels — `FALL_PER_LEVEL` (8 health) for each beyond (`Vitals.fall`, `hurt_by` "fall", «You
  crashed»); water under the landing place of 2 cells and deeper puts the fall out, of one — halves it
  (`Body.water_under`). A jump down faster than any fall (a teleport), the test's «jumps in the air» and
  `forget_fall` (respawn, `Player.teleport`) begin the count anew; on a leaning ladder (`Body.on_ladder`) there
  is no fall, the count goes from it. The test switch «Fall damage» (`Vitals.falls` off) makes every fall harmless; «Invulnerability» (`Vitals.harm` off,
  sent to a playtest server as `harm`, `Cheats.VITALS`) keeps health from going down at all.
  A plant that pricks (its `pricks`: a cactus, which is also `solid`) pricks a body touching it within
  `PRICK_REACH` cells or walking into it (`Body.bumped`): its `pricks` of health (`hurt_by` `plant:<id>`, the death
  screen «Pricked to death» with the plant's name), a push away from its root (`PRICK_KNOCK`, `PRICK_HOP`), and
  not again before `PRICK_PAUSE` (`_touch_spines`, asked of `Body.solid_near`); not while riding.
