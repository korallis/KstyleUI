# Complete crests: Priest, Druid, Shaman, every spec

Task `task_1679b129dcc0`, dispatch `ctx_bb02f58f6738`, 2026-11-23. This is research only. No code, commit or PR was made, and nothing was posted.

The owner asked for every class to have "everything they need built around the crests, so they only have one place to look". This file lists what a good player of each spec watches, what the crest or the HUD already shows, what is missing, how each missing piece can be fed without Lua comparing a secret, and a seat plan per spec and form.

## The answer, per class

| Class | On the crest today or being built | Top additions |
| --- | --- | --- |
| Priest | Shadow Weaving candles (shipped). Inner Fire rim, Penance or Mind Blast on the left shoulder, Shadowfiend, Shadowform or Vampiric Embrace on the right, Shadow Word: Pain gem (being built) | The five-second rule on the level plaque. For healers: your Power Word: Shield, Renew or Prayer of Mending on the target in the top medal, and Prayer of Mending ready on the top gem from level 40. For Shadow: Devouring Plague on the target and Shadow Word: Death ready on the foot perches (both are trainer spells for every race on Forever), and Silence ready in a ring socket. Cooldown rim: Inner Focus, Power Infusion, Fear Ward, race and trinket buffs |
| Druid | Claws in Cat Form and talons in Bear Form (shipped). Two seed medals, Clearcasting leaves and a Swiftmend, Nature's Swiftness or Innervate gem (being built), per-form plan in `forms.md` | A bear tank kit: Growl ready, Feral Charge ready, Primal Bite and Bash ready, threat on the emblem, and Frenzied Regeneration, Enrage and Barkskin on the cooldown rim. In caster forms: the five-second rule, plus a third seed in the top medal (Faerie Fire on an enemy, Wild Growth on a friend). In Cat Form: Pounce's bleed in the Rake seed, and an energy tick after one in-game check. Fix the Moonkin "Hurricane ready" gem, because Hurricane has no cooldown on Forever |
| Shaman | Spirit Poles, storm orbs, and the Ghost Wolf and Call medals (shipped). Imbue stones, the shock sweep and the ankh (being built) | A seed on the left foot perch for your effect on the target: Flame Shock, or Stormstrike's debuff, on an enemy, and Riptide on a friend. The five-second rule on the level plaque. Keep the shock sweep on the emblem for Enhancement too, because Earth Shock is the shaman's interrupt. Move the ankh onto the right foot perch. Cooldown rim: Lightning Mastery, Nature's Swiftness, Rage of the Farseer, race and trinket buffs |

## 1. What is shown today and what is being built

**Shipped (staging `7b544324d`):**

| Piece | What it shows for these classes | Source |
| --- | --- | --- |
| Crown | A priest's Shadow Weaving candles (talent 15257), a cat's combo claws, a bear's Lacerate talons; the shaman's storm kind only in the Frames row | `Core/Widgets/ClassPip.lua:26, 28, 34, 35` |
| Storm orbs | Lightning Shield charges, orbiting at 54 units | `KstyleUI_ActionBars/SlabStorm.lua:17` |
| Spirit Poles | The shaman's four totem sockets with spires, plus the Ghost Wolf and Call of the Elements medals on the shoulders (right click on Call: Totemic Recall or Totemic Call) | `KstyleUI_ActionBars/Totems.lua:1, 19-21` |
| Cap ring | The hub's ring lights at full rage or energy | `KstyleUI_ActionBars/SlabEffects.lua:1` |
| Crest debuff fan | Your own debuffs on the target, sorted by time left (`HARMFUL|PLAYER`) | `KstyleUI_UnitFrames/Fan.lua:1, 9` |
| Player slab | Health, power bar and power value | `KstyleUI_UnitFrames/README.md:141` |
| Druid mana bar | Mana while in a form, seated above the crown in Cat Form | `KstyleUI_UnitFrames/Resource.lua:1, 257` |
| Threat | The target frame's threat glow, and a threat percent (off by default) | `KstyleUI_UnitFrames/Indicators.lua:474-482, 491-500` |
| Cooldown row | Blizzard's Cooldown Manager essential and utility cooldowns (whatever the player lists) above the crest, plus tracked buffs | `KstyleUI_Cooldowns/README.md:57, 70, 109-111` |
| Consumables bar | Healing and mana potions, Healthstones, bandages, food, drink, flasks and elixirs, with their cooldowns | `KstyleUI_ActionBars/ConsumableData.lua:4-15` |
| Reminder | Out of combat: a missing class buff, and a missing flask in a raid | `KstyleUI_Auras/Reminder.lua:1, 24` |

**Being built** (branch `korallis/healer-crest-trackers` at `774f89a7e`, read with `git show`):

| Piece | Seat | Source |
| --- | --- | --- |
| Priest Inner Fire: halo and four flames | Inner rim | `SlabVigil.lua:8, 119` |
| Penance (Mind Blast before 30, or with Shadowform) | Left shoulder | `SlabVigil.lua:9-10, 120` |
| Shadowform lit, else Shadowfiend ready | Right shoulder | `SlabVigil.lua:11, 121` |
| Shadow Word: Pain on the target | Top gem (0, 60) | `SlabVigil.lua:12, 122` |
| Druid seeds: Moonfire, Rake or Rejuvenation on the left; Insect Swarm, Rip or Regrowth on the right | Shoulders | `SlabGrove.lua:7-11, 59-63` |
| Clearcasting leaves | Inner rim | `SlabGrove.lua:12, 84` |
| Swiftmend, else Nature's Swiftness, else Innervate ready | Top gem | `SlabGrove.lua:85` |
| Shaman imbue stones (main hand and off hand) | Lower ring | `SlabStormforged.lua:8, 24, 167-168` |
| Shock cooldown sweep | Emblem | `SlabStormforged.lua:12, 78-83, 169` |
| Reincarnation ankh | (16, -63), beside the level plaque | `SlabStormforged.lua:13, 94, 170` |

The builder's per-form plan is `crest-trackers/healers/build/forms.md`, and its cooldown list is `cooldowns-research.md`. The shared parts are `SlabMedals` (seats at `SlabMedals.lua:15`; `CooldownRim` at `:14, 281`, commit `37bed8ad1`) and the one tracker lifecycle with per-form choices and cooldown-rim families (`SlabTrackers.lua:1, 70-110`, commit `e4333eb4a`). The ranged build added the hip and foot seats (`SlabRanged.lua:14, 23-26` at `88a9f07f3`).

