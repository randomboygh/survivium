"""Back to chop_e (chop-all-3.gif), user 2026-11-20 01:02: east frame 3 the edge down, frame 4
the blade in sight (the axe tilted up forward, pulled free)."""
import copy
import chop_e
CHOP = copy.deepcopy(chop_e.CHOP)
CHOP["e"][2]["ccw"] = False
CHOP["e"][3]["a"] = 1
