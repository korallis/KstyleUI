# The crest tracks more: Hunter, Mage, Warlock (design study, no code)

Task `task_afadc59c7540`, 2026-11-23. Base `b1f25c6a9` (staging). Research, two concepts per class, concept sheets and one GIF per class. No addon code, no commit, no PR, nothing posted.

## Recommendation in one table

| Class | Recommended concept | What the crest tracks (new) | Already shipped, kept |
| --- | --- | --- | --- |
| Hunter | **A, The Hunt** | Aspect medal on the left hip; pet medal (happiness, health, Mend Pet) on the right hip; Hunter's Mark and Serpent Sting on the target as two small timer perches at the foot; a gust across the crest on Quick Shots and Rapid Fire | Sniper Shot arrows (crown), hawk perches (shoulders) |
| Mage | **A, Arcanist's Regalia** | Armor spell medal with its time left on the left shoulder; mana gem (ready, cooling, none) on the right shoulder; a ward ring on the inner rim for Ice Barrier, Mana Shield and the wards; the rune ring blazing on Clearcasting | Arcane Blast shards (crown) |
| Warlock | **A, Torments and Soul Wisps** | Corruption, Bane, Immolate and Siphon Life on the target as four spires that burn down, each on a small socket; Soul Shards in the bags as soul wisps circling the emblem; demon medal (present, health, sacrifice) on the left shoulder; Healthstone (ready, cooling, none) on the right shoulder; the ring burning violet on Shadow Trance | Nothing: the shard jewels read a power type Forever does not have (see Warlock) |

Every piece is fed by one of four routes that are already proven in the shipped crest (section 2). Nothing here needs Lua to compare a secret.

## 1. Files

All in `C:/Users/leeba/.cache/kstyleui-evidence/crest-trackers/ranged/`.

| File | What it shows |
| --- | --- |
| `hunter-sheet.png`, `mage-sheet.png`, `warlock-sheet.png` | The concept sheet per class: A at rest, A in a fight (with callouts), A's moment, and B |
| `<class>-A-rest.png`, `<class>-A-fight.png`, `<class>-A-moment.png`, `<class>-B.png` | The same stills at 3x (1560 by 840), for judging detail |
| `hunter-A-moment.gif` | 7 s: Hunter's Mark lands, Serpent Sting lands and drains, Quick Shots gusts across the crest, the pet is hurt and mended, the Sting runs out |
| `mage-A-moment.gif` | 7.4 s: Arcane Blast builds to four, Clearcasting blazes and is spent, the mana gem is used and cools, a ward goes up and drains |
| `warlock-A-moment.gif` | 8 s: three DoTs and Siphon Life land and burn down, Shadow Trance, a shard is spent, a soul flies in, Corruption gutters out |

How the pictures were made, and their limits:

- **The HUD is real, the new pieces are composites.** Each picture starts from `Tools/render/shoot.sh hud_<class>_mac` at 1920x1080 (`RENDER_SIZE=auto`, `RENDER_LAYOUT=DPS`, `--ppu 1`, `--strict`, exit 0). The new pieces are drawn over it with PIL at 4x and resolved to 1x, then the crop is enlarged 3x, so every piece has the pixels it would have at 1080.
- **Art is shipped art, used as stand-ins.** Spires, shards and arrows are `Media/Textures/Pips/*`; bursts, ring glyphs and halos are `Media/Textures/Medallions/Burst*`, `RuneGlyphs`, `Ambient*`; icons are the set B repaints. Medal rims, timer rings, soul wisps and the gust are procedural. Judge placement, size and behaviour, not final art. Higgsfield was not used; no credits were spent and nothing left this machine.
- **Backdrops are real game scenery, cropped.** UI-free 1600x900 crops of `game_04` (hunter), `game_02` (mage) and `game_09` (warlock), scaled 1.2x to 1920x1080.
- **Hunter base:** `RENDER_FX=hawks RENDER_FX_T=12`, so both shipped hawk perches are lit. The fixture hunter does not know Sniper Shot, so the three arrows are drawn from their shipped art at the crown's place.
- **Mage base:** the fixture mage does not know Arcane Blast, so the four shards are drawn from their shipped art.
- **Warlock base:** rendered with the crest jewels off. That took one temporary line in `Tools/render/scenes/_common.lua` (`crestJewels = false`), reverted straight after; `git status` is clean.
- **Timers in the GIFs are shortened** so a story fits in 8 s. A real Serpent Sting lasts 15 s and a real Corruption 18 s.
- **Only Medallions at 1920x1080 was drawn.** Frames is described per class, not drawn. 2560x1440, 5120x1440 and 3840x2160 are reasoned from anchors.

