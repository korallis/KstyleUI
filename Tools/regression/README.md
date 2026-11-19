# Regression tests

`run-all.sh` runs every `test-*.lua` in this folder from the repository root and prints the last 5 lines of each failing test. Tests run in parallel, `JOBS` at a time (default: the number of CPUs), never more than the machine-wide worker slots allow (below), and report in file order; a test must write only to its own temporary paths. `run-all.sh` starts `run_all.py`, which does the work.

```bash
bash Tools/regression/run-all.sh                            # every file, as CI's lua shards together run them
bash Tools/regression/run-all.sh --affected origin/staging  # only the files a change can reach
bash Tools/regression/run-all.sh --shard 2/4                # slice 2 of 4, how CI splits the files across jobs
```

To see a failing test's full output, run that test alone, for example `lua5.1 Tools/regression/test-taint-scan.lua`.

## Modes

CI runs the whole suite on hosted `ubuntu-latest` for pull requests as six `--shard I/6` jobs, and on self-hosted Macs for staging pushes and manual runs as two `--shard I/2` jobs. Staging always runs Lua, even with green PR markers, to check Mac CPU limits and cumulative instruction budgets. Hosted per-file CPU overruns and per-path CPU headroom warn; functional tests, instruction budgets, memory limits and hang guards still fail. A developer's pre-push run is `--affected`. The full run with no argument is for reproducing a CI failure.

| Option | What it runs | Last line |
| --- | --- | --- |
| none | Every `test-*.lua` | `passed N, failed M` |
| `--shard I/N` | Slice I of N of the files. The first line after the budget says `shard I/N: X of Y test files`. | `passed N, failed M` for the slice |
| `--affected [BASE]` | The files that load something changed against BASE (default `origin/staging`) | `passed N, failed M (affected mode: X of Y test files ran; the other Z did not, and CI runs them all)` |
| `--margins` | The files one at a time, then the files within 20% of a budget | `passed N, failed M` |
| `--write-weights` | Every file, then writes `weights.json` | `passed N, failed M` |

`--shard`, `--affected` and `--margins` can be combined with each other, but none of them with `--write-weights`. A shard exits 0 only when its own files pass; CI requires every Lua shard job and the parallel `lint, python and package` job to pass.

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

### Python test subprocesses

Python tests that bound a command use `Tools.tests.subprocess_budget.run(..., cpu_budget=N)` instead of `subprocess.run(..., timeout=N)`. Their existing limits are CPU seconds, with a separate wall-clock hang guard of `max(120, 5 * N)` seconds. Child accounting reuses `runner_platform.wait`: `wait4` on POSIX and `GetProcessTimes` on Windows. Windows accounts for the direct child; POSIX also includes descendants that child waited for. Shell-launcher tests retain the hang guard on both platforms. Captured input and output use temporary files so pipe buffers cannot deadlock the accounting wait.

Every command prints measured CPU and wall time. Failed commands include those measurements with their captured output; `CPU budget exceeded` says to make the test cheaper, while `hang guard` identifies the independent wall limit. CPU overruns fail on Mac CI and warn elsewhere, as in the Lua runner; missing CPU accounting fails on Mac CI rather than substituting wall time. LuaJIT reports `not budgeted` and still has the 120-second hang guard. `test_subprocess_budget.py` exercises an actual hung child with a shortened guard, checks the production floor and multiplier separately, and rejects fixed `subprocess.run` timeouts in Python tests with the replacement command in its failure message.

### Margins

`bash Tools/regression/run-all.sh --margins` runs files serially and lists those using at least 80% of their CPU or peak memory budget. Wall time does not determine this list. Runs without a CPU budget still report peak-memory margins. Allowance removal is a dedicated serial `--margins` calibration review: propose deleting a line only when the file is below 16 CPU seconds on every sampled Mac. Normal shard runs never expire an allowance from a single fast sample. LEE-5827 owns reducing these files and removing the lines; the list may only shrink.

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
3. `luajit -joff`, LuaJIT with its compiler off. These runs print `not budgeted`. It is not the same interpreter: it accepts `goto`, and `test-widgets-statusbar` fails its allocation check in about one run in ten under it.

`gate.sh` and `run-all.sh` choose Python in this order: `$KSTYLEUI_PYTHON`, `~/.local/share/wow-dev/venv/bin/python` or `Scripts/python.exe`, `py -3`, `python3`, `python`. Each candidate must run `-c 'import sys'`; a Microsoft Store alias that fails the probe is rejected. The command uses a Bash array, and `KSTYLEUI_PYTHON` exports its resolved executable for child scripts. A quoted `LUA` path may contain spaces and Windows backslashes.

`LUA=luajit bash Tools/regression/run-all.sh` is fast mode, for quick iteration only. LuaJIT's compiler runs some tests 100 times faster than Lua 5.1. A test that took 0.5 s in fast mode took 53 s under Lua 5.1 and pushed CI past its 15-minute limit. Fast mode times do not predict CI, so run without `LUA` before a push.

## Time and memory budget

