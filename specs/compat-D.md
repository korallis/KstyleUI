# Task: compatibility batch D: CVars come back

**Goal**: the owner rule is that KstyleUI must not conflict with other addons. Implement batch D of the compatibility audit at `C:/Users/leeba/.cache/kstyleui-evidence/compat-audit/report.md`. Read the report's finding rows and guard rows for this batch first.

**Scope**: Finding 7 and guard G4: KstyleUI_Nameplates/CVars.lua:12,53-66,87-93 restores game defaults instead of the player's values, and the applied list is session-only. Setup writes nameplateShowSelf=0 (Core/Setup/Setup.lua:322-328) with no memory. Keep { original, written } per CVar in the account store the way Stacking.lua does, and add these to Core/CVars.lua MEMORIES. New test-cvar-roundtrip.lua covering every module that writes CVars (Chat, CombatText, Meters, Nameplates, QoL): turn on, set up, turn off, reload, and every CVar is back to the player's value.

**Tests**: the guard named above. Its failure message names the fix, and it fails on the real current code before your fix. Add the batch's own behaviour tests.

**Constraints**: minimal code; AGENTS.md rules (CRLF/ASCII, one event handler per owner, Forever API cited). Evidence never committed (`C:/Users/leeba/.cache/kstyleui-evidence/compat-D/`). Open a **draft** PR against `staging` titled `fix(compat): CVars come back`, with `## Changelog` (`Fixed: ...` in player words), `## In-game checks` and `## Before and after` where visual. Do not merge.

**Gate**: lint, python and the touched modules' tests locally; green CI is the full proof.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, base SHA, PR URL and run id.
