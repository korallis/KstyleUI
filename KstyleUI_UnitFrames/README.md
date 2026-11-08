# KstyleUI_UnitFrames

Player, target, target of target, focus, focus target, pet and boss 1 to 5. Portraits (switchable), cast bars, frame auras, class resources, threat glow, raid markers, leader and role icons.

| Field | Value |
| --- | --- |
| Module name | `UnitFrames`: its switch in `Core/Features.lua` and the `name` it registers with `KstyleUI.Modules.Register` |
| Approach | Replace |
| Loads | With the core addon, switched off until the player turns it on |
| Files | `KstyleUI_UnitFrames.toc` lists `UnitFrames.xml`, which loads every Lua file in order, so adding a file never edits the TOC |

## Rules

These come from the [design spec](../docs/superpowers/specs/2026-11-07-kstyleui-design.md). The roadmap's Global Constraints and [AGENTS.md](../AGENTS.md) apply too.

- Unit frames use `SecureUnitButtonTemplate` buttons with `RegisterUnitWatch`. Health goes straight to the bar with `SetMinMaxValues(0, UnitHealthMax(unit))` and `SetValue(UnitHealth(unit))`. Health text comes from `UnitHealthPercent` or `AbbreviateNumbers`, never from Lua arithmetic. Bar colours that depend on health come from `C_CurveUtil` colour curves. Incoming heals come from `CreateUnitHealPredictionCalculator`. Range fade uses `SetAlphaFromBoolean`.
- Combo points draw as one-point status bars, so the comparison happens in the engine.
- Cast bars use `StatusBar:SetTimerDuration` with the duration object from the cast APIs. Casts by units other than the player and pet can be secret, so the bar never reads the spell name except through widget setters.
- Auras use the AuraContainer engine (`CustomAuraContainerTemplate`, aura groups and filter strings). Never scan auras by index while `C_Secrets.ShouldAurasBeSecret()` returns true. Aura data turns secret during a boss pull before `InCombatLockdown()` returns true.
- Player and target frames are 296 by 89 units at the 1080 reference, the kit sheet's 469 by 141 proportions with the portrait as tall as the frame. They sit above the action bars on either side of the Cooldown Manager, as tall as its two rows. Portraits are on by default, with a switch to turn them off.
- Blizzard frames this module replaces are hidden only through `KstyleUI.Safe.HideBlizzard`.
- At load the module only registers itself with `KstyleUI.Modules.Register`. It creates no frames, registers no events and installs no hooks until `Enable` runs. `test-modules-load.lua` checks the frames.
- Every element it shows registers with `KstyleUI.Layout.Register`, and every setting is declared through `KstyleUI.Options.Register`, so the player can resize and customise everything from the settings window.
- UI comes from `KstyleUI.Widgets`, colours from `KstyleUI.Tokens` and strings from `KstyleUI.L`. Translations go in `Locale.lua` in this folder, loaded by `UnitFrames.xml`.
- Build mode: check that an API exists before calling it, check `issecretvalue` before any comparison, fall back to a safer path when the preferred one is unavailable, and log the path taken with `KstyleUI.DevTest.Log`.

## Frames

| Frame | Element key | Unit | Default size |
| --- | --- | --- | --- |
| Player | `unitframes.player` | `player` | 280 x 89: an 89-unit portrait over one glass panel, the owner's mockup's 279 by 90 |
| Target | `unitframes.target` | `target` | 280 x 89, the portrait on the right |
| Target of target | `unitframes.targettarget` | `targettarget` | 104 x 24, compact |
| Focus | `unitframes.focus` | `focus` | 240 x 96: a 240 by 72 frame, then its 20-unit cast bar |
| Focus target | `unitframes.focustarget` | `focustarget` | 120 x 24, compact |
| Pet | `unitframes.pet` | `pet` | 104 x 24, compact |
| Boss | `unitframes.boss` | `boss1` to `boss5` | 200 x 400: five slots of 72 units, 10 apart, each a 200 by 60 frame and a 10-unit cast bar |
| Player cast bar | `unitframes.castbar.player` | `player` | 340 x 36, above the frames and the essential cooldowns |
| Target cast bar | `unitframes.castbar.target` | `target` | 272 x 28, under the target frame and the tracked buff icons, nearly the frame's width as on the design file |

Each frame is a plain holder frame registered with `KstyleUI.Layout.Register` under its key, with the setup's label, `module = "UnitFrames"` and `resizable = true`. The holder carries one `SecureUnitButtonTemplate` button per unit (five for the boss frame). The button has the attributes `unit`, `type1 = "target"` and `type2 = "togglemenu"`, registers for `AnyUp` clicks and is shown and hidden by `RegisterUnitWatch`. Layout moves and sizes the holder; the module anchors the buttons inside it and lays out their parts again whenever the holder's size changes. Hovering a button shows the unit tooltip through Blizzard's `UnitFrame_OnEnter` and `UnitFrame_OnLeave`.

