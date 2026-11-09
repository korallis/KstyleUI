# Layout

`KstyleUI.Layout` places every visible KstyleUI element, stores where the player puts it, and runs Layout Mode. The spec's [Layout Mode](../../docs/superpowers/specs/2026-11-07-kstyleui-design.md#layout-mode) and [Customisation and resizing](../../docs/superpowers/specs/2026-11-07-kstyleui-design.md#customisation-and-resizing) sections are binding. `Core/Layout/Layout.xml` loads the files in this order:

| File | What it holds |
| --- | --- |
| `Geometry.lua` | `Layout.Geometry`: pure maths for anchors, rects, whole-pixel snapping, guides, resizing and rescaling |
| `History.lua` | `Layout.History`: the undo and redo stacks |
| `Rules.lua` | `Layout.Rules`: the shown rules, as Lua tests and as state-driver macro options |
| `Layout.lua` | The registry, per-profile settings, applying, sessions, undo, and Layout Mode's own settings page |
| `Mode.lua` | `Layout.Mode`: Layout Mode's screen: plates, handles, guides, the grid, the story slot's outline, the keyboard and the toolbar. The story slot's label and hint stand on their own glass card at its top, and the raid line's note on another under the line; each card hides while a mover plate covers any of it, so a plate's label is never written over and the guidance never hides half under a plate. |
| `Calm.lua` | `Layout.Calm`: the combat calm, which rests the idle lines at 30%, the readout card at a legible 65%, dims the cards you read to 75% and the story card (tracker and guide) only to 90% in combat |

Tests: `Tools/regression/test-layout.lua` (maths, snapping, resize clamping, history, shown rules), `test-layout-service.lua` (the registry against the stubs), `test-layout-hover.lua` (the mouseover rule over content Layout cannot hook), `test-layout-mode.lua` (the screen, driven like a player) and `test-layout-calm.lua` (the combat calm).

## Registering an element

```lua
KstyleUI.Layout.Register(frame, key, defaultPosition, opts)
```

- `frame`: the KstyleUI frame to place. Never a Blizzard frame.
- `key`: a unique name of 1 to 64 characters, such as `"UnitFrames.Player"`. Saved positions use it, so never rename a key.
- `defaultPosition = { anchor, x, y }`: one of the nine anchors (`TOPLEFT`, `TOP`, `TOPRIGHT`, `LEFT`, `CENTER`, `RIGHT`, `BOTTOMLEFT`, `BOTTOM`, `BOTTOMRIGHT`) and offsets in root units. The frame's anchor point sits at the same anchor of `KstyleUI_Root`.
- `opts`, all optional:

| Option | Meaning |
| --- | --- |
| `label` | The name on the mover plate and in the settings window. Default: the key. |
| `module` | The module that owns the element, such as `"UnitFrames"`. Layout never shows a frame of a module that is not running. |
| `resizable` | Layout owns the frame's width and height. Default size: the frame's size when it registers. |
| `minWidth`, `maxWidth`, `minHeight`, `maxHeight` | Size limits in the frame's own units. Defaults 8 and 4096. |
| `aspect` | `true` keeps the default proportions; a number is width over height. Only with `resizable`. |
| `scalable` | Layout owns the frame's scale, from 0.5 to 2. Default: the frame's scale when it registers. |
| `plate` | `false` draws no mover plate, for a frame that moves itself in Layout Mode, such as the Layout toolbar. |
| `window` | `true` for a core window the player needs to get back to: the settings window, the dialog host, the Layout Mode toolbar and the first-run setup. The settings window shows no Shown row for it, and its opacity sliders stop at 25%. |
| `fields` | The settings that apply, as a list of `shown`, `anchor`, `x`, `y`, `width`, `height`, `scale`, `alphaCombat`, `alphaIdle` and `strata`. The settings window builds only those rows. For a proxy element, such as the nameplate size sample (`{ "width", "height" }`) or the tooltip anchor (`{ "anchor", "x", "y", "scale" }`). Default: every field. |

`Register` raises an error for a bad argument. Registering a key again updates its frame, default and options. `Widgets.Place(frame, key, position, opts)` positions a frame and registers it in one call.

### What Layout owns

