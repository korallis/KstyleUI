"""forge.py: Blender 5.3, headless. Render every emblem height map in a folder as forged neutral metal.

    blender -b --factory-startup --python-exit-code 1 -P Tools/media/forge/forge.py -- <maps_dir> <out_dir> [--res 512] [--only A,B] [--depth 0.16]

For each <name>_h.png (16-bit height), <name>_m.png (silhouette) and <name>_c.png (cavity) it displaces one grid,
lights it as jewellery is lit (a soft key from the upper left, a cool rim from the lower right, a studio sky for
the reflections) and writes <out_dir>/<name>.png, RGBA on transparent, in bright neutral metal so a game tint colours it.
"""
import json
import os
import sys
import time

import bpy
import numpy as np

argv = sys.argv[sys.argv.index("--") + 1:]
maps, out = argv[0], argv[1]
opt = {"res": 512, "only": "", "depth": 0.16, "samples": 96, "grid": 1024}
i = 2
while i < len(argv):
    opt[argv[i].lstrip("-")] = type(opt[argv[i].lstrip("-")])(argv[i + 1])
    i += 2
os.makedirs(out, exist_ok=True)
G = int(opt["grid"])

scene = bpy.context.scene
for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob)

# the grid: one mesh reused for every emblem
xs = np.linspace(-0.5, 0.5, G, dtype=np.float32)
X, Y = np.meshgrid(xs, -xs)
co = np.zeros((G * G, 3), np.float32)
co[:, 0], co[:, 1] = X.ravel(), Y.ravel()
idx = np.arange(G * G, dtype=np.int32).reshape(G, G)
quads = np.stack([idx[:-1, :-1], idx[1:, :-1], idx[1:, 1:], idx[:-1, 1:]], -1).reshape(-1, 4)
mesh = bpy.data.meshes.new("Relief")
mesh.vertices.add(G * G)
mesh.loops.add(quads.size)
mesh.polygons.add(len(quads))
mesh.vertices.foreach_set("co", co.ravel())
mesh.loops.foreach_set("vertex_index", quads.ravel())
mesh.polygons.foreach_set("loop_start", np.arange(0, quads.size, 4, dtype=np.int32))
mesh.polygons.foreach_set("loop_total", np.full(len(quads), 4, np.int32))
mesh.polygons.foreach_set("use_smooth", np.ones(len(quads), bool))
mesh.update()
mesh.validate()
uv = mesh.uv_layers.new(name="UV")
u = (co[:, 0] + 0.5)[quads.ravel()]
v = (co[:, 1] + 0.5)[quads.ravel()]
uv.data.foreach_set("uv", np.stack([u, v], -1).ravel())
ob = bpy.data.objects.new("Relief", mesh)
scene.collection.objects.link(ob)

# material: bright neutral metal, dark patina in the cavities, silhouette as alpha
mat = bpy.data.materials.new("Forged")
nt = mat.node_tree
for n in list(nt.nodes):
    nt.nodes.remove(n)
outn = nt.nodes.new("ShaderNodeOutputMaterial")
bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
tcav = nt.nodes.new("ShaderNodeTexImage")
tmask = nt.nodes.new("ShaderNodeTexImage")
mixc = nt.nodes.new("ShaderNodeMix")
mixc.data_type = "RGBA"
ramp = nt.nodes.new("ShaderNodeMapRange")
mixc.inputs["A"].default_value = (0.88, 0.88, 0.875, 1)
mixc.inputs["B"].default_value = (0.035, 0.03, 0.028, 1)
nt.links.new(tcav.outputs["Color"], mixc.inputs["Factor"])
nt.links.new(mixc.outputs["Result"], bsdf.inputs["Base Color"])
ramp.inputs["From Min"].default_value = 0.0
ramp.inputs["From Max"].default_value = 1.0
ramp.inputs["To Min"].default_value = float(os.environ.get("FORGE_ROUGH", "0.3"))
ramp.inputs["To Max"].default_value = 0.7
nt.links.new(tcav.outputs["Color"], ramp.inputs["Value"])
nt.links.new(ramp.outputs["Result"], bsdf.inputs["Roughness"])
bsdf.inputs["Metallic"].default_value = 1.0
nt.links.new(tmask.outputs["Color"], bsdf.inputs["Alpha"])
nt.links.new(bsdf.outputs["BSDF"], outn.inputs["Surface"])
mesh.materials.append(mat)

# camera: straight down, orthographic, the unit box fills the frame
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
cam.data.type = "ORTHO"
cam.data.ortho_scale = 1.0
cam.location = (0, 0, 3)
scene.collection.objects.link(cam)
scene.camera = cam


# the sky the metal reflects, painted by direction: seen from straight above, a flat face mirrors the zenith and a
# slope mirrors the sky twice its tilt away, so the zenith sets the flats, a broad lamp to the upper left lights the
# slopes that face it, a thin cool lamp low on the lower right edges the far slopes, and the rest stays dark.
world = bpy.data.worlds.new("Sky")
scene.world = world
wt = world.node_tree
for n in list(wt.nodes):
    wt.nodes.remove(n)
