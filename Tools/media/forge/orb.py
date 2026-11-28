"""orb.py: Blender 5.3, headless. Design render of the mage power orb that replaces the crest hub's painted crest.

One orb per race: the class lives inside (an arcane crystal star in its orbit rings, wrapped in swirling mage light),
the race is the vessel round it. The orb's light is the signature cooldown's charge: full is ready, spent it drains and
rises again as the cooldown recovers. A proc floods it with its school's own effect.

    blender -b --factory-startup --python-exit-code 1 --python orb.py -- RACE OUT --repo REPO
        [--story race|procs] [--build arcane|fire|frost] [--proc clearcasting|missile|heating|fingers]
        [--frames a:b|n,n] [--size 720] [--samples 24]
"""
import argparse
import math
import random
import sys
import time
from pathlib import Path

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
ap = argparse.ArgumentParser()
ap.add_argument("race")
ap.add_argument("out")
ap.add_argument("--repo", required=True)
ap.add_argument("--story", default="race")
ap.add_argument("--proc", default="clearcasting")
ap.add_argument("--frames", default="")
ap.add_argument("--size", type=int, default=720)
ap.add_argument("--samples", type=int, default=24)
ap.add_argument("--scale", type=float, default=2.9, help="ortho scale: the frame's width in opening radii")
ap.add_argument("--noring", action="store_true", help="the orb alone on black, for the bake")
ap.add_argument("--save", default="")
ap.add_argument("--school", default="", help="arcane, fire or frost: light the orb in that tree's school colour")
ap.add_argument("--layer", default="", help="bake one in-game layer: " + ", ".join(sorted(["vessel", "light", "glass", "core", "meniscus", "clear", "barrage", "heat", "rime1", "rime2"])))
ap.add_argument("--re", type=float, default=0.0, help="the glass's radius in opening radii, over the race's own")
ap.add_argument("--cells", type=int, default=16, help="frames in a layer's loop")
ap.add_argument("--seconds", type=float, default=1.6, help="a layer loop's length")
args = ap.parse_args(argv)
RACE = args.race
REPO = Path(args.repo)
OUT = Path(args.out)
OUT.mkdir(parents=True, exist_ok=True)

