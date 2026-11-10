# Edit Mode geometry recorder

The recorder is developer-only and **off on every login/reload**. `/kstyle devlog on` arms it for this session; `/kstyle devlog off` stops it. It does not change the existing error/fallback devlog or any module setting.

It reads Edit Mode state every 0.25 seconds from an anonymous addon-owned frame. On entry, throughout a detected drag, on release and on exit, it records `ObjectiveTrackerFrame` and its `Selection`: parent identity, every sampled anchor tuple, rectangle, shown/visible state and local/effective scale. Other registered Edit Mode systems are included when either the system or its selection has a nil/unreadable rectangle. Changed state is logged; unchanged samples are deduplicated. `sample` and `part` identify related lines.

Each entry uses the existing `KstyleUIDB.devlog`, including its newest-500-entry bound. Long snapshots are split below the existing 1,000-character message limit, not silently cut off. Anchor reads are limited to 32 per object, with an explicit marker if a broken accessor reports more. Configuration recursion is bounded to eight levels with a cycle/depth marker; individual values over 160 characters are marked truncated. Secret values become `<secret>` before any comparison, arithmetic, indexing or string formatting. Missing/refused getters become `<unavailable>`; their error contents are not logged. A client without `issecretvalue` cannot enable the recorder.

At entry and a drag's start, the log includes the active profile, all module enable/running states, the profile's setting values, and the manager's actual merged-layout name/type/index and preset count. `GetActiveLayoutInfo` includes built-in presets and active overrides; the saved-layout list alone cannot identify those. This records `Skins.quests.enabled` and other relevant switches without calling `Store.Module` or changing settings. It never calls `SaveLayouts`, `SetActiveLayout`, an Edit Mode setter or a Blizzard `SetScript`/hook; the only frame it scripts or shows is its own polling frame. `Core/Setup/EditMode.lua` is unchanged.

## Exactly two diagnostic drags

Run out of combat on the staging build, with other addons disabled for the controlled comparison. If the quest card hides the stock tracker selection, turn **Windows → Quest card** off for both drags (`Skins.quests.enabled`); do not drag the KstyleUI card or RestedXP. Record the original layout choice so it can be restored.

1. **Placement applied:** select the existing **KstyleUI …** layout in Blizzard Edit Mode (use `/kstyle setup` to apply the intended preset first if none exists), then run `/kstyle devlog on`. Drag the **stock Objective Tracker selection** a short distance, hold it for at least two seconds, then release. Do this once.
2. **Placement not applied:** in the same Edit Mode session, select a **Blizzard built-in preset**, not a layout named KstyleUI. If asked about the first drag's unsaved changes, **discard** them before switching. Do not reapply KstyleUI setup. Drag that same **stock Objective Tracker selection** a short distance, hold for at least two seconds, then release. Do this once.

Do not save the diagnostic drag positions. Discard them, return to the original layout, exit Edit Mode, run `/kstyle devlog off`, then `/reload` to flush SavedVariables. The Captain can read the `EditModeRecorder` entries directly; no manual `/dump` is required. If a nil-rectangle error occurs, release and finish the same save sequence without extra drags that would overwrite the bounded log.

This is sampling, not an execution trace: a state created and repaired entirely between two callbacks can be missed. Holding each drag makes it observable without hooking or tainting Blizzard's drag code. A new client log is still required to establish what caused a nil rectangle; the recorder itself makes no geometry repair.

## Forever 70862 proof

All paths below are under the read-only `Gethe/wow-ui-source` **9dc84f0**, `Interface/AddOns/`:

| Read or behavior | Source contract |
| --- | --- |
| `EditModeManagerFrame:IsEditModeActive()` | `Blizzard_EditMode/Shared/EditModeManager.lua:149-150` is a pure read of `editModeActive`; entry/exit set it at 99/117. No manager method that changes state is called. |
| `registeredSystemFrames` | The manager creates the table at line 24, inserts system frames at 220-221 and iterates it at 95/113. |
| `Selection` and `isDragging` | `Blizzard_EditMode/Shared/EditModeSystemTemplates.lua:885-906` reads the selection and sets the system's drag flag. The flag clears before magnetism, so the recorder also samples release. |
| `GetRect` | `Blizzard_APIDocumentationGenerated/SimpleScriptRegionAPIDocumentation.lua:193-208`: may return nothing; `SecretWhenAnchoringSecret`. Every return is independently masked. |
| `GetNumPoints`, `GetPoint` | `SimpleScriptRegionResizingAPIDocumentation.lua:52-86`: the point accessor may return nothing, has `SecretWhenAnchoringSecret` and accepts secret arguments only when untainted. The recorder passes only a plain, bounded integer index. |
| `GetParent` | `SimpleObjectAPIDocumentation.lua:34-46`: hierarchy-aspect return can be secret, so it is never indexed or named before checking. |
| `GetDebugName`, `GetName` | `SimpleObjectAPIDocumentation.lua:17-31` and `SimpleFrameScriptObjectAPIDocumentation.lua:107-119`: names are formatted only after masking; the latter has the ObjectName secret aspect. |
| `IsShown`, `IsVisible` | `SimpleScriptRegionAPIDocumentation.lua:568-595`: shown-aspect state can be secret and is only serialized after masking. It never controls a recorder branch. |
| `GetScale`, `GetEffectiveScale` | `SimpleFrameAPIDocumentation.lua:621-633,381-393`: Scale-aspect returns are masked, never used for arithmetic. |
| Merged layout identity | `Blizzard_EditMode/Shared/EditModeManager.lua:1018-1020` prepends presets to saved layouts; `GetActiveLayoutInfo` at 1527-1533 is a pure getter of that merged list or the active override. The recorder reads it, `layoutInfo.activeLayout`, and counts `Enum.EditModeLayoutType.Preset` entries (`EditModeManagerConstantsDocumentation.lua:511-522`) without assuming two presets. |
| `issecretvalue` | `FrameScriptDocumentation.lua:287-303`: returns a public boolean identifying a secret value. The recorder stays off when the function is unavailable and never hooks it. |
| Addon-owned frame polling | `Blizzard_SharedXML/Shared/InputIcons/InputDeviceIconSetManager.lua:8` uses anonymous `CreateFrame("Frame")`; `SimpleScriptRegionAPIDocumentation.lua:712-740` documents `SetScript`/`SetShown`; `Blizzard_EditMode/Shared/EditModeManager.lua:84-87` uses `OnUpdate`. No event-registry callback, hook, native field write or script replacement is needed. |

`Tools/regression/test-devtest-editmode.lua` uses immutable native-frame proxies with throwing setters/hooks, secret geometry/parent/name-independent values, refused accessors, cyclic settings, a broken point count, entry/drag/release/exit transitions, throttling and session-off checks. `test-devtest.lua` still covers the original devlog and slash behavior.
