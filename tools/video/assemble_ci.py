"""Join CI-rendered shots, master audio, and verify the upload-ready MP4."""
from pathlib import Path
import json
import shutil
import subprocess
import textwrap

def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True).stdout

build = Path('build')
out = build / 'delivery'
out.mkdir(exist_ok=True)
timeline = json.loads((build / 'timeline.json').read_text())
shots = timeline['shots']
fps = timeline['fps']
(build / 'concat.txt').write_text(''.join(f"file 'shots/{key}.mp4'\n" for key in shots))
run('ffmpeg', '-y', '-f', 'concat', '-safe', '0', '-i', str(build / 'concat.txt'),
    '-c:v', 'copy', '-af', 'loudnorm=I=-14:TP=-1:LRA=9', '-c:a', 'aac', '-b:a', '192k',
    '-ar', '48000', '-movflags', '+faststart', str(out / 'tiktok-american.mp4'))
probe = json.loads(run('ffprobe', '-v', 'error', '-show_streams', '-show_format', '-of', 'json', str(out / 'tiktok-american.mp4')))
video = next(s for s in probe['streams'] if s['codec_type'] == 'video')
audio = next(s for s in probe['streams'] if s['codec_type'] == 'audio')
assert (video['width'], video['height']) == (1080, 1920), video
assert video['codec_name'] == 'h264' and video['pix_fmt'] == 'yuv420p', video
assert audio['codec_name'] == 'aac', audio
assert abs(float(probe['format']['duration']) - timeline['frames'] / fps) < 0.5, probe
run('ffmpeg', '-v', 'error', '-i', str(out / 'tiktok-american.mp4'), '-f', 'null', '-')
(out / 'metadata.json').write_text(json.dumps(probe, indent=2))

def stamp(seconds):
    ms = round(seconds * 1000)
    h, ms = divmod(ms, 3600000)
    m, ms = divmod(ms, 60000)
    s, ms = divmod(ms, 1000)
    return f'{h:02}:{m:02}:{s:02},{ms:03}'

lines = dict(line.split('|', 1) for line in Path('tools/video/voice_lines.txt').read_text().splitlines())
subs = []
for i, (key, (_, end, start)) in enumerate(shots.items(), 1):
    subs.append(f'{i}\n{stamp((start-1)/fps)} --> {stamp((end-1)/fps)}\n' + '\n'.join(textwrap.wrap(lines[key], 38)))
(out / 'subtitles.srt').write_text('\n\n'.join(subs) + '\n')
shutil.copy(build / 'shots/outro.png', out / 'preview.png')
for key in shots:
    shutil.copy(build / f'shots/{key}.png', out / f'frame-{key}.png')
(out / 'licenses.txt').write_text('Monsters: Quaternius Ultimate Monsters, CC0.\nMusic and effects: synthesized by tools/video/ad_voiced.py.\nFont: Luckiest Guy, see repository assets/fonts/LICENSE-LuckiestGuy.txt.\nPiper Joe American English voice model:\n' + (build / 'tts/MODEL_CARD').read_text())
(out / 'README.md').write_text('# Steal a Monster — TikTok ad\n\n'
    'Download **tiktok-american.mp4** (View raw / Download raw file). '
    '1080×1920, 30 fps, H.264 + AAC, American English male narration, music, effects and animated English captions.\n\n'
    'Rendered entirely on GitHub Actions with Blender 4.3.2. These are staged promotional scenes using the game monster assets, not recorded gameplay. '
    'English transcript: subtitles.srt. Review images: frame-*.png.\n\n'
    'Suggested caption: Someone stole my TITAN. You stealing it back? 👀 #Roblox #StealAMonster #RobloxGames\n')
print(json.dumps({'duration': probe['format']['duration'], 'resolution': '1080x1920', 'audio': audio['codec_name']}))
