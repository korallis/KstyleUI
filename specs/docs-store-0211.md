# Task: store description and roadmap current for v0.2.11

v0.2.11 is released (tag `v0.2.11`; notes in `CHANGELOG.md` and `docs/RELEASE_NOTES.md`). Bring the store master and the roadmap up to date in one docs PR. Read `docs/store/CHECKLIST.md`, `Tools/tests/test_marketing.py` and how `Tools/media/marketing.py` splices `docs/store/description.md` into `README.md`, `docs/store/curseforge.md` and `docs/store/wago.md`.

1. **Store master** (`docs/store/description.md`): add Zygor Guides Viewer support next to RestedXP (the guide on the story rail in the forged window card; credit contributor Baine), the Medallions hawk perches for hunters with Summon Hawk, and the polished crest jewels (flare, drain, whole-ring glow at max). **Correct a false claim**: Forever has no holy power or soul shards (no such power types in the client), so the crest jewels are rogue and cat-form druid combo points only; remove holy power / soul shards wherever the master, README or store kit says them. Keep the Discord invite at the top. Player words, short; never name EllesmereUI, CaithUI or any other UI pack. Text only (no new pictures in this PR).
2. **Roadmap** (`docs/ROADMAP.md`): v0.2.11 is out (its headline items); v0.2.12 next: Medallions cast bars on the player and target frames (merged #686), class crowns over the crest (rogue crown of blades and cat-druid claws, PR #678; warrior, priest, shaman, mage, bear druid and hunter crowns in progress), plus whatever the roadmap already lists that is still true. Remove anything shipped or dropped (paladin/warlock crowns are dropped).
3. Run `python3 Tools/media/marketing.py`, then the Python suite and lint.

PR to `staging`: `docs(store): v0.2.11 description and roadmap`, label `no changelog`. Do not merge, do not edit live store pages or post anything.

**Files it may edit**: `docs/store/**`, `README.md`, `docs/ROADMAP.md`, `Tools/media/**` (only if the splice needs it), `Tools/tests/test_marketing.py`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report PR number, SHA and run id, and paste the final CurseForge and Wago description paths.
