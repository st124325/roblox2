#!/usr/bin/env python3
"""Create every game pass and developer product from src/shared/Products.luau in the experience
via Open Cloud, then write the ids back into Products.luau.

Idempotent: items that already have an id are skipped, and an existing product/pass with the
same name is reused instead of creating a duplicate.
Needs an API key with game-pass:read/write and developer-product:read/write
(~/.config/stealakaiju/publish.env: ROBLOX_API_KEY, UNIVERSE_ID).
Usage: tools/products/create.py [--dry-run]"""
import json, os, re, subprocess, sys, time

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ENV = os.environ.get("STEALAKAIJU_PUBLISH_ENV", os.path.expanduser("~/.config/stealakaiju/publish.env"))
PRODUCTS = os.path.join(ROOT, "src/shared/Products.luau")
DRY = "--dry-run" in sys.argv
AD_REWARD_PRICE = 5  # Roblox recommends ad rewards worth 3-10 Robux

env = {}
for line in open(ENV, encoding="utf-8"):
    line = line.strip()
    if line and not line.startswith("#") and "=" in line:
        k, v = line.split("=", 1)
        env[k.strip()] = v.split("#")[0].strip()
KEY, UNIVERSE = env["ROBLOX_API_KEY"], env["UNIVERSE_ID"]
API = "https://apis.roblox.com"


def curl(method, path, fields=None):
    args = ["curl", "-s", "--noproxy", "*", "-X", method, "-H", f"x-api-key: {KEY}", "-w", "\n%{http_code}"]
    for k, v in (fields or {}).items():
        args += ["-F", f"{k}={v}"]
    for attempt in range(5):
        out = subprocess.run(args + [API + path], capture_output=True, text=True).stdout
        body, _, code = out.rpartition("\n")
        if code != "429":
            break
        time.sleep(5 * (attempt + 1))
    try:
        data = json.loads(body) if body else {}
    except json.JSONDecodeError:
        data = {"raw": body[:300]}
    return int(code or 0), data


def list_all(path, key):
    items, token = [], ""
    while True:
        code, data = curl("GET", f"{path}?pageSize=50" + (f"&pageToken={token}" if token else ""))
        if code != 200:
            sys.exit(f"list {path} failed: HTTP {code} {data}")
        items += data.get(key) or []
        token = data.get("nextPageToken")
        if not token:
            return items


# --- parse Products.luau --------------------------------------------------------------------------
src = open(PRODUCTS, encoding="utf-8").read()


def section(name):
    start = src.index(f"Products.{name} = {{")
    depth, i = 0, src.index("{", start)
    for j in range(i, len(src)):
        depth += {"{": 1, "}": -1}.get(src[j], 0)
        if depth == 0:
            return start, j
    raise ValueError(name)


def entries(name):
    a, b = section(name)
    body = src[a:b]
    out = []
    # entries may span several lines: Key = { Id = 0, Name = "...", ... },
    for m in re.finditer(r"\n\t(\w+) = \{(.*?)\n?\t?\},", body, re.S):
        key, fields = m.group(1), m.group(2)
        get = lambda f: (re.search(rf'\b{f} = "([^"]*)"', fields) or re.search(rf"\b{f} = ([\d_]+)", fields))
        out.append({
            "Key": key,
            "Id": int(get("Id").group(1).replace("_", "")),
            "Name": get("Name").group(1) if get("Name") else None,
            "Desc": get("Desc").group(1) if get("Desc") else "",
            "Price": int(get("Price").group(1).replace("_", "")) if get("Price") else None,
        })
    return out


passes, items, ads, gifts = entries("Passes"), entries("Items"), entries("AdRewards"), entries("Gifts")
pass_by_key = {p["Key"]: p for p in passes}
for g in gifts:
    p = pass_by_key[g["Key"]]
    g.update(Name=f"Gift: {p['Name']}", Desc=f"Gift {p['Name']} to another player", Price=p["Price"])
for a in ads:
    a.update(Price=AD_REWARD_PRICE, Desc=f"Rewarded video ad reward: {a['Desc']}")

# --- create -------------------------------------------------------------------------------------
existing_passes = {p["name"]: p["gamePassId"] for p in list_all(f"/game-passes/v1/universes/{UNIVERSE}/game-passes/creator", "gamePasses")}
existing_products = {p["name"]: p["productId"] for p in list_all(f"/developer-products/v2/universes/{UNIVERSE}/developer-products/creator", "developerProducts")}
print(f"existing: {len(existing_passes)} passes, {len(existing_products)} products")

new_ids = {}  # (section, key) -> id
for sec, group, is_pass in (("Passes", passes, True), ("Items", items, False), ("AdRewards", ads, False), ("Gifts", gifts, False)):
    for e in group:
        if e["Id"]:
            continue
        existing = (existing_passes if is_pass else existing_products).get(e["Name"])
        if existing:
            new_ids[(sec, e["Key"])] = existing
            print(f"= {sec}.{e['Key']:16} reuse {existing}")
            continue
        fields = {"name": e["Name"], "description": e["Desc"][:1000], "price": e["Price"], "isForSale": "true"}
        if DRY:
            print(f"+ {sec}.{e['Key']:16} would create {fields}")
            continue
        path = f"/game-passes/v1/universes/{UNIVERSE}/game-passes" if is_pass else f"/developer-products/v2/universes/{UNIVERSE}/developer-products"
        code, data = curl("POST", path, fields)
        new_id = data.get("gamePassId") if is_pass else data.get("productId")
        if code in (200, 201) and new_id:
            new_ids[(sec, e["Key"])] = new_id
            print(f"+ {sec}.{e['Key']:16} {e['Name']:24} R${e['Price']:<5} -> {new_id}")
        else:
            print(f"✗ {sec}.{e['Key']}: HTTP {code} {data}")

# --- write ids back -----------------------------------------------------------------------------
for (sec, key), new_id in new_ids.items():
    a, b = section(sec)
    body = src[a:b]
    body2, n = re.subn(rf"(\n\t{key} = \{{\s*Id = )0\b", rf"\g<1>{new_id}", body, count=1)
    if n != 1:
        print(f"! could not write id for {sec}.{key}")
        continue
    src = src[:a] + body2 + src[b:]
if new_ids and not DRY:
    open(PRODUCTS, "w", encoding="utf-8").write(src)
print(f"done: {len(new_ids)} ids written to src/shared/Products.luau")
