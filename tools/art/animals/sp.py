from eng import *
from bird import *
PAL = {'K': '#2b201a', 'G': '#7a7470', 'g': '#9a948e', 'R': '#7a3f22', 'r': '#a85d34', 'h': '#c8844e',
       'B': '#4e3020', 'k': '#181414', 'W': '#ece6d8', 'w': '#c8c0b0', 'v': '#a39a8c', 'Y': '#c4ac8a', 'P': '#c89880'}
REST = {
 's': ["..KKK..", ".KGgGK.", "KRkGkRK", "KWWYWWK", "KRWkWRK", "KhRwRhK", "KRwwwRK", ".KvvvK.", "..KKK..", "..P.P.."],
 'n': ["..KKK..", ".KGGGK.", "KGGgGGK", "KRRRRRK", "KhrBrhK", "KrBrBrK", "KRrBrRK", ".KRBRK.", "..KBK..", "..PKP.."],
 'w': ["..KKK......", ".KGgGK.....", "KGkRRRK....", "YkWWRhKKK..", ".KkWhrBrhKK", ".KkwRWBhBBK", "..KwwRBrBK.", "...KKKKKK..", "....P.P...."],
}
# Flight, side (fills): body horizontal facing left; wing up, level, down.
BODY_W = [".GG.........", "GkRRrr......", "YWWRhrBrBB..", ".kwwwvrBBBB.", "..vvvv......"]
WUP = ["......hB", ".....hrB", "....hrrB", "...hrrBB", "..hrrrB.", "..rrrr.."]
WMID = ["hhrrrBBB", ".hrrrBB."]
WDN = ["rrrrB.", ".hrrB.", "..hrB.", "...hB."]
BX, BY = 1, 6
SIDE_FLY = side_flight(BODY_W, BX, BY, [(WUP, BX + 2, BY - 4), (WMID, BX + 3, BY + 1), (WDN, BX + 4, BY + 2), (WMID, BX + 3, BY + 1)], 14, 12)
BODY_S = [".GgG.", "RkGkR", "WWYWW", "RWkWR", "rwwwr", "rwwwr", ".vvv."]
BODY_N = [".GGG.", "GGgGG", "RRRRR", "hrBrh", "rrBrr", ".RBR.", "..B.."]
UP_L = ["B.....", "hB....", "rhB...", "rrhB..", ".Rrhhr", "..Rrrr", "....Rr"]
MID_L = ["BBhhrr", ".Bhrrr", "..BRrr"]
DN_L = ["..Rrrr", ".Rrhhr", "rrhBRr", "rhB...", "hB...."]
FX, FY = 6, 5
def _f(body): return front_flight(body, FX, FY, [(UP_L, FX - 5, FY - 1), (MID_L, FX - 5, FY + 3), (DN_L, FX - 5, FY + 3), (MID_L, FX - 5, FY + 3)], 17, 13)
FS = _f(BODY_S)
FN = _f(BODY_N)

def rest(d): return pad(REST[d], 1, 1, 2)
IDLE = {
 's': [rest('s'), paint(rest('s'), [(3, 4, 'G.G')]), squash(rest('s'), 8), paint(rest('s'), [(3, 4, 'G.G')])],
 'n': [rest('n'), paint(rest('n'), [(3, 10, '.K.')]), squash(rest('n'), 8), rest('n')],
 'w': [rest('w'), paint(rest('w'), [(3, 4, 'G')]), squash(rest('w'), 8), paint(rest('w'), [(9, 5, 'KK'), (10, 6, 'BK'), (10, 7, 'BK'), (11,8,'.')])],
}
# Hops: crouched, pushing off (legs long), in the air (legs tucked), landed.
def hop(d):
    r = rest(d)
    longleg = r[:-1] + [r[-1]]
    stretch = up(r, 1)[:-2] + [r[-1].replace('P', 'P'), r[-1]]
    return [squash(r, 8), stretch, up(r, 2, 1), r]
WALK = {d: hop(d) for d in 'snw'}
DEAD = outline(["....P.P....", ".GgWwwwvB..", "YkWRrhrBBBB", ".RRrBrBhB.."], skip='P')
