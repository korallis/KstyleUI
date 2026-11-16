# Regression tests

`run-all.sh` runs every `test-*.lua` in this folder from the repository root and prints the last 5 lines of each failing test. Tests run in parallel, `JOBS` at a time (default: the number of CPUs), never more than the machine-wide worker slots allow (below), and report in file order; a test must write only to its own temporary paths. `run-all.sh` starts `run_all.py`, which does the work.

```bash
bash Tools/regression/run-all.sh                            # every file, as CI's lua shards together run them
bash Tools/regression/run-all.sh --affected origin/staging  # only the files a change can reach
bash Tools/regression/run-all.sh --shard 2/4                # slice 2 of 4, how CI splits the files across jobs
```

To see a failing test's full output, run that test alone, for example `lua5.1 Tools/regression/test-taint-scan.lua`.

## Modes

CI runs the whole suite once per pull request head and once per push to `staging`, as two `--shard I/2` jobs. A developer's pre-push run is `--affected`. The full run with no argument is for reproducing a CI failure.

| Option | What it runs | Last line |
| --- | --- | --- |
| none | Every `test-*.lua` | `passed N, failed M` |
| `--shard I/N` | Slice I of N of the files. The first line after the budget says `shard I/N: X of Y test files`. | `passed N, failed M` for the slice |
| `--affected [BASE]` | The files that load something changed against BASE (default `origin/staging`) | `passed N, failed M (affected mode: X of Y test files ran; the other Z did not, and CI runs them all)` |
| `--margins` | The files one at a time, then the files within 20% of a budget | `passed N, failed M` |
| `--write-weights` | Every file, then writes `weights.json` | `passed N, failed M` |

`--shard`, `--affected` and `--margins` can be combined with each other, but none of them with `--write-weights`. A shard exits 0 only when its own files pass; CI requires both Lua shard jobs and the parallel `lint, python and package` job to pass.

### Shards and weights

`weights.json` holds each file's time in seconds on the Mac. `--shard` puts the heaviest file in the lightest slice first, so every slice takes about the same time (4 slices: 72, 72, 72 and 72 s of test time against 76, 55, 95 and 61 s for taking every fourth file). A file with no weight counts as the median, so a new test file needs no entry and a stale entry does no harm. Every run starts the heaviest files first. Refresh the weights with `bash Tools/regression/run-all.sh --write-weights` when the slices drift apart by more than a third; it is not part of a pull request's checks.

### Affected mode

`--affected BASE` compares the working tree (staged, unstaged and untracked files included) with the merge base of BASE and HEAD, and runs the test files whose record meets a changed file. It prints how many files it runs and why each one runs.

When a changed file is an addon `.lua` file (anything outside `Tools/` and `docs/`) or is under `Tools/locale/`, `--affected` also runs `python3 Tools/locale/strings.py check`, which is the cheap part of `test_locale_strings` in CI's Python job. A failure prints `FAIL locale`, each problem and the fix (`python3 Tools/locale/strings.py sync`, then commit `Tools/locale` and `Core/Locales`), and counts as one failed file. A change that touches neither skips it.

What a test file loads comes from running it, not from its name. `trace.lua` is loaded before the test through `LUA_INIT` and writes each file the test opens for reading (`io.open`, `io.lines`, `dofile`, `loadfile`) and each listing it makes through `fs.lua`, the only file that runs shell commands (`test-shell-guard.lua`). `affected.py` turns that into a record per test file:

- **files:** the files read. A change to one of them selects the test. The test file itself counts.
- **listings:** the folders a test listed with `fs.list`, each with its glob (`KstyleUI_*`, `Tools/render/scenes/gallery_*.lua`). A name that appears or disappears in the folder selects the test: an added or deleted file there, or a file in a new or removed subfolder whose name the glob matches.
- **names:** the patterns a test passed to `fs.tracked` (`git ls-files`). An added or deleted file that matches selects the test.

Each record carries a hash of its test file, so a record made from another version of the test (another worktree changed it) does not count and the test runs. The records live in `~/.cache/kstyleui/regression-deps.json` (`KSTYLEUI_DEPS_CACHE` moves it), shared by every worktree of the Mac, outside the repository so branches never conflict on it. A test file that passes is traced and its record is replaced; a test file that fails keeps its old record, or has none and runs next time. Delete the file to rebuild every record; the next `--affected` run then runs and traces every test file.

