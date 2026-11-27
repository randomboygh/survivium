"""The clap, from the front, two variants for review (frames 58 and 59: apart and together): A the
hands before the chest, edged with the shade where they meet the skin; B lower, before the belly
and the loincloth, which shows them."""
from gestures_wide import seg, frame

BARE = {13: seg((4, "cCCCCc")), 14: seg((4, "UUuuUU"))}


def s(over):
    o = dict(BARE)
    o.update(over)
    return frame("s", o)


A = {"s": [s({12: seg((1, "44"), (3, "6"), (4, "cCCCCc"), (10, "9"), (11, "77")),
              13: seg((1, "55"), (3, "6"), (4, "cCCCCc"), (10, "9"), (11, "88"))}),
           s({12: seg((3, "c6"), (5, "4477"), (9, "9c")), 13: seg((4, "6"), (5, "5588"), (9, "9"))})]}
B = {"s": [s({13: seg((2, "44"), (4, "6CCCC9"), (10, "77")), 14: seg((2, "55"), (4, "6UuuU9"), (10, "88"))}),
           s({13: seg((4, "c64479")), 14: seg((4, "U5588U"))})]}


# The user's edit (2026-11-20 23:41 MSK): both hands, four pixels each, before the chest, a pixel
# apart and then together; nothing out past the shoulders.
C = {"s": [s({12: seg((3, "c"), (4, "44"), (6, "CC"), (8, "77"), (10, "c")), 13: seg((4, "55"), (6, "CC"), (8, "88"))}),
           s({12: seg((3, "cc"), (5, "4477"), (9, "cc")), 13: seg((4, "c"), (5, "5588"), (9, "c"))})]}
# The same with the hands' shade (6, 9) where they meet the chest.
D = {"s": [s({12: seg((3, "c"), (4, "44"), (6, "CC"), (8, "77"), (10, "c")), 13: seg((4, "56"), (6, "CC"), (8, "98"))}),
           s({12: seg((3, "cc"), (5, "4477"), (9, "cc")), 13: seg((4, "6"), (5, "5588"), (9, "9"))})]}


# The user's edit (2026-11-20 23:55 MSK): the first frame as A's, the second the hands folded in the
# middle of the chest: E with no outline (the forearms come in from the sides), F the same with
# the outline between the hands and the forearms.
E = {"s": [A["s"][0], A["s"][1]]}
F = {"s": [A["s"][0], s({12: seg((3, "6c4477c9")), 13: seg((4, "c5588c"))})]}


# The user's edit (2026-11-21 00:02 MSK): the second frame is the first's hands, each two pixels
# square, moved two pixels in, whole inside the body with their dark edge kept: G edged as the
# figure is (E), H edged brown (the skin's deepest, k).
def folded(e):
    return s({11: seg((4, e + "VkkV" + e)), 12: seg((3, "44" + e + "CC" + e + "77")),
              13: seg((3, "55" + e + "CC" + e + "88")), 14: seg((4, e + "UuuU" + e))})


G = {"s": [A["s"][0], folded("E")]}
H = {"s": [A["s"][0], folded("k")]}


# The user's edit (2026-11-21 00:05 MSK): three pixels in, so the hands meet: I edged as the
# figure is, J brown.
def met(e):
    return s({11: seg((4, e + e + "kk" + e + e)), 12: seg((4, "44" + e + e + "77")),
              13: seg((4, "55" + e + e + "88")), 14: seg((4, e + e + "uu" + e + e))})


I = {"s": [A["s"][0], met("E")]}
J = {"s": [A["s"][0], met("k")]}


# The user's pick (2026-11-21 00:06 MSK): J, in every direction: the hands out at the chest, then
# met in its middle, edged brown; turned away the hands go before the body, the forearms show.
def g(d, over):
    return frame(d, over)


ALL = {
    "s": J["s"],
    "se": [g("se", {13: seg((1, "446ccCCC977")), 14: seg((1, "5566cCCC988")), 15: seg((5, "UUuUU"))}),
           g("se", {12: seg((5, "kkkkk")), 13: seg((4, "44kk77")), 14: seg((4, "55kk88")),
                    15: seg((4, "kUuUkk"))})],
    "e": [g("e", {13: seg((5, "cCCc977")), 14: seg((5, "UUUu988")), 15: seg((5, "ttt"))}),
          g("e", {13: seg((5, "cCCk77")), 14: seg((5, "UUUk88")), 15: seg((5, "ttt"))})],
    "ne": [g("ne", {13: seg((1, "449ccccCCC644")), 14: seg((1, "5599VcccC6655")), 15: seg((5, "uuuuu"))}),
           g("ne", {13: seg((3, "9ccccCCC6")), 14: seg((4, "9VcccC6")), 15: seg((5, "uuuuu"))})],
    "n": [g("n", {13: seg((0, "779CCccccCC644")), 14: seg((0, "8899CccccC6655")), 15: seg((4, "uuuuuu"))}),
          g("n", {14: seg((3, "9CccccC6")), 15: seg((4, "uuuuuu"))})],
}


# The user's edits (2026-11-21 00:27 MSK): south-east the met hands a pixel right; north-east no
# shoulder pixels by the body; north the arms out a pixel higher.
ALL_B = dict(ALL)
ALL_B["se"] = [ALL["se"][0],
               g("se", {12: seg((5, "kkkkkk")), 13: seg((5, "44kk77")), 14: seg((5, "55kk88")),
                        15: seg((5, "kkuUkk"))})]
ALL_B["ne"] = [ALL["ne"][0], g("ne", {14: seg((4, "9VcccC6")), 15: seg((5, "uuuuu"))})]
ALL_B["n"] = [g("n", {12: seg((0, "779CCVVVVCC644")), 13: seg((0, "889CCccccCC655")),
                      14: seg((4, "CccccC")), 15: seg((4, "uuuuuu"))}),
              ALL["n"][1]]


# The user's edit (2026-11-21 00:31 MSK): south-east the arm on the picture's left two pixels shorter.
ALL_C = dict(ALL_B)
ALL_C["se"] = [g("se", {13: seg((3, "44"), (5, "cCCC977")), 14: seg((3, "55"), (5, "cCCC988")),
                        15: seg((5, "UUuUU"))}), ALL_B["se"][1]]


# The user's edit (2026-11-21 00:32 MSK): north-east and north the arms out a pixel shorter.
ALL_D = dict(ALL_C)
ALL_D["ne"] = [g("ne", {13: seg((2, "44ccccCCC44")), 14: seg((2, "559VcccC655")), 15: seg((5, "uuuuu"))}),
               ALL_C["ne"][1]]
ALL_D["n"] = [g("n", {12: seg((1, "77CCVVVVCC44")), 13: seg((1, "88CCccccCC55")),
                      14: seg((4, "CccccC")), 15: seg((4, "uuuuuu"))}), ALL_C["n"][1]]
