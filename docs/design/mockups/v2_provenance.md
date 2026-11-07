# KstyleUI mockups v2: provenance

| Field | Value |
| --- | --- |
| Model | Higgsfield `gpt_image_2_5` (GPT Image 2.5), variant `flare` |
| Settings | `--aspect_ratio 16:9 --resolution 2k --quality high`, two `--image-references` each |
| Date | 2026-11-07 |
| Reference 1 (all scenes) | `05_kit_hunter.png` (KstyleUI design-system sheet, generated 2026-11-07) |
| Class colours | Blizzard standard values: shaman `#0070DD`, paladin `#F48CBA`, warlock `#8788EE`. Forever reads them from `C_ClassColor.GetClassColor` at run time (`Blizzard_SharedXML/ClassColors.lua`), so they are not in the Lua source. |

## World references

| Scene | Reference 2 | Source page | Notes |
| --- | --- | --- | --- |
| Leveling | https://www.warcrafttavern.com/wp-content/uploads/2026/09/riverglades-new-zone-warcraft-forever.jpg | https://www.warcrafttavern.com/forever/news/all-new-zones-areas-in-wow-forever-revealed-at-blizzcon/ | Real 3840x2160 Forever screenshot (JPEG comment carries game worldport data); downscaled to 2048 px |
| Dungeon | https://www.warcrafttavern.com/wp-content/uploads/2026/09/wow-forever-hall-of-thanes-dungeon-guide-first-chamber.jpg | https://www.warcrafttavern.com/forever/guides/hall-of-thanes/ | Real Hall of Thanes first chamber, 1920x1080 |
| PvP | https://timesaver.gg/cdn/blog/wow-forever/wow-forever-pvp-battlegrounds-darkspear-islands-honor/featured.jpg | https://timesaver.gg/blog/wow-forever-pvp-battlegrounds-darkspear-islands-honor | Darkspear Islands battleground article image, cropped to 1600x770 to remove the watermark |

## v2_leveling

Result: https://d8j0ntlcm91z4.cloudfront.net/user_3JpAAQCiqO8qg3QRWViCBDmOWXp/hf_20261107_005907_504ffceb-e649-4ba6-bbf2-8f5aa619519e.png

```
Reference image 1 is the KstyleUI design-system sheet: use it as the exact component library for every piece of user interface, recoloured to this scene's class colour. Reference image 2 is a real in-game screenshot from World of Warcraft: Forever: the 3D world, terrain, architecture, lighting and characters must match its World of Warcraft art style exactly (stylised hand-painted textures, chunky readable proportions), not photorealistic.
Scene: a third-person over-the-shoulder in-game screenshot at 2560x1440 of World of Warcraft: Forever in the Riverglades zone. An orc shaman named Koral, level 38, in mail armour with a two-handed mace, fights a Riverglade crocolisk on a riverbank at mid-afternoon, a stone watchtower on a rocky hill behind like reference image 2. Lightning arcs from Koral's hand.
CLASS COLOUR: shaman blue #0070DD (accents only).
User interface, exactly in the component sheet's style but recoloured to #0070DD:
1. Player frame and target frame centred just above the action bars, side by side: a round portrait in a thin chamfered ring on the outer side of each, a wide slim health bar (player: blue gradient fill; target: red), a thin mana bar under the player's, names KORAL level 38 and RIVERGLADE CROCOLISK level 37 in small spaced caps, health percentages in large numerals.
2. Centred under them, a slim player cast bar reading Lightning Bolt and 1.6s with a light sheen crossing it.
3. Bottom centre: two rows of twelve square chamfered action buttons in the sheet's style. Every button shows a custom icon of white light-sculpture art tinted shaman blue: lightning bolt, earth shock, flame shock, frost shock, stormstrike, healing wave, lightning shield, windfury weapon, searing totem, ghost wolf, chain lightning, purge. Tiny keybind text in each corner. Two buttons show a dark radial cooldown sweep with countdown numbers. The Stormstrike button has a pulsing blue proc glow.
4. Directly above the action bars, a prominent wide XP bar with blue fill, a lighter rested segment, and the text XP 41,250 / 62,000 (66%).
5. Top-right corner: a SQUARE minimap with small chamfered corners and a blue hairline frame; the zone name RIVERGLADES and the clock 16:24 sit on a dark strip INSIDE the minimap's bottom edge; a vertical column of four small monochrome line-icon buttons runs down its left side.
6. Under the minimap: a tidy row of square buff icons with durations and one debuff with a red edge.
7. Right side under the buffs: a quest tracker titled QUESTS with three quests in light grey (Snapjaw Season: Crocolisks slain 7/10; The Drowned Watchtower: Investigate the tower; Mudfin Raiders: Mudfin Scales 3/8) and a thin blue bar beside the active quest.
8. Floating combat text in KstyleUI's clean semibold font over the crocolisk: a large white-gold critical number 1,284 with a soft glow, a smaller 412, and a blue-tinted 236; over Koral a green +386.
9. Bottom-left: a smoked-glass chat panel with tabs GENERAL, COMBAT, TRADE, the active tab underlined in blue, four readable chat lines.
10. Bottom-right: a slim data strip: 144 FPS | 24 ms | 37g 12s | 92% | 16:24.
The 3D world stays clearly visible; the UI hugs the edges and the lower centre.
UI STYLE (KstyleUI): a modern, luxurious, minimal game interface. Every panel is near-black smoked glass (#101010 to #1c1c1c at about 88 percent opacity) with small crisp 45-degree chamfered (cut) corners, a double-line bevel edge (dark outer line plus a faint light inner hairline) and a soft outward drop shadow. The single accent colour is the CLASS COLOUR given below; use it sparingly: thin hairlines that fade out at both ends, soft glows, active and selected states, and the player health bar fill. Text is a clean semibold sans-serif (like Source Sans or Inter), light grey #ababab with white highlights, tiny all-caps labels with wide letter spacing, large crisp numerals for health percentages. Pixel-crisp, aligned to a clean grid, generous spacing. Absolutely no ornate fantasy borders, no gold filigree, no parchment, no stone textures on the UI, no rounded bubbly corners, no glossy plastic. Feels like a premium sports-car HUD or luxury watch interface fused with a high-fantasy MMORPG. Realistic in-game screenshot, sharp UI, readable text.
```

