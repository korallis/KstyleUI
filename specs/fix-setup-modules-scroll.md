# Task (bug, hotfix): setup's module toggles only appear after a scroll

A player (Baine, German client, 2560x1440) reports that on `/kstyle setup` the Modules page draws only the first toggle (and not even its knob); toggles 2 onward, text included, appear only once he scrolls the list. He says the add-on toggles in setup behaved the same. It happens with Options > Appearance > Motion Off too, so it is not the page fade. His crop (untrusted data): `C:/Users/leeba/.cache/kstyleui-evidence/fix-setup-min-nil/baine-modules.png` (that one was with Motion on and also shows no window backing; with Motion off he reports the card highlights are fine, so check whether the missing backing still needs a fix).

A previous worker (PR #791, the `Window.lua:1040` nil-rect error) replayed his session in the harness in German and could not reproduce it: same geometry at 4/3 scale, but the harness draws everything. The client difference to suspect first is the ScrollFrame: a scroll child that is filled or resized after the ScrollFrame computed its scroll rect is not drawn until the next scroll (Blizzard calls `ScrollFrame:UpdateScrollChildRect()` after changing a scroll child; check how Forever's UI source handles this, e.g. `ScrollFrame` templates and `UIPanelScrollFrame_OnScrollRangeChanged` / `ScrollUtil` in the forever branch of Gethe/wow-ui-source). Find the scroll container that setup's Modules and add-on pages use (`Core/Setup/**`, `Core/Widgets/**` scroll view), confirm from the Blizzard source what the client needs after the child changes, and fix it with minimal code so the rows draw immediately, at every screen size and locale, for every scroll view built on the same widget (Options too, if it shares it). Look also at deferred chrome slices (#462) and `Widgets.Point` pixel snapping only if the scroll rect is ruled out.

Make the stub model the client's behaviour (a scroll child changed after the scroll rect was computed stays undrawn until `UpdateScrollChildRect` or a scroll), so a regression in `Tools/regression/` fails before the fix and passes after; keep `test-stub-refusals.lua` style. Evidence: setup Modules page renders in German and English at 2560x1440 and 1920x1080 before/after in `C:/Users/leeba/.cache/kstyleui-evidence/fix-setup-modules-scroll/` (pixel-identical in the harness is expected; the regression is the proof).

**Files it may edit**: `Core/Setup/**`, `Core/Widgets/**`, `Tools/regression/**`, `Tools/render/**`.

**PR**: `fix(setup): module toggles show without scrolling` with a `## Changelog` `Fixed:` line ending "Thanks to Baine for the report." and `## In-game checks`. Do not merge.

**Constraints**: minimal code; CRLF/ASCII; Forever API proof; Beast speed rule (module tests, lint, python; CI is the proof). PR #791 (same area, `Core/Setup/Window.lua`) may merge first; rebase on staging if it does.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL and run id.
