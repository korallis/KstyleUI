# Task: compatibility batch B: same-job modules step aside

**Goal**: the owner rule is that KstyleUI must not conflict with other addons. Implement batch B of the compatibility audit at `C:/Users/leeba/.cache/kstyleui-evidence/compat-audit/report.md`. Read the report's finding rows and guard rows for this batch first.

**Scope**: Findings 1 and 5 and guard G5: in Core/Setup/Setup.lua NewChoice, start a module off when Integrations.Detected(name) is not empty. Add the missing OVERLAPS entries (ActionBars and DataBars menus: Bartender4, Dominos; Meters damage window: Details, keeping threat and swing; Bags: Baganator; Chat: Chattynator). ActionBars leaves its override bindings off while Bartender4 or Dominos is loaded unless the player turned the module on themselves, and posts one notice line. Leatrix Plus per-feature and BetterFriendlist are NOT in this batch.

**Tests**: the guard named above. Its failure message names the fix, and it fails on the real current code before your fix. Add the batch's own behaviour tests.

**Constraints**: minimal code; AGENTS.md rules (CRLF/ASCII, one event handler per owner, Forever API cited). Evidence never committed (`C:/Users/leeba/.cache/kstyleui-evidence/compat-B/`). Open a **draft** PR against `staging` titled `fix(compat): same-job modules step aside`, with `## Changelog` (`Fixed: ...` in player words), `## In-game checks` and `## Before and after` where visual. Do not merge.

**Gate**: lint, python and the touched modules' tests locally; green CI is the full proof.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, base SHA, PR URL and run id.
