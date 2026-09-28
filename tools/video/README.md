# TikTok render on GitHub Actions

Push video changes to `promo/tiktok-american`; `.github/workflows/tiktok-ad.yml`
generates Joe (en_US) speech with Piper, converts the existing monster meshes,
prepares a Blender 4.3.2 scene, renders seven shots on separate runners, then
assembles and checks a 1080×1920 H.264/AAC MP4. All media generation runs in CI.

The final artifact is `tiktok-american-1080x1920` (90 days); download files also
live on the dedicated `promo/tiktok-output` branch. That generated branch is
replaced on each successful run. The delivery workflow then copies the MP4,
preview, subtitles and credits into the root of `main`, as requested.
Run the render workflow manually from `main` to rebuild. Game publishing is unaffected.

Voice script: `voice_lines.txt`. Scene: `ad_voiced.py`. American English male
voice: Piper Joe medium, upstream model card included in delivery. Music and
effects are synthesized. Monster and font licenses remain in `assets/`.

The trailer is staged animation based on the game assets, not a gameplay capture.
English animated headlines are in the video; a full SRT transcript accompanies it.
