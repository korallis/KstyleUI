# Forever 1.60.1.70862 nameplate contract

Checked against the read-only `forever` source at commit `9dc84f0`, not the older 70840 checkout. Paths below are relative to `Interface/AddOns/`. The fill ramp uses `Texture:SetGradient` (`Blizzard_APIDocumentationGenerated/SimpleTextureBaseAPIDocumentation.lua:439`, `SecretArguments = AllowedWhenUntainted`) and `CreateColor` (`Blizzard_SharedXMLBase/Color.lua:3`). A secret colour never reaches `SetGradient`: it goes to `StatusBar:SetStatusBarColor` (`SimpleStatusBarAPIDocumentation.lua:282`, `AllowedWhenTainted`). No new event, template or CVar.

## Frames and permissions

`Blizzard_APIDocumentationGenerated/NamePlateDocumentation.lua:11-60` defines `C_NamePlate.GetNamePlateForUnit`, `GetNamePlateSize` and `SetNamePlateSize`; the size write is marked `HasRestrictions`, so the addon conservatively queues it out of combat. `Blizzard_NamePlates/Blizzard_NamePlateBase.lua:18` assigns the plate's `UnitFrame` through the driver's `AcquireUnitFrame` at `Blizzard_NamePlates.lua:158`; `Blizzard_NamePlateUnitFrame.lua` defines the unit-frame behavior. The addon creates its own child of the base, never reparents, resizes, anchors, hides, scripts or assigns unit attributes on either Blizzard frame. `Stacking.lua` uses the public size API through `Combat.Queue`, never `base:SetSize`.

The existing Blizzard-region changes are narrowly visual: `UnitFrame:SetAlpha(0)`, `selectionHighlight:SetAlpha(0)` (it ignores parent alpha), and `SoftTargetFrame:SetIgnoreParentAlpha(true)` (keep gamepad/accessibility prompts visible). They are restored on detach/disable. `Blizzard_NamePlates/Blizzard_NamePlates.xml` declares both regions and the highlight's parent-alpha behavior. The methods exist in `SimpleFrameAPIDocumentation.lua:1134,1364` and `SimpleRegionAPIDocumentation.lua:123,158`. The source identifies the hierarchy and methods, **not a blanket promise of addon access under every nameplate restriction**: forbidden friendly plates and restricted arena/instance behavior still require the live check. No newly styled bar or border is a Blizzard-owned region.

Own-frame presentation uses the existing kit: `SimpleFrameAPIDocumentation.lua`, `SimpleRegionAPIDocumentation.lua`, `SimpleTextureAPIDocumentation.lua`, `SimpleFontStringAPIDocumentation.lua` and `SimpleStatusBarAPIDocumentation.lua` define the frame/texture/font methods. `SetIgnoreParentScale` is in the frame and region docs (`:1374` / `:168`), and the status-bar `SetMinMaxValues`, `SetValue`, `SetTimerDuration` sinks are at `:229,355,334`. `SetVertexColorFromBoolean` and `SetAlphaFromBoolean` consume secret interrupt flags without a Lua decision.

## Values

All unit functions below are in `Blizzard_APIDocumentationGenerated/UnitDocumentation.lua`. A value marked secret is never compared, branched on, formatted by Lua, used as a key, or used in arithmetic. `type` and `issecretvalue` are used to choose a safe sink/fallback.

| APIs | Source / restriction | Consumer |
| --- | --- | --- |
| `UnitHealth`, `UnitHealthMax`, `UnitHealthPercent` | `:1526`, `:1472`, `:1506`; health is `SecretReturns`, maximum has `SecretWhenUnitHealthMaxRestricted` | Bar range/value; optional text via `AbbreviateNumbers` and `SetFormattedText`, never a Lua percentage |
| `UnitName` | `:2489`, `SecretWhenUnitNameIdentityRestricted` | Public names may be capitalised; a secret name goes directly to `SetText` |
| `UnitClass`, `UnitIsUnit`, `UnitGroupRolesAssigned` | unit class/comparison/role entries; identity/comparison restrictions | Class colour only through the kit's widget-safe class-colour resolver; a secret unit comparison does not select a target; secret roles do not choose tank behavior |
| `UnitCastingInfo`, `UnitChannelInfo` | `:828-852`, `:870-894`, `SecretWhenUnitSpellCastRestricted` | Name/icon to setters; flag to boolean widget setters; cast IDs compared only when public |
| `UnitCastingDuration`, `UnitChannelDuration` | `:811-824`, `:854-867`; casting duration is `SecretReturns` | Opaque duration goes straight to `SetTimerDuration`. A secret object is never indexed for `GetRemainingDuration`. Optional time text uses only a public duration object; the returned time still goes straight to `SetFormattedText` |
| `UnitPowerType`, `UnitPowerMax` | `:2859`, `:2801`; maximum has `SecretWhenUnitPowerMaxRestricted` | Only public values decide the optional caster colour; otherwise keep the known state |
| `UnitThreatSituation` | `:3279`, `SecretWhenUnitThreatStateRestricted` | Only a public status decides a threat colour; secret means no threat highlight |
| `GetRaidTargetIndex` | `Blizzard_APIDocumentationGenerated/RaidMarkersDocumentation.lua:55`, secret return | Index goes straight to `SetSpriteSheetCell`; `type` distinguishes an absent marker |
| `UnitCanAttack`, `UnitIsPlayer`, `UnitIsTapDenied`, `UnitClassification`, `UnitLevel`, `UnitEffectiveLevel`, `UnitReaction`, `UnitIsQuestBoss`, `UnitExists`, `UnitNameplateShowsWidgetsOnly` | Respective UnitDocumentation entries; no secret-return annotation on these entries | Defensive secret checks remain before any classification or comparison |
| `C_QuestLog.UnitIsRelatedToActiveQuest` | `QuestLogDocumentation.lua` | Optional type colour, only when the predicate is public |

