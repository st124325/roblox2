# The worst heist

A new 22-second narrative trailer: cold-open chase, flashback, theft, angry owner,
escape, false victory and a friend stealing the loot. Three purpose-built block
characters move through two neon bases; the loot is the game's Quaternius dragon.
This is staged animation, not recorded gameplay.

All media generation runs in `.github/workflows/tiktok-heist.yml`. Push changes
with `config.json: render_full=false` for an eight-frame composited storyboard.
After reviewing the storyboard, set it to `true` to render 20 animation chunks
and automatically place the new film in the root of `main`.

`prepare.py`: American English dialogue (Piper Joe), synthesized heist soundtrack
and effects. `scene.py`: environment and characters. `story.py`: deterministic
blocking and camera moves. `finish.py`: ASS dialogue, edit, loudness mastering,
frame count and codec checks. Nothing is rendered locally.

Delivery: `tiktok-heist.mp4`, cover, storyboard and SRT. The earlier ad remains
available as `tiktok-american.mp4`.
