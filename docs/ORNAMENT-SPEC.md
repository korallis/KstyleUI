# Forged ornaments

Painted trim for KstyleUI's frames: end pieces, rails, rivets, corners, crests, the portrait band and the rank pendants. KSTY-23 (LEE-117) built it in round three of a study the Captain judged on sheets, and ships it as a foundation pull request followed by one pull request per surface. Each surface's pull request amends this file.

## Levels

The setting is `Widgets.ornaments`, with three values:

| Level | What it draws |
| --- | --- |
| Off | Nothing. No ornament texture is created, so an Off screen is pixel-identical to a build without ornaments. |
| Subtle | Thin gilt rails and plain pointed ends on frames, bars and nameplates, and small arrow caps beside the action bars. |
| Full | Forged rails with rivets, clawed, winged and crested ends, the portrait band with its rank pendants, corners, crests and the full action-bar tray. |

- **Default.** Full, for a new profile and for a profile saved before the setting existed: `Widgets.Setting` returns the default for a missing or invalid stored value, so no Store migration is needed. An invalid or secret stored value also reads as Full. The owner asked for ornaments and changes the level in the settings window.
- **Where it is chosen.** The first-run setup's ornaments step (step 4 of 5, Full picked) and the General page of the settings window (a three-way control, `segmented` row type).
- **Glass.** The Glass card material draws no ornaments at any level, because the painted pieces are forged metal.
- **Full is never less than Subtle.** On the same block, Full never draws a smaller end piece than Subtle. On forged unit frames the end is chosen by weight: when Subtle's pointed pair outweighs the claws that fit (a claw fits on one end only, say), Full draws Subtle's pointed ends with Full's rail, so the two ends match. A smaller end at Full than at Subtle is a defect, not a note.

## Pieces

Every piece is a PNG in `Media/Textures/ForgedOrnaments/`, painted at its native size and drawn 1:1 in physical pixels. A piece is never scaled; only a rail stretches, along its own length. The registry (`Core/Widgets/Ornaments.lua`) attaches a handle to a frame with `Widgets.Ornament(owner, kind, target, passive)`, and the handle restyles when the target's size, the level, the material or the theme changes. During combat lockdown a restyle on a protected frame is queued until combat ends.

| Kind | Subtle | Full |
| --- | --- | --- |
| `bar`, `plate` | `Rail1` hairlines and `EndPointed` ends at the bar's height | `Rail` and `Forge` rails with `Tip` rivets, `EndClawed` ends; plates use `EndWinged` (elite) and `EndCrested` (boss or selected); a neighbouring lane swaps the claws for `Wing` caps |
| `ring` | nothing | `Ring` portrait band, with `ElitePendantR` or `BossPendantR` on an elite or boss target |
| `map` | `Map12`, `Map20` or `Map32` top corners | `Map16`, `Map24` or `Map40` corners, and `Point12` below the face where there is room |
| `plaque` | nothing | `Plaque` behind the minimap's north marker |
| `row` | `Arrow` caps beside an action bar | `Tray` and `Keystone` pieces beside and below the bars |
| `corners` | nothing | `Corner` tiers on a card's corners |
| `crest` | nothing | `Crest` tiers on a window's edge |

