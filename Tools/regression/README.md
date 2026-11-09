# Regression tests

`run-all.sh` runs every `test-*.lua` in this folder from the repository root and prints the last 5 lines of each failing test. Tests run in parallel, `JOBS` at a time (default: the number of CPUs), and report in file order; a test must write only to its own temporary paths. `run-all.sh` starts `run_all.py`, which does the work.

```bash
bash Tools/regression/run-all.sh
```

To see a failing test's full output, run that test alone, for example `lua5.1 Tools/regression/test-taint-scan.lua`.

## Interpreter

CI runs the tests with Lua 5.1 on Ubuntu. With no `LUA` set, `run-all.sh` picks the first of these and prints its choice on the first line:

1. `lua5.1` on the `PATH`. This is what CI runs.
2. `~/.local/bin/lua5.1`. `bash Tools/dev/install-lua51.sh` builds Lua 5.1.5 there; Homebrew has no Lua 5.1.
3. `luajit -joff`, LuaJIT with its compiler off. Its speed is within 10% of Lua 5.1's on this suite. It is not the same interpreter: it accepts `goto`, and `test-widgets-statusbar` fails its allocation check in about one run in ten under it.

`LUA=luajit bash Tools/regression/run-all.sh` is fast mode, for quick iteration only. LuaJIT's compiler runs some tests 100 times faster than Lua 5.1. A test that took 0.5 s in fast mode took 53 s under Lua 5.1 and pushed CI past its 15-minute limit. Fast mode times do not predict CI, so run without `LUA` before a push.

## Time and memory budget

Each test file has a budget. `run-all.sh` fails a file that goes over it and names the fix:

```text
FAIL test-groupframes-depth: took 57.4 s, over the 20 s budget. Make the test cheaper; CI runs Lua 5.1, about 4 times slower than this Mac.
FAIL test-groupframes-depth: peaked at 10028 MB, over the 4096 MB budget. Make the test use less memory; CI runs 4 test files at once on 16 GB.
```

- **Time.** The budget is 20 s of wall time under Lua 5.1 on the Mac. CI's runner is about 4 times slower, so when `CI=true` the budget is 80 s. On 2026-11-09 the slowest file took 9.8 s here.
- **Memory.** The budget is 4096 MB of peak resident memory. CI runs 4 files at once on a 16 GB runner, and a file over the budget can push the runner into swap. On 2026-11-09 the largest file peaked at 2.8 GB.
- **Stop.** A file still running at 3 times the time budget is stopped and fails.

After the results, `run-all.sh` prints the five slowest files with their time and peak memory, then the total test time, the wall time and the number of jobs. The last line is always `passed N, failed M`. `TEST_TIME_BUDGET` (seconds) and `TEST_MEMORY_BUDGET` (MB) change the budgets for the runner's own tests in `Tools/tests/test_run_all.py`. CI never sets them.

When a file goes over a budget, make it cheaper: build fewer frames, run fewer rounds, or split it into two files. Never raise the budget to make a file pass.

## Files

Each `test-*.lua` file is one test. The other files are shared by the tests:

| File | What it does |
| --- | --- |
| `run_all.py` | Runs the test files for `run-all.sh`: picks the interpreter, runs the files in parallel and checks each one's time and memory budget. |
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
| `measure.lua` | Times a call and counts the memory it allocates with the garbage collector stopped, and names the addon lines that allocate. `perf_runner.lua` runs it for `test-perf.lua` and `test-perf-frames.lua`. |
| `perf/` | The combat paths `test-perf.lua` and `test-perf-frames.lua` measure, one file per addon folder, split between them by `perf_runner.lua`. |
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

`test-perf.lua` and `test-perf-frames.lua` measure every combat path registered in `perf/`. A path fails when:

- Its average time per call is over its budget.
- It allocates memory on an addon line. The spec allows no allocation in a combat path.
- It reports an error while it runs.

`measure.lua` calls the path 10 times to fill caches, then runs 5 rounds of 1,000 calls with the garbage collector stopped. The time is the CPU time per call in the fastest round, so a round that another process slowed does not set it. When the rounds allocate, it runs 1,000 more calls under a debug hook that charges each allocation to the line that ran it, so a line that allocates only on some calls is found too; the hook costs about fifty times a plain call, which is most of a perf test's time. Memory that a C function such as `string.format` allocates is charged to the Lua line that called it. Only lines in files outside `Tools/` count against the path, so memory that a stub or a fake allocates, such as a duration object from `UnitCastingDuration`, never fails it. A line that allocates less often than once in 1,000 calls can escape the trace. `measure.lua` switches LuaJIT's compiler off, because the game runs an interpreter and a compiled trace is itself an allocation.

The paths run as two test files so each stays well inside its 20 s budget while run-all runs 18 files at once: `test-perf.lua` measures the core, action bar, combat text, cooldown, group frame and meter files, and `test-perf-frames.lua` the nameplate and unit frame files. `perf_runner.lua` holds the two lists (`GROUPS`) and fails both files when a `perf/` file sits in neither, or in both.

A path that fails on time alone (over budget, or under the headroom rule below) is measured again, up to 3 attempts in all, and its fastest attempt counts; the printed line then says `(fastest of N attempts)`. An allocation never clears on another attempt. When a failure stands, the report ends with the machine's load average, so a run that failed under five parallel test runs can be told from a real regression (round 3 to 5 of the ranking loop saw `test-perf` fail a different untouched path on each loaded run).

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
