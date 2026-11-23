# Crest trackers for Priest, Druid and Shaman: research and concepts

Task `task_e1d3e0e8234c`, 2026-11-23. Base `b1f25c6a9` (staging). Design only: no addon code, no commit, no PR, nothing posted.

## Recommendation

| Class | Recommended concept | What the crest tracks |
| --- | --- | --- |
| Priest | **A, Vigil** | Inner Fire charges (halo and four flames on the inner rim), Penance or Mind Blast ready (left shoulder medal), Shadowfiend ready or Shadowform (right shoulder medal), your Shadow Word: Pain on the target (gem at the top of the ring) |
| Druid | **A, Grove** | Your two effects on the target (two seed medals on the shoulders, form-aware), Clearcasting (leaves bloom on the inner rim), Swiftmend, Nature's Swiftness or Innervate ready (gem at the top of the ring) |
| Shaman | **A, Stormforged** (adds to Spirit Poles, storm orbs and the two medals) | Weapon imbues (two stones set into the ring, main hand and off hand), shock cooldown (the emblem sweeps and sparks) |

Every piece uses a route that is already proven in the addon: Blizzard's aura slots, duration objects, the totem and form booleans, or values the client never marks secret. No Lua comparison of a secret is needed anywhere.

## 1. Pictures

All in `C:/Users/leeba/.cache/kstyleui-evidence/crest-trackers/healers/`.

| File | What it shows |
| --- | --- |
| `priest-concepts.png` | Priest A (Vigil) and B (Censer), three states each, crest crop at 3x |
| `priest-A-vigil.gif` | Priest A, 7 s at 12 fps: Inner Fire cast, Pain on the target, Penance cooldown and ready, flames going out, expiry |
| `druid-concepts.png` | Druid A (Grove) and B (Moon and Claw), three states each |
| `druid-A-grove.gif` | Druid A, 7.2 s: two timed effects, a Clearcasting bloom spent on the next cast, Moonfire expiring and recast, Swiftmend cooldown and ready |
| `shaman-concepts.png` | Shaman A (Stormforged) and B (Charged Band) on today's crest with Spirit Poles, medals and storm orbs |
| `shaman-A-stormforged.gif` | Shaman A, 7.2 s: off-hand imbue cast, shock cooldown and ready spark, main-hand imbue guttering, lost and recast |

How they were made, and their limits:

- **The HUD is real.** Each picture starts from `Tools/render/shoot.sh hud_priest_mac`, `hud_druid_mac` or `hud_shaman_mac` at 1920x1080, `--ppu 1`, Medallions, `RENDER_SIZE=auto`, DPS layout. The shaman base also sets `RENDER_TOTEMS=story RENDER_TOTEMS_T=8 RENDER_FX=storm RENDER_FX_T=2.5`, so the Spirit Poles, both medals and the storm orbs are the shipped code's own drawing.
- **The backdrop is real game scenery.** A UI-free band of `game_06` (crop 40,180 to 1640,1080, scaled 1.2x to 1920x1080).
- **The new pieces are composites, drawn with PIL from shipped textures only.** No generated art and no Higgsfield job. The flames are `Storm/StormOrb.png` recoloured gold, the halo and bloom are the shipped `AmbientPriest.png`, `AmbientDruid.png`, `BurstPriest.png`, `BurstDruid.png` and `ParticleDruid.png`, the candles are the shipped crown candles, and the medals, gems and stones are `Ring128.png`, `Ring.png`, `Dot.png` and `Glow.png` with icons from `Tools/icons/setB/Icons`. They are stand-ins for placement and behaviour, not final art.
- **Drawn at 1x, enlarged afterwards** (3x in the sheets, 2x in the GIFs), so sizes are honest: a medal is 28 px, a flame about 22 px, a gem or stone 15 px.
- **Time is compressed in the GIFs.** A 12 s Penance cooldown runs in 2.4 s, a 60 minute imbue in seconds. Each frame names its beat underneath.
- **Only Medallions at 1920x1080 was drawn.** Frames is described in section 7, not drawn. 2560x1440, 5120x1440 and 3840x2160 were not rendered.
- **Two beats depend on an in-game check** and are marked in sections 3 to 5: the last-flame flicker in combat, and the "last seconds" flicker of a druid effect.

