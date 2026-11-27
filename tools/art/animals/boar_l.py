"""The boar, twelfth drawing: the attack at size B, from the reference's five attack frames, the
south first. The reference: 0 standing (the stand); 1 the head turned to our left and lowered, the
mane down its side, one eye and one tusk seen; 2 the snout down at the ground on the left, the mane
an arc over the top; 3 the head tossed up to the right, the tusks out, a white swipe of the tusks
from the ground at the left round under the belly and up past the snout; 4 the head back to the
right, the swipe's end a thin arc over the body and under the belly. The user's rule keeps four of
the five (the review shows the choices).

Every frame is laid on one canvas, the stand's columns at x + 1 (its feet at 3-5 and 11-13); the
frames are cut from the reference as the stand is (two body columns and four or five rows left out,
the eye, tusk, mane and feet kept), then cleaned by hand. The swipe is a letter of its own, `S`.
"""
from boar_c import flip
from boar_e import N0 as N0_STAND
from boar_e import W0 as W0_STAND
from boar_f import PAL as PAL_F
from boar_f import REF as REF_F
from boar_f import S0
from proto import paint

PAL = dict(PAL_F, S="#e0e8f0")
# The reference's attack keeps its swipe (proto.ref_frame).
REF = dict(REF_F, swipe=("attack",))


def canvas(rows, w=19, x=0):
    return [("." * x + r).ljust(w, ".") for r in rows]


A0 = canvas(S0, x=1)

# 1: the reference's rows 0, 9, 11, 14 and columns 8, 9 left out.
A1 = [
    ".....K.KnKK........",
    ".....KhKnKKK.......",
    ".....KnNNNgqK......",
    "..OOOKnNqMLMO......",
    "..OllKNNMMLLMO.....",
    "..OMKnNMMMOOOO.....",
    "...OKNNLMMlHLMO....",
    "..OOhNqlLMLLMOO....",
    "..OOHHLLMMMDMMO....",
    "..ODLLMDEMMMDDO....",
    "..OMMMMqWMMDDDO....",
    "..ODDMMMTOODDDO....",
    "...ODDMuuhODDO.....",
    "...OOOOOh.pDMO.....",
    "...OgO.....ODO.....",
    "....Oh.....Oh......",
]

# 2: rows 0, 3, 9, 11 and columns 7, 10 left out (the mane's crest kept whole).
A2 = [
    "....h.KnKK.........",
    "...KnKnNNnKK.......",
    ".K.KnKNMLLLMO......",
    "..KnNhMLLHHLMO.....",
    "OOKnqMMLLLHHLO.....",
    "OlKNMMMDOOMLLMO....",
    ".KNqLLMLHMOMLMO....",
    ".OqHLLMMMMMMMMO....",
    ".OLMDMMMMMMMDDO....",
    "OLLDEMMMMMDDDDO....",
    "OMMpWMMMMDDDDDO....",
    "OMMMLMMMDODDDDO....",
    "OMMMMTMOO.hDMO.....",
    ".hMMtuh....ODO.....",
    "..OOOh.....Oh......",
]

# 3: rows 1, 7, 12, 15, 17 and columns 7, 10, 18 left out; the swipe hugs the right side and the
# belly, over the near leg, two or three pixels thick as the reference's.
A3 = [
    "........KK.........",
    ".......KNNnh.......",
    ".....OOnhqLLOOp....",
    "...hKOLOMMLMLHHOOS.",
    "....KOLLMMMEgLHHlp.",
    "....KOMLDMMWgMLLDOS",
    "...KNgOMMMMMLTMMDOS",
    "..KNMLLDMMMMMuWTMSS",
    ".KNNlLMMMMLMMtupOSS",
    "..KqMLMMMMLLMMMOSS.",
    "..OMMMMMMMMMMMhSS..",
    "..ODMMMMMMMMMDSSS..",
    "..ODDMDMMMDMSSSS...",
    "...ODDDOhSSSSS.....",
    "...ODDh.SSSSgO.....",
    "...pMgSSSSSgMO.....",
    "..SSSSSSS..OMO.....",
    "....hO.....Oh......",
]

# 4: rows 1, 4, 10, 14, 16 and columns 6, 9, 16 left out; the swipe's end over the body.
A4 = [
    ".......K...........",
    "......KNh..........",
    "....K.KNNKh........",
    "....KnNLLHHLOO.....",
    "....OOMLLDLHLLO....",
    "...OHLLMLEDLLDMO...",
    "..OlLLMMMWNMDMMO...",
    "..OOOMMMMLMDDDMO...",
    ".KOMLMMLLLTMDDO....",
    "..OHLMMMLMuTTOOS...",
    "..OLMMMMMDDOOMS....",
    "..ODMMMMMMMMMSO....",
    "..ODDDDMMMSSSDO....",
    "...ODDOOOOODDO.....",
    "...ODDOSS.hDMO.....",
    "...OMSS....ODO.....",
    "....OO.....Oh......",
]


def wide(rows):
    """A south frame on the canvas every direction shares: 23 wide, the stand's columns at x + 4."""
    return canvas(rows, w=23, x=3)


