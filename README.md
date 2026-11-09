<h1 align="center">KstyleUI</h1>

<p align="center"><b>The whole World of Warcraft: Forever interface, in one piece of glass.</b></p>

<p align="center">KstyleUI replaces every part of the Forever screen with one theme, Lumen: frosted blue glass, a lit rim and gilt details.<br>It reads the fight for you, stays inside the rules Forever sets for addons, and sets itself up on your first login.</p>

<p align="center"><a href="https://github.com/korallis/KstyleUI/releases">Releases</a>&nbsp;&nbsp;&nbsp;<a href="https://gist.githack.com/korallis/4061c2bddaede3a2d45fb91c39c3cbe9/raw/index.html">Product page</a>&nbsp;&nbsp;&nbsp;<a href="https://gist.githack.com/korallis/4061c2bddaede3a2d45fb91c39c3cbe9/raw/gallery.html">Every frame and feature</a>&nbsp;&nbsp;&nbsp;<a href="#get-started">Get started</a></p>

<p align="center"><img src="docs/media/readme/hero.jpg" width="100%" alt="The KstyleUI DPS layout while questing: party frames, quests and chat on the left, the minimap, Blessings card and damage meter on the right, vitals, bars and cooldowns at the bottom centre"></p>

<p align="center"><sub>The DPS layout while questing. Every image on this page is rendered from the addon's own code. The code holds 464 features, 355 of them functional.</sub></p>

## Why KstyleUI

### One material for the whole screen, Blizzard's windows included

<p align="center"><img src="docs/media/readme/merit_skins.jpg" width="800" alt="The character sheet on Lumen glass"></p>

<p align="center"><sub>The character sheet, skinned.</sub></p>

Every panel, card and window is frosted Lumen glass: a deep blue tint, a lit rim, gilt filament tips and 14-unit corners. Cinzel for titles, Alegreya Sans for everything else, and your class colour on every accent.

Turn on the Skins module and the game's own windows take the same glass, one switch per window: character sheet, spellbook, talents, world map and quest log, mail, merchant, professions, loot, group finder, friends, guild, popups and the Escape menu.

### A combat cluster you read without looking down

<p align="center"><img src="docs/media/readme/merit_combat.jpg" width="800" alt="The combat cluster in a pull: a nameplate casting, the target sigil with its health pill and cast line, its debuffs and your bars"></p>

<p align="center"><sub>The combat cluster in a pull: a nameplate casting, the target sigil, its debuffs and your bars.</sub></p>

Your target is a sigil centred over your bars: the name, a level line, a health pill between two gems and a gold cast line, over a soft scrim so it reads against bright scenes. A cast you cannot interrupt reads <b>Locked</b> in red, even when the game keeps that fact secret.

When a frame's aura row is full, the last socket reads <b>+N</b>. The game's secure aura engine does the counting, so the number stays true in combat. Boss cards stand in a column. The boss you target folds to a slim Targeted chip because the sigil already shows its health and cast.

### Party and raid frames at a healer's standard

<p align="center"><img src="docs/media/readme/merit_raid.jpg" alt="Twenty raid tiles with missing health, debuffs, a dead and an offline member"></p>

<p align="center"><sub>Twenty raid tiles: missing health, debuffs, a dead and an offline member.</sub></p>

Up to 40 members on the game's own group headers, so clicks land on the right person mid-fight. Dispellable debuffs lead the row, a member with a boss debuff glows red, a dispel tints the tile by its type, a thin line shows the whole shield even at full health, and your own heals over time sit in their own lane.

Six indicator slots each show a category of auras in the nearest free spot. The frames work with the game's Click Casting, and the settings page shows your bindings live.

### Set up in one window on your first login

<p align="center"><img src="docs/media/readme/merit_setup.jpg" width="800" alt="The setup's layout step: DPS, Tank and Healer cards over one preview of the layout you point at"></p>

<p align="center"><sub>The layout step: three layouts over one preview of the one you point at.</sub></p>

A four-step window opens on your first login: pick the DPS, Tank or Healer layout from a real-size preview, choose your modules, apply. KstyleUI then writes a layout into Blizzard's Edit Mode so the quest tracker, the damage meter and your tracked buffs take their places too.

Closing it early still gives you the DPS layout. <b>Keep my UI</b> leaves the game's interface exactly as it was. Run it again any time with <code>/kstyle setup</code>.

### Built for Forever from the start

<p align="center"><img src="docs/media/readme/merit_plates.jpg" width="800" alt="A seven-mob pull: stacked nameplates, your debuffs on each, two casts, one of them your target's"></p>

<p align="center"><sub>A seven-mob pull: stacked plates, your debuffs on each, two casts, one of them your target's.</sub></p>

Health, power, casts and auras go straight to the game's widgets. Every comparison is guarded by <code>issecretvalue</code>, and a secret takes a safe default. Protected work waits for combat to end. Blizzard's frames are hidden by reparenting, never scripted, and come back when a module stops.