## 2. Routes that keep secrets out of Lua

Paths are under `~/.cache/wow-ui-source/Interface/AddOns` at `9dc84f0` (1.60.1.70862). Client data is `SkillLineAbility`, `SpellName`, `Spell`, `SpellAuraOptions`, `SpellCooldowns`, `SpellLevels`, `SpellMisc`, `SpellEffect`, `SpellReagents`, `SpellItemEnchantment`, `Talent` and `TalentTab`, exported read-only from the installed `wowf` client **1.60.1.71037** with TACTTool and DBC2CSV into the task's scratch folder. `SpellDuration` did not convert, so durations quoted below are the Classic values and are marked so.

| Route | What it gives | Proof | Already used in KstyleUI |
| --- | --- | --- | --- |
| **R1 Aura slot + application bar** | A lit piece per charge or stack, and "aura is up" (the slot button hides itself when the aura is gone) | `Blizzard_AuraContainer/Blizzard_CustomAuraContainer.lua:417`; `Blizzard_CustomAuraButton.lua:68-77, 419-431, 694-705` | `KstyleUI_ActionBars/SlabStorm.lua:108-122, 199-212` |
| **R2 Aura slot + duration** | A bar or a radial swipe fed the aura's own duration object: `SetDurationBar` calls `SetTimerDuration`, `SetDurationCooldown` calls `SetCooldownFromDurationObject` | `Blizzard_CustomAuraButton.lua:159-168, 224-233, 598-623` | `KstyleUI_Auras/Button.lua:183-184` |
| **R3 Spell cooldown** | `C_Spell.GetSpellCooldownDuration(spell, ignoreGCD)` returns a duration object with no secret flag. The ready moment comes from the Cooldown widget's `OnCooldownDone` and from `isActive` and `isOnGCD`, both `NeverSecret` | `Blizzard_APIDocumentationGenerated/SpellDocumentation.lua:327`; `SpellSharedDocumentation.lua:26, 30`; `FrameAPICooldownDocumentation.lua:308` | `KstyleUI_ActionBars/Button.lua:155-156`; `KstyleUI_Cooldowns/Mirror.lua:471, 549` |
| **R4 Form** | `GetShapeshiftFormInfo(i)` gives `texture, isActive, isCastable, spellID`; the active boolean goes to `SetAlphaFromBoolean` when it is secret | `Blizzard_ActionBar/Shared/StanceBar.lua:155` | `KstyleUI_ActionBars/Totems.lua:91-101, 288-295` (Ghost Wolf medal) |
| **R5 Weapon imbue** | `container:AddItemEnchantment(slot)` gives a slot frame fed the temporary enchant's duration and charges; `C_PaperDollInfo.GetTemporaryEnchantmentInfo(slot)` returns `enchantID`, `remainingTimeMs`, `chargesRemaining`, `hasExpirationTime` with no secret flag | `Blizzard_CustomAuraContainer.lua:488-507`; `Blizzard_AuraContainerUtil.lua:206-214`; `PaperDollInfoDocumentation.lua:226, 491-498`; event `WEAPON_ENCHANT_CHANGED`, `ItemDocumentation.lua:1923` | `KstyleUI_Auras/Panel.lua:394-401, 513-525` |
| **R6 Totem slot** | `GetTotemInfo` boolean and `GetTotemDuration` object | `TotemDocumentation.lua:44, 59` | Spirit Poles, hawk perches |
| **R7 Item count** | `C_Item.GetItemCount(id)` has no secret return flag | `ItemDocumentation.lua:451` | `KstyleUI_Auras/Reminder.lua:85-87` |
| **R8 Own casts** | The player's own `UNIT_SPELLCAST_SUCCEEDED` is readable; used only to time a flourish | `UnitDocumentation.lua:4847-4855` | `SlabStorm.lua:318-333` |

**Which auras a slot may pick by spell ID** (`Blizzard_AuraContainerUtil.lua:52-86`, applied at `:101-111`):

