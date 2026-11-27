"""Draw the crest's sigils into Media/Textures/Sigils/.

A sigil is one cooldown family's mark, engraved line art in the crest's rune style (the shaman's imbue rune,
Tools/media/healer_trackers.py): white strokes with round caps in a soft glow, tinted in the game by the class colour
and drawn steel when dark. Procedural, no model and no input image: each is drawn at 8x from strokes, arcs, rings and
dots in a unit box (y down), and reduced with a linear-light Lanczos to 64x64. Drawn ADD: colour unpremultiplied,
alpha the brightest channel (as medallions_kit.py stores effects).

    python3 Tools/media/sigils.py [--out DIR] [--sheet PNG]
"""
import argparse
import hashlib
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from healer_trackers import additive, blur

SIZE, SCALE = 64, 8
N = SIZE * SCALE
WIDTH = 0.085
OUT = Path(__file__).resolve().parents[2] / "Media/Textures/Sigils"


class Pen:
    def __init__(self):
        self.image = Image.new("L", (N, N), 0)
        self.draw = ImageDraw.Draw(self.image)

    def line(self, *points, width=WIDTH):
        w = int(width * N)
        xy = [(x * N, y * N) for x, y in points]
        self.draw.line(xy, fill=255, width=w, joint="curve")
        for x, y in (xy[0], xy[-1]):
            self.draw.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=255)

    def poly(self, *points, width=WIDTH):
        self.line(*points, points[0], width=width)

    def fill(self, *points):
        self.draw.polygon([(x * N, y * N) for x, y in points], fill=255)

    def arc(self, cx, cy, r, start, end, width=WIDTH, steps=48):
        a0, a1 = math.radians(start), math.radians(end)
        self.line(*[(cx + r * math.cos(a0 + (a1 - a0) * k / steps), cy + r * math.sin(a0 + (a1 - a0) * k / steps))
                    for k in range(steps + 1)], width=width)

    def ring(self, cx, cy, r, width=WIDTH):
        self.arc(cx, cy, r, 0, 360, width)

    def dot(self, cx, cy, r):
        self.draw.ellipse([(cx - r) * N, (cy - r) * N, (cx + r) * N, (cy + r) * N], fill=255)

    def curve(self, f, t0, t1, width=WIDTH, steps=64):
        self.line(*[f(t0 + (t1 - t0) * k / steps) for k in range(steps + 1)], width=width)


def heart(p, cx=0.5, cy=0.52, s=0.021):
    p.curve(lambda t: (cx + s * 16 * math.sin(t) ** 3,
                       cy - s * (13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))), 0, 2 * math.pi)


def shield(p, top=0.18, bottom=0.84, half=0.3):
    p.poly((0.5 - half, top), (0.5 + half, top), (0.5 + half, top + 0.32), (0.5 + half * 0.72, top + 0.48), (0.5, bottom),
           (0.5 - half * 0.72, top + 0.48), (0.5 - half, top + 0.32))


def blade(p, x0, y0, x1, y1):
    dx, dy = x1 - x0, y1 - y0
    length = math.hypot(dx, dy)
    ux, uy, nx, ny = dx / length, dy / length, -dy / length, dx / length
    p.line((x0, y0), (x1, y1))
    gx, gy = x0 + ux * 0.14, y0 + uy * 0.14
    p.line((gx + nx * 0.09, gy + ny * 0.09), (gx - nx * 0.09, gy - ny * 0.09))


def arrow(p, x0, y0, x1, y1, head=0.12, width=WIDTH):
    p.line((x0, y0), (x1, y1), width=width)
    a = math.atan2(y1 - y0, x1 - x0)
    for side in (-1, 1):
        p.line((x1, y1), (x1 - head * math.cos(a + side * 0.55), y1 - head * math.sin(a + side * 0.55)), width=width)


def eye(p, cx=0.5, cy=0.5, w=0.34, h=0.2):
    p.curve(lambda t: (cx + w * math.cos(t), cy - h * math.sin(t) * abs(math.sin(t)) ** 0.2), 0, 2 * math.pi)
    p.dot(cx, cy, 0.08)


