# Task: the class trainer window's rows and footer overlap

**Goal**: the owner's in-game screenshot of the skinned class trainer (`C:\Users\leeba\.cache\lee-shots\trainer-overlap-2026-11-19.png`, Forever, warlock trainer) shows: (1) a skill's "Requires: ..." line wraps to a second line that spills past the bottom edge of its row card (Demon Skin, Curse of Weakness, Shadow Bolt rows); (2) the list's last row runs under the money line (30 silver / 28) and the Train button at the bottom, which also overlap each other. Make every row hold its text and the list stop above the footer, in the KstyleUI style.

**Target**: KstyleUI on latest `origin/staging`: `KstyleUI_Skins/PartB/Trainer.lua` and the shared skin helpers it uses. Check the Forever UI source (`forever` branch of Gethe/wow-ui-source at `9dc84f0`, clone `C:\Users\leeba\.cache\wow-ui-source`) for the trainer frame's real regions (scroll box, row template, money frame, Train button) and name the proving file.

**Change**: rows grow to fit their wrapped text (or the text is sized and truncated cleanly to the row; prefer fitting two lines), the scroll area ends above the footer, and the money line and Train button sit in the footer without overlapping. Smallest change; no new setting needed (a fix), but if the skin has an off switch, off must still give Blizzard's look. Add a render scene (or extend the existing skins gallery scene) for the trainer with long "Requires" lines and a full list, and a regression test that rows contain their text and the list bottom is above the footer.

**Constraints**: minimal code; AGENTS.md rules (CRLF/ASCII, `K.Widgets.FontString`, one comment per TOC-loaded file, combat lockdown, Forever API grep). Local checks per the speed rule below; renders at 1920x1080 and 3456x2234, at most 2 at a time, over a real backdrop. Open a **draft** PR against `staging`: title `fix(skins): trainer rows hold their text and clear the footer`, `## Summary`, `## Changelog` (`Fixed: The class trainer's skill rows no longer spill over each other or the Train button.`), `## In-game checks`, `## Before and after`.

**Files it may edit**: `KstyleUI_Skins/**`, `Tools/regression/**`, `Tools/render/**`.

**Gate**: lint, python and the Skins tests locally; green Mac CI is the full proof.

**Evidence of done**: before/after renders matching the screenshot's case; the test red before and green after; the draft PR's green `checks` run.

**Before worker_done**: follow `C:\Users\leeba\orca-jev-router\WORKER.md`. Report SHA, base SHA, PR URL, run id and render paths.
