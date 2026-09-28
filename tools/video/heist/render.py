"""Render storyboard frames or one animation chunk on GitHub Actions."""
from pathlib import Path
import json
import sys
import bpy

HERE = Path(__file__).parent
sys.path.insert(0,str(HERE))
import story
story.register()
cfg = json.loads((HERE/'config.json').read_text())
root = HERE.parents[2]
build = root/'build/heist'
(build/'parts').mkdir(parents=True, exist_ok=True)
scene = bpy.context.scene
mode = sys.argv[sys.argv.index('--')+1]
if mode == 'preview':
    times = [1.2,3.4,6.9,8.6,11.5,15.4,17.7,20.3]
    (build/'preview/times.json').write_text(json.dumps(times))
    for i,t in enumerate(times):
        scene.frame_set(round(t*cfg['fps'])+1)
        scene.render.image_settings.file_format = 'PNG'
        scene.render.filepath = str(build/f'raw/preview-{i:02}.png')
        bpy.ops.render.render(write_still=True)
else:
    index = int(mode)
    frames = cfg['fps']*cfg['seconds']
    scene.frame_start = frames*index//cfg['chunks']+1
    scene.frame_end = frames*(index+1)//cfg['chunks']
    scene.render.image_settings.file_format = 'FFMPEG'
    scene.render.ffmpeg.format = 'MPEG4'
    scene.render.ffmpeg.codec = 'H264'
    scene.render.ffmpeg.constant_rate_factor = 'HIGH'
    scene.render.ffmpeg.ffmpeg_preset = 'GOOD'
    scene.render.ffmpeg.audio_codec = 'NONE'
    scene.render.filepath = str(build/f'parts/part-{index:02}.mp4')
    bpy.ops.render.render(animation=True)
