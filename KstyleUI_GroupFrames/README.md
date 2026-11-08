# KstyleUI_GroupFrames

Party and raid frames up to 40: class colours, role icons, range fade, incoming heals and dispellable debuff highlight.

| Field | Value |
| --- | --- |
| Module name | `GroupFrames`: its switch in `Core/Features.lua` and the `name` it registers with `KstyleUI.Modules.Register` |
| Approach | Replace |
| Loads | With the core addon, switched off until the player turns it on |
| Files | `KstyleUI_GroupFrames.toc` lists `GroupFrames.xml`, which loads every Lua file in order, so adding a file never edits the TOC |

## Rules

These come from the [design spec](../docs/superpowers/specs/2026-11-07-kstyleui-design.md). The roadmap's Global Constraints and [AGENTS.md](../AGENTS.md) apply too.

- Group frames use `SecureGroupHeaderTemplate` headers of `SecureUnitButtonTemplate` buttons. Health goes straight to the bar with `SetMinMaxValues(0, UnitHealthMax(unit))` and `SetValue(UnitHealth(unit))`. Health text comes from `UnitHealthPercent` or `AbbreviateNumbers`, never from Lua arithmetic. Incoming heals come from `CreateUnitHealPredictionCalculator`. Range fade uses `SetAlphaFromBoolean`, because `UnitInRange` is always secret.
- Auras use the AuraContainer engine (`CustomAuraContainerTemplate`, aura groups and filter strings). Never scan auras by index while `C_Secrets.ShouldAurasBeSecret()` returns true. Aura data turns secret during a boss pull before `InCombatLockdown()` returns true.
- Blizzard frames this module replaces are hidden only through `KstyleUI.Safe.HideBlizzard`.
- At load the module only registers itself with `KstyleUI.Modules.Register`. It creates no frames, registers no events and installs no hooks until `Enable` runs. `test-modules-load.lua` checks the frames.
- Every element it shows registers with `KstyleUI.Layout.Register`, and every setting is declared through `KstyleUI.Options.Register`, so the player can resize and customise everything from the settings window.
- UI comes from `KstyleUI.Widgets`, colours from `KstyleUI.Tokens` and strings from `KstyleUI.L`. Translations go in `Locale.lua` in this folder, loaded by `GroupFrames.xml`.
- Build mode: check that an API exists before calling it, check `issecretvalue` before any comparison, fall back to a safer path when the preferred one is unavailable, and log the path taken with `KstyleUI.DevTest.Log`.

## Files

`GroupFrames.xml` loads these in order:

| File | What it holds |
| --- | --- |
| `Init.lua` | The addon table the files share |
| `Settings.lua` | `ns.Settings`: the defaults, the settings schema, `Get(key)` and `Refresh()`, which read each saved value through its schema row so a damaged value gives its default |
| `Geometry.lua` | `ns.Geometry`: pure layout maths: header attributes per growth, holder sizes, raid group slots, flow columns and the parts inside one frame |
| `Style.lua` | `ns.Style`: builds a frame's look on any frame (glass tile, portrait, health and power bars, texts, target ring) and lays it out from the settings; `Ring` and `Wash` draw the kit's chamfered bevel lines and chamfered fill for the highlights |
| `Unit.lua` | `ns.Unit`: reads a unit into a frame on unit events: name, health, health text, power, colours, dead and offline states, portrait, level, range and target |
| `Button.lua` | `ns.Button`: dresses each secure button a header makes with a plain content frame, hooks that follow its `unit` attribute, hover and the unit tooltip |
| `Headers.lua` | `ns.Headers`: the party header and eight raid headers, their attributes, buttons made out of combat, and visibility drivers |
| `Blizzard.lua` | `ns.Blizzard`: hides and restores Blizzard's party frames, compact raid frames and raid manager through `KstyleUI.Safe`, and tells when the gamepad interface is on |
| `Frames.lua` | `ns.Frames`: `Enable` and `Disable`, settings applied out of combat, Layout registration, group events, the gamepad stand-down and the `/kstyle test` check |
| `Indicators.lua` | `ns.Indicators`: role, leader and assistant, raid marker and ready-check icons, and the threat glow |
| `Prediction.lua` | `ns.Prediction`: incoming heals and absorbs after the health fill |
| `Auras.lua` | `ns.Auras`: debuff icons, dressed as the kit's chamfered icon tiles, and the dispellable debuff highlight on the AuraContainer engine |
| `Preview.lua` | `ns.Preview`: the settings window's live preview with sample party and raid frames |
| `Module.lua` | `KstyleUI.Modules.Register` and `KstyleUI.Options.Register` |

