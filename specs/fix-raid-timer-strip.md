# Task (polish): the Frames raid aura timer sits across the blue power strip

Found while reviewing #802 (expiring timers, merged): on the Frames HUD style the raid frames' aura timer text sits across the blue power strip at the bottom of the tile instead of inside the aura's own space. Move it so every raid and party aura timer (and stack count) sits fully inside its tile clear of the power strip and the health text, at 1920x1080, 2560x1440, 5120x1440 and 3840x2160, both HUD styles, without changing anything else (same font, size, colours, including the expiring colour). Never read state back from regions inside engine aura buttons.

Also tidy the two notes the #802 review left: the scope wording in `docs/core-visuals.md` and the `Tools/render/scenes/hud.lua` log line that calls target rows "crest debuffs".

Regression: the timer and count rects stay inside the tile and outside the power strip at the four sizes; prove it fails first. Evidence: 2x crops of raid and party tiles before/after at 1920x1080 and 5120x1440 in `C:/Users/leeba/.cache/kstyleui-evidence/fix-raid-timer-strip/`.

**Files it may edit**: `KstyleUI_GroupFrames/**`, `Tools/regression/**`, `Tools/render/**`, `docs/core-visuals.md`.

**PR**: `fix(group): raid aura timers sit clear of the power strip` with a `## Changelog` `Fixed:` line and `## In-game checks`. Do not merge.

**Constraints**: minimal code; CRLF/ASCII; Beast speed rule (at most 2 renders at once).

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL and run id.
