# Major cooldowns and self-enhancements: priest, druid, shaman (Forever 1.60.1.71037)

Source: `SkillLineAbility`, `SpellName`, `SpellCooldowns`, `SpellEffect` and `SpellLevels`, exported read-only from the installed `wowf` client with `Tools/icons/casc_export.py`'s `export_tables` (TACTTool + DBC2CSV). A spell counts only when `AcquireMethod` is 0 (trainer or talent; 3 is a Season of Discovery rune, not learnable on Forever) and its class mask covers the class. Every entry applies an aura to the caster (`SpellEffect.Effect` 6) and has a cooldown of 30 s or more.

Route for all: Blizzard's aura slot on `"player"`, `HELPFUL`, `includeSpellIDs` = the list (helpful auras on the player are always filterable, `Blizzard_AuraContainerUtil.lua:70`); the slot's icon, duration and shown state are engine-fed, so Lua never reads a secret. A ready glint, if wanted, reads `C_Spell.GetSpellCooldown(id).isActive` (`NeverSecret`). Every spell is shown only when `C_SpellBook.IsSpellKnown` says so.

| Class | Spell | IDs | Cooldown | Notes |
| --- | --- | --- | --- | --- |
| Priest | Power Infusion | 10060 | 3 min | Level 40; also lights when another priest casts it on you |
| Priest | Inner Focus | 14751 | 3 min | Talent; until the next spell |
| Priest | Fade | 586, 9578, 9579, 9592, 10941, 10942 | 30 s | Trainer, level 8 |
| Priest | Fear Ward | 6346 | 3 min | When cast on yourself |
| Priest | Elune's Grace | 2651 | 5 min | Night elf only (race mask 8) |
| Priest | Feedback | 13896, 19271, 19273, 19274, 19275 | 3 min | Human only (race mask 1) |
| Priest | Dark Sacrifice | 1277324 | 10 min | Undead only (race mask 16) |
| Priest | Contingency Plan | 1277462 | 10 min | Gnome only (race mask 64) |
| Druid | Barkskin | 22812 | 1 min | Level 44 |
| Druid | Nature's Swiftness | 17116 | 3 min | Talent |
| Druid | Frenzied Regeneration | 22842 | 3 min | Level 36, Bear Form |
| Druid | Dash | 1850, 9821 | 5 min | Level 26 and 46 |
| Druid | Enrage | 5229 | 1 min | Level 12, Bear Form |
| Druid | Innervate | 29166 | 6 min | When cast on yourself |
| Druid | Nature's Grasp | 16689, 16810, 16811, 16812, 16813, 17329 | 1 min | Talent ranks |
| Shaman | Lightning Mastery | 16166 | 3 min | Talent; Forever's name for Elemental Mastery |
| Shaman | Nature's Swiftness | 16188 | 3 min | Talent |
| Shaman | Rage of the Farseer | 425336 | 3 min | Enhancement, acquire method 0, level 1 in the tables; in-game check that a shaman can learn it |

Not learnable on Forever (acquire method 3, runes): Pain Suppression 402004, Dispersion 425294, Power Word: Barrier 425207, Tiger's Fury 5217 and 417045, Berserk 417141, Survival Instincts 408024, Water Shield 408510, Earth Shield 408514, Ancestral Guidance 409324. Absent from the client: Shamanistic Rage, Bloodlust, Heroism. Divine Favor (20216) sits on the shared Holy line but is a paladin spell.
