# Everything each melee spec needs, built around the crest: Warrior, Paladin, Rogue

Task `task_f875ff84d5c1`, dispatch `ctx_b42a6fb24eb8`, 2026-11-23. Research only: no code, no PR, nothing posted.

Read: staging `7b544324d` (shipped crest), and the three builders' live worktrees: melee `sculpin-2` (`37bed8ad1` plus uncommitted work: `CooldownRim`, per-stance `choices`, `Register`), ranged `limpet-2` (`88a9f07f3`, hips and feet), healers `kelpfish-2` (`774f89a7e`). Also the three design reports in `crest-trackers/{melee,ranged,healers}/REPORT.md` and `specs/QUEUE.md:643-646` (owner's later asks).

Client data: `SkillLineAbility`, `SpellLevels`, `SpellCooldowns`, `Talent`, `SpellAuraOptions`, `SpellCategories`, `SpellEffect`, `SpellMisc`, `SpellName` from the `wowf` 1.60.1.71037 export (copied from `%TEMP%\orca-ctx_6b231e178299\db2`), and `Spell`, `SpellShapeshiftForm`, `ItemSparse`, `ItemEffect`, `ItemXItemEffect` from `~/.cache/kstyleui-evidence/parity-qol-r5/db2/`. A spell counts as learnable when it has a `SkillLineAbility` row with `AcquireMethod` 0 or 2, or is a talent rank in `Talent.csv`; `AcquireMethod` 3 is a rune and out. "L0" means the row has no level in `SpellLevels` (learnable, level unknown offline). UI source: `~/.cache/wow-ui-source` at `9dc84f0` (1.60.1.70862); `Docs/` = `Interface/AddOns/Blizzard_APIDocumentationGenerated/`.

## Top additions per class

