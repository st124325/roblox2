"""Build a single neon neighborhood with three animated block characters."""
import math
import sys
from pathlib import Path
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'build/heist'
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = 'BLENDER_EEVEE_NEXT'
scene.eevee.taa_render_samples = 4
scene.render.resolution_x, scene.render.resolution_y = 1080, 1920
scene.render.resolution_percentage = 100
scene.render.fps = 30
scene.frame_start, scene.frame_end = 1, 660
scene.view_settings.view_transform = 'AgX'
scene.render.image_settings.file_format = 'PNG'
world = bpy.data.worlds.new('Night sky')
scene.world = world
world.use_nodes = True
world.node_tree.nodes['Background'].inputs[0].default_value = (0.09, 0.17, 0.29, 1)
world.node_tree.nodes['Background'].inputs[1].default_value = 0.5

def mat(name, rgb, emission=0):
    existing = bpy.data.materials.get(name)
    if existing:
        return existing
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1)
    m.use_nodes = True
    bs = m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value = (*rgb, 1)
    bs.inputs['Roughness'].default_value = 0.65
    bs.inputs['Emission Color'].default_value = (*rgb, 1)
    bs.inputs['Emission Strength'].default_value = emission
    return m

NAVY = mat('Midnight concrete', (0.045, 0.075, 0.13))
WALL = mat('Blue concrete', (0.12, 0.19, 0.26))
BLACK = mat('Ink', (0.01, 0.014, 0.024))
WHITE = mat('Warm white', (0.84, 0.87, 0.85))
CYAN = mat('Cyan neon', (0.01, 0.7, 1), 3)
LIME = mat('Lime neon', (0.52, 1, 0.025), 2.5)
CORAL = mat('Coral jacket', (0.95, 0.10, 0.075))
YELLOW = mat('Yellow jacket', (1, 0.62, 0.035))
SKIN = mat('Skin', (0.78, 0.46, 0.24))
ALARM = mat('Alarm', (1, 0.012, 0.025), 0.3)

def empty(name, loc=(0, 0, 0), parent=None):
    o = bpy.data.objects.new(name, None)
    scene.collection.objects.link(o)
    o.parent = parent
    o.location = loc
    return o

def box(name, loc, dims, material, parent=None, bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1)
    o = bpy.context.object
    o.name = name
    o.dimensions = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.parent = parent
    o.location = loc
    o.data.materials.append(material)
    if bevel:
        mod = o.modifiers.new('Soft toy edges', 'BEVEL')
        mod.width, mod.segments = bevel, 2
        o.modifiers.new('Weighted normals', 'WEIGHTED_NORMAL')
    return o

def text(body, loc, size, material):
    c = bpy.data.curves.new('Sign', 'FONT')
    c.body = body
    c.align_x = 'CENTER'
    c.size = size
    c.extrude = 0.003
    o = bpy.data.objects.new('Sign ' + body, c)
    scene.collection.objects.link(o)
    o.location = loc
    o.rotation_euler.x = math.pi/2
    c.materials.append(material)
    return o

box('Island', (0, 3, -0.5), (80, 50, 1), NAVY)
box('Street', (0, -3, -0.01), (70, 5, 0.1), mat('Asphalt', (0.07, 0.09, 0.12)))
for x in range(-32, 34, 4):
    box('Road dash', (x, -3, 0.06), (1.4, 0.09, 0.03), WHITE)
for y in (-6, 0):
    box('Curb', (0, y, 0.08), (72, 0.18, 0.18), WALL)
for x in (-12, 14):
    accent = LIME if x < 0 else CYAN
    box('Base floor', (x, 5, 0.1), (10, 10, 0.25), WALL)
    box('Base back wall', (x, 10, 2.5), (10, 0.35, 5), NAVY)
    for side in (-1, 1):
        box('Base side', (x+side*5, 6.7, 1.55), (0.3, 6.6, 3.1), NAVY)
        box('Base rim', (x+side*4.9, 4.9, 0.3), (0.10, 9.7, 0.08), accent)
    box('Entry threshold', (x, 0, 0.22), (9.8, 0.14, 0.08), accent)
    box('Display plinth', (x, 6, 0.6), (3, 2.4, 1), BLACK, bevel=0.12)
    box('Display light', (x, 6, 1.12), (2.8, 2.25, 0.05), accent)
    text('OPEN' if x < 0 else 'HOME', (x, 9.76, 2.7), 0.40, accent)
    text('SECRET' if x < 0 else 'YOUR BASE', (x, 9.77, 3.4), 0.75, accent)
    box('Back light', (x, 9.7, 4.4), (8, 0.1, 0.1), ALARM if x < 0 else accent)
    # Display slots and architectural details make the bases recognizable.
    for off in (-3.4, 3.4):
        box('Empty slot', (x+off, 6, 0.3), (1.8, 1.8, 0.4), BLACK, bevel=0.06)
        box('Slot light', (x+off, 5.10, 0.51), (1.8, 0.04, 0.035), accent)

