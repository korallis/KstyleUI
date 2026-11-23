# Verify (round 2): #445 review fixes at 2effdfd9

Work only in your own worktree (your starting directory); never cd into or change `C:\Projects\KstyleUI` or any other worktree. Fetch and check out `2effdfd93456480605e2ea5547348cabfa21a9fb` (draft PR https://github.com/korallis/KstyleUI/pull/445). The previous verified head is `fed610c6af79ac8a458baa06d4a2b44aa5750b3b`; staging base `a0984bb2cb32cd317f2f4ea16a62be1cef73f31b`. Edit nothing, push nothing, comment nothing.

**Inputs**: round-1 verdict `C:\Users\leeba\AppData\Local\Temp\orca-ctx_8f71437c55d8\report.md` (its probes are in that folder); author report `C:\Users\leeba\AppData\Local\Temp\orca-ctx_4b61eff34908\report.txt`; spec `C:\Projects\KstyleUI\specs\fb-keybinds.md`.

**Gate**: `bash scripts/gate.sh lint`, `bash scripts/gate.sh python` and `bash scripts/gate.sh lua --affected origin/staging` exit 0. Toolchain: prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. Test slots are shared and busy: be patient, never stop other processes.

**Checks** (`git diff fed610c6..2effdfd9`):
- Each round-1 issue is fixed, re-running the round-1 probes against the new head: (1) plain LeftButton/RightButton never bind; (2) canonical ALT-CTRL-SHIFT-META order, matching Blizzard's helper; (3) META honoured; (4) Character -> Account switch confirms and loads the account set first, never saves the character set over it; (5) hover highlight clearly visible in /kb mode; (6) locale terms consistent with the existing Possess strings, keys via GetBindingText, scene bindings unique; (7) `/kstyle bind` back in the feature map. Tests that pinned the old bugs were corrected, not deleted or weakened.
- New: `/kb` registered only when no other addon owns it, with a hint to use `/kstyle kb`; `/kstyle kb` always works. Check the ownership test covers both cases.
- Marketing: `docs/store/description.md` gains the /kb sentence; README.md, `docs/store/curseforge.md` and `docs/store/wago.md` match it via `Tools/media/marketing.py` (`test_marketing.py` green); no image under `docs/media/marketing/` changed bytes.
- `Tools/hooks/ci_scope.py`: only `docs/feature-map.md` added to READ_BY_TESTS.
- No regressions: `hud_reference` Frames/Orbs/Medallions at 1920x1080 base vs head 0 differing pixels; the /kb render `--strict` passes.
- CI run 44194112825 attempt 2 is green; attempt 1 failed CPU budgets across unchanged modules (runner load): confirm from ci-failed.log in the author's folder that no failing file is one this PR touches.

**Report**: start with "verified 2effdfd9"; PASS / ISSUES / BLOCKED; prove every issue with file:line and a command; end with an Attention list or "No flags".

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
