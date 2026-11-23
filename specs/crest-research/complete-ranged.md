# Complete crests: Hunter, Mage, Warlock, every spec (research, no code)

Task `task_877d37f0cc50`, 2026-11-23. Read-only: no addon code, no commit, no PR, nothing posted.

## The answer in one table

| Class | Already designed or built | Add first (P1) | Add next (P2) | Fix in the build |
| --- | --- | --- | --- | --- |
| Hunter | Aspect (left hip), pet (right hip), Hunter's Mark (left foot), any Sting (right foot), Quick Shots gust, Rapid Fire and Deterrence on the cooldown rim; shipped Sniper Shot crown and hawk perches | **The shot medal** on a new top gem: lit when Counterattack or Mongoose Bite is usable, else when Aimed Shot / Multi-Shot is ready. **Bestial Wrath** on the cooldown rim as a pet family | **Auto Shot ring** on the inner rim (from `PLAYER_SWING`), tinted when ammo runs low. **Lacerate and Black Arrow** join the Sting perch once a trainer check proves them | Sting list carries 7 IDs with no spell name on Forever (harmless) |
| Mage | Armor (left shoulder), mana gem (right shoulder), ward ring (inner rim), Clearcasting moment, Arcane Power / Presence of Mind / Combustion / Evocation / Ice Block on the rim; shipped Arcane Blast crown | **Counterspell ready** (left hip). **Frozen target** (left foot). **Spec hip** (right): Fire Vulnerability with five stack pips (Fire), Winter's Chill with five pips (Frost), Arcane Wrath ready (everyone else) | **Your fire DoT** on the target (right foot, Fire: Ignite, Pyroblast, Fireball). Low-mana glow on the gem medal | none |
| Warlock | Four torment spires, soul wisps, demon (left shoulder), Healthstone (right shoulder), Shadow Trance moment, Amplify Curse / Fel Domination / Shadow Ward on the rim | **Your Curse** on the target (left foot). **Conflagrate ready** socket (lower right; every warlock trains it at 25 on Forever). **Weapon stone** socket (lower left; Spellstone and Firestone enchant the weapon on Forever) | **Spell Lock ready** (right foot, Felhunter; needs an in-game check). **Voidwalker Sacrifice** on the rim | **Bane spire misses Bane of Agony rank 2 (1014)**, so a level 18 to 27 warlock's Bane never lights it |

All three classes share one cross-class addition: racial cooldown buffs as rim families (section 7).

**No tank or healer spec exists for these classes on Forever.** Every tank or heal kit they had in Season of Discovery is a rune with `AcquireMethod = 3` (unlearnable) or has no skill-line row: warlock Metamorphosis 403789, Menace 403828, Demonic Howl 412789, Demonic Grace 425463, Fel Armor 403619, Shadow Cleave 403835; mage Regeneration, Mass Regeneration, Arcane Surge, Temporal Anomaly, Living Flame; hunter Kill Command 409379, Readiness 23989. What tanks for these classes is the pet (hunter's pet, the Voidwalker), and the pet's health, taunts and Sacrifice are covered below.

## 1. Sources and method

- **Client tables**: `SkillLineAbility`, `Talent`, `SpellLevels`, `SpellCooldowns`, `SpellCategories`, `SpellAuraOptions`, `SpellEffect`, `SpellMisc`, `SpellName`, `Spell` (descriptions), `SkillLine`, `ItemSparse`, copied read-only from the same 1.60.1.71037 export the healer builder made (`%TEMP%\orca-ctx_6b231e178299\db2`, identical sizes) into my scratch folder and queried with a 60-line script. "Learnable" means a `SkillLineAbility` row with `AcquireMethod` 0 (trainer) or 2 (automatic) and a `SpellName` row; `AcquireMethod 3` is a rune and out. Levels are `SpellLevels.BaseLevel`; talent tiers unlock at 10, 15, 20 ... 40.
- **UI source**: `UI:` below is `~/.cache/wow-ui-source/Interface/AddOns` at `9dc84f0`; `Docs/` is `UI:Blizzard_APIDocumentationGenerated/`.
- **What is designed and built**: the three design reports in `../{melee,ranged,healers}/REPORT.md`; the shared helper and lifecycle at melee commit `e4333eb4a` (`KstyleUI_ActionBars/SlabMedals.lua`, `SlabTrackers.lua`, `docs/medallions-effects.md`); the ranged rows at ranged commit `88a9f07f3` (`KstyleUI_ActionBars/SlabRanged.lua`). The ranged builder is mid-rebase onto `e4333eb4a`, so its working tree differs; I cite commits, not the working tree.
- **What ships today**: `staging` at `7b544324d`.

## 2. Routes

Every route below is engine-driven or reads a value the docs never mark secret. Nothing here asks Lua to compare a secret.

| Route | What it gives | Proof |
| --- | --- | --- |
| **R1 aura slot** | One aura picked by spell ID: shown or hidden, its icon, a timer ring or bar from the aura's duration object | `UI:Blizzard_AuraContainer/Blizzard_CustomAuraContainer.lua:417`; `Blizzard_CustomAuraButton.lua:159` |
| R1 filter rule | Helpful on the player, a group member or **their pets**: allowed (`Blizzard_AuraContainerUtil.lua:70`). Harmful on an enemy: allowed. Harmful on a friend: refused (`:78`). **Helpful on an enemy: refused** (`:82`). `includeDispelTypes` is applied after the identity test, so it works where spell IDs are refused (`:123-127`) | as cited |
| **R1s stacks** | One application bar per stack, as the shipped crowns do | `Blizzard_CustomAuraButton.lua:68`; `Core/Widgets/ClassPip.lua:1` |
| **R2 items** | `C_Item.GetItemCount`, `C_Item.GetItemCooldown`: plain numbers | `Docs/ItemDocumentation.lua:434-468` |
| **R3 spell cooldown** | `C_Spell.GetSpellCooldownDuration` for the swipe; `isActive`, `isOnGCD` are `NeverSecret` | `Docs/SpellDocumentation.lua:327-342`; `Docs/SpellSharedDocumentation.lua:19-31` |
| **R4 usable** | `C_Spell.IsSpellUsable`, no secret flag: a reactive strike lights only while its condition holds | `Docs/SpellDocumentation.lua:980-995`; shipped as `Medals.Refresh` (`SlabMedals.lua:439` at `e4333eb4a`) |
| **R5 weapon enchant** | `AddItemEnchantment(MainHand)`: shown while the temporary enchant is on, drains with it | `Blizzard_CustomAuraContainer.lua:488`; `Docs/PaperDollInfoDocumentation.lua:226-240` |
| **R6 pet unit** | Pet exists, portrait, happiness (`C_PetInfo.GetPetHappiness`, no flag), health straight into a StatusBar | `Docs/PetInfoDocumentation.lua:35-45`; `../ranged/REPORT.md` section 2 |
| **R7 swing event** (new) | `PLAYER_SWING` carries `swingDuration` and `swingType` with no secret flag, so `Cooldown:SetCooldown(GetTime(), swingDuration)` is plain | `Docs/SwingTimerDocumentation.lua:42-53`; shipped use `KstyleUI_Meters/Swing.lua:1, 13, 19-23` |
| **R8 curve alpha** (new for trackers) | `UnitPowerPercent("player", mana, false, curve)` handed to `SetAlpha`; Lua never sees the number | `Docs/UnitDocumentation.lua:2838-2850`; shipped `KstyleUI_ActionBars/SlabEffects.lua:1, 116-136` |
| **R9 ammo count** (new) | `GetInventoryItemCount("player", ammoSlot)`: not in the generated docs, so no secret flag; Blizzard's own ammo slot reads it | `UI:Blizzard_UIPanels_Game/Camelot/PaperDollFrame.lua:1517, 2185`; shipped `KstyleUI_DataBars/Readouts.lua:289-292` |
| **R10 pet spellbook** (new) | `C_SpellBook.IsSpellKnown(id, Pet)` tells whether the demon out knows Spell Lock. Its cooldown through `GetSpellCooldownDuration` on a pet spell is **unproven**; Blizzard's pet bar uses the undocumented `GetPetActionCooldown(i)` | `Docs/SpellBookDocumentation.lua:738-752`; `UI:Blizzard_ActionBar/Shared/PetActionBar.lua:137` |
| R11 own casts | The player's own `UNIT_SPELLCAST_SUCCEEDED` is not secret (only other units' casts are) | `Docs/UnitDocumentation.lua:4845-4856`; `Docs/SecretPredicatesDocumentation.lua:115-117` |

