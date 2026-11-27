"""aura.py: Blender 5.3, headless. Render one crest mark as a looping spell-effect aura with EEVEE, frame by frame.

The figure's silhouette never moves, so it reads at any size; the light inside it flows, its edge burns, flame
tongues lick outward and motes rise round it. The loop is seamless: every noise field is the blend of two fields one
period apart, and the motes' lattice scrolls exactly one cell per loop. Tools/media/forge/auras.py writes the fields
this reads and bakes the frames into the sheet the game plays.

    blender -b --factory-startup --python-exit-code 1 --python aura.py -- FIELDS NAME OUT --palette JSON
        [--frames 16] [--size 512] [--fit 1.0] [--plate 0.445] [--pad 0.2754]

FIELDS holds NAME_sdf.png (16-bit signed distance, 0.5 on the outline, padded by --pad of its width on each side) and
NAME_ridge.png (16-bit relief ridges inside the figure). --palette is a JSON list of [stop, "rrggbb"] from dark to white heat.
"""
import argparse
import json
import sys
import time
from pathlib import Path

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
ap = argparse.ArgumentParser()
ap.add_argument("maps")
ap.add_argument("name")
ap.add_argument("out")
ap.add_argument("--frames", type=int, default=16)
ap.add_argument("--size", type=int, default=512)
ap.add_argument("--palette", required=True, help="JSON list of [stop, rrggbb]")
ap.add_argument("--fit", type=float, default=0.74, help="share of the frame the figure's unit box takes")
ap.add_argument("--plate", type=float, default=0.0, help="socket plate radius as a share of the frame; light outside the figure fades before it")
ap.add_argument("--pad", type=float, default=410.0 / 1024.0 / (1 + 2 * 410.0 / 1024.0), help="share of the field's width padded on each side")
args = ap.parse_args(argv)


out = Path(args.out)
out.mkdir(parents=True, exist_ok=True)
scene = bpy.context.scene
for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob, do_unlink=True)

# -- camera and card -------------------------------------------------------------------------------------------
bpy.ops.mesh.primitive_plane_add(size=2.0)
card = bpy.context.active_object
cam_data = bpy.data.cameras.new("cam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = 2.0
cam = bpy.data.objects.new("cam", cam_data)
cam.location = (0, 0, 5)
scene.collection.objects.link(cam)
scene.camera = cam
world = bpy.data.worlds.new("black")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0, 0, 0, 1)
scene.world = world

# -- material ---------------------------------------------------------------------------------------------------
mat = bpy.data.materials.new("aura")
mat.use_nodes = True
nt = mat.node_tree
N = nt.nodes
L = nt.links
for n in list(N):
    N.remove(n)


def node(kind, **props):
    n = N.new(kind)
    for k, v in props.items():
        setattr(n, k, v)
    return n


def feed(sock, v):
    if isinstance(v, (int, float)):
        sock.default_value = v
    elif isinstance(v, tuple):
        sock.default_value = v
    else:
        L.new(v, sock)


def m(op, a, b=None, clamp=False):
    n = node("ShaderNodeMath", operation=op, use_clamp=clamp)
    feed(n.inputs[0], a)
    if b is not None:
        feed(n.inputs[1], b)
    return n.outputs[0]


def v(op, a, b=None, scale=None):
    n = node("ShaderNodeVectorMath", operation=op)
    feed(n.inputs[0], a)
    if b is not None:
        feed(n.inputs[1], b)
    if scale is not None:
        feed(n.inputs["Scale"], scale)
    return n.outputs[0]


def xyz(x, y, z=0.0):
    n = node("ShaderNodeCombineXYZ")
    feed(n.inputs[0], x)
    feed(n.inputs[1], y)
    feed(n.inputs[2], z)
    return n.outputs[0]


def smooth(x, lo, hi):
    n = node("ShaderNodeMapRange", interpolation_type="SMOOTHSTEP", clamp=True)
    feed(n.inputs["Value"], x)
    n.inputs["From Min"].default_value = lo
    n.inputs["From Max"].default_value = hi
    return n.outputs["Result"]


def image(path, vec):
    img = bpy.data.images.load(str(path))
    img.colorspace_settings.name = "Non-Color"
    n = node("ShaderNodeTexImage", image=img, interpolation="Cubic", extension="EXTEND")
    L.new(vec, n.inputs["Vector"])
    return n.outputs["Color"]