| Aura | Allowed? | Line |
| --- | --- | --- |
| Helpful, on the player, a group member or any player-controlled unit | Yes | `:70` |
| Helpful, on another unit the player can assist | Yes (falls through to `return true`) | `:82-86` |
| Harmful, on a unit the player cannot assist (an enemy) | Yes | `:78`, `:86` |
| **Harmful, on the player or any unit the player can assist** | **No**, unless the spell is flagged never-secret | `:64`, `:78-80` |

That last row rejects every "debuff on me or on my friend" tracker, most importantly Weakened Soul.

**Not relied on:** the "about to expire" window (`AddPandemicRegion` and its enter and leave animations, `Blizzard_CustomAuraButton.lua:256-312, 728-815`) is engine-driven and secret-safe, but it only opens when `C_UnitAuras.GetRefreshCarryOverDuration` returns more than zero (`Blizzard_AuraContainerUtil.lua:13-28`). Whether Forever's Classic rules give any spell a carry-over cannot be read offline. Where it does, a "last seconds" flicker comes free; where it does not, that flicker is simply absent.

## 3. Priest

Today a priest's crest has only the crown: five candles for Shadow Weaving, and nothing at all without that talent. A healing priest's crest is bare.

### What a priest watches

| Thing | IDs on Forever | Level, talent | Route | Verdict |
| --- | --- | --- | --- | --- |
| **Inner Fire**, 20 charges, a hit spends one | 588, 7128, 602, 1006, 10951, 10952 (`ProcCharges = 20`, `CumulativeAura = 0`) | Trainer, level 12 | R1, helpful on the player: four flames fed 0-5, 5-10, 10-15, 15-20; a fifth slot is the halo | **Pass.** Check that charges arrive as `applications`, as they do for Lightning Shield |
| **Penance** ready | 402174, 1240720, 1240721, 1316995; 12 s category cooldown | Trainer, levels 30, 40, 50, 60 | R3 | **Pass** |
| **Mind Blast** ready | 8092, 8102, 8103, 8104, 8105, 8106, 10945, 10946, 10947; 8 s | Trainer, level 10 | R3 | **Pass** |
| **Shadowfiend** ready | 401977; 5 min cooldown; `AcquireMethod = 0` | Trainer; `SpellLevel 1`, so the level it is sold at is unknown offline | R3 | **Pass**; shown only once the spell is known |
| **Shadowform** | 15473 (talent 521, Shadow, 31 points); a shapeshift form (aura 36) | Talent | R4, as the Ghost Wolf medal | **Pass** |
| **Shadow Word: Pain** on the target | 589, 594, 970, 992, 2767, 10892, 10893, 10894 | Trainer, level 4 | R2, `HARMFUL|PLAYER` on `target` | **Pass** (enemy target) |
| Prayer of Mending ready | 401859, 1240826, 1240827; 10 s | Trainer, level 40 | R3 | Pass; not picked (three medals would crowd the crest) |
| Shadow Weaving stacks | 15258 | Talent | R1 on the target | Already the crown |
| Sacred Candle count | item 17029 (Prayer of Fortitude 21564, Prayer of Spirit 27681, Prayer of Shadow Protection 27683) | Level 48 | R7 | Pass; not picked (a bag count is not a combat signal) |

**Rejected:**

- **Weakened Soul** (6788) on yourself or a friend: a harmful aura on an assistable unit, so the slot may not pick it by ID (`Blizzard_AuraContainerUtil.lua:78-80`), and a Lua read is secret in combat.
- **Power Word: Shield on a friend, Renew on a friend:** allowed by the filter, but which friend matters, and that is the group frames' job, not the crest's.
- **Mind Spike, Serendipity, Dispersion, Pain Suppression, Circle of Healing, Shadow Word: Death, Vampiric Touch, Void Plague:** rune spells (`AcquireMethod = 3`), not learnable on Forever.
- **Race spells:** Shadowguard and Hex of Weakness (troll), Touch of Weakness and Dark Sacrifice (undead), Starshards and Elune's Grace (night elf), Desperate Prayer and Chastise (dwarf), Feedback and Divine Grace (human), Contingency Plan and Confounding Flash (gnome). Each belongs to one race (`SkillLineAbility.RaceMasks`), so none can be a class piece.

### A. Vigil (recommended)

