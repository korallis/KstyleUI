# KstyleUI Phase 0: Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give KstyleUI a repository where every NaowhForever-equivalent check runs locally and in CI, an empty addon that loads on Forever, a spike addon that answers the spec's open questions in game, and the list of every ability icon to generate.

**Architecture:** Tooling lives in `Tools/` and never ships. One TOC-and-XML walker, written once in Lua and once in Python, tells every check which files the game loads. Source scanners (taint, secrets) read those files as text. Regression tests load real addon files into a stub WoW environment with `setfenv`.

**Tech Stack:** Lua 5.1 and LuaJIT, Python 3.12 standard library only, luacheck 1.2.0, pre-commit, GitHub Actions, the BigWigs packager.

**Spec:** [`docs/superpowers/specs/2026-11-07-kstyleui-design.md`](../specs/2026-11-07-kstyleui-design.md). Roadmap: [`2026-11-07-kstyleui-roadmap.md`](2026-11-07-kstyleui-roadmap.md).

## Global Constraints

Every constraint in the roadmap's Global Constraints applies. These apply to this phase in particular:

- `Tools/` and `docs/` files use LF line endings and may be non-ASCII. Every other `.lua`, `.toc` and `.xml` file uses CRLF and ASCII.
- Python tools use the standard library only, so CI needs no `pip install` beyond pre-commit.
- Lua tests run with `$LUA` (default `lua5.1`). On the Mac run them with `LUA=luajit`.
- Every GitHub Action and pre-commit hook is pinned by full commit SHA with the version in a trailing comment.
- No file is copied from NaowhForever. Its checks are described in the spec; write fresh implementations.

## Review Focus

1. **A file on disk has different letter case from the TOC line.** macOS finds it and Linux CI does not. `check_toc.py` must report the case mismatch, not only missing files. Owner: Task 2.
2. **An XML file includes another XML file in a subfolder.** Paths in the nested file are relative to that file's folder. The walker must resolve them that way. Owner: Task 2.
3. **A Blizzard frame is reached through a local alias** (`local f = PlayerFrame` then `f:SetScript`). The taint scan must follow simple local aliases. Owner: Task 7.
4. **A secret value is compared on the line after it is fetched**, through a local. The secret lint must track simple locals within a file. Owner: Task 8.
5. **wago.tools is down or returns HTML instead of CSV.** The extractor must fail with a clear message and never write a partial `abilities.json`. Owner: Task 12.

## Task order

