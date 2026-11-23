# Task: party frames are hard to read in game

The owner (2026-11-23, v0.3.1 from CurseForge, Medallions, 5120x1440, a three-player party): "took a screenshot of party frames. they're hard to read". Screenshot `C:/Users/leeba/.cache/kstyleui-evidence/party-ingame-full.jpg`, 4x zoom of the frames `party-ingame-zoom.png`. What the zoom shows:
- The frames are tiny for a 5120x1440 screen: each row is about 95 px wide and the text about 11 px tall.
- The health percent is cut to "10..." instead of "100%" on two rows.
- A name is cut short ("For", likely "For Titude" or longer) with no sign it was cut.
- Class-coloured names (shaman blue, paladin pink) are dim on the dark backing; the out-of-range member is dimmed so far its name barely reads.
- The missing-health part of the bar is a pale tint of the class colour, so a 45% bar reads as nearly full at a glance.

Make the party frames (and the raid frames where the same code applies) clearly readable at every screen size, in Medallions and Frames:
1. Size: the default party frame size must scale sensibly with the screen (compare with the unit frames and the reference renders; 1920x1080, 2560x1440, 5120x1440, 3840x2160). Players who set their own size keep it.
2. Text never truncates the health percent ("100%" always fits); names truncate with an ellipsis only when truly long and keep at least about 10 characters at the default size.
3. Contrast: names and numbers meet a readable contrast over the backing (use the readable-ink and soft-shadow helpers #745 added); out-of-range dimming keeps the name legible.
4. The missing-health part of the bar reads clearly as missing (dark track, as the unit frames do), not as a pale class tint.

Keep the one consistent style with the unit frames. Every visible change gets an Options setting, on by default (Party and Raid page), and off restores today's look. Evidence: renders of a 3- and 5-player party with mixed classes, health levels, one out of range, at all four sizes, both styles, over a real backdrop (`game_*`), plus a side-by-side with the owner's crop; in `C:/Users/leeba/.cache/kstyleui-evidence/party-readability/`.

**Files it may edit**: `KstyleUI_GroupFrames/**`, `Core/Setup/Layouts.lua` (sizes only, no new top-level locals), `KstyleUI_Options/**` (rows only), locales, `Tools/regression/**`, `Tools/render/**`, `docs/feature-map.md`.

**PR**: `fix(groupframes): party frames you can read at a glance` with `## Changelog`, `## Options`, `## In-game checks`. Do not merge.

**Constraints**: minimal code; CRLF/ASCII; no new per-frame work (group frames update often); `test-perf-fights` and `test-perf-path-budgets` with no new ceiling; Beast speed rule (module tests locally, hosted CI as proof).

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL and run id.