CRATE = mat('Shipping crate', (0.28, 0.20, 0.13))
for x, y, h in [(-14.4, -0.5, 1.7), (-3, -3, 0.9), (17.6, 8.8, 1.5), (5, 0.7, 1.2)]:
    box('Cargo crate', (x, y, h/2), (1.7, 1.5, h), CRATE, bevel=0.06)
    for dx in (-0.65, 0.65):
        box('Crate band', (x+dx, y-0.765, h/2), (0.08, 0.035, h), BLACK)
for x in range(-28, 33, 8):
    box('Lamp pole', (x, 13, 2.7), (0.16, 0.16, 5.4), BLACK)
    box('Lamp cap', (x, 13, 5.4), (0.8, 0.5, 0.15), CYAN)
    box('Distant building', (x, 18, 3.5 + (x%3)), (5, 4, 7 + (x%3)*2), NAVY)
    for z in (2, 4, 6):
        box('Window', (x, 15.95, z), (2.8, 0.02, 0.08), CYAN)

def avatar(name, jacket, cap=False):
    root = empty(name)
    box(name+'_Torso', (0, 0, 2.07), (1.5, 0.78, 1.42), jacket, root, 0.12)
    box(name+'_Zip', (0, -0.414, 2.12), (0.055, 0.035, 1.15), BLACK, root)
    head = empty(name+'_Head', (0, 0, 3.2), root)
    box(name+'_Hood', (0, 0.12, 0.02), (1.30, 1, 1.12), jacket, head, 0.15)
    box(name+'_Face', (0, -0.30, 0), (1.08, 0.62, 0.90), SKIN, head, 0.12)
    for side in (-1, 1):
        box(name+'_Eye', (side*0.23, -0.625, 0.09), (0.14, 0.028, 0.20), BLACK, head, 0.025)
        brow = box(name+'_Brow', (side*0.23, -0.629, 0.29), (0.25, 0.028, 0.052), BLACK, head)
        brow.rotation_euler.y = side * (-0.16 if name == 'Owner' else 0.10)
    box(name+'_Mouth', (0, -0.628, -0.21), (0.29, 0.03, 0.06), BLACK, head, 0.015)
    if cap:
        box(name+'_Cap', (0, 0, 0.56), (1.38, 1.06, 0.25), BLACK, head, 0.06)
        box(name+'_Bill', (0, -0.61, 0.5), (1.36, 0.65, 0.09), BLACK, head)
    for side, sign in [('L', -1), ('R', 1)]:
        leg = empty(name+'_Leg'+side, (sign*0.43, 0, 1.37), root)
        box('Pants', (0, 0, -0.55), (0.62, 0.65, 1.14), BLACK, leg, 0.07)
        box('Sneaker', (0, -0.15, -1.12), (0.65, 0.90, 0.29), WHITE, leg, 0.07)
        arm = empty(name+'_Arm'+side, (sign*0.98, 0, 2.65), root)
        box('Sleeve', (0, 0, -0.53), (0.46, 0.62, 1.05), jacket, arm, 0.08)
        box('Hand', (0, 0, -1.09), (0.46, 0.56, 0.35), SKIN, arm, 0.06)
    return root

avatar('Hero', CORAL)
avatar('Owner', WHITE, True)
avatar('Friend', YELLOW, True)
arm = bpy.data.objects['Owner_ArmR']
bat = box('Bonk bat', (0, -0.12, -1.9), (0.19, 0.19, 1.75), mat('Bat wood', (0.46, 0.26, 0.08)), arm, 0.06)

before = set(bpy.data.objects)
bpy.ops.import_scene.fbx(filepath=str(OUT / 'models/Flying_Dragon_Evolved.fbx'))
meshes = [o for o in set(bpy.data.objects)-before if o.type == 'MESH']
loot = meshes[0]
loot.name = 'Loot'
bpy.context.view_layer.update()
loot.scale *= 1.45 / loot.dimensions.z
loot.location = (-12, 6, 1.05)

sun = bpy.data.objects.new('Moon key', bpy.data.lights.new('Moon key', 'SUN'))
scene.collection.objects.link(sun)
sun.rotation_euler = (math.radians(28), math.radians(-18), math.radians(-25))
sun.data.energy = 2.2
sun.data.color = (0.69, 0.82, 1)
for name, loc, color, energy, size in [
    ('Front softbox', (0, -10, 10), (0.65, 0.83, 1), 2200, 14),
    ('Warm rim', (-10, 9, 7), (1, 0.30, 0.12), 1400, 8),
]:
    o = bpy.data.objects.new(name, bpy.data.lights.new(name, 'AREA'))
    scene.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = (Vector((0, 2, 1.5))-o.location).to_track_quat('-Z','Y').to_euler()
    o.data.energy, o.data.color, o.data.size = energy, color, size
    if hasattr(o.data, 'use_shadow'):
        o.data.use_shadow = False

cam = bpy.data.objects.new('Camera', bpy.data.cameras.new('Camera'))
scene.collection.objects.link(cam)
scene.camera = cam
cam.data.clip_start, cam.data.clip_end = 0.1, 150
sys.path.insert(0, str(Path(__file__).parent))
import story
story.register()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'heist.blend'))
