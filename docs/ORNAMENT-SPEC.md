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
- **Where it is chosen.** The first-run setup's ornaments step (step 5 of 6, Full picked) and the General page of the settings window (a three-way control, `segmented` row type).
- **Glass.** The Glass card material draws no ornaments at any level, because the painted pieces are forged metal.
- **Full is never less than Subtle.** On the same block, Full never draws a smaller end piece than Subtle. On forged unit frames the end is chosen by weight: when Subtle's pointed pair outweighs the claws that fit (a claw fits on one end only, say), Full draws Subtle's pointed ends with Full's rail, so the two ends match. A smaller end at Full than at Subtle is a defect, not a note.

## Pieces

Every piece is a PNG in `Media/Textures/ForgedOrnaments/`, painted at its native size and drawn 1:1 in physical pixels. A piece is never scaled; only a rail stretches, along its own length. The frame a piece sits on may move by a pixel to meet a shipped tier (a casting plate's block grows by at most one physical pixel, see [Tier resolution](#tier-resolution)); the piece itself is still drawn 1:1. The registry (`Core/Widgets/Ornaments.lua`) attaches a handle to a frame with `Widgets.Ornament(owner, kind, target, passive)`, and the handle restyles when the target's size, the level, the material or the theme changes. During combat lockdown a restyle on a protected frame is queued until combat ends; until then pieces may only be hidden (see [Combat lockdown](#combat-lockdown)).

| Kind | Subtle | Full |
| --- | --- | --- |
| `bar`, `plate` | `Rail1` hairlines and `EndPointed` ends at the bar's height | `Rail` and `Forge` rails with `Tip` rivets, `EndClawed` ends; plates use `EndWinged` (elite) and `EndCrested` (boss or selected); where a neighbouring lane blocks the claws, a bar takes the end Subtle draws there first and `Wing` caps only when they are no smaller, so Full is never smaller than Subtle at the same end |
| `ring` | nothing | `Ring` portrait band, with `ElitePendantR` or `BossPendantR` on an elite or boss target |
| `map` | `Map12`, `Map20` or `Map32` top corners, and the bottom pair on a face of 280 px or more | `Map12` to `Map40` top corners; on a face of 280 px or more the bottom pair, and `Point12` below the face where there is room |
| `plaque` | nothing | `Plaque` behind the minimap's north marker |
| `row` | `Arrow` caps beside an action bar | `Tray` and `Keystone` pieces beside and below the bars |
| `corners` | nothing | `Corner` tiers on a card's corners |
| `crest` | nothing | `Crest` tiers on a window's edge |

Which surface uses which kind is listed under [Surfaces](#surfaces).

## Omissions

A piece is dropped, never forced, when:

- the level is Off, the material is Glass, or the handle's target is hidden;
- the target's size is unknown, zero or a secret value, or the edges of the target or of anything it must avoid are unknown or a secret value (no art is guessed); an edge at 0, on the screen's left or bottom side, is known like any other, and so is a negative edge off the screen (LEE-159, `test-ornament-zero-edge.lua`);
- a bar is under 4 physical pixels tall;
- the piece would come within the clearance below of anything it must avoid;
- the piece would cross the edge of a frame that clips its children (`DoesClipChildren`, `SimpleFrameAPIDocumentation.lua:188`) above the handle's owner, which would cut it with a straight edge; the bar and plate frames take that frame's bounds as they take a card's, so an end is drawn whole or falls back to a smaller tier or none. This is a safety net: the settings window's live preview never relies on it. After every refresh the preview places its ornaments once without the clip (`Widgets.OrnamentExtent`), and where they would cross it, the Unit Frames preview reserves that reach inside its fit and the Nameplates preview shrinks, until every piece lies inside; so the preview draws the pieces its frame draws at the preview's own size, none cut and none removed by the clip, at Off unchanged (Captain, 2026-11-11, LEE-160; `test-ornament-preview-clip.lua` and `-plates.lua`). At the preview's size a frame may take a smaller tier or a fallback family than on the HUD, by the same rules the HUD follows at that bar height;
- the reach table did not ship the piece (see [Tier resolution](#tier-resolution));
- `SetTexture` refuses the file, which hides that texture and leaves the frame as it was.
- the target, or anything the piece is placed against or must avoid, is a restricted region (see [Restricted regions](#restricted-regions)).


## Clearance (ruling C)

- Every ornament keeps at least **1 physical pixel** from text, fills, tracks, icons, discs and the white cast cursor.
- A rail lies flush against the bar or block it frames, and the portrait band lies flush against the gilt ring it frames: neither covers a single drawn pixel of what it frames, and the 1 px rule above is for everything else (Captain, 2026-11-11). A plate's rail at Full is the one exemption, named below.
- At Subtle a bar's `Rail1` hairlines lie flush outside its border, never on it, and cover no pixel of it (Captain, 2026-11-11, LEE-167). Plates drew rails under this rule and the Full plate rail exemption until KSTY-48 took every ornament off them (see Nameplates below).
- Between two groups of the centre column, the guard (`Tools/regression/centre_clearance_lib.lua`) keeps the gap #260 set: **4 root units or 3 physical pixels**, whichever is larger.
- The exempt pairs, where an ornament may enter that gap and keeps only the 1 px rule:
  - **Full plate rail**: retired with the plate ornaments (KSTY-48); no plate draws a rail.
  - **crest seat**: a window's or tooltip's crest frames its own surface and may cover that window's top edge line and the bare surface directly under it, 1 px clear of its title, close button, tabs, search box, icons and a tooltip's first line (Captain, 2026-11-11, as for the minimap's plaque). Above the edge it may stand over a window or panel flush against that edge, because the window is on top and the crest belongs to it. It keeps 1 px from any other visible KstyleUI window or card standing above with a gap, including that window's shadow when shadows are on, and steps down a tier or drops where it cannot (Captain, 2026-11-11, on #282).
- **The minimap's plaque** may sit on the face's gilt top rim and on the map's top rows, as many rows as its north plate is tall, because it frames its own north marker and sits on the face's top edge by design (Captain, 2026-11-11, from sheet 11). It lies behind the plate's crystal disc, which is drawn after it, and keeps 1 px from the N glyph, the zone, the clock, the coordinates and every minimap button. `Tools/regression/surfaces_clearance_lib.lua` names the exemption and fails on ink below those rows.
- A bottom rail that does not fit is dropped, never thinned.
- The clearance matrices run the HUD at Full on nine screens for 12 class and form presets, for normal, elite and world boss targets.

## Ink shapes (ruling A)

Clearance is measured on the drawn ink only for round and tapered art, and only where an ornament is one side of the pair. Everything else is a box, and two non-ornament groups are measured exactly as #260 wrote it.

- **Circles**: the level badge (`Dot`, and `Ring` with its gutter, which also holds the level number), the portrait's gilt ring (`RingBevel`) and every portrait band `RingN`.
- **Row spans**: the rank pendants (`BossPendantR`, `ElitePendantR`), one ink run per texel row.
- **Split row spans**: the minimap's corners, point and plaques (`MapN`, `PointN`, `PlaqueN`), one ink run for each separate stretch of ink in a texel row, so the hollow where a plaque frames its marker, and any gap inside a corner's row, are not ink.
- **One generated file.** `Tools/media/ornament_ink.py` reads the PNG alpha (any non-zero alpha is ink) and writes `Core/Widgets/OrnamentInk.lua`: each circle's radius, and each pendant's row runs widened by 1 texel. The registry and the guard both read that file. `python3 Tools/media/ornament_ink.py --check` and `Tools/tests/test_ornament_ink.py` fail when it is stale against the PNGs.
- **Widening.** Each circle is widened by 1 physical pixel in both the registry and the guard. A texture resampled to a 15 px badge antialiases past its geometric circle; the drawn-pixel proof measured 2.0 px where the model passed 3.
- **Proof.** `test-centre-clearance-shapes.lua` mutates each shape (the badge, a band ring and a pendant, plain and mirrored): a piece beside the empty corner passes on ink where a box would fail, and fails once moved closer to the ink than the rule allows. The drawn-pixel proof rasterized every texture's alpha at its placed rect for every clearance-matrix case: 6,669 pairs per target class, 0 failures, the tightest at exactly 3.00 px and 1.00 px.

## Shared registry

Modules avoid each other's ornaments through one registry of placed rows (`Widgets.OrnamentRows`, `Widgets.OrnamentBars`). When a row places its pieces, every bar ornament is restyled against it, so a bar's end yields to the action-bar tray (the unit frames draw none now, Lee, 2026-11-12). In the render harness every module builds in its own environment; `Tools/render/scenes/hud.lua` and `_lumen.lua` hand each environment the rows the others placed and draw a module again when they move its bar ornaments. Nothing else crosses environments.

## Media and the reach table (ruling 2)

- **Only reachable pieces ship.** `Tools/media/ornament_reach.json` maps each shipped piece to the first case that draws it. The walk behind it covers 13 scenes (the DPS, Tank and Healer HUD; elite and world boss targets; the unit-frame, nameplate, data-bar, minimap, skin, tooltip, setup and Options scenes) on nine screens, at every Interface size from 0.60 to 1.50 in steps of 0.05 (`Core/Scale.lua`, `Core/Appearance.lua`), at Subtle and Full: 4,446 runs, plus nameplate scales 0.50 to 1.60 on all nine screens. It found 332 of 390 painted pieces reachable.
- **The walk stays out of CI.** It takes 54 minutes, so it runs with the generator (`Tools/media/ornaments.py --reach`) when the art or the placement changes. CI runs `Tools/tests/test_ornament_reach.py`: the files, `OrnamentAssets`, the manifest and the reach table agree, and nothing unreachable ships.
- **Size cap: 1.7 MB.** The Captain raised the cap from 600 KB on 2026-11-11: the 400 KB target was an estimate from before whole frames existed. The pieces ship as the approved pixels, in lossless RGBA PNG: no quantization to save bytes (it changes approved pixels), no thinned height set (it breaks the 1:1 rule), no indexed PNG (an in-game risk for 200 KB). The portrait bands' 32-colour reduction in `Tools/media/ornaments.py` is part of the art the Captain approved, recorded in `Media/PROVENANCE.md`, not a size measure. The folder holds 330 PNGs, 1,569,272 B, and 1,646,243 B with its manifest; `Crest12` and `Crest8` were removed with the `Crest20` floor (1,010 B). `test_ornament_reach.py` fails when the folder passes 1,700,000 B.

## Tier resolution

A request for a piece the reach table did not ship resolves to the nearest smaller shipped tier, or the piece is dropped. It never sets a missing texture:

- **Tiered families** walk down to the largest shipped tier at or below the request: `Ring`, `ElitePendantR`, `BossPendantR` and `Rail` by their own loops; `Arrow`, `Tray`, `Keystone`, `Plaque`, `Map`, `Point`, `Crest` and `Wing` through `Tier()`; `Corner` and the frame crest down their size lists (the frame crest takes only `Crest32` and `Crest20`). A ring's request is the authored odd ring when its portrait is exactly 39, 59 or 79 pixels, otherwise the portrait's side rounded up to even, so the band centres on the portrait.
- **End pieces** are drawn only at the exact height the 1:1 rule asks for; when that height is not shipped, the family does not fit and the next family or no end is drawn.
- **A casting plate's block** may grow by one physical pixel, its bottom rail moving one pixel lower, when that lets its ends reach further: above 48 px the end tiers are 52, 56, 60 and 64, so a block of odd height there would match no end, or a shorter one than the idle frame. No piece is resampled, so this is a placement rule, not a breach of the 1:1 rule, and the clearance guard still holds (Captain, 2026-11-11). The idle frame caps its rail reach at what the joined block can match, so both frames draw the same rail weight.
- **Every other piece** is looked up in `OrnamentAssets` before `SetTexture`, and an unknown name creates no texture.

`Tools/regression/test-ornament-tiers.lua` removes each drawn ring and pendant tier at every portrait side from 24 to 160 and checks the step down, removes whole families and checks the drop, then thins the table at random 40 times and checks that bars, maps and rings draw only shipped files.

## Picture tests

The picture tests are judged with ornaments Off. A render scene draws at `RENDER_ORNAMENTS` (Off, Subtle or Full) and at Off when it is unset, so `hud_reference`, the TYPE-SPEC measurement, the material tests, the acceptance bundle and every existing gallery keep their meaning. A test that is about ornaments names its level: the clearance matrices run at Full, and the ornament guard at Full and Subtle. Ornament scenes and galleries are new and say so in their names (`setup_ornaments`, and the surfaces' own as they land).

The stubs do not fire `OnSizeChanged` when anchors resize a frame, so `Scene.Build` (`Tools/render/scene.lua`) restyles every ornament at the rect it solved for the target, as the game restyles it on `OnSizeChanged`, and builds again. Off skips that pass.

## Combat lockdown

This is the rule for every ornament whose owner the game may report protected: boss cards, the Targeted chip or nameplates when their owner is protected. It comes from the method flags in the 70862 API documentation (`Interface/AddOns/Blizzard_APIDocumentationGenerated/`). A method marked `IsProtectedFunction = true` is blocked in lockdown on a protected object. `ScriptRegion:IsProtected` (`SimpleScriptRegionAPIDocumentation.lua:540`) shows that a region, a texture included, can itself report protected.

| In lockdown, on a texture of a protected owner | Methods | Source |
| --- | --- | --- |
| Allowed: no protection flag | `Hide`, `Show`, `SetShown` | `SimpleScriptRegionAPIDocumentation.lua:357`, `:751`, `:725` |
| Allowed: no protection flag | `SetAlpha`, `SetVertexColor` | `SimpleRegionAPIDocumentation.lua:123`, `:191` |
| Allowed: no protection flag | `SetTexture`, `SetTexCoord` | `SimpleTextureBaseAPIDocumentation.lua:604`, `:580` |
| Blocked: `IsProtectedFunction` | `ClearAllPoints`, `SetAllPoints`, `SetPoint`, `SetSize` (and `SetWidth`, `SetHeight`) | `SimpleScriptRegionResizingAPIDocumentation.lua:22`, `:111`, `:135`, `:163` |
| Blocked: `IsProtectedFunction` | `SetScale` on a region | `SimpleRegionAPIDocumentation.lua:179` |
| Blocked on the owner frame itself | `Show`, `Hide`, `SetShown`, `SetFrameLevel` | `SimpleFrameAPIDocumentation.lua:1539`, `:687`, `:1484`, `:1281` |

So in lockdown an ornament on a protected owner **may only hide** pieces. `Handle:Yield(frame)` hides every placed piece that comes within the clearance of `frame` (4 root units or 3 physical pixels), or every piece when called without a frame. It reads edges and calls nothing but `Hide`, and an unknown or secret edge hides the piece. The ornament never anchors, sizes, creates a host frame, levels or reparents in lockdown. It does not show a piece again either, though the API allows it, because the piece's position may be stale. The full restyle waits in `Combat.Queue` for `PLAYER_REGEN_ENABLED`. A consumer calls `Yield` when an obstacle appears, or its pair breaks, while `Widgets.MayMove(owner)` is false.

## Restricted regions

The game refuses to measure some regions, and answers others with secrets.

- **Restricted.** A nameplate's base frame is restricted, and the restriction follows anchors: the plate KstyleUI anchors to it, the plate's health bar, text and level badge, and the ornament host are restricted too. `GetLeft`, `GetRight`, `GetTop`, `GetBottom`, `GetCenter` and `GetRect` raise "Action[FrameMeasurement] failed because[Can't measure restricted regions]" with KstyleUI's taint. The owner's first live session (2026-11-12, v0.0.5) raised it 37 times from a plate's frame ornament and 30 times from the world-cursor tooltip's crest, which measured every visible card and reached a plate's level badge. `ScriptRegion:IsAnchoringRestricted` (`SimpleScriptRegionAPIDocumentation.lua:400`) answers first; Blizzard asks it before `GetRect` and `GetPoint` (`Blizzard_RestrictedAddOnEnvironment/RestrictedFrames.lua:138`, `:377`) and of a frame two anchors from its target (`Blizzard_TutorialManager/Blizzard_TutorialPointerFrame.lua:95`). A secret answer counts as restricted. `GetWidth`, `GetHeight` and `GetEffectiveScale` still answer: the live session read the restricted bar's width as 170 before the frame ornament failed on `GetLeft`.
- **Secret.** A status bar given a secret value takes the `BarValue` secret aspect (`SetValue`, `SimpleStatusBarAPIDocumentation.lua:355`), and a font string given secret text takes one too. A region with a secret aspect anchors secretly (`Blizzard_RaidWarning/RaidWarning.lua:39` clears a string's text "so anchoring stops being secret"), and so does everything anchored to it. Its edges, size and anchors then come back as secrets (`SecretWhenAnchoringSecret` on `GetLeft`, `GetWidth`, `GetSize` and `GetPoint`). Every unit health and power bar is one, so on the live client the player and target blocks drew no rails or ends, silently.

So an ornament never depends on the game measuring a region. Every edge it reads goes through `Widgets.Edges` (`Core/Widgets/Base.lua`), which returns four `false` edges for a restricted region without measuring it. When an edge comes back `false` or secret, the handle asks `Widgets.LocalRect` (`Core/Widgets/Rects.lua`) instead. That solves the region's rect from the layout KstyleUI gave it: the anchors and sizes each `SetPoint`, `SetAllPoints`, `ClearAllPoints`, `SetSize`, `SetWidth` and `SetHeight` set, recorded as they are set by `Widgets.Record` (a `hooksecurefunc` on each of KstyleUI's own regions; a protected frame is never recorded). It also uses `GetWidth` and `GetHeight` where they answer plainly, and a font string's natural width (its string width, which is secret on a string anchored to a secret bar, so then the width of the same plain text in the same font on a free scratch string, `Widgets.StringWidth`; 0 for empty text; the ink box of a plate's name uses the same width) and natural height (its font size times 1.2, the renderer's line height). The chain stops at the first frame KstyleUI did not record, its root.

- If the root's own edges are plain, the solved rect is moved onto the screen and mixes with every other measured region. This is the player and target blocks: their root is the unit button, which the game measures.
- If the root cannot be measured either, the handle places in the target's own frame: the target's top-left corner is the origin and is taken to lie on the physical pixel grid, and only regions solved from the same root count. This is every plate: its root is the nameplate base. Obstacles outside that root, and a clipping frame above the owner, are not seen; a plate has nothing outside it to avoid. Coordinates are rounded to a millionth of a physical pixel, so a piece set flush against an icon by the layout stays flush.
- A font string whose width is secret spans its anchor's side of the frame it is anchored to, the widest it could be. A region KstyleUI did not record, and a target that is not recorded, keep the old rule: an unknown or secret edge drops the piece.

Only the unit-frame health and power bars, with the regions their ornaments avoid, are recorded today (`KstyleUI_UnitFrames/Style.lua`); plates draw no ornament now (KSTY-48). Off returns before any of this.

**Limits.** A restricted plate's pieces are snapped to its own corner, not the screen's grid. The game moves plates every frame and never says where one is, so a plate whose corner falls between pixels draws its pieces between pixels with it. The stubs place bases on whole pixels for the tests that measure against the screen grid (`N.Align` in `Tools/regression/nameplates_env.lua`). At 1280x720 and 1366x768 an elite plate at the smallest and largest plate scale now drops both ends where its name comes within the clearance of the winged end, as the Omissions above allow. Before, the stubs gave a name no rect until a render pass measured it, so the name went unseen.

**Tests.** The stubs answer as the game does: `env.RestrictAnchoring` restricts a frame, and every nameplate base from `N.Base` is restricted unless `opts.free`. A secret `SetValue`, `SetMinMaxValues`, `SetText` or `SetFormattedText` veils the region's geometry, and `env.SecretAnchoring(false)` turns that off for a comparison. A test reads geometry for its own checks through `env.Look`. `test-nameplates-bible.lua` shows a plate on a restricted nameplate building and taking a target, a cast, effects and setting changes with no measuring and no error. `test-ornament-secret-unitframes.lua` shows the player and target blocks, whose bars draw no ornament now, restyling with secret geometry without an error, the same as with plain geometry, at 1920x1080 and 5120x1440. `test-ornament-restricted-tooltip.lua` covers the world-cursor tooltip beside a restricted card. `test-ornament-measure-guard.lua` fails on any edge read outside `Widgets.Edges`.

## Surfaces

Each surface's pull request adds its section here.

| Surface | Pull request | State |
| --- | --- | --- |
| Setup step and Options control | foundation | shipped |
| Unit frames and their cast bars | 2 | shipped |
| Action-bar tray | 3 | removed (KSTY-49): the Frames tray card replaces it |
| Nameplates | 4 | shipped |
| Minimap and data bars | 5 | shipped |
| Window and card crests | 6 | shipped |

### Unit frames and their cast bars

| Piece | Handle | Subtle | Full |
| --- | --- | --- | --- |
| Health and power block (player, target, focus, boss, and the target-of-target, focus-target and pet rows) | `bar` on the health bar, spanning the power bar and an attached inline cast; marked `bare` | nothing | nothing |
| Portrait | `ring` on the portrait frame | nothing | the `Ring` band at the portrait's size; `ElitePendantR` on an elite or rare target, `BossPendantR` on a world boss or a boss card, from `UnitClassification` on every frame style (a secret value draws no pendant, on a boss card too) |
| Cast bar, separate or inline | `bar` on the cast bar, marked `bare`; an inline cast joins the block's handle | nothing | nothing |
| Focus and boss cards, the Targeted chip | `corners` on the card's chrome; it restyles with the chrome, after the block, and after the chip's name is set | nothing | `Corner` tiers |

**No ornament on the bars** (Lee, 2026-11-12, on v0.0.7: "the little textures above the hp bar and below the mana bar on the player / target frames look bad and not clean at all we should remove these", then "I liked our unit frames before we added the textures around health and power bars"). At Subtle and Full the unit frames draw no rail, rivet, crest, end or cap on or around their health, power and cast bars, so the bars read as they did before #278 brought the ornaments (staging 76fb4d01d). Each block's and cast bar's handle stays but is marked `bare` and places nothing, so the restyle paths, the combat queue and the corners that read the block's obstacles work as before, and Off is unchanged. The portrait band and its rank pendants stay, and so do the corners on the focus and boss cards and the Targeted chip. `test-ornament-unitframe-bars.lua` fails on any piece on the player or target block or its cast bar at Subtle or Full at 1920x1080 and 5120x1440, and `ornament_guard_lib.lua` on the nine screens of every preset. The placement rules below for the block (the forged rails, the yoke, the rail crest, the ends) stay in `Core/Widgets/Ornaments.lua`, but no unit frame uses them now.

The level badge and its number are measured as one circle (ruling A). The block avoids the badge (the lumen disc on the column, the octagon badge on the classic plate), the portrait band, the caption gems and every text on the frame.

**The band and the gilt ring.** The band runs under the level badge by design, because the badge sits on the gilt ring: the badge and its number draw above the band, so the band covers no pixel of either, and no gap is cut round the badge (Captain, 2026-11-11). The band's open middle is wider than the gilt ring it frames: `Tools/media/ornament_ink.py` writes each band's hole (the distance from its centre to its nearest ink pixel) to `OrnamentInk.lua`, and drawn 1:1 every band's nearest ink pixel lies at least 0.32 physical px past the gilt ring's and its backing disc's ink, each widened by 1 px for resampling. `test-ornament-band-ink-small.lua`, `-shipped.lua` and `-large.lua` check the player and target bands at Full on nine screens at Interface sizes 0.6, shipped and 1.5: the band must be drawn 1:1, cover no drawn pixel of the gilt ring, its disc or the portrait, and draw below the badge. Acceptance pass 7 (LEE-149) measured 16 to 36 covered pixels on four screens; the cause was the render scene, which rounded every `SetTexCoord` value to four decimals, so a band such as `Ring59` (75 of 128 texels) was drawn from 74.995 texels and resampled, and its inner edge bled up to 1 px into the ring's fringe. Its JSON export also wrote every number with six decimals, so `Ring79` (101 of 128 texels, 0.7890625) reached the renderer as 0.789062 and left 18 to 21 covered pixels on 2560x1440, 3440x1440 and 5120x1440. The game takes the exact coordinates and is not affected; `Tools/render/scene.lua` now exports them unrounded and writes in full any number that six decimals cannot hold, and `ornament_guard_lib.lua` requires every piece's crop to match its native size exactly.

**Combat and secure frames.** No ornament texture or frame belongs to the `SecureUnitButtonTemplate` button. The block's and cast bar's textures sit on a host frame created on the first placement as a child of the card panel (`view.panel`, `cb.panel`), anchored with `SetAllPoints` to its bar and levelled one above it. The band and pendants sit on the portrait frame, and the corners on the card panel or the chip. All of these are plain `Frame`s, but a boss card's panel and the chip are children of the secure button and anchored to it, so the game may report them protected in combat; the gate below then queues them. Every restyle first asks `Widgets.MayMove(owner)`: out of combat it runs; in lockdown it runs only when `owner:IsProtected()` is false. A true or secret answer queues it through `Combat.Queue` until `PLAYER_REGEN_ENABLED`. So in combat a target change can create, level, anchor and show these plain frames and textures, which the game allows. `test-ornament-combat.lua` proves that for the block, the band, the corners and the cast bar: a protected owner is not touched in lockdown, every handle's restyle is queued, and each runs after it.

**Cost.** A restyle runs only for a handle whose owner is shown. A handle whose owner is hidden is marked stale and places nothing; its owner's \`OnShow\` restyles it before that frame draws (\`test-ornament-stale.lua\`). After its first restyle at a size and level, a handle allocates nothing: obstacle, shape and span records, candidate ends, cuts and lanes are pooled on the handle, names and texture paths are interned once, and the tier walk reads a constant list. Per-event updates (health, power, prediction, auras, threat, cast progress, \`OnUpdate\`) never restyle (\`test-ornament-combat-paths.lua\`). Under Lua 5.1 on the Mac, a target change whose rank changes cost 0.72 ms at Full against 0.18 ms at Off while the blocks drew their rails and ends; with no bar ornament (Lee, 2026-11-12) it costs 0.17 to 0.18 ms at Full (load 11.6), the band and its pendant alone. \`test-perf-frames.lua\` holds it to a 1,000 us budget, down from 7,000 us, with no allocation on addon lines.

**Recorded limits.** Measured on this pull request's code at Full across the three presets, nine screens and the Interface size slider (0.84 is the shipped size, 16/19):

- **None of the block's limits apply now.** The yoke dropping beside the level badge, the target's bottom rail fitting only at some sizes, Subtle and Full told apart by rail weight, and the rail crest's `Crest20` floor (Captain, 2026-11-11, LEE-153) all concerned pieces the unit frames no longer draw (Lee, 2026-11-12). `test-ornament-crest-floor.lua` still fails on a unit-frame crest below `Crest20` and on any crest on the player or target block.

### Action-bar tray

Removed (KSTY-49, 2026-11-12). The KSTY-44 design bible (section 3.3) allows ornament only at card corners, heading rules, portrait rings and the level diamond, never around a bar, so bar 1 no longer owns a `row` handle and no `Tray` finial or `Keystone` draws. The Frames tray card behind bars 1 and 2 (`KstyleUI_ActionBars/Tray.lua`, the quest card's material and its corner brackets) replaces it at every ornament level.

### Nameplates

| Piece | Handle | Subtle | Full |
| --- | --- | --- | --- |
| Health frame, cast bar | none | nothing | nothing |

**No ornament on the plates** (KSTY-48, after the KSTY-44 bible: "Unit-frame bars are clean in both styles. Player, target, party and nameplate bars have a one-pixel black edge and nothing else", and Lee's "I liked our unit frames before we added the textures around health and power bars", 2026-11-12). At every ornament level a plate draws no rail, end, crest, wing or cap on or around its health or cast bar, and owns no ornament handle, so its restyle paths no longer place pieces, swap idle and casting sets or read a recorded layout. What the bible allows a plate is its own: gilt target brackets at both ends of the bar, the level diamond at the left end with its rank on the rim, and the player's effect over the right end (`KstyleUI_Nameplates/README.md`). Off is unchanged. `test-nameplates-bible.lua` fails on an ornament handle or an ornament texture on a plate at Subtle or Full at 1920x1080 and 5120x1440. The plate placement rules that stood here (the cast block, the slot beside an end, both ends or none, the two kept sets, the plate limits and the settings preview's one-plate choice) went with the pieces; the settings preview shows one sample, the richest whose own extent (`Stacking.Extent`, from the plate's constants) fits the pane. The `plate` handle kind stays in `Core/Widgets/Ornaments.lua`, but no module uses it now.

### Minimap and data bars

**The minimap places no piece since KSTY-50** (the overhaul's design bible, KSTY-44 section 3.3: ornament only on card corners). It is a forged card with gilt brackets on its corners, so its `map` and `plaque` handles are gone, and the minimap rows of the tables, the recorded limits and the paragraphs about the map below describe the build before it. `test-ornament-surfaces-minimap-full.lua` and `-subtle.lua` now fail on any forged piece under the minimap, and `test-perf-hud.lua` holds its zone change and layout without one. The `Map`, `Point` and `Plaque` pieces still ship and are unreachable until a clean-up removes them.

| Piece | Handle | Subtle | Full |
| --- | --- | --- | --- |
| Experience, reputation and honour bars | `bar` on each bar's rim frame (`view.rim`: the track, or with the border shown the border less its innermost physical pixel), owned by the bar's overlay (`Bars.NewView`) | `Rail1` hairlines above and below, `EndPointed` ends at the bar's height; `Arrow6` caps where no end fits | `EndClawed` ends and `Rail1`; `Wing6` caps where no claw fits |
| Minimap corners and point | `map` on the face's overlay | `Map12`, `Map20` or `Map32` top corners; the bottom pair on a face of 280 px or more | `Map12` to `Map40` top corners; on a face of 280 px or more the bottom pair, and `Point12` where the caption leaves room |
| North plaque | `plaque` on the face's north plate | nothing | `Plaque12` to `Plaque32` behind the plate's crystal disc |

Each bar avoids its own label, the other data bars' frames and pieces (1 physical pixel: the data bars are one group) and every other live Layout element, as the minimap does, and both ends take the same piece or both drop: every case of the clearance guard draws both ends or neither, and the guards fail when Full draws a smaller end than Subtle in the same state on any of the nine screens. When a data bar shows, hides or moves, every data bar restyles, so a bar that appears beside another moves the other's ends off it. A bar's border is part of the bar it frames: the rim frame puts the rails flush outside the border at both levels and on every screen, so no rail covers a border pixel (the experience bar has no border, so its rim frame is its track). A bar whose label sits on its line (the `CENTER` position, the reputation and honour bars' default, shown on hover) draws no ornament while the label shows: the label's glass plate is taller than the bar and crosses both rails, and a rail cut round it would land on the border. It places again when the label hides. The bars yield to the action-bar tray through the shared registry, so on the HUD at Full the experience bar draws one rail, below the bar, and smaller claws than it draws alone (`EndClawed9` at 1920x1080 against `EndClawed13` and two `Rail2` without the tray). The map avoids its zone, clock and coordinates and every other live Layout element (the buff and debuff rows beside it): `Handle:Map` steps a corner pair down the `Map` tiers until both corners keep 1 px clear, and drops the pair when none does. The plaque frames the north marker and is the exemption named under [Clearance](#clearance-ruling-c).

**Foundation.** These placement rules changed with this surface (Captain, 2026-11-11). On a bar that is not forged, a rail is split round an action-bar tray piece, a neighbouring Layout element or another data bar's piece instead of dropped: each part keeps 1 physical pixel of ink from it, and a part shorter than one end piece is dropped. How far such a bar's rails reach is no longer stopped by a tray piece or a neighbouring bar's piece (the rail is split round them instead), but a Layout element still stops it. Full keeps the end Subtle draws at the same place, or Subtle's `Arrow` cap, before any smaller `Wing` cap the neighbouring-lane rule offers (`test-ornament-settings.lua` pinned `Wing6` beside a lane before; it now pins the pointed end Subtle draws there). A cap (`Wing` or `Arrow`) on a bar that is not forged is dropped, never drawn, when it is shorter than 40% of the frame it closes (`CAP_SHARE`, rails and rims included; Captain, 2026-11-11): smaller, it reads as a speck. A bar whose target is marked `solidRim` (a data bar with its border shown) never takes an end that would put its rails on the rim row, so no rail covers the border. A Layout element whose edge is unreadable or secret is skipped as an obstacle rather than stopping the placement, and an edge at 0 is a rect (#288). No unit-frame, nameplate or action-bar placement changes on the HUD or in their galleries. `Handle:Map` is rewritten for the pairs (`Handle:Spot`, split out of `Handle:Piece`, `Handle:Clear` and `Handle:MapPair`), and `Tools/media/ornament_ink.py` writes split row spans for the `Map`, `Point` and `Plaque` pieces. The pendant rows are unchanged. `Tools/regression/surfaces_clearance_lib.lua` checks every piece against every drawn region of the reference HUD on nine screens (the minimap in DPS, Tank and Healer; the data bars in DPS on nine screens and Tank and Healer at 1920x1080), at Subtle and Full, and `test-ornament-surfaces-bars-states-a.lua` to `-c.lua` do the same on the nine screens for the experience and reputation bars empty, rested, full, alone at the level cap and hovered: 1 physical pixel of ink from all other content, flush only against the bar's own track, border and fill and the map's own picture. A bar's own drop shadow is exempt: its outer row is within one colour level of the backdrop (30,42,56 against 31,42,56 at 1920x1080), and a rail flush on the border lies on it.

**What restyles, and why.**

| Change | The ornament | Trigger and source |
| --- | --- | --- |
| A bar's label shows or hides, or changes width (rested experience ends, a new level's label, the pointer over a hover-text bar) | restyles once: the label is an obstacle the rails and ends keep clear of; a label on the bar's line hides the ornament until it hides again | `Bars.PaintValues` on `PLAYER_XP_UPDATE`, `UPDATE_EXHAUSTION`, `PLAYER_LEVEL_UP` (`UnitDocumentation.lua:3998`, `:4913`, `:3832`), `UPDATE_FACTION` (`PaperDollInfoDocumentation.lua:432`); the holder's `OnEnter` and `OnLeave` scripts (as `Blizzard_Minimap/Mainline/Minimap.xml:78` sets them); it compares the label's snapped `GetStringWidth` (`SimpleFontStringAPIDocumentation.lua:339`) and calls nothing when it is unchanged |
| A bar fills, gains rested experience with the same label, or a reputation bar gains with its text hidden | nothing: the pieces read the track, never the fill | per event, `test-ornament-bars-map-paths.lua` |
| A bar's settings or its Layout rect change | restyles in `Bars.Paint` | `Bars.Setting`, the `LayoutChanged` callback |
| The experience bar hides at the level cap; the reputation bar, its own Layout element, shows or hides | a hidden bar's handle goes stale and places nothing, and places when its bar shows; a shown bar keeps its own placed set | `content:SetShown`; the foundation's `OnShow` wake (`test-ornament-stale.lua`) |
| A new zone name | restyles the map once: a longer name can reach the bottom-right corner | `ZONE_CHANGED_NEW_AREA`, `ZONE_CHANGED`, `ZONE_CHANGED_INDOORS` (`MapDocumentation.lua:665`, `:653`, `:659`) through `Face:SetZone` |
| The clock ticks, the coordinates move, the zoom changes, the button drawer opens or closes | nothing: the clock and coordinates sit on the caption's second row, under no piece, and the drawer flies out beside the map | `C_Timer.NewTicker` (`UITimerDocumentation.lua:22`), the coordinates' `OnUpdate`, `MINIMAP_UPDATE_ZOOM` |
| The face's layout, the theme or the scale changes | restyles the map and the plaque | `Face:Layout`, from `Map.Refresh` on `ThemeChanged`, `ScaleChanged` and `ProfileChanged` |
| Another Layout element moves | restyles the map, whose corners avoid it | the `LayoutChanged` callback |

**Combat and secure frames.** Every owner is a plain `Frame` that KstyleUI creates: the bar's overlay under its content frame, and the face's overlay and north plate under the minimap holder. None inherits a secure template, and Blizzard's `Minimap` frame is not protected either (`Blizzard_Minimap/Mainline/Minimap.xml:56` declares it without `protected`, and no file in `Blizzard_Minimap` sets it). The minimap's one secure button, `SecureActionButtonTemplate` (`Blizzard_FrameXML/SecureTemplates.xml:4`), is a child of `UIParent`, not of the holder, and detaches at `PLAYER_REGEN_DISABLED`. So in lockdown the owners answer `IsProtected` false (`SimpleScriptRegionAPIDocumentation.lua:540`) and a restyle in combat (a level-up, a zone change, a hover) places at once. If the game ever reports an owner protected or secret, `Widgets.MayMove` queues the restyle in `Combat.Queue` until `PLAYER_REGEN_ENABLED` (`UnitDocumentation.lua:3893`), and the pieces stay where they are until then.

**Cost.** Per-event updates (experience with an unchanged label, rested experience, resting, reputation with its text hidden, the clock, the coordinates, the zoom and the button drawer) make no ornament call (`test-ornament-bars-map-paths.lua`). A hidden bar is stale and places on show. Under Lua 5.1 on the Mac, best of seven, in combat with the stubs quiet, at a load of 13:

| Path | Off | Subtle | Full |
| --- | --- | --- | --- |
| Experience painted, label unchanged | 16.1 us | 16.5 us | 15.9 us |
| Experience painted, label width changes (one restyle) | 17.3 us | 89.9 us | 96.1 us |
| A bar's restyle alone (4 pieces at Subtle and Full) | 1.4 us | 44.6 us | 48.4 us |
| The pointer enters or leaves the reputation bar (tooltip included) | 54.6 us | 76.8 us | 82.1 us |
| The face's layout (corners and plaque placed) | 28.2 us | 62.8 us | 72.1 us |
| A zone change with a new name | 11.7 us | 44.4 us | 43.5 us |
| A clock tick | 3.7 us | 3.8 us | 3.7 us |

**The data bars place no piece since KSTY-50** (bible section 3.4: nothing around a bar). The experience, reputation and honour bars own no `bar` handle, so the data-bar rows above, the experience bar column of the recorded limits below and the data-bar cost figures describe the build before it. `test-ornament-surfaces-xp-a.lua` to `-k.lua` and `test-ornament-surfaces-bars-states-a.lua` to `-c.lua` now fail on any forged piece under a data bar, and `test-ornament-bars-map-paths.lua` on any ornament made on a data bar.

`test-perf-hud.lua` holds the experience paint to 150 us unchanged and 1,400 us when the label changes, the clock tick to 50 us, a zone change to 400 us and the face's layout to 1,000 us (about ten times the Lua 5.1 time, as `perf_runner.lua` asks for CI), with no allocation on addon lines; each fixture fails at Full when the bar draws fewer than three pieces, or the map fewer than two corners or no plaque, and the layout path checks that after every call. `PLAYER_XP_UPDATE` itself allocates 384 B on staging, in the reading table `Sources.XP` builds (`KstyleUI_DataBars/Sources.lua:116`), before any ornament code runs; the perf paths paint a kept reading so that line is not counted.

**Recorded limits**, measured in the render scenes at the shipped Interface size:

| Screen | Minimap at Full | Minimap at Subtle | Experience bar |
| --- | --- | --- | --- |
| 1280x720 | `Map12` top corners, `Plaque12`; no bottom corners: the face is under 280 px, and `Map16` would come within 1 px of the buff row | `Map12` top corners | `Wing6` caps and one rail at Full, `Arrow6` caps and one rail at Subtle: no end piece fits |
| 1366x768 | as 1280x720 | as 1280x720 | `EndClawed9` and two rails at Full, `EndPointed9` at Subtle |
| 1920x1080 to 5120x1440, 2383x1540 | `Map24` top corners, `Plaque16` or `Plaque20`; no bottom corners: the face is under 280 px | `Map20` top corners | claws or points of 9 to 14 px |
| 3840x2160, 3456x2234 | `Map40` top and `Map32` bottom corners, `Plaque28` or `Plaque32` | `Map32` at all four corners | claws or points of 17 to 20 px |

`Point12` draws on no HUD screen: the reference zone name, WINDFIELD ORCHARD, runs under the face's middle. It draws in `gallery_minimap` at 3456x2234, where the name is Riverglades.

- **The experience bar's top rail at Full** is split round the action-bar tray's keystone above it: two parts, each 1 px of ink clear of the keystone. Subtle draws no keystone, so its top hairline is whole. With the keystone no longer stopping the rails' reach, the bar at 3456x2234 draws `EndClawed28` claws and `Rail6` rails at Full (the approved sheet 10 showed `EndClawed18` on the databars scene, which has no tray).
- **Caps at 1280x720.** No end piece fits there, so both levels draw `Arrow6` caps: Full's `Wing6` would be 1 px narrower.
- **Beside a watched reputation bar** the experience bar's claws would come within 1 px of it, so Full draws the pointed end Subtle draws there, one tier taller (`EndPointed13` against `EndPointed11` at 1920x1080). At 3440x1440 its Full end gives way to the reputation bar's `Rail6`. The reputation bar at its default place sits between the tray's finial and the experience bar's end: its top rail is split round the finial at Full, and at 3456x2234 it draws no end at either level: `Wing6`, the only `Wing` tier shipped, is under the 40% cap share there. `test-ornament-surfaces-xp-g.lua` to `-k.lua` run the HUD with Stormwind watched on the nine screens.

### Window and card crests

| Piece | Handle | Subtle | Full |
| --- | --- | --- | --- |
| Crest on a kit window: the settings window, the first-run setup, the bags, Copy chat, the KstyleUI dialog and the Layout Mode toolbar | `crest` on the window's chrome (`Widgets.Panel` gives every titled window one; the settings window asks for it) | nothing | one `Crest` centred on the top edge |
| Crest on a tooltip: GameTooltip, ItemRefTooltip and the four shopping tooltips | `crest` on the tooltip's glass (`KstyleUI_Tooltips/Style.lua`) | nothing | the same, smaller because a tooltip is narrower |
| Crest on a RestedXP window: the v2 guide window, the leveling report, the guide configurator, the guide importer and its popups, and the active-items and active-targets windows when they are wide enough | `crest` on the window glass (`KstyleUI_Skins/Addons/RestedXP/Chrome.lua`); the v2 window measures its height to the bottom of its steps frame | nothing | the same |

Subtle draws no crest, so on these surfaces Subtle and Off are the same picture.

**The crest.** A window takes the largest of `Crest64`, `Crest48`, `Crest32` and `Crest20` whose size is at or below 6% of its width in physical pixels, and a window narrower than 180 root units or shorter than 64 draws none. A tooltip takes the largest of them that fits five times across its width, so a 152 px tooltip at 1920x1080 takes `Crest20` and a 313 px one at 3456x2234 takes `Crest48` where its first line leaves room. No surface draws `Crest12` or `Crest8`: at native size they read as specks (Captain, 2026-11-11), so a surface too narrow for `Crest20` draws none. The crest is seated on the top edge with its point sunk into the window's own top band by a quarter of its height, under the crest seat exemption (see [Clearance](#clearance-ruling-c)): it may cover its own window's top edge line and the bare surface directly under it, and it keeps 1 physical pixel from everything the window lists as its top-band content: the title, the close button and the content frame of a kit window; the logo, title, close button and search box of the settings window; the first line of a tooltip; the caption, close button and logo of a RestedXP window. Where a tier's seat would come within 1 pixel of one of them, the crest takes the next smaller tier, and where `Crest20` would, it draws none. A tier that would leave the screen gives way to the next smaller one in the same way. A window that lists nothing draws no crest, and a listed region that is not placed draws nothing, so it does not block. The crest drops, and never cuts:

- when the window's top edge is closer to the screen's top than even `Crest20` stands above it, or every tier would cross the screen's left or right edge;
- when the window's size or position, or a listed region's, is unknown, secret or not finite (a bottom edge of 0 at the screen's bottom is known);
- while a tooltip follows the cursor (`GetAnchorType` starts with `ANCHOR_CURSOR`), because it moves every frame and is checked only when it shows;
- when it would come within 4 root units or 3 physical pixels of a shopping tooltip's compare header, which hangs above the tooltip's top-left corner.

The item tooltip embedded in another tooltip (`EmbeddedItemTooltip`) carries no crest: its top edge is inside its host's lines. Blizzard's windows that `Skin.Backdrop` dresses draw nothing; they can ask for a crest through `opts.ornament`, which this pull request does not do.

**No corners on the story card.** The story card (RestedXP's guide card and the quest card that takes its slot) keeps its forged brackets and draws no `corners`. Every `Corner` tier inside the card's rect lands on the brackets' own corner marks, so it would change pixels the Off render drew and double the brackets; outside the rect it would meet the right rail's neighbours. The brackets are the card's material and stay as they are; `corners` stays on the focus and boss cards and the Targeted chip only.

**What restyles in play.**

| Trigger | What restyles | Source that proves the trigger |
| --- | --- | --- |
| A window or tooltip changes size (`OnSizeChanged` on the chrome's owner) | that crest, at once rather than on the next frame, so a tooltip that changes size between two units never draws the old crest | `OnSizeChanged`: `Blizzard_ObjectiveTracker/Blizzard_ObjectiveTrackerContainer.xml:84` |
| A hidden window or tooltip shows (`OnShow` after `OnHide`) | that crest, once | `HookScript`, `Hide`: `SimpleScriptRegionAPIDocumentation.lua:365`, `:357` |
| A window is dropped after a drag (`StopMovingOrSizing` on a kit window, `ItemRefTooltip`, a RestedXP window, or the v2 guide window's outer frame, which RestedXP drags) | that crest, once. A drag moves the anchored crest with the window and restyles nothing | `SimpleFrameAPIDocumentation.lua:1571`; `Blizzard_UIPanels_Game/Mainline/ItemRef.lua:374`; RestedXP `UI/V2/Core.lua:1038` |
| A shopping tooltip's compare header shows, hides or changes width | that tooltip's crest | `Blizzard_SharedXMLGame/Tooltip/TooltipComparisonManager.lua:245` to `:247` |
| A tooltip shows with a different anchor type (cursor or not) | that crest | `GetAnchorType`: `Blizzard_SharedXMLGame/Tooltip/TooltipComparisonManager.lua:77` |
| The ornament level or the card material changes | every crest whose owner is shown | the settings window |

The tooltip's health bar, its lines and its money never restyle a crest (`test-ornament-crest-tooltips.lua`).

**Combat and secure frames.** No crest belongs to a frame the game protects. The kit windows are plain `Frame`s that `Widgets.Panel` creates; a tooltip's crest sits on KstyleUI's glass frame, a child of the tooltip; a RestedXP window's sits on the backdrop `Skin.Backdrop` creates. `GameTooltip` itself is not protected, but a tooltip anchored to a secure frame answers its geometry with secret values (`GetTop` and `GetWidth` are `SecretWhenAnchoringSecret`: `SimpleScriptRegionAPIDocumentation.lua:308`, `:323`), and a secret size or edge drops the crest. Every restyle still asks `Widgets.MayMove(owner)`: under `InCombatLockdown()` an owner that answers `IsProtected` true or secret (`SimpleScriptRegionAPIDocumentation.lua:540`) queues its restyle for `PLAYER_REGEN_ENABLED`, and a size change in lockdown first hides its crest with `Handle:Yield`, because the crest is anchored to the old centre. Only `Hide` is called in lockdown (see [Combat lockdown](#combat-lockdown)). A kit window opened in combat is not protected, so its crest draws as it opens.

**Cost.** Under Lua 5.1 on the Mac, a GameTooltip shown for two units of different size at Full costs 71 us per show with its crest re-placed (load average 12 while it ran), and allocates nothing on addon lines; an earlier measurement at load 58 put the show at 61 us at Off, 66 us at Subtle and 83 us at Full, and a 1040 by 680 window resized at 38, 46 and 73 us. Two chrome lines that allocated a table on every resize (`PlaceCorners` and the forged brackets) now reuse one. `Tools/regression/perf/KstyleUI_Tooltips.lua` holds the tooltip show at Full to 1,000 us with no allocation, and fails when its fixture places no crest.

**Recorded limits.**

- A tooltip under 64 root units tall (a one-line spell tooltip) or under 125 physical pixels wide (five `Crest20` widths), and any window under 180 by 64 root units or under 334 physical pixels wide (where 6% is under 20), draws no crest. So at 1920x1080 the RestedXP guide importer is the only RestedXP window wide enough, and at 1280x720 no RestedXP window and no gallery tooltip draws one. The first line can lower the tier further: the spell tooltip at 1920x1080 takes `Crest20` because `Crest32` would end 0.6 px short of its first line's box.
- A cursor-anchored tooltip draws no crest.
- The RestedXP feedback form and guide export are AceGUI `Frame` widgets that AceGUI pools and hands to whichever addon asks next once RestedXP releases them (`AceGUI-3.0.lua` 88-122), so the skin never dresses them with `Glass`. Their crest sits on the temporary panel `DressDialog` lays over the dialog while RestedXP shows it (`DressPanel` with its crest flag, which only these two dialogs set; the dropdown menus' panels carry none), with the dialog's caption as its neighbour. It hides with that panel when the dialog hides, so a frame AceGUI hands to another addon shows no crest. A drop after dragging the dialog re-checks the crest through a hook on the frame's `StopMovingOrSizing` that does nothing while the panel is hidden.
- The RestedXP level-splits window gets its caption and cog as neighbours only after RestedXP builds its title, which happens after the skin dresses the window (`LevelingTracker.lua` 1017-1071), so `Splits` fills the list then. At 1920x1080 the window is under 334 physical pixels wide and draws none.
- A kit window sits above the HUD, so its crest, like the window, may cover a HUD element or window moved flush against its top edge. A KstyleUI window or card standing above with any gap blocks the crest as a listed region does, measured on its frame plus its shadow (Captain, 2026-11-11). The crest checks its neighbours when it restyles (show, resize, drop, anchor change), so a window opened above it later is seen at the crest's next restyle, and a neighbour whose geometry is secret is not seen.
