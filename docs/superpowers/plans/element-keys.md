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
| `unitframes.target` | UnitFrames | Target frame | 490 x 84 (the layouts keep 490 x 130) | The Lumen target sigil at the heart of the combat cluster, centred right on the hands block and as wide as the vitals line: name, level line, a gem-ended health pill and the cast line, with your debuffs as sockets hanging under it, inside the 130 the layouts keep |
| `unitframes.targettarget` | UnitFrames | Target of target | 120 x 22 | A pill row 12 units right of the sigil, top-aligned with it. Tank: the threat card stands under it |
| `unitframes.focus` | UnitFrames | Focus frame | 200 x 90 (the layouts keep 200 x 112) | The focus card 12 units left of the sigil, top-aligned with it, its debuffs in a row over the card, inside the 112 the layouts keep |
| `unitframes.focustarget` | UnitFrames | Focus target | 120 x 22 | A pill row 4 units under the focus card, left-aligned |
| `unitframes.pet` | UnitFrames | Pet frame | 120 x 22 | A pill row beside the vitals line's ring, 12 units left of it, top-aligned |
| `unitframes.boss` | UnitFrames | Boss frames | 258 x 334 (the layouts keep 318 x 334) | The boss column: five compact 258 by 62 boss cards 6 apart (name and percentage, pill, cast line; no cap), their debuffs hanging in three 18-unit columns to the left, inside the 318 the layouts keep. The boss you target collapses to a slim Targeted chip, as the sigil carries its full read. DPS and Tank: at the top of the centre's right edge, 16 units left of the right rail. Healer: on the right rail under the Blessings |
| `unitframes.castbar.player` | UnitFrames | Player cast bar | 272 x 30 | Off under the Lumen style, whose cast line is inside the vitals line. For the classic plate: 8 units over bar 2's place over the cluster. Healer: under bar 2 at the top centre |
| `unitframes.castbar.target` | UnitFrames | Target cast bar | 220 x 24 | Off under the Lumen style, whose cast line is on the sigil. For the classic plate: 8 units over the player cast bar's place. Healer: under it at the top centre |
| `unitframes.resource` | UnitFrames | Class resource | 120 x 14 | Combo points and the druid's mana, centred between the vitals line and the essential cooldowns |
| `groupframes.party` | GroupFrames | Party frames | 318 x 324 | S4's party card at the head of the left rail: a Party cap, five 40-unit rows with 8-unit gaps (role ring, name, class line, class pill). Healer: 318 x 354, five 46-unit rows, on the combat cluster's left half, its right edge 116 units left of the centre line, 16 units over the cluster |
| `groupframes.raid` | GroupFrames | Raid frames | 318 x 427 | Four groups a row, two rows, five 77 by 40 frames each, 3-unit gaps, on the left rail's column. Healer: 318 x 487, 46-unit frames, in the party card's place over the cluster |
| `actionbars.bar1` | ActionBars | Action bar 1 | 489 x 38 | 12 buttons of 38 units with 3-unit gaps in one row, 12 units over the XP line |
| `actionbars.bar2` | ActionBars | Action bar 2 | 489 x 38 | Off in Lumen. For a player who turns it on: 8 units over the combat cluster, centred. Healer: at the top centre, as the group frames stand on the cluster |
| `actionbars.bar3` | ActionBars | Action bar 3 | 38 x 489 | Off in Lumen. A column of 12 at the top of the left side, right of bar 6 (the boss column holds the right side). Healer: 16 units left of the right rail |
| `actionbars.bar4` | ActionBars | Action bar 4 | 38 x 489 | Off in Lumen. A column of 12, right of bar 3. Healer: left of bar 3 |
| `actionbars.bar5` | ActionBars | Action bar 5 | 38 x 489 | Off in Lumen. A column of 12 at the top of the left side, 16 units right of the left rail. Healer: left of bar 4, as the party and raid take the left side |
| `actionbars.bar6` | ActionBars | Action bar 6 | 38 x 489 | Off in Lumen. A column of 12, right of bar 5. Healer: left of bar 5 |
| `actionbars.pet` | ActionBars | Pet bar | 162 x 63 | Two rows of five 30-unit sockets, 12 units left of bar 1's left end, bottom-aligned with it |
| `actionbars.stance` | ActionBars | Stance bar | 162 x 63 | Two rows of five 30-unit sockets, 12 units right of bar 1's right end, bottom-aligned with it |
| `cooldowns.essential` | Cooldowns | Essential cooldowns | 294 x 44 | 6 icons of 44 units with 6-unit gaps (one notch up from the 38-unit action button), centred over the vitals line |
| `cooldowns.utility` | Cooldowns | Utility cooldowns | 170 x 38 | 4 icons of 38 units (the action button's size) with 6-unit gaps, 16 units right of the essential row, bottom-aligned |
| `cooldowns.buffs` | Cooldowns | Tracked buff icons | 195 x 30 | 6 icons of 30 units, 16 units left of the essential row, bottom-aligned |
| `cooldowns.bars` | Cooldowns | Tracked buff bars | 195 x 43 | Two 195 by 20 bars, 8 units over the tracked buff icons |
| `auras.buffs` | Auras | Buffs | 318 x 177 | S4's Blessings card on the right rail, 16 units under the lens card: a cap, one row of six buffs with timers (the layouts write one row), a hairline and the debuff row docked under it. Two buff rows make it 318 x 240 |
| `auras.debuffs` | Auras | Debuffs | 318 x 63 | Docked in the Blessings card and not live there. Placed at the card's foot, where it stays when the player undocks it |
| `minimap.main` | Minimap | Minimap | 318 x 326 | S4's lens card at the head of the right rail, on the 28-unit margin: a round lens in a card with the gilt N, the zone and the clock in its foot |
| `chat.main` | Chat | Chat | 318 x 260 | The chat card at the left rail's foot, on the 28-unit margin, short enough to leave the story slot room for the guide and three quests |
| `databars.xp` | DataBars | Experience bar | 489 x 4 | The XP line under bar 1, as wide, 52 units up so its caption sits under it on the 34-unit bottom margin |
| `databars.rep` | DataBars | Reputation bar | 162 x 5 | Under the pet sockets, on the XP line's baseline |
| `databars.honor` | DataBars | Honour bar | 162 x 5 | Under the stance sockets, on the XP line's baseline: Forever's PvP rank, or honour |
| `databars.strip` | DataBars | Data strip | 318 x 118 | S4's readout card at the right rail's foot: the readout line, with the micro menu docked under it and the bag bar wrapped under that, which 318 units need, and 3 units for pixel snapping (a card a hair short drops the rows under it) |
| `databars.micro` | DataBars | Micro menu | 318 x 44 | Docked in the readout card and not live there. Placed at the card's foot |
| `databars.bags` | DataBars | Bag bar | 212 x 32 | Docked in the readout card and not live there. Placed in the card, over the micro menu's place |
| `meters.damage` | Meters | Damage meter | 318 x 190 | S4's damage card on the right rail, 16 units under the Blessings: six rows. Healer: at the head of the left rail |
| `meters.threat` | Meters | Threat meter | 318 x 144 | Shown in Tank only: 200 x 112, which Apply writes, in the combat cluster under the target of target. Off elsewhere, on the damage card's place |
| `meters.swing` | Meters | Swing timer | 260 x 8 | A slim bar 6 units over the essential cooldowns, part of the hands |
| `combattext.player` | CombatText | Your combat text | 160 x 180 | The field your incoming damage and heals rise through, right of the clear centre, 16 units over the combat cluster and under the boss column. Healer: just right of the character's column |
| `tooltips.anchor` | Tooltips | Tooltip anchor | 180 x 24 | The corner fixed tooltips grow from: 8 units over the readout card's right corner, on no card, so a tooltip grows up the right rail and never covers the readout or the menu you hover |

The story slot is not an element. Each layout has one (`Setup.Layouts.Slot(name)`): the left rail's column between the party card (Healer: the damage card) and chat, where the player drags RestedXP's guide and moves Blizzard's quest tracker in Edit Mode. KstyleUI never moves those frames. The setup's previews and Layout Mode draw its outline.

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
| DPS | The Lumen Rails: party and chat on the left rail, the lens, the Blessings, the damage card and the readout on the right; one combat cluster on the hands (the target sigil, the focus on its left, the target of target on its right); the boss column at the top of the centre's right edge |
| Tank | The threat card joins the combat cluster under the target of target |
| Healer | Party and raid frames stand on the cluster's left half; the damage card heads the left rail; the boss column moves to the right rail |

Party and raid frames never show together, so they may share space. On 4:3 and 5:4 screens the chat panel and the player frame overlap; the player moves one of them in Layout Mode.

## Functions

| Function | Behaviour |
| --- | --- |
| `Setup.Layouts.Default(key) -> position` | The DPS position as a fresh table. Raises an error for an unknown key. |
| `Setup.Layouts.Get(name) -> { [key] = position }` or `nil` | A copy of a layout: `"DPS"`, `"Tank"` or `"Healer"`. |
| `Setup.Layouts.Names()`, `Label(name)`, `Note(name)` | The layout names in order, and each one's label and one-line note for the setup |
| `Setup.Layouts.Element(key) -> element` or `nil` | `{ key, module, label, width, height }` from `Setup.Layouts.ELEMENTS` |
| `Setup.Layouts.Rect(element, position, rootWidth, rootHeight) -> left, bottom, right, top` | Where an element's footprint lands on a root of that size, in root units from the bottom left. The setup's preview and the tests use it. |
