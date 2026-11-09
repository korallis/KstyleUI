# KstyleUI_Bags

Combined bags and bank in Lumen sections, keyring, a search grammar, custom categories, other characters' counts in tooltips, sort, quality borders and selling junk.

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
| `Data.lua` | `ns.Data`: the bags that exist, what a slot holds, junk, item levels, item categories (built-in and custom), the search grammar and its matches, free slots and grid maths. No frames. |
| `Settings.lua` | `ns.Settings`: the defaults, the settings page and checked reads |
| `Slot.lua` | `ns.Slot`: one item slot, Blizzard's `ContainerFrameItemButtonTemplate` dressed as a KstyleUI tile |
| `Window.lua` | `ns.Window`: a glass panel with search, sort, slot grids per section or per item category under Lumen section caps in one height-bounded scrolling viewport, and a footer |
| `Blizzard.lua` | `ns.Blizzard`: the secure hooks on Blizzard's bag functions and the hiding of Blizzard's bag frames |
| `Junk.lua` | `ns.Junk`: selling junk at a merchant |
| `Inventory.lua` | `ns.Inventory`: the bag window |
| `Bank.lua` | `ns.Bank`: the bank window |
| `Alts.lua` | `ns.Alts`: each character's item counts, scanned into KstyleUI's account data and shown in item tooltips |
| `Preview.lua` | The settings window's live preview |
| `Module.lua` | Registers the module, its settings page and preview, its events and callbacks, and its `/kstyle test` check; follows the interface style |

Tests: `Tools/regression/test-bags-data.lua`, `test-bags-window.lua`, `test-bags-hooks.lua`, `test-bags-bank.lua`, `test-bags-junk.lua`, `test-bags-alts.lua` and `test-bags-gamepad.lua`, which load the module through `Tools/regression/bags_env.lua`, a fake inventory with Blizzard's open and close functions.

## The bag window

One glass window holds the backpack, the four bags and the reagent bag, and the keyring in its own section under them. The title bar has the close button; Escape closes the window too. Under the title sit the search field and the Sort button. The footer shows the free bag slots (the keyring does not count) and the player's money, through `GetMoneyString`, or as `123g 45s 67c` on a client without it.

With `layout` at `categories` (the default), the bag slots sort into sections by item type, each under a Lumen section cap (`Widgets.SectionCap`: gem, tracked caption, gilt rule and the count of slots in it): Equipment (weapons and armour), Consumables, Trade goods (trade goods, gems, reagents, enhancements, recipes and glyphs), Quest, Other, Junk (a poor item with a sell value, whatever its class) and Empty. `Data.CATEGORIES` holds the built-in order and labels; `Data.Categories()` puts the custom categories (below) in front of them. `Data.Category(record)` tries each custom rule first, then places a slot from `C_Item.GetItemInfoInstant`'s class, or in Other when the class is missing or secret. A section with nothing in it is never built. Each section is a grid of the window's columns; every slot's item button keeps a parent frame that carries its bag's ID, under the section's grid, so Blizzard's `GetBagID` still reads the right bag, and a slot whose item changes category moves to its new section's bag frame on the next refresh, out of combat (`Widgets.MayMove`; in combat the move waits for `Combat.Queue`). With `layout` at `grid`, every bag slot sits in one grid.

**Empty slots.** With `emptySlots` at `packed` (the default), the Empty section shows one empty slot per bag, so there is always somewhere to drop an item into each bag, and its cap counts every free slot; the other empty slots' buttons stay hidden. `all` shows every empty slot.

**The viewport.** The sections stack inside one clipping viewport (`win.viewport` holding `win.stack`), with the search row above it and the footer below it, so both stay reachable however many sections there are. The viewport's height is the stack's height, bounded by `rows` when it is above 0 (that many slot rows plus one cap) and always by the screen: the root frame's height in the window's own units, less the window's chrome and a 48-unit margin (`SCREEN_MARGIN`). The mouse wheel over the viewport scrolls the stack one slot row at a time and stops at both ends. The one grid of the `grid` layout is bounded the same way: `rows` caps its visible rows, the screen caps them again, and it scrolls when it shows fewer rows than it has. `test-bags-window.lua` reproduces a 100-slot, four-column, two-row inventory on a 1080 screen and fails if the window is ever taller than the screen. The window is always at least `columns` slots wide in the category layout, so sections do not change its width as counts change.