Nameplates show your debuffs through the engine with an honest +N chip, and colour a cast you could interrupt right now. In the gamepad interface KstyleUI steps aside for Blizzard's bars, frames and bags.

### The rest of the screen, in the same hand

<p align="center"><img src="docs/media/readme/merit_rail.jpg" width="520" alt="The right rail while questing: the round minimap lens, the Blessings card and the damage meter"></p>

<p align="center"><sub>The right rail while questing: the lens, the Blessings card and the damage meter.</sub></p>

The minimap sits in a round lens with an addon drawer. Your buffs live in a Blessings card beside it, with a +N count on the cap and a right-click to cancel. The damage meter reads from the game's own meter data with a Now, Last, All switch and a spell breakdown on click.

Bags sort into sections with a search that understands <code>&amp;</code>, <code>|</code>, <code>!</code> and <code>ilvl&gt;30</code>. Chat sits on a glass card, tooltips become glass cards, and experience is a gilt filament with its rested overlay.

## What it changes

KstyleUI is one core addon and one addon per module. Every module is off until you switch it on, and a module that is off costs nothing: no frames, no events and no hooks.

<table>
<tr>
<td width="50%" valign="top"><img src="docs/media/readme/tile_unitframes.jpg" alt="Unit frames"><br><b>Unit frames</b><br><sub>A vitals line with a ringed portrait, the target sigil, focus and boss cards.</sub></td>
<td width="50%" valign="top"><img src="docs/media/readme/tile_groupframes.jpg" alt="Party and raid frames"><br><b>Party and raid</b><br><sub>Secure frames with role rings, dispel and boss debuffs, shields and your heals.</sub></td>
</tr>
<tr>
<td width="50%" valign="top"><img src="docs/media/readme/tile_actionbars.jpg" alt="Action bars"><br><b>Action bars</b><br><sub>Six secure bars as dark sockets. A socket's rim turns gold while a proc is up.</sub></td>
<td width="50%" valign="top"><img src="docs/media/readme/tile_cooldowns.jpg" alt="Cooldowns"><br><b>Cooldowns</b><br><sub>Blizzard's Cooldown Manager mirrored as KstyleUI icons and bars, each movable.</sub></td>
</tr>
<tr>
<td width="50%" valign="top"><img src="docs/media/readme/tile_auras.jpg" alt="Blessings card"><br><b>Blessings card</b><br><sub>Your buffs and debuffs in one card, drawn by the game's secure aura engine.</sub></td>
<td width="50%" valign="top"><img src="docs/media/readme/tile_nameplates.jpg" alt="Nameplates"><br><b>Nameplates</b><br><sub>Health, level, your debuffs and a cast bar that says when you can interrupt.</sub></td>
</tr>
<tr>
<td width="50%" valign="top"><img src="docs/media/readme/tile_minimap.jpg" alt="Minimap"><br><b>Minimap</b><br><sub>A round lens with the zone and clock in its foot and an addon drawer.</sub></td>
<td width="50%" valign="top"><img src="docs/media/readme/tile_chat.jpg" alt="Chat"><br><b>Chat</b><br><sub>Blizzard's chat on a glass card with gilt tabs and a copy window.</sub></td>
</tr>
<tr>
<td width="50%" valign="top"><img src="docs/media/readme/tile_bags.jpg" alt="Bags and bank"><br><b>Bags and bank</b><br><sub>One window, sections by item type, and a search grammar.</sub></td>
<td width="50%" valign="top"><img src="docs/media/readme/tile_meters.jpg" alt="Meters"><br><b>Meters</b><br><sub>Damage and threat from the game's own data, with fight segments and spell lists.</sub></td>
</tr>
<tr>
<td width="50%" valign="top"><img src="docs/media/readme/tile_skins.jpg" alt="Blizzard windows, skinned"><br><b>Blizzard windows</b><br><sub>The spellbook, talents, map, mail, merchant and more on the same glass.</sub></td>
<td width="50%" valign="top"><img src="docs/media/readme/tile_layout.jpg" alt="Layout Mode"><br><b>Layout Mode</b><br><sub>Mover plates, snapping, a grid, resize handles, undo and redo.</sub></td>
</tr>
</table>

Every element KstyleUI shows can be moved, resized or scaled in Layout Mode and from the settings window, and every module has its own fonts, textures, colours and sizes.

<details>
<summary>Every module, in one table</summary>