| Class | Top additions |
| --- | --- |
| Warrior | Threat gem on the top band; main-strike cooldown (Mortal Strike, Bloodthirst, Shield Slam) on the left hip; Shield Block uptime (Defensive) or Flurry / Sweeping Strikes (Battle, Berserker) on the right hip; interrupt (Shield Bash, Pummel) on the left foot; Taunt (Defensive) or Charge / Intercept on the right foot; Thunder Clap uptime for tanks |
| Paladin | Fix four builder gaps (Seal of Fury ranks, Vengeance ranks 2-5, Avenging Wrath is a rune, dead Holy Power jewels); Judgement of Fury taunt on the right shoulder; per spec: Holy Shock / Hammer of the Righteous / Holy Strike on the left hip, Oath of Light / Righteous Fury / Hammer of Wrath on the right hip; Hammer of Justice and threat (Holy: stone and mana potion) on the feet; 5-second rule, Holy Shield or Vengeance ring on the inner rim |
| Rogue | Kick on the left foot; a spec perch on the right foot (Deadly Poison stacks, Riposte, Hemorrhage, then Death Mark, Shank); "empowered strike" fire (Remorseless, Ghostly Strike's opener, Poised) and Shank's Venom ring on the inner rim; energy tick as a spark on the energy bar |
| All | Racial, trinket and potion buffs join every cooldown rim; stack counts on charge medals (`SetApplicationCount`); focus as an aura unit for healers |

## 1. Builder bugs found (fix before more pieces)

1. **Avenging Wrath 407788 is a rune** (`AcquireMethod` 3), so its paladin cooldown-rim family never lights. Drop it. `sculpin-2 KstyleUI_ActionBars/SlabTrackers.lua:358`.
2. **The Seal list misses five Seal of Fury ranks**: 1311649 (L10), 20419 (L34), 20421 (L42), 20422 (L50), 20423 (L58). A Protection paladin's reliquary stays steel while sealed at 10-17 and 34+. `SlabTrackers.lua:352`.
3. **The Vengeance jewel feed knows only rank 1** (`known = { 20049 }`, `sculpin-2 SlabJewels.lua:26`). Vengeance's talent ranks are 20049, 20056, 20057, 20058, 20059 (`Talent.csv`) and each rank replaces the last, so from rank 2 the jewels lose their feed.
4. **Dead Holy Power jewels.** A paladin with neither Vengeance nor Holy Shield (every Holy paladin, every paladin under about 20) falls through `Fed` to `Kind` = `"holy"` (`sculpin-2 SlabJewels.lua:46-65`) and draws five jewels that read `HolyPower`, which Forever lacks (staging `SlabJewels.lua:23`). Add Reckoning 1326084 (stacks to 4; talent 20177, 20179, 20180, 20181, 20182) as a third feed, and draw no jewels when nothing feeds them.
5. **Judgement of Fury's taunt is missing from the "your Judgement on the target" medal** (`SlabTrackers.lua:356`). Seal of Fury's judgement "taunts the target to attack you for 20232d" (20163's text; 20232 is aura type 11, taunt). It is a Protection paladin's only taunt on Forever. Add 20232.
6. **The melee report's reason for Enrage no longer holds.** Raging Blow 402911 and Enraged Regeneration 402913 are runes (`melee/REPORT.md:66` assumes them). The rim still means "Enraged" (the Enrage talent's damage, Bloodrage's rage, Berserker Rage's immunity), so keep the piece and fix the wording in the docs.
7. **Dead IDs** (harmless; delete for minimal lists): Commanding Shout 403215 in `SHOUTS` (`SlabTrackers.lua:333`, rune), Blade Dance 400012 (`:365`, rune), Enrage 14201-14204 (no client rows; 12880 is the only Enrage aura).

## 2. Seats

Hub units (the 150-unit ring), radius at an angle, 0 degrees at 3 o'clock, counter-clockwise.

| Seat | Where | Size | Defined in |
| --- | --- | --- | --- |
| Crown | class pieces from 76 to 120 out, fanned over the top | class art | staging `SlabCrown.lua:15`, `Core/Widgets/ClassPip.lua:25-27` |
| Jewels | five gems at 62 on 30, 60, 90, 120 and 150 degrees | 12 | staging `SlabJewels.lua:14` |
| Top (reliquary) | 96 at 90 | 28 | `sculpin-2 SlabMedals.lua:15` |
| Top gem | 60 at 90, on the ring band under the crown's base | 12 socket | `healers/REPORT.md:96-97` |
| Shoulders | 84 at 148 and 32 | 26 | `sculpin-2 SlabMedals.lua:15` |
| Hips | 76 at 218 and 322 | 26 | `limpet-2 SlabRanged.lua:12` (59.9, -46.8) |
| Lower ring | 62 at 215 and 325 | 12 socket | `sculpin-2 SlabMedals.lua:15` |
| Feet | 73 at 247 and 293, either side of the level plaque | 17 perch | `limpet-2 SlabRanged.lua:10, 12` (28.5, -67.2) |
| Inner rim | a ring 104 across inside the rune ring; fire (ambient cell) and/or a draining ring | | `sculpin-2 SlabMedals.lua:13, 272` |
| Cooldown rim | a ring 90 across, and up to three 14-unit icons stacked 30 below the centre | | `sculpin-2 SlabMedals.lua:14, 291` |

Collision rules, measured from those numbers:

- **A hip and the lower-ring socket on the same side overlap** (centres 14 apart, 19 needed). A class uses one or the other per side. The rogue's vials take the lower ring, so a rogue has no hips.
- **The top gem collides with the middle jewel** (60 and 62 at 90 degrees). Only a class without jewels has it: the warrior (banners start at 76, so the gem clears them).
- Hips clear the feet by 16 and the shoulders easily; feet clear each other and the plaque (`ranged/REPORT.md:91-92`).
- The cooldown rim's icon stack sits inside the inner rim over the lower emblem; it can show with an inner-rim piece.

## 3. Routes

| | Route | Proof | Verdict |
| --- | --- | --- | --- |
| R1 | Aura slot: helpful on the player; harmful on an enemy target (`HARMFUL`, or `HARMFUL\|PLAYER` for yours); helpful on a friendly target or focus (`HELPFUL\|PLAYER`). Never harmful on a friendly unit | `Blizzard_AuraContainer/Blizzard_AuraContainerUtil.lua:52-111`; `Blizzard_CustomAuraContainer.lua:417` | Safe; shipped (crowns, storm orbs) |
| R2 | Stacks or charges: application bars (`SetApplicationBar`) or the engine-written number (`SetApplicationCount`) | `Blizzard_CustomAuraButton.lua:68-77, 87` | Safe; bars shipped (`ClassPip.lua`), the count is new |
| R3 | Spell cooldown: `C_Spell.GetSpellCooldownDuration` (duration object) and `isActive`/`isOnGCD` (never secret) | `Docs/SpellDocumentation.lua:309-343`; `Docs/SpellSharedDocumentation.lua:19-31` | Safe; builder `Medals.Refresh` |
| R4 | `C_Spell.IsSpellUsable` on `SPELL_UPDATE_USABLE` | `Docs/SpellDocumentation.lua:980-995` | Safe; keeps the last state on a secret answer (builder) |
| R5 | Weapon enchant slot | `Blizzard_CustomAuraContainer.lua:488-507`; `Docs/PaperDollInfoDocumentation.lua:226-240` | Safe; builder vials |
| R6 | Stance: `GetShapeshiftFormID` (Battle 17, Defensive 18, Berserker 19, Stealth 30 in `SpellShapeshiftForm`) | `Blizzard_ActionBar/Shared/StanceBar.lua:62, 155` | Safe; builder `Stance()` keeps the last value on a secret |
| R7 | The player's own `UNIT_SPELLCAST_SUCCEEDED` | `Docs/UnitDocumentation.lua:4847-4855` | Safe |
| R8 | Bag and item values: `C_Item.GetItemCount`, `C_Item.GetItemCooldown` (start, duration, enable; no secret flags); a shared category's sweep from `C_Spell.GetLastCategoryCooldownSource` into `GetSpellCooldownDuration`, both `AllowedWhenTainted` | `Docs/ItemDocumentation.lua:434-468`; `Docs/SpellDocumentation.lua:154-170, 327-343` | Safe; ranged item medal (`limpet-2 SlabRanged.lua:106, 370`), Cooldowns' category entries (`KstyleUI_Cooldowns/README.md:213`) |
| R9 | Threat: `UnitDetailedThreatSituation("player", "target")` on `UNIT_THREAT_LIST_UPDATE`, `UNIT_THREAT_SITUATION_UPDATE` and `PLAYER_TARGET_CHANGED`; `isTanking` goes to `SetAlphaFromBoolean` or `C_CurveUtil.EvaluateColorFromBoolean` then `SetVertexColor`; `scaledPercentage` goes to `StatusBar:SetValue` | `Docs/UnitDocumentation.lua:1086-1104, 4891-4907`; `Docs/SimpleRegionAPIDocumentation.lua:134-137, 191-194`; `Docs/SimpleStatusBarAPIDocumentation.lua:229-232, 355-358`; `Docs/CurveUtilDocumentation.lua:31-47` | **Pass**: each secret goes only into an `AllowedWhenTainted` setter. New to the crest; nameplates and the threat meter read it only when readable (`KstyleUI_Nameplates/Plate.lua:1455-1470`, `KstyleUI_Meters/Threat.lua:1`) |
| R10 | Target-cast flare: `UNIT_SPELLCAST_START`/`_STOP`/`_INTERRUPTED`/`_SUCCEEDED` for `"target"`, by arrival only; `notInterruptible` from `UnitCastingInfo("target")` only into `EvaluateColorValueFromBoolean` then `SetAlpha` | `Docs/UnitDocumentation.lua:828-850, 4817-4827`; `Docs/SimpleRegionAPIDocumentation.lua:125-126`; `Docs/CurveUtilDocumentation.lua:49-60` | **Pass**: no value is read or compared |
| R11 | A Lua timer started by a readable event: the five-second rule (own successful cast whose `C_Spell.GetSpellPowerCost` lists mana, then `SetCooldown(GetTime(), 5)` with plain numbers); the energy tick (each `UNIT_POWER_FREQUENT("player", "ENERGY")` with no own cast in the same frame resyncs a 2 s loop; the event carries no value) | `Docs/SpellDocumentation.lua:535-549`; `Docs/UnitDocumentation.lua:4532-4537`; the 5-second spark ships on the power bar (`KstyleUI_UnitFrames/README.md:448`) | Five-second rule: **Pass** (shipped). Energy tick: **Pass with an in-game check** (that Forever ticks every 2 s, and that Relentless Strikes, Thistle Tea and Adrenaline Rush gains arrive with a cast) |

**Rejected:**

- Ticks or thresholds read from the value: `UnitPower` is `SecretWhenUnitPowerRestricted` (`Docs/UnitDocumentation.lua:2732-2735`), `GetPowerRegen` is `SecretWhenUnitStatsRestricted` (`Docs/PlayerScriptDocumentation.lua:860-863`). That is why the shipped bar refuses regen ticks (`KstyleUI_UnitFrames/README.md:448`); R11's cadence never reads the value.
- Threat status as four colours: a curve's `Evaluate` takes a secret only when untainted (`Docs/LuaColorCurveObjectAPIDocumentation.lua:47-50`). Only the `isTanking` boolean drives colour.
- A trinket sweep from `GetInventoryItemCooldown`'s secrets: `Cooldown:SetCooldown` takes secrets only when untainted (`Docs/FrameAPICooldownDocumentation.lua:281-285`); the Cooldowns module already shows trinkets without a sweep (`KstyleUI_Cooldowns/README.md:214`).
- Forbearance 25771 and Recently Bandaged on the player: harmful on a friendly unit, refused by R1 (`melee/REPORT.md:52`), unless `C_Secrets.GetSpellAuraSecrecy` says never secret in game.
- The amount left on an absorb (Templar's Bulwark, Seal of Fury's shield): needs aura points, which are secret.
- Runes (`AcquireMethod` 3): Raging Blow 402911, Enraged Regeneration 402913, Commanding Shout 403215, Rallying Cry 426490, Devastate 403196, Shockwave 440488, Meathook 403228, Quick Strike 429765, Valor of Azeroth 461475; Avenging Wrath 407788, Seal of Martyrdom 407798, Rebuke 425609, Divine Storm 407778, Sacred Shield 412019, Horn of Lordaeron 425600, Shield of Righteousness 440658, Divine Sacrifice 407804, Righteous Fury 407627 (25780 is the trainer one), Divine Light 458856, the Exorcism 415068-415073 rows (879 and ranks are trainer); Blade Dance 400012, Saber Slash 424785, Shadowstrike 399985, Shuriken Toss 399986, Main Gauche 424919, Poisoned Knife 425012, Shiv 424799, Between the Eyes 400009, Quick Draw 398196.
- Not on Forever: Blessing of Salvation, Light and Sanctuary (no rows); Holy Power and paladin interrupts (Rebuke is a rune).

## 4. Shared by every melee spec

| Item | Why it matters | IDs | Route | Verdict | Covered by / seat |
| --- | --- | --- | --- | --- | --- |
| Rage or energy at the cap | spend before it is wasted | | engine curve | shipped | Crest cap ring (`docs/medallions-effects.md`, Resource cap) |
| Swing timer | Heroic Strike, Cleave and Slam timing | `C_SwingTimer` | Meters | shipped | Swing bar above the casts (`KstyleUI_Meters/README.md:24`; `Core/Setup/README.md:137`) |
| Target's cast and whether it can be stopped | interrupt timing | | cast bar | shipped | Target cast bar; **new** flare on each class's interrupt perch (R10) |
| Your debuffs on the target | upkeep | | engine | shipped | Target rows above the target medallion, or the crest fan (`KstyleUI_UnitFrames/README.md:29-35`) |
| Threat on the target | tanks hold, others must not pull | | R9 | Pass, in-game check 3 | Nameplate tint and threat meter; **new** crest piece per class below |
| Racial ready | burst or escape | Blood Fury 20572, Berserking 20554, Stoneform 20594, Escape Artist 20589, Will of the Forsaken 7744, Shadowmeld 20580, Perception 20600, War Stomp 20549, Cannibalize 20577; Forever: Will to Survive 1259718, Shatter Curse 1299026, Elune's Light 1259799, Rapid Regeneration 1260270, Eureka! 1259812, Skysight 1259686, Read Leyline 1259705, Walk on Air 1259416 | R3 | Pass | Cooldown row (the player adds it) |
| **Racial buff up** | it is a major cooldown | 20572, 20554, 20594, 20600, 1299026, 1259799, 1259812, 1260270, 7744 | R1 | Pass | **New: shared cooldown-rim families for every class** |
| On-use trinket ready | | slots 13, 14 | R8 (enable flag) | Pass, ready or cooling only | Cooldown row's equipped entries (`KstyleUI_Cooldowns/README.md:31, 214`) |
| **Trinket buff up** | | the equipped item's use spell (`C_Item.GetItemSpell`) | R1 | Pass with in-game check 7 (the buff carries the use spell's ID) | **New: rim families resolved on `PLAYER_EQUIPMENT_CHANGED`** |
| Potion ready (category 4, 2 min) | | healing 118, 858, 929, 1710, 3928, 13446 and Forever's 223913, 223914, 287966, 287967, 287977, 288896; mana 2455, 3385, 3827, 6149, 13443, 13444, 287968, 287969, 288897; rage 5631, 5633, 13442; Free Action 5634, Limited Invulnerability 3387, Swiftness 2459, Restorative 9030, Greater Stoneshield 13455 | R8 | Pass | Cooldown row's category entry; a crest seat only for Holy (Paladin) |
| Healthstone, rune, tuber or Thistle Tea ready (category 1153, one 2-min cooldown on Forever) | | Healthstones (the 15 in `limpet-2 SlabRanged.lua:489`), Demonic Rune 12662, Dark Rune 20520, Whipper Root Tuber 11951, Thistle Tea 7676 | R8 | Pass | Cooldown row; a crest seat only for Holy |
| **Potion buff up** | | Mighty Rage 17528, Free Action 6615, Invulnerability 3169, Greater Stoneshield 17540, Speed 2379, Restoration 11359, Juju Power 16323 | R1 | Pass | **New: shared rim families** |
| Flask, elixir, food | prepared before the pull | | R1 | Pass | Auras reminder card (`KstyleUI_Auras/Reminder.lua:1`), buff rows |
| Weapon stone or oil (warrior, paladin) | raid consumable | stones 12404, 18262, 12643; oils 20748, 20749, 23123 | R5 | Pass | Aura panel's enchant row (`KstyleUI_Auras/Panel.lua:394-401`); no free seat (hips take the lower ring) |