Every frame follows the kit sheet, [`docs/design/mockups/05_kit_hunter.jpg`](../docs/design/mockups/05_kit_hunter.jpg). The accent there is the hunter's green; in game it is the player's class colour.

- **Glass.** One `Widgets.Chrome` panel: chamfered corners, the double-line bevel and a soft shadow. With a portrait, the glass starts under the portrait's centre, so the portrait overlaps its outer end and stands proud of it. On a full frame its far-end chamfer is an eighth of its height, the design file's 8 units on a 64-unit panel; the compact kinds (target of target, focus target, pet) use the tile chamfer. The glass sits inside the frame's top and bottom by 2 units under a chamfered portrait (the design file) and by 0.06 H under a round one, so the panel's lines meet the ring where the owner's mockup joins them.
- **Portrait.** `round` (the default, the owner's mockup): the round mask, the `buttonFill` disc and the ring in the accent. `chamfered` (the design file): a `Widgets.Chrome` frame filled `buttonFill` with a chamfer 15% of its size, its inner bevel line in the accent lifted 15% towards white, with the 2D portrait drawn square (`SetPortraitTexture` with `disableMasking`) and masked by `portraitMask`, which cuts the same 15%. The image draws in the `BORDER` layer under the bevel lines, so its corners never cover them.
- **Level badge.** A regular octagon (a panel-chamfer chrome whose chamfer is `1 / (2 + sqrt 2)` of its size), filled `buttonFill` (the mockup's badges measure #101214), straddling the portrait's bottom outer corner so it stands below the portrait's bottom edge. Under a chamfered portrait it is 36% of the portrait with its centre 0.19 P in and 0.125 P up from the corner, with a neutral `text` line, as measured on the design file. Under a round portrait it is 37% of the portrait centred on the ring's lower outer point (0.196 P in and up), with its line in the accent like the ring, as on the mockup.

A frame 36 units tall or more is a full frame. Its column starts at the portrait's edge with no gap, as the design file's panel line is the portrait's border line. Its side insets are shares of the frame's height `H`: under a chamfered portrait the column starts `0.147 H` past the portrait and ends `0.2 H` before the glass's far end (the design file's 10 and 13.5 units on 68); under a round one `0.085 H` and `0.15 H` (the mockup's 7.5 and 13.5 units on 90). The vertical rhythm is a share of the glass's height `G`: the name's row starts `0.095 G` below the glass's top under a round portrait (the mockup's capitals sit 9 units down on a 77-unit glass) and `0.15 G` under a chamfered one (the design file), the rows are `0.1 G` apart, and the last row ends `0.14 G` above the glass's bottom edge. The two side paddings never take more than 40% of the panel beside the portrait, so a narrow frame keeps its track. Inside the glass, from the top:

1. The name, left-aligned, in capitals when `nameCaps` is on. The kit sheet tracks its capitals wide; `FontString` has no letter spacing, so a plain name in KstyleUI's own fonts gets a thin space (U+2009, 0.1 em) between letters. A secret name, or a name in another font that may lack the glyph, keeps the font's own spacing. The level sits at the right of this row when there is no portrait.
2. The health track, then the health text after it: the text's column is `Format.ColumnWidth` of the format shown at the track's end (`Format.Shown`: `percent` for `both` while the row under the track fits, `currentMax` when the game has no percent curve) and the health font, at least 28% of the column under a round portrait (the mockup's bar takes 72%), right-aligned to the column's far edge; the track takes the rest minus a 4-unit gap, so the fill never runs under the numerals. When that would leave the track less than half the column (a narrow frame, or a long fallback text), the text sits over the track's right end instead. The track takes the height the other rows leave, about `0.19 G` at the defaults. Its fill takes the bar colour, the kit sheet's red (`healthHostile`) for a hostile unit, and its track is `buttonFill`, the mockup's dark track. The health text is a light version of the bar colour (85% of the way to white, as the kit sheet's near-white numerals) with the soft shadow. A secret colour is never mixed: the text then stays `textEmphasis`.
3. A hairline under the track and the health text (`edgeBar`, the bar grade's white at 16%, one border thick, 2 units below the track), as the design file draws it, when a row or the power bar sits under the track.
4. A row under the track, as the owner's mockup draws it: the power bar at the left, a short bar 37% of the column and `powerHeight` tall (7 by default), its fill the class colour and its track `buttonFill`, the mockup's dark #101214 track like the health bar's, hidden with its text while the unit's max power is a plain zero (a crocolisk has no power; a secret max keeps the bar, since nothing may compare it); then, with the `both` format, current and max right-aligned at the health text's right edge, in the health font at 85% of its size and the near-white `textEmphasis`; and the power text after the bar, when its format is not `none`. Without any of these, or when the row does not fit whole, it is not drawn and the track grows taller; `both` then shows current, max and the percentage together at the track's end. The full frames show no power numbers by default.

A frame shorter than the kit's room squeezes the gaps first, down to 1 unit between the rows and 4 above the name, and keeps every part.

Text never pushes a bar out of the frame, and no two texts overlap. The track always keeps room for its own text. The row under the track gives way first, then the name, which shrinks to the height of its capitals and is left out below that. Every text rect is clamped inside the frame. A shorter frame is compact: the name and the health text sit inside the health bar, and there is no badge.

## Files

`UnitFrames.xml` loads the files in this order:

| File | What it holds |
| --- | --- |
| `Init.lua` | The addon table the files share |
| `Settings.lua` | `ns.Settings`: the defaults, the choices each setting allows, `Value(kind, key)` (the stored value, or the default with one devlog line when it is not allowed), `Font(kind, element) -> path, size, flags` (the size times Appearance's text size), `Accent() -> r, g, b`, `Snapshot(kind)` (plain values for the geometry) and `Schema()` |
| `Format.lua` | `ns.Format`: `Health(text, unit, format)` and `Power(text, unit, format, powerType)` write the text with `SetFormattedText`, `AbbreviateNumbers` and `UnitHealthPercent` or `UnitPowerPercent` with a 0 to 100 curve, so no secret is ever read. On a full frame `Main(format)` is the format at the track's end (`both` becomes `percent`) and `HealthDetail(text, unit, format)` writes current and max under the track for `both`, or clears it for a dead, ghost or offline unit, or when there is no curve and the main text already shows current and max. `ColumnWidth(format, size)` is the room a format needs on a compact frame. `Sample` and `SampleDetail` write plain numbers for the preview. |
| `Geometry.lua` | `ns.Geometry`: `Frame(s, width, height, fontScale) -> parts`, each part `{ x, y, w, h }` from the frame's top left with y growing downward, and `Slots(count, gap, width, height)` for the boss frames. `panel` is the column beside the portrait that holds the bars and texts; `glass` is the chamfered glass, which runs under the portrait; `healthSub` is current and max under the track. Pure maths, tested without frames. |
| `Style.lua` | `ns.Style`: `New(parent, kind) -> view` builds the parts on a button or the preview, `Layout(view, s, width, height)` places them in whole pixels, `Restyle(view, kind)` applies fonts, textures, fill directions, the portrait shape and the accent, `Shape(view, round)` shows the chamfered or the round portrait; the badge stays the octagon and `Accent` colours its line for the shape |
| `Indicators.lua` | `ns.Indicators`: the raid marker, the status icons (`SLOTS`: leader, role, PvP, combat, resting) and the threat glow. `New(view)`, `Layout(view, g, s)`, `Update(view, unit)`, and one function per indicator. |
| `Unit.lua` | `ns.Unit`: fills a view from the unit API. `All(view, unit, instant)`, `Health`, `Power`, `HealthColor`, `PowerColor`, `Prediction`, `Name`, `Level`, `Portrait`. |
| `Blizzard.lua` | `ns.Blizzard.Apply(active)`: hides or restores Blizzard's frames |
| `CastBar.lua` | `ns.CastBars`: the cast bars. `Geometry(width, height, icon, timer, textSize) -> parts` (pure maths: `icon`, `panel`, `bar`, `text`, `timer`, `stacked`, `tall`), `Get(kind)`, `Attach(view)` for focus and boss views, `Layout(cb, width, height)`, `Restyle(cb)`, `Refresh(kind)`, `Enable`, `Disable`, and `NewBar` for the preview. |
| `Auras.lua` | `ns.Auras`: frame auras. `Apply(view)` builds a view's container on first use and applies its settings, `Sync(view)` follows the button's visibility, `Open()` is the aura gate, `Enable`, `Disable`. |
| `Resource.lua` | `ns.Resource`: the class resource element. `Enable`, `Disable`, `Restyle`, `Layout`, `Visibility`, `Points`, `Mana`. |
| `Frames.lua` | `ns.Frames`: the holders and secure buttons, unit watches, events, `Enable`, `Disable`, `Get(kind)` |
| `Preview.lua` | `ns.Preview.Build(parent)`: the settings window's live preview |
| `Module.lua` | Registers the module, the settings page and the `/kstyle test` check |

Tests: `Tools/regression/test-unitframes-settings.lua`, `test-unitframes-geometry.lua`, `test-unitframes-frames.lua`, `test-unitframes-indicators.lua`, `test-unitframes-resource.lua`, `test-unitframes-castbars.lua`, `test-unitframes-castbar-style.lua`, `test-unitframes-kit.lua`, `test-unitframes-auras.lua` and `test-unitframes-preview.lua`, on the fake units in `Tools/regression/unitframes_env.lua`.

## Settings

The settings page starts with the module-wide settings, then a **Frame to customise** picker. Only the picked frame's rows show, so the page stays short. Each frame's rows carry `scope = { key = "edit", value = <frame> }`, so the settings search finds every frame's rows, whichever frame is picked. Every frame has the same settings, under its own key such as `player.healthText`:

| Key | Values | Default |
| --- | --- | --- |
| `hideBlizzard` | Hide Blizzard's frames that KstyleUI replaces | on |
| `accent`, `accentColor` | The portrait frame's colour, and the badge's on a round portrait: `class` (the KstyleUI accent) or `custom` | `class` |
| `edit` | The frame the page shows | `player` |
| `<frame>.enabled` | Show the frame | on |
| `<frame>.portrait`, `portraitStyle`, `portraitSide` | Portrait: on or off; `portrait` (2D) or `class` (class icon); `LEFT` or `RIGHT` | on for player, target, focus and boss; target on the right |
| `<frame>.portraitShape` | `round` (the owner's mockup: the ring, the octagon badge with the accent line) or `chamfered` (the design file: the chamfered square, the badge with the grey line) | `round` |
| `<frame>.name`, `nameCaps`, `level` | Name, in capitals; level badge | on |
| `<frame>.healthTexture`, `powerTexture` | Bar texture: KstyleUI's and LibSharedMedia's | Glass |
| `<frame>.healthColor`, `powerColor` | Colour source: `class` (class colour for players, reaction for NPCs), `reaction`, `custom`, and for power `power` (the power type's colour) | `class`; power `class` on full frames (the mockup's class-coloured rage bar) and `power` on compact ones; the target's health `reaction` |
| `<frame>.healthCustom`, `powerCustom` | The custom colours | from the tokens |
| `<frame>.healthOrientation`, `powerOrientation` | Fill direction: `RIGHT`, `LEFT`, `UP`, `DOWN` | `RIGHT` |
| `<frame>.healthText`, `powerText` | `percent`, `current`, `currentMax`, `both`, `none`. On a full frame `both` puts the percentage at the track's end and current and max under it. | health `both` on full frames, `percent` on compact ones; power `none` |
| `<frame>.healPrediction` | Incoming heals and absorbs on the health bar | on |
| `<frame>.power`, `powerHeight` | Power bar, 2 to 24 units | on for full frames; 7 units on full frames, 3 on compact ones |
| `<frame>.raidMarker`, `leader`, `role`, `pvp`, `combat`, `resting`, `threat` | The raid marker, the status icons and the threat glow. `resting` is the player's only. | on for full frames; combat and resting on the player only; the raid marker on every frame |
| `<frame>.iconSize` | Status icon size, 8 to 32 units | 14 |
| `<frame>.castbar`, `castbarIcon`, `castbarText`, `castbarCaps`, `castbarTimer` | The cast bar and its spell icon, spell name, the name in tracked capitals, and timer (player, target, focus and boss) | on; the player's icon and capitals off, as the mockup draws "Slam" |
| `<frame>.castbarHeight` | The focus and boss cast bar height, 6 to 40 units. The player and target cast bars are their own elements, sized in Layout. | 20 focus, 10 boss |
| `<frame>.auras` | Frame auras (player, target, focus and boss) | on for focus and boss |
| `<frame>.auraFilter` | `mine` (your debuffs), `debuffs`, `buffs`, `both` | `mine` |
| `<frame>.auraPosition`, `auraGrowth` | `BELOW`, `ABOVE`, `RIGHT`, `LEFT` of the frame; `RIGHT_DOWN`, `RIGHT_UP`, `LEFT_DOWN`, `LEFT_UP` | `RIGHT` for focus and boss, `BELOW` for the player, `ABOVE` for the target; `RIGHT_DOWN` |
| `<frame>.auraSize`, `auraSpacing`, `auraRows`, `auraColumns`, `auraTimer` | Icon size 12 to 48, spacing 0 to 12, 1 to 6 rows of each kind, 1 to 16 columns, the time left on each icon | 20 (boss 18), 2, 1, 8 (boss 6), on |
| `<frame>.castbarTexture`, `castbarColor`, `castbarCustom` | Cast bar texture, and `class` (the class accent), `reaction` (the caster's reaction to you; the class accent while it is secret) or `custom` colour | Glass, `class` |
| `<frame>.castbarOrientation` | Cast bar fill direction: `RIGHT`, `LEFT`, `UP`, `DOWN`. A cast bar taller than it is wide stacks its icon above the bar and puts the spell name at the top and the timer at the bottom. | `RIGHT` |
| `<frame>.fonts.<text>.font`, `.size`, `.outline` | For the `name`, `health`, `power`, `level` and, on frames with a cast bar and auras, `cast` and `aura` texts: `theme` (Appearance's font) or a font file; 6 to 32 units; `NONE`, `OUTLINE`, `THICKOUTLINE` | `theme`; name, health, power and level 15, 15, 13 and 16 on the player and target (the mockup's name capitals are 9.6 units, its level numerals 10.4), 12, 12, 10 and 12 on focus, 10, 10, 9 and 10 on boss, 9 on compact frames; cast 15 on the player's 36-unit bar (the mockup's Slam) and 12 on the target's 28-unit bar, 10 on focus, 9 on boss; `NONE` |

The class resource has its own settings, under the player frame's rows:

| Key | Values | Default |
| --- | --- | --- |
| `resource.enabled` | Show the class resource element | on |
| `resource.comboPoints`, `comboColor`, `comboCustom`, `spacing` | Combo point pips: on or off, `class` (the class accent) or `custom` colour, 0 to 12 units apart | on, `class`, 3 |
| `resource.druidMana`, `manaTexture`, `manaColor`, `manaCustom` | The druid's mana bar in bear and cat form: on or off, texture, `power`, `class` or `custom` colour | on, Glass, `power` |
| `resource.manaOrientation` | The druid mana bar's fill direction: `RIGHT`, `LEFT`, `UP`, `DOWN` | `RIGHT` |

Size, position, opacity, strata and the shown rule come from Layout's element rows under **Positions and sizes**.

## Indicators

| Indicator | Source | Where |
| --- | --- | --- |
| Raid marker | `GetRaidTargetIndex`, always secret, straight to `SetSpriteSheetCell` on `UI-RaidTargetingIcons` | Centred on the portrait's top edge, or the glass's |
| Leader | `UnitIsGroupLeader`; a secret answer goes to `SetAlphaFromBoolean` | The status icon row on the glass's top edge, running from the end away from the portrait |
| Role | `UnitGroupRolesAssigned`, the `roleicon-tiny-*` atlases | The same row |
| PvP | `UnitIsPVPFreeForAll`, `UnitIsPVP` and `UnitFactionGroup`, Camelot's `UI-HUD-UnitFrame-SmallCircle-*` atlases | The same row |
| Combat | `UnitAffectingCombat`, the `UI-HUD-UnitFrame-Player-CombatIcon` atlas | The same row |
| Resting | `IsResting`, a "Zz" in the accent colour | The same row, player only |
| Threat glow | `UnitThreatSituation`: the player's own status on the player frame and friendly units, the player's status on a hostile unit elsewhere. A status above 0 lights the glow in `Theme.ThreatColor`, the `neutral` and `hostile` tokens that group frames and nameplates also use. | A soft additive glow around the panel |

## Cast bars

Each cast bar is a tile-chamfer glass panel with a soft shadow. With `castbarIcon` on (the target, focus and boss bars, as the design file draws them) the spell icon sits in its own tile-chamfer square, as tall as the bar, then a gap of `0.21 H` (the design file's 6 units on a 28-unit bar, at least 2) before the glass; the player's bar has no icon and its glass spans the whole width, as the owner's mockup draws Slam. The status bar sits inside the glass with a `buttonFill` track and no border of its own. `CastBars.Geometry` picks one of three layouts:

| Layout | When | What |
| --- | --- | --- |
| Stacked | Wider than tall, and the glass leaves room for the cast text, a 1-unit gap and a 3-unit bar above its bottom inset | The spell name left and the timer right on a row at the top, and a thin bar (22% of the height, at least 3 units) `0.22 H` above the glass's bottom, `0.5 H` in from each end (never more than a tenth of the glass's width each, so a tall narrow bar keeps its fill and its name): the mockup's Slam bar, 8 units above the bottom and 18 units in on a 37-unit bar. The timer's column is 3 em, never more than half the row |
| Inline | Wider than tall and shorter than that | The bar fills the glass inside its bevel lines, with the spell name and the timer on it |
| Tall | Taller than wide | The icon on top, the glass under it, the spell name at the bar's top and the timer at its bottom |

The player cast bar (36 units), the focus cast bar (20 units) and the target cast bar (18 units) are stacked. The target cast bar turns inline when Layout makes it shorter, and the boss cast bars (10 units) are inline until their height setting makes them 18 or taller.


| Event | What the bar does |
| --- | --- |
| `UNIT_SPELLCAST_START`, `UNIT_SPELLCAST_DELAYED` | Reads `UnitCastingInfo`, then runs the bar on `UnitCastingDuration` through `StatusBar:SetTimerDuration` with `ElapsedTime`, so it fills |
| `UNIT_SPELLCAST_CHANNEL_START`, `UNIT_SPELLCAST_CHANNEL_UPDATE` | The same with `UnitChannelInfo`, `UnitChannelDuration` and `RemainingTime`, so it drains |
| `UNIT_SPELLCAST_STOP`, `UNIT_SPELLCAST_CHANNEL_STOP` | Fades out over `fade` |
| `UNIT_SPELLCAST_FAILED`, `UNIT_SPELLCAST_INTERRUPTED` | Shows "Failed" or "Interrupted" on a full bar in the `hostile` colour, then fades after 0.6 seconds |
| `UNIT_SPELLCAST_INTERRUPTIBLE`, `UNIT_SPELLCAST_NOT_INTERRUPTIBLE` | Greys a bar that cannot be interrupted |
| `PLAYER_TARGET_CHANGED`, `PLAYER_FOCUS_CHANGED`, `INSTANCE_ENCOUNTER_ENGAGE_UNIT` | Shows the new unit's cast in progress, or hides the bar |

- Whether a unit casts comes from `isTradeSkill`, which Forever never makes secret: it is a boolean while a cast runs and `nil` otherwise. No other cast value is ever tested.
- The spell name goes to `SetText` through `CastBars.SetName`: with `castbarCaps` on, in capitals tracked with thin spaces in KstyleUI's own fonts like the unit name (`Unit.Tracked`), as the design file's caption; off (the player's default), as the game writes it, the mockup's "Slam". A secret name goes to `SetText` untouched either way. The timer reads `1.8s`, with the suffix both references show. The icon goes to `SetTexture` untouched for every unit, a secret file ID included; the repainted icons reach it through the loose-file icon pack the client loads ([`docs/icons.md`](../docs/icons.md)).
- A secret `notInterruptible` colours the bar with `SetVertexColorFromBoolean`.
- The timer counts down on an `OnUpdate` that runs only while a cast shows its timer, every 0.05 seconds, through `SetFormattedText` with the duration's remaining time, which may be secret.
- Fallbacks, each logged once to the devlog: when there is no duration object or `SetTimerDuration` refuses one, the bar runs on the cast's start and end times while they are plain; when those are secret too, the bar shows full with the spell name and no timer. A secret duration object cannot be read, so it drives the bar with no timer text.
- A light sheen crosses a horizontal bar at the start of each cast, as the spec's motion table asks. A vertical bar has no sheen, because the sheen moves sideways.
- A cast start sets no fonts, textures or fill direction: settings, theme and profile changes restyle the bars. The bar colour is set only when it changes, the two colour objects for a secret `notInterruptible` are rebuilt only when a colour changes, and the hold after a failed or interrupted cast reuses one release function per bar.

## Frame auras

Each player, target, focus and boss view gets a `CustomAuraContainerTemplate` container the first time its auras are switched on. The container reads the unit's auras in Blizzard's secure environment, so the module never calls `C_UnitAuras` and never touches aura data.

| Part | How |
| --- | --- |
| Groups | Two groups, `debuffs` and `buffs`. The filter setting enables them and sets their filter strings: `HARMFUL|PLAYER`, `HARMFUL`, `HELPFUL`, or both, with buffs starting a new line. Each group holds `auraRows` times `auraColumns` icons. |
| Layout | The group layout sets `elementWidth`, `elementHeight` and the spacing; the flow layout grows from the corner the growth setting names, with lines `auraColumns` icons long. These container-level changes apply at once, in or out of combat. |
| Buttons | `initializeFrame` dresses each engine button in the kit's icon tile (`Auras.NewTile`, shared with the preview): a child frame with the kit's icon chrome (`Widgets.IconChrome`: the near-black `buttonFill` body, the accent rim with its halo, a 3-unit chamfer and double bevel at any icon size), the icon two borders in and masked by `iconMask` (`SetIcon`), a reverse cooldown swipe in the `iconMask` shape (`SetDurationCooldown`), the stack count (`SetApplicationCount`), the time left (`SetDurationText`) and, for debuffs, a `chamferTile` border the engine tints by dispel type with the `PreserveAsset` style (`AddDispelTypeTexture`). The icon size, spacing and gap to the frame snap to whole pixels. |
| The gate | The engine denies tainted code access to its buttons while `C_Secrets.ShouldAurasBeSecret()` is true. A later restyle of the buttons (size, tile, fonts, timer), including a theme change, runs only out of combat while auras are readable, and otherwise waits for `PLAYER_REGEN_ENABLED` or `ADDON_RESTRICTION_STATE_CHANGED`. |
| Placement | The container sits on a host frame on the root, anchored beside the unit's button. The host shows while the button shows and the auras are on, and mirrors the frame holder's alpha and strata, so Layout's opacity follows. |
| Fallback | Without the engine, or if it refuses a group, the frames show no auras and the devlog says why. |

## Class resource

`unitframes.resource` sits under the player frame, beside action bar 1. It shows only what the player's class and form need:

| Class and form | Shows |
| --- | --- |
| Rogue | Five combo point pips |
| Druid in cat form | Pips and the mana bar |
| Druid in bear form, or any form with a power other than mana | The mana bar |
| Anyone else | Nothing |

Each pip is a status bar from `i - 1` to `i` filled with the `dot` texture, and every pip gets the same count, so the engine decides which pips are full and a secret count never reaches a comparison. Combo points are bound to the target on Forever: the count comes from `GetComboPoints("player", "target")` and refreshes on `UNIT_POWER_FREQUENT`, `PLAYER_TARGET_CHANGED` and `COMBO_TARGET_CHANGED`. `UNIT_POWER_FREQUENT` and `UNIT_MAXPOWER` are registered only while the element shows pips or the mana bar, because `UNIT_POWER_FREQUENT` fires on every mana, energy and rage tick. The mana bar reads `UnitPower("player", Enum.PowerType.Mana)` and refreshes on mana power events, `UNIT_DISPLAYPOWER` and `UPDATE_SHAPESHIFT_FORM`.

## Blizzard frames

With `hideBlizzard` on, each Blizzard frame whose KstyleUI frame is on is hidden with `KstyleUI.Safe.HideBlizzard`, and restored with `Safe.RestoreBlizzard` when the module stops or the setting goes off:

| KstyleUI frame | Blizzard frames |
| --- | --- |
| Player | `PlayerFrame` |
| Target | `TargetFrame` (its target of target, `TargetFrameToT`, is a child) |
| Focus | `FocusFrame` (and its child `FocusFrameToT`) |
| Pet | `PetFrame` |
| Boss | `Boss1TargetFrame` to `Boss5TargetFrame` (their cast bars are children) |
| Player cast bar | `PlayerCastingBarFrame`, while `player.castbar` is on |

These names come from `Blizzard_UnitFrame/Mainline/TargetFrame.xml`, `PlayerFrame.xml` and `PetFrame.xml` on the `forever` branch, with the `Camelot/` overrides only changing their contents.

## Why

- **One holder per element, buttons inside.** `RegisterUnitWatch` shows and hides the secure button, and Layout's shown rules show and hide the holder, so the two never fight over one frame. The holder becomes protected through its secure children, so Layout queues its changes in combat; the module also re-anchors its buttons only out of combat.
- **The boss frames hide one by one.** `BossTargetFrameContainer` is a managed frame: Edit Mode and the right-side frame manager reparent it back to their container. Its five boss frames are not managed, so hiding each of them stays hidden.
- **Health never reaches Lua.** `UnitHealth` is always secret on Forever. The bar gets `SetMinMaxValues(0, UnitHealthMax(unit))` and `SetValue(UnitHealth(unit))`, the engine eases it, and the text comes from `SetFormattedText` with `AbbreviateNumbers` and `UnitHealthPercent` evaluated through a 0 to 100 curve. Without a curve API the percentage would be a 0 to 1 share, so the text falls back to current and max and the devlog says so.
- **The texts' columns come from settings, never from the text.** A text's width would be secret when its text is, so the module never measures one. The health text's column after the track is `Format.ColumnWidth` of the chosen format and font size, the same rule the compact frames use, and the row under the track is split in halves, so no bar's width depends on what a text says. The design file and the owner's mockup both draw the percentage after the bar, so the fill never runs under the numerals at any health.
- **The glass runs under the portrait.** The kit sheet draws one panel with the portrait over its outer end, not a portrait beside a separate box. Starting the glass at the portrait's centre hides its end behind the portrait at any frame size, and the 2-unit inset lets the panel's top and bottom lines run out from behind the portrait's chamfered corners.
- **The chamfered portrait asks for a square image.** `SetPortraitTexture` masks the portrait round unless `disableMasking` is true, and a round image would leave the octagon's corners empty. The image is then masked by `iconMask` and drawn under the bevel lines, which cover any difference between the mask's chamfer and the frame's.
- **The name has no letter spacing.** The kit sheet tracks its captions wide, but Forever's `FontString` has no letter-spacing call. Spacing a name with extra characters would need string work on a name that can be secret, so the name keeps the font's own spacing.
- **The frames are 89 units tall.** The kit sheet draws a frame 469 by 141 pixels on a 1520-pixel sheet, about 100 units at the 1080 reference, with room above the name and clear gaps between the rows; at 266 by 46 every row touched the next. On the Mac's 3456 by 2234 screen the root is 1671 units wide, and 89 units tall flanks the cooldown rows and clears the chat. The width is the owner's mockup's: its frame measures 279 units from the ring's outer edge to the glass's end on a 90-unit ring (at 1.348 px per unit), so the frame is 280 by 89, its inner edge 220 units from the screen's centre. The spacing is a share of the height, so a resized frame keeps the same look, and fonts are settings sized for each frame's default height: the name's capitals and the percentage's numerals are the same height, as measured on the sheet.
- **The small parts sit beside and under the frames, except the class resource.** The composition mockup puts the frames beside the essential row, with the utility row, the experience line and the action bars stacked below them. Its 195-unit tracked buff bars take the whole row under the player frame and the target cast bar the row under the target frame, and it shows neither a pet frame nor a target of target, so those two 104-unit compact frames sit beside the frames' portrait ends, 4 units out and bottom-aligned, mirroring each other. The class resource sits on top of the player frame, right-aligned, because the chat panel on the Mac's 1671-unit-wide root reaches up to where a second row under the frame would sit.
- **The target's health follows its reaction.** The kit sheet fills a hostile target red. With `reaction`, any hostile unit, player or NPC, is red; with `class`, a hostile player would show their class colour.
- **Fonts belong to the module.** The kit's `Widgets.Text` restyles its texts to their role on every theme change, which would undo a player's font choice. The unit frame texts are the module's own font strings, styled from their settings and restyled on `ThemeChanged`.
- **Target of target and focus target poll.** Unit events never fire for `targettarget` and `focustarget`. Those two frames refresh on `PLAYER_TARGET_CHANGED`, `PLAYER_FOCUS_CHANGED` and `UNIT_TARGET`, and poll health and power every 0.2 seconds only while their button is shown, as Blizzard's own frames do.
- **One picker, one frame's rows.** Seven frames with the same thirty settings would make a page of over two hundred rows. The page shows the picked frame's rows, and the preview draws that frame.
- **The target cast bar is its own element.** The target frame's footprint has no room for it, and the kit sheet shows it under the frame. It sits under the target frame, right-aligned, with the target of target under it; `test-setup-layouts.lua` checks that nothing overlaps and that every unit frame keeps 2 units from its neighbours.
- **Focus and boss cast bars live inside their frames.** Their footprints already hold a cast bar under each frame, so the bar is a child of the unit's button and moves and hides with it. Their height is a setting that takes room from the frame above.
- **Blizzard's player cast bar may come back after Edit Mode.** `PlayerCastingBarFrame` is a managed frame: Edit Mode can reparent it to its container while it is casting. The next login hides it again.
- **Layout owns visibility.** Layout's shown rules hide a holder with a state driver or `Hide`. The module shows a holder only when it hid it itself, in `Disable`, so a setting change never brings back an element the player set to never show.
- **Cast events match the shown cast.** A spell can fail or stop while another cast runs. Terminal events carry `castBarID`, which Forever never makes secret; the bar ends only when that ID matches the cast it shows, or, without IDs, when the unit has no cast left.
- **Aura containers are not children of the frame.** Layout's mouseover rule hooks `OnEnter` on an element's children four levels deep, and engine aura buttons refuse untrusted scripts. The host is a sibling on the root that follows the button and mirrors the holder's alpha and strata instead.
- **Auras are off on the player and target by default.** The Auras module shows the player's own buffs and debuffs under the minimap, and the space around the target frame belongs to the target cast bar, the target of target and the tracked buff icons. Focus and boss frames have room to their right. Any frame's auras can be switched on and placed on any side.
- **Status icons keep fixed slots.** A leader or PvP flag can be secret, so the module cannot tell which icons show to pack them together. Each icon keeps its own slot in the row, so nothing moves when a secret flag changes.
- **Resting is text.** Blizzard's resting art is a 42-frame flipbook atlas. A "Zz" in the accent colour needs no animation and follows the accent.
- **The class resource is its own element.** The pips sit under the frame in the v3 mockups. As their own Layout element they move and resize on their own, and the setup places them so they overlap nothing.
- **Focus target has its own key.** The element keys had no focus target. It sits under the focus frame, right-aligned, and `test-setup-layouts.lua` checks that it overlaps nothing in any layout.