wo = wt.nodes.new("ShaderNodeOutputWorld")
bg = wt.nodes.new("ShaderNodeBackground")
tc = wt.nodes.new("ShaderNodeTexCoord")


def lobe(direction, power, gain):
    d = np.array(direction, float)
    d /= np.linalg.norm(d)
    dot = wt.nodes.new("ShaderNodeVectorMath")
    dot.operation = "DOT_PRODUCT"
    dot.inputs[1].default_value = tuple(d)
    wt.links.new(tc.outputs["Generated"], dot.inputs[0])
    clamp = wt.nodes.new("ShaderNodeMath")
    clamp.operation = "MAXIMUM"
    clamp.inputs[1].default_value = 0.0
    wt.links.new(dot.outputs["Value"], clamp.inputs[0])
    powr = wt.nodes.new("ShaderNodeMath")
    powr.operation = "POWER"
    powr.inputs[1].default_value = power
    wt.links.new(clamp.outputs[0], powr.inputs[0])
    mul = wt.nodes.new("ShaderNodeMath")
    mul.operation = "MULTIPLY"
    mul.inputs[1].default_value = gain
    wt.links.new(powr.outputs[0], mul.inputs[0])
    return mul.outputs[0]


SKY = json.loads(os.environ.get("FORGE_SKY", "null")) or {
    "base": 0.035, "lobes": [[[0, 0, 1], 2.2, 0.36], [[-0.62, 0.66, 0.42], 5.0, 2.4], [[0.66, -0.7, 0.26], 22.0, 1.5], [[-0.2, 0.25, 0.95], 60.0, 0.5]]}
total = None
for direction, power, gain in SKY["lobes"]:
    o = lobe(direction, power, gain)
    if total is None:
        total = o
    else:
        addn = wt.nodes.new("ShaderNodeMath")
        addn.operation = "ADD"
        wt.links.new(total, addn.inputs[0])
        wt.links.new(o, addn.inputs[1])
        total = addn.outputs[0]
basen = wt.nodes.new("ShaderNodeMath")
basen.operation = "ADD"
basen.inputs[1].default_value = SKY["base"]
wt.links.new(total, basen.inputs[0])
wt.links.new(basen.outputs[0], bg.inputs["Strength"])
bg.inputs["Color"].default_value = (1, 1, 1, 1)
wt.links.new(bg.outputs["Background"], wo.inputs["Surface"])

scene.render.engine = "CYCLES"
prefs = bpy.context.preferences.addons["cycles"].preferences
device = "CPU"
for kind in ("OPTIX", "CUDA"):
    try:
        prefs.compute_device_type = kind
        prefs.get_devices()
        for d in prefs.devices:
            d.use = d.type != "CPU"
        if any(d.use for d in prefs.devices):
            device = "GPU"
            break
    except TypeError:
        continue
scene.cycles.device = device
scene.cycles.samples = int(opt["samples"])
scene.cycles.use_adaptive_sampling = True
scene.cycles.adaptive_threshold = 0.02
scene.cycles.use_denoising = True
scene.cycles.max_bounces = 6
scene.cycles.glossy_bounces = 4
scene.render.film_transparent = True
scene.render.resolution_x = scene.render.resolution_y = int(opt["res"])
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.image_settings.color_depth = "8"
scene.view_settings.view_transform = "Standard"
try:
    scene.view_settings.look = "None"
except TypeError:
    pass
scene.render.use_persistent_data = False

only = set(filter(None, str(opt["only"]).split(",")))
names = sorted(f[:-6] for f in os.listdir(maps) if f.endswith("_h.png"))
done = []
t0 = time.time()
for name in names:
    if only and name not in only:
        continue
    him = bpy.data.images.load(os.path.join(maps, name + "_h.png"))
    him.colorspace_settings.name = "Non-Color"
    w, h = him.size
    px = np.empty(w * h * 4, np.float32)
    him.pixels.foreach_get(px)
    H = px.reshape(h, w, 4)[::-1, :, 0]  # row 0 at the top
    ys = np.clip(np.round(np.linspace(0, h - 1, G)).astype(int), 0, h - 1)
    xs_i = np.clip(np.round(np.linspace(0, w - 1, G)).astype(int), 0, w - 1)
    z = H[np.ix_(ys, xs_i)].astype(np.float32) * float(opt["depth"])
    co[:, 2] = z.ravel()
    mesh.vertices.foreach_set("co", co.ravel())
    mesh.update()
    bpy.data.images.remove(him)
    for node, suffix in ((tcav, "_c.png"), (tmask, "_m.png")):
        old = node.image
        img = bpy.data.images.load(os.path.join(maps, name + suffix))
        img.colorspace_settings.name = "Non-Color"
        node.image = img
        node.extension = "CLIP"
        if old:
            bpy.data.images.remove(old)
    scene.render.filepath = os.path.join(out, name + ".png")
    bpy.ops.render.render(write_still=True)
    done.append(name)
print("@@JSON@@" + json.dumps({"rendered": len(done), "seconds": round(time.time() - t0, 1), "device": device,
                               "verts": G * G, "tris": int(len(quads) * 2), "out": out}))