def noise4(vec, w, scale, detail=4.0, rough=0.55, distortion=0.0):
    n = node("ShaderNodeTexNoise", noise_dimensions="4D")
    feed(n.inputs["Vector"], vec)
    feed(n.inputs["W"], w)
    n.inputs["Scale"].default_value = scale
    n.inputs["Detail"].default_value = detail
    n.inputs["Roughness"].default_value = rough
    n.inputs["Distortion"].default_value = distortion
    return n


def looping(vec, t, scale, drift, wspeed, detail=4.0, rough=0.55, color=False, distortion=0.0):
    """noise(vec + drift*t, wspeed*t) blended with the same one period back: seamless over t in 0..1."""
    out = []
    for back in (0.0, -1.0):
        tt = m("ADD", t, back)
        shift = v("SCALE", drift, None, scale=tt)
        n = noise4(v("ADD", vec, shift), m("MULTIPLY", tt, wspeed), scale, detail, rough, distortion)
        out.append(n.outputs["Color" if color else "Fac"])
    mix = node("ShaderNodeMix", data_type="RGBA" if color else "FLOAT")
    feed(mix.inputs["Factor"], t)
    if color:
        L.new(out[0], mix.inputs[6])
        L.new(out[1], mix.inputs[7])
        return mix.outputs[2]
    L.new(out[0], mix.inputs[2])
    L.new(out[1], mix.inputs[3])
    return mix.outputs[0]


# time 0..1 over the loop, keyed linearly
tnode = node("ShaderNodeValue")
T = tnode.outputs[0]
tnode.outputs[0].default_value = 0.0
tnode.outputs[0].keyframe_insert("default_value", frame=1)
tnode.outputs[0].default_value = 1.0
tnode.outputs[0].keyframe_insert("default_value", frame=1 + args.frames)
uv = node("ShaderNodeTexCoord").outputs["UV"]
# the figure's unit box sits centred at args.fit of the frame
centred = v("SUBTRACT", uv, (0.5, 0.5, 0.0))
fig = v("ADD", v("SCALE", centred, None, scale=1.0 / args.fit), (0.5, 0.5, 0.0))

# flame displacement: a looping colour noise, rising, stronger outside the figure
dn = looping(uv, T, 3.2, (0.0, -1.1, 0.0), 1.6, detail=3.0, rough=0.5, color=True)
dvec = v("SUBTRACT", dn, (0.5, 0.5, 0.5))
PADK = 1.0 - 2.0 * args.pad

def padded(vec):
    return v("ADD", v("SCALE", vec, None, scale=PADK), (0.5 * (1 - PADK), 0.5 * (1 - PADK), 0.0))

sdf_still = node("ShaderNodeSeparateColor")
L.new(image(Path(args.maps) / f"{args.name}_sdf.png", padded(fig)), sdf_still.inputs[0])
S0 = sdf_still.outputs[0]
reach = smooth(S0, 0.48, 0.78)  # 0 inside, 1 well outside: the flame bends more the further out it is
amp = m("ADD", 0.01, m("MULTIPLY", reach, 0.20))
lift = xyz(0.0, m("MULTIPLY", reach, -0.07))  # tongues lean upward
warped = v("ADD", v("ADD", fig, v("SCALE", dvec, None, scale=amp)), lift)
sdf_w = node("ShaderNodeSeparateColor")
L.new(image(Path(args.maps) / f"{args.name}_sdf.png", padded(warped)), sdf_w.inputs[0])
S = sdf_w.outputs[0]

ridge_sep = node("ShaderNodeSeparateColor")
L.new(image(Path(args.maps) / f"{args.name}_ridge.png", fig), ridge_sep.inputs[0])
R = ridge_sep.outputs[0]

