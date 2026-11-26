"""designs_casters.py: the mage's and warlock's crest marks as layered relief: the mage's Intellect, spells and gem, the warlock's four demons, its armor and two of its Curses.

Each design seats its figure on a plate, as the crest's perches and fuse heads draw it; plate=False leaves the figure free, as a cooldown medal's own dark face takes it.
"""
import math

from relief import Emblem, blob, ellipse, poly, stroke, transform

D = {}


def design(fn):
    D[fn.__name__] = fn
    return fn


def star4(cx, cy, r, waist=0.26, turn=0.0):
    pts = []
    for k in range(8):
        a = math.radians(-90 + 45 * k + turn)
        rr = r if k % 2 == 0 else r * waist
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    return poly(pts)


@design
def Intellect(plate=True):
    """Arcane Intellect: an open spell book under a four-point star."""
    e = Emblem("Intellect")
    cover = poly([(0.04, 0.50), (0.5, 0.60), (0.96, 0.50), (0.96, 0.90), (0.5, 0.99), (0.04, 0.90)])
    e.add(cover, h=0.5, r=0.03, base=0.25)
    for sx in (-1, 1):
        page = blob([(0.5, 0.56), (0.5 + sx * 0.20, 0.47), (0.5 + sx * 0.42, 0.44), (0.5 + sx * 0.42, 0.80), (0.5 + sx * 0.20, 0.83), (0.5, 0.92)], 12)
        e.add(page, h=0.9, r=0.09, base=0.5)
        for k in range(3):
            y = 0.575 + 0.085 * k
            e.cut(stroke([(0.5 + sx * 0.09, y + 0.02), (0.5 + sx * 0.22, y - 0.025), (0.5 + sx * 0.36, y - 0.035)], 0.016), depth=0.16, r=0.009)
    e.cut(stroke([(0.5, 0.56), (0.5, 0.93)], 0.02), depth=0.3, r=0.012)
    e.add(star4(0.5, 0.22, 0.22), h=1.0, r=0.05, base=0.45)
    e.add(ellipse(0.5, 0.22, 0.045), h=1.1, r=0.04, base=0.8)
    return e.seat() if plate else e.fit()


@design
def Sheep(plate=True):
    """Polymorph: a sheep, woolly, dark-faced."""
    e = Emblem("Sheep")
    for x in (0.30, 0.42, 0.60, 0.72):
        e.add(stroke([(x, 0.66), (x - 0.01, 0.93)], 0.075, 0.06), h=0.6, r=0.03, base=0.3)
    wool = [(0.22, 0.44, 0.13), (0.36, 0.34, 0.14), (0.54, 0.32, 0.15), (0.70, 0.40, 0.13), (0.72, 0.56, 0.13), (0.56, 0.64, 0.14),
            (0.38, 0.64, 0.14), (0.22, 0.58, 0.12), (0.46, 0.48, 0.18)]
    for (x, y, r) in wool:
        e.add(ellipse(x, y, r), h=0.9, r=r * 0.8, base=0.4)
    e.add(ellipse(0.12, 0.46, 0.055), h=0.7, r=0.04, base=0.35)
    head = blob([(0.74, 0.26), (0.86, 0.24), (0.95, 0.34), (0.97, 0.48), (0.90, 0.56), (0.80, 0.52), (0.73, 0.40)], 14)
    e.add(head, h=1.0, r=0.07, base=0.55)
    e.add(blob([(0.74, 0.30), (0.62, 0.30), (0.60, 0.38), (0.72, 0.38)], 12), h=1.0, r=0.03, base=0.6)
    e.add(ellipse(0.80, 0.22, 0.07, 0.05), h=1.0, r=0.04, base=0.6)
    e.cut(ellipse(0.87, 0.37, 0.018), depth=0.3, r=0.01)
    e.cut(stroke([(0.93, 0.47), (0.955, 0.49)], 0.012), depth=0.2, r=0.007)
    return e.seat() if plate else e.fit()


@design
def Flame(plate=True):
    """Fire spells and Immolate: a flame with a bright inner tongue."""
    e = Emblem("Flame")
    outer = blob([(0.52, 0.02), (0.60, 0.20), (0.74, 0.34), (0.70, 0.22), (0.84, 0.42), (0.86, 0.66), (0.74, 0.88), (0.5, 0.97), (0.26, 0.88),
                  (0.14, 0.66), (0.20, 0.44), (0.30, 0.30), (0.34, 0.44), (0.42, 0.24)], 14)
    e.add(outer, h=0.7, r=0.11, base=0.3)
    inner = blob([(0.52, 0.34), (0.60, 0.50), (0.68, 0.66), (0.62, 0.84), (0.5, 0.90), (0.38, 0.84), (0.33, 0.68), (0.42, 0.54)], 14)
    e.add(inner, h=1.0, r=0.08, base=0.62)
    e.cut(blob([(0.5, 0.62), (0.56, 0.74), (0.5, 0.84), (0.44, 0.74)], 12), depth=0.22, r=0.03)
    return e.seat() if plate else e.fit()


