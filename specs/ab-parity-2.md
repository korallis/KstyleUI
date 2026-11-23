# Task: action bar EllesmereUI parity, batch 2: visibility builder, toggle key, click-through, reverse order

The owner wants action bar customisation that rivals EllesmereUI. Read the parity audit in `KstyleUI_ActionBars/README.md`, "EllesmereUI parity audit (2026-11-20)", on `origin/staging`. Build these **Missing** rows (public behaviour only; copy no code):

1. **Visibility condition builder:**
   - per bar, a simple builder of ticked conditions that writes the existing Custom visibility macro string, so there is no second system. The conditions:
     - in combat or out of combat;
     - has target;
     - mounted;
     - in group or raid;
     - resting;
     - in instance or in city, if a secure macro condition exists on Forever (prove it in `C:/Users/leeba/.cache/wow-ui-source` at `9dc84f0`);
     - modifier keys;
   - it has show and hide modes; the text field stays for advanced users.
2. **Runtime visibility toggle key:**
   - a key binding per bar ("Toggle Action Bar N"), shown in Blizzard's Key Bindings under KstyleUI;
   - it securely shows or hides the bar through the existing state driver or a secure handler, and works in combat;
   - the toggled state persists per character.
3. **Click-through:**
   - per bar, the buttons ignore the mouse (to click the world through them) while keybinds still work;
   - hover, flyouts and Layout Mode must keep working when it's off;
   - when it's on, Layout Mode still lets you move the bar;
   - default off.
4. **Reverse button order:** per bar, so slot 1 starts at the other end. Check it against paging, keybinds (slot N stays bound to button N) and the Medallions slab (hide it where the slab fixes the order, with the slab note). Default off.

**Rules**:
- Everything per bar, in the existing schema; minimal code; one consistent style.
- New options keep today's behaviour by default.
- Secure-safe: no taint, and protected changes are queued in combat. Prove every macro condition and binding API on Forever.
- No per-frame work; stay within the reload budget.

**Tests**:
- the builder produces the expected macro strings and round-trips them;
- the toggle binding works in and out of combat in the stubs;
- click-through keeps keybind clicks and disables mouse hit;
- reverse order keeps the bindings on the same actions;
- `test-taint-scan` and `test-perf-path-budgets` pass.

**Renders**: the Options page with the builder at 1920x1080 and 5120x1440, plus a reversed bar. Use `--strict` and real game backdrops. Evidence goes to `C:/Users/leeba/.cache/kstyleui-evidence/ab-parity-2/`, never committed.

**PR**: open a PR (not a draft) against `staging` titled `feat(actionbars): visibility builder, toggle keys, click-through and reverse order`. Include:
- `## Changelog`, with `Added:` lines;
- `## Options`, `## In-game checks` and `## Forever API`;
- an update to the README parity table.

Do not merge.

**Files it may edit**: `KstyleUI_ActionBars/**`, `KstyleUI_Options/**`, `Bindings.xml` or the module's bindings file (and `.luacheckrc` for `BINDING_*` names on the module's own line), `Core/Locales/**`, `Tools/locale/*.json`, `Tools/regression/**`, `Tools/render/**`, `docs/feature-map.md`.

**Constraints**: CRLF/ASCII; locales synced with translations. Beast speed rule: no full local Lua suite, at most 2 renders at a time. A batch 1 PR (text placement and cooldown look) is in flight on the same files: keep your code in separate functions where you can, and rebase onto `origin/staging` before opening.

**Gate**: lint, python, the actionbars, options and taint tests and `test-perf-path-budgets` under PUC Lua 5.1, then hosted CI.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and render paths.