**Custom categories.** Up to three custom categories (`custom1` to `custom3`, each a name and a rule) come before the built-in sections, in their slot order. A rule is a search (the grammar below); an item the rule matches lands in that section. A category without a name or without a rule is not listed; a rule that matches nothing claims nothing. Renaming a category renames its cap on the next refresh.

| Element key | Label | Default position | Layout |
| --- | --- | --- | --- |
| `bags.inventory` | Bag window | `BOTTOMRIGHT`, x -16, y 134: above the bag bar | Scalable. Its size follows the slot settings. |

Drag the window by its title bar to move it. The drop saves the position through `Layout.Update` against the anchor the element already has, so a window anchored at the bottom right keeps growing up and to the left.

Each slot shows:

- The item's icon, masked to the kit's chamfer, inside the kit's icon chrome (`Widgets.IconChrome`): the near-black `buttonFill` body every square icon shares, at 55% alpha for an empty slot. The icon is the item's file ID through `SetTexture`; the repainted icons reach it through the loose-file icon pack the client loads ([`docs/icons.md`](../docs/icons.md)).
- The tile's hairline in the item's quality colour (`Theme.QualityColor`) from the chosen quality up; otherwise the accent rim an action button rests on (`Widgets.IconRim`), and the plain grey hairline for an empty slot. Under the mouse the hairline eases to the accent.
- The stack count at the bottom right and the item level of weapons and armour at the bottom left, in the item's quality colour.
- A gold dot at the top right on junk: a poor item that sells for money.
- A pulsing accent glow on a new item, until the pointer touches it or the window closes. Closing the window clears the new marks, as Blizzard's bags do.
- A dimmed icon for an item that does not match the search, and a grey icon while an item is locked.
- The item's cooldown, as a chamfered swipe.

Search is a small grammar, compiled once per text by `Data.Compile` and matched by `Data.Matches`. A plain term matches part of the item's name, type or subtype, as before; spaces inside a term are literal, so `minor heal` is one phrase. `&` needs both sides, `|` needs either, `!` negates, and brackets group: `weapon | armor & !leather`. `&` binds tighter than `|`. An unfinished expression (`sword &`, `(sword`) matches what it can; an expression with no term matches nothing. Keywords, when a term is exactly the word: `junk`, `new`, `bound`, `unbound`; the quality names `poor` to `legendary`; the category words `equipment`, `gear`, `consumable(s)`, `trade`, `tradegoods`, `reagent(s)`, `quest` and `other` (the built-in category, before any custom rule). `type:` or `t:` searches the type and subtype only, `name:` or `n:` the name only. `ilvl>30`, `ilvl>=30`, `ilvl<40`, `ilvl<=40`, `ilvl=35`, `ilvl:35` and `ilvl:30-40` compare the item level of weapons and armour (`#` is short for `ilvl`: `#>30`, `#30-40`); an item without a level never matches a level search. An empty slot never matches any search. Sort asks the game to sort the bags with `C_Container.SortBags`, after `C_Container.SetSortBagsRightToLeft` sets the chosen direction. In combat the sort waits for `Combat.Queue` and says so in chat.

## Selling junk

At a merchant, a Sell junk button shows in the bag window's header while there is junk to sell. With Sell junk by itself on, junk sells as soon as a merchant opens.

1. The sale goes through `KstyleUI.Combat.Queue`: out of combat it runs at once; in combat it waits for `PLAYER_REGEN_ENABLED` and chat says so. Each sale belongs to one merchant visit: when the queue or a later batch runs, it sells nothing if that visit ended, even if another merchant is open by then.
2. The preferred path is `C_MerchantFrame.SellAllJunkItems`, the game's own one-call sale, when `C_MerchantFrame.IsSellAllJunkEnabled` allows it. The devlog records it.
3. Without it, the module sells junk itself with `C_Container.UseContainerItem`, ten items at a time, 0.25 seconds apart, and logs that it took this path. Each batch checks combat and the merchant again. Junk is a poor item with a sell value. The keyring is never sold from, and bags marked to keep their junk (`C_Container.GetBackpackSellJunkDisabled`, `C_Container.GetBagSlotFlag` with `Enum.BagSlotFlags.ExcludeJunkSell`) are skipped.

