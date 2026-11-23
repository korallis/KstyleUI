# Task: fix the pipefail/SIGPIPE race in Tools/hooks/check-package.sh

PR #746's hosted checks run 45113777493 attempt 1 failed in `Tools/hooks/check-package.sh` around line 69, reporting `LICENSE.md` missing from the package although it is there (attempt 2 and staging passed). It looks like a `set -o pipefail` pipeline where a reader such as `grep -q` or `head` exits early and the writer gets SIGPIPE, so the pipeline fails at random.

Pull the failing log (`gh run view 45113777493 --attempt 1 --log-failed`), confirm the cause, and fix it so the check is deterministic and still fails on a truly missing file (for example capture the listing in a variable first, then search it). Prove both: a loop of 200 local runs passes, and a run with LICENSE.md removed from a scratch package still fails.

**Files it may edit**: `Tools/hooks/check-package.sh` and its Python test in `Tools/tests/` if one exists.

**PR**: `fix(ci): make check-package deterministic under pipefail`, label `no changelog`. Do not merge.

**Constraints**: minimal code.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and the cause.
