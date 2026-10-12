import os, math, random
from lib import *

OUT = 'out'
os.makedirs(OUT, exist_ok=True)

OL = '#1d1a2b'
GOLD = '#ffd21f'
ORANGE = '#ff8a1f'
SKIN = '#f2c29b'

# ───────────────────────── 1. unlock burst (one-shot) ─────────────────────────
def unlock_burst():
    OP = 42
    layers = []
    idx = 1
    cx = [200, 200]
    # white flash
    layers.append(layer([group([ellipse(120), fill('#ffffff')], 'flash',
                               s=A([(0, [20, 20]), (8, [130, 130]), (14, [160, 160])]),
                               o=A([(0, 90), (14, 0)]))], 'flash', idx, OP, p=cx)); idx += 1
    # sparkles
    sp = []
    for i in range(8):
        ang = math.radians(i * 45 + 20)
        rad = 128 + (i % 2) * 22
        x, y = math.cos(ang) * rad, math.sin(ang) * rad
        t0 = 4 + (i % 4) * 2
        sp.append(group([star(4, 18 if i % 2 == 0 else 13, 5), fill('#ffffff' if i % 2 else GOLD), stroke(OL, 3)],
                        f'sp{i}', p=[x, y],
                        s=A([(t0, [0, 0]), (t0 + 8, [120, 120]), (t0 + 20, [0, 0])]),
                        r=A([(t0, 0), (t0 + 20, 120)])))
    layers.append(layer(sp, 'sparkles', idx, OP, p=cx)); idx += 1
    # rays
    rays = []
    for i in range(12):
        col = GOLD if i % 2 == 0 else '#ff9d2e'
        inner = group([rrect(14, 44 if i % 2 == 0 else 30, 6), fill(col), stroke(OL, 3)], f'ray{i}',
                      p=A([(2, [0, -62]), (26, [0, -170])]),
                      o=A([(2, 0), (5, 100), (18, 100), (30, 0)]))
        rays.append(group([inner], f'rayrot{i}', r=i * 30))
    layers.append(layer(rays, 'rays', idx, OP, p=cx)); idx += 1
    # rings
    layers.append(layer([group([ellipse(100), stroke('#ffffff', 8)], 'ring2',
                               s=A([(6, [30, 30]), (32, [210, 210])]),
                               o=A([(6, 0), (9, 90), (32, 0)]))], 'ring2', idx, OP, p=cx)); idx += 1
    layers.append(layer([group([ellipse(100), stroke(GOLD, 16)], 'ring1',
                               s=A([(0, [30, 30]), (26, [190, 190])]),
                               o=A([(0, 100), (12, 90), (26, 0)]))], 'ring1', idx, OP, p=cx)); idx += 1
    return comp('unlock_burst', 400, 400, OP, layers)

# ───────────────────────── 2. confetti + stars (one-shot) ─────────────────────────
def confetti():
    OP = 120
    rnd = random.Random(7)
    cols = ['#ff4d6d', '#34c8ff', '#5ed67b', '#ffd21f', '#b48cff', '#ff8a1f', '#ffffff']
    items = []
    for i in range(46):
        x0 = rnd.uniform(15, 385)
        d = rnd.randint(0, 46)
        sway = rnd.uniform(-45, 45)
        x1 = x0 + rnd.uniform(-70, 70)
        fall_end = min(OP, d + rnd.randint(56, 74))
        kind = i % 6  # 0..3 rect, 4 circle, 5 star
        col = cols[i % len(cols)]
        p = A([(0, [x0, -30]), (d, [x0, -30]), (d + (fall_end - d) * 0.5, [x0 + sway, 330]), (fall_end, [x1, 660]), (OP, [x1, 660])], linear=True)
        rot = A([(0, 0), (OP, rnd.choice([-1, 1]) * rnd.uniform(500, 1100))], linear=True)
        if kind <= 3:
            per = rnd.choice([10, 12, 14])
            sc_keys = [(0, [100, 100])]
            t = 0
            flip = True
            while t < OP:
                t += per
                sc_keys.append((min(t, OP), [100, 20 if flip else 100]))
                flip = not flip
            shp = [rrect(rnd.randint(9, 13), rnd.randint(15, 21), 3), fill(col), stroke(OL, 2.5)]
            items.append(group(shp, f'c{i}', p=p, r=rot, s=A(sc_keys, linear=True)))
        elif kind == 4:
            items.append(group([ellipse(rnd.randint(10, 14)), fill(col), stroke(OL, 2.5)], f'c{i}', p=p, r=rot))
        else:
            sz = rnd.uniform(13, 19)
            items.append(group([star(5, sz, sz * 0.45), fill(GOLD), stroke(OL, 3)], f'c{i}', p=p, r=rot))
    # a few big stars popping near the top for a "stars" feel
    pops = []
    for i, (x, y, t0) in enumerate([(70, 120, 2), (330, 150, 6), (200, 90, 10)]):
        pops.append(group([star(5, 26, 11), fill(GOLD), stroke(OL, 4)], f'pop{i}', p=[x, y],
                          s=A([(t0, [0, 0]), (t0 + 8, [130, 130]), (t0 + 14, [100, 100]), (t0 + 34, [0, 0])]),
                          r=A([(t0, -25), (t0 + 34, 25)])))
    return comp('confetti', 400, 600, OP, [layer(pops, 'stars', 1, OP), layer(items, 'confetti', 2, OP)])