## 5. Warrior

Specs show through talents, and the stance chooses the set; the builder already switches the opening by stance (`sculpin-2 SlabTrackers.lua:340-345`).

### Every warrior

| Item | Why it matters | IDs | Route | Verdict | Covered by / seat |
| --- | --- | --- | --- | --- | --- |
| Sunder Armor stacks | armor and threat | 7386, 7405, 8380, 11596, 11597 | R1, R2 | shipped | Banner crown |
| Battle Shout | attack power, 2-min upkeep | 6673 (L1), 5242, 6192, 11549, 11550, 11551, 25289 | R1 | Pass | Builder: left shoulder |
| The opening | reactive strikes | Overpower 7384 (L12), 7887, 11584, 11585; Revenge 6572 (L14) and ranks; Execute 5308 (L24) and ranks; Victory Rush 402927 (L20, trainer) | R4, R3 | Pass | Builder: right shoulder, per stance |
| Enraged | damage window | Enrage 12880 (talent 12317, 13045-13048), Bloodrage 29131 (L10), Berserker Rage 18499 (L30) | R1 | Pass | Builder: inner rim |
| Major cooldowns up | | Recklessness 1719 (L50), Death Wish 12328, Shield Wall 871 (L28), Last Stand 12976, Sweeping Strikes 12292, Retaliation 20230 (L20) | R1 | Pass | Builder: cooldown rim |
| **Interrupt ready** | stop a cast | Shield Bash 72 (L12, 12 s), 1671, 1672; Pummel 6552 (L38, 10 s), 6554; one category (88) | R3, R10 | Pass | **New: left foot** |
| **Threat on the target** | | | R9 | Pass | **New: top gem** |
| Charge, Intercept | gap closer | Charge 100 (L4), 6178, 11578; Intercept 20252 (L30), 20616, 20617 | R4, R3 | Pass | **New: right foot (Battle, Berserker)** |
| Rend, Hamstring, Deep Wounds, Thunder Clap, Demoralizing Shout on the target | upkeep | Rend 772 (L4) and ranks; Hamstring 1715, 7372, 7373 | R1 | Pass | Target rows / fan |
| Bloodrage, Berserker Rage, Disarm, Intimidating Shout ready | | 2687, 18499, 676, 5246 | R3 | Pass | Cooldown row |

