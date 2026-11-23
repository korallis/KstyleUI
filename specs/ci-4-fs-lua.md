# Task: CI PR 4: route every shell call in the Lua tests through fs.lua

**Goal**: make the Lua regression tests run natively on Windows (Git Bash, no WSL) as well as macOS and Linux, by putting every shell call behind one tested module. This is the first step of the portable gate.

**Target**: KstyleUI repository (GitHub `korallis/KstyleUI`), branch from `origin/staging`. The approved plan is `C:\Users\leeba\.capy\drive\captain-kstyle-project-lead\reports\CI-PLAN-2026-11-16.md`: read section 3 ("Test runner decision"), the `fs.lua` API and `--affected` subsections, and PR 4's row in section 4. Those are your Change.

**Change** (from the plan, PR 4):
- New `Tools/regression/fs.lua`, the only file allowed to call `io.popen`/`os.execute`: `list(dir, {dirs=, allow_empty=})` with an `&& echo __OK__` sentinel so a failed listing is an error, not an empty list; quoted paths, `\` on Windows, `/ad` vs `-d */`, bytewise sorted, `.DS_Store`/`desktop.ini`/`Thumbs.db` filtered, ASCII names; `tracked(pattern)` via `git ls-files "<pattern>"`; `mkdir`/`rmtree` that refuse any path outside `KSTYLEUI_TMP` (fall back to a gitignored `Tools/regression/.tmp` when run standalone); never `os.tmpname()`.
- Convert the 13 shell-using files: `perf_runner.lua` (`uptime` becomes `KSTYLEUI_LOAD` from the environment, absent means unknown), `pixel_audit_lib.lua`, `render_scenes_lib.lua`, `taint_allow.lua`, `toc_files.lua`, `test-actionbars.lua`, `test-features.lua`, `test-load-files.lua`, `test-lua-source.lua`, `test-render-scene.lua`, `test-role-fonts.lua`, `test-scaffold.lua`, `test-taint-allow.lua`. Where possible use checked-in fixture folders instead of temp dirs.
- `test-actionbars.lua:283` reads `~/.local/share/wow-dev/wow-ui-source` and silently passes when it is missing: vendor the name list it needs into `Tools/data/` (generated from the same pinned build as `Tools/data/forever_globals.lua`; add the generator step next to `Tools/build/gen_globals.py` or document the one-off command in the file's first-line comment) so the test reads nothing outside the repo.
- Reads of repository files use binary mode `"rb"` (e.g. `unitframes_env.lua:674`, `pixel_audit_lib.lua:486`).
- A guard test (new `Tools/regression/test-shell-guard.lua` or an extension of an existing source guard) fails on `io.popen`/`os.execute` outside `fs.lua` and on text-mode reads of repo files; its message names `fs.lua` / `"rb"`. Prove it fails on today's `toc_files.lua`.
- A probe test that records Lua runtime divergence: seeded `math.random` sequence hash, `string.format('%d', 2^40)`, `tostring(1/0)`, so a Windows Lua that differs from the Mac is caught.
- `--affected`: `trace.lua` records `n <dir>` listing lines and a glob such as `KstyleUI_*` records its parent folder; bump `affected.VERSION` (`Tools/regression/affected.py:20`); add a `Tools/tests/test_affected.py` case: adding `KstyleUI_New/x.lua` selects every test that lists `KstyleUI_*`.
- Add the shell rule to AGENTS.md "Conventions the tests enforce" (one line).
- Do NOT change `run_all.py`, `run-all.sh`, `gate.sh` or any `.github/` file (later PRs own those).

**Playbook**: refactor -> Read and follow `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\poteto-mode\playbooks\refactoring.md`, steps 1, 4, 5, 6, 8 only. Skip any delegation/subagents, model names, /loop, Bugbot, cloud agents, PR steps, and references to skills or sections not given as a path.

**Constraints**:
- Addon-file rules in AGENTS.md apply (Tools/ files are LF; a TOC-loaded file has one comment; never rewrite CRLF files with Python read_text/write_text).
- Every test keeps its assertions; never weaken a test to make it pass on Windows. Each test file stays within 20 s and 4096 MB under PUC Lua 5.1.5.
- Windows machine (Beast). Toolchain: prepend `~/.local/bin` (lua5.1 5.1.5, luacheck), `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. `run_all.py` does not run on Windows yet, so run test files directly: `for f in Tools/regression/test-*.lua; do lua5.1 "$f" >/dev/null 2>&1 || echo "FAIL $f"; done`.
- You may push your branch and open a **draft** pull request against `staging` for the Mac CI run that is your evidence: title `test(regression): route every shell call through fs.lua`, label `no changelog`, body with `## Summary`, `## Changelog` ("No changelog: tooling only"), `## In-game checks` ("None"). Do not merge it or mark it ready.

**Files it may edit**: `Tools/regression/**`, `Tools/data/**` (new vendored list only), `Tools/build/**` (generator step only), `Tools/tests/test_affected.py`, `.gitignore` (the `.tmp` folder), `AGENTS.md` (one Conventions line).

**Gate**: `bash scripts/gate.sh`. Known failing on Windows: `lua` and `python` groups (AGENTS.md). On Windows the bar is `bash scripts/gate.sh lint` exit 0; the full suite is proven by the draft PR's Mac CI run.

**Evidence of done**:
- Before and after counts on Windows of the direct `lua5.1` loop above (failing files listed), target 482+ of 486 passing after, with the remaining failures explained.
- The guard test failing on `origin/staging`'s `toc_files.lua` and passing after.
- `python -m unittest Tools.tests.test_affected -v` with the new glob case, exit 0.
- The draft PR's `checks` run green on the Macs (`gh run view <id> --json jobs`).

**Before worker_done**: run the Gate as above; clean comments in `git diff origin/staging..HEAD` by following `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` in worker mode (delete the comments, list MUST KILL flags, skip its greeting). Commit with Conventional Commits subjects. If you stop before green: commit `wip: <what>` and report BLOCKED (worker_done `--outcome failed`). Report commit SHA, base SHA, PR URL, run id, Gate output and evidence output.
