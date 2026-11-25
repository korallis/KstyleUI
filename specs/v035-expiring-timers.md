# Task (v0.3.5): expiring aura timers stay readable over any scenery

Audit C35: when an aura timer is about to run out it turns a low-contrast red that is hard to read over scenery. Add one shared expiring colour in Core (`Core Duration.ExpiringColor` or the existing duration helper; find where timers pick their expiring colour across UnitFrames, GroupFrames, Auras, Nameplates and the crest) chosen for contrast with its outline over light and dark scenery, and use it everywhere timers turn "expiring", so all of them match (one consistent style). Keep the threshold logic as is. If there is already a colour setting, respect it.

Regression: every timer path that colours an expiring timer uses the shared colour; a contrast check of the colour against the outline. Evidence: 2x crops of expiring timers on the unit frames, raid frames, buff bar, nameplates and crest over a bright and a dark backdrop at 1920x1080 and 5120x1440, before/after, in `C:/Users/leeba/.cache/kstyleui-evidence/v035-expiring-timers/`.

**Files it may edit**: `Core/**` (Duration/Tokens only for the colour, with a reason in the PR since Tokens.lua is guarded), the modules that colour timers, `Tools/regression/**`, `Tools/render/**`.

**PR**: `feat(auras): expiring timers stay readable over any scenery` with a `## Changelog` `Changed:` line and `## In-game checks`. Do not merge.

**Constraints**: minimal code; CRLF/ASCII; both HUD styles; Beast speed rule (at most 2 renders at once).

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL and run id.
