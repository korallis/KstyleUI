# Verify: #423 vehicle leave button placement at a743039d

Work only in your own worktree (your starting directory); never cd into or change `C:\Projects\KstyleUI` or any other worktree. Fetch and check out `a743039dec24c8c16658b7e6227dcb2116b028bc` (draft PR https://github.com/korallis/KstyleUI/pull/423). Base is `f6144445fcd16f9e922607e5ed7cc4c65e737414`. Edit nothing, push nothing, comment nothing.

**Spec**: `C:\Projects\KstyleUI\specs\ui-vehicle-leave.md`. Author evidence and renders: `C:/Users/leeba/.capy/drive/captain-kstyle-project-lead/renders/vehicle/evidence.txt` and the PNGs beside it. The PR's Decisions: Medallions below the left slab's outermost slot clearing the XP strip; Frames beyond the stance bar while forms exist; Orbs beyond the power orb rim (Layouts.OrbsTray geometry); the button parents to the root, copies bar 1's layout scale, refreshes on bar layout and form changes, and queues protected changes in combat.

**Allowed files**: `KstyleUI_ActionBars/**`, `Core/Setup/Layouts.lua` (no new top-level locals), `Tools/regression/**` (tests for this), `Tools/render/scenes/**`, `docs/feature-map.md`.

**Gate**: `bash scripts/gate.sh` (the `lua` group runs natively; Windows wall-clock overruns and four known files are PR 7's). Windows bar: `gate.sh lint` exit 0 plus the new and touched tests under `lua5.1`. Toolchain: prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`; `verify/SKILL.md` documents rendering.

**Checks**:
- Render yourself the warlock in a vehicle in Frames, Orbs and Medallions at 5120x1440, 3456x2234 (0.8158) and 1920x1080 with `--strict`, plus a class with stance forms in Frames; open each and confirm the button is clear of the hub, action buttons, pet/stance slabs, unit cluster, XP strip and orb, and fully on screen.
- Secure-frame safety (Forever): the leave button is protected; prove from the code and a combat-lockdown test that no SetPoint/SetParent/SetScale/Show/Hide on it runs in combat (queued until PLAYER_REGEN_ENABLED), that it is never anchored to a region (`K.Widgets.Cover` rules), and that `CanExitVehicle`/`UnitHasVehicleUI` and every event used exist in the Forever UI source (grep the `forever` branch of Gethe/wow-ui-source at `9dc84f0`; clone to `C:\Users\leeba\.cache\wow-ui-source` if missing).
- Event registration follows `Core/Events.lua` (one handler per owner and event; `event_guard.lua` passes).
- The new test fails at base and passes at the SHA (paste both); apply `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\principle-test-behavior-not-implementation\SKILL.md`; one-row and hub tests still pass.
- CI run 43945628883 green for the SHA; `git diff --stat` within the allowed files; suppressions grep; comments via `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` REPORT ONLY; blast radius via `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\blast-radius\SKILL.md` steps 1-5.

**Report**: start with "verified a743039d"; PASS / ISSUES / BLOCKED; prove every issue with a command and its output; end with an Attention list or "No flags".

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
