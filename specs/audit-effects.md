# Audit lens 2 of 4: visual effects and motion

**Goal**: an honest, evidence-backed score out of 10 and a ranked list of improvements that would take KstyleUI to 10/10 for this lens.

**Lens**: Score every effect and animation: Medallions ambient effects (rune turns, breaths, particles, portrait sheen, 3D models), proc glows, cooldown sweeps and ready flashes, press/hover feedback, cast and channel bars, interrupt flashes, low-health ring pulse and vignette, combat-calm fades, window open fades, nameplate target brackets, aura timers, setup and Options transitions, and the Motion settings (Full/Calm/Off, Reduced). Read the code (`Core/Effects.lua`, `Core/Motion*`, `Core/Widgets/Glow.lua`, `Core/Widgets/Slot.lua`, `Core/Widgets/Medallion.lua`, `Core/Vignette.lua`, `KstyleUI_ActionBars/Slab.lua`, `Core/EffectModels.lua`, `Core/Layout/Calm.lua`) for durations, easing and loops; watch the in-game GIFs in docs/media/readme frame by frame. Judge: timing and easing quality, restraint vs noise, whether each effect carries information, consistency of the motion language, readability in a busy fight, and engine cost (looping animations, full-screen layers). Write C:\Users\leeba\.cache\kstyleui-audit\effects.md.

**Context**: KstyleUI is a premium WoW addon suite (Forever client). Read `docs/superpowers/specs/2026-11-07-kstyleui-design.md`, `docs/feature-map.md`, `README.md` and `Core/Tokens.lua` first. The owner's top priorities are **finesse, elegance and polish**. It ships three HUD styles (Medallions, Frames, Orbs), DPS/Tank/Healer layouts and Centred/Spread arrangements, plus nameplates, group frames, tooltips, bags, chat, meters, minimap, data bars, the quest/guide tracker, window skins, Options and the first-run setup. Its inspiration is Caith UI.

**Evidence base**:
- Render every relevant scene with the app driver (AGENTS.md "App driver", `Tools/render/README.md`, `docs/feature-map.md`) at 1920x1080 (`--ppu 1`), 3456x2234 (`--ppu 2.0685185185`) and 5120x1440 (`--ppu 1.3333333333`), in all three HUD styles where it applies, idle and in combat, with `--backdrop --strict`. Write the renders to `C:\Users\leeba\.cache\kstyleui-audit\renders\` (create it), never into the repository.
- The real in-game captures in `docs/media/readme/game_*` (they show the true game look, including the 3D world behind the UI).
- Open and look at every picture you cite; zoom into crops where finesse matters (edges, text, spacing, alignment).
- For comparison, find screenshots of the best-regarded WoW UIs (Caith UI, ElvUI, Blizzard's own modern UI, popular Wago packs) and of premium game UIs generally; save the ones you use to `C:\Users\leeba\.cache\kstyleui-audit\refs\` with their URLs. Never copy their art.

**Scoring**: give each area a score out of 10 with a one-line justification, then an overall score for your lens. A 10 means nothing a demanding player or art director would change. Be honest and specific; a flattering audit is useless.

**Improvements**: for every point below 10, list concrete improvements ranked by impact on finesse, elegance and polish. Each one: what is wrong (with the picture file and crop coordinates, or file:line), what it should be (precise: sizes in units, colours as Tokens names or hex, timing in ms, curves), why it raises the score, the effort (S/M/L) and the risk. Say which changes would alter the current look (allowed here: this is a design audit, unlike the performance work).

**Constraints**: read-only for the repository: change and commit nothing in the repo, open no PR. Work in your own worktree. Windows machine (Beast): prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. Other agents share the machine's test slots and CPU: never stop processes you did not start.

**Files it may edit**: none in the repository; only `C:\Users\leeba\.cache\kstyleui-audit\**`.

**Gate**: none (read-only).

**Before worker_done**: follow `C:\Users\leeba\orca-jev-router\WORKER.md`. Report the report path, your scores and your top five improvements.

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
