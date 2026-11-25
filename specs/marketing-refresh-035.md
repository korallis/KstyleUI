# Task: store pictures and copy for v0.3.5 (the crest comes alive)

v0.3.5 replaced every icon on the crest with effects built into the crest (break-out for all nine classes) and added ten WeakAuras-inspired crest effects and cooldown sigils. The store pages and README (refreshed at v0.3.4.4, PR #797) now show the old crest with icon medals. Bring them up to date, same pipeline and rules as #797 (`specs/marketing-refresh-034.md`): `docs/store/description.md` master, `Tools/media/marketing.py`, `Tools/render/readme.py`, gallery tables in `docs/store/curseforge.md` and `docs/store/wago.md`, `Tools/tests/test_marketing.py`.

1. Retake every marketing picture, gallery image and README picture that shows the crest (classes.gif, crowns.gif, crowns-more.gif, shaman.gif, hawks.gif, trackers.gif, show_frames_medals, hud shots) on staging so they show the new crest. Real game backdrops only (`~/.cache/kstyleui-backdrops`), never AI scenery; native pixels; the target portrait stand-in instead of an empty disc.
2. The real-code GIFs in `C:/Users/leeba/.cache/kstyleui-evidence/crest-real-gifs/` (15 classes/forms at 1080 and 5120x1440, made with the clip driver on local branch `gif/staging`, patch in `harness/gif-staging.patch`) are the best source for the crest story: reuse that clip driver to make the marketing GIFs (crest crop, a few classes per GIF, under 2.5 MB each so CurseForge accepts them), and add one new gallery picture for the WeakAuras-style effects (Unleashed, glyph tide, cast ring, kill window, target lock).
3. Update the copy: the crest section says the crest tracks everything as part of itself (no icons), names a few signature effects per class family, and mentions every piece has its own switch. Owner's voice (`C:/Users/leeba/.cache/kstyleui-evidence/voice/lee-discord-voice.txt`), short, no AI tells, no em dashes. Discord invite stays under the banner. Keep the banner and hero 01 (the owner's in-game capture).
4. Check every picture at native size and 2x (no truncation, nothing over the bars), before/after sheets in `C:/Users/leeba/.cache/kstyleui-evidence/marketing-refresh-035/`.

**Files it may edit**: `docs/store/**`, `docs/media/**`, `README.md`, `Tools/render/**`, `Tools/media/**`, `Tools/tests/test_marketing.py`.

**PR**: `docs(store): pictures and copy for the living crest` with label `no changelog`. Do not merge; do not touch CurseForge, Wago or Discord.

**Constraints**: minimal; Tools/docs are LF; at most 2 renders at once on this machine.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report PR, SHA, run id, the new and retaken images and the gallery order.