@design
def Shard(plate=True):
    """Frost spells and Winter's Chill: a cluster of three ice shards."""
    e = Emblem("Shard")
    def shard(pts, ridge, h):
        e.add(poly(pts), h=h, r=0.07, base=0.3 * h, prof="lin")
        e.add(stroke(ridge, 0.016, smooth=False), h=h + 0.06, r=0.008, base=h * 0.85)
    shard([(0.22, 0.30), (0.34, 0.24), (0.42, 0.62), (0.34, 0.92), (0.20, 0.66)], [(0.29, 0.27), (0.31, 0.88)], 0.75)
    shard([(0.70, 0.36), (0.82, 0.42), (0.80, 0.72), (0.66, 0.94), (0.60, 0.66)], [(0.75, 0.39), (0.69, 0.90)], 0.75)
    shard([(0.50, 0.02), (0.64, 0.22), (0.62, 0.72), (0.50, 0.98), (0.38, 0.72), (0.36, 0.22)], [(0.50, 0.05), (0.50, 0.95)], 1.0)
    e.cut(stroke([(0.37, 0.24), (0.50, 0.30), (0.63, 0.24)], 0.012, smooth=False), depth=0.14, r=0.007)
    e.cut(stroke([(0.39, 0.72), (0.50, 0.66), (0.61, 0.72)], 0.012, smooth=False), depth=0.14, r=0.007)
    return e.seat() if plate else e.fit()


@design
def Gem():
    """A mana gem or a healthstone: a cut stone, table and facets, free of any plate because it hangs from the crest's bail."""
    e = Emblem("Gem")
    out = [(0.5, 0.03), (0.83, 0.17), (0.97, 0.5), (0.83, 0.83), (0.5, 0.97), (0.17, 0.83), (0.03, 0.5), (0.17, 0.17)]
    e.add(poly(out), h=0.75, r=0.2, base=0.2, prof="lin")
    table = [(0.5 + (x - 0.5) * 0.5, 0.5 + (y - 0.5) * 0.5) for x, y in out]
    e.add(poly(table), h=0.95, r=0.02, base=0.9)
    for a, b in zip(out, table):
        e.cut(stroke([a, b], 0.012, smooth=False), depth=0.12, r=0.007)
    e.edge = 0.05
    return e.fit()


@design
def Imp(plate=True):
    """The Imp: a grinning head, great ears, two horns, a flame on its brow."""
    e = Emblem("Imp")
    for sx in (-1, 1):
        ear = blob([(0.5 + sx * 0.20, 0.46), (0.5 + sx * 0.36, 0.30), (0.5 + sx * 0.49, 0.20), (0.5 + sx * 0.42, 0.44), (0.5 + sx * 0.28, 0.62)], 12)
        e.add(ear, h=0.6, r=0.045, base=0.28)
        e.cut(stroke([(0.5 + sx * 0.27, 0.50), (0.5 + sx * 0.42, 0.28)], 0.03, 0.008), depth=0.2, r=0.016)
        horn = stroke([(0.5 + sx * 0.14, 0.30), (0.5 + sx * 0.20, 0.16), (0.5 + sx * 0.15, 0.03)], 0.085, 0.008)
        e.add(horn, h=0.85, r=0.03, base=0.4)
    head = blob([(0.5, 0.24), (0.66, 0.28), (0.74, 0.44), (0.70, 0.64), (0.60, 0.84), (0.5, 0.96), (0.40, 0.84), (0.30, 0.64), (0.26, 0.44), (0.34, 0.28)])
    e.add(head, h=0.85, r=0.12, base=0.35)
    e.add(blob([(0.5, 0.04), (0.56, 0.16), (0.5, 0.26), (0.44, 0.16)], 12), h=1.0, r=0.04, base=0.55)
    for sx in (-1, 1):
        eye = blob([(0.5 + sx * 0.06, 0.50), (0.5 + sx * 0.14, 0.42), (0.5 + sx * 0.21, 0.40), (0.5 + sx * 0.17, 0.50), (0.5 + sx * 0.10, 0.535)], 10)
        e.cut(eye, depth=0.36, r=0.02)
        e.add(stroke([(0.5 + sx * 0.04, 0.455), (0.5 + sx * 0.14, 0.375), (0.5 + sx * 0.23, 0.355)], 0.032, 0.014), h=1.0, r=0.014, base=0.75)
    e.add(blob([(0.5, 0.52), (0.545, 0.62), (0.5, 0.66), (0.455, 0.62)], 10), h=1.05, r=0.03, base=0.8)
    grin = blob([(0.34, 0.69), (0.42, 0.74), (0.5, 0.755), (0.58, 0.74), (0.66, 0.69), (0.60, 0.82), (0.5, 0.87), (0.40, 0.82)], 12)
    e.cut(grin, depth=0.4, r=0.02)
    for x in (0.415, 0.47, 0.53, 0.585):
        e.add(poly([(x - 0.022, 0.735), (x + 0.022, 0.735), (x, 0.80)]), h=0.9, r=0.012, base=0.6)
    return e.seat() if plate else e.fit()