### Arms

| Item | Why it matters | IDs | Route | Verdict | Covered by / seat |
| --- | --- | --- | --- | --- | --- |
| **Mortal Strike ready** | main strike, 6 s, shares category 971 with Bloodthirst and Shield Slam | 12294 (L40), 21551, 21552, 21553 | R3 | Pass | **New: left hip** |
| **Slam ready** | Forever gives Slam a 15 s cooldown (category 2412) | 1240193 (L20), 1464, 8820, 11604, 11605 | R3 | Pass | **New: left hip before 40** |
| Overpower, Execute | | | | | Builder opening |
| **Sweeping Strikes up** (5 hits) | cleave window | 12292 (talent, L30 rank) | R1, R2 count | Pass | Builder rim; **new: right hip with its count** |
| Spearing Strike ready | Forever: bonus against giants, dragonkin, mounted | 1310222 (L1) | R3 | Pass | Cooldown row |
| Weaponmaster's sword attack | | 1257049 | none (no aura) | | Nothing to show |

### Fury

| Item | Why it matters | IDs | Route | Verdict | Covered by / seat |
| --- | --- | --- | --- | --- | --- |
| **Bloodthirst ready** | main strike | 23881 (L40), 23892, 23893, 23894 | R3 | Pass | **New: left hip** |
| Whirlwind ready | 10 s | 1680 (L36) | R3 | Pass | Builder opening (Berserker); left hip before 40 |
| **Flurry up** (3 swings) | haste proc | aura 12966; talent 12319, 12971-12974 | R1, R2 count | Pass | **New: right hip** |
| **Reckless Swings up** (4 swings) | Forever: rage per swing, 15 s cooldown | 1329555 (Fury line, L0) | R1, R2 count | Pass, in-game check 6 (how it is learned) | **New: right hip when Flurry is unknown** |
| Death Wish, Recklessness, Enrage | | | | | Builder rim and inner rim |
| Pummel, Intercept | | | | | **New: feet (Berserker)** |

### Protection

| Item | Why it matters | IDs | Route | Verdict | Covered by / seat |
| --- | --- | --- | --- | --- | --- |
| **Shield Block up** | mitigation uptime; Forever: 5 s cooldown, 2 blocks (3 with Improved Shield Block 12945, 12307, 12944) | 2565 (L16) | R1, R2 count | Pass | **New: right hip (Defensive)**; its readiness is in the builder's Defensive opening |
| **Thunder Clap on the target** | attack-speed slow, mitigation uptime; anyone's counts | 6343 (L6), 8198, 8204, 8205, 11580, 11581 | R1 `HARMFUL` | Pass | **New: left hip (Defensive)** |
| Demoralizing Shout on the target | attack-power cut; anyone's counts | 1160 (L14), 6190, 11554, 11555, 11556 | R1 | Pass | Target rows / fan (no free seat) |
| **Taunt ready, and your taunt holding** | | Taunt 355 (L10, 8 s); taunt auras 355, Mocking Blow 694 (L16), 7400, 7402, 20559, 20560, Challenging Shout 1161 (L26) | R3 plus R1 `HARMFUL\|PLAYER` | Pass | **New: right foot (Defensive)**, a cooldown swipe and a ring while the taunt holds |
| Revenge, Shield Slam ready | | | | | Builder Defensive opening |
| Shield Wall, Last Stand up | | | | | Builder rim |
| **Threat** | | | R9 | Pass | **New: top gem**, gold while you tank |
| Concussion Blow, Challenging Shout ready | | 12809, 1161 | R3 | Pass | Cooldown row |

