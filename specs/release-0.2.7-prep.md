# Task: prepare the v0.2.7 release notes and store copy now, so tagging is fast

**Goal**: v0.2.7 ships as soon as the last two PRs merge: #530 (data bar readouts) and the Medallions layout PR ("feat(medallions): centred cooldowns and aura rows above the unit frames"). Draft everything now in one draft PR and keep it current.

**Target**: latest `origin/staging`. Read how v0.2.6 was done: its `CHANGELOG.md` entry, `docs/RELEASE_NOTES.md`, and `Tools/release/discord_post.py`, which posts the notes to Discord at release. Then read the `## Changelog` section of every PR merged since tag `v0.2.6` (`git log v0.2.6..origin/staging`, `gh pr view <n> --json body`).

**Change**:
1. Add a `v0.2.7` entry to `CHANGELOG.md` and `docs/RELEASE_NOTES.md`, built from the merged PRs' Changelog lines in player words, grouped Added / Changed / Fixed, in v0.2.6's style. It's a big release, so lead with a short highlights list (data bar, consumables bar, crest clicks and minimap, Medallions extra bars, text formats, attach frames, aura filters, a layout per spec, party quest progress, fixes for the minimap freeze and the alt-tab stutter, no overlaps at any size). Mention the optional KstyleUI Icons pack the way the store text does. The Discord post must fit Discord's limits (`discord_post.py` behaviour); check with its own test.
2. At the end of the draft, list the two still-open PRs with their numbers. The coordinator adds their lines at tag time.
3. Do not bump versions or retake pictures; that happens after the last look change lands. Dry-run the picture retake commands once to prove they run (`python Tools/render/readme.py --help`, `python Tools/media/marketing.py --help`), and put the exact commands and their run time in the PR body.

**Constraints**: minimal; docs only. Open a **draft** PR against `staging` titled `docs(release): v0.2.7 notes`, labelled `no changelog`. Local checks: `bash scripts/gate.sh lint` and `bash scripts/gate.sh python`.

**Files it may edit**: `CHANGELOG.md`, `docs/RELEASE_NOTES.md`.

**Evidence of done**: the draft PR URL with green checks, and the list of included PRs.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`.
