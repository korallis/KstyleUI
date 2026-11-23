# Task: customisation batch 4: attach an element to another, and match its width

**Goal**: the owner approved the customisation-parity plan (EllesmereUI-level customisation inside one consistent style) and wants it all in v0.2.7. Read `C:/Users/leeba/.cache/kstyleui-evidence/customisation-parity/report.md` (the Layout Mode table, "Shared building blocks" item 4 and batch 4). Batch 2 (show in party, raid or solo) is draft PR #521 on branch `korallis/feat-show-in-party`, and it touches the same `Core/Layout` files. **Base your branch on `korallis/feat-show-in-party`**, open a PR stacked on it, and rebase onto staging once #521 merges.

**Scope**: Add an optional link on each Layout element: a target element key, a side (above, below, left or right, not a 9-to-9 matrix), an offset, and 'match width'. The default is not attached, which is today's anchor to the root. Moving the target moves attached elements. A missing or disabled target falls back to the element's own saved place. Prevent cycles. Add Options rows on the element: 'Attach to', 'Side', 'Match width'. Layout Mode shows the link. Secure frames apply through Combat.Queue.

**Rules**:
- An absent key is today's behaviour, and no migration rewrites a saved place.
- Schemas are built when the page opens, with near-zero reload cost: `test-perf-path-budgets` must stay under 15.7M.
- Protected moves wait for `Combat.Queue`.
- One consistent style.

**Tests**: behaviour tests for each piece, including defaults. Default renders are pixel-identical to base. Renders of the feature in use at 1920x1080, 2560x1440, 5120x1440 and 3840x2160.

**Constraints**: minimal code; AGENTS.md rules. Evidence never committed (`C:/Users/leeba/.cache/kstyleui-evidence/cust-4/`). Open a **draft** PR with base `korallis/feat-show-in-party`, titled `feat(layout): attach an element to another, and match its width`, with `## Changelog` (`Added: Attach any element to another one (above, below or beside it) and match its width; it follows wherever you move the other.`), `## Options`, `## In-game checks` and `## Before and after`. Do not merge.

**Files it may edit**: `Core/Layout/**`, `KstyleUI_Options/**`, `Core/Locales/**`, `Tools/locale/*.json`, `Tools/regression/**`, `Tools/render/**`, `docs/feature-map.md`, `Core/Layout/README.md`.

**Gate**: lint, python and the touched tests plus `test-perf-path-budgets` under PUC Lua 5.1. Send worker_done once local proof is done, without waiting for queued CI.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and render paths.