## 2. The four routes (all proven in the shipped crest)

Paths are under `C:/Users/leeba/.cache/wow-ui-source/Interface/AddOns` at `9dc84f0` (1.60.1.70862).

| Route | What it gives | Proof | Shipped use |
| --- | --- | --- | --- |
| **R1. Blizzard aura slot** | For one aura picked by spell ID: shown or hidden, its icon, a timer swipe, a timer bar, a stack bar, and animations on first show and on assignment. Blizzard's untainted code does every comparison. | `Blizzard_AuraContainer/Blizzard_CustomAuraContainer.lua:417` (`AddAuraSlot`); `Blizzard_CustomAuraButton.lua:68-77` (`SetApplicationBar`), `:159-168` (`SetDurationCooldown`), `:224-233` (`SetDurationBar`), `:243-250` (`SetIcon`), `:314-317`, `:327-330` (animations), `:598-623` (the swipe and bar are fed the aura's duration object), `:694-705` (visibility) | `Core/Widgets/ClassPip.lua:262-282` (crowns), `KstyleUI_ActionBars/SlabStorm.lua:109, 206-216` (storm orbs) |
| **R2. Plain bag and item values** | Item counts and item cooldowns are ordinary numbers; Lua may compare them. | `Blizzard_APIDocumentationGenerated/ItemDocumentation.lua:451-468` (`C_Item.GetItemCount`), `:434-449` (`C_Item.GetItemCooldown`); neither carries a `SecretReturns` or `SecretWhen*` flag. `ContainerDocumentation.lua:675-677` (`BAG_UPDATE_DELAYED`) | `KstyleUI_ActionBars/Consumables.lua` |
| **R3. Pet unit** | Whether the pet exists, its portrait, its happiness, and its health as a bar. | `UnitDocumentation.lua:1192-1205` (`UnitExists`, no secret flag), `:572-574` (`SetPortraitTexture`), `:4449-4457` (`UNIT_PET`), `:4288-4296` (`UNIT_HAPPINESS`); `PetInfoDocumentation.lua:35-45` (`C_PetInfo.GetPetHappiness`, no secret flag). `UnitHealth` is `SecretReturns` (`UnitDocumentation.lua:1526-1529`), so health goes straight into a StatusBar and is never read. | The pet unit frame |
| **R4. Cooldown flags** | Whether a spell is on a real cooldown: `isActive` and `isOnGCD` are `NeverSecret`; the swipe takes the duration object. | `SpellSharedDocumentation.lua:25-30`; `SpellDocumentation.lua:327-343` (`C_Spell.GetSpellCooldownDuration`) | `KstyleUI_Cooldowns/Mirror.lua:141-167, 471` (ready glow) |

Which auras R1 may pick by spell ID (`Blizzard_AuraContainer/Blizzard_AuraContainerUtil.lua`):

- Helpful auras on the player, a group member **or their pets**: always (`:68-72`). This covers every self-buff here and Mend Pet on the pet.
- Harmful auras on a unit the player cannot assist, such as an enemy target: allowed (`:76-80`, `:101-104`). This covers Hunter's Mark, the Stings and every warlock DoT. The filter `"HARMFUL|PLAYER"` keeps it to your own.
- Harmful auras on friendly units: refused (`:78-80`, `:106-110`). Nothing here needs them.

