# Task: release notes for v0.2.8.2

Write the notes PR for KstyleUI v0.2.8.2, which will be tagged from `staging`. Branch from `origin/staging` at `b94abee8` (do not rebase onto later commits; the release content is frozen there).

**What the release contains**: every commit in `git log v0.2.8..b94abee8` on staging. Note that v0.2.8.1 was cut from main as a hotfix: `origin/main` has `ad9049a7 docs(release): v0.2.8.1 notes`, which staging lacks. Bring its `## v0.2.8.1` CHANGELOG section and its `docs/RELEASE_NOTES.md` section into this branch unchanged (copy the text; do not merge main), then add v0.2.8.2 above it. Leave out of v0.2.8.2 anything v0.2.8.1 already shipped (#570, #571).

**Format**: the same branded, readable format as the v0.2.8 sections in `CHANGELOG.md` and `docs/RELEASE_NOTES.md`, following `docs/` release-highlight rules from #582 and #575 (short highlights that fit the Discord embed, which `Tools/release/discord_post.py` builds; check that its output for v0.2.8.2 fits and reads well by running it in dry-run or preview mode if it has one). Lead the highlights with the player bug fixes (RestedXP guide card never cuts the current step, the ten polish-audit fixes, welcome text, French Options footer, readable data bar, colour-vision health), then the new options and world map road routes. Player words only: never name EllesmereUI, CaithUI or any other UI pack, and no internal PR jargon. Every new option is off by default unless the commit says otherwise; say so where it matters. Each line must be true of `b94abee8`: verify claims against the code or the PR bodies, not titles alone.

**Gate**: `bash scripts/gate.sh lint` and `python`, plus `Tools/hooks/check-pr.sh` rules. PR title `docs(release): v0.2.8.2 notes`, target `staging`, label `no changelog` only if check-pr requires it for a docs-only PR. Do not merge, tag or post anything.

**Files it may edit**: `CHANGELOG.md`, `docs/RELEASE_NOTES.md`, the version in TOC files only if earlier release-notes PRs bumped it (check `git show ad9049a7 --stat` and the v0.2.8 notes PR).

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report PR number, SHA and run id.
