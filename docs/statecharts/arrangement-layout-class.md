# Ultrawide arrangement and layout class

`Core/Scale.lua` sizes and places `KstyleUI_Root`, the canvas every HUD element anchors to, and names its layout class. Three Elements settings feed it: Ultrawide arrangement (Centred or Spread), HUD width (21:9, 16:9 or full) and the layout preset. When the class or the Spread band inset changes, `Core/Layout/Layout.lua` moves every element still at its default to the new class's place; a place the player set stays. `test-layout-ultrawide` drives it.

```mermaid
stateDiagram-v2
    [*] --> Applying : the file loads and calls Apply
    Settled --> Applying : PLAYER_LOGIN calls Apply, even in combat
    Settled --> DisplayPending : display, UI scale, scale CVar or root size event
    DisplayPending --> DisplayPending : more events update the inputs
    DisplayPending --> Requested : next frame reads the final inputs
    Settled --> Requested : a setting calls Request(reason)
    Requested --> ResizePending : resize, option on, out of combat
    ResizePending --> ResizePending : another resize restarts 120 ms wait
    ResizePending --> Requested : last resize was 120 ms ago
    state combat <<choice>>
    Requested --> combat
    combat --> Applying : out of combat
    combat --> Waiting : in combat, nothing waiting yet
    Waiting --> Waiting : another Request in combat, dropped
    Waiting --> Applying : combat ends, ApplyWaiting
    state changed <<choice>>
    Applying --> changed
    changed --> Settled : inputs equal the last Apply
    changed --> Rescaled : any input differs
    state newClass <<choice>>
    Rescaled --> newClass : ScaleChanged fired
    newClass --> Settled : same class and band, ApplyAll and Mode Refresh
    newClass --> Reclassed : class or band changed
    Reclassed --> Settled : resolve elements, ApplyAll, notify changed geometry, Mode Refresh
```

## States

| State | What holds | Code |
| --- | --- | --- |
| DisplayPending | Display, UI-scale, scale-CVar and root-size events invalidate live scale reads immediately, then share one next-frame request; intermediate sizes never run fitting or layout. In combat they queue the final apply through Combat.Queue. | `RequestDisplay`, `test-scale-resize` |
| Requested | Out of combat `Request` calls `Apply` at once. In combat it sets `state.waiting` once and queues `ApplyWaiting` with `ns.Combat.Queue`; later requests in the same fight are dropped, because the one Apply reads every input fresh. `PLAYER_LOGIN` and the file's last line skip `Request` and call `Apply` even in combat, so a `/reload` in a fight rescales at once. | `Request`, `ApplyWaiting` |
| ResizePending | General > Window resizing offers **Wait for window resizing to stop**, on by default. When enabled, display and root-size events retain the current HUD for 120 ms after the last event, after the next-frame request. Only the latest timer requests an apply; combat still queues protected work. | `Request`, `RequestDisplay`, `test-resize-debounce` |
| Applying | `Apply` reads the physical screen, works out the canvas width (`CanvasWidth`: the screen under Spread; under Centred `BandWidth`, the screen capped at the HUD width's aspect), the band width, the scale limit for the preset, style and enabled elements (`Limit`), and the size (Auto or the player's, in whole-pixel steps). It compares eight inputs with the last Apply and returns when none changed. The six latest fitted size answers stay in session memory, including in development checkouts; fitting settings clear them before the next search. | `Apply`, `CanvasWidth`, `BandWidth`, `Limit` |
| Rescaled | The root's scale and points are set: centred on the screen when the canvas is narrower than it, else all points on `UIParent`. `state.aspect` is `AspectClass(width, height)` of the canvas: `16:9` below 2.05, `21:9` from 2.05, `32:9` from 2.9. `state.band` is the Spread inset where group and boss frames stay. Then `ScaleChanged` fires. | `Apply`, `AspectClass`, `Scale.Aspect`, `Scale.Band` |
| Reclassed | Layout's `ScaleChanged` handler always runs `ApplyAll`, and `Mode("Refresh")` when Layout Mode is open. Only when it saw a new class or band does it first run `ResolveAll`, which gives each element `StyleDefault`, the place for this class and HUD style from `Setup.Layouts`, with the player's saved fields on top, then `UpdateEvents`, and afterwards fire `LayoutChanged(key, "scale")` only for elements whose resolved anchor, offsets, size or scale changed. Setup's own `ScaleChanged` handler calls `Restyle`, which queues `EditMode.Restyle` when the active Edit Mode layout is KstyleUI's. | `Layout.lua` `ScaleChanged` handler, `ResolveAll`, `StyleDefault`; `Setup.lua` `Restyle` |

## What calls Request

- `SettingChanged` for `Layout.arrangement`, `Layout.canvas` (HUD width), `Layout.preset`, or any module's setting.
- `HudStyleChanged` (see [hud-style.md](hud-style.md)), `ModuleChanged` and `ProfileChanged` (which first reloads Auto and the size from Appearance).
- `Scale.SetAuto` and `Scale.SetUserScale` when the value changes.
- `UI_SCALE_CHANGED`, `DISPLAY_SIZE_CHANGED` and `CVAR_UPDATE` for `uiScale` or `useUiScale`, and the root's `OnSizeChanged`, coalesced into one request on the next frame.

`PLAYER_LOGIN` and the file's last line call `Apply` directly, without the combat wait.
