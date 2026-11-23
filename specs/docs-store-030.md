# Task: README and store page for v0.3.0, with GIFs of what's new

v0.3.0 shipped the polish and explorer releases together (see the v0.3.0 section of `CHANGELOG.md` and `docs/RELEASE_NOTES.md` on `origin/staging`). The README and store page (`docs/store/description.md`, spliced into README.md, `docs/store/curseforge.md` and `docs/store/wago.md` by `python3 Tools/media/marketing.py --pages`) must show it. The owner's rule: store pages and README are always current, short, GIF-led, in his own voice, nothing AI-looking.

**Keep** the current structure, length and voice (it was redone in #706-ish, "a short, GIF-led README"). Do not grow it into a feature list. Swap or add at most four highlight GIFs, each with one plain line under it:
1. Clean screen at rest: panels easing out of combat, snapping back on a target.
2. Cast bars: who it's aimed at (YOU), the shield on an uninterruptible cast, the interrupt dim and ready mark.
3. World map travel: a route using a zeppelin or the tram plus a Nearest picker.
4. One still or short GIF of the lit glass bars and forged slab ends on the Medallions HUD.
Update any line that is now out of date (for example first run Looks, the About > Status page if the page mentions troubleshooting).

**Voice**: `C:/Users/leeba/.cache/kstyleui-evidence/voice/lee-discord-voice.txt`. Short, plain, first person, no em dashes, no AI tells, never name another UI pack.

**GIFs**: render from current `origin/staging` with the harness, over REAL game backdrops only (`~/.cache/kstyleui-backdrops`), `--strict`, cropped tight for phones, 12-20 fps, under 1.5 MB each, framing and branding matching the existing marketing GIFs in `docs/media/marketing/`. Look at every frame strip by eye. Delete images no longer used. Update `Tools/tests/test_marketing.py` and media budget tests if needed. At most 2 renders at a time.

Gate: lint and python. PR `docs: README and store page for v0.3.0`, label `no changelog`, with the GIF list and sizes in the body. Do not merge.

**Files it may edit**: `README.md`, `docs/store/**`, `docs/media/**`, `Tools/media/**`, `Tools/render/readme.py`, `Tools/render/scenes/**` (scene-only showcase switches), `Tools/tests/test_marketing.py` and media budget tests.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report PR, SHA, run id and the GIF list with sizes and paths.
