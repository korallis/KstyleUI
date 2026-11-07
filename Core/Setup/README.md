# Setup

`KstyleUI.Setup` is the first-run setup: four steps that pick a layout and the modules, then apply both and offer a reload. The spec's [Settings and first-run setup](../../docs/superpowers/specs/2026-11-07-kstyleui-design.md#settings-and-first-run-setup) section is binding. `Core/Setup/Setup.xml` loads the files in this order:

| File | What it holds |
| --- | --- |
| `Layouts.lua` | `Setup.Layouts`: the element keys and the DPS, Tank and Healer layouts. See [`element-keys.md`](../../docs/superpowers/plans/element-keys.md). |
| `Setup.lua` | The choices, `Apply`, and when the window opens |
| `Window.lua` | The window, built from the widget kit |

Tests: `Tools/regression/test-setup.lua` and `test-setup-layouts.lua`.

## When it opens

- At `PLAYER_LOGIN`, when the account switch `Features.account.setupSeen` is off, the setup opens 2 seconds later. The switch is account-wide, so the setup opens once per account, not once per character.
- Applying or closing the setup turns the switch on. Closing without applying prints how to run it again.
- `/kstyle setup` opens it at any time, on the welcome step with fresh choices.

## The steps

The window is a titled `Widgets.Panel` (760 by 540 units, `DIALOG` strata, Escape closes it) that opens with the panel motion. It registers with Layout as `setup.window`, scalable, 40 units above the centre. A `Widgets.Tabs` strip shows the four steps. A step the player has not reached is disabled, and each page fades in over `fade`.

1. **Welcome.** The logo, a short welcome, the three steps ahead, **Skip setup** and **Next**.
2. **Layout.** One card per layout: a 16:9 preview that draws each element's footprint from `Setup.Layouts`, the layout's name and its one-line note. A click picks the card: an `accent` hairline, a selection glow and an `accent` preview. DPS is picked first.
3. **Modules.** A toggle and a one-line note for each module in `Setup.PICKER`, with **All on** and **All off**. Every module whose addon loaded starts on. A module whose addon did not load is off, disabled and says so. Custom icons need the `KstyleUI_Icons` addon to exist. The settings window and icon set B are not in the list: the settings window loads on demand, and the Icons page picks the set.
4. **Summary.** The layout and the modules that will be on and off, then **Apply**. After Apply, the secure **Reload** button and **Later**. Changing a choice afterwards shows **Apply** again.

## Apply

`Setup.Apply(choice)` with `choice = { layout, modules = { [name] = boolean } }`:

1. For each module in the picker whose addon loaded, `Options.Write(name, "enabled", value)`. Writing through `Options` starts or stops the module through `Modules`, waiting for the end of combat if needed, and fires `SettingChanged`, so an open settings window refreshes.
2. For each element key, the layout's `{ anchor, x, y }`:
   - An element that Layout has registered (`Layout.Get(key)` is not `nil`) moves at once through `Layout.Update(key, position, "setup")`.
   - Every other element, and any that `Layout.Update` refuses, is written into the profile's layout table (`Store.Layout()[key]`). Other fields, such as a size or a shown rule, stay as they are. The modules place these elements after the reload.
3. It turns `setupSeen` on and logs the layout, the counts and the modules switched on and off to the devlog.

It returns `false` for an unknown layout, or before the saved data loads.

## Functions

| Function | Behaviour |
| --- | --- |
| `Open() -> boolean` | Opens the window on the welcome step with fresh choices. Refused before the saved data loads. |
| `Apply(choice) -> boolean` | See above |
| `Choice()`, `NewChoice()` | The window's current choice, and a fresh one: DPS and every available module on |
| `Available(name) -> boolean` | The module's addon loaded and registered. For `Icons`, also that `KstyleUI_Icons` exists. |
| `Go(step)`, `Step()` | Moves to a step, 1 to 4, and reports the current one |
| `IsShown() -> boolean` | True from `Open` until the window starts to close, so a reopen during the closing fade shows it again and the first-login timer never resets a setup the player opened |
| `MarkSeen()`, `Closed(applied)` | Turn the account switch on. `Closed` also prints the `/kstyle setup` hint. |
| `PICKER` | `{ { name, label, note }, ... }` in the picker's order |
| `window` | The panel, once it has been built. Fields: `steps`, `pages`, `cards`, `toggles`, `summary`, `back`, `skip`, `next`, `apply`, `reload` and `later`. |

## Why

- The setup never calls a protected function. Modules start through `Modules`, which queues them in combat. The reload is the kit's secure macro button, because `ReloadUI()` is blocked for addons.
- Positions for elements that are not registered yet go straight into the profile's layout table. Most modules are switched on by this same Apply and register only after the reload, and the Layout service reads that table when an element registers.
