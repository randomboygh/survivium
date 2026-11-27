# Round 23 step 2: the winter sheet (mockup, no game code). Run from the merged src folder (setup_run.sh):
#   winter_sheet23.py render [slot,slot..]   -> ../cache23w/<slot>_<s>.npz (keyed: ground KEY_G, shadow KEY_S)
#   winter_sheet23.py sheet <out.png> [k=2] [row width 1020]
# 24 slots: every species of sheet 87 in winter by the game's rules (content/plants trees.yaml `bare`; foliage.gd):
# a broadleaf tree goes bare (oak, linden and willow also keep dry leaves under snow: two slots each), spruce, fir and
# pine keep their needles under snow, the larch goes bare, the dead tree keeps its own limbs; the hot-zone trees
# (palms, acacia, ceiba, mangrove) stay as in summer, no snow (user 2026-11-24 «1. А»), on a patch of grass.
# The field is the game's winter ground in sun (sampled off survivium-builds/weather/snow-sun/snow-sun-v4-drift-sizes.png).
import os, sys, time, numpy as np
from multiprocessing import Pool
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, '..', 'cache23w')
KEY_G, KEY_S = 'ff00ff', '00ffff'
SIZES = (0.42, 0.68, 1.0)
SNOW_G, SNOW_S = 'eef4fb', 'bfd2e8'          # the game's sunlit snow and a tree's shadow on it

# (slot, species key, look, name, what it shows, group)
SLOTS = [
    ('oak', 'oak', 'bare', 'дуб', 'голый, снег на ветках', 'leaf'),
    ('oak_dry', 'oak', 'dry', 'дуб', 'сухие листья под снегом', 'leaf'),
    ('linden', 'linden', 'bare', 'липа', 'голая, снег на ветках', 'leaf'),
    ('linden_dry', 'linden', 'dry', 'липа', 'сухие листья под снегом', 'leaf'),
    ('birch', 'birch', 'bare', 'берёза', 'голая, снег на ветках', 'leaf'),
    ('apple', 'apple', 'bare', 'яблоня', 'голая, снег на ветках', 'leaf'),
    ('cherry', 'cherry', 'bare', 'вишня', 'голая, снег на ветках', 'leaf'),
    ('poplar', 'poplar', 'bare', 'тополь', 'голый, снег на ветках', 'leaf'),
    ('maple', 'maple', 'bare', 'клён', 'голый, снег на ветках', 'leaf'),
    ('red_maple', 'red_maple', 'bare', 'красный клён', 'голый, снег на ветках', 'leaf'),
    ('bird_cherry', 'bird_cherry', 'bare', 'черёмуха', 'голая, снег на ветках', 'leaf'),
    ('rowan', 'rowan', 'bare', 'рябина', 'голая, снег на ветках', 'leaf'),
    ('willow', 'willow', 'bare', 'ива', 'голая, снег на ветках', 'leaf'),
    ('willow_dry', 'willow', 'dry', 'ива', 'сухие листья под снегом', 'leaf'),
    ('deadwood', 'deadwood', 'dead', 'сухое дерево', 'свои сучья, снег на них', 'leaf'),
    ('spruce', 'spruce', 'ever', 'ель', 'снег на лапах', 'ever'),
    ('fir', 'fir', 'ever', 'пихта', 'снег на лапах', 'ever'),
    ('larch', 'larch', 'larch', 'лиственница', 'голая, снег на ветках', 'ever'),
    ('pine', 'pine', 'ever', 'сосна', 'снег на лапах', 'ever'),
    ('acacia', 'acacia', 'hot', 'акация', 'жаркий пояс: без снега', 'hot'),
    ('mangrove', 'mangrove', 'hot', 'мангр', 'жаркий пояс: без снега', 'hot'),
    ('ceiba', 'ceiba', 'hot', 'сейба', 'жаркий пояс: без снега', 'hot'),
    ('palm', 'palm', 'hot', 'пальма', 'жаркий пояс: без снега', 'hot'),
    ('fan_palm', 'fan_palm', 'hot', 'веерная пальма', 'жаркий пояс: без снега', 'hot'),
]
BY = {s[0]: s for s in SLOTS}