Tests: `Tools/regression/test-groupframes-geometry.lua` (the maths), `test-groupframes-settings.lua` (registration, schema and damaged values), `test-groupframes-frames.lua` (headers, units, colours, range, sorting, combat safety, Blizzard frames, Disable) `test-groupframes-indicators.lua` (icons, threat, heals and absorbs, with their fallbacks), `test-groupframes-auras.lua` (debuffs and the dispel highlight, secrecy, combat and a client without the engine), `test-groupframes-shapes.lua` (the chamfered highlights and debuff icons, whole-pixel icon sizes, and the icon chrome waiting while auras are secret), `test-groupframes-gamepad.lua` (the stand-down for the gamepad interface, in and out of combat), `test-groupframes-preview.lua` and `test-groupframes-fallbacks.lua`. They load the module through `Tools/regression/group_env.lua`, which adds a roster, secure group headers that place units as Blizzard's `SecureGroupHeaders.lua` does, and a combat guard that raises on any protected call outside secure code.

## Elements

| Key | Frame | Layout options |
| --- | --- | --- |
| `groupframes.party` | The party holder: the party header in a frame sized to five members | Scalable |
| `groupframes.raid` | The raid holder: eight group headers, or one header in role or class order | Scalable |

The holders are scalable rather than resizable: frame width, height, spacing and growth are settings, and the holder's size follows them. Layout Mode scales a whole group block.

## Headers

- The party header shows `player` (when **Show yourself** is on) and `party1` to `party4`. Its state driver is `[group:raid] hide; [group] show; hide`, or `[group:raid] hide; show` with **Show when solo**.
- Sorting by **Group** gives eight raid headers, one per raid group (`groupFilter` 1 to 8), placed by `Geometry.RaidGroups`. Each shows in a raid only.
- Sorting by **Role** or **Class** uses the first raid header with every group, `groupBy` `ASSIGNEDROLE` (tanks, healers, damage) or `CLASS` (`CLASS_SORT_ORDER`), and `unitsPerColumn` columns. The other seven headers are driven to `hide`.
- Buttons come from `SecureUnitButtonTemplate`. The header's `initialConfigFunction` sizes each button from the header's `kstyle-width` and `kstyle-height` attributes and sets `*type1` to `target` and `*type2` to `togglemenu`, so new buttons are right even when the header makes them in combat.
- Every button a header can need is made when the settings apply, out of combat: the header is hidden, every `show*` attribute is turned off, `startingIndex` is set to `1 - count` and the header is shown once. Raid and party changes in combat then only reassign units.
- A hook on the header's `OnAttributeChanged` sees each new `child<n>` and dresses it. The hook on the button's `OnAttributeChanged` follows the `unit` attribute and only touches the plain content frame, so a unit change in combat makes no protected call.
- Attribute, size and anchor changes wait for `KstyleUI.Combat.Queue` in combat.

## Settings

