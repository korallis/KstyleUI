# KstyleUI_Nameplates

A KstyleUI plate on each nameplate: health, name, level, threat colour, target and focus highlights, raid, elite and rare markers, in a friendly and an enemy style.

| Field | Value |
| --- | --- |
| Module name | `Nameplates`: its switch in `Core/Features.lua` and the `name` it registers with `KstyleUI.Modules.Register` |
| Approach | Replace the visible plate |
| Loads | With the core addon, switched off until the player turns it on |
| Files | `KstyleUI_Nameplates.toc` lists `Nameplates.xml`, which loads every Lua file in order, so adding a file never edits the TOC |
| Tests | `Tools/regression/test-nameplates.lua` and `test-nameplates-settings.lua`, through `Tools/regression/nameplates_env.lua` |

## Rules

These come from the [design spec](../docs/superpowers/specs/2026-11-07-kstyleui-design.md). The roadmap's Global Constraints and [AGENTS.md](../AGENTS.md) apply too.

- Attach a KstyleUI frame to each plate on `NAME_PLATE_UNIT_ADDED` and fade Blizzard's plate with alpha. Names of non-player units can be secret in combat, so they pass through whole.
- Cast bars use `StatusBar:SetTimerDuration` with the duration object from the cast APIs. Casts by units other than the player and pet can be secret, so the bar never reads the spell name except through widget setters.
- Auras use the AuraContainer engine (`CustomAuraContainerTemplate`, aura groups and filter strings). Never scan auras by index while `C_Secrets.ShouldAurasBeSecret()` returns true. Aura data turns secret during a boss pull before `InCombatLockdown()` returns true.
- At load the module only registers itself with `KstyleUI.Modules.Register`. It creates no frames, registers no events and installs no hooks until `Enable` runs. `test-modules-load.lua` checks the frames.
- Every element it shows registers with `KstyleUI.Layout.Register`, and every setting is declared through `KstyleUI.Options.Register`, so the player can resize and customise everything from the settings window.
- UI comes from `KstyleUI.Widgets`, colours from `KstyleUI.Tokens` and strings from `KstyleUI.L`. Translations go in `Locale.lua` in this folder, loaded by `Nameplates.xml`.
- Build mode: check that an API exists before calling it, check `issecretvalue` before any comparison, fall back to a safer path when the preferred one is unavailable, and log the path taken with `KstyleUI.DevTest.Log`.

## Files

`Nameplates.xml` loads them in this order:

| File | What it holds |
| --- | --- |
| `Init.lua` | The addon table the files share |
| `Logic.lua` | `ns.Logic`: pure rules. Threat states, the colour a bar uses, classification markers, level text, the plate's scale and the CVar plan. |
| `Settings.lua` | `ns.Settings`: the defaults, the settings page, and `Get(key)`, a checked and cached read of one setting |
| `Plate.lua` | `ns.NewPlate(parent, sample)`: one plate, and `ns.Components`, the parts later files add to every plate |
| `Plates.lua` | `ns.Plates`: attach and detach, the Blizzard fade, events, target and focus tracking |
| `CVars.lua` | `ns.CVars`: the nameplate CVars |
| `Preview.lua` | `ns.Preview`: the settings window's live preview and the Layout Mode sample |
| `Module.lua` | `Modules.Register`, `Options.Register`, `Enable` and `Disable` |

## How a plate attaches

1. `Enable` registers the events and attaches a plate to every nameplate already shown (`nameplate1` to `nameplate40`).
2. `NAME_PLATE_UNIT_ADDED` gets the base frame with `C_NamePlate.GetNamePlateForUnit(unit)`. The player's own plate (the base `GetNamePlateForUnit("player")` returns) and plates that show only widgets (`UnitNameplateShowsWidgetsOnly`) stay Blizzard's. Forbidden plates, such as friendly plates in instances, never fire this event and stay Blizzard's too.
3. Each base frame gets one KstyleUI plate, made the first time and kept: a child of the base, anchored to its bottom. Base frames are reused, so the number of plates stays small.
4. Blizzard's `UnitFrame` on the base gets alpha 0, and so does its `selectionHighlight`, which ignores its parent's alpha. A `hooksecurefunc` on the UnitFrame's `SetAlpha` puts 0 back when Blizzard's code sets the alpha. If the UnitFrame is not there yet, because KstyleUI's handler ran before Blizzard's driver, the fade waits one frame.
5. `NAME_PLATE_UNIT_REMOVED` hides the plate and gives the UnitFrame its alpha back, because Blizzard's pool may hand it to a plate KstyleUI leaves alone.
6. `Disable` detaches every plate and restores every alpha it changed. The `SetAlpha` hook stays, as hooks do, and does nothing while the module is off.

