# Setup

`KstyleUI.Setup` is the first-run setup: four steps that pick a layout and the modules, then apply both and offer a reload. The spec's [Settings and first-run setup](../../docs/superpowers/specs/2026-11-07-kstyleui-design.md#settings-and-first-run-setup) section is binding. `Core/Setup/Setup.xml` loads the files in this order:

| File | What it holds |
| --- | --- |
| `Layouts.lua` | `Setup.Layouts`: the element keys and the Lumen DPS, Tank and Healer layouts: positions, footprints, the module settings each writes and the story slot. See [`element-keys.md`](../../docs/superpowers/plans/element-keys.md). |
| `EditMode.lua` | `Setup.EditMode`: Apply's Edit Mode writer, which puts the objective tracker in the story slot, Blizzard's damage meter on the damage card and Blizzard's tracked buff icon and bar viewers in their slots |
| `Setup.lua` | The choices, `Apply`, the story slot's split, the first run, and when the window opens |
| `Window.lua` | The window, built from the widget kit |

Tests: `Tools/regression/test-setup.lua`, `test-setup-editmode.lua` and `test-setup-layouts.lua`.

## When it opens

- At `PLAYER_LOGIN`, when the account switch `Features.account.setupSeen` is off, the setup opens 2 seconds later. The switch is account-wide, so the setup opens once per account, not once per character.
- Applying or closing the setup turns the switch on.
- On the first run, closing the window without Apply (the close button, Escape or **Later**) applies the choice as it stands: DPS and every loaded module unless the player changed them. A skipped setup never leaves an empty screen. The welcome step says so, and **Keep my UI** is the opt-out: it closes the setup and changes nothing.
- A setup opened later with `/kstyle setup` changes nothing when it closes without Apply; it prints how to run it again.
- `/kstyle setup` opens it at any time, on the welcome step with fresh choices.

## The steps

The window is a titled `Widgets.Panel` (760 by 540 units, `DIALOG` strata, Escape closes it) that opens with the panel motion. It registers with Layout as `setup.window`, scalable, 40 units above the centre. A `Widgets.Tabs` strip shows the four steps. A step the player has not reached is disabled, and each page fades in over `fade`.

1. **Welcome.** The logo, a short welcome, the three steps ahead, on the first run the note that closing applies the DPS layout, **Keep my UI** and **Next**.
2. **Layout.** One card per layout on the button grade's body, its name and its note, over one large 16:9 preview of the picked layout (the hovered card's while the pointer is on one): a glass panel at the tile chamfer with the drop shadow that draws each element the layout shows at its Lumen footprint (`Layouts.Footprint`, `Layouts.Shown`), names it where its label (or its `short` label) fits the block, and outlines the story slot in the accent and names it (**Story rail**, or **Quests** where that does not fit; round 6, Opus). The elements whose place or presence differs between the layouts (the group frames, the threat and boss cards, your combat text) draw in the accent over the shared hands and rails, so Tank's named threat card and Healer's group frames read at a glance. The legend beside the preview names the outline, the **Story rail**, and says Apply places the quest tracker there through Edit Mode. A click picks the card: an `accent` hairline and a selection glow. DPS is picked first. The preview takes the page's height under the cards, so the step has no empty half.
3. **Modules.** A toggle and a one-line note for each module in `Setup.PICKER`, with **All on** and **All off**. Every module whose addon loaded starts on. A module whose addon did not load is off, disabled and says so. The settings window is not in the list: it loads on demand.
4. **Summary.** The layout and the modules that will be on and off, then **Apply**. After Apply, the secure **Reload** button and **Later**, and what Edit Mode did (`EditMode.Last()`): the active "KstyleUI <layout>" layout, a write waiting for combat to end, or a refusal with its reason and **Try again** (`Setup.RetryEditMode`), never a drag instruction. When the tracked buffs overflow every arrangement, it names the counts and offers **Open the Cooldown Manager**. Changing a choice afterwards shows **Apply** again.

## Apply

`Setup.Apply(choice)` with `choice = { layout, modules = { [name] = boolean } }`:

1. For each module in the picker whose addon loaded, `Options.Write(name, "enabled", value)`. Writing through `Options` starts or stops the module through `Modules`, waiting for the end of combat if needed, and fires `SettingChanged`, so an open settings window refreshes.
2. For each element key, the layout's `{ anchor, x, y }`:
   - An element that Layout has registered (`Layout.Get(key)` is not `nil`) moves at once through `Layout.Update(key, position, "setup")`.
   - Every other element, and any that `Layout.Update` refuses, is written into the profile's layout table (`Store.Layout()[key]`). Other fields, such as a size or a shown rule, stay as they are. The modules place these elements after the reload.
