#!/usr/bin/env python3
"""Upload build/icons/<Section>.<Key>.png as the thumbnail of each pass / developer product
(ids read from src/shared/Products.luau). Render the icons first with tools/products/icons.py."""
import os, re, subprocess, sys, time

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ENV = os.environ.get("STEALAKAIJU_PUBLISH_ENV", os.path.expanduser("~/.config/stealakaiju/publish.env"))
env = dict(l.strip().split("=", 1) for l in open(ENV, encoding="utf-8") if "=" in l and not l.startswith("#"))
KEY, UNIVERSE = env["ROBLOX_API_KEY"].strip(), env["UNIVERSE_ID"].strip()
src = open(os.path.join(ROOT, "src/shared/Products.luau"), encoding="utf-8").read()

def ids(section):
    start = src.index(f"Products.{section} = {{")
    end = src.index("\n}", start)
    return re.findall(r"\n\t(\w+) = \{\s*Id = (\d+)", src[start:end])

ok = 0
for section in ("Passes", "Items", "AdRewards", "Gifts"):
    for key, pid in ids(section):
        png = os.path.join(ROOT, "build/icons", f"{section}.{key}.png")
        if pid == "0" or not os.path.exists(png):
            print(f"- skip {section}.{key}")
            continue
        path = (f"/game-passes/v1/universes/{UNIVERSE}/game-passes/{pid}" if section == "Passes"
                else f"/developer-products/v2/universes/{UNIVERSE}/developer-products/{pid}")
        for attempt in range(5):
            r = subprocess.run(["curl", "-s", "--noproxy", "*", "-o", "/dev/stderr", "-w", "%{http_code}", "-X", "PATCH",
                                "-H", f"x-api-key: {KEY}", "-F", f"imageFile=@{png};type=image/png",
                                "https://apis.roblox.com" + path], capture_output=True, text=True)
            if r.stdout != "429":
                break
            time.sleep(5 * (attempt + 1))
        good = r.stdout in ("200", "204")
        ok += good
        print(f"{'✓' if good else '✗'} {section}.{key:16} HTTP {r.stdout} {'' if good else r.stderr[:200]}")
print(f"{ok} icons uploaded")
