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
| `unitframes.player` | UnitFrames | Player frame | 220 x 70 | The owner's mockup's proportions (279 by 90: a round portrait as tall as the frame over one glass panel) at the owner's in-game scale of 2026-11-08, under two 38-unit action buttons tall |
| `unitframes.target` | UnitFrames | Target frame | 220 x 70 | Mirror of the player frame |
| `unitframes.targettarget` | UnitFrames | Target of target | 88 x 22 | Beside the target frame's portrait end, 4 units right of it, bottom-aligned; the mockup shows no target of target |
| `unitframes.focus` | UnitFrames | Focus frame | 200 x 80 | A 200 by 60 frame with its 16-unit cast bar under it |
| `unitframes.focustarget` | UnitFrames | Focus target | 96 x 22 | Under the focus frame, right-aligned |
| `unitframes.pet` | UnitFrames | Pet frame | 88 x 22 | Beside the player frame's portrait end, 4 units left of it, bottom-aligned, mirroring the target of target; the mockup shows no pet |
| `unitframes.boss` | UnitFrames | Boss frames | 200 x 400 | Boss 1 to 5 stacked downward, 72 units each with 10-unit gaps: a 200 by 60 frame and a 10-unit cast bar |
| `unitframes.castbar.player` | UnitFrames | Player cast bar | 272 x 30 | Above the essential cooldowns and the frames, with the spell name and time over a thin bar |
| `unitframes.castbar.target` | UnitFrames | Target cast bar | 220 x 24 | Under the target frame and the tracked buff icons, the frame's width, clear of the experience bar's end |
| `unitframes.resource` | UnitFrames | Class resource | 120 x 14 | Combo points and the druid's mana, on top of the player frame, right-aligned |
| `groupframes.party` | GroupFrames | Party frames | 230 x 270 | Five 46-unit frames stacked downward with 10-unit gaps |
| `groupframes.raid` | GroupFrames | Raid frames | 597 x 212 | Eight groups side by side, five 72 by 40 frames each, 3-unit gaps |
| `actionbars.bar1` | ActionBars | Action bar 1 | 489 x 38 | 12 buttons of 38 units with 3-unit gaps in one row |
| `actionbars.bar2` | ActionBars | Action bar 2 | 489 x 38 | The second row, 10 units under bar 1 |
| `actionbars.bar3` | ActionBars | Action bar 3 | 38 x 489 | A column of 12 at the right edge, under the debuff row |
| `actionbars.bar4` | ActionBars | Action bar 4 | 38 x 489 | A column of 12, left of bar 3 |
| `actionbars.bar5` | ActionBars | Action bar 5 | 38 x 489 | A column of 12 at the left edge |
| `actionbars.bar6` | ActionBars | Action bar 6 | 38 x 489 | A column of 12, right of bar 5 |
| `actionbars.pet` | ActionBars | Pet bar | 327 x 30 | 10 buttons of 30 units in one row, above the player frame |
| `actionbars.stance` | ActionBars | Stance bar | 327 x 30 | Up to 10 buttons of 30 units, above the pet bar |
| `cooldowns.essential` | Cooldowns | Essential cooldowns | 294 x 44 | 6 icons of 44 units with 6-unit gaps (one notch up from the 38-unit action button), between the player and target frames |
| `cooldowns.utility` | Cooldowns | Utility cooldowns | 170 x 38 | 4 icons of 38 units (the action button's size) with 6-unit gaps, under the essential row and the frames |
| `cooldowns.buffs` | Cooldowns | Tracked buff icons | 195 x 30 | 6 icons of 30 units, under the target frame |
| `cooldowns.bars` | Cooldowns | Tracked buff bars | 195 x 43 | Two 195 by 20 bars, 5 units under the player frame, right-aligned with it: the mockup's bars start 225 units above the screen's bottom, ours 235, so they clear the 424-unit chat panel on the owner's 1671-unit-wide root |
| `auras.buffs` | Auras | Buffs | 360 x 102 | Two rows of eight 38-unit icons with their timers, beside the minimap (12 units left of its element, top-aligned with it), growing left from the minimap so the shortest time left sits next to it; Forever's Edit Mode preset pins the objective tracker 38 units under the minimap, so nothing fits beneath it |
| `auras.debuffs` | Auras | Debuffs | 360 x 51 | One row of eight, 8 units under the buffs, flush with them |
| `minimap.main` | Minimap | Minimap | 259 x 221 | The mockup's 221 chamfered frame: a 217 map square 2 units inside its bevel line, clipped to the frame's cut corners, with the 30-unit footer over its bottom, and the 34-unit button column 4 units left of it |
| `chat.main` | Chat | Chat | 424 x 164 | The panel with its tabs and edit box |
| `databars.xp` | DataBars | Experience bar | 352 x 4 | Between the utility row and action bar 1, with its XP caption on the line; the mockup's 440 line scaled with the frames so it ends inside the target cast bar |
| `databars.rep` | DataBars | Reputation bar | 440 x 5 | Under action bar 2 |
| `databars.honor` | DataBars | Honour bar | 440 x 5 | Under the reputation bar: Forever's PvP rank, or honour |
| `databars.strip` | DataBars | Data strip | 492 x 43 | FPS, latency, gold, durability and time |
| `databars.micro` | DataBars | Micro menu | 314 x 32 | One row above the data strip |
| `databars.bags` | DataBars | Bag bar | 212 x 32 | One row above the micro menu |
| `meters.damage` | Meters | Damage meter | 208 x 130 | Right side, inside the right-hand bar columns, above the tooltip anchor |
| `meters.threat` | Meters | Threat meter | 208 x 104 | Above the damage meter |
| `meters.swing` | Meters | Swing timer | 260 x 8 | A slim bar above the player cast bar |
| `combattext.player` | CombatText | Your combat text | 160 x 180 | The field your incoming damage and heals rise through, above your character |
| `tooltips.anchor` | Tooltips | Tooltip anchor | 180 x 24 | The corner fixed tooltips grow from, just above the frames' line and under the damage meter |

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