- **Inner Fire: a halo and four flames on the inner rim.** Four gilt studs sit on the crest's inner rim at the corners, where the shaman's storm orbs rest. Casting Inner Fire lights a soft halo and a flame on each stud, 5 charges each. As hits spend charges the flames go out one at a time, top right first; the last one flickers and the halo dims. When the buff ends the studs stand dark, which reads as "recast".
- **Left shoulder medal: Penance ready.** The icon sweeps through its 12 s cooldown and the medal rings gold when it is ready. Before level 30, and for a priest who has Shadowform, the medal is Mind Blast (8 s).
- **Right shoulder medal: Shadowfiend ready**, with the same sweep and ring over 5 minutes. A priest with Shadowform gets the Shadowform medal here instead, lit violet while in the form, exactly as the Ghost Wolf medal lights.
- **Gem at the top of the ring: Shadow Word: Pain on the target.** It fills violet when your Pain lands and drains over its duration (18 s in Classic); an empty socket means the target has no Pain of yours.
- **Clear of the crown:** the gem sits on the ring band at 60 px, under the candles' base at 76 px.

### B. Censer

- **Inner Fire burns on the crown:** the five shipped candles, 4 charges each, for every priest without Shadow Weaving. A shadow priest keeps Shadow Weaving on the candles and sees no Inner Fire.
- The same two shoulder medals. Nothing tracks the target.
- It is the smaller build (the crown exists; only its feed changes), but it leaves shadow priests without Inner Fire and gives healers nothing new except a crown.

### Why A

A works the same for every priest, keeps the approved Shadow Weaving crown untouched, and reuses the storm orbs' proven build (studs, one aura slot per piece, a halo slot). B is the fallback if the inner rim should stay the shaman's alone.

### What a low-level priest sees

Nothing until level 4. Then the Pain gem (4), the Mind Blast medal (10), the Inner Fire studs and flames (12), Penance on the left medal (30), Shadowfiend when trained, Shadowform at 40 with the talent. A piece whose spell is unknown is not created.

### In-game checks

1. `/dump C_UnitAuras.GetPlayerAuraBySpellID(10952).applications` out of combat with a fresh Inner Fire should be 20.
2. **Last-flame flicker in combat.** Lua cannot count hits taken, so the flicker needs an engine-only trick: the first flame drawn as two layers, a flickering one fed charges 0-1 under a steady one fed charges 5-6. If that does not read well, the flicker plays only while the count is readable (out of combat) and the flames still go out correctly in combat.
3. The level at which the trainer sells Shadowfiend.
4. Whether the Pain gem's duration bar moves on a hostile target inside an instance.

## 4. Druid

Today the druid's crest has a crown in two forms (claws for combo points in Cat Form, talons for Lacerate in Bear Form) and nothing as a caster, a healer or a moonkin.

### What a druid watches

| Thing | IDs on Forever | Level, talent | Route | Verdict |
| --- | --- | --- | --- | --- |
| **Moonfire** on the target | 8921, 8924, 8925, 8926, 8927, 8928, 8929, 9833, 9834, 9835 | Trainer, level 4 | R2, `HARMFUL|PLAYER` on `target` | **Pass** |
| **Insect Swarm** on the target | 5570, 24974, 24975, 24976, 24977 | Talent (Restoration tree, third row) | R2, same | **Pass** |
| **Rejuvenation** on the target | 774, 1058, 1430, 2090, 2091, 3627, 8910, 9839, 9840, 9841, 25299 | Trainer, level 4 | R2, `HELPFUL|PLAYER` on `target` | **Pass**: helpful on a friendly player is always filterable (`:70`) |
| **Regrowth** on the target | 8936, 8938, 8939, 8940, 8941, 9750, 9856, 9857, 9858 | Trainer, level 12 | R2, same | **Pass** |
| **Rake** on the target | 1822, 1823, 1824, 9904 | Trainer, level 24 | R2, harmful | **Pass** |
| **Rip** on the target | 1079, 9492, 9493, 9752, 9894, 9896 | Trainer, level 20 | R2, harmful | **Pass** |
| **Clearcasting** (Omen of Clarity) | 16870, one charge, 15 s in Classic; talent 16864 | Talent (Balance, third row), level 20 | R1 and R2, helpful on the player; the bloom is an aura-shown animation | **Pass** |
| **Swiftmend** ready | 18562; 15 s | Talent (Restoration, 31 points) | R3 | **Pass** |
| **Nature's Swiftness** ready | 17116; 3 min | Talent (Restoration) | R3 | **Pass** |
| **Innervate** ready | 29166; 6 min | Trainer, level 40 | R3 | **Pass** |
| Bear, Cat, Travel, Aquatic, Moonkin form | 5487, 9634, 768, 783, 1066, 24858 | Levels 10, 40, 20, 30, 16; Moonkin is a talent | R4 | Pass; used in concept B |
| Lacerate, combo points | | | | Already the crown |
| Wild Growth ready | 408120 and two more ranks; 6 s | Trainer, level 40 | R3 | Pass; not picked |
| Barkskin, Enrage, Frenzied Regeneration, Feral Charge ready | 22812 (60 s), 5229 (60 s), 22842 (3 min), 1238122 (15 s) | Trainer | R3 | Pass; not picked (form-specific, and the cooldown row shows them) |

