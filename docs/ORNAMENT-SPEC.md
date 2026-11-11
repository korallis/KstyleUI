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

Every piece is a PNG in `Media/Textures/ForgedOrnaments/`, painted at its native size and drawn 1:1 in physical pixels. A piece is never scaled; only a rail stretches, along its own length. The frame a piece sits on may move by a pixel to meet a shipped tier (a casting plate's block grows by at most one physical pixel, see [Tier resolution](#tier-resolution)); the piece itself is still drawn 1:1. The registry (`Core/Widgets/Ornaments.lua`) attaches a handle to a frame with `Widgets.Ornament(owner, kind, target, passive)`, and the handle restyles when the target's size, the level, the material or the theme changes. During combat lockdown a restyle on a protected frame is queued until combat ends; until then pieces may only be hidden (see [Combat lockdown](#combat-lockdown)).

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
- the target's size is unknown, zero or a secret value, or the edges of the target or of anything it must avoid are unknown or a secret value (no art is guessed); an edge at 0, on the screen's left or bottom side, is known like any other, and so is a negative edge off the screen (LEE-159, `test-ornament-zero-edge.lua`);
- a bar is under 4 physical pixels tall;
- the piece would come within the clearance below of anything it must avoid;
- the reach table did not ship the piece (see [Tier resolution](#tier-resolution));
- `SetTexture` refuses the file, which hides that texture and leaves the frame as it was.


## Clearance (ruling C)

- Every ornament keeps at least **1 physical pixel** from text, fills, tracks, icons, discs and the white cast cursor.
- A rail lies flush against the bar or block it frames, and the portrait band lies flush against the gilt ring it frames: neither covers a single drawn pixel of what it frames, and the 1 px rule above is for everything else (Captain, 2026-11-11).
- Between two groups of the centre column, the guard (`Tools/regression/centre_clearance_lib.lua`) keeps the gap #260 set: **4 root units or 3 physical pixels**, whichever is larger.
- The exempt pairs, where an ornament may enter that gap and keeps only the 1 px rule:
  - **bottom rail**: the art closing a player or target bar block may run into the gap above that unit's own cast bar, 1 px clear of its fill, track, text, icon and white cursor;
  - **yoke**: the art joining a bar block to its own portrait band may meet the band (and on the target, the pendants), which are ornament too, 1 px clear of the portrait picture and the gilt ring;
  - **crest seat**: a window's or tooltip's crest frames its own surface and may cover that window's top edge line and the bare surface directly under it, 1 px clear of its title, close button, tabs, search box, icons and a tooltip's first line (Captain, 2026-11-11, as for the minimap's plaque). Above the edge it may stand over a window or panel flush against that edge, because the window is on top and the crest belongs to it. It keeps 1 px from any other visible KstyleUI window or card standing above with a gap, including that window's shadow when shadows are on, and steps down a tier or drops where it cannot (Captain, 2026-11-11, on #282).
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

This is the rule for every ornament whose owner the game may report protected: the action-bar tray on its secure header, and boss cards, the Targeted chip or nameplates when their owner is protected. It comes from the method flags in the 70862 API documentation (`Interface/AddOns/Blizzard_APIDocumentationGenerated/`). A method marked `IsProtectedFunction = true` is blocked in lockdown on a protected object. `ScriptRegion:IsProtected` (`SimpleScriptRegionAPIDocumentation.lua:540`) shows that a region, a texture included, can itself report protected.

| In lockdown, on a texture of a protected owner | Methods | Source |
| --- | --- | --- |
| Allowed: no protection flag | `Hide`, `Show`, `SetShown` | `SimpleScriptRegionAPIDocumentation.lua:357`, `:751`, `:725` |
| Allowed: no protection flag | `SetAlpha`, `SetVertexColor` | `SimpleRegionAPIDocumentation.lua:123`, `:191` |
| Allowed: no protection flag | `SetTexture`, `SetTexCoord` | `SimpleTextureBaseAPIDocumentation.lua:604`, `:580` |
| Blocked: `IsProtectedFunction` | `ClearAllPoints`, `SetAllPoints`, `SetPoint`, `SetSize` (and `SetWidth`, `SetHeight`) | `SimpleScriptRegionResizingAPIDocumentation.lua:22`, `:111`, `:135`, `:163` |
| Blocked: `IsProtectedFunction` | `SetScale` on a region | `SimpleRegionAPIDocumentation.lua:179` |
| Blocked on the owner frame itself | `Show`, `Hide`, `SetShown`, `SetFrameLevel` | `SimpleFrameAPIDocumentation.lua:1539`, `:687`, `:1484`, `:1281` |

So in lockdown an ornament on a protected owner **may only hide** pieces. `Handle:Yield(frame)` hides every placed piece that comes within the clearance of `frame` (4 root units or 3 physical pixels), or every piece when called without a frame. It reads edges and calls nothing but `Hide`, and an unknown or secret edge hides the piece. The ornament never anchors, sizes, creates a host frame, levels or reparents in lockdown. It does not show a piece again either, though the API allows it, because the piece's position may be stale. The full restyle waits in `Combat.Queue` for `PLAYER_REGEN_ENABLED`. A consumer calls `Yield` when an obstacle appears, or its pair breaks, while `Widgets.MayMove(owner)` is false. `test-ornament-tray-paths.lua` makes the anchoring and sizing methods on the tray's textures, and the header's own frame methods, raise the game's `ADDON_ACTION_BLOCKED` in lockdown, then enters a vehicle in combat.

## Surfaces

Each surface's pull request adds its section here.

| Surface | Pull request | State |
| --- | --- | --- |
| Setup step and Options control | foundation | shipped |
| Unit frames and their cast bars | 2 | shipped |
| Action-bar tray | 3 | shipped |
| Nameplates | 4 | shipped |
| Minimap and data bars | 5 | to come |
| Window and card crests | 6 | shipped |

### Unit frames and their cast bars

| Piece | Handle | Subtle | Full |
| --- | --- | --- | --- |
| Health and power block (player, target, focus, boss, party) | `bar` on the health bar, spanning the power bar and an attached inline cast | `Rail1` hairlines above and below, `EndPointed` ends at the block's height | `Forge` rails with `Tip` rivets, 2 to 7 px by screen and Interface size; `EndClawed` ends where they fit, otherwise Subtle's pointed ends; the yoke: the rail on the portrait side runs into the portrait band |
| Portrait | `ring` on the portrait frame | nothing | the `Ring` band at the portrait's size; `ElitePendantR` on an elite or rare target, `BossPendantR` on a world boss or a boss card, from `UnitClassification` on every frame style (a secret value draws no pendant, on a boss card too) |
| Separate cast bar | `bar` on the cast bar, pointed family only | as the block | as the block, clear of the spell icon |
| Inline cast bar | joins the block's handle; its own handle stands down | | |
| Focus and boss cards, the Targeted chip | `corners` on the card's chrome; it restyles with the chrome, after the block, and after the chip's name is set | nothing | `Corner` tiers |

The level badge and its number are measured as one circle (ruling A). The block avoids the badge (the lumen disc on the column, the octagon badge on the classic plate), the portrait band, the caption gems and every text on the frame.

**The band and the gilt ring.** The band runs under the level badge by design, because the badge sits on the gilt ring: the badge and its number draw above the band, so the band covers no pixel of either, and no gap is cut round the badge (Captain, 2026-11-11). The band's open middle is wider than the gilt ring it frames: `Tools/media/ornament_ink.py` writes each band's hole (the distance from its centre to its nearest ink pixel) to `OrnamentInk.lua`, and drawn 1:1 every band's nearest ink pixel lies at least 0.32 physical px past the gilt ring's and its backing disc's ink, each widened by 1 px for resampling. `test-ornament-band-ink-small.lua`, `-shipped.lua` and `-large.lua` check the player and target bands at Full on nine screens at Interface sizes 0.6, shipped and 1.5: the band must be drawn 1:1, cover no drawn pixel of the gilt ring, its disc or the portrait, and draw below the badge. Acceptance pass 7 (LEE-149) measured 16 to 36 covered pixels on four screens; the cause was the render scene, which rounded every `SetTexCoord` value to four decimals, so a band such as `Ring59` (75 of 128 texels) was drawn from 74.995 texels and resampled, and its inner edge bled up to 1 px into the ring's fringe. Its JSON export also wrote every number with six decimals, so `Ring79` (101 of 128 texels, 0.7890625) reached the renderer as 0.789062 and left 18 to 21 covered pixels on 2560x1440, 3440x1440 and 5120x1440. The game takes the exact coordinates and is not affected; `Tools/render/scene.lua` now exports them unrounded and writes in full any number that six decimals cannot hold, and `ornament_guard_lib.lua` requires every piece's crop to match its native size exactly.

**Combat and secure frames.** No ornament texture or frame belongs to the `SecureUnitButtonTemplate` button. The block's and cast bar's textures sit on a host frame created on the first placement as a child of the card panel (`view.panel`, `cb.panel`), anchored with `SetAllPoints` to its bar and levelled one above it. The band and pendants sit on the portrait frame, and the corners on the card panel or the chip. All of these are plain `Frame`s, but a boss card's panel and the chip are children of the secure button and anchored to it, so the game may report them protected in combat; the gate below then queues them. Every restyle first asks `Widgets.MayMove(owner)`: out of combat it runs; in lockdown it runs only when `owner:IsProtected()` is false. A true or secret answer queues it through `Combat.Queue` until `PLAYER_REGEN_ENABLED`. So in combat a target change can create, level, anchor and show these plain frames and textures, which the game allows. `test-ornament-combat.lua` proves that for the block, the band, the corners and the cast bar: a protected owner is not touched in lockdown, every handle's restyle is queued, and each runs after it.

**Cost.** A restyle runs only for a handle whose owner is shown. A handle whose owner is hidden is marked stale and places nothing; its owner's \`OnShow\` restyles it before that frame draws (\`test-ornament-stale.lua\`). After its first restyle at a size and level, a handle allocates nothing: obstacle, shape and span records, candidate ends, cuts and lanes are pooled on the handle, names and texture paths are interned once, and the tier walk reads a constant list. Per-event updates (health, power, prediction, auras, threat, cast progress, \`OnUpdate\`) never restyle (\`test-ornament-combat-paths.lua\`). Under Lua 5.1 on the Mac, a target change whose rank changes costs 0.72 ms at Full against 0.18 ms at Off, and 0.41 ms against 0.16 ms when the rank stays; \`test-perf-frames.lua\` holds the first to a 7,000 us budget and no allocation on addon lines.

**Recorded limits.** Measured on this pull request's code at Full across the three presets, nine screens and the Interface size slider (0.84 is the shipped size, 16/19):

- **The yoke drops** where it cannot meet the band and keep 3 px from the level badge. The same in DPS, Tank and Healer:

  | Frame | Screen | Interface sizes without a yoke |
  | --- | --- | --- |
  | player | 1280x720 | 0.60, 0.65, 0.84 |
  | player | 1366x768 | 0.60, 0.65 |
  | target | 1280x720 | 0.60, 0.65, 0.90 |
  | target | 1366x768 | 0.60, 0.65 |
  | target | 1920x1080 | 0.60 |

  At 1280x720 and the shipped size, the player's rail would have to reach x <= 494 to enter the band's ink. There its drawn gap to the level badge is 2.83 px, under the 3 px rule. The Captain accepted the player yoke as absent there on 2026-11-11; the target's yoke joins.
- **The target's bottom rail** closes the block only where the gap above the inline cast bar holds it, and then as a 1 px hairline; everywhere else it is dropped, never thinned (ruling C). It is drawn at:

  | Screen | DPS and Tank | Healer |
  | --- | --- | --- |
  | 1280x720, 1366x768, 1920x1080 | never | never |
  | 2560x1440, 3440x1440, 5120x1440 | 0.70, 0.95 | 0.70, 0.95, 1.05, 1.10 |
  | 3840x2160 | 0.65, 0.95 | 0.65, 0.95, 1.00 to 1.50 |
  | 2383x1540 | 0.65 | 0.65, 1.00 |
  | 3456x2234 | 0.70, 0.95 to 1.50 | 0.70, 0.95 to 1.50 |

  The player's bottom rail is forged at every screen and size.
- **Levels told apart by rail weight only.** In `gallery_unitframes` the party frames keep the same `EndPointed` ends at both levels and differ only in the rail: `Rail1` at Subtle, `Forge3`/`Forge4` with rivets at Full. On the HUD, the 1920x1080 target keeps Subtle's ends at Full for the same reason: the claws do not fit.
- **The rail crest has a Crest20 floor** (Captain, 2026-11-11, LEE-153). The crest centred on a block's forged top rail takes `Crest32` or `Crest20`, the largest that keeps its clearance, and is dropped where neither fits; it never takes `Crest16`, `Crest12` or `Crest8`. On the HUD at the shipped Interface size the crest is `Crest20` at 1920x1080, 2560x1440, 3440x1440, 5120x1440 and 2383x1540, `Crest32` at 3840x2160 and 3456x2234, and absent at 1280x720 (where it was `Crest12`) and 1366x768, in all three presets. `test-ornament-crest-floor.lua` fails on a smaller crest.

### Action-bar tray

| Piece | Handle | Subtle | Full |
| --- | --- | --- | --- |
| Tray finials beside bars 1 and 2 | `row` on bar 1's state header, paired with bar 2's header | `Arrow` caps at 0.4 of the pair's height, up to `Arrow32` | `Tray` finials at the pair's height, up to `Tray96` |
| Keystone below bar 1 | the same handle | nothing | `Keystone6`, or `Keystone12` when bar 1 is 50 px tall or more; drawn when bar 1 is at least 30 px tall |

Only bar 1 owns a handle, and only a bar 1 at least 240 px wide draws a tray. The finials draw when bars 1 and 2 form a pair: both shown, neither set to fade, neither under a mouseover Layout rule, both with the same combat and idle opacity, their left and right edges within one physical pixel, bar 2 directly above bar 1 at bar 1's spacing (one pixel either way), and the pair no taller than three bar heights. Any other arrangement draws no finials. Every other shown bar (bars 3 to 5, the stance bar while it has forms, the pet bar while a pet exists) and the leave-vehicle button while it shows are obstacles: both finials drop when either would come within 4 root units or 3 physical pixels of one, whichever is larger, and the keystone drops when it would meet one. An obstacle's unknown or secret edge drops the finials too. The tray is a row in the shared registry, so a unit frame's end yields to it (`test-ornament-tray-gap.lua`).

**Combat and secure frames.** Bar 1's header is created from `SecureHandlerStateTemplate`, which inherits `SecureFrameTemplate` and so is protected (`Blizzard_RestrictedAddOnEnvironment/SecureHandlerTemplates.xml:13`, `Blizzard_FrameXML/SecureTemplatesBase.xml:4`). The tray's textures are created on that header (`BACKGROUND` layer); no host frame is created. Every restyle asks `Widgets.MayMove(header)`, and in lockdown the header answers protected, so the restyle is queued through `Combat.Queue` until `PLAYER_REGEN_ENABLED`: in combat nothing creates, sets, shows or anchors a tray texture. When a pet is summoned, a Layout rule shows a bar, or a vehicle shows the leave-vehicle button in combat, the tray hides at once every piece the new obstacle covers (`Handle:Yield`), and hides all its pieces if the pair breaks. Only hiding is allowed in lockdown (see [Combat lockdown](#combat-lockdown)). The tray re-places when combat ends. `test-ornament-tray-paths.lua` proves it.

**Cost.** The tray restyles only when something it reads changes: bar 2's header, bar 1's spacing, whether the pair is enabled, or the list of shown obstacles. A bar's shown state is its setting plus its holder's and header's own `OnShow` and `OnHide`, so a Layout shown rule or a state driver reaches the tray without reading a secret `IsShown`. `Bar:RefreshOrnament` compares them on every pet update, every shown change and every leave-button change, and restyles only on a change; a settings pass (`ApplyAll`, the visual refresh) holds the tray and restyles it once at the end, and releases it even when the pass raises an error; bar 1's size change restyles it through `OnSizeChanged`. Per-event updates (cooldowns, charges, usable, range, procs, state, pet bar updates, `UNIT_FLAGS` on the pet, a target change and the bars' `OnUpdate` scripts) never restyle (`test-ornament-tray-paths.lua`). While bar 1 is hidden the tray is stale and draws on the header's or an ancestor's `OnShow`. Under Lua 5.1 on the Mac a tray restyle that draws both finials and the keystone costs 0.046 ms at Full, 0.030 ms at Subtle and 0.001 ms at Off, and allocates nothing on addon lines (the first figures, 0.045 and 0.026 ms, were taken with a pet out, when only the keystone drew; the cost fixture now fails if the tray draws fewer than three pieces); a pet appearing and leaving costs 0.22 ms at Full against 0.12 ms at Off. `test-perf.lua` holds the pet bar's cooldown update and a pet change in combat to 160 us and 170 us with no allocation on addon lines.

**Recorded limits.** While Layout Mode drags or resizes a bar, the tray follows bar 1 and does not see bar 2 or the obstacles move; it restyles when the move is dropped.

### Nameplates

| Piece | Handle | Subtle | Full |
| --- | --- | --- | --- |
| Health frame | `plate` on the health bar; while the plate casts it spans the cast bar too | `Rail1` hairlines above and below, `EndPointed` ends | rails of 1 to 4 px at the shipped Interface size, by screen; `EndCrested` ends on the target and on a world boss, `EndWinged` on an elite, `EndClawed` otherwise, falling back in that order to `EndPointed` |
| Backing under the level dot | the same handle, while casting | one colour texture in the cast bar's track colour | the same |
| Slot beside the far end | the same handle, idle and casting | one colour texture in the bars' track colour | the same |

**The cast block.** While the cast bar shows, the health bar and the cast bar form one block, as an inline cast does on the unit frames: the ends span both bars, the top rail runs above the health bar and the bottom rail below the cast bar. A casting plate keeps the family it has idle; only the end's size changes (Captain, 2026-11-11). Where the block wraps round a level dot that sits beside the health bar, the cast bar does not reach under the dot, so a backing in the cast bar's track colour (`Handle:Fill`, `SetColorTexture`, `SimpleTextureBaseAPIDocumentation.lua:403`) fills the gap between the block's edge and the cast bar's rim, at the cast bar's height. It draws only while the block is joined and the dot is there, at Subtle and Full, and never covers the dot, a fill or the cast bar. Where the optional level disc or spell icon reaches into that gap, the backing is cut back to keep 1 physical px clear of it, on whichever side loses the least area, and it is dropped when nothing is left (`test-ornament-nameplates.lua` runs with both shown). The plate's own rectangles are the picture's and are judged with ornaments Off, so the cast bar is not moved to close the gap. The selection box stays round the health bar only, as the picture has it. While casting, the bottom rail runs below the cast bar, so the box's bottom edge shows between the two bars and the box reads three-sided against the block; that edge reads as a divider between the bars, as the inline cast does on the unit frames, and it is an accepted limit (Captain, 2026-11-11).

**The slot beside an end.** An end stands off the health bar when the block reaches past the bar to clear the level dot, or when the end slides out so that it does not touch a name wider than the bar. That leaves a slot between the bars' rims, the rails and the end, where the backdrop showed (19 by 26 px idle on the elite at 3456x2234, 2 to 5 px on other plates). One fill in the bars' track colour (`Handle:Fill`) closes it, idle and casting, at Subtle and Full, whenever the slot holds no icon (Captain, 2026-11-11). It runs from the bars' rim to the end and from the top rail down to the lowest bar's rim, so while casting it also covers the 2 px gap between the bars beside the slot. It covers no rail and no end: a fill and a piece in the same draw layer have no defined order, so the fill stops at the rails' inner edges. Where a level dot, raid mark, level disc or spell icon reaches into the slot, the slot fill is not drawn: idle the slot stays open (beside a raid mark at 3456x2234 that leaves about 1.5 px each side of the icon), and while casting the backing beside the cast bar is drawn as before, cut back to keep 1 px clear of the icon. While casting, the slot and the backing on that side are one texture, so a casting plate still draws at most 6. `test-ornament-plate-slot.lua` checks every pixel of each slot that holds no icon on five screens and two plate scales, idle and casting, and fails when the slot shows the backdrop, when a fill covers a rail, an end or plate content, or when a plate draws more than 6 pieces.

**Both ends or none.** A plate never draws one end without the other. Where one side is blocked, both sides take the largest piece that fits both, and where none fits both, both drop and the rails stand alone (Captain, 2026-11-11). `test-ornament-nameplates.lua` fails on a plate with one end.

**Rails agree.** The idle and casting frames draw rails of the same weight at Full. Above 48 px the end tiers are only 52, 56, 60 and 64, so a joined block can reach fewer heights than the health bar alone; the idle frame therefore caps its rail at the largest reach the joined block can match (see [Tier resolution](#tier-resolution)). `test-ornament-plate-swap.lua` fails when the weights differ.

**Two kept sets (ruling D).** A plate keeps an idle set and a casting set of placed pieces. The casting set is placed the first time the plate casts. A cast showing or ending hides one set and shows the other with region `Hide` and `Show` only, so it touches no anchor and works in lockdown. If the cast bar has no rect yet when it shows (`GetBottom` may return nothing), the casting set is not cached and the draw is retried on the next frame, at most three times per switch (`test-ornament-plate-swap.lua`). Any restyle (a change in the plate's signature, its size or the level) drops the set not shown, which is placed again on the next switch. A recycled plate whose signature is unchanged keeps both sets. The signature is the plate's target state, rank (boss, elite or plain, and the classification marker), raid mark, name, level badge and name-only mode; each change restyles once, and a secret value restyles. `test-ornament-plate-swap.lua` compares every shown set with a forced restyle on nine screens, the smallest, default and largest plate scale (0.5, 1.0, 1.6), four kinds, Subtle and Full, before and after a size, level, target or lockdown change.

**Regions.** At Off a plate creates no texture. A plate allocates at most 6 regions for its idle set (two ends, two rails and a slot fill beside each end) and 6 for its casting set (two ends, two rails, and the backing or a slot fill beside each end, or a spare for a split rail), and draws at most 6 at once. Forty plates that have each cast once, with every fourth still casting (`test-ornament-plate-regions.lua`, 1920x1080): 321 regions allocated and 149 drawn at Full and at Subtle, at most 5 drawn on one plate. The test fails above 6 idle, 6 casting or 12 allocated on one plate, or above 6 drawn at once.

**Combat and secure frames.** The plate is a plain `Frame` that KstyleUI creates as a child of the base the game hands out for a unit (`C_NamePlate.GetNamePlateForUnit`, `NamePlateDocumentation.lua:11`; `NAME_PLATE_UNIT_ADDED`, `NamePlateManagerDocumentation.lua:120`). The ornament's textures sit on a host frame created on the first placement as a child of the plate, anchored to the health bar and levelled one above it. Forbidden plates (`ForbiddenNamePlateUnitFrameTemplate`, `Blizzard_NamePlates.xml:368`) are never handed to an addon and carry no ornament. Every restyle asks `Widgets.MayMove(plate)`; if the game reports the plate protected or secret in lockdown, the restyle waits in `Combat.Queue`. A swap to a kept set only shows and hides regions, which the [lockdown rule](#combat-lockdown) allows; a swap to a dropped set hides the old pieces and queues the placement. `test-ornament-plate-swap.lua` makes the plate protected in lockdown and makes anchoring, sizing and texture setters raise on its pieces while casts start and stop.

**Cost.** Per-event updates (health, auras, threat, names, cast progress, `OnUpdate`) touch no ornament across forty plates (`test-ornament-nameplates-paths.lua`). A hidden plate is stale and places on show. Under Lua 5.1 on the Mac, forty positioned plates with eight debuffs each and every fourth casting, allocating nothing on addon lines:

| Path | Off | Subtle | Full |
| --- | --- | --- | --- |
| Cast start, stop and fade end on one plate, later casts | 7.6 us | 10.2 us | 10.6 us |
| First cast after a change (the casting set placed once) | 7.3 us | 52.5 us | 53.8 us |
| Target change among forty | 100 us | 216 us | 211 us |
| Plate recycled, same kind | 31 us | 31 us | 32 us |
| Plate recycled, rank changes | 31 us | 87 us | 88 us |
| Forty-plate pull (sixteen rank changes) | 1,245 us | 2,246 us | 2,541 us |
| Raid mark moves onto the plate, then a cast | 36 us | 146 us | 144 us |
| `RAID_TARGET_UPDATE` | 28 us | 62 us | 64 us |
| `UNIT_HEALTH` | 1.0 us | 1.2 us | 1.0 us |

At Off a plate builds no signature. The Off pull costs about 6% more than before ornaments (1,245 us against 1,176 us, best of seven; the Off pull figure in the table is that best of seven): the foundation's stale-wake check on each plate's hidden cast bar, under 2 us per plate. `test-perf-frames.lua` holds a later cast to 110 us, a raid mark followed by the first cast to 1,300 us and the forty-plate pull at Full to 23,000 us, and its fixture fails when any of the forty plates places no piece at Full.

**Recorded limits** (Captain, 2026-11-11), the same idle and casting, measured in the render scenes at the shipped Interface size:

| Screen | Kind | Full | Subtle |
| --- | --- | --- | --- |
| 1280x720, 1366x768 | elite | no ends, one rail | no ends, one rail |
| 1280x720 | target | `EndPointed` instead of the crest, one rail | as Full |
| 1366x768 | target | `EndPointed` instead of the crest | as Full |

From 1920x1080 up every kind keeps its family. The level dot pulls an elite's and a boss's frame about 5 root units left of the plate's centre, the elite's wings widen the frame by about a fifth when a cast starts, and the target's crest sits about 3 root units off the selection box at 3456x2234; all three are accepted.

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
