# Profiling KstyleUI's Lua time

`/kstyle perf` records the frame rate and the Lua time this addon spends for a window, then writes both to the devlog. It answers one question: **is this addon's own Lua a meaningful part of a frame, and which work is the largest part of it?** It does not tell you what the client or the GPU costs, and it cannot see work that no timer wraps.

## Running it

1. Get into the scene you care about: the layout and HUD style you want, the modules on, and preferably something moving (a target, a fight, the quest card filling and emptying).
2. `/kstyle perf 30` starts a 30-second window (`/kstyle perf` alone uses 20; anything under 1 is raised to 1). The chat prints that it is recording.
3. Play the scene normally. Do not open the options or `/reload` mid-window: either hides the addon you wanted to measure.
4. `/kstyle perf` again stops it early, or it stops itself at the end of the window. The report lands in the devlog.
5. `/reload` saves the devlog, then read `KstyleUIDB.devlog` in `WTF/Account/<ACCOUNT>/SavedVariables/KstyleUI.lua` and look at the entries whose `module` is `Perf`. The log keeps the newest 500 entries, so a run right before the reload is the one that survives.

The command needs the client's `debugprofilestop`. When a client lacks it, the command says so instead of recording.

## The two summary lines

```
Perf: 30.0 s window: 61 fps mean, 38 lowest, 64 highest, 61 samples
Perf: this addon's Lua: 14.6 ms per second, 1.46% of the wall time, 41188 timed calls
```

- **Window** is the measured time, then the mean, lowest and highest frame rate. The rate is sampled every 0.5 s, hence the sample count, and the first sample is taken when the window opens. The **lowest** value is the one a player feels as stutter; a healthy mean with a very low minimum means a hitch, not a steady cost.
- **Milliseconds per second** is the addon's Lua time divided by the window: 14.6 ms of every second, on average, inside the timer. This is a rate, not a frame figure.
- **Per cent of the wall time** is that rate over 1000 ms, so 10 ms per second is 1%. Treat it as the share of one core's clock that this addon's Lua occupies.
- **Timed calls** counts the wrapped calls in the window, whether or not each one was slow. A high count with a small rate is a frequency problem (the work runs very often); a low count with a large rate is a cost problem (each run is expensive).

## The rows

```
Perf:    6.42 ms/s   1809 calls  Motion step
Perf:    3.88 ms/s    612 calls  Skins PLAYER_ENTERING_WORLD
Perf:    2.10 ms/s   1680 calls  UnitFrames UNIT_HEALTH
```

Up to ten rows, largest total first. `ms/s` is that name's share of the millisecond-per-second figure above, and `calls` is how often it ran in the window, so **cost per call is `ms/s × window ÷ calls`** — here 6.42 × 30 ÷ 1809 ≈ 0.11 ms per motion step. The name is either `<owner> <event>` for an event handler (`Skins PLAYER_ENTERING_WORLD`, `UnitFrames UNIT_HEALTH`) or one of the two shared drivers: `Motion step` for every tween in one shared `OnUpdate`, and `Calm wait` for the transition hold.

When nothing was timed, the line says so instead:

```
Perf: no timed work ran: the frames go somewhere outside this addon's Lua, so look at regions, textures and animation
```

That is a real result, not a failure. It means the frame rate problem, if there is one, is not in Lua that KstyleUI times.

## Judging the numbers

- **The frame budget.** At 60 frames per second one frame is 16.7 ms, and a full second of frames is 1000 ms. So the millisecond-per-second figure is directly comparable with that budget: 10 ms per second is 1% of the time, 167 ms per second is one whole frame's worth per second.
- **Rough bands.** Under 10 ms/s (under 1%) is noise; 10 to 50 ms/s is small enough that only the weakest scenes would show it; 50 to 150 ms/s is worth naming in a pull request; above 150 ms/s is worth fixing before it ships. These bands are judgement, not a gate — pair them with the lowest frame rate, which is what players notice.
- **Read it as a sample.** Two 30-second runs of the same scene can differ by 10–20%. Run it two or three times and keep the middle result before you claim a difference, and use the same window length on both sides of a before/after.
- **Only compare like with like.** Same client, same resolution, same HUD style, layout and modules, same activity. A number from one machine, character or settings file says nothing about another.
- **A row at the top does not mean a bug.** Movement and combat dispatch a lot of events; `Motion step` and event owners are expected to lead a busy scene. What matters is whether the rate climbs without a change in what you did.

## What is and is not counted

Counted: every event handler reached through `Core/Events.lua` (named `<owner> <event>`), the shared motion driver (`Motion step`), the Calm transition wait (`Calm wait`), and anything else wrapped with `DevTest.Time` or `DevTest.Timed`.

Not counted: client C code, textures, animations, the 3D model pool, sound, and any `OnUpdate` a file sets without `DevTest.Timed`. A keybind, a mouse script or a frame script is only visible if it is wrapped. Because of that, a small total is not proof that the addon is cheap overall — it is proof that the timed paths are cheap.

The wrappers are transparent when no profile runs: `DevTest.Time` calls straight through, and the two drivers install the plain function. A running profile costs one `debugprofilestop` pair per wrapped call.

## Profiling your own work

```lua
local DevTest = KstyleUI.DevTest
local total = DevTest.Time("UnitFrames UpdateHealth", UpdateHealth, unit, value)
local step = DevTest.Timed("UnitFrames spark", AnimationStep)
frame:SetScript("OnUpdate", step)
```

Keep names stable, unique and descriptive — a name is how a row in the devlog becomes a file and a function — and wrap at the same level you would measure: around the whole unit of work, not around a single `SetValue`. Both functions return their arguments' results and pass straight through when nothing is recording, so the call sites can stay in shipped code.

## What to put in a pull request

The two summary lines and the top rows, with the scene described (resolution, HUD style, layout, modules, what you did in the window), and a before/after pair measured the same way with the same window length. That is enough for a reviewer to see whether a change moved the cost and where.
