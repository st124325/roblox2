# Render 512x512 icons for every pass / developer product with the game's monsters (Blender, headless).
# Usage: blender -b --python tools/products/icons.py -- <out_dir> [key ...]
import math
import os
import sys

import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MODELS = os.path.join(ROOT, "build", "models")
FONT_PATH = os.path.join(ROOT, "assets", "fonts", "LuckiestGuy-Regular.ttf")
ARGS = sys.argv[sys.argv.index("--") + 1:]
OUT_DIR = ARGS[0]
ONLY = set(ARGS[1:])

# key: (monster model, label, background hex, extra prop)
ICONS = {
    "Passes.DoubleCash": ("Blob_Cat", "2X", "#1FB45A", "coins"),
    "Passes.VIP": ("Big_MushroomKing", "VIP", "#E8A317", "none"),  # already wears a crown
    "Passes.AutoCollect": ("Flying_Glub", "AUTO", "#2B7BE4", "coins"),
    "Passes.ExtraSlots": ("Blob_Mushnub", "+2", "#F07A1A", "pads"),
    "Passes.FastLegs": ("Blob_Chicken", "FAST", "#E23B3B", "speed"),
    "Items.StarterPack": ("Blob_PinkBlob", "START", "#9A3BE2", "coins"),
    "Items.UnlockPad": ("Blob_Dog", "UNLOCK", "#17A3A3", "pads"),
    "Items.Shield10": ("Big_Yeti", "10 MIN", "#2B7BE4", "shield"),
    "Items.Shield30": ("Big_Yeti", "30 MIN", "#1D4FB8", "shield"),
    "Items.GrowBoost": ("Flying_Dragon", "GROW", "#27B84A", "grow"),
    "Items.CashRain": ("Big_Alien", "2X ALL", "#E8A317", "coins"),
    "Items.CashSmall": ("Blob_Cat", "CASH", "#1FB45A", "coins"),
    "Items.CashMedium": ("Blob_Mushnub_Evolved", "BAG", "#189A4C", "coins"),
    "Items.CashLarge": ("Big_Cactoro", "VAULT", "#12803E", "coins"),
    "Items.CashHuge": ("Flying_Dragon_Evolved", "MEGA", "#0B6630", "coins"),
    "AdRewards.AdCash": ("Blob_Fish", "FREE", "#3B6FE2", "coins"),
    "AdRewards.AdShield": ("Blob_GreenBlob", "FREE", "#3B6FE2", "shield"),
    "AdRewards.AdDoubleOffline": ("Flying_Ghost", "2X", "#4B2A9A", "coins"),
    "Gifts.DoubleCash": ("Blob_Cat", "GIFT", "#E24B9A", "gift"),
    "Gifts.VIP": ("Big_MushroomKing", "GIFT", "#E24B9A", "gift"),
    "Gifts.AutoCollect": ("Flying_Glub", "GIFT", "#E24B9A", "gift"),
    "Gifts.ExtraSlots": ("Blob_Mushnub", "GIFT", "#E24B9A", "gift"),
    "Gifts.FastLegs": ("Blob_Chicken", "GIFT", "#E24B9A", "gift"),
}


def hexcol(h, a=1.0):
    h = h.lstrip("#")
    return tuple((int(h[i:i + 2], 16) / 255) ** 2.2 for i in (0, 2, 4)) + (a,)


def material(name, color, emission=0.0, alpha=1.0, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = 0.35
    bsdf.inputs["Metallic"].default_value = metallic
    if emission:
        bsdf.inputs["Emission Color"].default_value = color
        bsdf.inputs["Emission Strength"].default_value = emission
    if alpha < 1:
        bsdf.inputs["Alpha"].default_value = alpha
        mat.surface_render_method = "BLENDED"
    return mat


def setup():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.eevee.taa_render_samples = 32
    scene.render.resolution_x = scene.render.resolution_y = 512
    scene.view_settings.view_transform = "Standard"
    scene.render.image_settings.file_format = "PNG"
    world = bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.4
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.4
    sun.rotation_euler = (math.radians(40), math.radians(-15), math.radians(20))
    scene.collection.objects.link(sun)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 7.0
    cam.location = (0, -20, 2.5)
    cam.rotation_euler = (math.radians(88), 0, 0)
    scene.collection.objects.link(cam)
    scene.camera = cam
    return scene


def monster(model, height):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=os.path.join(MODELS, model + ".fbx"))
    new = set(bpy.data.objects) - before
    obj = next(o for o in new if o.type == "MESH")
    for o in new:
        if o is not obj:
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.context.view_layer.update()
    s = height / max(obj.dimensions.z, 0.01)
    wide = max(obj.dimensions.x, obj.dimensions.y) * s
    if wide > 5.2:  # wings: fit the frame
        s *= 5.2 / wide
    obj.scale = obj.scale * s
    obj.location = (0, 0, 0.35)
    return obj


