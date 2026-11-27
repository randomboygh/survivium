"""The gestures' frames: the wave in every drawn direction, third review of all (the user,
2026-11-20 18:28 MSK: from the east variant Б, the hand by the ear over the side of the head,
a pixel lower and forward). Its lower row lies over the face: in the shade, or it would not
show on the skin."""
from gestures_wide import seg, frame
import gestures_g as prev

LOW = {13: seg((5, "cCCc")), 14: seg((5, "UUUu")), 15: seg((5, "ttt"))}


def e(over):
    o = dict(LOW)
    o.update(over)
    return frame("e", o)


S = prev.S
SE = prev.SE
# From the side the near arm is in front of the head: the hand over its side by the ear
# (with the fists), the forearm up across the jaw, light over its shade; a pixel forward and
# back.
E = [e({9: seg((5, "44")), 10: seg((5, "55")), 11: seg((6, "45")), 12: seg((6, "CVk"))}),
     e({9: seg((4, "44")), 10: seg((4, "55")), 11: seg((5, "455")), 12: seg((6, "CVk"))})]
NE = prev.NE
N = prev.N
WAVE = {"s": S, "se": SE, "e": E, "ne": NE, "n": N}
