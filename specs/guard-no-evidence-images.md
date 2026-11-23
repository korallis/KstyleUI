# Task: a check that blocks committed evidence renders

**Goal**: workers twice committed evidence renders to the repository:
- #489 added `Tools/render/evidence/bags-steady/*.png`, 2.3 MB;
- #500 added `docs/media/review/meters-both/*.jpg`, 12 JPEGs.

Renders are evidence only and never belong in git (verify/SKILL.md). Only published pictures do. Encode this as a check in the Gate whose error names the fix, and prove it fails on the real past mistakes.

**Target**: latest `origin/staging`: `Tools/hooks/` (existing pre-commit checks such as `check_toc.py`), `.pre-commit-config.yaml`, `Tools/tests/`.

**Change**:
1. A small check in `Tools/hooks/`, wired into pre-commit so `bash scripts/gate.sh lint` and CI run it. It fails when a tracked image (`.png`, `.jpg`, `.jpeg`, `.webp`, `.gif`, `.tga`, `.blp`) sits outside the published allow list:
   - `Media/**`;
   - `docs/media/readme/**`, `docs/media/marketing/**`, `docs/media/plates/**` and `docs/media/faq/**`;
   - `docs/store/**`;
   - the render harness's committed inputs (find them, e.g. `Tools/render/assets/**`, and any other existing tracked image folder that is legitimately source).

   List the allow list in one place. Build it from what is tracked on staging today, so the check passes on staging. The error message names the fix: "Evidence renders are not committed: remove <path> and put it in the PR body; published pictures live in docs/media/readme, marketing, plates or faq."
2. A Python test that runs the check on fixtures: it passes on today's tree, fails on `Tools/render/evidence/bags-steady/x.png` and on `docs/media/review/meters-both/x.jpg` (the two real past mistakes), and passes on `docs/media/readme/x.jpg`.

**Constraints**: minimal code (stdlib Python, a few dozen lines at most). No other behaviour changes. Open a **draft** PR against `staging` titled `test(hooks): evidence renders stay out of git`, labelled `no changelog`. Its body shows the check failing on the two past paths and passing on staging. Do not merge.

**Files it may edit**: `Tools/hooks/**`, `.pre-commit-config.yaml`, `Tools/tests/**`, `docs/DEVELOPING.md` (one line under the gate).

**Gate**: `bash scripts/gate.sh lint`, `bash scripts/gate.sh python`; green PR checks.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`.
