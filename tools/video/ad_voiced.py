# Voiced ad (~26 s, 1080x1920) for Steal a Monster: voiceover + synthesized music + sound effects,
# rendered headless in Blender from the game's monster meshes. Shots are timed to the voice lines.
#
# 1. Voice lines (Piper TTS, voice "joe", CC0) -> build/voice/<key>.wav, see tools/video/voice_lines.txt
# 2. blender -b --python tools/video/ad_voiced.py -- <out.mp4> [--still FRAME out.png]
import math
import os
import random
import sys
import wave
import json

import bpy
import numpy as np
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MODELS = os.path.join(ROOT, "build", "models")
VOICE = os.path.join(ROOT, "build", "voice")
AUDIO = os.path.join(ROOT, "build", "audio")
FONT_PATH = os.path.join(ROOT, "assets", "fonts", "LuckiestGuy-Regular.ttf")
ARGS = sys.argv[sys.argv.index("--") + 1:]
OUT = ARGS[0]
STILL = int(ARGS[ARGS.index("--still") + 1]) if "--still" in ARGS else None
FPS = 30
RATE = 44100
os.makedirs(AUDIO, exist_ok=True)
random.seed(7)

# --- timeline from the voice lines ----------------------------------------------------------------
LINES = ["hook", "belt", "cash", "grow", "steal", "defend", "outro"]
PAD_BEFORE = {"hook": 4}
PAD_AFTER = {"outro": 45}
shots, cursor = {}, 1
for key in LINES:
    w = wave.open(os.path.join(VOICE, key + ".wav"))
    dur = w.getnframes() / w.getframerate()
    first = cursor
    vo = first + PAD_BEFORE.get(key, 7)
    last = vo + math.ceil(dur * FPS) + PAD_AFTER.get(key, 8)
    shots[key] = (first, last, vo)
    cursor = last + 1
END = cursor - 1

# --- scene ------------------------------------------------------------------------------------------
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE_NEXT"
scene.eevee.taa_render_samples = 4
scene.render.resolution_x, scene.render.resolution_y = 1080, 1920
scene.render.fps = FPS
scene.frame_start, scene.frame_end = 1, END
scene.view_settings.view_transform = "Standard"
FONT = bpy.data.fonts.load(FONT_PATH)
world = bpy.data.worlds.new("World")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.35, 0.3, 0.6, 1)
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 4.0
sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(30))
scene.collection.objects.link(sun)


def hexcol(h, a=1.0):
    h = h.lstrip("#")
    return tuple((int(h[i:i + 2], 16) / 255) ** 2.2 for i in (0, 2, 4)) + (a,)


