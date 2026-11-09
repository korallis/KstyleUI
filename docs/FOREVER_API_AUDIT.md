# Forever API audit, 2026-11-09

Target: **1.60.1.70862**, `Gethe/wow-ui-source` commit **9dc84f0**. The initial source checkout was 70840 (`5987a8e`); the installed client is 70862. This is source-level conformance work, not an error-free-in-game certificate. Native event timing, protected execution and opaque values require the in-game checks in the pull request.

## Build delta

A bytewise comparison of both complete source trees found no additions or removals and exactly five changed files:

| Source path | Change and relevance |
| --- | --- |
| `Blizzard_BarbershopUI/Mainline/Blizzard_BarberShopUI.lua` | Adds a downward gamepad navigation override from the SD toggle to Accept. No KstyleUI call or hook targets this function. |
| `Blizzard_BarbershopUI/Mainline/Blizzard_BarberShopUI.xml` | Sets `disallowGamepadUnfocus` on BarberShopFrame. KstyleUI does not write that field or skin this window. |
| `Blizzard_GamepadSharedUtility/FrameControlsManager.lua` | Checks whether the current top-level parent forbids unfocusing before dismissing a focused frame. Shared gamepad behavior needs a client check; no addon call site targets the changed implementation. |
| `Blizzard_GamepadSmartNavigation/SmartNavigation.lua` | Registers/unregisters `UI.AlternateTopLevelParentChanged` to reparent and raise the navigation cursor. No addon hook targets those changed methods. |
| `version.txt` | 1.60.1.70840 → 1.60.1.70862. |

Paths in this table are below `Interface/AddOns/`, except `version.txt`. All generated API documentation, Edit Mode code, and the other source files cited below are byte-identical. There are no changed documented signatures, secret flags, events, templates or CVars in this delta. This says nothing about changes inside the native executable.

## Findings and disposition

Addon locations in this table refer to the pre-fix baseline `b02d691f1`, so the original defect can be found after the fix moves lines. Source locations are below the 70862 tree's `Interface/AddOns/`.

| Addon location and name | Source evidence | In-game consequence and disposition |
| --- | --- | --- |
| `KstyleUI_ActionBars/Module.lua:307`, `SPELL_UPDATE_ICON` | `Blizzard_APIDocumentationGenerated/SpellBookDocumentation.lua:938-945`; `Blizzard_ActionBar/Shared/ActionButton.lua:1069-1070` | The payload is a spell ID, not an action slot. Interpreting it as a slot leaves icons stale. Fixed by refreshing action icons and flyout data without treating the ID as a slot. |
| `KstyleUI_ActionBars/Flyout.lua:190-198`, `GetFlyoutSlotInfo` | `Blizzard_ActionBar/Shared/SpellFlyout.lua:313,345-355` | Discarding the override spell displays the base icon while Blizzard displays the override. Fixed by retaining a separate display spell; secure casting still uses the base spell. |
| `KstyleUI_ActionBars/Button.lua:140,305-310`, `KstyleUI_Cooldowns/Mirror.lua:100`, `KstyleUI_Nameplates/Logic.lua:106-114`, `isOnGCD` | `Blizzard_APIDocumentationGenerated/SpellSharedDocumentation.lua:19-30`; `ActionBarFrameDocumentation.lua`'s ActionCooldownInfo contract | The field is only trustworthy during `SPELL_UPDATE_COOLDOWN`. General refreshes could classify a real cooldown as only GCD. Fixed by explicit event context; action buttons retain trustworthy classification for the same action, and mirror/nameplate readiness is conservative on non-event reads. Secret flags are not tested as Lua booleans. |
| `KstyleUI_Auras/Tracked.lua:129-188`, effective viewer categories | `Blizzard_CooldownViewer/CooldownViewerSettingsDataProvider.lua:109-177,229-234` | Default categories do not include the player's saved overrides. Falling back to defaults while the provider is dirty could remove a buff from both displays. Fixed by excluding nothing unless a clean effective layout and an always-visible enabled viewer are proven. |
| `KstyleUI_GroupFrames/Unit.lua:320`, `UnitInRange` | `Blizzard_APIDocumentationGenerated/UnitDocumentation.lua:1700-1714`; `Blizzard_UnitFrame/Shared/CompactUnitFrame.lua:1043-1052` | Ignoring `checkedRange` fades an unchecked unit as out of range. Fixed by composing both opaque booleans through engine alpha setters. `SimpleFrameAPIDocumentation.lua:276-289,1145-1157` proves secret alpha readback and tainted-secret setter arguments; no secret arithmetic is performed. |
| `KstyleUI_Meters/Damage.lua:386-391`, `SourceApi() ~= nil` | `Blizzard_APIDocumentationGenerated/DamageMeterDocumentation.lua:57-94` | A false capability result was treated as present, advertising unavailable drill-down. Fixed by testing the boolean directly. The APIs exist in 70862; this fixes the guarded fallback rather than claiming they are missing. |
| `Core/CVars.lua` and write wrappers in Chat, CombatText, Meters, Nameplates and QoL | `Blizzard_APIDocumentationGenerated/CVarDocumentation.lua:90-108,130-174` | The setter requires valid/public/nonsecure/non-read-only CVars and rejects secret arguments. Centralized writes now probe `GetCVarInfo`, reject unknown/protected/secret inputs and contain native exceptions. Restoration keeps remembered values when the probe cannot safely read them. |
| `KstyleUI_Nameplates/Logic.lua:173-183`, `nameplateMotion` fallback | No occurrence in the matching source Lua/XML or exact NUL-delimited string in the 70862 executable; `Blizzard_SettingsDefinitions_Frame/Nameplates.lua` uses the supported `nameplateStackingTypes` bitfield | The legacy fallback was unproven and could be attempted when the supported bitfield was unavailable. Removed it and its unused motion values; stacking stays unchanged when the supported bitfield is unavailable. The guard now covers `Logic.*_CVAR` field assignments and literal names passed through the core CVar wrappers. |
| `Tools/build/gen_globals.py`, client-only GlobalStrings | Client `DBFilesClient/GlobalStrings.db2`, exported with DBC2CSV; `GlobalStrings.dbd` defines Flags bit 0 as FrameXML, bit 1 as GlueXML | UI-source-only globals omit engine-provided localized format strings. Added a build-matched CSV supplement that imports FrameXML names only, not localized text or GlueXML-only names. The output header records the CSV hash and client build. |
| `Tools`' name guards | Generated API docs and the actual Forever TOC-loaded source | luacheck checks namespace roots, not members, and cannot validate strings passed as event/template/CVar names or dynamically indexed globals. Added a source-derived contract catalog and pre-commit guard, provenance inventory and negative fixture tests. See `API_CONFORMANCE.md` for exact boundaries. |

