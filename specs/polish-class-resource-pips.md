# Task: class-themed, animated resource pips (the dots above the crest)

The owner (2026-11-21) approved the polished crest jewels (PR #671) and says: "the normal dots above the crest look basic and need some animation polish, but be unique for each class. So rogues themed around the class." These are the player's class resource pips drawn above the Medallions crest (and on the player frame in Frames/Orbs): today plain yellow circles (see `C:/Users/leeba/.cache/kstyleui-evidence/showcase-jewels/crest-rogue.png`, the row of dots above the crest). Find where they are built (the UnitFrames class resource element, `unitframes.resource`; check `KstyleUI_UnitFrames/` and Medallions effects) and every class/power it supports on Forever.

**Design, one forged look, unique per class** (read docs/medallions.md, docs/medallions-effects.md, docs/ORNAMENT-SPEC.md; reuse tokens in `Core/Tokens.lua`, new art with provenance in `Media/`):
- **Rogue combo points**: themed on the class: e.g. small blade/dagger-shaped pips or crossed-blade sigils in ember/crimson with a steel edge; each point unsheathes/glints in, finishing-move-ready (max) gives a quick blade-shine sweep across all pips; spending makes them fade with a slash.
- **Druid (cat) combo points**: claw-mark pips in amber/green, a scratch-in on gain.
- **Paladin holy power**: gold sun/rune sigils with a radiant flare on gain and a holy pulse at max.
- **Warlock soul shards**: violet crystal shards with a fel wisp on gain, a soul-glow at max.
- Any other class resource shown as pips (prove which exist on Forever at 9dc84f0): themed the same way.
- Animations: gain, spend, and a max-state accent that matches the crest jewels' full-ring glow (same timing family). All follow Appearance > Motion (Full/Calm/Off; Off = end states, no animation) and cost nothing idle (no OnUpdate when nothing animates; pass `test-perf-idle-draw` with hidden-not-alpha-0 layers).
- Secret-safe: engine-fed values (status bars/curves), never compare secret power values in Lua.
- Toggle: **Class-themed pips** under the class resource options, ON by default (off restores today's plain pips pixel-for-pixel).

**Evidence**: animated GIFs per class (0 → max → spend) at 1920x1080 and 5120x1440 over real game backdrops, `--strict`, in Medallions and Frames; the owner reviews them before merge. Off-state pixel-identical to staging. Regressions: per-class art and colour, gain/spend/max transitions, Motion Off, no idle OnUpdate, secret values never compared. Lint, python, UnitFrames and ActionBars tests, `test-taint-scan`, `test-perf-path-budgets`, `test-perf*`, `test-secrets` under PUC Lua 5.1; hosted CI green. One PR to `staging`, `feat(unitframes): class-themed resource pips`, `Added:` line. Do not merge.

**Files it may edit**: `KstyleUI_UnitFrames/**`, `KstyleUI_ActionBars/**` (only if the pips live there), `Core/Tokens.lua` (new tokens only), `Media/**` with provenance, `Core/Locales/*`, `Tools/locale/*`, `docs/feature-map.md`, `docs/medallions-effects.md`, `Tools/regression/**`, `Tools/render/**`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report PR, SHA, run id and GIF paths.