The choice is conservative in these cases:

- A test file with no record runs.
- Every file runs when a changed file is one of `SHARED_PATHS` in `affected.py` (the runner, `trace.lua`, `fs.lua`, `stubs/`, the `*_env.lua` helpers, `load_files.lua`, `toc_files.lua`, `.luacheckrc`), or when 10 or more test files, and at least half of them, load the changed file. In practice a change under `Core/` runs everything.
- The source guards in `GUARDS` (the scanners and loaders that read the whole tree) run on every affected run, even when nothing they read changed.
- A module's own TOC or XML only lists that module's files, so a change to `KstyleUI_<Module>/*.toc` or `*.xml` selects the tests that load that module's Lua files, not every test that walks the TOCs.

What it cannot see: a file a test reads through a path it builds at run time is recorded when the test last passed, not when it will next run; a dependency that appeared after the record was made is missed until the test runs again. The record also cannot see files outside the repository; no test reads one. CI runs every file, so a miss here is caught there, and the run says so on its last line.

It uses `JOBS` files at a time, a third of the CPUs by default (6 on the 18-CPU Mac). The full run asks for all the CPUs, and the worker slots below hold it to their count.

## Worker slots

Every run takes a **worker slot** per test file, so all local runs together use at most a third of the CPUs by default (6 on the 18-CPU Mac, leaving room for the game). `KSTYLEUI_SLOTS` sets the count; `KSTYLEUI_SLOTS=0` disables it. A run waits and polls when every slot is held; waiting does not consume a test's CPU budget.

Each slot is a lock file, `~/.cache/kstyleui/worker-slot-N.lock` (`KSTYLEUI_SLOT_DIR` moves the folder), held with nonblocking `flock` on POSIX or `msvcrt.locking` on Windows. The OS releases a crashed or killed runner's locks. A hung runner keeps its slots until it exits or is killed; stop only a runner you started, by its PID. The runner never kills a process it did not start, and nobody needs a `pkill` or a full-suite `lockf`. On a GitHub-hosted runner `CI=true` turns the limit off, because that runner has no other runs. CI's self-hosted Mac runners set `RUNNER_ENVIRONMENT=self-hosted`, so there CI takes slots like any other run on the Mac.

Each completed file prints `progress: N/T test files done`. Each file also prints `usage: NAME cpu=SECONDS wall=SECONDS peak_mb=MB`, including passing files, so CI logs contain calibration data. Load averages print `n/a` where the OS does not provide them. The summary reports slot waiting separately from test wall time.

### Margins

`bash Tools/regression/run-all.sh --margins` runs files serially and lists those using at least 80% of their CPU or peak memory budget. Wall time does not determine this list. Runs that are not budgeted have no budget margins.

## Interface size in tests

`Stubs.NewEnv` takes a `size` option: the Appearance page's Interface size the addon starts at. It is 1 by default, so a root unit is a whole number of pixels on the stub screens and a module test can measure exact unit sizes; `load_files.lua` applies it once `Core/Appearance.lua` registers its defaults. Pass `size = "default"` to test the size KstyleUI ships (`Scale.DEFAULT_USER_SCALE`, 16 / 19), as `test-hud-scale.lua`, `test-appearance.lua` and the owner's screen in the setup tests do. The render scenes always use the shipped size (`Common.ForceScreen`). The Lumen layouts are drawn on the shipped canvas (`Setup.Layouts.HEIGHT`) whatever the size.

Reference-unit fixtures isolate the fit cap: `load_files.lua` supplies their unrestricted 1.5 maximum. Pass `fit = true` to exercise the production preset-fit calculation at a numeric size; `size = "default"` and render scenes enable it automatically. `test-setup-collisions.lua` explicitly opts into it across nine screens, three requests and all three presets. `test-pixels.lua` checks unbounded pixel arithmetic; `test-text-pixels.lua` builds modules once and drives live display/size changes through production fit and restyle callbacks. Its optional `STUB_ENVS` collector and `STUB_FONT_ORIGINS` marker distinguish addon setters from scene stand-ins: engine-sized world numbers and manually copied chat lines are not addon font setters.