Two limits that shape the designs:

1. **A piece fed by R1 lives under its slot button**, which hides when the aura is gone (`Blizzard_AuraContainerUtil.lua:329-333`, `Blizzard_CustomAuraButton.lua:694-705`). So the dormant art sits on the crest and the lit art in the slot, exactly as the crowns and storm orbs do.
2. **There is no engine signal for "about to run out".** Blizzard's pandemic animations (`Blizzard_CustomAuraButton.lua:256-310, 728-810`) fire only when `C_UnitAuras.GetRefreshCarryOverDuration` reports a carry-over (`Blizzard_AuraContainerUtil.lua:13-28`; `UnitAuraDocumentation.lua:414-420`). Classic rules have no carry-over, so I expect it to be nil on Forever (in-game check 3). The designs therefore show time as a draining swipe or spire and promise no "refresh now" pulse. The last-fifth flicker stays what it is on the Spirit Poles: only while the value is readable.

Client data: `SkillLineAbility`, `Talent`, `TalentTab`, `SpellCooldowns`, `SpellReagents`, `SpellLevels` and `SpellClassOptions` exported read-only from the installed `wowf` client **1.60.1.71037** with the repository's `Tools/icons/casc_export.py`; `SpellName`, `Spell`, `SpellEffect`, `SpellAuraOptions`, `SpellMisc` and `ItemSparse` from the identical earlier export in `~/.cache/kstyleui-evidence/parity-qol-r5/db2/`. All three classes have the Classic talent trees (16 or 17 talents per tree, 31-point capstones). Rune spells are `AcquireMethod = 3` and unlearnable, as the class-crowns report found.

## 3. Hunter

### What a hunter watches

| Candidate | IDs (Forever 1.60.1) | Level or talent | Route | Verdict |
| --- | --- | --- | --- | --- |
| **Aspect** (which one, or none) | Hawk 13165, 14318-14322, 25296; Monkey 13163; Cheetah 5118; Pack 13159; Wild 20043, 20190; Beast 13161, 1299445-1299447; Viper 415423; Falcon 469145 | Monkey 4, Hawk 10, Cheetah 20, Beast 30, Pack 40, Wild 46; Viper and Falcon are trainer spells on Forever (`AcquireMethod 0`) | R1, helpful on the player: one slot with every Aspect ID, `SetIcon` | **Pass.** Aspects are auras, not stance-bar forms (none is in `SpellShapeshiftForm`) |
| **Pet** (present, happiness, health) | none; Mend Pet 136, 3111, 3661, 3662, 13542-13544 | Pet at 10, Mend Pet 12 | R3; Mend Pet's heal on the pet through R1 (helpful on your pet) | **Pass.** Happiness is real on Forever: the client's `PowerType` has Happiness and Feed Pet 6991 is trained |
| **Hunter's Mark on the target** | 1130, 14323, 14324, 14325 | 6 | R1, `"HARMFUL"` on the target (any hunter's Mark helps you) | **Pass** |
| **Sting on the target** | Serpent 1978, 13549-13555, 25295; Viper 3034, 14279, 14280; Scorpid 3043 | Serpent 4 | R1, `"HARMFUL|PLAYER"` on the target; one slot, since "only one Sting per Hunter" | **Pass** |
| **Quick Shots** (haste proc) | 6150; Quick Strikes 1299448 (Beast) and 469144 (Falcon) | Talent Deadly Aspects 19552-19556 (Beast Mastery, first row) | R1, helpful on the player, `AddAuraShownAnimation` | **Pass.** Nothing without the talent |
| **Rapid Fire** up | 3045 | 26 | R1 for the buff; its cooldown is already on the cooldown row above the crest | **Pass** as a buff; not repeated as a cooldown |
| Ammo left | ammo slot, `GetInventoryItemCount("player", 0)` | where `UnitUsesAmmo` | Plain count, as Blizzard's own slot shows it (`Blizzard_UIPanels_Game/Camelot/PaperDollFrame.lua:1517, 2185`); not in the generated docs | **Pass with a check** (in-game check 5). Used in concept B only |
| Mongoose Bite, Counterattack ready | 1495 and ranks; 19306 and ranks | 16; Survival talent | `C_Spell.IsSpellUsable` has no secret flag (`SpellDocumentation.lua:980-995`) | Possible, but melee-only and niche. Left out |
| Sniper Shot shots, hawks | 1310687 and ranks; 1293241 and ranks | 40; 25 | shipped | Kept as they are |
| Kill Command, Flanking Strike, Lock and Load, Cobra Strikes | 409379, 415320 and others | runes | none | **Rejected**: unlearnable |
| Frenzy on the pet | 19615 | Beast Mastery talent | R1 on the pet | Works, low value. Left out |
| Trap and Feign Death cooldowns | 1499, 13795, 5384 and ranks | trainer spells | R4 | Already on the cooldown row. Left out |

