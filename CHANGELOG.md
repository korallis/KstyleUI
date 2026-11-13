# KstyleUI changelog

## v0.1.0 (2026-11-13)

This is the overhaul. KstyleUI now has two HUD styles, Frames and Orbs, that you pick in Options and in the first-run setup, and almost every part of the screen was redrawn to match them: cleaner bars, new nameplates, a group damage meter and an interface size that lands exactly on whole screen pixels.

### Added

- Two HUD styles to choose from. Frames keeps the framed player and target cards. Orbs puts health and resource in two orbs with a forged tray round your first action bar. Options > General shows a picture of each style and the first-run setup has a HUD style step, so you see what you are picking.
- A group damage meter in the style of Details: one card with a bar per player, a switch between this fight, the last fight and the whole session, and the spell split under each row. The threat card follows the same design.
- Nameplates redrawn: plain, flat bars with tracked capital names, a black track while you hold threat, cast and stop flashes, and a name-only plate for objects such as a mailbox that can never fill a bar.
- A wide target bar at the top of the screen under Orbs, and a wide form of the target frame under Frames.
- Ultrawide screens choose between Centred and Spread. Centred keeps the HUD in the 21:9 band in the middle of a 32:9 monitor. Spread uses the whole width and keeps your group frames on the 21:9 line.
- One shared action slot for the action bars and the cooldown rows, with a pressed state, a proc glow, a lit sweep edge and a gilt flash when an ability is ready again.
- Combat text with white hits, gold crits and a short rise.
- Buffs sorted by how you use them.

### Changed

- The unit bars are clean: health and resource fill with a held loss band, a flash on a hit and a warning curve at low health. The target fills from the left, cast bars are taller, and party and raid frames use the same bars with a low-health glow.
- Interface size Auto now picks the size that fits your screen exactly and keeps every frame, bar, slot, aura and combat text on whole screen pixels. Under Orbs it reaches the same size as under Frames.
- The experience strip is clean, the readout sits on the world, and the micro menu shows only when you need it.
- Party frames sit at mid-left, and the right rail leaves room for four quests with the threat card off the centre.
- Tooltips, windows and the quest card share one card design. Tooltip headings, window headings, dropdown chevrons, bag and chat headings and in-tile aura counts were redrawn to match.
- Class colours on names are easier to read, and spell and cast labels no longer use Cinzel.
- Text is never drawn below 11 pixels at 1080 lines, and the Meters sample fits the settings pane.
- Options names only Frames and Orbs as HUD styles.

### Fixed

- The RestedXP guide step arrow is set in the number face and the steps are pitched like the quest card, and RestedXP's steps frame is sized so it enables under the rail.
- The damage card shows short whole numbers in and out of combat.
- Nameplates no longer dart about: the plate scale settings are held at 1 while plates ignore that scale.
- Baine fixed two things and we ported them: minimap buttons now move onto the square map's shape even when they were made before KstyleUI loaded, and the drawer collects the buttons Blackthornes and 0xgle Bugs draw themselves, and hands them back as they were. Baine also fixed nameplates for game objects. Thank you, Baine.
- The unit frames' bars no longer carry an ornament around them.
- The chat tab and its wash sit inside the chat card.

## v0.0.7 (2026-11-13)

A small release that fixes two things in the cooldown and buff displays.

### Fixed

- When KstyleUI falls back to Blizzard's own essential and utility cooldown rows, they now sit on KstyleUI's rows instead of on top of your action bars. A row you moved yourself, or one too wide to fit, stays where it was.
- Tracked buff icons and bars keep the right gap between icons at every icon size and UI scale.

## v0.0.6 (2026-11-13)

This release fixes what the first live session on World of Warcraft: Forever turned up, and sets the HUD up properly for ultrawide screens.

### Added

- A centred HUD width for ultrawide screens. The HUD sits in a 21:9 band by default, with 16:9 and full width as choices in Options, so nothing is stranded at the far edges of a 32:9 monitor.
- Separate cards for your quests and the RestedXP guide on the right rail, in place of one shared story card.

### Changed

- Empty slots on action bars 4 and 5 are hidden at rest. They still show while you drag an action onto a bar and while Layout Mode is open, and filled slots are always drawn.
- The damage meter shows KstyleUI's own card instead of Blizzard's restyled window. Blizzard's window is still there under Options > Meters > Style.

### Fixed

- Forged trim now draws on nameplates and on the player and target frames, placed from KstyleUI's own layout.
- Nameplates and the unit tooltip no longer raise "Can't measure restricted regions", so nameplates are no longer left half built.
- The chat text area fills the chat card, with no gap under the last line.

## v0.0.5 (2026-11-12)