def spiral(p, cx, cy, r0, r1, turns, start=0):
    p.curve(lambda t: (cx + (r0 + (r1 - r0) * t) * math.cos(start + turns * 2 * math.pi * t),
                       cy + (r0 + (r1 - r0) * t) * math.sin(start + turns * 2 * math.pi * t)), 0, 1, steps=120)


def bolt(p, x=0.5, s=1.0):
    p.poly((x + 0.08 * s, 0.14), (x - 0.16 * s, 0.54), (x - 0.01 * s, 0.54), (x - 0.1 * s, 0.86), (x + 0.18 * s, 0.42),
           (x + 0.02 * s, 0.42))


def star(p, cx, cy, outer, inner, points, turn=-90):
    pts = []
    for k in range(points * 2):
        r = outer if k % 2 == 0 else inner
        a = math.radians(turn + 180 * k / points)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    p.poly(*pts)


def drop(p, cx=0.5, top=0.16, bottom=0.84, r=0.2):
    cy = bottom - r
    p.curve(lambda t: (cx + r * math.cos(t), cy + r * math.sin(t)), math.radians(-35), math.radians(215))
    p.line((cx - r * math.cos(math.radians(35)), cy - r * math.sin(math.radians(35))), (cx, top),
           (cx + r * math.cos(math.radians(35)), cy - r * math.sin(math.radians(35))))


def wave(p, y, x0=0.18, x1=0.82, amp=0.05, waves=1.5):
    p.curve(lambda t: (x0 + (x1 - x0) * t, y + amp * math.sin(t * waves * 2 * math.pi)), 0, 1)


def leaf(p, cx, cy, length, angle, width=0.1):
    a = math.radians(angle)
    ux, uy, nx, ny = math.cos(a), math.sin(a), -math.sin(a), math.cos(a)
    p.curve(lambda t: (cx + ux * length * t + nx * width * math.sin(math.pi * t),
                       cy + uy * length * t + ny * width * math.sin(math.pi * t)), 0, 1)
    p.curve(lambda t: (cx + ux * length * t - nx * width * math.sin(math.pi * t),
                       cy + uy * length * t - ny * width * math.sin(math.pi * t)), 0, 1)


def bezier(p, a, c, b, width=WIDTH):
    p.curve(lambda t: ((1 - t) ** 2 * a[0] + 2 * (1 - t) * t * c[0] + t * t * b[0],
                       (1 - t) ** 2 * a[1] + 2 * (1 - t) * t * c[1] + t * t * b[1]), 0, 1, width=width)


GLYPHS = {"Heart": heart, "Drop": drop, "Bolt": bolt, "Eye": eye}


def glyph(fn):
    GLYPHS[fn.__name__] = fn
    return fn


# Warrior
@glyph
def Crossed(p):
    blade(p, 0.2, 0.8, 0.82, 0.18)
    blade(p, 0.8, 0.8, 0.18, 0.18)


@glyph
def Skull(p):
    p.arc(0.5, 0.46, 0.28, 180, 360)
    p.line((0.22, 0.46), (0.26, 0.62), (0.37, 0.67), (0.37, 0.82), (0.63, 0.82), (0.63, 0.67), (0.74, 0.62), (0.78, 0.46))
    p.dot(0.39, 0.5, 0.075)
    p.dot(0.61, 0.5, 0.075)
    p.line((0.5, 0.7), (0.5, 0.82))


@glyph
def Wall(p):
    shield(p)
    p.line((0.2, 0.38), (0.8, 0.38))
    p.line((0.23, 0.57), (0.77, 0.57))
    p.line((0.5, 0.18), (0.5, 0.38))
    p.line((0.36, 0.38), (0.36, 0.57))
    p.line((0.64, 0.38), (0.64, 0.57))


@glyph
def Sweep(p):
    # a sword swung through a crescent arc: the arc trails the blade
    p.arc(0.5, 0.5, 0.36, 150, 300, width=0.05)
    p.arc(0.5, 0.5, 0.29, 165, 285, width=0.035)
    blade(p, 0.24, 0.8, 0.8, 0.2)
    p.dot(0.2, 0.84, 0.05)