## 2. Seats

Positions are given as radius and angle, in hub units (the ring is 150) and degrees counterclockwise from the right.

| Seat | Where | Size | Priest | Druid | Shaman |
| --- | --- | --- | --- | --- | --- |
| Crown | Above the ring's top arc | | Shadow Weaving candles (talent) | Claws (cat), talons (bear) | Spirit Pole spires |
| Top medal ("reliquary") | 96 @ 90 (`SlabMedals.lua:15`, `top`) | 28 | **Free for healers** (no crown) | **Free in caster and moonkin forms** | Taken (sockets) |
| Top gem | (0, 60), on the ring band (`SlabVigil.lua:122`) | 12 | Pain | Swiftmend gem | Taken (sockets) |
| Shoulders | 84 @ 148 and 32 (`SlabMedals.lua:15`) | 26 | Built | Built | Ghost Wolf and Call |
| Lower ring sockets | 62 @ 215 and 325 (`SlabMedals.lua:15`) | 12 to 18 | **Free** | **Free** | Imbue stones |
| Hips | 76 @ 218 and 322 (`SlabRanged.lua:23-24`) | 26 | Same arc as the lower sockets, so use one or the other | Same as priest | Blocked by the stones |
| Foot perches | 73 @ 247 and 293 (`SlabRanged.lua:25-26`) | 17 | **Free** | **Free** | Left free; right overlaps the ankh by about 2 units |
| Level plaque | Bottom centre, (0, -71), 18 to 20 (`Slab.lua:19, 487-489`) | | Unused | Unused | Unused |
| Inner rim | 54-unit orbit (`SlabStorm.lua:17`, `SlabVigil.lua:14`) | | Inner Fire | Clearcasting leaves | Storm orbs |
| Cooldown rim | 45-unit ring, plus up to three 14-unit icons 30 units below the centre (`SlabMedals.lua:14`) | | **Free** | **Free** | **Free** |
| Emblem | The crest art, swept by a cooldown (`SlabStormforged.lua:78-83`) | | **Free** | **Free** | Shock |

**What "no empty seats" means here:** a seat a class uses in any form holds something in every form of that class, so nothing vanishes and leaves a hole when you shift. Seats a class never uses stay bare by design. Druid bear seats that only bear needs hide in the other forms, as `forms.md` already does.

**Fit to check in the renders:**

- The cooldown rim's icon row (x ±23, y -30 to -44) touches the two lowest druid leaves (247.5 and 292.5 degrees at 54 units) by about 1 unit.
- The shaman's storm orbs pass through the icon row once per orbit.
- The Inner Fire studs at 225 and 315 degrees clear it by about 9 units.

## 3. Routes

R1 to R8 are the routes in `healers/REPORT.md` §2 (aura slot with application bar, aura slot with duration, spell cooldown duration object, form, weapon enchant, totem slot, item count, own casts), with the same proofs. This research adds five:

| Route | What it gives | Proof (paths under `wow-ui-source/Interface/AddOns` at `9dc84f0`) | Verdict |
| --- | --- | --- | --- |
| **R9 Own mana spend** (five-second rule) | On the player's own `UNIT_SPELLCAST_SUCCEEDED` (and `_CHANNEL_START`), `C_Spell.GetSpellPowerCost(spellID)` says whether the spell cost mana. If it did, Lua starts its own 5-second `Cooldown:SetCooldown(GetTime(), 5)`. | Event: `Blizzard_APIDocumentationGenerated/UnitDocumentation.lua:4845-4856`; secret only for a unit other than the player or pet, `SecretPredicatesDocumentation.lua:115-117`. Cost: `SpellDocumentation.lua:535-550`, no secret return flag; structure at `SpellSharedDocumentation.lua:46-58`. The rule exists on Forever: Meditation 14521, Reflection 17106 and Spirit Tap 15271 carry aura 134 (mana regeneration while casting) in `SpellEffect` | **Pass.** Every value is a spell ID, a static cost or Lua's own clock |
| **R10 Threat status** | `UnitThreatSituation("player", "target")` returns 0 to 3 | `UnitDocumentation.lua:3279-3292`; "queries where … one unit token is the player … are generally not secret", `SecretPredicatesDocumentation.lua:160-162`. KstyleUI already calls it, `Indicators.lua:474-482` | **Pass with a guard:** `issecretvalue` first, and keep the last state on a secret answer |
| **R11 Queued** | `C_Spell.IsCurrentSpell(spell)` is true while Maul waits for the next swing | `SpellDocumentation.lua:741-754`, no secret return flag; event `CURRENT_SPELL_CAST_CHANGED`, `SpellBookDocumentation.lua:841` | **Pass with a guard** (`forms.md` already plans it) |
| **R12 Equipped item** | A trinket's use spell from `C_Item.GetItemSpell(itemID)` gives that buff's aura IDs for an R1 slot. Its cooldown comes from `GetInventoryItemCooldown("player", 13 or 14)` | `ItemDocumentation.lua:970-985` (no secret return); Blizzard compares the trinket cooldown in plain Lua, `Blizzard_CooldownViewer/CooldownViewer.lua:1017-1019`. Item counts and item cooldowns: `ItemDocumentation.lua:434-468` | **Pass.** Rebuild the list out of combat on `PLAYER_EQUIPMENT_CHANGED` |
| **R13 Energy tick** | Two ways. If `C_Secrets.GetPowerTypeSecrecy(Energy)` says never secret, read the gains directly. Otherwise, take every `UNIT_POWER_FREQUENT` energy event that no own energy-costing cast explains in the same frame as a tick, then predict a tick every 2 s from it | `UNIT_POWER_FREQUENT`, `UnitDocumentation.lua:4532`; `GetPowerTypeSecrecy`, `SecretPredicateAPIDocumentation.lua:29-41`; `UnitPower` is secret unless the power type is flagged never-secret, `UnitDocumentation.lua:2732-2747` and `SecretPredicatesDocumentation.lua:150-152` | **Conditional.** The heuristic reads no value, so it is secret-safe, but it needs in-game check 1 before any build |

Rejected routes:

- `GetManaRegen` for the five-second rule: `SecretWhenUnitStatsRestricted`, `PlayerScriptDocumentation.lua:571-580`.
- Any Lua read of `UnitPower`, `UnitHealth` or an aura.
- Any filter of a harmful aura on a friendly unit: refused at `Blizzard_AuraContainer/Blizzard_AuraContainerUtil.lua:78-80`. Helpful auras on the player or a group member are always allowed (`:69-71`).

Sources for the IDs: client tables exported read-only from the installed Forever client (`%TEMP%\orca-ctx_a0fd9335904a\db2\`: `SkillLineAbility`, `SpellName`, `Spell`, `SpellCooldowns`, `SpellLevels`, `SpellAuraOptions`, `SpellEffect`, `Talent`, `ItemSparse`, `ItemEffect`, `ItemXItemEffect`). A spell is learnable when its `SkillLineAbility.AcquireMethod` is 0 (trainer or talent) or 2 (racial). A 3 is a rune and is rejected. "Talent tier N" means the 0-based `TierID`, so tier 2 is the third row (level 19 at the earliest), tier 4 is level 29, and tier 6 is the capstone (level 39). Cooldowns come from `SpellCooldowns` (the larger of `RecoveryTime` and `CategoryRecoveryTime`).

In the tables below, "Built" means the piece is on the builder's branch, and **New** means it is missing.

## 4. Priest

Layout switch: the shadow layout applies when Shadow Weaving (15257 and ranks) or Shadowform (15473) is known, the same `known` test the candles use (`ClassPip.lua:28`). Otherwise the priest gets the healer layout, used by Discipline and Holy.

### Every priest

| Item | Why it matters | IDs; learnable | Route | Verdict | Covered by, or seat |
| --- | --- | --- | --- | --- | --- |
| Mana | Every spell costs it | | | | Covered: player slab power bar and value |
| **Five-second rule** | Regeneration stops for 5 s after a mana spend. Healers time their casts and drinks to it | Every mana spell; level 1 | R9 | **Pass** | **New:** level plaque dims and refills over the 5 s |
| Inner Fire charges and time | Armour that a hit spends | 588, 7128, 602, 1006, 10951, 10952; level 12; 20 charges | R1 | Pass | Built: inner rim |
| Penance or Mind Blast ready | The main cooldown of a healer or a damage dealer | Penance 402174, 1240720, 1240721, 1316995 (levels 30 to 60, 12 s); Mind Blast 8092 … 10947 (level 10, 8 s) | R3 | Pass | Built: left shoulder |
| Shadowfiend ready | Mana return | 401977; trainer, 5 min (training level is an in-game check) | R3 | Pass | Built: right shoulder (healer layout) |
| Shadow Word: Pain on the target | Damage over time while levelling and in Shadow | 589, 594, 970, 992, 2767, 10892, 10893, 10894; level 4 | R1 (`target`, `HARMFUL|PLAYER`) | Pass | Built: top gem; also in the crest debuff fan |
| **Fear Ward** | A 3-minute ward, now for every race | 6346; level 20, `RaceMasks` -1 on Forever (Classic gave it to dwarves only) | R1 (on you); R3 ready | Pass | **New:** cooldown rim while it is on you. Ready time goes to the cooldown row |
| **Inner Focus** | Next spell free with +25% critical chance | 14751; Discipline tier 2 talent; 3 min; one charge | R1; R3 | Pass | **New:** cooldown rim while up. Ready time goes to the cooldown row |
| **Power Infusion** | A 3-minute burst for you or an ally | 10060; Discipline tier 6 talent | R1 (also lights when another priest gives it to you) | Pass | **New:** cooldown rim |
| Fade ready | Drops threat | 586, 9578, 9579, 9592, 10941, 10942; level 8; 30 s | R3 | Pass | Cooldown row |
| Psychic Scream ready | Emergency fear | 8122, 8124, 10888, 10890; level 14; 30 s | R3 | Pass | Cooldown row |
| Race spells with a buff on you | | Feedback 13896, 19271, 19273-19275 (human); Elune's Grace 2651 (night elf); Dark Sacrifice 1277324-1277328 (undead); Contingency Plan 1277462, 1277634, 1277638-1277640 (gnome, self) | R1; R3 | Pass | **New:** cooldown rim families. Ready time goes to the cooldown row |
| Race spells with no buff | | Divine Grace 1277370-1277378 (human; heals a friend and removes Weakened Soul; 10 min), Desperate Prayer 13908, 19236 … 19243 (dwarf only, `RaceMasks` 4; 10 min), Chastise 1277331-1277335 (dwarf), Confounding Flash 1277455 (gnome), Starshards (night elf), Hex of Weakness (troll) | R3 | Pass | Cooldown row |
| Shadowguard, Touch of Weakness | Maintenance buffs (troll, undead) | 18137, 19308-19312; 2652, 19261-19266 | R1 | Pass | Not picked: the buff row and the Reminder cover them |

### Discipline

| Item | Why it matters | IDs; learnable | Route | Verdict | Covered by, or seat |
| --- | --- | --- | --- | --- | --- |
| **Power Word: Shield on your target** | The healer's first question: is my shield still on the person I am healing? | 17, 592, 600, 3747, 6065, 6066, 10898-10901; level 6. The spell has a 4 s cooldown on Forever (`CategoryRecoveryTime` 4000) | R2 (`target`, `HELPFUL|PLAYER`; always allowed on a friendly player) | Pass | **New:** top medal, gold ring (feed 1 of 3) |
| Weakened Soul on your target | When you may shield again | 6788 | Harmful on a friendly unit: the filter is refused, and a Lua read is secret | **Rejected** | |
| Penance | | | | | Built: left shoulder |
| Inner Focus, Power Infusion | | | | | **New:** cooldown rim (above) |
| Focused Casting (from Martyrdom) | Pushback immunity after a critical melee hit | 27828; Discipline tier 1 | R1 | Pass | Not picked: a passive outcome |
| Divine Spirit | Out-of-combat buff | 14752, 14818, 14819 | | | Buff panel and Reminder |

### Holy

| Item | Why it matters | IDs; learnable | Route | Verdict | Covered by, or seat |
| --- | --- | --- | --- | --- | --- |
| **Renew on your target** | Your heal over time | 139, 6074-6078, 10927-10929, 25315; level 8 | R2 (`target`, `HELPFUL|PLAYER`) | Pass | **New:** top medal, green ring (feed 2) |
| **Prayer of Mending on your target** | Where your Mending charge sits | Aura 401877, 1240848, 1240849 (5 stacks); from 401859, 1240826, 1240827 | R2 | Pass | **New:** top medal, white ring (feed 3) |
| **Prayer of Mending ready** | The Holy priest's 10-second cooldown | 401859 (level 40), 1240826 (50), 1240827 (60); trainer on Forever; 10 s | R3 | Pass | **New:** top gem from level 40. Shadow Word: Pain stays there before 40, and stays in the fan after |
| Lightwell ready | | 724; Holy tier 6 talent; 10 min | R3 | Pass | Cooldown row |
| Holy Fire on the target | Damage when levelling | 14914, 15261-15267 | R1 | Pass | Covered: crest debuff fan |
| Inspiration on the target | Armour after a critical heal | 14893 | R1 | Pass | Not picked: an outcome that shows on the tank's frame |
| Litany of Light | Mana back when you alternate heals | 1317006 (passive) | No aura known | | In-game check 7 |
| Spirit of Redemption, Holy Nova | | | | | Nothing to track (passive, or no cooldown) |

### Shadow

| Item | Why it matters | IDs; learnable | Route | Verdict | Covered by, or seat |
| --- | --- | --- | --- | --- | --- |
| Shadow Weaving stacks | | 15258 | | | Covered: candles crown |
| Shadowform | | 15473; Shadow tier 6 | R4 | Pass | Built: right shoulder, steel while not worn (`forms.md`) |
| Vampiric Embrace on the target | Group healing | 15286; Shadow tier 4; 30 s cooldown in this client | R1 (`HARMFUL|PLAYER`) | Pass | Right shoulder in Shadowform (`forms.md`) |
| **Devouring Plague on the target, and ready** | The strongest damage over time, on a 24 s cooldown | 2944, 19276-19280; level 20; **every race on Forever** (`RaceMasks` -1, `ClassMask` 16) | R1 aura, with the medal's ring; R3 behind it | Pass | **New:** left foot perch |
| **Shadow Word: Death ready** | Burst and finisher | 1309595 (level 32), 1309633 (40), 1309635 (48), 1309636 (56); trainer, Shadow line; 18 s | R3 | Pass | **New:** right foot perch |
| **Silence ready** | The priest's only interrupt | 15487; Shadow tier 4; 45 s | R3 | Pass | **New:** lower-left socket, which refills and flares when ready |
| Mind Flay | A channel | | | | Covered: cast bar |
| Spirit Tap, Blackout | Levelling buff; a stun proc on the target | 15271; 15269 | R1 | Pass | Not picked |

### Priest seat plan

| Seat | Healer layout (Discipline, Holy) | Shadow, out of form | Shadowform |
| --- | --- | --- | --- |
| Crown | none | Shadow Weaving candles | same |
| Top medal | **Your shield and heals on the target:** Power Word: Shield (gold), Renew (green), Prayer of Mending (white). Steel when none is up | none (the crown is there) | none |
| Top gem | Pain before level 40, then **Prayer of Mending ready** | Pain | Pain |
| Left shoulder | Penance (Mind Blast before 30) | Mind Blast | Mind Blast |
| Right shoulder | Shadowfiend ready | Shadowform, steel | Vampiric Embrace on the target, else Shadowfiend |
| Inner rim | Inner Fire flames and halo | same | same |
| Level plaque | **Five-second rule** | same | same |
| Cooldown rim | **Inner Focus, Power Infusion, Fear Ward, race buffs, trinket buffs** | same | same |
| Left foot perch | none | **Devouring Plague on the target** | same |
| Right foot perch | none | **Shadow Word: Death ready** | same |
| Lower-left socket | none | **Silence ready** (talent) | same |
| Lower-right socket | **Main-hand oil** (§7) | same | same |

**Priority if the crest must shed pieces:**

1. Must show:
   - Healer: Inner Fire, Penance, the target medal, the five-second rule.
   - Shadow: the candles, Pain, Mind Blast, Shadowform, Devouring Plague.
2. Can share: the top gem changes from Pain to Prayer of Mending by level, and the cooldown rim burns only the newest buff.
3. Goes to the cooldown row first: Shadowfiend, Silence, Shadow Word: Death.
4. Goes to the crest debuff fan: Vampiric Embrace and Devouring Plague timers.

**Level bands:**

| Level | What arrives |
| --- | --- |
| 1 | Plaque |
| 4 | Pain gem |
| 6 | Shield in the top medal |
| 8 | Renew |
| 10 | Mind Blast |
| 12 | Inner Fire |
| 19 | Inner Focus |
| 20 | Fear Ward rim; Devouring Plague in the shadow layout |
| 24 | Candles (with the talent, which also switches to the shadow layout) |
| 29 | Silence, Vampiric Embrace |
| 30 | Penance |
| 32 | Shadow Word: Death |
| 39 | Shadowform, Power Infusion |
| 40 | Prayer of Mending gem and feed |

## 5. Druid

The form switch follows `forms.md` (`GetShapeshiftFormID`: cat 1, travel 3, aquatic 4, bear 8, Moonkin 31 and 35).

### Every druid

| Item | Why it matters | IDs; learnable | Route | Verdict | Covered by, or seat |
| --- | --- | --- | --- | --- | --- |
| Mana, and mana in a form | | | | | Covered: slab, and the druid mana bar |
| **Five-second rule** (caster and Moonkin forms) | | Reflection 17106 (Restoration tier 2) carries aura 134 | R9 | Pass | **New:** level plaque |
| Clearcasting | A free spell | 16870 (+457342, 467735); Omen of Clarity 16864 is **Balance** tier 2 on Forever (tab 283) | R1 | Pass | Built: inner rim leaves |
| Innervate | Mana cooldown | 29166; level 40; 6 min | R3 ready; R1 when self-cast | Pass | Built: top gem fallback. **New:** cooldown rim while it is on you |
| **Barkskin** | Defensive | 22812; level 44; 60 s | R1; R3 | Pass | **New:** cooldown rim. Ready time goes to the cooldown row |
| **Dash** | | 1850, 9821; levels 26 and 46; 5 min | R1 | Pass | **New:** cooldown rim |
| **Nature's Grasp** | | 16689, 16810-16813, 17329; Balance tier 0; 60 s | R1 | Pass | **New:** cooldown rim |
| Rebirth, Tranquility | Battle resurrection; raid heal | 20484, 20739, 20742, 20747, 20748 (30 min); 740, 8918, 9862, 9863 (5 min) | R3 | Pass | Cooldown row |
| Faerie Fire on the target | Armour debuff; anyone's counts | 770, 778, 9749, 9907; level 18 | R1 (`HARMFUL`) | Pass | Cat top gem and bear right shoulder (`forms.md`). **New:** caster top medal |
| Race | | Night elf: Elune's Light 1259799 (3 min, buff), Shadowmeld 20580; Tauren: War Stomp 20549 (90 s, no buff) | R1; R3 | Pass | **New:** cooldown rim (Elune's Light). Cooldown row for the rest |

### Balance (caster and Moonkin forms)

| Item | Why it matters | IDs; learnable | Route | Verdict | Covered by, or seat |
| --- | --- | --- | --- | --- | --- |
| Moonfire, Insect Swarm on the target | Your damage over time | Moonfire 8921 …; Insect Swarm 5570 … (a **Restoration** tier 2 talent on Forever, tab 282) | R2 | Pass | Built: seeds |
| **Your Faerie Fire on the target** | Uptime | as above | R2 (`HARMFUL|PLAYER`) | Pass | **New:** top medal, enemy feed |
| Nature's Grace | Next spell casts 0.5 s faster after a critical hit | 16886; Balance tier 4 | R1 | Pass | Not picked: tracked buff row (optional: a second cell on the leaves' rim) |
| Hurricane ready | | 16914, 17401, 17402 | **No cooldown on Forever:** `SpellCooldowns` rows 55168, 55180 and 55179 have 0 and 0 | **Rejected** | Replace `forms.md`'s Moonkin top gem with the caster chain (Nature's Swiftness, else Innervate) |
| Moonkin Form | | 24858; Balance tier 6 | R4 | Pass | Form switch |
| Starfire stun, Entangling Roots, Hibernate | | 16922; 339 …; 2637 … | R1 | Pass | Covered: crest debuff fan |

### Feral, Cat Form

| Item | Why it matters | IDs; learnable | Route | Verdict | Covered by, or seat |
| --- | --- | --- | --- | --- | --- |
| Combo points | | | | | Covered: claws crown |
| Energy, and energy at maximum | | | | | Covered: slab power bar, cap ring |
| **Energy tick** | When the next 20 energy arrives decides whether to wait or press | 2-second Classic tick | R13 | **Conditional** (in-game check 1) | **New:** level plaque in Cat Form, refilling every 2 s |
| Rake, Rip on the target | | | | | Built: seeds |
| **Pounce's bleed** | Opener uptime | 9007, 9824, 9826 (from Pounce 9005, 9823, 9827; level 36) | R2 | Pass | **New:** add to the left seed's cat feed, beside Rake |
| Faerie Fire | | | | | Top gem (`forms.md`) |
| Tiger's Fury | | 5217, 417045: `AcquireMethod` 3 | | **Rejected** (rune) | |
| Prowl | | 5215, 6783, 9913 (a stealth aura, not a form) | R1 | Pass | Not picked: obvious on screen |
| Dash, Barkskin | | | | | **New:** cooldown rim |
| Poised, Leader of the Pack, Blood Frenzy | | 1328829 (level 32), 24932, 16959 | | | Not picked: passives, or a tiny opener buff |

### Feral, Bear Form (tank)

| Item | Why it matters | IDs; learnable | Route | Verdict | Covered by, or seat |
| --- | --- | --- | --- | --- | --- |
| Rage, and rage at maximum | | | | | Covered: slab, cap ring |
| Lacerate stacks | | | | | Covered: talons crown (`ClassPip.lua:34`) |
| Demoralizing Roar uptime | Mitigation | 99, 1735, 9490, 9747, 9898; level 10; anyone's counts | R1 (`HARMFUL`) | Pass | Left shoulder (`forms.md`) |
| Faerie Fire uptime | | | | | Right shoulder (`forms.md`) |
| Maul queued | Rage spend on the next swing | 6807, 6808, 6809, 8972, 9745, 9880, 9881; level 10 | R11 | Pass, guarded | Top gem (`forms.md`) |
| **Growl ready** | The taunt | 6795; level 10; 8 s (`CategoryRecoveryTime` 8000) | R3 | Pass | **New:** left foot perch |
| **Feral Charge ready** | The bear's interrupt (effect 19675 interrupts and roots) | 1238122; trainer, level 20; 15 s (the talent 16979 is `AcquireMethod` 3) | R3 | Pass | **New:** right foot perch |
| **Bash ready** | Stun that also interrupts | 5211, 6798, 8983; level 14; 60 s | R3 | Pass | **New:** lower-right socket in Bear Form (in caster forms this socket holds the oil) |
| **Primal Bite ready** | Forever's threat bite ("a high amount of threat") | 407995 (level 40), 1238069 (50), 1238070 (60); trainer; 6 s | R3 | Pass | **New:** lower-left socket in Bear Form |
| **Frenzied Regeneration** | Self-heal | 22842; level 36; 3 min | R1; R3 | Pass | **New:** cooldown rim |
| **Enrage** | Rage, at an armour cost | 5229; level 12; 60 s | R1 | Pass | **New:** cooldown rim |
| **Threat on your target** | Am I holding it? | | R10 | Pass, guarded | **New:** emblem in Bear Form; dims red while you are not tanking your target (status below 3) |
| Challenging Roar | Area taunt | 5209; level 28; 10 min | R3 | Pass | Cooldown row |
| Swipe, Thick Hide, Leader of the Pack | | | | | Nothing to track |

### Restoration

| Item | Why it matters | IDs; learnable | Route | Verdict | Covered by, or seat |
| --- | --- | --- | --- | --- | --- |
| Rejuvenation, Regrowth on the target | | | | | Built: seeds |
| **Wild Growth on the target** | Your third heal over time | 408120 (level 40), 1238214 (50), 1238215 (60); **trainer on Forever**; 6 s | R2 (`HELPFUL|PLAYER`) | Pass | **New:** top medal, friend feed |
| Swiftmend, Nature's Swiftness ready | | 18562 (Restoration tier 6; 15 s); 17116 (tier 4; 3 min) | R3 | Pass | Built: top gem. **New:** Nature's Swiftness on the cooldown rim while up |
| Five-second rule | | | | | **New:** plaque |
| Lifebloom, Nourish | | 408124, 408247: `AcquireMethod` 3 | | **Rejected** | |
| Tree of Life | | Not in the client | | **Rejected** | |

### Druid seat plan

| Seat | Caster, travel, aquatic | Moonkin | Cat | Bear |
| --- | --- | --- | --- | --- |
| Crown | none | none | Claws | Talons |
| Top medal | **Third seed:** your Faerie Fire on an enemy, Wild Growth on a friend (40+) | **Your Faerie Fire** | none (the crown is there) | none |
| Top gem | Swiftmend, else Nature's Swiftness, else Innervate | **Nature's Swiftness, else Innervate** (not Hurricane) | Faerie Fire on the target | Maul queued |
| Left shoulder | Moonfire, or Rejuvenation | Moonfire | Rake, **plus Pounce's bleed** | Demoralizing Roar |
| Right shoulder | Insect Swarm, or Regrowth | Insect Swarm | Rip | Faerie Fire |
| Inner rim | Clearcasting | same | same | same |
| Level plaque | **Five-second rule** | same | **Energy tick** (after check 1) | none |
| Emblem | none | none | none | **Threat** |
| Cooldown rim | **Innervate, Nature's Swiftness, Barkskin, Dash, Nature's Grasp, race, trinket** | same | **Dash, Barkskin, race, trinket** | **Frenzied Regeneration, Enrage, Barkskin, Dash, race, trinket** |
| Left foot perch | none | none | none | **Growl ready** |
| Right foot perch | none | none | none | **Feral Charge ready** |
| Lower-left socket | none | none | none | **Primal Bite ready** (40+) |
| Lower-right socket | **Main-hand oil** (§7) | same | none | **Bash ready** |

**Priority if the crest must shed pieces:**

1. Must show:
   - Bear: talons, Growl, Feral Charge, threat, Demoralizing Roar.
   - Cat: claws, Rake, Rip.
   - Healer: seeds, Swiftmend, the five-second rule.
2. Can share: the top gem and the lower-right socket change by form.
3. Goes to the cooldown row first: Bash, Primal Bite.
4. The energy tick waits for its check.

**Level bands:**

| Level | What arrives |
| --- | --- |
| 4 | Left seed |
| 10 | Bear: Demoralizing Roar, Growl perch, Maul gem |
| 12 | Regrowth seed, Enrage rim |
| 14 | Bash socket |
| 18 | Faerie Fire |
| 19 | Clearcasting, Insect Swarm |
| 20 | Cat claws, Rip; Feral Charge perch |
| 24 | Rake |
| 25 | Talons |
| 26 | Dash |
| 29 | Nature's Swiftness, Nature's Grace |
| 36 | Frenzied Regeneration, Pounce |
| 39 | Swiftmend, Moonkin |
| 40 | Innervate, Wild Growth, Primal Bite |
| 44 | Barkskin |

## 6. Shaman

Nothing here needs a spec switch. The one new seed is driven by what is on the target, and the cooldown-rim families are gated by known spells.

### Every shaman

| Item | Why it matters | IDs; learnable | Route | Verdict | Covered by, or seat |
| --- | --- | --- | --- | --- | --- |
| Totems and their time | | | | | Covered: Spirit Poles |
| Lightning Shield charges | | | | | Covered: storm orbs |
| Ghost Wolf, Call of the Elements, Totemic Recall or Totemic Call | | 2645; 66842; 36936, 437009 (level 22, 30 s) | | | Covered: shoulder medals |
| Weapon imbues | | | | | Built: stones |
| **Shock ready, which is the interrupt** | Earth Shock interrupts (effect 68); every shock shares one 6 s category | 8042, 8044, 8045, 8046, 10412, 10413, 10414 | R3 | Pass | Built: emblem. Keep it for **every** spec (§8) |
| Reincarnation and an Ankh | | 20608; item 17030 | | | Built: ankh. **Move** it onto the right foot perch (§2) |
| **Five-second rule** | Elemental and Restoration live on mana | | R9 | Pass | **New:** level plaque |
| Grounding Totem ready | Spell reflect | 8177; level 30; 15 s | R3 | Pass | The air socket shows the totem's life. Ready time goes to the cooldown row |
| Purge | | 370, 8012 | | | No cooldown |
| Race | | Orc: Blood Fury 20572 (2 min), Shatter Curse 1299026 (3 min); Troll: Berserking 20554 (3 min), Rapid Regeneration 1260270 (3 min); Tauren: War Stomp | R1; R3 | Pass | **New:** cooldown rim. Cooldown row for the rest |

### Elemental

| Item | Why it matters | IDs; learnable | Route | Verdict | Covered by, or seat |
| --- | --- | --- | --- | --- | --- |
| **Flame Shock on the target** | Damage over time, and the shock choice | 8050, 8052, 8053, 10447, 10448, 29228; level 10 | R2 (`HARMFUL|PLAYER`) | Pass | **New:** left foot perch, enemy feed |
| **Lightning Mastery** | Forever's name for Elemental Mastery: the next spell is a certain critical hit, 3 min | 16166; Elemental tier 6 | R1; R3 | Pass | **New:** cooldown rim |
| Clearcasting (Elemental Focus) | Next spell cheaper | 16246 (one charge); Elemental tier 2 | R1 | Pass | Not picked: tracked buff row (optional: a tint on the storm halo) |
| Chain Lightning, Fire Nova ready | | 421, 930, 2860, 10605 (level 32, 6 s); Fire Nova (a spell on Forever) 408341-408345 (level 12, 10 s) | R3 | Pass | Cooldown row |

### Enhancement

| Item | Why it matters | IDs; learnable | Route | Verdict | Covered by, or seat |
| --- | --- | --- | --- | --- | --- |
| **Stormstrike's debuff on the target** | Nature damage +20%: shock now | 17364 (`HARMFUL|PLAYER` on the target) | R2 | Pass | **New:** left foot perch, drawn over Flame Shock |
| Stormstrike ready | | 17364; Enhancement tier 6; 8 s | R3 | Pass | Cooldown row. `forms.md` moves it onto the emblem, which loses the interrupt (§8) |
| Flurry | | 16257 (three charges); Enhancement tier 3 | R1 | Pass | Not picked: tracked buff row |
| **Rage of the Farseer** | Attack speed, 3 min | 425336 (`AcquireMethod` 0, `SpellLevel` 1) | R1; R3 | Pass; learnable is in-game check 5 | **New:** cooldown rim |
| Windfury Totem's weapon buff | Replaces the main-hand imbue under Classic rules | | R5 | Pass | Built stone; its colour needs in-game check 8 |
| Shamanistic Rage, Bloodlust, Heroism; Maelstrom Weapon, Lava Lash | | Not in the client; runes | | **Rejected** | |

### Restoration

| Item | Why it matters | IDs; learnable | Route | Verdict | Covered by, or seat |
| --- | --- | --- | --- | --- | --- |
| **Riptide on the target** | Heal over time, and +Chain Heal on that target | 408521 (level 40), 1239242 (50), 1239243 (60); **trainer on Forever**; 12 s | R2 (`HELPFUL|PLAYER`) | Pass | **New:** left foot perch, friend feed |
| **Nature's Swiftness** | Emergency instant heal | 16188; Restoration tier 4; 3 min | R1; R3 | Pass | **New:** cooldown rim. Ready time goes to the cooldown row |
| Mana Tide Totem | | 16190, 17354, 17359, 1325256 | R6 | Pass | Covered: water socket. Ready time goes to the cooldown row |
| Healing Way | | 29206 is a passive modifier on Forever (aura 108; no stacking buff) | | Nothing to track | |
| Ancestral Fortitude on the target | | 16177 | R1 | Pass | Not picked |
| Water Shield, Earth Shield | | 408510, 408514: `AcquireMethod` 3 | | **Rejected** | |

### Shaman seat plan (the same in every spec)

| Seat | Every shaman |
| --- | --- |
| Crown and top arc | Spirit Poles sockets and spires (shipped) |
| Shoulders | Ghost Wolf, Call (shipped) |
| Inner rim | Storm orbs (shipped) |
| Lower ring | Imbue stones (built) |
| Emblem | Shock sweep: readiness and interrupt (built) |
| Level plaque | **Five-second rule** |
| Left foot perch | **Your effect on the target:** Flame Shock on an enemy (Stormstrike's debuff drawn over it once Stormstrike is known), Riptide on a friend (40+) |
| Right foot perch | **Ankh** (moved from (16, -63); same 17-unit perch as the hunter's) |
| Cooldown rim | **Lightning Mastery, Nature's Swiftness, Rage of the Farseer, race, trinket** |

**Priority if the crest must shed pieces:** totems, shield and shock must show. The foot seed stays: it is the only target piece a shaman has. The ankh can go to the level plaque's tint first. Clearcasting and Flurry stay on the tracked buff row.

**Level bands:**

| Level | What arrives |
| --- | --- |
| 1 | Main-hand stone, plaque |
| 4 | Shock sweep |
| 8 | Orbs |
| 10 | Flame Shock seed |
| 20 | Medals |
| 30 | Ankh |
| 39 | Lightning Mastery, Mana Tide |
| 40 | Riptide feed, Stormstrike |

## 7. Shared by every class here

| Item | Why it matters | IDs | Route | Verdict | Covered by, or seat |
| --- | --- | --- | --- | --- | --- |
| **Trinket buffs** | On-use trinkets are major cooldowns | Slots 13 and 14; the buff comes from `C_Item.GetItemSpell` | R12 into R1 | Pass | **New:** cooldown-rim family, rebuilt out of combat on an equipment change |
| Trinket ready | | `GetInventoryItemCooldown` | R12 | Pass | Cooldown row (the Cooldown Manager handles equipped items, `CooldownViewer.lua:1014-1030`) |
| **Race buffs** | | See §4 to §6. Also Stoneform 20594 (dwarf), Will to Survive 1259718 and Perception 20600 (human), Eureka! 1259823 (gnome priest) | R1 | Pass | **New:** cooldown rim |
| Potions, Healthstone | | Mana potion category 4 (2 min); Healthstone category 1153 (2 min) | R7 | Pass | Covered: consumables bar |
| **Dark Rune, Demonic Rune** | The healer's second mana button | 20520, 12662 (they share Healthstone's category 1153) | R7 | Pass | **Missing from the consumables bar** (`ConsumableData.lua:4-15` has no rune kind). Add them there, not on the crest |
| Flask, elixir, food buff | | | | | Covered outside the crest: the Reminder (flask) and the buff panel |
| **Main-hand oil** (priest, druid) | Healing or spell power | Items 20744-20750 apply spells 25117-25123 | R5 (`MainHand`) | Pass, never secret | **New:** lower-right socket, shown only while an oil is on the weapon or one is in the bags (`C_Item.GetItemCount`). Otherwise a levelling player would see a socket nagging for a missing oil |
| Weakened Soul, Recently Bandaged | | 6788 | | **Rejected**: a harmful aura on a friendly unit | |

## 8. Corrections to the current designs

1. **Hurricane has no cooldown on Forever.** `SpellCooldowns` has 0 and 0 for 16914, 17401 and 17402. `forms.md`'s Moonkin top gem "Hurricane ready, else Innervate" would never sweep. Use Nature's Swiftness, else Innervate.
2. **Shadow Word: Death is a trainer spell on Forever.** 1309595, 1309633, 1309635 and 1309636 are on the Shadow line with `AcquireMethod` 0, from level 32, with an 18 s cooldown. `healers/REPORT.md:88` rejected Shadow Word: Death as a rune, but that is only the rune ID 401955.
3. **Devouring Plague and Fear Ward belong to every race on Forever** (`SkillLineAbility.RaceMasks` -1). They are class pieces, not race pieces as `healers/REPORT.md:89` implies. Desperate Prayer is dwarf only (mask 4), and Divine Grace is human (mask 1).
4. **Keep the shock sweep on the emblem for Enhancement.** `forms.md` swaps it for Stormstrike, but Earth Shock (effect 68) is the shaman's only interrupt, and all shocks share the 6 s category. Stormstrike's readiness belongs on the cooldown row. Its debuff is better on the foot seed, where it says "shock now".
5. **The ankh at (16, -63) overlaps the right foot perch** (centres 13 units apart, against a 17-unit perch and a 12-unit ankh). Moving it onto the perch keeps the foot seats symmetrical with the hunter's.
6. **Labels:** Insect Swarm is a Restoration talent (tab 282, tier 2) and Omen of Clarity is a Balance talent (tab 283, tier 2) on Forever. Power Word: Shield has a 4 s cooldown. Healing Way is passive. Vampiric Embrace has a 30 s cooldown in this client.

## 9. Rejected, all three classes

- **Harmful on a friendly unit:** Weakened Soul 6788 and Recently Bandaged (`Blizzard_AuraContainerUtil.lua:78-80`).
- **Lua comparison of a secret:** mana or energy values (`UnitPower`), `GetManaRegen`, the target's health percent (for a Shadow Word: Death execute window), and aura reads.
- **Runes (`AcquireMethod` 3):**
  - Priest: Pain Suppression 402004, Dispersion 425294, Power Word: Barrier 425207, Vampiric Touch 402668, the Shadow Word: Death rune 401955, and the Penance rune rows 402284, 402289, 1240723 to 1240730.
  - Druid: Tiger's Fury 5217 and 417045, Berserk 417141, Survival Instincts 408024, Lifebloom 408124, Nourish 408247, Starsurge 417157, Sunfire 414684.
  - Shaman: Water Shield 408510, Earth Shield 408514, Lava Lash 408507.
- **Absent from the client:** Faerie Fire (Feral) 16857 (no name row), Tree of Life, Mangle, Holy Concentration, Shamanistic Rage, Bloodlust, Heroism.
- **No feed:** the Shadowfiend's remaining time (it is a guardian, with no pet unit and no proven totem slot). Its cooldown medal already starts on the summon.

## 10. In-game checks before a build

| # | Check | If it fails |
| --- | --- | --- |
| 1 | `/dump C_Secrets.GetPowerTypeSecrecy(Enum.PowerType.Energy)` in Cat Form, in and out of combat. Then, in combat, check that the predicted 2-second sweep lines up with the energy gains | If energy is never secret, read gains directly. If the heuristic drifts, drop the energy tick |
| 2 | `/dump C_Spell.GetSpellPowerCost(2061)` in combat (Flash Heal), then Mind Flay and Tranquility | Mana cost and type should be readable. Channels may spend at the start, so listen to `UNIT_SPELLCAST_CHANNEL_START` too |
| 3 | `/dump UnitThreatSituation("player", "target")` in Bear Form on a dungeon mob and on a boss | If it is secret on bosses, the emblem keeps its last state there |
| 4 | `/dump C_Spell.IsCurrentSpell(9881)` with Maul queued, in combat | Expect true until the swing |
| 5 | Whether a trainer teaches Rage of the Farseer 425336 | Otherwise drop it from the rim |
| 6 | Barkskin in Bear Form | If Forever limits it to caster form, it leaves the bear's rim list |
| 7 | Whether Litany of Light 1317006 shows an aura | If it does, it could tint the healer's top medal |
| 8 | `/dump C_PaperDollInfo.GetTemporaryEnchantmentInfo(16).enchantID` under Windfury Totem, and with each oil | Gives the stone's air colour and an oil colour. Presence works without this |
| 9 | Trainer levels for Shadowfiend, and for Devouring Plague and Fear Ward on a non-undead, non-dwarf priest | |
| 10 | Hurricane in game: no cooldown sweep | Confirms correction 1 |
| 11 | Feral Charge 1238122 interrupts a cast | It should, through 19675 |
| 12 | Power Word: Shield's 4-second cooldown | Confirms the label in correction 6 |

The checks already listed in `healers/REPORT.md` §3 to §5 still stand: Inner Fire charges as applications, which slot wins the shared target seeds, and imbue values in combat.

## 11. What to add to the builders

Each new piece gets its own switch, on by default, beside the existing crest switches. Calm crest at rest calms them. Under Frames, each one joins the tracker row above the stance bar as a medal, and the plaque and emblem pieces become medals there, as the shock does (`SlabStormforged.lua:169`).

**Shared helper (small named extensions):**

- `Medals.Emblem`, lifted from Stormforged's `Shock` (`SlabStormforged.lua:78-92`): a sweep over a named hub region, either the emblem (`hub.crest`) or the level plaque (`hub.plaque`, `Slab.lua:487-490`).
- A `"timer"` feed that Lua starts itself (five-second rule, energy tick), and a `"threat"` tint (R10).
- A `"queued"` feed (R11), already planned in `forms.md`.
- Trinket families for `CooldownRim` (R12).
- Optional: `focus` in the feed's refresh map, for a healer's focus seed.

**Priest:**

- Five-second rule on the plaque.
- Healer top medal: Power Word: Shield, Renew and Prayer of Mending on the target.
- Top gem: Prayer of Mending ready from 40.
- Shadow: Devouring Plague on the target (left foot) and Shadow Word: Death ready (right foot).
- Shadow: Silence ready (lower-left socket).
- Main-hand oil socket.
- Cooldown rim: Inner Focus, Power Infusion, Fear Ward, race (Feedback, Elune's Grace, Dark Sacrifice, Contingency Plan, Berserking, Stoneform, Will to Survive, Elune's Light, Eureka!) and trinkets.

**Druid:**

- Bear: Growl (left foot), Feral Charge (right foot), Primal Bite and Bash sockets, threat on the emblem.
- Caster: five-second rule on the plaque, and the top-medal third seed (Faerie Fire, Wild Growth).
- Cat: Pounce's bleed in the Rake seed, and the energy tick after check 1.
- Moonkin: replace the Hurricane gem.
- Main-hand oil socket.
- Cooldown rim: Innervate, Nature's Swiftness, Barkskin, Dash, Nature's Grasp, Frenzied Regeneration, Enrage, Elune's Light and trinkets.

**Shaman:**

- Left foot seed: Flame Shock, or Stormstrike's debuff, on an enemy, and Riptide on a friend.
- Five-second rule on the plaque.
- Keep the shock sweep for Enhancement.
- Ankh onto the right foot perch.
- Cooldown rim: Lightning Mastery, Nature's Swiftness, Rage of the Farseer, Blood Fury, Shatter Curse, Berserking, Rapid Regeneration and trinkets.

**Consumables bar (not the crest):** a Dark Rune and Demonic Rune kind.

## How it was made

- **Client tables:** queried read-only with three scratch scripts in `%TEMP%\orca-ctx_bb02f58f6738\`: `q.py` (spells by name: learnability, level, cooldown, charges, effects), `tal.py` (talent trees by tab) and `col.py` (collapses ranks).
- **UI source:** grepped at `9dc84f0`.
- **Builder branches:** `korallis/healer-crest-trackers`, `korallis/melee-crest-trackers` (`37bed8ad1`) and `korallis/ranged-crest-trackers` (`88a9f07f3`), read with `git show`.
- **Not done:** no render, no checkout, and no file in the repository changed.