The button counts junk with `C_MerchantFrame.GetNumJunkItems`, or by reading the bags when the game has no count.

## The bank window

A second glass window shows the bank while the player visits a banker. It is built from the same window and slots as the bag window.

| Element key | Label | Default position | Layout |
| --- | --- | --- | --- |
| `bags.bank` | Bank window | `TOPLEFT`, x 60, y -110: where Blizzard's bank opens | Scalable. Its size follows the slot settings and Bank columns. |

- **Sections.** The bank's slots sort into the same sections as the bags, under the same caps, with the same search, custom categories, packed empty slots and viewport; with `layout` at `grid` the bank is one grid too.
- **Bank types.** The sections hold every purchased tab of the chosen bank type, from `C_Bank.FetchPurchasedBankTabIDs`. When the player can view both the character bank and the Warband bank (`C_Bank.CanViewBank`), tabs above the search field switch between them.
- **Bank bags.** On Forever a bank type's tabs after the first are bank bag slots that hold bags (`C_Bank.ShouldUsePlayerBagsInBank`). A row of small slots under the search field shows each bought bank bag slot of the chosen bank type with its bag. Clicking or dragging picks the bag up or puts one in, with `C_Container.PickupContainerItem` on `Enum.BagIndex.Characterbanktab` or `Accountbanktab`, out of combat only. The tooltip is `GameTooltip:SetBagItem`.
- **Late item data.** `GET_ITEM_INFO_RECEIVED` refreshes an open window 0.2 seconds later, once however many arrive, so item levels and searches catch up with items the client had not cached. `BAG_UPDATE_COOLDOWN` updates both windows' cooldowns.
- **Buy tab.** The Buy tab button is Blizzard's `BankPanelPurchaseButtonScriptTemplate`, the template Blizzard provides for addons, with the `overrideBankType` attribute set to the chosen bank type. Its click runs Blizzard's own confirmation. It shows while `C_Bank.CanPurchaseBankTab` is true, which includes a new character's free first tab.
- **Deposit all.** Shown for a bank type that `C_Bank.DoesBankTypeSupportAutoDeposit` allows; it calls `C_Bank.AutoDepositItemsIntoBank` through `Combat.Queue`.
- **Sort** calls `C_Container.SortBank(bankType)`, or `SortBankBags` and `SortAccountBankBags` on a client without it.
- **Depositing by right-click** goes through Blizzard's item button, which deposits into the bank type Blizzard's own bank panel has selected: the character bank. Drag items to the Warband bank.

The window opens on `BANKFRAME_OPENED`, and on `PLAYER_INTERACTION_MANAGER_FRAME_SHOW` for a banker if that event comes first, and opens the bag window beside it while Bank opens bags is on. `BANKFRAME_CLOSED` closes it, and the bags too when the bank opened them. Closing the bank window by its close button or Escape ends the visit with `C_Bank.CloseBankFrame`.

`BankFrame` goes under the hidden parent at `Enable`, before it ever shows, because Blizzard shows it with `ShowUIPanel` when a visit starts. Moving a shown `BankFrame` would run its `OnHide`, which ends the visit, so:

- Turning the module on during a visit leaves Blizzard's bank for that visit and hides it when the visit ends.
- Turning the module off during a visit ends the visit and gives Blizzard its bank back when `BANKFRAME_CLOSED` arrives.
- With Replace bank off, Blizzard's bank stays. A change to Replace bank takes effect after `/reload`, and the module asks for one.

## Other characters' counts

