# KstyleUI_Bags

Combined bags and bank in Lumen sections, keyring, a search grammar, custom categories, other characters' counts in tooltips and a read-only view of their bags and bank, sort, quality borders and selling junk.

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
- UI comes from `KstyleUI.Widgets`, colours from `KstyleUI.Tokens` and strings from `KstyleUI.L`. Translations live in the core string tables; see Languages in the repository README.
- Build mode: check that an API exists before calling it, check `issecretvalue` before any comparison, fall back to a safer path when the preferred one is unavailable, and log the path taken with `KstyleUI.DevTest.Log`.

## Files

`Bags.xml` loads them in this order.

| File | What it holds |
| --- | --- |
| `Init.lua` | The addon table, `ns.On(event, fn)` (the module's event list) and `ns.Log(message)` (devlog lines under `Bags`) |
| `Locale.lua` | `ns.L`, the core's locale table |
| `Data.lua` | `ns.Data`: the bags that exist, what a slot holds, junk, item levels, item categories (built-in and custom), the search grammar and its matches, free slots, grid maths, pinned item IDs and the footer's currency line. No frames. |
| `Settings.lua` | `ns.Settings`: the defaults, the settings page and checked reads |
| `Slot.lua` | `ns.Slot`: one item slot, Blizzard's `ContainerFrameItemButtonTemplate` dressed as a KstyleUI tile |
| `Window.lua` | `ns.Window`: a glass panel with search, sort, slot grids per section or per item category under Lumen section caps in one height-bounded scrolling viewport, and a footer |
| `List.lua` | `ns.List`: the category list beside a window: its views, the bank's tabs and its sections |
| `Remote.lua` | `ns.Remote`: the read-only view of a saved character's items the picker shows in the bag window |
| `Blizzard.lua` | `ns.Blizzard`: the secure hooks on Blizzard's bag functions and the hiding of Blizzard's bag frames |
| `Junk.lua` | `ns.Junk`: selling junk at a merchant |
| `Inventory.lua` | `ns.Inventory`: the bag window |
| `Bank.lua` | `ns.Bank`: the bank window |
| `Alts.lua` | `ns.Alts`: each character's items, scanned into KstyleUI's account data: the counts tooltips show and the catalogue the picker browses |
| `Preview.lua` | The settings window's live preview |
| `Module.lua` | Registers the module, its settings page and preview, its events and callbacks, and its `/kstyle test` check; follows the interface style |

Tests: `Tools/regression/test-bags-data.lua`, `test-bags-window.lua`, `test-bags-hooks.lua`, `test-bags-bank.lua`, `test-bags-junk.lua`, `test-bags-alts.lua` (counts, tooltips and the picker's read-only view) and `test-bags-gamepad.lua`, which load the module through `Tools/regression/bags_env.lua`, a fake inventory with Blizzard's open and close functions.

## The bag window

One glass window holds the backpack, the four bags and the reagent bag, and the keyring in its own section under them. The title bar has the close button; Escape closes the window too. Under the title sit the search field and the Sort button. The footer shows the free bag slots (the keyring does not count) and the player's money, through `GetMoneyString`, or as `123g 45s 67c` on a client without it.

By default, bags and bank show a fixed grid sized for all purchased slots, including empty sockets. Looting, selling, splitting stacks and sorting keep the window size and physical slot positions; only a change to bag capacity or grid settings changes the geometry. Reagent-bag slots share the grid and the keyring keeps its own fixed section. At a merchant, Sell junk stays in place and is disabled when no junk remains.

With **Compact bags** on (`compactBags`, default off) and `layout` at `categories` (the compact default), the bag slots sort into sections by item type, each under a Lumen section cap (`Widgets.SectionCap`: gem, tracked caption, gilt rule and the count of slots in it): Equipment (weapons and armour), Consumables, Trade goods (trade goods, gems, reagents, enhancements, recipes and glyphs), Quest, Other, Junk (a poor item with a sell value, whatever its class) and Empty. `Data.CATEGORIES` holds the built-in order and labels; `Data.Categories()` puts the custom categories (below) in front of them. `Data.Category(record)` tries each custom rule first, then places a slot from `C_Item.GetItemInfoInstant`'s class, or in Other when the class is missing or secret. A section with nothing in it is never built. Each section is a grid of the window's columns; every slot's item button keeps a parent frame that carries its bag's ID, under the section's grid, so Blizzard's `GetBagID` still reads the right bag, and a slot whose item changes category moves to its new section's bag frame on the next refresh, out of combat (`Widgets.MayMove`; in combat the move waits for `Combat.Queue`). With `layout` at `grid`, every bag slot sits in one grid.

**Empty slots in compact sections.** With `emptySlots` at `packed` (the default), the Empty section shows one stacked tile per bag family (`C_Container.GetContainerNumFreeSlots`' second return: the regular bags together, and a quiver, soul bag or other special bag on its own, since only its kind goes in it), wearing the family's free count as a stack number, so there is always somewhere to drop an item of each kind and the count is read at a glance; the cap counts every free slot, and the other empty slots' buttons stay hidden. `all` shows every empty slot, plain.

Clicking or dropping a held item onto a packed Empty tile tries that tile's bag first, then the other suitable free slots in the window. Unused category row space uses the first suitable free slot across the window. Profession bags require a matching item family, the reagent bag requires a crafting reagent, and the keyring accepts keys. Empty tiles highlight while an item is held; merchant and money cursors keep Blizzard's original slot handling. If nothing fits, the normal inventory-full error appears. The bank accepts drops only during a bank visit; saved character views remain read-only.

**The viewport.** The sections stack inside one clipping viewport (`win.viewport` holding `win.stack`), with the search row above it and the footer below it, so both stay reachable however many sections there are. The viewport's height is the stack's height, bounded by `rows` when it is above 0 (that many slot rows plus one cap) and always by the screen: the root frame's height in the window's own units, less the window's chrome and a 48-unit margin (`SCREEN_MARGIN`). The mouse wheel over the viewport scrolls the stack one slot row at a time and stops at both ends. The one grid of the `grid` layout is bounded the same way: `rows` caps its visible rows, the screen caps them again, and it scrolls when it shows fewer rows than it has. `test-bags-window.lua` reproduces a 100-slot, four-column, two-row inventory on a 1080 screen and fails if the window is ever taller than the screen. The window hugs its content: it is as wide as its widest section row (never wider than `columns` slots, which wraps a longer row), with a floor of 160 units (`MIN_CONTENT_WIDTH`, the footer's need) or the width Sort and the buttons beside it need, so a window of short rows is not mostly empty glass; a row that grows past the widest one widens the window with it. When the search box, Sort and the buttons would not fit side by side in that width (a five-wide window at a merchant, with Sell junk showing), the header stacks: the search box spans the row and the buttons sit right-aligned on a row of their own under it.

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

At a merchant, a Sell junk button shows in the bag window's header while there is junk to sell. With Sell junk by itself on, the default, junk sells as soon as a merchant opens.

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

## Other characters' counts and bags

`Alts.lua` keeps each character's items in KstyleUI's own saved data, `KstyleUIDB.account.inventory` (never another addon's): `{ version = 2, characters = { ["Realm-Name"] = { name, realm, class, seen, bags = { [itemID] = count }, bank = { [itemID] = count }, items = { [itemID] = { icon, quality, cat, name } }, free, total, bankFree, bankTotal, money } }, warband = { [itemID] = count } }`. Only plain numbers and strings go in: a secret item ID, stack count, icon or name is skipped (`Data.Read` turns secrets into nil). Version 2 added `items` (what each counted item is: its icon file ID, quality, category key and name), the free and total slot counts and the money; a version 1 character keeps its counts and gains those fields on its next scan. An item that leaves both the bags and the bank leaves `items` too.

- **Scanning.** At `Enable` the character is recorded with its name, realm and class token and its bags are counted (the keyring is not). `BAG_UPDATE_DELAYED` and `BAG_CONTAINER_UPDATE` count the bags again half a second later, once however many arrive; `PLAYER_LOGOUT` and `Disable` count them one last time. The bank is counted on `BANKFRAME_OPENED` and on `BANK_TABS_CHANGED`, `PLAYERBANKSLOTS_CHANGED` and `PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED` during a visit, through `Bank.Tabs(kind)`: the character bank into the character's `bank`, the Warband bank into the account's `warband`. A character not seen for 60 days is dropped at `Enable`, which keeps the table small.
- **Browsing.** Once another character is saved, the bag window's header grows a character picker (`win.picker`, a `Widgets.Dropdown` left of Sort, hidden while this character is the only one): `This character`, then the others by name. Picking one calls `Window:Browse(key)`, which reads `Alts.View(key)` (that character's `bags` and `bank` entries, each `{ id, count, icon, quality, cat, name }` in the categories' order then by name, with the free and total slot counts and the money) and lays the view out in place of the live sections: `Remote.lua` draws one plain tile per item (`Slot.New` without the secure template, so nothing can be picked up or used) under the same Lumen caps, the bags' categories first and then one `Bank` cap, with the count as a stack number and the quality hairline; the window hugs the widest row as it does for the live bags; the search filters the tiles by name, quality, category word and `junk`; a tile's tooltip is `GameTooltip:SetItemByID`; the footer shows that character's free slots and money. Picking `This character` brings the live bags back. The view is read-only and never writes anything.
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

Held items can be placed during combat, as in Blizzard's bags; placement is immediate and never queued for later.

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
| `compactBags` | `false` | toggle: use the previous category sections and packed empty tiles instead of a steady grid |
| `layout` | `categories` | dropdown: sections by item type, or one grid |
| `emptySlots` | `packed` | dropdown: one stacked empty tile per bag family in the Empty section, or every empty slot |
| `columns` | 10 | slider, 4 to 24 |
| `rows` | 0 | slider, 0 to 20: the rows shown before the grid or the sections' viewport scrolls with the mouse wheel; 0 fits the screen |
| `slotSize` | 34 (`actionButton`) | slider, 24 to 48 |
| `spacing` | 4 (`gapSmall`) | slider, 0 to 12 |
| `growth` | `RIGHT_DOWN` | dropdown: right then down, left then down, right then up, left then up |
| `showCount` | `true` | toggle |
| `showItemLevel` | `true` | toggle |
| `font` | Interface font: the `number` role (PT Serif Bold in Folio, Alegreya Sans ExtraBold in Lumen) | font |
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
| `autoSellJunk` | `true` | toggle: sell junk when a merchant opens. The QoL page points here instead of a second switch |
| `altCounts` | `true` | toggle: other characters' counts in item tooltips |
| `custom1.name`, `custom1.rule` | `""`, `""` | text rows, up to 60 letters; `custom2` and `custom3` the same |

Position, scale, opacity, strata and the shown rule come from Layout, on the Elements page and in Layout Mode. The preview shows eight sample slots drawn by `Slot.lua` with the current settings under the card heading the bag window's sections wear (`Widgets.SectionCap`: the diamond, `BAGS` in the caps face and heading gold, and the rule, as wide as the slots; KSTY-60 item 28 found the old centred caption dim); it makes no Blizzard item buttons. Section value puts a sample value beside the heading's count, Bag slots puts four bag tiles above the sample and Tracked currencies a currency line under it; the reagent marker shows only while the reagent bag shares the grid. The options that arrange sections, the window's height and corner, opening and closing, and gold act on the real window only, as Compact bags always has.

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

## EllesmereUI parity audit (2026-11-20)

Public surface: v9.9.1 and public source `8abfcbf`, inspected for option labels and observable behaviour only; no implementation, assets or game-data tables copied. Each distinct control, its cog controls and dynamic checklists are inventoried below; repeated controls are qualified by the panel that owns them. Shared visibility choices are listed together because they are values of one control.

Sources: [CurseForge description and screenshots](https://www.curseforge.com/wow/addons/ellesmereui), [v9.9.1 release](https://www.curseforge.com/wow/addons/ellesmereui/files/9708838), [Wago listing](https://addons.wago.io/addons/ellesmereui), [public changelog](https://ellesmereui.com/patch-notes), and the pinned public options links in each row. Wago's product page requires JavaScript in a static reader and does not expose an exhaustive menu inventory; the public source supplies the detailed rows. The [public HUD screenshot](https://media.forgecdn.net/attachments/1664/341/1-png.png) and [public style screenshot](https://media.forgecdn.net/attachments/1663/772/7-png.png) show the product's visible combat styling; they do not enumerate shell controls or prove API availability.

**Counts:** Present: 78; Missing, fits: 0; Missing, breaks consistency: 4; Not possible on Forever: 2. Present includes equivalent controls in another KstyleUI module; the control column names that placement. A partial equivalent states the missing part separately. These are implementation status counts after this PR, not a claim that every fitting option has shipped.

**PR-sized split:** the fitting inventory exceeds 600 implementation lines (multiple data bars, saved bag pins/recent history/list view, whole-panel chat idle state, unit-tooltip inspection and the QoL tools each need their own state and tests). This PR ships nine small, frequently visible controls, preserving existing defaults. Every remaining fitting row is explicitly assigned to follow-up A (minimap/data/chat), B (bags/tooltips) or C (QoL). Those batches must use the existing schemas, shared TextRows/BarRows/ordered-list rows and Layout Mode. Decorative border/shape editors stay excluded. New switches default off; Display subzone, Ignore low-level quests and Quest helpers in instances default on because that is already today's behaviour, including on a v0.2.8-shaped profile.

Forever limitations below are evidence from `C:/Users/leeba/.cache/wow-ui-source` at `9dc84f0`, not an inference from an option being absent. In particular, camelot's `Blizzard_UIPanels_Game/Camelot/BankFrame.lua` explicitly supports account-bank tabs: warband/account-bank options remain fitting work, not falsely labelled impossible.

| Publicly documented option | KstyleUI status | Control or remaining work | Public source |
| --- | --- | --- | --- |
| Bank > Bank Display | Present | KstyleUI bank / character and account tabs | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L72) |
| Grouping > Nest by Expansion | Present | Bags > Sections > Split the bank by expansion (off): bank sections split by the expansion from `C_Item.GetItemInfo`, newest first. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L100) |
| Grouping > Group by Category | Present | Compact bags > Layout > Sections by item type | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L108) |
| Sidebar > Category Sidebar | Present | Bags > Category list > Category list (off): All items, One grid and Bag by bag, the bank's tabs, then each section with its count, down the left of the bag and bank windows; a click shows that one alone. A list taller than Maximum height allows scrolls. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L121) |
| Sidebar > Hide Bank Tabs in Sidebar | Present | Bags > Category list > Bank tabs in the list (on while the list is on): off leaves the bank's list to its sections. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L129) |
| Sidebar > Hide Empty Slots When Grouped | Present | Compact bags > Empty slots > One stacked tile per bag kind | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L141) |
| Warband gold > Auto Deposit/Withdraw | Present | Bags > Bank > Keep gold on hand (off): at the bank, gold above the amount goes to the Warband bank and gold below comes back, guarded by `C_Bank.DoesBankTypeSupportMoneyTransfer`. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L169) |
| Warband gold > Amount | Present | Bags > Bank > Gold to keep: whole gold only; empty, or anything but digits such as 1.5, moves nothing. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L176) |
| Warband gold > Post Result to Chat | Present | Bags > Bank > Report in chat (off): only a transfer whose call ran. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L196) |
| Offline bank > Offline Bank | Present | Character picker > saved bank (read-only) | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L210) |
| Window > Bag Style | Present | Compact bags (steady grid or sections) and Bags > Slots > List view (off). | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L288) |
| Window > Default Selected Bag | Present | Bags > Category list > Opens to: All items (today's window), One grid or Bag by bag, each time the bag window opens. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L304) |
| Window > Window Scale | Present | Positions and sizes > Scale | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L320) |
| Window > Frame Strata | Present | Elements > Bags / Bank > Strata (Layout). | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L332) |
| Window > Slot Size | Present | Slot size | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L343) |
| Window > Slot Spacing | Present | Spacing | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L351) |
| Window > Auto-Size to Fit | Present | Rows shown > 0 fits the screen | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L362) |
| Window > Background Color | Missing, breaks consistency | Same option as Window > Bag background colour below: a per-window tint would make the bags the one window with its own colour. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L380) |
| Window > Background Opacity | Present | Appearance > Panel opacity: every KstyleUI window shares one opacity. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L391) |
| Window > Slot Background | Missing, breaks consistency | Per-element chrome or shape variants would make sibling frames use different visual languages; Appearance supplies the shared material and rim. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L398) |
| Window > Anchor to Nearest Corner | Present | Bags > Slots > Hold the nearest corner (off): a moved window saves the nearest screen corner as its anchor. Off gives each window its own anchor back (bags bottom right, bank top left) where it stands. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L427) |
| Window > Shrink | Present | Bags > Slots > Shrink while open (on, today's behaviour): off holds the window's size until it closes, with the footer kept at the bottom. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L449) |
| Window > Max Height (% of Screen) | Present | Bags > Slots > Maximum height (100 keeps the screen-minus-margin bound). | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L456) |
| Categories > Show Pinned Items | Present | Bags > Pinned items > Pinned items (off): Alt-click pins an item, keys included; pinned items also show in a Pinned section at the top of the bag window. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L475) |
| Categories > Show Recent Items | Present | Bags > Sections > Recent items (off): new items (`C_NewItems`) open a Recent section first. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L483) |
| Categories > Show in OneBag/MultiBag | Present | Bags > Pinned items > Pinned in grids (on): Pinned also shows above one grid and bag by bag. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L501) |
| Categories > Hide Items in Their Categories | Present | Bags > Pinned items > Only in Pinned (off): in sections, pinned items leave their own section, Recent items, the keyring and a reagent bag shown apart; the footer still counts their slots. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L507) |
| Categories > Dim Items in OneBag/MultiBag | Present | Bags > Pinned items > Dim pinned in grids (off): the original slot dims, and a search keeps it dimmed. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L514) |
| Categories > Pins per Character | Present | Bags > Pinned items > Pins per character (on): each character's own pins, copied from the shared ones on first use. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L524) |
| Categories > Show Clear Button | Present | Bags > Sections > Clear button (off): Clear recent in the header. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L554) |
| Categories > New Items Only | Present | Bags > Sections > New items only (off): a new item joins Recent only when no older stack of it is in your bags. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L560) |
| Categories > Show Picked-Up Amount | Present | Bags > Sections > Picked-up amount (off): one recent tile per item with the amount gained. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L568) |
| Categories > Hide Categories with 0 Items | Present | Bags > Category list > Empty categories (off): off keeps empty categories off the list, as upstream's default does. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L586) |
| Categories > Hide 'Add Category' Tab | Present | Bags > Category list > Add category entry (on): the list's last entry opens the Bags settings page at the custom categories. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L646) |
| Categories > Split Set Gear by Set | Present | Bags > Sections > Equipment set sections (off), from `C_EquipmentSet`. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L653) |
| Categories > Category Title Size | Present | Bags > Sections > Heading size (11 keeps today's headings). | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L671) |
| Categories > Hide Sidebar Icons When Collapsed | Present | Bags > Category list > Hide the folded list (off): a folded list keeps one diamond per entry; on hides it and leaves the unfold arrow by the window's title. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L678) |
| Categories > Categorize Reagent Bag Items | Present | Bags > Sections > Reagent bag in sections (on, today's behaviour); off gives the reagent bag its own section. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L699) |
| Categories > Reagent Bag Icon | Present | Bags > Markers > Reagent bag marker (off): the kit's diamond on reagent-bag items that share a grid. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L706) |
| Categories > Size | Present | Bags > Markers > Marker size. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L729) |
| Grid and compact > Show Item Level | Present | Item levels | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L755) |
| Grid and compact > Item Level Text Size | Present | Font size (shared with stack counts) | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L771) |
| Grid and compact > Show Gear Track Rank | Not possible on Forever | `9dc84f0`: Blizzard_ItemUpgradeUI.toc allows mainline/mists only; no camelot upgrade track. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L792) |
| Grid and compact > Show BoE / Warbound Text | Present | Bags > Slot text > Bind labels (off): BoE and WuE on unbound gear, from `bindType`, on the row the item level leaves free. Unknown binding shows nothing, and an unbound BoE or WuE copy of a set item is never shown or filed as the set's, because equipping it would bind it. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L836) |
| Grid and compact > Item Count Text Size | Present | Font size | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L846) |
| Grid and compact > Text Size | Present | Bags > Slot text > Label size. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L871) |
| Grid and compact > Show Set Name on Gear | Present | Bags > Slot text > Equipment set names (off). | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L888) |
| Grid and compact > Nest by Expansion | Present | Bags > Sections > Split by expansion (off). | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L897) |
| List > Left Gap | Present | Bags > Slots > Left gap (list view). | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L937) |
| List > Right Gap | Present | Bags > Slots > Right gap (list view). | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L946) |
| List > Row Height | Present | Bags > Slots > Row height (list view). | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L955) |
| List > Text Size | Present | Bags > Slots > Row text size (list view). | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L965) |
| List > Round Icons | Missing, breaks consistency | Per-element chrome or shape variants would make sibling frames use different visual languages; Appearance supplies the shared material and rim. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L974) |
| List > Section Gold Value | Present | Bags > Sections > Section value (off): sell value beside each section's count, in tiles or the list. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L986) |
| List > Hide Row Stripes | Present | Bags > Slots > Row stripes (on in the list view). | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L997) |
| Slot extras > Merge Duplicate Items | Present | Bags > Sections > Merge stacks (off); never gear. Merging and picked-up amounts pause at a merchant, bank, guild bank, mailbox, trade or auction house. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L1043) |
| Slot extras > Group Gear by Slot | Present | Bags > Sections > Gear by slot (off). | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L1050) |
| Slot extras > Compact Slot Groups | Present | Bags > Sections > Small sections side by side (off): two to a row when the heading fits. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L1083) |
| Slot extras > Quality Item Border | Present | Quality borders / Coloured from | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L1099) |
| Footer > Gold Tracking and History | Present | Bags > Footer > Gold of every character (on; hover only, no visible change): each saved character's gold and the total. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L1145) |
| Footer > Sort to Bottom | Present | Bags > Sorting > Sort to bottom (off): grids, the bank and bag by bag draw the empty slots on the top rows, whichever way Growth runs, so items sit at the bottom in their order; while on, Blizzard's Sort packs from the side opposite Sort direction, and off restores Sort direction's side. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L1203) |
| Footer > Show Coins | Present | Bags > Footer > Coins shown. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L1235) |
| Footer > Icon Zoom | Present | Bags > Icon zoom (7 percent preserves the original crop). | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L1249) |
| Automation > Stack Splitter | Present | Shift-click uses Blizzard container item buttons | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L1394) |
| Automation > Open Bags with Character Window | Present | Bank > Character window opens bags (off); closes only bags it opened and still owns (closing them by hand or turning it off hands them back) and hooks the character window only once on. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L1398) |
| Automation > Slot Count Format | Present | Bags > Slot count format: Free / total (default), Used / total, Free slots only. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L1433) |
| Automation > Separate Reagent Slots | Present | Bags > Markers > Reagent bag apart (off): the reagent bag on its own row under the steady grid. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L1445) |
| Window > Bag frame strata | Present | Elements > Bags / Bank > Strata (Layout). | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L1) |
| Window > Bag background colour | Missing, breaks consistency | Bag and bank use the same surface material as every other window. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L1) |
| Categories > Enabled categories / custom category rules | Present | Custom categories 1-3 > name and rule; Compact bags > Sections by item type | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L1) |
| List > Split by type (armour, weapons, professions) | Present | Bags > Sections > Split by type (off): equipment by armour or weapon type, trade goods by material. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L1) |
| Slot extras > Desaturate junk | Present | Desaturate junk (new; off) | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L1) |
| Slot extras > Junk coin marker | Present | Junk marker (shared kit glyph equivalent) | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L1) |
| Top bar > Bags icon | Present | Bags > Slots > Bag slots (off): the equipped bags in a row under the search box; out of combat only. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L1) |
| Top bar > Junk icon | Present | Sell junk button at merchants | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L1) |
| Top bar > Sort icon | Present | Sort button | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L1) |
| Top bar > Quick actions: Disenchant, Pick Lock | Present | Bags > Slots > Quick actions (off): hold Alt over an uncommon to epic weapon or armour piece that can be disenchanted, or a locked box, and one secure cast button covers the slot; Alt-right-click casts Disenchant (13262) or Pick Lock (1804) on it, Alt-left-click still pins. Set only out of combat and removed as combat starts, when Alt is released, the cursor leaves or the bags close. Shown only for a spell you know. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L1) |
| Top bar > Quick actions: Prospect, Mill | Not possible on Forever | The installed client (1.60.1.71037, `SpellName` and `SkillLineAbility` exported read-only with `Tools/icons/casc_export.py`) has no Prospecting (31252) or Milling (51005) spell and no Jewelcrafting or Inscription skill line; the UI source at `9dc84f0` names neither. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L1) |
| Top bar > Keyring icon | Present | Keyring switch | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L1) |
| Footer > Enabled currencies | Present | Bags > Footer > Currency 1, 2 and 3 (none): chosen currencies replace the backpack's on the Tracked currencies line; the list comes from the currency tab's open groups. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L1) |
| Auto open bags > merchant / bank / mail / trade / auction / loot / quest | Present | Bags > Open and close with: one choice per window (merchant, mailbox and auction house open and close by default; trade, loot and quest giver leave bags alone); the bank keeps Bank opens bags. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L1) |
| Auto close bags > merchant / bank / mail / trade / auction / loot / quest | Present | Bags > Open and close with: Open and close bags closes only bags that window opened. | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L1) |
| Search / filters | Present | Search box: name, type, quality, slot, item level and custom rule grammar | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L1) |
| Visibility: always, combat, out of combat, party, raid, solo, hidden | Present | Positions and sizes > Shown | [public options](https://github.com/EllesmereGaming/EllesmereUI/blob/8abfcbf6afa4129369cdc9fb5e03e96d1fdd94e5/EllesmereUIOptions/EUI_Bags_Options.lua#L1) |

### Controls shipped in this batch

**Desaturate junk.** Off preserves coloured icons. On desaturates only sellable junk; locked-item desaturation remains independent.

Forever proof at `9dc84f0`: `Texture:SetDesaturated`: `Blizzard_APIDocumentationGenerated/SimpleTextureBaseAPIDocumentation.lua`. The existing slot refresh applies this to our own icon texture with a method guard; no new events, frames or protected actions.

`test-shell-parity.lua` verifies defaults, Options writes, live application, reversal, API fallbacks, secret values and v0.2.8 profile compatibility; `test-perf-path-budgets.lua` keeps the reload/resize ceilings. Render with `shell_parity`, `RENDER_SHELL_MODULE=Bags`, `RENDER_SHELL_OPTIONS=1` for the page or `0` for affected frames, and `RENDER_SHELL_DEFAULTS=1` for unchanged defaults. The render uses the real module and Options.Write; its fixture text and item data stay in Tools. Evidence is outside the repository at `C:/Users/leeba/.cache/kstyleui-evidence/parity-shell/`.

### Next parity batch (2026-11-20)

Window strata already comes from Elements > Bags / Bank > Strata (Layout). Slot-count format and icon zoom apply to the existing bag/bank builders. Defaults remain free/total and 7 percent. Follow-up B still covers category/list features, item labels, bank automation and the remaining toolbar controls.

`test-shell-parity-followup.lua` covers writes, application, reversal and v0.2.8 profiles; `test-perf-path-budgets.lua` covers reload cost. Strict default pixel comparisons and Options captures live in `C:/Users/leeba/.cache/kstyleui-evidence/parity-shell-2/`. No row was skipped because of reload cost; remaining rows are separate feature work.

### Parity batch 3 (2026-11-20)

Character window opens bags is off. Follow-up B still covers category/list features, item labels, bank automation and the remaining toolbar controls.

`test-shell-parity-3.lua` covers defaults, writes, application, reversal and v0.2.8 profiles; `test-perf-path-budgets.lua` covers reload cost, with the same widget calls as staging. Strict default pixel comparisons and Options captures live in `C:/Users/leeba/.cache/kstyleui-evidence/parity-shell-3/`. No row was skipped because of reload cost.

### Parity round 1 (2026-11-20)

Thirty-eight rows: thirty-six new controls, Background Opacity, which today's design already covers, and Background Color, the same option as Bag background colour, moved to "breaks consistency". The review of #602 moved Shrink, Hide Categories with 0 Items, Sort to Bottom and Enabled currencies back to "Missing, fits": KstyleUI has no switch for any of them. Every new switch is off, and every new slider and choice defaults to today's value, so the default bag and bank windows draw pixel for pixel as before; Gold of every character is on because it only adds a hover list. New slot labels, the reagent marker, list names and stripes, the reagent row's heading and the currency line are made only when switched on.

| Key | Default | Row |
| --- | --- | --- |
| `maxHeight` | 100 | slider, 30 to 100: the tallest window as a share of the screen |
| `nearestCorner`, `bagSlots`, `listView` | `false` | toggles; `listRowHeight` 24, `listFontSize` 11, `listLeft` 0, `listRight` 0 and `listStripes` `true` apply to the list view |
| `capSize` | 11 | slider, 8 to 16 |
| `recentItems`, `recentClear`, `recentNewOnly`, `recentGained`, `mergeStacks`, `sectionValue`, `gearBySlot`, `splitTypes`, `splitSets`, `nestExpansion`, `bankNestExpansion`, `compactGroups` | `false` | toggles that act on Compact bags' sections |
| `categorizeReagents` | `true` | toggle; off gives the reagent bag its own section |
| `separateReagents` | `false` | toggle; the reagent bag's own row in the steady grid |
| `bindText`, `setNames`, `reagentMark` | `false` | toggles; `labelSize` 9 and `reagentMarkSize` 12 |
| `goldTooltip` | `true` | toggle; `goldCoins` `copper` (gold, silver and copper) |
| `currencies` | `false` | toggle; no line on a saved character's view |
| `autoMerchant`, `autoMail`, `autoAuction` | `both` | dropdowns: open and close bags, open bags, leave bags alone |
| `autoTrade`, `autoLoot`, `autoQuest` | `none` | the same dropdowns |
| `warbandGold`, `warbandGoldChat` | `false` | toggles; `warbandGoldAmount` `""` (whole gold) |

- **Sections.** Recent, equipment-set, slot, type and expansion sections are keys under the main section; with every split off the keys stay `equipment`, `consumables` and so on. Ranks keep the built-in order. Merging and picked-up amounts hide the extra stacks' buttons the way packed empty slots do, and `MAIL_SHOW`, `TRADE_SHOW`, `AUCTION_HOUSE_SHOW`, `MERCHANT_SHOW`, `BANKFRAME_OPENED` and `GUILDBANKFRAME_OPENED` pause merging and picked-up amounts until their closing events. New items only compares each new item with the older stacks in the bags at that refresh.
- **Open and close with.** The hooks pass the frame Blizzard's `OpenAllBags(frame)` and `CloseAllBags(frame)` name, so the merchant, mailbox and auction house choices filter Blizzard's own calls. Trade, loot and the quest giver open on `TRADE_SHOW`, `LOOT_OPENED` and `QUEST_DETAIL`, `QUEST_PROGRESS`, `QUEST_COMPLETE` or `QUEST_GREETING`, and close on `TRADE_CLOSED`, `LOOT_CLOSED` and `QUEST_FINISHED` only when they opened the bags.
- **Keep gold on hand** runs once per bank visit through `Combat.Queue`. When it runs it rechecks that the switch is on, the amount is whole gold and the same visit is still open, so a fight that ends after the bank closed or after the switch went off moves nothing. It moves gold only after `C_Bank.DoesBankTypeSupportMoneyTransfer`, `CanDepositMoney` or `CanWithdrawMoney` agree, withdraws no more than `FetchDepositedMoney`, and reports only a transfer whose call ran.
- **Bag slots** swap bags with `PutItemInBag` and `PickupBagFromSlot` on `C_Container.ContainerIDToInventoryID`, out of combat only.

Forever proof at `9dc84f0`: `Blizzard_APIDocumentationGenerated/ItemDocumentation.lua` (`GetItemInfo` returns `itemEquipLoc`, `sellPrice`, `bindType`, `expansionID`), `ItemConstantsDocumentation.lua` (`Enum.ItemBind` 2 and 9), `EquipmentManagerDocumentation.lua` (`GetEquipmentSetIDs`, `GetEquipmentSetInfo`, `GetItemIDs`, `EQUIPMENT_SETS_CHANGED`), `CurrencyInfoDocumentation.lua` (`GetBackpackCurrencyInfo`, `CURRENCY_DISPLAY_UPDATE`), `BankDocumentation.lua` (`DoesBankTypeSupportMoneyTransfer`, `CanDepositMoney`, `CanWithdrawMoney`, `DepositMoney`, `WithdrawMoney`, `FetchDepositedMoney`), `ContainerDocumentation.lua` (`ContainerIDToInventoryID`), `GuildBankDocumentation.lua` (`GUILDBANKFRAME_OPENED`, `GUILDBANKFRAME_CLOSED`), `TradeInfoDocumentation.lua`, `LootDocumentation.lua`, `QuestOfferDocumentation.lua`, `MailInfoDocumentation.lua` and `AuctionHouseDocumentation.lua` for the events, `Blizzard_UIPanels_Game/Vanilla/BankFrame.lua` for `PutItemInBag` and `PickupBagFromSlot`, `Blizzard_MainMenuBarBagButtons/Camelot/MainMenuBarBagButtons.xml` for Forever's reagent bag slot, and `Blizzard_UIPanels_Game/Mainline/MerchantFrame.lua`, `Blizzard_MailFrame/MailFrame.lua` and `Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseFrame.lua` for the frames Blizzard passes to `OpenAllBags`.

`test-bags-parity.lua` covers defaults and v0.2.8 profiles, every option switched on, turning each off, the events and the live preview; `test-perf-path-budgets.lua` covers reload cost. Strict default pixel comparisons, enabled renders at four screen sizes over game backdrops and Options captures live in `C:/Users/leeba/.cache/kstyleui-evidence/parity-bags-r1/`.

### Parity round 2 (2026-11-21)

Fourteen rows. Every new switch is off and every new choice keeps today's window, so the default bag and bank windows draw pixel for pixel as before. Shrink while open is on because today's window already shrinks; Pinned in grids, Pins per character, Add category entry and Bank tabs in the list are on but act only once their parent switch is on. The category list, the Pinned section and its copies are made only when switched on.

| Key | Default | Row |
| --- | --- | --- |
| `shrink` | `true` | toggle: off holds the window's size until it closes |
| `sortBottom` | `false` | toggle: grids show empty slots first |
| `currency1`, `currency2`, `currency3` | 0 | dropdowns: a currency from the currency tab, or the backpack's tracked ones |
| `pins`, `pinsOnly`, `pinsDim` | `false` | toggles; `pinsInGrid` and `pinsPerCharacter` `true` |
| `openTo` | `all` | dropdown: All items, One grid or Bag by bag |
| `sidebar`, `sidebarEmpty`, `sidebarHide` | `false` | toggles; `sidebarAdd` and `sidebarTabs` `true` |

- **Pinned items.** Alt-click is free on Blizzard's item button: `ContainerFrameItemButtonMixin:OnClick` sends a modified click to `OnModifiedClick`, which acts only on the expand, chat-link, dress-up and split-stack modifiers. The module hooks `OnClick` after Blizzard's handler and pins only when no item is on the cursor. Pins are item IDs in the account store (`bagPins`), shared or per character. The Pinned section holds copies: more of Blizzard's item buttons for the same bag slots, so a click on a copy uses, sells or moves the item as the original does. Copies are made out of combat; one needed in combat waits for `Combat.Queue`. They follow `BAG_UPDATE_DELAYED`, `ITEM_LOCK_CHANGED`, theme and font changes, and a copy whose slot a smaller bag lost hides. The Alt state is read through `issecretvalue`, so a restricted answer pins nothing, and nothing is stored until the first pin.
- **Views and the list.** One grid draws the steady grid even with Compact bags on; Bag by bag files every slot, empty ones included, under its bag's name from `C_Container.GetBagName`, without Recent items or merged stacks. Opens to applies each time the window opens and at once when changed. The list is a column down the window's left side, built on the shared scrolling list with the settings rail's row height, hover wash and selected mark; folded, each entry keeps a diamond. It stays within Maximum height and scrolls, and Shrink while open off holds the whole window, list included. A selected section that empties falls back to everything unless Empty categories is on, and switching the list or its bank tabs off clears what they selected. An empty category counts every section of its kind, so a split category is never listed as empty. The bank lists its purchased tabs, and a tab shows alone until the bank type changes or the visit ends.
- **Sort to bottom** reorders what the grid draws and, as upstream does, flips the side Blizzard's Sort packs from (`C_Container.SetSortBagsRightToLeft`): Sort direction's side again when switched off. Sections are left alone, as upstream leaves its category views.
- **Previews.** The live preview shows Sort to bottom where it applies, the chosen currencies, the list with its entries, the view the window opens to, the Pinned section with Only in Pinned and dimming. Holding the size and the bank's tabs leave nothing to draw on a still bag card.

Forever proof at `9dc84f0`: `Blizzard_APIDocumentationGenerated/CurrencyInfoDocumentation.lua` (`GetCurrencyListSize`, `GetCurrencyListInfo` with `currencyID` and `isHeader`, `GetCurrencyInfo`, `CURRENCY_DISPLAY_UPDATE`), `ContainerDocumentation.lua` (`GetBagName`), `Blizzard_UIPanels_Game/Mainline/ContainerFrame.lua` (`OnClick` and `OnModifiedClick`; Camelot loads the Mainline family) and `Tools/data/forever_globals.lua` (`IsAltKeyDown`).

`test-bags-parity-2.lua` covers defaults and v0.2.8 profiles, every option switched on, turning each off, the events, combat and the live preview; `test-bags-parity-2-review.lua` keeps each finding of the review fixed; `test-perf-path-budgets.lua` covers reload cost. Strict default pixel comparisons, enabled renders at four screen sizes over game backdrops and Options captures live in `C:/Users/leeba/.cache/kstyleui-evidence/parity-bags-r2/`.

### Parity round 3 (2026-11-21)

Quick actions, the last fitting row. Spell proof: the installed client's `SpellName` table names 13262 Disenchant and 1804 Pick Lock, and `SkillLineAbility` teaches them from Enchanting (333) and Lockpicking (633, rogues). Forever API at `9dc84f0`: `Blizzard_FrameXML/SecureTemplates.lua:770` (a `spell` action button with `target-bag` and `target-slot` uses the item once the spell asks for one), `SpellBookDocumentation.lua` (`C_SpellBook.IsSpellKnown`), `TooltipInfoDocumentation.lua` (`C_TooltipInfo.GetBagItem`, whose lines hold the game's `LOCKED` and `ITEM_DISENCHANT_NOT_DISENCHANTABLE` text), `KeyBindingsDocumentation.lua` (`MODIFIER_STATE_CHANGED`) and `Blizzard_FrameXML/Camelot/EquipmentFlyout.lua:386` (`GameTooltip:SetBagItem`). The button is parented to `UIParent`, never the bag window, so the bags stay unprotected; its two events are registered only while the option is on, and the slot hover pays one boolean read while it is off. `test-bags-quick.lua` covers the default, a v0.2.8 profile, each spell, the refusals, Alt, combat, pins, closing the bags and switching off.
