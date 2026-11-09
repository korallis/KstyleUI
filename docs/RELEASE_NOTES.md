# KstyleUI release notes

## 1.0.0: the first release

Unreleased. The owner tags it after the in-game test of `staging` passes, as [`TESTING.md`](TESTING.md) describes.

KstyleUI replaces or restyles the whole World of Warcraft: Forever interface in one art direction, Lumen: translucent frost glass with soft rounded corners, gilt corner marks and rules, Cinzel headings over Alegreya Sans text, a live class-colour accent and eased motion. The default layout lines the interface up in rails: a story column on the left, your hands at the centre and the fight column on the right, and in combat the cards you only glance at calm to a lower opacity. It needs Forever (TOC `16001`).

### Added: the core

- **Design system.** One set of colour, size, motion and font tokens. The accent follows your class colour, or a custom colour, and changes in every open window when you log in on another class.
- **Whole-pixel scaling.** Everything draws on one canvas 1080 units tall, so it takes the same share of the screen at 1080p, 1440p, 4K and on a Retina Mac, and every border is a whole number of physical pixels. Moving the game to another screen redraws every border.
- **Settings window.** `/kstyle` opens it, with a page per module, search across every setting, a live preview of the module you are changing, and the Layout Mode button. It also opens from Esc > Options > AddOns and from the minimap's addon compartment. General settings cover the accent, the font (Lumen's Cinzel and Alegreya Sans by default, Source Sans 3 or Inter, or any LibSharedMedia font), the interface size from 75% to 150%, the text size and the motion level.
- **Layout Mode.** `/kstyle layout` shows a mover over every element. Drag with snapping guides and an optional grid, nudge with the arrow keys one physical pixel at a time (ten with Shift), resize from the corners and edges, scale with the mouse wheel, and undo, redo or reset. Combat closes Layout Mode and puts everything back. Positions save per profile against one of nine anchors, so one layout fits every screen.
- **Element settings.** Every element also gets rows in the settings window: when it shows (always, in combat, out of combat, with a target, on mouseover or never), its anchor and offsets, its size or scale, its opacity in and out of combat, and its strata.
- **Profiles.** Per-character profiles that store only what differs from the defaults. Export a profile as one string and import it back; a truncated, foreign or hostile string is refused with a reason before anything changes.
- **First-run setup.** On an account's first login, four steps pick a DPS, Tank or Healer layout and the modules to switch on, then reload through a secure button. `/kstyle setup` runs it again.
- **Languages.** English, German, French, Spanish (also on Latin American clients) and Simplified Chinese, in WoW's own terms for each language. Chinese, Taiwanese and Korean clients draw KstyleUI's text in the game's own font, and Russian clients get the game's Cyrillic font in place of Cinzel. Capitals keep their accents.
- **Smoke checks.** `/kstyle test` checks that every module you switched on is running, that no Lua error was caught, that the APIs KstyleUI needs exist, and that a profile export round-trips. The results and every fallback KstyleUI takes are kept in a devlog in the saved variables.

### Added: the modules