def render_one(job):
    slot, s = job
    out = os.path.join(CACHE, '%s_%.2f.npz' % (slot, s))
    if os.path.exists(out): return out, 0.0
    t0 = time.time()
    _, key, look, *_ = BY[slot]
    import all23 as A, winter23 as W, bare23 as B
    A._taller(); W.install(); W._install_twigs()
    if look == 'hot':
        summer = os.path.join(HERE, '..', 'cache23', '%s_%.2f.npz' % (key, s))
        if os.path.exists(summer):
            d = np.load(summer); np.savez_compressed(out, img=d['img'], ox=d['ox'], oy=d['oy'])
            return out, time.time() - t0
        t = A.build(key, s); img = t.render(ground=KEY_G, shade=KEY_S); ox, oy = t.ox, t.oy
    elif look == 'bare':
        t, _ = W.build(key, s, 'bare')
        B.bare_tree(t, **B.TWIG)
        if key == 'willow': B.weeping(t)
        img = t.render(ground=KEY_G, shade=KEY_S)
        B.twig_colours(t, img)
        B.snow_balls(t, img, None, None, **B.SNOWK)
        ox, oy = t.ox, t.oy
    elif look == 'dead':
        t, _ = W.build(key, s, 'bare')
        t.twig_info = B.skeleton_info(t)
        img = t.render(ground=KEY_G, shade=KEY_S)
        kw = dict(B.SNOWK); kw.update(per_mod=0, every=3)
        B.snow_balls(t, img, None, None, **kw)
        ox, oy = t.ox, t.oy
    else:
        t, _ = W.build(key, s, look)
        img = t.render(ground=KEY_G, shade=KEY_S); ox, oy = t.ox, t.oy
    np.savez_compressed(out, img=img, ox=ox, oy=oy)
    return out, time.time() - t0


def load(slot, s):
    d = np.load(os.path.join(CACHE, '%s_%.2f.npz' % (slot, s)))
    return d['img'], float(d['ox']), float(d['oy'])


