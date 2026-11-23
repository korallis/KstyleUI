# Task: customisation batch 3: one bar options set everywhere

**Goal**: the owner approved the customisation-parity plan and wants it all in v0.2.7. Read `C:/Users/leeba/.cache/kstyleui-evidence/customisation-parity/report.md` (gap table rows 4 and 5, "Shared building blocks" and batch 3). Batch 1 (the shared `TextRows` builder and tag formats) is draft PR #523 on branch `feat/options-text-tags`, and it touches the same module settings. **Base your branch on `feat/options-text-tags`**, open a PR stacked on it, and rebase onto staging once #523 merges. Another batch (3 or 5) runs in parallel on the same base and also touches `KstyleUI_Nameplates/Settings.lua`, so keep your edits there small and local to your section.

**Scope**: Replace the hand-rolled bar texture, colour-mode and height rows in each module that still has its own (unit frames, nameplates, group frames, cooldown bars, meters and data bars, per the report) with one shared bar-rows builder next to TextRows. The stored keys stay the same, so nothing changes for players. Net lines should go down.

**Rules**:
- An absent key is today's look and behaviour, and no migration rewrites saved settings.
- Schemas are built when the page opens: `test-perf-path-budgets` must stay under 15.7M.
- No comparison of secret values.
- One consistent style.

**Tests**: behaviour tests including defaults and off. Default renders are pixel-identical to base at 1920x1080 and 3840x2160. Renders of the options in use at all four sizes.

**Constraints**: minimal code; prefer deleting copies to adding. AGENTS.md rules. Evidence never committed (`C:/Users/leeba/.cache/kstyleui-evidence/cust-3/`). Open a **draft** PR with base `feat/options-text-tags`, titled `feat(options): one bar options set everywhere`, with `## Changelog` (`Changed: Every bar's texture, colour and height options look and work the same in every module.`), `## Options`, `## In-game checks` and `## Before and after`. Do not merge.

**Files it may edit**: `Core/Options.lua`, `Core/Widgets/**` (the shared builder only), the modules' `Settings.lua` files, `KstyleUI_Options/**`, `Core/Locales/**`, `Tools/locale/*.json`, `Tools/regression/**`, `Tools/render/**`, the touched modules' READMEs.

**Gate**: lint, python and the touched tests plus `test-perf-path-budgets` under PUC Lua 5.1. Send worker_done once local proof is done, without waiting for queued CI.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and render paths.
