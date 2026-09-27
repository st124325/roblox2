#!/usr/bin/env python3
"""Send videos to your TikTok drafts (inbox) through the official Content Posting API.
TikTok then shows a notification: open it, add a trending sound and caption, and post.

Setup (once):
  1. developers.tiktok.com -> Manage apps -> Create app; add products "Login Kit" and
     "Content Posting API"; scope video.upload; add a Redirect URI (any https page you own,
     e.g. https://<you>.github.io/ — it only needs to exist in the settings).
  2. ~/.config/stealakaiju/tiktok.env:
       TIKTOK_CLIENT_KEY=...
       TIKTOK_CLIENT_SECRET=...
       TIKTOK_REDIRECT_URI=https://...
  3. tools/tiktok/tiktok.py auth       -> open the printed link, allow, copy the ?code=... from the
                                          address bar of the page you land on
     tools/tiktok/tiktok.py token CODE -> saves tokens (refreshed automatically, valid ~1 year)
Use:
  tools/tiktok/tiktok.py upload video.mp4
  tools/tiktok/tiktok.py status PUBLISH_ID
Limits: 5 pending drafts per 24 h, 6 requests/min."""
import json, os, secrets, subprocess, sys, time, urllib.parse

CONF = os.path.expanduser("~/.config/stealakaiju")
ENV = os.path.join(CONF, "tiktok.env")
TOKENS = os.path.join(CONF, "tiktok_token.json")
API = "https://open.tiktokapis.com"


def env():
    if not os.path.exists(ENV):
        sys.exit(f"Create {ENV} first (see the header of this script).")
    out = {}
    for line in open(ENV, encoding="utf-8"):
        if "=" in line and not line.lstrip().startswith("#"):
            k, v = line.split("=", 1)
            out[k.strip()] = v.strip()
    return out


def curl(args):
    r = subprocess.run(["curl", "-s", "--noproxy", "*"] + args, capture_output=True, text=True)
    try:
        return json.loads(r.stdout)
    except json.JSONDecodeError:
        return {"raw": r.stdout[:500]}


def save_tokens(data):
    data["obtained_at"] = int(time.time())
    os.makedirs(CONF, exist_ok=True)
    with open(TOKENS, "w", encoding="utf-8") as f:
        json.dump(data, f)
    os.chmod(TOKENS, 0o600)


def token_request(fields):
    e = env()
    form = {"client_key": e["TIKTOK_CLIENT_KEY"], "client_secret": e["TIKTOK_CLIENT_SECRET"], **fields}
    args = ["-X", "POST", f"{API}/v2/oauth/token/", "-H", "Content-Type: application/x-www-form-urlencoded"]
    for k, v in form.items():
        args += ["--data-urlencode", f"{k}={v}"]
    data = curl(args)
    if "access_token" not in data:
        sys.exit(f"Token request failed: {data}")
    save_tokens(data)
    return data


def access_token():
    if not os.path.exists(TOKENS):
        sys.exit("No tokens yet: run `auth`, then `token CODE`.")
    data = json.load(open(TOKENS, encoding="utf-8"))
    if time.time() > data["obtained_at"] + data.get("expires_in", 0) - 300:
        data = token_request({"grant_type": "refresh_token", "refresh_token": data["refresh_token"]})
    return data["access_token"]


def cmd_auth():
    e = env()
    query = urllib.parse.urlencode({
        "client_key": e["TIKTOK_CLIENT_KEY"], "scope": "user.info.basic,video.upload",
        "response_type": "code", "redirect_uri": e["TIKTOK_REDIRECT_URI"], "state": secrets.token_urlsafe(12),
    })
    print("Open this link, allow access, then copy the `code` value from the address bar:\n")
    print("https://www.tiktok.com/v2/auth/authorize/?" + query)


def cmd_token(code):
    code = urllib.parse.unquote(code.split("code=")[-1].split("&")[0])  # accept the whole URL too
    token_request({"code": code, "grant_type": "authorization_code", "redirect_uri": env()["TIKTOK_REDIRECT_URI"]})
    print(f"Saved tokens to {TOKENS}")


def cmd_upload(path):
    size = os.path.getsize(path)
    if size > 64 * 1024 * 1024:
        sys.exit("Videos over 64 MB need chunked upload; keep ads short.")
    token = access_token()
    init = curl(["-X", "POST", f"{API}/v2/post/publish/inbox/video/init/",
                 "-H", f"Authorization: Bearer {token}", "-H", "Content-Type: application/json; charset=UTF-8",
                 "-d", json.dumps({"source_info": {"source": "FILE_UPLOAD", "video_size": size,
                                                   "chunk_size": size, "total_chunk_count": 1}})])
    data = init.get("data") or {}
    if not data.get("upload_url"):
        sys.exit(f"Init failed: {init}")
    r = subprocess.run(["curl", "-s", "--noproxy", "*", "-o", "/dev/null", "-w", "%{http_code}", "-X", "PUT",
                        "-H", "Content-Type: video/mp4", "-H", f"Content-Range: bytes 0-{size - 1}/{size}",
                        "--data-binary", f"@{path}", data["upload_url"]], capture_output=True, text=True)
    if r.stdout not in ("200", "201"):
        sys.exit(f"Upload failed: HTTP {r.stdout}")
    print(f"Uploaded. publish_id={data['publish_id']}")
    print("Open TikTok -> inbox notification -> add a sound and caption -> Post.")


def cmd_status(publish_id):
    print(json.dumps(curl(["-X", "POST", f"{API}/v2/post/publish/status/fetch/",
                           "-H", f"Authorization: Bearer {access_token()}",
                           "-H", "Content-Type: application/json; charset=UTF-8",
                           "-d", json.dumps({"publish_id": publish_id})]), indent=2))


if __name__ == "__main__":
    commands = {"auth": cmd_auth, "token": cmd_token, "upload": cmd_upload, "status": cmd_status}
    if len(sys.argv) < 2 or sys.argv[1] not in commands:
        sys.exit(__doc__)
    commands[sys.argv[1]](*sys.argv[2:])