**Rejected:**

- **Lifebloom (408124), Nourish, Living Seed, Starsurge, Sunfire, Starfall, Berserk, Survival Instincts, Skull Bash, Savage Roar (407988):** rune spells or no skill-line row; not learnable on Forever.
- **Tiger's Fury:** 5217 is `AcquireMethod = 3` on Forever and its older ranks have no name row, so I cannot prove a druid can learn it. Left out until an in-game look.
- **Mark of the Wild or Thorns missing:** half-hour and ten-minute buffs; the buff row covers them.
- **Demoralizing Roar and Faerie Fire on the target:** anyone's application counts, and `PLAYER` filtering would show an empty piece while the debuff is in fact up.
- **The energy tick:** no engine feed.

### A. Grove (recommended)

- **Two seed medals on the shoulders: your two effects on the target.** Each shows the effect's icon with a timer sweeping round it and a lit rim in the effect's colour; a dim medal means the effect is missing. What they show follows what is on the target, so they need no mode switch:

| Target | Left medal | Right medal |
| --- | --- | --- |
| Enemy | Moonfire | Insect Swarm (talent) |
| Friend | Rejuvenation | Regrowth |
| Enemy, in Cat Form | Rake | Rip |

  Each medal is two aura slots on `target` (one `HARMFUL|PLAYER`, one `HELPFUL|PLAYER`) with the icon and the swipe fed by the engine. For a healer, both medals lit on a friend also means Swiftmend has something to consume.
- **Clearcasting: leaves bloom round the inner rim.** When Omen of Clarity procs, a ring of leaves and a warm glow unfurl inside the rune ring and hold while the buff is up; on the cast that spends it they scatter outward. This is the druid's "moment".
- **Gem at the top of the ring: Swiftmend ready.** Lit green when ready; it empties when used and refills over the cooldown, then flashes. Without the Swiftmend talent it is Nature's Swiftness, and without that, Innervate (level 40).
- **Clear of the crown:** the medals sit at the shaman's medal seats, outside the claws' and talons' fan (50 to 130 degrees), and the gem sits under the crown's base.

### B. Moon and Claw

- **Bear Form and Cat Form ride as medals on the shoulders,** lit while you are in that form and clickable to shift, as the shaman's Ghost Wolf is.
- **Clearcasting:** the inner rim glows green.
- **Gem at the top:** Innervate ready.
- It is the closest translation of the shaman's medals, and the lightest build. It tells a druid little they cannot already see: their form is on screen and on the stance bar.

### Why A

A shows the three things a druid otherwise hunts for in the target's debuff row, in every form, with one unchanged layout. B is the fallback if the owner wants form buttons on the crest; the two cannot share the shoulders.

### What a low-level druid sees

From level 4 the left medal (Moonfire, Rejuvenation). The right medal arrives with Regrowth at 12, and with Insect Swarm when talented. Clearcasting arrives with the talent at level 20 or later, Rake and Rip in Cat Form from 20 and 24, the gem with Innervate at 40 or a Restoration talent.

### In-game checks