Tasks 1 to 4 run in sequence. After Task 4, Tasks 5, 6, 8 (which needs 5's globals list only for its fixtures, so it can start in parallel), 10, 11 and 12 can run in parallel worktrees. Task 7 needs Task 5. Task 9 needs Tasks 6, 7 and 8. Task 13 needs Tasks 10 and 11.

---

### Task 1: Repository rules and line endings

**Files:**
- Create: `.gitattributes`, `Tools/dev/crlf.py`, `Tools/tests/test_crlf.py`, `AGENTS.md`, `LICENSE.md`
- Modify: `README.md`, `.gitignore`

**Interfaces:**
- Produces: `python3 Tools/dev/crlf.py [PATH ...]` converts addon files to CRLF in place. With no paths it converts every changed or untracked addon file from `git status --porcelain`. `--check` changes nothing, prints each LF addon file and exits 1 if any exist. An addon file is a `.lua`, `.toc` or `.xml` file not under `Tools/` or `docs/`.

- [ ] **Step 1: Write the failing tests** in `Tools/tests/test_crlf.py`:

```python
def test_converts_lf_to_crlf(self):            # b"a\nb\n" -> b"a\r\nb\r\n"
def test_leaves_crlf_unchanged(self):          # bytes identical after run
def test_does_not_double_convert(self):        # b"a\r\n" stays b"a\r\n"
def test_skips_tools_and_docs(self):           # Tools/x.lua, docs/x.xml untouched
def test_skips_other_extensions(self):         # README.md untouched
def test_check_mode_exits_1_and_lists_files(self)
def test_check_mode_exits_0_when_clean(self)
```

Each test builds a temporary directory and calls `crlf.main(argv)`.

- [ ] **Step 2: Run the tests and see them fail**

Run: `python3 -m unittest discover -s Tools/tests -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'crlf'` (the test adds `Tools/dev` to `sys.path`).

- [ ] **Step 3: Implement `main(argv: list[str]) -> int` in `Tools/dev/crlf.py`**

Normalise with `data.replace(b"\r\n", b"\n").replace(b"\n", b"\r\n")`. Write only when the bytes change.

- [ ] **Step 4: Run the tests and see them pass**

Run: `python3 -m unittest discover -s Tools/tests -v`
Expected: 7 tests, OK.

- [ ] **Step 5: Write the repository files**

- `.gitattributes`: `* -text`, so git never rewrites line endings.
- `.gitignore`: add `Tools/data/db2cache/` and `__pycache__/`.
- `LICENSE.md`: "Copyright 2026 the KstyleUI authors. All rights reserved." Then a section per bundled third-party item, empty for now.
- `AGENTS.md`: the repository's commands (the four pre-PR commands from the roadmap's Global Constraints), the branch flow (branch from `staging`, PR into `staging`, `main` moves only after the owner's in-game pass), sensitive paths (`.github/workflows/`, `.pkgmeta`, `Core/Tokens.lua`), the CRLF rule with the `crlf.py` command, and an empty "Learned mistakes" section.
- `README.md`: add an Install section for players (download from Releases into `Interface/AddOns`) and a Develop section that points to `AGENTS.md`.

- [ ] **Step 6: Commit**

```bash
git add .gitattributes .gitignore Tools/dev/crlf.py Tools/tests/test_crlf.py AGENTS.md LICENSE.md README.md
git commit -m "build: add line-ending rules, crlf converter and AGENTS.md"
```

---

### Task 2: TOC and XML walker

**Files:**
- Create: `Tools/regression/toc_files.lua`, `Tools/regression/test-toc-walker.lua`, `Tools/hooks/toc_files.py`, `Tools/hooks/check_toc.py`, `Tools/tests/test_toc_files.py`
- Create fixtures: `Tools/regression/fixtures/toc/Fix.toc`, `Tools/regression/fixtures/toc/Core/Core.xml`, `Tools/regression/fixtures/toc/Core/Sub/Sub.xml`, `Tools/regression/fixtures/toc/Core/A.lua`, `Tools/regression/fixtures/toc/Core/Sub/B.lua`, `Tools/regression/fixtures/toc/Fix_Mod/Fix_Mod.toc`, `Tools/regression/fixtures/toc/Fix_Mod/Mod.xml`, `Tools/regression/fixtures/toc/Fix_Mod/C.lua`

**Interfaces:**
- Produces (Lua): `local TocFiles = dofile("Tools/regression/toc_files.lua")`, then `TocFiles(pattern, root) -> { path, ... }`. It reads `<root>/*.toc` and `<root>/KstyleUI_*/*.toc` (and in the fixture, `Fix_*`), follows each listed `.xml` file's `<Script file="..."/>` and `<Include file="..."/>` entries relative to that XML file's folder, and returns every resolved path in load order, filtered by the Lua pattern. `root` defaults to `"."`. Lines starting `#` in a TOC are skipped. Paths use `/`.
- Produces (Python): `toc_files.toc_files(root: Path, module_glob: str = "KstyleUI_*") -> list[str]`, the same contract.
- Produces: `python3 Tools/hooks/check_toc.py [--root ROOT]` exits 1 and prints `missing: <path>` or `case: <listed> != <on disk>` for each problem.

- [ ] **Step 1: Write the fixtures and the failing Lua test** `test-toc-walker.lua`:

```lua
local files = TocFiles("%.lua$", "Tools/regression/fixtures/toc")
assert(#files == 3, "expected 3 lua files, got " .. #files)
assert(files[1]:match("Core/A%.lua$"))
assert(files[2]:match("Core/Sub/B%.lua$"))   -- nested include resolved from Sub/
assert(files[3]:match("Fix_Mod/C%.lua$"))
print("toc walker ok")
```

- [ ] **Step 2: Run it and see it fail**

Run: `LUA=luajit; $LUA Tools/regression/test-toc-walker.lua`
Expected: FAIL, `cannot open Tools/regression/toc_files.lua`.

- [ ] **Step 3: Implement `toc_files.lua`**

Use `io.popen("ls ...")` to list TOCs, since Lua 5.1 has no directory API. Match XML entries with `file%s*=%s*"([^"]+)"`.

- [ ] **Step 4: Run it and see it pass**

Run: `$LUA Tools/regression/test-toc-walker.lua`
Expected: `toc walker ok`.

- [ ] **Step 5: Write the failing Python tests** in `test_toc_files.py`: the same three files in the same order, plus `test_check_toc_reports_missing` (a TOC line naming a file that does not exist) and `test_check_toc_reports_case` (a TOC line `core/a.lua` against `Core/A.lua` on disk; compare names with `os.listdir`, not `Path.exists`, because macOS is case-insensitive).

- [ ] **Step 6: Run them and see them fail**, then implement `toc_files.py` and `check_toc.py`, then run them and see them pass.

Run: `python3 -m unittest discover -s Tools/tests -v`
Expected: all tests OK.

- [ ] **Step 7: Commit**

```bash
git add Tools/regression Tools/hooks Tools/tests
git commit -m "test: add TOC and XML walker with case-sensitive check"
```

---

### Task 3: Addon skeleton, syntax test and dev links

**Files:**
- Create: `KstyleUI.toc`, `Core/Core.xml`, `Core/Init.lua`, `Tools/regression/test-syntax.lua`, `Tools/dev/link-addons.sh`

**Interfaces:**
- Consumes: `TocFiles` from Task 2.
- Produces: the global `KstyleUI` table with `KstyleUI.VERSION` (`"@project-version@"`, replaced by the packager) and `KstyleUI.CODE_BUILD = 1`.
- Produces: `bash Tools/dev/link-addons.sh [--spike] [--dry-run]`. It creates the worktree `~/KstyleUI.worktrees/staging-live` on `staging` if missing, then links `Interface/AddOns/KstyleUI` and every `KstyleUI_*` folder in that worktree into `/Applications/World of Warcraft/_forever_/Interface/AddOns/`. `--spike` also links `Tools/spikes/KstyleUI_Spike`. Running it twice changes nothing. It never deletes a real folder: if a target exists and is not a symlink, it prints the path and exits 1.

- [ ] **Step 1: Write the failing test** `test-syntax.lua`: for every path from `TocFiles("%.lua$")`, `assert(loadfile(path))`. Count the files, assert at least one, and print `N TOC files compile`.

- [ ] **Step 2: Run it and see it fail**

Run: `$LUA Tools/regression/test-syntax.lua`
Expected: FAIL, `no Lua files found`.

- [ ] **Step 3: Create the skeleton**

`KstyleUI.toc`:

```
## Interface: 16001
## AllowLoadGameType: camelot
## Title: KstyleUI
## Notes: A complete UI for WoW Forever.
## Author: korallis
## Version: @project-version@
## Group: KstyleUI
## SavedVariables: KstyleUIDB
## IconTexture: Interface\AddOns\KstyleUI\Media\Logo\Logo64

Core\Core.xml
```

`Core/Core.xml` loads `Init.lua`. `Core/Init.lua` sets `KstyleUI` to the addon's private table and sets `VERSION` and `CODE_BUILD`. Run `python3 Tools/dev/crlf.py` afterwards. Leave `IconTexture` pointing at a path Phase 1 fills. The game shows a blank icon until then.

- [ ] **Step 4: Run the tests and see them pass**

Run: `$LUA Tools/regression/test-syntax.lua && python3 Tools/hooks/check_toc.py`
Expected: `1 TOC files compile`, and `check_toc.py` exits 0.

- [ ] **Step 5: Write `link-addons.sh`, then run it with `--dry-run`**

Run: `bash Tools/dev/link-addons.sh --dry-run`
Expected: one `link` line per addon folder, and no changes on disk.

- [ ] **Step 6: Commit**

```bash
git add KstyleUI.toc Core Tools/regression/test-syntax.lua Tools/dev/link-addons.sh
git commit -m "feat(core): add loadable addon skeleton and dev links"
```

- [ ] **Step 7: First in-game check (owner)**

After this task merges, the owner runs `bash Tools/dev/link-addons.sh`, restarts the game once, and confirms that KstyleUI appears in the AddOns list and that `/dump KstyleUI.CODE_BUILD` prints `1`.

---

### Task 4: Regression runner and WoW stubs

**Files:**
- Create: `Tools/regression/run-all.sh`, `Tools/regression/load_files.lua`, `Tools/regression/stubs/wow.lua`, `Tools/regression/test-stubs.lua`

**Interfaces:**
- Produces: `bash Tools/regression/run-all.sh` runs every `Tools/regression/test-*.lua` with `$LUA` from the repository root, prints `FAIL <name>` and the last 5 output lines for each failure, prints `passed N, failed M`, and exits non-zero on any failure.
- Produces: `local Load = dofile("Tools/regression/load_files.lua")`, then `Load(files, env) -> env`. It runs each file with `setfenv(chunk, env)` and passes `"KstyleUI", ns` as the chunk's varargs, matching the game's `local addonName, ns = ...`.
- Produces: `local Stubs = dofile("Tools/regression/stubs/wow.lua")`, then `Stubs.NewEnv(opts) -> env`. `env` falls back to `_G` for Lua builtins. It provides `CreateFrame(type, name, parent, template)` returning objects that record every method call in `obj._calls`; `UIParent` with `GetEffectiveScale()`; `GetPhysicalScreenSize()` returning `opts.width, opts.height` (default 1920, 1080); `InCombatLockdown()` returning `env._combat`; `C_Timer.After(s, fn)` that queues `fn` until `env.RunTimers()`; `issecretvalue(v)` returning true for values made by `env.Secret(n)`; `hooksecurefunc`; and `env.FireEvent(event, ...)`, which calls every registered `OnEvent` script.

- [ ] **Step 1: Write the failing test** `test-stubs.lua`:

```lua
local env = Stubs.NewEnv({ width = 3840, height = 2160 })
local f = env.CreateFrame("Frame", "TestFrame", env.UIParent)
f:SetSize(10, 20)
assert(f._calls[1].method == "SetSize" and f._calls[1].args[2] == 20)
assert(select(2, env.GetPhysicalScreenSize()) == 2160)
local ran = false
env.C_Timer.After(0, function() ran = true end)
assert(not ran); env.RunTimers(); assert(ran)
assert(env.issecretvalue(env.Secret(5)) and not env.issecretvalue(5))
f:RegisterEvent("PLAYER_LOGIN")
local got
f:SetScript("OnEvent", function(_, e) got = e end)
env.FireEvent("PLAYER_LOGIN"); assert(got == "PLAYER_LOGIN")
print("stubs ok")
```

- [ ] **Step 2: Run it and see it fail**, then implement the three files, then run `bash Tools/regression/run-all.sh` and see `passed 3, failed 0` (walker, syntax, stubs).

A secret made by `env.Secret(n)` is a table whose metatable raises `"attempt to compare a secret value"` from `__lt`, `__le` and `__eq`, and `"attempt to perform arithmetic on a secret value"` from `__add`, `__sub`, `__mul`, `__div`, `__mod`, `__unm` and `__len`. Later tests use it to prove that code never touches a secret.

- [ ] **Step 3: Commit**

```bash
git add Tools/regression
git commit -m "test: add regression runner, file loader and WoW stubs"
```

---

### Task 5: Generated Forever globals and luacheck

**Files:**
- Create: `Tools/build/gen_globals.py`, `Tools/tests/test_gen_globals.py`, `Tools/data/forever_globals.lua` (generated), `.luacheckrc`

**Interfaces:**
- Produces: `python3 Tools/build/gen_globals.py --source <wow-ui-source checkout on branch forever> --out Tools/data/forever_globals.lua`. It writes `return { read = { ...names... }, deprecated = { ...names... } }`, sorted and de-duplicated, with a header line naming the source commit (`git -C <source> log -1 --format=%h %s`).
  - `read` holds the API namespaces and global functions from `Interface/AddOns/Blizzard_APIDocumentationGenerated/*.lua` (each `Namespace = "C_X"`, plus each function in a table whose `Namespace` is absent), plus top-level `function Name(` and `Name = ` globals from every `.lua` under `Interface/AddOns` whose TOC loads on camelot, excluding every `Blizzard_Deprecated*` folder.
  - `deprecated` holds the global function names defined in `Blizzard_Deprecated*` folders.
- Produces: `.luacheckrc` with `std = "lua51"`, `max_line_length = false`, `ignore = { "212" }`, `exclude_files = { "Libs/", "Tools/regression/fixtures/", "Tools/spikes/" }`, `read_globals` from `dofile("Tools/data/forever_globals.lua").read`, and `globals = { "KstyleUI", "KstyleUIDB", "SlashCmdList" }` plus each `SLASH_KSTYLE<n>`.

- [ ] **Step 1: Write the failing tests** in `test_gen_globals.py` against a tiny fake source tree built in a temp directory: `test_reads_api_namespace` (`C_Spell` in `read`), `test_reads_framexml_function` (`PixelUtil` in `read`), `test_excludes_deprecated` (`IsPlayerSpell` in `deprecated`, not in `read`), `test_output_is_sorted_lua`.

- [ ] **Step 2: Run them and see them fail**, then implement `gen_globals.py`, then run them and see them pass.

Run: `python3 -m unittest discover -s Tools/tests -v`
Expected: all OK.

- [ ] **Step 3: Generate the real list**

Run: `git clone --depth 1 --branch forever https://github.com/Gethe/wow-ui-source.git /tmp/wow-ui-forever && python3 Tools/build/gen_globals.py --source /tmp/wow-ui-forever --out Tools/data/forever_globals.lua`
Expected: the header names build 70840 or newer, `read` contains `C_Secrets`, `C_SwingTimer`, `UnitHealthPercent` and `WOW_PROJECT_CAMELOT`, and `read` does not contain `IsPlayerSpell`.

- [ ] **Step 4: Write `.luacheckrc` and run luacheck**

Run: `luacheck .`
Expected: `0 warnings / 0 errors`. Then add `IsPlayerSpell()` to `Core/Init.lua` temporarily. Expected: `accessing undefined variable 'IsPlayerSpell'`. Remove the line.

- [ ] **Step 5: Commit**

```bash
git add Tools/build/gen_globals.py Tools/tests/test_gen_globals.py Tools/data/forever_globals.lua .luacheckrc
git commit -m "build: generate Forever globals for luacheck"
```

---

### Task 6: pre-commit configuration

**Files:**
- Create: `.pre-commit-config.yaml`

**Interfaces:**
- Consumes: `.luacheckrc` (Task 5), `check_toc.py` (Task 2).
- Produces: hooks for the `pre-commit` and `commit-msg` stages. `exclude: ^Libs/`.

| Hook | Source | Settings |
| --- | --- | --- |
| `check-merge-conflict`, `check-yaml`, `check-xml`, `check-case-conflict`, `detect-private-key`, `trailing-whitespace` | `pre-commit/pre-commit-hooks` | defaults |
| `check-added-large-files` | same | `--maxkb=5120` |
| `mixed-line-ending` | same | `--fix=no` |
| `actionlint` | `Mateusz-Grzelinski/actionlint-py` | defaults |
| `zizmor` | `zizmorcore/zizmor-pre-commit` | defaults |
| `conventional-pre-commit` | `compilerla/conventional-pre-commit` | types `feat fix perf refactor docs test ci build chore revert` |
| `luacheck` | local, `language: system`, `types: [lua]` | |
| `addon-crlf` | local `pygrep`, `entry: '(?<!\r)\n'`, `--multiline` | `files: \.(lua|toc|xml)$`, `exclude: ^(Tools|docs)/` |
| `addon-ascii` | local `pygrep`, `entry: '[^\x00-\x7F]'` | same files and exclude |
| `no-goto` | local `pygrep`, `entry: '\bgoto\b|::[A-Za-z_][A-Za-z0-9_]*::'` | `files: \.lua$`, `exclude: ^Tools/` |
| `toc-files` | local `python Tools/hooks/check_toc.py` | `files: \.(toc|lua|xml)$`, `pass_filenames: false` |

- [ ] **Step 1: Write the config**, pinning each remote repo with `rev: <full SHA> # frozen: vX.Y.Z`. Look up each SHA with `git ls-remote <repo> refs/tags/<tag>`.

- [ ] **Step 2: Run it**

Run: `pre-commit install --hook-type pre-commit --hook-type commit-msg && pre-commit run --all-files`
Expected: every hook `Passed` or `(no files to check)Skipped`.

- [ ] **Step 3: Prove the custom hooks fail**

Create a temporary `Core/Bad.lua` containing `goto x` with LF endings and a non-ASCII character, and list it in `Core/Core.xml`. Run `pre-commit run --all-files`. Expected: `addon-crlf`, `addon-ascii` and `no-goto` fail on `Core/Bad.lua`. Delete the file and the XML line, then run again. Expected: all pass.

- [ ] **Step 4: Commit**

```bash
git add .pre-commit-config.yaml
git commit -m "build: add pre-commit checks"
```

---

### Task 7: Taint scan

**Files:**
- Create: `Tools/regression/taint_scan.lua`, `Tools/regression/taint_allow.lua`, `Tools/regression/test-taint-scan.lua`, `Tools/regression/test-taint-fixtures.lua`, fixtures `Tools/regression/fixtures/taint/bad.lua` and `Tools/regression/fixtures/taint/good.lua`

**Interfaces:**
- Consumes: `TocFiles` (Task 2), `Tools/data/forever_globals.lua` (Task 5).
- Produces: `local Scan = dofile("Tools/regression/taint_scan.lua")`, then `Scan(source, blizzardNames) -> { { kind, call, line }, ... }`. Kinds:
  - `frame-call`: one of `SetScript`, `Hide`, `SetParent`, `ClearAllPoints`, `SetPoint`, `SetAllPoints`, `SetSize`, `SetWidth`, `SetHeight`, `SetScale`, `UnregisterAllEvents`, `UnregisterEvent`, `RegisterEvent`, `EnableMouse`, `SetAttribute`, `SetFrameStrata` called on a Blizzard name or on a local assigned from one.
  - `field-write`: `<BlizzardName>.<field> =` or the same through a local alias.
  - `game-table-write`: a write into `UISpecialFrames`, `UIPanelWindows` or `hash_SlashCmdList`, a `StaticPopupDialogs` key without the `KSTYLEUI_` prefix, or assignment to a Blizzard name.
  - `protected-unguarded`: a call of `PickupAction`, `PlaceAction`, `SetBinding`, `SetOverrideBinding`, `SetOverrideBindingClick`, `ClearOverrideBindings`, `CreateMacro`, `EditMacro`, `C_Container.PickupContainerItem`, `C_Container.UseContainerItem`, `TargetUnit`, `CastSpellByName`, `CastSpellByID`, `UseAction`, `RunMacroText`, `ShowUIPanel` or `HideUIPanel` with no `InCombatLockdown` and no `KstyleUI.Combat.Queue` in the 40 lines before it.
  - `setparent-unguarded`: `SetParent` on any receiver with no `EditModeManagerFrame:IsShown` and no `KstyleUI.Safe.` in the 40 lines before it.
  - `aura-unguarded`: `C_UnitAuras.` in a file with no `ShouldAurasBeSecret` and no `issecretvalue`.
- Produces: `taint_allow.lua` returns `{ ["path"] = { why = "...", calls = { ["PlayerFrame:SetAlpha"] = 1 } } }`. It starts empty.

A Blizzard name is any name in `read` from `forever_globals.lua` that does not start with `KstyleUI`.

- [ ] **Step 1: Write the fixtures and the failing fixture test** `test-taint-fixtures.lua`. `bad.lua` holds one example of each kind, including `local f = PlayerFrame; f:SetScript("OnShow", nil)`. `good.lua` holds the guarded forms: a `Combat.Queue` before `SetBinding`, `Safe.HideBlizzard(PlayerFrame)`, and an aura read after `C_Secrets.ShouldAurasBeSecret()`.

```lua
local kinds = {}
for _, f in ipairs(Scan(read("fixtures/taint/bad.lua"), names)) do kinds[f.kind] = (kinds[f.kind] or 0) + 1 end
for _, k in ipairs({ "frame-call", "field-write", "game-table-write", "protected-unguarded", "setparent-unguarded", "aura-unguarded" }) do
	assert(kinds[k], "bad.lua: no " .. k .. " finding")
end
assert(#Scan(read("fixtures/taint/good.lua"), names) == 0, "good.lua must be clean")
print("taint fixtures ok")
```

- [ ] **Step 2: Run it and see it fail**, then implement `taint_scan.lua`, then run it and see it pass.

- [ ] **Step 3: Write `test-taint-scan.lua`**. It scans every `TocFiles("%.lua$")` path outside `Libs/`, compares the findings per file and call with `taint_allow.lua`, and fails on a new finding, a count above the allowed count, an allowed entry that no longer matches anything, and an entry with an empty `why`. It also asserts that it scanned at least one file.

- [ ] **Step 4: Run the suite**

Run: `LUA=luajit bash Tools/regression/run-all.sh`
Expected: `failed 0`.

- [ ] **Step 5: Commit**

```bash
git add Tools/regression
git commit -m "test: add taint scan with reviewed allow-list"
```

---

### Task 8: Secret-value lint

**Files:**
- Create: `Tools/regression/secret_lint.lua`, `Tools/regression/test-secrets.lua`, `Tools/regression/test-secret-fixtures.lua`, fixtures `Tools/regression/fixtures/secrets/bad.lua` and `Tools/regression/fixtures/secrets/good.lua`

**Interfaces:**
- Consumes: `TocFiles` (Task 2).
- Produces: `local Lint = dofile("Tools/regression/secret_lint.lua")`, then `Lint(source) -> { { kind, name, line }, ... }`.
  - Secret sources: `UnitHealth`, `UnitHealthMissing`, `UnitHealthPercent`, `UnitInRange`, `UnitPower`, `UnitPowerMax`, `UnitCastingInfo`, `UnitChannelInfo`, `UnitGetIncomingHeals`, and every `C_UnitAuras.` function.
  - A tainted name is a local assigned from a secret source, directly or through `select`.
  - Kinds: `compare` (a tainted name or a secret call next to `<`, `>`, `<=`, `>=`, `==` or `~=`), `arith` (next to `+`, `-`, `*`, `/`, `%` or `^`), `length` (`#name`), `key` (`[name]`), `bool` (`if name`, `not name`, `name and`, `name or`). A use is allowed when `issecretvalue(name)` appears earlier on the same line or in the enclosing `if` condition. `combatlog` is any `COMBAT_LOG_EVENT` or `CombatLogGetCurrentEventInfo`.

- [ ] **Step 1: Write the fixtures and the failing fixture test.** `bad.lua` has one line per kind, for example `local hp = UnitHealth("player") if hp < 100 then end`. `good.lua` has `bar:SetValue(UnitHealth(unit))`, `text:SetText(AbbreviateNumbers(UnitHealth(unit)))` and `if not issecretvalue(hp) and hp < 100 then end`. Assert that each kind appears for `bad.lua` and that `good.lua` gives zero findings.

- [ ] **Step 2: Run it and see it fail**, then implement `secret_lint.lua`, then run it and see it pass.

- [ ] **Step 3: Write `test-secrets.lua`**, which runs `Lint` over every TOC-loaded Lua file outside `Libs/` and fails on any finding. It has no allow-list. A real need for an exception goes through `issecretvalue`.

- [ ] **Step 4: Run the suite and commit**

Run: `LUA=luajit bash Tools/regression/run-all.sh`
Expected: `failed 0`.

```bash
git add Tools/regression
git commit -m "test: add secret-value lint"
```

---

### Task 9: Packaging, PR rules and CI

**Files:**
- Create: `.pkgmeta`, `Tools/hooks/check-package.sh`, `Tools/hooks/check-pr.sh`, `.github/workflows/checks.yml`, `.github/workflows/pr-title.yml`, `.github/dependabot.yml`, `.github/PULL_REQUEST_TEMPLATE.md`, `Tools/tests/test_check_pr.py`

**Interfaces:**
- Produces: `.pkgmeta` with `package-as: KstyleUI` and `enable-nolib-creation: no`. Its `ignore` list holds `Tools`, `docs`, `research_notes`, `reports`, `.github`, `.luacheckrc`, `.pre-commit-config.yaml`, `AGENTS.md` and `README.md`. It has an empty `move-folders` map. Each module task in later phases adds `KstyleUI/KstyleUI_<Module>: KstyleUI_<Module>`.
- Produces: `bash Tools/hooks/check-package.sh [.release]` asserts the packager made exactly one zip, the zip's top level holds only `KstyleUI` and `KstyleUI_*` folders, every `TocFiles` path is inside it, and no `Tools/`, `docs/`, `research_notes/`, `reports/`, `.luacheckrc` or `.pre-commit-config.yaml` is inside it.
- Produces: `bash Tools/hooks/check-pr.sh <base-ref>`, reading `PR_BODY` and `PR_LABELS` from the environment. If files outside `Tools/`, `docs/`, `research_notes/`, `reports/` and `.github/` changed, the body needs a line under `## Changelog` starting `Added:`, `Changed:` or `Fixed:`, unless `PR_LABELS` contains `no changelog`. A changed `## Version` line in any TOC, or a changed `CODE_BUILD`, fails unless `PR_LABELS` contains `release`. An unknown base ref exits 2.

- [ ] **Step 1: Write the failing tests** in `test_check_pr.py`, which run `check-pr.sh` against a throwaway git repository: `test_requires_changelog_for_addon_change`, `test_docs_only_needs_no_changelog`, `test_no_changelog_label_passes`, `test_version_change_needs_release_label`, `test_unknown_ref_exits_2`.

- [ ] **Step 2: Run them and see them fail**, then implement both scripts, then run them and see them pass.

- [ ] **Step 3: Write the workflows**

`checks.yml` runs on `pull_request` with `permissions: contents: read` and has four jobs on `ubuntu-24.04`. Each `actions/checkout` sets `persist-credentials: false`.
  - `pre-commit`: install `lua5.1 liblua5.1-dev luarocks`, then `luarocks install luacheck 1.2.0-1`, then `pip install pre-commit` and `pre-commit run --all-files --show-diff-on-failure`.
  - `tests`: install `lua5.1`, then `bash Tools/regression/run-all.sh` and `python3 -m unittest discover -s Tools/tests`.
  - `package`: `BigWigsMods/packager` with `args: -d -z -l` (no upload, no zip, no localisation) for the file check, then a second run with `-d -l` and `bash Tools/hooks/check-package.sh`.
  - `pr-rules`: `bash Tools/hooks/check-pr.sh origin/${{ github.base_ref }}`, with `PR_BODY` and `PR_LABELS` passed through `env:`, never interpolated into the script.

`pr-title.yml` checks `github.event.pull_request.title` against `^(feat|fix|perf|refactor|docs|test|ci|build|chore|revert)(\([a-z0-9-]+\))?: \S`, passed through `env:`.

`dependabot.yml` updates `github-actions` weekly.

`PULL_REQUEST_TEMPLATE.md` has sections for Summary, `## Changelog`, In-game checks (with the forced-restriction CVars line), and a checklist covering the four local commands, `cr review --agent` and `/codex:review`.

- [ ] **Step 4: Prove CI on a PR**

Push the branch and open the PR into `staging`.
Run: `gh pr checks --watch`
Expected: `pre-commit`, `tests`, `package`, `pr-rules` and `title` all pass.

- [ ] **Step 5: Commit** (before the push in Step 4)

```bash
git add .pkgmeta Tools/hooks Tools/tests/test_check_pr.py .github
git commit -m "ci: add package check, PR rules and CI workflows"
```

---

### Task 10: Spike addon, part 1

**Files:**
- Create: `Tools/spikes/KstyleUI_Spike/KstyleUI_Spike.toc`, `Tools/spikes/KstyleUI_Spike/Spike.xml`, `Tools/spikes/KstyleUI_Spike/Core.lua`, `Tools/spikes/KstyleUI_Spike/Fonts.lua`, `Tools/spikes/KstyleUI_Spike/Scale.lua`, `Tools/spikes/KstyleUI_Spike/Encoding.lua`, `Tools/spikes/KstyleUI_Spike/Textures.lua`, `Tools/spikes/KstyleUI_Spike/README.md`
- Add media: `Tools/spikes/KstyleUI_Spike/Media/SourceSans3-Semibold.ttf`, `Tools/spikes/KstyleUI_Spike/Media/Inter-SemiBold.ttf` with each font's `OFL.txt`, downloaded from the upstream GitHub releases (`adobe-fonts/source-sans`, `rsms/inter`); `Media/mask_2048.png` and `Media/alpha_test.png` drawn by a short script in the README.

**Interfaces:**
- Produces: SavedVariables `KstyleUISpikeDB = { runs = { { spike, time, build, results } } }`. `/kspike <name>` runs one spike and appends a run. `/kspike list` prints the spike names.
- Spikes in this task:
  - `fonts`: a panel showing "The quick brown fox 0123456789" in both fonts at 9, 11, 16 and 24 units, each with `""` and `"SLUG"` flags, inside a root scaled as in the spec. It records `GetFont()` for each.
  - `scale`: creates a root with the spec's `ApplyRootScale`, records `GetPhysicalScreenSize()`, `UIParent:GetEffectiveScale()`, the root's effective scale and its height in units, and registers `ADDON_ACTION_BLOCKED` and `ADDON_ACTION_FORBIDDEN` for 60 seconds.
  - `encoding`: records whether `C_EncodingUtil.SerializeCBOR`, `DeserializeCBOR`, `CompressString`, `DecompressString`, `EncodeBase64` and `DecodeBase64` exist, and round-trips a sample profile table.
  - `textures`: shows `mask_2048.png` and an `alpha_test.png` masked onto a solid texture, and records whether each texture loaded (`GetTexture()` non-nil after a frame).

- [ ] **Step 1: Write the addon.** It is a throwaway spike, so it has no unit tests. `.luacheckrc` excludes `Tools/spikes/`, and `test-syntax.lua` does not walk it, so Step 2 is its only check. Its TOC uses the Global Constraints header, without `## Group`.

- [ ] **Step 2: Verify it loads offline**

Run: `for f in Tools/spikes/KstyleUI_Spike/*.lua; do luajit -bl "$f" >/dev/null || echo "FAIL $f"; done`
Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add Tools/spikes
git commit -m "test: add spike addon for fonts, scale, encoding and textures"
```

---

### Task 11: Spike addon, part 2

**Files:**
- Create: `Tools/spikes/KstyleUI_Spike/Paging.lua`, `Tools/spikes/KstyleUI_Spike/CombatText.lua`, `Tools/spikes/KstyleUI_Spike/Auras.lua`, `Tools/spikes/KstyleUI_Spike/Meters.lua`, `Tools/spikes/KstyleUI_Spike/Presets.lua`, `Tools/spikes/KstyleUI_Spike/Cooldowns.lua`
- Modify: `Tools/spikes/KstyleUI_Spike/Spike.xml`, `Tools/spikes/KstyleUI_Spike/README.md`

**Interfaces:**
- Consumes: the `/kspike` command and the run log from Task 10.
- Spikes in this task:
  - `paging`: at `PLAYER_LOGIN`, creates one `SecureActionButtonTemplate` button with a `RegisterStateDriver` page driver (`[possessbar] 12; [bonusbar:1] 7; [bonusbar:2] 8; [bonusbar:3] 9; [bonusbar:4] 10; [stealth] 7; 1`) and a `WrapScript` `OnClick` snippet. It records each `page` attribute change with a timestamp, plus any `ADDON_ACTION_BLOCKED`.
  - `combat`: for 5 minutes, registers `UNIT_COMBAT` with no unit filter and records per unit token: the event count and, for each argument, whether `issecretvalue` was true, inside and outside `InCombatLockdown()`. It notes whether any `nameplateN` token fired.
  - `auras`: records timestamps of `ENCOUNTER_START`, `PLAYER_REGEN_DISABLED` and every flip of `C_Secrets.ShouldAurasBeSecret()`, sampled each 0.1 s while in combat. It records `issecretvalue(UnitPower("player", Enum.PowerType.ComboPoints))` in and out of combat.
  - `meters`: for each `Enum.PowerType` value, records the result of the power-type secrecy function if it exists (find its namespace with `grep -r GetPowerTypeSecrecy` in the Gethe `forever` branch). In combat it records whether the `C_DamageMeter` session values are secret.
  - `cdm`: lists the Cooldown Manager's categories and cooldown IDs through `C_CooldownViewer`, then in combat builds one KstyleUI-style icon per essential cooldown from that data, driving its `Cooldown` widget from the API's duration object. It records whether each call returned secret values and whether the mirrored icons matched Blizzard's viewer frames.
  - `presets`: records the Forever experience preset from the `GameRules` API (look up the exact getter in the Gethe `forever` branch's `GameRulesDocumentation.lua`), the active Edit Mode layout's preset type, and which of `PlayerFrame`, `TargetFrame`, `FocusFrame` and `MainActionBar` are shown.

- [ ] **Step 1: Write the files** and verify them with `luajit -bl` as in Task 10.

- [ ] **Step 2: Commit**

```bash
git add Tools/spikes
git commit -m "test: add spikes for paging, combat text, auras, meters and presets"
```

---

### Task 12: Ability data extraction

**Files:**
- Create: `Tools/icons/abilities.py`, `Tools/tests/test_abilities.py`, fixtures `Tools/tests/fixtures/db2/SkillLineAbility.csv`, `SkillLine.csv`, `SpellName.csv`, `SpellMisc.csv`, `ChrClasses.csv`, `ChrRaces.csv`
- Generate: `Tools/data/abilities.json` (excluded from the 400-line limit)

**Interfaces:**
- Produces: `python3 Tools/icons/abilities.py --build <version> [--from-dir DIR] --out Tools/data/abilities.json`.
  - Without `--from-dir`, it downloads `https://wago.tools/db2/<Table>/csv?build=<version>` for each table into `Tools/data/db2cache/<version>/`. It sends a `User-Agent` of `KstyleUI-tools`. It stops with a clear error if a response is not CSV (first line has no comma, or the content type is `text/html`).
  - It writes the output file only after every table parses, through a temporary file and `os.replace`.
- Produces: `abilities.json` = `{ "build": str, "icons": [ { "icon": int, "school": int, "spells": [ { "id": int, "name": str, "owner": str } ] } ] }`, sorted by `icon` and then spell `id`. `owner` is a class token such as `WARRIOR`, a race token for racials, or a profession name.
- Functions: `load_csv(path) -> list[dict]`, `build_abilities(tables) -> list[dict]`, `group_by_icon(abilities) -> list[dict]`.

Classify each `SkillLineAbility` row through its `SkillLine.CategoryID`: class skill lines (category 7), racial lines (category 12 or a `RaceMask` with no class), and professions (categories 9 and 11). Read the icon file ID and school mask from `SpellMisc`. Check the real column names against the downloaded CSV headers and use them in the fixtures exactly.

- [ ] **Step 1: Write the fixtures and the failing tests**: `test_groups_ranks_under_one_icon` (two Fireball ranks with one icon give one group with two spells), `test_classifies_class_racial_profession`, `test_skips_non_ability_lines`, `test_rejects_html_response` (the parser raises `ValueError` mentioning `not CSV`), `test_writes_atomically` (a failure leaves no partial file).

- [ ] **Step 2: Run them and see them fail**, then implement `abilities.py`, then run them and see them pass.

Run: `python3 -m unittest discover -s Tools/tests -v`
Expected: all OK.

- [ ] **Step 3: Generate the real data**

Run: `python3 Tools/icons/abilities.py --build 1.60.1.70840 --out Tools/data/abilities.json`
Expected: between 500 and 1,200 icon groups, every playable class present, and the group for Fireball's icon listing every Fireball rank. If wago.tools still returns 503, record that in the PR, export the same tables from the local client read-only with a CASC tool, and rerun with `--from-dir`.

- [ ] **Step 4: Spot-check against Wowhead Forever.** Look up 10 random spells by hand. Each one's name and icon must match.

- [ ] **Step 5: Commit**

```bash
git add Tools/icons Tools/tests/test_abilities.py Tools/tests/fixtures Tools/data/abilities.json
git commit -m "build: extract Forever ability icons from game data"
```

---

### Task 13: In-game spike session

**Files:**
- Create: `docs/superpowers/spikes/2026-11-spike-results.md`

**Interfaces:**
- Consumes: the spike addon from Tasks 10 and 11.
- Produces: one answer per spike question in the spec, each with the evidence from `KstyleUISpikeDB` and the decision it unblocks.

- [ ] **Step 1: The owner installs the spike.** Run `bash Tools/dev/link-addons.sh --spike`, then restart the game.

- [ ] **Step 2: The owner runs the spikes** with the steps in `Tools/spikes/KstyleUI_Spike/README.md`:
  - `/kspike fonts`, `scale`, `encoding`, `textures` and `presets` anywhere, on each available screen.
  - `paging` while changing stance or form, and while stealthing.
  - `combat` and `auras` during a dungeon boss pull.
  - `meters` and `cdm` in combat.
  - Then `/reload`.

- [ ] **Step 3: Read the results.** Parse `/Applications/World of Warcraft/_forever_/WTF/Account/*/SavedVariables/KstyleUI_Spike.lua` and write each answer into the results doc. Show the font panel screenshots to the owner and record the font they pick.

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/spikes
git commit -m "docs: record Phase 0 spike results"
```

**Phase 0 exit:** CI is green, KstyleUI loads in game, the results doc answers every spike question, and `abilities.json` is merged. Then write the Phase 1 plan.