### Warrior seat plan

| Seat | Battle stance (Arms) | Berserker stance (Fury) | Defensive stance (Protection) |
| --- | --- | --- | --- |
| Crown | Sunder banners | Sunder banners | Sunder banners |
| Top gem | **Threat**: lit red while you hold the target's aggro; the fill is your threat percent | same | **Threat**: lit gold while you tank it, red when you lose it |
| Left shoulder | Battle Shout | Battle Shout | Battle Shout |
| Right shoulder | Execute > Overpower > Revenge > Victory Rush; **below 12, Rend on the target** | Execute > Bloodthirst > Whirlwind > Victory Rush | Revenge > Shield Block > Shield Slam |
| Left hip | **Mortal Strike > Slam > Thunder Clap** ready | **Bloodthirst > Whirlwind > Slam** ready | **Thunder Clap on the target** |
| Right hip | **Flurry > Sweeping Strikes > Reckless Swings** up, with count | same | **Shield Block** up, with count |
| Left foot | **Shield Bash** | **Pummel** | **Shield Bash** |
| Right foot | **Charge** | **Intercept** | **Taunt** (swipe, and a ring while your taunt holds) |
| Inner rim | Enraged | Enraged | Enraged |
| Cooldown rim | builder + shared families | same | same |
| Left to the row, target rows or bars | Rend, Deep Wounds, Hamstring, Demoralizing Shout on the target; Bloodrage, Berserker Rage, Disarm, Intimidating Shout, Concussion Blow, Spearing Strike, Challenging Shout ready; swing timing | | |

Priority when crowded (also the Frames row order): opening, Battle Shout, strike, Shield Block or Flurry, interrupt, Taunt or gap closer, threat. The threat gem is the first to go if a stance has too much.

Level bands: 1-3 Battle Shout (and Reckless Swings if trained at 1); 4 Rend fallback, Charge; 6 Thunder Clap on the left hip; 10 banners, Defensive stance with Taunt and Thunder Clap uptime, Bloodrage lights the rim; 12 Overpower takes the right shoulder, Shield Bash; 14-16 Revenge, Shield Block; 20 Victory Rush, Slam, Retaliation; 30 Berserker stance with Intercept, Sweeping Strikes and Flurry talents; 38 Pummel; 40 the three strikes on the left hip; 50 Recklessness.

### Add to the warrior builder

- Delete 403215 from `SHOUTS`.
- Right shoulder: a last choice, `Rend` on the target (772, 6546, 6547, 6548, 11572, 11573, 11574, `HARMFUL|PLAYER`), for levels 4 to 11.
- Left hip choices by stance: Battle `{ 12294, 21551, 21552, 21553 }` > `{ 1240193, 1464, 8820, 11604, 11605 }` > Thunder Clap; Berserker `{ 23881, 23892, 23893, 23894 }` > `{ 1680 }` > Slam; Defensive Thunder Clap on the target (6343, 8198, 8204, 8205, 11580, 11581, `HARMFUL`).
- Right hip: Battle and Berserker `{ 12966 }` (known 12319, 12971-12974) > `{ 12292 }` > `{ 1329555 }`; Defensive `{ 2565 }`. All with the stack count.
- Left foot: Shield Bash `{ 72, 1671, 1672 }`, Berserker Pummel `{ 6552, 6554 }`, with the target-cast flare.
- Right foot: Battle Charge `{ 100, 6178, 11578 }`, Berserker Intercept `{ 20252, 20616, 20617 }`, Defensive Taunt (cooldown 355; ring on `{ 355, 694, 7400, 7402, 20559, 20560, 1161 }`).
- Top gem: threat (R9).

## 6. Paladin

Specs are told apart by talents the client knows: Protection by Holy Shield (20925) or Reckoning (20177 and ranks); Holy by Holy Shock (20473) or Divine Favor (20216); Retribution by Vengeance (20049, 20056-20059), Seal of Command (20375) or Repentance (20066). With none, the Retribution column applies. Order: Protection, then Holy, then Retribution (a 31/20 hybrid tanks or heals).

### Every paladin

| Item | Why it matters | IDs | Route | Verdict | Covered by / seat |
| --- | --- | --- | --- | --- | --- |
| The active Seal and its time | every attack and Judgement depends on it | as `SlabTrackers.lua:352`, **plus Seal of Fury 1311649, 20419, 20421, 20422, 20423** | R1 | Pass | Builder: reliquary (fix 2) |
| Judgement ready | 10 s | 20271 (L4) | R3 | Pass | Builder: left shoulder |
| Your Judgement on the target | upkeep (Crusader, Light, Wisdom, Justice), and the tank's taunt | as `SlabTrackers.lua:356`, **plus 20232** | R1 `HARMFUL\|PLAYER` | Pass | Builder: right shoulder (fix 5) |
| Divine Protection, Divine Shield, Blessing of Protection on yourself | | 498 (L6), 5573; 642 (L34), 1020; 1022 (L10), 5599, 10278 | R1 | Pass | Builder rim |
| **Blessing of Freedom on yourself** | | 1044 (L18) | R1 | Pass | **New: rim family** |
| **Hammer of Justice ready** | the only interrupt-like tool (Rebuke is a rune) | 853 (L8), 5588, 5589, 10308 | R3, R10 | Pass | **New: left foot** (Protection, Retribution) |
| Lay on Hands, Divine Intervention, Swift Judgement, Consecration, Repentance, Turn Undead, Cleanse | | 633, 19752, 1310994 (Protection line, 60 s, L1), 26573 (Holy talent), 20066, 2878, 4987 | R3 | Pass | Cooldown row |
| Aura and Blessing upkeep | minutes-long buffs | | R1 | Pass | Buff rows, reminder card |
| Forbearance | | 25771 | R1 refused | Rejected | |

