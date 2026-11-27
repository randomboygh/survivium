"""The gestures' frames: the wave in every drawn direction, second review of all (the user,
2026-11-20 18:21 MSK: south-east the shoulder a pixel shorter; east the arm moving
level, thinner, the hand at the eyes)."""
from gestures_wide import seg, frame
import gestures_f as prev

S = prev.S
# Turned a little the near hand is a pixel over the head's edge (in front of it, as the
# fists are), so the shoulder is as short as the front's.
SE = [frame("se", {9: seg((1, "44")), 10: seg((1, "45")), 11: seg((2, "cC")), 12: seg((3, "cC"), (5, "VkkVc")),
                   13: seg((5, "cCCC88")), 14: seg((5, "cCCC88")), 15: seg((5, "UUuUU"))}),
      frame("se", {9: seg((0, "44")), 10: seg((0, "45")), 11: seg((1, "cC")), 12: seg((2, "cCC"), (5, "VkkVc")),
                   13: seg((5, "cCCC88")), 14: seg((5, "cCCC88")), 15: seg((5, "UUuUU"))})]
LOW = {13: seg((5, "cCCc")), 14: seg((5, "UUUu")), 15: seg((5, "ttt"))}


def e(over):
    o = dict(LOW)
    o.update(over)
    return frame("e", o)


# From the side the hand is at the eyes, a pixel clear of the face, on a thin arm under the
# chin and up; it goes a pixel forward and back.
E = [e({9: seg((13, "44")), 10: seg((13, "45")), 11: seg((12, "c")), 12: seg((6, "CVkccc"))}),
     e({9: seg((14, "44")), 10: seg((14, "45")), 11: seg((13, "c")), 12: seg((6, "CVkcccc"))})]
NE = prev.NE
N = prev.N
WAVE = {"s": S, "se": SE, "e": E, "ne": NE, "n": N}
