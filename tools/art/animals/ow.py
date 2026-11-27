from eng import *
from bird import *
PAL = {'K': '#2a1c14', 'D': '#5a3c26', 'B': '#7a5434', 'b': '#9a7048', 'c': '#bc9466', 'W': '#e2d0a8',
       'k': '#140e0a', 'e': '#f4ead0', 'y': '#c8a860', 'Y': '#8a7038'}
# A tawny owl: round head without ear tufts, a pale facial disc, dark eyes, mottled brown body.
_S = mir([".BBBB", "BcWWW", "BWekW", "BWkky", "BcWcY", "DBbcb", "DBcbc", "DBbcB", "DBcbc", ".DBbB", "..DBB"])
_W = ["..BBBB..", ".BDbBBB.", "BcWWbBD.", "WekWcBD.", "yWWcbBD.", ".cbcbBDD", ".bcbBBDD", ".cbcBDDD",
      ".bcbBDD.", "..cbBDD.", "...BDDD."]
_N = mir([".BBBB", "BDbBb", "BBDbB", "BbBDb", "BBBbB", "DBbBD", "DBDbB", "DBbBD", "DBDbB", ".DBDB", "..DDD"])
def _stand(fills, feet):
    return outline(fills + [feet], skip='y')
REST = {'s': _stand(_S, "..y...y.."), 'n': _stand(_N, "..y...y.."), 'w': _stand(_W, "...y.y..")}
def rest(d): return pad(REST[d], 1, 1, 2)
def _blink(r, d):
    return [x.replace('e', 'B').replace('k', 'D') for x in r]
IDLE = {
 's': [rest('s'), _blink(rest('s'), 's'), squash(rest('s'), 9), _blink(rest('s'), 's')],
 'n': [rest('n'), squash(rest('n'), 9), rest('n'), squash(rest('n'), 9)],
 'w': [rest('w'), _blink(rest('w'), 'w'), squash(rest('w'), 9), _blink(rest('w'), 'w')],
}
def hop(d):
    r = rest(d)
    return [squash(r, 9), up(r, 1)[:-2] + [r[-1], r[-1]], up(r, 2, 1), r]
WALK = {d: hop(d) for d in 'snw'}
# Flight: crow-sized wings in the owl's browns, one outline round wing and body.
T = str.maketrans({'k': 'D', 'n': 'B', 'b': 'c'})
BODY_W = ["..BBB...........", ".BcWbB..........", "yWekbBDBbBD.....", ".WWcbBbcbBBDDDD.", "..cbcbBcbBDDDD..", "...cbcbbB......"]
WUP = [r.translate(T) for r in [".........kk", "........knk", ".......knnk", "......knbn.", ".....knbn..", "...nnbbn...", "..nnnnn...."]]
WMID = [r.translate(T) for r in ["nbbbbbnnkkk", ".nnnnnnkkk."]]
WDN = [r.translate(T) for r in ["nnnnnk.", ".nbbnk.", "..nnbk.", "...nnk.", "....kk.", "....k.."]]
BX, BY = 1, 7
SIDE_FLY = side_flight(BODY_W, BX, BY, [(WUP, BX + 3, BY - 4), (WMID, BX + 4, BY + 2), (WDN, BX + 5, BY + 3), (WMID, BX + 4, BY + 2)], 19, 16)
BODY_S = [".BBBBB.", "BWWWWWB", "WekWekW", "WkkykkW", "BcWYWcB", ".cbcbc.", ".bcbcb.", ".cbcbc.", "..bcb..", "..BBB.."]
BODY_N = [".BBBBB.", "BDbBbDB", "BbBDBbB", "BBbBbBB", ".DBbBD.", ".BDbDB.", ".DBbBD.", "..DBD..", "..DDD.."]
UP_L = [r.translate(T) for r in ["k........", "kk.......", ".kn......", ".knb.....", "..knbb...", "...knnbbn", "....knnnn", "......knn"]]
MID_L = [r.translate(T) for r in ["kk.k.....", "kknnbbbnn", ".kknnnnnn", "....kknnn"]]
DN_L = [r.translate(T) for r in ["....knnnn", "...knnbbn", "..knbbnnn", ".knb.....", ".kn......", "kk.......", "k........"]]
FX, FY = 9, 4
# the user's pick: each wing's upper edge from the raised wing, its lower edge from the wing 1 px lower
_WINGS = [(UP_L, -1), (MID_L, 3), (DN_L, 4), (MID_L, 3)]
def _f(body):
    out = []
    for wr, dy in _WINGS:
        x = FX - 8; mid = FX + len(body[0]) // 2; rx = 2 * mid - (x + len(wr[0]) - 1)
        out.append(merged([(wr, x, FY + dy), (flip(wr), rx, FY + dy), (wr, x, FY + dy - 1), (flip(wr), rx, FY + dy - 1), (body, FX, FY)], 26, 18))
    return out
FS = _f(BODY_S)
FN = _f(BODY_N)
DEAD = outline(["........y..y.....", ".BBB.cbcbcbBB.....", "yWekbBcbcbBBDDDDD", ".WWcbBbBbBDDDD...", "....DDDDDDD......"], skip='y')