## 3. What already sits at the centre for every class

These are the "covered by" keys in the tables.

| Key | Piece | Where |
| --- | --- | --- |
| **CR** | The cooldown row above the crest: Blizzard's Cooldown Manager restyled (essential, utility, tracked buffs), with item-backed trinket, potion and Healthstone timers and an "All trinkets" option | `KstyleUI_Cooldowns/README.md:29, 57, 306` |
| **FOCUS** | Focus interrupt: your interrupt on your focus's plate, with a cast sound when it is ready (off by default) | `KstyleUI_Cooldowns/README.md:504` |
| **FAN** | The crest debuff fan: seven of **your** debuffs on the target (`HARMFUL|PLAYER`), engine sorted, above the crest | `KstyleUI_UnitFrames/Fan.lua:1, 9` |
| **SWING** | Swing timer with a Ranged (Auto Shot) bar, on by default, just above the essential row | `KstyleUI_Meters/Swing.lua:1, 23`; `KstyleUI_Meters/Settings.lua:114-115` |
| **FSR** | Five-second rule spark on the player power bar (off by default) | `KstyleUI_UnitFrames/Settings.lua:1503` |
| **THREAT** | Threat meter and tank alarm | `KstyleUI_Meters/Threat.lua:1`; `docs/feature-map.md:173` |
| **PETUF** | Pet frame: happiness badge, auras, cast bar | `docs/feature-map.md:31-33` |
| **CONS** | Consumables bar, auto-filled (potions, Healthstones) with counts and cooldowns | `KstyleUI_ActionBars/Consumables.lua:1` |
| **AMMO** | Data bar readout with the ammo count | `KstyleUI_DataBars/Readouts.lua:289-292` |
| **REM** | Reminder card: a class buff you know and lack, a flask (off by default, out of combat) | `KstyleUI_Auras/Reminder.lua:1` |
| **CAST** | Player cast bar, including channels (Arcane Missiles, Evocation, Drain Life, Drain Soul, Wrack, Volley, Health Funnel) | `KstyleUI_UnitFrames/CastBar.lua` |

## 4. Seats

Hub units (the 150-unit ring). Shoulders, top, lower ring from `SlabMedals.lua:15`; cooldown rim from `:14, 291`; hips, feet and spires from `SlabRanged.lua:23-26, 42-47` at `88a9f07f3`.