### Holy

| Item | Why it matters | IDs | Route | Verdict | Covered by / seat |
| --- | --- | --- | --- | --- | --- |
| Mana | | | | shipped | Slab power bar |
| **Five-second rule** | when regeneration resumes | spell costs via `GetSpellPowerCost` | R11 | Pass | Power-bar spark (option, `KstyleUI_UnitFrames/README.md:448`); **new: inner-rim ring** |
| **Holy Shock ready** | the strongest instant heal, 10 s | 1311606 (L30), 20473 (L40), 20929, 20930 (talent capstone) | R3 | Pass | **New: left hip** |
| **Divine Favor ready, and up** | next heal crits, 2 min | 20216 (talent, L0) | R3; R1 | Pass | **New: left hip when Holy Shock is unknown**; up already in the builder rim |
| **Oath of Light on your tank** | more healing on that one ally; one at a time | 1328548 (L0) | R1 `HELPFUL\|PLAYER` on focus, else target | Pass, needs a focus refresh (in-game check 8) | **New: right hip** |
| **Light's Vigil on the target** | the next Holy Shock there costs no cooldown and heals the party | cast 1310911 (L40), 1311590, 1311595; aura 1310909 | R1 `HELPFUL\|PLAYER` | Pass | **New: right hip, second ring** |
| **Voice of Truth up** | immune to interrupts for the cast | 1310897 (L20, 3 min) | R1 | Pass | **New: rim family** |
| **Mana potion, and stone or rune** | | category 4 and category 1153 items (section 4) | R8 | Pass | **New: right foot (potion), left foot (stone)** |
| Illumination | mana back on crits | 20210 and ranks | none (no aura) | | Nothing to show |
| Judgement of Light or Wisdom on the boss | | | | | Builder right shoulder |

### Protection

| Item | Why it matters | IDs | Route | Verdict | Covered by / seat |
| --- | --- | --- | --- | --- | --- |
| Holy Shield charges and time | block uptime, threat; 4 charges, 10 s | 20925 (talent, L30), 20927, 20928, 1239570 | R1, R2 | Pass | Builder jewels (count); **new: inner-rim ring (time)**; drop it from the rim families |
| **Righteous Fury** | threat; a missing Fury is the classic tank failure | 25780 (L10) | R1 (steel when missing) | Pass | **New: right hip** |
| **Taunt (Judgement of Fury)** | | 20232 | R1 | Pass | Builder right shoulder (fix 5); Swift Judgement 1310994 on the row gives a second |
| **Hammer of the Righteous or Holy Strike ready** | one category (2404) | 407632 (L40, 6 s); Holy Strike below | R3 | Pass | **New: left hip** |
| **Templar's Bulwark up** | Forever absorb, 5 min, applies Forbearance | 1311015 (Protection line, L0) | R1 | Pass | **New: rim family** |
| Reckoning stacks | extra swings, up to 4 | 1326084 (talent 20177, 20179-20182) | R2 | Pass | **New: jewel feed after Holy Shield** (fix 4) |
| Redoubt | block chance after hits | 20128 (talent 20127, 20130, 20135-20137) | R1 | Pass | Left out (passive proc) |
| **Threat** | | | R9 | Pass | **New: right foot**, gold while you tank |

### Retribution

| Item | Why it matters | IDs | Route | Verdict | Covered by / seat |
| --- | --- | --- | --- | --- | --- |
| Vengeance stacks and time | damage, up to 5 | 20050 (talent 20049, 20056-20059) | R2; R1 | Pass | Builder jewels (fix 3); **new: inner-rim ring (time)** |
| **Holy Strike ready** | main strike, 10 s, category 2404 | 679 (L6), 678, 1866, 680, 2495, 5569, 10332, 10333 | R3 | Pass | **New: left hip** |
| **Hammer of Wrath usable** | execute below 20% | 24275 (L44), 24274, 24239 | R4 | Pass | **New: right hip** |
| **Exorcism ready** | undead and demons | 879 (L20), 5614, 5615, 10312, 10313, 10314 | R3 | Pass, in-game check 9 (does usable reflect creature type) | **New: right hip before 44** |
| Seal of Command, Vindication | procs | 20375; 440667 on the target | none; R1 | | Nothing to show; target rows |
| **Threat** | don't pull | | R9 | Pass | **New: right foot**, red when you pull |

### Paladin seat plan

| Seat | Holy | Protection | Retribution (and no talents) |
| --- | --- | --- | --- |
| Jewels | **none** | Holy Shield charges > **Reckoning** stacks | Vengeance stacks (all ranks) |
| Top (reliquary) | Seal | Seal (all Seal of Fury ranks) | Seal |
| Left shoulder | Judgement ready | Judgement ready | Judgement ready |
| Right shoulder | your Judgement on the target | your Judgement on the target, **with Judgement of Fury's taunt** | your Judgement on the target |
| Left hip | **Holy Shock > Divine Favor > Holy Strike** ready | **Hammer of the Righteous > Holy Strike** ready | **Holy Strike** ready |
| Right hip | **Oath of Light on focus or target; Light's Vigil on the target** | **Righteous Fury** (steel when missing) | **Hammer of Wrath usable > Exorcism ready** |
| Left foot | **stone or rune** (category 1153) | **Hammer of Justice** | **Hammer of Justice** |
| Right foot | **mana potion** (category 4) | **threat**, gold | **threat**, red |
| Inner rim | **five-second rule** ring | **Holy Shield** time | **Vengeance** time |
| Cooldown rim | Divine Favor, **Voice of Truth**, Divine Shield, Divine Protection, Blessing of Protection, **Freedom** + shared | **Templar's Bulwark**, Divine Shield, Divine Protection, Blessing of Protection, **Freedom** + shared; not Holy Shield | Divine Shield, Divine Protection, Blessing of Protection, **Freedom** + shared; not Avenging Wrath |
| Left to the row or bars | Lay on Hands, Divine Intervention, Cleanse, Hammer of Justice | Swift Judgement, Consecration, Lay on Hands | Repentance, Consecration, Lay on Hands |

