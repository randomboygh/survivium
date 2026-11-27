from eng import *
from bird import *
PAL = {'K': '#1c2218', 'G': '#2f6a3a', 'g': '#4c9a50', 'e': '#101010', 'Y': '#d8b030', 'y': '#a88420', 'W': '#eeeeea',
       'C': '#6e3a28', 'c': '#94553a', 'w': '#b8b6ae', 'v': '#8e8c86', 'B': '#3a4a8a', 'k': '#2a2a2a', 'O': '#e07a28',
       'u': '#7a7264', 'b': '#5a5248'}
REST = {
 's': mir(["...KKK", "..KgGG", ".KeGGG", ".KGGYY", "..KKYy", "...KWW", "..KcCC", ".KcCCc", "KwcCCC", "KvwcCC", "KvvwCc", ".KvvwC", "..KKKK", "...O.."]),
 'n': mir(["...KKK", "..KgGG", ".KGGGG", ".KGGGg", "..KGGG", "...KWW", "..Kubb", ".KBuub", "KvBuub", "KvvBuu", ".KvvBu", "..KWkk", "...Kkk", "...KKK", "...O.."]),
 'w': ["...KKK...........", "..KgGGK..........", ".KGeGgK..........", "YYKGGGK..........", "YyyKGGK..........",
       "..KWWWK..........", ".KcCCcCKKKKKK.KK.", "KcCCCcwwwvwvvKkkK", "KCcCCwwvwvvvBBkK.", ".KCCwwwvvvvBBBK..",
       ".KKCwvvvvvvBKK...", "..KKKKKKKKKK.....", "....O...O........"],
}
def rest(d): return pad(REST[d], 1, 1, 2)
def setrow(r, i, s): r = list(r); r[i] = s; return r
IDLE = {
 's': [rest('s'), paint(rest('s'), [(3, 4, 'G'), (9, 4, 'G')]), shiftx(rest('s'), 1, 0, 7), shiftx(rest('s'), -1, 0, 7)],
 'n': [rest('n'), shiftx(rest('n'), 1, 0, 7), rest('n'), shiftx(rest('n'), -1, 0, 7)],
 'w': [rest('w'), paint(rest('w'), [(3, 4, 'G')]), up(squash(rest('w'), 7), 0), paint(rest('w'), [(14, 8, 'KK'), (15, 9, 'kK')])],
}
def waddle(d):
    r = rest(d); w = len(r[0])
    if d == 'w':
        a = setrow(r, -1, ".....O.....O......"[:w].ljust(w, '.'))
        b = setrow(r, -1, ".......OO........."[:w].ljust(w, '.'))
        return [a, b, setrow(r, -1, "....O....O........"[:w].ljust(w, '.')), b]
    L = r[-1]; xs = [i for i, c in enumerate(L) if c != '.']
    l1 = ''.join(c if i != xs[-1] else '.' for i, c in enumerate(L))
    l2 = ''.join(c if i != xs[0] else '.' for i, c in enumerate(L))
    return [setrow(shiftx(r, 1, 0, len(r) - 1), -1, l1), r, setrow(shiftx(r, -1, 0, len(r) - 1), -1, l2), r]
WALK = {d: waddle(d) for d in 'snw'}
BODY_W = ["..gG............", ".geGg...........", "YYGGG...........", "Yy.WcCcwwvwvvkkk", "...CcCwwwvvvBBk.", "....vvvvvvvv...."]
WUP = ['.........bb', '........bub', '.......buub', '......buwu.', '.....buwu..', '...uuwwu...', '..uuuuu....']
WMID = ['uwwwwwuubbb', '.uuuuuubbb.']
WDN = ['uuuuub.', '.uwwub.', '..uuwb.', '...uub.', '....bb.', '....b..']
BX, BY = 1, 7
SIDE_FLY = side_flight(BODY_W, BX, BY, [(WUP, BX + 4, BY - 4), (WMID, BX + 5, BY + 2), (WDN, BX + 6, BY + 3), (WMID, BX + 5, BY + 2)], 20, 16)
BODY_S = ["..GGG..", ".GgGgG.", ".eGGGe.", "..YYY..", "..WyW..", ".cCCCc.", ".wcCcw.", ".wcCcw.", "..vvv.."]
BODY_N = ["..GGG..", ".GgGGG.", ".GGGGG.", "..GGG..", "..WWW..", ".ubbbu.", ".vuBuv.", ".vuuuv.", "..kkk.."]
UP_L = ['b........', 'bb.......', '.bu......', '.buw.....', '..buww...', '...buuwwu', '....buuuu', '......buu']
MID_L = ['bb.b.....', 'bbuuwwwuu', '.bbuuuuuu', '....bbuuu']
DN_L = ['....buuuu', '...buuwwu', '..buwwuuu', '.buw.....', '.bu......', 'bb.......', 'b........']
FX, FY = 9, 4
def _f(body): return front_flight(body, FX, FY, [(UP_L, FX - 8, FY - 1), (MID_L, FX - 8, FY + 3), (DN_L, FX - 8, FY + 4), (MID_L, FX - 8, FY + 3)], 26, 18)
FS = _f(BODY_S)
FN = _f(BODY_N)

DEAD = outline(["........O..O.....", ".gG..wwwvvvv......", "YeGGWcCcwwvvBBkkk", "YyGGCcCuubbbBBk..", "....uuubbbb......"], skip='O')
