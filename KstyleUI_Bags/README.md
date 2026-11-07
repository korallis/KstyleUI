# KstyleUI_Bags

Combined bags and bank, keyring, search, sort, quality borders and selling junk.

| Field | Value |
| --- | --- |
| Module name | `Bags`: its switch in `Core/Features.lua` and the `name` it registers with `KstyleUI.Modules.Register` |
| Approach | Replace |
| Loads | With the core addon, switched off until the player turns it on |
| Files | `KstyleUI_Bags.toc` lists `Bags.xml`, which loads every Lua file in order, so adding a file never edits the TOC |

## Rules

These come from the [design spec](../docs/superpowers/specs/2026-11-07-kstyleui-design.md). The roadmap's Global Constraints and [AGENTS.md](../AGENTS.md) apply too.

- Protected container calls such as `C_Container.UseContainerItem` and `C_Container.PickupContainerItem` go through `KstyleUI.Combat.Queue` in combat.
- Windows handle Escape with their own key handler, not `UISpecialFrames`.
- Blizzard frames this module replaces are hidden only through `KstyleUI.Safe.HideBlizzard`.
- At load the module only registers itself with `KstyleUI.Modules.Register`. It creates no frames, registers no events and installs no hooks until `Enable` runs. `test-modules-load.lua` checks the frames.
- Every element it shows registers with `KstyleUI.Layout.Register`, and every setting is declared through `KstyleUI.Options.Register`, so the player can resize and customise everything from the settings window.
- UI comes from `KstyleUI.Widgets`, colours from `KstyleUI.Tokens` and strings from `KstyleUI.L`. Translations go in `Locale.lua` in this folder, loaded by `Bags.xml`.
- Build mode: check that an API exists before calling it, check `issecretvalue` before any comparison, fall back to a safer path when the preferred one is unavailable, and log the path taken with `KstyleUI.DevTest.Log`.

## Files

`Bags.xml` loads them in this order.