@glyph
def Thorns(p):
    p.ring(0.5, 0.5, 0.18)
    for k in range(8):
        a = math.radians(k * 45 + 22.5)
        tip, l, r = 0.4, a - 0.22, a + 0.22
        p.fill((0.5 + 0.2 * math.cos(l), 0.5 + 0.2 * math.sin(l)), (0.5 + tip * math.cos(a), 0.5 + tip * math.sin(a)),
               (0.5 + 0.2 * math.cos(r), 0.5 + 0.2 * math.sin(r)))


# Paladin
@glyph
def Bubble(p):
    p.ring(0.5, 0.5, 0.33)
    p.arc(0.5, 0.5, 0.22, 200, 260)
    p.line((0.5, 0.36), (0.5, 0.66))
    p.line((0.4, 0.46), (0.6, 0.46))


@glyph
def Aegis(p):
    shield(p)
    p.line((0.5, 0.3), (0.5, 0.7))
    p.line((0.34, 0.42), (0.66, 0.42))


@glyph
def Sun(p):
    p.ring(0.5, 0.5, 0.15)
    for k in range(8):
        a = math.radians(k * 45)
        r1 = 0.36 if k % 2 == 0 else 0.29
        p.line((0.5 + 0.22 * math.cos(a), 0.5 + 0.22 * math.sin(a)), (0.5 + r1 * math.cos(a), 0.5 + r1 * math.sin(a)))


@glyph
def Hand(p):
    for x, top in ((0.34, 0.3), (0.45, 0.2), (0.56, 0.2), (0.67, 0.28)):
        p.line((x, 0.52), (x, top))
    p.line((0.34, 0.52), (0.36, 0.72), (0.5, 0.84), (0.64, 0.78), (0.67, 0.52))
    p.line((0.36, 0.64), (0.22, 0.48))


@glyph
def Wing(p):
    bezier(p, (0.14, 0.7), (0.36, 0.14), (0.88, 0.18))
    for t, length in ((0.35, 0.3), (0.6, 0.36), (0.85, 0.4)):
        x = (1 - t) ** 2 * 0.14 + 2 * (1 - t) * t * 0.36 + t * t * 0.88
        y = (1 - t) ** 2 * 0.7 + 2 * (1 - t) * t * 0.14 + t * t * 0.18
        p.line((x, y), (x - length * 0.55, y + length * 0.85))


@glyph
def Bulwark(p):
    p.poly((0.26, 0.16), (0.74, 0.16), (0.74, 0.72), (0.5, 0.86), (0.26, 0.72))
    for x, y in ((0.36, 0.28), (0.64, 0.28), (0.36, 0.62), (0.64, 0.62)):
        p.dot(x, y, 0.045)
    p.line((0.5, 0.3), (0.5, 0.7))


@glyph
def Voice(p):
    p.dot(0.3, 0.5, 0.08)
    for r in (0.18, 0.3, 0.42):
        p.arc(0.3, 0.5, r, -45, 45)


# Rogue
@glyph
def Flurry(p):
    # three fanned daggers from one grip
    for ang in (-38, 0, 38):
        a = math.radians(ang - 90)
        blade(p, 0.5 + 0.16 * math.cos(a), 0.84 + 0.16 * math.sin(a), 0.5 + 0.7 * math.cos(a), 0.84 + 0.7 * math.sin(a))
        p.line((0.5, 0.86), (0.5 + 0.16 * math.cos(a), 0.84 + 0.16 * math.sin(a)), width=0.06)


@glyph
def Rush(p):
    # a heart struck by a bolt
    heart(p, 0.42, 0.58, 0.018)
    p.line((0.9, 0.06), (0.64, 0.28), (0.82, 0.34), (0.5, 0.66), width=0.07)


@glyph
def Evade(p):
    # a hooded cloak swept aside, two motion lines trailing it
    p.line((0.56, 0.12), (0.4, 0.3), (0.42, 0.46))
    p.line((0.56, 0.12), (0.66, 0.34), (0.62, 0.46))
    p.line((0.42, 0.46), (0.34, 0.86), (0.6, 0.78), (0.86, 0.84), (0.62, 0.46))
    p.line((0.48, 0.5), (0.5, 0.78), width=0.05)
    p.arc(0.5, 0.5, 0.4, 150, 200, width=0.05)
    p.arc(0.5, 0.5, 0.32, 160, 205, width=0.05)


