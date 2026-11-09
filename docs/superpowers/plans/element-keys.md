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

| Key | Module | Element | Footprint | Shape the layouts plan for |
| --- | --- | --- | --- | --- |
| `unitframes.player` | UnitFrames | Player frame | 491 x 80 (the layouts keep 582.5 x 80, offsetX -45.75) | LEE-20: the bar column is centred at x 0, bottom 138, 6 over bar 2; the portrait stands outside its left edge, inside the reserve's extra 91.5 units. Name and class sit over flat health and power bars; the player cast is separate |
| `unitframes.target` | UnitFrames | Target frame | 491 x 100.5 (the layouts keep 721.4 x 100.5, offsetX 115.2) | LEE-20: the bar column shares the player's centre and width, bottom 219.5, 1.5 above the player; the portrait and your debuffs sit outside its right edge, inside the reserve's extra 230.4 units. Reversed health and power bars and an inline target cast replace the sigil |
| `unitframes.targettarget` | UnitFrames | Target of target | 120 x 22 | The unchanged optional pill row at x 317, bottom 518. Tank: the threat card stands under it |
| `unitframes.focus` | UnitFrames | Focus frame | 200 x 90 (the layouts keep 200 x 112) | The unchanged optional focus card at x -357, bottom 428, with its debuffs above the card inside the 112-unit reserve |
| `unitframes.focustarget` | UnitFrames | Focus target | 120 x 22 | A pill row 4 units under the focus card, left-aligned |
| `unitframes.pet` | UnitFrames | Pet frame | 120 x 22 | The unchanged optional pill row at x -317, bottom 258 |
| `unitframes.boss` | UnitFrames | Boss frames | 222 x 334 (the layouts keep 318 x 334) | The boss column: five compact 222 by 62 boss cards 6 apart (name and percentage, pill, cast line; no cap), their debuffs in one row of four 22-unit sockets to the left (three and the "+N" chip, the timer in a corner badge), inside the 318 the layouts keep. The boss you target collapses to a slim Targeted chip on the column's rail edge, as the sigil carries its full read. DPS and Tank: on the centre's right edge, a rail gap left of the side bars' slots (bars 4 to 6), its foot a rail gap over your combat text. Healer: at the head of the left rail |
| `unitframes.castbar.player` | UnitFrames | Player cast bar | 347 x 30 | LEE-20: on in all presets, centred at bottom 385.5 above the essential cooldowns; tracked heading, elapsed / total time and a tan bar |
| `unitframes.castbar.target` | UnitFrames | Target cast bar | 220 x 24 | Off by default because the target frame carries its cast line; the optional separate bar retains its centred slot at bottom 640 |
| `unitframes.resource` | UnitFrames | Class resource | 120 x 14 | LEE-20: combo points and the druid's mana, centred at bottom 320.6 between the target and essential cooldowns |
| `groupframes.party` | GroupFrames | Party frames | 318 x 324 | S4's party card at the head of the left rail: a Party cap, five 40-unit rows with 8-unit gaps (role ring, name, class line, class pill). Healer: 318 x 354, five 46-unit rows, on the combat cluster's left half, its right edge 116 units left of the centre line, 16 units over the cluster |
| `groupframes.raid` | GroupFrames | Raid frames | 318 x 427 | Four groups a row, two rows, five 77 by 40 frames each, 3-unit gaps, on the left rail's column. Healer: 318 x 487, 46-unit frames, in the party card's place over the cluster |
| `actionbars.bar1` | ActionBars | Action bar 1 | 491 x 36.7 | LEE-20: 12 square tiles of 36.7 units with 4.6-unit gaps, centred at bottom 54; enabled with empty tiles shown |
| `actionbars.bar2` | ActionBars | Action bar 2 | 491 x 36.7 | LEE-20: enabled with empty tiles shown, centred at bottom 95.3, 4.6 over bar 1 |
| `actionbars.bar3` | ActionBars | Action bar 3 | 489 x 38 | LEE-20: off by default, its unchanged-size row now has a BOTTOMLEFT slot at x 28, bottom 428, above chat and outside the central 40% band |
| `actionbars.bar4` | ActionBars | Action bar 4 | 38 x 489 | Off in Lumen. A side bar: a column of twelve on the right edge of the play field, a rail gap left of the right rail, centred on the screen's height |
| `actionbars.bar5` | ActionBars | Action bar 5 | 38 x 489 | Off in Lumen. A side bar: a column of twelve 3 units left of bar 4 |
| `actionbars.bar6` | ActionBars | Action bar 6 | 38 x 489 | Off in Lumen. A column of twelve 3 units left of bar 5; the boss column stands a rail gap left of it |
| `actionbars.pet` | ActionBars | Pet bar | 162 x 63 | Two rows of five 30-unit sockets, unchanged at x -337.5, bottom 68 |
| `actionbars.stance` | ActionBars | Stance bar | 162 x 63 | Two rows of five 30-unit sockets, unchanged at x 337.5, bottom 68 |
| `cooldowns.essential` | Cooldowns | Essential cooldowns | 243.2 x 36.7 | LEE-20: 6 square 36.7 icons at 41.3 pitch, centred at bottom 335.3, above the target and below the player cast |
| `cooldowns.utility` | Cooldowns | Utility cooldowns | 161 x 38 | 4 optional 38-unit icons with 3-unit gaps; x 218, bottom 335.3, beside the essential row |
| `cooldowns.buffs` | Cooldowns | Tracked buff icons | 182.6 x 41.6 | LEE-20: 27.6-unit icons and timer space beside the player portrait, x -442.8, bottom 155.9 |
| `cooldowns.bars` | Cooldowns | Tracked buff bars | 243 x 43 | Two optional 243 by 20 bars with a 3-unit gap, x -480, bottom 340 |
| `auras.buffs` | Auras | Buffs | 282 x 88 | Two rows of eight 30-unit icons beside the minimap's left edge, top-aligned with it, growing left then down: a plain tile each (icon in a thin rim, timer under it in the body face, stack count on a corner badge), the last cell a "+N" socket counted by the engine. Buffs the Cooldown Manager tracks are left out by default |
| `auras.debuffs` | Auras | Debuffs | 282 x 88 | The same rows for debuffs, 16 under the buffs, with the engine's dispel-type plate on each tile; its own live element |
| `minimap.main` | Minimap | Minimap | 160 x 160 | The square map at the head of the right rail, on the 17-unit screen margin (the owner's picture of 2026-11-09; 28 in owner pass 1): a 156 chamfered square inside a thin rim, the zone band along its top edge and the clock band along its bottom edge; the controls show on hover |
| `chat.main` | Chat | Chat | 393 x 200 | The picture's chat card at the left rail's foot, on the 17-unit screen margin (LEE-20: the picture wins over #210's 372 by 260), in every preset |
| `databars.xp` | DataBars | Experience bar | 491 x 8 | LEE-20: centred at bottom 36.5, 9.5 below bar 1, a continuous track with the level, XP percentage and rested caption below it |
| `databars.rep` | DataBars | Reputation bar | 162 x 5 | Under the pet sockets, unchanged at bottom 52 |
| `databars.honor` | DataBars | Honour bar | 162 x 5 | Under the stance sockets, unchanged at bottom 52: Forever's PvP rank, or honour |
| `databars.strip` | DataBars | Data strip | 318 x 42 (the layouts keep 318 x 118) | S4's readout card at the right rail's foot: by default the readout line alone, 30 units with the card's top padding and 12 under it. The micro menu and the bag bar are hidden by default; turned on, they dock under the line, the bag row wrapped under the micro row at 318, and the card grows up into the 118 units the layouts keep, so a row turned on moves nothing and the tooltip anchor stays clear of it |
| `databars.micro` | DataBars | Micro menu | 318 x 44 | Docked in the readout card and not live there. Placed at the card's foot |
| `databars.bags` | DataBars | Bag bar | 212 x 32 | Docked in the readout card and not live there. Placed in the card, over the micro menu's place |
| `meters.damage` | Meters | Damage meter | 318 x 190 | The damage card at the right rail's foot, 16 units over the readout card, under the story slot: six rows |
| `meters.threat` | Meters | Threat meter | 318 x 144 | Shown in Tank only: 200 x 112, which Apply writes, in the combat cluster under the target of target. Off elsewhere, on the damage card's place |
| `meters.swing` | Meters | Swing timer | 260 x 8 | LEE-20: the optional slim bar is centred at bottom 376.5, 4.5 above the essential cooldowns |
| `combattext.player` | CombatText | Your combat text | 160 x 180 | The field your incoming damage and heals rise through, right of the clear centre, 16 units over the combat cluster and under the boss column. Healer: just right of the character's column |
| `qol.lootfeed` | QoL | Loot feed | 318 x 144 | Up to four short lines of what you loot, an icon tile, the name in its quality colour, a stack count, on the chat card's window glass (same panel, gold corner marks) that hugs the lines, 16 units over the chat card on its left edge. The card shows only while a line does |
| `tooltips.anchor` | Tooltips | Tooltip anchor | 180 x 24 | The corner fixed tooltips grow from: 8 units over the damage card's right corner, on no card, so a tooltip grows up over the story slot's foot and never covers the damage meter, the readout or the menu you hover |

The story slot is not an element. Each layout has one (`Setup.Layouts.Slot(name)`): the right rail's column under the map and the aura rows, over the tooltip anchor, the damage card and the readout. The quest card and the RestedXP guide's story rail sit there, and Apply places Blizzard's quest tracker there through Edit Mode; KstyleUI never moves Blizzard's tracker with code. The setup's previews and Layout Mode draw its outline.

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
