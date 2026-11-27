"""The point, from the front, three variants for review: A the right arm out level to the side
at the shoulder, a finger past the hand; B the arm down to the side and out, toward the ground
ahead; C the hand before the chest, pointing at the one who looks (the arm hidden behind it)."""
from gestures_wide import seg, frame

LOW = {13: seg((4, "cCCCCc87")), 14: seg((4, "UUuuUU87"))}


def s(over):
    o = dict(LOW)
    o.update(over)
    return frame("s", o)


A = {"s": [s({11: seg((-2, "444"), (1, "CCC"), (4, "cVkkVc")), 12: seg((-1, "45"), (1, "cc"), (3, "ccCCCCcc"))})]}
B = {"s": [s({12: seg((2, "cC"), (4, "cCCCCcc")), 13: seg((0, "cC"), (4, "cCCCCc87")),
              14: seg((-2, "4"), (-1, "44"), (4, "UUuuUU87")), 15: seg((-1, "55"), (4, "TT..TT"))})]}
C = {"s": [s({12: seg((3, "ccCC"), (7, "4"), (8, "Ccc")), 13: seg((4, "cCC"), (7, "44"), (9, "Cc87"))})]}


# The user's pick (2026-11-20 20:35 MSK): A, the arm two pixels shorter: a pixel of arm from the
# shoulder, the hand on the body's first row, the finger past it. Every direction the right hand.
def f(d, over, low):
    o = dict(low)
    o.update(over)
    return frame(d, o)


ALL = {
    "s": [f("s", {11: seg((0, "444"), (3, "C"), (4, "cVkkVc")), 12: seg((1, "45"), (3, "ccCCCCcc"))}, LOW)],
    "se": [f("se", {12: seg((1, "444"), (4, "C"), (5, "VkkVc")), 13: seg((2, "45"), (4, "ccCCC88"))},
             {14: seg((5, "cCCC88")), 15: seg((5, "UUuUU"))})],
    "e": [f("e", {12: seg((6, "CVkC"), (10, "444")), 13: seg((5, "cCCc"), (10, "45"))},
            {14: seg((5, "UUUu")), 15: seg((5, "ttt"))})],
    "ne": [f("ne", {12: seg((5, "VVVC"), (9, "C"), (10, "444")), 13: seg((4, "ccccCC"), (10, "54"))},
             {14: seg((3, "88VcccC")), 15: seg((3, "88uuuuu"))})],
    "n": [f("n", {12: seg((3, "CCVVVVCC"), (11, "C"), (12, "444")), 13: seg((3, "CCccccCC"), (12, "54"))},
            {14: seg((2, "77CccccC")), 15: seg((2, "88uuuuuu"))})],
}


# The user's edit (2026-11-20 20:40 MSK): north and east the hand a pixel nearer the body, no
# outline left between them.
ALL_B = dict(ALL,
    e=[f("e", {12: seg((6, "CVk"), (9, "444")), 13: seg((5, "cCCc"), (9, "45"))},
         {14: seg((5, "UUUu")), 15: seg((5, "ttt"))})],
    n=[f("n", {12: seg((3, "CCVVVVCC"), (11, "444")), 13: seg((3, "CCccccCC"), (11, "54"))},
         {14: seg((2, "77CccccC")), 15: seg((2, "88uuuuuu"))})])