## v2_dungeon

Result: https://d8j0ntlcm91z4.cloudfront.net/user_3JpAAQCiqO8qg3QRWViCBDmOWXp/hf_20261107_005907_5de1242c-897c-4a4a-97df-f0a9d9036ea1.png

```
Reference image 1 is the KstyleUI design-system sheet: use it as the exact component library for every piece of user interface, recoloured to this scene's class colour. Reference image 2 is a real in-game screenshot from World of Warcraft: Forever: the 3D world, terrain, architecture, lighting and characters must match its World of Warcraft art style exactly (stylised hand-painted textures, chunky readable proportions), not photorealistic. Reference image 2 shows the inside of the Hall of Thanes dungeon beneath Ironforge: carved dwarven stone pillars, braziers, red carpets, dark stone halls.
Scene: an in-game screenshot at 2560x1440 inside the Hall of Thanes. A party of five level 18 Alliance adventurers (a dwarf paladin, a human warrior tank, a gnome mage, a night elf rogue, a dwarf priest) fights MAGMATUS, a towering molten fire elemental, next to a Dark Iron Summoner, in a torch-lit dwarven hall. The camera sits behind the dwarf paladin (the player), who is casting Holy Light.
CLASS COLOUR: paladin pink #F48CBA (accents only).
User interface, exactly in the component sheet's style but recoloured to #F48CBA:
1. Left side: five compact party frames stacked vertically, each with a round portrait, a class-coloured health bar (warrior tan #C69B6D, mage blue #3FC7EB, rogue yellow #FFF468, priest white #FFFFFF, paladin pink #F48CBA), a role icon and tiny debuff icons; one frame shows incoming-heal shading and a green +642 floating off it.
2. Top centre: a boss bar MAGMATUS with a skull icon and a red health bar at 64%, and a smaller DARK IRON SUMMONER bar under it.
3. Screen centre: a boss cast bar with chamfered ends reading Molten Pulse 2.1s with a light sheen.
4. Nameplates over the enemies: slim chamfered bars with red health; the summoner's plate has a soft orange threat glow.
5. Lower centre, just above the action bars: the player frame (round portrait, pink gradient health, blue mana) and the target frame (Magmatus) side by side, with the player cast bar Holy Light 2.5s under them.
6. Bottom centre: two rows of square chamfered action buttons whose icons are white light-sculpture art tinted paladin pink (holy light, flash of light, seal of righteousness, judgement, blessing of might, devotion aura, hammer of justice, divine protection, lay on hands, purify, blessing of wisdom, redemption), keybind text, cooldown sweeps on two buttons, a pink proc glow on one.
7. Bottom-right: a THREAT meter panel (five bars with percentages) and under it a DAMAGE meter panel with five class-coloured bars and values like 48.2 DPS.
8. Top-right corner: a SQUARE minimap with chamfered corners and a pink hairline; the text HALL OF THANES and 21:05 on a dark strip INSIDE its bottom edge; a small column of monochrome buttons down its left side; buff icons under it.
9. Floating combat text over Magmatus in KstyleUI's clean font: a large critical 214, then 96 and 88.
10. Bottom-left: a chat panel with tabs, the active tab underlined in pink. A slim data strip in the bottom-right corner.
UI STYLE (KstyleUI): a modern, luxurious, minimal game interface. Every panel is near-black smoked glass (#101010 to #1c1c1c at about 88 percent opacity) with small crisp 45-degree chamfered (cut) corners, a double-line bevel edge (dark outer line plus a faint light inner hairline) and a soft outward drop shadow. The single accent colour is the CLASS COLOUR given below; use it sparingly: thin hairlines that fade out at both ends, soft glows, active and selected states, and the player health bar fill. Text is a clean semibold sans-serif (like Source Sans or Inter), light grey #ababab with white highlights, tiny all-caps labels with wide letter spacing, large crisp numerals for health percentages. Pixel-crisp, aligned to a clean grid, generous spacing. Absolutely no ornate fantasy borders, no gold filigree, no parchment, no stone textures on the UI, no rounded bubbly corners, no glossy plastic. Feels like a premium sports-car HUD or luxury watch interface fused with a high-fantasy MMORPG. Realistic in-game screenshot, sharp UI, readable text.
```

