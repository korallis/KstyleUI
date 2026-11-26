"""designs_hunter.py: the hunter's crest marks as layered relief: seven Aspects, six Stings, the two openings and Raptor Strike."""
import math

from relief import Emblem, blob, ellipse, poly, stroke, transform, mask_poly

D = {}


def design(fn):
    D[fn.__name__] = fn
    return fn


def leaf(x0, y0, x1, y1, w, bulge=0.45):
    """A feather or leaf from its base to its tip."""
    dx, dy = x1 - x0, y1 - y0
    ln = math.hypot(dx, dy)
    nx, ny = -dy / ln, dx / ln
    mx, my = x0 + dx * bulge, y0 + dy * bulge
    return blob([(x0, y0), (mx + nx * w, my + ny * w), (x1, y1), (mx - nx * w, my - ny * w)], 18)


@design
def Hawk():
    """Aspect of the Hawk: a hawk's head in profile, hooked beak, fierce brow, neck feathers."""
    e = Emblem("Hawk")
    # neck feathers first, back to front, so each overlaps the last
    for (x0, y0, x1, y1, w) in [
        (0.30, 0.50, 0.06, 0.74, 0.085), (0.34, 0.58, 0.10, 0.90, 0.09), (0.40, 0.62, 0.24, 0.98, 0.095),
        (0.46, 0.64, 0.40, 0.99, 0.095), (0.54, 0.62, 0.57, 0.95, 0.085),
    ]:
        e.add(leaf(x0, y0, x1, y1, w), h=0.55, r=0.035, base=0.2)
    head = blob([(0.50, 0.10), (0.63, 0.15), (0.72, 0.26), (0.71, 0.42), (0.66, 0.56), (0.60, 0.70), (0.44, 0.74),
                 (0.28, 0.66), (0.19, 0.48), (0.20, 0.30), (0.32, 0.15)])
    e.add(head, h=0.8, r=0.12, base=0.3)
    # second row of feathers lying on the neck
    for (x0, y0, x1, y1, w) in [(0.30, 0.40, 0.17, 0.62, 0.06), (0.36, 0.48, 0.26, 0.74, 0.065), (0.44, 0.52, 0.40, 0.80, 0.065),
                                (0.52, 0.52, 0.55, 0.78, 0.06)]:
        e.add(leaf(x0, y0, x1, y1, w), h=0.95, r=0.03, base=0.62)
    upper = blob([(0.64, 0.20), (0.78, 0.24), (0.90, 0.34), (0.955, 0.48), (0.925, 0.66), (0.885, 0.56), (0.82, 0.49),
                  (0.72, 0.47), (0.63, 0.45), (0.62, 0.32)], 18)
    lower = blob([(0.63, 0.47), (0.74, 0.50), (0.83, 0.535), (0.82, 0.59), (0.72, 0.60), (0.63, 0.56)], 16)
    e.add(lower, h=0.72, r=0.03, base=0.3)
    e.add(upper, h=1.0, r=0.06, base=0.4)
    # the cere and nostril
    e.cut(stroke([(0.655, 0.22), (0.675, 0.33), (0.655, 0.44)], 0.014), depth=0.2)
    e.cut(ellipse(0.735, 0.335, 0.022, 0.012, 20), depth=0.3)
    # the eye under a heavy brow
    e.cut(ellipse(0.535, 0.33, 0.062, 0.05, 12), depth=0.42, r=0.03)
    e.add(ellipse(0.54, 0.335, 0.03, 0.03), h=0.85, r=0.03, base=0.45)
    e.add(stroke([(0.36, 0.20), (0.50, 0.235), (0.635, 0.30)], 0.05, 0.022), h=1.05, r=0.02, base=0.7)
    # feather veins
    for (x0, y0, x1, y1) in [(0.30, 0.50, 0.09, 0.72), (0.34, 0.58, 0.12, 0.87), (0.40, 0.64, 0.26, 0.95), (0.46, 0.66, 0.41, 0.96)]:
        e.cut(stroke([(x0, y0), (x1, y1)], 0.012, 0.004), depth=0.16)
    return e.seat()


