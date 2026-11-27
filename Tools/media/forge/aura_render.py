"""aura_render.py: Blender 5.3, headless. Render each rail sigil as a looping spell-effect aura, one PNG per frame.

    blender -b --factory-startup --python-exit-code 1 -P Tools/media/forge/aura_render.py -- <maps_dir> <out_dir> <names> [--frames 16] [--res 256]

For each <name>_m.png (silhouette), <name>_h.png (height) and <name>_g.png (soft glow round the silhouette, over the whole cell) in maps_dir it lights
one plane with an emission shader: the sigil's own strokes carry white-gold energy that flows through them, green flames rise
off its edges, and five motes circle it. Every moving term is a function of the loop phase (a 4D noise walked round a circle,
two rising flame fields cross-faded, motes turned by one fifth of a turn), so frame <frames> would equal frame 0 and the
loop has no seam. Writes <out_dir>/<name>/<frame>.png, RGB light on black.
"""
import math
import os
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
maps, out, names = argv[0], argv[1], argv[2].split(",")
opt = {"frames": 16, "res": 256}
i = 3
while i < len(argv):
    opt[argv[i].lstrip("-")] = int(argv[i + 1])
    i += 2

# the sigil fills this share of the cell; flames and motes use the rest
SIGIL = 0.62
# the hunter's jewel green (jewelHawk in Core/Tokens.lua) and the white-gold of the energy in the strokes, both linear
GREEN = (0.402, 0.651, 0.168)
CORE = (1.0, 0.86, 0.52)

scene = bpy.context.scene
for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob)

bpy.ops.mesh.primitive_plane_add(size=1.0)
plane = bpy.context.active_object
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
cam.data.type = "ORTHO"
cam.data.ortho_scale = 1.0
cam.location = (0, 0, 2)
scene.collection.objects.link(cam)
scene.camera = cam

world = bpy.data.worlds.new("Black")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0, 0, 0, 1)
scene.world = world
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = scene.render.resolution_y = opt["res"]
scene.render.resolution_percentage = 100
scene.render.film_transparent = False
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGB"
scene.render.image_settings.color_depth = "16"
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "None"
scene.eevee.taa_render_samples = 16

mat = bpy.data.materials.new("Aura")
nt = mat.node_tree
for n in list(nt.nodes):
    nt.nodes.remove(n)
N, L = nt.nodes, nt.links


def node(kind, **values):
    n = N.new(kind)
    for k, v in values.items():
        setattr(n, k, v)
    return n


def math_node(op, a=None, b=None, clamp=False):
    n = node("ShaderNodeMath", operation=op, use_clamp=clamp)
    for slot, v in ((0, a), (1, b)):
        if isinstance(v, (int, float)):
            n.inputs[slot].default_value = v
        elif v is not None:
            L.new(v, n.inputs[slot])
    return n.outputs[0]


def value(name):
    n = node("ShaderNodeValue", label=name, name=name)
    return n, n.outputs[0]


coord = node("ShaderNodeTexCoord").outputs["UV"]
sep = node("ShaderNodeSeparateXYZ")
L.new(coord, sep.inputs[0])
u, v = sep.outputs[0], sep.outputs[1]
cu, cv = math_node("SUBTRACT", u, 0.5), math_node("SUBTRACT", v, 0.5)
radius = node("ShaderNodeVectorMath", operation="LENGTH")
comb = node("ShaderNodeCombineXYZ")
L.new(cu, comb.inputs[0])
L.new(cv, comb.inputs[1])
L.new(comb.outputs[0], radius.inputs[0])
r = radius.outputs["Value"]
angle = math_node("ARCTAN2", cv, cu)

# the sigil's own box: the cell's middle SIGIL share
inner = node("ShaderNodeMapping", vector_type="POINT")
L.new(coord, inner.inputs["Vector"])
inner.inputs["Location"].default_value = (0.5 - 0.5 / SIGIL, 0.5 - 0.5 / SIGIL, 0)
inner.inputs["Scale"].default_value = (1 / SIGIL, 1 / SIGIL, 1)


def image(name, suffix, at):
    t = node("ShaderNodeTexImage", interpolation="Cubic", extension="CLIP")
    t.image = bpy.data.images.load(os.path.join(maps, f"{name}{suffix}.png"), check_existing=False)
    t.image.colorspace_settings.name = "Non-Color"
    L.new(at, t.inputs["Vector"])
    return t


# the silhouette and height fill the sigil's box; the glow map is drawn over the whole cell
# the flames lean on a copy of the glow raised a little, so they lick upward off the strokes
raised = node("ShaderNodeMapping", vector_type="POINT")
L.new(coord, raised.inputs["Vector"])
raised.inputs["Location"].default_value = (0, -0.06, 0)
mask_t, height_t, glow_t = image(names[0], "_m", inner.outputs[0]), image(names[0], "_h", inner.outputs[0]), image(names[0], "_g", coord)
lick_t = image(names[0], "_g", raised.outputs[0])
mask, height, glow = mask_t.outputs["Color"], height_t.outputs["Color"], glow_t.outputs["Color"]
mask = math_node("MULTIPLY", mask, 1.0)
height = math_node("MULTIPLY", height, 1.0)
glow = math_node("MULTIPLY", glow, 1.0)
lick = math_node("MAXIMUM", math_node("MULTIPLY", lick_t.outputs["Color"], 1.0), glow)