| Key | Default | What it does |
| --- | --- | --- |
| `blizzard.party`, `blizzard.raid`, `blizzard.manager` | on | Hide Blizzard's party frames, compact raid frames and raid manager. In the gamepad interface all three stay Blizzard's |
| `party.width`, `party.height`, `party.spacing` | 230, 46, 10 | Frame size and gap |
| `party.growth` | `DOWN` | Which way the next frame goes |
| `party.sortBy` | `INDEX` | Group order, name or role |
| `party.showPlayer`, `party.showSolo` | on, off | Include yourself; show when solo |
| `party.portrait` | on | The class-ringed portrait with the level disc: a `buttonFill` disc with a ring in the accent one border outside it, the edge line the unit frames' badge wears |
| `raid.width`, `raid.height`, `raid.spacing` | 72, 40, 3 | Frame size and gap |
| `raid.growth`, `raid.groupGrowth`, `raid.groupSpacing` | `DOWN`, `RIGHT`, 3 | Member growth, group or column growth and the gap between groups |
| `raid.sortBy` | `GROUP` | Group, role or class |
| `raid.groupsPerRow` | 8 | Groups side by side before a new row (group sort) |
| `raid.unitsPerColumn` | 5 | Frames per column (role and class sort) |
| `<kind>.power`, `<kind>.powerHeight` | party on, 4; raid off, 3 | The power bar |
| `<kind>.textLayout` | party `ABOVE`, raid `INSIDE` | Name above the bar or on it |
| `<kind>.nameSize` | 11, 10 | Name size |
| `<kind>.healthText`, `<kind>.healthTextSize` | party `PERCENT` 11, raid `NONE` 9 | None, percent, current, missing, current and maximum, current and percent |
| `<kind>.iconSize` | 14, 12 | Role, leader, marker and ready-check icon size |
| `icons.role`, `icons.leader`, `icons.marker`, `icons.readyCheck` | on | Each status icon |
| `threat.enabled` | on | The threat glow |
| `<kind>.auraSize`, `<kind>.auraCount` | party 20, 3; raid 14, 3 | Debuff icon size and the most icons shown |
| `<kind>.auraDispelCount` | 1 | Dispellable debuffs shown first, before the others; 0 shows none |
| `<kind>.auraColumns`, `<kind>.auraRows`, `<kind>.auraSpacing` | 3, 1; party 2, raid 1 | Icons per row, rows and the gap; the count stops at columns times rows |
| `<kind>.auraPosition`, `<kind>.auraGrowth`, `<kind>.auraWrap` | party outside right, right, down; raid inside bottom left, right, up | Where the icons sit and which way they fill |
| `auras.enabled`, `auras.filter` | on, `ALL` | All classified debuffs, the ones Blizzard's raid frames show (`HARMFUL\|RAID_IN_COMBAT`), or only the ones you can dispel (`displayOnlyDispellableDebuffs`) |
| `auras.swipe` | on | The duration swipe on each icon |
| `auras.dispelHighlight`, `auras.dispelFilter` | on, `PLAYER` | The dispel highlight for debuffs you can dispel (`HARMFUL\|RAID`) or anyone in the group can (`HARMFUL\|RAID_PLAYER_DISPELLABLE`) |
| `prediction.heals`, `prediction.healColor` | on, friendly at 50% | Incoming heals |
| `prediction.absorbs`, `prediction.absorbColor` | on, white at 45% | Absorb shields |
| `health.texture` | Glass | Bar texture for health and power |
| `health.colorSource`, `health.color` | `class`, friendly | Class, reaction or a custom colour |
| `health.orientation` | `HORIZONTAL` | Fill left to right, or bottom up |
| `power.colorSource`, `power.color` | `power`, rare | Power type, class or a custom colour |
| `text.nameFont`, `text.nameOutline` | Source Sans 3 Semibold, soft shadow | Name font and outline |
| `text.nameColorSource`, `text.nameColor` | `text` | Text colour, class or a custom colour |
| `text.healthFont`, `text.healthOutline` | Source Sans 3 Semibold, soft shadow | Health text font and outline |
| `range.fade`, `range.alpha` | on, 0.4 | Fade members out of range |
| `accent.source`, `accent.color` | `class` | The target ring and hover hairline: the KstyleUI accent or a custom colour. The hairline eases toward it over the kit's hover time (0.15 s `outQuart`), as every kit control does. |

## Extension points

Feature files add to the frame without editing it: `Button.built` (build parts on a new frame), `Style.appliers` (lay them out after `Style.Apply`), `Style.painters` (paint them on preview samples), `Unit.extra` (refresh them with the unit), `Unit.Chain(event, fn)` (handle another unit event, registering it when new) and `Frames.events` (global events while the module runs).

