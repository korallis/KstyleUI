# Task: finish PR #410 (Medallions WP-C unit cluster) for merge

**Goal**: get PR #410 merge-ready: rebased on current staging, CI green, and its compare sheets re-rendered and checked against the KSTY-110 mock.

**Target**: KstyleUI, PR https://github.com/korallis/KstyleUI/pull/410, branch `capy/medallions-unit-cluster` (head `a175c599`). Read the PR body in full, especially "Decisions for the Captain" and "Pictures" (the KSTY-110 mock and CaithUI reference images are linked there; download them with `gh` or curl). Staging has moved (CI workflow changes #412, onboarding #411), so rebase.

**Change**:
1. Check out the PR branch in your worktree, rebase onto `origin/staging`, resolve conflicts, run the gate, force-push with lease to the same branch (this is the PR author's own branch; force-with-lease is allowed here and only here).
2. Confirm health and power numbers in Medallions use Barlow (the number role) at every screen.
3. Re-render the compare sheets the PR's Pictures section shows, from the rebased head, for the owner's case first: undead male warlock with an imp, Medallions, at 5120x1440 (`--ppu 1.3333333333`), 3456x2234 and 1920x1080, with `RENDER_SIZE=auto`, `--strict`, `--backdrop`. Put each next to the KSTY-110 mock at the same scale (side by side, same crop). Also confirm Frames and Orbs are pixel-identical to staging at those three screens (PIL difference has no bounding box).
4. Judge each sheet against the mock: unit cluster placement, one row of twelve action buttons on every screen with the action buttons above the hub, cast slabs, pet and stance slabs, no textures around bars. If something does not match the mock or a rule, fix it on this branch with a test that fails before the fix, and say so.
5. Update the PR's Pictures section with the new sheets (upload them as PR comment attachments or commit them under `docs/` only if the PR already does that) and add a short "Rebased and re-rendered" note. Do not merge.

**Playbook**: none.

**Constraints**:
- Rules from AGENTS.md apply (addon files CRLF/ASCII via `python3 Tools/dev/crlf.py`, one comment per file, Forever API grep, conventions the tests enforce). One row of action buttons on every screen; action buttons always above the hub; no textures around bars; all art original.
- This is UI work: judge by looking at the pictures, not only by tests. Open every PNG you cite.
- Windows machine (Beast): prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. `verify/SKILL.md` documents the render harness on Windows, including the Chrome shim at `C:\Users\leeba\.cache\kstyleui-verify\chrome-shim.sh` and the `C:\dev` folder.
- Render output goes under `C:\Users\leeba\.capy\drive\captain-kstyle-project-lead\renders\KSTY-113\` (not the repo).

**Files it may edit**: files the PR already touches, plus tests under `Tools/regression/` for any fix.

**Gate**: `bash scripts/gate.sh`. Known failing on Windows: `lua` and `python` groups (AGENTS.md); Windows bar is `gate.sh lint` exit 0 plus the PR's Medallions test files run directly with `lua5.1` (list them); the PR's CI run on the Macs proves the full suite.

**Evidence of done**: the rebased head SHA and its green `checks` run (`gh run view <id> --json jobs,conclusion`); the sheet paths with one line each on what matches and what differs from the mock; the Frames/Orbs no-diff output; the Barlow check.

**Before worker_done**: run the Gate as above; clean comments in `git diff origin/staging..HEAD` by following `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` in worker mode (delete the comments, list MUST KILL flags, skip its greeting). Conventional Commits subjects. If you stop before green: commit `wip: <what>` and report BLOCKED (worker_done `--outcome failed`). Report head SHA, base SHA, run id, Gate output and evidence.