1. With Moonfire and Rake both on one target (shift after casting), which one the left medal's slot picks; set the slot's sort so the current form's effect wins.
2. Whether the swipe moves on a hostile target in an instance, and on a friendly target in a raid.
3. **The "last seconds" flicker** in the GIF needs the engine's pandemic window (section 2). If Forever reports no carry-over, the medal simply sweeps to empty with no flicker.
4. Whether Clearcasting 16870 is the aura a Forever druid gets (the client also has 12536, 16246, 457342 and 467735; include them if not).
5. Whether Tiger's Fury can be learned.

## 5. Shaman: extending what exists

Today's crest: four Spirit Poles sockets with burning spires, three storm orbs and a halo for Lightning Shield, Ghost Wolf and Call of the Elements medals on the shoulders, and the ring catching the class colour with all four totems up. The top arc, the shoulders and the inner rim are full. The ring band's lower half and the emblem itself are the free space.

### What else a shaman watches

| Thing | IDs on Forever | Level, talent | Route | Verdict |
| --- | --- | --- | --- | --- |
| **Weapon imbue, main hand and off hand** | Spells: Rockbiter 8017 and 6 more ranks, Flametongue 8024 and 5 more, Frostbrand 8033 and 4 more, Windfury 8232 and 3 more. Enchant IDs: Rockbiter 29, 6, 1, 503, 1663, 683, 1664, 7568; Flametongue 5, 4, 3, 523, 1665, 1666, 7567; Frostbrand 2, 12, 524, 1667, 1668, 7566; Windfury 283, 284, 525, 1669, 7569. All last 3600 s | Trainer, levels 1, 10, 20, 30 | R5: the slot frame feeds the timer; the enchant ID (not secret) picks the element colour; "none" is `GetTemporaryEnchantmentInfo` returning nothing | **Pass** |
| **Shock cooldown** (Earth, Flame and Frost Shock share it) | Earth Shock 8042 to 10414, Flame Shock 8050 to 29228, Frost Shock 8056 to 10473; 6 s category | Trainer, level 4 | R3 with `ignoreGCD` true | **Pass** |
| Reincarnation ready, and an Ankh in the bags | 20608; 60 min; reagent item 17030 | Trainer, level 30 | R3 and R7 | Pass; an optional third piece (see below) |
| Stormstrike, Riptide, Elemental Mastery, Nature's Swiftness ready | 17364 (8 s, talent), 408521 and two more ranks (12 s, trainer, level 40), 16166 (3 min, talent), 16188 (3 min, talent) | | R3 | Pass; not picked: the shoulders are taken and the cooldown row shows them |
| Flame Shock on the target | 8050, 8052, 8053, 10447, 10448, 29228 | Level 10 | R2 | Pass; not picked (a fifth timer on a full crest) |
| Flurry, Clearcasting | 16257 (3 charges), 16246 (1 charge) | Talents | R1 | Pass; not picked |

**Rejected:**

- **Water Shield (408510, 3 charges) and Earth Shield (408514, 9 charges):** rune spells (`AcquireMethod = 3`); a Forever shaman cannot learn them. If an in-game look ever shows Water Shield on a Forever shaman, the three storm orbs can carry it in blue with one more set of slots.
- **Maelstrom Weapon, Lava Lash, Molten Blast, Decoy Totem, Healing Rain, Spirit of the Alpha, Ancestral Guidance:** runes.
- **Mana Tide Totem ready:** it is a water totem, so its socket and spire already show it.

### A. Stormforged (recommended)

- **Two weapon stones set into the ring:** one at the lower left for the main hand, one at the lower right for the off hand. A stone glows in its imbue's element colour, the same colours as the totem sockets: Windfury violet, Flametongue orange, Frostbrand blue, Rockbiter green. It gutters through the imbue's last five minutes, then goes dark and pulses a gilt rim until you re-imbue. Casting an imbue ignites the stone with a flare. The off-hand stone exists only while an off-hand weapon is equipped.
- **Shock cooldown in the emblem:** when you shock, the class emblem dims and a sweep runs round it for 6 s; when a shock is ready again the emblem sparks. Nothing new is added to the crest's outline.
- **Optional third piece, not drawn:** a small ankh on the level plaque, gold when Reincarnation is ready and an Ankh is in the bags, grey when either is missing. It is a once-an-hour signal, so it adds no noise.
- **Clear of everything that exists:** the stones sit on the ring band at 60 px, below the medals (which sit outside the ring at 84 px) and outside the orbs' orbit (54 px). The sweep is under the orbs and the halo.