| Seat | Where | Piece |
| --- | --- | --- |
| Crown | Above the ring, 3 to 5 pieces | `ClassPip` fed crown (shipped) |
| Shoulders | 84 units at 148 and 32 degrees | `Medal` |
| Hawk perches (hunter) | 78 units, 40 degrees off the top line | shipped `SlabHawks.lua:12-13` |
| Hips | 76 units at 218 and 322 degrees | `Medal` (ranged rows) |
| Lower ring | 62 units at 215 and 325 degrees; **overlaps the hips**, so a class uses one or the other | `Socket` (the rogue's poison vial) |
| Feet | 73 units at 247 and 293 degrees, beside the level plaque, 17-unit perches | `Medal` |
| Top | 96 units at 90 degrees (the paladin reliquary); **collides with any crown** | `Medal` |
| Top gem | On the ring band at 12 o'clock, about 60 units, under a crown's base (the priest's Pain gem) | **E1**, one new `SEATS` entry |
| Inner rim | A ring inside the rune ring (timer 104 units) | `Rim` |
| Cooldown rim | A 90-unit ring inside the inner rim, plus up to 3 icons 30 units below the centre | `CooldownRim` (families, optional `unit = "pet"`) |
| Spire sockets (warlock) | Four sockets at 82 units, 54 to 126 degrees, spires rising over the crown | `SlabRanged` spires |
| Moment | The whole ring | `Rim` with an ambient flipbook |

**Spec choice needs no new API.** `Register` rows take `choices`; every known choice is built and the first known one whose `forms` matches shows, and a choice with no `forms` matches any form (`SlabTrackers.lua:59-79, 109, 264` and `docs/medallions-effects.md:145` at `e4333eb4a`). A choice gated by a talent's rank IDs (`known`) is a spec variant. None of these classes has a stance or form on Forever (Aspects are auras, not `SpellShapeshiftForm` rows), so their crests change by talent and level, not by form.

**Named extensions this plan needs** (small, each with one owner):

- **E1 top gem seat**: `topGem = { 1, 60, 90 }` in `SEATS`. Hunter only here; the healers' gem is the precedent.
- **E2 stack pips**: `spec.stacks = n` on a `Medal` adds n tiny application bars round its rim (R1s, the crowns' route). Fire Vulnerability and Winter's Chill; the warrior's Sunder and any future stack read the same way.
- **E3 swing rim**: a `build` (the lifecycle's custom builder, `docs/medallions-effects.md:146`) that feeds a `Rim`'s timer from `PLAYER_SWING` (R7) and tints it from the ammo count (R9). Hunter only.
- **E4 low-mana glow** (P3): a glow layer on the mana gem medal whose alpha is a mana curve (R8), shown only while the gem is ready (R2). Mage only.

## 5. Hunter

### Forever facts

- Talent tabs 361 Beast Mastery, 363 Marksmanship, 362 Survival. Forever's own changes in the tables: **Deadly Aspects** (19552, BM tier 0) gives Quick Shots (6150) under Hawk and Quick Strikes (1299448, 469144) under Beast or Falcon; Unleashed Fury and Ferocity also buff the hawks; **Aimed Shot shares its 6 s cooldown with Multi-Shot** (category 2); Arcane Shot shares category 1173 with Summon Hawk; **Counterattack is also a trainer spell at 30** (1242634); Strider Kick (1317257) and Lacerate (24118) sit in the Survival line. Survival is a melee damage spec here.
- **No interrupt**: Silencing Shot 2004 has no skill-line row. Scatter Shot and Intimidation are crowd control, on CR.
- **Dead IDs** (no `SpellName` row, so not learnable): Wyvern Sting 19386, 24131 to 24135 (the Survival capstone row points at 19386); Scorpid Sting ranks 14275 to 14277; Multi-Shot ranks 14288 to 14290 (Multi-Shot is one rank, 2643). The build's Sting list carries them; they can never match and cost nothing.
- Aspects are auras, so the crest cannot switch layout by Aspect; the Aspect medal shows which one is up.

### All hunters

| Item | Why it matters | IDs | Route | Verdict | Covered by or seat |
| --- | --- | --- | --- | --- | --- |
| Aspect up, which | Wrong or missing Aspect is the commonest loss | Hawk 13165, 14318-14322, 25296; Monkey 13163; Cheetah 5118; Pack 13159; Wild 20043, 20190; Beast 13161, 1299445-1299447; Viper 415423; Falcon 469145 | R1 player | Pass | **Built**: left hip (`SlabRanged.lua:23`) |
| Pet present, happy, health, Mend Pet | The pet is half the damage and the tank | Call Pet 883; Mend Pet 136, 3111, 3661, 3662, 13542-13544 | R6, R1 on pet | Pass | **Built**: right hip (`:24`) |
| Hunter's Mark on the target | Ranged attack power for everyone | 1130, 14323-14325 | R1 target `HARMFUL` | Pass | **Built**: left foot (`:25`) |
| Any Sting on the target | One per hunter; Serpent, Viper or Scorpid | Serpent 1978, 13549-13555, 25295; Viper 3034, 14279, 14280; Scorpid 3043 | R1 target `HARMFUL|PLAYER` | Pass | **Built**: right foot (`:26`) |
| Quick Shots / Quick Strikes | The haste window to dump shots into | 6150; 1299448, 469144 (talent 19552-19556) | R1 player | Pass | **Built**: gust moment (`:28`) |
| Rapid Fire active | The big damage window | 3045 (26) | R1 player | Pass | **Built**: cooldown rim (`:27`); ready on CR |
| Sniper Shot shots | Three empowered shots | 1310687, 1310785, 1310786 (40) | R1s | Pass | **Shipped** crown (`ClassPip.lua:33`) |
| Hawks out | Summon Hawk's two hawks | 1293241, 1293525-1293527 (25) | totem slots | Pass | **Shipped** perches (`SlabHawks.lua:1`) |
| **Auto Shot timing** (and the melee swing) | When to fit Aimed Shot or Multi-Shot without clipping Auto Shot | Auto Shot 75 | **R7** | Pass | SWING (above the row). **Missing at the crest** -> inner rim, E3 (P2) |
| Ammo left | Running dry mid-pull stops Auto Shot | ammo slot | **R9** | Pass (in-game check 5) | AMMO readout. **Missing at the crest** -> tint on the Auto Shot ring (P2) |
| **Shot ready** | Aimed Shot / Multi-Shot, the shared 6 s cooldown | Multi-Shot 2643 (18); Aimed Shot 19434, 20900-20904 (talent) | R4 + R3 `isActive` | Pass | CR. **Missing at the crest** -> the shot medal on the top gem, last candidates (P1, with the opening below) |
| Mana | Hunters run dry | | | | Slab power bar; FSR; Viper shows on the Aspect medal |
| Threat, Feign Death | Dumping threat | Feign Death 5384 (30 s) | | | THREAT, CR |
| Traps, Disengage, Concussive, Scatter, Intimidation, Flare | Utility cooldowns | traps share category 411 (30 s) | R3 | | CR |
| Tranquilizing Shot target | An enraged mob to soothe | 19801 (60) | R1 refused: a helpful aura on an enemy (`Blizzard_AuraContainerUtil.lua:82`); `includeDispelTypes` might work | **Reject for now** (in-game check 6) | FAN does not show enemy buffs; target frame buffs do |
| Trueshot Aura, Aspect of the Pack / Wild for the group | Group buffs, minutes long | 19506, 1299346, 1299348, 20905, 20906 | R1 | Pass | REM and the buff row; not a crest glance |
| Pet abilities, pet focus | Growl, Bite, Claw | | | | Pet bar, PETUF |

### Beast Mastery adds

| Item | Why it matters | IDs | Route | Verdict | Covered by or seat |
| --- | --- | --- | --- | --- | --- |
| **Bestial Wrath on the pet** | The spec's 2-minute burst | 19574 (talent, tier 6) | R1 on `pet` (helpful on your pet is filterable, `:70`); a `CooldownRim` family with `unit = "pet"` (`SlabMedals.lua:295` at `e4333eb4a`) | Pass | **Missing** -> cooldown rim (P1) |
| The Beast Within | The hunter's share of Bestial Wrath | 1223758 is a passive with no player aura ID in the tables | | **Reject** (no aura to pick) | Bestial Wrath on the rim stands for it |
| Frenzy on the pet | Pet attack speed proc | 19615 (talent 19621-19625) | R1 on pet | Pass, low value | PETUF auras; not seated |
| Intimidation ready | Stun and threat | 19577 | R3 | Pass | CR |

### Marksmanship adds

| Item | Why it matters | IDs | Route | Verdict | Covered by or seat |
| --- | --- | --- | --- | --- | --- |
| Aimed Shot ready | The spec's big shot | 19434, 20900-20904 | R4 + R3 | Pass | Shot medal (top gem) |
| Black Arrow on the target | A Forever shot: slow, Shadow damage and mana drain over time | 3674, 14296 (Marksmanship line, `AcquireMethod 0`, **no level**) | R1 target `HARMFUL|PLAYER` | **Pass if trainable** (in-game check 4) | Joins the Sting perch, newest shows (P2) |
| Scatter Shot | Crowd control | 19503 | R3 | Pass | CR |

### Survival adds

| Item | Why it matters | IDs | Route | Verdict | Covered by or seat |
| --- | --- | --- | --- | --- | --- |
| **The opening** | Counterattack after a parry, Mongoose Bite after a dodge: the melee hunter's reactive strikes | Counterattack 19306, 20909, 20910, 1242634 (30); Mongoose Bite 1495 (16), 14269-14271 | **R4**, the warrior opening's route (`Medals.Refresh`) | Pass | **Missing** -> the shot medal on the top gem, first candidates (P1) |
| Lacerate on the target | The melee hunter's bleed | 24118, 24119, 24120 (30, 40, 50), 1299332 (60); `ClassMask 0` on the rows | R1 target `HARMFUL|PLAYER` | **Pass if trainable** (in-game check 4) | Joins the Sting perch (P2) |
| Deterrence active | The defensive | 19263 (talent) | R1 | Pass | **Built**: cooldown rim |
| Raptor Strike, Strider Kick, Wing Clip | Melee cooldowns | 2973 (6 s), 1317257 (8 s), 2974 | R3 | Pass | CR |
| Heart of the Lion | A permanent group aura | 409580 (Survival line, `AcquireMethod 0`, no level) | R1 | Pass if trainable | REM; not seated |
| Wyvern Sting | Capstone sleep | 19386 (no name row) | | **Reject** (unprovable) | |

### Seat plan

| Seat | Beast Mastery | Marksmanship | Survival | From level |
| --- | --- | --- | --- | --- |
| Crown | Sniper Shot arrows | same | same | 40 |
| Shoulders | Hawk perches | same | same | 25 |
| Left hip | Aspect | same | same | 4 |
| Right hip | Pet | same | same | 10 |
| Left foot | Hunter's Mark | same | same | 6 |
| Right foot | Your Sting (+ Black Arrow) | same | Your Sting or Lacerate | 4 |
| **Top gem** (E1) | Shot medal: Multi-Shot / Aimed Shot ready | same, Aimed Shot mostly | Shot medal lights Counterattack or Mongoose Bite first | 16 |
| **Inner rim** (E3) | Auto Shot ring | same | Last swing (main hand in melee) | 1 |
| Cooldown rim | Rapid Fire, **Bestial Wrath (pet)**, racial | Rapid Fire, racial | Rapid Fire, Deterrence, racial | 20 |
| Moment | Quick Shots gust | same | Quick Strikes gust | 10 (talent) |

- **The shot medal** is one `Medal` with `feed = "usable"` and `groups` in this order: Counterattack, Mongoose Bite, Aimed Shot, Multi-Shot. It lights the first that is usable and not on a real cooldown and shows that spell's icon; dark steel means "nothing to press but Auto Shot". No spec switch: a ranged hunter rarely parries or dodges, a melee hunter sees the opening first.
- **Priority** if 1080 gets crowded: pet, Aspect, Sting, Mark, shot medal, cooldown rim, gust, Auto Shot ring; the ammo tint goes first.
- **Level bands**: 1 the Auto Shot ring alone; 4 Aspect and Sting; 6 Mark; 10 pet, gust with Deadly Aspects; 16 shot medal (Mongoose Bite), 18 Multi-Shot joins it; 20 Deterrence; 25 hawks; 26 Rapid Fire; 40 Sniper crown and Bestial Wrath.
- **Frames**: each new piece becomes one medal in the row above the stance bar (the lifecycle's default); the Auto Shot ring becomes a medal with a sweep.

### Add to the hunter builder

1. `crestShot` row: `seat = "topGem"` (E1), `feed = "usable"`, `groups = { {20910, 20909, 19306, 1242634}, {14271, 14270, 14269, 1495}, {20904, 20903, 20902, 20901, 20900, 19434}, {2643} }`. P1.
2. Add `{ spells = { 19574 }, unit = "pet" }` to the hunter's `crestCooldowns` families. P1.
3. `crestAutoShot` row: `seat = "rim"` with E3's `build`; `hooks.events` `PLAYER_SWING` (and `UNIT_INVENTORY_CHANGED` for ammo); amber below 200 shots, red at 0; nothing per frame. P2.
4. Sting perch: add Lacerate 24118, 24119, 24120, 1299332 and Black Arrow 3674, 14296 with `newest = true`, once in-game check 4 proves them. P2.

## 6. Mage

### Forever facts

- Talent tabs 81 Arcane, 41 Fire, 61 Frost. Forever's changes: **Arcane Blast is a trainer spell for every mage** (400574 at 20, 1239696 at 30) feeding the 400573 stacks the crown shows; **Arcane Wrath** (1326079, 25, 6 s) scales with maximum mana; **Ice Lance** (1240044, 34) shares cooldown category 19 with Fire Blast and hits Frozen targets harder; **Frostfire Bolt** (1237312, 50) leaves a DoT; **Ice Barrier** also grants Frigid Power (1326891); **Winter's Chill** (12579) now empowers your next Cone of Cold; **Fire Power** (11124) adds damage per Fire effect of yours on the target, up to four, and "effects which mix multiple schools do not qualify" (so not Frostfire).
- No healer or tank spec (see the top).

### All mages

| Item | Why it matters | IDs | Route | Verdict | Covered by or seat |
| --- | --- | --- | --- | --- | --- |
| Armor up, which, time | 30-minute self-buff | Frost 168, 7300, 7301; Ice 7302, 7320, 10219, 10220; Mage 6117, 22782, 22783 | R1 | Pass | **Built**: left shoulder (`SlabRanged.lua:34`) |
| Mana gem ready | Instant mana | items 5514, 5513, 8007, 8008; conjure 759, 3552, 10053, 10054 | R2 | Pass | **Built**: right shoulder (`:35`) |
| Ward, Mana Shield, Ice Barrier | Absorb up and time | Ice Barrier 11426, 13031-13033; Mana Shield 1463, 8494, 8495, 10191-10193; Fire Ward 543, 8457, 8458, 10223, 10225; Frost Ward 6143, 8461, 8462, 10177, 28609 | R1 | Pass | **Built**: inner rim (`:36`) |
| Clearcasting | Free next spell | 12536 (talent 11213, 12574-12577) | R1 | Pass | **Built**: moment (`:38`) |
| Arcane Blast stacks | Spell damage stacks, four | 400573, 1300176, 1300177, 400586 | R1s | Pass | **Shipped** crown (`ClassPip.lua:29-32`) |
| Arcane Power, Presence of Mind, Combustion, Evocation, Ice Block active | Burst and survival windows | 12042, 12043, 11129, 28682, 12051, 11958, 27619 | R1 | Pass | **Built**: cooldown rim (`:37`) |
| **Counterspell ready** | The only interrupt; a must in dungeons | 2139 (24, category 88, 30 s) | R3 (`Medal` `feed = "cooldown"`, flares when ready) | Pass | CR, FOCUS (opt-in). **Missing at the crest** -> left hip (P1) |
| **Target is Frozen** | Ice Lance hits Frozen targets harder, Shatter, and "is it still rooted" when kiting | Frost Nova 122 (10), 865, 6131, 10230; Frostbite 12494 | R1 target `HARMFUL|PLAYER` | Pass | FAN (one of seven). **Missing as a seat** -> left foot (P1) |
| Mana, five-second rule, Evocation | Mana is the mage's clock | Evocation 12051 (20, 8 min) | R8 for a low-mana glow | Pass | Slab, FSR, CR; low-mana glow on the gem medal, E4 (P3) |
| Blink, Frost Nova, Cone of Cold, Fire Blast / Ice Lance, Blast Wave, Cold Snap | Rotation and escape cooldowns | 1953; 122...; 120...; category 19 | R3 | Pass | CR |
| Threat | Pulling aggro | | | | THREAT; Ice Block on the rim |
| Polymorph on a crowd-control target | CC timer | 118, 12824-12826, 28270 | R1 on focus | Pass | Focus frame and plates; not a crest piece |
| Arcane Intellect, decursing | Group duties | 1459...; Remove Lesser Curse 475 | | | REM; group frames' dispel marks |

### Arcane adds

| Item | Why it matters | IDs | Route | Verdict | Covered by or seat |
| --- | --- | --- | --- | --- | --- |
| Arcane Wrath ready | Forever's 6 s Arcane nuke, scaling with maximum mana | 1326079 (25) | R3 | Pass | **Missing** -> right hip, the default choice (P2) |
| Presence of Mind, Arcane Power | Burst | 12043, 12042 | R1 | Pass | **Built**: rim |
| Clearcasting | | | | | **Built**: moment |

### Fire adds

| Item | Why it matters | IDs | Route | Verdict | Covered by or seat |
| --- | --- | --- | --- | --- | --- |
| **Fire Vulnerability stacks and time** | Scorch upkeep, five stacks: the Fire mage's maintenance debuff | 22959 (5 stacks; talent Improved Scorch 11095, 12872, 12873) | R1 + R1s on target `HARMFUL|PLAYER` ("from the Mage") | Pass | **Missing** -> right hip with five pips, E2 (P1) |
| **Your fire DoT** | Fire Power counts them; Ignite is the spec's engine | Ignite 412538 (talent 11119, 11120, 12846-12848); Pyroblast 11366, 12505, 12522-12526, 18809; Fireball 133, 143, 145, 3140, 8400-8402, 10148-10151, 25306 | R1 target `HARMFUL|PLAYER`, newest | Pass | FAN. **Missing as a seat** -> right foot (P2) |
| Combustion | Burst | 11129, 28682 | R1 | Pass | **Built**: rim |
| Frostfire Bolt DoT | Mixed school, not counted by Fire Power | 1237312 | | | FAN |

### Frost adds

| Item | Why it matters | IDs | Route | Verdict | Covered by or seat |
| --- | --- | --- | --- | --- | --- |
| **Winter's Chill stacks** | Builds the next Cone of Cold on Forever | 12579 (5 stacks; talent 11180, 28592-28595) | R1 + R1s on target `HARMFUL|PLAYER` | Pass | **Missing** -> right hip with five pips, E2 (P1) |
| Frozen target | Shatter, Ice Lance | as above | R1 | Pass | Left foot (all mages) |
| Ice Barrier, Frigid Power | Absorb and Frost damage | 11426...; 1326891 rides with it | R1 | Pass | **Built**: inner rim |
| Your chill on the target | Kiting: is my slow still on | Frostbolt 116, 205, 837, 7322, 8406-8408, 10179-10181, 25304; Cone of Cold 120, 8492, 10159-10161 | R1 target `HARMFUL|PLAYER` | Pass | FAN; optional right foot for Frost (P3) |
| Cold Snap, Ice Block | | 12472; 11958 | R3; R1 | Pass | CR; rim |

### Seat plan

| Seat | Arcane (default) | Fire (knows Improved Scorch) | Frost (knows Winter's Chill) | From level |
| --- | --- | --- | --- | --- |
| Crown | Arcane Blast shards | same | same | 20 |
| Left shoulder | Armor | same | same | 1 |
| Right shoulder | Mana gem (+ E4 low-mana glow, P3) | same | same | 28 |
| **Left hip** | Counterspell ready | same | same | 24 |
| **Right hip** | Arcane Wrath ready | Fire Vulnerability, 5 pips | Winter's Chill, 5 pips | 25; talents from 25 and 35 |
| **Left foot** | Frozen target | same | same | 10 |
| **Right foot** | (none) | Your fire DoT (Ignite first) | Your chill (P3) | talent 15 |
| Inner rim | Ward ring | same | Ward ring with Ice Barrier | 20 |
| Cooldown rim | Arcane Power, Presence of Mind, Evocation, Ice Block, racial | Combustion, Evocation, Ice Block, racial | Ice Block, Evocation, racial | 20 |
| Moment | Clearcasting | Clearcasting if talented | same | 15 (talent) |
| Top gem | not built: the crown and the row above cover the top | | | |

- The right hip and right foot are `choices` gated by talent ranks: Fire first (`known` = Improved Scorch ranks; the foot's `known` = Ignite ranks), Frost next (`known` = Winter's Chill ranks), Arcane Wrath last. A hybrid who knows both Fire and Frost talents gets Fire.
- **Arcane's right foot stays unbuilt**: an Arcane mage puts no debuff of its own on the target that changes a decision. That is the one seat I leave empty rather than fill with noise; if the owner wants it filled, the chill piece serves.
- **Priority** at 1080: Counterspell, spec hip, Frozen, then the right foot; E4 last.
- **Level bands**: 1 armor; 10 Frozen; 20 crown, wards, Evocation on the rim; 24 Counterspell; 25 Arcane Wrath (or a talent hip); 28 gem; 30 to 40 talents fill the rim.
- **Frames**: the hips and feet become medals in the row; the stack pips sit on the medal's rim there too.

### Add to the mage builder

1. `crestCounterspell`: `seat` left hip, `feed = "cooldown"`, `known = { 2139 }`. P1.
2. `crestFrozen`: left foot, `feed = "aura"`, `unit = "target"`, `filter = "HARMFUL|PLAYER"`, `spells = { 122, 865, 6131, 10230, 12494 }`, timer colour frost. P1.
3. `crestSchool`: right hip, `choices` = Fire Vulnerability 22959 with `stacks = 5` (`known` 11095, 12872, 12873); Winter's Chill 12579 with `stacks = 5` (`known` 11180, 28592-28595); Arcane Wrath 1326079 `feed = "cooldown"`. Needs E2. P1.
4. `crestFireDot`: right foot, Fire only (`known` Ignite ranks), `spells` = Ignite 412538, Pyroblast and Fireball ranks, `newest = true`. P2.
5. Racial families on `crestCooldowns` (section 7). P2.
6. E4 low-mana glow on the gem. P3.

## 7. Warlock

### Forever facts

- Talent tabs 302 Affliction, 303 Demonology, 301 Destruction. Forever's changes: **Banes and Curses are separate** ("only one Bane per Warlock", "only one Curse per Warlock"): Banes are Agony, Doom, Havoc; Curses are Weakness, Recklessness, Tongues, the Elements (440892 at 20, 1311676, 1311677, 1311680) and Exhaustion (talent). **Conflagrate is a trainer spell at 25** (1293817, 1293818) besides its talent ranks (17962, 18930-18932). **Spellstone and Firestone "enchant your weapon"** (Create Spellstone 2362, 17727, 17728 from 36; Create Firestone 6366, 17951-17953 from 28), so they are temporary weapon enchants. **Wrack** (1316697, 40) is a channel that speeds your Corruption, Siphon Life and Bane of Agony; **Soul Siphon** (17804) counts those three. Incinerate (1293812, 1293813) rewards Immolate.
- No tank spec (see the top). Demons tank while levelling: Voidwalker Torment 3716 and Suffering 17735 are pet-bar buttons.
- **Interrupt**: only the Felhunter's Spell Lock (19244 at 36, 19647 at 52; 30 s).

### All warlocks

| Item | Why it matters | IDs | Route | Verdict | Covered by or seat |
| --- | --- | --- | --- | --- | --- |
| Corruption, Bane, Immolate, Siphon Life on the target | The warlock's whole fight | Corruption 172, 6222, 6223, 7648, 11671, 11672, 25311; **Bane of Agony 980, 1014, 6217, 11711-11713**, Doom 603, Havoc 1225228; Immolate 348, 707, 1094, 2941, 11665, 11667, 11668, 25309; Siphon Life 18265, 18879-18881 | R1 target `HARMFUL|PLAYER` | Pass | **Built**: spires (`SlabRanged.lua:42-47`). **Fix: 1014 (Bane of Agony rank 2, level 18) is missing from the Bane spire** (`:44`) |
| Soul Shards | Spent by summons, Healthstones, Soul Fire | item 6265 | R2 | Pass | **Built**: wisps (`:48`) |
| Demon, health, Demonic Sacrifice | | summons 688, 697, 712, 713, 691; sacrifice 18789-18792 | R6, R1 | Pass | **Built**: left shoulder (`:49`) |
| Healthstone | | items 5509-5512, 9421, 19004-19013 | R2 | Pass | **Built**: right shoulder (`:50`) |
| Shadow Trance | Instant Shadow Bolt | 17941 (talent 18094, 18095) | R1 | Pass | **Built**: moment (`:52`) |
| Amplify Curse, Fel Domination, Shadow Ward | | 18288; 18708; 6229, 11739, 11740, 28610 | R1 | Pass | **Built**: cooldown rim (`:51`) |
| **Your Curse on the target** | Raid curse duty (Elements, Recklessness), Weakness and Tongues on casters; five-minute upkeep | Weakness 702, 1108, 6205, 7646, 11707, 11708; Recklessness 704, 7658, 7659, 11717; Tongues 1714, 11719; Elements 440892, 1311676, 1311677, 1311680; Exhaustion 18223 | R1 target `HARMFUL|PLAYER` | Pass | FAN. **Missing as a seat** -> left foot (P1) |
| **Conflagrate ready** | Consumes your Immolate for a burst; every warlock has it from 25 | 1293817, 1293818, 17962, 18930-18932 (category 672, 10 s) | R3, `Socket` `feed = "cooldown"` (refills, flares) | Pass | CR. **Missing at the crest** -> lower-right socket (P1) |
| **Weapon stone** | A missing Spellstone or Firestone is lost haste or crit | enchant slot MainHand; `known` Create Spellstone / Firestone ranks | **R5** | Pass | **Missing** -> lower-left socket, the rogue vial's piece (P1) |
| **Spell Lock ready** | The warlock's only interrupt | 19244, 19647 (pet spellbook) | R10: built only while `IsSpellKnown(id, Pet)`; the swipe needs `GetSpellCooldownDuration` to answer for a pet spell | **Pass if in-game check 7 holds**, else leave to the pet bar | FOCUS (opt-in), pet bar. **Missing** -> right foot (P2) |
| Voidwalker Sacrifice shield | The levelling warlock's emergency absorb | 7812, 19438, 19440-19443 (on the player) | R1 player | Pass | **Missing** -> cooldown rim family (P2) |
| Death Coil, Howl of Terror, Soul Fire, Shadowburn, Inferno, Fear, Banish | Cooldowns and CC | 17925 (2 min), 17928, 6353 / 17924, 17877, 1122 | R3 | Pass | CR; Fear and Banish on focus |
| Mana, Life Tap, health | | Life Tap 1454 ranks | | | Slab, FSR |
| Threat | | | | | THREAT |
| Demon Armor, Soul Link, Master Demonologist | Permanent while up | 706...; 25228; 23759-23762 | R1 | Pass | Buff row, REM; not seated |
| Soulstone on a friend | Out of combat | items 5232, 16892-16896 | R2 | Pass | Group frames, bags |

### Affliction adds

| Item | Why it matters | IDs | Route | Verdict | Covered by or seat |
| --- | --- | --- | --- | --- | --- |
| Siphon Life | Fourth DoT | 18265... | R1 | Pass | **Built**: spire |
| Nightfall | | 17941 | R1 | Pass | **Built**: moment |
| Curse of Exhaustion | Kiting | 18223 | R1 | Pass | Curse perch (left foot) |
| Wrack | Channel that speeds your DoTs | 1316697 | | | CAST; the spires burn faster while it runs |

### Demonology adds

| Item | Why it matters | IDs | Route | Verdict | Covered by or seat |
| --- | --- | --- | --- | --- | --- |
| Demonic Sacrifice | 30-minute buff from the demon | 18789-18792 | R1 | Pass | **Built**: demon medal |
| Fel Domination | Fast re-summon | 18708 | R1 | Pass | **Built**: rim |
| Soul Harvest mana regen | After a Drain Soul kill | 1242853 (from 437032) | R1 | Pass, low value | Rim family, optional (P3) |
| Soul Link | Permanent while the demon lives | 25228 | | | Not seated |

### Destruction adds

| Item | Why it matters | IDs | Route | Verdict | Covered by or seat |
| --- | --- | --- | --- | --- | --- |
| Conflagrate | | as above | R3 | Pass | Lower-right socket (all warlocks) |
| Shadowburn | Execute, shard on kill | 17877 (talent) | R3 | Pass | CR |
| Shadow Vulnerability | From Improved Shadow Bolt crits | 17794 | R1 | Pass, no decision to make | FAN |
| Apocalypse | Fire crits buff Shadow and back | talent 18096, 18073; the buff IDs are not in the tables | | **Reject** (no aura ID) | |

### Seat plan

| Seat | Affliction | Demonology | Destruction | From level |
| --- | --- | --- | --- | --- |
| Spires | Corruption, Bane, Immolate, Siphon Life | Corruption, Bane, Immolate | same | 1, 4, 8; Siphon Life talent 30 |
| Inner rim | Soul wisps | same | same | 10 |
| Left shoulder | Demon | Demon with Sacrifice | Demon | 1 |
| Right shoulder | Healthstone | same | same | 10 |
| **Lower left** | Weapon stone | same | same | 28 |
| **Lower right** | Conflagrate ready | same | same (the spec's key button) | 25 |
| **Left foot** | Your Curse | same | same | 4 |
| **Right foot** | Spell Lock ready, while a Felhunter is out | same | same | 36 |
| Cooldown rim | Amplify Curse, Shadow Ward, Sacrifice, racial | Fel Domination, Shadow Ward, Sacrifice, racial | Shadow Ward, Sacrifice, racial | 16 |
| Moment | Shadow Trance | (talent) | (talent) | 25 |
| Hips, top gem | not built: the lower sockets take the hips' place, the spires the top | | | |

- The warlock uses the **lower-ring sockets** (`SEATS.lowerLeft`, `lowerRight`), not the hips, so the stone is the same jewel as the rogue's poison vial (one consistent style).
- **Priority** at 1080: Curse, Conflagrate, stone, then Spell Lock.
- **Level bands**: 1 Immolate spire and demon; 4 Corruption and the Curse perch; 8 Bane; 10 wisps and Healthstone; 16 Sacrifice on the rim; 20 Curse of the Elements; Shadow Ward joins the rim once trained (its rows carry no level); 25 Conflagrate; 28 stone; 36 Spell Lock; 60 Bane of Doom in the Bane spire.
- **Frames**: two more medals and two vials in the row, as the rogue's.

### Add to the warlock builder

1. **Fix**: add 1014 to the Bane spire's spells (`SlabRanged.lua:44` at `88a9f07f3`). P1.
2. `crestCurse`: left foot, `feed = "aura"`, `unit = "target"`, `filter = "HARMFUL|PLAYER"`, the Curse IDs above. P1.
3. `crestConflagrate`: `seat = "lowerRight"`, `Socket` with `feed = "cooldown"`, `known` = Conflagrate ranks. P1.
4. `crestStone`: `seat = "lowerLeft"`, `feed = "enchant"`, `slot = "MainHand"`, `known` = Create Spellstone and Create Firestone ranks (the rogue's poison row, `SlabTrackers.lua` at `e4333eb4a`). P1.
5. Add `{ spells = { 7812, 19438, 19440, 19441, 19442, 19443 } }` to `crestCooldowns`. P2.
6. `crestSpellLock`: right foot, `feed = "cooldown"`, `known = function` returning 19647 or 19244 when `C_SpellBook.IsSpellKnown(id, Enum.SpellBookSpellBank.Pet)`; repaint on `UNIT_PET`. Only after in-game check 7. P2.

## 8. Cross-class

| Item | IDs | Route | Verdict | Covered by or seat |
| --- | --- | --- | --- | --- |
| **Racial buffs while active** | Berserking 20554 (troll), Blood Fury 20572 (orc), Stoneform 20594 (dwarf), Will of the Forsaken 7744 (undead; the owner's warlock), Perception 20600 (human), Escape Artist 20589 (gnome); Skyborne Energized 1270842 (Read Leyline) and Elemental Blessing 1259688 (Skysight) | R1 player, one `CooldownRim` family each with `known` = the racial spell | Pass | **Add once to every class's rim** (P2). Readiness stays on CR |
| Trinket on-use buffs | Any item; not enumerable | | | CR (All trinkets) |
| Potion and Healthstone cooldowns | shared category | R2 | Pass | CONS, CR; the warlock's Healthstone medal |
| Flasks, elixirs, food | | | | REM, buff row |

## 9. Rejected

- **Any Lua read or compare of an aura, a stack count, a power value or a threat value** (`SecretWhenUnitAuraRestricted`, `SecretWhenUnitPowerRestricted` `Docs/UnitDocumentation.lua:2732-2735`, `SecretWhenUnitThreatStateRestricted` `:3279-3282`).
- **Enemy buffs by spell ID** (Tranquilizing Shot's Frenzy): refused at `Blizzard_AuraContainerUtil.lua:82`.
- **Runes and absent spells**: Kill Command, Lock and Load, Flanking Strike, Chimera Shot, Steady Shot, Readiness; Fingers of Frost, Hot Streak, Brain Freeze, Missile Barrage, Living Bomb, Icy Veins, Arcane Surge, every mage heal; Haunt, Chaos Bolt, Unstable Affliction, Shadowflame, Invocation, Metamorphosis and the warlock tank kit (all `AcquireMethod 3`); Wyvern Sting and Silencing Shot (no learnable row).
- **Aura IDs the tables do not have**: The Beast Within's player buff, Apocalypse's two buffs.
- **"About to expire" pulses**: depend on a refresh carry-over Forever likely lacks (`../ranged/REPORT.md` section 2).
- **A layout switch by Aspect**: Aspects are auras, secret to Lua in combat.

## 10. In-game checks before the build

1. **Stacks on a target medal (E2)**: three Scorches, then confirm five application bars on a `HARMFUL|PLAYER` slot fill one by one in combat (the crowns prove the route on the player and for Sunder on the target).
2. **Frozen**: Frost Nova a mob in combat and in a dungeon; the left-foot slot lights and drains; Frostbite procs light it too.
3. **`PLAYER_SWING` for Auto Shot**: `/etrace PLAYER_SWING` while shooting; `swingType` 2 and a plain `swingDuration` each shot.
4. **Lacerate, Black Arrow, Heart of the Lion**: does a hunter trainer sell them, at what level (`ClassMask 0` or `BaseLevel 0` in the tables)?
5. **Ammo**: `/dump UnitUsesAmmo("player"), GetInventoryItemCount("player", 0)` in combat.
6. **Enrage dispel type**: `/dump` a frenzied mob's buff `dispelName` out of combat; if it has one, `includeDispelTypes` can light a Tranquilizing Shot cue.
7. **Spell Lock**: with a Felhunter out, `/dump C_SpellBook.IsSpellKnown(19647, Enum.SpellBookSpellBank.Pet)` and `/dump C_Spell.GetSpellCooldownDuration(19647)` after a cast, in combat.
8. **Weapon stone as an enchant**: with a Spellstone applied, `/dump C_PaperDollInfo.GetTemporaryEnchantmentInfo(16)` in combat (the rogue poison check covers the route).
9. **Conflagrate trainer rank**: confirm a level 25 warlock of any talent build trains 1293817.

## 11. Method

Scratch only, in `%TEMP%\orca-ctx_a0fd9335904a\`: `q.py` (table lookups) and the copied `db2/` tables. No repository file was changed; this worktree's `git status` is clean.
