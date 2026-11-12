# KstyleUI release notes

The player-facing notes for every release are in [`CHANGELOG.md`](../CHANGELOG.md). The packager reads that file, so the GitHub release carries its newest section. The owner tags a release on `main` after the in-game test of `staging` passes, as [`TESTING.md`](TESTING.md) describes.

## 0.0.5: the first public release

KstyleUI restyles the whole World of Warcraft: Forever interface in one Diablo IV-style forged look: dark cards and windows with forged iron brackets (the card material is a setting), a type set you choose in Options (Folio by default, Lumen as an alternative) and forged ornaments at Off, Subtle or Full. The default layout lines the interface up in rails: a story column and chat on the left, your hands at the centre and the fight column on the right. It needs Forever (TOC `16001`). The repainted icons are an optional second download, `KstyleUI-Icons-<version>.zip`; see [`icons.md`](icons.md).

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
