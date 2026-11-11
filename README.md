<h1 align="center">KstyleUI</h1>

<p align="center"><b>The whole World of Warcraft: Forever interface, in one forged style.</b></p>

<p align="center">KstyleUI replaces every part of the Forever screen with one look: dark forged cards, gilt trim and painted ornaments.<br>It reads the fight for you, stays inside the rules Forever sets for addons, and sets itself up on your first login.</p>

<p align="center"><a href="https://github.com/korallis/KstyleUI/releases">Releases</a>&nbsp;&nbsp;&nbsp;<a href="https://gist.githack.com/korallis/4061c2bddaede3a2d45fb91c39c3cbe9/raw/index.html">Product page</a>&nbsp;&nbsp;&nbsp;<a href="https://gist.githack.com/korallis/4061c2bddaede3a2d45fb91c39c3cbe9/raw/gallery.html">Every frame and feature</a>&nbsp;&nbsp;&nbsp;<a href="#get-started">Get started</a></p>

<p align="center"><img src="docs/media/readme/hud_dps.png" width="100%" alt="The KstyleUI DPS layout: party and chat on the left, the minimap, aura rows, quests and damage meter on the right, target, player, cast bar, cooldowns and action bars at the bottom centre"></p>

<p align="center"><sub>Test render of the DPS layout on a 3456 by 2234 screen, ornaments on Full. Every picture on this page is a test render drawn from the addon's own code, not a game screenshot.</sub></p>

## Why KstyleUI

### One forged material for the whole screen, Blizzard's windows included

<p align="center"><img src="docs/media/readme/merit_skins.png" width="560" alt="The character sheet on a forged card"></p>

<p align="center"><sub>Test render of the character sheet, skinned.</sub></p>

Every panel, card and window is dark forged iron with a textured frame and corner brackets, and your class colour on every accent. Open **Options, General, Card material** to pick another surface: Forged iron with brackets (the default), Forged iron with gilt ticks, Slate, Flat or the original smoked Glass. The change repaints the open screen at once, with no reload, and **Panel opacity** sits beside it.

<p align="center"><img src="docs/media/readme/card_materials.png" width="800" alt="One chat card drawn at each of the five card materials"></p>

<p align="center"><sub>Test render of one card at each material. Top row: Forged iron with brackets, Forged iron with gilt ticks, Slate. Bottom row: Flat, Glass.</sub></p>

<p align="center"><img src="docs/media/readme/settings_ornaments.png" width="520" alt="The settings window's General page at the Ornaments row and the Card material dropdown"></p>

<p align="center"><sub>Test render of the settings window's General page at the Ornaments and Card material rows.</sub></p>

Turn on the Skins module and the game's own windows take the same surface, one switch per window: character sheet, spellbook, talents, world map and quest log, mail, merchant, professions, loot, group finder, friends, guild, popups and the Escape menu.

### Painted ornaments, at three levels

<p align="center"><img src="docs/media/readme/ornaments_strip.png" width="800" alt="The centre of the HUD at ornament level Off, Subtle and Full, left to right"></p>

<p align="center"><sub>Test render of the same part of the HUD at Off, Subtle and Full, left to right.</sub></p>

Ornaments are painted trim on the unit frames, their cast bars and the action bars: end pieces, rails, rivets, the portrait band and the rank pendants. **Off** draws nothing, so the screen is exactly the plain layout. **Subtle** draws thin gilt rails and plain pointed ends. **Full**, the default, draws forged rails, clawed ends and the action-bar tray. Ornaments never move anything. The setup's ornaments step and **Options, General, Ornaments** choose the level, and the Glass material draws none. [`docs/ORNAMENT-SPEC.md`](docs/ORNAMENT-SPEC.md) lists the pieces and where each shows.

<p align="center"><img src="docs/media/readme/setup_ornaments.png" width="520" alt="The setup's ornaments step with Off, Subtle and Full as three cards, Full picked"></p>

<p align="center"><sub>Test render of the setup's ornaments step, with Full picked.</sub></p>

### Folio or Lumen type, and a font for every role

<p align="center"><img src="docs/media/readme/settings_type.png" width="520" alt="The settings window's General page with the Type set set to Folio"></p>

<p align="center"><sub>Test render of the settings window's General page.</sub></p>

