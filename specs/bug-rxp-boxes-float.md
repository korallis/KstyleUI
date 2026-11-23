# Task: RestedXP's Active Targets and Active Items boxes float mid-screen instead of docking

**Goal**: a player on 5120x1440 (GitHub #484, photo `C:/Users/leeba/.cache/gh484/shot.png`) has RestedXP's Active Items box (Healthstones and other items) floating near the middle of the screen. Our own 5120x1440 renders show the same thing: `C:/Users/leeba/.cache/gh484/centred-5120.jpg` and `spread-5120.jpg` draw the ACTIVE TARGETS and ACTIVE ITEMS boxes at about x=1690-1820, y=820-950 (screen pixels), beside the nameplates, while the guide card sits top right. `KstyleUI_Skins/Addons/RestedXP/Rail.lua` (header comment) says these boxes dock under the guide's card until the player drags one away. Make them dock under the guide card in every HUD style, arrangement and screen size, unless the player has dragged one.

**Target**: latest `origin/staging`: `KstyleUI_Skins/Addons/RestedXP/{Rail,Chrome,Skin}.lua`, the render scene that draws them (`hud_reference` with RestedXP fixtures), and how "dragged by the player" is detected. Possible causes: docking runs only on certain events; the boxes are placed before the guide card has its final place; the dragged check is wrong; or the render fixture differs from the game. Find which, and prove it against the RestedXP source behaviour our stubs model.

**Change**: the smallest fix so the boxes dock under the guide card (side by side or stacked, as the header describes) at 1920x1080, 2560x1440, 5120x1440 and 3840x2160, in Centred and Spread and in Frames, Orbs and Medallions. A box the player really dragged stays where they put it. Keep the RestedXP flicker fix (#487) intact: no re-anchoring on every refresh. Add a regression test with box positions relative to the guide card across those sizes, red before and green after, and before/after renders.

**Options**: a fix; no new setting.

**Constraints**: minimal code; one consistent style; AGENTS.md rules. Consistency batch 6 (ctx_5c856ebac08a) edits the Skins card cap and inset, including RestedXP `Chrome.lua`. Keep to docking and rebase before the PR. Open a **draft** PR against `staging` titled `fix(skins): RestedXP item and target boxes dock under the guide`, with `## Summary` (the cause), `## Changelog` (`Fixed: RestedXP's Active Items and Active Targets boxes sit under the guide card instead of floating mid-screen.`), `## In-game checks` and `## Before and after`. Do not merge.

**Files it may edit**: `KstyleUI_Skins/**`, `Tools/regression/**`, `Tools/render/**`.

**Gate**: lint, python and the Skins tests locally. Green Mac CI is the full proof.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, base SHA, PR URL, run id and render paths.
