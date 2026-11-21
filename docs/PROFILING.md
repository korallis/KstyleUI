# Profiling KstyleUI's Lua time

`/kstyle perf` records the frame rate and the Lua time this addon spends for a window, then writes both to the devlog. It answers one question: **is this addon's own Lua a meaningful part of a frame, and which work is the largest part of it?** It does not tell you what the client or the GPU costs, and it cannot see work that no timer wraps.

## Running it

1. Get into the scene you care about: the layout and HUD style you want, the modules on, and preferably something moving (a target, a fight, the quest card filling and emptying).
2. `/kstyle perf 30` starts a 30-second window (`/kstyle perf` alone uses 20; anything under 1 is raised to 1, and a length that is not a finite number is refused). The chat prints that it is recording.
3. Play the scene normally. Do not open the options or `/reload` mid-window: either hides the addon you wanted to measure.
4. `/kstyle perf` again stops it early, or it stops itself at the end of the window. The report lands in the devlog. A window stopped before its first frame has nothing to measure, so it writes no report and says so.
5. `/reload` saves the devlog, then read `KstyleUIDB.devlog` in `WTF/Account/<ACCOUNT>/SavedVariables/KstyleUI.lua` and look at the entries whose `module` is `Perf`. The log keeps the newest 500 entries, so a run right before the reload is the one that survives.

The command needs the client's `debugprofilestop`. When a client lacks it, the command says so instead of recording.

## The two summary lines

```
Perf: 30.0 s window: 61 fps mean, 38 lowest, 64 highest, 61 samples
Perf: this addon's Lua: 14.6 ms per second, 1.46% of the wall time, 41188 timed calls
```

- **Window** is the measured time, then the mean, lowest and highest frame rate. The rate is the client's `GetFramerate`, which averages recent frames, sampled every 0.5 s, hence the sample count; the first sample is taken when the window opens. The **lowest** sample is the closest figure to stutter, and a healthy mean with a very low minimum points to a hitch rather than a steady cost. A single long frame between two samples can still be missed, so a good minimum does not rule a hitch out.
- **Milliseconds per second** is the addon's timed Lua time divided by the window: 14.6 ms of every second, on average, inside the timer. Time is counted once: when one timed call runs inside another, the inner time is not added again. This is a rate, not a frame figure.
- **Per cent of the wall time** is that rate over 1000 ms, so 10 ms per second is 1%. Treat it as the share of one core's clock that this addon's Lua occupies.
- **Timed calls** counts the wrapped calls in the window, whether or not each one was slow. A high count with a small rate is a frequency problem (the work runs very often); a low count with a large rate is a cost problem (each run is expensive).

## The rows

```
Perf:    6.42 ms/s   1809 calls  Motion step
Perf:    3.88 ms/s    612 calls  Skins PLAYER_ENTERING_WORLD
Perf:    2.10 ms/s   1680 calls  UnitFrames UNIT_HEALTH
```

Up to ten rows, largest first. `ms/s` is that name's own time: a timed call made inside it counts in its own row instead, so all the names together add up to the millisecond-per-second figure above. `calls` is how often it ran in the window, so **own cost per call is `ms/s × window ÷ calls`** — here 6.42 × 30 ÷ 1809 ≈ 0.11 ms per motion step. The name is either `<owner> <event>` for an event handler (`Skins PLAYER_ENTERING_WORLD`, `UnitFrames UNIT_HEALTH`) or one of the two shared drivers: `Motion step` for every tween in one shared `OnUpdate`, and `Calm wait` for the transition hold.

When nothing was timed, the line says so instead:

```
Perf: no timed work ran in the window
```

That is a real result, not a failure. None of the timed paths ran, so a frame rate problem, if there is one, lies elsewhere: in this addon's untimed Lua, in another addon, in the client or on the GPU.

## Judging the numbers

- **The frame budget.** At 60 frames per second one frame is 16.7 ms, and a full second of frames is 1000 ms. So the millisecond-per-second figure is directly comparable with that budget: 10 ms per second is 1% of the time, 16.7 ms per second is one 60 Hz frame's worth every second, and 167 ms per second is about ten such frames, a sixth of all the time.
- **Rough bands.** Under 10 ms/s (under 1%) is noise; 10 to 50 ms/s is small enough that only the weakest scenes would show it; 50 to 150 ms/s is worth naming in a pull request; above 150 ms/s is worth fixing before it ships. These bands are judgement, not a gate — pair them with the lowest frame rate, which is what players notice.
- **Read it as a sample.** Two 30-second runs of the same scene can differ by 10–20%. Run it two or three times and keep the middle result before you claim a difference, and use the same window length on both sides of a before/after.
- **Only compare like with like.** Same client, same resolution, same HUD style, layout and modules, same activity. A number from one machine, character or settings file says nothing about another.
- **A row at the top does not mean a bug.** Movement and combat dispatch a lot of events; `Motion step` and event owners are expected to lead a busy scene. What matters is whether the rate climbs without a change in what you did.

## What is and is not counted

Counted: every event handler reached through `Core/Events.lua` (named `<owner> <event>`), the shared motion driver (`Motion step`), the Calm transition wait (`Calm wait`), and anything else wrapped with `DevTest.Time` or `DevTest.Timed`. The timer measures elapsed time, so the client functions a timed call makes (`SetValue`, `SetText`, `SetPoint` and the like) count inside it.

Not counted: the work the client does outside those calls (drawing, textures, animations, the 3D model pool, sound), other addons, and any `OnUpdate` a file sets without `DevTest.Timed`. A keybind, a mouse script or a frame script is only visible if it is wrapped. Because of that, a small total is not proof that the addon is cheap overall — it is proof that the timed paths are cheap.

Outside a window nothing changes: the event dispatcher and the two drivers run their plain handlers, exactly as without the profiler. Opening a window swaps timed handlers in for the running ones and for any that start during it, and closing it puts the plain ones back. A running profile costs one `debugprofilestop` pair per timed call, plus the timer's own bookkeeping, which lands inside the measured time of an enclosing timed call. If something calls `debugprofilestart` during a call, that call's time is dropped rather than counted as negative.

## Profiling your own work

```lua
local DevTest = KstyleUI.DevTest
local total = DevTest.Time("UnitFrames UpdateHealth", UpdateHealth, unit, value)
local step = DevTest.Timed("UnitFrames spark", AnimationStep)
frame:SetScript("OnUpdate", step)
```

Keep names stable, unique and descriptive — a name is how a row in the devlog becomes a file and a function — and wrap at the same level you would measure: around the whole unit of work, not around a single `SetValue`. Both return exactly what the wrapped function returns, trailing `nil`s included. With no window open they still cost one extra call and a check each time, so keep them out of hot paths in shipped code; `Events.SetProfiling`, `Motion.SetProfiling` and `Calm.SetProfiling` show how a hot path swaps timing in for the window only.

## What to put in a pull request

The two summary lines and the top rows, with the scene described (resolution, HUD style, layout, modules, what you did in the window), and a before/after pair measured the same way with the same window length. That is enough for a reviewer to see whether a change moved the cost and where.
