# KstyleUI release notes

The player-facing notes for every release are in [`CHANGELOG.md`](../CHANGELOG.md). The packager reads that file, so the GitHub release carries the whole file. The owner tags a release on `main` after the in-game test of `staging` passes, as [`TESTING.md`](TESTING.md) describes.

## 0.2.5: your feedback

Bind any action, stance, pet or possess button by hovering it with `/kb` or `/kstyle kb` and pressing a key, then Save; bindings are real game bindings, so they show in Blizzard's Key Bindings window. Clicking the stance button cancels stealth again. Opening Options no longer raises "Invalid font height (0)". The RestedXP guide arrow is ivory with a dark edge, so it reads in dark zones. KstyleUI also does far less work at login, reload and display changes and skips needless updates in combat, with no visible change. `/reload` is enough after installing. The full list is in [`CHANGELOG.md`](../CHANGELOG.md).

## 0.2.4: on CurseForge and Wago

KstyleUI is now published on CurseForge and Wago Addons as well as GitHub, so addon managers such as the CurseForge app and WowUp can install and update it. The addon itself is unchanged from 0.2.3.

## 0.2.3: Medallions, polished

Medallions gets a polish pass. The chrome is dark gunmetal with rounded, bevelled edges, and the rails follow: dark cards with header bands in your class colour, a round minimap ring with an N badge, and matching chat, damage meter, quest card and tooltips. The action slab has recessed, rounded sockets, no keybinds on empty slots, a class-colour border inside a socket whose ability lights up, and your race-and-class crest fills its dark gunmetal ring at full brightness, clipped to the ring so even wide crests stay inside it; the wings are retired. Medallion rims carry an engraved band of runes. Numbers are Barlow Semi Condensed, nameplates are slimmer with ticks on your target, and scrolling combat text is gold and rises and fades faster. Your unit frames sit in one tight cluster just above the action slab, with outlined health numbers at the end of each bar, cast bars over the crest and your target's debuffs as small tiles with a dispel-colour underline, and the action bars are one row of twelve a side at every screen. Unused Medallions art is gone, so the download is smaller.

Fixes beyond the polish: on the Medallions target slab, creature types show in full, long names stay in capitals by shrinking a little before they shorten, and the raid marker sits clear of your target's debuff timers; beside the RestedXP guide the quest card keeps your objective and its progress on show, and it keeps a quest whose details have not loaded yet while others update and retries the load after combat, RestedXP's Active Items box lines up with Active Targets, Options sliders and live previews keep their labels and portraits in bounds, the leave-vehicle button sits clear of the hub and stays visible when your first bar is faded, and the quest card, minimap face, data bars and loot feed have crisper edges at fitted HUD sizes. Frames and Orbs are otherwise unchanged. The full list is in [`CHANGELOG.md`](../CHANGELOG.md).

## 0.2.2: readable Medallions and one combat-text display

The crest hub keeps its painted steel and runes visible between effects: changing its tint no longer revives the shock ring and square flash. Medallions bars are flat, without the white sheen, and bright health fills get dark, readable numbers. CombatText now hides Blizzard's separate world damage and healing numbers by default; a saved Keep choice remains unchanged. With Keep selected, the native numbers use the combat-text font role after a full logout to the character screen and login. `/reload` alone cannot refresh that font.

The intermittent blank quest card remains under investigation. If it goes blank, `/kstyle test` records its native visibility, opacity, frame levels and geometry. Zero-visible-row layouts also record a bounded, deduplicated diagnostic automatically. Reloading or logging out saves that devlog for inspection; these diagnostics do not change the card's layout.

## 0.2.1: the Medallions action slab, connected

Under Medallions your first two action bars now stand in one row on every screen, twelve either side of the crest, as the design drew them, instead of two rows of six below 21:9. The slab, the crest, its wings and your experience strip are one connected piece: the crest sits in the slab, its wings grow out along the slab's top edge and slide along it in combat, and the experience strip runs along the slab's lower edge. On 16:9 and narrower screens the buttons are a fifth smaller so the row fits beside your chat, and the pet and stance bars move to the right of the slab in two rows of five. Frames and Orbs are unchanged. No fonts or textures changed, so `/reload` is enough after installing. The full list is in [`CHANGELOG.md`](../CHANGELOG.md).

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