@design
def Monkey():
    """Aspect of the Monkey: a monkey's face, round ears, heart-shaped mask, wide muzzle."""
    e = Emblem("Monkey")
    for sx in (-1, 1):
        ear = ellipse(0.5 + sx * 0.36, 0.44, 0.13, 0.15)
        e.add(ear, h=0.6, r=0.05, base=0.25)
        e.cut(ellipse(0.5 + sx * 0.365, 0.44, 0.065, 0.085), depth=0.28, r=0.03)
    head = blob([(0.5, 0.08), (0.70, 0.14), (0.80, 0.34), (0.76, 0.56), (0.66, 0.68), (0.5, 0.72), (0.34, 0.68), (0.24, 0.56),
                 (0.20, 0.34), (0.30, 0.14)])
    e.add(head, h=0.75, r=0.12, base=0.3)
    # the hair tuft
    e.add(blob([(0.5, 0.02), (0.57, 0.10), (0.5, 0.17), (0.43, 0.10)]), h=0.85, r=0.03, base=0.5)
    # the face mask, heart-shaped, lower than the fur round it
    mask = blob([(0.5, 0.27), (0.60, 0.19), (0.71, 0.26), (0.72, 0.42), (0.63, 0.52), (0.5, 0.55), (0.37, 0.52), (0.28, 0.42),
                 (0.29, 0.26), (0.40, 0.19)])
    e.cut(mask, depth=0.2, r=0.03)
    muzzle = blob([(0.5, 0.50), (0.66, 0.54), (0.74, 0.70), (0.66, 0.88), (0.5, 0.93), (0.34, 0.88), (0.26, 0.70), (0.34, 0.54)])
    e.add(muzzle, h=1.0, r=0.1, base=0.5)
    for sx in (-1, 1):
        e.cut(ellipse(0.5 + sx * 0.115, 0.37, 0.058, 0.062), depth=0.3, r=0.03)
        e.add(ellipse(0.5 + sx * 0.115, 0.375, 0.032, 0.034), h=0.8, r=0.03, base=0.4)
        e.add(stroke([(0.5 + sx * 0.05, 0.285), (0.5 + sx * 0.13, 0.27), (0.5 + sx * 0.20, 0.30)], 0.03, 0.016), h=0.95, r=0.014, base=0.7)
        e.cut(ellipse(0.5 + sx * 0.035, 0.635, 0.018, 0.024, sx * 20), depth=0.35, r=0.012)
    e.cut(stroke([(0.37, 0.77), (0.44, 0.815), (0.5, 0.825), (0.56, 0.815), (0.63, 0.77)], 0.02), depth=0.38, r=0.012)
    e.cut(stroke([(0.5, 0.67), (0.5, 0.815)], 0.012), depth=0.2)
    return e.seat()


