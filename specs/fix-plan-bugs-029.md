# Task: the small bugs the polish plan found, for v0.2.9

Read `C:/Users/leeba/.cache/kstyleui-evidence/polish-audit/PLAN.md`, section "Bugs", the table **"New, small enough for v0.2.9"**, and its source reports (`B-astra.md`, `D-astra.md`, `D-codex.md`, `B-codex.md`, `B-fable.md`, `D-fable.md`). Fix each row. Rows marked Unverified must first be reproduced in the harness; if a row can't be reproduced, say so and skip it.

**The rows**:
1. **Percent slider:** typing `50` saves 100%, and `50%` is dropped (`KstyleUI_Options/Rows.lua:134-138`, `Pages.lua:340`). Typed values are in displayed units, so `50` and `50%` both mean 0.5.
2. **World latency:** it shows the Home number when World is unavailable (`KstyleUI_DataBars/Strip.lua:148`). Show "--" instead.
3. **Accented search:** bag and map search miss accented capitals (`KstyleUI_Bags/Data.lua:279-284`, `KstyleUI_Skins/WorldMapRoutes.lua:138-140`). Add `Locale.Lower` beside `Locale.Upper` (`Core/Locale.lua:94`) and use it in both.
4. **Mover double-click** opens the module page, not that element (`Core/Layout/Mode.lua:543-555`). It must open the exact element's settings; Target of Target must not land on Player.
5. **Search:** it keeps the last page's heading, and Reset targets the hidden page (`KstyleUI_Options/Window.lua:240`, `:281`).
6. **Layout Mode finder:** Enter doesn't select a single match (`Core/Layout/Mode.lua:886-903`). Unverified.
7. **Vehicle leave button** sits on the Medallions clock (`KstyleUI_ActionBars/Vehicle.lua:38`). Fixture only; reproduce at all four sizes.
8. **Setup Modules page** is cut mid-line at its default size (`Core/Setup/Window.lua:1072-1074`). Unverified.
9. **German overflow:** the "BEUTE" chat tab spills 3.5 units, and the Data Bars preview heading collides (`KstyleUI_DataBars/Settings.lua:385-398`).
10. **Untranslated strings:** English sentences shipped as translations count as 100% (`Tools/locale/deDE.json:2372`). Make the locale check flag a translation identical to the English text for sentences (not names or units), and fix the flagged strings properly in de, fr, es and zh.

**For each**: a failing-then-passing regression or strict render. Default views not touched by a fix stay pixel-identical. Render the text fixes in English, German and French where relevant, at all four sizes, over a real game backdrop. Evidence goes to `C:/Users/leeba/.cache/kstyleui-evidence/plan-bugs-029/`.

**PR**: open a PR (not a draft) against `staging` titled `fix: ten small bugs from the polish audit`, with:
- `## Changelog` (`Fixed:` lines in player words);
- `## In-game checks`.

Do not merge.

**Files it may edit**: the files named above, `Core/Locale.lua`, `Core/Locales/**`, `Tools/locale/**` (including its checker), `KstyleUI_Chat/**` (tab layout only), `Tools/regression/**`, `Tools/render/**`, `Tools/tests/**` (locale checker tests).

**Constraints**: minimal code; CRLF/ASCII. Beast speed rule. Other parity PRs run in parallel and touch locales; rebase before opening and merge locale files by taking both sides.

**Gate**: lint, python, the touched modules' tests and `test-perf-path-budgets` under PUC Lua 5.1, then hosted CI.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id, and the rows fixed or skipped with reasons.
