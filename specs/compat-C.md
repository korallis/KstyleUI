# Task: compatibility batch C: the skin text pass skips other addons' frames

**Goal**: the owner rule is that KstyleUI must not conflict with other addons. Implement batch C of the compatibility audit at `C:/Users/leeba/.cache/kstyleui-evidence/compat-audit/report.md`. Read the report's finding rows and guard rows for this batch first.

**Scope**: Finding 4 and guard G3: in KstyleUI_Skins/Style.lua SweepFrame (Registry.lua:151, Style.lua:408-447,462), skip a child whose GetSourceLocation() does not name a Blizzard_ path. Prove from the Forever source (SimpleScriptRegionAPIDocumentation.lua) what it returns, and treat nil or a missing method as 'skip only when we can tell it is an addon frame', so Blizzard frames are never skipped by mistake. Pixel-identical for Blizzard windows: show before and after renders of the skinned windows in the gallery.

**Tests**: the guard named above. Its failure message names the fix, and it fails on the real current code before your fix. Add the batch's own behaviour tests.

**Constraints**: minimal code; AGENTS.md rules (CRLF/ASCII, one event handler per owner, Forever API cited). Evidence never committed (`C:/Users/leeba/.cache/kstyleui-evidence/compat-C/`). Open a **draft** PR against `staging` titled `fix(compat): the skin text pass skips other addons' frames`, with `## Changelog` (`Fixed: ...` in player words), `## In-game checks` and `## Before and after` where visual. Do not merge.

**Gate**: lint, python and the touched modules' tests locally; green CI is the full proof.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, base SHA, PR URL and run id.