Nothing on Blizzard's frames is reparented, moved, resized, hidden or scripted.

## What a plate shows

| Part | Source | Notes |
| --- | --- | --- |
| Health bar | `UnitHealthMax`, `UnitHealth` | Both go straight to `SetMinMaxValues` and `SetValue`; the engine eases the bar. A new unit on a reused plate snaps to its value. |
| Health text | `UnitHealthPercent(unit, true, CurveConstants.ScaleTo100)`, `AbbreviateNumbers(UnitHealth(unit))` | `SetFormattedText` takes the secrets. Without the curve the module builds its own, and without the curve API it shows the value. |
| Name | `UnitName` | Upper case when readable. A secret name reaches `SetText` whole. Players' names can take their class colour. |
| Level badge | `UnitEffectiveLevel`, else `UnitLevel` | A chamfered tile left of the bar. `-1` reads `??` in the hostile colour; enemies' levels take `GetQuestDifficultyColor`. |
| Elite and rare marker | `UnitClassification` | A diamond (the chamfered icon mask turned 45 degrees) above the bar's right end: gold (`neutral`) for elites, red (`hostile`) for world bosses, blue (`rare`) for rares and rare elites. |
| Raid marker | `GetRaidTargetIndex` | Always secret on Forever. `type(index)` tells nil from a number without reading it, and the index goes to `SetSpriteSheetCell` on Blizzard's raid icon sheet. |
| Threat | `UnitThreatSituation("player", unit)` | Readable on Forever. A secret status counts as none. See below. |
| Target and focus | `C_NamePlate.GetNamePlateForUnit("target")` and `("focus")` | Compared with the plate's base frame, which is never secret. When that call is refused or returns nothing while the unit exists, `UnitIsUnit` decides, and a secret answer counts as no. |

### Styles

A unit the player can attack (`UnitCanAttack`) uses the enemy style, any other the friendly style. Each style has its own bar colour source: the class colour for players and the reaction colour for NPCs, the reaction colour for everyone, or a custom colour. A tapped enemy is grey (`textDisabled`). Friendly plates can show just the name.

### Threat

| Status | Tank | Anyone else |
| --- | --- | --- |
| Not on the threat list | none | none |
| 0: lower threat than the tank | danger | none |
| 1: higher threat, not tanking | warning | warning |
| 2: tanking, someone else higher | warning | danger |
| 3: tanking securely | safe | danger |

The role comes from the setting: from the group role (`UnitGroupRolesAssigned("player") == "TANK"`), or fixed to tank or not. By default threat shows only in a party or raid (`IsInGroup`). It shows as a glow around the bar, as the bar's colour, or not at all.

### Highlights

The target's plate gets a glow and an edge in the accent, or a custom colour. The focus's plate gets an edge in the focus colour. While the player has a target, other plates can fade to a set opacity.

## Size and placement

The plate's width and height belong to the Layout element `nameplates.plate`, a sample plate on `KstyleUI_Root`. It shows only in Layout Mode, where its handles resize every plate. Its **Width** and **Height** rows on the module's page in the settings window do the same. The element is not in the setup layouts: plates sit on Blizzard's plates, so the sample's position means nothing outside Layout Mode. **Height above the unit** moves every plate up or down.

Sizes are in KstyleUI root units. Each plate is scaled by `KstyleUI_Root`'s effective scale over the effective scale of its base frame's parent, so a plate is as large as the same element on the HUD, times the game's own per-plate scale (the target's larger plate, distant plates shrinking).

## Settings

Every setting is on the module's page. Text sizes run from 6 to 20 units; outlines are none (a soft shadow), thin or thick.

