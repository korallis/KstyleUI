# Task: the RestedXP guide window flickers a lot (v0.2.6)

**Goal**: the owner reports the skinned RestedXP guide window "is flickering A LOT" in v0.2.6 (Forever, 5120x1440, Medallions; screenshot of the window at rest: `C:\Users\leeba\.cache\lee-shots\minimap-2026-11-19.png`, top right, the "6-12 TIRISFAL GLADES / Step 95" card). Find the cause and stop the flicker without changing how the window looks when still. High priority: this ships as a quick fix release.

**Target**: KstyleUI at tag `v0.2.6` and latest `origin/staging`: `KstyleUI_Skins/Addons/RestedXP/{Skin,Chrome,Rail,Theme}.lua`, `Core/Skin.lua`. v0.2.6 changed these through #458 (rails), #473 (texture alpha one value), #469 (type), #481 (snap hard edges) and #476 (motion tokens, Skin.OpenMotion fade gate). Candidates: a restyle or snap on every RestedXP update or OnUpdate (RestedXP refreshes its step frame often), a hide/show or fade replay each refresh (OpenMotion), an alpha fight between our hush/SetAlpha hooks and RestedXP's own SetAlpha/SetVertexColor (last write wins in the client), or edge snapping re-anchoring on each size change. Compare v0.2.5 and v0.2.6 behaviour.

**Change**:
1. Reproduce in the stubs: drive the RestedXP frame the way the addon does (frequent step/text refreshes, size changes, its own alpha calls) and count, per refresh, our restyles, fades, Show/Hide, SetAlpha and anchor changes on the window and its regions. A flicker is any visible region whose alpha or shown state changes during a refresh that does not change content, or a fade that replays.
2. Fix the cause so a refresh that changes nothing visible makes no visible change (and does no repeated restyle work), and a real content change updates in place without a fade or blink. Smallest change.
3. Add a regression test with those counts (red on v0.2.6, green after) and before/after evidence.

**Options**: a fix; no new setting.

**Constraints**: minimal code; pixel-identical at rest (zero-diff renders of the RestedXP skins scene at 1920x1080 and 3456x2234 over a real backdrop); AGENTS.md rules; believe the client over the harness for alpha (texture alpha is one value, last write wins). Open a **draft** PR against `staging`: title `fix(skins): RestedXP guide window stops flickering`, `## Summary` (the cause), `## Changelog` (`Fixed: The RestedXP guide window no longer flickers.`), `## In-game checks`.

**Files it may edit**: `KstyleUI_Skins/**`, `Core/Skin.lua`, `Tools/regression/**`, `Tools/render/**`.

**Gate**: lint, python and the Skins tests locally; green Mac CI is the full proof.

**Evidence of done**: the cause with file:line; the counts before and after; the test red then green; zero-diff renders; the draft PR's green `checks` run.

**Before worker_done**: follow `C:\Users\leeba\orca-jev-router\WORKER.md`. Report SHA, base SHA, PR URL, run id.
