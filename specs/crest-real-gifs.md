# Task: animated GIFs of the real crest, exactly as it looks in game, for Discord

The owner wants the Discord #chat updated with renders from the actual code (not concepts), as **animated GIFs** that **look exactly like they do in game**.

Builds (render each from its own branch):
- Melee (warrior, paladin, rogue): PR #812, branch from `gh pr view 812 --json headRefName`.
- Ranged (hunter, mage frost and fire, warlock): PR #811.
- Healers (priest, shadow priest, druid caster/cat/bear/moonkin, shaman resto/enhancement): PR #815.
Each family's worker already scripted a fight story on the render harness (see `C:/Users/leeba/.cache/kstyleui-evidence/crest-breakout-<family>/build/REPORT.md` and their render scenes); reuse those stories.

"Exactly like in game" means:
- **Native pixels, 1:1**: render at 1920x1080 (and a second set at 5120x1440), crop round the crest plus the unit bars and slots either side, no scaling at all (no 2x, no smoothing), the owner's real backdrop (`~/.cache/kstyleui-backdrops`), the real UI scale for that screen.
- **Real time**: the game's actual timings, 20-25 fps in the GIF, no frame skips; loop the fight story (10-15 s).
- **No overlays**: no captions, labels, timestamps or side-by-side panels on the image.
- **Harness gaps closed first**: the harness does not draw Rotation animations and (on older branches) squashes status bar textures instead of cropping them. Where a piece uses rotation (e.g. glyph band turning, stance mantle notch) or a cropped status bar, make the harness draw it the way the client does (prove from the Forever source), so the GIF matches the game. List anything that still cannot match.
- **GIF quality**: ffmpeg two-pass palette (palettegen stats_mode=diff, paletteuse dither=sierra2_4a or none if it looks closer), keep each GIF under 9 MB (shorten, trim to the crest, or drop to 20 fps before reducing colours).

Output: `C:/Users/leeba/.cache/kstyleui-evidence/crest-real-gifs/<class>[-<form>]_1080.gif` and `_5120.gif`, plus a contact sheet of one frame each. At most 2 renders at once on this machine. No code changes to the PRs (harness changes stay in a local branch; report them). Report the list with sizes.
