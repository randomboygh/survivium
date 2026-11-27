"""The boar, fourteenth drawing: the death at size B, direction by direction, from the reference's six
death frames, in the boar's own colours (the reference paints frames 3-5 red, as the hurt; the game
flashes a hit animal red with a shader instead). The boar stays on the last frame until the player
picks up what it drops.

The reference's south: 0 as it stands; 1 the hurt's frame 1 (sunk, the eyes squinting); 2 dropped on its
belly, the legs folded under it with the hooves out at the sides, the eyes shut; 3 the head down on the
ground, the back showing above it (the mane and two rows of the back between the mane's tip and the
ears), the shoulders out a pixel each side, the front legs splayed out beside the snout, a row squashed
by the fall; 4 settled, the row back; 5 as 4 (only the red gone). Every frame on one canvas 17 wide, the
stand's columns at x + 1 (the splayed legs reach the canvas's edges).

The reference's north (seen from behind): 1 the hurt's frame 1 (the head ducked); 2 a leg row out, the
hind legs folding (the haunches lighter over them, a light hock in each leg, the hooves a pixel out);
3 lying flat, a row squashed (the head into the shoulders); 4 the dead pose: the haunches round over
the hind legs splayed out at the sides, the belly's outline on the ground between them; 5 as 4. At
size B the frames go on from the hurt's frame 1 (no neck row), every one 15 wide as the stand.

The reference's west: 1 the hurt's frame 1 with the tail's tip down; 2 the eye shut (as the hurt's
frame 2), the hind leg sliding back, the front hoof tucked a pixel in, the tail drooping; 3 lying, a row
squashed; 4 the dead pose: the back level under a flat mane, the head down a row more (the ear laid
back a row lower, the snout on the ground), the front leg folded under the chest, the hind leg
stretched back, the tail flat; 5 as 4. Cut as the stand (the reference's columns 10, 14, 16, 18 out;
its dead pose's rows 1, 6 and 11 out, the tail put on the tusk's row); 3 here the head's plainest
row out (the reference squashes the tail's and the tusk's rows into one, the cut already has).
The east is the west mirrored.

The user's pick (2026-11-21 «А»): the reference's 2-3-4-6, for every direction (`DEATH`).
"""
from boar_c import flip
from boar_m import H1, NH1, PAL, REF, W_LID, W_SHUT, WH1  # noqa: F401
from boar_d import S0
from boar_e import N0, W0


def canvas(rows, w=17, x=1):
    return [("." * x + r).ljust(w, ".") for r in rows]


# 2: dropped on its belly. The eyes' upper row turned fur (the light blue and the dark corners
# lighter), the white row a dark dash each; the legs folded, the hooves out at the sides under the
# body's edges, the chin's tip between them.
D2 = S0[:8] + [
    ".OLDMMLMLMMDLO.",
    ".OMOMOOMOOMOMO.",
] + S0[10:13] + [
    ".hh....p....OO.",
]

# 4 (= 5): the head down. The reference's frame 5 cut as the stand (its columns 8 and 10 out, its
# face a column right of the stand's; the spike's second row, the row under the eyes' brow and one of
# the forehead's three rows out; the chin's lowest pixel out), the stand's mane, ears and cheeks kept.
D5 = [
    "........K........",
    ".......KnK.......",
    "......KNnNK......",
    ".....OLNnNLO.....",
    "....OLLNNNLlO....",
    "...pOMLhhKLMOO...",
    "..OMHOMqNqMOHMO..",
    ".OMMMLDlqlDLMMMO.",
    "..ODMMLHqHLMMDO..",
    ".OLMDMMLLLMMDMLO.",
    ".OMMDMMLMLMMDMMO.",
    ".OMOOMOOMOOMOOMO.",
    "OMO.OlMMDMMlO.OMO",
    "OO..OTlDMDLTO..Oh",
    "....puuDMDtuO....",
    ".....hOODOOh.....",
]
# 3: the fall's squash, the brow's row out (the reference's frame 3 is its frame 5 a row shorter).
D3 = D5[:10] + D5[11:]

# The north. 2: the hurt's frame 1 a leg row shorter, the hind legs folding.
N_D2 = NH1[:11] + [
    "..OLMOOOOOMLO..",
    "..OlO.....OlO..",
    "..hh.......hh..",
]
# 4 (= 5): lying flat: the haunches over the splayed hind legs, the tail's lower row between them.
N_D5 = NH1[:10] + [
    ".OHMOMDDDMOMHO.",
    ".OHO.OOOOO.OHO.",
    ".OO.........OO.",
]
# 3: the fall's squash, the row under the head out (the reference's 3 is its 5 without that row).
N_D3 = N_D5[:6] + N_D5[7:]

# The west. 1: the hurt's frame 1, the tail's tip down.
W_D1 = WH1[:9] + [".gDDMuMMDMLLMMMLLLMDOO."] + WH1[10:]
# 2: the eye shut, the hind leg sliding back, the front hoof a pixel in, the tail drooping.
W_D2 = W0[:6] + [W_LID, W_SHUT] + W0[8:9] + [".gDDMuMMDMLLMMMLLLMDOOh"] + W0[10:12] + [
    ".........ODDOOOODDDO...",
    "..........hDO...hODDO..",
    "...........hh.....hOO..",
]
# 4 (= 5): lying dead.
W_D5 = [
    ".........K.............",
    ".........KnNKKNK.K.....",
    "......OOONNNKNNNKK.....",
    ".....hLLlOMMMLMNNnK....",
    "......ODLLDMLLLlMqK....",
    ".....OLMDMLLLLLLLMMK...",
    "....OHLMMDLHHLHLLLMO...",
    "..OOHLLMMMHHLLLHLLMDO..",
    "..OLLMOOMMLLLMLHHLMDO..",
    "g.ODMMMMMMMMMMMLLMMDOOO",
    ".ggDMuMMDDMMMDDMMMDDO..",
    ".gTuuuDDDODMMDDMMDDMDh.",
    "..ggggOOOOODMpOOOODMMMO",
    "...........OOM....OOOh.",
    ".............O.........",
]
# 3: the fall's squash, the head's plainest row out.
W_D3 = W_D5[:5] + W_D5[6:]
WEST = [W0, W_D1, W_D2, W_D3, W_D5, W_D5]

DEATH6 = {"s": [canvas(S0), canvas(H1), canvas(D2), D3, D5, D5], "n": [N0, NH1, N_D2, N_D3, N_D5, N_D5],
          "w": WEST, "e": [flip(f) for f in WEST]}
# The variants of four: A the reference's 2-3-4-6 (the stand is the idle's frame, 5 is 6 with the
# red), B its 1-3-4-6 (from the stand, the squint left out).
DEATH_A = {"s": [DEATH6["s"][i] for i in (1, 2, 3, 5)]}
DEATH_B = {"s": [DEATH6["s"][i] for i in (0, 2, 3, 5)]}
DEATH = {d: [f[i] for i in (1, 2, 3, 5)] for d, f in DEATH6.items()}