Layout owns the registered frame's anchor, and its size, scale, strata, visibility and alpha where the element's settings ask for them:

- Position: always. Layout clears the frame's points and sets one point on `KstyleUI_Root`.
- Size: only for a `resizable` element. Scale: only for a `scalable` element.
- Strata: once the player picks one other than the frame's own.
- Alpha: once the player picks an opacity other than 100% or the mouseover rule.
- Visibility: for any rule other than `always`.

A module that fades or shows and hides its own frame, such as a cast bar, a unit frame with `RegisterUnitWatch` or a range fade with `SetAlphaFromBoolean`, registers a holder frame and fades or toggles a child, so Layout and the module never fight over one frame.

## Element settings

Every element has these settings, saved per profile in `KstyleUIDB.layouts[profile][key]`. Only the fields that differ from the defaults are saved.

| Field | Values | Default |
| --- | --- | --- |
| `anchor` | One of the nine anchors | `defaultPosition.anchor` |
| `x`, `y` | Root units from the anchor | `defaultPosition.x` and `.y`, or 0 |
| `width`, `height` | Frame units, within the limits. For an element that is not resizable, the frame's current size, read only | The frame's size |
| `scale` | 0.5 to 2, read only unless `scalable` | The frame's scale |
| `shown` | `always`, `combat`, `noCombat`, `target`, `mouseover`, `never` | `always` |
| `alphaCombat`, `alphaIdle` | 0 to 1 | 1 |
| `strata` | `BACKGROUND`, `LOW`, `MEDIUM`, `HIGH`, or the frame's own strata | The frame's strata |

`Layout.SHOWN_OPTIONS`, `Layout.STRATA_OPTIONS` and `Layout.ANCHOR_OPTIONS` are `{ { value, label }, ... }` lists for the settings window's dropdowns. `Layout.SCALE_MIN`, `SCALE_MAX` and `SCALE_STEP` give the scale slider.

A saved value that is not allowed, such as from a damaged or hand-edited profile, gives the default and one devlog line.

## Functions

| Function | Behaviour |
| --- | --- |
| `Register(frame, key, defaultPosition, opts)` | See above. Applies the saved settings at once, or the defaults before the saved data loads. |
| `Elements() -> { { key, label, module, opts, live }, ... }` | Every element in registration order. `opts` is a copy. `live` is `Live(key)`; the settings window lists only live elements. |
| `Get(key) -> settings` | A copy of the element's settings, or `nil` for an unknown key. |
| `Set(key, field, value) -> true` or `false, reason` | Checks, stores and applies one field, then fires `LayoutChanged(key)`. `nil` resets the field. Sizes clamp to the limits and an aspect-locked element moves the other size with it. A scale outside 0.5 to 2 clamps. A new anchor keeps the element where it is by converting `x` and `y`. A bad field, a bad value, a secret, an unknown key, or a call before the saved data loads is refused with a reason. |
| `Update(key, values, merge) -> true` or `false, reason` | Several fields as one change. Layout Mode uses it. Consecutive changes with the same `merge` key fold into one undo step. |
| `Reset(key)`, `ResetAll()` | Return elements to their defaults. Each call is one undo step. |
| `Enter() -> boolean` | Opens Layout Mode. Refused in combat and before the saved data loads, with a chat line. |
| `Exit(save)` | Closes Layout Mode. `Exit(false)` restores the layout saved when Layout Mode opened; any other value keeps the changes. |
| `Toggle()`, `IsActive()` | `/kstyle layout` calls `Toggle`. |
| `Undo()`, `Redo()`, `CanUndo()`, `CanRedo()` | The history of one Layout Mode session. Changes made outside Layout Mode are not recorded. |
| `Rect(key) -> left, bottom, width, height` | The element's rect in root units, as applied. |
| `RefreshAlpha(key, duration) -> boolean` | Applies the element's alpha again over `duration` seconds (0 is instant). The combat calm uses it. `false` for an unknown key. |
| `Preview(key, left, bottom, width, height, scale)` | Moves the frame without saving, for drags. |
| `Restore(key)` | Applies the saved settings again, after a preview. |
| `RootSize() -> width, height` | `KstyleUI_Root`'s size in root units. |
| `Live(key) -> boolean` | True when the element exists, its module, if it names one, is running, and the module has not switched it off with `SetLive`. Layout Mode draws plates only for live elements. |
| `SetLive(key, live) -> boolean` | A module switches one of its elements off (`false`) or on (`true`, the default) when the element's own setting changes, such as a unit frame, a cast bar, an action bar or a meter switched off. A change refreshes the element's plate and fires `LayoutChanged(key)`. Returns `false` for an unknown key. |
| `Setting(key)` | One of Layout Mode's own settings, checked. |