@glyph
def Dash(p):
    # a winged boot
    p.line((0.34, 0.2), (0.34, 0.64), (0.3, 0.78), (0.78, 0.8), (0.8, 0.7), (0.56, 0.62), (0.54, 0.2))
    p.line((0.3, 0.2), (0.58, 0.2))
    for k, (dx, dy) in enumerate(((-0.24, -0.1), (-0.26, 0.02), (-0.22, 0.13))):
        p.line((0.34, 0.36 + k * 0.08), (0.34 + dx, 0.36 + k * 0.08 + dy))


@glyph
def Smoke(p):
    # a burst smoke cloud
    for cx, cy, r in ((0.32, 0.6, 0.15), (0.5, 0.48, 0.19), (0.7, 0.6, 0.15), (0.5, 0.7, 0.13)):
        p.arc(cx, cy, r, 0, 360, width=0.07)
    for cx, cy, r in ((0.32, 0.6, 0.15), (0.5, 0.48, 0.19), (0.7, 0.6, 0.15), (0.5, 0.7, 0.13)):
        p.dot(cx, cy, r - 0.035)
    for x, y in ((0.18, 0.28), (0.82, 0.3), (0.5, 0.16)):
        p.dot(x, y, 0.04)


@glyph
def Ghost(p):
    p.arc(0.5, 0.42, 0.24, 180, 360)
    p.line((0.26, 0.42), (0.26, 0.8))
    wave(p, 0.8, 0.26, 0.74, 0.04, 2)
    p.line((0.74, 0.42), (0.74, 0.8))
    p.dot(0.42, 0.44, 0.05)
    p.dot(0.58, 0.44, 0.05)


# Hunter
@glyph
def Volley(p):
    for x, y, half in ((0.13, 0.44, 0.13), (0.5, 0.04, 0.25), (0.87, 0.44, 0.13)):
        p.fill((x - half, y + half * 1.6), (x, y), (x + half, y + half * 1.6))
        p.line((x, y + half), (x, 0.92), width=half * 0.6)


@glyph
def Deflect(p):
    p.poly((0.19, 0.17), (0.81, 0.17), (0.81, 0.48), (0.5, 0.84), (0.19, 0.48), width=0.19)


@glyph
def Paw(p):
    p.dot(0.5, 0.68, 0.19)
    for x, y in ((0.14, 0.44), (0.36, 0.2), (0.64, 0.2), (0.86, 0.44)):
        p.dot(x, y, 0.1)


@glyph
def Intimidate(p):
    p.arc(0.5, 0.62, 0.38, 200, 340, width=0.13)
    for x in (0.3, 0.7):
        p.fill((x - 0.13, 0.36), (x + 0.13, 0.36), (x, 0.9))
    p.dot(0.5, 0.2, 0.08)


@glyph
def FireTrap(p):
    p.arc(0.5, 0.5, 0.4, 20, 160, width=0.11)
    for k in range(5):
        x = 0.18 + 0.16 * k
        p.fill((x - 0.06, 0.78), (x + 0.06, 0.78), (x, 0.62))
    p.fill((0.5, 0.04), (0.6, 0.2), (0.68, 0.36), (0.66, 0.5), (0.58, 0.6), (0.5, 0.62), (0.42, 0.6), (0.34, 0.5),
           (0.33, 0.38), (0.4, 0.3), (0.42, 0.42), (0.5, 0.26))


@glyph
def Sniper(p):
    p.ring(0.5, 0.5, 0.3, width=0.1)
    for x0, y0, x1, y1 in ((0.5, 0.04, 0.5, 0.3), (0.5, 0.7, 0.5, 0.96), (0.04, 0.5, 0.3, 0.5), (0.7, 0.5, 0.96, 0.5)):
        p.line((x0, y0), (x1, y1), width=0.1)
    p.dot(0.5, 0.5, 0.08)


@glyph
def Aimed(p):
    p.ring(0.64, 0.36, 0.26, width=0.1)
    p.dot(0.64, 0.36, 0.07)
    arrow(p, 0.08, 0.92, 0.4, 0.6, head=0.2, width=0.11)


@glyph
def Charm(p):
    p.ring(0.5, 0.16, 0.1, width=0.08)
    p.fill((0.5, 0.3), (0.8, 0.5), (0.5, 0.94), (0.2, 0.5))
    p.line((0.2, 0.5), (0.8, 0.5), width=0.05)


