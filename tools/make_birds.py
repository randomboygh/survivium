"""Draws the sheets of the crow, the owl and the duck, content/animals/<bird>/sprites/creatures/.

Drawn by hand in the sparrow's style (tools/make_sparrow.py, 2026-11-07): an outline in
the bird's darkest colour round the whole bird, broad wings in flight. Each species has
a canvas, a palette, its standing art in five views and a level flying body seen from
the side; the wings are shared templates moved to its shoulder.

Rows (creatures.yaml `views: 5`): the side (E, facing right), the front (S), the back
(N), the front three-quarter (SE) and the back three-quarter (NE); the game mirrors
them for the other three ways. Columns (`frames: 9`, `walk: 4`, `hop: 2`): sitting, the
wing beat (up, level, down, rising), two idle frames (feeding; the owl blinks and looks
down), and the hop on the ground (crouched, in the air; the duck waddles instead).

    python3 tools/make_birds.py [crow owl duck]
"""
import os
import sys

from PIL import Image

OUTLINE_SKIP = "LO"


def art(rows):
    return {(x, y): ch for y, r in rows.items() for x, ch in enumerate(r) if ch != "."}


def shift(px, dx, dy):
    return {(x + dx, y + dy): ch for (x, y), ch in px.items()}


def hexc(s):
    return tuple(int(s[i:i + 2], 16) for i in (1, 3, 5)) + (255,)


# Wing templates (crow-sized), shoulder about (8, 9) side and (5, 10) front-left.
SIDE_WINGS = [
    art({0: "...w.w.w.w..", 1: "...wwwwwww..", 2: "...wwWWWWw..", 3: "....WWWWWW..",
         4: ".....WWYWW..", 5: "......WWWW..", 6: ".......WWW..", 7: "........WW..", 8: "........WW.."}),
    art({7: "....wwWWWWW.", 8: "..wwwwWWYYWW", 9: "w.wwwwWWWWW.", 10: "..w.w.w....."}),
    art({9: "........WW....", 10: ".......WWYYWW.", 11: "......WWWWWW..", 12: ".....wwWWWW...",
         13: "...wwwwWW.....", 14: "..w.w.w......."}),
    art({3: ".ww.......", 4: "..www.....", 5: "..wwwWW...", 6: "....WWWWW.", 7: "......WYWW",
         8: ".......WWW"}),
]
FRONT_WINGS = [
    art({1: "w.w.w...", 2: "wwwww...", 3: "wwWWWw..", 4: ".wWWWW..", 5: "..WWWYW.",
         6: "...WWWW.", 7: "....WWWW", 8: ".....WWW", 9: "......WW"}),
    art({8: "...wWWWW..", 9: "wwwWWWYYW.", 10: "wwwwWWWW..", 11: "w.w.w.w..."}),
    art({9: "......WW", 10: ".....WYW", 11: "....WWW.", 12: "..wwWW..", 13: ".wwww...", 14: "w.w.w..."}),
    art({3: ".w......", 4: ".ww.....", 5: "..wWW...", 6: "...wWYW.", 7: "....WWWW", 8: "......WW"}),
]
BEAT_BOB = [0, -1, 0, -1]