A low-level hunter sees the pieces arrive in order: the Sting perch at 4, the Aspect medal at 4 (Monkey), the Mark perch at 6, the pet medal at 10. Before a spell is known its piece is not drawn at all.

### A. The Hunt (recommended)

The hawks keep the shoulders, so the new medals take the **hips**, and the crest becomes a compass of four round perches around the emblem. Round with a draining ring already means "a timed thing" on this crest (the hawks).

| Piece, as a player would say it | Where | States |
| --- | --- | --- |
| **Aspect medal on the left hip** | On the ring at about 8 o'clock, 24 px | The icon of the Aspect that is up. Grey steel when none is up, which is the reminder. A change of Aspect flares the medal. |
| **Pet medal on the right hip** | About 4 o'clock, 24 px | The pet's portrait. The rim is green, amber or red for happy, content, unhappy. The portrait darkens red from the top as the pet loses health. Grey steel when there is no pet or it is dead. A green pulse while Mend Pet is on it. |
| **Hunter's Mark at the left foot** | Beside the level plaque, 17 px | Lit with a red timer ring that drains while your target carries the Mark. Dark when it does not. |
| **Sting at the right foot** | Beside the level plaque, 17 px | Lit with a green timer ring that drains over the Sting. Shows whichever Sting you used. Dark when the target has none. |
| **The moment: Quick Shots** | Whole crest | Feather-thin streaks gust across the crest and the rune ring glows hunter green while the haste lasts. Rapid Fire uses the same glow. |

Why it reads: the two things a hunter forgets (Aspect, pet) are the two biggest new pieces and both go grey when wrong. The target's two debuffs sit together at the foot, so one glance answers "is this target set up". Nothing is shown twice: cooldowns stay on the cooldown row.

Frames: no crest, so the four perches stand in a forged row at the stance bar's place beside the tray, in the order Aspect, pet, Mark, Sting, sized as its buttons, as the Spirit Poles row does. The gust becomes a glint along that row.

### B. Quiver and Coil

- An ammo **quiver on the left hip** whose rim turns red when ammo runs low.
- The **Aspect tints the rune ring**: green for Hawk, amber for Cheetah, teal for Viper, dull for none.
- The pet medal on the right hip, as in A.
- Hunter's Mark and the Sting as **two draining arcs** on the ring's lower band, Mark on the left, Sting on the right.

It is quieter and has fewer pieces, but a tinted ring cannot say "no Aspect" as plainly as a grey medal, the arcs are 3 px thin at 1080, and the ring tint competes with the ring glow that hawks, crowns and procs already use.

**Recommendation: A.**

## 4. Mage

### What a mage watches

