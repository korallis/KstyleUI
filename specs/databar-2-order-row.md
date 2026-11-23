# Task: data bar batch 2: an ordered module list row in Options

**Goal**: build batch 2 of the approved XIV-style data bar (`C:/Users/leeba/.cache/kstyleui-evidence/xiv-databar/design.md`, section 5 and PR 2; mockups `mockup_options_window.png` and `mockup_options_1080.png`). It adds one new generic Options schema row type, `order`. Its value is an ordered list of ids plus each id's `shown` flag and `zone` (Left / Centre / Right).

**How it looks and works**:
- `KstyleUI_Options/Model.lua` expands an `order` row into one item per entry, so the virtualised 48-unit rows and search keep working.
- Each entry row has a toggle, a zone dropdown and up/down arrows, built from the existing Options controls in the same style.
- An entry that is switched on shows its own child rows under it through `showWhen`.
- Arrows only; drag reordering is a later follow-up.

**Scope**: only the generic row type and its tests, in `Core/Options.lua`, `KstyleUI_Options/Model.lua`, `KstyleUI_Options/Rows.lua` and Options' own tests. Wire it to the data bar only if batch 1 (`feat(databars): the data strip grows into a top bar`) has already merged when you finish. If it hasn't, add a small Options render scene or test fixture that shows the row with sample modules, and say so in the PR.

**Tests**:
- the order and zone values persist;
- up and down at the list ends are no-ops;
- search finds entries;
- `showWhen` children show and hide;
- the virtualised list still recycles rows.

Renders of the Options window with the list at 1920x1080 and 3840x2160.

**Constraints**: minimal code; AGENTS.md rules (`K.Widgets.FontString`, CRLF/ASCII); evidence never committed (`C:/Users/leeba/.cache/kstyleui-evidence/databar-2/`). Open a **draft** PR against `staging` titled `feat(options): an ordered list row with zones` with the `no changelog` label if nothing player-facing changes yet, otherwise a `## Changelog` line. Include `## In-game checks` and `## Before and after`. Do not merge.

**Files it may edit**: `Core/Options.lua`, `KstyleUI_Options/**`, `Core/Locales/**`, `Tools/locale/*.json`, `Tools/regression/**`, `Tools/render/**`.

**Gate**: lint, python and the touched modules' tests locally; green Mac CI is the full proof.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, base SHA, PR URL, run id and render paths.
