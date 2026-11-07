# Layout element keys

Every element a module shows registers with Layout under one key from this page:

```lua
KstyleUI.Layout.Register(frame, "unitframes.player", KstyleUI.Setup.Layouts.Default("unitframes.player"), opts)
```

The first-run setup writes the DPS, Tank or Healer position of each key into the profile's layout, so a module that registers under another key is never placed by the setup. Use the keys exactly as written. `test-setup-layouts.lua` fails when this page, `Core/Setup/Layouts.lua` and the plan's key list disagree.

## Rules

- A key is `<module>.<element>` in lower case, where `<module>` is the module's folder name without `KstyleUI_`. Sub-elements add a part: `unitframes.castbar.player`.
- Pass `KstyleUI.Setup.Layouts.Element(key).label` as `opts.label`, so the mover plate and the settings window use the same name as the setup.
- Pass `KstyleUI.Setup.Layouts.Default(key)` as the default position. It returns a fresh `{ anchor, x, y }`: the DPS layout's position, so a profile that never ran the setup still gets the v3 layout. It raises an error for a key this page does not list, so a typo fails the module's test.
- Build the element at its footprint, or smaller, at the 1080 reference. The layouts are planned so that no two elements overlap at 1920x1080, 2560x1440, 3840x2160 and 3456x2234 when each element fits its footprint. An element that needs more room changes its footprint here and in `Core/Setup/Layouts.lua` in the same pull request, and `test-setup-layouts.lua` must still pass.
- The position anchors the element's own point to the same point of `KstyleUI_Root`: `BOTTOM` with `x = -279, y = 113` puts the element's bottom centre 279 units left of the screen's bottom centre and 113 units up. Offsets are root units: the root is 1080 units tall, 1920 units wide at 16:9 and about 1671 units wide on a 3456x2234 Mac.
- Nameplates sit on Blizzard's plates and have no position key. Their size comes from a Layout Mode sample listed under [Elements outside the layouts](#elements-outside-the-layouts). Combat text numbers on unit, group and nameplate frames ride those frames and have no key either; only the player's own field, `combattext.player`, has one. A module element not listed here, such as a settings window, picks a key in the same form and adds a row in the same pull request. Core windows are listed under [Core windows](#core-windows), outside the layouts.

## Keys

Footprints are width x height in units at the 1080 reference.

| Key | Module | Element | Footprint | Shape the layouts plan for |
| --- | --- | --- | --- | --- |
| `unitframes.player` | UnitFrames | Player frame | 296 x 89 | The kit sheet's 469 by 141 proportions: an 89-unit portrait over one glass panel |
| `unitframes.target` | UnitFrames | Target frame | 296 x 89 | Mirror of the player frame |
| `unitframes.targettarget` | UnitFrames | Target of target | 120 x 24 | Under the target frame, right-aligned |
| `unitframes.focus` | UnitFrames | Focus frame | 240 x 96 | A 240 by 72 frame with its 20-unit cast bar under it |
| `unitframes.focustarget` | UnitFrames | Focus target | 120 x 24 | Under the focus frame, right-aligned |
| `unitframes.pet` | UnitFrames | Pet frame | 120 x 24 | Under the player frame, left-aligned, mirroring the target of target |
| `unitframes.boss` | UnitFrames | Boss frames | 200 x 400 | Boss 1 to 5 stacked downward, 72 units each with 10-unit gaps: a 200 by 60 frame and a 10-unit cast bar |
| `unitframes.castbar.player` | UnitFrames | Player cast bar | 260 x 20 | Above the essential cooldowns |
| `unitframes.castbar.target` | UnitFrames | Target cast bar | 194 x 18 | Under the target frame, right-aligned, beside action bar 1 |
| `unitframes.resource` | UnitFrames | Class resource | 120 x 14 | Combo points and the druid's mana, under the player frame, beside action bar 1 |
| `groupframes.party` | GroupFrames | Party frames | 230 x 270 | Five 46-unit frames stacked downward with 10-unit gaps |
| `groupframes.raid` | GroupFrames | Raid frames | 597 x 212 | Eight groups side by side, five 72 by 40 frames each, 3-unit gaps |
| `actionbars.bar1` | ActionBars | Action bar 1 | 441 x 34 | 12 buttons of 34 units with 3-unit gaps in one row |
| `actionbars.bar2` | ActionBars | Action bar 2 | 441 x 34 | The second row, under bar 1 |
| `actionbars.bar3` | ActionBars | Action bar 3 | 34 x 441 | A column of 12 at the right edge |
| `actionbars.bar4` | ActionBars | Action bar 4 | 34 x 441 | A column of 12, left of bar 3 |
| `actionbars.bar5` | ActionBars | Action bar 5 | 34 x 441 | A column of 12 at the left edge |
| `actionbars.bar6` | ActionBars | Action bar 6 | 34 x 441 | A column of 12, right of bar 5 |
| `actionbars.pet` | ActionBars | Pet bar | 327 x 30 | 10 buttons of 30 units in one row, above the chat |
| `actionbars.stance` | ActionBars | Stance bar | 327 x 30 | Up to 10 buttons of 30 units, above the pet bar |
| `cooldowns.essential` | Cooldowns | Essential cooldowns | 255 x 40 | 6 icons of 40 units per row |
| `cooldowns.utility` | Cooldowns | Utility cooldowns | 195 x 30 | 6 icons of 30 units per row, under the essential row |
| `cooldowns.buffs` | Cooldowns | Tracked buff icons | 195 x 30 | 6 icons of 30 units, above the target frame |
| `cooldowns.bars` | Cooldowns | Tracked buff bars | 180 x 60 | Three 180 by 18 bars, above the player frame |
| `auras.buffs` | Auras | Buffs | 420 x 76 | Two rows of icons under the minimap, growing left |
| `auras.debuffs` | Auras | Debuffs | 420 x 38 | One row under the buffs |
| `minimap.main` | Minimap | Minimap | 226 x 196 | A 196-unit square with the button column on its left |
| `chat.main` | Chat | Chat | 390 x 190 | The panel with its tabs and edit box |
| `databars.xp` | DataBars | Experience bar | 441 x 5 | Under the action bars, as wide as them |
| `databars.rep` | DataBars | Reputation bar | 441 x 5 | Under the experience bar |
| `databars.honor` | DataBars | Honour bar | 441 x 5 | Under the reputation bar: Forever's PvP rank, or honour |
| `databars.strip` | DataBars | Data strip | 430 x 36 | FPS, latency, gold, durability and time |
| `databars.micro` | DataBars | Micro menu | 270 x 28 | One row above the data strip |
| `databars.bags` | DataBars | Bag bar | 180 x 30 | One row above the micro menu |
| `meters.damage` | Meters | Damage meter | 260 x 174 | Right side, inside the right-hand bar columns |
| `meters.threat` | Meters | Threat meter | 260 x 130 | Above the damage meter |
| `meters.swing` | Meters | Swing timer | 260 x 8 | A slim bar above the cast bar |
| `combattext.player` | CombatText | Your combat text | 160 x 180 | The field your incoming damage and heals rise through, above your character |
| `tooltips.anchor` | Tooltips | Tooltip anchor | 180 x 24 | The corner fixed tooltips grow from, above the threat meter |

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
| DPS | Nothing: the compact HUD band low in the centre (player frame, Cooldown Manager and target frame side by side, the cast bar above, two action bar rows below), the square minimap top right with buffs under it, chat bottom left, the data strip bottom right, party frames left and meters right |
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
