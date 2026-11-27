"""The beckon («иди сюда»), from the front, three variants for review, the right hand: A the hand
held out at the shoulder as the point's, lifted a pixel and back (the fingers curling in); B the
hand out and drawn in against the body; C the forearm swung from low out up to the shoulder."""
from gestures_wide import seg, frame

LOW = {13: seg((4, "cCCCCc87")), 14: seg((4, "UUuuUU87"))}


def s(over):
    o = dict(LOW)
    o.update(over)
    return frame("s", o)


OUT = s({11: seg((1, "44"), (3, "C"), (4, "cVkkVc")), 12: seg((1, "45"), (3, "ccCCCCcc"))})
A = {"s": [OUT, s({10: seg((1, "44")), 11: seg((1, "45"), (3, "C"), (4, "cVkkVc")), 12: seg((3, "ccCCCCcc"))})]}
B = {"s": [OUT, s({11: seg((2, "44"), (4, "cVkkVc")), 12: seg((2, "45"), (4, "cCCCCcc"))})]}
C = {"s": [s({12: seg((0, "44"), (2, "cC"), (4, "cCCCCcc")), 13: seg((0, "45"), (4, "cCCCCc87"))}),
           s({9: seg((2, "44")), 10: seg((2, "45")), 11: seg((3, "C"), (4, "cVkkVc"))})]}


# The user's pick (2026-11-20 21:14 MSK): A in every direction: the hand where the point holds it
# (without the finger), then lifted a pixel.
def f(d, over, low):
    o = dict(low)
    o.update(over)
    return frame(d, o)


SE_LOW = {14: seg((5, "cCCC88")), 15: seg((5, "UUuUU"))}
E_LOW = {14: seg((5, "UUUu")), 15: seg((5, "ttt"))}
NE_LOW = {14: seg((3, "88VcccC")), 15: seg((3, "88uuuuu"))}
N_LOW = {14: seg((2, "77CccccC")), 15: seg((2, "88uuuuuu"))}
ALL = {
    "s": A["s"],
    "se": [f("se", {12: seg((2, "44"), (4, "C"), (5, "VkkVc")), 13: seg((2, "45"), (4, "ccCCC88"))}, SE_LOW),
           f("se", {11: seg((2, "44")), 12: seg((2, "45"), (4, "C"), (5, "VkkVc")), 13: seg((4, "ccCCC88"))}, SE_LOW)],
    "e": [f("e", {12: seg((6, "CVk"), (9, "44")), 13: seg((5, "cCCc"), (9, "45"))}, E_LOW),
          f("e", {11: seg((9, "44")), 12: seg((6, "CVk"), (9, "45")), 13: seg((5, "cCCc"))}, E_LOW)],
    "ne": [f("ne", {12: seg((5, "VVVC"), (9, "C"), (10, "44")), 13: seg((4, "ccccCC"), (10, "54"))}, NE_LOW),
           f("ne", {11: seg((10, "44")), 12: seg((5, "VVVC"), (9, "C"), (10, "54")), 13: seg((4, "ccccCCC"))}, NE_LOW)],
    "n": [f("n", {12: seg((3, "CCVVVVCC"), (11, "44")), 13: seg((3, "CCccccCC"), (11, "54"))}, N_LOW),
          f("n", {11: seg((11, "44")), 12: seg((3, "CCVVVVCC"), (11, "54")), 13: seg((3, "CCccccCC"))}, N_LOW)],
}
