# Task: follow-up batch F: test(stubs): textures and alpha behave like the client

**Goal**: v0.2.7 has shipped. This batch clears queued follow-ups from `specs/QUEUE.md` and the release reviews. Work on the latest `origin/staging`.

**Scope**: Test-infrastructure gaps from earlier reviews. (1) `stubs/wow.lua` SetAtlas keeps the previous texture path, but the client replaces it. (2) `stubs/wow.lua:526-535`: GetAlpha and GetVertexColor share one alpha, which matches the client (texture alpha is one value; SetAlpha equals vertex alpha, last write wins). Verify against the client rule and document it in the stub, so nobody 'fixes' it wrongly. (3) `Tools/tests/test_render_size.py` PUC subprocess timeouts of 60-90 s under load on Beast: make the timeout load-aware, or scale it the way the Lua hang guard does. Keep every existing test green; if a stub fix exposes real addon bugs, list them, don't fix them here.

**Rules**:
- Owner rules apply: one consistent style; everything toggleable, ON by default; minimal code.
- Never move a saved position.
- `test-perf-path-budgets` stays under 15.7M (staging is at about 14.84M).
- Visual changes come with before and after strict renders at 1920x1080 and 5120x1440. Changes that should be invisible must be pixel-identical.

**Tests**: a regression test for each fix that fails before it, with a failure message that names the fix.

**Constraints**: CRLF/ASCII for addon files; locales synced with translations. Evidence never committed (`C:/Users/leeba/.cache/kstyleui-evidence/fu-F/`). Open a PR (not a draft) against `staging` titled `test(stubs): textures and alpha behave like the client` with `## Changelog` (`no changelog` label), `## In-game checks` and `## Before and after` where visual. Do not merge.

**Files it may edit**: `Tools/regression/stubs/**`, `Tools/tests/**`, `Core/Locales/**`, `Tools/locale/*.json`, `Tools/regression/**`, `Tools/render/**`, the touched modules' READMEs.

**Gate**: lint, python and the touched tests under PUC Lua 5.1; CI is hosted and fast. Send worker_done with the run id once it's green.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and render paths.