def cat_run(e, fat):
    """A cheetah at full stretch, running right; fat thickens the limbs, tail and neck so they survive at HUD size."""
    w = fat
    tail = stroke([(0.20, 0.44), (0.10, 0.40), (0.04, 0.30), (0.06, 0.20), (0.12, 0.16)], 0.05 * w, 0.03 * w)
    e.add(tail, h=0.6, r=0.02, base=0.3)
    far_hind = stroke([(0.26, 0.52), (0.17, 0.60), (0.07, 0.62), (0.01, 0.66)], 0.07 * w, 0.03 * w)
    far_fore = stroke([(0.66, 0.54), (0.78, 0.62), (0.88, 0.60), (0.95, 0.62)], 0.06 * w, 0.028 * w)
    e.add(far_hind, h=0.5, r=0.02, base=0.25)
    e.add(far_fore, h=0.5, r=0.02, base=0.25)
    body = blob([(0.20, 0.40), (0.34, 0.345), (0.50, 0.37), (0.64, 0.345), (0.74, 0.38), (0.76, 0.50), (0.66, 0.56), (0.52, 0.52),
                 (0.40, 0.50), (0.28, 0.56), (0.19, 0.50)], 16)
    e.add(body, h=0.85, r=0.07 * w, base=0.35)
    hind = stroke([(0.27, 0.48), (0.32, 0.62), (0.24, 0.70), (0.12, 0.76), (0.05, 0.82)], 0.105 * w, 0.03 * w)
    fore = stroke([(0.68, 0.48), (0.74, 0.62), (0.84, 0.72), (0.95, 0.76)], 0.085 * w, 0.03 * w)
    e.add(hind, h=0.95, r=0.03 * w, base=0.5)
    e.add(fore, h=0.95, r=0.028 * w, base=0.5)
    neck = stroke([(0.70, 0.40), (0.79, 0.33)], 0.12 * w, 0.10 * w)
    e.add(neck, h=0.9, r=0.04 * w, base=0.45)
    head = blob([(0.76, 0.24), (0.84, 0.21), (0.92, 0.25), (0.985, 0.32), (0.975, 0.37), (0.90, 0.39), (0.81, 0.37), (0.76, 0.32)], 14)
    e.add(head, h=1.0, r=0.045 * w, base=0.5)
    e.add(blob([(0.775, 0.245), (0.785, 0.155), (0.835, 0.215)], 10), h=0.95, r=0.015 * w, base=0.5)
    e.cut(ellipse(0.895, 0.285, 0.014 * w), depth=0.3, r=0.008)
    e.cut(stroke([(0.905, 0.30), (0.915, 0.345), (0.955, 0.365)], 0.009 * w), depth=0.22, r=0.006)
    for (x, y, r) in [(0.30, 0.42, 0.020), (0.37, 0.40, 0.017), (0.44, 0.425, 0.019), (0.51, 0.42, 0.017), (0.58, 0.405, 0.019),
                      (0.65, 0.42, 0.017), (0.34, 0.475, 0.016), (0.46, 0.475, 0.015), (0.61, 0.475, 0.016), (0.71, 0.455, 0.015),
                      (0.26, 0.47, 0.014), (0.535, 0.47, 0.013), (0.40, 0.445, 0.011)]:
        e.cut(ellipse(x, y, r * w), depth=0.22, r=0.01)
    return e


@design
def Cheetah():
    """Aspect of the Cheetah: a spotted cheetah at full stretch, limbs heavy enough to read small."""
    e = Emblem("Cheetah")
    cat_run(e, fat=1.9)
    return e.seat()


@design
def Pack():
    """Aspect of the Pack: three cats' faces set apart in a triangle, two above and a larger one below, each with pricked ears, open eyes and a nose."""
    e = Emblem("Pack")
    for (cx, cy, k, h) in ((0.22, 0.25, 0.42, 0.9), (0.78, 0.25, 0.42, 0.9), (0.50, 0.77, 0.50, 1.0)):
        def P(x, y, cx=cx, cy=cy, k=k):
            return (cx + x * k, cy + y * k)
        for side in (-1, 1):
            e.add(poly([P(side * 0.08, -0.26), P(side * 0.44, -0.74), P(side * 0.50, -0.02)]), h=0.8 * h, r=0.03, base=0.4 * h)
        e.add(blob([P(0, -0.36), P(0.34, -0.30), P(0.48, 0.0), P(0.30, 0.30), P(0, 0.42), P(-0.30, 0.30), P(-0.48, 0.0), P(-0.34, -0.30)]),
              h=0.95 * h, r=0.12 * k, base=0.4 * h)
        for side in (-1, 1):
            e.pierce(ellipse(*P(side * 0.20, -0.06), 0.11 * k, 0.075 * k, side * 25))
        e.pierce(poly([P(-0.09, 0.14), P(0.09, 0.14), P(0, 0.27)]))
    return e.seat()


