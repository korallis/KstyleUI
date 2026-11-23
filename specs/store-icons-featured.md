# Task: a featured "KstyleUI Icons" section in the README and store descriptions

**Goal**: few players use the optional repainted icon pack, because CurseForge and Wago install addons only and the pack is a separate loose-file download. The owner wants a **featured section** in the descriptions that tells players what the pack is, where to get it and how to install it. No addon code changes.

**Change**:
1. In the master description `docs/store/description.md`, add a featured section high on the page, right after the opening pitch: "KstyleUI Icons: the full repainted look". It has:
   - **What it is**: every ability, item, buff and debuff icon repainted in one style, everywhere the game draws it, including buff tiles. It is optional and AI-made, as the picture captions already say.
   - **One before-and-after picture**: the same action bar row with Blizzard's icons, then with the pack. Make it with the render harness: the scenes can resolve icons from the pack or from Blizzard's extract (see `docs/icons.md`, "The renders"). Use the branded marketing style of the existing images in `docs/media/marketing/`, made by `Tools/media/marketing.py`. Use real game scenery only, never AI scenery.
   - **Get it**: the `KstyleUI-Icons-<version>.zip` attached to each GitHub release. Link to the releases page (`https://github.com/korallis/KstyleUI/releases/latest`), not to a zip file.
   - **Install in 5 short steps**, from `docs/icons.md`: quit the game fully; unzip; copy the `Interface` folder into `World of Warcraft/_forever_/` so the files land in `_forever_/Interface/Icons/`; the Mac path; start the game. Add one line on removing it.
   - **Notes**: the pack works with or without the addon; it needs a full restart, not `/reload`; and a few store and event icons stay Blizzard's.
2. Run `Tools/media/marketing.py` so the README and the store kit (`docs/store/curseforge.md`, `wago.md`) get the same block.
3. `Tools/tests/test_marketing.py` fails on a releases/.zip download link. Allow exactly the releases-page link for the icon pack, in the fewest lines, and keep the ban on links to addon zips. Say why in the PR.
4. Add the same short install steps as an FAQ entry in the FAQ section.

**Constraints**: minimal change. The text follows the house style of the existing description (short, plain, second person). Evidence is never committed; only the one marketing image goes in `docs/media/marketing/`. Open a PR against `staging` titled `docs(store): a featured section for the KstyleUI Icons pack` with the `no changelog` label and `## In-game checks` (none: docs only). Not a draft, since it is docs only; do not merge.

**Files it may edit**: `docs/store/**`, `README.md`, `docs/media/marketing/**` (one new image), `Tools/media/marketing.py`, `Tools/tests/test_marketing.py`, `docs/icons.md` (only if a step there is wrong).

**Gate**: `bash scripts/gate.sh lint` and `python` locally; green Mac CI.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, base SHA, PR URL, run id and the image path.