# ───────────────────────── 3. level-up burst (loop) ─────────────────────────
def level_burst():
    OP = 90
    c = [150, 150]
    layers = []
    layers.append(layer([group([ellipse(150), stroke('#ffffff', 6)], 'ring',
                               s=A([(0, [70, 70]), (44, [150, 150]), (45, [70, 70]), (89, [150, 150])], linear=True),
                               o=A([(0, 90), (44, 0), (45, 90), (89, 0)], linear=True))], 'ring', 1, OP, p=c))
    layers.append(layer([group([ellipse(190), fill(GOLD, 38)], 'glow',
                               s=A([(0, [88, 88]), (45, [106, 106]), (90, [88, 88])]))], 'glow', 2, OP, p=c))
    layers.append(layer([group([star(8, 112, 30, polygon=False), fill('#ffffff', 40)], 'rays2',
                               r=A([(0, 0), (90, -360)], linear=True))], 'rays2', 3, OP, p=c))
    layers.append(layer([group([star(12, 142, 40), fill(GOLD, 48)], 'rays1',
                               r=A([(0, 0), (90, 360)], linear=True))], 'rays1', 4, OP, p=c))
    return comp('level_burst', 300, 300, OP, layers)

# ───────────────────────── 4. coin spin (loop) ─────────────────────────
def coin_spin():
    OP = 48
    D = '#8a5a00'
    face = group([
        ellipse(140), fill('#ffcc33'), stroke(OL, 8)], 'face')
    ring = group([ellipse(104), stroke('#f0a500', 7)], 'ring')
    bar = group([rrect(18, 52, 7), fill('#f0a500'), stroke(D, 4)], 'bar')
    shine = group([rrect(14, 30, 7, p=[-36, -26]), fill('#ffffff', 70)], 'shine', r=-35)
    coin = group([shine, bar, ring, face], 'coin',
                 s=A([(0, [100, 100]), (12, [62, 100]), (24, [7, 100]), (36, [62, 100]), (48, [100, 100])]),
                 p=A([(0, [0, 0]), (24, [0, -9]), (48, [0, 0])]))
    spark = group([star(4, 20, 6), fill('#ffffff'), stroke(OL, 3)], 'spark', p=[62, -62],
                  s=A([(0, [0, 0]), (16, [0, 0]), (24, [110, 110]), (34, [0, 0]), (48, [0, 0])]),
                  r=A([(16, 0), (34, 90)]))
    return comp('coin_spin', 200, 200, OP, [layer([spark], 'spark', 1, OP, p=[100, 100]),
                                            layer([coin], 'coin', 2, OP, p=[100, 108])])

