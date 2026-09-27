# TikTok / Shorts ad for Steal a Monster, rendered headless in Blender from the game's monster meshes.
# Usage: blender -b --python tools/video/tiktok.py -- <out.mp4> [--still FRAME out.png]
# 15 s, 1080x1920, 30 fps, silent (add a trending sound inside TikTok).
import math
import os
import sys

import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MODELS = os.path.join(ROOT, "build", "models")
FONT_PATH = os.path.join(ROOT, "assets", "fonts", "LuckiestGuy-Regular.ttf")
ARGS = sys.argv[sys.argv.index("--") + 1:]
OUT = ARGS[0]
STILL = int(ARGS[ARGS.index("--still") + 1]) if "--still" in ARGS else None

FPS = 30
END = 450

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE_NEXT"
scene.eevee.taa_render_samples = 16
scene.render.resolution_x, scene.render.resolution_y = 1080, 1920
scene.render.fps = FPS
scene.frame_start, scene.frame_end = 1, END
scene.view_settings.view_transform = "Standard"  # keep the cartoon colours punchy
scene.view_settings.look = "None"
FONT = bpy.data.fonts.load(FONT_PATH)

world = bpy.data.worlds.new("World")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.35, 0.3, 0.6, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 1.0

sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 4.0
sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(30))
scene.collection.objects.link(sun)


def hexcol(h, a=1.0):
    h = h.lstrip("#")
    return tuple((int(h[i:i + 2], 16) / 255) ** 2.2 for i in (0, 2, 4)) + (a,)