class Bird:
    def __init__(self, name, w, h, axis, pal, stand, fly_e, peck, head_rows, side_off=(0, 0),
                 front_off=(0, 0), idles=None, waddle=False):
        self.name, self.W, self.H, self.axis, self.pal = name, w, h, axis, pal
        self.stand = {k: art(v) for k, v in stand.items()}
        self.fly_e = art(fly_e)
        self.peck = [art(p) for p in peck]
        self.head_rows = head_rows
        self.side_off, self.front_off = side_off, front_off
        self.idles = idles
        self.waddle = waddle

    def render(self, layers):
        out = {}
        for layer in layers:
            for (x, y), ch in layer.items():
                if 0 <= x < self.W and 0 <= y < self.H:
                    out[(x, y)] = ch
        im = Image.new("RGBA", (self.W, self.H), (0, 0, 0, 0))
        for (x, y), ch in out.items():
            im.putpixel((x, y), hexc(self.pal[ch]))
        for x in range(self.W):
            for y in range(self.H):
                if (x, y) in out:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    n = out.get((x + dx, y + dy))
                    if n is not None and n not in OUTLINE_SKIP:
                        im.putpixel((x, y), hexc(self.pal["O"]))
                        break
        return im

    def mirror(self, px):
        return {(self.axis - x, y): ch for (x, y), ch in px.items()}

    def posed(self, view, head=(0, 0), bob=0, crouch=False, swap=None, sway=0):
        px = {}
        items = sorted(self.stand[view].items(), key=lambda kv: kv[0][1] <= self.head_rows)
        for (x, y), ch in items:
            dx, dy = head if y <= self.head_rows else (0, 0)
            if crouch and ch != "L":
                dy += 1
            if sway and ch != "L":
                dx += sway
            if swap and ch in swap:
                ch = swap[ch]
            px[(x + dx, y + dy + bob)] = ch
        return px

    def fly_body(self, view):
        if view == "E":
            return self.fly_e
        return shift({k: ch for k, ch in self.stand[view].items() if ch != "L"}, 0, -1)

    def flight(self, view, i):
        body = self.fly_body(view)
        side = shift(SIDE_WINGS[i], *self.side_off)
        left = shift(FRONT_WINGS[i], *self.front_off)
        if view == "E":
            layers = [body, side]
        elif view in ("S", "N"):
            layers = [left, self.mirror(left), body]
        else:
            far = {k: ("w" if ch in "WY" else "D") for k, ch in shift(self.mirror(left), -1, 0).items()}
            layers = [far, body, shift(side, 0, 1)]
        return self.render([shift(layer, 0, BEAT_BOB[i]) for layer in layers])

    def frames(self, view):
        side = view not in ("S", "N")
        out = [self.render([self.posed(view)])]
        out += [self.flight(view, i) for i in range(4)]
        if self.idles is not None:
            out += [self.render([p]) for p in self.idles(self, view)]
        elif side:
            out += [self.render([p]) for p in self.peck]
        else:
            out += [self.render([self.posed(view, head=(0, 1))]), self.render([self.posed(view, head=(0, 2))])]
        if self.waddle:
            out += [self.render([self.posed(view, sway=-1 if side else 0, bob=-1 if side else 0)]),
                    self.render([self.posed(view, sway=0 if side else 1, bob=0 if side else -1)])]
        else:
            out += [self.render([self.posed(view, crouch=True)]), self.render([self.posed(view, bob=-2)])]
        return out

    def sheet(self, order=("E", "S", "N", "SE", "NE")):
        rows = [self.frames(v) for v in order]
        im = Image.new("RGBA", (self.W * len(rows[0]), self.H * len(rows)), (0, 0, 0, 0))
        for j, r in enumerate(rows):
            for i, f in enumerate(r):
                im.alpha_composite(f, (i * self.W, j * self.H))
        return im


# ---- Crow --------------------------------------------------------------------------------
CROW = Bird("crow", 18, 15, 17, {
    "O": "#121018", "L": "#121018", "K": "#3a3850", "k": "#5c5a7a", "D": "#24223a", "T": "#2c2a42",
    "E": "#8e8aa8", "B": "#5a5664", "W": "#3e3c56", "w": "#1e1c2c", "Y": "#55536e",
}, {
    "E": {5: "...........kKK....", 6: "..........kKKKKB..", 7: "..........KKEKBB..",
          8: ".........kKKKK....", 9: "......kkKKKKKK....", 10: "...kkKKKKKKKKK....",
          11: ".TTKKKKKKDKKK.....", 12: "TTTDKKKKDDKK......", 13: "......DDDD........",
          14: "......L.L........."},
    "S": {5: ".......kKKk.......", 6: "......kKKKKk......", 7: "......KEKKEK......",
          8: ".......KBBK.......", 9: "......kKBBKk......", 10: ".....kKKKKKKk.....",
          11: ".....KKKKKKKK.....", 12: ".....DKKKKKKD.....", 13: "......DDKKDD......",
          14: ".......L..L......."},
    "N": {5: ".......kKKk.......", 6: "......kKKKKk......", 7: "......KKKKKK......",
          8: ".......KKKK.......", 9: "......kKKKKk......", 10: ".....kKKKKKKk.....",
          11: ".....KKDKKDKK.....", 12: ".....DKKDDKKD.....", 13: "......DDTTDD......",
          14: ".......LTTL......."},
    "SE": {5: "...........kKK....", 6: "..........kKKKKB..", 7: "..........KEKKBB..",
           8: ".........kKKKK....", 9: "......kkKKKKKK....", 10: "....kKKKKKKKKK....",
           11: "..TKKKKKKKKKK.....", 12: ".TTDKKKKKKKK......", 13: "......DDDDD.......",
           14: "......L..L........"},
    "NE": {5: "...........kKK....", 6: "..........kKKKKB..", 7: "..........KKKKB...",
           8: ".........kKKKK....", 9: "......kkKKKKKK....", 10: "...kKKKKKKKKKK....",
           11: ".TTKKDKKKDKKK.....", 12: "TTTDKKDKKDKK......", 13: ".T....DDDD........",
           14: "......L..L........"},
}, {6: "............kKK...", 7: "...........kKKKKB.", 8: ".TT.......KKKEKBB.",
    9: "TTTTKKKKKKKKKK....", 10: ".TTKKKKKKKKKK.....", 11: ".....DDDDDDD......"},
    [{7: ".T................", 8: ".TTkk.............", 9: "..TKKKkkKK........",
      10: "...KKKKKKKkKK.....", 11: "....KKKKKKKKKEK...", 12: ".....DKKDDKKKBB...",
      13: "......DDDD....B...", 14: "......L.L........."},
     {8: ".T................", 9: ".TTk..............", 10: "..TKKkkKKK........",
      11: "...KKKKKKKKkK.....", 12: "....DKKKDDKKKEK...", 13: ".....DDDDD..KKB...",
      14: "......L.L....B...."}],
    head_rows=8)