def text(body, size, loc, color, outline=True):
    for layer, (col, offset, dy) in enumerate(((hexcol("#151515"), size * 0.11, 0.08), (color, 0, 0))):
        if layer == 0 and not outline:
            continue
        curve = bpy.data.curves.new("T", "FONT")
        curve.body = body
        curve.font = bpy.data.fonts.load(FONT_PATH, check_existing=True)
        curve.size = size
        curve.align_x = "CENTER"
        curve.align_y = "CENTER"
        curve.offset = offset
        obj = bpy.data.objects.new("T", curve)
        obj.rotation_euler = (math.radians(90), 0, math.radians(-4))
        obj.location = Vector(loc) + Vector((0, -2 - layer * 0.1, 0)) + Vector((0, 0, 0))
        obj.visible_shadow = False
        curve.materials.append(material("TM", col, emission=0.8 if layer else 0))
        bpy.context.scene.collection.objects.link(obj)


def coin(loc, rot):
    bpy.ops.mesh.primitive_cylinder_add(radius=0.42, depth=0.12, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.data.materials.append(material("Gold", hexcol("#FFC92E"), emission=0.15, metallic=0.7))


def prop(kind, bg):
    if kind in ("coins", "gift"):
        for loc, rot in (((-2.5, -1, 0.5), (1.2, 0.3, 0)), ((2.4, -1, 0.9), (1.4, -0.4, 0.3)),
                         ((-2.2, -1, 4.6), (0.9, 0.5, 0.2)), ((2.5, -1, 4.2), (1.6, 0.2, -0.3))):
            coin(loc, rot)
    if kind == "gift":
        bpy.ops.mesh.primitive_cube_add(size=1.3, location=(2.2, -1.2, 0.8))
        bpy.context.active_object.data.materials.append(material("Gift", hexcol("#FFD23F")))
        bpy.ops.mesh.primitive_cube_add(size=1, location=(2.2, -1.2, 0.8), scale=(1.36, 0.25, 1.36))
        bpy.context.active_object.data.materials.append(material("Ribbon", hexcol("#E8283C"), emission=0.2))
    if kind == "shield":
        bpy.ops.mesh.primitive_uv_sphere_add(radius=2.8, location=(0, 0, 2.0), segments=48, ring_count=24)
        bpy.context.active_object.data.materials.append(material("Shield", hexcol("#6FD8FF"), emission=0.3, alpha=0.18))
    if kind == "crown":
        bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.8, radius2=1.05, depth=0.6, location=(0, 0, 4.55))
        bpy.context.active_object.data.materials.append(material("Crown", hexcol("#FFD23F"), emission=0.2, metallic=0.8))
    if kind == "pads":
        for x in (-2.2, 2.2):
            bpy.ops.mesh.primitive_cube_add(size=1, location=(x, -0.5, 0.2), scale=(1.5, 1.5, 0.3))
            bpy.context.active_object.data.materials.append(material("Pad", hexcol("#FFFFFF"), emission=0.4))
    if kind == "speed":
        for i, z in enumerate((1.0, 1.8, 2.6)):
            bpy.ops.mesh.primitive_cube_add(size=1, location=(-2.4 - i * 0.2, -0.5, z), scale=(1.6, 0.05, 0.12))
            bpy.context.active_object.data.materials.append(material("Streak", hexcol("#FFFFFF"), emission=1))


def render(key, out):
    model, label, bg, kind = ICONS[key]
    setup()
    # radial glow background
    bpy.context.scene.world.node_tree.nodes["Background"].inputs[0].default_value = hexcol(bg)
    bpy.ops.mesh.primitive_plane_add(size=30, location=(0, 8, 2.6), rotation=(math.radians(90), 0, 0))
    bpy.context.active_object.data.materials.append(material("BG", hexcol(bg), emission=1.0))
    bpy.ops.mesh.primitive_circle_add(vertices=64, radius=3.4, fill_type="NGON", location=(0, 7.5, 2.8), rotation=(math.radians(90), 0, 0))
    bpy.context.active_object.data.materials.append(material("Glow", hexcol("#FFFFFF"), emission=0.5, alpha=0.22))
    monster(model, 3.2 if not model.startswith("Big") else 3.7)
    prop(kind, bg)
    size = 1.8 if len(label) <= 3 else (1.4 if len(label) <= 5 else 1.1)
    text(label, size, (0, 0, 0.0 if kind != "crown" else -0.1), hexcol("#FFFFFF"))
    bpy.context.scene.render.filepath = out
    bpy.ops.render.render(write_still=True)


os.makedirs(OUT_DIR, exist_ok=True)
for key in ICONS:
    if ONLY and key not in ONLY:
        continue
    render(key, os.path.join(OUT_DIR, key + ".png"))