@design
def Voidwalker(plate=True):
    """The Voidwalker: a hooded bulk with burning eyes, huge braced arms, no legs."""
    e = Emblem("Voidwalker")
    tail = blob([(0.36, 0.62), (0.64, 0.62), (0.62, 0.80), (0.54, 0.90), (0.44, 0.99), (0.46, 0.86), (0.38, 0.76)], 14)
    e.add(tail, h=0.55, r=0.07, base=0.25)
    for sx in (-1, 1):
        arm = stroke([(0.5 + sx * 0.24, 0.38), (0.5 + sx * 0.38, 0.52), (0.5 + sx * 0.36, 0.72)], 0.20, 0.17)
        e.add(arm, h=0.75, r=0.08, base=0.3)
        fist = ellipse(0.5 + sx * 0.34, 0.80, 0.115, 0.10)
        e.add(fist, h=0.85, r=0.07, base=0.4)
        brace = stroke([(0.5 + sx * 0.255, 0.61), (0.5 + sx * 0.475, 0.62)], 0.085, smooth=False, cap=False)
        e.add(brace, h=1.0, r=0.02, base=0.75)
    body = blob([(0.5, 0.20), (0.70, 0.26), (0.76, 0.44), (0.66, 0.66), (0.5, 0.72), (0.34, 0.66), (0.24, 0.44), (0.30, 0.26)])
    e.add(body, h=0.8, r=0.13, base=0.3)
    hood = blob([(0.5, 0.03), (0.63, 0.09), (0.69, 0.24), (0.63, 0.38), (0.5, 0.43), (0.37, 0.38), (0.31, 0.24), (0.37, 0.09)])
    e.add(hood, h=1.0, r=0.09, base=0.5)
    e.cut(blob([(0.5, 0.16), (0.60, 0.20), (0.62, 0.30), (0.5, 0.36), (0.38, 0.30), (0.40, 0.20)]), depth=0.42, r=0.04)
    for sx in (-1, 1):
        e.add(blob([(0.5 + sx * 0.035, 0.275), (0.5 + sx * 0.09, 0.235), (0.5 + sx * 0.105, 0.265), (0.5 + sx * 0.06, 0.30)], 10), h=1.0, r=0.012, base=0.8)
    return e.seat() if plate else e.fit()


@design
def Succubus(plate=True):
    """The Succubus: a horned head between spread bat wings, a heart at her throat."""
    e = Emblem("Succubus")
    for sx in (-1, 1):
        w = [(0.5 + sx * 0.10, 0.50), (0.5 + sx * 0.22, 0.26), (0.5 + sx * 0.47, 0.12), (0.5 + sx * 0.44, 0.34), (0.5 + sx * 0.49, 0.50),
             (0.5 + sx * 0.36, 0.52), (0.5 + sx * 0.38, 0.68), (0.5 + sx * 0.24, 0.62), (0.5 + sx * 0.20, 0.76)]
        e.add(blob(w, 6), h=0.5, r=0.04, base=0.22)
        for tip in ((0.5 + sx * 0.47, 0.12), (0.5 + sx * 0.49, 0.50), (0.5 + sx * 0.38, 0.68)):
            e.add(stroke([(0.5 + sx * 0.14, 0.44), tip], 0.035, 0.008), h=0.75, r=0.014, base=0.45)
        horn = stroke([(0.5 + sx * 0.10, 0.22), (0.5 + sx * 0.20, 0.12), (0.5 + sx * 0.16, 0.0)], 0.07, 0.006)
        e.add(horn, h=0.9, r=0.026, base=0.45)
        hair = blob([(0.5 + sx * 0.02, 0.12), (0.5 + sx * 0.17, 0.20), (0.5 + sx * 0.21, 0.44), (0.5 + sx * 0.25, 0.64), (0.5 + sx * 0.14, 0.58),
                     (0.5 + sx * 0.10, 0.36)], 12)
        e.add(hair, h=0.7, r=0.04, base=0.35)
    face = blob([(0.5, 0.16), (0.60, 0.20), (0.63, 0.33), (0.58, 0.46), (0.5, 0.53), (0.42, 0.46), (0.37, 0.33), (0.40, 0.20)])
    e.add(face, h=0.95, r=0.09, base=0.5)
    for sx in (-1, 1):
        e.cut(blob([(0.5 + sx * 0.03, 0.335), (0.5 + sx * 0.08, 0.305), (0.5 + sx * 0.115, 0.31), (0.5 + sx * 0.08, 0.35)], 10), depth=0.3, r=0.012)
    e.cut(stroke([(0.465, 0.445), (0.5, 0.455), (0.535, 0.445)], 0.014), depth=0.25, r=0.008)
    heart = blob([(0.5, 0.70), (0.56, 0.62), (0.64, 0.66), (0.63, 0.78), (0.5, 0.96), (0.37, 0.78), (0.36, 0.66), (0.44, 0.62)], 12)
    e.add(heart, h=1.0, r=0.07, base=0.5)
    return e.seat() if plate else e.fit()


