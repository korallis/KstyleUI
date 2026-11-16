# KstyleUI release notes

The player-facing notes for every release are in [`CHANGELOG.md`](../CHANGELOG.md). The packager reads that file, so the GitHub release carries the whole file. The owner tags a release on `main` after the in-game test of `staging` passes, as [`TESTING.md`](TESTING.md) describes.

## 0.2.0: Medallions

A third HUD style, Medallions, next to Frames and Orbs. Your frames become steel slabs with a round medallion that shows a painted portrait of your race, class and sex. Your first two action bars share one steel slab, and at its centre sits a crest painted for your race and class. The crest breathes at rest, spreads its wings in combat, pulses when an ability beside it lights up and bursts when you level up, always under your action buttons. Medallions motion, under Options > General > Medallions, sets how much moves: Full, Calm or Off. Cards, windows, the minimap, party, raid frames and nameplates follow in steel. Pick it in Options > General > HUD style or in the first-run setup. The addon has new files, so fully restart the game after installing rather than using `/reload`. The full list is in [`CHANGELOG.md`](../CHANGELOG.md).

## 0.1.3: RestedXP guide hotfix

The RestedXP guide card shows your whole current step again, instead of a blank block with only the step's last line and "1 more". Under Frames, while the guide is shown, the guide card takes the tall column and the quest card moves under the minimap, where it shows at least one quest and scrolls for the rest. The cards swap only when the guide opens or closes. Also fixed: the bag window's close button after a drag, a hunter's doubled ranged swing bar, and nameplates that crept upward. No fonts or textures changed, so `/reload` is enough after installing. The full list is in [`CHANGELOG.md`](../CHANGELOG.md).

## 0.1.2: minimap, RestedXP guide and screen fit

Keeps the minimap's zone name clear of the N diamond, hides the pins that guides such as RestedXP park on the map's edge (the new setting **Addon pins on the map's edge** brings them back), and docks RestedXP's Active Targets and Active Items boxes side by side under the guide card. Under Orbs, the orbs no longer cover chat on 4:3, 3:2 and 16:10 screens, and action bar 3 has its own place. Interface size Auto steps down until the whole HUD fits, and settings that had stopped updating at an older version update again. No fonts or textures changed, so `/reload` is enough after installing. The full list is in [`CHANGELOG.md`](../CHANGELOG.md).

## 0.1.1: hotfix

Fixes load and switch errors in raid frames, window skins, the HUD style switch and the quest tracker in Edit Mode, a false interrupt warning at login, and nameplates that dropped below the mob in combat. After installing, fully restart the game so the addon's fonts load. The full list is in [`CHANGELOG.md`](../CHANGELOG.md).

## 0.1.0: the HUD overhaul

KstyleUI has two HUD styles, Frames and Orbs, picked in Options and in the first-run setup. Bars, nameplates, the group damage meter and the action slots were redrawn, the interface size Auto lands on whole screen pixels, and ultrawide screens choose between a Centred and a Spread arrangement. It needs Forever (TOC `16001`). The full list is in [`CHANGELOG.md`](../CHANGELOG.md); the minimap and nameplate fixes in it are Baine's.

## 0.0.5: the first public release

KstyleUI restyles the whole World of Warcraft: Forever interface in one Diablo IV-style forged look: dark cards and windows with forged iron brackets (the card material is a setting), a type set you choose in Options (Folio by default, Lumen as an alternative) and forged ornaments at Off, Subtle or Full. The default layout lines the interface up in rails: chat and your party on the left, your hands at the centre, and the map, buffs, readout and story card on the right. It needs Forever (TOC `16001`). The repainted icons are an optional second download, `KstyleUI-Icons-<version>.zip`; see [`icons.md`](icons.md).

### Safety and performance

- Every module is off until you switch it on, and a module that is off creates no frames and registers no events.
- KstyleUI never compares or does arithmetic on the game's secret values: health, power, casts and aura data go straight to the game's widgets.
- Protected changes made in combat wait for combat to end. Blizzard's frames are hidden by moving them to a hidden parent outside combat and Edit Mode, never by scripting them.
- Action bars, group frames, bags and auras hand back to Blizzard's in the gamepad interface.
- Combat paths are measured offline against a time budget and must allocate no memory.

### Known limitations

- Several engine behaviours are confirmed only in game. Where KstyleUI cannot confirm one, it takes a safer path and writes which path it took to the devlog.
- The nameplate distance settings show only on a client that has those settings.
- A gamepad layout, extra themes, boss timelines and translations beyond the five shipped languages are not part of this release. The German, French, Spanish and Simplified Chinese tables are machine-translated and unreviewed by native speakers.
