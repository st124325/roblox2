"""Render one shot of the prepared scene. Run only on GitHub Actions."""
import bpy
import json
import os
import sys

args = sys.argv[sys.argv.index("--") + 1:]
chunk, output = args
with open("build/timeline.json") as f:
    timeline = json.load(f)
scene = bpy.context.scene
index = int(chunk)
count = 20
first = timeline["frames"] * index // count + 1
last = timeline["frames"] * (index + 1) // count
scene.frame_start, scene.frame_end = first, last
scene.render.image_settings.file_format = "FFMPEG"
scene.render.ffmpeg.format = "MPEG4"
scene.render.ffmpeg.codec = "H264"
scene.render.ffmpeg.constant_rate_factor = "HIGH"
scene.render.ffmpeg.ffmpeg_preset = "GOOD"
scene.render.ffmpeg.audio_codec = "AAC"
scene.render.ffmpeg.audio_bitrate = 192
scene.render.ffmpeg.audio_mixrate = 44100
scene.render.ffmpeg.audio_channels = "STEREO"
scene.render.filepath = os.path.abspath(output)
bpy.ops.render.render(animation=True)
# A review frame per shot, rendered by whichever chunk contains it.
for key, (start, end, _) in timeline["shots"].items():
    frame = (start + end) // 2
    if first <= frame <= last:
        scene.frame_set(frame)
        scene.render.image_settings.file_format = "PNG"
        scene.render.filepath = os.path.abspath(os.path.join(os.path.dirname(output), key + ".png"))
        bpy.ops.render.render(write_still=True)