Which surface uses which kind is listed under [Surfaces](#surfaces).

## Omissions

A piece is dropped, never forced, when:

- the level is Off, the material is Glass, or the handle's target is hidden;
- the target's size or position is unknown, zero or a secret value (no art is guessed);
- a bar is under 4 physical pixels tall;
- the piece would come within the clearance below of anything it must avoid;
- the reach table did not ship the piece (see [Tier resolution](#tier-resolution));
- `SetTexture` refuses the file, which hides that texture and leaves the frame as it was.


## Clearance (ruling C)

- Every ornament keeps at least **1 physical pixel** from text, fills, tracks, icons, discs and the white cast cursor.
- Between two groups of the centre column, the guard (`Tools/regression/centre_clearance_lib.lua`) keeps the gap #260 set: **4 root units or 3 physical pixels**, whichever is larger.
- The exempt pairs, where an ornament may enter that gap and keeps only the 1 px rule:
  - **bottom rail**: the art closing a player or target bar block may run into the gap above that unit's own cast bar, 1 px clear of its fill, track, text, icon and white cursor;
  - **yoke**: the art joining a bar block to its own portrait band may meet the band (and on the target, the pendants), which are ornament too, 1 px clear of the portrait picture and the gilt ring.
- A bottom rail that does not fit is dropped, never thinned.
- Where both sides of an exempt pair are ornament (a yoke meeting the band or a pendant), the two may meet: that join is the yoke.
- The clearance matrices run the HUD at Full on nine screens for 12 class and form presets, for normal, elite and world boss targets.

## Ink shapes (ruling A)

Clearance is measured on the drawn ink only for round and tapered art, and only where an ornament is one side of the pair. Everything else is a box, and two non-ornament groups are measured exactly as #260 wrote it.

- **Circles**: the level badge (`Dot`, and `Ring` with its gutter, which also holds the level number), the portrait's gilt ring (`RingBevel`) and every portrait band `RingN`.
- **Row spans**: the rank pendants (`BossPendantR`, `ElitePendantR`), one ink run per texel row.
- **One generated file.** `Tools/media/ornament_ink.py` reads the PNG alpha (any non-zero alpha is ink) and writes `Core/Widgets/OrnamentInk.lua`: each circle's radius, and each pendant's row runs widened by 1 texel. The registry and the guard both read that file. `python3 Tools/media/ornament_ink.py --check` and `Tools/tests/test_ornament_ink.py` fail when it is stale against the PNGs.
- **Widening.** Each circle is widened by 1 physical pixel in both the registry and the guard. A texture resampled to a 15 px badge antialiases past its geometric circle; the drawn-pixel proof measured 2.0 px where the model passed 3.
- **Proof.** `test-centre-clearance-shapes.lua` mutates each shape (the badge, a band ring and a pendant, plain and mirrored): a piece beside the empty corner passes on ink where a box would fail, and fails once moved closer to the ink than the rule allows. The drawn-pixel proof rasterized every texture's alpha at its placed rect for every clearance-matrix case: 6,669 pairs per target class, 0 failures, the tightest at exactly 3.00 px and 1.00 px.

## Shared registry

Modules avoid each other's ornaments through one registry of placed rows (`Widgets.OrnamentRows`, `Widgets.OrnamentBars`). When a row places its pieces, every bar ornament is restyled against it, so a unit frame's end yields to the action-bar tray. In the render harness every module builds in its own environment; `Tools/render/scenes/hud.lua` and `_lumen.lua` hand each environment the rows the others placed and draw a module again when they move its bar ornaments. Nothing else crosses environments.

## Media and the reach table (ruling 2)

- **Only reachable pieces ship.** `Tools/media/ornament_reach.json` maps each shipped piece to the first case that draws it. The walk behind it covers 13 scenes (the DPS, Tank and Healer HUD; elite and world boss targets; the unit-frame, nameplate, data-bar, minimap, skin, tooltip, setup and Options scenes) on nine screens, at every Interface size from 0.60 to 1.50 in steps of 0.05 (`Core/Scale.lua`, `Core/Appearance.lua`), at Subtle and Full: 4,446 runs, plus nameplate scales 0.50 to 1.60 on all nine screens. It found 332 of 390 painted pieces reachable.
- **The walk stays out of CI.** It takes 54 minutes, so it runs with the generator (`Tools/media/ornaments.py --reach`) when the art or the placement changes. CI runs `Tools/tests/test_ornament_reach.py`: the files, `OrnamentAssets`, the manifest and the reach table agree, and nothing unreachable ships.
- **Size cap: 1.7 MB.** The Captain raised the cap from 600 KB on 2026-11-11: the 400 KB target was an estimate from before whole frames existed. The pieces ship as the approved pixels, in lossless RGBA PNG: no quantization to save bytes (it changes approved pixels), no thinned height set (it breaks the 1:1 rule), no indexed PNG (an in-game risk for 200 KB). The portrait bands' 32-colour reduction in `Tools/media/ornaments.py` is part of the art the Captain approved, recorded in `Media/PROVENANCE.md`, not a size measure. The folder holds 332 PNGs, 1,570,282 B, and 1,647,628 B with its manifest. `test_ornament_reach.py` fails when the folder passes 1,700,000 B.

## Tier resolution

A request for a piece the reach table did not ship resolves to the nearest smaller shipped tier, or the piece is dropped. It never sets a missing texture:

- **Tiered families** walk down to the largest shipped tier at or below the request: `Ring`, `ElitePendantR`, `BossPendantR` and `Rail` by their own loops; `Arrow`, `Tray`, `Keystone`, `Plaque`, `Map`, `Point`, `Crest` and `Wing` through `Tier()`; `Corner` and the frame crest down their size lists. A ring's request is the authored odd ring when its portrait is exactly 39, 59 or 79 pixels, otherwise the portrait's side rounded up to even, so the band centres on the portrait.
- **End pieces** are drawn only at the exact height the 1:1 rule asks for; when that height is not shipped, the family does not fit and the next family or no end is drawn.
- **Every other piece** is looked up in `OrnamentAssets` before `SetTexture`, and an unknown name creates no texture.

`Tools/regression/test-ornament-tiers.lua` removes each drawn ring and pendant tier at every portrait side from 24 to 160 and checks the step down, removes whole families and checks the drop, then thins the table at random 40 times and checks that bars, maps and rings draw only shipped files.

## Picture tests

The picture tests are judged with ornaments Off. A render scene draws at `RENDER_ORNAMENTS` (Off, Subtle or Full) and at Off when it is unset, so `hud_reference`, the TYPE-SPEC measurement, the material tests, the acceptance bundle and every existing gallery keep their meaning. A test that is about ornaments names its level: the clearance matrices run at Full, and the ornament guard at Full and Subtle. Ornament scenes and galleries are new and say so in their names (`setup_ornaments`, and the surfaces' own as they land).

The stubs do not fire `OnSizeChanged` when anchors resize a frame, so `Scene.Build` (`Tools/render/scene.lua`) restyles every ornament at the rect it solved for the target, as the game restyles it on `OnSizeChanged`, and builds again. Off skips that pass.

## Surfaces

Each surface's pull request adds its section here.

| Surface | Pull request | State |
| --- | --- | --- |
| Setup step and Options control | foundation | shipped |
| Unit frames and their cast bars | 2 | to come |
| Action-bar tray | 3 | to come |
| Nameplates | 4 | to come |
| Minimap and data bars | 5 | to come |
| Window and card crests | 6 | to come |
