# Task: redo the README and store descriptions — short, GIF-led, in the owner's voice

The owner (2026-11-22): "redo the entire README and marketing descriptions, they're too big and over-populated. Make things easier by using GIFs that show everything, like highlight reels. We definitely want the cool aura stuff: the class crowns ('forms'), the Lightning Shield storm orbs, the rogue blades etc. Make sure nothing looks AI-generated, and it's written in my tone and voice" (from the KstyleUI Discord).

**Voice**: read `C:/Users/leeba/.cache/kstyleui-evidence/voice/lee-discord-voice.txt` (his own Discord messages). Write like him: short, plain, casual, first person ("i built", "we"), a bit of humour, no marketing fluff. Avoid AI tells: no em dashes, no "Elevate/Seamless/Unleash/Whether you're", no triplet lists of adjectives, no rhetorical questions, no emoji walls, no bold on every line. Proper sentence case is fine (it's a store page), but keep his directness. Never name EllesmereUI, CaithUI or any other UI pack.

**Structure** (one master `docs/store/description.md`, spliced by `python3 Tools/media/marketing.py --pages` into README.md, `docs/store/curseforge.md`, `docs/store/wago.md`):
- Banner, then the Discord invite right under it (keep; `Tools/tests/test_marketing.py` enforces it).
- One short paragraph: what KstyleUI is (Medallions, one forged look, Forever only).
- A highlight reel of GIFs, each with one line under it: the Medallions HUD overview; class crowns (rogue crown of blades, cat druid claws, and a strip of the other classes); shaman Spirit Poles (totem bar on the crest) and Lightning Shield storm orbs; hunter hawk perches; crest jewels; plus 2-3 everyday features (unit/raid frames, story rail with quests and the guide top-left, bags/tooltips/world map) as short GIFs or stills.
- A short "how to install" and links. Cut everything else (long feature lists, FAQ walls, per-module essays); link the GitHub docs for detail.
- README may keep a short "for developers" section at the end pointing at docs/DEVELOPING.md.

**GIFs**: render fresh from current `origin/staging` with the harness (`Tools/render/`, the scenes used for the crowns, storm orbs, totems, hawks and jewels; see `docs/feature-map.md`), over the REAL game backdrops only (`~/.cache/kstyleui-backdrops`, never the mockup plate), `--strict`, cropped tight so they read on a phone, smooth (12-20 fps), small (aim under 1.5 MB each; CurseForge rejects big images), consistent framing and branding with the existing marketing images. Captions must say they are test renders over in-game screenshots where the store rules need it. Put them in `docs/media/marketing/` (store pages load them by raw `main` URL, so they go live at the next release). Update `Tools/tests/test_marketing.py` and any media budget test if GIFs need it (keep the total sensible). Delete marketing images no longer used.

Look at every GIF by eye before reporting. Gate: python suite and lint. PR `docs: a short, GIF-led README and store page`, label `no changelog`; paste before/after length (words, images) in the body. Do not merge.

**Files it may edit**: `README.md`, `docs/store/**`, `docs/media/**`, `Tools/media/**`, `Tools/render/readme.py`, `Tools/render/scenes/**` (scene-only switches for showcases), `Tools/tests/test_marketing.py` and media budget tests.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report PR, SHA, run id and the GIF list with sizes.
