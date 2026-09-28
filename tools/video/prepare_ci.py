"""Build American speech and convert only meshes used in the ad (CI only)."""
from pathlib import Path
import re
import subprocess
import urllib.request

def run(*args, **kwargs):
    subprocess.run(args, check=True, **kwargs)

root = Path(__file__).resolve().parents[2]
build = root / "build"
for folder in ("models", "voice", "tts", "delivery"):
    (build / folder).mkdir(parents=True, exist_ok=True)
base = "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/joe/medium/"
for name in ("en_US-joe-medium.onnx", "en_US-joe-medium.onnx.json", "MODEL_CARD"):
    urllib.request.urlretrieve(base + name, build / "tts" / name)
for line in (root / "tools/video/voice_lines.txt").read_text().splitlines():
    key, text = line.split("|", 1)
    run("/tmp/piper/piper", "--model", str(build / "tts/en_US-joe-medium.onnx"),
        "--length_scale", "0.92", "--output_file", str(build / "voice" / f"{key}.wav"),
        input=text + "\n", text=True)
source = (root / "tools/video/ad_voiced.py").read_text()
models = sorted(set(re.findall(r'"((?:Big|Blob|Flying)_[A-Za-z_]+)"', source)))
for model in models:
    run("blender", "-b", "--python", "tools/models/convert.py", "--",
        str(root / "assets/monsters" / f"{model}.fbx"),
        str(root / "assets/monsters/Atlas_Monsters.png"),
        str(build / "models" / f"{model}.fbx"))
run("blender", "-b", "--python", "tools/video/ad_voiced.py", "--",
    str(build / "ad.blend"), "--prepare")
