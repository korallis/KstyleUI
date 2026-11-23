# Task: customisation batch 5: one aura filter set

**Goal**: the owner approved the customisation-parity plan and wants it all in v0.2.7. Read `C:/Users/leeba/.cache/kstyleui-evidence/customisation-parity/report.md` (gap table rows 4 and 5, "Shared building blocks" and batch 5). Batch 1 (the shared `TextRows` builder and tag formats) is draft PR #523 on branch `feat/options-text-tags`, and it touches the same module settings. **Base your branch on `feat/options-text-tags`**, open a PR stacked on it, and rebase onto staging once #523 merges. Another batch (3 or 5) runs in parallel on the same base and also touches `KstyleUI_Nameplates/Settings.lua`, so keep your edits there small and local to your section.

**Scope**: One shared aura filter row (only mine, dispellable by me, spell ID allow and block lists, sort), used by player auras (KstyleUI_Auras), nameplate debuffs and group frame debuffs. Today's filters stay the defaults, mapped from the existing keys. Spell IDs are plain numbers. Never compare secret aura fields; skip a secret spell ID safely.

**Rules**:
- An absent key is today's look and behaviour, and no migration rewrites saved settings.
- Schemas are built when the page opens: `test-perf-path-budgets` must stay under 15.7M.
- No comparison of secret values.
- One consistent style.

**Tests**: behaviour tests including defaults and off. Default renders are pixel-identical to base at 1920x1080 and 3840x2160. Renders of the options in use at all four sizes.

**Constraints**: minimal code; prefer deleting copies to adding. AGENTS.md rules. Evidence never committed (`C:/Users/leeba/.cache/kstyleui-evidence/cust-5/`). Open a **draft** PR with base `feat/options-text-tags`, titled `feat(options): one aura filter set`, with `## Changelog` (`Added: One aura filter for your auras, nameplates and group frames: only yours, dispellable by you, and spell lists to always show or hide.`), `## Options`, `## In-game checks` and `## Before and after`. Do not merge.

**Files it may edit**: `Core/Options.lua`, `Core/Widgets/**` (the shared row only), `KstyleUI_Auras/**`, `KstyleUI_Nameplates/**`, `KstyleUI_GroupFrames/**`, `KstyleUI_Options/**`, `Core/Locales/**`, `Tools/locale/*.json`, `Tools/regression/**`, `Tools/render/**`, the touched modules' READMEs.

**Gate**: lint, python and the touched tests plus `test-perf-path-budgets` under PUC Lua 5.1. Send worker_done once local proof is done, without waiting for queued CI.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and render paths.