# ---- Owl ---------------------------------------------------------------------------------
def owl_idles(bird, view):
    # Blinks, then looks down.
    blink = {"G": "D", "E": "D"}
    return [bird.posed(view, swap=blink), bird.posed(view, head=(0, 1))]


OWL = Bird("owl", 16, 17, 15, {
    "O": "#2a1e14", "L": "#2a1e14", "A": "#9a7a52", "a": "#c8a878", "D": "#6a5034", "T": "#7a5c3c",
    "t": "#6a5034", "F": "#e0c8a0", "G": "#f0c030", "E": "#1a1008", "B": "#4a3a2a",
    "W": "#8a6a44", "w": "#5a4228", "Y": "#c8a878",
}, {
    "E": {4: ".........t......", 5: "......aAAAt.....", 6: ".....aAAFFF.....", 7: ".....AAFGEF.....",
          8: ".....AAAFFB.....", 9: "....aAAAaa......", 10: "....AADAaa......", 11: "....AAADaa......",
          12: "...DAADAaa......", 13: "...DDAAAa.......", 14: "...TDDAA........", 15: "...TT.DD........",
          16: ".....L.L........"},
    "S": {4: "....t......t....", 5: "....aAAAAAAa....", 6: "....AFFFFFFA....", 7: "....FGEFFEGF....",
          8: "....AFFBBFFA....", 9: "....aAFFFFAa....", 10: "....AaaaaaaA....", 11: "....AaDaaDaA....",
          12: "....AaaaaaaA....", 13: "....DAaDDaAD....", 14: ".....DAaaAD.....", 15: "......DDDD......",
          16: "......L..L......"},
    "N": {4: "....t......t....", 5: "....aAAAAAAa....", 6: "....AAAAAAAA....", 7: "....AADAADAA....",
          8: "....AAAAAAAA....", 9: "....aAAAAAAa....", 10: "....AADAADAA....", 11: "....AAAAAAAA....",
          12: "....AADAADAA....", 13: "....DAAAAAAD....", 14: ".....DATTAD.....", 15: "......TTTT......",
          16: "......L..L......"},
    "SE": {4: ".....t....t.....", 5: ".....aAAAAAa....", 6: ".....AFFFFFF....", 7: ".....AFGEFGE....",
           8: ".....AFFFBFF....", 9: "....aAAFFFFa....", 10: "....AAaaaaa.....", 11: "....AADaaDa.....",
           12: "...DAAaaaaa.....", 13: "...DAAaDDaa.....", 14: "...TDAAaaA......", 15: "...TT.DDD.......",
           16: "......L.L......."},
    "NE": {4: ".....t....t.....", 5: ".....aAAAAAa....", 6: ".....AAAAAAF....", 7: ".....AADAAFF....",
           8: ".....AAAAAFB....", 9: "....aAAAAAa.....", 10: "....AADAADA.....", 11: "....AAAAAAA.....",
           12: "...DAADAADA.....", 13: "...DAAAAAAA.....", 14: "...TDAAAAD......", 15: "...TT.DDD.......",
           16: "......L.L......."},
}, {7: "...........t....", 8: "........aAAAt...", 9: ".TT....aAAFFF...", 10: "TTTAAAAAAFGEF...",
    11: ".TTAAADAAAFFB...", 12: "...DaaaaaaA.....", 13: ".....DDDD......."},
    [], head_rows=8, side_off=(-1, 1), front_off=(-1, 1), idles=owl_idles)