The **Mac CI runners are the CPU budget of record**, using default PUC Lua 5.1.5. Their default file limit is **20 CPU seconds**. Windows and every non-CI run print a warning naming a file and its measured CPU time when it exceeds its CPU limit; they do not fail for CPU overruns. The **4096 MB peak-memory limit and hang guard fail everywhere**, including interpreter overrides. CPU time is user plus system time: POSIX `wait4` supplies it alongside `ru_maxrss`; Windows `GetProcessTimes` and `PeakPagefileUsage` supply process CPU time and peak committed memory. Peak committed memory cannot be hidden by working-set trimming. Measurements are collected after exit; missing measurements print `n/a` and an explicit `not budgeted` note. Wall time remains in the summary and sharding weights, so the scheduler is unchanged.

CPU limits fail only on macOS with `CI=true`; other platforms and local runs use them as warning thresholds. `cpu_allowances.tsv` holds the measured LEE-5827 exceptions: name, CPU seconds, ticket, one file per line. Every file whose worst recorded Mac time is **at least 16 CPU seconds** receives an allowance of that worst time plus 25%, rounded up to a whole second. The list currently has 53 files, with every raw worst value and source run in the allowance-input table below. This covers the 10-16% same-runner variation measured by verification; in particular, `test-text-floor.lua` initially measured 19.918132 CPU seconds (25-second allowance); its newer 20.662359-second maximum now receives 26 seconds. On Mac CI a listed file fails above its allowance and an unlisted file fails above 20 seconds. On Windows and non-CI runs both overruns are warnings. The runner rejects any added or changed baseline line against `origin/staging` locally or the shallow CI checkout's `HEAD^1`, once the initial approved list has merged; deletions remain allowed. The runner probes `_VERSION == "Lua 5.1"`, `jit == nil`, and the `Lua 5.1.5` release banner before applying CPU thresholds. Any `LUA` override, including an empty override, and LuaJIT with or without `-joff` print **not budgeted**. The memory limit, hang guard and functional failures still fail those runs. `TEST_TIME_BUDGET` (CPU seconds) and `TEST_MEMORY_BUDGET` (MB) override the limits for runner checks; CI does not set them.

The wall-clock hang guard is **max(120 seconds, five times the file CPU limit)**, including its allowance and platform factor. The 120-second floor applies when a run is not budgeted. POSIX kills the owned process group; Windows kills and waits for the direct test process. Tests must limit shell children to short commands. CPU diagnostics and memory failures name the fix: make the file cheaper, use less memory, or split it. Never raise a budget without measured calibration evidence.

The perf tests retain their existing per-call clock measurements and allocation checks. On POSIX, `os.clock` measures CPU time: budgets must be at least **five times** the measured PUC Lua 5.1 time, including in CI. Windows MSVC `os.clock` measures wall time, so `HeadroomProblem` prints a skip note there; per-call time and allocation checks still run. LuaJIT also skips the PUC headroom check rather than estimating PUC speed.

### Per-path noise calibration (2026-11-17)

Every `test-perf*.lua` budget lives in `Tools/regression/perf/*.lua`. Keep the fivefold PUC Lua 5.1 CPU headroom check unchanged; calibrate each budget to at least **5 x the worst observed per-call time x 1.25**. Round increases up to the next 5 microseconds and retain an existing budget when it already meets that minimum. This calibration raises 15 budgets and retains 39; allocation checks, file CPU allowances and other limits are unchanged. Keep LEE-5831 on the Skins quest-update budget.

