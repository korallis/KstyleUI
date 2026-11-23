# Task: skins on by default, and the setup asks which installed addons to skin

**Goal**: the owner wants two things.
1. **Every skin is ON by default:** Blizzard windows and every supported addon skin (RestedXP, Questie and the others in the Skins registry). Today some skins may default off; find them all in `KstyleUI_Skins/Settings.lua` and the registry.
2. **The first-run setup gets an addons step.** It detects which supported addons are installed and lets the player choose, per addon, whether KstyleUI skins it. The choices are pre-ticked to "Skin it". The step also covers the same-job choices that already exist: quest tracker (KstyleUI card, Questie, or both), action bars against Bartender or Dominos, meters against Details, and so on. That way the player decides everything in one place instead of finding out later.

**Change**:
- **Defaults:** every skin defaults ON. Existing players: don't change a skin they turned off themselves. Anything at its untouched default becomes ON. If a migration is needed, take the next free number.
- **Setup step:** "Your addons". It lists only the supported addons that are installed (`Integrations.Loaded` and the Skins registry), each with:
  - a "Skin it" toggle (ON);
  - for same-job addons, the existing choice, with KstyleUI's recommended default and a one-line explanation.

  If no supported addon is installed, skip the step. Re-running `/kstyle setup` shows it again with the current choices. "Keep my UI" still leaves everything untouched.
- **Detection** uses only `C_AddOns.IsAddOnLoaded` and `GetAddOnInfo` (prove them on Forever, `C:/Users/leeba/.cache/wow-ui-source` at `9dc84f0`); no new globals.
- **Style:** one consistent style. Use the existing setup step chrome, toggles and the live preview where it makes sense.
- **Docs:** update `docs/statecharts/setup.md` (the setup flow changes; AGENTS.md requires it), `docs/feature-map.md` and the Skins README.

**Tests**:
- every skin's default is ON;
- the existing-player migration (an untouched default becomes ON; a player's explicit off is kept);
- the step appears only with detected addons;
- each choice writes the right setting;
- the same-job choices match the Options page;
- re-running setup preserves the choices;
- Keep my UI is untouched;
- `test-perf-path-budgets` passes.

Renders of the new setup step at 1920x1080 and 3840x2160 (with RestedXP, Questie, Details and Bartender detected), over real game backdrops.

**Constraints**: minimal code, reusing the existing setup steps, toggles, the Integrations module and the Skins registry (no new framework). CRLF/ASCII; locales synced with translations. Evidence never committed (`C:/Users/leeba/.cache/kstyleui-evidence/setup-addons/`). Open a PR (not a draft) against `staging` titled `feat(setup): choose which of your addons KstyleUI skins` with:
- `## Changelog`: `Added: The setup now lists the addons you have installed and lets you choose which ones KstyleUI skins. Changed: Every skin is on by default.`
- `## Options`, `## In-game checks` and `## Before and after`.

Do not merge.

**Files it may edit**: `Core/Setup/**`, `KstyleUI_Skins/**`, `Core/Store.lua` (migration only), `KstyleUI_Options/**`, `Core/Locales/**`, `Tools/locale/*.json`, `Tools/regression/**`, `Tools/render/**`, `docs/statecharts/setup.md`, `docs/feature-map.md`, the Skins README.

**Gate**: lint, python and the setup and skins tests under PUC Lua 5.1; hosted CI. Send worker_done with the run id once it's green.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id, render paths and the migration number.