### Four native CVars retained

All four names absent from UI Lua were found as exact NUL-delimited strings in the installed 70862 executable, `World of Warcraft.app/Contents/MacOS/World of Warcraft`, SHA256 `033eb1605af1b627a571374108d76236732c26209ad90821674f55bda36103dd`:

| Name | Baseline addon location | Executable byte offset |
| --- | --- | --- |
| `floatingCombatTextPetMeleeDamage_v2` | `KstyleUI_CombatText/Blizzard.lua:15` | 57295856 |
| `floatingCombatTextPetSpellDamage_v2` | `KstyleUI_CombatText/Blizzard.lua:16` | 57295930 |
| `nameplateMaxDistance` | `KstyleUI_Nameplates/Logic.lua:165` | 57442479 |
| `nameplateMaxVerticalDistance` | `KstyleUI_Nameplates/Logic.lua:166` | 57442816 |

No behavior was removed on the basis of incomplete UI-source evidence. The generated catalog records these native proofs; runtime `GetCVarInfo` still decides whether a particular write is allowed. The owner's global `WTF/Config.wtf` did not contain these four names; that is not evidence of absence.

## BugGrabber: the Edit Mode nil rectangle

The capture at 20:20:11 on November 9 has `self=ObjectiveTrackerFrame`, `isDragging=true`, `selectedAnchored=true`, and **all four** rectangle values nil. In `Blizzard_EditMode/Shared/EditModeSystemTemplates.lua:604-607`, `self.Selection:GetRect()` supplies those values. Therefore the invalid rectangle is **the dragged objective tracker's selection**, not one of the magnetic target frames.

`GetFrameMagneticEligibility` at lines 794-812 checks the candidate's `HasValidSelectionRect()` but not its own before `IsVerticallyAlignedWithFrame` reads its rectangle at line 578. The generated `SimpleScriptRegionAPIDocumentation.lua:193-208` explicitly permits `GetRect` to return nothing. Running those actual Blizzard functions with an invalid own selection and valid candidate reproduces the exact nil-left arithmetic error under Lua 5.1; giving the selection a valid rectangle succeeds.

That proves the immediate failure and the missing Blizzard guard, **not why this particular selection lost its rectangle**. The capture lacks parent, points, visibility and rectangle history. The owner's live-checkout reflog places the session at #202 (`4ea561d3`, pulled at 20:14:48), before the quest-card reparenting code in #205 existed. The tracker skin at that commit changes its own fit/backdrop children and typography, not `ObjectiveTrackerFrame` or `Selection` anchors, parent or size. Setup writes an ordinary `UIParent`-relative anchor through `C_EditMode`; the saved layout also shows a `UIParent` relative anchor. Neither fact proves that every later native/addon mutation was harmless. Other addons and native frame movement were running.

The relevant Edit Mode functions are unchanged in 70862. No override of Blizzard's method, fake zero rectangle, or speculative anchor repair was shipped: these would conceal the symptom or change layout without proving causality. A controlled client reproduction is still required with other addons disabled, first with KstyleUI off, then on, recording `ObjectiveTrackerFrame` and `.Selection` parent/points/rect before and while dragging. The current quest card should be disabled for that diagnostic so the stock tracker can be dragged. This part of the requested root-cause investigation remains unresolved beyond the immediate invalid selection.

## Existing staging fix: the aura badge secret boolean