Recent staging/PR `checks` logs inspected: [44005345315](https://github.com/korallis/KstyleUI/actions/runs/44005345315), [44000011724](https://github.com/korallis/KstyleUI/actions/runs/44000011724), [43998377644](https://github.com/korallis/KstyleUI/actions/runs/43998377644), [43996582309](https://github.com/korallis/KstyleUI/actions/runs/43996582309), [43995158154](https://github.com/korallis/KstyleUI/actions/runs/43995158154), [43993106012](https://github.com/korallis/KstyleUI/actions/runs/43993106012), [43987318285](https://github.com/korallis/KstyleUI/actions/runs/43987318285), [43984790448](https://github.com/korallis/KstyleUI/actions/runs/43984790448), [43981688505](https://github.com/korallis/KstyleUI/actions/runs/43981688505). The harness prints only the last five lines of failing tests and deletes its temporary output, so passing paths have no recoverable per-call samples in those logs. The CI column below records every available per-path maximum, including the 218 us target-change failure and 1313.46 us quest-update failure in PR #431 (rounded up to 1314 us for calibration); a dash means no per-path timing was logged. The target-change diagnostic rounds to three significant figures. These CI observations also enter the worst-time calculation.

To supply all 54 paths, run each of `test-perf.lua` (core), `test-perf-frames.lua` (frames), `test-perf-hud.lua` (hud) and `test-perf-skins.lua` (skins) directly and serially, five times per file, with `~/.local/bin/lua5.1` (PUC Lua 5.1.5) on the CI-class Mac mini. These samples used a fresh temporary clone of `staging` at `f083193cbf33b11a0f13ec0f6bbbec04245647ca`; the clone was deleted afterward. The table uses the worst of the five reported times, each already the harness's fastest round/attempt. Original budgets were retained during sampling, so some samples correctly reported insufficient headroom. Sample IDs below are `file group/sample number`; all times are CPU microseconds per call, and the budget covers the larger of the Mac sample and available CI time.

| Path | Worst Mac us | Sample | Worst logged CI us (run) | Budget us |
| --- | ---: | --- | --- | ---: |
| Glow Start and Stop | 3.68 | core/4 | - | 30 |
| StatusBar SetBarColor | 1.89 | core/5 | - | 15 |
| StatusBar SetBarTexture | 0.64 | core/1 | - | 10 |
| Effects Claim and Release a place | 0.81 | core/5 | - | 20 |
| Effects Allows at the current level | 0.70 | core/4 | - | 20 |
| Effects Burst into the 3D pool | 5.56 | core/1 | - | 120 |
| Effects vignette UNIT_HEALTH | 0.68 | core/3 | - | 20 |
| ActionBars ACTIONBAR_UPDATE_COOLDOWN | 19.39 | core/2 | - | 125 |
| ActionBars PET_BAR_UPDATE_COOLDOWN with a pet, tray card unchanged | 33.89 | core/1 | - | 215 |
| ActionBars pet appears and leaves in combat, tray card kept | 35.98 | core/5 | - | 750 |
| ActionBars key press flashes a slot | 0.97 | core/1 | - | 20 |
| ActionBars SPELL_ACTIVATION_OVERLAY_GLOW_SHOW and HIDE on a slot | 70.44 | core/5 | - | 445 |
| ActionBars Medallions ready flash on a slot | 6.47 | core/1 | - | 120 |
| ActionBars Medallions hub ring UNIT_POWER_UPDATE | 0.69 | core/1 | - | 20 |
| CombatText UNIT_COMBAT | 37.95 | core/2 | - | 250 |
| Cooldowns UNIT_AURA | 22.41 | core/3 | - | 160 |
| Cooldowns SPELL_UPDATE_COOLDOWN | 13.16 | core/1 | - | 85 |
| DataBars PLAYER_XP_UPDATE at Full, label unchanged | 12.63 | hud/2 | - | 300 |
| DataBars experience painted at Full, label unchanged | 6.43 | hud/1 | - | 150 |
| DataBars experience painted at Full, the label's width changes | 6.34 | hud/5 | - | 1400 |
| GroupFrames UNIT_HEALTH | 12.87 | core/1 | - | 90 |
| GroupFrames UNIT_FLAGS | 8.79 | core/4 | - | 55 |
| Meters threat Update | 28.98 | core/5 | - | 300 |
| Meters damage refresh, raid of twenty | 422.92 | core/1 | - | 2645 |
| Minimap clock tick at Full | 4.85 | hud/1 | - | 50 |
| Minimap zone change at Full, the name's width changes | 5.31 | hud/2 | - | 400 |
| Minimap face layout at Full, the card and its brackets placed again | 2.33 | hud/2 | - | 1000 |
| Nameplates UNIT_HEALTH | 4.16 | frames/1 | - | 30 |
| Nameplates UNIT_SPELLCAST_START | 3.93 | frames/2 | - | 50 |
| Nameplates SPELL_UPDATE_COOLDOWN while casting | 0.79 | frames/1 | - | 20 |
| Nameplates interrupt readiness flipping under three casts | 1.64 | frames/2 | - | 80 |
| Nameplates PLAYER_TARGET_CHANGED over three casting plates | 4.15 | frames/3 | - | 200 |
| Nameplates PLAYER_TARGET_CHANGED over forty plates with their overflow ghosts | 47.32 | frames/3 | - | 2000 |
| Nameplates NAME_PLATE_UNIT_ADDED recycling a plate among forty | 34.80 | frames/3 | - | 400 |
| Nameplates cast start and stop on one plate among forty, later casts | 9.38 | frames/2 | - | 110 |
| Nameplates raid mark onto a plate among forty, then its first cast | 36.54 | frames/1 | - | 300 |
| Nameplates forty-plate pull | 2126.25 | frames/1 | - | 17000 |
| Nameplates target change between two plates among forty, brackets | 107.44 | frames/2 | - | 1000 |
| Nameplates QUEST_LOG_UPDATE with a plate | 3.39 | frames/2 | - | 25 |
| Nameplates UNIT_FLAGS while casting | 5.87 | frames/2 | - | 40 |
| Skins quest card QUEST_LOG_UPDATE, 25 quests | 1308.14 | skins/3 | 1314 (1313.46 rounded up; [44005345315](https://github.com/korallis/KstyleUI/actions/runs/44005345315)) | 8215 |
| Skins quest card QUEST_LOG_UPDATE, 25 quests, an item button up | 507.91 | skins/4 | 497.91 ([43998377644](https://github.com/korallis/KstyleUI/actions/runs/43998377644)) | 3175 |
| Tooltips GameTooltip shown for two units of different size: the card resized and its fade played | 186.92 | core/3 | - | 1170 |
| UnitFrames UNIT_HEALTH | 7.94 | frames/1 | - | 50 |
| UnitFrames UNIT_HEALTH on the player: loss band, hit flash, spark and low-health curve | 9.13 | frames/2 | - | 60 |
| UnitFrames UNIT_POWER_UPDATE | 4.42 | frames/2 | - | 25 |
| UnitFrames UNIT_FLAGS | 11.23 | frames/2 | - | 95 |
| UnitFrames UNIT_THREAT_LIST_UPDATE | 1.97 | frames/5 | - | 15 |
| UnitFrames UNIT_THREAT_LIST_UPDATE for another unit | 1.03 | frames/1 | - | 10 |
| UnitFrames UNIT_SPELLCAST_START | 10.94 | frames/2 | - | 80 |
| UnitFrames target change at Full, rank changes | 209.78 | frames/3 | 218 ([44000011724](https://github.com/korallis/KstyleUI/actions/runs/44000011724)) | 1365 |
| UnitFrames Orbs UNIT_HEALTH | 4.37 | frames/2 | - | 30 |
| UnitFrames Orbs UNIT_POWER_UPDATE | 2.54 | frames/1 | 2.38 ([43993106012](https://github.com/korallis/KstyleUI/actions/runs/43993106012)) | 20 |
| UnitFrames Medallions cast flash | 6.59 | frames/2 | 6.36 ([43993106012](https://github.com/korallis/KstyleUI/actions/runs/43993106012)) | 200 |

Load at the start of every sample (UTC on 2026-11-17); these are the 1-, 5- and 15-minute load averages, not timing multipliers:

| Sample | UTC | Load 1 min | Load 5 min | Load 15 min |
| --- | --- | ---: | ---: | ---: |
| core/1 | 02:24:51 | 9.57 | 10.03 | 9.08 |
| core/2 | 02:25:19 | 9.61 | 9.99 | 9.10 |
| core/3 | 02:25:50 | 9.48 | 9.93 | 9.10 |
| core/4 | 02:26:14 | 9.40 | 9.88 | 9.10 |
| core/5 | 02:26:41 | 8.89 | 9.72 | 9.07 |
| frames/1 | 02:27:03 | 8.98 | 9.68 | 9.07 |
| frames/2 | 02:27:19 | 9.14 | 9.67 | 9.08 |
| frames/3 | 02:27:34 | 9.20 | 9.66 | 9.09 |
| frames/4 | 02:27:50 | 9.45 | 9.69 | 9.11 |
| frames/5 | 02:28:04 | 8.90 | 9.56 | 9.07 |
| hud/1 | 02:28:19 | 10.31 | 9.81 | 9.17 |
| hud/2 | 02:28:21 | 10.31 | 9.81 | 9.17 |
| hud/3 | 02:28:23 | 10.31 | 9.81 | 9.17 |
| hud/4 | 02:28:25 | 10.84 | 9.93 | 9.21 |
| hud/5 | 02:28:27 | 10.84 | 9.93 | 9.21 |
| skins/1 | 02:28:30 | 10.53 | 9.88 | 9.20 |
| skins/2 | 02:28:41 | 10.45 | 9.88 | 9.21 |
| skins/3 | 02:29:07 | 9.77 | 9.77 | 9.18 |
| skins/4 | 02:29:33 | 9.60 | 9.72 | 9.18 |
| skins/5 | 02:29:52 | 9.65 | 9.73 | 9.20 |

Reproduce sampling in a disposable clone with `for file in Tools/regression/test-perf*.lua; do for sample in 1 2 3 4 5; do date -u; uptime; ~/.local/bin/lua5.1 "$file"; done; done`. Save the full output before deleting the clone; standard CI logs alone cannot reconstruct passing per-path measurements.

### Runtime portability

`test-lua-runtime.lua` records the seeded random hash, large integer formatting, infinity and NaN spelling. The measured seed-7 hashes are 708739911 on macOS and 1701382795 on Windows LuaBinaries 5.1.5; Windows also prints -2147483648 for `%d` of 2^40 and `1.#INF` / `-1.#IND`. No fixture requires those spellings or wide `%d` conversion; numeric infinity/NaN and the integer range fixtures use remain asserted.

The only existing random consumer is `test-ornament-tiers.lua`: it removes random subsets of assets and asserts that every drawn piece exists and resolves to an available tier, with a coverage floor of 1000 pieces, rather than expecting any particular draw. Both platform sequences pass those assertions. The runtime probe rejects additional `math.random` callers: new fixtures must use `property_lib.lua`'s portable generator. The property tests already do. This keeps the installed, isolated Lua 5.1.5 build instead of changing its C runtime to imitate another platform.

### CPU calibration (2026-11-16)

The table records the 20 slowest files in the initial calibration, before the later perf recalibration listed below. Mac columns name `mac-KstyleUI-1`, `-2` and `-3`; a dash means no sample on that runner. Every file has samples from at least two Mac runners. Values are user plus system CPU seconds, not wall time.

Mac evidence: [full run 43943487980](https://github.com/korallis/KstyleUI/actions/runs/43943487980), [cross-run 43944756619](https://github.com/korallis/KstyleUI/actions/runs/43944756619), and the completed 30-file `lua 2/2` calibration job in [run 43948081097](https://github.com/korallis/KstyleUI/actions/runs/43948081097/job/133582934893). The remaining queued jobs of that calibration run were cancelled after the required second-runner samples were collected. Temporary calibration selection and reversed sharding were removed before the final full-suite verification.

Windows evidence: Beast, LuaBinaries PUC 5.1.5, 21 serial files (the final slowest 20 plus the original twentieth-ranked grid-10) (`KSTYLEUI_SLOTS=1`), 2026-11-16. The calibration-only wall guard was 600 seconds, to capture complete CPU samples under the machine's concurrent agent load; no stopped sample enters the table. Raw measurements and commands are attached to the PR evidence. The installed runner uses the budget-derived guard described above.

| File | Mac 1 CPU s | Mac 2 CPU s | Mac 3 CPU s | Windows CPU s | Mac allowance s |
| --- | ---: | ---: | ---: | ---: | ---: |
| `test-ornament-surfaces-minimap-subtle.lua` | — | 38.50 | 35.73 | 49.72 | 49 |
| `test-ornament-surfaces-minimap-full.lua` | 34.50 | — | 37.13 | 44.42 | 47 |
| `test-render-story-guard-tank.lua` | — | 26.22 | 23.38 | 29.31 | 33 |
| `test-render-scenes-gallery.lua` | — | 26.08 | 23.84 | 40.11 | 33 |
| `test-text-pixels-hud.lua` | 25.76 | — | 23.84 | 44.70 | 33 |
| `test-render-story-guard-healer.lua` | 23.52 | — | 25.61 | 31.75 | 33 |
| `test-render-story-guard-dps.lua` | 21.30 | — | 24.30 | 30.16 | 31 |
| `test-pixel-grid-16.lua` | 24.28 | — | 24.14 | 43.45 | 31 |
| `test-pixel-grid-8.lua` | 22.26 | — | 23.10 | 39.73 | 29 |
| `test-pixel-grid-3.lua` | — | 22.58 | 21.73 | 39.50 | 29 |
| `test-groupframes-rows.lua` | 22.28 | — | 20.79 | 36.48 | 28 |
| `test-pixel-grid-2.lua` | 22.06 | — | 21.46 | 38.58 | 28 |
| `test-pixel-grid-15.lua` | — | 21.89 | 20.35 | 30.33 | 28 |
| `test-pixel-grid-12.lua` | — | 21.70 | 20.74 | 34.16 | 28 |
| `test-render-scenes-classes.lua` | 21.49 | — | 21.50 | 35.61 | 27 |
| `test-pixel-grid-9.lua` | — | 21.35 | 20.27 | 34.05 | 27 |
| `test-pixel-grid-14.lua` | 21.15 | — | 21.30 | 41.20 | 27 |
| `test-perf.lua` | — | 21.27 | 20.29 | 44.88 | 27 |
| `test-hud-material-tank.lua` | — | 21.13 | 20.27 | 46.58 | 27 |
| `test-pixel-grid-11.lua` | 20.75 | — | 21.08 | 37.30 | 27 |

The Windows factor is **2.21**, the largest ratio in the 21-file serial Windows calibration of Windows CPU / worst Mac CPU rounded up to 0.01: `test-hud-material-tank.lua` = 46.578125 / 21.126243 = 2.204752. It scales Windows CPU warning thresholds and the budget-derived hang guard, including every allowance; it does not make Windows CPU time authoritative. The 4096 MB memory limit is unchanged. POSIX uses factor 1. The initial LEE-5827 allowances are `ceil(worst observed Mac CPU × 1.25)` for every measured file at or above 16 CPU seconds; files omitted from the list retain 20 seconds.

The original same-logical-core time-slicing probe changed from 2.343750 CPU / 2.994216 wall seconds to 2.421875 CPU / 24.619557 wall seconds. That did not test sibling-hyperthread contention. Verification subsequently measured identical Windows work at 43.609375 CPU seconds alone and 64.000000 CPU seconds under load, and a sibling-core probe rose about 1.7 times. CPU accounting therefore does not make Windows verdicts independent of load: Windows CPU overruns are advisory, and Mac CI decides the CPU verdict. The memory and hang limits remain fatal.

LuaJIT `-joff` prints `not budgeted` for CPU; memory and hangs remain checked. The native timeout and freed-allocation peak-memory checks pass. LEE-1537 margin and ordering tests use injected measurements; fixture ordering uses separate per-file markers and the held-slot test waits for an observed-lock handshake.

### Allowance inputs

These worst observed Mac CPU values include calibration runs, full run 43953802560, and the latest merged-staging run 43972698741. The 16-second inclusion threshold and 25% allowance apply to all rows; LEE-5827 owns reducing them.

| File | Worst Mac CPU s | Allowance s | Source |
| --- | ---: | ---: | --- |
| `test-actionbars-vehicle.lua` | 19.811575 | 25 | Mac 1, [run 43972698741](https://github.com/korallis/KstyleUI/actions/runs/43972698741) |
| `test-centre-clearance-dps-cat.lua` | 16.530659 | 21 | Mac 3, [run 43944756619](https://github.com/korallis/KstyleUI/actions/runs/43944756619) |
| `test-centre-clearance-healer-bear.lua` | 17.407659 | 22 | Mac 2, [run 43943487980](https://github.com/korallis/KstyleUI/actions/runs/43943487980) |
| `test-centre-clearance-healer-cat.lua` | 18.035937 | 23 | Mac 3, [run 43944756619](https://github.com/korallis/KstyleUI/actions/runs/43944756619) |
| `test-centre-clearance-healer-paladin.lua` | 18.073578 | 23 | Mac 3, [run 43944756619](https://github.com/korallis/KstyleUI/actions/runs/43944756619) |
| `test-centre-clearance-healer-rogue.lua` | 18.200957 | 23 | Mac 3, [run 43944756619](https://github.com/korallis/KstyleUI/actions/runs/43944756619) |
| `test-centre-clearance-tank-bear.lua` | 17.435912 | 22 | Mac 2, [run 43943487980](https://github.com/korallis/KstyleUI/actions/runs/43943487980) |
| `test-centre-clearance-tank-cat.lua` | 17.872141 | 23 | Mac 2, [run 43943487980](https://github.com/korallis/KstyleUI/actions/runs/43943487980) |
| `test-centre-clearance-tank-paladin.lua` | 17.948227 | 23 | Mac 3, [run 43944756619](https://github.com/korallis/KstyleUI/actions/runs/43944756619) |
| `test-centre-clearance-tank-rogue.lua` | 17.489064 | 22 | Mac 2, [run 43943487980](https://github.com/korallis/KstyleUI/actions/runs/43943487980) |
| `test-groupframes-grid.lua` | 17.034914 | 22 | Mac 1, [run 43972698741](https://github.com/korallis/KstyleUI/actions/runs/43972698741) |
| `test-groupframes-medallions-tiles-wide.lua` | 18.470120 | 24 | Mac 1, [run 43943487980](https://github.com/korallis/KstyleUI/actions/runs/43943487980) |
| `test-groupframes-medallions-tiles.lua` | 18.362331 | 23 | Mac 1, [run 43972698741](https://github.com/korallis/KstyleUI/actions/runs/43972698741) |
| `test-groupframes-raid-tile.lua` | 16.931091 | 22 | Mac 1, [run 43972698741](https://github.com/korallis/KstyleUI/actions/runs/43972698741) |
| `test-groupframes-rows.lua` | 22.281631 | 28 | Mac 1, [run 43943487980](https://github.com/korallis/KstyleUI/actions/runs/43943487980) |
| `test-hud-material-tank.lua` | 21.126243 | 27 | Mac 2, [run 43943487980](https://github.com/korallis/KstyleUI/actions/runs/43943487980) |
| `test-ornament-surfaces-minimap-full.lua` | 38.294389 | 48 | Mac 3, [run 43972698741](https://github.com/korallis/KstyleUI/actions/runs/43972698741) |
| `test-ornament-surfaces-minimap-subtle.lua` | 38.498007 | 49 | Mac 2, [run 43943487980](https://github.com/korallis/KstyleUI/actions/runs/43943487980) |
| `test-ornament-surfaces-xp-b.lua` | 16.370179 | 21 | Mac 1, [run 43943487980](https://github.com/korallis/KstyleUI/actions/runs/43943487980) |
| `test-ornament-surfaces-xp-c.lua` | 16.431729 | 21 | Mac 3, [run 43972698741](https://github.com/korallis/KstyleUI/actions/runs/43972698741) |
| `test-ornament-surfaces-xp-d.lua` | 16.154422 | 21 | Mac 3, [run 43972698741](https://github.com/korallis/KstyleUI/actions/runs/43972698741) |
| `test-ornament-surfaces-xp-f.lua` | 16.128701 | 21 | Mac 2, [run 43943487980](https://github.com/korallis/KstyleUI/actions/runs/43943487980) |
| `test-ornament-surfaces-xp-h.lua` | 16.370400 | 21 | Mac 1, [run 43943487980](https://github.com/korallis/KstyleUI/actions/runs/43943487980) |
| `test-ornament-surfaces-xp-j.lua` | 16.171037 | 21 | Mac 2, [run 43943487980](https://github.com/korallis/KstyleUI/actions/runs/43943487980) |
| `test-perf-frames.lua` | 16.497820 | 21 | Mac 1, [run 43972698741](https://github.com/korallis/KstyleUI/actions/runs/43972698741) |
| `test-perf-skins.lua` | 25.667379 | 33 | Mac 1, [run 43972698741](https://github.com/korallis/KstyleUI/actions/runs/43972698741) |
| `test-perf.lua` | 30.999676 | 39 | Mac 1, [run 43972698741](https://github.com/korallis/KstyleUI/actions/runs/43972698741) |
| `test-pixel-grid-1.lua` | 21.265459 | 27 | Mac 3, [run 43972698741](https://github.com/korallis/KstyleUI/actions/runs/43972698741) |
| `test-pixel-grid-10.lua` | 21.913607 | 28 | Mac 3, [run 43972698741](https://github.com/korallis/KstyleUI/actions/runs/43972698741) |
| `test-pixel-grid-11.lua` | 21.578320 | 27 | Mac 3, [run 43972698741](https://github.com/korallis/KstyleUI/actions/runs/43972698741) |
| `test-pixel-grid-12.lua` | 21.700801 | 28 | Mac 2, [run 43943487980](https://github.com/korallis/KstyleUI/actions/runs/43943487980) |
| `test-pixel-grid-13.lua` | 21.528263 | 27 | Mac 3, [run 43972698741](https://github.com/korallis/KstyleUI/actions/runs/43972698741) |
| `test-pixel-grid-14.lua` | 22.265655 | 28 | Mac 3, [run 43972698741](https://github.com/korallis/KstyleUI/actions/runs/43972698741) |
| `test-pixel-grid-15.lua` | 21.891535 | 28 | Mac 2, [run 43943487980](https://github.com/korallis/KstyleUI/actions/runs/43943487980) |
| `test-pixel-grid-16.lua` | 25.913421 | 33 | Mac 3, [run 43972698741](https://github.com/korallis/KstyleUI/actions/runs/43972698741) |
| `test-pixel-grid-2.lua` | 22.405043 | 29 | Mac 3, [run 43972698741](https://github.com/korallis/KstyleUI/actions/runs/43972698741) |
| `test-pixel-grid-3.lua` | 22.579293 | 29 | Mac 2, [run 43943487980](https://github.com/korallis/KstyleUI/actions/runs/43943487980) |
| `test-pixel-grid-4.lua` | 20.680394 | 26 | Mac 2, [run 43943487980](https://github.com/korallis/KstyleUI/actions/runs/43943487980) |
| `test-pixel-grid-5.lua` | 19.684303 | 25 | Mac 2, [run 43943487980](https://github.com/korallis/KstyleUI/actions/runs/43943487980) |
| `test-pixel-grid-6.lua` | 20.574053 | 26 | Mac 3, [run 43972698741](https://github.com/korallis/KstyleUI/actions/runs/43972698741) |
| `test-pixel-grid-7.lua` | 20.774353 | 26 | Mac 3, [run 43972698741](https://github.com/korallis/KstyleUI/actions/runs/43972698741) |
| `test-pixel-grid-8.lua` | 23.231944 | 30 | Mac 3, [run 43972698741](https://github.com/korallis/KstyleUI/actions/runs/43972698741) |
| `test-pixel-grid-9.lua` | 21.348517 | 27 | Mac 2, [run 43943487980](https://github.com/korallis/KstyleUI/actions/runs/43943487980) |
| `test-render-scenes-classes.lua` | 22.390381 | 28 | Mac 3, [run 43972698741](https://github.com/korallis/KstyleUI/actions/runs/43972698741) |
| `test-render-scenes-gallery.lua` | 26.079952 | 33 | Mac 2, [run 43943487980](https://github.com/korallis/KstyleUI/actions/runs/43943487980) |
| `test-render-story-guard-dps.lua` | 24.303940 | 31 | Mac 3, [run 43944756619](https://github.com/korallis/KstyleUI/actions/runs/43944756619) |
| `test-render-story-guard-healer.lua` | 26.347332 | 33 | Mac 3, [run 43972698741](https://github.com/korallis/KstyleUI/actions/runs/43972698741) |
| `test-render-story-guard-tank.lua` | 26.221612 | 33 | Mac 2, [run 43943487980](https://github.com/korallis/KstyleUI/actions/runs/43943487980) |
| `test-setup-collisions.lua` | 19.201334 | 25 | Mac 1, [run 43943487980](https://github.com/korallis/KstyleUI/actions/runs/43943487980) |
| `test-text-floor.lua` | 20.662359 | 26 | Mac 3, [run 43972698741](https://github.com/korallis/KstyleUI/actions/runs/43972698741) |
| `test-text-pixels-hud.lua` | 25.756223 | 33 | Mac 1, [run 43943487980](https://github.com/korallis/KstyleUI/actions/runs/43943487980) |
| `test-type-roles.lua` | 20.670064 | 26 | Mac 2, [run 43943487980](https://github.com/korallis/KstyleUI/actions/runs/43943487980) |
| `test-unitframes-column-keep.lua` | 18.874668 | 24 | Mac 1, [run 43972698741](https://github.com/korallis/KstyleUI/actions/runs/43972698741) |

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

The paths run as four test files to bound each file's work; their CPU limits, including `test-perf.lua`'s measured allowance, are recorded in `cpu_allowances.tsv`: `test-perf.lua` measures the core, action bar, combat text, cooldown, group frame and meter files, `test-perf-frames.lua` the nameplate and unit frame files, `test-perf-skins.lua` the quest card's, and `test-perf-hud.lua` the data bars' and the minimap's. `perf_runner.lua` holds the lists (`GROUPS`) and fails every file when a `perf/` file sits in no group, or in two. A slow path can lower `calls` (the quest card's use 100) so its allocation trace, about fifty times a plain call, stays inside the file's time.

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
- `budget` is the time per call in microseconds. `lua5.1 Tools/regression/test-perf.lua` prints each path's time. Use at least five times the measured PUC Lua 5.1 CPU time on the Mac.
- `setup` builds a stub environment and returns it with the function to measure. It runs once.
- `calls`, optional, sets the calls per round and the trace. The default is 1,000.

`Perf.Event(env, event, ...)` returns a function that runs the `OnEvent` script of each frame registered for the event, with the arguments given, as the game dispatches it. It finds the frames on its first call and raises if no frame is registered. A path that runs on a timer, such as the threat meter's update, fires its event and then calls `env.RunTimers()`.

When a path fails for allocation, the message names the lines and the bytes per call:

```text
StatusBar SetBarColor: allocates 152 bytes per call: Core/Widgets/StatusBar.lua:78 (152 bytes)
```

Fix the line: reuse a table that the object owns, or pass values as arguments. A table built once at load time is not a per-call allocation.

### Calibrate a budget

A per-call budget must be **at least five times the measured PUC Lua 5.1 CPU time on a Mac**, including CI. Hosted CI prints a warning for this machine-dependent headroom check; per-call budget overruns, allocations and errors still fail there. The test reports the minimum when a budget is too tight:

```text
Nameplates interrupt readiness flipping under three casts: budget 40 us is 2.8 times the 14.2 us Lua 5.1 CPU time; set it to at least 71 us (5 times)
```

Run [43972698741](https://github.com/korallis/KstyleUI/actions/runs/43972698741) measured five paths below their required headroom. Their budgets were recalibrated from the reported minimums, rounded up, while retaining the fivefold check:

| Path | Measured CPU us/call | Budget us |
| --- | ---: | ---: |
| UnitFrames target change, rank changes | 208 | 1050 |
| Skins quest update, 25 quests (LEE-5831) | 1291.75 | 6500 |
| ActionBars pet cooldown update | 33.2 | 170 |
| GroupFrames UNIT_FLAGS | 8.58 | 45 |
| Meters raid-of-twenty damage refresh | 413 | 2100 |

LEE-5831 tracks the Skins quest-update slowdown since #418. The historical slower-runner multiplier is gone. Windows prints a headroom skip note because MSVC `os.clock` measures wall time; LuaJIT also skips this PUC CPU-headroom check. Per-call timing, allocation and error checks continue to run.

## Cold HUD scale search

`lua5.1 Tools/regression/test-scalelimit-identity.lua` compares the search with the independent, frozen `fixtures/scalelimit-before.lua` from staging `a0984bb2`. It checks exact `%.17g` doubles, predicates at both sides of the boundary, public Story geometry and Get's copy ownership. The fixture includes the previous layout data so a shared helper cannot make both sides agree on the same mistake.

Run paired measurements from the repository root with PUC Lua 5.1, never LuaJIT:

```bash
lua5.1 Tools/regression/bench-scalelimit.lua
lua5.1 Tools/regression/bench-scalelimit.lua --display
```

Both commands alternate five before/after cold calls, stop GC while measuring, invalidate the real result cache, verify every result and report median/range time and allocated bytes. `--display` drives `DISPLAY_SIZE_CHANGED` through the loaded core's real Scale.Apply, with automatic size, Spread and the DPS enabled-element fixture. It includes the core's event dispatch, snapping and scale callbacks; the game engine and module frame construction are outside this measurement. Windows MSVC `os.clock` measures wall time, so Windows results must say so.

The perf entry measures six prepared candidate checks (one fitting size and one just above it for each style) with a 2,000 us budget and 0 B on addon lines. Cold preparation allocates the positions, dimensions and collision buffers once per search. The candidate loop reuses them and two Story cards. Its bounded memo holds the last exact Story tuple: name, guide=true, style and shown=nil are fixed by the search closure; rootHeight and the deterministically derived rootWidth are compared exactly. A changed candidate rewrites the cards without allocating, and the cached predicate retains only this small scratch state.

## Pixel-grid baseline provenance

`pixel_allow.tsv` is generated by `lua5.1 Tools/dev/pixel_allow.lua`; keep only its two standard headers and measured data. The gate reads this TSV as `SUPPRESSION_BASELINES` and authorizes growth only through the durable `Baseline-Growth: LEE-5882` commit trailer, not comments inside generated data. LEE-5882 tracks the remaining C4 native-tooltip fractional geometry; regeneration must lower improved counts and keep all checks active. `test-pixel-ledger.lua` prevents ticket notes from being added to the generated file again.

The following C1-C5 entries exceed the pre-change staging counts (base 92135ee2); their ticket is LEE-5882. The remaining changes lower counts, including removal of the Tooltips preview allowance after its positions were snapped.

| Scene | Screen | File | Staging | Current | Ticket |
| --- | --- | --- | ---: | ---: | --- |
| `gallery_groupframes` | 2560x1440 | `Core/Widgets/SectionCap.lua` | 0 | 1 | LEE-5882 |
| `gallery_groupframes` | 3440x1440 | `Core/Widgets/SectionCap.lua` | 0 | 1 | LEE-5882 |
| `gallery_groupframes` | 5120x1440 | `Core/Widgets/SectionCap.lua` | 0 | 1 | LEE-5882 |
| `gallery_restedxp` | 1280x720 | `KstyleUI_Skins/Addons/RestedXP/Chrome.lua` | 33 | 34 | LEE-5882 |
| `gallery_restedxp` | 1920x1080 | `KstyleUI_Skins/Addons/RestedXP/Chrome.lua` | 9 | 10 | LEE-5882 |
| `gallery_restedxp` | 3840x1080 | `KstyleUI_Skins/Addons/RestedXP/Chrome.lua` | 9 | 10 | LEE-5882 |
| `gallery_skins_talents` | 3840x2160 | `KstyleUI_Tooltips/Style.lua` | 4 | 5 | LEE-5882 |
| `gallery_tooltips` | 3840x2160 | `KstyleUI_Tooltips/Style.lua` | 37 | 39 | LEE-5882 |
| `hud_reference` | 2560x1440 | `KstyleUI_Skins/Addons/RestedXP/Chrome.lua` | 3 | 4 | LEE-5882 |
| `hud_reference` | 3440x1440 | `KstyleUI_Skins/Addons/RestedXP/Chrome.lua` | 3 | 4 | LEE-5882 |
| `hud_reference` | 5120x1440 | `KstyleUI_Skins/Addons/RestedXP/Chrome.lua` | 3 | 4 | LEE-5882 |
| `hud_reference` | 5120x1440 spread | `KstyleUI_Skins/Addons/RestedXP/Chrome.lua` | 3 | 4 | LEE-5882 |
