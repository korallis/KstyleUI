# Task: README features Medallions first

**Goal**: the README presents Medallions as KstyleUI's featured HUD style.

**Target**: KstyleUI, branch from the latest `origin/staging`. Today the README's hero picture is `docs/media/readme/hud_orbs_5120.jpg`, the intro lists "classic frames, ... orbs ..., or Medallions" last, and the section "Three HUD styles: Frames, Orbs and Medallions" shows Frames and Orbs first with Medallions in a sub-section after them. The owner, 2026-11-17: "make medallions the feature layout".

**Change** (README text and order only; reuse the existing pictures, no new renders):
- Hero picture under the links: `hud_medallions_5120.jpg` (Spread), with its caption saying it is the Medallions HUD; the intro paragraph leads with Medallions and then mentions Frames and Orbs as the other two styles.
- The HUD styles section is titled and ordered Medallions, then Frames, then Orbs: Medallions' text, crop and 1080 picture come first; the Orbs 5120 picture moves into the Orbs part (it is no longer the hero); Frames and Orbs keep their own pictures and text.
- Update the in-page anchor links (for example `#three-hud-styles-frames-orbs-and-medallions`) so every link still works; keep alt texts accurate.
- Keep everything else (install, features, ultrawide section, changelog links) unchanged.

**Playbook**: none.

**Constraints**: README only. Windows machine (Beast): prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. Run any README test in `Tools/tests/` (e.g. one that checks image links or anchors). Open a **draft** PR against `staging`: title `docs(readme): feature the Medallions HUD`, label `no changelog`, body with `## Summary`, `## Changelog` ("No changelog: docs"), `## In-game checks` ("None"). Do not merge.

**Files it may edit**: `README.md`.

**Gate**: `bash scripts/gate.sh lint` and `gate.sh python` exit 0.

**Evidence of done**: a short outline of the new README order; every image path and in-page anchor resolves (list them with a check); the draft PR's green `checks` run.

**Before worker_done**: Conventional Commits subjects. Report SHA, base SHA, PR URL and run id.

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
