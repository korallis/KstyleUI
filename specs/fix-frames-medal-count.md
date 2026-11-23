# Task: in the Frames tracker row, a medal's charge count runs past its edge

The crest trackers (all nine classes, merged in #776, #778, #771) put a Frames row of medals above the stance bar. The healer builder found that the shared Medal's charge or stack count runs past its medal's edge toward the next medal: `C:/Users/leeba/.cache/kstyleui-evidence/crest-trackers/healers/build/crops/DEFECTS.md` and its crop of priest Frames at 2560x1440.

Fix it in the shared Medal (`KstyleUI_ActionBars/SlabMedals.lua`) so every count sits inside its own medal's corner at every size and in both HUD styles (crest seats too), consistent with how other KstyleUI counts sit (inside the icon's corner, readable, with its outline). Check every class's counts: priest Inner Fire, warlock wisps, mage stacks, rogue poison count, warrior and paladin, druid and shaman. Add a regression that a count's rect stays inside its medal. Evidence: before/after 2x crops of the Frames row and the crest for a counted medal of each class at 1920x1080 and 5120x1440, in `C:/Users/leeba/.cache/kstyleui-evidence/fix-frames-medal-count/`; zero pixel diffs on uncounted medals.

**Files it may edit**: `KstyleUI_ActionBars/SlabMedals.lua` (and class Slab*.lua files only if a class overrides the count), `Tools/regression/**`, `Tools/render/**`.

**PR**: `fix(crest): medal counts stay inside their medal` with a `## Changelog` `Fixed:` line and `## In-game checks`. Do not merge.

**Constraints**: minimal code; CRLF/ASCII; Beast speed rule.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL and run id.