FPS, DUR = 24, 12.0
NFR = int(FPS * DUR)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def srgb(hexv):
    def lin(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return tuple(lin(int(hexv[i:i + 2], 16) / 255.0) for i in (0, 2, 4)) + (1.0,)


MAGE = "3fc7eb"      # the mage's class colour (Core/Appearance.lua)
ARCANE = "e07bff"    # schoolArcane (Core/Tokens.lua)
FIRE = "ff7a1a"
FROST = "6fd6ff"     # schoolFrost
SCHOOL = {"clearcasting": ARCANE, "missile": ARCANE, "heat1": FIRE, "heat2": FIRE, "heat3": FIRE, "heating": FIRE,
          "fingers": FROST, "fingers1": FROST}
RACES = {
    "human": dict(re=0.78, ramp=["000000", "04102e", "0d3f86", MAGE, "b4f0ff", "ffffff"], accent="f3dca4",
                  twist=2.2, scale=2.4, rim="9fe6ff", deep="050b18"),
    "gnome": dict(re=0.72, ramp=["000000", "031a2a", "0b5a80", MAGE, "c9f7ff", "ffffff"], accent="fff0a0",
                  twist=2.8, scale=2.8, rim="b8f2ff", deep="040d14"),
    "orc": dict(re=0.74, ramp=["000000", "120a1c", "153d70", MAGE, "d6f5ff", "ffffff"], accent="ff6a20",
                twist=1.8, scale=2.2, rim="9fe6ff", deep="0e0606"),
    "scourge": dict(re=0.76, ramp=["000000", "120626", "26307e", MAGE, "c8f0ff", "ffffff"], accent="8dff6a",
                    twist=2.4, scale=2.3, rim="b8b0ff", deep="0a0612"),
    "troll": dict(re=0.74, ramp=["000000", "021c22", "0a5664", MAGE, "c4fff6", "ffffff"], accent="4dffb8",
                  twist=2.6, scale=2.5, rim="8ff7e8", deep="041012"),
    "skyborne": dict(re=0.74, ramp=["000000", "081428", "2c6aa8", "7fd8f5", "e6faff", "ffffff"], accent="ffffff",
                     twist=3.4, scale=2.1, rim="e6f6ff", deep="08101c"),
}
R = dict(RACES[RACE])
# the light in each tree's school colour (Core/Tokens.lua schoolArcane, schoolFire, schoolFrost); the race keeps its vessel,
# its swirl and its accent
SCHOOLS = {"arcane": (ARCANE, ["000000", "160428", "4a1a8a", ARCANE, "f2d6ff", "ffffff"], "f3dca4"),
           "fire": (FIRE, ["000000", "260600", "8a2604", FIRE, "ffd890", "fffbf0"], "ffd060"),
           "frost": (FROST, ["000000", "021a2e", "0b5a80", FROST, "d6f8ff", "ffffff"], "e6fbff")}
LIGHT = MAGE
if args.school:
    LIGHT, R["ramp"], R["accent"] = SCHOOLS[args.school]
if args.re:
    R["re"] = args.re
RE = R["re"]


def ease(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


def lerp(a, b, x):
    return a + (b - a) * x


# ----------------------------------------------------------------------------------------------- the story
BASE = dict(level=1.0, power=0.34, speed=0.05, star=0.35, sharp=5.0, accent=0.2, glyph=0.0, spin=0.015, men=0.0, light=0.6,
            clear=0.0, bolts=0.0, fire=0.0, fh=1.0, rime=0.0, arcs=0.0, rays=0.0)
IDLE = dict(BASE)
CHARGE = dict(BASE, level=0.04, power=0.58, speed=0.10, star=0.22, sharp=5.0, accent=0.35, glyph=0.15, spin=0.22, men=1.0, light=0.7)
READY = dict(BASE, power=0.64, speed=0.13, star=1.3, sharp=5.5, accent=0.45, glyph=0.6, spin=0.05, light=1.0, rays=0.22, arcs=0.05)
PROC_BASE = dict(READY, power=0.68, speed=0.30, star=1.6, sharp=7.0, accent=0.8, glyph=1.0, spin=0.3, light=1.4, rays=0.55, arcs=0.6)
PROCS = {
    "clearcasting": dict(PROC_BASE, clear=1.0),
    "missile": dict(PROC_BASE, bolts=1.0, clear=0.25),
    "heat1": dict(PROC_BASE, power=0.6, fire=0.95, fh=0.36, arcs=0.15, rays=0.25, speed=0.18, star=1.3),
    "heat2": dict(PROC_BASE, power=0.58, fire=1.0, fh=0.66, arcs=0.3, rays=0.4, speed=0.24, star=1.45),
    "heat3": dict(PROC_BASE, fire=1.0, fh=1.0, power=0.55),
    "fingers": dict(PROC_BASE, rime=1.0, power=0.6, speed=0.16),
    "fingers1": dict(PROC_BASE, rime=0.5, power=0.62, speed=0.14, rays=0.35, arcs=0.3),
}


def mix(a, b, x):
    return {k: lerp(a[k], b[k], x) for k in a}


def wave(t, start, length, r0, r1, amp, key):
    if start <= t < start + length:
        u = (t - start) / length
        return [(lerp(r0, r1, 1 - (1 - u) ** 2), amp * (1 - u) ** 1.5, key)]
    return []


def flash_at(t, start, length, amp):
    return amp * (1 - (t - start) / length) ** 2 if start <= t < start + length else 0.0


def stepped(t, steps, prev):
    """Walk a list of (start, state) steps, easing 0.25 s into each."""
    s, last = dict(prev), prev
    for start, st in steps:
        if t >= start:
            s = mix(last, st, ease((t - start) / 0.25))
            last = st
    return s, last


def proc_steps(proc, t0):
    if proc == "heating":  # Heating Up: one third of fire per stack, the orb erupts at three
        return [(t0, PROCS["heat1"]), (t0 + 0.6, PROCS["heat2"]), (t0 + 1.2, PROCS["heat3"])], t0 + 1.2
    if proc == "fingers":  # Fingers of Frost: two charges of rime, one spent
        return [(t0, PROCS["fingers"]), (t0 + 1.3, PROCS["fingers1"])], t0
    return [(t0, PROCS[proc])], t0


def story_race(t, proc):
    steps, big = proc_steps(proc, 9.0)
    P = steps[-1][1]
    if t < 2.0:
        s = dict(IDLE)
    elif t < 2.5:  # the signature cooldown is cast: the light discharges
        x = (t - 2.0) / 0.5
        s = mix(IDLE, CHARGE, ease(x))
        s["level"] = lerp(1.0, CHARGE["level"], ease(x))
        s["power"] = lerp(1.4, CHARGE["power"], ease(x))
        s["men"] = ease(x)
        s["arcs"] = 0.8 * (1 - x)
    elif t < 6.5:  # charging: the cooldown recovers linearly, as the engine's duration does
        x = (t - 2.5) / 4.0
        s = dict(CHARGE)
        s["level"] = lerp(CHARGE["level"], 1.0, x)
        s["star"] = lerp(0.22, 0.5, x)
        s["glyph"] = lerp(0.1, 0.4, x)
        s["men"] = 1.0 if x < 0.97 else (1 - x) / 0.03
    elif t < 9.0:  # ready
        s = mix(CHARGE, READY, ease((t - 6.5) / 0.5))
        s["level"] = 1.0
        s["men"] = 0.0
        s["star"] = READY["star"] + 0.8 * max(0.0, 1 - (t - 6.5) / 0.6)
    elif t < 11.0:  # the proc
        s, _ = stepped(t, steps, READY)
    else:  # spent: settle to rest
        s = mix(P, IDLE, ease((t - 11.0) / 1.0))
    sc = SCHOOL.get(proc, ARCANE)
    s["waves"] = (wave(t, 2.0, 0.45, 0.25, 1.0, 0.6, MAGE) + wave(t, 6.5, 0.7, 0.3, 1.32, 1.0, MAGE)
                  + wave(t, big, 0.55, 0.2, 1.45, 1.3, sc) + wave(t, big + 0.2, 0.65, 0.2, 1.38, 0.7, "ffffff"))[:2]
    s["flash"] = (flash_at(t, 2.0, 0.35, 0.7) + flash_at(t, 6.5, 0.45, 0.8) + flash_at(t, 9.0, 0.4, 0.8)
                  + (flash_at(t, big, 0.4, 1.0) if big > 9.0 else 0.0))
    s["school"] = sc
    return s


GALLERY = [("clearcasting", 0.2, [(0.2, "clearcasting")], 2.2), ("missile", 2.6, [(2.6, "missile")], 4.6),
           ("heating", 5.0, [(5.0, "heat1"), (5.6, "heat2"), (6.2, "heat3")], 7.6),
           ("fingers", 8.0, [(8.0, "fingers"), (9.2, "fingers1")], 10.2)]


def story_procs(t):
    """Every proc in turn over a ready orb."""
    s = dict(READY)
    sc = ARCANE
    waves, flash = [], 0.0
    for kind, a, steps, b in GALLERY:
        sc_k = SCHOOL[kind]
        st = [(x, PROCS[k]) for x, k in steps]
        if a <= t < b + 0.3:
            s, last = stepped(t, st, READY)
            if t >= b:
                s = mix(last, READY, ease((t - b) / 0.3))
            sc = sc_k
        for x, k in steps:
            big = k in ("clearcasting", "missile", "heat3", "fingers")
            waves += wave(t, x, 0.55, 0.2, 1.45, 1.2 if big else 0.6, sc_k)
            flash += flash_at(t, x, 0.4, 0.9 if big else 0.35)
    s["waves"] = waves[:2]
    s["flash"] = flash
    s["school"] = sc
    return s


def story(t):
    return story_procs(t) if args.story == "procs" else story_race(t, args.proc)


# the preview's 12 s timeline; a layer bake (--layer) renders its own fixed states and never reads it
STATES = []
phase = spin = turn = 0.0
for f in range(0 if args.layer else NFR):
    t = f / FPS
    s = story(t)
    phase += s["speed"] / FPS
    spin += s["spin"] / FPS
    turn += (0.011 + 0.03 * s["glyph"]) / FPS
    s.update(t=t, phase=phase, spinA=spin * 2 * math.pi, turn=turn * 2 * math.pi)
    STATES.append(s)

# ----------------------------------------------------------------------------------------------- node helpers
class Graph:
    def __init__(self, mat):
        mat.use_nodes = True
        self.nt = mat.node_tree
        self.N = self.nt.nodes
        self.L = self.nt.links
        for n in list(self.N):
            self.N.remove(n)
        self.values = {}

    def node(self, kind, **props):
        n = self.N.new(kind)
        for k, v in props.items():
            setattr(n, k, v)
        return n

    def feed(self, sock, v):
        if isinstance(v, (int, float)):
            sock.default_value = v
        elif isinstance(v, tuple):
            sock.default_value = v
        else:
            self.L.new(v, sock)

    def m(self, op, a, b=None, clamp=False):
        n = self.node("ShaderNodeMath", operation=op, use_clamp=clamp)
        self.feed(n.inputs[0], a)
        if b is not None:
            self.feed(n.inputs[1], b)
        return n.outputs[0]

    def v(self, op, a, b=None, scale=None):
        n = self.node("ShaderNodeVectorMath", operation=op)
        self.feed(n.inputs[0], a)
        if b is not None:
            self.feed(n.inputs[1], b)
        if scale is not None:
            self.feed(n.inputs["Scale"], scale)
        return n.outputs["Value" if op in ("LENGTH", "DOT_PRODUCT", "DISTANCE") else "Vector"]

    def xyz(self, x, y, z=0.0):
        n = self.node("ShaderNodeCombineXYZ")
        self.feed(n.inputs[0], x)
        self.feed(n.inputs[1], y)
        self.feed(n.inputs[2], z)
        return n.outputs[0]

    def sep(self, vec):
        n = self.node("ShaderNodeSeparateXYZ")
        self.feed(n.inputs[0], vec)
        return n.outputs

    def smooth(self, x, lo, hi):
        n = self.node("ShaderNodeMapRange", interpolation_type="SMOOTHSTEP", clamp=True)
        self.feed(n.inputs["Value"], x)
        self.feed(n.inputs["From Min"], lo)
        self.feed(n.inputs["From Max"], hi)
        return n.outputs["Result"]

    def value(self, name, v=0.0):
        n = self.node("ShaderNodeValue")
        n.outputs[0].default_value = v
        self.values[name] = n
        return n.outputs[0]

    def rgb(self, hexv):
        n = self.node("ShaderNodeRGB")
        n.outputs[0].default_value = srgb(hexv)
        return n.outputs[0]

    def mixc(self, fac, a, b):
        n = self.node("ShaderNodeMix", data_type="RGBA", blend_type="MIX")
        self.feed(n.inputs["Factor"], fac)
        self.feed(n.inputs[6], a)
        self.feed(n.inputs[7], b)
        return n.outputs[2]

    def addc(self, a, b):
        n = self.node("ShaderNodeMix", data_type="RGBA", blend_type="ADD")
        n.inputs["Factor"].default_value = 1.0
        self.feed(n.inputs[6], a)
        self.feed(n.inputs[7], b)
        return n.outputs[2]

    def scalec(self, c, f):
        n = self.node("ShaderNodeMix", data_type="RGBA", blend_type="MULTIPLY")
        n.inputs["Factor"].default_value = 1.0
        self.feed(n.inputs[6], c)
        g = self.node("ShaderNodeCombineColor")
        self.feed(g.inputs[0], f)
        self.feed(g.inputs[1], f)
        self.feed(g.inputs[2], f)
        self.L.new(g.outputs[0], n.inputs[7])
        return n.outputs[2]

    def ramp(self, fac, stops):
        n = self.node("ShaderNodeValToRGB")
        els = n.color_ramp.elements
        while len(els) < len(stops):
            els.new(0.5)
        for el, (pos, hexv) in zip(els, stops):
            el.position = pos
            el.color = srgb(hexv)
        self.feed(n.inputs["Fac"], fac)
        return n.outputs["Color"]

    def additive(self, color, strength=1.0):
        e = self.node("ShaderNodeEmission")
        self.feed(e.inputs["Color"], color)
        self.feed(e.inputs["Strength"], strength)
        tr = self.node("ShaderNodeBsdfTransparent")
        add = self.node("ShaderNodeAddShader")
        self.L.new(e.outputs[0], add.inputs[0])
        self.L.new(tr.outputs[0], add.inputs[1])
        out = self.node("ShaderNodeOutputMaterial")
        self.L.new(add.outputs[0], out.inputs["Surface"])

    def emissive(self, color, strength=1.0):
        e = self.node("ShaderNodeEmission")
        self.feed(e.inputs["Color"], color)
        self.feed(e.inputs["Strength"], strength)
        out = self.node("ShaderNodeOutputMaterial")
        self.L.new(e.outputs[0], out.inputs["Surface"])


GRAPHS = []


def material(name, blended=True, cull=True):
    mat = bpy.data.materials.new(name)
    mat.surface_render_method = "BLENDED" if blended else "DITHERED"
    mat.use_backface_culling = cull
    g = Graph(mat)
    GRAPHS.append(g)
    return mat, g


def metal(name, base, rough=0.35, metallic=1.0, noise=0.0, emit=None):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = srgb(base)
    b.inputs["Metallic"].default_value = metallic
    b.inputs["Roughness"].default_value = rough
    if noise:
        tex = nt.nodes.new("ShaderNodeTexNoise")
        tex.inputs["Scale"].default_value = 18.0
        tex.inputs["Detail"].default_value = 6.0
        rmp = nt.nodes.new("ShaderNodeMapRange")
        rmp.inputs["To Min"].default_value = rough - noise
        rmp.inputs["To Max"].default_value = rough + noise
        nt.links.new(tex.outputs["Fac"], rmp.inputs["Value"])
        nt.links.new(rmp.outputs["Result"], b.inputs["Roughness"])
    if emit:
        b.inputs["Emission Color"].default_value = srgb(emit[0])
        b.inputs["Emission Strength"].default_value = emit[1]
    return mat


# ----------------------------------------------------------------------------------------------- mesh helpers
def link(ob):
    scene.collection.objects.link(ob)
    return ob


def mesh_obj(name, build, mat=None, smooth=True):
    bm = bmesh.new()
    build(bm)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = smooth
    ob = link(bpy.data.objects.new(name, me))
    if mat:
        ob.data.materials.append(mat)
    return ob


def uvsphere(name, r, mat, segs=96, rings=48):
    return mesh_obj(name, lambda bm: bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=r), mat)


def torus(name, Rm, rm, mat, segs=160, rsegs=20, loc=(0, 0, 0), rot=(0, 0, 0), smooth=True):
    def build(bm):
        verts = []
        for i in range(segs):
            a = 2 * math.pi * i / segs
            ring = []
            for j in range(rsegs):
                b = 2 * math.pi * j / rsegs
                x = (Rm + rm * math.cos(b)) * math.cos(a)
                y = (Rm + rm * math.cos(b)) * math.sin(a)
                z = rm * math.sin(b)
                ring.append(bm.verts.new((x, y, z)))
            verts.append(ring)
        for i in range(segs):
            for j in range(rsegs):
                bm.faces.new((verts[i][j], verts[(i + 1) % segs][j], verts[(i + 1) % segs][(j + 1) % rsegs], verts[i][(j + 1) % rsegs]))
    ob = mesh_obj(name, build, mat, smooth)
    ob.location = loc
    ob.rotation_euler = rot
    return ob


def disc(name, r, mat, segs=128, z=0.0, inner=0.0):
    def build(bm):
        if inner <= 0:
            bmesh.ops.create_circle(bm, cap_ends=True, segments=segs, radius=r)
        else:
            outer = [bm.verts.new((r * math.cos(2 * math.pi * i / segs), r * math.sin(2 * math.pi * i / segs), 0)) for i in range(segs)]
            inn = [bm.verts.new((inner * math.cos(2 * math.pi * i / segs), inner * math.sin(2 * math.pi * i / segs), 0)) for i in range(segs)]
            for i in range(segs):
                bm.faces.new((inn[i], outer[i], outer[(i + 1) % segs], inn[(i + 1) % segs]))
    ob = mesh_obj(name, build, mat, True)
    ob.location.z = z
    return ob


def plane(name, size, mat, z):
    def build(bm):
        uv = bm.loops.layers.uv.new("UVMap")
        bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=size / 2)
        for f in bm.faces:
            for lp in f.loops:
                co = lp.vert.co
                lp[uv].uv = (co.x / size + 0.5, co.y / size + 0.5)
    ob = mesh_obj(name, build, mat, True)
    ob.location.z = z
    return ob


