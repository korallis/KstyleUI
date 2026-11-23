# Task: follow-up batch G: percentages round like Blizzard, and paragon reputation

**Goal**: two owner decisions from the accuracy audit (`C:/Users/leeba/.cache/kstyleui-accuracy-audit*` or the accuracy notes in `specs/QUEUE.md`). Owner rule: trust in numbers, so show exactly what the game shows.
1. **Whole-percent rounding matches Blizzard** in every module that shows a percentage: health, power, XP, rested, reputation, threat and any other. Find how Blizzard's own UI rounds each one in the Forever UI source (`C:/Users/leeba/.cache/wt-ui-source` or `C:/Users/leeba/.cache/wow-ui-source`, `forever` at `9dc84f0`; cite file:line). The audit says it rounds up, for example 114.6% shows as 115%. Use one shared helper in `Core` (or the existing short-number or format module) instead of copies. Secret values are never compared or computed: hand them to the engine path exactly as today.
2. **Paragon reputation:** when a watched faction is at Exalted with paragon (`C_Reputation.IsFactionParagon` / `GetFactionParagonInfo`; prove they exist on Forever, else skip with a note), the reputation bar and its text show paragon progress the way Blizzard's reputation UI does (cite it), with a reward-ready indicator if Blizzard shows one.

Cooldown numbers stay hidden when "Readable countdowns" is off (owner decision): change nothing there.

**Rules**: minimal code; one helper. Every changed number has a test against Blizzard's formula at boundary values (x.4, x.5, x.6, 99.6, 100). Renders of the XP and reputation bars before and after, at 1920x1080.

**Constraints**: CRLF/ASCII; locales synced. Evidence never committed (`C:/Users/leeba/.cache/kstyleui-evidence/fu-G/`). Open a PR (not a draft) against `staging` titled `fix(accuracy): percentages round like Blizzard, and paragon reputation` with `## Changelog` (`Fixed: Percentages round the same way the game does.` and `Added: Paragon reputation progress on the reputation bar.`), `## In-game checks` and `## Before and after`. Do not merge.

**Files it may edit**: `Core/**` (the helper), the modules that show percentages, `KstyleUI_DataBars/**`, `Core/Locales/**`, `Tools/locale/*.json`, `Tools/regression/**`, `Tools/render/**`.

**Gate**: lint, python and the touched tests under PUC Lua 5.1; hosted CI. Send worker_done with the run id once it's green.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and render paths.
