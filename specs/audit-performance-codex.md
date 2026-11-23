# Audit lens 3 of 4: performance

**Goal**: an honest, evidence-backed score out of 10 and a ranked list of improvements that would take KstyleUI to 10/10 for this lens.

**Lens**: Score load time, memory, steady-state CPU in combat (solo, 5-player, 25 and 40 raid, 20 nameplates), garbage, layout and resize work, and engine-side costs. Start from the existing measured report C:\Users\leeba\.cache\kstyleui-perf-research\REPORT.md and its probes (do not redo what it measured; re-measure only what changed). Account for the fixes in flight: PRs #447 (group prediction ranges), #448 (scale search), #449 (boss targetable filter) and the branch perf/widgets-lazy-chrome (lazy regions; fetch it) - score the UI before and after those land. Then find what still keeps it from 10/10 (target-change spike, animations, vignette, per-event costs, memory per module, load order) with measured numbers under PUC lua5.1. Every improvement must keep the look pixel-identical unless you flag it clearly as a look change. Write C:\Users\leeba\.cache\kstyleui-audit\performance-codex.md.

**Context**: KstyleUI is a premium WoW addon suite (Forever client). Read `docs/superpowers/specs/2026-11-07-kstyleui-design.md`, `docs/feature-map.md`, `README.md` and `Core/Tokens.lua` first. The owner's top priorities are **finesse, elegance and polish**. It ships three HUD styles (Medallions, Frames, Orbs), DPS/Tank/Healer layouts and Centred/Spread arrangements, plus nameplates, group frames, tooltips, bags, chat, meters, minimap, data bars, the quest/guide tracker, window skins, Options and the first-run setup. Its inspiration is Caith UI.

**Evidence base**:
- Render every relevant scene with the app driver (AGENTS.md "App driver", `Tools/render/README.md`, `docs/feature-map.md`) at 1920x1080 (`--ppu 1`), 3456x2234 (`--ppu 2.0685185185`) and 5120x1440 (`--ppu 1.3333333333`), in all three HUD styles where it applies, idle and in combat, with `--backdrop --strict`. Write the renders to `C:\Users\leeba\.cache\kstyleui-audit\renders-codex\` (create it), never into the repository.
- The real in-game captures in `docs/media/readme/game_*` (they show the true game look, including the 3D world behind the UI).
- Open and look at every picture you cite; zoom into crops where finesse matters (edges, text, spacing, alignment).
- For comparison, find screenshots of the best-regarded WoW UIs (Caith UI, ElvUI, Blizzard's own modern UI, popular Wago packs) and of premium game UIs generally; save the ones you use to `C:\Users\leeba\.cache\kstyleui-audit\refs-codex\` with their URLs. Never copy their art.

**Scoring**: give each area a score out of 10 with a one-line justification, then an overall score for your lens. A 10 means nothing a demanding player or art director would change. Be honest and specific; a flattering audit is useless.

**Improvements**: for every point below 10, list concrete improvements ranked by impact on finesse, elegance and polish. Each one: what is wrong (with the picture file and crop coordinates, or file:line), what it should be (precise: sizes in units, colours as Tokens names or hex, timing in ms, curves), why it raises the score, the effort (S/M/L) and the risk. Say which changes would alter the current look (allowed here: this is a design audit, unlike the performance work).

**Constraints**: read-only for the repository: change and commit nothing in the repo, open no PR. Work in your own worktree. Windows machine (Beast): prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. Other agents share the machine's test slots and CPU: never stop processes you did not start.

**Files it may edit**: none in the repository; only `C:\Users\leeba\.cache\kstyleui-audit\**`.

**Gate**: none (read-only).

**Before worker_done**: follow `C:\Users\leeba\orca-jev-router\WORKER.md`. Report the report path, your scores and your top five improvements.

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
