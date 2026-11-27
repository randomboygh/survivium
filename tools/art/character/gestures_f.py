"""The gestures' frames: the wave in every drawn direction (after the front the user
accepted on 2026-11-20 18:13 MSK: the hand at the eyes' rows near the face, a short
shoulder a pixel and a half wide, a pixel of shade under the hand next to it; the hand and
the shoulder move a pixel out and back). From the side the hand is forward at the chin
(the head is in the way higher up) and goes a pixel down and up; turned away it is by the
jaw, clear of the cheek."""
from gestures_wide import seg, frame

S = [frame("s", {8: seg((0, "44")), 9: seg((0, "45")), 10: seg((1, "cC")), 11: seg((2, "cC"), (4, "cVkkVc")),
                 12: seg((4, "cCCCCcc")), 13: seg((4, "cCCCCc87")), 14: seg((4, "UUuuUU87"))}),
     frame("s", {8: seg((-1, "44")), 9: seg((-1, "45")), 10: seg((0, "cC")), 11: seg((1, "cCC"), (4, "cVkkVc")),
                 12: seg((4, "cCCCCcc")), 13: seg((4, "cCCCCc87")), 14: seg((4, "UUuuUU87"))})]
SE = [frame("se", {9: seg((0, "44")), 10: seg((0, "45")), 11: seg((1, "cC")), 12: seg((2, "cCc"), (5, "VkkVc")),
                   13: seg((5, "cCCC88")), 14: seg((5, "cCCC88")), 15: seg((5, "UUuUU"))}),
      frame("se", {9: seg((-1, "44")), 10: seg((-1, "45")), 11: seg((0, "cC")), 12: seg((1, "cCCc"), (5, "VkkVc")),
                   13: seg((5, "cCCC88")), 14: seg((5, "cCCC88")), 15: seg((5, "UUuUU"))})]
E = [frame("e", {11: seg((12, "44")), 12: seg((6, "CVkCCc45")), 13: seg((5, "cCCccc")), 14: seg((5, "UUUu")), 15: seg((5, "ttt"))}),
     frame("e", {12: seg((6, "CVk"), (12, "44")), 13: seg((5, "cCCcCCc45")), 14: seg((5, "UUUucc")), 15: seg((5, "ttt"))})]
NE = [frame("ne", {10: seg((12, "44")), 11: seg((12, "54")), 12: seg((5, "VVVC"), (11, "Cc")), 13: seg((4, "ccccCCCc")),
                   14: seg((3, "88VcccC")), 15: seg((3, "88uuuuu"))}),
      frame("ne", {10: seg((13, "44")), 11: seg((13, "54")), 12: seg((5, "VVVC"), (11, "CCc")), 13: seg((4, "ccccCCCc")),
                   14: seg((3, "88VcccC")), 15: seg((3, "88uuuuu"))})]
N = [frame("n", {9: seg((12, "44")), 10: seg((12, "54")), 11: seg((11, "Cc")), 12: seg((3, "CCVVVVCCc")),
                 13: seg((3, "CCccccC")), 14: seg((2, "77CccccC")), 15: seg((2, "88uuuuuu"))}),
     frame("n", {9: seg((13, "44")), 10: seg((13, "54")), 11: seg((12, "Cc")), 12: seg((3, "CCVVVVCCCc")),
                 13: seg((3, "CCccccC")), 14: seg((2, "77CccccC")), 15: seg((2, "88uuuuuu"))})]
WAVE = {"s": S, "se": SE, "e": E, "ne": NE, "n": N}
