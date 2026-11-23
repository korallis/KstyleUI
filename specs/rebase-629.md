# Task: rebase PR #629 onto staging after #625

PR https://github.com/korallis/KstyleUI/pull/629 (Unit frames parity round 3b, head `8d91384d`) conflicts with staging in `Tools/render/scenes/frames_text_slots.lua`, `docs/feature-map.md` and locale files because PR #625 (Unit frames round 3a, MiniFrames) just merged. Rebase onto `origin/staging`, keep both PRs' behaviour (read #625's squash commit and its README to understand what it changed), take both sides' locale strings and run `python3 Tools/locale/strings.py sync`.

**Prove nothing regressed**: every `test-unitframes-*` (including r3a, r3b and their review tests), `test-store`, `test-taint-scan`, `test-perf-path-budgets` under PUC Lua 5.1; lint and python; 0 default pixel diffs staging-vs-PR for hud_reference Frames, Orbs and Medallions and frames_text_slots at 1920x1080 and 5120x1440; the r3b enabled renders at all four sizes `--strict`. Push to the same branch with force-with-lease; hosted CI green. Do not merge.

**Files it may edit**: the files either PR touches, plus `Tools/regression/**` and `Tools/render/**`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA and run id.