# ---- Duck --------------------------------------------------------------------------------
DUCK = Bird("duck", 19, 16, 17, {
    "O": "#2a2420", "L": "#e08030", "G": "#2e7a44", "g": "#4aa060", "Q": "#ece8dc", "C": "#7a4a34",
    "A": "#a89888", "a": "#c8bcae", "D": "#6a5c50", "T": "#3a3434", "S": "#3a5ab8", "E": "#0e0c0a",
    "B": "#e0b030", "W": "#9a8a7a", "w": "#5e5248", "Y": "#3a5ab8",
}, {
    "E": {5: "............gGG....", 6: "...........gGGGGB..", 7: "...........GGEGBBB.",
          8: "............GGG....", 9: "............QQQ....", 10: "...aaaaaaaaCCCC....",
          11: "..TAAAAAAAACCCC....", 12: ".TTAASSAAAAACCC....", 13: "..TDAAAAAAAACC.....",
          14: "....DDDDDDDDD......", 15: "......L..L........."},
    "S": {5: "......gGGg.......", 6: ".....gGGGGG......", 7: ".....GEGGEG......", 8: "......GBBG.......",
          9: "......QBBQ.......", 10: "....CCCCCCCC.....", 11: "...aCCCCCCCCa....", 12: "...AaaaaaaaaA....",
          13: "...DAaaaaaaAD....", 14: "....DDDDDDDD.....", 15: ".....L....L......"},
    "N": {5: "......gGGg.......", 6: ".....gGGGGg......", 7: ".....GGGGGG......", 8: "......GGGG.......",
          9: "......QQQQ.......", 10: "....aAAAAAAa.....", 11: "...aAAAAAAAAa....", 12: "...ASAAAAAASA....",
          13: "...AAAAAAAAAA....", 14: "....DATTTTAD.....", 15: ".....L.TT.L......"},
    "SE": {5: "............gGG....", 6: "...........gGGGGB..", 7: "...........GEGGBBB.",
           8: "............GGG....", 9: "............QQQ....", 10: "......aaaaaCCCC....",
           11: "....aAAAAAACCCCC...", 12: "...TAASAAAAACCC....", 13: "..TTDAAAAAAACC.....",
           14: ".....DDDDDDDD......", 15: ".......L..L........"},
    "NE": {5: "............gGG....", 6: "...........gGGGGB..", 7: "...........GGGGBB..",
           8: "............GGG....", 9: "............QQ.....", 10: "....aaaaaaaaAA.....",
           11: "..TAAAASAAAAAA.....", 12: ".TTAAAASSAAAAA.....", 13: "..TDAAAAAAAAA......",
           14: "....DDDDDDDDD......", 15: "......L..L........."},
}, {7: "..............gGG..", 8: ".TT..........gGGGBB", 9: "TTTaaaaaaaaQQGGEGB.",
    10: ".TTAAAAAAAACCC.....", 11: "...DAAAAAACC.......", 12: ".....DDDDDD........"},
    [{9: ".T.................", 10: ".TTaaaaaaa.........", 11: "..TAAAAAAACCC......",
      12: "...AASAAAACCCGG....", 13: "...DAAAAAAACGGEG...", 14: ".....DDDDDDDD.GBB..",
      15: "......L..L.....B..."},
     {10: ".T.................", 11: ".TTaaaaaaa.........", 12: "..TAAAAAAACCC......",
      13: "...AASAAAACCCCgG...", 14: "...DAAAAAAAD.GGEG..", 15: "......L..L....GBB.."}],
    head_rows=9, side_off=(1, 1), front_off=(-1, 1), waddle=True)

BIRDS = [CROW, OWL, DUCK]

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "content", "animals")


def main():
    only = sys.argv[1:]
    for b in BIRDS:
        if only and b.name not in only:
            continue
        path = os.path.join(ROOT, b.name, "sprites", "creatures", "%s.png" % b.name)
        b.sheet().save(path)
        print(path, b.W, b.H)


if __name__ == "__main__":
    main()
