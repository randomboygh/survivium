from eng import *
from bird import lay, merged
FAR = str.maketrans({'r': 'd', 'R': 'D', 'h': 'd'})
PAL = {'d': '#7a3014', 'D': '#5a200c', 'K': '#2e1a12', 'R': '#8c3a1a', 'r': '#b85a28', 'h': '#d8803c', 'l': '#eaa262', 'W': '#f0e8dc', 'w': '#cfc2ae', 'k': '#120c0a'}
# Side, on all fours (fills, facing left): head, body, tail, legs per pose.
HEAD = ["..R.R", ".rrrrr", "rkrrrr", ".Wrrr."]
BODY = ["..rrrrR", ".rrrrrRR", "WWrrrRRR", ".wWrRR.."]
TAIL_UP = ["..lhh.", ".lhhrr", ".hrrRr", ".hrR..", "hrR...", "rR...."]
TAIL_BACK = [".llhh", "lhhrR", "hrRR.", "rRR.."]
def run_side(body_dy, head_dx, head_dy, front, hind, tail, tail_xy, w=20, h=14):
    parts = [(tail, tail_xy[0] + 1, tail_xy[1] + (3 if tail is TAIL_UP else 2)), (BODY, 4, 7 + body_dy), (HEAD, 0 + head_dx, 4 + body_dy + head_dy)]
    legs = []
    # The far hind leg first, darker, a pixel off the near one (forward when sitting, back when stretched).
    for (x, y, rows) in hind:
        dx = -1 if rows is H_SIT else 1
        legs.append(([r.translate(FAR) for r in rows], x + dx, y + 1))
    for (x, y, rows) in front + hind:
        legs.append((rows, x, y + 1))
    return merged(legs + parts, w, h)
LEG_DN = ["R", "R"]
LEG_BK = ["R.", ".R"]
LEG_FW = [".R", "R."]
# Bounding as the hare: big hind legs do the work, the front ones are half as long.
# Hind: sitting (thigh and a long foot on the ground), pushing (stretched back), tucked (folded under the rump).
H_SIT = ["rRR", "hRR"]
H_PUSH = ["r.", "rR", ".h"]
H_TUCK = ["rR", "hR"]
F_DOWN = ["r", "h"]
F_FWD = ["h"]
F_TUCK = ["h"]
RUN_W = [
 run_side(1, 1, 0, [(5, 11, F_DOWN)], [(8, 11, H_SIT)], TAIL_UP, (10, 0)),       # gathered
 run_side(0, 0, 0, [(5, 10, F_TUCK)], [(10, 10, H_PUSH)], TAIL_UP, (10, -1)),    # pushing off
 run_side(-1, -1, 0, [(3, 9, F_FWD)], [(11, 9, H_PUSH)], TAIL_BACK, (11, 4)),   # stretched
 run_side(1, 0, 0, [(4, 11, F_DOWN)], [(10, 10, H_TUCK)], TAIL_UP, (10, 0)),     # landing on the front
]
WALK_W = [
 run_side(1, 1, 0, [(5, 11, F_DOWN)], [(8, 11, H_SIT)], TAIL_UP, (10, 0)),
 run_side(0, 1, 0, [(5, 10, F_TUCK)], [(9, 10, H_PUSH)], TAIL_UP, (10, -1)),
 run_side(-1, 0, 0, [(4, 9, F_FWD)], [(10, 9, H_PUSH)], TAIL_UP, (10, -1)),
 run_side(1, 1, 0, [(5, 11, F_DOWN)], [(9, 10, H_TUCK)], TAIL_UP, (10, 0)),
]
HEAD_S = ["R.....R", "rR...Rr", "rrrrrrr", "rkrrrkr", ".rWkWr.", "rrWWWrr", "rrWWWrr", ".rwWwr."]
BODY_S = ["r"]
TAIL_S = [".llh.", "lhhrr", "hhrrR", ".hrR.", "..rR."]
HEAD_N = ["R.....R", "rR...Rr", "rrrrrrr", "rrrrrrr", ".rrrrr."]
BODY_N = [".rrrrr.", "rrrRrrr", ".rRRRr."]
TAIL_N = ["..llh..", ".lhhhr.", "lhhrrrR", "hhrrrRR", ".hrrRR.", "..rRR..", "...R..."]
def run_front(head, body, tail, view, dy, paws, w=13, h=14):
    """paws: (x, y, rows) each."""
    if view == 's':
        parts = [(tail, 8, 1 + dy), (head, 3, 3 + dy)]
    else:
        parts = [(body, 3, 7 + dy), (head, 3, 3 + dy), (tail, 3, 6 + dy)]
    legs = [(rows, x, y) for (x, y, rows) in paws]
    return merged(legs + parts, w, h)
