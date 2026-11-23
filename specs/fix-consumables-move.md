# Task: the consumables bar snaps back when moved in Layout Mode

**Bug (reported by a player on v0.2.8)**: when they move the consumables bar it snaps back and doesn't move.

**Cause**:
- `defaults.consumables.attached = true` ("Attach to the player frame");
- `C.Dock()` (`KstyleUI_ActionBars/Consumables.lua:47-62`) re-anchors the holder to the player frame on every Apply while `attached` is on, so the Layout Mode position is overwritten.

Confirm this on `origin/staging` with a failing regression first: move the bar through the Layout Mode path (the same calls a drag makes), apply, and assert it stays where it was put.

**Fix** (minimal):
- Moving the bar yourself means you want it there:
  - when the player drags or nudges the bar in Layout Mode, or sets its position numerically, turn `attached` off and keep the new position;
  - the Options toggle then shows it off;
  - turning "Attach to the player frame" back on re-docks it beside the player frame.
- Check whether KstyleUI's shared attach feature from #524 ("attach an element to another") already covers this. If replacing the bar's own `attached` with the shared attach is smaller and keeps today's default look, do that instead, and say which you chose.
- Existing players keep the default docked look until they move the bar.
- **Other elements:** check every other element that re-anchors itself in Apply despite its Layout position (grep for similar "attached" or dock patterns), and fix the same bug there if it exists, listing them.

**Tests**:
- the failing-then-passing move regression;
- toggling Attach back on re-docks the bar;
- the default is unchanged;
- protected moves stay queued in combat;
- `test-perf-path-budgets` passes.

**Renders**: Layout Mode before and after a move at 1920x1080 and 5120x1440, over real game backdrops. Evidence goes to `C:/Users/leeba/.cache/kstyleui-evidence/consumables-move/`.

**PR**: open a PR (not a draft) against `staging` titled `fix(actionbars): the consumables bar stays where you move it`, with:
- `## Changelog`: `Fixed: The consumables bar stays where you move it; moving it turns off Attach to the player frame.`
- `## In-game checks`.

Do not merge.

**Files it may edit**: `KstyleUI_ActionBars/**`, `Core/Layout/**` (only if the shared attach is used), `Core/Locales/**`, `Tools/locale/*.json`, `Tools/regression/**`.

**Constraints**: CRLF/ASCII. Beast speed rule. Other parity PRs touch other modules; rebase before opening.

**Gate**: lint, python, the consumables, actionbars and layout tests and `test-perf-path-budgets` under PUC Lua 5.1, then hosted CI.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL and run id.