def material(name, color, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = 0.6
    if emission > 0:
        bsdf.inputs["Emission Color"].default_value = color
        bsdf.inputs["Emission Strength"].default_value = emission
    return mat


def box(name, size, loc, color, emission=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    obj.data.materials.append(material(name, color, emission))
    return obj


def monster(model, loc, height, yaw=0.0):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=os.path.join(MODELS, model + ".fbx"))
    obj = next(o for o in set(bpy.data.objects) - before if o.type == "MESH")
    for o in set(bpy.data.objects) - before:
        if o is not obj:
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.context.view_layer.update()
    h = max(obj.dimensions.z, 0.01)
    obj.scale = obj.scale * (height / h)
    obj.rotation_euler.z += yaw
    obj.location = loc
    return obj


def key_visible(obj, first, last):
    """Visible (rendered) only on frames first..last."""
    for f, hidden in ((1, True), (first, False), (last + 1, True)):
        if f < 1:
            continue
        obj.hide_render = hidden
        obj.keyframe_insert("hide_render", frame=f)
    if first <= 1:
        obj.hide_render = False
        obj.keyframe_insert("hide_render", frame=1)


def pop(obj, frame, base=1.0, over=1.25):
    """Scale 0 -> overshoot -> base, cartoon style."""
    for f, s in ((frame, 0.001), (frame + 4, base * over), (frame + 8, base * 0.95), (frame + 11, base)):
        obj.scale = (s, s, s)
        obj.keyframe_insert("scale", frame=f)


CAPTION_SCALE = 0.3
camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
camera.data.lens = 30
camera.data.clip_start = 0.05
scene.collection.objects.link(camera)
scene.camera = camera


def text(body, size, color, y, first, last, pop_at=None):
    """Screen-space caption: parented to the camera, y in [-1 (bottom), 1 (top)], with a black outline."""
    group = bpy.data.objects.new("Caption", None)
    scene.collection.objects.link(group)
    group.parent = camera
    # Close to the lens (scaled down to match) so captions never dip into the scenery
    group.location = (0, y * 6.2 * CAPTION_SCALE, -10 * CAPTION_SCALE)
    for layer, (col, offset, z) in enumerate(((hexcol("#111111"), size * 0.09, -0.08), (color, 0.0, 0.0))):
        curve = bpy.data.curves.new("Text", "FONT")
        curve.body = body
        curve.font = FONT
        curve.size = size
        curve.align_x = "CENTER"
        curve.align_y = "CENTER"
        curve.offset = offset
        obj = bpy.data.objects.new("Text", curve)
        obj.visible_shadow = False
        scene.collection.objects.link(obj)
        obj.parent = group
        obj.location = (0, 0, z)
        curve.materials.append(material("TextMat", col, emission=1.0 if layer else 0.0))
        key_visible(obj, first, last)
    pop(group, pop_at if pop_at is not None else first, base=CAPTION_SCALE)
    return group


def camera_shot(first, last, start, end, look_start, look_end):
    """Camera move for one shot (constant jump between shots, linear inside)."""
    for f, loc, look in ((first, start, look_start), (last, end, look_end)):
        camera.location = loc
        direction = Vector(look) - Vector(loc)
        camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        camera.keyframe_insert("location", frame=f)
        camera.keyframe_insert("rotation_euler", frame=f)


def ground(x, color):
    box("Ground", (40, 40, 0.5), (x, 0, -0.25), color)
    box("Backdrop", (40, 0.5, 30), (x, 14, 10), color, emission=0.25)


YELLOW, WHITE, RED, GREEN = hexcol("#FFD83A"), hexcol("#FFFFFF"), hexcol("#FF3B3B"), hexcol("#3BFF7A")

# --- Shot A (0-3 s): hook ---------------------------------------------------------------------
ground(0, hexcol("#6A2CC9"))
titan = monster("Big_BlueDemon", (0, 0, 0), 6.5)
camera_shot(1, 90, (0, -16, 4.2), (0, -10.5, 3.6), (0, 0, 3.8), (0, 0, 3.4))
text("POV:", 0.9, WHITE, 0.78, 1, 90)
text("SOMEONE STOLE", 1.05, WHITE, 0.62, 6, 90)
text("YOUR TITAN!", 1.5, RED, 0.43, 14, 90)
# the titan gets carried away at the end of the shot
for f, loc in ((60, (0, 0, 0)), (90, (9, -2, 3))):
    titan.location = loc
    titan.keyframe_insert("location", frame=f)

# --- Shot B (3-7 s): conveyor ---------------------------------------------------------------------
X = 70
ground(X, hexcol("#1F8FFF"))
box("Belt", (60, 5, 0.8), (X, 0, 0.4), hexcol("#2A2A36"))
for i in range(12):
    box("Stripe", (0.5, 5.05, 0.82), (X - 30 + i * 5, 0, 0.41), hexcol("#FFD83A"), emission=0.5)
belt = [
    ("Blob_Mushnub", "$15", "#C9CED8"),
    ("Blob_Cactoro", "$2K", "#2396FF"),
    ("Blob_Mushnub_Evolved", "$312K", "#A537FF"),
    ("Blob_Cat", "$41M", "#FFAF0F"),
    ("Big_Dino", "$1.4B", "#FF2D55"),
    ("Flying_Dragon_Evolved", "$216B", "#00FFC8"),
]
for i, (model, price, col) in enumerate(belt):
    m = monster(model, (0, 0, 0), 3.0 if not model.startswith("Big") else 3.6)
    for f, px in ((91, X - 22 + i * 7.5), (210, X - 6 + i * 7.5)):
        m.location = (px, 0, 0.8)
        m.keyframe_insert("location", frame=f)
    tag = bpy.data.curves.new("Price", "FONT")
    tag.body, tag.font, tag.size, tag.align_x, tag.extrude = price, FONT, 1.1, "CENTER", 0.05
    tag.materials.append(material("PriceMat", hexcol(col), emission=1.5))
    tag_obj = bpy.data.objects.new("PriceTag", tag)
    scene.collection.objects.link(tag_obj)
    tag_obj.rotation_euler = (math.radians(90), 0, 0)
    for f, px in ((91, X - 22 + i * 7.5), (210, X - 6 + i * 7.5)):
        tag_obj.location = (px, -0.5, 5.0)
        tag_obj.keyframe_insert("location", frame=f)
camera_shot(91, 210, (X + 4, -13.5, 4.2), (X + 10, -13.5, 4.0), (X + 4, 0, 2.6), (X + 10, 0, 2.6))
text("GRAB MONSTERS", 1.15, WHITE, 0.72, 91, 210)
text("OFF THE BELT!", 1.15, YELLOW, 0.56, 97, 210)
text("FROM $15", 1.25, WHITE, -0.5, 120, 210)
text("TO $216 BILLION!", 1.1, hexcol("#00FFC8"), -0.66, 150, 210)

# --- Shot C (7-10.5 s): growth -----------------------------------------------------------------------
X = 140
ground(X, hexcol("#18B85A"))
grower = monster("Flying_Dragon", (X, 0, 0), 1.3)
base_scale = grower.scale.copy()
stages = [("S", 1.0), ("M", 1.5), ("L", 2.1), ("XL", 2.8), ("TITAN", 3.8)]
for i, (name, s) in enumerate(stages):
    f = 211 + i * 20
    for df, k in ((0, s * 1.2), (5, s * 0.95), (9, s)):
        grower.scale = base_scale * k
        grower.keyframe_insert("scale", frame=f + df)
    text(name, 2.2 if name != "TITAN" else 2.0, YELLOW if name != "TITAN" else RED, -0.62, f, 315 if name == "TITAN" else f + 19)
camera_shot(211, 315, (X, -14, 3.5), (X, -17, 4.5), (X, 0, 2.0), (X, 0, 3.0))
text("THEY GROW", 1.3, WHITE, 0.72, 211, 315)
text("INTO TITANS!", 1.3, GREEN, 0.55, 217, 315)

# --- Shot D (10.5-13 s): stealing ----------------------------------------------------------------------
X = 210
ground(X, hexcol("#E0442C"))
for i, model in enumerate(("Blob_Chicken", "Big_Alien", "Blob_PinkBlob")):
    box("Pad", (3.4, 3.4, 0.3), (X - 5 + i * 5, 0, 0.15), hexcol("#36394A"))
    m = monster(model, (X - 5 + i * 5, 0, 0.3), 2.6 if i != 1 else 3.6)
    if model == "Big_Alien":
        for f, loc in ((316, (X, 0, 0.3)), (332, (X, 0, 0.3)), (342, (X, -1.5, 3.5)), (390, (X + 9, -4, 5))):
            m.location = loc
            m.keyframe_insert("location", frame=f)
camera_shot(316, 390, (X, -15, 4.5), (X + 2, -13, 5), (X, 0, 2.5), (X + 2, 0, 3))
text("STEAL", 1.6, WHITE, 0.72, 316, 390)
text("THE BEST ONES", 1.1, YELLOW, 0.56, 322, 390)
stamp = text("STOLEN!", 1.8, RED, -0.55, 350, 390)
stamp.rotation_euler = (0, 0, math.radians(-12))

# --- Shot E (13-15 s): logo ---------------------------------------------------------------------------
X = 280
ground(X, hexcol("#6A2CC9"))
for i, model in enumerate(("Blob_Cat", "Flying_Dragon", "Big_Yeti", "Blob_Fish", "Big_MushroomKing")):
    m = monster(model, (X - 8 + i * 4, 1.5 if i % 2 else 0, 0), 3.0 if i != 2 else 4.0)
    pop(m, 391 + i * 3, base=m.scale.x)
camera_shot(391, 450, (X, -17, 4), (X, -15, 4), (X, 0, 2.5), (X, 0, 2.5))
text("STEAL A", 1.5, WHITE, 0.74, 391, 450)
text("MONSTER", 2.1, YELLOW, 0.54, 395, 450)
text("PLAY NOW ON ROBLOX", 0.8, WHITE, -0.7, 405, 450)

# Camera cuts between shots, not glides
for fc in camera.animation_data.action.fcurves:
    for kp in fc.keyframe_points:
        kp.interpolation = "LINEAR"
for obj in bpy.data.objects:
    ad = obj.animation_data
    if ad and ad.action:
        for fc in ad.action.fcurves:
            if fc.data_path == "hide_render":
                for kp in fc.keyframe_points:
                    kp.interpolation = "CONSTANT"
# hold the first key of each shot: a constant step at the cut frame
shot_starts = [1, 91, 211, 316, 391]
for fc in camera.animation_data.action.fcurves:
    for kp in fc.keyframe_points:
        if int(kp.co.x) in (90, 210, 315, 390):
            kp.interpolation = "CONSTANT"

if STILL is not None:
    scene.frame_set(STILL)
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = ARGS[ARGS.index("--still") + 2]
    bpy.ops.render.render(write_still=True)
else:
    scene.render.image_settings.file_format = "FFMPEG"
    scene.render.ffmpeg.format = "MPEG4"
    scene.render.ffmpeg.codec = "H264"
    scene.render.ffmpeg.constant_rate_factor = "HIGH"
    scene.render.ffmpeg.ffmpeg_preset = "GOOD"
    scene.render.ffmpeg.audio_codec = "NONE"
    scene.render.filepath = OUT
    bpy.ops.render.render(animation=True)