# ───────────────────────── 5. gem pop (one-shot) ─────────────────────────
def gem_pop():
    OP = 46
    gem_pts = [(-26, -40), (26, -40), (48, -8), (0, 54), (-48, -8)]
    body = group([path(gem_pts), fill('#34c8ff'), stroke(OL, 7)], 'body')
    facet_l = group([path([(-26, -40), (-10, -8), (-48, -8)]), fill('#8fe3ff')], 'fl')
    facet_t = group([path([(-26, -40), (26, -40), (10, -8), (-10, -8)]), fill('#bff1ff')], 'ft')
    facet_r = group([path([(26, -40), (48, -8), (10, -8)]), fill('#1fa6e0')], 'fr')
    facet_b = group([path([(-10, -8), (10, -8), (0, 54)]), fill('#2ab8f2')], 'fb')
    lines = group([path([(-48, -8), (48, -8)], closed=False), stroke(OL, 4)], 'ln')
    shine = group([rrect(9, 18, 4, p=[-24, -26]), fill('#ffffff', 85)], 'sh', r=25)
    gem = group([shine, lines, facet_t, facet_l, facet_r, facet_b, body], 'gem',
                s=A([(0, [0, 0]), (10, [128, 128]), (16, [94, 94]), (22, [104, 104]), (28, [100, 100])]),
                r=A([(0, -14), (10, 7), (18, -4), (28, 0)]))
    sp = []
    for i in range(6):
        ang = math.radians(i * 60 + 15)
        rad = 86
        sp.append(group([star(4, 15, 5), fill('#ffffff' if i % 2 else '#8fe3ff'), stroke(OL, 3)], f'sp{i}',
                        p=A([(8, [math.cos(ang) * 40, math.sin(ang) * 40]), (34, [math.cos(ang) * rad, math.sin(ang) * rad])]),
                        s=A([(8, [0, 0]), (14, [110, 110]), (34, [0, 0])]),
                        r=A([(8, 0), (34, 100)])))
    ring = group([ellipse(100), stroke('#8fe3ff', 7)], 'ring',
                 s=A([(6, [30, 30]), (30, [170, 170])]), o=A([(6, 0), (9, 90), (30, 0)]))
    return comp('gem_pop', 200, 200, OP, [layer(sp, 'sparkles', 1, OP, p=[100, 100]),
                                          layer([gem], 'gem', 2, OP, p=[100, 100]),
                                          layer([ring], 'ring', 3, OP, p=[100, 100])])

# ───────────────────────── 6. running hero loader (loop) ─────────────────────────
def run_loader():
    OP = 24
    ORG, ORGD = '#ff8a1f', '#d96a00'

    def limb(w, h, color, rot_keys, pos, shoe=False, name='limb'):
        shapes = [group([rrect(w, h, w / 2.2, p=[0, h / 2 - 2]), fill(color), stroke(OL, 5)], name + '_shape')]
        if shoe:
            shapes.insert(0, group([rrect(26, 13, 6, p=[5, h - 2]), fill('#ffffff'), stroke(OL, 5)], name + '_shoe'))
            shapes.insert(0, group([rrect(26, 5, 2, p=[5, h + 2]), fill('#e5484d')], name + '_sole'))
        return group(shapes, name, p=pos, r=A(rot_keys))

    k_a = [(0, 42), (12, -42), (24, 42)]
    k_b = [(0, -42), (12, 42), (24, -42)]
    # arms swing opposite to the leg on the same side
    back_leg = limb(15, 32, SKIN, k_a, [-4, 30], True, 'bleg')
    front_leg = limb(15, 32, SKIN, k_b, [6, 30], True, 'fleg')
    back_arm = limb(11, 22, ORGD, k_b, [-6, 8], False, 'barm')
    front_arm = limb(11, 22, ORGD, k_a, [6, 8], False, 'farm')
    hand_b = None
    body = group([ellipse(66, 76), fill(ORG), stroke(OL, 6)], 'torso')
    belly = group([ellipse(30, 38, p=[-8, 8]), fill('#ffffff', 30)], 'belly')
    eye = group([ellipse(15, 18, p=[17, -12]), fill('#ffffff'), stroke(OL, 3)], 'eye')
    pupil = group([ellipse(7, 9, p=[20, -11]), fill(OL)], 'pupil')
    band = group([rrect(64, 11, 4, p=[0, -26]), fill('#e5484d'), stroke(OL, 4)], 'band')
    tail = group([path([(-30, -26), (-52, -34), (-48, -22), (-56, -14), (-30, -20)]), fill('#e5484d'), stroke(OL, 3)], 'tail',
                 r=A([(0, 0), (6, 12), (12, 0), (18, 12), (24, 0)]), p=[0, 0])
    mouth = group([path([(14, 0), (22, 2), (14, 5)], closed=False), stroke(OL, 3)], 'mouth')
    bounce = A([(0, [0, 0]), (6, [0, -9]), (12, [0, 0]), (18, [0, -9]), (24, [0, 0])])
    hero = group([mouth, pupil, eye, front_arm, front_leg, tail, band, belly, body, back_leg, back_arm], 'hero', p=bounce)
    shadow = group([ellipse(72, 14), fill('#000000', 35)], 'shadow',
                   s=A([(0, [100, 100]), (6, [82, 82]), (12, [100, 100]), (18, [82, 82]), (24, [100, 100])]))
    speed = []
    for i, y in enumerate([-18, 4, 26]):
        speed.append(group([rrect(26 - i * 4, 5, 2.5), fill('#ffffff', 75)], f'sl{i}',
                           p=A([(0, [-62, y]), (12, [-92, y]), (24, [-62, y])], linear=True),
                           o=A([(0, 70), (12, 15), (24, 70)], linear=True)))
    return comp('run_loader', 240, 240, OP, [
        layer(speed, 'speed', 1, OP, p=[120, 112]),
        layer([hero], 'hero', 2, OP, p=[120, 112]),
        layer([shadow], 'shadow', 3, OP, p=[120, 190])])