KstyleUI is a full interface for World of Warcraft: Forever, drawn in one dark, Diablo IV-style forged look. Cards and windows are forged iron with corner brackets by default, and you can switch the card material in Options. You choose the type set (Folio, a classic serif, is the default; Lumen is still there) and a font for each kind of text, and forged ornaments on frames, bars, plates, the minimap and windows run at Off, Subtle or Full. This is the first public release.

### Added

- Every part of the interface as a module you switch on when you want it: unit frames, group frames, action bars, cooldowns, buffs and debuffs, nameplates, combat text, minimap, chat, bags and bank, tooltips, data bars, meters, window skins and a quality-of-life module.
- A settings window (`/kstyle`) with a page per module, search across every setting and a live preview, per-character profiles you can export and import as a string, and a first-run setup that picks a DPS, Tank or Healer layout and your modules.
- Layout Mode (`/kstyle layout`): move, resize and scale every element with snapping guides, a grid, arrow-key nudges, undo and redo, and set when each element shows.
- A card material choice in General: Forged iron with brackets (the default), Forged iron with gilt ticks, Slate, Flat or Glass. Dropdowns and tooltips stay opaque on every material except Glass.
- Type sets and fonts by role: pick Folio or Lumen, then override the font for any role, from KstyleUI's own faces or any LibSharedMedia font.
- Forged ornaments at Off, Subtle or Full (Full by default), on unit frames and cast bars, the action bar tray, nameplates, the minimap, the experience, reputation and honour bars, windows, tooltips and the RestedXP windows. They are dropped where they do not fit, never squeezed.
- A story card on the right rail that shows the RestedXP guide and your quests, a loot feed above the chat card, a white cursor on the player's cast bar, and a skin for RestedXP's other windows.
- Fast auto loot, auto repair, quest hand-in and quiet error text in the quality-of-life module, and an offer to update your bars when you learn a new spell rank.
- Bag search with `type:`, `name:`, `ilvl` and quality keywords, custom categories, junk selling, and a bank window with Warband tabs.
- A damage meter with a fight switch (now, last, all) and a spell split under each row, a group threat meter and a swing timer.
- Chat history that survives a reload or relog, a copy window, timestamps, short channel names and clickable links.
- Group frames with debuff priority and dispel highlights, your heals, absorbs, indicator slots and compact raid frames above 25 players.
- English, German, French, Spanish and Simplified Chinese. The German, French, Spanish and Chinese strings are machine-made and not yet checked by native speakers; report a wrong or awkward one.
- An optional icon pack of repainted ability and item icons, a separate download (see How to install).

### Changed

- Layouts follow one reference picture: chat and your party on the left, your hands at the centre, and the map, buffs, bars, readout and story card on the right. DPS, Tank and Healer layouts do not overlap at 16:9, 16:10 or 21:9, and everything sits on whole screen pixels at every size.
- The minimap is a square map inside a thin rim, with its controls shown while the pointer is over it. Buffs and debuffs are plain icon rows beside it.
- Unit frames, cast bars, the experience bar, nameplates and the chat card follow the picture's sizes, ramps and edges. Nameplates are flat bars with tracked capital names, and they are larger when you pull.
- Section captions and names use letter-spaced capitals. Under Folio, tooltip titles, chat and the boss cast names follow the type set.
- Player-facing German wording for the action bar, meter, minimap and font options was polished.

### Fixed

- Nothing raises "Font not set", "Cannot anchor protected frames to regions" or a secret-value error on the minimap, aura frames or nameplate casts, and capitals no longer show boxes between letters.
- Bags, group frames, auras and action bars hand back to Blizzard's own when you switch to the gamepad interface.
- The data strip, clock, chat, group frames and nameplates do less repeated work, so busy groups and big pulls stay smooth. Nameplate cast bars no longer restart or stick.
- Pet bar icons and right-click autocast work, item cooldowns use the right timers, and tracked buffs and group frames no longer hide dispellable debuffs.
- Chat shows whole lines at every size, the threat card keeps its rows at 1366x768, the quest card keeps all four quests, and forged trim no longer disappears on bars at the screen's edge.
- Players whose class is hidden in restricted content keep their class colour.

## How to install

1. Download the addon zip (`KstyleUI-v0.0.7-forever.zip`) from the [GitHub release](https://github.com/korallis/KstyleUI/releases) and unzip it into `World of Warcraft/_forever_/Interface/AddOns`. You get `KstyleUI` and a `KstyleUI_<Module>` folder for each module. Start the game (or `/reload`), then type `/kstyle` and switch on the modules you want.
2. Optional: the icon pack `KstyleUI-Icons-0.0.7.zip`, from the same release, repaints ability and item icons everywhere, buff tiles included. It is not an addon and does not go into `AddOns`: quit the game, copy its `Interface` folder into `_forever_`, and start the game again. The steps, and how to remove it, are in [the icon pack guide](https://github.com/korallis/KstyleUI/blob/main/docs/icons.md).
