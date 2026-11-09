# Setup

`KstyleUI.Setup` is the first-run setup: four steps that pick a layout and the modules, then apply both and offer a reload. The spec's [Settings and first-run setup](../../docs/superpowers/specs/2026-11-07-kstyleui-design.md#settings-and-first-run-setup) section is binding. `Core/Setup/Setup.xml` loads the files in this order:

| File | What it holds |
| --- | --- |
| `Layouts.lua` | `Setup.Layouts`: the element keys and the Lumen DPS, Tank and Healer layouts: positions, footprints, the module settings each writes and the story slot. See [`element-keys.md`](../../docs/superpowers/plans/element-keys.md). |
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
2. **Layout.** One card per layout on the button grade's body: a 16:9 preview, a glass panel at the tile chamfer with the drop shadow, that draws each element the layout shows at its Lumen footprint (`Layouts.Footprint`, `Layouts.Shown`) and outlines the story slot in the accent, the layout's name and its one-line note. The line under the cards names the outline, the **Story rail**, and says what goes there. A click picks the card: an `accent` hairline, a selection glow and an `accent` preview. DPS is picked first.
3. **Modules.** A toggle and a one-line note for each module in `Setup.PICKER`, with **All on** and **All off**. Every module whose addon loaded starts on. A module whose addon did not load is off, disabled and says so. The settings window is not in the list: it loads on demand.
4. **Summary.** The layout and the modules that will be on and off, then **Apply**. After Apply, the secure **Reload** button and **Later**. Changing a choice afterwards shows **Apply** again.

## Apply

`Setup.Apply(choice)` with `choice = { layout, modules = { [name] = boolean } }`:

1. For each module in the picker whose addon loaded, `Options.Write(name, "enabled", value)`. Writing through `Options` starts or stops the module through `Modules`, waiting for the end of combat if needed, and fires `SettingChanged`, so an open settings window refreshes.
2. For each element key, the layout's `{ anchor, x, y }`:
   - An element that Layout has registered (`Layout.Get(key)` is not `nil`) moves at once through `Layout.Update(key, position, "setup")`.
   - Every other element, and any that `Layout.Update` refuses, is written into the profile's layout table (`Store.Layout()[key]`). Other fields, such as a size or a shown rule, stay as they are. The modules place these elements after the reload.
3. For each `{ module, key, value }` in `Layouts.Settings(layout)` whose module loaded and has that setting, `Options.Write(module, key, value)`: bars 2 to 6 off and bar 1 one row, the pet and stance sockets in two rows of five, the threat card on in Tank only, one row of buffs in the Blessings card with the debuffs docked, the menu and bags docked in the readout card, the raid in four groups a row at 77 units wide, and the party and raid row heights (Healer's are larger). The positions carry `Layouts.Sizes(layout)` too: the meters' heights. Settings of a module that did not load are skipped and counted.
4. `Options.Write("Layout", "preset", layout)`, so Layout Mode outlines that layout's story slot.
5. It turns `setupSeen` on and logs the layout, the counts and the modules switched on and off to the devlog.

It returns `false` for an unknown layout, or before the saved data loads.

## Functions

| Function | Behaviour |
| --- | --- |
| `Open() -> boolean` | Opens the window on the welcome step with fresh choices. Refused before the saved data loads. |
| `Apply(choice) -> boolean` | See above |
| `Choice()`, `NewChoice()` | The window's current choice, and a fresh one: DPS and every available module on |
| `Available(name) -> boolean` | The module's addon loaded and registered. |
| `Go(step)`, `Step()` | Moves to a step, 1 to 4, and reports the current one |
| `IsShown() -> boolean` | True from `Open` until the window starts to close, so a reopen during the closing fade shows it again and the first-login timer never resets a setup the player opened |
| `MarkSeen()`, `Closed(applied)` | Turn the account switch on. `Closed` also prints the `/kstyle setup` hint. |
| `PICKER` | `{ { name, label, note }, ... }` in the picker's order |
| `window` | The panel, once it has been built. Fields: `steps`, `pages`, `cards`, `toggles`, `summary`, `back`, `skip`, `next`, `apply`, `reload` and `later`. |

## Why

- The setup never calls a protected function. Modules start through `Modules`, which queues them in combat. The reload is the kit's secure macro button, because `ReloadUI()` is blocked for addons.
- Positions for elements that are not registered yet go straight into the profile's layout table. Most modules are switched on by this same Apply and register only after the reload, and the Layout service reads that table when an element registers.

## The Lumen layouts

DPS, Tank and Healer place every element on the Lumen Rails: two 318-unit rails on a 28-unit margin, the hands at the bottom centre and the target sigil at the top. `test-setup-layouts.lua` holds the rules.

- **Left rail:** the party card (the raid card in a raid) at the top, chat at the foot, and between them the story slot for the RestedXP guide and the quest tracker, which KstyleUI cannot move. The setup's cards and Layout Mode outline the slot.
- **Right rail:** the lens card, the Blessings card (one row of buffs, the debuffs docked under them), room for one boss card, the damage card, the threat card (Tank only, under a two-row damage card), and the readout card with the menu docked under it at the foot. Cards sit 16 to 22 units apart.
- **Centre:** the XP line 52 units up with its caption under it on the 34-unit margin, bar 1 12 units over it, the vitals line 12 over bar 1, the class resource, the essential cooldowns with the utility row and the tracked buffs beside them, the cast bar and the swing timer, then bar 2's place. The pet and stance sockets sit beside bar 1's ends, with the reputation and honour lines under them on the XP line's baseline. The sigil sits 40 units under the top with its cast bar and the target of target under it. The focus card sits at mid-left, beside the left rail. The world between, 520 units wide, stays clear.
- **Healer** uses the same columns with larger party and raid frames. **Tank** adds the threat card.

| Function | Behaviour |
| --- | --- |
| `Footprint(name, key) -> width, height` | The size the layout places the element by: the layout's own size (Healer's group frames, Tank's meters), else the element's reserve (`Reserves`), else its footprint |
| `Shown(name, key) -> boolean` | Whether the layout switches the element on |
| `Settings(name) -> { { module, key, value }, ... }` | The module settings Apply writes |
| `Slot(name) -> { key, anchor, x, y, width, height, raid, label, hint, raidHint }` | The story slot, as a position with a size. `raid` is how far the raid card, taller than the party card, reaches down into the slot in a raid; a 1080-unit rail has no room to keep them apart. |
| `Sizes(name) -> { [key] = { width, height } }` | The sizes Apply writes through Layout with the positions: the meters' heights (six damage rows, or in Tank two damage rows over two threat rows) |
| `Dock(key) -> hostKey` | The card a docked element sits in: the debuff row in the Blessings card, the micro menu and the bag bar in the readout card. Not live while docked; its position is inside the host, where it stays when the player undocks it |
| `Reserves() -> { { key, width, height }, ... }` | The room the layouts keep for an element whose frame is another size: the sigil's 126 (its debuff sockets hang under its 80-unit frame) and the boss card's 120 (the rail has room for one of the five) |

Saved layouts stay as they are until the player applies a layout again. A profile that never stored a position gets the Lumen DPS position from `Layouts.Default`.