_, phase = value("phase")
_, ring_x = value("ring_x")
_, ring_y = value("ring_y")

# energy flowing through the strokes: 4D noise walked round a circle in its last two axes
flow_in = node("ShaderNodeCombineXYZ")
L.new(math_node("MULTIPLY", u, 7.0), flow_in.inputs[0])
L.new(math_node("MULTIPLY", v, 7.0), flow_in.inputs[1])
L.new(math_node("MULTIPLY", ring_x, 0.9), flow_in.inputs[2])
flow = node("ShaderNodeTexNoise", noise_dimensions="4D")
flow.inputs["Detail"].default_value = 3.0
flow.inputs["Scale"].default_value = 1.0
L.new(flow_in.outputs[0], flow.inputs["Vector"])
L.new(math_node("MULTIPLY", ring_y, 0.9), flow.inputs["W"])
pulse = node("ShaderNodeMapRange", interpolation_type="SMOOTHSTEP")
pulse.inputs["From Min"].default_value, pulse.inputs["From Max"].default_value = 0.38, 0.68
pulse.inputs["To Min"].default_value, pulse.inputs["To Max"].default_value = 0.3, 1.1
L.new(flow.outputs["Fac"], pulse.inputs["Value"])
ridge = math_node("ADD", math_node("MULTIPLY", height, 0.5), 0.5)
core = math_node("MULTIPLY", math_node("MULTIPLY", mask, pulse.outputs["Result"]), ridge)


# flames rising off the edges: two fields drifting up one flame height a loop apart, cross-faded so the loop closes
def flames(shift):
    p = node("ShaderNodeCombineXYZ")
    L.new(math_node("MULTIPLY", u, 9.0), p.inputs[0])
    drift = math_node("MULTIPLY", math_node("SUBTRACT", phase, shift), 2.2)
    L.new(math_node("SUBTRACT", math_node("MULTIPLY", v, 4.5), drift), p.inputs[1])
    n = node("ShaderNodeTexNoise", noise_dimensions="3D")
    n.inputs["Detail"].default_value = 4.0
    n.inputs["Roughness"].default_value = 0.55
    n.inputs["Scale"].default_value = 1.0
    L.new(p.outputs[0], n.inputs["Vector"])
    return n.outputs["Fac"]


fade = node("ShaderNodeMix", data_type="FLOAT")
L.new(phase, fade.inputs["Factor"])
L.new(flames(0.0), fade.inputs["A"])
L.new(flames(1.0), fade.inputs["B"])
tongues = node("ShaderNodeMapRange", interpolation_type="SMOOTHSTEP")
tongues.inputs["From Min"].default_value, tongues.inputs["From Max"].default_value = 0.5, 0.66
L.new(fade.outputs["Result"], tongues.inputs["Value"])
corona = math_node("MULTIPLY", math_node("MULTIPLY", lick, tongues.outputs["Result"]), math_node("SUBTRACT", 1.0, mask))
halo = math_node("MULTIPLY", glow, 0.16)

# five motes circling at four tenths of the cell, a fifth of a turn a loop
spin = math_node("SUBTRACT", math_node("MULTIPLY", angle, 5.0), math_node("MULTIPLY", phase, 2 * math.pi))
beads = math_node("POWER", math_node("MAXIMUM", math_node("COSINE", spin), 0.0), 90.0)
band = math_node("EXPONENT", math_node("MULTIPLY", math_node("POWER", math_node("DIVIDE", math_node("SUBTRACT", r, 0.41), 0.016), 2.0), -1.0))
motes = math_node("MULTIPLY", beads, band)


def tint(amount, rgb, strength):
    c = node("ShaderNodeCombineXYZ")
    for k in range(3):
        L.new(math_node("MULTIPLY", amount, rgb[k] * strength), c.inputs[k])
    return c.outputs[0]


def add(a, b):
    n = node("ShaderNodeVectorMath", operation="ADD")
    L.new(a, n.inputs[0])
    L.new(b, n.inputs[1])
    return n.outputs[0]


light = add(add(tint(core, CORE, 1.2), tint(math_node("ADD", corona, halo), GREEN, 2.1)), tint(motes, (0.75, 0.9, 0.45), 1.1))
emit = node("ShaderNodeEmission")
L.new(light, emit.inputs["Color"])
emit.inputs["Strength"].default_value = 1.0
outp = node("ShaderNodeOutputMaterial")
L.new(emit.outputs[0], outp.inputs["Surface"])
plane.data.materials.append(mat)

frames = opt["frames"]
for name in names:
    for t, suffix in ((mask_t, "_m"), (height_t, "_h"), (glow_t, "_g"), (lick_t, "_g")):
        t.image = bpy.data.images.load(os.path.join(maps, f"{name}{suffix}.png"), check_existing=False)
        t.image.colorspace_settings.name = "Non-Color"
    os.makedirs(os.path.join(out, name), exist_ok=True)
    for f in range(frames):
        t = f / frames
        N["phase"].outputs[0].default_value = t
        N["ring_x"].outputs[0].default_value = math.cos(2 * math.pi * t)
        N["ring_y"].outputs[0].default_value = math.sin(2 * math.pi * t)
        scene.render.filepath = os.path.join(out, name, f"{f:02d}.png")
        bpy.ops.render.render(write_still=True)
    print("aura", name, frames)
