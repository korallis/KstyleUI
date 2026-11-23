# Task: v0.2.8 release notes

**Goal**: v0.2.8 is a test build for the owner and goes out to players through the stores, so it needs notes now.

**Target**: latest `origin/staging`. Read how v0.2.7 was done: its `CHANGELOG.md` entry, `docs/RELEASE_NOTES.md` and `Tools/release/discord_post.py`. Then read the `## Changelog` section of every PR merged since tag `v0.2.7` (`git log v0.2.7..origin/staging`, `gh pr view <n> --json body`). PRs labelled `no changelog` add no lines.

**Change**: add a `v0.2.8` entry to `CHANGELOG.md` and `docs/RELEASE_NOTES.md`.
- Build it from the merged PRs' Changelog lines, in player words, grouped Added / Changed / Fixed, in v0.2.7's style.
- Lead with a short highlights list:
  - the world map's smooth zoom, search and route card;
  - the setup's "Your addons" step, with skins on by default;
  - action bar tabs and the new per-bar options (text placement, cooldown look, item quality borders, visibility builder, toggle keys, click-through, reverse order);
  - the consumables bar at half size with a backdrop;
  - the fixes from the owner's gameplay video.
- Routes are straight lines in this build and the card says so; say that honestly ("road-following routes are coming").
- The Discord post must fit Discord's limits; check with its test.

**Constraints**: minimal; docs only. No version bumps or picture retakes unless v0.2.7's process did them in the notes PR (check, and follow it).

**PR**: open a PR (**not** a draft) against `staging` titled `docs(release): v0.2.8 notes`, labelled `no changelog`. Local checks: `bash scripts/gate.sh lint` and `bash scripts/gate.sh python`. Do not merge.

**Files it may edit**: `CHANGELOG.md`, `docs/RELEASE_NOTES.md`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report the PR URL and the list of included PRs.
