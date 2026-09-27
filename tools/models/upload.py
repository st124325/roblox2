#!/usr/bin/env python3
"""Upload converted monster FBX files (build/models) to Roblox as Model assets via Open Cloud
and write their asset ids to src/shared/KaijuAssets.luau.
Settings come from ~/.config/stealakaiju/publish.env (ROBLOX_API_KEY, CREATOR_USER_ID).
Usage: tools/models/upload.py            upload models missing from KaijuAssets.luau
       tools/models/upload.py --force    re-upload everything"""
import json, os, re, subprocess, sys, time

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ENV = os.environ.get("STEALAKAIJU_PUBLISH_ENV", os.path.expanduser("~/.config/stealakaiju/publish.env"))
OUT = os.path.join(ROOT, "src/shared/KaijuAssets.luau")

# kaiju id -> Quaternius model (assets/monsters/README.md)
MAPPING = {
    "toastosaurus": "Blob_Mushnub", "mudpup": "Blob_Dog", "craboid": "Blob_GreenSpikyBlob",
    "chirik": "Blob_Chicken", "nosatik": "Blob_Fish", "cactusaur": "Blob_Cactoro",
    "bubblegum_goblin": "Blob_PinkBlob", "crabburger": "Blob_Orc", "pigeon_bomber": "Flying_Pigeon",
    "giraffecrane": "Flying_Alpaking", "pelmenisaur": "Blob_Mushnub_Evolved", "slime_shlepa": "Blob_GreenBlob",
    "boxer_crab": "Flying_Armabee", "interceptor_seagull": "Blob_Birb", "bananosaur": "Flying_Glub",
    "catzilla": "Blob_Cat", "avocado_monster": "Big_Frog", "king_crab": "Big_MushroomKing",
    "grill_phoenix": "Flying_Dragon", "mecha_godzilych": "Big_Dino", "black_hole_blob": "Flying_Ghost",
    "crab_armageddon": "Flying_Demon", "shawarmasaur": "Big_Cactoro", "cosmo_capybara": "Big_Alien",
    "giga_shlepa": "Big_Yeti", "baton_dragon": "Flying_Dragon_Evolved", "cyber_titan_rex": "Big_BlueDemon",
}

env = {}
for line in open(ENV, encoding="utf-8"):
    line = line.strip()
    if line and not line.startswith("#") and "=" in line:
        k, v = line.split("=", 1)
        env[k.strip()] = v.split("#")[0].strip()
KEY, USER = env["ROBLOX_API_KEY"], env["CREATOR_USER_ID"]

def curl(*args):
    r = subprocess.run(["curl", "-s", "--noproxy", "*", "-H", f"x-api-key: {KEY}", *args], capture_output=True, text=True)
    try:
        return json.loads(r.stdout)
    except json.JSONDecodeError:
        return {"error": r.stdout[:300]}

def existing():
    if not os.path.exists(OUT) or "--force" in sys.argv:
        return {}
    return dict(re.findall(r'(\w+) = (\d+),', open(OUT, encoding="utf-8").read()))

def write(ids):
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("-- Roblox Model asset ids of the kaiju meshes (written by tools/models/upload.py — don't edit by hand).\n")
        f.write("-- Each model is one textured MeshPart, feet at its bottom, from Quaternius Ultimate Monsters (CC0).\n")
        f.write("return table.freeze({\n")
        for kaiju in MAPPING:
            if kaiju in ids:
                f.write(f"\t{kaiju} = {ids[kaiju]},\n")
        f.write("})\n")

ids = existing()
for kaiju, model in MAPPING.items():
    if kaiju in ids:
        continue
    path = os.path.join(ROOT, "build/models", model + ".fbx")
    request = {"assetType": "Model", "displayName": f"Monster {model}",
               "description": "Steal a Monster — Quaternius Ultimate Monsters (CC0)",
               "creationContext": {"creator": {"userId": USER}}}
    for attempt in range(5):
        op = curl("-X", "POST", "https://apis.roblox.com/assets/v1/assets",
                  "-F", "request=" + json.dumps(request), "-F", f"fileContent=@{path};type=model/fbx")
        if "path" in op:
            break
        time.sleep(10 * (attempt + 1))  # rate limited or busy
    if "path" not in op:
        print(f"✗ {kaiju} ({model}): {op}")
        continue
    op_path = op["path"]
    for _ in range(90):
        if op.get("done"):
            break
        time.sleep(3)
        polled = curl(f"https://apis.roblox.com/assets/v1/{op_path}")
        if "done" in polled or "path" in polled:
            op = polled  # otherwise a rate-limit / transient error: keep polling
    asset = (op.get("response") or {}).get("assetId")
    if asset:
        ids[kaiju] = asset
        print(f"✓ {kaiju:20} {model:24} {asset}")
        write(ids)
    else:
        print(f"✗ {kaiju} ({model}): {op}")

write(ids)
print(f"{len(ids)}/{len(MAPPING)} uploaded -> {os.path.relpath(OUT, ROOT)}")
