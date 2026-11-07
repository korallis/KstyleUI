# KstyleUI mockups v3

Twenty-seven mockups: three scenes (leveling in Riverglades, the Hall of Thanes dungeon, the Darkspear Islands battleground), each for all nine Forever classes. They show the compact action bars and the Cooldown Manager that the spec requires. They are AI concept art. Names, numbers and quest text are placeholders.

| Field | Value |
| --- | --- |
| Model | Higgsfield `gpt_image_2_5`, variant `flare` |
| Settings | `--aspect_ratio 16:9 --resolution 2k --quality high`, downscaled here to 1600 px JPEG at quality 82 |
| Date | 2026-11-07 |
| Generator | [`gen_v3.py`](gen_v3.py) holds the full prompt template, the per-class data and the shared layout block |
| Masters | `leveling_shaman`, `dungeon_paladin` and `pvp_warlock` were generated first from two references: `../05_kit_hunter.jpg` and a world reference. Every other image adds its scene's master as a third reference for layout. |
| World references | Riverglades and the Hall of Thanes: real Forever screenshots published by Warcraft Tavern (URLs in `../v2_provenance.md`). Darkspear Islands: KstyleUI's own `../v2_pvp.jpg`. The reference screenshots are not in this repository. |
| Rerolls | `dungeon_warrior` (missing action bars), `pvp_rogue` and `pvp_mage` (copied the master's demon pet) were generated a second time with an extra instruction, set through the `EXTRA` environment variable. |