@glyph
def Strider(p):
    p.fill((0.36, 0.12), (0.62, 0.12), (0.62, 0.56), (0.92, 0.7), (0.92, 0.86), (0.36, 0.86))
    for y in (0.36, 0.56, 0.76):
        p.line((0.06, y), (0.22, y), width=0.08)


# Mage
@glyph
def Arcane(p):
    star(p, 0.5, 0.5, 0.36, 0.11, 4)
    p.ring(0.5, 0.5, 0.36, width=0.05)


@glyph
def Hourglass(p):
    p.line((0.26, 0.16), (0.74, 0.16))
    p.line((0.26, 0.84), (0.74, 0.84))
    p.line((0.32, 0.18), (0.5, 0.5), (0.32, 0.82))
    p.line((0.68, 0.18), (0.5, 0.5), (0.68, 0.82))
    p.fill((0.4, 0.78), (0.6, 0.78), (0.5, 0.62))


@glyph
def Flame(p):
    p.arc(0.5, 0.64, 0.2, -10, 190)
    bezier(p, (0.303, 0.605), (0.26, 0.34), (0.56, 0.14))
    bezier(p, (0.697, 0.605), (0.74, 0.4), (0.56, 0.14))
    bezier(p, (0.5, 0.76), (0.62, 0.6), (0.48, 0.42))


@glyph
def Vortex(p):
    for k, r in enumerate((0.34, 0.24, 0.14)):
        p.arc(0.5, 0.5, r, 30 + 70 * k, 300 + 70 * k)


@glyph
def Crystal(p):
    pts = [(0.5 + 0.34 * math.cos(math.radians(a)), 0.5 + 0.34 * math.sin(math.radians(a))) for a in range(-90, 270, 60)]
    p.poly(*pts)
    p.line(pts[0], (0.5, 0.5), pts[2])
    p.line((0.5, 0.5), pts[4])


# the mage's rail (KstyleUI_ActionBars/SlabRail.lua): the cooldowns its seats count
@glyph
def Blink(p):
    # a figure's outline left behind and the arrow it jumps along
    p.arc(0.3, 0.32, 0.08, 0, 360, width=0.05)
    p.line((0.3, 0.42), (0.3, 0.7), width=0.05)
    arrow(p, 0.42, 0.56, 0.84, 0.56, head=0.13)
    p.dot(0.84, 0.32, 0.05)


@glyph
def FrostNova(p):
    # a burst of ice: six spikes round a ring
    p.ring(0.5, 0.5, 0.14)
    for k in range(6):
        a = math.radians(90 + 60 * k)
        p.line((0.5 + 0.2 * math.cos(a), 0.5 + 0.2 * math.sin(a)), (0.5 + 0.38 * math.cos(a), 0.5 + 0.38 * math.sin(a)))
        b = math.radians(120 + 60 * k)
        p.dot(0.5 + 0.3 * math.cos(b), 0.5 + 0.3 * math.sin(b), 0.035)


@glyph
def FireBlast(p):
    # a flame struck through by a blast's three lines
    bezier(p, (0.42, 0.84), (0.2, 0.5), (0.46, 0.16))
    bezier(p, (0.42, 0.84), (0.68, 0.62), (0.52, 0.38))
    for k, y in enumerate((0.36, 0.52, 0.68)):
        p.line((0.62, y), (0.86 - 0.04 * k, y - 0.06))


@glyph
def BlastWave(p):
    # a fire's heart and the waves it throws out
    p.dot(0.5, 0.6, 0.08)
    for r in (0.18, 0.3, 0.42):
        p.arc(0.5, 0.6, r, 200, 340)


@glyph
def ColdSnap(p):
    # a six-armed snowflake, each arm branching
    for k in range(3):
        a = math.radians(90 + 60 * k)
        p.line((0.5 - 0.34 * math.cos(a), 0.5 - 0.34 * math.sin(a)), (0.5 + 0.34 * math.cos(a), 0.5 + 0.34 * math.sin(a)))
    for k in range(6):
        a = math.radians(90 + 60 * k)
        x, y = 0.5 + 0.22 * math.cos(a), 0.5 + 0.22 * math.sin(a)
        for side in (-1, 1):
            b = a + side * math.radians(40)
            p.line((x, y), (x + 0.1 * math.cos(b), y + 0.1 * math.sin(b)), width=0.05)