def material(name, color, emission=0.0, alpha=1.0, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = 0.55
    bsdf.inputs["Metallic"].default_value = metallic
    if emission:
        bsdf.inputs["Emission Color"].default_value = color
        bsdf.inputs["Emission Strength"].default_value = emission
    if alpha < 1:
        bsdf.inputs["Alpha"].default_value = alpha
        mat.surface_render_method = "DITHERED"
    return mat


def box(name, size, loc, color, emission=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    obj.data.materials.append(material(name, color, emission))
    return obj


def monster(model, loc, height):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=os.path.join(MODELS, model + ".fbx"))
    new = set(bpy.data.objects) - before
    obj = next(o for o in new if o.type == "MESH")
    for o in new:
        if o is not obj:
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.context.view_layer.update()
    obj.scale = obj.scale * (height / max(obj.dimensions.z, 0.01))
    obj.location = loc
    return obj


def key_visible(obj, first, last):
    obj.hide_render = True
    obj.keyframe_insert("hide_render", frame=1)
    obj.hide_render = False
    obj.keyframe_insert("hide_render", frame=max(first, 1))
    obj.hide_render = True
    obj.keyframe_insert("hide_render", frame=last + 1)


def pop(obj, frame, base=1.0, over=1.25):
    for f, s in ((frame, 0.001), (frame + 4, base * over), (frame + 8, base * 0.95), (frame + 11, base)):
        obj.scale = (s, s, s)
        obj.keyframe_insert("scale", frame=f)


CAPTION_SCALE = 0.3
camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
camera.data.lens = 30
camera.data.clip_start = 0.05
scene.collection.objects.link(camera)
scene.camera = camera


def text(body, size, color, y, first, last, pop_at=None, tilt=0.0):
    group = bpy.data.objects.new("Caption", None)
    scene.collection.objects.link(group)
    group.parent = camera
    group.location = (0, y * 6.2 * CAPTION_SCALE, -10 * CAPTION_SCALE)
    group.rotation_euler = (0, 0, math.radians(tilt))
    for layer, (col, offset, z) in enumerate(((hexcol("#111111"), size * 0.09, -0.08), (color, 0.0, 0.0))):
        curve = bpy.data.curves.new("Text", "FONT")
        curve.body, curve.font, curve.size = body, FONT, size
        curve.align_x = curve.align_y = "CENTER"
        curve.offset = 0  # Expanded font curves self-intersect; use a clean drop shadow.
        obj = bpy.data.objects.new("Text", curve)
        obj.visible_shadow = False
        scene.collection.objects.link(obj)
        obj.parent = group
        obj.location = (size * 0.025 if layer == 0 else 0, -size * 0.035 if layer == 0 else 0, z)
        curve.materials.append(material("TextMat", col, emission=1.0 if layer else 0.0))
        key_visible(obj, first, last)
    pop(group, pop_at if pop_at is not None else first, base=CAPTION_SCALE)
    return group


def camera_shot(first, last, start, end, look_start, look_end):
    for f, loc, look in ((first, start, look_start), (last, end, look_end)):
        camera.location = loc
        camera.rotation_euler = (Vector(look) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        camera.keyframe_insert("location", frame=f)
        camera.keyframe_insert("rotation_euler", frame=f)


def ground(x, color):
    box("Ground", (40, 40, 0.5), (x, 0, -0.25), color)
    box("Backdrop", (40, 0.5, 30), (x, 14, 10), color, emission=0.25)


def world_text(body, size, color, loc, first, last):
    curve = bpy.data.curves.new("W", "FONT")
    curve.body, curve.font, curve.size = body, FONT, size
    curve.align_x = curve.align_y = "CENTER"
    curve.materials.append(material("WMat", color, emission=1.5))
    obj = bpy.data.objects.new("W", curve)
    obj.rotation_euler = (math.radians(90), 0, 0)
    obj.visible_shadow = False
    scene.collection.objects.link(obj)
    obj.location = loc
    key_visible(obj, first, last)
    return obj


YELLOW, WHITE, RED, GREEN, CYAN = (hexcol(c) for c in ("#FFD83A", "#FFFFFF", "#FF3B3B", "#3BFF7A", "#00FFC8"))
SFX = []  # (name, frame, volume)

# --- shots ------------------------------------------------------------------------------------------
f0, f1, vo = shots["hook"]
ground(0, hexcol("#6A2CC9"))
titan = monster("Big_BlueDemon", (0, 0, 0), 6.5)
camera_shot(f0, f1, (0, -16, 4.2), (0, -11, 3.6), (0, 0, 3.8), (0, 0, 3.4))
text("SOMEONE STOLE", 1.05, WHITE, 0.62, f0, f1)
text("MY TITAN!", 1.7, RED, 0.43, vo + 18, f1)
for f, loc in ((f1 - 22, (0, 0, 0)), (f1, (8, -2, 3))):
    titan.location = loc
    titan.keyframe_insert("location", frame=f)
SFX.append(("alarm", vo + 18, 0.5))

f0, f1, vo = shots["belt"]
X = 70
ground(X, hexcol("#1F8FFF"))
box("Belt", (80, 5, 0.8), (X, 0, 0.4), hexcol("#2A2A36"))
for i in range(16):
    stripe = box("Stripe", (0.5, 5.05, 0.82), (X - 40 + i * 5, 0, 0.41), YELLOW, emission=0.5)
belt = [("Blob_Mushnub", "$15", "#C9CED8"), ("Blob_Cactoro", "$2K", "#2396FF"), ("Blob_Mushnub_Evolved", "$312K", "#A537FF"),
        ("Blob_Cat", "$41M", "#FFAF0F"), ("Big_Dino", "$1.4B", "#FF2D55"), ("Big_BlueDemon", "$216B", "#00FFC8")]
for i, (model, price, col) in enumerate(belt):
    m = monster(model, (0, 0, 0), 3.0 if not model.startswith("Big") else 3.6)
    tag = world_text(price, 1.1, hexcol(col), (0, 0, 0), f0, f1)
    for f, px in ((f0, X - 26 + i * 7.5), (f1, X - 6 + i * 7.5)):
        m.location = (px, 0, 0.8)
        m.keyframe_insert("location", frame=f)
        tag.location = (px, -0.5, 5.0)
        tag.keyframe_insert("location", frame=f)
camera_shot(f0, f1, (X - 2, -13.5, 4.2), (X + 8, -13.5, 4.0), (X - 2, 0, 2.6), (X + 8, 0, 2.6))
text("GRAB MONSTERS", 1.15, WHITE, 0.72, f0, f1)
text("OFF THE BELT!", 1.15, YELLOW, 0.56, vo + 20, f1)
text("FROM $15", 1.25, WHITE, -0.5, vo + 40, f1)
text("TO $216 BILLION!", 1.1, CYAN, -0.66, vo + 60, f1)
SFX += [("coin", vo + 40, 0.5), ("coin", vo + 60, 0.6)]

f0, f1, vo = shots["cash"]
X = 140
ground(X, hexcol("#18B85A"))
for i, model in enumerate(("Blob_Cat", "Big_Frog", "Blob_Fish")):
    px = X - 5 + i * 5
    box("Pad", (3.4, 3.4, 0.3), (px, 0, 0.15), hexcol("#36394A"))
    monster(model, (px, 0, 0.3), 2.6 if i != 1 else 3.4)
    # "+$" popping up above each monster, three times
    for k in range(3):
        t0 = vo + 6 + k * 26 + i * 7
        t1 = min(t0 + 22, f1)
        pop_text = world_text("+ CASH", 0.8, GREEN, (px, -0.6, 3.6), t0, t1)
        for f, z in ((t0, 3.6 if i != 1 else 4.4), (t1, 5.2 if i != 1 else 6.0)):
            pop_text.location = (px, -0.6, z)
            pop_text.keyframe_insert("location", frame=f)
        SFX.append(("coin", t0, 0.35))
camera_shot(f0, f1, (X, -15, 4.5), (X, -13, 4.2), (X, 0, 2.4), (X, 0, 2.6))
text("CASH", 1.9, GREEN, 0.7, f0, f1)
text("EVERY SECOND!", 1.1, WHITE, 0.52, vo + 30, f1)

f0, f1, vo = shots["grow"]
X = 210
ground(X, hexcol("#27A84A"))
grower = monster("Flying_Dragon", (X, 0, 0), 1.3)
base_scale = grower.scale.copy()
stages = [("S", 1.0), ("M", 1.5), ("L", 2.1), ("XL", 2.8), ("TITAN", 3.8)]
step = max(8, (f1 - vo - 10) // len(stages))
for i, (name, s) in enumerate(stages):
    f = vo + i * step
    for df, k in ((0, s * 1.2), (5, s * 0.95), (9, s)):
        grower.scale = base_scale * k
        grower.keyframe_insert("scale", frame=f + df)
    last_frame = f1 if name == "TITAN" else f + step - 1
    text(name, 2.2 if name != "TITAN" else 2.0, YELLOW if name != "TITAN" else RED, -0.62, f, last_frame)
    SFX.append(("pop", f, 0.55 if name != "TITAN" else 0.8))
camera_shot(f0, f1, (X, -14, 3.5), (X, -17, 4.5), (X, 0, 2.0), (X, 0, 3.0))
text("THEY GROW", 1.3, WHITE, 0.72, f0, f1)
text("INTO TITANS!", 1.3, GREEN, 0.55, vo + step * 4, f1)

f0, f1, vo = shots["steal"]
X = 280
ground(X, hexcol("#E0442C"))
for i, model in enumerate(("Blob_Chicken", "Big_Alien", "Blob_PinkBlob")):
    box("Pad", (3.4, 3.4, 0.3), (X - 5 + i * 5, 0, 0.15), hexcol("#36394A"))
    m = monster(model, (X - 5 + i * 5, 0, 0.3), 2.6 if i != 1 else 3.6)
    if model == "Big_Alien":
        grab = vo + 30
        for f, loc in ((f0, (X, 0, 0.3)), (grab, (X, 0, 0.3)), (grab + 10, (X, -1.5, 3.5)), (f1, (X + 9, -4, 5))):
            m.location = loc
            m.keyframe_insert("location", frame=f)
camera_shot(f0, f1, (X, -15, 4.5), (X + 2, -13, 5), (X, 0, 2.5), (X + 2, 0, 3))
text("WATCH OUT!", 1.4, WHITE, 0.72, f0, f1)
text("THIEVES!", 1.4, YELLOW, 0.55, vo + 20, f1)
text("STOLEN!", 1.8, RED, -0.55, vo + 40, f1, tilt=-12)
SFX += [("alarm", vo + 40, 0.6)]

f0, f1, vo = shots["defend"]
X = 350
ground(X, hexcol("#2B5BD8"))
for i, model in enumerate(("Blob_Cat", "Flying_Glub", "Blob_Dog")):
    box("Pad", (3.4, 3.4, 0.3), (X - 5 + i * 5, 0, 0.15), hexcol("#36394A"))
    monster(model, (X - 5 + i * 5, 0, 0.3), 2.6)
bpy.ops.mesh.primitive_uv_sphere_add(radius=8, location=(X, 0, 0), segments=48, ring_count=24)
dome = bpy.context.active_object
dome.data.materials.append(material("Dome", hexcol("#6FD8FF"), emission=0.25, alpha=0.12))
dome.visible_shadow = False
pop(dome, vo + 4, base=1.0, over=1.1)
third = (f1 - vo) // 3
camera_shot(f0, f1, (X, -19, 6), (X, -17, 5.5), (X, 0, 2.5), (X, 0, 2.5))
text("LOCK", 1.6, CYAN, 0.72, vo, f1)
text("BONK", 1.6, YELLOW, 0.56, vo + third, f1)
text("STEAL!", 1.6, RED, 0.40, vo + 2 * third, f1)
SFX += [("pop", vo + 4, 0.6), ("boom", vo + third, 0.45), ("coin", vo + 2 * third, 0.6)]

f0, f1, vo = shots["outro"]
X = 420
ground(X, hexcol("#6A2CC9"))
for i, model in enumerate(("Blob_Cat", "Flying_Dragon", "Big_Yeti", "Blob_Fish", "Big_MushroomKing")):
    m = monster(model, (X - 8 + i * 4, 1.5 if i % 2 else 0, 0), 3.0 if i != 2 else 4.0)
    pop(m, f0 + i * 3, base=m.scale.x)
camera_shot(f0, f1, (X, -17, 4), (X, -15, 4), (X, 0, 2.5), (X, 0, 2.5))
text("STEAL A", 1.5, WHITE, 0.74, f0, f1)
text("MONSTER", 2.1, YELLOW, 0.54, f0 + 4, f1)
text("PLAY NOW ON ROBLOX", 0.8, WHITE, -0.7, vo + 20, f1)
SFX += [("boom", f0, 0.7)]
for key in LINES[1:]:
    SFX.append(("whoosh", shots[key][0], 0.45))

# camera cuts at shot boundaries
for fc in camera.animation_data.action.fcurves:
    for kp in fc.keyframe_points:
        kp.interpolation = "CONSTANT" if int(kp.co.x) in {shots[k][1] for k in LINES} else "LINEAR"
for obj in bpy.data.objects:
    if obj.animation_data and obj.animation_data.action:
        for fc in obj.animation_data.action.fcurves:
            if fc.data_path == "hide_render":
                for kp in fc.keyframe_points:
                    kp.interpolation = "CONSTANT"


# --- audio: synthesized music and effects -----------------------------------------------------------
def write_wav(path, signal):
    signal = np.clip(signal, -1, 1)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((signal * 32767).astype(np.int16).tobytes())


def env(n, decay):
    return np.exp(-np.arange(n) / (decay * RATE))


def music(seconds):
    bpm = 124
    beat = 60 / bpm
    n = int(seconds * RATE)
    out = np.zeros(n)
    t_kick = np.arange(int(0.3 * RATE)) / RATE
    freq = 45 + 90 * np.exp(-t_kick * 25)
    kick = np.sin(2 * np.pi * np.cumsum(freq) / RATE) * np.exp(-t_kick * 9)
    rng = np.random.default_rng(3)
    clap = rng.uniform(-1, 1, int(0.15 * RATE)) * env(int(0.15 * RATE), 0.04)
    hat_noise = rng.uniform(-1, 1, int(0.05 * RATE))
    hat = (hat_noise - np.convolve(hat_noise, np.ones(6) / 6, "same")) * env(len(hat_noise), 0.012)
    roots = [48, 45, 41, 43]  # C, Am, F, G
    chords = [[60, 64, 67], [57, 60, 64], [53, 57, 60], [55, 59, 62]]

    def note(midi, dur, shape="tri"):
        f = 440 * 2 ** ((midi - 69) / 12)
        t = np.arange(int(dur * RATE)) / RATE
        if shape == "tri":
            wave_ = 2 * np.abs(2 * ((t * f) % 1) - 1) - 1
        else:
            wave_ = np.sign(np.sin(2 * np.pi * f * t)) * 0.6 + np.sin(2 * np.pi * f * t) * 0.4
        return wave_ * env(len(t), dur * 0.35)

    def add(sig, at, gain):
        i = int(at * RATE)
        if i >= n:
            return
        j = min(n, i + len(sig))
        out[i:j] += sig[: j - i] * gain

    beats = int(seconds / beat) + 1
    for b in range(beats):
        t = b * beat
        bar = (b // 4) % 4
        intro = b < 4  # no kick for the first bar: the hook voice line lands clean
        if not intro:
            add(kick, t, 0.9)
        if b % 2 == 1 and not intro:
            add(clap, t, 0.35)
        for h in range(2):
            add(hat, t + h * beat / 2, 0.18)
        for h in range(2):
            add(note(roots[bar] - 12, beat / 2 * 0.9, "sq"), t + h * beat / 2, 0.22)
        for h in range(4):
            add(note(chords[bar][(b * 4 + h) % 3] + 12, beat / 4 * 0.9), t + h * beat / 4, 0.1)
    return out / max(1e-6, np.max(np.abs(out))) * 0.8


def sfx_coin():
    t = np.arange(int(0.35 * RATE)) / RATE
    a = np.sin(2 * np.pi * 1318.5 * t) * (t < 0.07)
    b = np.sin(2 * np.pi * 1975.5 * t) * (t >= 0.07)
    return (a + b) * env(len(t), 0.12) * 0.8


def sfx_pop():
    t = np.arange(int(0.25 * RATE)) / RATE
    f = 300 + 900 * (1 - np.exp(-t * 20))
    return np.sin(2 * np.pi * np.cumsum(f) / RATE) * env(len(t), 0.07)


def sfx_whoosh():
    rng = np.random.default_rng(1)
    n = int(0.45 * RATE)
    noise = rng.uniform(-1, 1, n)
    k = np.linspace(40, 4, n).astype(int)
    smooth = np.array([noise[max(0, i - k[i]):i + 1].mean() for i in range(n)])
    shape = np.sin(np.linspace(0, np.pi, n))
    return smooth * shape * 2.5


def sfx_alarm():
    t = np.arange(int(0.9 * RATE)) / RATE
    f = 700 + 300 * np.sign(np.sin(2 * np.pi * 5 * t))
    return np.sign(np.sin(2 * np.pi * np.cumsum(f) / RATE)) * 0.35 * env(len(t), 0.5)


def sfx_boom():
    t = np.arange(int(0.8 * RATE)) / RATE
    rng = np.random.default_rng(2)
    f = 40 + 80 * np.exp(-t * 10)
    return (np.sin(2 * np.pi * np.cumsum(f) / RATE) + rng.uniform(-0.4, 0.4, len(t)) * np.exp(-t * 20)) * np.exp(-t * 4)


write_wav(os.path.join(AUDIO, "music.wav"), music(END / FPS + 1))
for name, fn in (("coin", sfx_coin), ("pop", sfx_pop), ("whoosh", sfx_whoosh), ("alarm", sfx_alarm), ("boom", sfx_boom)):
    write_wav(os.path.join(AUDIO, name + ".wav"), fn())

seq = scene.sequence_editor_create()
strips = seq.strips if hasattr(seq, "strips") else seq.sequences


def sound(name, path, channel, frame, volume):
    strip = strips.new_sound(name, path, channel, frame)
    strip.volume = volume
    return strip


sound("music", os.path.join(AUDIO, "music.wav"), 1, 1, 0.12)
for key in LINES:
    sound("vo_" + key, os.path.join(VOICE, key + ".wav"), 2, shots[key][2], 0.85)
for i, (name, frame, volume) in enumerate(SFX):
    ch = 3 + i % 5  # spread over channels so overlapping effects don't clash
    sound(f"sfx_{name}_{i}", os.path.join(AUDIO, name + ".wav"), ch, max(1, frame), volume * 0.65)

print(f"TIMELINE {END} frames ({END / FPS:.1f}s): " + ", ".join(f"{k} {v[0]}-{v[1]}" for k, v in shots.items()))

if "--prepare" in ARGS:
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(os.path.join(os.path.dirname(OUT), "timeline.json"), "w") as f:
        json.dump({"fps": FPS, "frames": END, "shots": shots}, f)
    bpy.ops.wm.save_as_mainfile(filepath=OUT)
elif STILL is not None:
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
    scene.render.ffmpeg.audio_codec = "AAC"
    scene.render.ffmpeg.audio_bitrate = 192
    scene.render.ffmpeg.audio_mixrate = RATE
    scene.render.ffmpeg.audio_channels = "STEREO"
    scene.render.filepath = OUT
    bpy.ops.render.render(animation=True)