## Why

- **Secure headers, not our own roster code.** `SecureGroupHeaderTemplate` places units in secure code, so the roster can change in combat and clicks still target the right member. Everything KstyleUI draws sits on a plain content frame inside each secure button, so drawing never needs a protected call.
- **Buttons made out of combat.** A header makes a button the first time it needs one. If that happened in combat, our dressing code would run in combat. Making every button at apply time, with `startingIndex` and the `show*` attributes off, keeps all frame creation out of combat.
- **Eight raid headers.** One header with `groupBy = GROUP` fills columns of five in turn, so a group with three members pulls the next group's members into its column. One header per group keeps each group in its own column, as the raid footprint plans. Role and class order reuse the first header, because those orders are meant to flow.
- **Holders that scale.** The headers size themselves from the frame size, the spacing and the roster. A holder sized to the largest group gives Layout a stable footprint to anchor, while the settings own the frame size.
- **Secrets go straight to the engine.** Health, maximum health, power and range are secret on Forever. They reach `SetValue`, `SetMinMaxValues`, `SetFormattedText` and `SetAlphaFromBoolean` untouched. Percent text uses `UnitHealthPercent` with a 0 to 100 curve (`CurveConstants.ScaleTo100`, or our own curve), and the missing-health text hides at full health through a step curve on its alpha. Nothing compares or adds a health value.
- **Class colour with secret pass-through.** When a unit's class is secret, `Theme.ClassColorForWidget` passes the secret colour from `C_ClassColor.GetClassColor` straight to `SetStatusBarColor`. A plain class gives `Theme.ClassColor`.
- **The player never fades.** `UnitInRange` reports the player as not checked, so the player's own frame keeps full opacity. Offline members keep full opacity too; their grey bar already says why they cannot be healed.
- **The gamepad interface gets Blizzard's group frames back.** Forever's gamepad group targeting (`Blizzard_GamepadTargeting`, `RaidTargetDPAD.lua`) runs `SmartNavigation` over `CompactRaidFrameContainer` in a raid and `CompactPartyFrame`, a child of `PartyFrame`, in a party. While `InputUtil.IsGamepadUIEnabled()` is true (or, without `InputUtil`, `C_InputInterfaceStyle.GetCurrentStyle()` is the gamepad style), the module gives all three Blizzard frames back through `Safe.RestoreBlizzard`, hides its headers and holders, stops its unit events and binds its debuff containers to `none`. `INPUT_DEVICE_INTERFACE_TRANSITION` switches between the two states. In combat the header changes wait for `KstyleUI.Combat.Queue` and only the last switch applies; until they run, KstyleUI's frames are still the ones on screen, so they keep following their units. Settings changes made while standing down apply when keyboard and mouse return. A secret or missing answer counts as keyboard and mouse.
- **Blizzard frames through Safe.** `PartyFrame` holds Blizzard's party frames and `CompactPartyFrame`; `CompactRaidFrameContainer` and `CompactRaidFrameManager` hold the raid frames and the manager tab. Each is reparented through `Safe.HideBlizzard`, which waits for combat and Edit Mode to end, and comes back through `Safe.RestoreBlizzard` when the module or the setting is switched off. `Blizzard_CompactRaidFrames` can load after login, so `ADDON_LOADED` applies the setting again.
- **Role icons through Blizzard's secure delegate.** `UnitFrameUtil.UpdateUnitFrameRoleIcon` reads the role and wraps it in a secret when the unit's identity is restricted, then sets the texture and visibility itself. Without it, the role from `UnitGroupRolesAssigned` is used when it is plain.
- **Leader and markers without a test on a secret.** The leader flag goes to `SetAlphaFromBoolean`. `GetRaidTargetIndex` is always secret, so the marker hides only when `type(index)` is not `"number"`; `type` sees through a secret, and a secret index goes straight to `SetSpriteSheetCell`.
- **Heals and absorbs anchored to the fill.** Each prediction bar spans the health maximum and is anchored to the end of the fill before it, so the engine places it; Lua never adds health and heals. The calculator clamps heals and absorbs to missing health, and a clip frame over the health bar cuts anything that would still spill out. One calculator is made per frame and reused.
- **Threat is readable on Forever**, but a secret status or colour hides the glow rather than guessing. The glow is the kit's selection glow (`Widgets.Glow`, the shadow falloff) one level behind the frame's tile, so it rings the chamfered silhouette instead of a square box; party frames get an 8-unit glow and raid frames, 3 units apart, a 4-unit one.
- **Debuffs on the AuraContainer engine.** Aura data is secret during a boss pull, and index scans error under restriction. Each frame gets one `CustomAuraContainerTemplate` container bound to its unit with `SetUnit`. The container runs Blizzard's raid frame classification (`SetAuraProcessingPolicy(ProcessAura)`, buffs ignored), and two aura groups take its results through `candidateFilters.processedAuraType`: `dispels` (debuffs your raid can dispel) first, then `debuffs` (boss, priority and other debuffs). Both sort by `AuraContainerSortMethod.UnitFrameDebuff`, which reads the `debuffType` that only the classification fills, so each group holds only classified auras. A `dispel` aura slot draws the highlight. The engine finds, sorts and draws the auras; Lua only sets filters, counts and layout. A client without the processing policy gets one group in the default order.
- **The dispel highlight is the slot's own frame.** The slot's frame covers the group frame, with a faint wash (a `chamferTile` nine-slice at 16%) and the tile's double bevel edge, each piece registered through `AddDispelTypeTexture` in the `PreserveAsset` style, so the engine shows them and tints them in the debuff type's colour only while a matching debuff is on the unit. Lua never learns the debuff type. Every piece follows the 3-unit chamfer, so nothing paints the corners the tile cuts away.
- **Rings are drawn the way the kit draws its edges.** `Style.Ring` builds the tile's double bevel edge as `Widgets.Chrome` does: the corner pieces of `bevelTileOuter` and `bevelTileInner`, which carry the 3-unit chamfer and are sized in borders as the chrome sizes its own so the line in the art is one border wide, and straight sides one `Widgets.Border` thick between them, the inner line one border in. The sides are whole physical pixels on every screen and no piece reaches the corners the tile cuts away. Core keeps its bevel builder private, so the module has its own copy with a draw layer it can choose and pieces it can hand to the aura engine.
- **The target ring follows the chamfer.** The target highlight is that double bevel edge in the accent, on a frame whose alpha follows the secret `UnitIsUnit(unit, "target")` through `SetAlphaFromBoolean`. It traces the tile's own double bevel edge, two lines thick like the old outline.
- **Debuff icons are the kit's icon tiles.** Each engine button gets a `Widgets.Chrome` tile, the icon two borders in and masked by `iconMask`, and a cooldown swipe drawn with `iconMask`, as `KstyleUI_Auras` dresses its buttons. The debuff type colour fills a `chamferTile` nine-slice behind the icon, so it shows as a chamfered border. Icon size and spacing are snapped to whole pixels with `Widgets.Snap` before they reach the engine's layout, and buttons are sized with `Widgets.Size`. The chrome's `Restyle` is wrapped by the same secrecy gate as the rest of the icon, so `Widgets.RestyleAll` never reaches a restricted aura button.
- **Containers are made out of combat, when a frame first gets a unit.** Raid buttons are many and most stay empty, so a container per button would cost ten aura buttons each for nothing. A frame that first gets a unit in combat makes its container when combat ends.
- **Aura buttons are touched only while auras are readable.** The engine denies tainted access to its aura buttons while auras are secret, so icon size and font changes wait until `C_Secrets.ShouldAurasBeSecret()` is false. Container settings (filter, count, layout) go through the container's own methods and apply at once.
- **Clicks pass through debuff icons.** `SetMouseClickEnabled(false)` keeps the debuff tooltip on hover while a click on an icon still targets the member.