Folio is the default type set: IM Fell and EB Garamond for titles and captions, Cinzel for names, and PT Serif for reading and figures. The Lumen set of Cinzel and Alegreya Sans is one dropdown away. Under **Fonts by role** each of 13 roles (display, heading, title, capitals, names, unit name, body, prose, caption, number, time, timer and world text) takes its own font, from KstyleUI's bundled faces or from LibSharedMedia. A font you pick stays when you change the type set.

### Three layouts: DPS, Tank and Healer

<p align="center"><img src="docs/media/readme/hud_tank.png" width="100%" alt="The KstyleUI Tank layout: the DPS layout with a threat card under the target"></p>

<p align="center"><sub>Test render of the Tank layout: the DPS layout with the threat meter in the combat cluster.</sub></p>

<p align="center"><img src="docs/media/readme/hud_healer.png" width="100%" alt="The KstyleUI Healer layout: larger party frames beside the combat cluster"></p>

<p align="center"><sub>Test render of the Healer layout: larger party and raid frames beside the combat cluster, dispellable debuffs first.</sub></p>

The first-run setup puts every element in the place its layout draws. The three layouts share the left and right rails and the centre column, and differ where the role needs them to: Tank adds the threat card, Healer gives the group frames more room and heads the left rail with the boss cards.

### A combat cluster you read without looking down

<p align="center"><img src="docs/media/readme/merit_combat.png" width="720" alt="The combat cluster in a pull: a cast bar, the target's frame with its portrait band, your frame and your bars"></p>

<p align="center"><sub>Test render of the combat cluster in a pull.</sub></p>

Your target stands over your own frame in the same column: the name, a health bar, a thin cast line and the portrait on the far side with its level. A cast you cannot interrupt reads <b>Locked</b> in red, even when the game keeps that fact secret.

When a frame's aura row is full, the last socket reads <b>+N</b>. The game's secure aura engine does the counting, so the number stays true in combat. Boss cards stand in a column. The boss you target folds to a slim Targeted chip because the target frame already shows its health and cast.

### Party and raid frames at a healer's standard

<p align="center"><img src="docs/media/readme/merit_raid.png" alt="Twenty raid tiles with missing health, debuffs, a dead and an offline member"></p>

<p align="center"><sub>Test render of twenty raid tiles: missing health, debuffs, a dead and an offline member.</sub></p>

Up to 40 members on the game's own group headers, so clicks land on the right person mid-fight. Dispellable debuffs lead the row, a member with a boss debuff glows red, a dispel tints the tile by its type, a thin line shows the whole shield even at full health, and your own heals over time sit in their own lane.

Six indicator slots each show a category of auras in the nearest free spot. The frames work with the game's Click Casting, and the settings page shows your bindings live.

### Set up in one window on your first login

<p align="center"><img src="docs/media/readme/merit_setup.png" width="720" alt="The setup's layout step: DPS, Tank and Healer cards over one preview of the layout you point at"></p>

<p align="center"><sub>Test render of the layout step: three layouts over one preview of the one you point at.</sub></p>

A five-step window opens on your first login: pick the DPS, Tank or Healer layout from a real-size preview, choose your modules, choose the ornament level, apply. KstyleUI then writes a layout into Blizzard's Edit Mode so the quest tracker, the damage meter and your tracked buffs take their places too.

Closing it early still gives you the DPS layout with Full ornaments. <b>Keep my UI</b> leaves the game's interface exactly as it was. Run it again any time with <code>/kstyle setup</code>.

### Built for Forever from the start

<p align="center"><img src="docs/media/readme/merit_plates.png" width="720" alt="A seven-mob pull: stacked nameplates, your debuffs on each, two casts, one of them your target's"></p>

<p align="center"><sub>Test render of a seven-mob pull: stacked plates, your debuffs on each, two casts, one of them your target's.</sub></p>

Health, power, casts and auras go straight to the game's widgets. Every comparison is guarded by <code>issecretvalue</code>, and a secret takes a safe default. Protected work waits for combat to end. Blizzard's frames are hidden by reparenting, never scripted, and come back when a module stops.

Nameplates show your debuffs through the engine with an honest +N chip, and colour a cast you could interrupt right now. In the gamepad interface KstyleUI steps aside for Blizzard's bars, frames and bags.

### The rest of the screen, in the same hand

<p align="center"><img src="docs/media/readme/merit_rail.png" width="520" alt="The right rail while questing: the aura rows, the minimap, the quest card and the first side bars"></p>

<p align="center"><sub>Test render of the right rail while questing: the aura rows, the minimap and the quest card.</sub></p>