def sheet(out, k=2, wmax=1020, title=None, slots=None, ground=(SNOW_G, SNOW_S), loader=None, patch=('hot',)):
    """Lay the slots out like sheet23 (thick, medium, thin a species; rows by width), a new row at each group."""
    import sheet23 as S23, all23 as A, render6 as R6
    from render2 import hexc
    loader = loader or load
    slots = slots or SLOTS
    def slot_of(sl):
        trees = []
        for s in reversed(SIZES):
            img, ox, oy = loader(sl[0], s)
            trees.append((img, ox, oy, S23.extents(img, ox, oy)))
        T = trees[0][3]
        x = -min(T['x0'], T['sx0'])
        feet = [x]
        for (_, _, _, a), (_, _, _, b) in zip(trees, trees[1:]):
            x = x + a['x1'] - b['x0'] + S23.GAP
            feet.append(x)
        Sx = trees[-1][3]
        return dict(slot=sl, trees=trees, feet=feet, width=feet[-1] + max(Sx['x1'], Sx['sx1']) + 1,
                    up=max(t[3]['up'] for t in trees), dn=max(t[3]['dn'] for t in trees),
                    left=feet[0] + T['x0'], right=feet[-1] + Sx['x1'])
    built = [slot_of(sl) for sl in slots]
    rows = []
    for g in dict.fromkeys(sl[5] for sl in slots):
        rows += S23.rows_of([b for b in built if b['slot'][5] == g], wmax)
    W = S23.SIDE * 2 + max(sum(s['width'] for s in r) + S23.SGAP * (len(r) - 1) for r in rows)
    y, placed, bands = S23.TOP, [], []
    for r in rows:
        y0 = y - S23.TOP // 2
        y += max(s['up'] for s in r)
        base = y
        rw = sum(s['width'] for s in r) + S23.SGAP * (len(r) - 1)
        x = S23.SIDE + (W - 2 * S23.SIDE - rw) // 2
        rdn = max(s['dn'] for s in r)
        for s in r:
            placed.append((s, x, base, rdn)); x += s['width'] + S23.SGAP
        y = base + rdn + S23.LABEL + 8
        bands.append((r[0]['slot'][5], y0, y - S23.TOP // 2 + 2))
    H = y + 4
    canvas = np.zeros((H, W, 3), np.uint8); canvas[:] = hexc(ground[0])
    shade_of = np.zeros((H, W), object); shade_of[:] = ground[1]
    for g, a, b in bands:                       # the hot-zone trees on their own grass
        if g in patch:
            canvas[max(0, a):b] = hexc(R6.GRASS); shade_of[max(0, a):b] = R6.GRASS_SHADE
    ks = np.array(hexc(KEY_S)); kg = np.array(hexc(KEY_G))
    jobs = []
    for s, x, base, _ in placed:
        for (img, ox, oy, e), fx in zip(s['trees'], s['feet']):
            jobs.append((base, x + fx, img, ox, oy))
    for base, fx, img, ox, oy in jobs:
        m = (img == ks).all(2)
        ys, xs = np.nonzero(m)
        Y, X = ys + int(round(base - oy)), xs + int(round(fx - ox))
        ok = (Y >= 0) & (Y < H) & (X >= 0) & (X < W)
        for yy, xx in zip(Y[ok], X[ok]): canvas[yy, xx] = hexc(shade_of[yy, xx])
    for base, fx, img, ox, oy in sorted(jobs, key=lambda j: j[0]):
        m = ~((img == ks).all(2) | (img == kg).all(2))
        ys, xs = np.nonzero(m)
        Y, X = ys + int(round(base - oy)), xs + int(round(fx - ox))
        ok = (Y >= 0) & (Y < H) & (X >= 0) & (X < W)
        canvas[Y[ok], X[ok]] = img[ys[ok], xs[ok]]
    big = Image.fromarray(canvas).resize((W * k, H * k), Image.NEAREST)
    d = ImageDraw.Draw(big)
    for s, x, base, rdn in placed:
        _, _, _, name, sub, _g = s['slot']
        cx = (x + (s['left'] + s['right']) / 2) * k
        ty = (base + rdn + 2) * k
        f1, f2 = S23.FONT(12 * k, True), S23.FONT(9 * k)
        w1 = d.textlength(name, font=f1); w2 = d.textlength(sub, font=f2)
        d.text((cx - w1 / 2, ty), name, font=f1, fill=(255, 255, 255), stroke_width=k, stroke_fill=(25, 35, 45))
        d.text((cx - w2 / 2, ty + 13 * k), sub, font=f2, fill=(235, 240, 245), stroke_width=k, stroke_fill=(25, 35, 45))
    if title:
        hdr = Image.new('RGB', (big.size[0], 22 * k), (250, 250, 250))
        ImageDraw.Draw(hdr).text((8, 4 * k), title, font=S23.FONT(11 * k), fill=(10, 10, 30))
        sh = Image.new('RGB', (big.size[0], big.size[1] + hdr.size[1]), (250, 250, 250))
        sh.paste(hdr, (0, 0)); sh.paste(big, (0, hdr.size[1])); big = sh
    big.save(out)
    return (W, H)


if __name__ == '__main__':
    if sys.argv[1] == 'render':
        os.makedirs(CACHE, exist_ok=True)
        names = sys.argv[2].split(',') if len(sys.argv) > 2 else [s[0] for s in SLOTS]
        jobs = [(n, s) for n in names for s in SIZES]
        jobs.sort(key=lambda j: -j[1])
        with Pool(4) as p:
            for out, dt in p.imap_unordered(render_one, jobs):
                print('%-40s %.1fs' % (os.path.basename(out), dt), flush=True)
    else:
        out = sys.argv[2]
        k = int(sys.argv[3]) if len(sys.argv) > 3 else 2
        wmax = int(sys.argv[4]) if len(sys.argv) > 4 else 1020
        title = ('Зима: у каждого вида толстое, среднее, тонкое. Дуб, липа, ива по два раза: голые и с сухой листвой '
                 '(в игре часть деревьев держит листья). Жаркий пояс без снега. ×%d' % k)
        print(sheet(out, k, wmax, title))