`LayoutChanged(key)` fires through `KstyleUI.Callbacks` after `Set`, `Update`, `Reset`, `ResetAll`, undo, redo, a restore on `Exit(false)`, and for every element after `ProfileChanged`.

## Whole pixels

Layout applies every position and size in whole physical pixels on every screen. For each element it:

1. Computes the element's rect on the root from the anchor and offsets, using the frame's size times its scale against the root.
2. Moves the left and bottom edges to the nearest whole pixel (`Scale.Pixel(1)` root units).
3. Converts back to offsets from the same anchor, divided by the frame's scale, because `SetPoint` offsets are in the frame's own units.

A resizable element's width and height snap so that size times scale is a whole number of pixels. Layout applies everything again on `ScaleChanged`, so a move to another monitor or a new size setting keeps every edge on a pixel. A `ProfileChanged` re-applies the new profile's layout.

## Shown rules and opacity

| Rule | Lua frame | Protected frame |
| --- | --- | --- |
| `always` | Left alone | No state driver |
| `combat` | Shown from `PLAYER_REGEN_DISABLED`, hidden from `PLAYER_REGEN_ENABLED` | `RegisterStateDriver(frame, "visibility", "[combat] show; hide")` |
| `noCombat` | The reverse | `"[combat] hide; show"` |
| `target` | Follows `PLAYER_TARGET_CHANGED` and `UnitExists("target")` | `"[@target,exists] show; hide"` |
| `mouseover` | Shown at alpha 0 until the pointer is over the frame's rect or a hooked child | No state driver; alpha only |
| `never` | Hidden | `"hide"` |

- A frame counts as protected when `IsProtected()` is true or secret. Its state driver changes only out of combat; in combat the change waits for `Combat.Queue`. The secure state driver manager shows and hides the frame in combat, so no KstyleUI code makes a protected call there. Each driver is logged to the devlog with what `SecureCmdOptionParse` reads for it.
- Without `RegisterStateDriver`, a protected element keeps its own visibility and the devlog says so.
- On a Lua frame Layout hides a frame the rule hides, and shows it again only if Layout hid it and its module is running. A hooked `OnShow` hides the frame again while the rule says hidden.
- The alpha is `alphaCombat` in combat and `alphaIdle` out of it, faded over `fade`. Alpha changes are allowed on protected frames in combat. The mouseover rule uses alpha 0 until the pointer is over the element, and turns on mouse motion for a frame that has no mouse, so the pointer finds it without blocking clicks.
- The mouseover rule finds the pointer in two ways:
  - Hooks: `OnEnter` and `OnLeave` on the frame and its children, four levels deep, show and hide it at once. Layout hooks the tree again when the rule applies, when the frame shows, and when a hover starts, so a child made since, such as a lazily made icon, joins.
  - A poll: while any element uses the rule, one `C_Timer.NewTicker` reads `IsMouseOver` on each such frame, and on each hooked child under the pointer, every 0.1 s. It finds content that keeps the mouse focus from Layout's hooks: a child made since the last hook pass, or a frame mirrored over the element from outside its tree, such as the Auras host, whose aura buttons Layout never touches. It skips an element whose module is off, and it stops when no element uses the rule.
- A frame that denies access, as an aura button does while auras are secret (`CanBeAccessedInContext` is false), is never hooked or read; it counts as not under the pointer. A secret `IsMouseOver` counts as under it, so the element stays visible rather than invisible and clickable. Each fallback is logged once.
- Layout listens for `PLAYER_REGEN_DISABLED` and `PLAYER_REGEN_ENABLED` only while Layout Mode is open or an element needs them, and for `PLAYER_TARGET_CHANGED` only while an element uses the target rule.