| Key | Default | Row |
| --- | --- | --- |
| `offsetY` | 0 | slider, -40 to 40 |
| `font` | Source Sans 3 Semibold | font |
| `health.texture`, `health.orientation`, `health.reverse` | Glass, horizontal, off | texture, dropdown, toggle |
| `enemy.colorSource`, `enemy.color` | class, `hostile` | dropdown, colour |
| `friendly.colorSource`, `friendly.color`, `friendly.nameOnly` | class, `friendly`, off | dropdown, colour, toggle |
| `name.show`, `name.size`, `name.outline`, `name.upper`, `name.classColor` | on, 10, thin, on, on | toggle, slider, dropdown, toggle, toggle |
| `level.show`, `level.size`, `level.outline` | on, 9, thin | toggle, slider, dropdown |
| `healthText.show`, `healthText.size`, `healthText.outline`, `healthText.format` | on, 9, thin, percent | toggle, slider, dropdown, dropdown |
| `threat.display`, `threat.role`, `threat.groupOnly` | glow, auto, on | dropdown, dropdown, toggle |
| `threat.safe`, `threat.warning`, `threat.danger` | `friendly`, `neutral`, `hostile` | colour |
| `target.highlight`, `target.colorSource`, `target.color`, `target.dimOthers` | on, accent, `accentDefault`, 1 | toggle, dropdown, colour, slider 0.2 to 1 |
| `focus.highlight`, `focus.color` | on, `rare` | toggle, colour |
| `markers.classification`, `markers.raid`, `markers.raidSize` | on, on, 16 | toggle, toggle, slider 8 to 32 |
| `cvars.*` | see below | |

`Settings.Get(key)` checks the saved value against its row: an unknown choice, a colour channel outside 0 to 1 or a value of the wrong type reads as the default with one devlog line, and a slider value out of range clamps. Reads are cached until a setting or the profile changes.

## Nameplate CVars

Off by default. With **Manage these settings** on, the module writes these CVars through `Combat.Queue`, so a change in combat waits for `PLAYER_REGEN_ENABLED`:

| Setting | Default | CVar |
| --- | --- | --- |
| `cvars.maxDistance` | 40 | `nameplateMaxDistance` |
| `cvars.verticalDistance` | 0 | `nameplateMaxVerticalDistance` (Forever only; 0 turns the check off) |
| `cvars.stacking` | enemy | `nameplateStackingTypes` bits 1 (enemy) and 2 (friendly), or `nameplateMotion` on a client without the bitfield |
| `cvars.selectedScale` | 1.2 | `nameplateSelectedScale` |
| `cvars.minScale` | 0.8 | `nameplateMinScale` |
| `cvars.clickSize` | 2 | `nameplateSize` |

A CVar the client does not have is skipped and logged once. Turning management off, or turning the module off, sets every CVar the module changed this session back to `C_CVar.GetCVarDefault`.

## Smoke check

`/kstyle test` adds a **Nameplates** line: off, or the number of plates attached.

## Why

- **Children of the base, not of the root.** A plate parented to Blizzard's base frame moves, scales, fades and hides with it, as the engine places and culls nameplates. A frame on `KstyleUI_Root` anchored to the base would show after the base hides and would miss the engine's occlusion and distance fades.
- **Fade, never hide or reparent.** Blizzard lays the UnitFrame out and owns it; hiding or reparenting it taints the nameplate driver. Alpha is not protected, and a post hook on `SetAlpha` is the one change to Blizzard's table, as the core's Skin helpers allow.
- **Base frames compared by identity.** `UnitIsUnit` can return a secret while unit comparison is restricted. A frame reference is never secret, so the target and focus come from `GetNamePlateForUnit` and an identity test.
- **One plate per base.** Base frames are pooled by the engine and reused for new units, so a plate is built once per base and refreshed on each attach. Nothing is built in a combat path after the first sighting of a base.
- **A sample plate for Layout.** Plates have no screen position of their own, but the spec wants every element resized in Layout Mode. The sample gives the player handles to drag; its size is the plates' size.
- **Threat only in a group.** Alone, every mob that attacks the player is on them, and a red glow on each says nothing new.
- **CVars back to the defaults.** The module does not store the player's own CVar values. Returning to the game's defaults is predictable and needs no saved state.