The minimap is a square with a thin gilt rim and a round N plate on its top edge: the zone name, your coordinates and the clock sit under it, and the tracking, calendar and addon-drawer buttons stand down its right edge (the zoom slider shows while your pointer is over it). Your buffs and debuffs are plain icon rows beside it: a thin rim, the time left under each icon, stack counts on a corner badge, a +N on the last icon when the rows are full, and a right-click to cancel. A buff the Cooldown Manager already tracks shows there only. The damage meter is a small card that reads from the game's own meter data: a DAMAGE cap with your damage per second, then one bar per spell, coloured by its school, with the spell's damage and its share of the total at the right ("412 · 46%"). Alone, it lists your own spells; in a group, it lists the group and a spell breakdown opens under the row your pointer is on. The Now, Last, All switch shows only while your pointer is on the cap's right end.

Bags sort into sections with a search that understands <code>&amp;</code>, <code>|</code>, <code>!</code> and <code>ilvl&gt;30</code>. Chat sits on a forged card, tooltips become forged cards, and experience is a thin bar with its rested overlay.

### Every screen size

The layout and ornament tests draw the HUD on nine screens: 1280 by 720, 1366 by 768, 1920 by 1080, 2560 by 1440, 3440 by 1440, 5120 by 1440, 3840 by 2160, 2383 by 1540 and 3456 by 2234. Everything draws on one canvas 1080 units tall, so it takes the same share of the screen at each size, and every border is a whole number of physical pixels. Where an ornament piece does not fit, as on 1280 by 720, it is left out, never squeezed or thinned. A render is not the game, so the owner checks each release in game before it ships.

## What it changes

KstyleUI is one core addon and one addon per module. A module that is off costs nothing: no frames, no events and no hooks, and the first-run setup switches on the ones you pick.

<table>
<tr>
<td width="50%" valign="top"><img src="docs/media/readme/tile_unitframes.png" alt="Unit frames"><br><b>Unit frames</b><br><sub>Player and target as mirrored columns with a portrait band, focus and boss cards.</sub></td>
<td width="50%" valign="top"><img src="docs/media/readme/tile_groupframes.png" alt="Party and raid frames"><br><b>Party and raid</b><br><sub>Secure frames with role rings, dispel and boss debuffs, shields and your heals.</sub></td>
</tr>
<tr>
<td width="50%" valign="top"><img src="docs/media/readme/tile_actionbars.png" alt="Action bars"><br><b>Action bars</b><br><sub>Six secure bars as dark sockets. A socket's rim turns gold while a proc is up.</sub></td>
<td width="50%" valign="top"><img src="docs/media/readme/tile_cooldowns.png" alt="Cooldowns"><br><b>Cooldowns</b><br><sub>Blizzard's Cooldown Manager mirrored as KstyleUI icons and bars, each movable.</sub></td>
</tr>
<tr>
<td width="50%" valign="top"><img src="docs/media/readme/tile_auras.png" alt="Aura rows"><br><b>Aura rows</b><br><sub>Your buffs and debuffs as plain icon rows, drawn by the game's secure aura engine.</sub></td>
<td width="50%" valign="top"><img src="docs/media/readme/tile_nameplates.png" alt="Nameplates"><br><b>Nameplates</b><br><sub>Health, level, your debuffs and a cast bar that says when you can interrupt.</sub></td>
</tr>
<tr>
<td width="50%" valign="top"><img src="docs/media/readme/tile_minimap.png" alt="Minimap"><br><b>Minimap</b><br><sub>A square map in a gilt rim with an N plate, its zone, coordinates and clock under it and round buttons down its edge.</sub></td>
<td width="50%" valign="top"><img src="docs/media/readme/tile_chat.png" alt="Chat"><br><b>Chat</b><br><sub>Blizzard's chat on a forged card with gilt tabs and a copy window.</sub></td>
</tr>
<tr>
<td width="50%" valign="top"><img src="docs/media/readme/tile_bags.png" alt="Bags and bank"><br><b>Bags and bank</b><br><sub>One window, sections by item type, and a search grammar.</sub></td>
<td width="50%" valign="top"><img src="docs/media/readme/tile_meters.png" alt="Meters"><br><b>Meters</b><br><sub>Damage and threat from the game's own data, with fight segments and spell lists.</sub></td>
</tr>
<tr>
<td width="50%" valign="top"><img src="docs/media/readme/tile_skins.png" alt="Blizzard windows, skinned"><br><b>Blizzard windows</b><br><sub>The spellbook, talents, map, mail, merchant and more on the same forged surface.</sub></td>
<td width="50%" valign="top"><img src="docs/media/readme/tile_layout.png" alt="Layout Mode"><br><b>Layout Mode</b><br><sub>Mover plates, snapping, a grid, resize handles, undo and redo.</sub></td>
</tr>
</table>

