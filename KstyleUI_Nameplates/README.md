# KstyleUI_Nameplates

A KstyleUI plate on each nameplate: health, name, level, cast bar, the player's debuffs, threat colour, target and focus highlights, raid, elite and rare markers, in a friendly and an enemy style.

| Field | Value |
| --- | --- |
| Module name | `Nameplates`: its switch in `Core/Features.lua` and the `name` it registers with `KstyleUI.Modules.Register` |
| Approach | Replace the visible plate |
| Loads | With the core addon, switched off until the player turns it on |
| Files | `KstyleUI_Nameplates.toc` lists `Nameplates.xml`, which loads every Lua file in order, so adding a file never edits the TOC |
| Tests | `Tools/regression/test-nameplates.lua`, `test-nameplates-settings.lua`, `test-nameplates-cast.lua` and `test-nameplates-auras.lua`, through `Tools/regression/nameplates_env.lua`, which uses the fake AuraContainer engine in `auras_env.lua` |

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
| `Cast.lua` | `ns.Cast`: the cast bar component |
| `Auras.lua` | `ns.Auras`: the debuff component |
| `Plates.lua` | `ns.Plates`: attach and detach, the Blizzard fade, events, target and focus tracking |
| `CVars.lua` | `ns.CVars`: the nameplate CVars |
| `Preview.lua` | `ns.Preview`: the settings window's live preview and the Layout Mode sample |
| `Module.lua` | `Modules.Register`, `Options.Register`, `Enable` and `Disable` |

## How a plate attaches

1. `Enable` registers the events and attaches a plate to every nameplate already shown (`nameplate1` to `nameplate40`).
2. `NAME_PLATE_UNIT_ADDED` gets the base frame with `C_NamePlate.GetNamePlateForUnit(unit)`. The player's own plate (the base `GetNamePlateForUnit("player")` returns) and plates that show only widgets (`UnitNameplateShowsWidgetsOnly`) stay Blizzard's. Forbidden plates, such as friendly plates in instances, never fire this event and stay Blizzard's too.
3. Each base frame gets one KstyleUI plate, made the first time and kept: a child of the base, anchored to its bottom. Base frames are reused, so the number of plates stays small.
4. Blizzard's `UnitFrame` on the base gets alpha 0, and so does its `selectionHighlight`, which ignores its parent's alpha. Its `SoftTargetFrame` gets `SetIgnoreParentAlpha(true)` instead, so the soft-target icon Blizzard draws there stays visible: the gamepad interact prompt (`SoftTargetIconInteract`, which gamepad mode turns on) and the enemy and friend icons the accessibility settings turn on. Blizzard still decides when the icon shows. A `hooksecurefunc` on the UnitFrame's `SetAlpha` puts 0 back when Blizzard's code sets the alpha. If the UnitFrame is not there yet, because KstyleUI's handler ran before Blizzard's driver, the fade waits one frame.
5. `NAME_PLATE_UNIT_REMOVED` hides the plate, gives the UnitFrame its alpha back and the `SoftTargetFrame` its own parent-alpha setting, because Blizzard's pool may hand it to a plate KstyleUI leaves alone.
6. `Disable` detaches every plate and restores every alpha it changed. The `SetAlpha` hook stays, as hooks do, and does nothing while the module is off.

Nothing on Blizzard's frames is reparented, moved, resized, hidden or scripted.

## What a plate shows

| Part | Source | Notes |
| --- | --- | --- |
| Health bar | `UnitHealthMax`, `UnitHealth` | Both go straight to `SetMinMaxValues` and `SetValue`; the engine eases the bar. A new unit on a reused plate snaps to its value. |
| Health text | `UnitHealthPercent(unit, true, CurveConstants.ScaleTo100)`, `AbbreviateNumbers(UnitHealth(unit))` | `SetFormattedText` takes the secrets. Without the curve the module builds its own, and without the curve API it shows the value. |
| Name | `UnitName` | In its own case when readable, as the mockup's "Riverglade Crocolisk"; the upper-case setting capitalises it. A secret name reaches `SetText` whole. Players' names can take their class colour. |
| Level badge | `UnitEffectiveLevel`, else `UnitLevel` | A 34-unit octagon (a 10.5-unit chamfer) rimmed in the bar's colour, overlapping the bar's left end by one unit and drawn over it. The level reads white; `-1` reads `??` in the hostile colour. |
| Elite and rare marker | `UnitClassification` | A diamond (the chamfered icon mask turned 45 degrees) above the bar's right end: gold (`neutral`) for elites, red (`hostile`) for world bosses, blue (`rare`) for rares and rare elites. |
| Raid marker | `GetRaidTargetIndex` | Always secret on Forever. `type(index)` tells nil from a number without reading it, and the index goes to `SetSpriteSheetCell` on Blizzard's raid icon sheet. |
| Threat | `UnitThreatSituation("player", unit)` | Readable on Forever. A secret status counts as none. See below. |
| Target and focus | `C_NamePlate.GetNamePlateForUnit("target")` and `("focus")` | Compared with the plate's base frame, which is never secret. When that call is refused or returns nothing while the unit exists, `UnitIsUnit` decides, and a secret answer counts as no. |