# ───────────────────────── 7. pointing hand (loop) ─────────────────────────
def pointing_hand():
    OP = 48
    ol = stroke(OL, 5)
    finger = group([rrect(21, 66, 10.5, p=[0, -30]), fill(SKIN), ol], 'finger')
    palm = group([rrect(60, 52, 15, p=[8, 22]), fill(SKIN), ol], 'palm')
    knuckles = []
    for i, x in enumerate([14, 27, 40]):
        knuckles.append(group([ellipse(15, 19, p=[x, -2 + i * 2]), fill(SKIN), ol], f'k{i}'))
    thumb = group([rrect(17, 34, 8.5, p=[-24, 20]), fill(SKIN), ol], 'thumb', r=24)
    cuff = group([rrect(62, 16, 5, p=[8, 52]), fill('#2e6be6'), ol], 'cuff')
    hand = group([cuff, thumb, palm] + knuckles[::-1] + [finger], 'hand',
                 p=A([(0, [0, 0]), (10, [0, -20]), (18, [0, 0]), (48, [0, 0])]),
                 s=A([(0, [100, 100]), (10, [94, 94]), (18, [100, 100]), (48, [100, 100])]))
    ripple = group([ellipse(40), stroke('#ffffff', 6)], 'ripple', p=[0, -86],
                   s=A([(8, [20, 20]), (30, [150, 150])]), o=A([(8, 0), (11, 90), (30, 0)]))
    ripple2 = group([ellipse(40), stroke(GOLD, 6)], 'ripple2', p=[0, -86],
                    s=A([(14, [20, 20]), (38, [150, 150])]), o=A([(14, 0), (17, 80), (38, 0)]))
    return comp('pointing_hand', 200, 200, OP, [
        layer([ripple, ripple2], 'ripple', 1, OP, p=[100, 120]),
        layer([hand], 'hand', 2, OP, p=[100, 120])])

# ───────────────────────── 8. bouncing arrow (loop) ─────────────────────────
def arrow_bounce():
    OP = 30
    pts = [(0, 52), (-44, 4), (-19, 4), (-19, -52), (19, -52), (19, 4), (44, 4)]
    arrow = group([path(pts), fill(GOLD), stroke(OL, 7)], 'arrow',
                  p=A([(0, [0, -10]), (15, [0, 14]), (30, [0, -10])]),
                  s=A([(0, [100, 100]), (15, [106, 94]), (30, [100, 100])]))
    shine = group([rrect(8, 34, 4, p=[-9, -26]), fill('#ffffff', 70)], 'shine',
                  p=A([(0, [0, -10]), (15, [0, 14]), (30, [0, -10])]))
    return comp('arrow_bounce', 200, 200, OP, [layer([shine], 'shine', 1, OP, p=[100, 100]),
                                               layer([arrow], 'arrow', 2, OP, p=[100, 100])])

ALL = {
    'unlock_burst': unlock_burst, 'confetti': confetti, 'level_burst': level_burst,
    'coin_spin': coin_spin, 'gem_pop': gem_pop, 'run_loader': run_loader,
    'pointing_hand': pointing_hand, 'arrow_bounce': arrow_bounce,
}

if __name__ == '__main__':
    for n, f in ALL.items():
        c = f()
        save(c, f'{OUT}/{n}.json')
        print(n, c['w'], c['h'], c['op'], os.path.getsize(f'{OUT}/{n}.json'), 'bytes')
