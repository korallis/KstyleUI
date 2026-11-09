# Media provenance

Every file in `Media/` has a row here: where it came from, how it was made, and when. No file is copied from another addon.

## Fonts

All fonts are under the SIL Open Font License 1.1; `Media/Fonts/OFL.txt` holds each project's licence text. No font has a Reserved Font Name that the files below would break: Source Sans's "Source" applies only to modified versions, and its files are unmodified.

Lumen's faces come from [google/fonts](https://github.com/google/fonts) at commit `5bb28733cec313b63fbd415b574b5ae35c8aa8b8`, downloaded on 2026-11-09. `Tools/media/make_fonts.py` makes the four files from the sources with fontTools 4.68.0, run from a throwaway virtual environment outside the repository (its docstring has the commands). It saves without touching the timestamp, so running it again gives the same bytes.

| File | Source | How it was made | SHA-256 |
| --- | --- | --- | --- |
| `Media/Fonts/Cinzel-SemiBold.ttf` | [`ofl/cinzel/Cinzel[wght].ttf`](https://github.com/google/fonts/blob/5bb28733cec313b63fbd415b574b5ae35c8aa8b8/ofl/cinzel/Cinzel%5Bwght%5D.ttf) (SHA-256 `f4d83d34d1f6c741193e4acf4b3dff9531e5a67b6aa65228d00a7db72a4e0f34`) | The variable font pinned at weight 600 with `fontTools.varLib.instancer` (`static=True`), named Cinzel SemiBold, weight class 600. Static TrueType (`glyf`) outlines, no `fvar`. | `9c3c347c3a80b1c92d26f2b2ee4558bbdbdea1028f74e8e951aa70095c88a09e` |
| `Media/Fonts/AlegreyaSansTabular-Regular.ttf` | [`ofl/alegreyasans/AlegreyaSans-Regular.ttf`](https://github.com/google/fonts/blob/5bb28733cec313b63fbd415b574b5ae35c8aa8b8/ofl/alegreyasans/AlegreyaSans-Regular.ttf) (SHA-256 `8fab634196007afca839f1e5a6fb300976daff55d8528b590ef032f01b14ea10`) | The digits 0 to 9 mapped in the character map to the font's own tabular lining figures (`zero.tf` to `nine.tf`, 475 units wide); the family renamed Alegreya Sans Tabular. Nothing else changes. | `e6ccbd3e17acbdb0679263654c1e4bbb0c7b3999ef8c75fdaa96569aaf045217` |
| `Media/Fonts/AlegreyaSansTabular-Medium.ttf` | [`ofl/alegreyasans/AlegreyaSans-Medium.ttf`](https://github.com/google/fonts/blob/5bb28733cec313b63fbd415b574b5ae35c8aa8b8/ofl/alegreyasans/AlegreyaSans-Medium.ttf) (SHA-256 `4b89fe7804fd1485ec2757795a53ffdb66e1206dd56f844c2d72b3c944815b43`) | As Regular. | `dfaeea3367c68b4c902c05dc0b380b3b3e46a7b9f4a65f50846678c7ab81458b` |
| `Media/Fonts/AlegreyaSansTabular-Bold.ttf` | [`ofl/alegreyasans/AlegreyaSans-Bold.ttf`](https://github.com/google/fonts/blob/5bb28733cec313b63fbd415b574b5ae35c8aa8b8/ofl/alegreyasans/AlegreyaSans-Bold.ttf) (SHA-256 `a3055a1893759bdbd7504bb22abc583769e7974c49353176eac0b03792c9fb8e`) | As Regular. | `8835842781fb18452989336edd03f085aa8c0f5184e569d13ceb3dafc8fd5909` |

Why the digits are remapped: the game's text renderer applies no OpenType features, so a font always draws its default figures. Alegreya Sans's default figures are oldstyle and proportional (the 3, 4, 5, 7 and 9 drop below the baseline, and each digit has its own width). The mockup asks for `font-variant-numeric: tabular-nums lining-nums`, and the font has `tnum` and `lnum` features the game cannot turn on, so the files point the digits straight at the tabular lining glyphs. Numbers then keep their width as they change, and no widget needs a fixed-width reservation for them. Cinzel's figures stay proportional; Cinzel is used for headings and captions, which do not count.

The other fonts are unmodified files from each project's GitHub release, downloaded on 2026-11-07.

| File | Source | Archive member | SHA-256 |
| --- | --- | --- | --- |
| `Media/Fonts/SourceSans3-Regular.ttf` | [`adobe-fonts/source-sans` 3.052R](https://github.com/adobe-fonts/source-sans/releases/tag/3.052R), `TTF-source-sans-3.052R.zip` | `TTF/SourceSans3-Regular.ttf` | `4644c81b86ec9caaa76b634889968ed3c4f4f52f054855933acc7c2b21e53b0f` |
| `Media/Fonts/SourceSans3-Semibold.ttf` | [`adobe-fonts/source-sans` 3.052R](https://github.com/adobe-fonts/source-sans/releases/tag/3.052R), `TTF-source-sans-3.052R.zip` | `TTF/SourceSans3-Semibold.ttf` | `a3f4f8dcf343a8f24dc61951de93f3ba1558b15cd250ba24af8a40e957081b7d` |
| `Media/Fonts/Inter-SemiBold.ttf` | [`rsms/inter` v4.1](https://github.com/rsms/inter/releases/tag/v4.1), `Inter-4.1.zip` | `extras/ttf/Inter-SemiBold.ttf` | `78a843fade9d4612a5567302fb595b56976eb5fcebf4fea5a5912d638bafcde3` |
| `Media/Fonts/OFL.txt` | Source Sans 3's `LICENSE.md` at tag 3.052R, Inter's `LICENSE.txt` from `Inter-4.1.zip`, then `ofl/cinzel/OFL.txt` and `ofl/alegreyasans/OFL.txt` at the google/fonts commit above | | |

Lumen is the default font set: Cinzel SemiBold for display, heading and caption text, Alegreya Sans Tabular Regular for body text, Bold for numbers and Medium with an outline for text over the world. Source Sans 3 Semibold, Source Sans 3 and Inter stay selectable; picking one sets every role to that face, with Source Sans 3 Semibold (whose digits are tabular by default) for numbers.

## Procedural textures and logo

`Tools/media/make_media.py` draws these files. No image model or prompt is involved: each texture is a shape or a smooth function sampled 4x4 times per pixel and averaged. Run `python3 Tools/media/make_media.py` to redraw them and this table.

Shapes are white with their coverage in alpha, so the game tints them with `SetVertexColor`. Chamfers and bevels are drawn at 4 texels per root unit. A texture with slice margins is a nine-slice source: a corner piece of `m` texels draws at `m / 4` root units, so the corners of the fill and both bevel lines line up. Every row and column between the margins is the same, so the edges and centre stretch cleanly. The shadow is drawn at 2 texels per unit: its 48-texel corner pieces are 24 units, centred on the panel's corners. `python3 -m unittest discover -s Tools/tests` fails when a file differs from what the script draws.

<!-- BEGIN make_media -->
| File | Size | What it is | Made with | Settings | Date |
| --- | --- | --- | --- | --- | --- |
| `Media/Textures/LumenShape.png` | 128x128 | Lumen card shape: a square with 14-unit round corners at 4 texels per unit. Nine-slice fill for the deep tint, the socket body and the dispel tint, or a mask. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled; slice margins 56 texels | 2026-11-09 |
| `Media/Textures/LumenFrost.png` | 128x128 | Lumen frost: the card shape with the mockup's vertical frost gradient baked into its alpha, falling from full at the top to 75% where the top corners end, 50% where the bottom corners start and 45% at the bottom. Nine-slice; tinted with the glass token. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled; columns between the margins match, rows hold the gradient; slice margins 56 texels | 2026-11-09 |
| `Media/Textures/LumenRim.png` | 128x128 | Lumen rim for 14-unit corners: a 0.75-unit line just inside the card's edge, full strength along the top, 33% on the sides and bottom (the mockup's 18% rim-soft under its 55% top light), easing around the top corners. Nine-slice. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled; slice margins 56 texels | 2026-11-09 |
| `Media/Textures/LumenRimSmall.png` | 128x128 | Lumen rim for 8-unit corners (sockets and small tiles): the same 0.75-unit line and top light on the smaller radius. Nine-slice. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled; slice margins 32 texels | 2026-11-09 |
| `Media/Textures/LumenOutline.png` | 128x128 | Even outline for 8-unit corners: the rim's 0.75-unit line at one strength all round, for highlight rings such as the group frames' target ring. Nine-slice. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled; slice margins 32 texels | 2026-11-09 |
| `Media/Textures/LumenGilt.png` | 128x128 | Gilt filament for a window or rail's top left corner, mirrored for the bottom right: a 1.5-unit line on the 14-unit radius with 18-unit legs that fade to a tip over their last 3 units. Covers 20 units from one unit outside the corner. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled | 2026-11-09 |
| `Media/Textures/LumenGem.png` | 64x64 | Gilt gem for section caps: a 7-unit square turned 45 degrees with four facets lit from the top left, in a 6-unit halo at half strength. Covers 16 units. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled, shading in the colour channels | 2026-11-09 |
| `Media/Textures/PillCapLeft.png` | 32x32 | Mask that rounds a bar fill's left end: a half disc on the left, solid on the right. Placed over the fill's first square with CLAMPTOWHITE, so the rest of the fill shows. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled | 2026-11-09 |
| `Media/Textures/PillCapRight.png` | 32x32 | Mask that rounds a bar fill's moving right end: PillCapLeft mirrored, anchored to the fill's edge. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled | 2026-11-09 |
| `Media/Textures/BarSheen.png` | 8x32 | The bar fill's top sheen: white from the top row fading to nothing 55% of the way down, the mockup's .bar i highlight. Tinted white at 35% over the fill. | `Tools/media/make_media.py`, procedural, no model | 4x supersampled gradient | 2026-11-09 |
| `Media/Textures/LensMask.png` | 512x512 | Round mask for the minimap lens: a disc touching the texture's edges. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled | 2026-11-09 |
| `Media/Textures/SocketMask.png` | 128x128 | Icon mask for sockets, portraits and every square icon: corners rounded 8 units on a 44-unit icon (18% of the side). | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled | 2026-11-09 |
| `Media/Textures/RuleFade.png` | 256x4 | Section cap rule: a line that fades from full at its left end to nothing at its right. | `Tools/media/make_media.py`, procedural, no model | smoothstep fade, 4x supersampled | 2026-11-09 |
| `Media/Textures/Shadow.png` | 128x128 | Nine-slice shadow falloff. Corner pieces are 12 units, centred on the panel's corners; the shadow reaches 6 units out. | `Tools/media/make_media.py`, procedural, no model | analytic Gaussian blur of a box, 4x supersampled; slice margins 24 texels | 2026-11-07 |
| `Media/Textures/LumenShadow.png` | 128x128 | The Lumen card's drop shadow: a shape rounded 6 units, dropped 3 units and blurred to reach 14, with the card's own 14-unit rounded shape cut out, as a CSS box shadow, so it never darkens the glass above it. Corner pieces are 28 units, centred on the card's corners. | `Tools/media/make_media.py`, procedural, no model | separable Gaussian blur (sigma 3.5 units) of the 4x4 supersampled shape at 2 texels per unit; slice margins 56 texels | 2026-11-09 |
| `Media/Textures/Glow.png` | 128x128 | Soft radial glow for procs, hover and selection. | `Tools/media/make_media.py`, procedural, no model | Gaussian falloff to zero at the edge, 4x4 supersampled | 2026-11-07 |
| `Media/Textures/Divider.png` | 256x4 | Divider line that fades out over 40% of its length at each end. | `Tools/media/make_media.py`, procedural, no model | smoothstep fades, 4x supersampled | 2026-11-07 |
| `Media/Textures/Noise.png` | 128x128 | Tileable grain for the smoked-glass surface, used at low alpha. | `Tools/media/make_media.py`, procedural, no model | seeded random field (seed 1107), 4x4 box-downsampled, 3x3 wrap blur | 2026-11-07 |
| `Media/Textures/Ring.png` | 128x128 | Thin ring, 8 texels wide, for round indicators and pings. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled | 2026-11-07 |
| `Media/Textures/RingBevel.png` | 128x128 | Bevelled ring for portraits and round badges: a 5-texel line from radius 57 to 62, shaded dark outside, lit in the middle and three quarters inside, so one tint reads as the mockup's thin metal ring. The disc under it shows for 2 texels outside; a portrait inside starts at radius 56. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled, shading in the colour channels | 2026-11-07 |
| `Media/Textures/BarFlat.png` | 256x32 | Flat status bar fill. | `Tools/media/make_media.py`, procedural, no model | solid | 2026-11-07 |
| `Media/Textures/BarSoft.png` | 256x32 | Status bar fill with a soft top-to-bottom gradient. | `Tools/media/make_media.py`, procedural, no model | 4x supersampled gradient | 2026-11-07 |
| `Media/Textures/BarGlass.png` | 256x32 | Status bar fill whose top is 12% brighter than its bottom, the design's near-flat health fill. | `Tools/media/make_media.py`, procedural, no model | 4x supersampled gradient | 2026-11-07 |
| `Media/Textures/MinimapMask.png` | 512x512 | Chamfered square mask for Minimap:SetMaskTexture and the minimap footer: the cut is 8 of 217 units, the frame's 12-unit chamfer at the map's 2-unit inset on the mockup's 221 frame. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled | 2026-11-07 |
| `Media/Textures/Dot.png` | 64x64 | Filled disc for toggle and slider knobs. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled | 2026-11-07 |
| `Media/Textures/Pill.png` | 64x32 | Capsule for toggle and slider tracks. Each round cap is 16 texels wide, so a widget three-slices it. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled | 2026-11-07 |
| `Media/Textures/GlyphChevron.png` | 32x32 | Downward chevron for dropdowns and scroll steppers. Flip the texture coordinates to point it up. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled | 2026-11-07 |
| `Media/Textures/GlyphClose.png` | 32x32 | Cross for close buttons. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled | 2026-11-07 |
| `Media/Logo/Logo64.png` | 64x64 | KstyleUI logo, the chamfered diamond, at 64 px. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled | 2026-11-07 |
| `Media/Logo/Logo64.tga` | 64x64 | Logo64 as a TGA for the TOC IconTexture line, which names the file without an extension. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled | 2026-11-07 |
| `Media/Logo/Logo256.png` | 256x256 | KstyleUI logo, the chamfered diamond, at 256 px. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled | 2026-11-07 |
<!-- END make_media -->

## Ability icons

The repainted icons are not in `Media/` and do not ship in the addon. Their art lives in [`Tools/icons/setB/`](../Tools/icons/setB/) with [`PROVENANCE.md`](../Tools/icons/setB/PROVENANCE.md), one row per icon, and ships as the loose-file icon pack described in [`docs/icons.md`](../docs/icons.md).

## Module media

Media that a module ships in its own folder. Each row names the script that draws the file.

| File | Size | What it is | Made with | Settings | Date |
| --- | --- | --- | --- | --- | --- |
| `KstyleUI_Minimap/Media/Glyphs.png` | 128x64 | Minimap button glyphs on 32-texel cells: tracking, mail, calendar, group finder and the addon drawer. White line art, tinted in game. | `Tools/media/make_minimap_glyphs.py`, procedural, no model | 2.6-texel strokes, 4x4 supersampled with `make_media.py`'s sampler | 2026-11-07 |
