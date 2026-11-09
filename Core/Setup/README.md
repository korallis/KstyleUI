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
3. For each `{ module, key, value }` in `Layouts.Settings(layout)` whose module loaded and has that setting, `Options.Write(module, key, value)`: bars 2 to 6 off and bar 1 one row, the pet and stance sockets in two rows of five, the threat card on in Tank only, one row of buffs in the Blessings card with the debuffs docked, the menu and bags docked in the readout card, the raid in four groups a row at 77 units wide, and the party and raid row heights (Healer's are larger, with two dispellable debuffs first). The positions carry `Layouts.Sizes(layout)` too: the meters' heights. Settings of a module that did not load are skipped and counted.
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

DPS, Tank and Healer place every element on the Lumen Rails: two 318-unit rails on a 28-unit margin and one combat cluster at the bottom centre: the hands, and right on them your target, its target and your focus. `test-setup-layouts.lua` holds the composition rules; `test-setup-collisions.lua` resolves every layout at 16:9, 16:10 and 21:9 and fails on any element off screen or overlapping another, each at the full footprint it draws.

- **Left rail:** the party card (the raid card in a raid) at the top, chat at the foot, and between them the story slot for the RestedXP guide and the quest tracker, which KstyleUI cannot move. The setup's cards and Layout Mode outline the slot. Chat is 260 tall, so the slot holds the guide and three quests.
- **Right rail:** the lens card, the Blessings card (one row of buffs, the debuffs docked under them), the damage card, and the readout card with the menu docked under it at the foot. Cards sit 16 to 22 units apart. The tooltip anchor lies on the readout card, so a fixed tooltip covers the idle readout and grows up the rail, never over the hands, your combat text or the bosses.
- **Enemy, at the top:** the sigil 40 units under the top with its cast bar and the target of target under it, and the boss column 16 units in from the right rail and 16 under the target of target: five compact cards and their debuffs, clear of the meters at every aspect.
- **Centre:** the XP line 52 units up with its caption under it on the 34-unit margin, bar 1 12 units over it, the vitals line 12 over bar 1, the class resource, the essential cooldowns with the swing line 6 units over them and the utility row and the tracked buffs beside them. The pet and stance sockets sit beside bar 1's ends, with the reputation and honour lines under them on the XP line's baseline.
- **Combat cluster:** right on that block (13 units over the tracked buff bars) the target sigil, 490 wide like the vitals line, its debuff sockets under it; the focus card 12 units to its left, top-aligned, its target under it; the target of target 12 units to its right, top-aligned. Bar 2 and the plate cast bars, for a player who turns them on, stack 8 units over the cluster. Your combat text rises right of the cluster, under the boss column, which heads the centre's right edge 16 units in from the right rail. The world over the cluster, 520 units wide, stays clear.
- **Tank** brings the threat card into the cluster, 200 by 112 under the target of target.
- **Healer** stands the party and raid on the cluster's left half: their right edge 116 units off the centre line (the character's column stays clear), their foot 16 units over the cluster. Rows are 46 units and up to two dispellable debuffs show first on each frame. The damage card heads the left rail over the story slot, the boss column takes the damage card's place on the right rail, the spare bars 3 to 6 stand left of the right rail, bar 2 and the plate cast bars wait at the top centre, and your combat text rises just right of the character's column.
- **Spare bars:** bars 2 to 6 are off in every layout. Bar 2 waits on the hands block; bars 3 to 6 are columns beside the rails, apart from everything at 16:9, 16:10 and 21:9. On a narrower screen (the 16:10.3 MacBook) a column of bar 3 or 4 touches the sigil, so a player who turns one on there places it.

### Why the target stays at the top

The sigil at the top and the vitals at the bottom are a full screen-height apart, and one judge asked for the target next to the player. Lumen keeps the split and closes the gap in two ways:

- The enemy's side is one place. The sigil, the target of target and the boss column all sit in the top band, so a pull reads as "them above, me below", and the boss you target is marked on its card instead of drawn twice.
- The read you need mid-pull is already at the centre. The target's nameplate carries its health and cast bar beside the character, where the eye is; the sigil is the large, calm read of the same target. The hands keep everything about you within 300 units of the bottom.

A player who wants the classic placement moves the sigil in Layout Mode; it is one element, and the layouts never move it again until a layout is applied.

| Function | Behaviour |
| --- | --- |
| `Footprint(name, key) -> width, height` | The size the layout places the element by: the layout's own size (Healer's group frames, Tank's threat card), else the element's reserve (`Reserves`), else its footprint |
| `Shown(name, key) -> boolean` | Whether the layout switches the element on |
| `Settings(name) -> { { module, key, value }, ... }` | The module settings Apply writes |
| `Slot(name) -> { key, anchor, x, y, width, height, raid, label, hint, raidHint }` | The story slot, as a position with a size: from 16 under the left rail's head (the party card, or Healer's damage card) to 16 over chat. `raid` is how far the raid card, taller than the party card, reaches down into the slot in a raid (a 1080-unit rail has no room to keep them apart); 0 in Healer, whose raid stands on the cluster, and then there is no `raidHint`. |
| `Sizes(name) -> { [key] = { width, height } }` | The sizes Apply writes through Layout with the positions: the meters' sizes (six damage rows; in Tank the threat card at 200 by 112 in the cluster) |
| `Dock(key) -> hostKey` | The card a docked element sits in: the debuff row in the Blessings card, the micro menu and the bag bar in the readout card. Not live while docked; its position is inside the host, where it stays when the player undocks it |
| `Reserves() -> { { key, width, height }, ... }` | The room the layouts keep for an element whose frame is another size: the sigil's 126 (its debuff sockets hang under its 80-unit frame) and the boss column's 318 (its debuffs hang left of its 258-unit cards). A reserve is never smaller than its element |

Saved layouts stay as they are until the player applies a layout again. A profile that never stored a position gets the Lumen DPS position from `Layouts.Default`.