@glyph
def IceBarrier(p):
    # a shield of ice facets
    shield(p)
    p.line((0.5, 0.2), (0.5, 0.82), width=0.05)
    p.line((0.22, 0.42), (0.5, 0.56), (0.78, 0.42), width=0.05)


@glyph
def IceLance(p):
    # a lance of ice thrown down and to the right
    p.poly((0.18, 0.18), (0.3, 0.14), (0.86, 0.86), (0.14, 0.3))
    p.line((0.3, 0.3), (0.62, 0.62), width=0.05)


@glyph
def Escape(p):
    # a broken shackle
    p.arc(0.36, 0.56, 0.18, 30, 300)
    p.arc(0.64, 0.44, 0.18, 210, 480)
    p.line((0.5, 0.12), (0.5, 0.24), width=0.05)
    p.line((0.5, 0.76), (0.5, 0.88), width=0.05)


# Warlock
@glyph
def Curse(p):
    p.poly((0.18, 0.24), (0.82, 0.24), (0.5, 0.82))
    eye(p, 0.5, 0.42, 0.16, 0.09)


@glyph
def Horns(p):
    bezier(p, (0.42, 0.74), (0.08, 0.62), (0.24, 0.16))
    bezier(p, (0.58, 0.74), (0.92, 0.62), (0.76, 0.16))
    p.arc(0.5, 0.9, 0.2, 235, 305)


@glyph
def Shade(p):
    shield(p)
    p.arc(0.5, 0.48, 0.16, 110, 340)
    p.arc(0.56, 0.44, 0.13, 120, 330, width=0.05)


@glyph
def Void(p):
    p.ring(0.5, 0.5, 0.34)
    p.ring(0.5, 0.5, 0.17)
    p.dot(0.5, 0.5, 0.06)


# Priest
@glyph
def Infusion(p):
    arrow(p, 0.5, 0.84, 0.5, 0.2, 0.16)
    star(p, 0.26, 0.38, 0.1, 0.035, 4)
    star(p, 0.74, 0.58, 0.1, 0.035, 4)


@glyph
def Focus(p):
    p.ring(0.5, 0.5, 0.33)
    p.ring(0.5, 0.5, 0.18)
    p.dot(0.5, 0.5, 0.06)
    for a in (0, 90, 180, 270):
        r = math.radians(a)
        p.line((0.5 + 0.33 * math.cos(r), 0.5 + 0.33 * math.sin(r)), (0.5 + 0.42 * math.cos(r), 0.5 + 0.42 * math.sin(r)))


@glyph
def Veil(p):
    p.ring(0.5, 0.3, 0.13)
    p.arc(0.5, 0.92, 0.32, 200, 340)
    for k, x in enumerate((0.7, 0.8, 0.88)):
        p.dot(x, 0.34 + 0.12 * k, 0.04 - 0.008 * k)


@glyph
def Brave(p):
    shield(p)
    star(p, 0.5, 0.45, 0.17, 0.07, 5)


@glyph
def Moon(p):
    p.arc(0.5, 0.5, 0.33, 60, 300)
    p.arc(0.7, 0.5, 0.288, 97, 263)


@glyph
def Feedback(p):
    p.ring(0.5, 0.5, 0.36)
    bolt(p, 0.5, 0.7)


@glyph
def Sacrifice(p):
    heart(p, 0.5, 0.56, 0.017)
    blade(p, 0.5, 0.9, 0.5, 0.12)


@glyph
def Lifeline(p):
    p.ring(0.5, 0.5, 0.34)
    p.line((0.5, 0.3), (0.5, 0.7))
    p.line((0.3, 0.5), (0.7, 0.5))


# Druid
@glyph
def Mend(p):
    heart(p)
    p.line((0.5, 0.38), (0.5, 0.62))
    p.line((0.38, 0.5), (0.62, 0.5))


@glyph
def Fang(p):
    for x in (0.34, 0.66):
        p.line((x - 0.1, 0.22), (x, 0.8), (x + 0.1, 0.22))
    p.line((0.18, 0.22), (0.82, 0.22))