# Front and back: hind feet wide at the sides, front paws one pixel under the chest.
HF, FP, HD, HT = ["Rh"], ["h"], ["R", "Rh"], ["R"]
def _hf(x): return ["hR"] if x > 6 else ["Rh"]
def front_run(head, body, tail, v):
    return [run_front(head, body, tail, v, 1, [(3, 12, _hf(3)), (8, 12, _hf(8)), (5, 12, FP), (7, 12, FP)]),
            run_front(head, body, tail, v, 0, [(3, 11, HD), (8, 11, ["R", "hR"])]),
            run_front(head, body, tail, v, -1, [(4, 10, ["R", "R"]), (8, 10, ["R", "R"]), (5, 10, FP), (7, 10, FP)]),
            run_front(head, body, tail, v, 1, [(5, 12, FP), (7, 12, FP), (3, 11, HT), (9, 11, HT)])]
RUN_S = front_run(HEAD_S, BODY_S, TAIL_S, 's')
RUN_N = front_run(HEAD_N, BODY_N, TAIL_N, 'n')
REST = {
 's': [".KK...KK.KKK.", ".KrK.KrK.KhlK", ".KrrKrrK.KrhK", "KrrrrrrrKKRhK", "KrkrrrkrK.KRK", "KrrWkWrrK.KRK",
       ".KrWWWrK.KRrK", ".KRhWhRKKKRrK", "KRrWWWrRKRrK.", "KRrWwWrRKKK..", ".KrwwwrK.....", ".KhKKKhK....."],
 'w': [".KK......KKK..", ".KrK....KhllK.", "KrrrKK..KrhhlK", "KrkrrrK.KRrhhK", "KrrrrRK..KRrhK", "KWWrRK...KRrhK",
       ".KWWrRK..KRrK.", ".KWhWrRK.KRrK.", "..KWWrRRKKRrK.", "..KwWrrRRKRK..", ".KhKKrrRRKK...", "..KKKKKKKK...."],
}
_TB = [".llh", "lhhr", "hhrR", "hrR.", "hrR.", ".rR.", ".rR.", "..rR", "..rR", "...R"]
_HB = ["R.....R", "rR...Rr", "rrrrrrr", "rrrrrrr", ".rrrrr."]
_BB = [".rrrrr.", "rrrRrrr", "rrRRRrr", "rrRRRrr", ".rRRRr.", "h.....h"]
REST['n'] = trim(merged([(_TB, 0, 0), (_BB, 3, 5), (_HB, 3, 1)], 12, 12))
def rest(d): return pad(REST[d], 1, 1, 2)
IDLE = {
 's': [rest('s'), paint(rest('s'), [(3, 6, 'r'), (7, 6, 'r')]), squash(rest('s'), 10), paint(rest('s'), [(2, 2, '__'), (2, 3, '.KK')])],
 'n': [rest('n'), squash(rest('n'), 10), rest('n'), shiftx(rest('n'), -1, 2, 6)],
 'w': [rest('w'), paint(rest('w'), [(3, 5, 'r')]), squash(rest('w'), 7), paint(rest('w'), [(2, 2, '__'), (2, 3, '.KK')])],
}
def walk_front(head, body, tail, v):
    return [run_front(head, body, tail, v, 1, [(3, 12, _hf(3)), (8, 12, _hf(8)), (5, 12, FP), (7, 12, FP)]),
            run_front(head, body, tail, v, 0, [(3, 11, HD), (8, 11, ["R", "hR"])]),
            run_front(head, body, tail, v, 0, [(4, 11, ["R"]), (8, 11, ["R"]), (5, 11, FP), (7, 11, FP)]),
            run_front(head, body, tail, v, 1, [(5, 12, FP), (7, 12, FP), (3, 11, HT), (9, 11, HT)])]
WALK = {'s': walk_front(HEAD_S, BODY_S, TAIL_S, 's'), 'n': walk_front(HEAD_N, BODY_N, TAIL_N, 'n'), 'w': WALK_W}
RUN = {'s': RUN_S, 'n': RUN_N, 'w': RUN_W}
DEAD = outline(["...R.R...........", ".rrrrrrrrrr.lhh..", "rKrrrrrrrrRlhhrrR", ".WWWWrrRRRRhhrrR.", "..R.R..R.R..rrR.."])
# No outline inside the body (the user's rule): every frame cleaned.
for _d in (IDLE, WALK, RUN):
    for _v in _d:
        _d[_v] = [no_inner(f, keep='kW') for f in _d[_v]]