3. For each `{ module, key, value }` in `Layouts.Settings(layout)` whose module loaded and has that setting, `Options.Write(module, key, value)`: bars 1 and 2 on in one row with empty tiles shown (LEE-20), bars 3 to 6 off with empty tiles hidden, the pet and stance sockets in two rows of five (the stance sockets growing up from their unchanged baseline), the threat card on in Tank only, the menu and bags docked in the readout card, the raid in four groups a row at 77 units wide, and the party and raid row heights (Healer's are larger, with two dispellable debuffs first). The positions carry `Layouts.Sizes(layout)` too: the meters' heights. Settings of a module that did not load are skipped and counted.
4. `Options.Write("Layout", "preset", layout)`, so Layout Mode outlines that layout's story slot.
5. Out of combat (queued through `Combat.Queue` in combat), `EditMode.Write(layout, Story(layout, guide))` writes the story rail into Edit Mode. See [Edit Mode](#edit-mode).
6. It turns `setupSeen` on and logs the layout, the counts and the modules switched on and off to the devlog.

It returns `false` for an unknown layout, or before the saved data loads.

## Edit Mode

KstyleUI never calls `SetPoint` on Blizzard's objective tracker, damage meter or Cooldown Manager viewers. Apply writes their places into an Edit Mode layout instead, through the API `Blizzard_APIDocumentationGenerated/EditModeManagerDocumentation.lua` documents on Forever 1.60.1, and Edit Mode moves them:

1. `C_EditMode.GetLayouts()` returns the saved layouts; `EditModePresetLayoutManager:GetCopyOfPresetLayouts()` the presets, which come first in the index Edit Mode counts with (`Blizzard_EditMode/Shared/EditModeManager.lua`, `UpdateLayoutInfo`).
2. The writer finds the account layout named `KstyleUI <layout>`, or makes one: a copy of the active layout, so every other system keeps the player's place, inserted after the last account layout as `MakeNewLayout` does. `IsValidLayoutName` must approve the name, and a full set of account layouts (`Constants.EditModeConsts.EditModeMaxLayoutsPerType`) is never overwritten.
3. In that layout, the `ObjectiveTracker` system hangs its `TOPLEFT` from `UIParent`'s `BOTTOMLEFT`, 16 units right of the story slot's edge and 34 above its top (`TRACKER_LEFT`, `TRACKER_TOP`), so the tracker skin's glass, which starts 16 left of the tracker and 34 under its top, lands on the slot. Its Height setting takes Edit Mode's lowest value (400), so a long quest list stays off chat. With RestedXP loaded, the tracker takes the slot's lower half and the guide the upper half (`Story`).
4. The `DamageMeter` system sits on the layout's damage card at the card's size (`FrameWidth` and `FrameHeight`, stored less their 200 and 120 minimums, clamped to Edit Mode's 600 and 400), so the meter's Blizzard skin mode, used on restricted clients, sits where the Lumen card would.
5. The `CooldownViewer` system's `BuffIcon` and `BuffBar` entries (`Enum.EditModeCooldownViewerSystemIndices` 3 and 4) are Blizzard's tracked buff viewers, which the Cooldowns module restyles on Forever's automatic path. Blizzard's viewer gives every tracked item a slot (`includeAsLayoutChildWhenHidden`), at least two, each 40 by 40 (a bar 220 by 30) scaled by `IconSize` (stored as (percent - 50) / 10), and ignores `IconLimit` for these two viewers, so the icons are always one row or one column. The writer knows each arrangement's length from the tracked counts (`EditMode.CountTracked(fn)`; `EditMode.Tracked(group)` reads them, six icons and two bars without the module) and tries these places in order, taking the first where every item fits at a readable size (icons 24 root units, bars 18), else at any size down to 50 %, touching no other footprint, the essential and utility slots included, and staying on screen:
   - icons: one row hung from the `cooldowns.buffs` slot's right edge, 14 units above its bottom to reserve the timers, ordered left to right with native direction RIGHT and 3 UIParent units between sockets; else a column beside the focus or right rail, or right of the focus above the target;
   - bars: their independent `cooldowns.bars` slot; else under the target of target, above the focus, beside an already placed dense icon column, or beside the right rail. Each candidate must hold the whole viewer clear of the other elements.
   LEE-20 targets 27.6-root-unit icons. Forever's `EditModeSettingDisplayInfo.lua` exposes only 10% steps, so the nearest legal native size on the owner's default canvas is 28.5 at 60%, not the custom row's exact 27.6. Six native icons span 188.8125 units including gaps, extending 6.2125 left of the 182.6-unit renderer holder into available space; the portrait-side edge stays fixed. The writer checks the actual native bounds against every obstacle and falls back to smaller steps when needed, retaining the engine's 50% minimum. Bars keep a 24-unit cap with a minimum-step exception; `BarWidthScale` comes from the chosen stack width. At 16 icons and six bars, every preset fits at 16:9, 16:10, 21:9 and the owner's 2383 by 1540 screen (`test-setup-editmode.lua`). The writer first protects spare action-bar slots and tries both viewer orders; only if neither arrangement fits does it relax disabled slots. Enabled bar 2 always remains protected. A viewer moves only when every tracked item fits whole and clear. Otherwise it keeps its existing placement and the setup summary names the count and how many would fit, with Cooldown Manager, Try again and Edit Mode as recovery paths.
6. The `RaidWarning` system (boss emotes, boss whispers and raid warnings, which the encounter warnings skin narrows to its lane) goes in the upper band where Blizzard, DBM and BigWigs put warnings, off the nameplates that draw over the characters (round 6, Opus #3): each candidate lane, centred or beside a footprint, starts with its top 15% under the screen's top and sinks under whatever it meets, a rail gap clear; the highest wins, the centred one on a tie, between the rails and above the target. `test-setup-warnings.lua` holds its top in the upper 35% of the screen on every preset and screen.
7. `C_EditMode.SaveLayouts` saves the presets and the saved layouts together, and `C_EditMode.SetActiveLayout` activates the KstyleUI layout.

Offsets are in `UIParent`'s units: root units times the root's effective scale over `UIParent`'s. Every call is protected by `pcall`; a missing `C_EditMode`, a refused name, a full set of layouts or a failed save logs the reason, keeps a player-facing reason for the setup summary, and prints that **Try again** is on the summary.

## Functions

| Function | Behaviour |
| --- | --- |
| `Open(first) -> boolean` | Opens the window on the welcome step with fresh choices. `first` is true for the first-login open, whose close applies the choice. Refused before the saved data loads. |
| `IsFirstRun()`, `Keep()` | Whether the open window is the first run; `Keep` makes its close change nothing (the **Keep my UI** button) |
| `Story(name, guide) -> { story, guide, tracker }` | The layout's story slot in root units (`left`, `right`, `bottom`, `top`), and the parts of it the guide and the tracker take: with `guide`, the guide the upper half and the tracker the lower half one rail gap (16) under it; without, the tracker the whole slot |
| `GuideLoaded()`, `RootSize()` | Whether RestedXP Guides is loaded; the root's size, through Layout when it is there |
| `EditMode.Write(name, story) -> boolean`, `EditMode.Available()`, `EditMode.CountTracked(fn)`, `EditMode.Tracked(group) -> number` | See [Edit Mode](#edit-mode) |
| `EditMode.Last() -> { state, name, layout, why, notes }`, `EditMode.Note(note) -> string`, `RetryEditMode() -> boolean` | The last write for the summary: `state` is `none`, `waiting` (combat), `written` or `failed`; `notes` lists `{ group, count, fits }` for tracked viewers no place held. `RetryEditMode` writes the last layout again. |
| `Apply(choice) -> boolean` | See above |
| `Choice()`, `NewChoice()` | The window's current choice, and a fresh one: DPS and every available module on |
| `Available(name) -> boolean` | The module's addon loaded and registered. |
| `Go(step)`, `Step()` | Moves to a step, 1 to 4, and reports the current one |
| `IsShown() -> boolean` | True from `Open` until the window starts to close, so a reopen during the closing fade shows it again and the first-login timer never resets a setup the player opened |
| `MarkSeen()`, `Closed(applied)` | Turn the account switch on. On the first run `Closed` applies the choice unless the player chose **Keep my UI**; otherwise it prints the `/kstyle setup` hint. |
| `PICKER` | `{ { name, label, note }, ... }` in the picker's order |
| `window` | The panel, once it has been built. Fields: `steps`, `pages`, `cards`, `preview`, `layoutHint`, `toggles`, `summary`, `editMode`, `retry`, `manager`, `back`, `skip`, `next`, `apply`, `reload` and `later`. |

## Why

- The setup never calls a protected function. Modules start through `Modules`, which queues them in combat. The reload is the kit's secure macro button, because `ReloadUI()` is blocked for addons.
- Positions for elements that are not registered yet go straight into the profile's layout table. Most modules are switched on by this same Apply and register only after the reload, and the Layout service reads that table when an element registers.

## The Lumen layouts

DPS, Tank and Healer place every element on the Lumen Rails: two 318-unit rails on the `screenMargin` (17 units, the owner's picture of 2026-11-09) and a shared centre column. The owner's 2026-11-09 ruling, LEE-20 ("let the picture win its what i want"), supersedes the earlier target sigil, common 38-unit tile size and spare-bar stack. `test-setup-layouts.lua` pins the picture geometry for all three presets and seven reference screens while preserving unrelated rail and optional-element slots; `test-setup-collisions.lua` checks the full footprints the modules draw.

- **Left rail:** the party card (the raid card in a raid) at the top and chat at the foot, on one left edge: the party card 318 wide, chat 393 by 186 on the `screenMargin` token (LEE-20: the picture wins over #210's 372). Healer keeps the 318 rail width at the picture's 186 height, because six tracked bars do not fit beside a 393 card on a 2383 by 1540 screen at UI scale 1.
- **Right rail:** the square map with the buff and debuff rows beside it; 16 under the lower of the two, the story slot for the RestedXP guide and the quest tracker, where a tracker sits in the classic UI, so the quests read right under the map (owner, 2026-11-09). Apply puts the tracker there through Edit Mode and the RestedXP skin's story rail puts the guide there (`KstyleUI_Skins/README.md`); the setup's cards and Layout Mode outline the slot. At the rail's foot the readout card with the menu docked under it, the damage card 16 over it, and the tooltip anchor 8 over the damage card, with the slot ending 16 over the anchor. A fixed tooltip grows up over the slot's foot, never over the damage meter you read in combat, the hands, your combat text or the bosses.
- **Boss column:** a rail gap left of the side bars' slots (bars 4 to 6), its foot a rail gap over your combat text, growing up (`boss.growth = UP`): boss1 sits at the foot beside the cluster, so a lone boss, the usual pull, reads next to your target rather than alone at the top of the screen (round 6, Grok #4); five fill the column upward, clear of the meters at every aspect. Healer heads the left rail with it and grows it down.
- **Centre (LEE-20):** a continuous 491 x 8 XP track at bottom 36.5 with its caption below; two enabled 491 x 36.7 action rows at bottoms 54 and 95.3, made from twelve square 36.7 tiles with 4.6 gaps and empty tiles shown; the player's 491 x 77.5 bar column at bottom 138; the target's 491 x 102.5 bar column at bottom 217.5. Both bar columns share x 0 with the action rows and XP. The 243.2 x 36.7 essential row sits at 335.3, the optional swing timer at 376.5, and the separate 347 x 30 player cast at 385.5. The optional class resource sits at bottom 420, 4.5 above the cast: its 14-unit height cannot fit safely in the 15.3-unit target-to-cooldown gap once positions and sizes snap independently to physical pixels. Portraits stay enabled with their setting retained.
- **External portraits and buffs (LEE-20):** the player portrait extends 91.5 left of its bar column, with a further 4-unit pixel-snapping buffer, so its reserve is 586.5 x 77.5 with offsetX -47.75. The target portrait and four debuff slots extend 230.4 right of its bar column, with a further 16-unit buffer for accumulated pixel rounding at 720 pixels and Interface size 0.6, so its reserve is 737.4 x 102.5 with offsetX 123.2. These buffers do not change either 491-unit visual bar column. Positions always anchor the bar column, not the reserve's centre. Tracked buff icons reserve 182.6 x 41.6 beside the player portrait at x -442.8, bottom 155.9. The optional utility row retains x 218 at bottom 335.3 and tracked bars sit at x -480, bottom 340.
- **Optional combat slots:** the focus reserve remains at x -357, bottom 428, its target below it; the target of target remains at x 317, bottom 518, opposite the focus cap at 540. The optional pet frame remains at x -317, bottom 258; pet and stance sockets keep x -337.5 and 337.5, bottom 68, with reputation and honour at bottom 52 below them. The separate target cast stays off at bottom 640 because the target frame carries an inline cast. Your combat text and boss column keep their original slots, and the 520-unit-wide world column above bottom 664 stays clear.
- **Tank** brings the threat card into the cluster, 200 by 112 under the target of target.
- **Healer** keeps the party and raid's original upper-left combat slots: their right edge 152 units off the centre line, bottom 556. Rows are 46 units and up to two dispellable debuffs show first on each frame. The boss column heads the left rail, its debuffs hanging right of the cards, towards the centre (the layouts write `boss.auraPosition` RIGHT here and LEFT in DPS and Tank). The right rail and centre column match DPS, and your combat text mirrors the group frames 152 right of the centre line.
- **Right rail budget:** the lens card (160), then the damage card 16 under it. The buff row and the debuff row (306.5 by 41.5 each, 8 apart) stand 10.9 left of the map, 1.4 units under the margin (the picture's 48 px tiles at a 54 px pitch, LEE-69), growing left; `test-setup-collisions.lua` and `test-auras-counts.lua` check the live rows at 0, 2, 8, 24 and 40 buffs beside 12 debuffs at every aspect.
- **Spare bars (LEE-20):** bars 3 to 6 stay off with free slots. Bar 3's 489 x 38 row uses BOTTOMLEFT at screenMargin (17), bottom 431.5, derived from the greater of the loot-feed top and player-cast top plus a 16-unit gap. It stays above the loot feed's full reserve (233 to 377) and outside the central 40% band at every reference aspect. Bars 4, 5 and 6 are 36.7 x 491 columns, the centre bars' slots at their 4.6 gap (72 px a step on the picture's screen), 1.4 units inside the screen margin, side by side from the right edge of the rail, bar 4 outermost. Turning an optional bar on moves nothing else.

### Why the target shares the player's column

LEE-20 replaces the earlier top sigil with the picture's target directly over the player. Their bars align, while the portraits and target debuffs remain outside the column, so the centre reads as one stack without shrinking the bars to make room for portraits.

A player can still move either frame in Layout Mode. Applying a preset restores the reference column; changing Interface size keeps its bottom offsets rather than lifting a top-anchored sigil.

| Function | Behaviour |
| --- | --- |
| `Get(name, rootHeight) -> { [key] = { anchor, x, y } }` | A copy of the layout's positions on the shipped 1282.5-unit canvas. Player and target use bottom-anchored bar-column centres, unchanged by `rootHeight`; their asymmetric reserves do not alter the registered positions. |
| `Upgrade(saved, preset, rootHeight) -> moved` | Store migration 7: moves each saved position still at a place a preset had before owner pass 1 (the 1080-unit canvas: the hands, the cluster, the boss column, the old bar columns, Tank's threat card and Healer's group frames) to that preset's place now, the profile's preset first. A field Layout left out because it equalled the old default is read as that default before matching. A position the player moved stays. Store drops positions equal to their defaults, so without it a Healer or Tank profile kept its group frames or threat card over the risen sigil |
| `UpgradeCentre(saved, rootHeight)` | Store migration 11, after the chat migration: upgrades saved centre positions still matching the pre-picture defaults and removes their old default sizes. Custom positions and sizes stay; missing position fields are interpreted using the old defaults before matching. |
| `BUTTON`, `HEIGHT` | The retained 38-unit optional button size, and the canvas height; central action tiles and essential icons use 36.7 under LEE-20. |
| `Footprint(name, key) -> width, height, offsetX` | The layout's own size (Healer's group frames, Tank's threat card), else the element's reserve (`Reserves`), else its footprint; the third result offsets asymmetric player/target reserves from their bar-column anchors. |
| `Rect(element, position, rootWidth, rootHeight) -> left, bottom, right, top` | Resolves the footprint and adds `element.offsetX` horizontally. A preview or collision caller passes all three `Footprint` results as width, height and offsetX. |
| `Shown(name, key) -> boolean` | Whether the layout switches the element on |
| `Settings(name) -> { { module, key, value }, ... }` | The module settings Apply writes |
| `Slot(name, rootHeight) -> { key, anchor, x, y, width, height, label, hint }` | The story slot, as a position with a size: the right rail's 318 columns from 16 under the map and the aura rows, whichever reaches lower, to 16 over the tooltip anchor. Its top hangs from the root's top and its foot stands on the bottom stack, so a shorter root (a larger Interface size) shortens it. |
| `Sizes(name) -> { [key] = { width, height } }` | The sizes Apply writes through Layout with the positions: the meters' sizes (six damage rows; in Tank the threat card at 200 by 112 in the cluster) |
| `Dock(key) -> hostKey` | The card a docked element sits in: the micro menu and the bag bar in the readout card. Not live while docked; its position is inside the host, where it stays when the player undocks it |
| `Reserves() -> { { key, width, height, offsetX }, ... }` | The room beyond an element's frame: player portrait 586.5 x 77.5 at offsetX -47.75; target portrait and auras 737.4 x 102.5 at offsetX 123.2; the focus card's 112 height, boss column's 318 width, and readout card's 118 height. A reserve is never smaller than its element. |

Saved custom positions stay as they are; Store migrations upgrade positions that still match superseded preset defaults. A profile that never stored a position gets the reference DPS position from `Layouts.Default`. Bottom-anchored player and target columns keep their relative placement when the Interface size changes.
