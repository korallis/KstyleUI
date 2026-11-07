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
- Player and target frames are 220 by 46 units with 46-unit portraits at the 1080 reference, centred above the action bars on either side of the Cooldown Manager. Portraits are on by default, with a switch to turn them off.
- Blizzard frames this module replaces are hidden only through `KstyleUI.Safe.HideBlizzard`.
- At load the module only registers itself with `KstyleUI.Modules.Register`. It creates no frames, registers no events and installs no hooks until `Enable` runs. `test-modules-load.lua` checks the frames.
- Every element it shows registers with `KstyleUI.Layout.Register`, and every setting is declared through `KstyleUI.Options.Register`, so the player can resize and customise everything from the settings window.
- UI comes from `KstyleUI.Widgets`, colours from `KstyleUI.Tokens` and strings from `KstyleUI.L`. Translations go in `Locale.lua` in this folder, loaded by `UnitFrames.xml`.
- Build mode: check that an API exists before calling it, check `issecretvalue` before any comparison, fall back to a safer path when the preferred one is unavailable, and log the path taken with `KstyleUI.DevTest.Log`.

## Frames

| Frame | Element key | Unit | Default size |
| --- | --- | --- | --- |
| Player | `unitframes.player` | `player` | 266 x 46: a 46-unit portrait and a 220 by 46 panel |
| Target | `unitframes.target` | `target` | 266 x 46, the portrait on the right |
| Target of target | `unitframes.targettarget` | `targettarget` | 120 x 24, compact |
| Focus | `unitframes.focus` | `focus` | 266 x 70: a 46-unit frame, then its 20-unit cast bar |
| Focus target | `unitframes.focustarget` | `focustarget` | 120 x 24, compact |
| Pet | `unitframes.pet` | `pet` | 120 x 24, compact |
| Boss | `unitframes.boss` | `boss1` to `boss5` | 266 x 330: five slots of 58 units, 10 apart, each a 46-unit frame and a 10-unit cast bar |
| Player cast bar | `unitframes.castbar.player` | `player` | 260 x 20 |
| Target cast bar | `unitframes.castbar.target` | `target` | 220 x 14, under the target frame's bars |

Each frame is a plain holder frame registered with `KstyleUI.Layout.Register` under its key, with the setup's label, `module = "UnitFrames"` and `resizable = true`. The holder carries one `SecureUnitButtonTemplate` button per unit (five for the boss frame). The button has the attributes `unit`, `type1 = "target"` and `type2 = "togglemenu"`, registers for `AnyUp` clicks and is shown and hidden by `RegisterUnitWatch`. Layout moves and sizes the holder; the module anchors the buttons inside it and lays out their parts again whenever the holder's size changes. Hovering a button shows the unit tooltip through Blizzard's `UnitFrame_OnEnter` and `UnitFrame_OnLeave`.

A frame 36 units tall or more is a full frame: the name row on top, the health bar, then the power bar, with the health and power texts in columns to the right of their bars, and a level badge in the portrait's bottom outer corner. A shorter frame is compact: the name and the health text sit inside the health bar, and there is no badge.

## Files

`UnitFrames.xml` loads the files in this order:

