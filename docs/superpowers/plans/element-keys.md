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
- The position anchors the element's own point to the same point of `KstyleUI_Root`: `BOTTOM` with `x = -279, y = 113` puts the element's bottom centre 279 units left of the screen's bottom centre and 113 units up. Offsets are root units: the root is 1080 units tall, 1920 units wide at 16:9 and about 1671 units wide on a 3456x2234 Mac.
- Nameplates sit on Blizzard's plates and have no position key. Their size comes from a Layout Mode sample listed under [Elements outside the layouts](#elements-outside-the-layouts). Combat text numbers on unit, group and nameplate frames ride those frames and have no key either; only the player's own field, `combattext.player`, has one. A module element not listed here, such as a settings window, picks a key in the same form and adds a row in the same pull request. Core windows are listed under [Core windows](#core-windows), outside the layouts.

## Keys

Footprints are width x height in units at the 1080 reference. A footprint followed by the room the layouts keep is a reserve (`Setup.Layouts.Reserves()`): the element's frame is its footprint, and the layouts place it by the reserve.

| Key | Module | Element | Footprint | Shape the layouts plan for |
| --- | --- | --- | --- | --- |
| `unitframes.player` | UnitFrames | Player frame | 490 x 80 | The Lumen vitals line over bar 1: a 62-unit portrait ring with its level disc, the name, a 12-unit health pill, a 5-unit power pill and the cast line inside, as wide as bar 1, 12 units over it |
| `unitframes.target` | UnitFrames | Target frame | 640 x 80 (the layouts keep 640 x 126) | The Lumen target sigil, centred 40 units under the top: name, level line, a gem-ended health pill and the cast line, with your debuffs as sockets hanging under it, inside the 126 the layouts keep |
| `unitframes.targettarget` | UnitFrames | Target of target | 120 x 22 | A pill row under the sigil's right end, beside the target cast bar |
| `unitframes.focus` | UnitFrames | Focus frame | 318 x 120 | The focus card at mid-left, 16 units right of the left rail, at the clear centre's outer edge |
| `unitframes.focustarget` | UnitFrames | Focus target | 120 x 22 | A pill row under the focus card, left-aligned |
| `unitframes.pet` | UnitFrames | Pet frame | 120 x 22 | A pill row beside the vitals line's ring, 12 units left of it, top-aligned |
| `unitframes.boss` | UnitFrames | Boss frames | 318 x 640 (the layouts keep 318 x 120) | Five 318 by 120 boss cards 10 apart on the right rail, under the Blessings. The rail keeps room for the first card only: in a fight with two or more bosses, the second card on reaches over the damage card |
| `unitframes.castbar.player` | UnitFrames | Player cast bar | 272 x 30 | Off under the Lumen style, whose cast line is inside the vitals line. Placed over the essential cooldowns for the classic plate |
| `unitframes.castbar.target` | UnitFrames | Target cast bar | 220 x 24 | Off under the Lumen style, whose cast line is on the sigil. Placed 8 units under the sigil's sockets for the classic plate |
| `unitframes.resource` | UnitFrames | Class resource | 120 x 14 | Combo points and the druid's mana, centred between the vitals line and the essential cooldowns |
| `groupframes.party` | GroupFrames | Party frames | 318 x 324 | S4's party card at the head of the left rail: a Party cap, five 40-unit rows with 8-unit gaps (role ring, name, class line, class pill). Healer: 318 x 354, five 46-unit rows |
| `groupframes.raid` | GroupFrames | Raid frames | 318 x 427 | Four groups a row, two rows, five 77 by 40 frames each, 3-unit gaps, on the left rail's column. Healer: 318 x 487, 46-unit frames |
| `actionbars.bar1` | ActionBars | Action bar 1 | 489 x 38 | 12 buttons of 38 units with 3-unit gaps in one row, 12 units over the XP line |
| `actionbars.bar2` | ActionBars | Action bar 2 | 489 x 38 | Off in Lumen. Placed at the top of the hands, over the swing timer, for a player who turns it on |
| `actionbars.bar3` | ActionBars | Action bar 3 | 38 x 489 | Off in Lumen. A column of 12 at the top of the right side, 16 units left of the right rail |
| `actionbars.bar4` | ActionBars | Action bar 4 | 38 x 489 | Off in Lumen. A column of 12, left of bar 3 |
| `actionbars.bar5` | ActionBars | Action bar 5 | 38 x 489 | Off in Lumen. A column of 12 at the top of the left side, 16 units right of the left rail |
| `actionbars.bar6` | ActionBars | Action bar 6 | 38 x 489 | Off in Lumen. A column of 12, right of bar 5 |
| `actionbars.pet` | ActionBars | Pet bar | 162 x 63 | Two rows of five 30-unit sockets, 12 units left of bar 1's left end, bottom-aligned with it |
| `actionbars.stance` | ActionBars | Stance bar | 162 x 63 | Two rows of five 30-unit sockets, 12 units right of bar 1's right end, bottom-aligned with it |
| `cooldowns.essential` | Cooldowns | Essential cooldowns | 294 x 44 | 6 icons of 44 units with 6-unit gaps (one notch up from the 38-unit action button), centred over the vitals line |
| `cooldowns.utility` | Cooldowns | Utility cooldowns | 170 x 38 | 4 icons of 38 units (the action button's size) with 6-unit gaps, 16 units right of the essential row, bottom-aligned |
| `cooldowns.buffs` | Cooldowns | Tracked buff icons | 195 x 30 | 6 icons of 30 units, 16 units left of the essential row, bottom-aligned |
| `cooldowns.bars` | Cooldowns | Tracked buff bars | 195 x 43 | Two 195 by 20 bars, 8 units over the tracked buff icons |
| `auras.buffs` | Auras | Buffs | 318 x 177 | S4's Blessings card on the right rail, 16 units under the lens card: a cap, one row of six buffs with timers (the layouts write one row), a hairline and the debuff row docked under it. Two buff rows make it 318 x 240 |
| `auras.debuffs` | Auras | Debuffs | 318 x 63 | Docked in the Blessings card and not live there. Placed at the card's foot, where it stays when the player undocks it |
| `minimap.main` | Minimap | Minimap | 318 x 326 | S4's lens card at the head of the right rail, on the 28-unit margin: a round lens in a card with the gilt N, the zone and the clock in its foot |
| `chat.main` | Chat | Chat | 318 x 300 | The chat card at the left rail's foot, on the 28-unit margin, short enough to leave the story slot its room |
| `databars.xp` | DataBars | Experience bar | 489 x 4 | The XP line under bar 1, as wide, 52 units up so its caption sits under it on the 34-unit bottom margin |
| `databars.rep` | DataBars | Reputation bar | 162 x 5 | Under the pet sockets, on the XP line's baseline |
| `databars.honor` | DataBars | Honour bar | 162 x 5 | Under the stance sockets, on the XP line's baseline: Forever's PvP rank, or honour |
| `databars.strip` | DataBars | Data strip | 318 x 118 | S4's readout card at the right rail's foot: the readout line, with the micro menu docked under it and the bag bar wrapped under that, which 318 units need, and 3 units for pixel snapping (a card a hair short drops the rows under it) |
| `databars.micro` | DataBars | Micro menu | 318 x 44 | Docked in the readout card and not live there. Placed at the card's foot |
| `databars.bags` | DataBars | Bag bar | 212 x 32 | Docked in the readout card and not live there. Placed in the card, over the micro menu's place |
| `meters.damage` | Meters | Damage meter | 318 x 190 | S4's damage card on the right rail, 16 units under the boss card's room: six rows. Tank: 318 x 98, two rows, which Apply writes |
| `meters.threat` | Meters | Threat meter | 318 x 144 | Shown in Tank only, under the damage card, at 318 x 98 (two rows), which Apply writes. Off elsewhere, on the damage card's place |
| `meters.swing` | Meters | Swing timer | 260 x 8 | A slim bar over the player cast bar |
| `combattext.player` | CombatText | Your combat text | 160 x 180 | The field your incoming damage and heals rise through, right of the clear centre |
| `tooltips.anchor` | Tooltips | Tooltip anchor | 180 x 24 | The corner fixed tooltips grow from, beside the right rail, over the bag bar |

The story slot is not an element. Each layout has one (`Setup.Layouts.Slot(name)`): the left rail's column between the party card and chat, where the player drags RestedXP's guide and moves Blizzard's quest tracker in Edit Mode. KstyleUI never moves those frames. The setup's previews and Layout Mode draw its outline.

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

| Layout | What it changes from the v3 mockups |
| --- | --- |
| DPS | Nothing: the compact HUD band low in the centre (player frame, Cooldown Manager and target frame side by side, the cast bar above, two action bar rows below), the square minimap top right with the buffs beside it, chat bottom left, the data strip bottom right, party frames left and meters right |
| Tank | The threat meter moves in above the target frame |
| Healer | Party and raid frames move above the HUD band, at the centre |

Party and raid frames never show together, so they may share space. On 4:3 and 5:4 screens the chat panel and the player frame overlap; the player moves one of them in Layout Mode.

## Functions

| Function | Behaviour |
| --- | --- |
| `Setup.Layouts.Default(key) -> position` | The DPS position as a fresh table. Raises an error for an unknown key. |
| `Setup.Layouts.Get(name) -> { [key] = position }` or `nil` | A copy of a layout: `"DPS"`, `"Tank"` or `"Healer"`. |
| `Setup.Layouts.Names()`, `Label(name)`, `Note(name)` | The layout names in order, and each one's label and one-line note for the setup |
| `Setup.Layouts.Element(key) -> element` or `nil` | `{ key, module, label, width, height }` from `Setup.Layouts.ELEMENTS` |
| `Setup.Layouts.Rect(element, position, rootWidth, rootHeight) -> left, bottom, right, top` | Where an element's footprint lands on a root of that size, in root units from the bottom left. The setup's preview and the tests use it. |