@glyph
def Bark(p):
    for k, (rx, ry) in enumerate(((0.34, 0.36), (0.22, 0.25), (0.1, 0.13))):
        p.curve(lambda t, rx=rx, ry=ry, k=k: (0.5 + rx * math.cos(t) * (1 + 0.06 * math.sin(3 * t + k)),
                                              0.5 + ry * math.sin(t) * (1 + 0.06 * math.cos(2 * t + k))), 0, 2 * math.pi)


@glyph
def Innervate(p):
    drop(p, 0.5, 0.14, 0.86, 0.24)
    spiral(p, 0.5, 0.62, 0.02, 0.12, 1.2)


@glyph
def Swift(p):
    for k, y in enumerate((0.26, 0.5, 0.74)):
        x0 = 0.14 + 0.1 * (k % 2)
        bezier(p, (x0, y + 0.06), (0.5, y - 0.1), (0.78, y))
        p.arc(0.74, y + 0.07, 0.07, -60, 160)


@glyph
def Roots(p):
    p.line((0.5, 0.16), (0.5, 0.5))
    p.line((0.5, 0.5), (0.3, 0.68), (0.22, 0.86))
    p.line((0.5, 0.5), (0.7, 0.68), (0.78, 0.86))
    p.line((0.5, 0.5), (0.5, 0.86))
    p.line((0.3, 0.68), (0.16, 0.66))
    p.line((0.7, 0.68), (0.84, 0.66))


# Shaman
@glyph
def Farseer(p):
    p.poly((0.5, 0.14), (0.86, 0.8), (0.14, 0.8))
    eye(p, 0.5, 0.58, 0.18, 0.1)


# Races
@glyph
def Axe(p):
    # a double-bitted axe
    p.line((0.5, 0.12), (0.5, 0.9))
    for s in (-1, 1):
        p.fill((0.5, 0.24), (0.5 + s * 0.2, 0.16), (0.5 + s * 0.36, 0.12), (0.5 + s * 0.3, 0.36), (0.5 + s * 0.36, 0.6),
               (0.5 + s * 0.2, 0.54), (0.5, 0.48))


@glyph
def Tusks(p):
    # a tusked troll face: long ears, brow, eyes and two tusks curling up from the jaw
    p.line((0.32, 0.3), (0.06, 0.18), (0.3, 0.46))
    p.line((0.68, 0.3), (0.94, 0.18), (0.7, 0.46))
    p.line((0.32, 0.3), (0.5, 0.2), (0.68, 0.3), (0.7, 0.58), (0.6, 0.82), (0.4, 0.82), (0.3, 0.58), (0.32, 0.3))
    p.dot(0.42, 0.46, 0.04)
    p.dot(0.58, 0.46, 0.04)
    for s in (-1, 1):
        bezier(p, (0.5 + s * 0.08, 0.74), (0.5 + s * 0.3, 0.8), (0.5 + s * 0.3, 0.5), width=0.075)


@glyph
def Stone(p):
    # a cracked boulder
    p.poly((0.2, 0.62), (0.26, 0.36), (0.44, 0.22), (0.66, 0.24), (0.82, 0.4), (0.86, 0.64), (0.72, 0.8), (0.3, 0.8))
    p.line((0.52, 0.23), (0.46, 0.42), (0.56, 0.52), (0.48, 0.8))
    p.line((0.56, 0.52), (0.74, 0.58))


@glyph
def Grave(p):
    p.line((0.26, 0.84), (0.26, 0.38))
    p.arc(0.5, 0.38, 0.24, 180, 360)
    p.line((0.74, 0.38), (0.74, 0.84))
    p.line((0.18, 0.84), (0.82, 0.84))
    p.line((0.5, 0.32), (0.5, 0.66))
    p.line((0.4, 0.44), (0.6, 0.44))


@glyph
def Shatter(p):
    p.arc(0.5, 0.5, 0.33, -60, 140)
    p.arc(0.5, 0.5, 0.33, 165, 280)
    p.line((0.56, 0.18), (0.46, 0.4), (0.58, 0.54), (0.44, 0.82))


@glyph
def Star(p):
    star(p, 0.5, 0.5, 0.38, 0.1, 4)
    star(p, 0.5, 0.5, 0.2, 0.06, 4, -45)