| Candidate | IDs | Level or talent | Route | Verdict |
| --- | --- | --- | --- | --- |
| **Armor spell** (up, which, time left) | Frost Armor 168, 7300, 7301; Ice Armor 7302, 7320, 10219, 10220; Mage Armor 6117, 22782, 22783 | 1, 30, 34 | R1, helpful on the player; `SetIcon` and `SetDurationCooldown` | **Pass.** "Only one type of Armor spell can be active" |
| **Mana gem** (have one, ready, cooling) | items 5514 Agate, 5513 Jade, 8007 Citrine, 8008 Ruby; conjured by 759, 3552, 10053, 10054 | 28, 38, 48, 58 | R2 | **Pass.** Each is unique (`MaxCount 1`) |
| **Shield up and time left** | Ice Barrier 11426, 13031-13033; Mana Shield 1463, 8494, 8495, 10191-10193; Fire Ward 543, 8457, 8458, 10223, 10225; Frost Ward 6143, 8461, 8462, 10177, 28609 | Ice Barrier is the Frost capstone talent; Mana Shield 20; wards 20 and 22 | R1, helpful on the player; a Cooldown swipe on a ring | **Pass** for "up and how long". The amount left on the absorb is not shown |
| **Clearcasting** | 12536 | Talent Arcane Concentration 11213, 12574-12577 (Arcane, second row) | R1, `AddAuraShownAnimation` | **Pass.** Nothing without the talent |
| Arcane Blast stacks | 400573 | 20 | shipped crown | Kept |
| Fire Vulnerability, Winter's Chill on the target | 22959; 12579 | Talents Improved Scorch 11095, Winter's Chill 11180 | R1 stack bar on the target | **Pass**; used in concept B |
| Combustion | 28682 (stacks to 10), 11129 (3 charges) | Fire capstone | R1 | Works; a 3-minute cooldown, low value day to day. Left out |
| Arcane Intellect up | 1459, 1460, 1461, 10156, 10157; Brilliance 23028 | 1 | R1 | Works. Left out to hold the crest at four pieces; a natural later stud under the armor medal |
| Counterspell, Evocation, Blink, Ice Block ready | 2139, 12051, 1953, 11958 | 24, 20, 20, talent | R4 | Already on the cooldown row. Left out |
| Reagents (Arcane Powder 17020, Runes 17031 and 17032, Light Feather 17056) | items | | R2 | Out-of-combat stock, not a glance in a fight. Left out |
| Fingers of Frost, Hot Streak, Missile Barrage, Icy Veins, Arcane Surge, Living Bomb | runes | | none | **Rejected**: unlearnable |

A level 1 mage already has the armor medal (Frost Armor). The ward ring arrives at 20, the gem at 28, the shards at 20.

### A. Arcanist's Regalia (recommended)

| Piece | Where | States |
| --- | --- | --- |
| **Armor medal on the left shoulder** | Where the shaman's Ghost Wolf medal sits, 24 px | The icon of the armor that is up, ringed by its 30 minutes draining. Grey steel when no armor is up. A flare when it is cast. |
| **Mana gem on the right shoulder** | Where the shaman's Call medal sits, 24 px | The gem lit and glowing when one is in the bags and ready. Greyed with a draining ring while its cooldown runs. An empty dark setting when you have none: conjure one. |
| **Ward ring on the inner rim** | A 3 px band inside the rune ring | Pale frost light all the way round when a shield or ward goes up, draining clockwise over its duration. Nothing when no shield is up. |
| **The moment: Clearcasting** | Whole crest | A burst, then the rune glyphs blaze and an arcane halo turns on the rim until the free spell is cast. |

Why it reads: the crown stays the mage's damage read (Arcane Blast). The shoulders hold the two things kept ready between fights. The inner rim holds the one short timer a mage must not miss in a fight. Clearcasting is the brightest thing the crest ever does, because it is the one a mage acts on at once.

