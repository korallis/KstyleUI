"""Render the crest's proc aura, Media/Textures/Medallions/Auras/ProcAura.png, in Blender and bake it into a flipbook.

A proc lights a white aura that the crest and the cooldown rails tint in the proc's colour (procAura in Core/Tokens.lua):
three bright arcs run round a ring of light at 80% of the cell's radius over a dimmer inner ring that runs the other way,
with sparks orbiting on it, so the medal's centre stays clear and the loop reads as motion, never as a still icon.
Blender (EEVEE, orthographic, black world, emission only) renders 16 frames of one whole turn of the pattern; the bake adds
a soft glow, box-filters each frame to a 128 px cell (Lanczos rings dark round a spark), fades 3 texels at each cell edge and writes a 4x4 sheet for ADD blending
(white, alpha is the light).

    python3 Tools/media/proc_aura.py [--blender PATH] [--work DIR] [--out PATH]

Needs Blender 5.x (BLENDER, --blender or blender on the PATH), numpy and Pillow.
"""
import math
import sys

FRAMES, COLUMNS, CELL, RENDER = 16, 4, 128, 256
RING, INNER, ARCS = 0.80, 0.70, 3
SPARKS = ((0.0, 0.80, 1, 0.022), (2.1, 0.74, 1, 0.016), (4.2, 0.84, 1, 0.018), (1.0, 0.70, -1, 0.014), (3.6, 0.77, -1, 0.016))


def scene(out):
    import bpy

    bpy.ops.wm.read_factory_settings(use_empty=True)
    s = bpy.context.scene
    s.render.engine = "BLENDER_EEVEE"
    s.render.resolution_x = s.render.resolution_y = RENDER
    s.render.film_transparent = False
    s.view_settings.view_transform = "Standard"
    s.world = bpy.data.worlds.new("black")
    s.world.color = (0, 0, 0)
    s.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.type, cam.data.ortho_scale = "ORTHO", 2.0
    cam.location = (0, 0, 5)
    s.collection.objects.link(cam)
    s.camera = cam

    def glow(name, strength, lobes, sign):
        m = bpy.data.materials.new(name)
        n, links = m.node_tree.nodes, m.node_tree.links
        n.clear()
        geo, sep = n.new("ShaderNodeNewGeometry"), n.new("ShaderNodeSeparateXYZ")
        angle = n.new("ShaderNodeMath")
        angle.operation = "ARCTAN2"
        links.new(geo.outputs["Position"], sep.inputs[0])
        links.new(sep.outputs["Y"], angle.inputs[0])
        links.new(sep.outputs["X"], angle.inputs[1])
        times = n.new("ShaderNodeMath")
        times.operation, times.inputs[1].default_value = "MULTIPLY", lobes * sign
        links.new(angle.outputs[0], times.inputs[0])
        phase = n.new("ShaderNodeValue")
        phase.name = "phase"
        add = n.new("ShaderNodeMath")
        add.operation = "ADD"
        links.new(times.outputs[0], add.inputs[0])
        links.new(phase.outputs[0], add.inputs[1])
        wave = n.new("ShaderNodeMath")
        wave.operation = "SINE"
        links.new(add.outputs[0], wave.inputs[0])
        lift = n.new("ShaderNodeMapRange")
        lift.inputs["From Min"].default_value, lift.inputs["To Min"].default_value = -1, 0
        links.new(wave.outputs[0], lift.inputs["Value"])
        sharp = n.new("ShaderNodeMath")
        sharp.operation, sharp.inputs[1].default_value = "POWER", 6
        links.new(lift.outputs[0], sharp.inputs[0])
        level = n.new("ShaderNodeMath")
        level.operation, level.inputs[1].default_value = "MULTIPLY_ADD", strength
        level.inputs[2].default_value = strength * 0.05
        links.new(sharp.outputs[0], level.inputs[0])
        emit, out_node = n.new("ShaderNodeEmission"), n.new("ShaderNodeOutputMaterial")
        links.new(level.outputs[0], emit.inputs["Strength"])
        links.new(emit.outputs[0], out_node.inputs[0])
        return m, phase

    def torus(name, radius, minor, mat):
        bpy.ops.mesh.primitive_torus_add(major_radius=radius, minor_radius=minor, major_segments=192, minor_segments=12)
        o = bpy.context.object
        o.name = name
        o.data.materials.append(mat)
        return o

    outer, outer_phase = glow("outer", 1.3, ARCS, 1)
    inner, inner_phase = glow("inner", 0.8, ARCS - 1, -1)
    torus("ring", RING, 0.024, outer)
    torus("inner", INNER, 0.012, inner)
    spark = bpy.data.materials.new("spark")
    spark.node_tree.nodes.clear()
    e, o = spark.node_tree.nodes.new("ShaderNodeEmission"), spark.node_tree.nodes.new("ShaderNodeOutputMaterial")
    e.inputs["Strength"].default_value = 3
    spark.node_tree.links.new(e.outputs[0], o.inputs[0])
    sparks = []
    for start, radius, turn, size in SPARKS:
        bpy.ops.mesh.primitive_uv_sphere_add(radius=size, segments=16, ring_count=8)
        bpy.context.object.data.materials.append(spark)
        sparks.append((bpy.context.object, start, radius, turn))
    for f in range(FRAMES):
        t = 2 * math.pi * f / FRAMES
        outer_phase.outputs[0].default_value = -t
        inner_phase.outputs[0].default_value = -t
        for ob, start, radius, turn in sparks:
            a = start + turn * t
            ob.location = (radius * math.cos(a), radius * math.sin(a), 0.05)
        s.render.filepath = f"{out}/frame{f:02d}.png"
        bpy.ops.render.render(write_still=True)