@design
def Wild():
    """Aspect of the Wild: an oak leaf, lobed, with raised veins."""
    e = Emblem("Wild")
    pts = []
    # lobes down the right side, then mirrored up the left; the leaf leans a little
    right = [(0.50, 0.04), (0.60, 0.10), (0.585, 0.17), (0.70, 0.20), (0.66, 0.30), (0.79, 0.36), (0.71, 0.45), (0.82, 0.54),
             (0.71, 0.62), (0.76, 0.72), (0.63, 0.76), (0.60, 0.85), (0.53, 0.86)]
    pts = right + [(0.5, 0.86)] + [(1 - x, y) for x, y in reversed(right[1:])]
    body = blob(pts, 10)
    body = transform(body, rot=-12)
    e.add(body, h=0.7, r=0.07, base=0.3)
    stem = transform(stroke([(0.5, 0.10), (0.5, 0.86), (0.49, 0.98)], 0.022, 0.05), rot=-12)
    e.add(stem, h=1.0, r=0.018, base=0.62)
    for y, half in ((0.24, 0.13), (0.40, 0.20), (0.57, 0.22), (0.72, 0.15)):
        for sx in (-1, 1):
            vein = transform(stroke([(0.5, y + 0.06), (0.5 + sx * half * 0.55, y - 0.01), (0.5 + sx * half, y - 0.045)], 0.022, 0.008), rot=-12)
            e.add(vein, h=0.92, r=0.012, base=0.62)
    return e.seat()


@design
def Beast():
    """Aspect of the Beast: a great clawed paw, pads raised, four hooked claws."""
    e = Emblem("Beast")
    toes = [(0.20, 0.47, -24), (0.38, 0.33, -8), (0.60, 0.33, 8), (0.79, 0.47, 24)]
    for (x, y, a) in toes:
        ca = math.radians(a)
        tx, ty = x + math.sin(ca) * 0.30, y - math.cos(ca) * 0.30
        bx, by = x + math.sin(ca) * 0.04, y - math.cos(ca) * 0.04
        hook = 0.035 * (1 if a >= 0 else -1)
        claw = stroke([(bx, by), ((bx + tx) / 2 - hook * 0.4, (by + ty) / 2), (tx + hook, ty + 0.01)], 0.085, 0.006)
        e.add(claw, h=0.8, r=0.025, base=0.3)
    for (x, y, a) in toes:
        e.add(ellipse(x, y, 0.088, 0.115, a), h=0.95, r=0.06, base=0.45)
    pad = blob([(0.5, 0.52), (0.64, 0.56), (0.76, 0.70), (0.72, 0.87), (0.60, 0.93), (0.5, 0.89), (0.40, 0.93), (0.28, 0.87), (0.24, 0.70),
                (0.36, 0.56)])
    e.add(pad, h=1.0, r=0.1, base=0.45)
    return e.seat()


@design
def Viper():
    """Aspect of the Viper: a coiled viper, head reared, tongue out."""
    e = Emblem("Viper")
    # the coil: two loops of the body, the outer one behind
    def ring(cx, cy, rx, ry, a0, a1, w0, w1, n=40):
        return stroke([(cx + rx * math.cos(math.radians(a0 + (a1 - a0) * k / n)), cy + ry * math.sin(math.radians(a0 + (a1 - a0) * k / n)))
                       for k in range(n + 1)], w0, w1, smooth=False)
    e.add(ring(0.47, 0.72, 0.36, 0.17, -30, 310, 0.04, 0.13), h=0.6, r=0.05, base=0.28)
    e.add(ring(0.47, 0.62, 0.27, 0.135, 150, 500, 0.13, 0.13), h=0.8, r=0.055, base=0.4)
    # the neck rises from the coil in an S and the head strikes right
    neck = stroke([(0.30, 0.56), (0.26, 0.44), (0.34, 0.33), (0.47, 0.30), (0.55, 0.22), (0.58, 0.15)], 0.13, 0.10)
    e.add(neck, h=0.95, r=0.05, base=0.5)
    head = blob([(0.50, 0.09), (0.60, 0.04), (0.74, 0.06), (0.88, 0.13), (0.93, 0.19), (0.86, 0.24), (0.72, 0.25), (0.58, 0.23), (0.51, 0.17)], 14)
    e.add(head, h=1.0, r=0.06, base=0.55)
    e.cut(ellipse(0.71, 0.125, 0.026, 0.02, 15), depth=0.35, r=0.012)
    e.cut(stroke([(0.93, 0.195), (0.80, 0.205), (0.68, 0.215)], 0.012), depth=0.25, r=0.008)
    tongue = stroke([(0.92, 0.19), (0.975, 0.215)], 0.016, 0.012)
    e.add(tongue, h=0.5, r=0.008, base=0.3)
    for (x, y) in ((0.995, 0.19), (0.995, 0.25)):
        e.add(stroke([(0.972, 0.215), (x, y)], 0.012, 0.005), h=0.5, r=0.006, base=0.3)
    # belly scales along the neck
    for t in range(6):
        k = t / 5
        x = 0.285 + (0.50 - 0.285) * k
        y = 0.50 - 0.19 * k - 0.04 * math.sin(math.pi * k)
        e.cut(stroke([(x - 0.045, y + 0.02), (x + 0.04, y - 0.03)], 0.011), depth=0.13, r=0.008)
    return e.seat()