Frames: armor medal and gem medal in the stance bar's place beside the tray; the ward ring becomes a thin frost bar along the top edge of the player frame's class row, where the shards already sit; Clearcasting lights the class row.

### B. School Crown

- **The crown follows your talents**: five embers for Fire Vulnerability (Improved Scorch) or five ice shards for Winter's Chill on the target, Arcane Blast shards otherwise.
- **Your armor tints the rune ring** frost blue or arcane violet, dull when missing.
- **A ward dome** arcs over the top of the emblem while a shield is up.

It gives fire and frost mages a crown of their own, which A does not. But both stack crowns are empty with no target and nothing without the talent, the ring tint has the same weakness as the hunter's, and the mana gem has no home. The school crowns are better as a follow-up to the shipped crown than as this piece of work.

**Recommendation: A**, with B's school crowns noted as a separate, later crown task.

## 5. Warlock

### What exists today

`KstyleUI_ActionBars/SlabJewels.lua:20-24` lights the warlock's jewels from `UnitPower(..., SoulShards)`. Forever has no such power type (the client's `PowerType` table holds only Mana, Rage, Focus, Energy, ComboPoints and Happiness; class-crowns report, "Facts" point 2). The harness draws three lit jewels because its stub supplies the power; a warlock in the game should see five dark jewels or none. So the warlock is the class with the least on its crest, and the recommended concept replaces those jewels.

### What a warlock watches

| Candidate | IDs | Level or talent | Route | Verdict |
| --- | --- | --- | --- | --- |
| **DoTs on the target, with time left** | Corruption 172, 6222, 6223, 7648, 11671, 11672, 25311; Bane of Agony 980, 6217, 11711-11713; Bane of Doom 603; Bane of Havoc 1225228; Immolate 348, 707, 1094, 2941, 11665, 11667, 11668, 25309; Siphon Life 18265, 18879-18881 | Immolate 1, Corruption 4, Agony 8, Doom 60, Havoc is a Forever trainer spell; Siphon Life is an Affliction talent | R1, `"HARMFUL|PLAYER"` on the target; `SetIcon` and `SetDurationBar` per spire | **Pass.** On Forever Agony, Doom and Havoc are **Banes** ("only one Bane per Warlock") and share one spire |
| **Soul Shards** | item 6265 | Drain Soul at 10 | R2: `C_Item.GetItemCount(6265)` | **Pass.** Plain number, so the full gain and spend animation is honest |
| **Demon** (present, health) | summons 688, 697, 712, 713, 691 | Imp at 1 | R3. Which demon it is comes from the engine-drawn portrait; `UnitCreatureFamily` is `SecretWhenUnitIdentityRestricted` (`UnitDocumentation.lua:996-999`) and is not read | **Pass** |
| Demonic Sacrifice | 18789, 18790, 18791, 18792 | Demonology talent 18788 | R1, helpful on the player; shown on the demon medal | **Pass** |
| **Healthstone** (have one, ready, cooling) | items 5512, 19004, 19005, 5511, 19006, 19007, 5509, 19008, 19009, 5510, 19010, 19011, 9421, 19012, 19013 | Create Healthstone at 10 | R2 | **Pass.** Each is unique |
| **Shadow Trance** (Nightfall) | 17941 | Affliction talent Nightfall 18094, 18095 | R1, `AddAuraShownAnimation` | **Pass.** Nothing without the talent |
| Demon Skin, Demon Armor up | 687, 696; 706, 1086, 11733-11735 | 1, 20 | R1 | Works. Left out to hold the crest at four pieces; a 30-minute buff the buff row already shows |
| Curse on the target | Weakness 702 and ranks, Recklessness 704 and ranks, Tongues 1714, 11719, Exhaustion 18223 | | R1 | Works. Not given a spire: curses last minutes, and a fifth spire crowds the crown |
| Spellstone, Firestone on the weapon | items 5522, 13602, 13603; 1254, 13699-13701 | 36, 28 | `C_Item.GetWeaponEnchantInfo` (`ItemDocumentation.lua:1141-1154`, structure `:1968-1979`), no secret flag | Possible on Forever, where both "enchant your weapon". Left out; a later missing-stone mark |
| Soulstone | items 5232, 16892, 16893, 16895, 16896 | 18 | R2 | Works. Left out |
| Conflagrate, Shadowburn, Death Coil ready | 17962 and ranks, 17877 and ranks, 6789 and ranks | talents; 42 | R4 | Already on the cooldown row. Left out |
| Shadow Vulnerability on the target | 17794 | Destruction talent | R1 | A single debuff, no stacks. Left out |
| Fel Armor, Metamorphosis, Haunt, Unstable Affliction, Chaos Bolt, Backdraft | runes | | none | **Rejected**: unlearnable |

