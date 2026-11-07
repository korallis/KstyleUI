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
| `Style.lua` | `ns.Style`: builds a frame's look on any frame (glass tile, portrait, health and power bars, texts, target outline) and lays it out from the settings |
| `Unit.lua` | `ns.Unit`: reads a unit into a frame on unit events: name, health, health text, power, colours, dead and offline states, portrait, level, range and target |
| `Button.lua` | `ns.Button`: dresses each secure button a header makes with a plain content frame, hooks that follow its `unit` attribute, hover and the unit tooltip |
| `Headers.lua` | `ns.Headers`: the party header and eight raid headers, their attributes, buttons made out of combat, and visibility drivers |
| `Blizzard.lua` | `ns.Blizzard`: hides and restores Blizzard's party frames, compact raid frames and raid manager through `KstyleUI.Safe` |
| `Frames.lua` | `ns.Frames`: `Enable` and `Disable`, settings applied out of combat, Layout registration, group events and the `/kstyle test` check |
| `Preview.lua` | `ns.Preview`: the settings window's live preview with sample party and raid frames |
| `Module.lua` | `KstyleUI.Modules.Register` and `KstyleUI.Options.Register` |

Tests: `Tools/regression/test-groupframes-geometry.lua` (the maths), `test-groupframes-settings.lua` (registration, schema and damaged values), `test-groupframes-frames.lua` (headers, units, colours, range, sorting, combat safety, Blizzard frames, Disable) and `test-groupframes-preview.lua`. They load the module through `Tools/regression/group_env.lua`, which adds a roster, secure group headers that place units as Blizzard's `SecureGroupHeaders.lua` does, and a combat guard that raises on any protected call outside secure code.

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
| `blizzard.party`, `blizzard.raid`, `blizzard.manager` | on | Hide Blizzard's party frames, compact raid frames and raid manager |
| `party.width`, `party.height`, `party.spacing` | 230, 46, 10 | Frame size and gap |
| `party.growth` | `DOWN` | Which way the next frame goes |
| `party.sortBy` | `INDEX` | Group order, name or role |
| `party.showPlayer`, `party.showSolo` | on, off | Include yourself; show when solo |
| `party.portrait` | on | The class-ringed portrait with the level badge |
| `raid.width`, `raid.height`, `raid.spacing` | 72, 40, 3 | Frame size and gap |
| `raid.growth`, `raid.groupGrowth`, `raid.groupSpacing` | `DOWN`, `RIGHT`, 3 | Member growth, group or column growth and the gap between groups |
| `raid.sortBy` | `GROUP` | Group, role or class |
| `raid.groupsPerRow` | 8 | Groups side by side before a new row (group sort) |
| `raid.unitsPerColumn` | 5 | Frames per column (role and class sort) |
| `<kind>.power`, `<kind>.powerHeight` | party on, 4; raid off, 3 | The power bar |
| `<kind>.textLayout` | party `ABOVE`, raid `INSIDE` | Name above the bar or on it |
| `<kind>.nameSize` | 11, 10 | Name size |
| `<kind>.healthText`, `<kind>.healthTextSize` | party `PERCENT` 11, raid `NONE` 9 | None, percent, current, missing, current and maximum, current and percent |
| `health.texture` | Glass | Bar texture for health and power |
| `health.colorSource`, `health.color` | `class`, friendly | Class, reaction or a custom colour |
| `health.orientation` | `HORIZONTAL` | Fill left to right, or bottom up |
| `power.colorSource`, `power.color` | `power`, rare | Power type, class or a custom colour |
| `text.nameFont`, `text.nameOutline` | Source Sans 3 Semibold, soft shadow | Name font and outline |
| `text.nameColorSource`, `text.nameColor` | `text` | Text colour, class or a custom colour |
| `text.healthFont`, `text.healthOutline` | Source Sans 3 Semibold, soft shadow | Health text font and outline |
| `range.fade`, `range.alpha` | on, 0.4 | Fade members out of range |
| `accent.source`, `accent.color` | `class` | The target outline and hover hairline: the KstyleUI accent or a custom colour |

## Why

- **Secure headers, not our own roster code.** `SecureGroupHeaderTemplate` places units in secure code, so the roster can change in combat and clicks still target the right member. Everything KstyleUI draws sits on a plain content frame inside each secure button, so drawing never needs a protected call.
- **Buttons made out of combat.** A header makes a button the first time it needs one. If that happened in combat, our dressing code would run in combat. Making every button at apply time, with `startingIndex` and the `show*` attributes off, keeps all frame creation out of combat.
- **Eight raid headers.** One header with `groupBy = GROUP` fills columns of five in turn, so a group with three members pulls the next group's members into its column. One header per group keeps each group in its own column, as the raid footprint plans. Role and class order reuse the first header, because those orders are meant to flow.
- **Holders that scale.** The headers size themselves from the frame size, the spacing and the roster. A holder sized to the largest group gives Layout a stable footprint to anchor, while the settings own the frame size.
- **Secrets go straight to the engine.** Health, maximum health, power and range are secret on Forever. They reach `SetValue`, `SetMinMaxValues`, `SetFormattedText` and `SetAlphaFromBoolean` untouched. Percent text uses `UnitHealthPercent` with a 0 to 100 curve (`CurveConstants.ScaleTo100`, or our own curve), and the missing-health text hides at full health through a step curve on its alpha. Nothing compares or adds a health value.
- **Class colour with secret pass-through.** When a unit's class is secret, `C_ClassColor.GetClassColor` still returns its colour as secrets, and those go straight to `SetStatusBarColor`. A plain class goes through `Theme.ClassColor`.
- **The player never fades.** `UnitInRange` reports the player as not checked, so the player's own frame keeps full opacity. Offline members keep full opacity too; their grey bar already says why they cannot be healed.
- **Blizzard frames through Safe.** `PartyFrame` holds Blizzard's party frames and `CompactPartyFrame`; `CompactRaidFrameContainer` and `CompactRaidFrameManager` hold the raid frames and the manager tab. Each is reparented through `Safe.HideBlizzard`, which waits for combat and Edit Mode to end, and comes back through `Safe.RestoreBlizzard` when the module or the setting is switched off. `Blizzard_CompactRaidFrames` can load after login, so `ADDON_LOADED` applies the setting again.
