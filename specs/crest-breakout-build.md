# Crest break-out: GO (owner, 2026-11-24)

The owner saw the animated mockups and said go. Build your family's break-out design (your Step 1 REPORT and hi-fi clips are the target) into your existing PR, replacing the socketed effects there.

- Rebase onto the latest origin/staging first: it now has all ten WeakAuras enhancements (#807 kill window/target lock, #808 rings, #810 Unleashed/Rising heat, #813 glyph tide/stance mantle), the shared sigils (#809), trinkets (#805), raid timers (#814). Fit your pieces around them (the cooldown row is sigils; rings, glyph band and coronas are already there).
- **Region budget**: the crest is at 4,898 of 4,900 created textures (test-widgets-lazy) and near test-perf-idle-draw's ceiling. Remove the old sockets, medal frames and backing textures your design replaces, share masks and textures, and build per-form pieces lazily so the totals stay within the current ceilings. Only if that is truly impossible, raise a ceiling by the measured amount with the reason in the PR body.
- Match the real-render clips' look and timings; every tracked thing keeps its switch; the #799 combat rules hold (nothing written under an engine aura button while auras are secret, size at build, replay on ADDON_RESTRICTION_STATE_CHANGED); nothing crosses the unit bars, cast bar, level badge or action slots at the four screen sizes; Frames shows the same objects free-standing.
- The no-icon guard stays and must also fail on any round socket frame for your pieces.
- Regressions for each piece (feed, states, toggle off, in-combat, Frames), failing first. Evidence: real-render clips at 1080 and 5120x1440 next to your Step 1 clips, 2x crops.
- Push to your PR, green CI, report. Then it gets one review.
