# Task: finish v0.2.6: notes, picture retakes, one PR

**Goal**: everything for v0.2.6 is merged on `staging`. Bring the release notes and the published pictures up to date in the existing draft PR #480 (branch `korallis/release-notes-v0-2`), fast.

**Change**:
1. Start now while PR #483 (G-b) applies three tiny code cuts that change no visuals: take the pictures from `origin/staging` merged with #483's head; when #483 merges (the coordinator will tell you), rebase #480 onto `origin/staging`. Rebase #480 onto `origin/staging`. In `CHANGELOG.md` and `docs/RELEASE_NOTES.md`, replace the marked list of open PRs with the `## Changelog` lines of every PR merged since `v0.2.5` that is not yet listed (`git log v0.2.5..origin/staging`, `gh pr view <n> --json body`): #460, #476, #477, #478, #479, #481, #482, #483 and any other. Player words, grouped Added / Changed / Fixed, as in v0.2.5. Not #475 (v0.2.7). Set the date to today (2026-11-18). Add "Known in-game checks" only if v0.2.5 had that section.
2. Retake the pictures: `python Tools/render/readme.py` and `python Tools/media/marketing.py --pages` (commands as listed in PR #480's body). Real game scenery only (the scripts use the owner's backdrops; never AI scenery); keep the `game_*` in-game captures; README ultrawide heroes stay Spread; Medallions shows one action row. Open every changed picture and check it shows the new looks (danger glow edge, cast results, Options task page, bar 3 beside the slab, crest debuff fan). Commit the retaken files the scripts write (README pictures and the store/marketing pages) in the same PR.
3. Change the PR title to `docs(release): v0.2.6 notes and pictures`, keep the `no changelog` label, mark it ready, wait for green checks.

**Constraints**: minimal; only the files the scripts write plus the two notes files. Windows (Beast): see `C:\Users\leeba\.claude\projects\C--Projects-KstyleUI\memory\beast-render-harness-chrome-urls.md` for the file-URL fix if a render writes no PNG; at most 2 renders at a time. Do not merge, tag or touch `main`.

**Files it may edit**: `CHANGELOG.md`, `docs/RELEASE_NOTES.md`, `docs/media/**`, the marketing/store page files `Tools/media/marketing.py` writes.

**Gate**: `bash scripts/gate.sh lint`, `bash scripts/gate.sh python`; green PR checks.

**Evidence of done**: PR #480 head SHA with green checks; the list of included PRs; the list of retaken pictures with one line on what changed in each.

**Before worker_done**: follow `C:\Users\leeba\orca-jev-router\WORKER.md`.