def tube(name, pts, mat, bevel=0.02, res=24, closed=False, taper=None):
    """A bevelled curve through pts [(x,y,z[,radius])]."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = bevel
    cu.bevel_resolution = 6
    cu.resolution_u = res
    cu.use_fill_caps = True
    sp = cu.splines.new("BEZIER")
    sp.bezier_points.add(len(pts) - 1)
    for bp, p in zip(sp.bezier_points, pts):
        bp.co = p[:3]
        bp.handle_left_type = bp.handle_right_type = "AUTO"
        bp.radius = p[3] if len(p) > 3 else 1.0
    sp.use_cyclic_u = closed
    ob = link(bpy.data.objects.new(name, cu))
    ob.data.materials.append(mat)
    return ob


def cone(name, r1, r2, depth, mat, segs=24, loc=(0, 0, 0), direction=(0, 0, 1), smooth=True):
    def build(bm):
        bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r1, radius2=r2, depth=depth)
    ob = mesh_obj(name, build, mat, smooth)
    d = Vector(direction).normalized()
    ob.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    ob.location = Vector(loc) + d * depth / 2
    return ob


def ico(name, r, mat, loc=(0, 0, 0), sub=2, smooth=True):
    ob = mesh_obj(name, lambda bm: bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r), mat, smooth)
    ob.location = loc
    return ob


def no_shadow(*obs):
    for o in obs:
        o.visible_shadow = False


SPINNERS = []  # (object, axis, rate, base Euler)
# ----------------------------------------------------------------------------------------------- the hub around the orb
def image_plane(name, file, size, z, mode, colour=None, base=1.0):
    mat, g = material(name)
    img = bpy.data.images.load(str(REPO / file))
    tex = g.node("ShaderNodeTexImage", image=img, interpolation="Cubic", extension="CLIP")
    g.L.new(g.node("ShaderNodeTexCoord").outputs["UV"], tex.inputs["Vector"])
    a = tex.outputs["Alpha"]
    if mode == "over":
        e = g.node("ShaderNodeEmission")
        if colour:
            g.L.new(g.mixc(1.0, tex.outputs["Color"], g.rgb(colour)), e.inputs["Color"])
            a = g.m("MULTIPLY", a, base)
        else:
            g.L.new(tex.outputs["Color"], e.inputs["Color"])
        tr = g.node("ShaderNodeBsdfTransparent")
        mx = g.node("ShaderNodeMixShader")
        g.feed(mx.inputs[0], a)
        g.L.new(tr.outputs[0], mx.inputs[1])
        g.L.new(e.outputs[0], mx.inputs[2])
        out = g.node("ShaderNodeOutputMaterial")
        g.L.new(mx.outputs[0], out.inputs["Surface"])
    else:  # the texture added in a colour, as the hub's ADD layers draw
        amt = g.value("amt", base)
        c = g.scalec(g.mixc(0.0, g.rgb(colour), g.rgb(colour)), g.m("MULTIPLY", g.m("MULTIPLY", a, tex.outputs["Color"]), amt))
        g.additive(c)
    ob = plane(name, size, mat, z)
    no_shadow(ob)
    return ob, g


HUB = 150.0 / 118.0  # the ring's outer radius in opening radii (Slab.lua: ring 150, opening 118)
backdrop_mat, bg = material("Backdrop", blended=False)
tc = bg.node("ShaderNodeTexCoord").outputs["Object"]
rr = bg.v("LENGTH", tc)
bg.emissive(bg.mixc(bg.smooth(rr, 0.5, 2.4), bg.rgb("1a1d24"), bg.rgb("07080a")))
backdrop = plane("Backdrop", 8.0, backdrop_mat, -4.0)
no_shadow(backdrop)
hub_glow_mat, hg = material("HubGlow")
tcg = hg.node("ShaderNodeTexCoord").outputs["Object"]
rg = hg.v("LENGTH", tcg)
hub_glow_amt = hg.value("amt", 0.3)
hg.additive(hg.scalec(hg.rgb(MAGE), hg.m("MULTIPLY", hg.m("EXPONENT", hg.m("MULTIPLY", hg.m("MULTIPLY", rg, rg), -1.6)), hub_glow_amt)))
hub_glow = plane("HubGlow", 4.4, hub_glow_mat, -3.0)
no_shadow(hub_glow)
# the crest's ring, enamel and rune glyphs frame the preview only; a layer bake draws the orb alone
if not (args.noring or args.layer):
    ring, _ = image_plane("Ring", "Media/Textures/Medallions/Ring256.png", 2 * HUB, -0.3, "over")
    enamel, _ = image_plane("Enamel", "Media/Textures/Medallions/Enamel256.png", 2 * HUB, -0.29, "over", MAGE, 0.35)
    glyphs, glyph_g = image_plane("RuneGlyphs", "Media/Textures/Medallions/RuneGlyphs.png", 2 * HUB, -0.28, "add", MAGE, 0.25)
else:
    ring = enamel = glyphs = glyph_g = None
    backdrop.hide_render = True
    hub_glow.hide_render = True

# ----------------------------------------------------------------------------------------------- the orb
back_mat, bk = material("Back", blended=False, cull=False)
tcb = bk.node("ShaderNodeTexCoord").outputs["Object"]
rb = bk.v("LENGTH", tcb)
bk.emissive(bk.mixc(bk.smooth(rb, 0.0, 1.0), bk.rgb(R["deep"]), bk.rgb("010203")))
back = disc("BackGlass", RE * 1.005, back_mat, z=-1.6)
no_shadow(back)

# the light: a surface shader that marches six slices through the sphere behind each front point
energy_mat, eg = material("Energy")
P = eg.node("ShaderNodeTexCoord").outputs["Object"]
px, py, pz = eg.sep(P)
level = eg.value("level", 1.0)
power = eg.value("power", 1.0)
phs = eg.value("phase", 0.0)
sharp = eg.value("sharp", 5.0)
acc_amt = eg.value("accent", 0.3)
men = eg.value("men", 0.0)
clear = eg.value("clear", 0.0)
fire = eg.value("fire", 0.0)
fh = eg.value("fh", 1.0)  # how high the fire stands: one third per Heating Up stack
t_abs = eg.value("time", 0.0)
lvl_y = eg.m("SUBTRACT", eg.m("MULTIPLY", level, 2.08), 1.04)  # 0..1 to the sphere's -1..1
ang = eg.m("MULTIPLY", phs, 2 * math.pi)
surf = eg.m("MULTIPLY", eg.m("SINE", eg.m("ADD", eg.m("MULTIPLY", px, 7.0), eg.m("MULTIPLY", ang, 3.0))), 0.018)
yy = eg.m("ADD", py, surf)
fillm = eg.m("SUBTRACT", 1.0, eg.smooth(eg.m("SUBTRACT", yy, lvl_y), -0.02, 0.02))
fh_y = eg.m("SUBTRACT", eg.m("MULTIPLY", fh, 2.3), 1.15)
fmask = eg.m("SUBTRACT", 1.0, eg.smooth(eg.m("SUBTRACT", eg.m("ADD", yy, eg.m("MULTIPLY", surf, 3.0)), fh_y), -0.12, 0.06))
NS = 6
acc_d = acc_a = acc_f = None
for k in range(NS):
    zk = eg.m("MULTIPLY", pz, 1 - 2 * (k + 0.5) / NS)
    pk = eg.xyz(px, py, zk)
    r = eg.v("LENGTH", pk)
    inner = eg.m("SUBTRACT", 1.0, r)
    rot = eg.node("ShaderNodeVectorRotate", rotation_type="Y_AXIS")
    eg.feed(rot.inputs["Vector"], pk)
    eg.feed(rot.inputs["Angle"], eg.m("ADD", ang, eg.m("MULTIPLY", inner, R["twist"])))
    rot2 = eg.node("ShaderNodeVectorRotate", rotation_type="Z_AXIS")
    eg.L.new(rot.outputs[0], rot2.inputs["Vector"])
    eg.feed(rot2.inputs["Angle"], eg.m("ADD", eg.m("MULTIPLY", ang, 0.35), eg.m("MULTIPLY", inner, R["twist"] * 0.6)))
    n = eg.node("ShaderNodeTexNoise", noise_dimensions="4D")
    eg.L.new(rot2.outputs[0], n.inputs["Vector"])
    eg.feed(n.inputs["W"], eg.m("MULTIPLY", phs, 0.6))
    n.inputs["Scale"].default_value = R["scale"]
    n.inputs["Detail"].default_value = 3.0
    n.inputs["Roughness"].default_value = 0.55
    n.inputs["Distortion"].default_value = 0.35
    ridge = eg.m("SUBTRACT", 1.0, eg.m("ABSOLUTE", eg.m("SUBTRACT", eg.m("MULTIPLY", n.outputs["Fac"], 2.0), 1.0)))
    fil = eg.m("POWER", ridge, sharp)
    body = eg.smooth(n.outputs["Fac"], 0.42, 0.85)
    core = eg.m("EXPONENT", eg.m("MULTIPLY", eg.m("MULTIPLY", r, r), -14.0))
    dens = eg.m("ADD", eg.m("MULTIPLY", fil, 1.25), eg.m("ADD", eg.m("MULTIPLY", body, 0.32), eg.m("MULTIPLY", core, 0.7)))
    lvl_k = eg.m("SUBTRACT", 1.0, eg.smooth(eg.m("SUBTRACT", yy, lvl_y), -0.02, 0.02))
    dens = eg.m("MULTIPLY", dens, eg.m("ADD", eg.m("MULTIPLY", lvl_k, 0.95), 0.05))
    # accent: a second, finer field, sparks or wisps in the race's colour
    n2 = eg.node("ShaderNodeTexNoise", noise_dimensions="4D")
    eg.L.new(rot2.outputs[0], n2.inputs["Vector"])
    eg.feed(n2.inputs["W"], eg.m("ADD", eg.m("MULTIPLY", phs, 1.1), 7.3))
    n2.inputs["Scale"].default_value = R["scale"] * 2.4
    n2.inputs["Detail"].default_value = 2.0
    ad = eg.m("MULTIPLY", eg.smooth(n2.outputs["Fac"], 0.64, 0.74), lvl_k)
    # fire: tongues rising through the orb, a flame noise scrolling upward
    fv = eg.v("ADD", eg.v("MULTIPLY", pk, (2.2, 1.3, 2.2)), eg.xyz(0.0, eg.m("MULTIPLY", t_abs, -1.6), 0.0))
    fn = eg.node("ShaderNodeTexNoise", noise_dimensions="4D")
    eg.L.new(fv, fn.inputs["Vector"])
    eg.feed(fn.inputs["W"], eg.m("MULTIPLY", t_abs, 0.7))
    fn.inputs["Scale"].default_value = 2.2
    fn.inputs["Detail"].default_value = 4.0
    fn.inputs["Distortion"].default_value = 0.8
    rise = eg.smooth(eg.m("SUBTRACT", eg.m("MULTIPLY", fn.outputs["Fac"], 1.6), eg.m("MULTIPLY", eg.m("ADD", py, 1.0), 0.3)), 0.3, 0.72)
    acc_d = dens if acc_d is None else eg.m("ADD", acc_d, dens)
    acc_a = ad if acc_a is None else eg.m("ADD", acc_a, ad)
    acc_f = rise if acc_f is None else eg.m("ADD", acc_f, rise)
avg = eg.m("DIVIDE", acc_d, NS)
total = eg.m("MULTIPLY", avg, power)
band = eg.m("EXPONENT", eg.m("MULTIPLY", eg.m("POWER", eg.m("DIVIDE", eg.m("SUBTRACT", yy, lvl_y), 0.03), 2.0), -1.0))
total = eg.m("ADD", total, eg.m("MULTIPLY", band, eg.m("MULTIPLY", men, 0.75)))
stops = R["ramp"]
col = eg.ramp(eg.m("MINIMUM", total, 1.0), list(zip((0.0, 0.1, 0.28, 0.5, 0.76, 1.0), stops)))
acol = eg.scalec(eg.rgb(R["accent"]), eg.m("MULTIPLY", eg.m("DIVIDE", acc_a, NS), eg.m("MULTIPLY", acc_amt, 1.8)))
col = eg.addc(col, acol)
# clearcasting: the light turns clear, white and arcane violet, glittering
spark = eg.node("ShaderNodeTexVoronoi", voronoi_dimensions="4D", feature="F1")
eg.L.new(P, spark.inputs["Vector"])
eg.feed(spark.inputs["W"], eg.m("MULTIPLY", t_abs, 2.5))
spark.inputs["Scale"].default_value = 22.0
glit = eg.m("MULTIPLY", eg.m("SUBTRACT", 1.0, eg.smooth(spark.outputs["Distance"], 0.0, 0.06)), fillm)
clr = eg.addc(eg.scalec(eg.ramp(eg.m("MINIMUM", eg.m("MULTIPLY", avg, 1.15), 1.0), [(0.0, "000000"), (0.3, "4a1a7a"), (0.6, ARCANE), (0.85, "f4dcff"), (1.0, "ffffff")]), 1.0),
              eg.scalec(eg.rgb("ffffff"), glit))
col = eg.mixc(eg.m("MULTIPLY", clear, 0.7), col, clr)
col = eg.addc(col, eg.scalec(clr, eg.m("MULTIPLY", clear, 0.15)))
# hot streak: fire floods up through the light
fcol = eg.ramp(eg.m("MINIMUM", eg.m("MULTIPLY", eg.m("DIVIDE", acc_f, NS), 1.3), 1.0),
               [(0.0, "000000"), (0.25, "4a0800"), (0.5, "d43a06"), (0.72, FIRE), (0.88, "ffd060"), (1.0, "fff6e0")])
fire_m = eg.m("MULTIPLY", fire, fmask)
col = eg.mixc(eg.m("MULTIPLY", fire_m, 0.7), col, fcol)
col = eg.addc(col, eg.scalec(fcol, eg.m("MULTIPLY", fire_m, 0.3)))
eg.additive(col)
energy = uvsphere("Energy", 1.0, energy_mat)
energy.scale = (RE, RE, RE)
no_shadow(energy)

# the glass: a rim in the class colour, a crisp window and a crescent, a caustic at the foot, frost when Fingers of Frost is up
glass_mat, gg = material("Glass")
Nw = gg.node("ShaderNodeNewGeometry").outputs["Normal"]
Pg = gg.node("ShaderNodeTexCoord").outputs["Object"]
lw = gg.node("ShaderNodeLayerWeight")
lw.inputs["Blend"].default_value = 0.35
rim_amt = gg.value("rim", 0.5)
rime = gg.value("rime", 0.0)
gt = gg.value("time", 0.0)
facing = lw.outputs["Facing"]
fres = gg.m("POWER", facing, 2.6)
hl_dir = Vector((-0.42, 0.55, 0.72)).normalized()
d1 = gg.v("DOT_PRODUCT", Nw, tuple(hl_dir))
hl = gg.m("ADD", gg.m("MULTIPLY", gg.smooth(d1, 0.9955, 0.998), 0.95), gg.m("MULTIPLY", gg.smooth(d1, 0.8, 0.995), 0.05))
cres = gg.m("MULTIPLY", gg.m("MULTIPLY", gg.smooth(facing, 0.55, 0.7), gg.m("SUBTRACT", 1.0, gg.smooth(facing, 0.78, 0.9))), gg.smooth(d1, 0.55, 0.8))
hl = gg.m("ADD", hl, gg.m("MULTIPLY", cres, 0.35))
d2 = gg.v("DOT_PRODUCT", Nw, tuple(Vector((0.35, -0.62, 0.70)).normalized()))
caus = gg.m("MULTIPLY", gg.smooth(d2, 0.86, 0.985), 0.35)
c = gg.addc(gg.scalec(gg.rgb(R["rim"]), gg.m("MULTIPLY", fres, rim_amt)), gg.scalec(gg.rgb("ffffff"), hl))
c = gg.addc(c, gg.scalec(gg.rgb(LIGHT), gg.m("MULTIPLY", caus, rim_amt)))
crystal = gg.node("ShaderNodeTexVoronoi", feature="DISTANCE_TO_EDGE")
crystal.inputs["Scale"].default_value = 7.0
gg.L.new(gg.v("MULTIPLY", Pg, (1.0, 1.0, 1.0)), crystal.inputs["Vector"])
veins = gg.m("SUBTRACT", 1.0, gg.smooth(crystal.outputs["Distance"], 0.0, 0.07))
grow = gg.m("SUBTRACT", 1.0, gg.m("MULTIPLY", rime, 0.62))
rmask = gg.smooth(gg.m("ADD", facing, gg.m("MULTIPLY", veins, 0.12)), grow, gg.m("ADD", grow, 0.12))
frost = gg.scalec(gg.mixc(veins, gg.rgb("4fb8e8"), gg.rgb("f2fcff")), gg.m("MULTIPLY", rmask, gg.m("ADD", 0.35, gg.m("MULTIPLY", veins, 0.65))))
glint = gg.node("ShaderNodeTexNoise", noise_dimensions="4D")
gg.L.new(Pg, glint.inputs["Vector"])
gg.feed(glint.inputs["W"], gg.m("MULTIPLY", gt, 0.9))
glint.inputs["Scale"].default_value = 9.0
shimmer = gg.m("ADD", 0.7, gg.m("MULTIPLY", gg.smooth(glint.outputs["Fac"], 0.45, 0.75), 0.7))
c = gg.addc(c, gg.scalec(frost, gg.m("MULTIPLY", rime, shimmer)))
gg.additive(c)
glass = uvsphere("Glass", RE * 1.012, glass_mat)
no_shadow(glass)

# the class at the heart: an arcane crystal star in two orbit rings, as the painted crests carry it
def star_mesh(bm):
    spikes = [((1, 0, 0), 1.0), ((-1, 0, 0), 1.0), ((0, 1, 0), 1.0), ((0, -1, 0), 1.0), ((0, 0, 1), 1.0), ((0, 0, -1), 1.0)]
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                spikes.append(((sx, sy, sz), 0.55))
    for d, ln in spikes:
        d = Vector(d).normalized()
        tip = d * ln
        side = d.orthogonal().normalized()
        up = d.cross(side).normalized()
        w = 0.16 if ln > 0.9 else 0.12
        base = [bm.verts.new(tuple(d * 0.12 + (side * math.cos(a) + up * math.sin(a)) * w)) for a in (0, math.pi / 2, math.pi, 1.5 * math.pi)]
        t = bm.verts.new(tuple(tip))
        for i in range(4):
            bm.faces.new((base[i], base[(i + 1) % 4], t))
        bm.faces.new(tuple(reversed(base)))


star_mat, sg = material("Star", blended=False, cull=False)
lws = sg.node("ShaderNodeLayerWeight")
lws.inputs["Blend"].default_value = 0.5
sb = sg.value("star", 1.0)
face = sg.m("POWER", lws.outputs["Facing"], 0.8)
scol = sg.ramp(sg.m("MINIMUM", sg.m("MULTIPLY", sg.m("ADD", sg.m("MULTIPLY", sg.m("SUBTRACT", 1.0, face), 0.7), 0.3), sb), 1.0),
               [(0.0, "02141c"), (0.35, "167fa8"), (0.6, LIGHT), (0.85, "c9f7ff"), (1.0, "ffffff")])
sstr = sg.m("ADD", 1.0, sg.m("MULTIPLY", sg.m("MAXIMUM", sg.m("SUBTRACT", sb, 0.8), 0.0), 1.6))
sg.emissive(scol, sstr)
star = mesh_obj("Star", star_mesh, star_mat, smooth=False)
star.scale = (0.2, 0.2, 0.2)
no_shadow(star)

orbit_mat, og = material("Orbit", blended=False)
ob_amt = og.value("amt", 1.0)
og.emissive(og.scalec(og.rgb("f3dca4"), ob_amt), 1.0)
orbits = [torus("OrbitA", 0.3, 0.0055, orbit_mat, rsegs=8, rot=(math.radians(72), 0, math.radians(20))),
          torus("OrbitB", 0.3, 0.0055, orbit_mat, rsegs=8, rot=(math.radians(-64), math.radians(30), math.radians(-35)))]
no_shadow(*orbits)

# motes in the light
mote_mat, mg = material("Mote", blended=True)
mote_amt = mg.value("amt", 1.0)
mg.additive(mg.scalec(mg.rgb(R["accent"]), mote_amt), 1.0)
rng = random.Random(7)
MOTES = []
for i in range(36):
    o = ico(f"Mote{i}", rng.uniform(0.007, 0.015), mote_mat, sub=1)
    no_shadow(o)
    MOTES.append((o, rng.uniform(0.15, 0.95), rng.uniform(0, 2 * math.pi), rng.uniform(-1, 1), rng.uniform(0.4, 1.4), rng.random()))

# Missile Barrage: five arcane missiles circling inside the glass, each with its trail
bolt_mat, bg2 = material("Bolt", blended=True)
bolt_amt = bg2.value("amt", 0.0)
bg2.additive(bg2.scalec(bg2.rgb("f4c0ff"), bolt_amt), 3.0)
BOLTS = []
for i in range(3):
    trail = []
    for j in range(14):
        o = ico(f"Bolt{i}_{j}", 0.05 * (1 - j / 15.0), bolt_mat, sub=2)
        no_shadow(o)
        trail.append(o)
    BOLTS.append(trail)

# shockwaves and the core flash, in front of everything
waves_mat, wg = material("Waves")
Pw = wg.node("ShaderNodeTexCoord").outputs["Object"]
rw = wg.v("LENGTH", Pw)
wc = None
for i in range(2):
    wr = wg.value(f"r{i}", 0.0)
    wa = wg.value(f"a{i}", 0.0)
    ringw = wg.m("EXPONENT", wg.m("MULTIPLY", wg.m("POWER", wg.m("DIVIDE", wg.m("SUBTRACT", rw, wr), 0.04), 2.0), -1.0))
    inner_glow = wg.m("MULTIPLY", wg.m("SUBTRACT", 1.0, wg.smooth(rw, 0.0, wr)), 0.2)
    wcol = wg.node("ShaderNodeRGB", name=f"c{i}")
    wcol.outputs[0].default_value = srgb(MAGE)
    term = wg.scalec(wcol.outputs[0], wg.m("MULTIPLY", wg.m("ADD", ringw, inner_glow), wa))
    wc = term if wc is None else wg.addc(wc, term)
fl = wg.value("flash", 0.0)
core_flash = wg.m("MULTIPLY", wg.m("EXPONENT", wg.m("MULTIPLY", wg.m("MULTIPLY", rw, rw), -7.0)), fl)
wc = wg.addc(wc, wg.scalec(wg.rgb("e8fbff"), core_flash))
# rays and arcs: light streaming out over the ring when ready, lightning when a proc lands
th = wg.m("ARCTAN2", wg.sep(Pw)[1], wg.sep(Pw)[0])
wt = wg.value("time", 0.0)
rays_amt = wg.value("rays", 0.0)
arcs_amt = wg.value("arcs", 0.0)
circ = wg.xyz(wg.m("MULTIPLY", wg.m("COSINE", th), 2.2), wg.m("MULTIPLY", wg.m("SINE", th), 2.2), wg.m("MULTIPLY", wt, 0.25))
rn = wg.node("ShaderNodeTexNoise")
wg.L.new(circ, rn.inputs["Vector"])
rn.inputs["Scale"].default_value = 2.0
rn.inputs["Detail"].default_value = 1.0
rays = wg.m("MULTIPLY", wg.m("POWER", wg.smooth(rn.outputs["Fac"], 0.45, 0.8), 2.0),
            wg.m("MULTIPLY", wg.smooth(rw, RE * 0.9, RE * 1.05), wg.m("EXPONENT", wg.m("MULTIPLY", wg.m("SUBTRACT", rw, RE), -3.2))))
arcv = wg.xyz(wg.m("MULTIPLY", wg.m("COSINE", th), 3.0), wg.m("MULTIPLY", wg.m("SINE", th), 3.0), wg.m("MULTIPLY", rw, 4.0))
an = wg.node("ShaderNodeTexNoise", noise_dimensions="4D")
wg.L.new(arcv, an.inputs["Vector"])
wg.feed(an.inputs["W"], wg.m("MULTIPLY", wt, 3.0))
an.inputs["Scale"].default_value = 1.6
an.inputs["Detail"].default_value = 3.0
an.inputs["Distortion"].default_value = 0.6
aridge = wg.m("SUBTRACT", 1.0, wg.m("ABSOLUTE", wg.m("SUBTRACT", wg.m("MULTIPLY", an.outputs["Fac"], 2.0), 1.0)))
gate = wg.node("ShaderNodeTexNoise", noise_dimensions="4D")
wg.L.new(wg.xyz(wg.m("COSINE", th), wg.m("SINE", th), 0.0), gate.inputs["Vector"])
wg.feed(gate.inputs["W"], wg.m("MULTIPLY", wt, 1.7))
gate.inputs["Scale"].default_value = 1.8
arcs = wg.m("MULTIPLY", wg.m("POWER", aridge, 22.0), wg.smooth(gate.outputs["Fac"], 0.52, 0.62))
arcs = wg.m("MULTIPLY", arcs, wg.m("MULTIPLY", wg.smooth(rw, RE * 0.55, RE * 0.95), wg.m("SUBTRACT", 1.0, wg.smooth(rw, HUB * 0.95, HUB * 1.08))))
sch = wg.node("ShaderNodeRGB", name="school")
sch.outputs[0].default_value = srgb(ARCANE)
wc = wg.addc(wc, wg.scalec(wg.mixc(0.5, wg.rgb(MAGE), sch.outputs[0]), wg.m("MULTIPLY", rays, rays_amt)))
wc = wg.addc(wc, wg.scalec(wg.mixc(0.45, sch.outputs[0], wg.rgb("ffffff")), wg.m("MULTIPLY", arcs, wg.m("MULTIPLY", arcs_amt, 2.2))))
wg.additive(wc)
waves = disc("Waves", 1.75, waves_mat, z=1.5)
no_shadow(waves)

# the orb's own light on its vessel
orb_light = bpy.data.lights.new("OrbLight", "POINT")
orb_light.color = srgb("bfeeff")[:3]
orb_light.shadow_soft_size = 0.35
olo = link(bpy.data.objects.new("OrbLight", orb_light))
olo.location = (0, 0, 0.55)


def area(name, energy, loc, size, colour="ffffff"):
    ld = bpy.data.lights.new(name, "AREA")
    ld.energy = energy
    ld.size = size
    ld.color = srgb(colour)[:3]
    o = link(bpy.data.objects.new(name, ld))
    o.location = loc
    o.rotation_euler = Vector(loc).to_track_quat("Z", "Y").to_euler()
    return o


area("Key", 110, (-2.4, 3.0, 3.6), 2.0, "fff1dc")
area("Fill", 26, (3.2, -1.0, 2.6), 3.0, "cfe6ff")
area("Rim", 70, (0.6, 3.8, 0.4), 1.6, "dff4ff")

# ----------------------------------------------------------------------------------------------- the vessels
GILT = "d3b574"
GILT_LIT = "f3dca4"


def vessel_human():
    gold = metal("Gilt", "e0b860", 0.22, noise=0.08)
    blue = metal("Enamel", "1a3fa8", 0.18, metallic=0.0)
    sapph = metal("Sapphire", "2050ff", 0.05, metallic=0.0, emit=("3060ff", 0.6))
    torus("Bezel", 0.885, 0.05, gold, rsegs=24)
    torus("BezelLip", 0.805, 0.018, gold, rsegs=12, loc=(0, 0, 0.02))
    torus("BezelOuter", 0.965, 0.022, gold, rsegs=12)
    disc("EnamelBand", 0.95, blue, z=-0.02, inner=0.82)
    for i in range(16):
        a = 2 * math.pi * i / 16
        ico(f"Stud{i}", 0.022 if i % 4 else 0.0, gold, loc=(0.885 * math.cos(a), 0.885 * math.sin(a), 0.05))
    for i, a in enumerate((90, 0, 180, 270)):
        aa = math.radians(a)
        ico(f"Gem{i}", 0.042, sapph, loc=(0.885 * math.cos(aa), 0.885 * math.sin(aa), 0.06), sub=1, smooth=False)
    # a small crown riding the bezel's crown
    for i, (x, h) in enumerate(((-0.17, 0.08), (-0.085, 0.11), (0.0, 0.14), (0.085, 0.11), (0.17, 0.08))):
        cone(f"Crown{i}", 0.03, 0.0, h, gold, loc=(x, 0.86, 0.16), direction=(x * 0.5, 1, 0.1))
        ico(f"CrownPearl{i}", 0.02, gold, loc=(x + x * 0.5 * h, 0.86 + h, 0.16 + 0.1 * h))
    tube("CrownBand", [(-0.2, 0.84, 0.15), (0.0, 0.875, 0.17), (0.2, 0.84, 0.15)], gold, bevel=0.026)
    ico("CrownGem", 0.034, sapph, loc=(0, 0.88, 0.2), sub=1, smooth=False)
    a = torus("ArmillaryA", 0.84, 0.011, gold, rsegs=10)
    b = torus("ArmillaryB", 0.84, 0.011, gold, rsegs=10)
    SPINNERS.append((a, Euler((math.radians(76), 0, 0)), (0, 1, 0), 1.0))
    SPINNERS.append((b, Euler((math.radians(76), 0, math.radians(90))), (0, 1, 0), -0.7))


def gear_mesh(bm, r_in, r_out, r_tip, teeth, depth):
    """A flat gear outline (annulus plus trapezoid teeth); the caller solidifies it."""
    m = teeth * 8
    inn = [bm.verts.new((r_in * math.cos(2 * math.pi * i / m), r_in * math.sin(2 * math.pi * i / m), 0)) for i in range(m)]
    out = [bm.verts.new((r_out * math.cos(2 * math.pi * i / m), r_out * math.sin(2 * math.pi * i / m), 0)) for i in range(m)]
    for i in range(m):
        j = (i + 1) % m
        bm.faces.new((inn[i], out[i], out[j], inn[j]))
    for k in range(teeth):
        i0 = k * 8 + 2
        i1 = k * 8 + 5
        a0 = 2 * math.pi * (i0 + 0.6) / m
        a1 = 2 * math.pi * (i1 - 0.6) / m
        t0 = bm.verts.new((r_tip * math.cos(a0), r_tip * math.sin(a0), 0))
        t1 = bm.verts.new((r_tip * math.cos(a1), r_tip * math.sin(a1), 0))
        bm.faces.new((out[i0], out[i0 + 1], out[i0 + 2], out[i1], t1, t0))


def solid(ob, depth):
    mod = ob.modifiers.new("Solid", "SOLIDIFY")
    mod.thickness = depth
    mod.offset = 0.0
    mod.use_even_offset = True
    bev = ob.modifiers.new("Bevel", "BEVEL")
    bev.width = 0.006
    bev.segments = 2
    bev.limit_method = "ANGLE"
    return ob


def vessel_gnome():
    brass = metal("Brass", "c8953e", 0.28, noise=0.1)
    copper = metal("Copper", "c2683a", 0.3, noise=0.1)
    dark = metal("DarkIron", "2a2a2e", 0.5)
    glassm = metal("GaugeGlass", "f4efe0", 0.15, metallic=0.0, emit=("fff6d8", 0.35))
    cog = solid(mesh_obj("Cog", lambda bm: gear_mesh(bm, 0.775, 0.90, 0.985, 22, 0.08), brass, smooth=False), 0.07)
    SPINNERS.append((cog, Euler((0, 0, 0)), (0, 0, 1), 1.0))
    torus("CogBoss", 0.775, 0.035, copper, rsegs=16, loc=(0, 0, 0.03))
    for i in range(12):
        a = 2 * math.pi * (i + 0.5) / 12
        ico(f"Rivet{i}", 0.018, copper, loc=(0.84 * math.cos(a), 0.84 * math.sin(a), 0.05))
    # the pressure gauge at the top: its needle reads the charge
    torus("GaugeRim", 0.105, 0.016, brass, rsegs=12, loc=(0, 0.83, 0.14))
    disc("GaugeFace", 0.1, glassm, z=0.0).location = (0, 0.83, 0.135)
    needle = cone("GaugeNeedle", 0.008, 0.0, 0.085, dark, segs=8, loc=(0, 0.83, 0.15), direction=(0, 1, 0))
    for i in range(7):
        a = math.radians(-120 + 240 * i / 6) + math.pi / 2
        cone(f"Tick{i}", 0.004, 0.004, 0.02, dark, segs=6, loc=(0.075 * math.cos(a), 0.83 + 0.075 * math.sin(a), 0.14),
             direction=(math.cos(a), math.sin(a), 0))
    # copper coils clasping both sides
    for side in (-1, 1):
        pts = []
        for i in range(60):
            u = i / 59
            ang = u * 2 * math.pi * 4
            y = lerp(-0.45, 0.45, u)
            x = side * (0.755 + 0.035 * math.cos(ang))
            z = 0.035 * math.sin(ang) + 0.1
            pts.append((x, y, z))
        tube(f"Coil{side}", pts, copper, bevel=0.009, res=6)
    return needle


def vessel_orc():
    iron = metal("Iron", "3a3735", 0.55, noise=0.15)
    ivory = metal("Tusk", "d9c9a2", 0.38, metallic=0.0, noise=0.1)
    band = torus("IronBand", 0.875, 0.075, iron, rsegs=20)
    # glowing seams in the iron: emissive noise in ember
    seam_mat, sm = material("Seams")
    Ps = sm.node("ShaderNodeTexCoord").outputs["Object"]
    vor = sm.node("ShaderNodeTexVoronoi", feature="DISTANCE_TO_EDGE")
    vor.inputs["Scale"].default_value = 9.0
    sm.L.new(Ps, vor.inputs["Vector"])
    crack = sm.m("SUBTRACT", 1.0, sm.smooth(vor.outputs["Distance"], 0.0, 0.05))
    sa = sm.value("amt", 0.4)
    sm.additive(sm.scalec(sm.rgb("ff5a1a"), sm.m("MULTIPLY", crack, sa)))
    sob = torus("Seams", 0.875, 0.0765, seam_mat, rsegs=20)
    no_shadow(sob)
    for i in range(10):
        a = 2 * math.pi * (i + 0.5) / 10
        ico(f"Rivet{i}", 0.026, iron, loc=(0.875 * math.cos(a), 0.875 * math.sin(a), 0.075), sub=1)
    # four iron claws grip the orb
    for i, a in enumerate((45, 135, 225, 315)):
        aa = math.radians(a)
        d = Vector((math.cos(aa), math.sin(aa), 0))
        pts = [tuple(d * 0.93) + (0.06, 1.4), tuple(d * 0.80 + Vector((0, 0, 0.32))) + (0.9,), tuple(d * 0.62 + Vector((0, 0, 0.5))) + (0.25,)]
        tube(f"Claw{i}", pts, iron, bevel=0.04, res=16)
    # war horns rising from the band's crown, as the orc crest wears them
    for side in (-1, 1):
        pts = [(side * 0.5, 0.74, 0.18, 1.6), (side * 0.8, 0.5, 0.26, 1.2), (side * 0.93, 0.15, 0.24, 0.7), (side * 0.8, -0.12, 0.2, 0.1)]
        tube(f"Horn{side}", pts, ivory, bevel=0.065, res=24)
    for i in range(9):
        a = math.radians(200 + 140 * i / 8)
        d = (math.cos(a), math.sin(a), 0.0)
        cone(f"Spike{i}", 0.035, 0.0, 0.09, iron, segs=10, loc=(0.9 * math.cos(a), 0.9 * math.sin(a), 0.05), direction=d)
    return sm


def vessel_scourge():
    bone = metal("Bone", "d8d2b8", 0.6, metallic=0.0)
    iron = metal("BlackIron", "26222c", 0.45, noise=0.1)
    torus("ThornRing", 0.905, 0.04, iron, rsegs=16)
    for i in range(16):
        a = 2 * math.pi * (i + 0.25) / 16
        d = (math.cos(a + 0.25), math.sin(a + 0.25), 0)
        cone(f"Thorn{i}", 0.03, 0.0, 0.085, iron, segs=8, loc=(0.91 * math.cos(a), 0.91 * math.sin(a), 0.0), direction=d)
    # a skeletal hand cradles the orb from below: four fingers and a thumb
    wrist = Vector((0.0, -0.98, 0.15))
    fingers = [(-0.62, 1.0), (-0.22, 1.15), (0.22, 1.12), (0.6, 0.95)]
    for i, (x, ln) in enumerate(fingers):
        knuckle = Vector((x * 0.55, -0.80, 0.42))
        mid = Vector((x * 1.05, -0.45 + 0.1 * ln, 0.55))
        tip = Vector((x * 1.05, -0.05 + 0.25 * ln - abs(x) * 0.25, 0.42))
        tube(f"Finger{i}", [tuple(wrist) + (1.3,), tuple(knuckle) + (1.0,), tuple(mid) + (0.85,), tuple(tip) + (0.5,)], bone, bevel=0.035, res=16)
        for j, p in enumerate((knuckle, mid)):
            ico(f"Joint{i}{j}", 0.042, bone, loc=tuple(p), sub=2)
    tube("Thumb", [(0.2, -0.95, 0.2, 1.3), (0.75, -0.75, 0.35, 1.0), (0.88, -0.38, 0.38, 0.7), (0.78, -0.12, 0.32, 0.4)], bone, bevel=0.035)
    ico("Palm", 0.1, bone, loc=(0, -0.92, 0.22), sub=3)


def vessel_troll():
    wood = metal("Wood", "5a3a22", 0.7, metallic=0.0, noise=0.1)
    ivory = metal("Ivory", "efe6cc", 0.4, metallic=0.0)
    jade = metal("Jade", "1fae8a", 0.2, metallic=0.0, emit=("2fd6a8", 0.25))
    bonebead = metal("BoneBead", "e6dcc4", 0.5, metallic=0.0)
    red = metal("Feather", "c0392b", 0.6, metallic=0.0)
    teal = metal("FeatherTeal", "1b9aa0", 0.6, metallic=0.0)
    torus("WoodRing", 0.89, 0.06, wood, rsegs=16)
    for i in range(28):
        a = 2 * math.pi * i / 28
        ico(f"Bead{i}", 0.034, jade if i % 2 else bonebead, loc=(0.89 * math.cos(a), 0.89 * math.sin(a), 0.07), sub=2)
    for side in (-1, 1):
        pts = [(side * 0.1, -0.96, 0.18, 1.6), (side * 0.66, -0.8, 0.3, 1.3), (side * 0.95, -0.25, 0.3, 0.9), (side * 0.80, 0.28, 0.24, 0.35), (side * 0.6, 0.48, 0.2, 0.05)]
        tube(f"Tusk{side}", pts, ivory, bevel=0.065, res=24)
    for i, (x, m) in enumerate(((-0.14, teal), (0.0, red), (0.14, teal))):
        tube(f"Feather{i}", [(x * 0.5, 0.8, 0.12, 0.6), (x, 0.9, 0.14, 1.0), (x * 1.4, 0.99, 0.12, 0.3)], m, bevel=0.035, res=12)
    ico("Mask", 0.06, ivory, loc=(0, 0.86, 0.16), sub=2)


def vessel_skyborne():
    silver = metal("Silver", "dfe6ee", 0.18, noise=0.05)
    pearl = metal("Pearl", "f4f1ea", 0.25, metallic=0.0, emit=("eaf6ff", 0.2))
    feather = metal("Vane", "e9eef4", 0.35, metallic=0.4)
    torus("SilverRing", 0.835, 0.03, silver, rsegs=16, loc=(0, 0, 0.04))
    vanes = []
    for i in range(14):
        a = 2 * math.pi * i / 14

        def build(bm, a=a):
            # a flat feather: a quill and a vane, swept along the ring
            pts = []
            for j in range(9):
                u = j / 8
                r = lerp(0.84, 1.0, u)
                w = 0.11 * math.sin(math.pi * min(1, u * 1.1)) + 0.01
                ang = a + u * 0.35
                pts.append((r, ang, w))
            left = [bm.verts.new(((r) * math.cos(ang + w / r), (r) * math.sin(ang + w / r), 0.02 + 0.03 * j / 8)) for j, (r, ang, w) in enumerate(pts)]
            right = [bm.verts.new(((r) * math.cos(ang - w / r * 0.4), (r) * math.sin(ang - w / r * 0.4), 0.05 + 0.03 * j / 8)) for j, (r, ang, w) in enumerate(pts)]
            for j in range(8):
                bm.faces.new((left[j], left[j + 1], right[j + 1], right[j]))
        v = mesh_obj(f"Vane{i}", build, feather, smooth=True)
        vanes.append(v)
    for v in vanes:
        SPINNERS.append((v, Euler((0, 0, 0)), (0, 0, 1), 1.0))
    for i in range(8):
        a = 2 * math.pi * (i + 0.5) / 8
        ico(f"Pearl{i}", 0.022, pearl, loc=(0.835 * math.cos(a), 0.835 * math.sin(a), 0.07))
    # a four-point star at the top
    def star4(bm):
        c = bm.verts.new((0, 0, 0.03))
        ring = []
        for k in range(8):
            a = 2 * math.pi * k / 8 + math.pi / 2
            r = 0.11 if k % 2 == 0 else 0.03
            ring.append(bm.verts.new((r * math.cos(a), r * math.sin(a), 0)))
        for k in range(8):
            bm.faces.new((c, ring[k], ring[(k + 1) % 8]))
    s = mesh_obj("SkyStar", star4, metal("StarSilver", "ffffff", 0.1, emit=("eaf8ff", 1.2)), smooth=False)
    s.location = (0, 0.86, 0.14)


BEFORE = set(bpy.data.objects)
EXTRA = {"human": vessel_human, "gnome": vessel_gnome, "orc": vessel_orc, "scourge": vessel_scourge,
         "troll": vessel_troll, "skyborne": vessel_skyborne}[RACE]()
VESSEL = set(bpy.data.objects) - BEFORE

# ----------------------------------------------------------------------------------------------- camera, world, render, bloom
cam_data = bpy.data.cameras.new("cam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = args.scale
cam = link(bpy.data.objects.new("cam", cam_data))
cam.location = (0, 0, 8)
scene.camera = cam

# a studio world the metal reflects: a dark room with a warm softbox up left and a cool one to the right
world = bpy.data.worlds.new("w")
world.use_nodes = True
wn = world.node_tree.nodes
wl = world.node_tree.links
for n in list(wn):
    wn.remove(n)
wtc = wn.new("ShaderNodeTexCoord")
wnorm = wn.new("ShaderNodeVectorMath")
wnorm.operation = "NORMALIZE"
wl.new(wtc.outputs["Generated"], wnorm.inputs[0])


def wdot(d):
    n = wn.new("ShaderNodeVectorMath")
    n.operation = "DOT_PRODUCT"
    wl.new(wnorm.outputs[0], n.inputs[0])
    n.inputs[1].default_value = tuple(Vector(d).normalized())
    mr = wn.new("ShaderNodeMapRange")
    mr.interpolation_type = "SMOOTHSTEP"
    wl.new(n.outputs["Value"], mr.inputs["Value"])
    return mr


k1 = wdot((-0.5, 0.6, 0.65))
k1.inputs["From Min"].default_value, k1.inputs["From Max"].default_value = 0.86, 0.95
k1.inputs["To Max"].default_value = 5.0
k2 = wdot((0.8, -0.2, 0.5))
k2.inputs["From Min"].default_value, k2.inputs["From Max"].default_value = 0.9, 0.97
k2.inputs["To Max"].default_value = 2.0
amb = wdot((0, 1, 0.2))
amb.inputs["From Min"].default_value, amb.inputs["From Max"].default_value = -1.0, 1.0
amb.inputs["To Min"].default_value, amb.inputs["To Max"].default_value = 0.03, 0.25
a1 = wn.new("ShaderNodeMath")
a1.operation = "ADD"
wl.new(k1.outputs["Result"], a1.inputs[0])
wl.new(k2.outputs["Result"], a1.inputs[1])
a2 = wn.new("ShaderNodeMath")
a2.operation = "ADD"
wl.new(a1.outputs[0], a2.inputs[0])
wl.new(amb.outputs["Result"], a2.inputs[1])
wbg = wn.new("ShaderNodeBackground")
wbg.inputs["Color"].default_value = srgb("fff4e6")
wl.new(a2.outputs[0], wbg.inputs["Strength"])
wout = wn.new("ShaderNodeOutputWorld")
wl.new(wbg.outputs[0], wout.inputs["Surface"])
scene.world = world

scene.render.engine = "BLENDER_EEVEE"
scene.eevee.taa_render_samples = args.samples
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "None"
scene.render.resolution_x = scene.render.resolution_y = args.size
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA" if args.noring else "RGB"
scene.render.film_transparent = bool(args.noring)
scene.render.fps = FPS

if not args.noring:
    tree = bpy.data.node_groups.new("Comp", "CompositorNodeTree")
    tree.interface.new_socket(name="Image", in_out="OUTPUT", socket_type="NodeSocketColor")
    rl = tree.nodes.new("CompositorNodeRLayers")
    glare = tree.nodes.new("CompositorNodeGlare")
    glare.inputs["Type"].default_value = "Bloom"
    glare.inputs["Threshold"].default_value = 0.6
    glare.inputs["Strength"].default_value = 0.6
    glare.inputs["Size"].default_value = 0.6
    go = tree.nodes.new("NodeGroupOutput")
    tree.links.new(rl.outputs["Image"], glare.inputs["Image"])
    tree.links.new(glare.outputs["Image"], go.inputs[0])
    scene.compositing_node_group = tree
    scene.render.use_compositing = True


def apply(s):
    t = s["t"]
    for k in ("level", "power", "phase", "sharp", "accent", "men", "clear", "fire", "fh"):
        eg.values[k].outputs[0].default_value = s[k]
    eg.values["time"].outputs[0].default_value = t
    sg.values["star"].outputs[0].default_value = s["star"]
    gg.values["rim"].outputs[0].default_value = 0.35 + 0.45 * s["power"]
    gg.values["rime"].outputs[0].default_value = s["rime"]
    gg.values["time"].outputs[0].default_value = t
    og.values["amt"].outputs[0].default_value = 0.3 + 0.55 * min(s["star"], 1.4)
    if glyph_g:
        glyph_g.values["amt"].outputs[0].default_value = 0.25 + 0.75 * s["glyph"]
    hg.values["amt"].outputs[0].default_value = 0.10 + 0.22 * s["power"] * (0.4 + 0.6 * s["level"]) + 0.3 * s["flash"]
    mg.values["amt"].outputs[0].default_value = 0.5 + 0.9 * s["accent"]
    bg2.values["amt"].outputs[0].default_value = s["bolts"]
    for i in range(2):
        r, a, key = s["waves"][i] if i < len(s["waves"]) else (0.0, 0.0, MAGE)
        wg.values[f"r{i}"].outputs[0].default_value = r
        wg.values[f"a{i}"].outputs[0].default_value = a
        wg.N[f"c{i}"].outputs[0].default_value = srgb(key)
    wg.values["flash"].outputs[0].default_value = s["flash"]
    wg.values["time"].outputs[0].default_value = t
    wg.values["rays"].outputs[0].default_value = s["rays"]
    wg.values["arcs"].outputs[0].default_value = s["arcs"]
    wg.N["school"].outputs[0].default_value = srgb(s["school"])
    orb_light.energy = 10.0 * s["light"] * (0.4 + 0.6 * s["level"]) + 30 * s["flash"]
    orb_light.color = srgb("bfeeff")[:3] if s["fire"] < 0.3 else srgb("ffc890")[:3]
    star.rotation_euler = (0.35 + s["phase"] * 1.3, 0.6 + s["phase"] * 2.1, s["phase"] * 0.7)
    orbits[0].rotation_euler = (math.radians(72), 0, math.radians(20) + s["phase"] * 2.5)
    orbits[1].rotation_euler = (math.radians(-64), math.radians(30), math.radians(-35) - s["phase"] * 2.0)
    if glyphs:
        glyphs.rotation_euler.z = -s["turn"]
    for ob, base, axis, rate in SPINNERS:
        q = Matrix.Rotation(s["spinA"] * rate, 4, Vector(axis)) @ base.to_matrix().to_4x4()
        ob.rotation_euler = q.to_euler()
    lvl_y = (s["level"] * 2.08 - 1.04) * RE
    for o, rad, a0, z0, sp, seed in MOTES:
        a = a0 + s["phase"] * 2 * math.pi * sp
        rr = rad * RE
        y = ((z0 + s["phase"] * 0.3 * sp + 1) % 2 - 1) * RE * 0.9
        o.location = (rr * math.cos(a) * math.sqrt(max(0, 1 - (y / RE) ** 2)), y, rr * math.sin(a) * 0.5 + 0.2)
        o.hide_render = not (y < lvl_y)
    for i, trail in enumerate(BOLTS):
        for j, o in enumerate(trail):
            a = t * 4.6 + i * 2 * math.pi / 3 - j * 0.075
            tilt = 0.5 * math.sin(i * 1.7 + 0.4)
            rr = RE * (0.66 + 0.06 * math.sin(a * 2 + i))
            o.location = (rr * math.cos(a), rr * math.sin(a) * math.cos(tilt), 0.45 + rr * math.sin(a) * math.sin(tilt) * 0.3)
            o.hide_render = s["bolts"] < 0.02
    if RACE == "gnome" and EXTRA is not None:
        ang = math.radians(120 - 240 * s["level"])
        d = Vector((math.sin(-ang), math.cos(ang), 0))
        EXTRA.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
        EXTRA.location = Vector((0, 0.83, 0.15)) + d * 0.0425
    if RACE == "orc" and EXTRA is not None:
        EXTRA.values["amt"].outputs[0].default_value = 0.25 + 0.9 * s["accent"] + 0.6 * s["fire"]


if args.layer:
    # one in-game layer (KstyleUI_ActionBars/SlabOrb.lua), framed on the glass alone: the vessel on clear film with its dark
    # glass, every light on black for the game's additive blend; Tools/media/forge/orbs.py packs the frames
    L = args.layer
    ORB = [back, energy, glass, star, *orbits, waves] + [m[0] for m in MOTES] + [o for trail in BOLTS for o in trail]
    SHOW = {"vessel": VESSEL | {back}, "light": {energy, star, *orbits} | {m[0] for m in MOTES}, "glass": {glass},
            "core": {star, waves}, "meniscus": {energy}, "clear": {energy}, "heat": {energy},
            "barrage": {o for trail in BOLTS for o in trail}, "rime1": {glass}, "rime2": {glass}}[L]
    for o in set(ORB) | VESSEL:
        o.hide_render = o not in SHOW
    for o in (backdrop, hub_glow, ring, enamel, glyphs):
        if o:
            o.hide_render = True
    if L == "vessel":
        scene.render.use_compositing = False
        scene.render.film_transparent = True
        scene.render.image_settings.color_mode = "RGBA"
    cam_data.ortho_scale = 2.9 * RE if L == "core" else 2.05 * RE if L != "vessel" else 2.1
    if L != "vessel":
        scene.render.film_transparent = False
        scene.render.image_settings.color_mode = "RGB"
        wl.remove(wbg.inputs["Strength"].links[0])
        wbg.inputs["Strength"].default_value = 0.0
    FIXED = dict(READY, school=LIGHT, waves=[], flash=0.0, turn=0.0, spinA=0.0, men=0.0, rays=0.0, arcs=0.0)
    LOOK = {"vessel": dict(), "light": dict(), "glass": dict(power=0.5), "core": dict(star=1.6, rays=0.7),
            "meniscus": dict(level=0.5, power=0.0, accent=0.0, men=1.0), "clear": dict(power=0.0, accent=0.0, clear=1.0),
            "heat": dict(power=0.0, accent=0.0, fire=1.0, fh=1.0), "barrage": dict(bolts=1.0), "rime1": dict(power=0.5, rime=0.5),
            "rime2": dict(power=0.5, rime=1.0)}[L]
    still = L in ("vessel", "glass", "meniscus")
    looped = L == "barrage"
    n = 1 if still else args.cells if looped else 2 * args.cells
    t0 = time.time()
    for f in range(n):
        t = f * args.seconds / args.cells
        s = dict(FIXED, **LOOK)
        s.update(t=t, phase=READY["speed"] * t)
        apply(s)
        for o in ORB:
            if o not in SHOW:
                o.hide_render = True
        if looped:
            # three missiles a third of a turn apart: one turn per loop closes it
            for i, trail in enumerate(BOLTS):
                for j, o in enumerate(trail):
                    a = 2 * math.pi * f / args.cells + i * 2 * math.pi / 3 - j * 0.075
                    tilt = 0.5 * math.sin(i * 1.7 + 0.4)
                    rr = RE * (0.66 + 0.06 * math.sin(a * 2 + i))
                    o.location = (rr * math.cos(a), rr * math.sin(a) * math.cos(tilt), 0.45 + rr * math.sin(a) * math.sin(tilt) * 0.3)
        if L in ("glass", "rime1", "rime2"):
            gg.values["rim"].outputs[0].default_value = 0.5
        scene.render.filepath = str(OUT / f"{L}_{f:02d}.png")
        bpy.ops.render.render(write_still=True)
    print("ORB", RACE, args.school or "-", L, n, "frames", f"{time.time() - t0:.1f}s")
    sys.exit(0)

if args.frames:
    if ":" in args.frames:
        a, b = args.frames.split(":")
        frames = list(range(int(a), int(b)))
    else:
        frames = [int(x) for x in args.frames.split(",")]
else:
    frames = list(range(NFR))

if args.save:
    apply(STATES[frames[0]])
    bpy.ops.wm.save_as_mainfile(filepath=args.save, compress=True)

t0 = time.time()
tag = RACE if args.story == "race" else f"{RACE}_procs"
for f in frames:
    apply(STATES[f])
    scene.render.filepath = str(OUT / f"{tag}_{f:04d}.png")
    bpy.ops.render.render(write_still=True)
print("ORB", tag, len(frames), "frames", f"{time.time() - t0:.1f}s")