@glyph
def Gear(p):
    # a toothed cog
    p.ring(0.5, 0.5, 0.24, width=0.11)
    p.ring(0.5, 0.5, 0.07, width=0.06)
    for k in range(8):
        a = math.radians(k * 45 + 22.5)
        w = 0.17
        pts = [(0.5 + r * math.cos(a + s), 0.5 + r * math.sin(a + s)) for r, s in ((0.27, -w), (0.4, -w * 0.62), (0.4, w * 0.62), (0.27, w))]
        p.fill(*pts)


@glyph
def Regen(p):
    p.arc(0.5, 0.5, 0.3, 200, 500)
    p.line((0.5 + 0.3 * math.cos(math.radians(140)), 0.5 + 0.3 * math.sin(math.radians(140))), (0.14, 0.62))
    p.line((0.5 + 0.3 * math.cos(math.radians(140)), 0.5 + 0.3 * math.sin(math.radians(140))), (0.3, 0.86))
    p.line((0.5, 0.4), (0.5, 0.6))
    p.line((0.4, 0.5), (0.6, 0.5))


@glyph
def Potion(p):
    p.line((0.42, 0.16), (0.58, 0.16))
    p.line((0.44, 0.16), (0.44, 0.36))
    p.line((0.56, 0.16), (0.56, 0.36))
    p.arc(0.5, 0.6, 0.26, -68, 248)
    wave(p, 0.62, 0.28, 0.72, 0.03, 1.5)


def render(draw):
    pen = Pen()
    draw(pen)
    lines = np.asarray(pen.image, np.float64) / 255
    glow = np.clip(blur(lines, 2.5) * 1.5, 0, 1)
    light = np.clip(np.maximum(lines, 0.55 * glow), 0, 1)
    rgb = np.array([0.9, 0.93, 1.0]) * glow[..., None] * (1 - lines[..., None]) + lines[..., None]
    return additive(np.clip(rgb, 0, 1) * light[..., None])


def sheet(images, path, cell=64):
    names = sorted(images)
    columns = 10
    rows = (len(names) + columns - 1) // columns
    out = Image.new("RGB", (columns * cell * 2, rows * (cell + 26)), (18, 18, 22))
    draw = ImageDraw.Draw(out)
    for k, name in enumerate(names):
        rgba = images[name]
        small = Image.fromarray(np.clip(rgba * 255 + 0.5, 0, 255).astype(np.uint8), "RGBA")
        x, y = k % columns * cell * 2, k // columns * (cell + 26)
        for size, dx in ((cell, 0), (14, cell + 8)):
            tile = small.resize((size, size), Image.LANCZOS)
            a = np.asarray(tile, np.float64) / 255
            add = (a[..., :3] * a[..., 3:4] * np.array([1.0, 0.82, 0.45]) * 255).astype(np.uint8)
            base = np.asarray(out.crop((x + dx, y, x + dx + size, y + size)), np.int32)
            out.paste(Image.fromarray(np.clip(base + add, 0, 255).astype(np.uint8)), (x + dx, y))
        draw.text((x + 2, y + cell + 6), name, fill=(200, 200, 200))
    out.save(path)


# Drawn here, written as Blender-forged metal by Tools/media/forge/marks.py.
FORGED = {"Volley", "Deflect", "Paw", "Intimidate", "FireTrap", "Sniper", "Aimed", "Strider", "Charm",
          "Blink", "FrostNova", "FireBlast", "BlastWave", "ColdSnap", "IceBarrier", "IceLance", "Escape"}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path, default=OUT)
    parser.add_argument("--sheet", type=Path)
    args = parser.parse_args(argv)
    args.out.mkdir(parents=True, exist_ok=True)
    images = {}
    for name, draw in GLYPHS.items():
        if name in FORGED:
            continue
        images[name] = render(draw)
        path = args.out / f"{name}.png"
        Image.fromarray(np.clip(images[name] * 255 + 0.5, 0, 255).astype(np.uint8), "RGBA").save(path, optimize=True)
        print(path.relative_to(args.out.parents[2]) if args.out == OUT else path, hashlib.sha256(path.read_bytes()).hexdigest())
    if args.sheet:
        sheet(images, args.sheet)


if __name__ == "__main__":
    main()