| File | What it holds |
| --- | --- |
| `Init.lua` | The addon table the files share |
| `Settings.lua` | `ns.Settings`: the defaults, the choices each setting allows, `Value(kind, key)` (the stored value, or the default with one devlog line when it is not allowed), `Font(kind, element) -> path, size, flags` (the size times Appearance's text size), `Accent() -> r, g, b`, `Snapshot(kind)` (plain values for the geometry) and `Schema()` |
| `Format.lua` | `ns.Format`: `Health(text, unit, format)` and `Power(text, unit, format, powerType)` write the text with `SetFormattedText`, `AbbreviateNumbers` and `UnitHealthPercent` or `UnitPowerPercent` with a 0 to 100 curve, so no secret is ever read. `ColumnWidth(format, size)` is the room a format needs. `Sample` writes plain numbers for the preview. |
| `Geometry.lua` | `ns.Geometry`: `Frame(s, width, height, fontScale) -> parts`, each part `{ x, y, w, h }` from the frame's top left with y growing downward, and `Slots(count, gap, width, height)` for the boss frames. Pure maths, tested without frames. |
| `Style.lua` | `ns.Style`: `New(parent, kind) -> view` builds the parts on a button or the preview, `Layout(view, s, width, height)` places them in whole pixels, `Restyle(view, kind)` applies fonts, textures, fill directions and the accent |
| `Indicators.lua` | `ns.Indicators`: the raid marker, the status icons (`SLOTS`: leader, role, PvP, combat, resting) and the threat glow. `New(view)`, `Layout(view, g, s)`, `Update(view, unit)`, and one function per indicator. |
| `Unit.lua` | `ns.Unit`: fills a view from the unit API. `All(view, unit, instant)`, `Health`, `Power`, `HealthColor`, `PowerColor`, `Prediction`, `Name`, `Level`, `Portrait`. |
| `Blizzard.lua` | `ns.Blizzard.Apply(active)`: hides or restores Blizzard's frames |
| `CastBar.lua` | `ns.CastBars`: the cast bars. `Get(kind)`, `Attach(view)` for focus and boss views, `Layout(cb, width, height)`, `Restyle(cb)`, `Refresh(kind)`, `Enable`, `Disable`, and `NewBar` for the preview. |
| `Auras.lua` | `ns.Auras`: frame auras. `Apply(view)` builds a view's container on first use and applies its settings, `Sync(view)` follows the button's visibility, `Open()` is the aura gate, `Enable`, `Disable`. |
| `Resource.lua` | `ns.Resource`: the class resource element. `Enable`, `Disable`, `Restyle`, `Layout`, `Visibility`, `Points`, `Mana`. |
| `Frames.lua` | `ns.Frames`: the holders and secure buttons, unit watches, events, `Enable`, `Disable`, `Get(kind)` |
| `Preview.lua` | `ns.Preview.Build(parent)`: the settings window's live preview |
| `Module.lua` | Registers the module, the settings page and the `/kstyle test` check |

Tests: `Tools/regression/test-unitframes-settings.lua`, `test-unitframes-geometry.lua`, `test-unitframes-frames.lua`, `test-unitframes-indicators.lua`, `test-unitframes-resource.lua`, `test-unitframes-castbars.lua`, `test-unitframes-castbar-style.lua`, `test-unitframes-auras.lua` and `test-unitframes-preview.lua`, on the fake units in `Tools/regression/unitframes_env.lua`.

## Settings

The settings page starts with the module-wide settings, then a **Frame to customise** picker. Only the picked frame's rows show, so the page stays short. Each frame's rows carry `scope = { key = "edit", value = <frame> }`, so the settings search finds every frame's rows, whichever frame is picked. Every frame has the same settings, under its own key such as `player.healthText`:

| Key | Values | Default |
| --- | --- | --- |
| `hideBlizzard` | Hide Blizzard's frames that KstyleUI replaces | on |
| `accent`, `accentColor` | Portrait ring and badge colour: `class` (the KstyleUI accent) or `custom` | `class` |
| `edit` | The frame the page shows | `player` |
| `<frame>.enabled` | Show the frame | on |
| `<frame>.portrait`, `portraitStyle`, `portraitSide` | Round portrait: on or off; `portrait` (2D) or `class` (class icon); `LEFT` or `RIGHT` | on for player, target, focus and boss; target on the right |
| `<frame>.name`, `nameCaps`, `level` | Name, in capitals; level badge | on |
| `<frame>.healthTexture`, `powerTexture` | Bar texture: KstyleUI's and LibSharedMedia's | Glass |
| `<frame>.healthColor`, `powerColor` | Colour source: `class` (class colour for players, reaction for NPCs), `reaction`, `custom`, and for power `power` (the power type's colour) | `class`, `power` |
| `<frame>.healthCustom`, `powerCustom` | The custom colours | from the tokens |
| `<frame>.healthOrientation`, `powerOrientation` | Fill direction: `RIGHT`, `LEFT`, `UP`, `DOWN` | `RIGHT` |
| `<frame>.healthText`, `powerText` | `percent`, `current`, `currentMax`, `both`, `none` | `percent`; power `currentMax` on the player and target |
| `<frame>.healPrediction` | Incoming heals and absorbs on the health bar | on |
| `<frame>.power`, `powerHeight` | Power bar, 2 to 24 units | on for full frames, 5 units |
| `<frame>.raidMarker`, `leader`, `role`, `pvp`, `combat`, `resting`, `threat` | The raid marker, the status icons and the threat glow. `resting` is the player's only. | on for full frames; combat and resting on the player only; the raid marker on every frame |
| `<frame>.iconSize` | Status icon size, 8 to 32 units | 14 |
| `<frame>.castbar`, `castbarIcon`, `castbarText`, `castbarTimer` | The cast bar and its spell icon, spell name and timer (player, target, focus and boss) | on |
| `<frame>.castbarHeight` | The focus and boss cast bar height, 6 to 40 units. The player and target cast bars are their own elements, sized in Layout. | 20 focus, 10 boss |
| `<frame>.auras` | Frame auras (player, target, focus and boss) | on for focus and boss |
| `<frame>.auraFilter` | `mine` (your debuffs), `debuffs`, `buffs`, `both` | `mine` |
| `<frame>.auraPosition`, `auraGrowth` | `BELOW`, `ABOVE`, `RIGHT`, `LEFT` of the frame; `RIGHT_DOWN`, `RIGHT_UP`, `LEFT_DOWN`, `LEFT_UP` | `RIGHT` for focus and boss, `BELOW` for the player, `ABOVE` for the target; `RIGHT_DOWN` |
| `<frame>.auraSize`, `auraSpacing`, `auraRows`, `auraColumns`, `auraTimer` | Icon size 12 to 48, spacing 0 to 12, 1 to 6 rows of each kind, 1 to 16 columns, the time left on each icon | 20 (boss 18), 2, 1, 8 (boss 6), on |
| `<frame>.castbarTexture`, `castbarColor`, `castbarCustom` | Cast bar texture, and `class` (the class accent), `reaction` (the caster's reaction to you; the class accent while it is secret) or `custom` colour | Glass, `class` |
| `<frame>.castbarOrientation` | Cast bar fill direction: `RIGHT`, `LEFT`, `UP`, `DOWN`. A cast bar taller than it is wide stacks its icon above the bar and puts the spell name at the top and the timer at the bottom. | `RIGHT` |
| `<frame>.fonts.<text>.font`, `.size`, `.outline` | For the `name`, `health`, `power`, `level` and, on frames with a cast bar and auras, `cast` and `aura` texts: `theme` (Appearance's font) or a font file; 6 to 32 units; `NONE`, `OUTLINE`, `THICKOUTLINE` | `theme`, 11 or 9, `NONE` |

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
| Raid marker | `GetRaidTargetIndex`, always secret, straight to `SetSpriteSheetCell` on `UI-RaidTargetingIcons` | Centred on the portrait's top edge, or the panel's |
| Leader | `UnitIsGroupLeader`; a secret answer goes to `SetAlphaFromBoolean` | The status icon row on the panel's top edge, running from the end away from the portrait |
| Role | `UnitGroupRolesAssigned`, the `roleicon-tiny-*` atlases | The same row |
| PvP | `UnitIsPVPFreeForAll`, `UnitIsPVP` and `UnitFactionGroup`, Camelot's `UI-HUD-UnitFrame-SmallCircle-*` atlases | The same row |
| Combat | `UnitAffectingCombat`, the `UI-HUD-UnitFrame-Player-CombatIcon` atlas | The same row |
| Resting | `IsResting`, a "Zz" in the accent colour | The same row, player only |
| Threat glow | `UnitThreatSituation`: the player's own status on the player frame and friendly units, the player's status on a hostile unit elsewhere. A status above 0 lights the glow in `Theme.ThreatColor`, the `neutral` and `hostile` tokens that group frames and nameplates also use. | A soft additive glow around the panel |

## Cast bars

| Event | What the bar does |
| --- | --- |
| `UNIT_SPELLCAST_START`, `UNIT_SPELLCAST_DELAYED` | Reads `UnitCastingInfo`, then runs the bar on `UnitCastingDuration` through `StatusBar:SetTimerDuration` with `ElapsedTime`, so it fills |
| `UNIT_SPELLCAST_CHANNEL_START`, `UNIT_SPELLCAST_CHANNEL_UPDATE` | The same with `UnitChannelInfo`, `UnitChannelDuration` and `RemainingTime`, so it drains |
| `UNIT_SPELLCAST_STOP`, `UNIT_SPELLCAST_CHANNEL_STOP` | Fades out over `fade` |
| `UNIT_SPELLCAST_FAILED`, `UNIT_SPELLCAST_INTERRUPTED` | Shows "Failed" or "Interrupted" on a full bar in the `hostile` colour, then fades after 0.6 seconds |
| `UNIT_SPELLCAST_INTERRUPTIBLE`, `UNIT_SPELLCAST_NOT_INTERRUPTIBLE` | Greys a bar that cannot be interrupted |
| `PLAYER_TARGET_CHANGED`, `PLAYER_FOCUS_CHANGED`, `INSTANCE_ENCOUNTER_ENGAGE_UNIT` | Shows the new unit's cast in progress, or hides the bar |

- Whether a unit casts comes from `isTradeSkill`, which Forever never makes secret: it is a boolean while a cast runs and `nil` otherwise. No other cast value is ever tested.
- The spell name goes to `SetText` and, for every unit but the player, the icon to `SetTexture`, both untouched. The player's icon goes through `KstyleUI.Icons.Apply`, so the custom icon sets show on the player cast bar only.
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
| Buttons | `initializeFrame` dresses each engine button in the kit's icon tile (`Auras.NewTile`, shared with the preview): a child frame with a `Widgets.Chrome` tile (raised fill, 3-unit chamfer and double bevel at any icon size), the icon two borders in and masked by `iconMask` (`SetIcon`), a reverse cooldown swipe in the `iconMask` shape (`SetDurationCooldown`), the stack count (`SetApplicationCount`), the time left (`SetDurationText`) and, for debuffs, a `chamferTile` border the engine tints by dispel type with the `PreserveAsset` style (`AddDispelTypeTexture`). The icon size, spacing and gap to the frame snap to whole pixels. |
| The gate | The engine denies tainted code access to its buttons while `C_Secrets.ShouldAurasBeSecret()` is true. A later restyle of the buttons (size, tile, fonts, timer), including a theme change, runs only out of combat while auras are readable, and otherwise waits for `PLAYER_REGEN_ENABLED` or `ADDON_RESTRICTION_STATE_CHANGED`. |
| Placement | The container sits on a host frame on the root, anchored beside the unit's button. The host shows while the button shows and the auras are on, and mirrors the frame holder's alpha and strata, so Layout's opacity follows. |
| Fallback | Without the engine, or if it refuses a group, the frames show no auras and the devlog says why. |

## Class resource

`unitframes.resource` sits under the player frame, right-aligned. It shows only what the player's class and form need:

| Class and form | Shows |
| --- | --- |
| Rogue | Five combo point pips |
| Druid in cat form | Pips and the mana bar |
| Druid in bear form, or any form with a power other than mana | The mana bar |
| Anyone else | Nothing |

Each pip is a status bar from `i - 1` to `i` filled with the `dot` texture, and every pip gets the same count, so the engine decides which pips are full and a secret count never reaches a comparison. Combo points are bound to the target on Forever: the count comes from `GetComboPoints("player", "target")` and refreshes on `UNIT_POWER_FREQUENT`, `PLAYER_TARGET_CHANGED` and `COMBO_TARGET_CHANGED`. The mana bar reads `UnitPower("player", Enum.PowerType.Mana)` and refreshes on mana power events, `UNIT_DISPLAYPOWER` and `UPDATE_SHAPESHIFT_FORM`.

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
- **Text columns come from the format, not the string.** A text's width would be secret when its text is, so the room each bar leaves for its text comes from the chosen format and font size. That is why the power bar is shorter than the health bar when it shows current and max, as in the v3 mockups.
- **Fonts belong to the module.** The kit's `Widgets.Text` restyles its texts to their role on every theme change, which would undo a player's font choice. The unit frame texts are the module's own font strings, styled from their settings and restyled on `ThemeChanged`.
- **Target of target and focus target poll.** Unit events never fire for `targettarget` and `focustarget`. Those two frames refresh on `PLAYER_TARGET_CHANGED`, `PLAYER_FOCUS_CHANGED` and `UNIT_TARGET`, and poll health and power every 0.2 seconds only while their button is shown, as Blizzard's own frames do.
- **One picker, one frame's rows.** Seven frames with the same thirty settings would make a page of over two hundred rows. The page shows the picked frame's rows, and the preview draws that frame.
- **The target cast bar is its own element.** The target frame's footprint has no room for it, and the kit sheet shows it under the frame. It sits under the target frame's bars, and the target of target moved down 24 units to make room; `test-setup-layouts.lua` checks that nothing overlaps.
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
