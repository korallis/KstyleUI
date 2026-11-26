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
    """Aspect of the Pack: three cats' faces together, one in front of two."""
    e = Emblem("Pack")
    for (cx, cy, k, h) in ((0.23, 0.30, 0.44, 0.8), (0.77, 0.30, 0.44, 0.8), (0.50, 0.74, 0.56, 1.0)):
        def P(x, y, cx=cx, cy=cy, k=k):
            return (cx + x * k, cy + y * k)
        for side in (-1, 1):
            e.add(poly([P(side * 0.14, -0.30), P(side * 0.46, -0.62), P(side * 0.50, -0.06)]), h=0.8 * h, r=0.03, base=0.4 * h)
        e.add(ellipse(cx, cy, 0.46 * k, 0.40 * k), h=0.95 * h, r=0.12 * k, base=0.4 * h)
        for side in (-1, 1):
            e.cut(ellipse(*P(side * 0.19, -0.06), 0.085 * k, 0.05 * k, side * 20), depth=0.4 * h, r=0.012)
        e.cut(poly([P(-0.07, 0.12), P(0.07, 0.12), P(0, 0.22)]), depth=0.35 * h, r=0.01)
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
    """Viper Sting: a viper's two long fangs curving in toward each other, a drop of venom falling between their tips."""
    e = Emblem("ViperSting")
    for side in (-1, 1):
        fang = stroke([(0.5 + side * 0.30, 0.06), (0.5 + side * 0.36, 0.34), (0.5 + side * 0.28, 0.60), (0.5 + side * 0.12, 0.80)], 0.26, 0.008)
        e.add(fang, h=1.0, r=0.05, base=0.7)
    x, y = 0.5, 0.84
    drop = blob([(x, y - 0.20), (x + 0.10, y - 0.01), (x + 0.07, y + 0.11), (x, y + 0.14), (x - 0.07, y + 0.11), (x - 0.10, y - 0.01)], 14)
    e.add(drop, h=1.0, r=0.06, base=0.45)
    return e.seat()


@design
def Scorpid():
    """Scorpid Sting: a scorpion in few heavy parts: two open pincers, a body and a tail arched over it to the barb."""
    e = Emblem("Scorpid")
    for sy in (-1, 1):
        arm = stroke([(0.60, 0.70 + sy * 0.06), (0.72, 0.70 + sy * 0.18), (0.82, 0.70 + sy * 0.19)], 0.09, 0.08)
        e.add(arm, h=0.7, r=0.03, base=0.35)
        claw = blob([(0.78, 0.70 + sy * 0.28), (0.92, 0.70 + sy * 0.30), (1.02, 0.70 + sy * 0.14), (0.94, 0.70 + sy * 0.03), (0.91, 0.70 + sy * 0.14),
                     (0.82, 0.70 + sy * 0.12)], 10)
        e.add(claw, h=0.9, r=0.045, base=0.45)
    body = blob([(0.24, 0.70), (0.34, 0.57), (0.56, 0.55), (0.70, 0.62), (0.74, 0.70), (0.70, 0.78), (0.56, 0.85), (0.34, 0.83)], 14)
    e.add(body, h=0.85, r=0.09, base=0.4)
    for x in (0.40, 0.52):
        e.cut(stroke([(x, 0.59), (x - 0.01, 0.81)], 0.014), depth=0.14, r=0.008)
    tail = [(0.22, 0.68, 0.11), (0.10, 0.54, 0.10), (0.10, 0.36, 0.095), (0.21, 0.21, 0.09), (0.38, 0.15, 0.085)]
    for (x, y, r) in tail:
        e.add(ellipse(x, y, r), h=0.95, r=r * 0.8, base=0.45)
    e.add(ellipse(0.53, 0.20, 0.09, 0.08, 30), h=1.0, r=0.05, base=0.5)
    e.add(stroke([(0.57, 0.22), (0.68, 0.30), (0.66, 0.46)], 0.09, 0.006), h=1.0, r=0.02, base=0.55)
    return e.seat()


