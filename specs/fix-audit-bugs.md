# Task: fix four real bugs the polish audit found (for v0.2.9)

The systems polish audit, `C:/Users/leeba/.cache/kstyleui-evidence/polish-audit/D-fable.md`, found defects on current staging. They're bugs, not polish, so they ship in v0.2.9. Read that report's findings 1-3 and 5, with their renders.

**Fix**, each with a failing-then-passing regression or strict render:
1. **Welcome page fold:** the first-run welcome page cuts its key sentence at the fold, in English and German (`Core/Setup/Window.lua:389`). The full text must fit at all four screen sizes in every shipped language.
2. **French Options footer:** the French settings window fails the strict guard because the footer button covers a help line (`KstyleUI_Options/Window.lua:323-330`). Nothing may overlap in any shipped language.
3. **Data bar clamp:** the top data bar clamps text to about 8 units at 1080p (`KstyleUI_DataBars/Settings.lua:71`, `Strip.lua:686`). Readouts must be legible at 1920x1080, keeping the 14-unit bar.
4. **Colour-vision health fill:** colour-vision modes leave the health fill the same red (`Core/ColorVision.lua:48-52`, `Core/Theme.lua:381-394`). The health fill must follow the chosen colour-vision palette. Default "off" stays pixel-identical.

**Evidence**: strict renders at 1920x1080, 2560x1440, 5120x1440 and 3840x2160 (English, German and French where text is involved) over a real game backdrop. Default views not touched by a fix must show zero pixel difference. Evidence goes to `C:/Users/leeba/.cache/kstyleui-evidence/audit-bugs/`.

**PR**: open a PR (not a draft) against `staging` titled `fix(ui): welcome text, French Options footer, readable data bar and colour-vision health`, with:
- `## Changelog` (`Fixed:` lines in player words);
- `## In-game checks` and `## Before and after`.

Do not merge.

**Files it may edit**: the files named above, `Core/Locales/**`, `Tools/locale/*.json`, `Tools/regression/**`, `Tools/render/**`.

**Constraints**: minimal code; CRLF/ASCII. Beast speed rule.

**Gate**: lint, python, the touched modules' tests and `test-perf-path-budgets` under PUC Lua 5.1, then hosted CI.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL and run id.
