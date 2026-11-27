# Stations by flags, size and turn

Part of [Crafting, stations and things on cells](../crafting.md). Stations by flags, the size and turn of a thing.

**Stations by flags.** `prop` is an open class of a thing (the model, the solid parts), and what it does is
said by the item's flags: `storage` (keeps things, a chest: 16 places, a big chest: 40; such a thing is not a
station), `fire` (burns: is put out, lit with fuel, burns whoever touched the logs (`Placed.FLAMES_HALF` — the
same half-cell from the middle as `FIRE_BOXES`, plus the body's width) or bumped into them by a step
(`Body.bumped`): `Vitals.BURN_LOW`..`BURN_HIGH` by its fuel (`Placed.fuel_share`), the knock `Character.BURN_KNOCK`; one can warm up on the stones around; only
the logs in the middle are solid, cell by cell, `Placed.FIRE_BOXES`, the ring of stones is passable; a fire
with a model of its own is a hearth, `Placed.is_hearth`: the 2×1 fireplace of the bundle `tools/fireplace` is
solid by its model, does not burn, is placed cold (`fuel_start` 0), an extinguished one is taken into the bag,
the flame is drawn by `Effects.add_campfire(…, hearth)` in the middle of its cells, one cooks at it what one
cooks at a campfire (`serves`)), `repairs` (tools are repaired at it: a workbench), `serves` (replaces the
named stations: their recipes and repair), `place_tool` (placed only if the bag has a tool of this class).
`Placed` and `Workshop` ask the flags; a new station is only data: an item, a model, an icon, recipes.

**Size and turn.** A thing occupies a square of cells by the slice of its model (`Placed.sizes`: a slice of
16 voxels — 2×2, 8 — one cell) and is placed facing the camera (`turn`: 0 — facing south, 1 — west, 2 —
north, 3 — east; stored in the save and goes to the copies): the client sends the view's turn
(`Props.view_turn`, the last arg of `PROP_PUT` and `PROP_PUT_AT`) and a station, a chest, furniture and a
sign take it (`Placed.faces_view`, the user's ask 2026-11-13), while a door, a window, a hatch, stairs, a
fence, a ladder and a board on a wall still face the player, as the wall or the climb needs (a request
without the turn — a bot — faces the player too). In the build mode (`Placed.put_at`, `put_spot`) the best turn
is taken by itself where there is one (the user's pick 2026-11-26): a door, a window, a wicket or a gate goes in
the plane of the wall or the fence it is set into or stands in, its front to the player (`Placed.plane_turn`:
the way with more solid cells or fences beside the cell tapped, so a door set into a doorway left in a wall or
at a wall's end goes on along it; at a tie — a corner, a pillar — across the face tapped, the last arg of
`PROP_PUT_AT`, a `Placed.SIDES` index, an opening moved over a corner's top in the plane of the wall it was
in; in the open as the player faces; never across its wall: of the spots round the cell, `_wall_spot`, one with
more wall beside its cells across its plane than along it, or in a corner's cell, is skipped, `_across`, and a
moved opening's own cells (a ghost one's too, `_moved_opening`) count as its wall, `_moving_cells`; user
2026-11-27, a door dragged by a corner stood across the wall; and each column of the opening has a block it
cuts, a cell of a gap left in the wall or of the moved opening, `_wall_cells`, else the spot is skipped: user
2026-11-27, doors stood on the ground before a house whose wall was too short for them and on a bare floor);
a thing that faces the view and a
ladder set down by a wall turn their back to it (`Placed._backed`: of the four turns the one whose spot has the
most solid cells right behind its back edge, then the fewest open ones, so a bed lies along the wall; a tie
keeps the view's or the kept turn), in the open they take the view's (or the kept) turn as before; a ladder put
on a ladder keeps its turn. Solid and occupied are only the cells where its
voxels are (`Placed.cells_of`), the model and boxes turn together (`Placed.turned`, `Props._model`). A ladder
is an item with `steps`: its solid parts are boxes by quarters of a cell (`WorldData.blockers` stores an array
for a cell), the body steps up the half-cell steps with no jump; it is placed over a void too, a tap takes it
back, it is not counted a station. A door is an item with `door`: the leaf is drawn along the north edge of
its cell and stands shut in the middle of its depth, between the wall's faces as a window does
(`Placed.shut_voxels`, `DOOR_SHUT`, 2026-11-27); a door and a window are drawn alike from both sides, the
front half of the model's leaf (and the handle before it) mirrored onto the back (`VoxelProps.two_faced`, user
2026-11-27), a tap (`Protocol.PROP_OPEN`, `Placed.swing`, the plot's right «Open doors») turns it on a hinge in
the north-west corner to the west edge (`Placed.open_voxels`, as it is drawn); an open door is solid nowhere
(`opened_boxes` are empty: a thrown-back leaf would occupy a quarter of the opening that a body barely passes
and would stand into the one who opens), nothing is placed in its opening (`Placed._in_open_door`), with a
body in the opening it does not close; the copies learn from `PROP_OPENED`, the state `open` in the save. A
door in a wall (`Placed.is_wall_door`: not a hatch, a wicket or a gate) also opens by itself when a player walks
into it (`Placed.walk_open` from `Session.step_players`, user 2026-11-27): the client's step stops short at it
(`Body.bumped`, sent in `INPUT`), the server opens a shut door there no farther than `WALK_OPEN_REACH` from the
feet, where the land gives «Open doors»; it stays open, a tap shuts it, and it stays shut until walked into again. A
door two cells wide (2×2, 2×3) is double-leaf: the west leaf opens to the west edge, the east one on a hinge
in the north-east corner to the east. A window is an item with `window`: a frame with glass, solid, a tap
takes it (`Placed.is_part`), the light of the sun, moon and fires passes through it (`Placed.lets_light`), and
through a closed door — not; windows 1×1, 1×2, 2×1, 2×2, 3×2 (width × height); doors 1×2, 2×2, 2×3 and gates
3×3 (two leaves of a cell and a half each). **A fence** (stage 1, item 5; the bundle `tools/fence`) is an item
with `fence`: a post in the middle of the cell, rails to each neighbouring cell of its level where there is a
fence, a wicket or a gate (`Placed.joins`, `join` — the bits of the sides `Placed.SIDES`; a lone link — rails
across its face; the neighbours are rebuilt when a link is placed or taken, the signal `joined`, `Props`
draws the post and the model's north rail turned to each side); solid up to `Placed.FENCE_TOP` (2 cells —
above a jump), so a body neither passes nor jumps over, and beasts do not come in (`Wildlife._fenced`: a
thing higher than a cell and a half is a wall for a beast, a chest is still passable); a tap takes it in build
mode (`is_part`), it is built there by a blueprint, a line or a square (`Plans.is_fence`). A wicket (1) and a
gate (2) are doors with `fence`: a leaf of rails in the middle of the cell, of the same height of solidity,
an open one swings out to the south on a hinge at its edge (`Placed.swung_voxels`); a tap with a wicket on a
fence link in build mode puts it in its place, the links go into the bag (`Placed._swappable`). **A hatch**
(`tools/hatch`, 1×1 and 2×2) is a door with `hatch`: the lid at the top of its cell, a closed one is solid as
a floor; it is placed into a floor or a ceiling of built blocks (a tap on a block takes it out, `rest_of` →
`IN_FLOOR`: a solid cell next to it), an open one raises the lid on a hinge at the north edge into the cell
above it. **A leaning ladder** (`tools/ladder`) is an item with `ladder`: a link per cell at the back side of
its cell, not solid — its cell is in `WorldData.ladders` (cell → turn); it is placed on the ground or on the
link under it (`ON_LADDER`), a tap on a ladder with a ladder in build mode extends it from above with the same
turn; climbing — `Body._climb` ([character.md](../character.md)). A thing higher than a cell (a door) is placed
only if there is air above it. A thing that occupies only a row of its square (a door or a window wider than
a cell, a fireplace) is placed into the cells right before the player (`_spot_in_front` aims at the middle of
its cells), and is tapped there too: `Placed.center` — the middle of the occupied cells (`Placed.middles` by
the turn), not of the square.
