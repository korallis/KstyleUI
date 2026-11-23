# Task: v0.2.3 release prep: changelog, release notes, README text and pictures

**Goal**: one docs PR that makes `CHANGELOG.md`, `docs/RELEASE_NOTES.md` and `README.md` (text and pictures) describe exactly what staging ships for v0.2.3, so the owner can tag it.

**Target**: KstyleUI, branch from the latest `origin/staging`. A WIP draft exists on `origin/release/v0.2.3-prep` (commit `354b2ba4`, based on an older staging): reuse its wording where it is still true. Everything merged to staging since v0.2.2 (`git log v0.2.2..origin/staging --oneline`) is in scope; player-facing changes (Medallions polish #405-#410, quest card #418, Options #421, rune rim #424, vehicle button #423, crisper edges #426, unused art removed #420) go in the changelog; tooling and CI PRs do not (the `no changelog` label marks them). Read each merged PR's `## Changelog` line (`gh pr view <n> --json body`) as the source.

**Change**:
- `CHANGELOG.md`: a `## v0.2.3 (<today's date>)` section above v0.2.2 with `### Changed` and `### Fixed` lines a player understands, one line per player-visible change, no PR numbers or internals. Match the style of earlier sections.
- `docs/RELEASE_NOTES.md`: the v0.2.3 notes in the file's existing format.
- `README.md`: current features only (Lee: "it's like a marketing page for the addon"); update the Medallions text and any feature that changed; no old data.
- Pictures: retake every README picture with `python Tools/render/readme.py` from this branch (the render harness now uses the game's real HUD fit), after reading its `--help` and `Tools/render/README.md`; open each new picture and check it shows the current look (one row of action buttons, engraved rims, unit cluster); commit only the pictures `readme.py` writes.
- Do not change any version line in a TOC or `CODE_BUILD` (the owner's release step does that if needed; say in the PR if the release workflow needs it).

**Playbook**: none.

**Constraints**: docs and pictures only; no addon code. Windows machine (Beast): prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`; `verify/SKILL.md` documents rendering. Open a **draft** PR against `staging`: title `docs(release): v0.2.3 changelog, release notes and README`, label `no changelog`, body with `## Summary`, `## Changelog` ("No changelog: docs"), `## In-game checks` ("None"), and the list of pictures changed. Do not merge it, do not tag.

**Files it may edit**: `CHANGELOG.md`, `docs/RELEASE_NOTES.md`, `README.md`, the picture files `Tools/render/readme.py` writes.

**Gate**: `bash scripts/gate.sh` (lint must pass; `Tools/tests/test_release_changelog.py` checks the changelog format, run it).

**Evidence of done**: the changelog section; the list of PRs since v0.2.2 with which went in and why the rest did not; every new README picture opened and described in one line; `readme.py` exit code; the draft PR's green `checks` run.

**Before worker_done**: run the Gate as above. Conventional Commits subjects. If you stop before green: commit `wip: <what>` and report BLOCKED. Report SHA, base SHA, PR URL, run id, Gate output and evidence.

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
