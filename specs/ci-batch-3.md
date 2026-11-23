# Task: CI batch 3, safer releases

The owner approved this from the two CI audits. Read `C:/Users/leeba/.cache/kstyleui-evidence/ci-audit/claude.md` (items 10-12) and `codex.md` (items 8-9). PR #575, the Discord embed and repost job, has merged; start from current `origin/staging`.

**Change**:
1. **A release refuses known-red proof:**
   - `release.yml` must not publish when the tagged commit's latest staging `checks` run (or the hotfix branch's run) **failed**. Release `44684631014` published after staging run `44684586974` failed;
   - distinguish "known failed proof" (refuse) from "no proof yet" (keep today's behaviour of running its own Lua check);
   - lint and Python must also be proven: rerun them in the release `check` job if they have no proof, which is cheap.
2. **Check the uploaded zip:** `release.yml:100-107` rebuilds and uploads without running `check-package.sh`; only the `check` job's separate dry build is checked. Run `check-package.sh` on the exact zip that gets uploaded, before the upload.
3. **Trim brittle snapshot tests:** in `Tools/tests/test_workflows.py`, delete the tests that only mirror YAML values, such as exact job names, timeouts and shard topology snapshots, which actionlint and zizmor already cover. Keep the behaviour and security invariants (permissions, pinning, scope decisions, red/green proof logic, the manual dispatch that can't upload). Report the lines removed.

**Constraints**:
- Never weaken a real guard. Minimal code.
- Say why `.github/workflows/` changes.
- The CI batch 1 PR (#574, five Mac shards) may still be open and edits `release.yml`'s Lua shard count. Keep your change separate from it, and rebase if it merges first.

**Proof**: tests for the refusal logic, with a fake GitHub API or the existing test harness pattern, for these cases:
- red latest run, which refuses;
- green, which publishes;
- no run yet, which runs its own checks;
- the zip check on the upload path.

**PR**: open a PR (not a draft) against `staging` titled `build(release): refuse red proof and check the uploaded zip`, with the `no changelog` label. Do not merge.

**Files it may edit**: `.github/workflows/release.yml`, `Tools/hooks/check-package.sh` (only if needed), `Tools/tests/test_workflows.py`, `Tools/tests/test_release*.py`, `Tools/release/*` (only for a small proof helper, if needed).

**Gate**: lint and python, then hosted CI.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL and run id.