`CurveConstants.ScaleTo100` comes from `Blizzard_SharedXMLBase/CurveConstants.lua`; the optional fallback uses the documented curve API. Interrupt readiness uses the existing `C_Spell.GetSpellCooldown` `isActive`/`isOnGCD` fields (`NeverSecret` in `SpellSharedDocumentation.lua`) and `C_SpellBook.IsSpellKnown` from `SpellBookDocumentation.lua`. Missing or secret cooldown information never invents a wait state.

## Auras

`Blizzard_AuraContainer/Blizzard_CustomAuraContainer.xml:4-17` declares `CustomAuraContainerTemplate`; `Blizzard_CustomAuraContainer.lua` implements unit binding, aura-group configuration, flow layout, sort/filter setters, `GetAuraGroupFrame` and `GetAuraGroupFrameCount` (`:335-356`). `Blizzard_CustomAuraButton.lua:243,159,87,178` defines `SetIcon`, `SetDurationCooldown`, `SetApplicationCount` and `SetDurationText`, respectively. Count, duration, icon and cooldown aspects become secret inside the engine. The engine fills addon-owned regions; the addon never reads their state or visibility back. Desired timer/count visibility comes from settings. `C_Secrets.ShouldAurasBeSecret` is in `SecretPredicateAPIDocumentation.lua:119`; manual button restyling waits while it is true, including before combat begins. Flow configuration remains on the container's public inbound API. The flat icon border is static and has no auto-restyling chrome that reads restricted button dimensions.

## Events

All paths in this table are under `Blizzard_APIDocumentationGenerated/`.

| Registered events | Definition |
| --- | --- |
| `NAME_PLATE_UNIT_ADDED`, `NAME_PLATE_UNIT_REMOVED` | `NamePlateManagerDocumentation.lua:120-141` |
| `UNIT_HEALTH`, `UNIT_MAXHEALTH`, `UNIT_NAME_UPDATE`, `UNIT_LEVEL`, `UNIT_CLASSIFICATION_CHANGED`, `UNIT_FACTION`, `UNIT_FLAGS`, `UNIT_DISPLAYPOWER` | `UnitDocumentation.lua:4161,4237,4259,4269,4320,4353,4398,4431` |
| `UNIT_THREAT_SITUATION_UPDATE`, `UNIT_THREAT_LIST_UPDATE` | `UnitDocumentation.lua:4891-4902` |
| `UNIT_SPELLCAST_START`, `UNIT_SPELLCAST_CHANNEL_START`, `UNIT_SPELLCAST_DELAYED`, `UNIT_SPELLCAST_CHANNEL_UPDATE`, `UNIT_SPELLCAST_STOP`, `UNIT_SPELLCAST_FAILED`, `UNIT_SPELLCAST_CHANNEL_STOP`, `UNIT_SPELLCAST_INTERRUPTED`, `UNIT_SPELLCAST_INTERRUPTIBLE`, `UNIT_SPELLCAST_NOT_INTERRUPTIBLE` | `UnitDocumentation.lua:4615-4833` |
| `PLAYER_TARGET_CHANGED`, `PLAYER_FOCUS_CHANGED`, `UNIT_QUEST_LOG_CHANGED` | `UnitDocumentation.lua:3976,3792,4565` |
| `RAID_TARGET_UPDATE` | `EncounterInfoDocumentation.lua:86` |
| `QUEST_LOG_UPDATE` | `QuestLogDocumentation.lua:1373` |
| `PLAYER_ROLES_ASSIGNED`, `GROUP_ROSTER_UPDATE` | `PartyInfoDocumentation.lua:828,680` |
| `SPELLS_CHANGED`, `SPELL_UPDATE_COOLDOWN` | `SpellBookDocumentation.lua:966,925` |

Cast GUIDs/event payloads can be secret: the handlers do not inspect spell IDs or branch on those values. The engine owns cast progress and interruptibility.

## CVars (unchanged; KSTY-5 owns writes)

`nameplateMinScale`, `nameplateMaxScale` and `nameplateSelectedScale` are referenced by `Blizzard_Commentator/Mainline/Blizzard_Commentator.lua:232-234`, which sets all three to 1 as Stacking.lua's scale hold does; `nameplateSize` by `Blizzard_NamePlates/Blizzard_NamePlateConstants.lua:12` and `Blizzard_SettingsDefinitions_Frame/Nameplates.lua:562`; `nameplateStackingTypes` by `Blizzard_SettingsDefinitions_Frame/Nameplates.lua:529-546`. Generic CVar reads/writes are in `CVarDocumentation.lua`.

The UI source has **no literal proof** for native `nameplateMaxDistance` or `nameplateMaxVerticalDistance`. Both were independently verified as exact NUL-delimited strings in the installed 70862 executable at byte offsets 57442479 and 57442816, respectively (SHA256 `033eb1605af1b627a571374108d76236732c26209ad90821674f55bda36103dd`). This proves native names, not runtime writability; `C_CVar.GetCVarInfo` (`CVarDocumentation.lua:90-108`) is the separate runtime probe. The executable was read, never run or changed.

The legacy fallback `nameplateMotion` is absent from both UI source and the exact executable strings. KSTY-5's API audit PR #216 removes that unsupported fallback and records the native proofs in `Tools/data/forever_api_contracts.json` and `docs/FOREVER_API_AUDIT.md`. This visual PR leaves all CVar writes and fallback code untouched under that ownership. Do not present a generic `SetCVar` declaration as proof of an individual CVar.
