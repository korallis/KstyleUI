# Task: EllesmereUI parity, option by option: the minimap, data bars and data texts, chat, bags, tooltips and QoL

**The owner's words**: "Do an option by option audit and add anything that can be done that doesn't break our consistency thing." KstyleUI's customisation should rival EllesmereUI's.

**Context**:
- The earlier high-level audit is `C:/Users/leeba/.cache/kstyleui-evidence/customisation-parity/report.md`, and its seven batches are merged.
- The action bars already have an option-by-option table, with the rows done; it's in `KstyleUI_ActionBars/README.md`, "EllesmereUI parity audit". Follow that format.
- The shared builders are on staging: `TextRows` and tags, `BarRows`, the aura filter row, Shown (party, raid, solo), attach and match width, and a layout per spec. Reuse them; build no new framework.

**Scope**: the minimap, data bars and data texts, chat, bags, tooltips and QoL.

**Do**:
1. **Audit:** list **every** EllesmereUI option for these modules from public sources: its CurseForge and Wago pages, changelogs, public screenshots and its public source for behaviour only (copy no code or data). For each option, record:
   - **Present**: name the KstyleUI control;
   - **Missing, fits**;
   - **Missing, breaks consistency**: say why, for example per-element chrome or shape zoos, 3D portraits, a second settings system or anything that makes siblings look different;
   - **Not possible on Forever**: prove it in `C:/Users/leeba/.cache/wow-ui-source` at `9dc84f0`.
2. **Build every "Missing, fits" row:**
   - in the existing schemas with the shared builders, keeping it minimal;
   - new options are toggleable;
   - **defaults keep today's look and behaviour**, unless an option is a clear improvement players expect, in which case say why and default it ON (the everything-toggleable, ON-by-default rule);
   - prove every API and event, guard each one, and check `issecretvalue`;
   - no per-frame work; secure changes are queued in combat; stay within the reload budget (`test-perf-path-budgets`, about 15.05M of 15.7M today; the Options schemas are lazy, so keep them lazy).
3. **Too big for one PR:** if the fitting rows exceed about 600 lines, ship the most player-visible ones in this PR and list the rest as a follow-up batch.

**Tests**:
- each new option writes and applies, and its default is unchanged;
- upgrade safety: a v0.2.8-shaped profile loads;
- `test-perf-path-budgets` passes.

**Renders**: each changed module's Options page and the affected frames, at 1920x1080 and 5120x1440 (add 2560x1440 and 3840x2160 for layout changes). Use `--strict` and real game backdrops. Evidence goes to `C:/Users/leeba/.cache/kstyleui-evidence/parity-shell/`, never committed.

**PR**: open a PR (not a draft) against `staging` titled `feat(options): minimap, data text, chat, bag, tooltip and QoL options to EllesmereUI parity`. Include:
- `## Changelog`, with `Added:` lines in player words;
- `## Options`, `## In-game checks` and `## Forever API`;
- a parity table section in each module's README, in the action bar table's format.

Do not merge.

**Files it may edit**: the scoped modules' folders (`KstyleUI_Minimap/**, KstyleUI_DataBars/**, KstyleUI_Chat/**, KstyleUI_Bags/**, KstyleUI_Tooltips/**, KstyleUI_QoL/**`), `KstyleUI_Options/**` (rows only, no new framework), `Core/Widgets/Text.lua` and the shared row builders (only to extend a shared builder all modules use), `Core/Locales/**`, `Tools/locale/*.json`, `Tools/regression/**`, `Tools/render/**`, `docs/feature-map.md`.

**Constraints**:
- One consistent style.
- CRLF/ASCII; locales synced with translations.
- Beast speed rule: no full local Lua suite, at most 2 renders at a time.
- Other parity PRs are running in parallel on other modules; touch shared builders only if necessary, and rebase before opening.

**Gate**: lint, python, the scoped modules' tests and `test-perf-path-budgets` under PUC Lua 5.1, then hosted CI.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id, the parity table (counts per status) and render paths.