## v2_pvp

Result: https://d8j0ntlcm91z4.cloudfront.net/user_3JpAAQCiqO8qg3QRWViCBDmOWXp/hf_20261107_005908_2a31357d-d927-46bf-9e77-a3b0f5eeaabf.png

```
Reference image 1 is the KstyleUI design-system sheet: use it as the exact component library for every piece of user interface, recoloured to this scene's class colour. Reference image 2 is a real in-game screenshot from World of Warcraft: Forever: the 3D world, terrain, architecture, lighting and characters must match its World of Warcraft art style exactly (stylised hand-painted textures, chunky readable proportions), not photorealistic. Reference image 2 shows the Darkspear Islands battleground: red-earth tropical islands, troll huts on stilts, palm trees, wooden piers and turquoise sea at sunset.
Scene: an in-game screenshot at 2560x1440 of a 15 versus 15 battleground fight on Darkspear Islands at sunset. The player, an undead warlock (Horde, level 60) with a felhunter pet, fights Alliance players: a human priest casting a heal, a night elf druid, a dwarf paladin and a gnome mage. Shadow bolts and fel fire fly across the scene.
CLASS COLOUR: warlock violet #8788EE (accents only).
User interface, exactly in the component sheet's style but recoloured to #8788EE:
1. Top centre: a smoked-glass battleground objective strip: HORDE 3 BASES 1,240 on one side and ALLIANCE 2 BASES 980 on the other, the timer 14:32, and five small base icons coloured by owner.
2. Enemy player nameplates over each enemy with class-coloured health bars (priest white #FFFFFF, druid orange #FF7C0A, paladin pink #F48CBA, mage blue #3FC7EB), names in small caps, and small crowd-control icons on two of them (Fear with a countdown, Polymorph).
3. A focus frame left of centre: FOCUS ELUNARA, PRIEST with a round portrait, a health bar and a focus cast bar Greater Heal shown INTERRUPTED: the bar flashes red with the word INTERRUPTED and a small Spell Lock icon.
4. Player frame and target frame centred just above the action bars (round portraits, violet gradient health, mana bar), a small pet frame FELHUNTER under the player frame, and the player cast bar Shadow Bolt 1.9s with a light sheen.
5. Bottom centre: two rows of square chamfered action buttons whose icons are white light-sculpture art tinted warlock violet (shadow bolt, corruption, curse of agony, immolate, fear, howl of terror, death coil, drain life, life tap, spell lock, shadowburn, healthstone), keybind text, cooldown sweeps on Death Coil and Howl of Terror, and a violet proc glow on Shadow Bolt.
6. Floating combat text in KstyleUI's clean font: a big critical 2,431 over the priest, violet damage-over-time ticks 687 and 512, and a green +214 over the player.
7. Top-right corner: a SQUARE minimap with chamfered corners and a violet hairline; DARKSPEAR ISLANDS and 19:48 on a dark strip INSIDE its bottom edge; a small column of monochrome buttons down its left side; buffs and one red-edged debuff under it.
8. Left side: five compact friendly group frames with class-coloured health bars and round portraits.
9. Bottom-left: a chat panel with the BATTLEGROUND tab active and underlined in violet. Bottom-right: a slim data strip ending in Honor 1,820.
UI STYLE (KstyleUI): a modern, luxurious, minimal game interface. Every panel is near-black smoked glass (#101010 to #1c1c1c at about 88 percent opacity) with small crisp 45-degree chamfered (cut) corners, a double-line bevel edge (dark outer line plus a faint light inner hairline) and a soft outward drop shadow. The single accent colour is the CLASS COLOUR given below; use it sparingly: thin hairlines that fade out at both ends, soft glows, active and selected states, and the player health bar fill. Text is a clean semibold sans-serif (like Source Sans or Inter), light grey #ababab with white highlights, tiny all-caps labels with wide letter spacing, large crisp numerals for health percentages. Pixel-crisp, aligned to a clean grid, generous spacing. Absolutely no ornate fantasy borders, no gold filigree, no parchment, no stone textures on the UI, no rounded bubbly corners, no glossy plastic. Feels like a premium sports-car HUD or luxury watch interface fused with a high-fantasy MMORPG. Realistic in-game screenshot, sharp UI, readable text.
```

