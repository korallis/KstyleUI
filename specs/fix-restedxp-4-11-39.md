# Task (hotfix): the RestedXP skin doesn't apply to RestedXP v4.11.39

The review of PR #773 found that the RestedXP installed on this machine (`C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/RXPGuides`, v4.11.39) fails the KstyleUI RestedXP skin's entry check, so none of the RestedXP skin runs for players on that version (guide card, arrow, configurator, docked boxes). This predates #773 and affects released builds. Report: `C:/Users/leeba/.cache/kstyleui-evidence/verify-773-0ddd2d2e/REPORT.md` (finding 1 and its probe commands).

Read the installed RestedXP's code (read-only; it's third-party, never copy its code into KstyleUI) to establish the API and frames v4.11.39 exposes, then make the skin's entry check and hooks work with it while still working with the older versions the skin supported (keep their test fixtures passing). Guard every lookup; if a version exposes nothing we can skin safely, skip cleanly with no error. Never fight RestedXP: hook once, no per-frame work, no repeated re-skinning (`test-perf-fights` with no new ceiling).

Add a fixture for v4.11.39's shape to the regression stubs, with a test that fails on staging today. Evidence: renders of the guide card, arrow and boxes with the v4.11.39 fixture at 1920x1080 and 5120x1440 in both styles, in `C:/Users/leeba/.cache/kstyleui-evidence/fix-restedxp-41139/`. List the in-game checks (the owner runs RestedXP).

**Files it may edit**: the RestedXP skin files in `KstyleUI_Skins/**`, `Core/Setup/Integrations.lua` (detection only), `Tools/regression/**`, `Tools/render/**`, `docs/feature-map.md`. PR #773 also edits the RestedXP skin: rebase onto it if it merges first.

**PR**: `fix(skins): RestedXP skin works with RestedXP 4.11.39` with a `## Changelog` `Fixed:` line and `## In-game checks`. Do not merge.

**Constraints**: minimal code; CRLF/ASCII; Beast speed rule (module tests locally, hosted CI as proof).

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and what changed in RestedXP.
