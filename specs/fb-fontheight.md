# Task: fix "Invalid font height (0)" from the group-frames preview (GitHub #444)

**Goal**: opening the Options window never raises `FontString:SetFont(): Invalid font height`, and no font string anywhere is ever given a zero, negative, NaN or secret height.

**Target**: KstyleUI on the latest `origin/staging`. Player report (GitHub issue #443/#444, BugGrabber):
```
Message: FontString:SetFont(): Invalid font height (0.000000): height must be > 0
[KstyleUI/Core/Widgets/Base.lua]:553: in function 'ApplyFont'
[KstyleUI_GroupFrames/Style.lua]:136 <- Style.lua:303 <- Style.lua:522 <- GroupFrames/Medallions.lua:138 'Apply'
<- GroupFrames/Preview.lua:211 <- Preview.lua:246 <- [C] GetLeft <- Base.lua:74 'Edges' <- Base.lua:1757 <- Base.lua:1774 'MeasureHeader'
<- Base.lua:1838 'CardHeader' ... <- Options/Preview.lua:532 'Layout' <- Options/Preview.lua:529 'SetRoom' <- Options/Window.lua:265 ...
Locals: path=".../AlegreyaSansTabular-ExtraBold.ttf" size=11 flags="" f=0.006993
```
So a group-frames preview is laid out while its scale factor `f` is about 0.007 (the preview or its parent has a near-zero size during the Options layout, reached re-entrantly through a `GetLeft` measurement), and `size * f` rounds to 0.

**Change**: find and fix the root cause (why the group preview applies its style with a near-zero factor, and the re-entrant layout through `GetLeft`): e.g. skip or defer the preview's Apply until it has a real size, and compute the factor only from sane values. Also make `Widgets.ApplyFont` refuse to pass the client a height that is not a finite number > 0 (clamp to a floor of 1 or keep the previous font), so no future caller can raise this error. Tests: reproduce the reported stack in the stubs (the stub should raise the client's error for a 0 height if it does not already; check `test-stub-refusals.lua`) and show it red on staging, green after; a guard test that `ApplyFont` never forwards a non-positive height.

**Playbook**: bug -> Read and follow `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\poteto-mode\playbooks\bug-fix.md`, intro + steps 1, 2, 4, 5 only. Skip any delegation/subagents, model names, /loop, Bugbot, cloud agents, PR steps, and references to skills or sections not given as a path.

**Constraints**: AGENTS.md rules (CRLF/ASCII addon files, one comment per file, Forever API grep, secret values). Do not edit `KstyleUI_ActionBars/` (another task). Windows machine (Beast): prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. Open a **draft** PR against `staging`: title `fix(groupframes): never give a font a zero height in the Options preview`, body with `## Summary` (reference #444), `## Changelog` (`Fixed: ...`), `## In-game checks`. Do not merge.

**Files it may edit**: `Core/Widgets/Base.lua`, `KstyleUI_GroupFrames/**`, `KstyleUI_Options/**`, `Tools/regression/**`.

**Gate**: `bash scripts/gate.sh` (natively green on Windows; Known failing: none).

**Evidence of done**: the reproducing test red on staging and green after; `gallery_options --strict` render in all three HUD styles still passes; the draft PR's green `checks` run.

**Before worker_done**: follow `C:\Users\leeba\orca-jev-router\WORKER.md`. Report SHA, base SHA, PR URL, run id, Gate output and evidence.