Priority when crowded: Seal, Judgement pair, hips, jewels, rim, feet. Under Frames the jewels stay with the player frame's class row.

Level bands: 1 Seal; 4 Judgement; 6 Holy Strike on the left hip, the Judgement medal lights with Crusader; 8 Hammer of Justice; 10 Righteous Fury, Seal of Fury, Blessing of Protection; 18 Freedom; 20 Exorcism, Voice of Truth, the first talents choose a column (Vengeance jewels); 30 Holy Shield (jewels and rim), Holy Shock's first rank; 40 Hammer of the Righteous, Light's Vigil; 44 Hammer of Wrath. A Holy paladin shows no jewels at any level.

### Add to the paladin builder

- Seal list: add 1311649, 20419, 20421, 20422, 20423.
- Judged medal: add 20232.
- Jewels (`SlabJewels.lua:26`): Vengeance `known = { 20049, 20056, 20057, 20058, 20059 }`; a third feed Reckoning (`known = { 20177, 20179, 20180, 20181, 20182 }`, `spells = { 1326084 }`); no feed, no jewels.
- Cooldown rim: drop 407788 and the Holy Shield family; add 1311015, 1310897, 1044.
- Left hip choices: Protection `{ 407632 }` > Holy Strike; Holy `{ 20930, 20929, 20473, 1311606 }` > `{ 20216 }` > Holy Strike; Retribution and default Holy Strike `{ 10333, 10332, 5569, 2495, 680, 1866, 678, 679 }`.
- Right hip: Protection `{ 25780 }` aura; Holy feeds `{ 1328548 }` on focus then target and `{ 1310909 }` on target; Retribution usable `{ 24239, 24274, 24275 }` > Exorcism cooldown `{ 10314, 10313, 10312, 5615, 5614, 879 }`.
- Feet: Hammer of Justice `{ 10308, 5589, 5588, 853 }` with the cast flare, and threat; Holy instead the category-1153 and category-4 item perches.
- Inner rim: Holy five-second ring (R11); Protection Holy Shield `{ 20925, 20927, 20928, 1239570 }` ring; Retribution Vengeance `{ 20050 }` ring.

## 7. Rogue

Every rogue learns Shank (L24), Venom (L30), Mutilate and Death Mark (L40) from the trainer; specs differ only by talents: Assassination by Vile Poisons (16513 and ranks), Improved Poisons (14113 and ranks), Seal Fate (14186 and ranks) or Cold Blood (14177); Combat by Riposte (14251); Subtlety by Hemorrhage (16511).

### Every rogue

| Item | Why it matters | IDs | Route | Verdict | Covered by / seat |
| --- | --- | --- | --- | --- | --- |
| Combo points | | | `GetComboPoints` bars | shipped | Blade crown and jewels |
| Energy at the cap | | | | shipped | Crest cap ring |
| **Energy tick** | time openers and finishers | | R11 | Pass with in-game check 1 | **New: a spark on the energy bar** (beside the five-second spark); not the crest, where the rim is busier |
| Slice and Dice | | 5171 (L10), 6774 | R1 | Pass | Builder: left shoulder (stealth: opener usable) |
| Rupture or Garrote on the target | | Rupture 1943 (L20) and ranks; Garrote 703 (L14) and ranks | R1 | Pass | Builder: right shoulder (stealth: Vanish) |
| Poison on each weapon | | | R5 | Pass | Builder: lower ring |
| **Kick ready** | interrupt, 10 s, category 88 | 1766 (L12), 1767, 1768, 1769 | R3, R10 | Pass | **New: left foot**; Gouge 1776 (L6) before 12 |
| **Venom up** | Shank raises poison damage and chance (Forever) | aura 1310703; passive 1329328 (L30) | R1 | Pass | **New: inner-rim ring** |
| **Shank ready** | 10 s, energy, cannot miss | 1329283 (L24), 1329549 | R3 | Pass | **New: right-foot fallback** |
| **Death Mark on the target** | Forever finisher: stores damage, 10 s | 1316709 (L40), 1325756, 1325757, 1325758 | R1 `HARMFUL\|PLAYER` | Pass | **New: right-foot fallback** |
| **Remorseless** | next strike crits after a kill | 14143 (talent 14144, 14148) | R1 | Pass | **New: inner-rim fire** |
| Blade Flurry, Adrenaline Rush, Evasion, Sprint, Cold Blood, Vanish, Ghostly Strike up | | 13877, 13750, 5277, 2983/8696/11305, 14177, 11327/11329, 14278 | R1 | Pass | Builder rim |
| Expose Armor, Sap, Kidney Shot, Blind, Gouge on the target | | | R1 | Pass | Target rows / fan |
| Feint, Blind, Kidney Shot, Distract, Redirect ready | | 1966, 2094, 408, 1725, 438040 | R3 | Pass | Cooldown row |
| Flash Powder, Thistle Tea | | items 5140, 7676 | R8 | Pass | Cooldown row (Thistle Tea shares the Healthstone category) |

### Assassination

| Item | Why it matters | IDs | Route | Verdict | Covered by / seat |
| --- | --- | --- | --- | --- | --- |
| **Deadly or Occult Poison stacks on the target** | the damage the spec keeps at five | Deadly 2818, 2819, 11353, 11354, 25349, 434312-434316; Occult 458820, 462286, 1214170 | R1, R2 count, `HARMFUL\|PLAYER` | Pass | **New: right foot** |
| Cold Blood | | 14177 | | | Builder rim |
| Mutilate | dagger builder | 399956 (L40), 1241582, 1241584 | | | Action bars |

### Combat

| Item | Why it matters | IDs | Route | Verdict | Covered by / seat |
| --- | --- | --- | --- | --- | --- |
| **Riposte usable** | after a parry, 6 s | 14251 (talent) | R4 | Pass | **New: right foot** |
| Blade Flurry, Adrenaline Rush | | | | | Builder rim |

### Subtlety

