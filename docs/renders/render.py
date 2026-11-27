"""Render the existing class crest textures in a simple Blender studio.

Run with Blender 5.3 in background mode from the repository root:
blender --background --factory-startup --python-exit-code 1 --python docs/renders/render.py
These are renders of flat existing texture art, not new crest models or aura animation.
"""
from pathlib import Path
import bpy

root = Path(__file__).resolve().parents[2]
out = root / 'docs/renders/media'
out.mkdir(parents=True, exist_ok=True)
sources = {'hunter': 'skyborne', 'mage': 'human', 'warlock': 'human',
           'warrior': 'dwarf', 'paladin': 'human', 'rogue': 'human',
           'priest': 'human', 'druid': 'nightelf', 'shaman': 'dwarf'}
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.render.engine = 'BLENDER_EEVEE'
scene.eevee.taa_render_samples = 16
scene.render.resolution_x = scene.render.resolution_y = 512
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.view_settings.view_transform = 'Standard'
world = bpy.data.worlds.new('Backdrop')
world.use_nodes = True
world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.012, 0.016, 0.025, 1)
scene.world = world
bpy.ops.mesh.primitive_plane_add(size=2)
card = bpy.context.object
material = bpy.data.materials.new('Crest artwork')
material.use_nodes = True
nodes = material.node_tree.nodes
nodes.clear()
image = nodes.new('ShaderNodeTexImage')
emit = nodes.new('ShaderNodeEmission')
output = nodes.new('ShaderNodeOutputMaterial')
material.node_tree.links.new(image.outputs['Color'], emit.inputs['Color'])
material.node_tree.links.new(emit.outputs[0], output.inputs['Surface'])
card.data.materials.append(material)
camera_data = bpy.data.cameras.new('Camera')
camera_data.type = 'ORTHO'
camera_data.ortho_scale = 2.4
camera = bpy.data.objects.new('Camera', camera_data)
camera.location = (0, 0, 3)
scene.collection.objects.link(camera)
scene.camera = camera
for name, race in sources.items():
    path = root / 'Media/Textures/Medallions/Crests' / (race + '_' + name + '.png')
    image.image = bpy.data.images.load(str(path), check_existing=True)
    scene.render.filepath = str(out / (name + '.png'))
    bpy.ops.render.render(write_still=True)
