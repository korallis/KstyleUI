# Task: staging and release checks run on GitHub-hosted runners; the Macs never block

The owner (2026-11-23): "you can use GitHub runners too which solve any bottlenecks". Today a staging push (`.github/workflows/checks.yml` line ~22) and every release job (`.github/workflows/release.yml`, `runs-on: [self-hosted, mac-ci, KstyleUI]` at lines ~31, 85, 111, 158) run only on the three self-hosted Macs. When a Mac is offline, on battery or busy (Spotlight, XProtect after a reboot), staging and releases stall or fail on CPU budgets for no code reason. This happened twice on 2026-11-23.

**Goal**: staging pushes and releases are gated by GitHub-hosted runners, exactly as pull requests already are (`ubuntu-latest`, 8 Lua shards, the hosted CPU rules: per-file overruns warn above a 2.5 factor, headroom skipped, functional, instruction, memory and hang checks fatal). The Macs keep measuring CPU budgets but never block: run the Mac Lua shards as a separate, non-blocking job or workflow on staging pushes (results visible, failures reported, never required, never awaited by release). Release (`release.yml`) runs its check jobs on `ubuntu-latest`, and its same-tree reuse accepts a green hosted staging run. Packaging, upload and Discord jobs move to `ubuntu-latest` unless they truly need macOS (say why if so).

Keep it minimal: change `runs-on`, the matrix size and the required/awaited jobs; don't restructure the workflows. Update `AGENTS.md`'s Budget rule and "The gate" paragraph, `Tools/regression/README.md` and any Python tests in `Tools/tests/` that assert the workflow shape (`test_ci_*`, `test_release_*`) so the docs match: hosted CI is the gate everywhere; Mac CI is a non-blocking CPU budget monitor.

`.github/workflows/` is a guarded path: say why in the PR body (owner's request, quote above).

**Proof**: the Python suite and lint; a `workflow_dispatch` or test push of `checks.yml` on your branch showing the hosted shards run; show with `act`-free reasoning in the PR body which jobs release now waits for. Do not tag anything.

**Files it may edit**: `.github/workflows/checks.yml`, `.github/workflows/release.yml`, `AGENTS.md` (those two paragraphs), `Tools/regression/README.md`, `Tools/tests/**`, `scripts/gate.sh` only if a flag is needed.

**PR**: `ci: gate staging and releases on GitHub-hosted runners`, label `no changelog`. Do not merge.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run ids.
