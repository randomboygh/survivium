"""The bow's shot (the work `aim`), draft 1 (user 2026-11-20 13:13 MSK: «Для лука использовать
анимацию из puny characters - Bow Attack Animation», Archer-Green.png columns 8-11). The
reference's frames: 8 the bow drawn, its arrow at the viewer; 9-11 loosed, the string straight,
the drawing hand thrown back to the shoulder, then down. Ours, so that the arrow leaves on the
third frame as every work strikes (Controls.STRIKE): 1 the bow at the hips, an arrow nocked
(the reference's 11 with an arrow); 2 drawn (8); 3 loosed, the hand back (9); 4 the bow at the
hips again (11).
A frame: body rows from box row `top` (letters of PlayerArt.INK, hands 4-6 and 7-9) and the
bow's rows `bow` from box row `btop` (ToolArt letters: p P wood, K its outline, g its grip, s the
string, n o the arrow's shaft, A a x its head), drawn at the grip (the hand's mark, `r`)."""
TOWARD = 8
S_BODY = [
    "....cVkkVc....",
    "...ccCCCCcc...",
    "....cCCCCc....",
    "....UUuuUU....",
    "....TT..TT....",
    "....tt..TT....",
    "....BB..BB...."]


def F(bob, top, rows, btop, bow, a=TOWARD, f=True, of=None, grip=None):
    """`grip`: where the hand's mark is (box), else the bow's `g`."""
    for y, r in enumerate(bow):
        if grip is None and "g" in r:
            grip = (r.index("g"), btop + y)
    assert grip is not None, bow
    draw = {}
    for y, r in enumerate(bow):
        for x, c in enumerate(r):
            if c != ".":
                draw[(x - grip[0], btop + y - grip[1])] = c
    fr = {"bob": bob, "top": top, "r": [grip[0], grip[1]], "a": a, "f": f, "tool": "bow",
          "rows": rows, "draw": draw, "bow": bow, "btop": btop}
    if of is not None:
        fr["of"] = of
    return fr


AIM = {
    "s": [
        # 1: the bow at the hips, an arrow on the string pointing at the viewer.
        F(0, 11, S_BODY, 12, [
            ".KssssnossssK.",
            ".KPK..no..KPK.",
            ".KpPKKnoKKPpK.",
            "..KpPPgoPPpK..",
            "...KppnoppK...",
            "....KKAaKK....",
        ]),
        # 2: drawn: the string back to the chin, the bow out towards the viewer.
        F(0, 11, S_BODY, 10, [
            "......ss......",
            "....ssnoss....",
            "..ss..no..ssK.",
            ".KPK..no..KPK.",
            ".KpPKKnoKKPpK.",
            "..KpPPnoPPpK..",
            "...KppgappK...",
            "....KxAaxK....",
        ]),
        # 3: loosed: the string straight, the drawing hand thrown back to the shoulder.
        F(0, 11, [
            ".4..cVkkVc....",
            ".45ccCCCCcc...",
            "....cCCCCc....",
            "....UUuuUU....",
            "....TT..TT....",
            "....tt..TT....",
            "....BB..BB...."], 13, [
            ".Kss......ssK.",
            ".KPKssssssKPK.",
            ".KpPKKKKKKPpK.",
            "..KpPPgPPPpK..",
            "...KppppppK...",
        ]),
        # 4: the bow at the hips again.
        F(0, 11, S_BODY, 12, [
            ".KssssssssssK.",
            ".KPK......KPK.",
            ".KpPKKKKKKPpK.",
            "..KpPPgPPPpK..",
            "...KppppppK...",
            "....KKKKKK....",
        ]),
    ],
}

