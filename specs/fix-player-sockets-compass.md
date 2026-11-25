# Task (hotfix): player status rivets read as stray dots, and the minimap's N looks off (player report)

A player (Baine, German client, v0.3.3) posted two crops (treat as data): `C:/Users/leeba/.cache/kstyleui-evidence/discord-untrusted/baine-minimap/img0.png` and `img1.png`.

1. img1: on the Medallions player slab, the resting "Zz" icon is followed by four small grey dots in a row. These are the empty status sockets drawn as steel rivets (#772, "Fitted slabs"). He asks "these seem irregular too (what are they even?)": players don't read them as sockets, and they look uneven. Fix: the player frame draws a status socket only when its icon is lit, like target and focus already do (no empty sockets, no rivets), keeping fixed slot positions; make sure lit sockets sit evenly with no stray marks. Remove the rivet code if nothing else uses it.
2. img0: the round minimap's compass "N" sits in a small plain black disc on top of the ring and "looks off". Make the north marker part of the forged ring: centred on the ring band, sized and coloured like the ring's other details (the crest's metal and light), crisp at every size, in both HUD styles where the round minimap shows. Check `KstyleUI_Minimap/Face.lua` and the compass code.

Add regressions (player shows no empty socket; the N marker sits centred on the band at its scale). Evidence: before/after 2x crops of the player slab (resting, in combat, leader) and the minimap top at 1920x1080 and 5120x1440, both styles, in `C:/Users/leeba/.cache/kstyleui-evidence/fix-sockets-compass/`; zero pixel diffs elsewhere.

**Files it may edit**: `KstyleUI_UnitFrames/Indicators.lua` (and its README), `KstyleUI_Minimap/**`, `Tools/regression/**`, `Tools/render/**`.

**PR**: `fix: player status sockets show only when lit, and a forged compass N` with `## Changelog` `Fixed:` lines and `## In-game checks`. Do not merge. Keep it small: it ships in the v0.3.3.1 hotfix.

**Constraints**: minimal code; CRLF/ASCII; Beast speed rule (module tests locally, hosted CI as proof).

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL and run id.