# the parts
fill = m("SUBTRACT", 1.0, smooth(S0, 0.494, 0.506))  # the still silhouette: never moves
dist = m("ABSOLUTE", m("SUBTRACT", S, 0.5))
rim = m("POWER", m("SUBTRACT", 1.0, smooth(dist, 0.0, 0.012)), 1.5)
edge = m("SUBTRACT", 1.0, smooth(m("ABSOLUTE", m("SUBTRACT", S0, 0.5)), 0.0, 0.005))  # the burning edge, on the warped field
tongue = m("MULTIPLY", m("SUBTRACT", 1.0, smooth(S, 0.47, 0.585)), smooth(S0, 0.495, 0.52))  # flame outside the silhouette
flick = looping(v("MULTIPLY", uv, (3.0, 1.0, 1.0)), T, 2.6, (0.0, -3.0, 0.0), 2.4, detail=2.0, rough=0.45)
tongue = m("MULTIPLY", m("POWER", tongue, 1.7), smooth(flick, 0.42, 0.66))  # tapered tips
glow = m("MULTIPLY", m("SUBTRACT", 1.0, smooth(S0, 0.5, 0.70)), smooth(S0, 0.5, 0.505))
sheen = m("MULTIPLY", fill, smooth(S0, 0.465, 0.5))
flow = looping(fig, T, 4.0, (0.0, -1.6, 0.0), 1.4, detail=3.0, rough=0.5, distortion=1.2)
flow = smooth(flow, 0.54, 0.80)
# motes: a Voronoi lattice that scrolls up exactly one cell per loop
cells = 9.0
vor = node("ShaderNodeTexVoronoi", voronoi_dimensions="3D", feature="F1")
vor.inputs["Scale"].default_value = cells
vor.inputs["Randomness"].default_value = 1.0
L.new(v("ADD", uv, xyz(0.0, m("MULTIPLY", T, -1.0 / cells))), vor.inputs["Vector"])
mote = m("SUBTRACT", 1.0, smooth(vor.outputs["Distance"], 0.0, 0.08))
mote = m("MULTIPLY", mote, m("MULTIPLY", smooth(S0, 0.52, 0.55), m("SUBTRACT", 1.0, smooth(S0, 0.6, 0.66))))

inner = m("MULTIPLY", fill, m("ADD", 0.12, m("MULTIPLY", flow, 0.78)))
struct = m("MULTIPLY", fill, m("MULTIPLY", R, 0.46))
outer = m("ADD", m("MULTIPLY", tongue, 0.80), m("ADD", m("MULTIPLY", glow, 0.14), m("MULTIPLY", mote, 1.0)))
if args.plate > 0:
    ln = node("ShaderNodeVectorMath", operation="LENGTH")
    L.new(centred, ln.inputs[0])
    rad = ln.outputs["Value"]
    outer = m("MULTIPLY", outer, m("SUBTRACT", 1.0, smooth(rad, args.plate * 0.74, args.plate * 0.97)))
I = m("ADD", inner, struct)
I = m("ADD", I, m("MULTIPLY", sheen, 0.40))
I = m("ADD", I, m("MULTIPLY", edge, 0.80))
I = m("ADD", I, outer)
I = m("MINIMUM", I, 1.0)

def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


ramp = node("ShaderNodeValToRGB")
els = ramp.color_ramp.elements
stops = json.loads(args.palette)
while len(els) < len(stops):
    els.new(0.5)
for el, (pos, hexv) in zip(els, stops):
    el.position = pos
    el.color = tuple(srgb_to_linear(int(hexv[i:i + 2], 16) / 255.0) for i in (0, 2, 4)) + (1.0,)  # the ramp works in linear light
L.new(I, ramp.inputs["Fac"])
emit = node("ShaderNodeEmission")
L.new(ramp.outputs["Color"], emit.inputs["Color"])
emit.inputs["Strength"].default_value = 1.0
outn = node("ShaderNodeOutputMaterial")
L.new(emit.outputs[0], outn.inputs["Surface"])
card.data.materials.append(mat)

# make the time curve linear (Blender 5 actions keep curves in channelbags)
ad = nt.animation_data
if ad and ad.action:
    act = ad.action
    curves = []
    if hasattr(act, "layers"):
        for layer in act.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    curves.extend(bag.fcurves)
    if hasattr(act, "fcurves"):
        curves.extend(act.fcurves)
    for fc in curves:
        for k in fc.keyframe_points:
            k.interpolation = "LINEAR"
    print("time curves", len(curves))

# -- render ------------------------------------------------------------------------------------------------------
scene.render.engine = "BLENDER_EEVEE"
scene.eevee.taa_render_samples = 16
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "None"
scene.render.resolution_x = scene.render.resolution_y = args.size
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGB"
t0 = time.time()
for i in range(args.frames):
    scene.frame_set(1 + i)
    scene.render.filepath = str(out / f"{args.name}_{i:02d}.png")
    bpy.ops.render.render(write_still=True)
print("AURA", args.name, args.frames, "frames", f"{time.time() - t0:.1f}s")
