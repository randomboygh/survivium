"""The boar, thirteenth drawing: the hurt (the flinch at a blow) at size B, direction by direction, from
the reference's four hurt frames, in the boar's own colours: the reference paints frames 1-3 red, and
the game flashes a hurt animal red with a shader instead (the user, 2026-11-21).

The reference's south: 0 as it stands; 1 the body a pixel lower, as the idle's sunk frame (the chest's
lower row on the legs' tops), the eyes squinting (the upper lids down, the whites' lower pixel left);
2 a pixel lower again, the face a row shorter with the eyes shut (a dark dash each, the two eye rows in
one); 3 as 1. The ears, the mane and the tusks stay as standing.

The reference's north ducks its head instead: 1 the neck a row shorter (its two narrow rows one; the
body's outline as standing, the mane's dark line a row down its back, the tail a pixel lower inside
it); 2 the back a row shorter as well; 3 as 1. At size B the stand has one narrow neck row (its cut
leaves out the reference's rows 7, 8, 13 and 15, the very rows the hurt takes out), so here the neck
row goes in 1 and a plain back row with it in 2 (the mane's line carried onto the row under the
head); the tail stays, its lower row already on the belly's.

The reference's west sinks as the south: 1 one of the legs' rows out (as the idle's sunk frame), the
eye squinting (its upper pixel dark, the white under it left); 2 the belly's lower row out as well, the
eye shut (a dark dash where the white was, fur above it); 3 as 1. The stand's cut leaves that belly
row out already, so in 2 the lowest body row goes into the belly's outline under it (the snout's lower
edge kept), the rump's corner a pixel in. The east is the west mirrored.
"""
from boar_d import S0, S_SUNK, sunk
from boar_c import flip
from boar_e import N0, W0, w_sunk
from boar_l import PAL, REF  # noqa: F401

# The eyes' upper row with the lids down: the light blue gone, the white below it stays.
SQUINT = ".OLDMDDMDDMDLO."
# The two eye rows in one, the eyes shut: a dark dash each (the reference's frame 2, its tint undone).
SHUT = ".OMOMOODOOMOMO."

H1 = sunk(S0[:8] + [SQUINT] + S0[9:])
H2 = S0[:8] + [SHUT] + S0[10:13] + [S_SUNK] + S0[15:]


def maned(row):
    """A back row with the mane's dark line down its middle (the head's row above it)."""
    return row[:7] + "h" + row[8:]


# The north: the neck's narrow row out (1), a plain back row as well (2).
NH1 = N0[:6] + [maned(N0[7])] + N0[8:]
NH2 = N0[:6] + [maned(N0[8])] + N0[9:]

# The west's eye rows: squinting (the light blue dark), shut (the fur over a dark dash).
W_SQUINT = "..OOHLDDMMLLLLLLLMMK..."
W_LID = "..OOHLMMMMLLLLLLLMMK..."
W_SHUT = "..OlLMOOMMLHHLHLLLMO..."
# The lowest body row gone into the belly's outline: the snout's lower edge, then the outline.
W_BELLY = "..ggggOOOODDOOOODDDO..."

WH1 = w_sunk(W0[:6] + [W_SQUINT] + W0[7:])
WH2 = W0[:6] + [W_LID, W_SHUT] + W0[8:11] + [W_BELLY] + W0[13:14] + W0[15:]
WEST = [W0, WH1, WH2, WH1]
HURT = {"s": [S0, H1, H2, H1], "n": [N0, NH1, NH2, NH1], "w": WEST, "e": [flip(f) for f in WEST]}