def bake(work, out):
    import numpy as np
    from PIL import Image, ImageFilter

    def linear(x):
        return np.where(x <= 0.04045, x / 12.92, ((x + 0.055) / 1.055) ** 2.4)

    fade = np.clip(np.minimum(np.arange(CELL), np.arange(CELL)[::-1]) / 3.0, 0, 1)
    window = fade[:, None] * fade[None, :]
    rows = FRAMES // COLUMNS
    sheet = np.zeros((CELL * rows, CELL * COLUMNS))
    for f in range(FRAMES):
        grey = Image.open(f"{work}/frame{f:02d}.png").convert("L")
        lin = linear(np.asarray(grey, np.float64) / 255)
        wide = np.asarray(Image.fromarray(np.uint8(np.clip(lin, 0, 1) * 255)).filter(ImageFilter.GaussianBlur(RENDER / 40)), np.float64) / 255
        lit = np.clip(lin + 0.9 * wide, 0, 1)
        small = np.asarray(Image.fromarray(np.float32(lit), "F").resize((CELL, CELL), Image.BOX), np.float64)
        y, x = divmod(f, COLUMNS)
        sheet[y * CELL:(y + 1) * CELL, x * CELL:(x + 1) * CELL] = np.clip(small, 0, 1) * window
    s = np.where(sheet <= 0.0031308, sheet * 12.92, 1.055 * sheet ** (1 / 2.4) - 0.055)
    alpha = np.round(np.clip(s, 0, 1) * 255).astype(np.uint8)
    rgba = np.zeros(alpha.shape + (4,), np.uint8)
    rgba[..., :3] = np.where(alpha[..., None] > 0, 255, 0)
    rgba[..., 3] = alpha
    Image.fromarray(rgba, "RGBA").save(out, optimize=True)


def main():
    import argparse
    import os
    import shutil
    import subprocess
    import tempfile
    from pathlib import Path

    root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--blender", default=os.environ.get("BLENDER") or shutil.which("blender"))
    parser.add_argument("--work", type=Path, help="keep the 256 px renders here")
    parser.add_argument("--out", type=Path, default=root / "Media/Textures/Medallions/Auras/ProcAura.png")
    args = parser.parse_args()
    if not args.blender:
        parser.error("no Blender found; set BLENDER or pass --blender")
    work = args.work or Path(tempfile.mkdtemp(prefix="proc-aura-"))
    work.mkdir(parents=True, exist_ok=True)
    subprocess.run([args.blender, "-b", "--factory-startup", "--python-exit-code", "1", "-P", __file__, "--", "render", str(work)], check=True)
    bake(work, args.out)
    print(args.out)


if __name__ == "__main__":
    if "--" in sys.argv and sys.argv[sys.argv.index("--") + 1:][:1] == ["render"]:
        scene(sys.argv[sys.argv.index("--") + 2])
    else:
        main()