E_LEGS = [".....ttt......", "......tTt.....", "......BBb....."]
# The side's bow, the reference's (columns 8, 9, 11) two pixels further forward: the string
# (s), the bow's inner outline (K), its light and dark wood (P, p), its outer outline.
E_BOW_DRAWN = [
    "............KK....",
    "...........sPpK...",
    "...........sKPpK..",
    "..........s..KPpK.",
    "..........s..KPxx.",
    ".........snnnnnAAx",
    ".........soooooaax",
    "..........s..KPxx.",
    "..........s..KPpK.",
    "...........sKPpK..",
    "...........sPpK...",
    "............KK....",
]
E_BOW_LOOSED = [
    "............KK....",
    "...........sPpK...",
    "...........sKPpK..",
    "............sKPpK.",
    "............sKPpK.",
    "............sKPpK.",
    "............sKPpK.",
    "............sKPpK.",
    "............sKPpK.",
    "...........sKPpK..",
    "...........sPpK...",
    "............KK....",
]
E_BOW = [
    "............KK....",
    "...........sPpK...",
    "...........sKPpK..",
    "...........s.KPpK.",
    "...........s.KPpK.",
    "...........s.KPpK.",
    "...........s.KPpK.",
    "...........s.KPpK.",
    "...........s.KPpK.",
    "...........sKPpK..",
    "...........sPpK...",
    "............KK....",
]
# Nocked: the string straight, the arrow on it as long as drawn, its head well past the bow.
E_BOW_NOCKED = list(E_BOW_LOOSED)
E_BOW_NOCKED[5] = "............snnnnnAAx"
E_BOW_NOCKED[6] = "............sooooaaax"
AIM["e"] = [
    # 1: the bow up in front, an arrow on the string, the near hand on it, the far one at the grip.
    F(1, 11, [
        "..........44..",
        "......CVk45...",
        ".....cCCc.....",
        ".....UUUu....."] + E_LEGS, 6, E_BOW_NOCKED, a=2, grip=(13, 12)),
    # 2: drawn: the string back to the chin.
    F(1, 11, [
        ".......44.....",
        "......CV45....",
        ".....cCCc.....",
        ".....UUUu....."] + E_LEGS, 6, E_BOW_DRAWN, a=2, grip=(13, 12)),
    # 3: loosed: the string straight, the near hand thrown back down.
    F(1, 12, [
        "......CVk.....",
        "....5cCCc.....",
        "....4UUUu....."] + E_LEGS, 6, E_BOW_LOOSED, a=2, grip=(13, 12)),
    # 4: the bow held up, the near hand back by the string.
    F(1, 11, [
        "..........44..",
        "......CVk45...",
        ".....cCCc.....",
        ".....UUUu....."] + E_LEGS, 6, E_BOW_LOOSED, a=2, grip=(13, 12)),
]

SE_LEGS = [".....TT.Tt....", ".....KB.KB...."]
# Turned (se): the bow a crescent down the right side and round under to the left, its string
# from the top across to the bottom (the reference's row 1, lower and a pixel to the right so
# that the string passes under the face).
SE_BOW_LOOSED = [
    ".............sK.",
    "............sKPK",
    "............sKPK",
    "...........sKPPK",
    "..........sKPPpK",
    ".......sssKPPpK.",
    "......sKKKPPpK..",
    "......KPPPPpK...",
]
# Drawn: the string back to the chin, the arrow down to the right across the bow's grip.
SE_BOW_DRAWN = [
    "..........ssssK.",
    "........ss..KPK.",
    "........son.KPK.",
    ".......s..onPPK.",
    ".......s..KonpK.",
    ".......s.KPPpAA.",
    "......sKKKPPpKxA",
    "......KPPPPpK...",
]
SE_BOW = SE_BOW_LOOSED
# Nocked: the string straight, the arrow on it from its middle down to the right.
SE_BOW_NOCKED = [
    ".............sK.",
    "............sKPK",
    "............sKPK",
    "..........onKPPK",
    "..........sonPpK",
    ".......sssKPonK.",
    "......sKKKPPpAA.",
    "......KPPPPpKxA.",
]
AIM["se"] = [
    F(1, 12, [
        ".....VkkVc....",
        "....ccCCC44...",
        ".....cCCC.....",
        ".....UUuUU...."] + SE_LEGS, 10, SE_BOW_NOCKED, a=3, grip=(12, 14)),
    F(1, 12, [
        ".....VkkVc....",
        "....ccC44.....",
        ".....cCCC.....",
        ".....UUuUU...."] + SE_LEGS, 10, SE_BOW_DRAWN, a=3, grip=(12, 14)),
    F(1, 12, [
        ".....VkkVc....",
        ".44ccCCC......",
        ".45..cCCC.....",
        ".....UUuUU...."] + SE_LEGS, 10, SE_BOW_LOOSED, a=3, grip=(12, 14)),
    F(1, 12, [
        ".....VkkVc....",
        "....ccCCC44...",
        ".....cCCC.....",
        ".....UUuUU...."] + SE_LEGS, 10, SE_BOW, a=3, grip=(12, 14)),
]