| Item | Why it matters | IDs | Route | Verdict | Covered by / seat |
| --- | --- | --- | --- | --- | --- |
| **Hemorrhage on the target** | Rupture and Garrote take more | 16511 (talent, L30) | R1 `HARMFUL\|PLAYER` | Pass | **New: right foot** |
| **Ghostly Strike's opener** | next Ambush or Garrote without stealth | 1329326 (talent 14278) | R1 | Pass | **New: inner-rim fire** |
| **Poised** | next ability cheaper (out of combat at full energy) | 1328826 (passive 1328825, L18) | R1 | Pass | **New: inner-rim fire** |
| Premeditation, Preparation ready | | 14183, 14185 | R3 | Pass | Cooldown row |

### Rogue seat plan

| Seat | Assassination | Combat | Subtlety | In Stealth |
| --- | --- | --- | --- | --- |
| Crown, jewels | combo points | combo points | combo points | combo points |
| Left shoulder | Slice and Dice | Slice and Dice | Slice and Dice | opener usable |
| Right shoulder | Rupture or Garrote | Rupture or Garrote | Rupture or Garrote | Vanish ready |
| Lower ring | a poison vial per weapon | same | same | same |
| Left foot | **Kick** (Gouge before 12) | same | same | same |
| Right foot | **poison stacks** > Death Mark > Shank | **Riposte** > Death Mark > Shank | **Hemorrhage** > Death Mark > Shank | same |
| Inner rim, fire | **Remorseless** | **Remorseless** | **Ghostly Strike's opener, Poised, Remorseless** | same |
| Inner rim, ring | **Venom** | **Venom** | **Venom** | |
| Cooldown rim | builder + shared | same | same | same |
| Energy bar | **energy tick spark** | same | same | same |

No hips: the vials take the lower ring. Priority when crowded: Slice and Dice, Rupture, vials, Kick, the right foot, the rim.

Level bands: 1 crown; 6 Gouge on the left foot; 10 Slice and Dice; 12 Kick; 14-20 Garrote then Rupture; 20 vials; 24 Shank on the right foot; 30 Venom ring, Hemorrhage or poison stacks by talent; 40 Death Mark.

### Add to the rogue builder

- Delete 400012 from the Slice list.
- Left foot: Kick `{ 1769, 1768, 1767, 1766 }` with the cast flare; before 12 Gouge `{ 11286, 11285, 8629, 1777, 1776 }`.
- Right foot choices: Assassination (known 16513/14113/14186/14177 families) stacks `{ 2818, 2819, 11353, 11354, 25349, 434312, 434313, 434314, 434315, 434316, 458820, 462286, 1214170 }`; Combat usable `{ 14251 }`; Subtlety `{ 16511 }` on the target; then Death Mark `{ 1316709, 1325756, 1325757, 1325758 }` on the target; then Shank cooldown `{ 1329549, 1329283 }`.
- Inner rim: a fire Rim on `{ 14143, 1329326, 1328826 }`; a ring Rim on `{ 1310703 }`.
- Energy tick: a spark on the energy bar (Unit Frames, R11), on by default.

## 8. Shared pieces to add to SlabMedals (small named extensions)

1. **Stack count on a medal or perch**: one engine `FontString` (`K.Widgets.FontString`) given to `SetApplicationCount` (`Blizzard_CustomAuraButton.lua:87`). For Shield Block, Flurry, Sweeping Strikes, Reckless Swings and poison stacks.
2. **A cooldown swipe and an aura ring on one medal** (`feeds` mixing `"cooldown"` and `"aura"`; today `Refresh` treats a medal as one kind). For Taunt.
3. **Focus as an aura unit**: one line in `REFRESH` (`sculpin-2 SlabMedals.lua:19`), `focus = { "PLAYER_FOCUS_CHANGED" }`. For Oath of Light.
4. **Threat gem**: a `Socket` whose bar takes `scaledPercentage` and whose lit layer takes `isTanking` (R9), coloured by role (Defensive stance or the `TANK` role: gold; otherwise red).
5. **Target-cast flare** on an interrupt piece (R10).
6. **A Lua-timed ring** on the inner rim (R11, five-second rule).
7. **Item perch** for category 4 and 1153: the ranged item medal at perch size.
8. **Shared rim families**: racial and potion buffs for every class, and the equipped trinkets' use spells.

Under Frames each added piece joins the builder's row above the stance bar in the priority order given per class; the crown and jewels stay in the player frame's class row.

## 9. In-game checks

1. Energy: on a rogue, does `UNIT_POWER_FREQUENT` for energy arrive every 2 s at a steady phase, and does every non-tick gain arrive with a cast?
2. `C_Spell.IsSpellUsable` for Overpower (7384), Riposte (14251) and Hammer of Wrath (24239) turns true only when the condition holds, in combat, unsecret.
3. Threat: `/dump UnitDetailedThreatSituation("player", "target")` in a dungeon pull; and that `SetAlphaFromBoolean` takes `isTanking` when it is secret.
4. `/dump C_Secrets.GetSpellAuraSecrecy(25771)`: if Forbearance is never secret, a mark becomes possible.
5. An `HARMFUL` slot on the target shows another warrior's Thunder Clap and Demoralizing Shout.
6. How Reckless Swings (1329555), Oath of Light (1328548), Templar's Bulwark (1311015) and Divine Favor (20216) are learned; they have no level in `SpellLevels`.
7. A trinket's buff carries the use spell's ID (`C_Item.GetItemSpell`) for the rim families.
8. A `HELPFUL|PLAYER` slot on `focus` refreshes on `PLAYER_FOCUS_CHANGED` and in combat.
9. Whether `IsSpellUsable(879)` is false on a non-undead, non-demon target; if not, Exorcism stays a cooldown medal.
10. The Judgement of Fury taunt (20232) appears on the target under `HARMFUL|PLAYER`.
11. Poison stack count: `SetApplicationCount` shows 1 to 5 on a Deadly Poison slot on the target in combat.

## 10. How it was made

Scratch only, in `%TEMP%\orca-ctx_b42a6fb24eb8\`: `q.py` and `ranks.py` (table lookups over the copied CSVs in `db2\`). No repository file was changed; the builders' worktrees were read, not touched.
