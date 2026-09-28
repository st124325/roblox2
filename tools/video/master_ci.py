"""Master one continuous soundtrack and exact 30 fps timing, inside Actions."""
import bpy
import json
import math
from pathlib import Path
import subprocess

def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True)

timeline = json.loads(Path('build/timeline.json').read_text())
scene = bpy.context.scene
scene.frame_start, scene.frame_end = 1, timeline['frames']
bpy.ops.sound.mixdown(filepath=str(Path('build/master.wav').resolve()),
    container='WAV', codec='PCM', format='F32', split_channels=False)
analysis = run('ffmpeg', '-hide_banner', '-i', 'build/master.wav', '-af',
    'loudnorm=I=-14:TP=-1:LRA=9:print_format=json', '-f', 'null', '-').stderr
levels = json.loads(analysis[analysis.rfind('{'):])
assert math.isfinite(float(levels['input_i'])) and float(levels['input_i']) > -50, levels
filt = ('loudnorm=I=-14:TP=-1:LRA=9:linear=true:'
    f"measured_I={levels['input_i']}:measured_TP={levels['input_tp']}:"
    f"measured_LRA={levels['input_lra']}:measured_thresh={levels['input_thresh']}:"
    f"offset={levels['target_offset']}")
run('ffmpeg', '-y', '-i', 'delivery/tiktok-american.mp4', '-i', 'build/master.wav',
    '-map', '0:v:0', '-map', '1:a:0', '-vf', 'setpts=N/(30*TB)', '-r', '30',
    '-c:v', 'libx264', '-preset', 'medium', '-crf', '18', '-pix_fmt', 'yuv420p',
    '-af', filt, '-c:a', 'aac', '-b:a', '192k', '-ar', '48000',
    '-movflags', '+faststart', '-t', str(timeline['frames']/30), 'delivery/mastered.mp4')
probe = json.loads(run('ffprobe', '-v', 'error', '-count_frames', '-show_streams',
    '-show_format', '-of', 'json', 'delivery/mastered.mp4').stdout)
video = next(s for s in probe['streams'] if s['codec_type'] == 'video')
audio = next(s for s in probe['streams'] if s['codec_type'] == 'audio')
assert int(video['nb_read_frames']) == timeline['frames'], video
assert video['avg_frame_rate'] == '30/1', video
assert (video['width'], video['height']) == (1080, 1920), video
assert audio['codec_name'] == 'aac' and audio['sample_rate'] == '48000', audio
assert abs(float(probe['format']['duration']) - timeline['frames']/30) < 0.05, probe
Path('delivery/mastered.mp4').replace('delivery/tiktok-american.mp4')
Path('delivery/metadata.json').write_text(json.dumps(probe, indent=2))
print('VERIFIED', timeline['frames'], 'frames at 30 fps; continuous US voice, music and effects')