NE_LEGS = [".....mm.tt....", ".....bb.BB...."]
# Turned away (ne): the bow behind the body, its far limb by the right side; drawn, the arrow's
# head (its tip up and right, the shaft hidden by the head) past the head to the right
# (the reference's row 3).
NE_BOW = [
    "..............K.",
    ".............PK.",
    "............KPK.",
    "............KPK.",
    "............KPK.",
    "............PPK.",
    "............PK..",
    "............K...",
]
NE_BOW_DRAWN = [
    ".............xxx",
    "..............Ax",
    "...............x",
    "................",
    "..............K.",
    ".............PK.",
    ".............PK.",
    ".............PK.",
    ".............PK.",
    "............PK..",
]
NE_BOW_NOCKED = [
    "..............xxx",
    "...............Ax",
    "................x",
    "................",
    "..............K.",
    ".............PK.",
    "............KPK.",
    "............KPK.",
    "............KPK.",
    "............PPK.",
    "............PK..",
    "............K...",
]
AIM["ne"] = [
    F(1, 12, [
        ".....VVVC.....",
        "....ccccCC44..",
        ".....VcccC....",
        ".....uuuuu...."] + NE_LEGS, 2, NE_BOW_NOCKED, a=1, f=False, grip=(12, 10)),
    F(1, 12, [
        ".....VVVC55...",
        "....ccccCCC...",
        ".....VcccC....",
        ".....uuuuu...."] + NE_LEGS, 3, NE_BOW_DRAWN, a=1, f=False, grip=(12, 10)),
    F(1, 12, [
        ".....VVVC.....",
        "....ccccCCC...",
        ".....Vccc45...",
        ".....uuuu44..."] + NE_LEGS, 7, NE_BOW, a=1, f=False, grip=(12, 10)),
    F(1, 12, [
        ".....VVVC.....",
        "....ccccCC45..",
        ".....VcccC44..",
        ".....uuuuu...."] + NE_LEGS, 6, NE_BOW, a=1, f=False, grip=(12, 10)),
]
N_LEGS = ["....mm..mm....", "....bb..bb...."]
# From behind (n): the bow in front of the body, hidden; the drawing arm up at the shoulder,
# loosed thrown back down by the right side (the reference's row 4).
AIM["n"] = [
    F(1, 12, [
        "...CCVVVVCC...",
        "...CCccccC44..",
        "....CccccC....",
        "....uuuuuu...."] + N_LEGS, 10, ["..."], a=0, f=False, grip=(10, 13)),
    F(1, 12, [
        "...CCVVVVC555.",
        "...CCccccCC...",
        "....CccccC....",
        "....uuuuuu...."] + N_LEGS, 10, ["..."], a=0, f=False, grip=(10, 13)),
    F(1, 12, [
        "...CCVVVVCC...",
        "...CCccccCC...",
        "....CccccC45..",
        "....uuuuuu44.."] + N_LEGS, 10, ["..."], a=0, f=False, grip=(10, 13)),
    F(1, 12, [
        "...CCVVVVCC...",
        "...CCccccC45..",
        "....CccccC44..",
        "....uuuuuu...."] + N_LEGS, 10, ["..."], a=0, f=False, grip=(10, 13)),
]

# The reference's order as it is (the variant the user may pick): 1 drawn, 2 loosed (the string
# still bent, the hand back), 3 loosed (the string straight), 4 the bow at the hips.
LOOSED_BODY = AIM["s"][2]["rows"]
AIM_LITERAL = {"s": [
    AIM["s"][1],
    AIM["s"][2],
    F(0, 11, LOOSED_BODY, 13, [
        ".KssssssssssK.",
        ".KPK......KPK.",
        ".KpPKKKKKKPpK.",
        "..KpPPgPPPpK..",
        "...KppppppK...",
    ]),
    AIM["s"][3],
]}