## Protected frames and combat

- Position, size, scale, strata and state-driver changes on a protected frame in combat wait for `Combat.Queue`, once per element however many changes arrive.
- `PLAYER_REGEN_DISABLED` fires before lockdown. If Layout Mode is open then, Layout leaves it, restores the layout saved when it opened, and prints a line (Review Focus item 3). Every restore runs before lockdown, so no protected call fires in combat.
- `Enter` refuses to open in combat.

## Sessions and undo

`Enter` copies the active profile's layout. Every change in Layout Mode goes on a history of up to 100 steps. `Exit(false)` writes the copy back. A profile change while Layout Mode is open closes it and keeps the old profile's changes, because they belong to that profile.

## Layout Mode

`/kstyle layout`, `Layout.Toggle()` or the settings window's Layout Mode button opens it out of combat.

| Part | What it does |
| --- | --- |
| Overlay | A frame over `KstyleUI_Root` in the `FULLSCREEN` strata. It takes the keyboard with propagation on, so only the keys below stop at it. |
| Plates | One per element whose `plate` option is not `false` and whose module is running: a chamfered tile over the element on the button grade's body, translucent so the element shows through, with the accent on its edge and the element's name as a caption. The body deepens and the edge brightens under the mouse and when selected. The selected plate shows its anchor, offsets, size and scale. A plate is at least 16 units on each side, so an empty frame can still be grabbed. |
| Handles | The selected resizable element shows eight handles on its corners and edges. A selected element that is scalable and not resizable shows one scale handle on its bottom right corner. |
| Guides | An accent line on each axis while a drag is snapped. |
| Grid | Lines every `gridSize` units from the centre, in the `BACKGROUND` strata, while `grid` is on. The centre lines are the accent. |
| Toolbar | A glass panel in the `FULLSCREEN_DIALOG` strata with the Grid and Snap switches and the Undo, Redo, Reset and Done buttons. It registers as the element `Layout.Toolbar` (scalable, no plate) and moves by its title bar. |
| Story slot | An accent outline under the plates, at the story slot of the layout last applied (the `preset` setting): `Setup.Layouts.Slot(preset)`, the left rail between the party card and chat. It shows the slot's label, **Story rail**, and a one-line hint: Apply places the quest tracker there through Edit Mode, and Window skins put the RestedXP guide above it. A fainter line marks how far the raid card reaches into the slot in a raid, with a caption that says so. The outline takes no mouse. `Mode.Slot()` returns it. |

| Input | Effect |
| --- | --- |
| Press a plate | Selects it. |
| Drag a plate | Moves the element. With `snap` on, an edge or the centre within `snapDistance` units snaps to another element's edges and centre, the screen's edges and centre, and, with the grid on, the nearest grid line. The release saves the position against the nearest of the nine anchors. |
| Drag a handle | Resizes within the limits, keeping the opposite edge, the aspect when it is locked, and whole pixels. The scale handle scales from 0.5 to 2 and keeps the top left corner. |
| Mouse wheel on a plate | Scales a scalable element by 0.05 around its anchor. |
| Right-click a plate | Resets the element. |
| Arrow keys | Nudge the selected element by one physical pixel, or ten with Shift. A run of nudges is one undo step. |
| Ctrl+Z, Ctrl+Y, Ctrl+Shift+Z | Undo, redo, redo. |
| Escape | Cancels a drag, then deselects, then leaves Layout Mode keeping the changes. |

A drag runs one `OnUpdate` on the overlay and removes it on release. It moves the frame with `Layout.Preview` and saves once, on release, as one undo step. Combat, a profile change or leaving Layout Mode cancels a drag and puts the frame back.

## Layout Mode's settings

`Layout` registers its own settings page with `Store.RegisterDefaults("Layout", defaults)` and `Options.Register("Layout", schema)`:

| Key | Default | Row |
| --- | --- | --- |
| `grid` | `false` | toggle |
| `gridSize` | 16 | slider, 4 to 64 in steps of 4 |
| `snap` | `true` | toggle |
| `snapDistance` | 8 | slider, 2 to 24 |
| `calm` | `true` | toggle, **Calm the rails in combat**, under a **Combat** header |
| `preset` | `"DPS"` | none. The layout the first-run setup last applied, which Layout Mode outlines the story slot for |

