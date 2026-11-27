from eng import *
from bird import *
PAL = {'K': '#141318', 'k': '#25242c', 'n': '#36353f', 'b': '#55556a', 'G': '#7f8188', 'g': '#a0a2a8', 'd': '#5f616a', 'e': '#9a9ab0'}
REST = {
 's': mir(["...KKK", "..Kknb", ".Kkekk", ".Kkkkb", "..KkKn", ".KKkkK", "KkkGkk", "KkkgGk", "KknkGG", "KknkdG", ".KkkdG", "..KKKK", "...k.."]),
 'n': mir(["...KKK", "..Kknb", ".Kkknn", ".Kkkkk", "..KkGG", ".KKgGg", "KkkdGG", "KknkdG", "Kknkkd", ".Kknkk", "..KKkn", "...KKk", "...k.K"]),
 'w': ["....KKK..........", "...KnbnK.........", ".KKkekknK........", "KbnnkkknK........", ".KKKkkkkKK.......",
       "....KkGgGgKK.....", "....KkgGgGgnKK...", "....KdGnbnnnnkKK.", ".....KdnkkkkkkkkK", "......KKKkkkKKKK.",
       ".......KkK.......", ".......k.k......."],
}
def rest(d): return pad(REST[d], 1, 1, 2)
def legs(r, last, prev=None):
    r = list(r); r[-1] = last
    if prev is not None: r[-2] = prev
    return r
IDLE = {
 's': [rest('s'), paint(rest('s'), [(3, 4, 'k'), (9, 4, 'k')]), squash(rest('s'), 9), paint(rest('s'), [(3, 4, 'k'), (9, 4, 'k')])],
 'n': [rest('n'), shiftx(rest('n'), -1, 0, 7), squash(rest('n'), 9), shiftx(rest('n'), 1, 0, 7)],
 'w': [rest('w'), paint(rest('w'), [(3, 4, 'k')]), squash(rest('w'), 9), paint(rest('w'), [(16, 8, 'KK'), (15, 10, 'KK'), (16, 9, 'nK')])],
}
def steps(d):
    r = rest(d); w = len(r[0])
    if d == 'w':
        a = legs(r, "......k...k........"[:w].ljust(w, '.'))
        b = up(legs(r, '.' * w), 1)
        b = legs(b, "........k.........."[:w].ljust(w, '.'))
        c = legs(r, ".......k..k........"[:w].ljust(w, '.'))
        return [a, b, c, b]
    L = r[-1]; xs = [i for i, ch in enumerate(L) if ch != '.']
    left = ''.join(ch if i != xs[-1] else '.' for i, ch in enumerate(L))
    right = ''.join(ch if i != xs[0] else '.' for i, ch in enumerate(L))
    return [r, legs(up(r, 1), right), r, legs(up(r, 1), left)]
WALK = {d: steps(d) for d in 'snw'}
# Flight: side body facing left; wings up, level, down.
BODY_W = ["..kk............", ".kenk...........", "bnnkkkdGGGd.....", "..kkkGgGgGGnkkkk", "....dGGGdnkkkkk.", ".....ddddd......"]
WUP = ['.........kk', '........knk', '.......knnk', '......knbn.', '.....knbn..', '...nnbbn...', '..nnnnn....']
WMID = ['nbbbbbnnkkk', '.nnnnnnkkk.']
WDN = ['nnnnnk.', '.nbbnk.', '..nnbk.', '...nnk.', '....kk.', '....k..']
BX, BY = 1, 7
SIDE_FLY = side_flight(BODY_W, BX, BY, [(WUP, BX + 3, BY - 4), (WMID, BX + 4, BY + 2), (WDN, BX + 5, BY + 3), (WMID, BX + 4, BY + 2)], 19, 16)
BODY_S = ["..kkk..", ".knbnk.", ".kekek.", ".kkbkk.", "..knk..", ".kGgGk.", ".kgGgk.", "..dGd..", "..kkk.."]
BODY_N = ["..kkk..", ".kknkk.", ".kkkkk.", "..GgG..", ".dGgGd.", ".kdGdk.", "..knk..", "..kkk..", "...k..."]
UP_L = ['k........', 'kk.......', '.kn......', '.knb.....', '..knbb...', '...knnbbn', '....knnnn', '......knn']
MID_L = ['kk.k.....', 'kknnbbbnn', '.kknnnnnn', '....kknnn']
DN_L = ['....knnnn', '...knnbbn', '..knbbnnn', '.knb.....', '.kn......', 'kk.......', 'k........']
FX, FY = 9, 4
def _f(body): return front_flight(body, FX, FY, [(UP_L, FX - 8, FY - 1), (MID_L, FX - 8, FY + 3), (DN_L, FX - 8, FY + 4), (MID_L, FX - 8, FY + 3)], 26, 18)
FS = _f(BODY_S)
FN = _f(BODY_N)

DEAD = outline(["........k.k.....", "..kk.GGGGGd......", "bnnkkgGgGGdnkkkkk", "..kkknnbbnnkkkk..", "....kkkkkkk......"], skip='')
