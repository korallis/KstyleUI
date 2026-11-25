# Task (v0.3.5): build crest enhancements 2 (Expiring ember), 4 (Cast ring), 7 (Swing ring for melee) and 9 (Global cooldown spark)

The owner approved building all ten crest enhancements from the WeakAuras centre-piece research. Build enhancements 2 (Expiring ember), 4 (Cast ring), 7 (Swing ring for melee) and 9 (Global cooldown spark) exactly as specified in `C:/Users/leeba/.cache/kstyleui-evidence/research-weakauras-centerpiece/REPORT.md` (section 3: what the player sees, classes, seat or layer, motion, Forever feed, Frames behaviour, cost, toggle) with its mockups in `mockups/` as the visual target. Read sections 2 and 4 too (limits, and which routes need an in-game check).

Rules:
- Your area is the ring-edge timing layers (timer rings, outer ring arcs). Three other builders work in parallel on the other enhancements in the same crest files (`KstyleUI_ActionBars/SlabMedals.lua`, `SlabTrackers.lua`, `Slab.lua`): keep your changes local to your pieces, add new code in new small sections or files where that is cleaner, and rebase onto staging before you push.
- The crest's locked rules from #799: nothing the crest writes during combat may sit under an engine aura button; size and anchor at build time out of combat; replay deferred work on ADDON_RESTRICTION_STATE_CHANGED. Secret values: check `issecretvalue` before any comparison.
- Every enhancement gets its own switch in Options (on by default as the report says; the Global cooldown spark is off by default), both HUD styles (Frames behaviour as the report says), every class the report lists, one consistent forged style with the existing crest art. Expiring colours use the shared `timerExpiring` token (PR #802) if it is on staging when you start; otherwise use the same value and note it.
- Where the report marks a route as needing an in-game check, build the proven fallback it names, or the route plus a fallback, and list the check under the PR's In-game checks.
- Performance: respect the repo's perf budgets (`test-perf*`), no per-frame work when nothing changes, no new OnUpdate loops beyond what the motion needs while it is visible.
- Update `docs/medallions-effects.md` and `docs/feature-map.md`; strings via `strings.py sync`.

Regressions for each enhancement (feed, motion start/end state, toggle off, in-combat no forbidden writes, Frames), each proven failing first. Evidence: per enhancement, a GIF or stills of the real build over the owner's backdrops at 1920x1080 and 5120x1440 plus 2x crops, compared side by side with the report's mockup, in `C:/Users/leeba/.cache/kstyleui-evidence/build-crest-wa-b/`.

**Files it may edit**: `KstyleUI_ActionBars/**`, `KstyleUI_Options/**` (switches), `KstyleUI_UnitFrames/**` only if an enhancement reads cast/swing state already there, `Core/Locales/*`, `Tools/locale/*`, `Tools/media/**` (generated art only), `Media/**` (generated art only, with provenance), `Tools/regression/**`, `Tools/render/**`, `docs/medallions-effects.md`, `docs/feature-map.md`.

**PR**: `feat(crest): expiring embers, cast, swing and global cooldown rings` with a `## Changelog` `Added:` line per enhancement and `## In-game checks`. Do not merge.

**Constraints**: minimal code; CRLF/ASCII; Forever API proof (cite the files); Beast speed rule (module tests, lint, python; CI is the proof; at most 2 renders at once on this machine).

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL and run id.