| Module | What it does |
| --- | --- |
| Core | The design system, the settings window (with its General page's panel opacity, panel shadows, interface sounds and tooltip size), Layout Mode, profiles, the first-run setup and `/kstyle` |
| Unit Frames | Player, target, target of target, focus, focus target, pet and boss 1 to 5, with portraits, cast bars, frame auras, the class resource, threat glow and status icons |
| Group Frames | Party and raid frames up to 40, with class colours, roles, range fade, incoming heals, absorbs, debuffs and the dispel highlight |
| Action Bars | Secure action bars with stance, stealth, form and possess paging, pet and stance bars, keybind text, cooldowns, proc glows, range and usability shading, fade on mouseover, and a dialog that puts a newly learned spell rank on the bars |
| Cooldowns | Blizzard's Cooldown Manager in KstyleUI's style: essential and utility rows in the HUD band, tracked buff icons and bars |
| Auras | Your buffs and debuffs under the minimap |
| Nameplates | A KstyleUI plate on each nameplate, with health, cast bar, threat colour and your debuffs |
| Combat Text | Damage and heal numbers on KstyleUI's frames and plates, and KstyleUI's font for the game's own numbers |
| Minimap | A round lens on a frost card with the zone and clock in its foot, rim buttons and an addon-button drawer |
| Chat | Glass chat panels, tabs with an accent underline, timestamps, short channel names, clickable links, class-coloured names, a copy window, and a plus glyph in the tab row that opens the chat settings |
| Bags | Combined bags and bank with the keyring, search, sorting, quality borders and junk selling |
| Tooltips | Glass tooltips with quality and class colours, a health bar, optional IDs and cursor anchoring |
| Data Bars | XP, reputation and honour bars, the micro menu, the bag bar and a data strip with frame rate, latency, gold, durability and time |
| Meters | A damage meter, a threat meter and a swing timer |
| Skins | Blizzard's windows in KstyleUI's style: the character sheet, spellbook, talents, world map, quest log, objective tracker, game menu, group finder, mail, merchant, trainers, professions, social windows, Legacy, loot, popups, ready check and the AddOns list, and the RestedXP Guides addon's windows |

No module compares or does arithmetic on Forever's secret values, every protected change made in combat waits for combat to end, and the action bars, group frames, bags, auras, and the data bars' micro menu and bag bar hand back to Blizzard's in the gamepad interface.

</details>

## Every class

The same HUD on all nine classes: each class's own colour on every accent, its power type, its spells, its cast, its buffs and its pet.

<table>
<tr>
<td width="33%"><img src="docs/media/readme/class_druid.jpg" alt="Druid HUD"><br><sub>Druid</sub></td>
<td width="33%"><img src="docs/media/readme/class_hunter.jpg" alt="Hunter HUD"><br><sub>Hunter</sub></td>
<td width="33%"><img src="docs/media/readme/class_mage.jpg" alt="Mage HUD"><br><sub>Mage</sub></td>
</tr>
<tr>
<td width="33%"><img src="docs/media/readme/class_paladin.jpg" alt="Paladin HUD"><br><sub>Paladin</sub></td>
<td width="33%"><img src="docs/media/readme/class_priest.jpg" alt="Priest HUD"><br><sub>Priest</sub></td>
<td width="33%"><img src="docs/media/readme/class_rogue.jpg" alt="Rogue HUD"><br><sub>Rogue</sub></td>
</tr>
<tr>
<td width="33%"><img src="docs/media/readme/class_shaman.jpg" alt="Shaman HUD"><br><sub>Shaman</sub></td>
<td width="33%"><img src="docs/media/readme/class_warlock.jpg" alt="Warlock HUD"><br><sub>Warlock</sub></td>
<td width="33%"><img src="docs/media/readme/class_warrior.jpg" alt="Warrior HUD"><br><sub>Warrior</sub></td>
</tr>
</table>

## Get started

KstyleUI targets the Forever client only (TOC `16001`, game type `camelot`). It has not been released yet: the first release follows the owner's in-game test of the `staging` branch. Until then, follow [Install the addons](docs/TESTING.md#install-the-addons) in the test guide to run the current `staging` build from a clone.

1. Download the latest zip from the [Releases page](https://github.com/korallis/KstyleUI/releases) and unzip it into `World of Warcraft/_forever_/Interface/AddOns`, so that `KstyleUI` and the `KstyleUI_*` module folders sit there. Start the game. If the addons are not ticked in the game's AddOns list, tick them.
2. Log in. The first-run setup opens: pick the DPS, Tank or Healer layout and the modules you want, then click **Apply** and **Reload**. Close it early and you still get the DPS layout. **Keep my UI** changes nothing.
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

Cinzel and Alegreya Sans have no Chinese or Korean glyphs. On `zhCN`, `zhTW` and `koKR` clients every KstyleUI text uses the game's own font for that language, and on `ruRU` the game's Cyrillic font replaces Cinzel. A font you pick from another addon stays your choice.

## For developers

[`docs/DEVELOPING.md`](docs/DEVELOPING.md) has the repository layout, the checks to run, how to add a translation and where the design spec and the branch flow live.

## Licence

All rights reserved. See [`LICENSE.md`](LICENSE.md).