The owner's saved devlog has 107 entries naming `KstyleUI_UnitFrames/Auras.lua:223` and a secret-boolean test. This is the old `entry.badge:IsShown() and ...` expression. `SimpleScriptRegionAPIDocumentation.lua:568-578` marks `IsShown` with `SecretReturnsForAspect = Shown`, so that expression was invalid inside an engine aura button.

Commit **e9562211** (#201, 19:48 on November 9), already an ancestor of staging, replaces the readback with the desired timer placement and the saved `auraTimer` setting. Current `StyleButton` at lines 207-215 only passes state to setters; its conditions use `view.kind` and settings through `TimerBelow`/`Value`, never an engine visibility result. The existing `test-unitframes-auras.lua` makes each badge's `IsShown` raise, then restyles and crosses combat boundaries; it passes under Lua 5.1. The saved `!BugGrabber.lua` currently contains no matching aura entry. No duplicate fix was added; a fresh client pass is still needed to establish that no new error occurs.

## Findings left unchanged

- **Minimap Settings synchronization:** `Data.lua:212-230` keeps `C_Minimap.SetTracking`. Cross-family review showed that Forever's Options proxy reads `C_Minimap.IsFilteredOut` live (`Blizzard_SettingsDefinitions_Frame/Camelot/InterfaceOverrides.lua:12-28`), while calling `MinimapUtil` would enter Settings callbacks and write Blizzard's tracking-state upvalue (`Blizzard_Minimap/Mainline/Minimap.lua:858-879`). A stale open checkbox is not enough evidence to justify that new taint path. A regression test pins the native-only boundary; tracking and taint still need a client check.
- **Conservative cooldown readiness:** a non-event rebuild during a GCD can briefly dim a mirror icon or paint an interrupt as recharging until a trustworthy cooldown event arrives. This is the explicit trade-off for not reading the event-only `isOnGCD` field outside its contract; no timer or guessed GCD duration was added.
- **Item-link colour:** a source scan found no item quality derived from link colour in this baseline. Bags reads `ContainerItemInfo.quality` (`KstyleUI_Bags/Data.lua:139`), tooltip content calls `C_Item.GetItemQualityByID` (`KstyleUI_Tooltips/Content.lua:30-42`), and the loot skin reads row data quality (`KstyleUI_Skins/PartC/Loot.lua:15-24`). `Theme.QualityColor` maps that numeric quality, not hyperlink escape codes. The thirteen client-only loot strings requested by KSTY-8 are covered by the regenerated FrameXML globals.
- **Item-backed cooldown mirror rows:** `Mirror.lua:124-160` discards category item IDs and lacks equipped-item timing/update handling. Blizzard prefers item-specific cooldown information (`CooldownViewerItemData.lua:402-424`, `CooldownViewer.lua:1013-1044,1798-1800`). This can clear or misreport a sweep; the omission itself adds no unguarded raw-timing arithmetic. The Captain explicitly deferred the visual fallback to LEE-7. The detailed handoff is `findings-cooldowns-item-rows.md` in the Captain's drive.
- **Warning plate sizing:** `KstyleUI_Skins/Encounter/Warnings.lua:64-100,131-132` measures before Blizzard's per-frame text-size animation (`Blizzard_RaidWarning/RaidWarning.lua:121-146,205-226`, `Blizzard_FrameXMLUtil/FadingFrame.lua:79-95`). Possible clipping/fit drift is a layout finding; no size or anchor changes were made.
- **Bar count and pet feedback:** `KstyleUI_ActionBars/Data.lua:10-30` hides MultiBar6/7 without replacing those extra pages, and pet range/delayed minimap-tracking feedback is less complete than Blizzard's. These are product/interaction coverage questions, not proof of unsupported APIs; changing them would add UI behavior outside this audit.
- **Combat-text suppression:** `KstyleUI_CombatText/Settings.lua:24-26` intentionally disables Blizzard self text by default. That also suppresses notifications not reimplemented by the replacement (`Blizzard_CombatText/Shared/CombatText.lua:17-27,99-106`). Changing that default would be a visible policy change, not an API-conformance fix.
- **Unproven risks, not confirmed defects:** shared range-check ownership between duplicate action slots; secret swing-timer expiry; damage-session ordering; chat-buffer rewrite cost; external addons changing shared error-type switches. Source inspection did not prove a failure, so no speculative behavior changes were made.

## What the checks do not establish

The new inventory explicitly lists dynamic operands instead of passing them off as checked. It does not provide whole-program type inference, complete widget-type/mixin method validation, interprocedural secret propagation, native registry semantics from source alone, or a proof that every hooked frame exists at every load/combat transition. Widget stubs already restrict method names to generated Forever methods, but their union does not prove the receiver's concrete type. The existing secret lint tracks a limited source set and local expressions, not every secret aspect or callback.

The semantic audit checked important unit/cast/heal-prediction, action/pet/stance/flyout, cooldown, bank/item, meter, chat-filter, tooltip and CVar contracts. It was **not exhaustive for every dynamic frame field, mixin method and indirect call across the entire addon**. RestedXP and loot appearance remain owned by other threads. The PR's in-game list covers the unverified changed behavior; a live clean BugGrabber/taint pass is necessary before calling the suite error-free.
