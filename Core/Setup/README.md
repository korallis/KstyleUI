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
3. For each `{ module, key, value }` in `Layouts.Settings(layout)` whose module loaded and has that setting, `Options.Write(module, key, value)`: bars 2 to 6 off and bar 1 one row, the pet and stance sockets in two rows of five (the stance sockets growing up from bar 1's baseline), the threat card on in Tank only, one row of buffs in the Blessings card with the debuffs docked, the menu and bags docked in the readout card, every bar's empty sockets hidden (a spell on the cursor still shows them), the raid in four groups a row at 77 units wide, and the party and raid row heights (Healer's are larger, with two dispellable debuffs first). The positions carry `Layouts.Sizes(layout)` too: the meters' heights. Settings of a module that did not load are skipped and counted.
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
   - icons: one row hung from the `cooldowns.buffs` slot's bottom right, growing left (`IconDirection` Left) with 8 units between sockets; else one column (`Orientation` Vertical, `IconDirection` Right, growing up) beside the cluster, just left of the focus card, from the slot's baseline or from chat's foot, slid left past anything it meets; else the same column beside the right rail;
   - bars: a stack on the `cooldowns.bars` slot's bottom right, as wide as the icon row under it so both share one left and one right edge; else under the target of target, where Tank keeps its threat card; else over the focus card.
   Icons are never taller than 30 root units, bars never taller than 24; `BarWidthScale` is written from the stack's width (Edit Mode reads it as the stored value plus its slider's 50 minimum, `ConvertValueDefault`). At 16 icons and 6 bars every preset fits at 16:9, 16:10, 21:9 and the owner's 2383 by 1540 screen (`test-setup-editmode.lua`). The bars also try a column beside the right rail, trimmed clear of the target of target and the utility row; the over-focus spot trims around bar 2's column the same way. The writer first keeps bar 2's column free (bar 2 is on by default and Apply switches it off, so a player may turn it back on), and tries the icons first, then the bars first; only when no arrangement holds both does it give bar 2's column up. Placement is all or nothing: a viewer is moved only to a place that holds every tracked item whole (round 5, Astra #1). A viewer that fits nowhere keeps the place it had, untouched, and the setup summary and chat name the count and how many would fit, with the Cooldown Manager and Try again as the way out, or Edit Mode to place it by hand.
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

DPS, Tank and Healer place every element on the Lumen Rails: two 318-unit rails on a 28-unit margin and one combat cluster at the bottom centre: the hands, and right on them your target, its target and your focus. `test-setup-layouts.lua` holds the composition rules; `test-setup-collisions.lua` resolves every layout at 16:9, 16:10 and 21:9 and fails on any element off screen or overlapping another, each at the full footprint it draws.

- **Left rail:** the party card (the raid card in a raid) at the top, chat at the foot, and between them the story slot for the RestedXP guide and the quest tracker. Apply puts the tracker there through Edit Mode and the RestedXP skin's story rail puts the guide there (`KstyleUI_Skins/README.md`). The setup's cards and Layout Mode outline the slot. Chat is 260 tall, so the slot holds the guide and three quests.
- **Right rail:** the lens card, the Blessings card (one row of buffs, the debuffs docked under them), the damage card, and the readout card with the menu docked under it at the foot. Cards sit 16 to 22 units apart. The tooltip anchor lies on the readout card, so a fixed tooltip covers the idle readout and grows up the rail, never over the hands, your combat text or the bosses.
- **Boss column:** 16 units in from the right rail, its foot a rail gap over your combat text, growing up (`boss.growth = UP`): boss1 sits at the foot beside the cluster, so a lone boss, the usual pull, reads next to your target rather than alone at the top of the screen (round 6, Grok #4); five fill the column upward, clear of the meters at every aspect. Healer heads the left rail with it and grows it down.
- **Centre:** the XP line 52 units up with its caption under it on the 34-unit margin, bar 1 12 units over it, the vitals line 12 over bar 1, the class resource, the essential cooldowns with the swing line 6 units over them and the utility row and the tracked buffs beside them. The pet and stance sockets sit beside bar 1's ends, with the reputation and honour lines under them on the XP line's baseline.
- **Combat cluster:** right on that block (13 units over the tracked buff bars) the target sigil, 490 wide like the vitals line, its debuff sockets under it; the focus card 12 units to its left, top-aligned, its target under it; the target of target 12 units to its right, top-aligned. The plate cast bars, for a player who turns them on, stack over the cluster, `Layouts.SIGIL_CLEAR` (16) and one bar's room over the sigil cap. Bar 2 is a column of twelve a rail gap in from the left rail, bars 3 to 6 beside it, never over the character (round 5, Opus #2). Your combat text rises right of the cluster, under the boss column's foot. The world over the cluster, 520 units wide, stays clear.
- **Tank** brings the threat card into the cluster, 200 by 112 under the target of target.
- **Healer** stands the party and raid on the cluster's left half: their right edge 152 units off the centre line, 16 left of the player's cast bar, their foot 16 units over the cluster. Rows are 46 units and up to two dispellable debuffs show first on each frame. The boss column heads the left rail over the story slot, its debuffs hanging right of the cards, towards the centre (the layouts write `boss.auraPosition` RIGHT here and LEFT in DPS and Tank), the right rail keeps the DPS stack (the damage card under the Blessings), the spare bars 3 to 6 stand left of the right rail, bar 2 stands a rail gap under bar 3, the plate cast bars stay over the cluster where DPS keeps them, and your combat text mirrors the group frames 152 right of the centre line.
- **Right rail budget:** the lens card (346), the Blessings card at its cap (230: one buff row, the hairline and two docked debuff rows, the reserve `test-setup-collisions.lua` checks against the live card at 0, 8, 24 and 40 buffs beside 12 debuffs), then the damage card 16 under it.
- **Spare bars:** bars 2 to 6 are off in every layout. Bar 2 and bars 3 to 6 are columns of twelve beside the rails, out of the play field (`test-setup-collisions.lua` keeps every action bar out of the centre column above the sigil and the screen's central 40% band), apart from everything at 16:9, 16:10 and 21:9. On a narrower screen (the 16:10.3 MacBook) a column of bar 3 or 4 touches the sigil, so a player who turns one on there places it.

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
| `Slot(name) -> { key, anchor, x, y, width, height, raid, label, hint, raidHint }` | The story slot, as a position with a size: from 16 under the left rail's head (the party card, or Healer's boss column) to 16 over chat. `raid` is how far the raid card, taller than the party card, reaches down into the slot in a raid (a 1080-unit rail has no room to keep them apart); 0 in Healer, whose raid stands on the cluster, and then there is no `raidHint`. |
| `Sizes(name) -> { [key] = { width, height } }` | The sizes Apply writes through Layout with the positions: the meters' sizes (six damage rows; in Tank the threat card at 200 by 112 in the cluster) |
| `Dock(key) -> hostKey` | The card a docked element sits in: the debuff row in the Blessings card, the micro menu and the bag bar in the readout card. Not live while docked; its position is inside the host, where it stays when the player undocks it |
| `Reserves() -> { { key, width, height }, ... }` | The room the layouts keep for an element whose frame is another size: the sigil's 136 (its debuff sockets hang under its 84-unit frame), the focus card's 112, the boss column's 318 (its row of debuffs hangs left of its 222-unit cards) and the Blessings card's 230 at its cap. A reserve is never smaller than its element |

Saved layouts stay as they are until the player applies a layout again. A profile that never stored a position gets the Lumen DPS position from `Layouts.Default`.