@design
def Serpent():
    """Serpent Sting: a serpent reared in an S, its broad head striking right with one long fang."""
    e = Emblem("Serpent")
    body = stroke([(0.34, 0.96), (0.66, 0.88), (0.74, 0.70), (0.46, 0.58), (0.26, 0.42), (0.36, 0.24), (0.56, 0.20)], 0.15, 0.19)
    e.add(body, h=0.75, r=0.06, base=0.3)
    jaw = blob([(0.56, 0.30), (0.72, 0.34), (0.88, 0.46), (0.84, 0.53), (0.68, 0.46), (0.56, 0.40)], 12)
    e.add(jaw, h=0.8, r=0.03, base=0.4)
    skull = blob([(0.46, 0.14), (0.62, 0.04), (0.82, 0.06), (0.98, 0.18), (0.99, 0.28), (0.84, 0.31), (0.66, 0.30), (0.50, 0.30)], 14)
    e.add(skull, h=1.0, r=0.07, base=0.5)
    e.add(stroke([(0.90, 0.29), (0.885, 0.40), (0.86, 0.47)], 0.07, 0.006), h=0.95, r=0.016, base=0.55)
    e.cut(ellipse(0.74, 0.15, 0.04, 0.028, 15), depth=0.35, r=0.014)
    return e.seat()


@design
def ViperSting():
    """Viper Sting: a viper's head in profile, jaws thrown wide open, one long fang, a single tapered tongue."""
    e = Emblem("ViperSting")
    e.add(stroke([(0.02, 0.98), (0.10, 0.62)], 0.30, 0.30, smooth=False), h=0.7, r=0.07, base=0.3)
    lower = blob([(0.06, 0.62), (0.30, 0.62), (0.56, 0.74), (0.86, 0.96), (0.80, 1.02), (0.50, 0.94), (0.24, 0.86), (0.06, 0.80)], 14)
    e.add(lower, h=0.85, r=0.05, base=0.4)
    upper = blob([(0.02, 0.56), (0.06, 0.26), (0.26, 0.08), (0.54, 0.04), (0.82, 0.12), (0.99, 0.26), (0.97, 0.36), (0.74, 0.38),
                  (0.50, 0.42), (0.32, 0.56), (0.14, 0.68)], 14)
    e.add(upper, h=1.0, r=0.09, base=0.45)
    e.add(stroke([(0.84, 0.34), (0.80, 0.56), (0.70, 0.72)], 0.13, 0.01), h=1.0, r=0.03, base=0.55)
    e.add(stroke([(0.34, 0.66), (0.56, 0.60), (0.70, 0.50)], 0.05, 0.03), h=0.6, r=0.014, base=0.35)
    e.pierce(ellipse(0.50, 0.21, 0.085, 0.06, 15))
    return e.seat()


@design
def Scorpid():
    """Scorpid Sting: a scorpion from the side, a long body on short legs, its heavy tail arched high over its back with the barb hanging in front, an open two-pronged pincer reaching forward."""
    e = Emblem("Scorpid")
    for x in (0.28, 0.44, 0.60):
        e.add(stroke([(x, 0.78), (x - 0.05, 0.96)], 0.10, 0.07, smooth=False), h=0.6, r=0.02, base=0.3)
    e.add(blob([(0.12, 0.70), (0.28, 0.58), (0.54, 0.58), (0.74, 0.66), (0.76, 0.78), (0.56, 0.86), (0.28, 0.86), (0.12, 0.82)], 14),
          h=0.9, r=0.08, base=0.4)
    e.add(stroke([(0.18, 0.70), (0.09, 0.46), (0.17, 0.21), (0.40, 0.10), (0.62, 0.15), (0.72, 0.28)], 0.18, 0.15), h=0.95, r=0.05, base=0.45)
    e.add(stroke([(0.72, 0.26), (0.72, 0.38), (0.60, 0.48)], 0.17, 0.01), h=1.0, r=0.03, base=0.55)
    e.add(stroke([(0.72, 0.72), (0.84, 0.68)], 0.12, 0.12, smooth=False), h=0.8, r=0.03, base=0.4)
    for tip in ((0.98, 0.52), (0.98, 0.84)):
        e.add(stroke([(0.82, 0.68), tip], 0.14, 0.04, smooth=False), h=0.95, r=0.03, base=0.45)
    return e.seat()