### Cast bar

The cast bar is a component: it adds itself to `ns.Components` with `Build`, `Restyle`, `Refresh`, `Clear`, `Room` (the height it reserves under the health bar) and the unit events it handles. It sits under the health bar: the spell icon (masked to the chamfer), then the bar with the spell's name and the time left.

| Moment | What happens |
| --- | --- |
| `UNIT_SPELLCAST_START`, `UNIT_SPELLCAST_CHANNEL_START`, or a plate attaching to a unit that is casting | `UnitCastingInfo` or `UnitChannelInfo` gives the name, icon and `notInterruptible`; `type(name)` tells whether there is a cast without reading a secret. The bar runs from `UnitCastingDuration` or `UnitChannelDuration` through `SetTimerDuration`: casts fill (`ElapsedTime`), channels drain (`RemainingTime`). The name and icon reach `SetText` and `SetTexture` whole. A sheen crosses the bar once. |
| Time left | An `OnUpdate` on the bar, only while it casts, writes `duration:GetRemainingDuration()` through `SetFormattedText` every 0.1 s. |
| `UNIT_SPELLCAST_DELAYED`, `UNIT_SPELLCAST_CHANNEL_UPDATE` | The bar runs again from a fresh duration. |
| Interruptible or not | A plain flag picks the cast colour (the accent or a custom colour) or the uninterruptible colour, and dims the icon. A secret flag goes to `SetVertexColorFromBoolean` on the bar's texture and `SetAlphaFromBoolean` on the icon's shade, so the engine decides. `UNIT_SPELLCAST_INTERRUPTIBLE` and `UNIT_SPELLCAST_NOT_INTERRUPTIBLE` give a plain flag. |
| `UNIT_SPELLCAST_STOP`, `_FAILED`, `_CHANNEL_STOP` | The bar fades out over `fade`. |
| `UNIT_SPELLCAST_INTERRUPTED` | The bar fills, turns `hostile`, says **Interrupted** and fades out over 0.8 s. The `STOP` that follows is ignored. |
| `UNIT_FLAGS`, `UNIT_FACTION` | These fire often in combat (combat state, stuns, roots, fear), so they rerun only the style, the bar colour and threat. A plate whose kind or name-only state changed refreshes in full, and even then a cast that is already running keeps going: the bar restarts only for a new cast ID, a settings change or a new unit. |

Without the duration APIs or `SetTimerDuration`, the bar takes the cast's start and end times as its range (they may be secret; the engine compares them) and an `OnUpdate` sets the value to `GetTime() * 1000`. That path shows no time text, channels fill rather than drain, and the devlog says it ran.

### Debuffs

The debuffs are a component too. Each plate gets one `CustomAuraContainerTemplate` container, made the first time the plate shows a unit with debuffs on, and kept. It has one aura group, `debuffs`:

| Part | How |
| --- | --- |
| Which auras | The filter string `HARMFUL\|PLAYER\|INCLUDE_NAME_PLATE_ONLY`: the player's harmful auras on the unit, including the ones the game marks for nameplates only. A setting drops `INCLUDE_NAME_PLATE_ONLY`. The engine finds, sorts and updates them; Lua never reads aura data, so `C_Secrets.ShouldAurasBeSecret()` never stops it. |
| How many | `maxFrameCount` is icons per row times rows. |
| Layout | The engine's flow layout: horizontal lines `columns` icons long (`SetFlowLayoutMaximumLineSize`), growing right or left and up or down from the matching corner. The container hangs from that corner 4 units (`gapSmall`) above the name, or under the cast bar when rows grow down. |
| Unit | `SetUnit(unit)` when the plate attaches, `SetUnit("none")` when it detaches or debuffs are off. |
| Edit Mode | `SetEditModePreviewEnabled(false)`, so Blizzard's Edit Mode never fills plates with sample auras. |
| Buttons | `initializeFrame` builds each aura button before the engine restricts it: the kit's icon chrome (`Widgets.IconChrome`: the near-black button body and the accent rim, on a skin frame inside the button), the icon two border lines in and cut to `iconMask`, a cooldown swipe with the same mask, the stack count at the top right and the time left at the bottom, each text on its own holder frame so a switch can hide it. `SetIcon`, `SetDurationCooldown`, `SetApplicationCount` and `SetDurationText` hand them to the engine. |

Aura buttons deny tainted access while auras are secret. A setting that changes the buttons (size, text, switches) restyles them only when `C_Secrets.ShouldAurasBeSecret()` is false, and so does a theme change that restyles a button's tile. Otherwise the plate or the tile waits in one shared list, checked again after combat (`Combat.Queue`) or, when auras turn secret before combat starts, once a second, so a restyle never retries itself in a loop. The container's own layout changes at once. Without the engine, or when it refuses the container, plates show no debuffs and the devlog says why; a refusal in combat retries after combat.

Icon size and spacing snap to whole physical pixels (`Widgets.Snap` on the plate) before they go to the group layout, the flow line size and the buttons.

The settings window's preview draws three sample debuff tiles on the same snapped grid, because a preview has no unit for the engine. `Auras.Extent(plate)` gives how far a plate reaches above and below its health bar, debuffs included, and the preview spaces its sample plates by the tallest so no plate's debuffs run into the next. The pane clips its children, so when a large grid makes the stack taller than the pane, the preview shows only the plates that fit, at least one, and stacks again when the pane changes size.

The defaults are sized for a pull: 26-unit icons, five to a row (138 units, inside the 175-unit plate), with the time left and the stacks at 12 units, outlined. The owner judged the earlier 18-unit icons and 8-unit text too small to read in game on 2026-11-08. A plate shrunk for distance (`cvars.minScale` 0.8) still draws the icons at about 21 units. A size saved in a profile keeps its value.

### Styles

A unit the player can attack (`UnitCanAttack`) uses the enemy style, any other the friendly style. Each style has its own bar colour source: the class colour for players and the reaction colour for NPCs, the reaction colour for everyone, or a custom colour. A player whose class is secret gets the secret class colour from `Theme.ClassColorForWidget`, passed straight to the bar and the name, and the plate's colour cache is skipped for it so the secret is never compared. A tapped enemy is grey (`textDisabled`). Friendly plates can show just the name.

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

Sizes are in KstyleUI root units. The game scales each base frame itself: C code sets the base's scale to `UIParent`'s effective scale times the plate's own factor (`nameplateGlobalScale`, `nameplateMinScale` to `nameplateMaxScale` by distance, `nameplateSelectedScale` on the target), and changes it per frame with no event. The plate is a child of the base, so by default it ignores its parent's scale (`SetIgnoreParentScale(true)`) and takes `KstyleUI_Root`'s effective scale as its own: a plate is exactly as large as the same units on the HUD at any distance, and nothing has to update as the base's scale changes. With **Shrink distant plates** on, the plate inherits the base's scale again and is scaled by `KstyleUI_Root`'s effective scale over the base's parent's effective scale times `UIParent`'s, so it draws in root units times the game's per-plate factor: the target's larger plate, distant plates shrinking. On a client without `SetIgnoreParentScale`, the default divides by the base's effective scale at each restyle instead, which the devlog says and which goes stale as the unit moves. The sample plate on `KstyleUI_Root` keeps scale 1. Blizzard's base frame is never scaled, sized or reparented.

## Settings

Every setting is on the module's page. Text sizes run from 6 to 20 units; outlines are none (a soft shadow), thin or thick.