@design
def Felhunter(plate=True):
    """The Felhunter: a hound's head, jaws wide, two feelers sweeping back from its brow."""
    e = Emblem("Felhunter")
    for (pts, w) in (([(0.36, 0.30), (0.24, 0.12), (0.08, 0.06), (0.02, 0.14)], 0.07), ([(0.42, 0.30), (0.36, 0.10), (0.22, 0.0), (0.12, 0.02)], 0.06)):
        e.add(stroke(pts, w, 0.012), h=0.7, r=0.025, base=0.35)
    neck = blob([(0.04, 0.62), (0.16, 0.40), (0.36, 0.34), (0.44, 0.56), (0.34, 0.86), (0.10, 0.96)], 12)
    e.add(neck, h=0.7, r=0.1, base=0.3)
    for k in range(4):
        x, y = 0.07 + 0.045 * k, 0.56 - 0.07 * k
        e.add(poly([(x, y + 0.05), (x - 0.07, y - 0.07), (x + 0.07, y - 0.01)]), h=0.8, r=0.02, base=0.4)
    skull = blob([(0.30, 0.30), (0.46, 0.22), (0.66, 0.26), (0.84, 0.34), (0.97, 0.44), (0.92, 0.52), (0.74, 0.52), (0.56, 0.54), (0.40, 0.56), (0.30, 0.46)], 14)
    jaw = blob([(0.36, 0.62), (0.50, 0.64), (0.68, 0.72), (0.84, 0.86), (0.78, 0.93), (0.58, 0.86), (0.42, 0.80), (0.34, 0.72)], 14)
    e.add(jaw, h=0.85, r=0.05, base=0.4)
    e.add(skull, h=1.0, r=0.09, base=0.45)
    for (x, y, ln, s) in ((0.88, 0.51, 0.16, 1), (0.77, 0.52, 0.12, 1), (0.66, 0.53, 0.09, 1), (0.76, 0.86, 0.13, -1), (0.64, 0.80, 0.10, -1), (0.52, 0.74, 0.07, -1)):
        e.add(stroke([(x, y), (x - 0.02, y + s * ln)], 0.05, 0.004), h=0.95, r=0.015, base=0.55)
    e.cut(blob([(0.50, 0.33), (0.60, 0.31), (0.66, 0.36), (0.58, 0.40)], 10), depth=0.36, r=0.016)
    e.add(stroke([(0.44, 0.285), (0.58, 0.27), (0.70, 0.32)], 0.04, 0.016), h=1.08, r=0.014, base=0.8)
    return e.seat() if plate else e.fit()


