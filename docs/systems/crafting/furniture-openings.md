# Moving, furniture, snowman, openings

Part of [Crafting, stations and things on cells](../crafting.md). Moving and turning, furniture, the snowman, openings with the wall mended.

**Moving and turning** (2026-11-13, items 23–24 of the user's list). `Placed.movable`: a station, a chest,
furniture, a sign, a fireplace move, and since 2026-11-26 a door, a window and a hatch (below; not stairs, a
fence, a wicket, a gate, a ladder, a campfire, a cross, a boundary post); `Placed.move(who, e, corner, turn)` — the request `PROP_MOVE` [cell, corner, turn]
(in `PACED`): the free place nearest to `corner` (`move_spot`: `_spot_at` with the thing's own cells free),
within `Tools.PLACE_REACH`, land rights at both ends, the hands' stamina (`act("place")`); the thing is taken
and placed anew with what it holds, burns and says, so the copies and the save get it as an ordinary thing
(`removed`, `added`); the same cell with a quarter more turns it. A light set down (a torch, a candle) is handled as furniture, only in the build mode (a tap in the normal mode does nothing to it): it is held and moved, turned by a double tap (`turn` is saved with it), taken by a single tap, and moves by the same request: `Placed.move` hands it to `_move_light` (the cell `light_move_spot` finds: that one or one below/above, its own cell free; the same reach, land rights and stamina; it keeps what it burned). While a thing is dragged its flames (`Effects.shift_fire`, `shift_lamp`) go with it; the heat map is remade only when it is set down. The build mode drags and turns it
([interaction.md](../interaction.md)). On screen (`Props._arrive`) a thing set down while playing drops into
place from `DROP_HEIGHT` with dust of the ground under it (`Effects.dust`) and the sound `place` on landing
(lower for a 2×2 one); a thing gone and back on its cell within `RENEW_MS` was changed where it stands (a
sign written, `_renew`) and does not drop, a turned one hops; what comes with the world or on joining is still.

**Furniture** (decision 163, 7А; the bundle `tools/furniture`) — things with `furniture`: placed facing the
player, not counted stations (`Items.is_station`). A table and a rug — on 2×2 cells, a stool, a cupboard and
a barrel — on one (the cupboard two high), a wide cupboard — on two cells in width and two in height (48
places), a bed — bedding on 2×2 (`bedding` 2.5). In the inventory the divider above the cells of what it
keeps draws a scheme by its `prop` if `UiStyle.ICONS` knows it (a cupboard, a wide cupboard, a barrel),
otherwise a chest. A tap takes what keeps nothing (`Placed.is_part`). `seat`: one standing still on the thing
or near it (`Placed.SEAT_REACH`) gets stamina `seat` times faster (`Placed.seat_near` → `Vitals.rest_rate`,
set by `Character.update`). A cupboard and a barrel keep (`storage`); `keeps` — how many times slower food
spoils inside (`Placed.spoil`). Since 2026-11-23 the bundle also has a chair (planks and iron), a bench (planks and stone,
two cells long), a stone table, a stone and an iron bed (`bedding` 2.0 and 2.5), an iron safe (keeps like a
cupboard), a hide rug, a brine tub (`keeps` 0.2) and a Dutch stove (`brick_stove`: a hearth one cell square, two
high, its fire hidden inside, no `serves`); the hide for a wall and the framed flower (`plants:flower_frame`) hang
on a wall like the notice board (`wall`, `Placed.ON_WALL`; models one voxel thick on the cell's north edge). A door
wreath (an item with `wreath`) held in the hand is hung on a door at a tap (`Placed.swing` → `hang_wreath`): the door
keeps it (`wreath` in its record and save), Props draws it on the door's first leaf (`_with_wreath`) so it swings with
the door, and the door taken up gives it back. Their models are drawn by
`tools/art/voxel_furniture_art.gd` (called by `VoxelArt.prop`), the stone and iron pictures are VARIANTS of the
wooden ones in `icon_build_art.gd`.

**Snowman** (2026-11-23; the bundle `plants/snowman`) — furniture on one cell rolled by hand from snow (6),
branches (2), charcoal and a carrot. It is not a voxel model but a flat picture (the item's `picture`:
`sprites/things/<picture>.png`, drawn by `tools/art/snowman_sprite.py` from pixel circles): rows are the views
(front, back, facing left, facing right), columns the melting stages. `Props._add_sprite` stands it upright facing the
camera (the creatures' sprite shader, `sun_shadow_free`: the sun's shadow does not fall on it, its shading is drawn),
`Props.sprite_view` picks the row by the camera's turn, and a pictured thing is solid in `Placed.SPRITE_BOX`. A thing with `melts` (days of melting at `Placed.MELT_WARM` degrees) melts by
`Placed.melt`, a step of the session: by `Warmth.air` with the fires near (`Warmth.fire_heat`), not at all at 0° and
below. Its `melt` (0..1) is in its record and save; `Placed.melt_stage` (of `MELT_STAGES`) changes are told
(`melt_changed`, `Protocol.PROP_MELT`), and the client shows the stage's column. Melted through it is
gone (`melted`: `WorldActions.leave_melted` drops its `melts_to`). It is taken up only whole (`melt_stage` 0).

**Openings move with the wall mended** (the user's picks 2026-11-26, 5А and 6А; the building UX's PR 2).
`Placed.is_opening`: a door, a window or a hatch (not a wicket or a gate). Set down with `put_at`, it cuts the
blocks of its cells (`_opening_at`: its shut cells as high as it stands) and remembers them: `cut` in its
record, offset from `cell` → material id (`[[x, y, z, id], …]` in the save and in `PROP`, read by
`cut_from_list`; `{}` where it went into a gap of its size). `Placed.cut_of(e)` gives them by world cell; a door
of a save from before (no `cut`) takes the material most of the built blocks beside and over its cells are of
(`AROUND`), none in the open. `PROP_MOVE` [cell, the wall's cell pressed, turn, face] moves it
(`Placed.move_opening` → `_move_opening`; the turn is found again): its new place is found as for a new one (`opening_spot` = `put_spot` with its own cells free,
`_moving` keeps an open door out of its own way), within `PLACE_REACH`, land rights at the old cell and every new
cell, one `act("place")`. The new cells are cut (their blocks not dropped), the cells it shared with its old
place stay open and keep their remembered material, and its old cells are walled up again (`_mend`: a cube of
the remembered material): the blocks just cut pay first, then those in the bag, and a cell none is left for, or
one the player stands in, becomes a ghost block of the blueprint (`Placed.plans`, set by the session;
`Plans.put_ghosts`, the block that builds the material: `_placer`). Blocks cut and not put back go to the bag,
on the ground at the feet when it is full. [cell, cell, turn + 2] turns it the other way round in its own cells
(`Placed.move`, `flip_spot`); no other three-part `PROP_MOVE` moves an opening. Taken back into the bag (`take_up`) it leaves ghost blocks of its remembered blocks in its hole
(`_leave_ghosts`); set down or moved into cells with ghost blocks, it takes their place (`Plans.drop_ghosts`).
Drawn into the blueprint as a ghost thing (the setting «by blueprint», [interaction.md](../interaction.md)), a door
or a window takes the place of the ghost blocks of its cells and keeps them (`wall`): built, it remembers their
materials as the blocks it cut (`Placed.put_ghost`, `had`), so moved or taken back it walls its hole up with them.
