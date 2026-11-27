"""The bow's shot after the user's review of 2026-11-20 17:43 MSK: «Тетива на виде "Юго-Восток"
заходит на ноги - убери лишние 3 пикселя». Turned (se) the bow's lower end is under the frame's
edge, and the string went on to it across the hips and the left leg: three pixels past the limb
(at rest (8, 15), (7, 15), (6, 16); drawn, down from the hand, (7, 14), (7, 15), (6, 16)). Now the
string ends where it meets the limb, on the hips' row; drawn, it goes from the bow's upper end to
the hand and no further. The rest as aim_d."""
import aim_d
from aim_d import *  # noqa: F401,F403
from aim_a import F, SE_BOW_NOCKED, SE_BOW_LOOSED


def _cut(rows, edits):
    """`rows` with the rows of `edits` ({index: row}) put in."""
    out = list(rows)
    for i, r in edits.items():
        assert len(r) == len(out[i]), (r, out[i])
        out[i] = r
    return out


# The string's last pixel is the one beside the limb on the hips' row (box 9, 15).
SE_NOCKED = _cut(SE_BOW_NOCKED, {5: ".........sKPonK.", 6: ".......KKKPPpAA."})
SE_LOOSED = _cut(SE_BOW_LOOSED, {5: ".........sKPPpK.", 6: ".......KKKPPpK.."})
# Drawn: the string from the bow's upper end to the hand; its lower half ran down the belly and
# the leg.
SE_DRAWN = _cut(aim_d._SE, {4: "..........KonpK.", 5: ".........KPPpAA.", 6: ".......KKKPPpKxA"})

RAW = dict(aim_d.RAW)
RAW["se"] = [F(fr["bob"], fr["top"], fr["rows"], 10, bow, a=3, grip=(12, 14))
             for fr, bow in zip(aim_d.RAW["se"], (SE_NOCKED, SE_DRAWN, SE_LOOSED, SE_LOOSED))]
AIM = dict(aim_d.AIM)
AIM["se"] = [aim_d.peeled("se", fr) for fr in RAW["se"]]
