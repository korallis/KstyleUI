# Layout element keys

Every element a module shows registers with Layout under one key from this page:

```lua
KstyleUI.Layout.Register(frame, "unitframes.player", KstyleUI.Setup.Layouts.Default("unitframes.player"), opts)
```

The first-run setup writes the DPS, Tank or Healer position of each key into the profile's layout, so a module that registers under another key is never placed by the setup. Use the keys exactly as written. `test-setup-layouts.lua` fails when this page, `Core/Setup/Layouts.lua` and the plan's key list disagree.

## Rules

- A key is `<module>.<element>` in lower case, where `<module>` is the module's folder name without `KstyleUI_`. Sub-elements add a part: `unitframes.castbar.player`.
- Pass `KstyleUI.Setup.Layouts.Element(key).label` as `opts.label`, so the mover plate and the settings window use the same name as the setup.
- Pass `KstyleUI.Setup.Layouts.Default(key)` as the default position. It returns a fresh `{ anchor, x, y }`: the DPS layout's position, so a profile that never ran the setup still gets the Lumen layout. It raises an error for a key this page does not list, so a typo fails the module's test.
- Build the element at its footprint, or smaller, at the 1080 reference. The layouts are planned so that no two elements overlap at 1920x1080, 2560x1440, 3840x2160 and 3456x2234 when each element fits its footprint. An element that needs more room changes its footprint here and in `Core/Setup/Layouts.lua` in the same pull request, and `test-setup-layouts.lua` must still pass.
- The position anchors the element's own point to the same point of `KstyleUI_Root`: `BOTTOM` with `x = -279, y = 113` puts the element's bottom centre 279 units left of the screen's bottom centre and 113 units up. Offsets are root units: at the Interface size KstyleUI ships (16 / 19) the root is 1282.5 units tall (`Setup.Layouts.HEIGHT`), 2280 units wide at 16:9 and about 1984 units wide on a 3456x2234 Mac; at size 1 it is 1080 tall.
- Nameplates sit on Blizzard's plates and have no position key. Their size comes from a Layout Mode sample listed under [Elements outside the layouts](#elements-outside-the-layouts). Combat text numbers on unit, group and nameplate frames ride those frames and have no key either; only the player's own field, `combattext.player`, has one. A module element not listed here, such as a settings window, picks a key in the same form and adds a row in the same pull request. Core windows are listed under [Core windows](#core-windows), outside the layouts.

## Keys

Footprints are width x height in root units. The centre column follows the owner's 2026-11-09 picture ruling, LEE-20, superseding the older sigil and single-action-row arrangement. A footprint followed by the room the layouts keep is a reserve (`Setup.Layouts.Reserves()`): the element's frame is its footprint. `Footprint(name, key)` also returns the reserve's `offsetX`; pass it to `Rect` to measure the external portrait and aura space without moving the bar column's registered anchor.

KSTY-49 (2026-11-13): the Frames tray card, at the KSTY-44 mock-ups' size, lifts every element of the centre stack by `Layouts.TRAY_LIFT` (31 units): the player, target, cast bars, class resource, pet and focus frames, target of target, cooldown rows, swing timer, threat card and combat text, and in Healer the party and raid. A position below quoted from LEE-20 is before that lift; `Setup.Layouts` holds the live values.

| Key | Module | Element | Footprint | Shape the layouts plan for |
| --- | --- | --- | --- | --- |
| `unitframes.player` | UnitFrames | Player frame | 491 x 77.5 (the layouts keep 586.5 x 77.5, offsetX -47.75) | LEE-20: the bar column is centred at x 0, bottom 138, 6 over bar 2; the portrait stands 91.5 outside its left edge, with another 4 units reserved for pixel snapping. Name and class sit over flat health and power bars; the player cast is separate |
| `unitframes.target` | UnitFrames | Target frame | 491 x 102.5 (the layouts keep 737.4 x 102.5, offsetX 123.2) | LEE-20: the bar column shares the player's centre and width, bottom 217.5, 2 above the player; the portrait and four debuff slots extend 230.4 outside its right edge, with another 16 units reserved for accumulated pixel rounding at 720 pixels and Interface size 0.6. Reversed health and power bars and an inline target cast replace the sigil |
| `unitframes.targettarget` | UnitFrames | Target of target | 120 x 22 | The unchanged optional pill row at x 317, bottom 518. Tank: the threat card stands under it |
| `unitframes.focus` | UnitFrames | Focus frame | 200 x 90 (the layouts keep 200 x 112) | The unchanged optional focus card at x -357, bottom 428, with its debuffs above the card inside the 112-unit reserve |
| `unitframes.focustarget` | UnitFrames | Focus target | 120 x 22 | A pill row 4 units under the focus card, left-aligned |
| `unitframes.pet` | UnitFrames | Pet frame | 120 x 22 | The unchanged optional pill row at x -317, bottom 258 |
| `unitframes.boss` | UnitFrames | Boss frames | 222 x 334 (the layouts keep 318 x 334) | The boss column: five compact 222 by 62 boss cards 6 apart (name and percentage, pill, cast line; no cap), their debuffs in one row of four 22-unit sockets to the left (three and the "+N" chip, the timer in a corner badge), inside the 318 the layouts keep. The boss you target collapses to a slim Targeted chip on the column's rail edge, as the sigil carries its full read. DPS and Tank: on the centre's right edge, a rail gap left of the side bars' slots (bars 4 to 6), its foot a rail gap over your combat text. Healer: at the head of the left rail |
| `unitframes.castbar.player` | UnitFrames | Player cast bar | 347 x 30 | LEE-20: on in all presets, centred at bottom 385.5 above the essential cooldowns; tracked heading, elapsed / total time and a tan bar 14 units tall, two thirds of the health bar (KSTY-60 item 4) |
| `unitframes.castbar.target` | UnitFrames | Target cast bar | 220 x 32 | Off by default because the target frame carries its cast line; the optional separate bar retains its centred slot at bottom 640 |
| `unitframes.resource` | UnitFrames | Class resource | 120 x 14 | Combo points and the druid's mana, centred at bottom 420, 4.5 above the player cast; the target-to-cooldown gap cannot hold this optional row safely after independent pixel snapping |
| `groupframes.party` | GroupFrames | Party frames | 259 x 247 | The bare party at mid-left, where both KSTY-44 mock-ups draw it (KSTY-60 item 6): its 259-unit holder (the mock-up's 194-unit row and its debuff lane, KSTY-57), five 39-unit rows 13 apart, centred on the left margin so the DPS party's top is 465 under the top of the 1282.5-unit canvas, in both HUD styles. Healer: 259 x 267, five 43-unit rows, the same place. Under Spread it keeps to the 21:9 column's left edge |
| `groupframes.raid` | GroupFrames | Raid frames | 543 x 505 | The raid card (KSTY-57): four groups a row of five 116 by 36 rows at 20 players (543 wide), two rows of compact 96 by 28 rows at 40 under the card's cap, gap and padding (its real 505-unit holder, KSTY-64), at the top left in both HUD styles: the card's real size leaves it no room at mid-left over the loot feed. Healer: 623 x 505, 20 units wider rows for three heals, at the top left. Under Spread it keeps to the 21:9 column's left edge |
| `actionbars.bar1` | ActionBars | Action bar 1 | 580.6875 x 45.125 | KSTY-44 tray: 12 square tiles of 38 px with 3 px gaps at 1080p (45.125 and 3.5625 units), the bottom row of the tray card, 10.6875 over its bottom edge at 47.5; enabled with empty tiles shown |
| `actionbars.bar2` | ActionBars | Action bar 2 | 580.6875 x 45.125 | KSTY-44 tray: the top row of the tray card, 3.5625 over bar 1; the card top edge, `Layouts.TRAY_TOP`, is 10.6875 above it. Enabled with empty tiles shown |
| `actionbars.bar3` | ActionBars | Action bar 3 | 489 x 38 | LEE-20: off by default, its unchanged-size row has a BOTTOMLEFT slot at screenMargin (17), bottom 462.5 (431.5 plus the tray lift) derived from the rail stack and cast height, at least 16 over the loot feed's full reserve and the player cast and outside the central 40% band |
| `actionbars.bar4` | ActionBars | Action bar 4 | 36.7 x 491 | On in every Lumen layout (the owner's picture wins, LEE-20, 2026-11-09): the right column of the two-column block in the right rail, 1.4 units inside the screen margin (the picture's rail stands 32 px in on its 2234 px screen) under the story slot and 10 over the readout line: twelve 36.7-unit slots 4.6 apart, the centre bars' pitch (72 px), every empty slot drawn as a tile. #208's column left of the rail is gone |
| `actionbars.bar5` | ActionBars | Action bar 5 | 36.7 x 491 | On in every Lumen layout (the owner's picture wins, LEE-20, 2026-11-09): the left column of the rail's two-column block, 4.6 units left of bar 4 |
| `actionbars.bar6` | ActionBars | Action bar 6 | 36.7 x 491 | Off in Lumen. A third column 4.6 units left of bar 5 at the same height, so its slot costs the rail no height and the HUD size cap no room |
| `actionbars.pet` | ActionBars | Pet bar | 129 x 96 | Three rows of four 30-unit sockets left of the tray card, on its bottom edge, narrow enough to leave the chat-side column free for the tracked buffs |
| `actionbars.stance` | ActionBars | Stance bar | 129 x 96 | Three rows of four 30-unit sockets right of the tray card, on its bottom edge |
| `cooldowns.essential` | Cooldowns | Essential cooldowns | 243.2 x 36.7 | LEE-20: 6 square 36.7 icons at 41.3 pitch, centred at bottom 366.3 (335.3 plus the tray lift), above the target and below the player cast |
| `cooldowns.utility` | Cooldowns | Utility cooldowns | 161 x 38 | 4 optional 38-unit icons with 3-unit gaps; x 218, bottom 366.3, beside the essential row |
| `cooldowns.buffs` | Cooldowns | Tracked buff icons | 182.6 x 41.6 | 27.6-unit icons at the left end of the essential cooldown row, a cluster gap off it and on its foot (KSTY-60 item 28; it was beside the player portrait), where Apply also puts Blizzard's BuffIconCooldownViewer |
| `cooldowns.bars` | Cooldowns | Tracked buff bars | 243 x 43 | Two optional 243 by 20 bars with a 3-unit gap, x -480, bottom 340 |
| `auras.buffs` | Auras | Buffs | 306.5 x 41.5 | One row of ten 27.5-unit square icons 3.5 apart (the picture's 48 px tiles at a 54 px pitch), in listed order with the first at the left, timers under them, 11.9 units left of the map's square and 1.4 units under the screen margin (the owner's picture wins, LEE-20, 2026-11-09); #209's two rows of eight are gone. The rest past ten read +N |
| `auras.debuffs` | Auras | Debuffs | 306.5 x 41.5 | The same row for debuffs, right-aligned under the buffs, 8 under them; its own live element |
| `minimap.main` | Minimap | Minimap | 208 x 208 (the layouts keep 208 x 244) | The square map at the head of the right rail, its forged card (3 units outside the square) ending on the card margin like the cards under it (KSTY-60 item 28): a 208 square (the KSTY-44 mock-up's, KSTY-64; it was 188) in a 1 px gilt rim with the round N plate on its top edge and the tracking, calendar and drawer buttons down the inside of its right edge at rest; the zone in caps under it, the coordinates and the clock on the line under that, in the 36 units the layouts keep below the map |
| `chat.main` | Chat | Chat | 442 x 186 | The mock-up's 442-unit chat card (KSTY-64; it was 393; the Orbs bare chat keeps 393), the picture's chat card (186 high: its own edge, not the loot line above it, LEE-69) at the left rail's foot, on the 17-unit screen margin (LEE-20: the picture wins over #210's 372 by 260), in every preset |
| `databars.xp` | DataBars | Experience bar | 491 x 8.3125 | KSTY-44 and KSTY-50: the mock-up's 7 px strip (8.3125 units, KSTY-60 item 28), its top 9 mock-up px under the tray card (`Layouts.TRAY_BOTTOM` less 10.6875), ticked into ten segments, with the level, XP percentage and rested caption below it |
| `databars.rep` | DataBars | Reputation bar | 162 x 5 | Under the pet sockets, unchanged at bottom 52 |
| `databars.honor` | DataBars | Honour bar | 162 x 5 | Under the stance sockets, unchanged at bottom 52: Forever's PvP rank, or honour |
| `databars.strip` | DataBars | Data strip | 278 x 12 | The readout (the owner's picture wins, LEE-20, 2026-11-09): one right-aligned line of text with no card, "162 fps · 15 ms · 26s 16c", 6 over the damage card. Durability leaves the default line and stays a slot choice. The micro menu and the bag bar are hidden by default and no longer dock in it by default (`strip.menus` off) |
| `databars.micro` | DataBars | Micro menu | 318 x 44 | Hidden by default. Its own slot left of the rail's bar columns, on the bars' foot |
| `databars.bags` | DataBars | Bag bar | 212 x 32 | Hidden by default. Its own slot over the micro menu's |
| `meters.damage` | Meters | Damage meter | 269 x 158 | The damage card at the right rail's foot, on the screen margin (the owner's picture wins, LEE-20, 2026-11-09): a DAMAGE cap with the dps over five school-coloured bars. The readout line stands over it |
| `meters.threat` | Meters | Threat meter | 200 x 112 | Shown in Tank only, out of the clear centre (KSTY-64; it covered nameplates under the target of target): in Frames under the quest card's column, a rail gap over the target's top; in Orbs over the rail bars. Off elsewhere |
| `meters.swing` | Meters | Swing timer | 260 x 8 | LEE-20: the optional slim bar is centred at bottom 376.5, 4.5 above the essential cooldowns |
| `combattext.player` | CombatText | Your combat text | 160 x 149.3125 | The field your incoming damage and heals rise through, right of the clear centre, 16 units over the combat cluster and under the boss column. Healer: just right of the character's column |
| `qol.lootfeed` | QoL | Loot feed | 318 x 144 | Up to four short lines of what you loot, an icon tile, the name in its quality colour, a stack count, on the chat card's window glass (same panel, gold corner marks) that hugs the lines, 16 units over the chat card on its left edge. The card shows only while a line does |
| `tooltips.anchor` | Tooltips | Tooltip anchor | 180 x 24 | The corner fixed tooltips grow from: left of the rail's bar columns, over the micro menu's and bag bar's slots, on no card, so a tooltip grows up over the play field and never covers the rail |

The story slot is not an element. Each layout has one (`Setup.Layouts.Slot(name)`): the right rail's 278-unit column 16 under the minimap's caption and 12 over bars 4 and 5, which stand over the readout line and the damage card (the owner's picture wins, LEE-20, 2026-11-09). The quest card and the RestedXP guide's story rail sit there, and Apply places Blizzard's quest tracker there through Edit Mode; KstyleUI never moves Blizzard's tracker with code. The setup's previews and Layout Mode draw its outline.

## Core windows

These keys belong to core windows. The layouts do not place them.

- `setup.window`: the first-run setup window. Scalable, 40 units above the centre.

## Elements outside the layouts

These module elements register with Layout, but the layouts do not place them.

- `nameplates.plate`: a sample nameplate that shows only in Layout Mode. Resizable from 40 x 4 to 320 x 40; its size is the size of every KstyleUI nameplate. 160 units above the centre.
- `bags.inventory`: the bag window, which opens on demand over the HUD. Scalable; its size follows the slot settings. Bottom right, 134 units up, above the bag bar.
- `bags.bank`: the bank window, which opens at a banker. Scalable; its size follows the slot settings and the bank's columns. Top left, 60 units in and 110 down.
- `chat.copy`: the copy-chat window, which opens on demand. Resizable from 320 x 200 to 1400 x 1000, 560 x 380 by default. 40 units above the centre; dragging its title bar saves a new position.

## Layouts

`Core/Setup/Layouts.lua` holds the three layouts as data, keyed by element key. Each layout gives every key above a position.

| Layout | What it places |
| --- | --- |
| DPS | The Lumen Rails with the LEE-20 picture's centre column: XP, two action rows, player, target, essential cooldowns and separate player cast; tracked buffs left of the external player portrait. The rails, boss column and optional focus/target-of-target slots stay unchanged |
| Tank | The threat card joins the combat cluster under the target of target |
| Healer | Party and raid frames stand on the cluster's left half; the boss column heads the left rail over chat; the right rail as in DPS |

Party and raid frames never show together, so they may share space. On 4:3 and 5:4 screens the chat panel and the player frame overlap; the player moves one of them in Layout Mode.

## Functions

| Function | Behaviour |
| --- | --- |
| `Setup.Layouts.Default(key) -> position` | The DPS position as a fresh table. Raises an error for an unknown key. |
| `Setup.Layouts.Get(name) -> { [key] = position }` or `nil` | A copy of a layout: `"DPS"`, `"Tank"` or `"Healer"`. |
| `Setup.Layouts.Names()`, `Label(name)`, `Note(name)` | The layout names in order, and each one's label and one-line note for the setup |
| `Setup.Layouts.Element(key) -> element` or `nil` | `{ key, module, label, width, height }` from `Setup.Layouts.ELEMENTS` |
| `Setup.Layouts.Footprint(name, key) -> width, height, offsetX` | The reserved size and optional horizontal offset from the element's anchor. Player and target positions centre the bars, not their asymmetric portrait reserves. |
| `Setup.Layouts.Rect(element, position, rootWidth, rootHeight) -> left, bottom, right, top` | Where an element's footprint lands on a root of that size, in root units from the bottom left; applies `element.offsetX` for asymmetric reserves. The setup's preview and the tests use it. |
