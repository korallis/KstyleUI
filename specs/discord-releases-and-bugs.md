# Task: releases post their changelog to Discord, and bug reports go to Discord

**Goal**: the owner wants the KstyleUI Discord (invite https://discord.gg/A5qqGZEXyN, server set up already) to be where players get changelogs and report bugs.
- Every release posts its full changelog to #announcements automatically.
- The README, CurseForge and Wago send bug reports to the Discord #bug-reports forum only.

The stores already receive CHANGELOG.md through the packager (`.pkgmeta` manual-changelog): keep that.

**Target**: latest `origin/staging`, but work on branch `docs/faq-ultrawide-bars` (open PR #492). It already has the FAQ and the Discord link; add to it so this is one PR. Relevant files:
- `.github/workflows/release.yml`: the `release` job, environment `release`. The environment secret `DISCORD_RELEASE_WEBHOOK` is already set.
- `Tools/tests/test_release_changelog.py`, which shows how the tag's changelog section is read.
- `README.md`, `docs/store/curseforge.md`, `docs/store/wago.md`, `docs/store/description.md`.

**Change**:
1. A small stdlib-only Python script, `Tools/release/discord_post.py`, plus one step at the end of the `release` job after all uploads:
   - It reads the tag's section from `CHANGELOG.md` and posts it to `DISCORD_RELEASE_WEBHOOK`.
   - Message: a title line "KstyleUI vX.Y.Z is out", the summary, and the Added, Changed and Fixed lists in Discord markdown.
   - It then posts download links: CurseForge https://www.curseforge.com/wow/addons/kstyleui, Wago https://addons.wago.io/addons/kstyleui, and the GitHub release URL.
   - It splits the text into messages of at most 2000 characters at line breaks, and suppresses link previews (`flags: 4`).
   - If the secret is empty it skips with a notice and does not fail the release. If a post fails, it warns but the release still succeeds.

   Add a unit test for the parsing and splitting, with no network. Keep it to the fewest lines.
2. Bug reports to Discord:
   - Add `.github/ISSUE_TEMPLATE/config.yml` with `blank_issues_enabled: false` and one contact link: "Report a bug on Discord", URL https://discord.gg/A5qqGZEXyN, about "Post in #bug-reports with your KstyleUI version and a screenshot".
   - In the README and the store pages, change "How do I report a bug?" to point only to Discord #bug-reports. Change the Links lists so Discord is the place for bugs and help ("Bug reports and help: https://discord.gg/A5qqGZEXyN"). Keep the source code link and drop the GitHub "Issues:" line.
   - On CurseForge, keep the "Links to set on the project" list consistent: Issues = the Discord link.
3. Say in the PR body why `.github/workflows/` and `.github/ISSUE_TEMPLATE` changed (AGENTS.md asks for that).

**Constraints**: minimal code; never print or log the webhook URL; actions stay pinned by commit hash as the repo requires (no new third-party action; use plain `python3`). The PR stays labelled `no changelog`, retitled `docs: FAQ, Discord for bugs and release posts`. Run `actionlint` if the repo's checks use it (`.github/actionlint.yaml`). Do not merge or tag.

**Files it may edit**: `.github/workflows/release.yml`, `.github/ISSUE_TEMPLATE/config.yml` (new), `Tools/release/**` (new), `Tools/tests/**`, `README.md`, `docs/store/**`.

**Gate**: `bash scripts/gate.sh lint`, `bash scripts/gate.sh python`; green PR checks.

**Evidence of done**: the test output; a dry run of the script against `v0.2.6` that prints the messages it would send (with the webhook unset) and their lengths; the PR head with green checks.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`.
