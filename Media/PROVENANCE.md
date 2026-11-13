# Media provenance

Every file in `Media/` has a row here: where it came from, how it was made, and when. No file is copied from another addon.

## Fonts

All fonts are under the SIL Open Font License 1.1; `Media/Fonts/OFL.txt` holds the original families' licence texts. Folio adds separate `OFL-EBGaramond.txt`, `OFL-IMFell.txt` and `OFL-PTSerif.txt` beside its files without replacing that existing licence bundle. Source Sans's "Source" applies only to modified versions, and its files are unmodified; Cinzel's licence names no Reserved Font Name, so renaming the modified Cinzel Caps and Cinzel Names is a courtesy, not a duty. Folio's Reserved Font Names and unmodified-copy contracts are recorded below.

Lumen's faces come from [google/fonts](https://github.com/google/fonts) at commit `5bb28733cec313b63fbd415b574b5ae35c8aa8b8`, downloaded on 2026-11-09. `Tools/media/make_fonts.py` makes the five files from the sources with fontTools (4.68.0 for the first four; 4.60.2 gives the same bytes for Cinzel SemiBold, which was checked, and made Cinzel Caps and Cinzel Names), run from a throwaway virtual environment outside the repository (its docstring has the commands; `--only cinzel` needs just `Cinzel[wght].ttf`). It saves without touching the timestamp, so running it again gives the same bytes.

