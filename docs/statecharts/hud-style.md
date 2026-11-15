# HUD style switch

The HUD style is Frames, Orbs or Medallions, saved per profile in the `HudStyle` section. `Core/HudStyle.lua` owns the switch: it applies the saved style out of combat, holds a change made in combat until combat ends, fires `HudStyleChanged` once per real change, and offers a reload when a listener raised an error. `test-unitframes-orbs` drives the live switch, the combat queue (a second pick in combat prints nothing more) and the reload prompt; no test yet ends combat with the pick undone, or presses Later or Reload now.

```mermaid
stateDiagram-v2
    [*] --> Unapplied
    Unapplied --> Applied : first Apply() takes Saved(), fires nothing
    Applied --> Applied : Apply() with Saved() equal to applied
    Applied --> Queued : Apply() in combat lockdown
    Queued --> Queued : Apply() again in combat, ignored
    Queued --> Applied : combat ends, Saved() is back to applied
    Queued --> Switching : combat ends, Saved() differs
    Applied --> Switching : Apply() out of combat, Saved() differs
    Switching --> Applied : HudStyleChanged fired, no listener raised
    Switching --> ReloadOffered : ErrorCount() rose during the fire
    ReloadOffered --> Applied : Later
    ReloadOffered --> [*] : Reload now
```

## States

| State | What holds | Code |
| --- | --- | --- |
| Unapplied | `applied` is nil, so `HudStyle.Current()` returns `HudStyle.Saved()`: the profile's style when the Store is loaded and the value is a known, non-secret style, else `frames`. | `HudStyle.Saved`, `HudStyle.Current` |
| Applied | `applied` is the style every module draws; `Current()` returns it. | `Apply` (local) |
| Queued | `queued` is true. The player was told "Your HUD style changes when combat ends." and one function waits in `ns.Combat.Queue`. `Current()` still returns the old style, so modules keep drawing it while `Saved()` already holds the new one. | `Apply`, `Combat.Queue` (`Core/Combat.lua`) |
| Switching | `applied` is already the new style. `ns.Callbacks.Fire("HudStyleChanged", style)` runs each listener through `ns.Call`, so a listener that raises is counted, not propagated. | `Apply`, `Callbacks.Fire` (`Core/Callbacks.lua`), `ns.ErrorCount` (`Core/Init.lua`) |
| ReloadOffered | `Widgets.ReloadPrompt` shows "Your HUD style finishes changing when you reload." with Reload now and Later. Later leaves the new style applied, with the failed module part-way switched until the next reload. | `Widgets.ReloadPrompt` (`Core/Widgets/Dialog.lua`) |

## What calls Apply

- `ADDON_LOADED` for KstyleUI once the Store is loaded; the handler unregisters itself.
- `SettingChanged` for the `HudStyle` section: General > HUD style in the settings window, and `Setup.Apply`, which writes `HudStyle.style` through `Options.Write` with its `applying` flag set.
- `ProfileChanged`.

`Combat.Queue` flushes on `PLAYER_REGEN_ENABLED`; the queued function clears `queued` and calls `Apply` again, so a player who switches twice in one fight gets one change, or none when the second pick undoes the first.

## Who listens to HudStyleChanged

| Listener | What it does |
| --- | --- |
| `Core/Scale.lua` | `Request("the HUD style")`: the scale limit depends on the style. Under Medallions `Layouts.Fits` sizes bars 1 and 2 as the slab's two groups (6 by 2 slots below 21:9, 12 by 1 at 21:9 and wider) and counts the hub, a square 150 units wide centred on the slots' top edge, as a rect no element but the experience strip may enter. See [arrangement-layout-class.md](arrangement-layout-class.md). |
| `Core/Layout/Layout.lua` | `Restyle`: `ResolveAll` (each element's default comes from `StyleDefault` for the new style: Orbs and Medallions each have a table in `Setup/Layouts.lua`, Medallions' with 21:9 and 32:9 places of its own), `UpdateEvents`, `ApplyAll`, `LayoutChanged` for every element, then `Mode("Refresh")` when Layout Mode is open. |
| `Core/Setup/Setup.lua` | `Apply` takes any style `HudStyle.Valid` knows, Medallions included; `Restyle`: when `Setup.Apply` is not writing and the active Edit Mode layout is KstyleUI's layout for the current `Layout.preset` (`EditMode.ActiveName()` equals the preset), queues `EditMode.Restyle` to move the viewers and rows KstyleUI placed. |
| `KstyleUI_UnitFrames/Frames.lua` | `OnHudStyleChanged`: `Orbs.Apply`, the player frame, every restyle, and Blizzard's frames. |
| `KstyleUI_Chat/Module.lua` | `Refresh("framing")`. |
| `KstyleUI_Skins/Quests/Quests.lua` | `Replace`: places the quest card again. |
| `KstyleUI_QoL/Feed.lua` | `Restyle`, registered while the loot feed is on. |

## Medallions in the module listeners

The style switch itself has no Medallions state: `HudStyle.Valid` accepts the value and `HudStyle.Current()` answers `"medallions"`. The module listeners above test for `"orbs"` only, so until the Medallions module work lands each draws the Frames look under Medallions (unit frames, chat framing, story rail, loot feed), and the action bars keep their rows and split setting. What Medallions changes today is placement: `Core/Setup/Layouts.lua` gives it its own table, `Layouts.Fits` and so `Scale`'s limit know the slab's two groups and the hub, and the unit frames take the mock-up's sizes and stand either side of the hub, 120 mock pixels over the slots' top edge. `test-layout-medallions` drives the switch and the way back; `test-layout-medallions-hub` holds the hub against every slot.