@design
def Wyvern():
    """Wyvern Sting: a wyvern seen from the front, bat wings raised high and open with long fingers and deep hollows between them, a small head and a barbed tail."""
    e = Emblem("Wyvern")
    for side in (-1, 1):
        def X(x, side=side):
            return 0.5 + side * x
        wrist = (X(0.30), 0.06)
        tips = ((X(0.50), 0.50), (X(0.36), 0.70), (X(0.19), 0.62))
        web = [wrist, tips[0], (X(0.38), 0.34), tips[1], (X(0.27), 0.38), tips[2], (X(0.17), 0.34), (X(0.07), 0.42)]
        e.add(mask_poly(web), h=0.6, r=0.04, base=0.3)
        e.add(stroke([(X(0.06), 0.44), wrist], 0.12, 0.10, smooth=False), h=1.0, r=0.03, base=0.5)
        for tip in tips:
            e.add(stroke([wrist, tip], 0.10, 0.05, smooth=False), h=0.9, r=0.02, base=0.45)
    e.add(ellipse(0.5, 0.50, 0.085, 0.20), h=0.9, r=0.05, base=0.4)
    e.add(blob([(0.5, 0.12), (0.58, 0.20), (0.56, 0.32), (0.5, 0.37), (0.44, 0.32), (0.42, 0.20)], 12), h=1.0, r=0.05, base=0.5)
    e.add(poly([(0.50, 1.00), (0.39, 0.84), (0.47, 0.86), (0.47, 0.66), (0.53, 0.66), (0.53, 0.86), (0.61, 0.84)]), h=0.95, r=0.02, base=0.5)
    return e.seat()


@design
def Lacerate():
    """Lacerate: three deep claw rips, torn edges, a drop of blood."""
    e = Emblem("Lacerate")
    for k, dx in enumerate((-0.25, 0.0, 0.25)):
        rip = blob([(0.62 + dx, 0.04), (0.70 + dx, 0.22), (0.62 + dx, 0.48), (0.50 + dx, 0.74), (0.36 + dx, 0.94), (0.40 + dx, 0.70),
                    (0.48 + dx, 0.44), (0.54 + dx, 0.20)], 12)
        e.add(rip, h=0.9, r=0.045, base=0.3)
        e.cut(stroke([(0.62 + dx, 0.12), (0.57 + dx, 0.44), (0.42 + dx, 0.84)], 0.022, 0.006), depth=0.3, r=0.012)
    e.add(blob([(0.86, 0.72), (0.93, 0.84), (0.86, 0.94), (0.79, 0.84)], 14), h=1.0, r=0.06, base=0.45)
    return e.seat()


@design
def BlackArrow():
    """Black Arrow: an arrow flying down to the right, a thick shaft, a broad barbed head and a short fletching."""
    e = Emblem("BlackArrow")
    e.add(stroke([(0.5, 0.08), (0.5, 0.70)], 0.11), h=0.75, r=0.04, base=0.4)
    head = poly([(0.5, 1.02), (0.83, 0.52), (0.62, 0.64), (0.5, 0.58), (0.38, 0.64), (0.17, 0.52)])
    e.add(head, h=1.0, r=0.10, base=0.45)
    for sx in (-1, 1):
        for y in (0.04, 0.15):
            vane = poly([(0.5, y + 0.06), (0.5 + sx * 0.15, y - 0.04), (0.5 + sx * 0.15, y + 0.05), (0.5, y + 0.15)])
            e.add(vane, h=0.8, r=0.03, base=0.4)
    return e.turn(-45).seat()


