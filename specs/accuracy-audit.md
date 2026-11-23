# Task: accuracy audit: every number and timer KstyleUI shows must match the game

**Goal**: a tester (0xDAB, 2026-11-19, after v0.2.6): "The most important thing is the source of truth: I'm having a hard time trusting the info, like the swing timer." Players must be able to trust every value KstyleUI shows. Find every place where what we show can differ from what the game knows, then fix it.

**Target**: KstyleUI on latest `origin/staging`; the Forever UI source (`C:/Users/leeba/.cache/wow-ui-source`, `forever` branch at `9dc84f0`, including `Blizzard_APIDocumentationGenerated/` with its SecretReturns flags) for what the client really provides.

**Change**:
1. For each value, write down its source in our code (file:line) and the game's source of truth (API or event, proving file), and list where they can disagree, with a concrete scenario:
   - swing timer (`KstyleUI_Meters/Swing.lua`)
   - cast and channel bars
   - cooldown sweeps and numbers
   - aura timers and stacks
   - health and power numbers and percents
   - threat
   - damage and healing meter
   - range fading
   - XP, rest and reputation
   - durations rounding

   **Swing timer first and in depth**:
   - main hand, off hand and ranged, from the combat log or UnitAttackSpeed;
   - haste changes mid-swing;
   - parry haste;
   - swing resets from abilities (on-next-swing spells like Heroic Strike, Raptor Strike, Slam);
   - misses, dodges and parries;
   - wand and auto shot;
   - leaving combat and dead targets;
   - druid form changes;
   - lag compensation.

   Prove each problem in the stubs by firing the client's real event sequence. Report expected against shown.
2. Fix every proven discrepancy with the smallest change and a regression test per scenario (red before, green after). Group the fixes into one PR per module if more than one module changes (swing timer first). Values must never be invented or estimated where the game provides the truth. Where the game hides a value (secret values), show the game's own display, or nothing, rather than a guess.
3. List what cannot be proven in the harness as in-game checks.

**Options**: fixes need no setting; if a fix changes what a player sees (for example a swing timer that now resets on Slam), say so in the Changelog.

**Constraints**: minimal code; AGENTS.md rules (secret values, `issecretvalue` before comparisons, combat lockdown, Forever API grep naming the file). Open **draft** PRs against `staging`: `fix(<module>): <value> matches the game`, with `## Summary` (each discrepancy and cause), `## Changelog` (`Fixed: ...` in player words), `## In-game checks`. Do not merge.

**Files it may edit**: `KstyleUI_Meters/**`, `Core/Widgets/CastBar.lua`, `Core/Widgets/Duration.lua`, `KstyleUI_UnitFrames/**` (value code only), `KstyleUI_Cooldowns/**` (value code only), `KstyleUI_Auras/**` (value code only), `KstyleUI_DataBars/**`, `Tools/regression/**`.

**Gate**: lint, python and the touched modules' tests locally; green Mac CI is the full proof.

**Evidence of done**: the audit table at `%TEMP%/orca-<dispatch>/accuracy-audit.md` (value, our source, game source, discrepancies, status); the PR URLs with green checks; the in-game check list.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`.

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
**Local checks (speed rule, coordinator decision)**: do NOT run the full native Lua suite on Beast (no `bash scripts/gate.sh` or `gate.sh lua`); it starves the shared machine and CI runs the full suite in about 5 minutes. Before pushing run `bash scripts/gate.sh lint`, `bash scripts/gate.sh python`, and with PUC `lua5.1` directly the test files for the modules you changed plus `test-comments.lua` and `test-syntax.lua`; green Mac CI (`checks`) is the full proof. Render at most 2 pictures at a time, and only at the screen sizes your items need.

**Screen sizes (owner rule)**: tests and before/after renders for anything placed on screen cover 1920x1080, 2560x1440, 5120x1440 (ultrawide) and 3840x2160 (4K).

**One consistent style (owner rule)**: KstyleUI is "your whole interface, forged as one piece". Anything you add or change must match its siblings exactly (same frame, header, fonts, sizes, spacing, row and bar style), preferably through the same shared builder. Reviewers flag any visual inconsistency as an issue.