# The north: the stand's (boar_e.N0) cut, columns 6 and 12 of the half-mirrored back, on the shared
# canvas (x + 4, its feet at 6-8 and 14-16; the reference's feet stay put through the attack). The
# tail stays curled as in the stand (the reference's does), painted where the stand has it.
TAIL = ["12,0:M", "11,1:M.D", "11,2:DLD", "10,3:DDD"]


def tail(rows, top):
    return paint(rows, ["%s,%d:%s" % (m.split(":")[0].split(",")[0], int(m.split(":")[0].split(",")[1]) + top,
                               m.split(":")[1]) for m in TAIL])


N_LEGS = [
    "......ODDDOOODDDO......",
    "......ODDh...pDDO......",
    "......ODO.....ODO......",
    ".......OO.....Oh.......",
]

N0 = canvas(N0_STAND, w=23, x=4)

# 1: the head turned to its right (our right): the mane two columns over with a second spike, the
# right ear raised, the left one flattened, the right flank two columns fuller with a dark stripe,
# the snout's tip out past it; the reference's rows 7, 8, 13, 15 and columns 4, 9 left out.
B1 = tail([
    ".............K.........",
    "............KK.........",
    "........OO..Knh..Op....",
    ".......pDOOKNNKOOHHO...",
    "........pLLnNMMLLLLlO..",
    ".......pMLLnhLMMMLOO...",
    "......OMLHHqHHLMMMO....",
    ".....OMLHHHLHHHLMDMO...",
    ".....OMLLHHHHHLLMDMO...",
    ".....OMMLLHHHLLMMDMOg..",
    ".....OMMMLLLLLMMMDMp...",
    ".....ODMMMMMMMMMMDO....",
] + N_LEGS, 8)

# 2: the snout down at the ground on the right: the head and back a row lower and the ears two (the
# body settles onto the legs), the spike taller, the snout's tip lower; rows 6, 7, 12, 14 and
# columns 4, 9 left out.
B2 = tail([
    ".............N.........",
    "............hK.........",
    "............KnK........",
    "........OOOKNKNKOh.....",
    ".......hOLLnNgMOlHO....",
    ".......OMLLNpLMMLLHO...",
    ".....OMLHHHlHHHLMDMO...",
    ".....OMLLHHHHHLLMDMO...",
    ".....OMMLLHHHLLMMDMO...",
    ".....OMMMLLLLLMMMDMOg..",
    ".....ODMMMMMMMMMMDMO...",
    ".....ODDMOOOOODMDDO....",
] + N_LEGS[1:], 7)

# 3: the head tossed up to its left (our left), the snout and a tusk out past it, the swipe from the
# snout down the left side, then under the belly between the legs and out past the right leg; the
# rump a row higher (a row more under it); rows 3, 7, 10, 17 and columns 9, 15 left out.
B3 = tail([
    ".....OOOOKKK...........",
    "....pLllLKnNKK.........",
    "S..OMOOOOMKNnOOO.......",
    "SDgOMOlHLLgNNnOO.......",
    "SgTOMOMLMLMhhNO........",
    "SSgOMMOLMLLKNMMO.......",
    "SSS.pDOLLHHhHHLLO......",
    "SSS..OMLHHHlHHHLMO.....",
    ".SSS.OMLHHHLHHHLMO.....",
    "..SSSOMLLHHHHHLLMO.....",
    "..SSSOMMLLHHHLLMMO.....",
    "...SSOMMMLLLLLMMMO.....",
    "....SODMMMMMMMMMDO.....",
    ".....ODDMMMMMMMDDh.....",
    "......ODDDOOODDDO......",
    "......ODDOSSSpDDO......",
    "......ODO..SSSODOS.....",
    ".......OO.....Oh.......",
], 9)

# 4: the head back to the middle, still raised, the mane's spike up again, the swipe's end a thin
# line down the left side and under the belly; rows 1, 7, 15, 17 and columns 9, 15 left out.
B4 = tail([
    ".........K.............",
    "......OOKnK.h..........",
    "S...OOOOMNnK...........",
    "S.g.pHHHONNnKOOOO......",
    "S.gOOLHHLhKNMLLHh......",
    "S.gOOMLLLMKKnMLLO......",
    "...OMMOMLHHKqHLO.......",
    "....ODOLLHHhlHLLO......",
    ".S...OMLHHHHHHHLMO.....",
    "..S..OMLHHHLHHHLMO.....",
    "...S.OMLLHHHHHLLMO.....",
    "....SOMMLLHHHLLMMO.....",
    ".....OMMMLLLLLMMMO.....",
    ".....ODMMMMMMMMMDO.....",
    "......ODDDOOODDDO......",
    "......ODDh.SSpDDO......",
    "......ODO...SSODO......",
    ".......OO.....Oh.......",
], 10)

