# Verify: CI PR 4 (fs.lua for every Lua test shell call) at f2036c10

Work only in your own worktree (your starting directory); never cd into or change `C:\Projects\KstyleUI` or any other worktree. Fetch and check out `f2036c10` (draft PR https://github.com/korallis/KstyleUI/pull/413). Base is `076f267b`. Edit nothing, push nothing, comment nothing.

**Spec the author worked from**: `C:\Projects\KstyleUI\specs\ci-4-fs-lua.md` (it names plan section 3 in `C:\Users\leeba\.capy\drive\captain-kstyle-project-lead\reports\CI-PLAN-2026-11-16.md`). The author's evidence comment is on the PR.

**Allowed files**: `Tools/regression/**`, `Tools/data/**` (the vendored list only), `Tools/build/**` (generator step only), `Tools/tests/test_affected.py`, `.gitignore`, `AGENTS.md` (one Conventions line).

**Gate**: `bash scripts/gate.sh`; known failing on Windows: `lua` and `python` groups. Windows bar: `gate.sh lint` exit 0 plus `for f in Tools/regression/test-*.lua; do lua5.1 "$f" >/dev/null 2>&1 || echo "FAIL $f"; done` (author claims only the three perf headroom files and `test-lua-runtime` fail, the last by design on MSVC `rand`). Toolchain: prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`.

**Checks**:
- Coverage: grep the whole tree for `io.popen`, `os.execute`, `os.tmpname`, and text-mode `io.open` of repo files outside `fs.lua`; the guard test must catch each (mutate a file to prove it).
- Assertions kept: for each of the 13 converted files compare assertion counts and what they check before and after; flag any weakened or removed check, and any test that now passes vacuously (an empty listing, a missing folder) - `fs.list` must fail loudly on a failed listing (prove with a missing dir under both cmd and sh).
- `test-actionbars.lua` reads only in-repo data now; the vendored `Tools/data/gamepad_actionbar_names.txt` matches wow-ui-source `9dc84f0` (regenerate it with the command in its first line if the source is reachable).
- `--affected`: `affected.VERSION` bumped; the `KstyleUI_New/x.lua` glob case; run `Tools/tests/test_affected.py` on the Mac CI evidence (run 43904251827) since it needs `run_all.py`.
- `test-lua-runtime`: judge whether failing by design on Windows is correct and documented (it should name the difference); say whether it makes the Windows gate permanently red and what the fix would be (e.g. a Windows Lua build whose rand matches, or a probe that records rather than fails).
- Each converted test file stays within 20 s and 4096 MB under PUC Lua 5.1.5 (time the slowest few on Windows).
- `git diff --stat 076f267b..f2036c10` against the allowed files; whether it rebases cleanly onto current `origin/staging` (`git rebase --onto origin/staging 076f267b` in a scratch branch, report conflicts).
- Comments: `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` REPORT ONLY; blast radius: `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\blast-radius\SKILL.md` steps 1-5.

**Report**: start with "verified f2036c10"; PASS / ISSUES / BLOCKED; prove every issue with a command and its output; end with an Attention list or "No flags".