`Alts.lua` keeps each character's item counts in KstyleUI's own saved data, `KstyleUIDB.account.inventory` (never another addon's): `{ version = 1, characters = { ["Realm-Name"] = { name, realm, class, seen, bags = { [itemID] = count }, bank = { [itemID] = count } } }, warband = { [itemID] = count } }`. Only plain numbers go in: a secret item ID or stack count is skipped (`Data.Read` turns secrets into nil).

- **Scanning.** At `Enable` the character is recorded with its name, realm and class token and its bags are counted (the keyring is not). `BAG_UPDATE_DELAYED` and `BAG_CONTAINER_UPDATE` count the bags again half a second later, once however many arrive; `PLAYER_LOGOUT` and `Disable` count them one last time. The bank is counted on `BANKFRAME_OPENED` and on `BANK_TABS_CHANGED`, `PLAYERBANKSLOTS_CHANGED` and `PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED` during a visit, through `Bank.Tabs(kind)`: the character bank into the character's `bank`, the Warband bank into the account's `warband`. A character not seen for 60 days is dropped at `Enable`, which keeps the table small.
- **Tooltips.** `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, ...)` adds one double line per character that holds the item (name in its class colour; `12 in bags, 5 in bank`), this character first with its bank count only, then the others by name, then `Warband bank`. At most eight lines; the rest fold into `n more characters` with their total. The item ID is `data.id`, or `C_Item.GetItemInfoInstant` on `data.hyperlink`; a secret ID adds nothing. Without `TooltipDataProcessor` the counts still scan and the devlog says the lines are unavailable. `altCounts` turns the lines off.

## Opening and closing

The window follows Blizzard's own bag functions, so every key binding, the bag bar, merchants, mail and other windows that open the bags open it too.

1. The first time the module runs in the keyboard and mouse style, it calls `hooksecurefunc` on `ToggleAllBags`, `ToggleBackpack`, `ToggleBag`, `OpenAllBags`, `OpenBackpack`, `OpenBag`, `CloseAllBags`, `CloseBackpack` and `CloseBag`. The hooks stay for the session and do nothing while the module is off.
2. A hook records what the call meant (toggle, open or close) and waits for the next frame, so the calls Blizzard's functions make to each other settle first. The last call of the frame wins: that is the outermost call.
3. A toggle opens the window when it is closed and Blizzard allows bags (`ContainerFrame_AllowedToOpenBags`), and closes it when it is open.
4. An open opens the window when Blizzard's own state says the bags are open, so a refused open stays closed.
5. A close closes the window only when Blizzard's own state says the bags are closed, so `CloseAllBags(frame)` from a window that did not open the bags leaves them open, as in Blizzard's UI.

`Safe.HideBlizzard` reparents `ContainerFrameCombinedBags` and `ContainerFrameContainer`, which holds the single bag frames `ContainerFrame1` and up, to a hidden frame. Blizzard keeps opening and closing them there, unseen.

When the window closes by its close button or Escape, `Blizzard.Release` hides each Blizzard bag frame that is shown but not visible, so Blizzard's state matches the window and the next key press opens the bags at once.

## Combat

The window opens, closes, searches and refreshes in combat: the item buttons are not protected, and moving or hiding one taints nothing. Making one is different: an item button made in lockdown cannot use items. So the module makes every slot's button out of combat, at `Enable` and whenever a bag changes, and a slot that appears in combat waits for `Combat.Queue`.

## Gamepad

Forever's gamepad style navigates Blizzard's bags and bank with the D-pad, and its bag buttons call `ToggleAllBags` and `ToggleBackpack_Combined`. KstyleUI's window does not support the D-pad, so the module stands down while the gamepad style is on: it hides nothing, its hooks and its events stay inert, and it logs that it stood down.

- **At `Enable`.** When `InputUtil.IsGamepadUIEnabled()` returns true, the module stands down at once.
- **A switch to the gamepad style.** `Enable` registers `INPUT_DEVICE_INTERFACE_TRANSITION` before anything else, so the module hears the switch even when it started standing down. The switch closes KstyleUI's bag and bank windows, closes Blizzard's hidden bag frames with `Blizzard.Release`, gives Blizzard back `ContainerFrameCombinedBags`, `ContainerFrameContainer` and `BankFrame`, and unregisters the module's events. During a bank visit KstyleUI's bank was serving, the switch ends the visit and `BankFrame` returns when `BANKFRAME_CLOSED` arrives, as when the module turns off.
- **A switch back to the keyboard and mouse style.** The module takes Blizzard's bags and bank again and registers its events, as `Enable` does, without a reload.
- **Combat.** Each switch waits for `Combat.Queue`. Until combat ends, the style the module had keeps serving the bags. The queued work reads the style when it runs, so several switches in one fight end in the style the player chose last.

## Settings

| Key | Default | Row |
| --- | --- | --- |
| `enabled` | `false` | toggle |
| `layout` | `categories` | dropdown: sections by item type, or one grid |
| `emptySlots` | `packed` | dropdown: one empty slot per bag in the Empty section, or every empty slot |
| `columns` | 10 | slider, 4 to 24 |
| `rows` | 0 | slider, 0 to 20: the rows shown before the grid or the sections' viewport scrolls with the mouse wheel; 0 fits the screen |
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
| `replaceBank` | `true` | toggle; a change takes effect after `/reload` |
| `bankColumns` | 14 | slider, 4 to 24 |
| `bankOpensBags` | `true` | toggle |
| `autoSellJunk` | `false` | toggle: sell junk when a merchant opens |
| `altCounts` | `true` | toggle: other characters' counts in item tooltips |
| `custom1.name`, `custom1.rule` | `""`, `""` | text rows, up to 60 letters; `custom2` and `custom3` the same |

Position, scale, opacity, strata and the shown rule come from Layout, on the Elements page and in Layout Mode. The preview shows eight sample slots drawn by `Slot.lua` with the current settings; it makes no Blizzard item buttons.

## /kstyle test

The `bags` check passes while the module is off or standing down for the gamepad style, and says which. While it runs it fails if the window was not built, Blizzard's combined bags are not hidden, or Blizzard's bank is not hidden while the module replaces it outside a visit; otherwise it reports the number of slots and the bank's state.

## Why

- **Blizzard's item button, not our own.** `ContainerFrameItemButtonTemplate` carries Blizzard's secure click handling: using, equipping, selling at a merchant, depositing at the bank, splitting stacks, socketing and the tooltips. Its `GetBagID` reads the parent frame's ID, so each bag gets its own parent frame with `SetID(bag)` and each button `SetID(slot)`. The module never calls `SetBagID` and never writes fields onto the button: a value written by addon code and read during the click would taint the click and block `UseContainerItem`. The slot's own state lives in a separate Lua table. The template's own art is silenced on our button: the normal, pushed and highlight textures go to alpha 0, and the store highlight `BattlepayItemTexture`, which the template shows by default, is hidden.
- **Hooks, not replacements.** Replacing `ToggleAllBags` or calling Blizzard's open and close functions from addon code would run Blizzard's bag code, and the bag bar's, in KstyleUI's context. The research found that the bag bar tree is shown and hidden on the way to protected calls, so tainting it breaks other things. `hooksecurefunc` runs after Blizzard's function and leaves it untouched.
- **Hidden, not hooked on show.** Blizzard's bag frames move under a hidden parent through `Safe`, so their `OnShow` and `OnHide` never run while the module is on: no Blizzard bag code runs for frames nobody sees. The one exception, `Blizzard.Release`, calls `Hide` on frames that are already invisible, which runs none of their scripts. The taint allow-list in `Tools/regression/taint_allow/KstyleUI_Bags.lua` records it.
- **The next frame, not at once.** `ToggleAllBags` calls `CloseBackpack`, `CloseBag` and `OpenBackpack` itself, and each of those is hooked too. Deciding at the end of the frame, with the last call winning, acts on the outermost call only.
- **Toggles use the window's state, opens and closes use Blizzard's.** After the player closes the window by its own button, Blizzard's state would say open; a toggle that read Blizzard's state would need two key presses. Releasing Blizzard's frames on close keeps the two in step, and the toggle reads the window's own state anyway.
- **Buttons made out of combat.** An item button made in combat lockdown is tainted for good and cannot use items, so every slot is made at `Enable` or when combat ends.
- **The game sells junk.** `C_MerchantFrame.SellAllJunkItems` sells every junk item in one server call, as Blizzard's own merchant button does. Selling item by item is kept only as a fallback, in small batches, because the server throttles rapid sales and the buyback list keeps the last twelve.
- **The server sorts.** `C_Container.SortBags` sorts on the server in one call. Moving items one by one from Lua would need protected pickups in a loop and could be interrupted by combat.
- **Blizzard's purchase template, not our own purchase call.** `C_Bank.PurchaseBankTab` is restricted, and Blizzard's confirmation popup reads the bank type it is given. Blizzard ships `BankPanelPurchaseButtonScriptTemplate` for addons, so the click starts in Blizzard's code and the purchase stays untainted.
- **The bank waits for the visit to end.** `BankFrame:OnHide` calls `C_Bank.CloseBankFrame`, so reparenting a shown bank would end the player's visit and run Blizzard's bank code in KstyleUI's context. Every change to the bank's parent happens while it is closed.
- **Scalable, not resizable.** The window's size follows its columns, slot size and spacing, so Layout owns only its scale. A resizable window would need a second source for the column count.