- **Unit Frames.** Secure player, target, target of target, focus, focus target, pet and boss 1 to 5 frames. Round 2D portraits (or the class icon, or none), health and power bars eased by the game engine, health text, incoming heals, reaction and class colours (also for players whose class is hidden in restricted content), threat glow, raid marker, leader, role, PvP, combat and resting icons, combo points for rogues and druids in cat form, druid mana in bear and cat form, cast bars for every frame run from the game's duration objects, and your debuffs on focus and boss frames.
- **Group Frames.** Party and raid frames on secure group headers, up to 40, sorted by group, role or class. Portraits with class rings, range fade, dead and offline states, role, leader, marker and ready-check icons, a threat border, incoming heals, absorbs, debuff icons and the dispel highlight. They hand over to Blizzard's frames in the gamepad interface.
- **Action Bars.** KstyleUI's own secure buttons: two rows of 12 by default and up to six bars, a pet bar and a stance bar. Stance, stealth, form and possess paging, your existing keybinds with short keybind text, cooldown sweeps with charges, proc glows, range, power and usability shading, flyouts, a leave-vehicle button, fade until hovered, and a clean hand-over to the gamepad bars.
- **Cooldowns.** Blizzard's Cooldown Manager as KstyleUI icons: essential cooldowns above the action bars and utility cooldowns beneath, plus tracked buff icons and bars. If the mirror cannot work, Blizzard's viewers are restyled in place instead.
- **Auras.** Your buffs and debuffs under the minimap on the game's AuraContainer engine, with timers, weapon enchants, right-click to cancel and debuff-type borders.
- **Nameplates.** A KstyleUI plate on each enemy and friendly nameplate: health, name, level, cast bar, threat colour, your debuffs, target and focus highlights, raid markers, and elite and rare marks. Optional management of the game's nameplate settings.
- **Combat Text.** Animated damage and heal numbers on unit frames, group frames and nameplates, and in a field above your character, with rise, arc and pop animations. The game's own damage numbers use KstyleUI's font from the next login.
- **Minimap.** A round lens on a frost card that is the lens plus its foot, the zone and clock in the foot, the north mark on the lens's edge, coordinates, mouse-wheel zoom and a zoom slider, rim buttons (tracking, mail, calendar, queue status) and a drawer for addon minimap buttons.
- **Chat.** Glass chat panels with capitalised tabs and a gilt underline on the active one, a restyled edit box, timestamps, short channel names, clickable web links, class-coloured names, a copy window, and each window's last lines kept across a reload or relog (100 by default, never the combat log).
- **Bags.** One combined bag window and a bank window with bank types, bank bags and tab buying. Keyring, search, sorting, item levels, quality borders, new-item glows and junk selling, by button or by itself.
- **Tooltips.** Glass tooltips with quality-coloured edges, class-coloured names, guild and target lines, a health bar, optional item, spell and icon IDs, and an anchor you can place in Layout Mode or the cursor.
- **Data Bars.** XP, reputation and honour bars with ticks, rested XP and eased gains. The micro menu and bag bar on glass, placed with Layout. A data strip with frame rate, latency, gold, durability and the clock, each clickable.
- **Meters.** A damage meter on the game's damage meter data, with a fight switch on the card (this fight, the last fight or every fight) and each source's spells a click away, a threat meter for your group with warning colours, and a swing timer for melee and ranged.
- **Skins.** Blizzard's windows in KstyleUI's style: the character sheet with quality-rimmed slots, the spellbook and talents, the world map, quest log and objective tracker, the game menu, group finder, mail, merchant, class and profession trainers, professions, the friends list, the guild and communities window, Forever's Legacy window, loot and loot rolls, popups, the ready check and the AddOns list.
- **Icon pack.** Every player ability and item icon repainted from Blizzard's own art as a full-colour painting, shipped as a separate download, `KstyleUI-Icons-<version>.zip`, that goes into `_forever_/Interface/Icons`. The client loads it itself, so the repaints show everywhere, buff and debuff tiles included. See `docs/icons.md`.

### Safety and performance

- Every module is off until you switch it on, and a module that is off creates no frames and registers no events.
- KstyleUI never compares or does arithmetic on the game's secret values: health, power, casts and aura data go straight to the game's widgets.
- Protected changes made in combat wait for combat to end. Blizzard's frames are hidden by moving them to a hidden parent outside combat and Edit Mode, never by scripting them.
- The suite stays clear of Forever's gamepad interface: action bars, group frames, bags and auras hand back to Blizzard's when you switch to it.
- Combat paths are measured offline against a time budget and must allocate no memory.

### Known limitations

- Several engine behaviours are confirmed only in game. Where KstyleUI cannot confirm one, it takes a safer path and writes which path it took to the devlog.
- The nameplate distance settings show only on a client that has those settings.
- A gamepad layout, click-casting, extra themes, boss timelines and translations beyond English are not part of the first release.