<p align="center"><sub>Every picture in this grid is a test render.</sub></p>

Every element KstyleUI shows can be moved, resized or scaled in Layout Mode and from the settings window, and every module has its own fonts, textures, colours and sizes.

<details>
<summary>Every module, in one table</summary>

| Module | What it does |
| --- | --- |
| Core | The design system, the settings window (with its General page's type set and fonts by role, card material, ornaments, panel opacity, panel shadows, interface sounds and tooltip size), Layout Mode, profiles, the first-run setup and `/kstyle` |
| Unit Frames | Player, target, target of target, focus, focus target, pet and boss 1 to 5, with portraits, cast bars, frame auras, the class resource, threat glow and status icons |
| Group Frames | Party and raid frames up to 40, with class colours, roles, range fade, incoming heals, absorbs, debuffs and the dispel highlight |
| Action Bars | Secure action bars with stance, stealth, form and possess paging, pet and stance bars, keybind text, cooldowns, proc glows, range and usability shading, fade on mouseover, and a dialog that puts a newly learned spell rank on the bars |
| Cooldowns | Blizzard's Cooldown Manager in KstyleUI's style: essential and utility rows in the HUD band, tracked buff icons and bars |
| Auras | Your buffs and debuffs as plain icon rows beside the minimap |
| Nameplates | A KstyleUI plate on each nameplate, with health, cast bar, threat colour and your debuffs |
| Combat Text | Damage and heal numbers on KstyleUI's frames and plates, and KstyleUI's font for the game's own numbers |
| Minimap | A square map in a thin gilt rim with an N plate, the zone, coordinates and clock under it, and round buttons and an addon-button drawer down its edge |
| Chat | Forged chat cards, tabs with an accent underline, timestamps, short channel names, clickable links, class-coloured names, a copy window, and a plus glyph in the tab row that opens the chat settings |
| Bags | Combined bags and bank with the keyring, search, sorting, quality borders and junk selling |
| Tooltips | Forged tooltips with quality and class colours, a health bar, optional IDs and cursor anchoring |
| Data Bars | XP, reputation and honour bars, the micro menu, the bag bar and a data strip with frame rate, latency, gold, durability and time |
| Meters | A damage meter, a threat meter and a swing timer |
| QoL | Faster auto loot, auto repair, quest accept and turn-in, the farthest camera and quiet error text |
| Skins | Blizzard's windows in KstyleUI's style: the character sheet, spellbook, talents, world map, quest log, objective tracker, game menu, group finder, mail, merchant, trainers, professions, social windows, Legacy, loot, popups, ready check and the AddOns list, and the RestedXP Guides addon's windows |

No module compares or does arithmetic on Forever's secret values, every protected change made in combat waits for combat to end, and the action bars, group frames, bags, auras, and the data bars' micro menu and bag bar hand back to Blizzard's in the gamepad interface.

</details>

## Every class

The same HUD on all nine classes: each class's own colour on every accent, its power type, its spells, its cast, its buffs and its pet.

<table>
<tr>
<td width="33%"><img src="docs/media/readme/class_druid.png" alt="Druid HUD"><br><sub>Druid</sub></td>
<td width="33%"><img src="docs/media/readme/class_hunter.png" alt="Hunter HUD"><br><sub>Hunter</sub></td>
<td width="33%"><img src="docs/media/readme/class_mage.png" alt="Mage HUD"><br><sub>Mage</sub></td>
</tr>
<tr>
<td width="33%"><img src="docs/media/readme/class_paladin.png" alt="Paladin HUD"><br><sub>Paladin</sub></td>
<td width="33%"><img src="docs/media/readme/class_priest.png" alt="Priest HUD"><br><sub>Priest</sub></td>
<td width="33%"><img src="docs/media/readme/class_rogue.png" alt="Rogue HUD"><br><sub>Rogue</sub></td>
</tr>
<tr>
<td width="33%"><img src="docs/media/readme/class_shaman.png" alt="Shaman HUD"><br><sub>Shaman</sub></td>
<td width="33%"><img src="docs/media/readme/class_warlock.png" alt="Warlock HUD"><br><sub>Warlock</sub></td>
<td width="33%"><img src="docs/media/readme/class_warrior.png" alt="Warrior HUD"><br><sub>Warrior</sub></td>
</tr>
</table>

<p align="center"><sub>Every picture in this grid is a test render.</sub></p>

## Get started

KstyleUI targets the Forever client only (TOC `16001`, game type `camelot`). It has not been released yet: the first release follows the owner's in-game test of the `staging` branch. Until then, follow [Install the addons](docs/TESTING.md#install-the-addons) in the test guide to run the current `staging` build from a clone.

1. Download the latest zip from the [Releases page](https://github.com/korallis/KstyleUI/releases) and unzip it into `World of Warcraft/_forever_/Interface/AddOns`, so that `KstyleUI` and the `KstyleUI_*` module folders sit there. Start the game. If the addons are not ticked in the game's AddOns list, tick them.
2. Log in. The first-run setup opens: pick the DPS, Tank or Healer layout, the modules you want and the ornament level, then click **Apply** and **Reload**. Close it early and you still get the DPS layout with Full ornaments. **Keep my UI** changes nothing.
3. Type `/kstyle` for the settings window: a page per module, a search across every setting and a live preview of what you change.
4. Type `/kstyle layout` to place things your way. A mover plate covers every element: drag, snap, nudge with the arrow keys, undo. Positions save per profile.

<details>
<summary>Every command</summary>

| Command | What it does |
| --- | --- |
| `/kstyle` | Opens or closes the settings window. Esc > Options > AddOns > KstyleUI and the minimap's addon compartment open it too. |
| `/kstyle layout` | Enters or leaves Layout Mode. |
| `/kstyle setup` | Runs the first-run setup again. |
| `/kstyle bind` | Opens Blizzard's Quick Keybind mode: hover a button and press a key to bind it. |
| `/kstyle test` | Runs the smoke checks and writes the results to the devlog. Type `/reload` afterwards to save them. |
| `/kstyle devlog on`, `/kstyle devlog off` | Arms/stops the developer-only [Edit Mode geometry recorder](docs/EDIT_MODE_RECORDER.md) for this session; off after every reload. |
| `/kstyle profile` | Lists the profiles and marks the one this character uses. |
| `/kstyle profile use <name>` | Switches this character to a profile, creating it if needed. |
| `/kstyle profile new <name>` | Creates a profile with the default settings. |
| `/kstyle profile copy <name>` | Copies a profile into the active one. |
| `/kstyle profile rename <name>` | Renames the active profile. |
| `/kstyle profile delete <name>` | Deletes a profile. |
| `/kstyle profile reset` | Resets the active profile to the defaults. |

The settings window's Profiles page also exports a profile as one string and imports one back.

</details>

### The repainted icons are optional

KstyleUI's repainted icons are a separate download, `KstyleUI-Icons-<version>.zip` on the [release](https://github.com/korallis/KstyleUI/releases), not part of the addon. Quit the game, unzip it, and copy its `Interface` folder into `World of Warcraft/_forever_/` so the files land in `_forever_/Interface/Icons/`. Then start the game (a full restart, not `/reload`). The client loads the files itself, so every icon the pack covers changes everywhere, buff and debuff tiles included. To go back to Blizzard's icons, delete those files and restart. Encrypted store and event icons stay Blizzard's. [`docs/icons.md`](docs/icons.md) has the details, the install script and how the pack is made.

### Languages

KstyleUI ships English, German (`deDE`), French (`frFR`), Spanish (`esES`, also used on `esMX`) and Simplified Chinese (`zhCN`). The translations use WoW's own terms for each language, taken from Blizzard's localised interface strings for the Forever build. They are machine-made and have not yet been read by a native speaker, so report a wrong or awkward string as an issue. A string with no translation shows in English.

KstyleUI's bundled fonts have no Chinese or Korean glyphs. On `zhCN`, `zhTW` and `koKR` clients every KstyleUI text uses the game's own font for that language, and on `ruRU` the game's Cyrillic font replaces Cinzel and Folio's display face. A font you pick from another addon stays your choice.

## For developers

[`docs/DEVELOPING.md`](docs/DEVELOPING.md) has the repository layout, the checks to run, how to add a translation and where the design spec and the branch flow live.

## Licence

All rights reserved. See [`LICENSE.md`](LICENSE.md).