A level 1 warlock has the Immolate spire and the demon medal. Corruption joins at 4, the Bane at 8, soul wisps and the Healthstone at 10.

### A. Torments and Soul Wisps (recommended)

This is the Spirit Poles and the storm orbs, retold for the warlock: timers stand on the crown as spires, a count circles the emblem.

| Piece | Where | States |
| --- | --- | --- |
| **Torment spires** | Four spires fanned over the top of the ring, each on a 17 px socket: Corruption, Bane, Immolate, Siphon Life | The socket shows the spell's icon, dim until yours is on the target. The spire lights in the spell's colour (sickly green, violet, fire, blood red) and **burns down** over the DoT's life, then goes back to dark steel. The Bane socket shows whichever Bane you used. The Siphon Life spire stands only for warlocks with the talent. |
| **Soul wisps** | Five seats on the inner rim, circling the emblem | One violet wisp per Soul Shard in your bags, up to five. A spent shard bursts with a small bolt. A gained one flies in from the target's side and settles. With five or more the rim keeps a faint violet light. |
| **Demon medal on the left shoulder** | 24 px | Your demon's portrait, darkening red from the top as it loses health. Grey steel when you have no demon. After Demonic Sacrifice it shows the sacrifice's icon with a burning rim. |
| **Healthstone on the right shoulder** | 24 px | The green stone lit when one is in the bags and ready. Greyed with a draining ring on cooldown. An empty dark setting when you have none: make one. |
| **The moment: Shadow Trance** | Whole crest | A violet burst, then a dark-flame halo burns on the rim until the instant Shadow Bolt is cast. |

Why it reads: DoT timers are what a warlock watches every second, so they get the largest, most readable place and the proven spire mechanic. A dark spire is a missing DoT, seen from the corner of the eye. Shards are a count, so they take the storm orbs' place. The two shoulders hold the two things prepared before a fight.

Why Lua may count shards here: unlike Lightning Shield's charges, the shard count is a plain bag number, so the wisps need no engine bar and no guessing.

Frames: the four sockets stand in a forged row at the stance bar's place with their spires upright, as the Spirit Poles row does, followed by the demon and Healthstone medals; the wisps become five soul pips in the player frame's class row; Shadow Trance lights that row.

### B. Reliquary

- **Soul Shards as the crown**: five shard crystals, the crown look approved on 2026-11-21 and then dropped for want of a source.
- **The four torments as small timer medals** at the hips and feet, each with a draining ring.
- Demon medal and Healthstone on the shoulders, as in A.

It is the smaller build and keeps the approved crown. But it gives the best place to the count a warlock rarely needs in a fight, and the DoT timers shrink to 18 px rings at the bottom of the screen, under the ring and next to the level plaque.

**Recommendation: A.**

## 6. Fit and crowding

Measured on the 1080 renders: hub centre (960, 987), rune ring outer radius 68 px, inner rim 53 px, level plaque at 6 o'clock.