@design
def Counter():
    """Counterattack: two crossed swords, points up, each a long tapering blade over a short guard, a grip and a round pommel."""
    e = Emblem("Counter")
    for k, rot in ((0.85, -40), (1.0, 40)):
        blade = poly([(0.50, -0.02), (0.575, 0.12), (0.575, 0.70), (0.425, 0.70), (0.425, 0.12)])
        guard = stroke([(0.33, 0.72), (0.67, 0.72)], 0.075, smooth=False)
        grip = stroke([(0.50, 0.72), (0.50, 0.93)], 0.075, smooth=False)
        pommel = ellipse(0.50, 0.96, 0.07)
        for mask, h, r, base in ((blade, 1.0, 0.05, 0.45), (grip, 0.8, 0.03, 0.4), (guard, 0.95, 0.03, 0.5), (pommel, 1.0, 0.05, 0.5)):
            e.add(transform(mask, rot=rot), h=h * k, r=r, base=base * k)
    return e.fit()


@design
def Mongoose():
    """Mongoose Bite: a whole mongoose lunging to the right, long low body, short legs, a long thick tail, jaws open."""
    e = Emblem("Mongoose")
    e.add(stroke([(0.34, 0.60), (0.18, 0.66), (0.06, 0.56), (0.02, 0.38), (0.10, 0.24)], 0.14, 0.09), h=0.7, r=0.04, base=0.3)
    for (a, b) in (((0.36, 0.66), (0.30, 0.90)), ((0.62, 0.62), (0.70, 0.86))):
        e.add(stroke([a, b, (b[0] + 0.09, b[1] + 0.02)], 0.11, 0.07, smooth=False), h=0.7, r=0.03, base=0.3)
    e.add(stroke([(0.34, 0.58), (0.50, 0.52), (0.66, 0.50), (0.78, 0.40)], 0.24, 0.17), h=0.9, r=0.08, base=0.4)
    e.add(stroke([(0.66, 0.56), (0.80, 0.70), (0.92, 0.70)], 0.10, 0.06, smooth=False), h=0.95, r=0.03, base=0.5)
    skull = blob([(0.70, 0.36), (0.76, 0.24), (0.88, 0.22), (1.00, 0.26), (1.00, 0.33), (0.90, 0.36), (0.84, 0.44), (0.74, 0.46)], 14)
    e.add(skull, h=1.0, r=0.05, base=0.5)
    e.add(stroke([(0.82, 0.44), (0.96, 0.50)], 0.07, 0.03, smooth=False), h=0.9, r=0.02, base=0.5)
    e.add(ellipse(0.74, 0.21, 0.05, 0.04), h=1.05, r=0.02, base=0.7)
    e.pierce(ellipse(0.87, 0.285, 0.022))
    return e.fit()


@design
def Raptor():
    """Raptor Strike: a bird of prey's foot striking down from the upper left, a long shank, three heavy toes reaching forward and a short spur behind, each ending in a hooked claw."""
    e = Emblem("Raptor")
    e.add(stroke([(0.50, -0.16), (0.50, 0.46)], 0.20, 0.22, smooth=False), h=0.8, r=0.07, base=0.35)
    for (knuckle, tip, hook, w) in (((0.24, 0.68), (0.14, 0.86), (0.20, 1.02), 0.17), ((0.50, 0.78), (0.50, 0.94), (0.44, 1.10), 0.17),
                                    ((0.76, 0.68), (0.86, 0.86), (0.80, 1.02), 0.17), ((0.70, 0.34), (0.82, 0.32), (0.88, 0.46), 0.13)):
        e.add(stroke([(0.50, 0.46), knuckle, tip], w, w * 0.8), h=0.9, r=0.05, base=0.4)
        e.add(stroke([tip, hook], w * 0.8, 0.012, smooth=False), h=1.0, r=0.03, base=0.5)
    e.add(ellipse(0.50, 0.46, 0.15, 0.13), h=0.95, r=0.06, base=0.45)
    return e.turn(-35).fit()
