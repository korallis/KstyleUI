# KstyleUI mockups

These images are AI concept art for KstyleUI's look. They are design references, not game screenshots. Text, icons and numbers in them are placeholders.

`05_kit_hunter.jpg` is the canonical reference for every component: unit frames, the square minimap, action buttons, panels, tabs, controls, tooltips, tokens and type. `02_dungeon_mage.jpg` is the reference for how the combat HUD is composed.

| File | Shows | Class colour |
| --- | --- | --- |
| `01_openworld_warrior.jpg` | Open-world HUD | Warrior `#C69B6D` |
| `02_dungeon_mage.jpg` | Dungeon combat HUD: party frames, boss bar, nameplates, cast bar, meters | Mage `#3FC7EB` |
| `03_windows_rogue.jpg` | Character sheet, bags and tooltip | Rogue `#FFF468` |
| `04_settings_druid.jpg` | Settings window. The UI behind the window is Blizzard's default, so ignore it. | Druid `#FF7C0A` |
| `05_kit_hunter.jpg` | Design-system sheet | Hunter `#AAD372` |
| `icons_A_luminous.jpg` | Icon pilot, set A: white light art, tinted in game | None |
| `icons_A_tint_mage.jpg` | Set A tinted with one class colour, made locally from `icons_A_luminous.jpg` | Mage `#3FC7EB` |
| `icons_A_tint_school.jpg` | Set A tinted per spell school, made locally from `icons_A_luminous.jpg` | Per school |
| `icons_B_fullcolour.jpg` | Icon pilot, set B: full-colour painted art | None |
| `v2_leveling.jpg` | Leveling in Riverglades, built from the approved spec and a real Forever screenshot | Shaman `#0070DD` |
| `v2_dungeon.jpg` | Hall of Thanes boss fight. The party names are placeholders. | Paladin `#F48CBA` |
| `v2_pvp.jpg` | Darkspear Islands battleground | Warlock `#8788EE` |

The `v2_` mockups have their own provenance, with full prompts and the reference screenshots used, in [`v2_provenance.md`](v2_provenance.md). The reference screenshots themselves are not in this repository.

## Provenance

| Field | Value |
| --- | --- |
| Model | Higgsfield `gpt_image_2_5` (GPT Image 2.5), variant `flare` |
| Settings | `--resolution 2k --quality high`; `16:9` for screens, `3:2` for icon sheets |
| Date | 2026-11-07 |
| Account | The owner's Higgsfield account |
| Post-processing | PNG to JPEG at quality 88 with `sips`. The two tinted sheets came from a local Pillow script that maps greyscale to a colour ramp. |

Every screen prompt ended with the same style block:

```
UI STYLE (KstyleUI): a modern, luxurious, minimal game interface. Every panel is near-black smoked glass (#101010 to #1c1c1c at about 88 percent opacity) with small crisp 45-degree chamfered (cut) corners, a double-line bevel edge (dark outer line plus a faint light inner hairline) and a soft outward drop shadow. The single accent colour is the CLASS COLOUR given below; use it sparingly: thin hairlines that fade out at both ends, soft glows, active and selected states, and the player health bar fill. Text is a clean semibold sans-serif (like Source Sans or Inter), light grey #ababab with white highlights, tiny all-caps labels with wide letter spacing, large crisp numerals for health percentages. Pixel-crisp, aligned to a clean grid, generous spacing. Absolutely no ornate fantasy borders, no gold filigree, no parchment, no stone textures on the UI, no rounded bubbly corners, no glossy plastic. Feels like a premium sports-car HUD or luxury watch interface fused with a high-fantasy MMORPG. Realistic in-game screenshot, sharp UI, readable text.
```