| File | What it holds |
| --- | --- |
| `Init.lua` | The addon table, `ns.On(event, fn)` (the module's event list) and `ns.Log(message)` (devlog lines under `Bags`) |
| `Locale.lua` | `ns.L`, the core's locale table |
| `Data.lua` | `ns.Data`: the bags that exist, what a slot holds, junk, item levels, search matches, free slots and grid maths. No frames. |
| `Settings.lua` | `ns.Settings`: the defaults, the settings page and checked reads |
| `Slot.lua` | `ns.Slot`: one item slot, Blizzard's `ContainerFrameItemButtonTemplate` dressed as a KstyleUI tile |
| `Window.lua` | `ns.Window`: a glass panel with search, sort, slot grids per section and a footer |
| `Blizzard.lua` | `ns.Blizzard`: the secure hooks on Blizzard's bag functions and the hiding of Blizzard's bag frames |
| `Inventory.lua` | `ns.Inventory`: the bag window |
| `Preview.lua` | The settings window's live preview |
| `Module.lua` | Registers the module, its settings page and preview, its events and callbacks, and its `/kstyle test` check |

Tests: `Tools/regression/test-bags-data.lua`, `test-bags-window.lua` and `test-bags-hooks.lua`, which load the module through `Tools/regression/bags_env.lua`, a fake inventory with Blizzard's open and close functions.

## The bag window

One glass window holds the backpack, the four bags and the reagent bag in one grid, and the keyring in a second grid under them. The title bar has the close button; Escape closes the window too. Under the title sit the search field and the Sort button. The footer shows the free bag slots (the keyring does not count) and the player's money.

| Element key | Label | Default position | Layout |
| --- | --- | --- | --- |
| `bags.inventory` | Bag window | `BOTTOMRIGHT`, x -16, y 134: above the bag bar | Scalable. Its size follows the slot settings. |

Drag the window by its title bar to move it. The drop saves the position through `Layout.Update` against the anchor the element already has, so a window anchored at the bottom right keeps growing up and to the left.

Each slot shows:

- The item's icon, masked to the kit's chamfer, inside a raised tile.
- The tile's hairline in the item's quality colour (`Theme.QualityColor`) from the chosen quality up. Under the mouse the hairline eases to the accent.
- The stack count at the bottom right and the item level of weapons and armour at the bottom left, in the item's quality colour.
- A gold dot at the top right on junk: a poor item that sells for money.
- A pulsing accent glow on a new item, until the pointer touches it or the window closes. Closing the window clears the new marks, as Blizzard's bags do.
- A dimmed icon for an item that does not match the search, and a grey icon while an item is locked.
- The item's cooldown, as a chamfered swipe.

Search matches the item's name, type and subtype as plain text. Sort asks the game to sort the bags with `C_Container.SortBags`, after `C_Container.SetSortBagsRightToLeft` sets the chosen direction. In combat the sort waits for `Combat.Queue` and says so in chat.

## Opening and closing

The window follows Blizzard's own bag functions, so every key binding, the bag bar, merchants, mail and other windows that open the bags open it too.

1. At the first `Enable` the module calls `hooksecurefunc` on `ToggleAllBags`, `ToggleBackpack`, `ToggleBag`, `OpenAllBags`, `OpenBackpack`, `OpenBag`, `CloseAllBags`, `CloseBackpack` and `CloseBag`. The hooks stay for the session and do nothing while the module is off.
2. A hook records what the call meant (toggle, open or close) and waits for the next frame, so the calls Blizzard's functions make to each other settle first. The last call of the frame wins: that is the outermost call.
3. A toggle opens the window when it is closed and Blizzard allows bags (`ContainerFrame_AllowedToOpenBags`), and closes it when it is open.
4. An open opens the window when Blizzard's own state says the bags are open, so a refused open stays closed.
5. A close closes the window only when Blizzard's own state says the bags are closed, so `CloseAllBags(frame)` from a window that did not open the bags leaves them open, as in Blizzard's UI.

`Safe.HideBlizzard` reparents `ContainerFrameCombinedBags` and `ContainerFrameContainer`, which holds the single bag frames `ContainerFrame1` and up, to a hidden frame. Blizzard keeps opening and closing them there, unseen.

When the window closes by its close button or Escape, `Blizzard.Release` hides each Blizzard bag frame that is shown but not visible, so Blizzard's state matches the window and the next key press opens the bags at once.

## Combat

The window opens, closes, searches and refreshes in combat: the item buttons are not protected, and moving or hiding one taints nothing. Making one is different: an item button made in lockdown cannot use items. So the module makes every slot's button out of combat, at `Enable` and whenever a bag changes, and a slot that appears in combat waits for `Combat.Queue`.

## Gamepad

When `InputUtil.IsGamepadUIEnabled()` returns true at `Enable`, the module stands down: it hides nothing, its hooks stay inert, and it logs that it stood down. Forever's gamepad style navigates Blizzard's bags with the D-pad, which KstyleUI's window does not support. A style change takes effect after `/reload`.

## Settings

| Key | Default | Row |
| --- | --- | --- |
| `enabled` | `false` | toggle |
| `columns` | 10 | slider, 4 to 24 |
| `rows` | 0 | slider, 0 to 20: the rows shown before the grid scrolls with the mouse wheel; 0 shows every row |
| `slotSize` | 34 (`actionButton`) | slider, 24 to 48 |
| `spacing` | 4 (`gapSmall`) | slider, 0 to 12 |
| `growth` | `RIGHT_DOWN` | dropdown: right then down, left then down, right then up, left then up |
| `showCount` | `true` | toggle |
| `showItemLevel` | `true` | toggle |
| `font` | Source Sans 3 Semibold, the `number` font | font |
| `fontSize` | 11 (`number`) | slider, 6 to 20 |
| `fontOutline` | `NONE` | dropdown: soft shadow, thin outline, thick outline |
| `showQuality` | `true` | toggle |
| `qualityMin` | 2, uncommon | dropdown: poor to legendary and better |
| `showNewGlow` | `true` | toggle |
| `showJunk` | `true` | toggle |
| `showKeyring` | `true` | toggle |
| `accentSource` | `class` | dropdown: class colour or custom colour |
| `accentColor` | the kit's accent | colour, shown for a custom accent |
| `sortDirection` | `LEFT` | dropdown: left to right or right to left |

Position, scale, opacity, strata and the shown rule come from Layout, on the Elements page and in Layout Mode. The preview shows eight sample slots drawn by `Slot.lua` with the current settings; it makes no Blizzard item buttons.

## /kstyle test

The `bags` check passes while the module is off or standing down for the gamepad style. While it runs it fails if the window was not built or Blizzard's combined bags are not hidden, and otherwise reports the number of slots.

## Why

- **Blizzard's item button, not our own.** `ContainerFrameItemButtonTemplate` carries Blizzard's secure click handling: using, equipping, selling at a merchant, depositing at the bank, splitting stacks, socketing and the tooltips. Its `GetBagID` reads the parent frame's ID, so each bag gets its own parent frame with `SetID(bag)` and each button `SetID(slot)`. The module never calls `SetBagID` and never writes fields onto the button: a value written by addon code and read during the click would taint the click and block `UseContainerItem`. The slot's own state lives in a separate Lua table. The template's own art is silenced on our button: the normal, pushed and highlight textures go to alpha 0, and the store highlight `BattlepayItemTexture`, which the template shows by default, is hidden.
- **Hooks, not replacements.** Replacing `ToggleAllBags` or calling Blizzard's open and close functions from addon code would run Blizzard's bag code, and the bag bar's, in KstyleUI's context. The research found that the bag bar tree is shown and hidden on the way to protected calls, so tainting it breaks other things. `hooksecurefunc` runs after Blizzard's function and leaves it untouched.
- **Hidden, not hooked on show.** Blizzard's bag frames move under a hidden parent through `Safe`, so their `OnShow` and `OnHide` never run while the module is on: no Blizzard bag code runs for frames nobody sees. The one exception, `Blizzard.Release`, calls `Hide` on frames that are already invisible, which runs none of their scripts. The taint allow-list in `Tools/regression/taint_allow/KstyleUI_Bags.lua` records it.
- **The next frame, not at once.** `ToggleAllBags` calls `CloseBackpack`, `CloseBag` and `OpenBackpack` itself, and each of those is hooked too. Deciding at the end of the frame, with the last call winning, acts on the outermost call only.
- **Toggles use the window's state, opens and closes use Blizzard's.** After the player closes the window by its own button, Blizzard's state would say open; a toggle that read Blizzard's state would need two key presses. Releasing Blizzard's frames on close keeps the two in step, and the toggle reads the window's own state anyway.
- **Buttons made out of combat.** An item button made in combat lockdown is tainted for good and cannot use items, so every slot is made at `Enable` or when combat ends.
- **The server sorts.** `C_Container.SortBags` sorts on the server in one call. Moving items one by one from Lua would need protected pickups in a loop and could be interrupted by combat.
- **Scalable, not resizable.** The window's size follows its columns, slot size and spacing, so Layout owns only its scale. A resizable window would need a second source for the column count.