| Zone | Shaman (shipped) | Hunter A | Mage A | Warlock A |
| --- | --- | --- | --- | --- |
| Crown, above the ring | Totem sockets and spires | Sniper Shot arrows (shipped) | Arcane Blast shards (shipped) | Torment sockets and spires |
| Shoulders, about 10 and 2 o'clock | Ghost Wolf, Call | Hawk perches (shipped) | Armor, mana gem | Demon, Healthstone |
| Hips, about 8 and 4 o'clock | free | Aspect, pet | free | free |
| Foot, beside the plaque | free | Mark, Sting | free | free |
| Inner rim | Storm orbs | free | Ward ring | Soul wisps |
| Whole ring, for the moment | All four totems up | Quick Shots gust | Clearcasting | Shadow Trance |

- Each class adds four tracked pieces and one moment. No zone holds two things.
- The cooldown row's bottom edge is about 148 px above the hub centre. The tallest pieces, the warlock's spires, reach about 127 px at their tips, leaving about 21 px at 1080. That is the Spirit Poles' tight spot again and needs the same clearance test at all four screen sizes.
- The crest debuff fan (`KstyleUI_UnitFrames/Fan.lua`) defaults to the row above the spires and is not reached.
- The hunter's hip medals sit over the bottom corner of the action slab and end a few pixels from the strip below it at 1080. That is the one joint to judge in the 3x still (`hunter-A-fight.png`).
- Every piece is placed by angle and radius from the hub centre, so it scales with the hub at 2560x1440, 5120x1440 and 3840x2160 and in Centred and Spread.

Settings, to match the toggle rule: one setting per class under Action Bars > Slab and cooldowns, on by default, off restores today's crest pixel for pixel. Motion follows Appearance > Motion: Full plays the gust, halos and wisp orbit, Calm holds them still, Off shows end states.

## 7. In-game checks before any build

None of these can be answered offline.

1. **Stings and DoTs through a target container in combat.** Cast Serpent Sting and Corruption on a hostile target in combat and in a dungeon, and confirm a `"HARMFUL|PLAYER"` aura slot with `includeSpellIDs` shows and drains. The crowns' Sunder Armor and Lacerate use the same route, so this is expected to pass.
2. **A duration bar on an aura slot.** `SetDurationBar` is not used anywhere in KstyleUI yet (`SetApplicationBar` and the totem slots' own duration objects are). The warlock's spires depend on it.
3. **Carry-over.** `/dump C_UnitAuras.GetRefreshCarryOverDuration("target", <Corruption's auraInstanceID>)` out of combat. If Forever does report one, the spires and perches can gain a free, engine-driven "refresh now" pulse.
4. **Pet helpful auras.** Confirm a helpful slot on `"pet"` shows Mend Pet in combat (`Blizzard_AuraContainerUtil.lua:68-72` says a group member's pet passes; the player's own pet should).
5. **Ammo.** `/dump UnitUsesAmmo("player"), GetInventoryItemCount("player", 0)` on a hunter. Only concept B needs it.
6. **Item cooldowns in combat.** `/dump C_Item.GetItemCooldown(8008)` and a Healthstone ID in combat, to confirm the numbers stay readable as the docs say.
7. **Aspect IDs.** Confirm Viper 415423 and Falcon 469145 are trained on Forever as the data says, and that each Aspect's aura carries its cast ID.
8. **Shard count event.** Confirm `BAG_UPDATE_DELAYED` fires promptly on a Drain Soul shard and a Shadowburn spend, so the wisp animations land with the spell.

## 8. Build order, if approved

Each class is one PR, in this order of value against risk:

1. **Warlock A**: the class with nothing today, and the largest new mechanic (duration bars), which is best proven first.
2. **Hunter A**: all four pieces use routes the hawks and crowns already ship.
3. **Mage A**: the smallest; it reuses the medal and ring pieces the first two bring.

The medal (icon, rim, optional timer ring, grey when off) is one shared widget for all three classes and the shaman's shoulder medals; build it once in the first PR.