## Centre clearance matrix

`test-centre-clearance-<preset>-<class>.lua` covers all nine screens in each DPS, Tank and Healer preset for rogue, druid cat, druid bear and paladin (108 cases). Each case builds the real UnitFrames and Cooldowns scenes through `Setup.Apply`, at the shipped Interface size, with both casts, six essential and four utility cooldowns, five tracked buffs, two tracked bars, two target debuffs and every supported secondary resource visible. Shifted druid casts and rogue First Aid are synthetic lane-stress states, not class-mechanics tests. Paladin is the no-secondary-resource control.

The common `centre_clearance_lib.lua` assigns the renderer's actual visible texture/text rectangles to logical body, portrait, level, cast, aura, resource and cooldown components. It includes captions, countdowns, counts, chrome and empty tracks rather than using a Layout holder's enclosing rectangle. An unclaimed drawn asset fails, so a new screen-level asset cannot silently escape the measurement. It requires every intended item to paint with positive area, every asset to stay on screen, and every pair of different components to avoid overlap and clear both 4 root units and 3 physical pixels (0.001 rounding tolerance for the renderer's four-decimal coordinates). Internal widget composition is one component; the only cross-component exceptions are `player.level/player.portrait` and `target.level/target.portrait`, the attached level discs. The separate target cast holder is off; the test measures the target's inline cast. `test-centre-clearance.lua` proves overlap and both thresholds fail independently.

The twelve matrix files split by class/form and preset, with collection between screens, so no file retains the whole matrix or approaches the Lua 5.1 time/memory budget. Measure them with `bash Tools/regression/run-all.sh --affected origin/staging --margins`. They test the normal automatic path (essential/utility mirrors, tracked buff/bar native reskins), not hand-saved layouts or native Essential/Utility fallback; those need their own native-template and managed-flow fixture.

## Property tests

Three test files check properties on random cases instead of fixed ones. `property_lib.lua` makes each case from a seed and the case number with its own generator (Park and Miller's, exact in both Lua 5.1 and LuaJIT), so the same seed and case give the same case on every machine.

| File | Property | Default cases |
| --- | --- | --- |
| `test-property-layout.lua` | At random screens from 1024 x 768 to 7680 x 2160 (4:3, 3:2, 16:10, 16:9, 21:9 and 32:9, and ratios between), Interface sizes, HUD widths, both HUD styles and arrangements, the three layouts and random optional bars, every element Layout places from its defaults (stand-ins of each element's footprint, bar 2 split under Orbs as `Bar:Layout` does, and the quest card) lies on screen with its edges on whole physical pixels, the orbs (placed and clamped as `Orbs.lua` does) lie on screen, and no two elements the fit check keeps apart overlap, the orbs included. | 60 |
| `test-property-pixels.lua` | At random screens and sizes, `Scale.Pixel(1)` is one physical pixel, `Scale.Snap`, `Geometry.Align`, `Geometry.SnapSize` and `Widgets.Snap` give whole pixels and snap a snapped value to itself, no positive size snaps below one pixel, and `Scale.Nearest` gives a whole size step inside the allowed range. | 100 |
| `test-property-migrations.lua` | Random saved data (missing keys, wrong types, damaged profiles and layouts, any version) loads without an error at the current version (newer data keeps its own), loads again unchanged, and each migration run twice on data aimed at the fields it reads changes nothing the second time. | 80 |

These environment variables steer them:

- `KSTYLE_PROPERTY_ITERATIONS`: the number of cases. The defaults keep each file near 5 s under Lua 5.1, well inside the 20 s budget. The nightly verification run sets it high: 2000 for the layout file and the pixel file and 3000 for the migration file take about 3, 2 and 4 minutes under Lua 5.1. `run-all.sh` holds files to its budget, so run the files alone with `lua5.1` for that.
- `KSTYLE_PROPERTY_SEED`: the seed, a whole number. The default, 20261114, keeps every pull request's run the same; the nightly run passes a new one each night.
- `KSTYLE_PROPERTY_CASE`: run that one case alone.
- `KSTYLE_PROPERTY_ALL=1`: report every failing case before failing, not only the first.

A failure prints the seed, the case number, the case and the command that runs it again:

```text
property "layout at any screen" failed at case 18 of seed 20261114: actionbars.bar3 overlaps actionbars.pet
  case: 4236x1495 Healer orbs spread, HUD width full, size automatic (...)
  reproduce: KSTYLE_PROPERTY_SEED=20261114 KSTYLE_PROPERTY_CASE=18 lua5.1 Tools/regression/test-property-layout.lua
```

A bug a property finds is filed, and until it is fixed the file's `known` list claims its violations, and only those, by the issue code, so the suite stays green and the run prints `known failure LEE-n` with its first case. Fixing the bug means deleting its entry. The fix also adds the failing seed and case to the file's `regressions` list, which every run checks first whatever its seed, so the case stays covered after the seed changes.

## Interpreter

CI runs the tests with Lua 5.1.5 on the owner's self-hosted Mac runners. With no `LUA` set, `run-all.sh` picks the first of these and prints its choice on the first line:

1. `lua5.1` on the `PATH`. This is what CI runs.
2. `~/.local/bin/lua5.1` (`lua5.1.exe` on Windows). `bash Tools/dev/install-lua51.sh` builds Lua 5.1.5 on POSIX and installs the SHA-256-checked LuaBinaries 5.1.5 Win64 archive plus luacheck 1.2.0 on Windows; Homebrew has no Lua 5.1.
3. `luajit -joff`, LuaJIT with its compiler off. Its speed is within 10% of Lua 5.1's on this suite. It is not the same interpreter: it accepts `goto`, and `test-widgets-statusbar` fails its allocation check in about one run in ten under it.

`gate.sh` and `run-all.sh` choose Python in this order: `$KSTYLEUI_PYTHON`, `~/.local/share/wow-dev/venv/bin/python` or `Scripts/python.exe`, `py -3`, `python3`, `python`. Each candidate must run `-c 'import sys'`; a Microsoft Store alias that fails the probe is rejected. The command uses a Bash array, and `KSTYLEUI_PYTHON` exports its resolved executable for child scripts. A quoted `LUA` path may contain spaces and Windows backslashes.

`LUA=luajit bash Tools/regression/run-all.sh` is fast mode, for quick iteration only. LuaJIT's compiler runs some tests 100 times faster than Lua 5.1. A test that took 0.5 s in fast mode took 53 s under Lua 5.1 and pushed CI past its 15-minute limit. Fast mode times do not predict CI, so run without `LUA` before a push.

## Time and memory budget

Each test file has a **20 CPU second** and **4096 MB** budget under the default PUC Lua 5.1.5 interpreter. CPU time is user plus system time: POSIX `wait4` supplies it alongside `ru_maxrss`; Windows `GetProcessTimes` and `PeakPagefileUsage` supply process CPU time and peak committed memory. Peak committed memory cannot be hidden by working-set trimming. Measurements are collected after exit; missing measurements print `n/a` and an explicit `not budgeted` note. Wall time remains in the summary and sharding weights, so the scheduler is unchanged.

`CI=true` does not change the budgets. The runner probes `_VERSION == "Lua 5.1"`, `jit == nil`, and the `Lua 5.1.5` release banner before applying them. Any `LUA` override, including an empty override, and LuaJIT with or without `-joff` print **not budgeted**. Functional failures still fail those runs. `TEST_TIME_BUDGET` (CPU seconds) and `TEST_MEMORY_BUDGET` (MB) override the limits for runner checks; CI does not set them.

A separate **120 second wall-clock hang guard** applies to every interpreter. POSIX kills the owned process group; Windows kills and waits for the direct test process. Tests must limit shell children to short commands. CPU and memory failures name the fix: make the file cheaper, use less memory, or split it. Never raise a budget without measured calibration evidence.

The perf tests retain their existing per-call clock measurements and allocation checks. On POSIX, `os.clock` measures CPU time: budgets must be at least **five times** the measured PUC Lua 5.1 time, including in CI. Windows MSVC `os.clock` measures wall time, so `HeadroomProblem` prints a skip note there; per-call time and allocation checks still run. LuaJIT also skips the PUC headroom check rather than estimating PUC speed.

### Runtime portability

`test-lua-runtime.lua` records the seeded random hash, large integer formatting, infinity and NaN spelling. The measured seed-7 hashes are 708739911 on macOS and 1701382795 on Windows LuaBinaries 5.1.5; Windows also prints -2147483648 for `%d` of 2^40 and `1.#INF` / `-1.#IND`. No fixture requires those spellings or wide `%d` conversion; numeric infinity/NaN and the integer range fixtures use remain asserted.

The only existing random consumer is `test-ornament-tiers.lua`: it removes random subsets of assets and asserts that every drawn piece exists and resolves to an available tier, with a coverage floor of 1000 pieces, rather than expecting any particular draw. Both platform sequences pass those assertions. The runtime probe rejects additional `math.random` callers: new fixtures must use `property_lib.lua`'s portable generator. The property tests already do. This keeps the installed, isolated Lua 5.1.5 build instead of changing its C runtime to imitate another platform.

### CPU calibration (2026-11-16)

Per-file CPU and wall measurements for both Mac CI runners and Windows are captured in the PR's calibration logs. Platform factors are added only from those measurements; calibration is pending the first instrumented CI run.

## Files

Each `test-*.lua` file is one test. The other files are shared by the tests:

| File | What it does |
| --- | --- |
| `run_all.py` | Runs the test files for `run-all.sh`: picks the interpreter, picks the files for `--shard` and `--affected`, runs them in parallel and checks each one's time and memory budget. |
| `runner_platform.py` | OS slot locks, process stopping and peak-memory/CPU accounting; its injectable Windows paths are tested on every OS. |
| `affected.py` | Reads `trace.lua`'s record of what a test loads, keeps it in a cache and chooses the files a change can reach. `Tools/tests/test_affected.py` covers it. |
| `trace.lua` | Records the files a test opens and the commands it runs, for `--affected`. It changes no result a test sees. |
| `render_locales_lib.lua` | The settings-scene render check for one locale; the four `test-render-scenes-locale-*.lua` files call it so they run in parallel. |
| `weights.json` | Each test file's time in seconds, which `--shard` balances by. |
| `toc_files.lua` | Lists the files the game loads, in load order, from the TOCs and their XML includes. |
| `load_files.lua` | Runs addon files in a stub environment with the addon's `...` arguments. |
| `stubs/wow.lua` | A stub WoW API for offline tests. Extend it additively. |
| `widget_env.lua` | Loads the core with the widget kit, boots it, and drives frames like a player: hover, press, click, keys and tween frames. |
| `render_scenes_lib.lua` | Loads the render scene scripts as libraries and checks a built scene for the `test-render-scenes-*.lua` tests, which split the scenes by area so each file stays short. |
| `spike_env.lua` | Loads the spike addon into a stub environment that fakes the game APIs its spikes call. |
| `actionbars_env.lua` | Loads the core and `KstyleUI_ActionBars` into a fake game with action slots, bindings, a pet and forms. Secure frames record protected calls made in combat, and a fake restricted environment runs the bars' page snippet. |
| `lua_source.lua` | Tokenizes Lua 5.1 source and walks it with block and local scopes. The source scanners use it. |
| `taint_scan.lua` | Finds taint risks in addon source. |
| `taint_allow.lua` | Loads and merges the taint-scan allow-list from `taint_allow/`. |
| `secret_lint.lua` | Finds unsafe uses of secret values and any use of the combat log. |
| `color_lint.lua` | Finds colour literals, which belong only in `Core/Tokens.lua`. `test-tokens.lua` runs it. |
| `measure.lua` | Times a call and counts the memory it allocates with the garbage collector stopped, and names the addon lines that allocate. `perf_runner.lua` runs it for `test-perf.lua`, `test-perf-frames.lua`, `test-perf-skins.lua` and `test-perf-hud.lua`. |
| `perf/` | The combat paths `test-perf.lua`, `test-perf-frames.lua`, `test-perf-skins.lua` and `test-perf-hud.lua` measure, one file per addon folder, split between them by `perf_runner.lua`. |
| `property_lib.lua` | The seeded generator and `Property.Check` for the property tests. |
| `fixtures/` | Inputs for the tests. luacheck skips this folder. |

## Taint scan

`test-taint-scan.lua` scans every TOC-loaded Lua file outside `Libs/`. Each finding has a kind, a call, and a line.

| Kind | Example call | What it finds |
| --- | --- | --- |
| `frame-call` | `PlayerFrame:SetScript` | A call, with `:` or with `.` and the frame as first argument, of `SetScript`, `Hide`, `SetParent`, `ClearAllPoints`, `SetPoint`, `SetAllPoints`, `SetSize`, `SetWidth`, `SetHeight`, `SetScale`, `UnregisterAllEvents`, `UnregisterEvent`, `RegisterEvent`, `EnableMouse`, `SetAttribute`, or `SetFrameStrata` on a Blizzard frame. |
| `field-write` | `PlayerFrame.unit` | A field written on a Blizzard frame or table, including `function PlayerFrame:OnEvent()`. |
| `game-table-write` | `UISpecialFrames[?]` | A write into `UISpecialFrames`, `UIPanelWindows`, or `hash_SlashCmdList`, also through `tinsert`, `tremove`, or `wipe`. A `StaticPopupDialogs` key without the `KSTYLEUI_` prefix. A `SlashCmdList` key without the `KSTYLE` prefix. An assignment to a Blizzard name. |
| `protected-unguarded` | `SetBinding` | A protected call with no `InCombatLockdown` and no `Combat.Queue` in the 40 lines before it. |
| `setparent-unguarded` | `self.icon:SetParent` | `SetParent` on any frame with no `EditModeManagerFrame:IsShown` and no `Safe.<name>` in the 40 lines before it. |
| `aura-unguarded` | `C_UnitAuras.GetAuraDataByIndex` | `C_UnitAuras` in a file that never calls `C_Secrets.ShouldAurasBeSecret` or `issecretvalue`. |

The protected calls are `PickupAction`, `PlaceAction`, `SetBinding`, `SetOverrideBinding`, `SetOverrideBindingClick`, `ClearOverrideBindings`, `CreateMacro`, `EditMacro`, `C_Container.PickupContainerItem`, `C_Container.UseContainerItem`, `TargetUnit`, `CastSpellByName`, `CastSpellByID`, `UseAction`, `C_Macro.RunMacroText`, `RunMacroText`, `ShowUIPanel`, and `HideUIPanel`.

A Blizzard name is a name in `Tools/data/forever_globals.lua` that does not start with `KstyleUI`. `_G.PlayerFrame` and `_G["PlayerFrame"]` count as `PlayerFrame`, and `_G[name]` counts as the Blizzard frame `_G[?]`.

The scan follows locals within a file:

- A local given a Blizzard path, such as `local f = PlayerFrame` or `local hb = PlayerFrame.healthbar`, counts as that path until it is reassigned or its block ends.
- A reassignment inside a nested block or function may not run, so it never clears that path.
- A local or parameter with a Blizzard name, such as `button` or `text`, hides the global.
- A key computed at run time shows as `[?]` in the call.

The scan does not follow values through function calls, parameters, or table fields. `self:Hide()` inside a hook on a Blizzard frame is not found.

## Taint allow-list

When the scan reports a finding, fix the code. If the call is safe, list it in the allow-list with the reason. The test fails on any finding the list does not cover.

The allow-list is one file per addon folder in `Tools/regression/taint_allow/`. A file lists only its own folder's files, so agents that build different modules never edit the same file:

- `Core.lua` covers `Core/`.
- `KstyleUI_UnitFrames.lua` covers `KstyleUI_UnitFrames/`.

Each file returns a table keyed by the file path from the repository root:

```lua
return {
	["KstyleUI_Tooltips/Tooltips.lua"] = {
		why = "GameTooltip is hidden on mouse-out, as Blizzard's own buttons do. It is not a layout frame.",
		calls = {
			["GameTooltip:Hide"] = 2,
		},
	},
}
```

- `why` is required. It says why each listed call is safe.
- `calls` maps each call, written exactly as the scan prints it, to the number of places in the file that make it.
- One place can give two findings with the same call: `PlayerFrame:SetParent` with no Edit Mode check is a `frame-call` and a `setparent-unguarded` finding. It still counts as one place.

The file runs with no globals and holds data only. The test fails when:

- A finding's call has no entry.
- A call is found in more or fewer places than its count.
- An entry matches no finding, or its path is not a TOC-loaded Lua file.
- An area file is not named after a folder, lists a path outside its folder, or has an entry without a `why`.

Each failure message names the file and line, and the area file to change.

## Secret lint

`test-secrets.lua` runs `secret_lint.lua` over every TOC-loaded Lua file outside `Libs/` and fails on any finding. It has no allow-list. When a use is safe, guard it with `issecretvalue`.

A secret source is `UnitHealth`, `UnitHealthMax`, `UnitHealthMissing`, `UnitHealthPercent`, `UnitInRange`, `UnitPower`, `UnitPowerMax`, `UnitCastingInfo`, `UnitChannelInfo`, `UnitGetIncomingHeals`, or any `C_UnitAuras` function. A secret value is a local given a secret source's result, directly, through `select` or `pcall`, or from another secret value. Each field of a secret value, such as `aura.duration`, is a secret value too.

| Kind | What it finds |
| --- | --- |
| `compare` | A secret value or a secret call next to `<`, `>`, `<=`, `>=`, `==`, or `~=`. |
| `arith` | A secret value or a secret call next to `+`, `-`, `*`, `/`, `%`, or `^`. |
| `length` | `#` before a secret value. |
| `key` | A secret value used as a table key or index: `t[hp]`, `{ [hp] = true }`. |
| `bool` | A secret value after `if`, `elseif`, `while`, `until`, or `not`, or before `and`, `or`, `then`, or `do`. |
| `combatlog` | Any name or string that holds `COMBAT_LOG_EVENT`, and `CombatLogGetCurrentEventInfo`. |

Passing a secret on is allowed: to a widget setter, to `AbbreviateNumbers`, into a table, or with `..`.

A use is guarded, and allowed, when a check `issecretvalue(x)` on the same path proves the value is not secret. `issecretvalue(aura)` does not guard `aura.duration`. The check guards a use in these cases:

- It comes earlier in the same expression, joined the right way: `not issecretvalue(hp) and hp < 10`, or `issecretvalue(hp) or hp < 10`.
- The use is in the branch of an `if` whose condition holds `not issecretvalue(hp)` and no `or`.
- The use is in a later `elseif` or `else` branch, and an earlier condition holds `issecretvalue(hp)` and no `and`.
- An earlier `if issecretvalue(hp) then ... end` in the same block has no `and` and no other branch, and its body returns or gives `hp` a value that is not secret.

A guard ends when the local is given a secret value after the check.

```lua
local hp = UnitHealth(unit)
if issecretvalue(hp) then
	bar:SetValue(hp)
	return
end
if hp < 10 then
	-- hp is a plain number here
end
```

The lint follows locals within a file. It does not follow values through function parameters or table fields such as `self.hp` and `t[1]`. A `while` condition does not guard the loop body, and a check on one local does not guard another local that holds the same value.

## Performance budget

`test-perf.lua`, `test-perf-frames.lua`, `test-perf-skins.lua` and `test-perf-hud.lua` measure every combat path registered in `perf/`. A path fails when:

- Its average time per call is over its budget.
- It allocates memory on an addon line. The spec allows no allocation in a combat path.
- It reports an error while it runs.

`measure.lua` calls the path 10 times to fill caches, then runs 5 rounds of 1,000 calls with the garbage collector stopped. The time is the CPU time per call in the fastest round, so a round that another process slowed does not set it. When the rounds allocate, it runs 1,000 more calls under a debug hook that charges each allocation to the line that ran it, so a line that allocates only on some calls is found too; the hook costs about fifty times a plain call, which is most of a perf test's time. Memory that a C function such as `string.format` allocates is charged to the Lua line that called it. Only lines in files outside `Tools/` count against the path, so memory that a stub or a fake allocates, such as a duration object from `UnitCastingDuration`, never fails it. A line that allocates less often than once in 1,000 calls can escape the trace. `measure.lua` switches LuaJIT's compiler off, because the game runs an interpreter and a compiled trace is itself an allocation.

The paths run as four test files so each stays well inside its 20 s budget while run-all runs 18 files at once: `test-perf.lua` measures the core, action bar, combat text, cooldown, group frame and meter files, `test-perf-frames.lua` the nameplate and unit frame files, `test-perf-skins.lua` the quest card's, and `test-perf-hud.lua` the data bars' and the minimap's. `perf_runner.lua` holds the lists (`GROUPS`) and fails every file when a `perf/` file sits in no group, or in two. A slow path can lower `calls` (the quest card's use 100) so its allocation trace, about fifty times a plain call, stays inside the file's time.

A path that fails on time alone (over budget, or under the headroom rule below) is measured again, up to 3 attempts in all, and its fastest attempt counts; the printed line then says `(fastest of N attempts)`. An allocation never clears on another attempt. When a failure stands, the report ends with the machine's load average (`KSTYLEUI_LOAD`, which the runner sets; without it the load is unknown and not printed), so a run that failed under five parallel test runs can be told from a real regression (round 3 to 5 of the ranking loop saw `test-perf` fail a different untouched path on each loaded run).

Before it measures, the test enters combat with `env.SetCombat(true)` and switches the stubs to quiet mode with `env.SetQuiet(true)`. In quiet mode:

- A frame records no calls in `_calls`, and a method lookup returns one shared function.
- A repeated `Set<X>` refills its stored table, and `SetPoint` and `ClearAllPoints` reuse the frame's point tables.
- `env.Secret(value)` returns one shared secret per value.

`RunTimers` reuses its timer lists in every mode. The stubs then add little time, and a path whose fakes allocate nothing skips the trace.

### Register a combat path

Each file in `perf/` is named after the addon folder it covers, as in `taint_allow/`, so agents that build different modules never edit the same file:

- `Core.lua` covers `Core/`.
- `KstyleUI_UnitFrames.lua` covers `KstyleUI_UnitFrames/`.

The file runs with the test's `Perf` helper as its argument and returns a list of paths:

```lua
local Perf = ...
local U = dofile("Tools/regression/unitframes_env.lua")

return {
	{
		name = "UnitFrames UNIT_HEALTH",
		budget = 30,
		setup = function()
			local env = U.New()
			return env, Perf.Event(env, "UNIT_HEALTH", "player")
		end,
	},
}
```

- `name` is unique across `perf/`. Start it with the module.
- `budget` is the time per call in microseconds. `lua5.1 Tools/regression/test-perf.lua` prints each path's time. Set the budget near 10 times the time Lua 5.1 prints. Use at least 10.
- `setup` builds a stub environment and returns it with the function to measure. It runs once.
- `calls`, optional, sets the calls per round and the trace. The default is 1,000.

`Perf.Event(env, event, ...)` returns a function that runs the `OnEvent` script of each frame registered for the event, with the arguments given, as the game dispatches it. It finds the frames on its first call and raises if no frame is registered. A path that runs on a timer, such as the threat meter's update, fires its event and then calls `env.RunTimers()`.

When a path fails for allocation, the message names the lines and the bytes per call:

```text
StatusBar SetBarColor: allocates 152 bytes per call: Core/Widgets/StatusBar.lua:78 (152 bytes)
```

Fix the line: reuse a table that the object owns, or pass values as arguments. A table built once at load time is not a per-call allocation.

### Calibrate a budget

A budget is set on the Mac and must also pass on CI, so it follows one rule: **set it near 10 times the time Lua 5.1 takes on the Mac.** The test fails a budget below 5 times that time and prints the value to use:

```text
Nameplates interrupt readiness flipping under three casts: budget 40 us is 2.8 times the 14.2 us Lua 5.1 takes here, and CI runs about 4 times slower; set it near 142 us (10 times)
```

- CI's runner takes about 4 times as long per call. On 2026-11-09 that path took 13 us under Lua 5.1 on the Mac and 51.9 us on CI, over its 40 us budget.
- 10 times leaves CI 2.5 times its usual time. The shared runner varies, and other test files run beside `test-perf`.
- LuaJIT's interpreter runs a path about 1.5 times faster than Lua 5.1, so under LuaJIT the test scales the time up by 1.5 before the check.
- On CI (`CI=true`) the test skips this check. There the budget itself is the check.