@design
def Demon(plate=True):
    """Demon Skin and Demon Armor: a horned demon's skull, brow plate and fangs."""
    e = Emblem("Demon")
    for sx in (-1, 1):
        horn = stroke([(0.5 + sx * 0.20, 0.40), (0.5 + sx * 0.40, 0.36), (0.5 + sx * 0.46, 0.18), (0.5 + sx * 0.34, 0.03)], 0.15, 0.01)
        e.add(horn, h=0.8, r=0.05, base=0.35)
        for k in range(3):
            x, y = 0.5 + sx * (0.36 + 0.035 * k), 0.36 - 0.075 * k
            e.cut(stroke([(x - 0.06, y), (x + 0.06, y - 0.02 * sx)], 0.012), depth=0.14, r=0.008)
    skull = blob([(0.5, 0.20), (0.66, 0.24), (0.74, 0.40), (0.70, 0.58), (0.62, 0.70), (0.60, 0.88), (0.5, 0.96), (0.40, 0.88), (0.38, 0.70), (0.30, 0.58),
                  (0.26, 0.40), (0.34, 0.24)])
    e.add(skull, h=0.9, r=0.12, base=0.4)
    e.add(blob([(0.30, 0.38), (0.5, 0.46), (0.70, 0.38), (0.66, 0.30), (0.5, 0.36), (0.34, 0.30)], 12), h=1.05, r=0.03, base=0.8)
    for sx in (-1, 1):
        e.cut(blob([(0.5 + sx * 0.06, 0.52), (0.5 + sx * 0.14, 0.47), (0.5 + sx * 0.21, 0.49), (0.5 + sx * 0.16, 0.57), (0.5 + sx * 0.08, 0.575)], 10), depth=0.42, r=0.02)
        e.add(poly([(0.5 + sx * 0.045, 0.80), (0.5 + sx * 0.095, 0.80), (0.5 + sx * 0.07, 0.90)]), h=1.0, r=0.014, base=0.7)
    e.cut(blob([(0.5, 0.60), (0.535, 0.69), (0.5, 0.72), (0.465, 0.69)], 10), depth=0.35, r=0.016)
    e.cut(stroke([(0.41, 0.795), (0.59, 0.795)], 0.014, smooth=False), depth=0.25, r=0.008)
    return e.seat() if plate else e.fit()


@design
def BrokenBlade(plate=True):
    """Curse of Weakness: a broad sword snapped in two, its point fallen away from the hilt."""
    e = Emblem("BrokenBlade")

    def T(m):
        return transform(m, rot=40, scale=0.8)

    e.add(T(poly([(0.43, 0.74), (0.57, 0.74), (0.57, 0.40), (0.535, 0.45), (0.50, 0.37), (0.465, 0.46), (0.43, 0.41)])), h=0.9, r=0.05, base=0.4, prof="lin")
    e.add(T(stroke([(0.27, 0.76), (0.73, 0.76)], 0.075, smooth=False)), h=1.0, r=0.03, base=0.55)
    e.add(T(stroke([(0.5, 0.78), (0.5, 0.89)], 0.07, smooth=False)), h=0.85, r=0.03, base=0.45)
    e.add(T(ellipse(0.5, 0.94, 0.06)), h=1.0, r=0.05, base=0.5)
    tip = poly([(0.43, 0.33), (0.465, 0.39), (0.50, 0.31), (0.535, 0.38), (0.57, 0.34), (0.57, 0.17), (0.50, 0.03), (0.43, 0.17)])
    e.add(T(transform(tip, rot=38, dx=0.09, dy=0.02, about=(0.5, 0.36))), h=0.9, r=0.05, base=0.4, prof="lin")
    return e.seat() if plate else e.fit()


@design
def Tongues(plate=True):
    """Curse of Tongues: an open mouth, a forked tongue hanging from it."""
    e = Emblem("Tongues")
    lips = blob([(0.06, 0.34), (0.28, 0.14), (0.42, 0.10), (0.5, 0.15), (0.58, 0.10), (0.72, 0.14), (0.94, 0.34), (0.74, 0.54), (0.5, 0.60), (0.26, 0.54)], 14)
    e.add(lips, h=0.85, r=0.09, base=0.35)
    e.cut(blob([(0.20, 0.335), (0.38, 0.27), (0.5, 0.29), (0.62, 0.27), (0.80, 0.335), (0.64, 0.44), (0.5, 0.46), (0.36, 0.44)], 14), depth=0.5, r=0.03)
    for x in (0.34, 0.42, 0.5, 0.58, 0.66):
        e.add(poly([(x - 0.035, 0.285), (x + 0.035, 0.285), (x, 0.355)]), h=0.8, r=0.014, base=0.5)
    tongue = blob([(0.40, 0.40), (0.60, 0.40), (0.62, 0.66), (0.70, 0.82), (0.74, 0.97), (0.60, 0.84), (0.5, 0.74), (0.40, 0.84), (0.26, 0.97), (0.30, 0.82),
                   (0.38, 0.66)], 12)
    e.add(tongue, h=1.0, r=0.06, base=0.5)
    e.cut(stroke([(0.5, 0.44), (0.5, 0.72)], 0.014, smooth=False), depth=0.18, r=0.008)
    return e.seat() if plate else e.fit()
