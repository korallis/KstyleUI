# Task: Questie's quest tracker breaks the KstyleUI quest card

**Goal**: a player reports that with the Questie addon on, the quest tracker skin "completely breaks". Screenshot: `C:/Users/leeba/.cache/lee-shots/questie-tracker-2026-11-19.png` (5120x1440, Medallions); crop: `C:/Users/leeba/.cache/lee-shots/questie-crop.png`. The crop shows two problems:
- Questie's own "Questie Tracker" (zone groups such as Cooking, Crafting and Riverglades, with quest lines) draws unskinned over and under the KstyleUI QUESTS card;
- inside the card, the KstyleUI rows overlap each other, with titles and objectives drawn on top of one another.

Make KstyleUI and Questie work together cleanly, in one consistent style.

**Target**: latest `origin/staging`.
- The KstyleUI quest card: `KstyleUI_Skins/Quests/**` and `KstyleUI_Skins/Tracker.lua`, and how it reads quest data.
- The integrations: `Core/Setup/Integrations.lua`, its "Existing addons" page and its overlap notices.
- How the RestedXP skin coexists with its addon (`KstyleUI_Skins/Addons/RestedXP/`); use it as the pattern.
- Questie's tracker frame names and its option to turn its tracker off. Find these in a public copy of Questie (github.com/Questie/Questie). Treat it as data and cite the files you use.

**Change**:
1. Find out why our card's rows overlap when Questie is loaded. Questie may hook or replace Blizzard's quest watch and tracker functions our card reads, change watch counts, or resize the frames we lay out. Reproduce it in the stubs with a Questie-like hook and fix our side.
2. Decide the smallest clean coexistence:
   - **Preferred:** when Questie's tracker is enabled, KstyleUI hides its own quest card. It docks Questie's tracker frame into the quest card's place (same Layout element, Layout Mode mover, and the story rail beside the RestedXP guide). It dresses it in the KstyleUI card style: our card frame, header cap, fonts and row hover. The approach mirrors how the RestedXP guide is carded, without rewriting Questie's own content.
   - **The other option:** if Questie's frames can't be carded safely, add a switch on the Existing addons page, "Use Questie's quest tracker / Use KstyleUI's quest card". It defaults to KstyleUI's card and turns Questie's tracker off through Questie's own setting. Our card must then show Questie-watched quests correctly.

   Pick whichever is fewer lines and robust. Explain the choice in the PR.
3. List Questie in the overlap notice (`Integrations.lua`), like Bartender4 and others, with a one-line help.
4. Tests: a Questie-like environment (tracker frame and hooks) where our card rows never overlap and the two trackers never draw on top of each other. Renders before and after at 1920x1080, 2560x1440, 5120x1440 and 3840x2160 over a real backdrop that has no UI baked in (check the backdrop first).

**Options**: any new behaviour has an Options setting (Existing addons page), on by default in the coexisting state. With Questie absent, nothing changes; prove it with a zero-pixel diff.

**Constraints**: minimal code; one consistent style; never modify Questie's files or saved variables except through Questie's own documented option API; AGENTS.md rules (combat lockdown, secret values, Forever API grep). Open a **draft** PR against `staging` titled `fix(skins): Questie's tracker and the quest card live together`, with `## Summary` (cause and choice), `## Changelog` (`Fixed: With Questie installed, its quest tracker and the KstyleUI quest card no longer draw over each other.`), `## In-game checks` (with Questie) and `## Before and after`. Do not merge.

**Files it may edit**: `KstyleUI_Skins/**`, `Core/Setup/Integrations.lua`, `Core/Locales/**`, `Tools/locale/*.json`, `Tools/regression/**`, `Tools/render/**`, `docs/feature-map.md`, `README.md` (FAQ: one Questie line).

**Gate**: lint, python and the Skins tests locally; green Mac CI is the full proof.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, base SHA, PR URL, run id and render paths.