@design
def Wyvern():
    """Wyvern Sting: a wyvern seen from the front, bat wings spread, horned head and a barbed tail."""
    e = Emblem("Wyvern")
    for side in (-1, 1):
        def X(x, side=side):
            return 0.5 + side * x
        web = [(X(0.06), 0.34), (X(0.24), 0.12), (X(0.47), 0.10), (X(0.44), 0.40), (X(0.36), 0.33), (X(0.30), 0.56), (X(0.21), 0.44),
               (X(0.12), 0.62), (X(0.06), 0.50)]
        e.add(mask_poly(web), h=0.5, r=0.03, base=0.22)
        e.add(stroke([(X(0.05), 0.36), (X(0.24), 0.13), (X(0.47), 0.10)], 0.11, 0.06), h=1.0, r=0.03, base=0.5)
        for tip in ((0.44, 0.40), (0.30, 0.56), (0.12, 0.62)):
            e.add(stroke([(X(0.24), 0.14), (X(tip[0]), tip[1])], 0.07, 0.03, smooth=False), h=0.85, r=0.014, base=0.45)
        e.add(stroke([(X(0.045), 0.17), (X(0.10), 0.03)], 0.05, 0.008, smooth=False), h=1.0, r=0.014, base=0.5)
    e.add(ellipse(0.5, 0.42, 0.11, 0.19), h=0.9, r=0.06, base=0.4)
    e.add(blob([(0.5, 0.10), (0.585, 0.17), (0.56, 0.30), (0.5, 0.35), (0.44, 0.30), (0.415, 0.17)], 12), h=1.0, r=0.05, base=0.5)
    e.add(stroke([(0.5, 0.56), (0.47, 0.72), (0.55, 0.84), (0.50, 0.93)], 0.10, 0.05), h=0.9, r=0.02, base=0.45)
    e.add(poly([(0.50, 1.04), (0.37, 0.87), (0.63, 0.87)]), h=1.0, r=0.02, base=0.5)
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
    """Black Arrow: a broadhead arrow flying down, barbed, fletched."""
    e = Emblem("BlackArrow")
    e.add(stroke([(0.5, 0.10), (0.5, 0.74)], 0.06), h=0.7, r=0.028, base=0.35)
    head = poly([(0.5, 0.99), (0.74, 0.60), (0.60, 0.67), (0.5, 0.60), (0.40, 0.67), (0.26, 0.60)])
    e.add(head, h=1.0, r=0.09, base=0.4)
    e.cut(stroke([(0.5, 0.66), (0.5, 0.93)], 0.014), depth=0.18, r=0.01)
    for sx in (-1, 1):
        for k in range(3):
            y = 0.06 + 0.085 * k
            vane = poly([(0.5, y + 0.06), (0.5 + sx * 0.19, y - 0.05), (0.5 + sx * 0.19, y + 0.03), (0.5, y + 0.14)])
            e.add(vane, h=0.8, r=0.03, base=0.4)
    return e.seat()


@design
def Counter():
    """Counterattack: a blade turned aside on a raised guard."""
    e = Emblem("Counter")
    guard = stroke([(0.10, 0.80), (0.86, 0.14)], 0.10, 0.03)
    e.add(guard, h=0.75, r=0.04, base=0.35)
    e.add(stroke([(0.15, 0.62), (0.34, 0.88)], 0.075), h=0.95, r=0.03, base=0.5)
    e.add(ellipse(0.095, 0.865, 0.062), h=1.0, r=0.05, base=0.5)
    blade = poly([(0.90, 0.86), (0.84, 0.92), (0.30, 0.30), (0.20, 0.12), (0.38, 0.22)])
    e.add(blade, h=1.0, r=0.045, base=0.45)
    e.cut(stroke([(0.30, 0.22), (0.82, 0.84)], 0.012), depth=0.16, r=0.008)
    e.add(stroke([(0.72, 0.96), (0.96, 0.72)], 0.065), h=0.9, r=0.028, base=0.5)
    return e.fit()