# The west: the stand's cut (boar_c: the reference's columns 10, 14, 16, 18 out), the columns moved
# with each frame's feet (the reference's sheet drifts a column or two a frame, its feet stay put),
# on a canvas 29 wide with the stand (boar_e.W0) at x + 3 (centred on it: the swipe reaches 3
# columns past its snout). The east is the west mirrored, as the reference's is.
W0X = canvas(W0_STAND, w=29, x=3)

# 1: the head lowered, the snout and tusk down at the chin, the ear laid back, the tail straight
# out; rows 1, 4, 9, 13 left out (the snout's rows kept).
C1 = [
    ".............K...............",
    ".............hKNKhh..........",
    "............KhNNNNnKK.K......",
    "........pDOLHOOMLLMMNNnK.....",
    ".........OMOOHLOLLLLLMqK.....",
    ".........OLMMLHLMLLLLLMqK....",
    "........OLLLMLLMMLLLLLLMO....",
    ".......OlLLDMMLLHLLLLHHLMO...",
    "......OLLLDEMLLHLLMLLLHLMO...",
    "......OMLMhWMMLLMLMMLLLLMOhh.",
    ".....gTOMMuMDDMMMMDMMMMMO....",
    "......ggOgutOpDMDDDDMMMO.....",
    "......gugTgh.ODDOOODDDh......",
    ".......ggg...ODO...ODO.......",
    ".............ODO...ODO.......",
    ".............OO....Oh........",
]

# 2: the snout down at the ground in front, the head a row lower, the front leg bent under it;
# rows 1, 4, 10, 11 left out.
C2 = [
    ".............K...............",
    ".............hKNKhh..........",
    "............KNNNNNnKK.K......",
    "..........OOOOMMLLMMNNnK.....",
    ".........OMOLHOOLLLLLMqK.....",
    "..........OMOMLLMLLLLLMqK....",
    "..........OMMDLHDLLLLLLMO....",
    ".........OMLLDLLMLLLHHLMO....",
    "........OHHLDMMLLMMMLLLLMOhh.",
    "........OHLDEMMMLDDMMLLMMO...",
    ".......OLLlqWMDMMDDMMMMMO....",
    ".....g.OMLMMlDDMMDDDMMMO.....",
    "......ggOMMMtDDDOOODDMO......",
    ".........OOguODO...ODO.......",
    "........gggTgODh...ODO.......",
    ".........ggg.hO....Oh........",
]

# 3: the head tossed up and forward, the snout and tusk at the top, the ear up, the back sloping
# down to the rump; the swipe from over the snout down in front of the chest to the front foot;
# rows 2, 8, 11, 16 left out.
C3 = [
    "...S.........................",
    ".gS...........KK.............",
    "ggOOLMOOOOKKKHOnKK...........",
    "gSTMLLHHLlONNHONhn.KK........",
    "SguuMLLLLMDMMHOMMNKnK........",
    "SSggMMLLqEMMDHOMLMNNKK.......",
    "SSpDMMMMWMMDLLOMLLLMNnKK.....",
    "SSS.ODMMMMMMMMMMLLHLMMhK.....",
    "SSS..pDDMMMMMLLLLLHHLMqK.....",
    ".SSS...OODMMLHHLLMLLLLMO.....",
    ".SSS.....ODMLHLLMMLLLLMOO....",
    ".SSSS.....OMMLLMMDMLLMMO.....",
    "..SSS......pMLMMMDMMMMO......",
    "....SS......OMDDOODDDO.......",
    ".....SS.....ODDO..ODDO.......",
    ".......SS....ODO...ODO.......",
    ".............OO....Oh........",
]

# 4: the head back down, pushed forward two columns and up a row, the tusk out, the swipe's end a
# short line in front of the snout; rows 1, 4, 10, 15 left out.
C4 = [
    "............K................",
    ".......OOO..KnNKK............",
    "......OlLHOONNNKNK...........",
    ".......OMDLHMMMLLqnKK........",
    "......OHMDMLMMLLLLNNnK.......",
    ".....OHLDMDMMLLLLLMMNK.......",
    "...OOHLDEMMMMLLLLLLLMqK......",
    ".S.OlLMhWMMMMHLLLLHLLMO......",
    ".S.ODMMMMMMMLHLLLLHHLLMO.....",
    ".SggDguMMDMMMLLLLMLLLLMO.....",
    "..gTuuuDDDDMMLMMMMLLLLMOOO...",
    "..SggggOOODDMMMMMDMLLMMO.....",
    "...........pDMMDDDMMMDh......",
    "............OMDDOODDDO.......",
    "............hDDO..ODDO.......",
    ".............ODO...ODO.......",
    ".............hO....Oh........",
]

ATK5 = {"s": [wide(f) for f in (A0, A1, A2, A3, A4)], "n": [N0, B1, B2, B3, B4],
        "w": [W0X, C1, C2, C3, C4]}
ATK5["e"] = [flip(f) for f in ATK5["w"]]
# The user's pick (2026-11-21 «А»): the reference's 2-5, the stand left out (the attack starts from
# it anyway). B, shown for the south, kept the stand and left the follow-through out.
ATK = {d: f[1:] for d, f in ATK5.items()}
ATK_B = {"s": ATK5["s"][:4]}