| File | Source | How it was made | SHA-256 |
| --- | --- | --- | --- |
| `Media/Fonts/Cinzel-SemiBold.ttf` | [`ofl/cinzel/Cinzel[wght].ttf`](https://github.com/google/fonts/blob/5bb28733cec313b63fbd415b574b5ae35c8aa8b8/ofl/cinzel/Cinzel%5Bwght%5D.ttf) (SHA-256 `f4d83d34d1f6c741193e4acf4b3dff9531e5a67b6aa65228d00a7db72a4e0f34`) | The variable font pinned at weight 600 with `fontTools.varLib.instancer` (`static=True`), named Cinzel SemiBold, weight class 600. Static TrueType (`glyf`) outlines, no `fvar`. | `9c3c347c3a80b1c92d26f2b2ee4558bbdbdea1028f74e8e951aa70095c88a09e` |
| `Media/Fonts/CinzelCaps-Medium.ttf` | [`ofl/cinzel/Cinzel[wght].ttf`](https://github.com/google/fonts/blob/5bb28733cec313b63fbd415b574b5ae35c8aa8b8/ofl/cinzel/Cinzel%5Bwght%5D.ttf) (SHA-256 `f4d83d34d1f6c741193e4acf4b3dff9531e5a67b6aa65228d00a7db72a4e0f34`) | The variable font pinned at weight 500 with `fontTools.varLib.instancer` (`static=True`), then 65 units (0.065 em of 1000) added to the advance of every glyph that has one and 180 more to the space (495 in all, against Cinzel's 250), so the client draws letter-spaced capitals from the font itself, and each lowercase letter pointed at its capital in the character map (Cinzel draws lowercase as small capitals); the family renamed Cinzel Caps, weight class 500. The `caps` role: the gold captions. Outlines, left side bearings and kerning are Cinzel's. Static TrueType (`glyf`) outlines, no `fvar`. | `406ce658ff5e3210daa4bc0b0a92f3e737233f6e3d85dfbe5e91d2811b69a16f` |
| `Media/Fonts/CinzelNames-Medium.ttf` | [`ofl/cinzel/Cinzel[wght].ttf`](https://github.com/google/fonts/blob/5bb28733cec313b63fbd415b574b5ae35c8aa8b8/ofl/cinzel/Cinzel%5Bwght%5D.ttf) (SHA-256 `f4d83d34d1f6c741193e4acf4b3dff9531e5a67b6aa65228d00a7db72a4e0f34`) | The variable font pinned at weight 500 with `fontTools.varLib.instancer` (`static=True`), then no tracking and 160 units (0.16 em of 1000) added to the advance of the space (410 in all, against Cinzel's 250), so the client draws letter-spaced capitals from the font itself, and each lowercase letter pointed at its capital in the character map (Cinzel draws lowercase as small capitals); the family renamed Cinzel Names, weight class 500. The `names` role: the white names. Outlines, left side bearings and kerning are Cinzel's. Static TrueType (`glyf`) outlines, no `fvar`. | `8cb7474a2a962ccd152183b13e0776d9a04c20cccf4bcacebddae85b5ac7735f` |
| `Media/Fonts/CinzelUnit-Medium.ttf` | [`ofl/cinzel/Cinzel[wght].ttf`](https://github.com/google/fonts/blob/5bb28733cec313b63fbd415b574b5ae35c8aa8b8/ofl/cinzel/Cinzel%5Bwght%5D.ttf) (SHA-256 `f4d83d34d1f6c741193e4acf4b3dff9531e5a67b6aa65228d00a7db72a4e0f34`) | The variable font pinned at weight 500 with `fontTools.varLib.instancer` (`static=True`), then 64 units (0.064 em of 1000) taken off the advance of every glyph that has one and 250 added to the space (436 in all, against Cinzel's 250), so the client draws letter-spaced capitals from the font itself, and each lowercase letter pointed at its capital in the character map (Cinzel draws lowercase as small capitals); the family renamed Cinzel Unit, weight class 500. The `unit` role: the player and target names, which the picture draws at about 37 px and tighter than Cinzel's own advances (a fit of KORALLIS and SHADOWGALE POACHER against the picture gives -0.06 and -0.05 em at weight 500; the trailing advance is negative). Outlines, left side bearings and kerning are Cinzel's. Static TrueType (`glyf`) outlines, no `fvar`. | `b99db1b29441a2a67458427767a616f398d9bab7fbff66ffbc40149f8684f6d2` |
| `Media/Fonts/AlegreyaSansTabular-Regular.ttf` | [`ofl/alegreyasans/AlegreyaSans-Regular.ttf`](https://github.com/google/fonts/blob/5bb28733cec313b63fbd415b574b5ae35c8aa8b8/ofl/alegreyasans/AlegreyaSans-Regular.ttf) (SHA-256 `8fab634196007afca839f1e5a6fb300976daff55d8528b590ef032f01b14ea10`) | The digits 0 to 9 mapped in the character map to the font's own tabular oldstyle figures (`zero.tosf` to `nine.tosf`, 475 units wide); the family renamed Alegreya Sans Tabular. Nothing else changes. | `7292c6ef811abafe1620658f2fe3dcae071d5fb6ee86790932e69cbd028e2888` |
| `Media/Fonts/AlegreyaSansTabular-Medium.ttf` | [`ofl/alegreyasans/AlegreyaSans-Medium.ttf`](https://github.com/google/fonts/blob/5bb28733cec313b63fbd415b574b5ae35c8aa8b8/ofl/alegreyasans/AlegreyaSans-Medium.ttf) (SHA-256 `4b89fe7804fd1485ec2757795a53ffdb66e1206dd56f844c2d72b3c944815b43`) | As Regular. | `972ca3ca1efa29bbcdb0833e39cc18599e0b94eff7bfd7306f30ddaad8c15226` |
| `Media/Fonts/AlegreyaSansTabular-Bold.ttf` | [`ofl/alegreyasans/AlegreyaSans-Bold.ttf`](https://github.com/google/fonts/blob/5bb28733cec313b63fbd415b574b5ae35c8aa8b8/ofl/alegreyasans/AlegreyaSans-Bold.ttf) (SHA-256 `a3055a1893759bdbd7504bb22abc583769e7974c49353176eac0b03792c9fb8e`) | As Regular. | `1a5c53cfc2cb7e59f73afc79e0e5836ba01577f198e9da43d19706c60f5ddc5d` |
| `Media/Fonts/AlegreyaSans-Regular.ttf` | [`ofl/alegreyasans/AlegreyaSans-Regular.ttf`](https://github.com/google/fonts/blob/5bb28733cec313b63fbd415b574b5ae35c8aa8b8/ofl/alegreyasans/AlegreyaSans-Regular.ttf) (SHA-256 `8fab634196007afca839f1e5a6fb300976daff55d8528b590ef032f01b14ea10`) | Unmodified: the font as Alegreya Sans ships it, with its default oldstyle proportional figures, which is the picture's digits at the picture's widths. The `prose` role: static text whose figures change rarely (the experience bar's caption), where the tabular files' fixed 475-unit digit cells draw it wider than the picture (195 px against 189 on the owner's screen). Text that ticks (timers, health, damage, fps) stays on the tabular files. | `8fab634196007afca839f1e5a6fb300976daff55d8528b590ef032f01b14ea10` |
| `Media/Fonts/AlegreyaSansTabular-ExtraBold.ttf` | [`ofl/alegreyasans/AlegreyaSans-ExtraBold.ttf`](https://github.com/google/fonts/blob/5bb28733cec313b63fbd415b574b5ae35c8aa8b8/ofl/alegreyasans/AlegreyaSans-ExtraBold.ttf) (SHA-256 `3861f08a77d5c1b3b311055913443b07337a4b7abaff21a8cdb51fc0ae980b9e`) | As Regular, weight class 800. The `number` role: the picture draws its bold figures heavier than Bold (see below). | `99ef47d828e62b83156088020884b6a27789aefd7dab4b13480506e7b7beb05c` |

Why the numbers are Extra Bold (LEE-85): the picture's bold figures and words are heavier than Alegreya Sans Bold. The glyphs of each weight (Regular, Medium, Bold, ExtraBold, Black, with the digits remapped as below and the kit's tabular widths) were drawn at the kit's size, within 5%, with no kerning (the game applies none), at subpixel offsets, and compared with the picture's white ink by summed squared difference. Extra Bold fits the health value 203 (loss 12 against Bold's 32, Black's 22), the 50 of 50% (10, 27, 16), the damage totals 412 and 188 (20 and 20 against 26 and 22), Step 134 (50 against 69, Black 67) and the essential cooldown figures 4 and 12 (3 and 27 against 15 and 41), and Bold fits the clock 9:20 PM (16 and 15) and the cast time 1.2 / 2.5 (22 and 17) a little better. Summed over the seven strings Bold scores 208, Extra Bold 151 and Black 289, so Extra Bold takes the `number` role and the picture's heavier look, and the clock and the cast time, which fit Bold better, take their own `time` role in the Bold file. The picture's aura timers and small cooldown figures (45s, 14m, 7s, 8s, 14s) fit Medium (loss 5 to 12 against Regular's 6 to 16 and Bold's 4 to 13): they take their own `timer` role in the Medium file: the cooldown timers, the tracked-buff and bar timers and the unit-frame aura text. Both files already ship, so the roles add no font. The digits stay tabular at 475 units in every weight, so no number changes width; the letters widen by up to 2% (A is 600 units in Bold, 611 in Extra Bold) and no bold string grew by more than 0.6 px on the render.

Why the digits are remapped: the game's text renderer applies no OpenType features, so a font always draws its default figures. Alegreya Sans's default figures are oldstyle and proportional (the 3, 4, 5, 7 and 9 drop below the baseline, 0, 1 and 2 stand at x-height, and each digit has its own width), and the owner's picture draws exactly those: its percentages, health values, cast and cooldown figures, aura timers and damage rows show a hanging 3, 4, 5, 7 and 9 and a small 0, 1 and 2 (LEE-83, the Captain's reading of the picture at 4 times). The font has a `tnum` feature the game cannot turn on, so the files point the digits straight at the tabular oldstyle glyphs (`.tosf`, 475 units each): the picture's figures on fixed widths, so a ticking number never changes width and no widget needs a fixed-width reservation for them. The fixed width is the one difference left: the picture's proportional digits are narrower in places (a three-digit number is up to 3 px narrower than ours). `Tools/media/make_fonts.py --figures lining` points them at the tabular lining glyphs (`.tf`, the same 475 units; the mockup's `font-variant-numeric: tabular-nums lining-nums`) instead and gives the files this table recorded before LEE-83 (`e6ccbd3e17acbdb0679263654c1e4bbb0c7b3999ef8c75fdaa96569aaf045217`, `dfaeea3367c68b4c902c05dc0b380b3b3e46a7b9f4a65f50846678c7ab81458b`, `8835842781fb18452989336edd03f085aa8c0f5184e569d13ceb3dafc8fd5909` for Regular, Medium and Bold). Cinzel's figures stay proportional; Cinzel is used for headings and captions, which do not count.

The other fonts are unmodified files from each project's GitHub release, downloaded on 2026-11-07.

| File | Source | Archive member | SHA-256 |
| --- | --- | --- | --- |
| `Media/Fonts/SourceSans3-Regular.ttf` | [`adobe-fonts/source-sans` 3.052R](https://github.com/adobe-fonts/source-sans/releases/tag/3.052R), `TTF-source-sans-3.052R.zip` | `TTF/SourceSans3-Regular.ttf` | `4644c81b86ec9caaa76b634889968ed3c4f4f52f054855933acc7c2b21e53b0f` |
| `Media/Fonts/SourceSans3-Semibold.ttf` | [`adobe-fonts/source-sans` 3.052R](https://github.com/adobe-fonts/source-sans/releases/tag/3.052R), `TTF-source-sans-3.052R.zip` | `TTF/SourceSans3-Semibold.ttf` | `a3f4f8dcf343a8f24dc61951de93f3ba1558b15cd250ba24af8a40e957081b7d` |
| `Media/Fonts/Inter-SemiBold.ttf` | [`rsms/inter` v4.1](https://github.com/rsms/inter/releases/tag/v4.1), `Inter-4.1.zip` | `extras/ttf/Inter-SemiBold.ttf` | `78a843fade9d4612a5567302fb595b56976eb5fcebf4fea5a5912d638bafcde3` |
| `Media/Fonts/OFL.txt` | Source Sans 3's `LICENSE.md` at tag 3.052R, Inter's `LICENSE.txt` from `Inter-4.1.zip`, then `ofl/cinzel/OFL.txt` and `ofl/alegreyasans/OFL.txt` at the google/fonts commit above | | |

Why Cinzel is widened: the game has no letter-spacing call. `FontString:SetSpacing` is line spacing (Blizzard_APIDocumentationGenerated/SimpleFontStringAPIDocumentation.lua; the UI source uses it only on wrapped text) and no method on a FontString or a Font, nor any attribute in `UI.xsd`, spaces letters. Spacing letters with thin spaces needs a thin-space glyph, which Cinzel lacks (the game draws a box). So the tracking is part of the face. Three faces, because the picture spaces its gold captions, its white headings and its large unit names differently. How they were measured (owner's picture, 3456 by 2234, every heading 15 px of cap height, which is the 10-unit role at 2.0685 px per unit): the glyphs were drawn from Cinzel at 20.6 to 20.75 px for tracking 0 to 0.12 em and weights 400 to 700, with subpixel offsets, and compared with the picture's ink by summed squared difference. At weight 500 the gold captions fit 0.07 em (SKYBORNE), 0.06 (QUESTS) and 0.11 (DAMAGE), 0.065 jointly, and the white headings 0.01 (WINDFIELD ORCHARD), 0.04 (LIGHTNING BOLT), 0.02 to 0.03 (SHADOWGALE POACHER) and 0.01 to 0.02 (POACHER LOOKOUT), 0.02 jointly. The fit's loss is flat from weight 400 to 600 (heavier weights are wider, so they want less tracking), so weight was chosen by the strokes: a stem of the capital I measures 1.35 px at weight 400, 1.94 at 500 and 2.52 at 600 at this size, and the picture's stems read 2.1 to 2.8 px including the browser's halo; side by side at 5 times, weight 500 is the closest to the picture's captions (400 is thinner, 600 bolder). Measured on the game-side render, SKYBORNE's ink spans 118 px at weight 400 and 0.07 em against the picture's 119. The 0.15 em that a first reading of the picture suggests would make the word wider than the picture's. The gold captions carry no drop shadow in the picture (the pixels beside each stroke on its lower right are as bright as those on its upper left), so the caps face is drawn without the kit's text shadow; the white names have a soft halo (the ring two pixels to a stroke's lower right is darker than the background, the upper left's is not), which the client cannot draw, so the names face keeps a lighter hard shadow (docs/core-visuals.md has the measurement and the source files). The large unit names were fitted the same way, with the size free: KORALLIS (the player's name) and SHADOWGALE POACHER (the target's) fit Cinzel at weight 500, 37 to 38 px, with -0.06 and -0.05 em of tracking (a negative advance pulls the letters together; with the font's kerning switched on the fits move to -0.04 and -0.02, and the game applies none), and the word space is its own parameter beside the tracking, because the picture's browser sets a wider word space than Cinzel's and a tracking that fits the letters squeezes it (the target's gap at -0.055 em was 9 px against the picture's 18). A fit of the letters' tracking and the space's extra advance together, against the ink width and the widest word gap in each name (core pixels above 200, 3456 by 2234 picture and the game-side render), gives -0.065 em and 0.25 em extra for the unit face (SHADOWGALE POACHER 18 px gap, 445 px ink, the picture's 18 and 445), no tracking and 0.16 em extra for the names face (WINDFIELD ORCHARD 11 and 241 against the picture's 12 and 240, the plate's SHADOWGALE POACHER 11 and 267 against 11 and 266, POACHER LOOKOUT 10 and 220 against 10 and 220, LIGHTNING BOLT 12 and 186 against 12 and 192, COMBAT LOG 11 and 146 against 13 and 151) and 0.18 em extra at the caps face's 0.065 (1-9 SKYBORNE 14 px gap against the picture's 14). The picture's browser also kerns Cinzel's pairs, which the game cannot draw. `Widgets.ApplyFont` takes back the space the last letter leaves behind, a negative one for the unit face. The fonts have no thin space either, so nothing can space them with one. Build them with fontTools alone: with `uharfbuzz` installed fontTools packs GPOS differently and the bytes of the Cinzel files change, though the glyphs and advances do not; `make_fonts.py` refuses to run then, and `Tools/tests/test_fonts.py` checks that the files match the SHA-256 recorded here.

Lumen remains the selectable original font set: Cinzel SemiBold for display and heading text, Cinzel Caps, Cinzel Names and Cinzel Unit (Medium, spaced) for the `caps`, `names` and `unit` roles, Alegreya Sans Tabular Regular for body text, Medium for captions, Extra Bold for numbers and Medium with an outline for text over the world. Folio is now the default under the owner's LEE-113 ruling. Source Sans 3 Semibold, Source Sans 3 and Inter stay selectable; picking one sets every role to that face, with Source Sans 3 Semibold (whose digits are tabular by default) for numbers.

### Folio font assets

Folio's sources are pinned to [google/fonts commit `5bb28733cec313b63fbd415b574b5ae35c8aa8b8`](https://github.com/google/fonts/tree/5bb28733cec313b63fbd415b574b5ae35c8aa8b8), downloaded on 2026-11-10. `Tools/media/make_fonts.py --only folio --src DIR` builds only the six new files, never Lumen's files. `DIR` contains flat copies of `IMFeDPsc28P.ttf`, `EBGaramond[wght].ttf`, `Cinzel[wght].ttf`, `PT_Serif-Web-Regular.ttf` and `PT_Serif-Web-Bold.ttf`; their SHA-256 values are checked before any output is written. Run with fontTools 4.60.2 in an isolated environment outside the repository, without uharfbuzz. Timestamps are not recalculated. Rebuilding the existing default Lumen selection with this builder produced the same bytes for all eight generated files; every existing bundled font and `OFL.txt` stays byte-identical.

| File | Pinned source URL and source SHA-256 | Transform | Built SHA-256 | Bytes |
| --- | --- | --- | --- | ---: |
| `Media/Fonts/FolioDisplay-Regular.ttf` | [`ofl/imfelldoublepicasc/IMFeDPsc28P.ttf`](https://github.com/google/fonts/blob/5bb28733cec313b63fbd415b574b5ae35c8aa8b8/ofl/imfelldoublepicasc/IMFeDPsc28P.ttf), `cde1b1e206b36ef2f74ea4b2bf19786d99e93e1c65775b926701e1141726de81` | Unmodified binary copy, including cmap and internal family names. Weight 400, no added tracking or word spacing. Role code may uppercase text; this file is not remapped. | `cde1b1e206b36ef2f74ea4b2bf19786d99e93e1c65775b926701e1141726de81` | 197012 |
| `Media/Fonts/FolioCaps-SemiBold.ttf` | [`ofl/ebgaramond/EBGaramond[wght].ttf`](https://github.com/google/fonts/blob/5bb28733cec313b63fbd415b574b5ae35c8aa8b8/ofl/ebgaramond/EBGaramond%5Bwght%5D.ttf), `ef9512f92f6d579e5dc75af59a5a4b1b8b47d2eda89e00b954d44520e5369027` | Static weight 600; +0.045 em (45 units) on every positive advance, +0.08 em (80 more units) on the space, giving 350 units in all. Single-character lowercase-to-uppercase cmap mapping, including accented letters. Renamed Folio Caps SemiBold. | `013dfe836c3a9ffd9d746de47be5a9931115961a9e2ca545b0cfddd58e1dac95` | 520692 |
| `Media/Fonts/CinzelNames-SemiBold.ttf` | [`ofl/cinzel/Cinzel[wght].ttf`](https://github.com/google/fonts/blob/5bb28733cec313b63fbd415b574b5ae35c8aa8b8/ofl/cinzel/Cinzel%5Bwght%5D.ttf), `f4d83d34d1f6c741193e4acf4b3dff9531e5a67b6aa65228d00a7db72a4e0f34` | Static weight 600; no tracking; +0.16 em (160 units) on the space, giving 410 units. Uppercase cmap as above. Renamed Cinzel Names SemiBold. | `093759097bef8aecd9156e3f7f87dc4e0cd4023e39c67d5d17ea42eaf8e457c9` | 77760 |
| `Media/Fonts/CinzelUnit-SemiBold.ttf` | [`ofl/cinzel/Cinzel[wght].ttf`](https://github.com/google/fonts/blob/5bb28733cec313b63fbd415b574b5ae35c8aa8b8/ofl/cinzel/Cinzel%5Bwght%5D.ttf), `f4d83d34d1f6c741193e4acf4b3dff9531e5a67b6aa65228d00a7db72a4e0f34` | Static weight 600; -0.064 em (64 units removed) on every positive advance; +0.25 em (250 units) on the space, giving 436 units after tracking. Uppercase cmap as above. Renamed Cinzel Unit SemiBold. | `4bd8f69f468998747f024a26692fa3c06e865ae680c9d6ff15d48660b1f1e806` | 77756 |
| `Media/Fonts/PTSerif-Regular.ttf` | [`ofl/ptserif/PT_Serif-Web-Regular.ttf`](https://github.com/google/fonts/blob/5bb28733cec313b63fbd415b574b5ae35c8aa8b8/ofl/ptserif/PT_Serif-Web-Regular.ttf), `a4951fade06ff8f09b7673aa81ffb65a8cd409e24d3289a6dc670bc4dda2557a` | Unmodified binary copy. Weight 400; native tabular lining digits, no cmap remapping, tracking or word-spacing changes. | `a4951fade06ff8f09b7673aa81ffb65a8cd409e24d3289a6dc670bc4dda2557a` | 359048 |
| `Media/Fonts/PTSerif-Bold.ttf` | [`ofl/ptserif/PT_Serif-Web-Bold.ttf`](https://github.com/google/fonts/blob/5bb28733cec313b63fbd415b574b5ae35c8aa8b8/ofl/ptserif/PT_Serif-Web-Bold.ttf), `038ba7336bd7ea14f12ad155bed51a4345cac5153275d521dec3ba04021c526e` | Unmodified binary copy. Weight 700; native tabular lining digits, no cmap remapping, tracking or word-spacing changes. | `038ba7336bd7ea14f12ad155bed51a4345cac5153275d521dec3ba04021c526e` | 339996 |

The three transformed faces use `fontTools.varLib.instancer` with `static=True`; only instancing, horizontal advances, `hhea.advanceWidthMax`, `OS/2.xAvgCharWidth`, weight class, uppercase cmap and naming metadata change. Tracking is added after the last glyph too, as in Lumen; role integration compensates for it when aligning text. Multi-character uppercase expansions such as sharp s are not expressible as a one-glyph cmap mapping and retain their source mapping. There is no thin-space insertion and no synthetic outline change.

| Face | Default figures in the shipped cmap | Digit advance, font units | Units per em |
| --- | --- | --- | ---: |
| Folio Display Regular | IM Fell's native proportional oldstyle figures, unmodified | 0–9: 1050, 731, 1038, 786, 1104, 900, 1032, 940, 961, 1049 | 2048 |
| Folio Caps SemiBold | EB Garamond's native tabular lining figures, with tracking | 558 for each digit (513 + 45) | 1000 |
| Cinzel Names SemiBold | Cinzel's native proportional lining figures | 0–9: 634, 376, 596, 543, 607, 536, 607, 530, 586, 607 | 1000 |
| Cinzel Unit SemiBold | Cinzel's native proportional lining figures, with tracking | 0–9: 570, 312, 532, 479, 543, 472, 543, 466, 522, 543 | 1000 |
| PT Serif Regular | Native tabular lining figures; no OpenType feature selection needed | 533 for every digit | 1000 |
| PT Serif Bold | Native tabular lining figures; no OpenType feature selection needed | 565 for every digit | 1000 |

| Licence file | Pinned source | SHA-256: source; bundled copy | Reserved Font Names |
| --- | --- | --- | --- |
| `Media/Fonts/OFL-EBGaramond.txt` | [`ofl/ebgaramond/OFL.txt`](https://github.com/google/fonts/blob/5bb28733cec313b63fbd415b574b5ae35c8aa8b8/ofl/ebgaramond/OFL.txt) | `0985066662eb755ed3683ae5482a81a9195b49ce3f7e165cc2388b3dbece7dd7`; `b921242b4a54e7dbb2744fd44cc008f8b421d0585f8b902360a9300e00cb48b8` | None declared. The derivative is renamed Folio Caps SemiBold. |
| `Media/Fonts/OFL-IMFell.txt` | [`ofl/imfelldoublepicasc/OFL.txt`](https://github.com/google/fonts/blob/5bb28733cec313b63fbd415b574b5ae35c8aa8b8/ofl/imfelldoublepicasc/OFL.txt) | `2a3ca501fc4d5efcad9798531e3e06962b1e20c60e464f6cbd6c17630112c773`; `4a50b4c34bf783b09a89bc35e692b884f9a9aece17343174ce6170684540fee6` | `IM FELL Double Pica SC`, recorded in the source font's copyright name record. The binary is unmodified, so it retains that name. |
| `Media/Fonts/OFL-PTSerif.txt` | [`ofl/ptserif/OFL.txt`](https://github.com/google/fonts/blob/5bb28733cec313b63fbd415b574b5ae35c8aa8b8/ofl/ptserif/OFL.txt) | `ddf311c28ddf5a5ad9747649837346b67bed9d356789c3072bb27dbce49e514d`; `1037c6ad244bddf78bb822ec4b74354015ddae6db0a6c4e35d942e6ecfa5f5e3` | `PT Sans`, `PT Serif`, `ParaType`. Both binaries are unmodified and retain their names. |

The existing `OFL.txt` already includes the pinned Cinzel licence (no Reserved Font Name). The three new licence texts retain the source content; only trailing whitespace is removed by the repository's formatting hook. The six new TTF files total **1,572,264 bytes**; their three added licence files total **13,279 bytes**, for **1,585,543 additional uncompressed packaged asset bytes**, excluding this documentation. No Chinese font is bundled. `Core/Locale.lua`'s existing zhCN client-font substitution is unchanged: Chinese coverage is supplied by the client, not by our verified font corpus.

`Tools/tests/test_folio_fonts.py` reads the actual Windows Unicode cmap, not a font-family coverage claim. Every printable character in the keys and values of the shipped `enUS`, `deDE`, `frFR` and `esES` JSON locale tables is covered by every Folio file, including the uppercase of each string and accented letters: 83, 92, 108 and 98 distinct characters respectively at this build, 128 in their union, zero missing glyphs. The test recomputes that corpus when locale strings change. It also checks static TrueType outlines, weights, hashes, uppercase cmap mappings, baked tracking and word spacing, and the native PT Serif tabular lining digits. This is a cmap/metric check, not an in-game rasterization or arbitrary player-name coverage guarantee.

## Procedural textures and logo

`Tools/media/make_media.py` draws the procedural files below and re-exports the prepared sources for the optional card-material study. The procedural rows use no image model or prompt: each texture is a shape or a smooth function sampled 4x4 times per pixel and averaged. The study rows name their source model or pixel-construction method and retained prepared source; their prompts follow the table. Run `python3 Tools/media/make_media.py` to rebuild the files and this table.

Shapes are white with their coverage in alpha, so the game tints them with `SetVertexColor`. Chamfers and bevels are drawn at 4 texels per root unit. A texture with slice margins is a nine-slice source: a corner piece of `m` texels draws at `m / 4` root units, so the corners of the fill and both bevel lines line up. Every row and column between the margins is the same, so the edges and centre stretch cleanly. The shadow is drawn at 2 texels per unit: its 48-texel corner pieces are 24 units, centred on the panel's corners. `python3 -m unittest discover -s Tools/tests` fails when a file differs from what the script draws.

<!-- BEGIN make_media -->
| File | Size | What it is | Made with | Settings | Date |
| --- | --- | --- | --- | --- | --- |
| `Media/Textures/LumenShape.png` | 128x128 | Lumen card shape: a square with 14-unit round corners at 4 texels per unit. Nine-slice fill for the deep tint, the socket body and the dispel tint, or a mask. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled; slice margins 56 texels | 2026-11-09 |
| `Media/Textures/CardShape.png` | 128x128 | The card's fill: the rounded shape, a file of its own so a render tells a card's fill from a socket's. The kit draws its corner pieces five border lines square, one line inside the card's six-line edge, the picture's corner. Nine-slice. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled; slice margins 56 texels | 2026-11-09 |
| `Media/Textures/LumenOutline.png` | 128x128 | Even outline for 8-unit corners: a 0.75-unit line at one strength all round, for bar tracks and highlight rings such as the group frames' target ring. Nine-slice. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled; slice margins 32 texels | 2026-11-09 |
| `Media/Textures/RingLine2.png` | 128x128 | A quarter ring in each corner piece, one line thick on the outside of a corner 2 lines round: a card's dark edge (6), its rim and the arcs of its gilt L-ticks (5), a socket's dark edge (3) and its rim (2); the other counts serve short frames and pinned corners such as discs, so the kit draws the ring nearest the corner's line count. The kit draws each corner piece 2 border lines square, so the arc is one border line thick and meets the straight runs on whole pixels. Nine-slice; the runs are solid lines. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled; slice margins 64 texels | 2026-11-09 |
| `Media/Textures/RingLine3.png` | 128x128 | A quarter ring in each corner piece, one line thick on the outside of a corner 3 lines round: a card's dark edge (6), its rim and the arcs of its gilt L-ticks (5), a socket's dark edge (3) and its rim (2); the other counts serve short frames and pinned corners such as discs, so the kit draws the ring nearest the corner's line count. The kit draws each corner piece 3 border lines square, so the arc is one border line thick and meets the straight runs on whole pixels. Nine-slice; the runs are solid lines. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled; slice margins 64 texels | 2026-11-09 |
| `Media/Textures/RingLine4.png` | 128x128 | A quarter ring in each corner piece, one line thick on the outside of a corner 4 lines round: a card's dark edge (6), its rim and the arcs of its gilt L-ticks (5), a socket's dark edge (3) and its rim (2); the other counts serve short frames and pinned corners such as discs, so the kit draws the ring nearest the corner's line count. The kit draws each corner piece 4 border lines square, so the arc is one border line thick and meets the straight runs on whole pixels. Nine-slice; the runs are solid lines. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled; slice margins 64 texels | 2026-11-09 |
| `Media/Textures/RingLine5.png` | 128x128 | A quarter ring in each corner piece, one line thick on the outside of a corner 5 lines round: a card's dark edge (6), its rim and the arcs of its gilt L-ticks (5), a socket's dark edge (3) and its rim (2); the other counts serve short frames and pinned corners such as discs, so the kit draws the ring nearest the corner's line count. The kit draws each corner piece 5 border lines square, so the arc is one border line thick and meets the straight runs on whole pixels. Nine-slice; the runs are solid lines. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled; slice margins 64 texels | 2026-11-09 |
| `Media/Textures/RingLine6.png` | 128x128 | A quarter ring in each corner piece, one line thick on the outside of a corner 6 lines round: a card's dark edge (6), its rim and the arcs of its gilt L-ticks (5), a socket's dark edge (3) and its rim (2); the other counts serve short frames and pinned corners such as discs, so the kit draws the ring nearest the corner's line count. The kit draws each corner piece 6 border lines square, so the arc is one border line thick and meets the straight runs on whole pixels. Nine-slice; the runs are solid lines. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled; slice margins 64 texels | 2026-11-09 |
| `Media/Textures/RingLine8.png` | 128x128 | A quarter ring in each corner piece, one line thick on the outside of a corner 8 lines round: a card's dark edge (6), its rim and the arcs of its gilt L-ticks (5), a socket's dark edge (3) and its rim (2); the other counts serve short frames and pinned corners such as discs, so the kit draws the ring nearest the corner's line count. The kit draws each corner piece 8 border lines square, so the arc is one border line thick and meets the straight runs on whole pixels. Nine-slice; the runs are solid lines. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled; slice margins 64 texels | 2026-11-09 |
| `Media/Textures/RingLine10.png` | 128x128 | A quarter ring in each corner piece, one line thick on the outside of a corner 10 lines round: a card's dark edge (6), its rim and the arcs of its gilt L-ticks (5), a socket's dark edge (3) and its rim (2); the other counts serve short frames and pinned corners such as discs, so the kit draws the ring nearest the corner's line count. The kit draws each corner piece 10 border lines square, so the arc is one border line thick and meets the straight runs on whole pixels. Nine-slice; the runs are solid lines. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled; slice margins 64 texels | 2026-11-09 |
| `Media/Textures/RingLine12.png` | 128x128 | A quarter ring in each corner piece, one line thick on the outside of a corner 12 lines round: a card's dark edge (6), its rim and the arcs of its gilt L-ticks (5), a socket's dark edge (3) and its rim (2); the other counts serve short frames and pinned corners such as discs, so the kit draws the ring nearest the corner's line count. The kit draws each corner piece 12 border lines square, so the arc is one border line thick and meets the straight runs on whole pixels. Nine-slice; the runs are solid lines. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled; slice margins 64 texels | 2026-11-09 |
| `Media/Textures/RingLine16.png` | 128x128 | A quarter ring in each corner piece, one line thick on the outside of a corner 16 lines round: a card's dark edge (6), its rim and the arcs of its gilt L-ticks (5), a socket's dark edge (3) and its rim (2); the other counts serve short frames and pinned corners such as discs, so the kit draws the ring nearest the corner's line count. The kit draws each corner piece 16 border lines square, so the arc is one border line thick and meets the straight runs on whole pixels. Nine-slice; the runs are solid lines. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled; slice margins 64 texels | 2026-11-09 |
| `Media/Textures/RingLine20.png` | 128x128 | A quarter ring in each corner piece, one line thick on the outside of a corner 20 lines round: a card's dark edge (6), its rim and the arcs of its gilt L-ticks (5), a socket's dark edge (3) and its rim (2); the other counts serve short frames and pinned corners such as discs, so the kit draws the ring nearest the corner's line count. The kit draws each corner piece 20 border lines square, so the arc is one border line thick and meets the straight runs on whole pixels. Nine-slice; the runs are solid lines. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled; slice margins 64 texels | 2026-11-09 |
| `Media/Textures/RingLine24.png` | 128x128 | A quarter ring in each corner piece, one line thick on the outside of a corner 24 lines round: a card's dark edge (6), its rim and the arcs of its gilt L-ticks (5), a socket's dark edge (3) and its rim (2); the other counts serve short frames and pinned corners such as discs, so the kit draws the ring nearest the corner's line count. The kit draws each corner piece 24 border lines square, so the arc is one border line thick and meets the straight runs on whole pixels. Nine-slice; the runs are solid lines. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled; slice margins 64 texels | 2026-11-09 |
| `Media/Textures/RingLine32.png` | 128x128 | A quarter ring in each corner piece, one line thick on the outside of a corner 32 lines round: a card's dark edge (6), its rim and the arcs of its gilt L-ticks (5), a socket's dark edge (3) and its rim (2); the other counts serve short frames and pinned corners such as discs, so the kit draws the ring nearest the corner's line count. The kit draws each corner piece 32 border lines square, so the arc is one border line thick and meets the straight runs on whole pixels. Nine-slice; the runs are solid lines. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled; slice margins 64 texels | 2026-11-09 |
| `Media/Textures/Diamond.png` | 64x64 | The picture's caption bullet: a flat square turned 45 degrees, its points on the middle of the edges, with no facets and no halo. Tinted gilt at 8 units point to point (14 pixels on the owner's screen). | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled | 2026-11-10 |
| `Media/Textures/PillCapLeft.png` | 32x32 | Mask that rounds a bar fill's left end: a half disc on the left, solid on the right. Placed over the fill's first square with CLAMPTOWHITE, so the rest of the fill shows. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled | 2026-11-09 |
| `Media/Textures/PillCapRight.png` | 32x32 | Mask that rounds a bar fill's moving right end: PillCapLeft mirrored, anchored to the fill's edge. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled | 2026-11-09 |
| `Media/Textures/BarSheen.png` | 8x32 | The bar fill's top sheen: white from the top row fading to nothing 55% of the way down, the mockup's .bar i highlight. Tinted white at 35% over the fill. | `Tools/media/make_media.py`, procedural, no model | 4x supersampled gradient | 2026-11-09 |
| `Media/Textures/LensMask.png` | 512x512 | Round mask for the minimap lens: a disc touching the texture's edges. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled | 2026-11-09 |
| `Media/Textures/SocketMask.png` | 128x128 | Icon mask for sockets and every square icon: corners rounded 3 units on a 44-unit icon (7% of the side), to meet the socket's inner corner. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled | 2026-11-09 |
| `Media/Textures/PortraitMask.png` | 128x128 | Mask for the square portrait: corners rounded 8 units on a 44-unit image (18% of the side), inside the portrait frame's own rounder corner. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled | 2026-11-09 |
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
| `Media/Textures/MinimapMask.png` | 64x64 | Plain square mask for Minimap:SetMaskTexture: opaque white to every edge, so the map keeps square corners, as the owner's picture draws it (LEE-20: the picture wins over #207's chamfer). | `Tools/media/make_media.py`, procedural, no model | solid | 2026-11-09 |
| `Media/Textures/Dot.png` | 64x64 | Filled disc for toggle and slider knobs. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled | 2026-11-07 |
| `Media/Textures/Pill.png` | 64x32 | Capsule for toggle and slider tracks. Each round cap is 16 texels wide, so a widget three-slices it. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled | 2026-11-07 |
| `Media/Textures/GlyphChevron.png` | 32x32 | Downward chevron for dropdowns and scroll steppers. Flip the texture coordinates to point it up. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled | 2026-11-07 |
| `Media/Textures/GlyphClose.png` | 32x32 | Cross for close buttons. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled | 2026-11-07 |
| `Media/Logo/Logo64.png` | 64x64 | KstyleUI logo, the chamfered diamond, at 64 px. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled | 2026-11-07 |
| `Media/Logo/Logo64.tga` | 64x64 | Logo64 as a TGA for the TOC IconTexture line, which names the file without an extension. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled | 2026-11-07 |
| `Media/Logo/Logo256.png` | 256x256 | KstyleUI logo, the chamfered diamond, at 256 px. | `Tools/media/make_media.py`, procedural, no model | 4x4 supersampled | 2026-11-07 |
| `Media/Textures/MaterialSlate.png` | 256x256 | Prepared slate grain for the optional card-material study. | Higgsfield `gpt_image_2_6`; source-backed export by `Tools/media/make_media.py` | Prepared source in Tools/media/materials; lighting removed, 16px seam repair; prompt below | 2026-11-10 |
| `Media/Textures/MaterialForged.png` | 256x256 | Prepared forged grain for the optional card-material study. | Higgsfield `gpt_image_2_6`; source-backed export by `Tools/media/make_media.py` | Prepared source in Tools/media/materials; lighting removed, 16px seam repair; prompt below | 2026-11-10 |
| `Media/Textures/ForgedFrame1.png` | 32x32 | Original pixel-aligned forged-frame or header finish for the forged-material study. | Python/Pillow construction using original Higgsfield reference palettes | Prepared source in Tools/media/materials; source palette and pixel construction recorded below; slice margins 8 texels | 2026-11-10 |
| `Media/Textures/ForgedFrame2.png` | 64x64 | Original pixel-aligned forged-frame or header finish for the forged-material study. | Python/Pillow construction using original Higgsfield reference palettes | Prepared source in Tools/media/materials; source palette and pixel construction recorded below; slice margins 16 texels | 2026-11-10 |
| `Media/Textures/ForgedFrame3.png` | 128x128 | Original pixel-aligned forged-frame or header finish for the forged-material study. | Python/Pillow construction using original Higgsfield reference palettes | Prepared source in Tools/media/materials; source palette and pixel construction recorded below; slice margins 24 texels | 2026-11-10 |
| `Media/Textures/ForgedBracket1.png` | 8x8 | Original pixel-aligned forged-frame or header finish for the forged-material study. | Python/Pillow construction using original Higgsfield reference palettes | Prepared source in Tools/media/materials; source palette and pixel construction recorded below | 2026-11-10 |
| `Media/Textures/ForgedBracket2.png` | 16x16 | Original pixel-aligned forged-frame or header finish for the forged-material study. | Python/Pillow construction using original Higgsfield reference palettes | Prepared source in Tools/media/materials; source palette and pixel construction recorded below | 2026-11-10 |
| `Media/Textures/ForgedBracket3.png` | 32x32 | Original pixel-aligned forged-frame or header finish for the forged-material study. | Python/Pillow construction using original Higgsfield reference palettes | Prepared source in Tools/media/materials; source palette and pixel construction recorded below | 2026-11-10 |
| `Media/Textures/ForgedDiamond.png` | 64x64 | Original pixel-aligned forged-frame or header finish for the forged-material study. | Python/Pillow construction using original Higgsfield reference palettes | Prepared source in Tools/media/materials; source palette and pixel construction recorded below | 2026-11-10 |
| `Media/Textures/ForgedRule.png` | 256x4 | Original pixel-aligned forged-frame or header finish for the forged-material study. | Python/Pillow construction using original Higgsfield reference palettes | Prepared source in Tools/media/materials; source palette and pixel construction recorded below | 2026-11-10 |
| `Media/Textures/OrbMask.png` | 256x256 | Round mask for the Orbs HUD style's liquid: opaque white inside the orb's opening. | `Tools/media/make_media.py`, procedural, no model | centre sampled, disc edges 4x4 supersampled | 2026-11-12 |
| `Media/Textures/OrbBack.png` | 128x128 | The empty orb: glass lit from 34% down, white at its lit point, so SetVertexColor gives each orb its own dark tint under the liquid. | `Tools/media/make_media.py`, procedural, no model | centre sampled, disc edges 4x4 supersampled | 2026-11-13 |
| `Media/Textures/OrbGlass.png` | 128x128 | The orb's glass over the liquid: a rim that darkens towards the ring and four glints. | `Tools/media/make_media.py`, procedural, no model | centre sampled, disc edges 4x4 supersampled | 2026-11-12 |
| `Media/Textures/OrbLiquid.png` | 64x64 | Liquid fill for an orb's vertical status bar, shaded as a cylinder; SetStatusBarColor tints it. | `Tools/media/make_media.py`, procedural, no model | centre sampled, disc edges 4x4 supersampled | 2026-11-12 |
| `Media/Textures/OrbSurface.png` | 256x64 | The liquid's curved surface: an ellipse as wide as the orb and 11% as tall, lit from 35% down, centred on the fill's top edge and tinted with the liquid's colour; also the pale cap of the loss band. | `Tools/media/make_media.py`, procedural, no model | centre sampled, disc edges 4x4 supersampled | 2026-11-13 |
| `Media/Textures/OrbSurfaceLight.png` | 256x64 | The light over the surface ellipse: a white line along its top edge, a white sheen at its lit point and a soft shadow under it, drawn untinted. | `Tools/media/make_media.py`, procedural, no model | centre sampled, disc edges 4x4 supersampled | 2026-11-13 |
| `Media/Textures/OrbRing.png` | 512x512 | Forged ring around an orb, with its four spikes; its opening is 70.1% of the texture. | Higgsfield (KSTY-44 job 5a7af16a, the ring); production pass by `Tools/media/orbs.py` | Prepared source in Tools/media/materials by Tools/media/orbs.py (centred on its opening, premultiplied Lanczos resample, light unsharp mask); prompt below | 2026-11-12 |
| `Media/Textures/OrbArm.png` | 128x256 | The Orbs tray's arm: the forged bracket that joins an orb's ring to the tray, the tray hole's left edge at 47.2% across. | Higgsfield (KSTY-44 job 0b133988-204e-4852-89b6-a73ce6714226, the base); production pass by `Tools/media/orbs.py` | Prepared source in Tools/media/materials by Tools/media/orbs.py (cut from the base, rails joined from three segments, the last mirrored, with 40 px cross-fades, premultiplied Lanczos resample, light unsharp mask); prompt below | 2026-11-13 |
| `Media/Textures/OrbCrest.png` | 256x128 | The Orbs tray's centre crest over the top rail, between the two halves of action bar 2. | Higgsfield (KSTY-44 job 0b133988-204e-4852-89b6-a73ce6714226, the base); production pass by `Tools/media/orbs.py` | Prepared source in Tools/media/materials by Tools/media/orbs.py (cut from the base, rails joined from three segments, the last mirrored, with 40 px cross-fades, premultiplied Lanczos resample, light unsharp mask); prompt below | 2026-11-13 |
| `Media/Textures/OrbRail.png` | 1024x64 | The Orbs tray's top rail, one strip with cross-faded seams, stretched between the arms. | Higgsfield (KSTY-44 job 0b133988-204e-4852-89b6-a73ce6714226, the base); production pass by `Tools/media/orbs.py` | Prepared source in Tools/media/materials by Tools/media/orbs.py (cut from the base, rails joined from three segments, the last mirrored, with 40 px cross-fades, premultiplied Lanczos resample, light unsharp mask); prompt below | 2026-11-13 |
| `Media/Textures/OrbRailBottom.png` | 1024x64 | The Orbs tray's bottom rail, one strip with cross-faded seams, stretched between the arms. | Higgsfield (KSTY-44 job 0b133988-204e-4852-89b6-a73ce6714226, the base); production pass by `Tools/media/orbs.py` | Prepared source in Tools/media/materials by Tools/media/orbs.py (cut from the base, rails joined from three segments, the last mirrored, with 40 px cross-fades, premultiplied Lanczos resample, light unsharp mask); prompt below | 2026-11-13 |
| `Media/Textures/HudStyleFrames.png` | 512x256 | The Frames HUD style's picture for the settings window and the setup: the cast bar, cooldowns, target and player frames and the two-row tray, cropped from the hud_reference render. | KstyleUI's own render of its code (Tools/render/shoot.sh); no model | Prepared source in Tools/media/materials by Tools/media/hud_pictures.py from hud_reference renders at RENDER_SIZE=auto, 1920 by 1080 at 2 px per unit, with no backdrop, no stand-ins and the KstyleUI icon pack's repaints only; Lanczos to 512x256, opaque | 2026-11-13 |
| `Media/Textures/HudStyleOrbs.png` | 512x256 | The Orbs HUD style's picture for the settings window and the setup: the two orbs, the forged tray and the cast bar, cropped from the hud_reference render. | KstyleUI's own render of its code (Tools/render/shoot.sh); no model | Prepared source in Tools/media/materials by Tools/media/hud_pictures.py from hud_reference renders at RENDER_SIZE=auto, 1920 by 1080 at 2 px per unit, with no backdrop, no stand-ins and the KstyleUI icon pack's repaints only; Lanczos to 512x256, opaque | 2026-11-13 |
<!-- END make_media -->

## Card materials (study sources, 2026-11-10)

The Captain generated original style sources through Higgsfield `generateImage`, model `gpt_image_2_6`, on 2026-11-10. Source files and exact prompts are retained in the Captain drive at `handoffs/material-study/` and its `diablo4/` folder. The built-in image tool had no organisation credits; Higgsfield was callable only from the Captain's thread. The owner's direction was "assets should be based around Diablo 4 for that ultimate polish feel". No actual Diablo asset was used, traced or extracted.

The Slate prompt below ended: "even flat scanner light, low contrast, no objects, no text, no symbols, no frame, no vignette, no lighting gradient."

| Study texture | Source prompt | Processing |
| --- | --- | --- |
| `Media/Textures/MaterialSlate.png` | Seamless square orthographic material scan of dark charcoal worn slate, fine stone grain and shallow mineral fissures, restrained warm iron grey | 256x256, 8-bit RGBA PNG; monochrome detail; Lanczos reduction; subtract 32px Gaussian lighting field; map 2nd–98th percentiles to 64–192; blend 16px edge bands to identical opposing edges |
| `Media/Textures/MaterialForged.png` | Seamless tileable square orthographic texture for a dark gothic action RPG interface panel background: near-black desaturated charcoal stone with faint smoky mottling and very fine grain, cold neutral tone with a trace of warm brown, low contrast, even flat light, no text, no letters, no logos, no characters, no frame, no vignette, no lighting gradient. | Same processing; one shared source for the plain-tick and forged-bracket variants |

`ForgedFrame1`, `ForgedFrame2`, `ForgedFrame3`, `ForgedBracket1`, `ForgedBracket2` and `ForgedBracket3` were constructed with Python/Pillow on the same date, not cropped from a game asset. Their iron and bronze palettes are averaged from these original generated sources, then normalized to restrained highlight levels:

- Iron prompt: "Seamless tileable square orthographic material scan of dark forged blackened iron, subtle hammer marks, fine pitting, faint worn edges catching dull light, desaturated gunmetal, low contrast, even flat light, no text, no letters, no logos, no characters, no frame, no vignette."
- Bronze prompt: "Seamless tileable square orthographic material scan of aged dark bronze metal with muted antique gold highlights and darkened recesses, fine brushed wear, restrained, desaturated, low contrast, even flat light, no text, no letters, no logos, no characters, no frame, no vignette."

The frame has a dark outer band, forged-iron band and narrow aged-gold inner band, constructed directly on a one-, two- or three-pixel border grid. Its nine-slice files are 32x32 with 8px margins, 64x64 with 16px margins and 128x128 with 24px margins. Corners are sampled at one physical pixel per texel; straight edge strips are constant along their length, so stretching them does not stretch any grain. The 8x8 and 16x16 brackets, plus a 24x24 bracket in the top-left of its 32x32 source, are original angular L-inlays with a diagonal iron brace, also sampled one physical pixel per texel. The original generated frame/corner sheets were visual references only.

`ForgedDiamond` is a procedural dark-faced diamond in the existing diamond's exact alpha silhouette, tinted aged gold in game. `ForgedRule` is an original 256x4 alpha taper, constant vertically so a one-physical-pixel rule stays a solid pixel. Both were constructed with Python/Pillow on 2026-11-10, informed by the original generated divider/header reference, without extracting game art. The diamond and rule keep their original geometry; only their finish changes.

The stone grain uses one physical pixel per texel with explicit repeating UVs. The forged fill is opaque at its default strength. A quiet flat band inside the frame keeps grain out of corner arcs. No PNG encoding or filtering claim exceeds the existing RGBA PNG assets and matching 70862 PNG path evidence. Native loading and sampler parity still require a client restart and in-game inspection. Executable preparation recipes are retained with the study handoff; `make_media.py` re-exports the prepared sources in `Tools/media/materials`.

## Forged ornament study

Original painted sources generated by the project Captain with Higgsfield gpt_image_2_6 on 2026-11-10. No artwork was extracted or traced from a game. The source sheets and prompts are retained in the Captain's handoffs/ornament-study folder. Tools/media/painted_ornaments.py keys and despills their magenta backgrounds; Tools/media/ornaments.py crops, premultiplies, downsamples and masks the original painted pieces to preserve existing content. Runtime placement is one physical pixel per authored texel, without stretching. Every PNG uses RGBA encoding. Ring colours are reduced to 32 entries without dithering before RGBA export; fully transparent source pixels remain exactly transparent. Other pieces retain their downsampled RGBA samples. Native loading still needs the client's in-game pass.

The source SHA-256 hashes, crop sizes and PNG byte counts are recorded in `Media/Textures/ForgedOrnaments/manifest.json`. This remains a local, opt-in study.

| File | Native texels | Painted source cut | PNG bytes |
| --- | --- | --- | ---: |
| `Media/Textures/ForgedOrnaments/Arrow10.png` | 13x10 | cap-arrow-left | 568 |
| `Media/Textures/ForgedOrnaments/Arrow12.png` | 15x12 | cap-arrow-left | 684 |
| `Media/Textures/ForgedOrnaments/Arrow14.png` | 18x14 | cap-arrow-left | 888 |
| `Media/Textures/ForgedOrnaments/Arrow16.png` | 20x16 | cap-arrow-left | 1064 |
| `Media/Textures/ForgedOrnaments/Arrow20.png` | 25x20 | cap-arrow-left | 1522 |
| `Media/Textures/ForgedOrnaments/Arrow24.png` | 30x24 | cap-arrow-left | 1969 |
| `Media/Textures/ForgedOrnaments/Arrow28.png` | 35x28 | cap-arrow-left | 2529 |
| `Media/Textures/ForgedOrnaments/Arrow32.png` | 40x32 | cap-arrow-left | 3183 |
| `Media/Textures/ForgedOrnaments/Arrow6.png` | 8x6 | cap-arrow-left | 250 |
| `Media/Textures/ForgedOrnaments/Arrow8.png` | 10x8 | cap-arrow-left | 415 |
| `Media/Textures/ForgedOrnaments/BossPendantR17.png` | 23x37 | portrait-boss-pendant | 2156 |
| `Media/Textures/ForgedOrnaments/BossPendantR20.png` | 27x44 | portrait-boss-pendant | 2819 |
| `Media/Textures/ForgedOrnaments/BossPendantR24.png` | 32x52 | portrait-boss-pendant | 3547 |
| `Media/Textures/ForgedOrnaments/BossPendantR28.png` | 37x61 | portrait-boss-pendant | 4605 |
| `Media/Textures/ForgedOrnaments/BossPendantR32.png` | 42x70 | portrait-boss-pendant | 5741 |
| `Media/Textures/ForgedOrnaments/BossPendantR38.png` | 50x83 | portrait-boss-pendant | 7556 |
| `Media/Textures/ForgedOrnaments/BossPendantR44.png` | 58x96 | portrait-boss-pendant | 9702 |
| `Media/Textures/ForgedOrnaments/BossPendantR52.png` | 69x113 | portrait-boss-pendant | 13026 |
| `Media/Textures/ForgedOrnaments/BossPendantR60.png` | 80x131 | portrait-boss-pendant | 17159 |
| `Media/Textures/ForgedOrnaments/BossPendantR70.png` | 93x152 | portrait-boss-pendant | 22254 |
| `Media/Textures/ForgedOrnaments/BossPendantR80.png` | 106x174 | portrait-boss-pendant | 27959 |
| `Media/Textures/ForgedOrnaments/Corner12.png` | 14x12 | corner-plain | 531 |
| `Media/Textures/ForgedOrnaments/Corner16.png` | 18x16 | corner-plain | 743 |
| `Media/Textures/ForgedOrnaments/Corner20.png` | 23x20 | corner-plain | 1100 |
| `Media/Textures/ForgedOrnaments/Corner24.png` | 27x24 | corner-plain | 1432 |
| `Media/Textures/ForgedOrnaments/Crest20.png` | 25x20 | window-crest-open | 1464 |
| `Media/Textures/ForgedOrnaments/Crest32.png` | 39x32 | window-crest-open | 3015 |
| `Media/Textures/ForgedOrnaments/Crest48.png` | 59x48 | window-crest-open | 5965 |
| `Media/Textures/ForgedOrnaments/Crest64.png` | 79x64 | window-crest-open | 9818 |
| `Media/Textures/ForgedOrnaments/ElitePendantR17.png` | 13x22 | portrait-elite-pendant | 934 |
| `Media/Textures/ForgedOrnaments/ElitePendantR20.png` | 15x26 | portrait-elite-pendant | 1171 |
| `Media/Textures/ForgedOrnaments/ElitePendantR24.png` | 18x32 | portrait-elite-pendant | 1573 |
| `Media/Textures/ForgedOrnaments/ElitePendantR28.png` | 21x37 | portrait-elite-pendant | 2028 |
| `Media/Textures/ForgedOrnaments/ElitePendantR32.png` | 24x42 | portrait-elite-pendant | 2468 |
| `Media/Textures/ForgedOrnaments/ElitePendantR38.png` | 29x50 | portrait-elite-pendant | 3318 |
| `Media/Textures/ForgedOrnaments/ElitePendantR44.png` | 33x58 | portrait-elite-pendant | 4154 |
| `Media/Textures/ForgedOrnaments/ElitePendantR52.png` | 39x69 | portrait-elite-pendant | 5566 |
| `Media/Textures/ForgedOrnaments/ElitePendantR60.png` | 45x79 | portrait-elite-pendant | 6980 |
| `Media/Textures/ForgedOrnaments/ElitePendantR70.png` | 53x93 | portrait-elite-pendant | 9176 |
| `Media/Textures/ForgedOrnaments/ElitePendantR80.png` | 61x106 | portrait-elite-pendant | 11582 |
| `Media/Textures/ForgedOrnaments/EndClawed10.png` | 13x18 | frame-clawed | 963 |
| `Media/Textures/ForgedOrnaments/EndClawed11.png` | 15x19 | frame-clawed | 1121 |
| `Media/Textures/ForgedOrnaments/EndClawed12.png` | 16x21 | frame-clawed | 1228 |
| `Media/Textures/ForgedOrnaments/EndClawed13.png` | 17x23 | frame-clawed | 1401 |
| `Media/Textures/ForgedOrnaments/EndClawed14.png` | 19x24 | frame-clawed | 1636 |
| `Media/Textures/ForgedOrnaments/EndClawed15.png` | 20x26 | frame-clawed | 1830 |
| `Media/Textures/ForgedOrnaments/EndClawed16.png` | 21x28 | frame-clawed | 1971 |
| `Media/Textures/ForgedOrnaments/EndClawed17.png` | 23x30 | frame-clawed | 2190 |
| `Media/Textures/ForgedOrnaments/EndClawed18.png` | 24x32 | frame-clawed | 2392 |
| `Media/Textures/ForgedOrnaments/EndClawed19.png` | 25x33 | frame-clawed | 2524 |
| `Media/Textures/ForgedOrnaments/EndClawed20.png` | 27x35 | frame-clawed | 2828 |
| `Media/Textures/ForgedOrnaments/EndClawed21.png` | 28x37 | frame-clawed | 3073 |
| `Media/Textures/ForgedOrnaments/EndClawed22.png` | 29x38 | frame-clawed | 3240 |
| `Media/Textures/ForgedOrnaments/EndClawed23.png` | 31x40 | frame-clawed | 3495 |
| `Media/Textures/ForgedOrnaments/EndClawed24.png` | 32x42 | frame-clawed | 3688 |
| `Media/Textures/ForgedOrnaments/EndClawed25.png` | 33x44 | frame-clawed | 4044 |
| `Media/Textures/ForgedOrnaments/EndClawed26.png` | 35x46 | frame-clawed | 4345 |
| `Media/Textures/ForgedOrnaments/EndClawed27.png` | 36x47 | frame-clawed | 4498 |
| `Media/Textures/ForgedOrnaments/EndClawed28.png` | 37x49 | frame-clawed | 4784 |
| `Media/Textures/ForgedOrnaments/EndClawed29.png` | 39x51 | frame-clawed | 5126 |
| `Media/Textures/ForgedOrnaments/EndClawed30.png` | 40x52 | frame-clawed | 5344 |
| `Media/Textures/ForgedOrnaments/EndClawed31.png` | 41x54 | frame-clawed | 5596 |
| `Media/Textures/ForgedOrnaments/EndClawed32.png` | 43x56 | frame-clawed | 6017 |
| `Media/Textures/ForgedOrnaments/EndClawed33.png` | 44x58 | frame-clawed | 6358 |
| `Media/Textures/ForgedOrnaments/EndClawed34.png` | 45x60 | frame-clawed | 6503 |
| `Media/Textures/ForgedOrnaments/EndClawed35.png` | 47x61 | frame-clawed | 6862 |
| `Media/Textures/ForgedOrnaments/EndClawed36.png` | 48x63 | frame-clawed | 7215 |
| `Media/Textures/ForgedOrnaments/EndClawed37.png` | 49x65 | frame-clawed | 7542 |
| `Media/Textures/ForgedOrnaments/EndClawed38.png` | 51x66 | frame-clawed | 7814 |
| `Media/Textures/ForgedOrnaments/EndClawed39.png` | 52x68 | frame-clawed | 8176 |
| `Media/Textures/ForgedOrnaments/EndClawed40.png` | 53x70 | frame-clawed | 8517 |
| `Media/Textures/ForgedOrnaments/EndClawed41.png` | 55x72 | frame-clawed | 9037 |
| `Media/Textures/ForgedOrnaments/EndClawed42.png` | 56x74 | frame-clawed | 9285 |
| `Media/Textures/ForgedOrnaments/EndClawed43.png` | 57x75 | frame-clawed | 9598 |
| `Media/Textures/ForgedOrnaments/EndClawed44.png` | 59x77 | frame-clawed | 10049 |
| `Media/Textures/ForgedOrnaments/EndClawed45.png` | 60x79 | frame-clawed | 10444 |
| `Media/Textures/ForgedOrnaments/EndClawed46.png` | 61x80 | frame-clawed | 10639 |
| `Media/Textures/ForgedOrnaments/EndClawed47.png` | 63x82 | frame-clawed | 11196 |
| `Media/Textures/ForgedOrnaments/EndClawed48.png` | 64x84 | frame-clawed | 11445 |
| `Media/Textures/ForgedOrnaments/EndClawed52.png` | 69x91 | frame-clawed | 13345 |
| `Media/Textures/ForgedOrnaments/EndClawed56.png` | 75x98 | frame-clawed | 15049 |
| `Media/Textures/ForgedOrnaments/EndClawed60.png` | 80x105 | frame-clawed | 16869 |
| `Media/Textures/ForgedOrnaments/EndClawed64.png` | 85x112 | frame-clawed | 18688 |
| `Media/Textures/ForgedOrnaments/EndClawed8.png` | 11x14 | frame-clawed | 698 |
| `Media/Textures/ForgedOrnaments/EndClawed9.png` | 12x16 | frame-clawed | 801 |
| `Media/Textures/ForgedOrnaments/EndPointed10.png` | 12x10 | frame-pointed | 533 |
| `Media/Textures/ForgedOrnaments/EndPointed11.png` | 14x11 | frame-pointed | 629 |
| `Media/Textures/ForgedOrnaments/EndPointed12.png` | 15x12 | frame-pointed | 701 |
| `Media/Textures/ForgedOrnaments/EndPointed13.png` | 16x13 | frame-pointed | 732 |
| `Media/Textures/ForgedOrnaments/EndPointed14.png` | 17x14 | frame-pointed | 857 |
| `Media/Textures/ForgedOrnaments/EndPointed15.png` | 18x15 | frame-pointed | 932 |
| `Media/Textures/ForgedOrnaments/EndPointed16.png` | 20x16 | frame-pointed | 1050 |
| `Media/Textures/ForgedOrnaments/EndPointed17.png` | 21x17 | frame-pointed | 1170 |
| `Media/Textures/ForgedOrnaments/EndPointed18.png` | 22x18 | frame-pointed | 1241 |
| `Media/Textures/ForgedOrnaments/EndPointed19.png` | 23x19 | frame-pointed | 1361 |
| `Media/Textures/ForgedOrnaments/EndPointed20.png` | 25x20 | frame-pointed | 1500 |
| `Media/Textures/ForgedOrnaments/EndPointed21.png` | 26x21 | frame-pointed | 1596 |
| `Media/Textures/ForgedOrnaments/EndPointed22.png` | 27x22 | frame-pointed | 1686 |
| `Media/Textures/ForgedOrnaments/EndPointed23.png` | 28x23 | frame-pointed | 1786 |
| `Media/Textures/ForgedOrnaments/EndPointed24.png` | 30x24 | frame-pointed | 1944 |
| `Media/Textures/ForgedOrnaments/EndPointed25.png` | 31x25 | frame-pointed | 2045 |
| `Media/Textures/ForgedOrnaments/EndPointed26.png` | 32x26 | frame-pointed | 2104 |
| `Media/Textures/ForgedOrnaments/EndPointed27.png` | 33x27 | frame-pointed | 2281 |
| `Media/Textures/ForgedOrnaments/EndPointed28.png` | 35x28 | frame-pointed | 2462 |
| `Media/Textures/ForgedOrnaments/EndPointed29.png` | 36x29 | frame-pointed | 2602 |
| `Media/Textures/ForgedOrnaments/EndPointed30.png` | 37x30 | frame-pointed | 2751 |
| `Media/Textures/ForgedOrnaments/EndPointed31.png` | 38x31 | frame-pointed | 2842 |
| `Media/Textures/ForgedOrnaments/EndPointed32.png` | 39x32 | frame-pointed | 2972 |
| `Media/Textures/ForgedOrnaments/EndPointed33.png` | 41x33 | frame-pointed | 3184 |
| `Media/Textures/ForgedOrnaments/EndPointed34.png` | 42x34 | frame-pointed | 3339 |
| `Media/Textures/ForgedOrnaments/EndPointed35.png` | 43x35 | frame-pointed | 3480 |
| `Media/Textures/ForgedOrnaments/EndPointed36.png` | 44x36 | frame-pointed | 3637 |
| `Media/Textures/ForgedOrnaments/EndPointed37.png` | 46x37 | frame-pointed | 3803 |
| `Media/Textures/ForgedOrnaments/EndPointed38.png` | 47x38 | frame-pointed | 3984 |
| `Media/Textures/ForgedOrnaments/EndPointed39.png` | 48x39 | frame-pointed | 4144 |
| `Media/Textures/ForgedOrnaments/EndPointed40.png` | 49x40 | frame-pointed | 4285 |
| `Media/Textures/ForgedOrnaments/EndPointed41.png` | 51x41 | frame-pointed | 4493 |
| `Media/Textures/ForgedOrnaments/EndPointed42.png` | 52x42 | frame-pointed | 4695 |
| `Media/Textures/ForgedOrnaments/EndPointed43.png` | 53x43 | frame-pointed | 4901 |
| `Media/Textures/ForgedOrnaments/EndPointed44.png` | 54x44 | frame-pointed | 5036 |
| `Media/Textures/ForgedOrnaments/EndPointed45.png` | 55x45 | frame-pointed | 5181 |
| `Media/Textures/ForgedOrnaments/EndPointed46.png` | 57x46 | frame-pointed | 5411 |
| `Media/Textures/ForgedOrnaments/EndPointed47.png` | 58x47 | frame-pointed | 5612 |
| `Media/Textures/ForgedOrnaments/EndPointed48.png` | 59x48 | frame-pointed | 5813 |
| `Media/Textures/ForgedOrnaments/EndPointed52.png` | 64x52 | frame-pointed | 6489 |
| `Media/Textures/ForgedOrnaments/EndPointed56.png` | 69x56 | frame-pointed | 7524 |
| `Media/Textures/ForgedOrnaments/EndPointed60.png` | 74x60 | frame-pointed | 8441 |
| `Media/Textures/ForgedOrnaments/EndPointed64.png` | 79x64 | frame-pointed | 9308 |
| `Media/Textures/ForgedOrnaments/EndPointed8.png` | 10x8 | frame-pointed | 390 |
| `Media/Textures/ForgedOrnaments/EndPointed9.png` | 11x9 | frame-pointed | 453 |
| `Media/Textures/ForgedOrnaments/Forge2.png` | 1020x2 | rail-riveted | 119 |
| `Media/Textures/ForgedOrnaments/Forge3.png` | 1017x3 | rail-riveted | 211 |
| `Media/Textures/ForgedOrnaments/Forge4.png` | 1020x4 | rail-riveted | 280 |
| `Media/Textures/ForgedOrnaments/Forge5.png` | 1020x5 | rail-riveted | 327 |
| `Media/Textures/ForgedOrnaments/Forge6.png` | 1008x6 | rail-riveted | 383 |
| `Media/Textures/ForgedOrnaments/Forge7.png` | 1008x7 | rail-riveted | 433 |
| `Media/Textures/ForgedOrnaments/Rail1.png` | 16x1 | rail-gold | 123 |
| `Media/Textures/ForgedOrnaments/Rail10.png` | 16x10 | rail-gold | 493 |
| `Media/Textures/ForgedOrnaments/Rail11.png` | 16x11 | rail-gold | 524 |
| `Media/Textures/ForgedOrnaments/Rail2.png` | 16x2 | rail-gold | 165 |
| `Media/Textures/ForgedOrnaments/Rail3.png` | 16x3 | rail-gold | 209 |
| `Media/Textures/ForgedOrnaments/Rail4.png` | 16x4 | rail-gold | 243 |
| `Media/Textures/ForgedOrnaments/Rail5.png` | 16x5 | rail-gold | 286 |
| `Media/Textures/ForgedOrnaments/Rail6.png` | 16x6 | rail-gold | 326 |
| `Media/Textures/ForgedOrnaments/Rail7.png` | 16x7 | rail-gold | 375 |
| `Media/Textures/ForgedOrnaments/Rail8.png` | 16x8 | rail-gold | 405 |
| `Media/Textures/ForgedOrnaments/Rail9.png` | 16x9 | rail-gold | 454 |
| `Media/Textures/ForgedOrnaments/Ring100.png` | 128x128 | portrait-plain | 5562 |
| `Media/Textures/ForgedOrnaments/Ring102.png` | 130x130 | portrait-plain | 6288 |
| `Media/Textures/ForgedOrnaments/Ring104.png` | 132x132 | portrait-plain | 6264 |
| `Media/Textures/ForgedOrnaments/Ring106.png` | 134x134 | portrait-plain | 6143 |
| `Media/Textures/ForgedOrnaments/Ring110.png` | 140x140 | portrait-plain | 6852 |
| `Media/Textures/ForgedOrnaments/Ring112.png` | 142x142 | portrait-plain | 6831 |
| `Media/Textures/ForgedOrnaments/Ring116.png` | 148x148 | portrait-plain | 7125 |
| `Media/Textures/ForgedOrnaments/Ring118.png` | 150x150 | portrait-plain | 7580 |
| `Media/Textures/ForgedOrnaments/Ring120.png` | 152x152 | portrait-plain | 7414 |
| `Media/Textures/ForgedOrnaments/Ring122.png` | 156x156 | portrait-plain | 8377 |
| `Media/Textures/ForgedOrnaments/Ring124.png` | 158x158 | portrait-plain | 7905 |
| `Media/Textures/ForgedOrnaments/Ring126.png` | 160x160 | portrait-plain | 7901 |
| `Media/Textures/ForgedOrnaments/Ring128.png` | 162x162 | portrait-plain | 8961 |
| `Media/Textures/ForgedOrnaments/Ring130.png` | 166x166 | portrait-plain | 8650 |
| `Media/Textures/ForgedOrnaments/Ring134.png` | 170x170 | portrait-plain | 8704 |
| `Media/Textures/ForgedOrnaments/Ring138.png` | 176x176 | portrait-plain | 9718 |
| `Media/Textures/ForgedOrnaments/Ring140.png` | 178x178 | portrait-plain | 9114 |
| `Media/Textures/ForgedOrnaments/Ring144.png` | 184x184 | portrait-plain | 10115 |
| `Media/Textures/ForgedOrnaments/Ring146.png` | 186x186 | portrait-plain | 10197 |
| `Media/Textures/ForgedOrnaments/Ring148.png` | 188x188 | portrait-plain | 9898 |
| `Media/Textures/ForgedOrnaments/Ring152.png` | 194x194 | portrait-plain | 11360 |
| `Media/Textures/ForgedOrnaments/Ring154.png` | 196x196 | portrait-plain | 10629 |
| `Media/Textures/ForgedOrnaments/Ring158.png` | 202x202 | portrait-plain | 11686 |
| `Media/Textures/ForgedOrnaments/Ring160.png` | 204x204 | portrait-plain | 11880 |
| `Media/Textures/ForgedOrnaments/Ring26.png` | 34x34 | portrait-plain | 902 |
| `Media/Textures/ForgedOrnaments/Ring28.png` | 36x36 | portrait-plain | 1148 |
| `Media/Textures/ForgedOrnaments/Ring30.png` | 38x38 | portrait-plain | 1125 |
| `Media/Textures/ForgedOrnaments/Ring32.png` | 40x40 | portrait-plain | 1033 |
| `Media/Textures/ForgedOrnaments/Ring34.png` | 42x42 | portrait-plain | 1162 |
| `Media/Textures/ForgedOrnaments/Ring36.png` | 46x46 | portrait-plain | 1483 |
| `Media/Textures/ForgedOrnaments/Ring38.png` | 48x48 | portrait-plain | 1626 |
| `Media/Textures/ForgedOrnaments/Ring39.png` | 49x49 | portrait-plain | 1713 |
| `Media/Textures/ForgedOrnaments/Ring40.png` | 50x50 | portrait-plain | 1797 |
| `Media/Textures/ForgedOrnaments/Ring42.png` | 52x52 | portrait-plain | 1801 |
| `Media/Textures/ForgedOrnaments/Ring44.png` | 56x56 | portrait-plain | 1922 |
| `Media/Textures/ForgedOrnaments/Ring46.png` | 58x58 | portrait-plain | 2091 |
| `Media/Textures/ForgedOrnaments/Ring48.png` | 60x60 | portrait-plain | 2069 |
| `Media/Textures/ForgedOrnaments/Ring50.png` | 64x64 | portrait-plain | 2494 |
| `Media/Textures/ForgedOrnaments/Ring52.png` | 66x66 | portrait-plain | 2451 |
| `Media/Textures/ForgedOrnaments/Ring54.png` | 68x68 | portrait-plain | 2430 |
| `Media/Textures/ForgedOrnaments/Ring56.png` | 70x70 | portrait-plain | 3012 |
| `Media/Textures/ForgedOrnaments/Ring58.png` | 74x74 | portrait-plain | 2919 |
| `Media/Textures/ForgedOrnaments/Ring59.png` | 75x75 | portrait-plain | 2671 |
| `Media/Textures/ForgedOrnaments/Ring60.png` | 76x76 | portrait-plain | 2675 |
| `Media/Textures/ForgedOrnaments/Ring62.png` | 78x78 | portrait-plain | 2760 |
| `Media/Textures/ForgedOrnaments/Ring64.png` | 80x80 | portrait-plain | 3171 |
| `Media/Textures/ForgedOrnaments/Ring66.png` | 84x84 | portrait-plain | 3237 |
| `Media/Textures/ForgedOrnaments/Ring68.png` | 86x86 | portrait-plain | 3177 |
| `Media/Textures/ForgedOrnaments/Ring70.png` | 88x88 | portrait-plain | 3116 |
| `Media/Textures/ForgedOrnaments/Ring72.png` | 92x92 | portrait-plain | 3640 |
| `Media/Textures/ForgedOrnaments/Ring74.png` | 94x94 | portrait-plain | 3703 |
| `Media/Textures/ForgedOrnaments/Ring76.png` | 96x96 | portrait-plain | 3693 |
| `Media/Textures/ForgedOrnaments/Ring78.png` | 98x98 | portrait-plain | 3933 |
| `Media/Textures/ForgedOrnaments/Ring79.png` | 101x101 | portrait-plain | 3932 |
| `Media/Textures/ForgedOrnaments/Ring80.png` | 102x102 | portrait-plain | 4085 |
| `Media/Textures/ForgedOrnaments/Ring82.png` | 104x104 | portrait-plain | 4204 |
| `Media/Textures/ForgedOrnaments/Ring84.png` | 106x106 | portrait-plain | 4181 |
| `Media/Textures/ForgedOrnaments/Ring86.png` | 110x110 | portrait-plain | 4419 |
| `Media/Textures/ForgedOrnaments/Ring88.png` | 112x112 | portrait-plain | 4535 |
| `Media/Textures/ForgedOrnaments/Ring90.png` | 114x114 | portrait-plain | 4690 |
| `Media/Textures/ForgedOrnaments/Ring92.png` | 116x116 | portrait-plain | 4835 |
| `Media/Textures/ForgedOrnaments/Ring94.png` | 120x120 | portrait-plain | 4950 |
| `Media/Textures/ForgedOrnaments/Ring96.png` | 122x122 | portrait-plain | 4950 |
| `Media/Textures/ForgedOrnaments/Ring98.png` | 124x124 | portrait-plain | 4945 |
| `Media/Textures/ForgedOrnaments/Tip2.png` | 7x2 | rail-riveted | 93 |
| `Media/Textures/ForgedOrnaments/Tip3.png` | 10x3 | rail-riveted | 155 |
| `Media/Textures/ForgedOrnaments/Tip4.png` | 13x4 | rail-riveted | 228 |
| `Media/Textures/ForgedOrnaments/Tip5.png` | 17x5 | rail-riveted | 275 |
| `Media/Textures/ForgedOrnaments/Tip6.png` | 20x6 | rail-riveted | 292 |
| `Media/Textures/ForgedOrnaments/Tip7.png` | 23x7 | rail-riveted | 334 |
| `Media/Textures/ForgedOrnaments/Wing6.png` | 7x6 | cap-wing-left | 276 |

## Ability icons

The repainted icons are not in `Media/` and do not ship in the addon. Their art lives in [`Tools/icons/setB/`](../Tools/icons/setB/) with [`PROVENANCE.md`](../Tools/icons/setB/PROVENANCE.md), one row per icon, and ships as the loose-file icon pack described in [`docs/icons.md`](../docs/icons.md).

## Module media

Media that a module ships in its own folder. Each row names the script that draws the file.

| File | Size | What it is | Made with | Settings | Date |
| --- | --- | --- | --- | --- | --- |
| `KstyleUI_Minimap/Media/Glyphs.png` | 128x64 | Minimap button glyphs on 32-texel cells: tracking, mail, calendar, group finder and the addon drawer. White line art, tinted in game. | `Tools/media/make_minimap_glyphs.py`, procedural, no model | 2.6-texel strokes, 4x4 supersampled with `make_media.py`'s sampler | 2026-11-07 |

LEE-94 core-mask correction (2026-11-10): acceptance-2 uses a white core above RGB 210, while the earlier fit above used 200. At the pinned 210 mask, -0.065 em gives the target core 443 x 27 against 445 x 27 in the picture. Taking off 64 font units instead of 65 (-0.064 em) makes it 444 x 27 with its top-left within one physical pixel, and leaves KORALLIS at the same measured 164 x 27 core (picture 163 x 27). The word-space increment stays 250 units and every outline, bearing, weight, shadow and cap height stays unchanged. Only the unit file changes; the gold caps and names files are byte-identical. This corrects the core width, not the surrounding halo.

## Orbs HUD style (KSTY-46, 2026-11-12)

`OrbRing` is the forged ring generated with Higgsfield for the KSTY-44 mock-ups on 2026-11-12 (job `5a7af16a-d840-4e86-af19-af14e99fc431`), original art made for this project, not extracted or traced from any game. Its prompt began "Game user interface asset, front-on orthographic"; KSTY-44 kept only that much of the text. The source (2028x2032 RGBA) stays on the owner's MacBook at `~/.capy/work/KSTY-44/mock/assets/ring.png` and is not committed. `Tools/media/orbs.py` is the production pass: it centres the ring on its opening (measured at 290, 304 to 1723, 1729 in the source) in a transparent square, resamples it to 512x512 with premultiplied alpha and Lanczos so the spikes carry no dark fringe, applies a light unsharp mask (radius 1.2, 60%, threshold 2) and zeroes alpha below 4. The result is the prepared source `Tools/media/materials/OrbRing.png`, which `make_media.py` exports unchanged. The opening is 70.1% of the texture.

`OrbArm`, `OrbCrest`, `OrbRail` and `OrbRailBottom` are the Orbs tray, cut from the base generated with Higgsfield for the KSTY-44 mock-ups on 2026-11-12 (job `0b133988-204e-4852-89b6-a73ce6714226`), original art made for this project, not extracted or traced from any game. Its prompt began "Game user interface asset, front-on orthographic", like the ring's; KSTY-44 kept only that much of the text. The source (2663x668 RGBA) stays on the owner's MacBook at `~/.capy/work/KSTY-44/mock/assets/base.png` and is not committed. `Tools/media/orbs.py` cuts the arm (556, 185 to 736, 545) and the crest (1152, 146 to 1512, 326) from it. Each rail (rows 262 to 326 on top, 452 to 516 below) is the segment 736 to 1140, then 1530 to 1927, then 736 to 1140 mirrored, joined with 40 px cross-faded seams, so both ends meet the arm's joint the way the game draws the right arm, as the left one flipped. Each piece is resampled with premultiplied alpha and Lanczos, given the same light unsharp mask as the ring, and has alpha below 4 zeroed. `Layouts.OrbsTray` in `Core/Setup/Layouts.lua` places the pieces from the same source coordinates, fitting the tray's hole (641, 320 to 2023, 460) round action bar 1.

`OrbMask`, `OrbBack`, `OrbGlass`, `OrbLiquid`, `OrbSurface` and `OrbSurfaceLight` are procedural, drawn by `make_media.py` from the KSTY-44 mock-up's CSS gradients (the orb's dark glass, its rim and four glints, the liquid's lit surface ellipse with its white top line and shadow) and a cylinder shading for the liquid. KSTY-63 (2026-11-13) redrew `OrbBack` white at its lit point so each orb tints its own glass, and replaced the surface's thin line with the mock-up's ellipse.

## HUD style pictures (KSTY-65, 2026-11-13)

`HudStyleFrames` and `HudStyleOrbs` are the pictures of the two HUD styles in the settings window's General page and the setup's HUD style step. They replace the flat schematic drawings KSTY-46 made (KSTY-60 item 27: "the HUD style picker shows schematic diagrams, not pictures"). Each is a crop of KstyleUI's own `hud_reference` render of its shipped code at `RENDER_SIZE=auto` on a 1920 by 1080 screen, drawn at 2 px per unit, made by `Tools/media/hud_pictures.py` (its docstring has the commands) and exported by `make_media.py`. The renders have no backdrop and no stand-in cut from the handoff mock-up, and ran without the Blizzard icon and atlas caches, so nothing in them is extracted from a game: the icons are the KstyleUI icon pack's own repaints (`Tools/icons/setB`, [docs/icons.md](../docs/icons.md)), the orb ring and tray are the Higgsfield art above, the portraits are the renderer's flat stand-in discs, and the rest is the addon's own textures and fonts. Rerun the script after a change that alters either style's centre.