| Key | Default | Row |
| --- | --- | --- |
| `offsetY` | 0 | slider, -40 to 40 |
| `shrinkDistant` | off | toggle |
| `font` | Source Sans 3 Semibold | font |
| `health.texture`, `health.orientation`, `health.reverse` | Glass, horizontal, off | texture, dropdown, toggle |
| `enemy.colorSource`, `enemy.color` | class, `hostile` | dropdown, colour |
| `friendly.colorSource`, `friendly.color`, `friendly.nameOnly` | class, `friendly`, off | dropdown, colour, toggle |
| `name.show`, `name.size`, `name.outline`, `name.upper`, `name.classColor` | on, 14, thin, off, on | toggle, slider, dropdown, toggle, toggle |
| `level.show`, `level.size`, `level.outline` | on, 16, thin | toggle, slider, dropdown |
| `healthText.show`, `healthText.size`, `healthText.outline`, `healthText.format` | off, 9, thin, percent | toggle, slider, dropdown, dropdown |
| `cast.enabled`, `cast.height` | on, 12 | toggle, slider 6 to 24 |
| `cast.texture`, `cast.orientation`, `cast.reverse` | Glass, horizontal, off | texture, dropdown, toggle |
| `cast.colorSource`, `cast.color`, `cast.shieldColor` | accent, `accentDefault`, `textDisabled` | dropdown, colour, colour |
| `cast.showIcon`, `cast.showName`, `cast.showTime`, `cast.textSize`, `cast.outline` | on, on, on, 10, thin | toggle, toggle, toggle, slider, dropdown |
| `debuffs.enabled`, `debuffs.includePlateOnly` | on, on | toggle, toggle |
| `debuffs.size`, `debuffs.spacing`, `debuffs.columns`, `debuffs.rows` | 26, 2, 5, 1 | sliders: 10 to 40, 0 to 10, 1 to 10, 1 to 4 |
| `debuffs.growthX`, `debuffs.growthY` | right, up | dropdown, dropdown |
| `debuffs.showTime`, `debuffs.showCount`, `debuffs.textSize`, `debuffs.outline` | on, on, 12, thin | toggle, toggle, slider, dropdown |
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

A CVar the client does not have is skipped and logged once. `nameplateMaxDistance` and `nameplateMaxVerticalDistance` appear nowhere in the Forever UI source (build 70840), so their rows show only when `C_CVar.GetCVar` returns a value for them on this client; otherwise the settings page hides them rather than show a slider that does nothing. The owner's first in-game test confirms whether they exist (`/dump C_CVar.GetCVarInfo("nameplateMaxDistance")`). Turning management off, or turning the module off, sets every CVar the module changed this session back to `C_CVar.GetCVarDefault`.

## Smoke check

`/kstyle test` adds a **Nameplates** line: off, or the number of plates attached.

## Why

- **Children of the base, not of the root.** A plate parented to Blizzard's base frame moves, scales, fades and hides with it, as the engine places and culls nameplates. A frame on `KstyleUI_Root` anchored to the base would show after the base hides and would miss the engine's occlusion and distance fades.
- **Fade, never hide or reparent.** Blizzard lays the UnitFrame out and owns it; hiding or reparenting it taints the nameplate driver. Alpha is not protected, and a post hook on `SetAlpha` is the one change to Blizzard's table, as the core's Skin helpers allow.
- **Base frames compared by identity.** `UnitIsUnit` can return a secret while unit comparison is restricted. A frame reference is never secret, so the target and focus come from `GetNamePlateForUnit` and an identity test.
- **One plate per base.** Base frames are pooled by the engine and reused for new units, so a plate is built once per base and refreshed on each attach. Nothing is built in a combat path after the first sighting of a base.
- **A sample plate for Layout.** Plates have no screen position of their own, but the spec wants every element resized in Layout Mode. The sample gives the player handles to drag; its size is the plates' size.
- **The engine shows the debuffs.** Aura data turns secret during a boss pull, before combat lockdown. The AuraContainer engine reads it in secure code and fills KstyleUI's own buttons, so the plates keep their debuffs through the pull without a Lua scan.
- **The engine runs the cast bar.** Enemy casts can be secret, so Lua never reads a cast's times or flags. Duration objects and the `FromBoolean` setters let the engine fill, time and colour the bar.
- **Threat only in a group.** Alone, every mob that attacks the player is on them, and a red glow on each says nothing new.
- **CVars back to the defaults.** The module does not store the player's own CVar values. Returning to the game's defaults is predictable and needs no saved state.
