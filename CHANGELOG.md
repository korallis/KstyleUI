# KstyleUI changelog

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

- Layouts follow one reference picture: a story and chat column on the left, your hands at the centre, the map, buffs, bars and readout on the right. DPS, Tank and Healer layouts do not overlap at 16:9, 16:10 or 21:9, and everything sits on whole screen pixels at every size.
- The minimap is a square map inside a thin rim, with its controls shown while the pointer is over it. Buffs and debuffs are plain icon rows beside it.
- Unit frames, cast bars, the experience bar, nameplates and the chat card follow the picture's sizes, ramps and edges. Nameplates are flat bars with tracked capital names, and they are larger when you pull.
- Section captions and names use letter-spaced capitals; numbers use oldstyle figures. Under Folio, tooltip titles, chat and the boss cast names follow the type set.
- Player-facing German wording for the action bar, meter, minimap and font options was polished.

### Fixed

- Nothing raises "Font not set", "Cannot anchor protected frames to regions" or a secret-value error on the minimap, aura frames or nameplate casts, and capitals no longer show boxes between letters.
- Bags, group frames, auras and action bars hand back to Blizzard's own when you switch to the gamepad interface.
- The data strip, clock, chat, group frames and nameplates do less repeated work, so busy groups and big pulls stay smooth. Nameplate cast bars no longer restart or stick.
- Pet bar icons and right-click autocast work, item cooldowns use the right timers, and tracked buffs and group frames no longer hide dispellable debuffs.
- Chat shows whole lines at every size, the threat card keeps its rows at 1366x768, the quest card keeps all four quests, and forged trim no longer disappears on bars at the screen's edge.
- Players whose class is hidden in restricted content keep their class colour.

## How to install

1. Download `KstyleUI-0.0.5.zip` from the [GitHub release](https://github.com/korallis/KstyleUI/releases) and unzip it into `World of Warcraft/_forever_/Interface/AddOns`. You get `KstyleUI` and a `KstyleUI_<Module>` folder for each module. Start the game (or `/reload`), then type `/kstyle` and switch on the modules you want.
2. Optional: the icon pack `KstyleUI-Icons-0.0.5.zip`, from the same release, repaints ability and item icons everywhere, buff tiles included. It is not an addon and does not go into `AddOns`: quit the game, copy its `Interface` folder into `_forever_`, and start the game again. The steps, and how to remove it, are in [docs/icons.md](docs/icons.md).
