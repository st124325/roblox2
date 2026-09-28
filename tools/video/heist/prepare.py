"""Generate all heist audio and the Blender scene on the Actions runner."""
from pathlib import Path
import json
import math
import subprocess
import urllib.request
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[3]
BUILD = ROOT / 'build/heist'
CFG = json.loads((Path(__file__).parent / 'config.json').read_text())
RATE = 48000

def run(*args, **kwargs):
    subprocess.run(args, check=True, **kwargs)

def read(path):
    with wave.open(str(path)) as w:
        return np.frombuffer(w.readframes(w.getnframes()), dtype='<i2').astype(np.float64)/32768, w.getframerate()

def write(path, data):
    with wave.open(str(path), 'wb') as w:
        w.setnchannels(2 if data.ndim == 2 else 1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((np.clip(data, -1, 1)*32767).astype('<i2').tobytes())

for folder in ['voice', 'tts', 'models', 'preview', 'raw', 'parts', 'delivery']:
    (BUILD / folder).mkdir(parents=True, exist_ok=True)
base = 'https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/joe/medium/'
for name in ['en_US-joe-medium.onnx', 'en_US-joe-medium.onnx.json', 'MODEL_CARD']:
    urllib.request.urlretrieve(base + name, BUILD / 'tts' / name)

count = CFG['seconds'] * RATE
voice = np.zeros((count, 2))
duck = np.ones(count)
for line in CFG['voice']:
    raw = BUILD / 'voice' / (line['key'] + '-raw.wav')
    dst = BUILD / 'voice' / (line['key'] + '.wav')
    run('/tmp/piper/piper', '--model', str(BUILD/'tts/en_US-joe-medium.onnx'),
        '--length_scale', '1.0', '--output_file', str(raw), input=line['text']+'\n', text=True)
    data, rate = read(raw)
    speed = max(1, len(data)/rate/(line['end']-line['start']-0.08))
    filt = f"asetrate={round(rate*line['pitch'])},aresample={RATE},atempo={speed/line['pitch']}"
    run('ffmpeg', '-loglevel', 'error', '-y', '-i', str(raw), '-af', filt, '-ac', '1', str(dst))
    data, rate = read(dst)
    assert rate == RATE
    assert len(data)/RATE <= line['end']-line['start']+0.02
    data *= 0.66/max(0.01, np.max(np.abs(data)))
    start = round(line['start']*RATE)
    voice[start:start+len(data)] += data[:, None]
    duck[max(0,start-2400):min(count,start+len(data)+5000)] = 0.35

music = np.zeros((count, 2))
sfx = np.zeros((count, 2))
rng = np.random.default_rng(17)

def add(track, sig, at, gain=1, pan=0):
    i = round(at*RATE)
    n = min(len(sig), count-i)
    if n > 0 and i >= 0:
        track[i:i+n, 0] += sig[:n]*gain*(1-pan)
        track[i:i+n, 1] += sig[:n]*gain*(1+pan)

def tone(freq, seconds, decay=5):
    t = np.arange(round(seconds*RATE))/RATE
    return np.sin(2*np.pi*freq*t)*np.exp(-t*decay)

beat = 60/144
for b in range(math.ceil(CFG['seconds']/beat)):
    at = b*beat
    if 16.2 < at < 18.5:
        continue
    roots = [36, 36, 31, 34]
    freq = 440*2**((roots[(b//8)%4]-69)/12)
    gain = 0.08 if at < 9.8 else 0.15
    add(music, tone(freq, 0.3, 10) + 0.25*tone(freq*2,0.3,14), at, gain)
    t = np.arange(round(0.22*RATE))/RATE
    kick = np.sin(2*np.pi*np.cumsum(48+100*np.exp(-t*30))/RATE)*np.exp(-t*20)
    if at < 2.2 or at > 9.8:
        add(music, kick, at, 0.19)
        if b%2:
            add(music, rng.uniform(-1,1,4800)*np.exp(-np.arange(4800)/900), at, 0.08)
    if b%2 == 0:
        add(music, tone(freq*8,0.35,9), at+beat/2, 0.035, (-1 if b%4 else 1)*0.3)

for start, end in [(0,2.2),(8,15.4),(17.2,21.8)]:
    for at in np.arange(start,end,0.24):
        add(sfx, rng.uniform(-1,1,1800)*np.exp(-np.arange(1800)/300), at, 0.10)
for at in [7.75,8.2,8.65,9.1]:
    add(sfx, tone(720,0.15,6), at,0.18)
for at in [2.18,4.48,9.78,13.78,18.58]:
    t = np.arange(12000)/RATE
    noise = rng.uniform(-1,1,len(t))
    smooth = np.convolve(noise,np.ones(18)/18,'same')
    add(sfx,smooth*np.sin(np.linspace(0,np.pi,len(t))),at,0.36)
add(sfx,tone(1450,0.25,14)+tone(2175,0.25,16),7.0,0.12)
add(sfx,tone(330,0.24,18),16.76,0.16)
add(sfx,tone(62,0.8,5),18.6,0.28)
master = voice + music*duck[:,None] + sfx
master *= min(1,0.90/max(0.01,np.max(np.abs(master))))
write(BUILD/'master.wav',master)
run('blender','-b','--python','tools/models/convert.py','--',
    str(ROOT/'assets/monsters/Flying_Dragon_Evolved.fbx'),
    str(ROOT/'assets/monsters/Atlas_Monsters.png'),
    str(BUILD/'models/Flying_Dragon_Evolved.fbx'))
run('blender','-b','--python','tools/video/heist/scene.py')
run('/usr/bin/python3','tools/video/heist/finish.py','captions')