### B. Charged Band

- **The imbues light the rune band itself:** the lower left arc for the main hand and the lower right arc for the off hand, in the element colour; a dark arc means no imbue.
- **Shock ready:** a storm gem at the top of the ring, under the sockets, that empties and refills.
- It reads from further away, but the band is also what catches the class colour and breathes when all four totems are up, so two effects would fight over the same metal; and the gem adds a fifth item to the crowded top.

### Why A

A puts both additions where the crest is empty today, and it borrows nothing from the ring's all-four-totems glow. A shaman has Rockbiter Weapon at level 1, so the first stone is the first thing a new shaman's crest ever shows.

### What a low-level shaman sees

The main-hand stone from level 1, the shock sweep from level 4, then Lightning Shield (8), the first sockets as totems are trained, Ghost Wolf and Call at 20.

### In-game checks

1. `/dump C_PaperDollInfo.GetTemporaryEnchantmentInfo(16)` and `(17)` in combat: confirm the values are readable there, as the API documentation says. If `remainingTimeMs` turns out restricted, the gutter falls back to the slot frame's own timer and the stone still lights and clears correctly.
2. Whether a Forever shaman can dual wield (the client has Dual Wield 674 on the shaman line as an automatic grant).
3. Confirm the emblem sweep with `ignoreGCD` true does not start on every global cooldown.
4. Whether the imbue's enchant IDs on Forever are the old ranks or the new 7566 to 7569 rows; both are in the table above.

## 6. Shared design rules

- **One family.** Medals are round and sit on the shoulder seats the shaman's medals use (`Totems.lua:21`). Gems and stones are set into the ring band at 60 px. Counted charges are flames on the inner-rim studs at 54 px, as the storm orbs are. Nothing new is invented per class except the art.
- **Draw nothing when unknown.** A piece is created only when its spell is known; a class that is not the player's creates no frame and registers no event.
- **Motion** follows Appearance > Motion as the shaman's pieces do: Full plays flares, flickers and the bloom; Calm keeps the state changes and drops flicker and pulse; Off shows end states only. Timers are state, not motion, and always run.
- **Settings**, each on by default, under Action Bars > Slab and cooldowns: "Priest trackers on the crest", "Druid trackers on the crest", "Weapon imbues on the crest", "Shock cooldown on the crest". Off restores today's crest pixel for pixel.
- **At most four things per class:** priest 4, druid 4 (the two medals count as two), shaman 2 added.

## 7. Frames

Frames has no crest. Following the shaman's rule (the same pieces stand in a row at the stance bar's place beside the tray, `Totems.lua:1`):

| Piece | Under Frames |
| --- | --- |
| Priest flames (Inner Fire) | Four flame pips in the player frame's class row, where crown pieces go |
| Priest medals, Pain gem | Two round medals and one gem in a row at the stance bar's place |
| Druid seed medals, gem | The same row, after the form buttons |
| Druid Clearcasting bloom | One leaf pip in the class row that lights while the buff is up |
| Shaman weapon stones | Two stones at the end of the Spirit Poles row, after the medals |
| Shaman shock cooldown | A third medal in that row (Earth Shock's icon with the sweep), since there is no emblem |

## 8. Open decisions for the owner

1. **Priest right medal:** Shadowfiend for everyone and Shadowform for shadow priests (as drawn), or Prayer of Mending for healers from level 40.
2. **Druid:** A's target medals or B's form medals; they cannot both use the shoulders.
3. **Shaman ankh** on the level plaque: build it as a third piece, or leave it out.
4. **Final art.** The flames, leaves and stones are recoloured shipped textures. The build would want its own flame, leaf and rune-stone art, as the storm orbs got theirs.

## 9. How it was made

Scratch only, in `%TEMP%\orca-ctx_68219ce33cfb\`: `q.py` (table queries), `mock.py` (compositor, sheets and GIFs, assembled with ffmpeg), the exported tables under `work/stage/`, and the four base renders. No file in the repository was changed; `git status` is clean.
