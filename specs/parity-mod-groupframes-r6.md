# Task: EllesmereUI parity, Group frames: build the remaining "Missing, fits" rows (round 6)

**The owner's decision**: v0.2.9 waits until **every** "Missing, fits" EllesmereUI parity row is built. One worker per module, in parallel. You own **Group frames** (folder `KstyleUI_GroupFrames`).

**The backlog**: the parity table in `KstyleUI_GroupFrames/README.md` on `origin/staging`. Every row marked "Missing, fits" is yours. The original rules are in `C:/Projects/KstyleUI/specs/parity-frames.md`; read them, they all apply:
- reuse the shared builders (TextRows/tags, BarRows, the aura filter row, the placement helper, Shown rules, attach);
- one consistent style;
- every Forever API proven at `9dc84f0` and guarded, with `issecretvalue` checked;
- no per-frame work, and secure changes queued in combat.

**Build as many rows as you can in one PR: aim for 40 or more**, grouped so the PR stays reviewable (about 1,500 lines of Lua at most). Mark each built row Present in the README. If rows remain, list them under "Next round" in the PR body; the coordinator starts another round.

**Defaults**: today's look and behaviour stay the default (zero pixel difference). A new option that's a clear improvement players would expect may default ON only if that doesn't change today's default look; otherwise it's OFF.

**Recent reviews have rejected batches for the same mistakes, so check these yourself before opening the PR**:
1. **Option on, not just off:** for every new option, test **the option switched on**, with a regression that probes the enabled state. Bugs only showed when enabled: text colouring a hidden element, overlap with neighbouring icons or text, stale state after events.
2. **Turning off restores:** turning an option off restores Blizzard's or KstyleUI's original state exactly, including native elements you changed.
3. **Events:** state refreshes on the events that change it (faction, combat or encounter start and end, unit changes), not only on show.
4. **Independence:** an option doesn't silently depend on another being on (for example, a cast tint needing the cast bar shown).
5. **Previews:** the Options live preview reflects each new option.
6. **No hot-path work:** don't reconfigure the same thing on every update, and don't re-hide hidden regions; cache per change.
7. **Safe fallbacks:** if an API is missing, take the safe path (refuse, rather than scan, in combat).
8. **Combat-uncertain features:** if the game can't tell you something safely (for example, a caster's combat state), don't build it. Mark it "Not possible on Forever" with the reason.

**Evidence** (in `C:/Users/leeba/.cache/kstyleui-evidence/parity-groupframes-r6/`):
- base-against-PR default pixel diffs at 1920x1080 and 5120x1440, which must be zero;
- **enabled-state renders at all four sizes** (1920x1080, 2560x1440, 5120x1440, 3840x2160) over a real game backdrop (`game_*` in `~/.cache/kstyleui-backdrops`), with `--strict`;
- the Options page renders.

**Reload budget**: `test-perf-path-budgets` is about 12.4M of the 13.0M ceiling. New options must stay lazy and add no measurable reload cost.

**PR**: open a PR (not a draft) against `staging` titled `feat(groupframes): EllesmereUI parity round 6`, with:
- `## Changelog` (`Added:` lines in player words, grouped);
- `## Options`, `## In-game checks` and `## Forever API`;
- the rows built and the rows left.

Do not merge.

**Files it may edit**: `KstyleUI_GroupFrames/**`, `KstyleUI_Options/**` (rows only), `Core/Locales/**`, `Tools/locale/*.json`, `Tools/regression/**`, `Tools/render/**`, `docs/feature-map.md`. Shared builders in `Core/Widgets/**` only for a small extension every caller benefits from; say why.

**Constraints**:
- Minimal code; CRLF/ASCII; locales synced with translations.
- Beast speed rule: no full local Lua suite, at most 2 renders at a time.
- Other module workers run in parallel and all touch `Core/Locales` and `Tools/locale`; rebase onto `origin/staging` right before opening, and merge the locale files by taking both sides' strings.

**Gate**: lint, python, the module's tests, `test-taint-scan` and `test-perf-path-budgets` under PUC Lua 5.1, then hosted CI.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id, the rows built and the rows left.

**Also**: finish the rows marked Partial. Keep each new test file under ~10 CPU s on the Mac (split at seams, share boots, as `groupframes_r3a.lua` H.boot does).