@design
def Mongoose():
    """Mongoose Bite: a mongoose's slender head on a furred neck, round ear low on the skull, jaws open to bite."""
    e = Emblem("Mongoose")
    neck = stroke([(0.05, 0.97), (0.13, 0.72), (0.30, 0.50)], 0.30, 0.24)
    e.add(neck, h=0.7, r=0.08, base=0.3)
    for (x, y) in ((0.02, 0.60), (0.06, 0.74), (0.20, 0.84), (0.27, 0.72)):
        e.add(leaf(x + 0.08, y - 0.06, x - 0.04, y + 0.10, 0.045), h=0.8, r=0.02, base=0.5)
    jaw = blob([(0.36, 0.60), (0.52, 0.63), (0.68, 0.72), (0.78, 0.81), (0.73, 0.86), (0.58, 0.81), (0.44, 0.75), (0.34, 0.68)], 14)
    e.add(jaw, h=0.8, r=0.035, base=0.4)
    skull = blob([(0.18, 0.46), (0.27, 0.30), (0.44, 0.25), (0.62, 0.31), (0.78, 0.41), (0.92, 0.49), (0.90, 0.555), (0.74, 0.56),
                  (0.58, 0.57), (0.40, 0.61), (0.22, 0.60)], 14)
    e.add(skull, h=1.0, r=0.09, base=0.45)
    e.add(ellipse(0.25, 0.37, 0.10, 0.075, -20), h=1.08, r=0.035, base=0.75)
    e.cut(ellipse(0.255, 0.375, 0.05, 0.032, -20), depth=0.22, r=0.014)
    for (x, y, ln, d) in ((0.85, 0.55, 0.10, 1), (0.75, 0.555, 0.07, 1), (0.72, 0.80, 0.09, -1), (0.62, 0.755, 0.06, -1)):
        e.add(stroke([(x, y), (x - 0.015, y + d * ln)], 0.04, 0.004), h=0.95, r=0.012, base=0.55)
    e.cut(ellipse(0.58, 0.40, 0.045, 0.032, 15), depth=0.36, r=0.016)
    e.add(ellipse(0.915, 0.50, 0.035, 0.03), h=1.08, r=0.02, base=0.85)
    return e.fit()


@design
def Raptor():
    """Raptor Strike: a bird of prey's foot striking down, three toes spread forward and one back, each ending in a hooked claw."""
    e = Emblem("Raptor")
    e.add(stroke([(0.50, 0.02), (0.50, 0.36)], 0.20, 0.17, smooth=False), h=0.8, r=0.07, base=0.35)
    for k in range(3):
        e.cut(stroke([(0.42, 0.08 + 0.08 * k), (0.58, 0.10 + 0.08 * k)], 0.014), depth=0.14, r=0.008)
    for (knee, tip, hook) in (((0.24, 0.52), (0.10, 0.70), (0.16, 0.92)), ((0.50, 0.62), (0.50, 0.80), (0.42, 0.98)),
                              ((0.76, 0.52), (0.90, 0.70), (0.84, 0.92)), ((0.74, 0.30), (0.90, 0.24), (0.98, 0.38))):
        e.add(stroke([(0.50, 0.38), knee, tip], 0.13, 0.10), h=0.9, r=0.05, base=0.4)
        e.add(stroke([tip, ((tip[0] + hook[0]) / 2 + (tip[0] - 0.5) * 0.12, (tip[1] + hook[1]) / 2), hook], 0.10, 0.012), h=1.0, r=0.03, base=0.5)
    e.add(ellipse(0.50, 0.40, 0.13, 0.11), h=0.95, r=0.06, base=0.45)
    return e.fit()