## Why

- Layout stores positions against nine anchors in root units, so one layout fits 16:9, 16:10 and the Mac's 3456x2234 screen alike. An element near the right edge stays near the right edge on a wider screen.
- Layout never moves a Blizzard frame. A Blizzard frame that needs a new place is hidden through `Safe` and replaced by a KstyleUI frame.
- Layout owns only what an element's settings ask for, so an element at its defaults behaves exactly as its module made it.

## Combat calm

`Calm.lua` rests the rails' slow cards in combat, so the eye stays on the centre and the focus cards. It owns no frame's alpha of its own: for a Layout element it gives Layout's alpha a factor, so Layout stays the one writer.

| Value | |
| --- | --- |
| `Calm.IDLE` | The idle lines, which nobody reads mid-pull: `databars.xp`, `databars.rep`, `databars.honor` |
| `Calm.READOUT` | The readout card and its docked menus, which a player glances at mid-pull (frame rate, latency, durability): `databars.strip`, `databars.micro`, `databars.bags` |
| `Calm.READ` | The cards you read mid-pull (raid calls, the map): `chat.main`, `minimap.main` |
| `Calm.CARDS` | Every list, read cards first |
| `Calm.SURFACES` | The guide and quest skins: `ObjectiveTrackerFrame` and `RXPFrame`, while the Skins module runs. They are the story card and rest at `Calm.STORY`, 90%: objective lines over bright scenery were the HUD's hardest read at 75% (round 5, Muse 6e) |
| `Calm.ALPHA` | 0.3, the idle lines' level |
| `Calm.FLOOR` | 0.65, the readout card's level: legible, never a ghost (round 3, Muse #3) |
| `Calm.SOFT` | 0.75, the read cards' and surfaces' level: dimmed so the centre leads, never below 60%, so chat, the map and the quests stay readable |
| `Calm.FALL`, `Calm.RISE`, `Calm.HOVER` | 0.24 s into the calm, 0.6 s out of it, 0.24 s for a hover |
| `Calm.DELAY` | 3 s after combat ends before the cards rise |

- **Focus cards never calm:** party and raid, the boss card, the target sigil and every centre hand (unit frames, cast bars, action bars, cooldowns), the Blessings (`auras.*`), and the damage and threat meters. The damage meter stays readable in a pull.
- **In combat** (`PLAYER_REGEN_DISABLED`), each idle line tweens to 30%, the readout card to 65%, each read card to 75% and the story surfaces to 90% over 0.24 s. **Out of combat** (`PLAYER_REGEN_ENABLED`), the cards wait 3 s, counted on an `OnUpdate` that runs only while it waits, then rise over 0.6 s. A pull during the wait keeps them calm, and the wait starts again when it ends.
- **Hover:** while calm, a `C_Timer.NewTicker` reads `IsMouseOver` on each calmed card every 0.1 s. A card under the pointer rises to 100% and calms again when the pointer leaves. A secret `IsMouseOver` counts as over, and a frame that denies access counts as not over. The ticker stops with the calm.
- **Alpha only:** the calm never changes a size, a point, a scale or a shown rule, so it never touches a protected frame's geometry in combat.
- **One owner per frame:** a Layout element calms only while its own opacity is at the defaults (`shown` is not `mouseover`, `alphaCombat` and `alphaIdle` are 1). A player's own opacity or mouseover rule wins. Layout's `ApplyAlpha` multiplies its alpha by `Calm.Level(key)` and does not restart a fade already heading to the same alpha. A surface outside Layout calms only from 100%. When the calm ends it rises only if its alpha is still what the calm set, so a fade another addon starts in the meantime is left alone.
- **Reduced motion** (`Motion.ReducedMotion()`) makes every calm fade instant; the 3-second wait stays.
- **The setting** `Layout.calm`, on by default. Turned off in combat, the cards rise at once; turned on in combat, they calm. The calm listens for combat only while the setting is on and a slow card is registered or the Skins module runs.
