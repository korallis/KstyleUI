# Task (hotfix): the setup window's Welcome page is blank in game on v0.3.1

The owner ran `/kstyle setup` on v0.3.1 from CurseForge (2026-11-23). The setup window opens with its title, the step tabs (Welcome, HUD style, Layout, Modules, Your addons, Summary), Keep my UI and Next, but the Welcome page body is completely empty: no title, logo, note or steps, just the dark panel with the world faintly showing through. Screenshot: `C:/Users/leeba/.cache/kstyleui-evidence/setup-ingame-full.jpg` (5120x1440), crop `setup-ingame-window.png` in the same folder. The render harness shows the page, so this is a harness-vs-client gap; believe the game.

Prime suspects, from v0.3.0 (all merged after v0.2.15):
- #741 "page changes fade with the shared page timing" and Motion.Moment: a page fade-in (alpha animation or C_Timer) that never completes or never starts in the client leaves the page at alpha 0. Render scenes never flush C_Timer, so the harness wouldn't see it.
- #739 big pictures and Looks on setup steps (hidden steps load no picture; Welcome branded/classic switch `general.brandedWelcome`, `Core/Setup/Window.lua` `BuildWelcome`, lines ~300-450).
- A Lua error while building the page (ask: the owner can run `/console scriptErrors 1`; check BugSack-style paths in code for anything that could throw on the client but not the stubs).

Find the cause, check every setup page (not just Welcome) and the Options window's page changes (#741 touched both), and fix it. Make the stubs model the client behaviour so a regression test fails on today's code (for example run the motion/timer path the client runs). Evidence: renders of every setup step at 1920x1080 and 5120x1440 after the fix, with timers flushed, in `C:/Users/leeba/.cache/kstyleui-evidence/hotfix-setup-blank/`.

**Files it may edit**: `Core/Setup/**` (no new top-level locals in `Layouts.lua`), `Core/Motion.lua`, `KstyleUI_Options/Window.lua`, `Core/Widgets/Panel.lua`, `Tools/regression/**` (stubs included), `Tools/render/**`.

**PR**: `fix(setup): the Welcome page shows in game again` with a `## Changelog` `Fixed:` line and `## In-game checks`. Do not merge. This ships as a hotfix as soon as it is green, so keep it small.

**Constraints**: minimal code; CRLF/ASCII; Beast speed rule (module tests locally, hosted CI as proof).

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and the cause.
