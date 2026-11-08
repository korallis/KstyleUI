# Media provenance

Every file in `Media/` has a row here: where it came from, how it was made, and when. No file is copied from another addon.

## Fonts

The fonts are unmodified files from each project's GitHub release, downloaded on 2026-11-07. They are under the SIL Open Font License 1.1. `Media/Fonts/OFL.txt` holds both licence texts.

| File | Source | Archive member | SHA-256 |
| --- | --- | --- | --- |
| `Media/Fonts/SourceSans3-Regular.ttf` | [`adobe-fonts/source-sans` 3.052R](https://github.com/adobe-fonts/source-sans/releases/tag/3.052R), `TTF-source-sans-3.052R.zip` | `TTF/SourceSans3-Regular.ttf` | `4644c81b86ec9caaa76b634889968ed3c4f4f52f054855933acc7c2b21e53b0f` |
| `Media/Fonts/SourceSans3-Semibold.ttf` | [`adobe-fonts/source-sans` 3.052R](https://github.com/adobe-fonts/source-sans/releases/tag/3.052R), `TTF-source-sans-3.052R.zip` | `TTF/SourceSans3-Semibold.ttf` | `a3f4f8dcf343a8f24dc61951de93f3ba1558b15cd250ba24af8a40e957081b7d` |
| `Media/Fonts/Inter-SemiBold.ttf` | [`rsms/inter` v4.1](https://github.com/rsms/inter/releases/tag/v4.1), `Inter-4.1.zip` | `extras/ttf/Inter-SemiBold.ttf` | `78a843fade9d4612a5567302fb595b56976eb5fcebf4fea5a5912d638bafcde3` |
| `Media/Fonts/OFL.txt` | Source Sans 3's `LICENSE.md` at tag 3.052R, then Inter's `LICENSE.txt` from `Inter-4.1.zip` | | |

Source Sans 3 Semibold is the default UI font. Its digits are tabular by default, so numbers that change keep their width. Inter's default digits are proportional.

## Procedural textures and logo

`Tools/media/make_media.py` draws these files. No image model or prompt is involved: each texture is a shape or a smooth function sampled 4x4 times per pixel and averaged. Run `python3 Tools/media/make_media.py` to redraw them and this table.

Shapes are white with their coverage in alpha, so the game tints them with `SetVertexColor`. Chamfers and bevels are drawn at 4 texels per root unit. A texture with slice margins is a nine-slice source: a corner piece of `m` texels draws at `m / 4` root units, so the corners of the fill and both bevel lines line up. Every row and column between the margins is the same, so the edges and centre stretch cleanly. The shadow is drawn at 2 texels per unit: its 48-texel corner pieces are 24 units, centred on the panel's corners. `python3 -m unittest discover -s Tools/tests` fails when a file differs from what the script draws.

<!-- BEGIN make_media -->
| File | Size | What it is | Made with | Settings | Date |
| --- | --- | --- | --- | --- | --- |
| `Media/Textures/ChamferPanel.png` | 128x128 | Panel shape with 8-unit chamfers at 4 texels per unit. Nine-slice fill or mask. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled; slice margins 32 texels | 2026-11-07 |
| `Media/Textures/ChamferTile.png` | 32x32 | Tile and button shape with 3.5-unit chamfers at 4 texels per unit. Nine-slice fill or mask. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled; slice margins 14 texels | 2026-11-07 |
| `Media/Textures/ChamferWindow.png` | 128x128 | Window shape with 12-unit chamfers at 4 texels per unit. Nine-slice fill or mask. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled; slice margins 48 texels | 2026-11-07 |
| `Media/Textures/Line.png` | 4x4 | Line strip for the bevel corners: one opaque row (rows 1 of 4) between clear rows, mapped onto each chamfer's diagonal. | `Tools/media/make_media.py`, procedural, no model | solid | 2026-11-07 |
| `Media/Textures/ChamferIconMask.png` | 128x128 | Square mask for icons and portraits: a 3-unit chamfer on a 34-unit square. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled | 2026-11-07 |
| `Media/Textures/ChamferPortraitMask.png` | 128x128 | Square mask for the unit frames' chamfered portrait: the cut is 15% of the side, the design file's 10 units on 68. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled | 2026-11-07 |
| `Media/Textures/Shadow.png` | 128x128 | Nine-slice shadow falloff. Corner pieces are 12 units, centred on the panel's corners; the shadow reaches 6 units out. | `Tools/media/make_media.py`, procedural, no model | analytic Gaussian blur of a box, 4x supersampled; slice margins 24 texels | 2026-11-07 |
| `Media/Textures/Glow.png` | 128x128 | Soft radial glow for procs, hover and selection. | `Tools/media/make_media.py`, procedural, no model | Gaussian falloff to zero at the edge, 4x4 supersampled | 2026-11-07 |
| `Media/Textures/Divider.png` | 256x4 | Divider line that fades out over 40% of its length at each end. | `Tools/media/make_media.py`, procedural, no model | smoothstep fades, 4x supersampled | 2026-11-07 |
| `Media/Textures/Noise.png` | 128x128 | Tileable grain for the smoked-glass surface, used at low alpha. | `Tools/media/make_media.py`, procedural, no model | seeded random field (seed 1107), 4x4 box-downsampled, 3x3 wrap blur | 2026-11-07 |
| `Media/Textures/Ring.png` | 128x128 | Thin ring, 8 texels wide, for round indicators and pings. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled | 2026-11-07 |
| `Media/Textures/RingBevel.png` | 128x128 | Bevelled ring for portraits and round badges: a 5-texel line from radius 57 to 62, shaded dark outside, lit in the middle and three quarters inside, so one tint reads as the mockup's thin metal ring. The disc under it shows for 2 texels outside; a portrait inside starts at radius 56. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled, shading in the colour channels | 2026-11-07 |
| `Media/Textures/BarFlat.png` | 256x32 | Flat status bar fill. | `Tools/media/make_media.py`, procedural, no model | solid | 2026-11-07 |
| `Media/Textures/BarSoft.png` | 256x32 | Status bar fill with a soft top-to-bottom gradient. | `Tools/media/make_media.py`, procedural, no model | 4x supersampled gradient | 2026-11-07 |
| `Media/Textures/BarGlass.png` | 256x32 | Status bar fill whose top is 12% brighter than its bottom, the design's near-flat health fill. | `Tools/media/make_media.py`, procedural, no model | 4x supersampled gradient | 2026-11-07 |
| `Media/Textures/MinimapMask.png` | 128x128 | Square minimap mask for Minimap:SetMaskTexture. | `Tools/media/make_media.py`, procedural, no model | solid | 2026-11-07 |
| `Media/Textures/Dot.png` | 64x64 | Filled disc for toggle and slider knobs. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled | 2026-11-07 |
| `Media/Textures/Pill.png` | 64x32 | Capsule for toggle and slider tracks. Each round cap is 16 texels wide, so a widget three-slices it. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled | 2026-11-07 |
| `Media/Textures/GlyphChevron.png` | 32x32 | Downward chevron for dropdowns and scroll steppers. Flip the texture coordinates to point it up. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled | 2026-11-07 |
| `Media/Textures/GlyphClose.png` | 32x32 | Cross for close buttons. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled | 2026-11-07 |
| `Media/Logo/Logo64.png` | 64x64 | KstyleUI logo, the chamfered diamond, at 64 px. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled | 2026-11-07 |
| `Media/Logo/Logo64.tga` | 64x64 | Logo64 as a TGA for the TOC IconTexture line, which names the file without an extension. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled | 2026-11-07 |
| `Media/Logo/Logo256.png` | 256x256 | KstyleUI logo, the chamfered diamond, at 256 px. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled | 2026-11-07 |
<!-- END make_media -->

## Ability icons

The generated ability icons are not in `Media/`. Each icon set keeps its provenance next to its art: [`KstyleUI_Icons/PROVENANCE.md`](../KstyleUI_Icons/PROVENANCE.md) has a row for every set A icon, and [`KstyleUI_IconsColour/PROVENANCE.md`](../KstyleUI_IconsColour/PROVENANCE.md) one for every set B icon.

## Module media

Media that a module ships in its own folder. Each row names the script that draws the file.

| File | Size | What it is | Made with | Settings | Date |
| --- | --- | --- | --- | --- | --- |
| `KstyleUI_Minimap/Media/Glyphs.png` | 128x64 | Minimap button glyphs on 32-texel cells: tracking, mail, calendar, group finder and the addon drawer. White line art, tinted in game. | `Tools/media/make_minimap_glyphs.py`, procedural, no model | 2.6-texel strokes, 4x4 supersampled with `make_media.py`'s sampler | 2026-11-07 |
