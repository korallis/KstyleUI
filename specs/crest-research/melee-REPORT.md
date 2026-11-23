# The crest tracks more: Warrior, Paladin, Rogue (design study, no code, no PR)

Task `task_82ce6f8ef311`, 2026-11-23. Base `b1f25c6a9` (staging). Nothing was committed, pushed or posted.

## Recommendation, one line per class

| Class | Recommended concept | What the crest tracks (crown first) |
| --- | --- | --- |
| Warrior | **A, War Drums** | Sunder Armor banners (today's crown), **Battle Shout timer on the left shoulder**, **"the opening" on the right shoulder** (Overpower, Revenge or Execute is usable), **Enrage burning round the inner rim** |
| Paladin | **A, Seal and Gavel** | **the active Seal and its timer in a reliquary above the crest**, **Judgement cooldown on the left shoulder**, **your Judgement on the target on the right shoulder**, the five ring jewels fed by Vengeance (or Holy Shield charges) |
| Rogue | **A, Cutthroat's Kit** | combo-point blades (today's crown), **Slice and Dice timer on the left shoulder**, **Rupture on the target on the right shoulder**, **a poison vial per weapon on the lower ring** |

Every piece is drawn by the engine from a duration object, an aura slot or a weapon-enchant frame, or from a value Blizzard documents as never secret. Nothing asks Lua to compare a secret.

## Files (all in this folder)

| File | What it shows |
| --- | --- |
| `warrior-concepts.png`, `paladin-concepts.png`, `rogue-concepts.png` | Concept A (top row) and B (bottom row), three states each, crest crop at 3x |
| `warrior-moment-opening.gif` | A: the target dodges and Overpower lights with a flash, it is spent, Enrage ignites and burns down, Execute lights |
| `paladin-moment-judgement.gif` | A: Judgement comes off cooldown with a flash, the old Judgement falls off the target, the paladin judges again (sweep restarts, the target medal relights), the Seal drains throughout |
| `rogue-moment-slice-and-dice.gif` | A: five blades are spent on Slice and Dice, its medal ignites and starts to drain, Rupture runs out and goes to steel, the off-hand vial is empty the whole time |

How the pictures were made, and their limits:

- **The HUD is real, the new pieces are composites.** Each picture starts from `Tools/render/shoot.sh hud_<class>_mac` at 1920x1080 (`--ppu 1`, `RENDER_HUD_STYLE=Medallions`, `RENDER_SIZE=auto`, DPS layout) over a UI-free band of the owner's `game_06` screenshot (the crop the Spirit Poles study made). The medals, vials, rim timers and flashes are drawn over it with PIL at true 1080 size, then the crest crop is enlarged (3x in the sheets, 2x in the GIFs), so a shoulder medal is honestly 28 px across in game.
- **Art is the shipped art.** Medal icons come from the icon set (`Tools/icons/setB/Icons`), the flashes are the shipped `Burst<Class>.png`, the inner-rim fire and halo are cells of the shipped `Ambient<Class>.png`. Rims, sockets and timer rings are procedural stand-ins in the gilt, steel and socket colours. Higgsfield was not used; no credits were spent and nothing left the machine.
- **The warrior's Sunder banners are not in the pictures.** The harness draws that crown only while a Sunder is on the target; it sits above the ring exactly as in `class-crowns/build/crown-warrior-medallions-1080.gif`, clear of both shoulder medals.
- **The paladin's five ring jewels are today's render state** (3 lit from the harness fixture). On Forever nothing feeds them (see Paladin, crown).
- **GIF timings use Classic durations**, because `SpellDuration` does not decode for this build: Enrage 12 s, Seal 30 s, Judgement cooldown and debuff 10 s, Slice and Dice 21 s and Rupture 16 s at five points. In game the engine draws whatever the real duration is.
- **Only 1920x1080 and Medallions were drawn.** Frames is described per class below.
- **No "about to expire" flicker is shown.** The aura button's pandemic animations depend on `C_UnitAuras.GetRefreshCarryOverDuration` (`Blizzard_AuraContainer/Blizzard_AuraContainerUtil.lua:13-28`), which I could not prove returns anything on Forever. The short ring is the warning.

## The routes every piece uses

Paths are under `~/.cache/wow-ui-source/Interface/AddOns` at `9dc84f0` (1.60.1.70862). `Docs/` stands for `Blizzard_APIDocumentationGenerated/`. Spell rows come from the client tables cached in `~/.cache/kstyleui-evidence/parity-qol-r5/db2/` (`SpellName`, `Spell`, `SpellEffect`, `SpellAuraOptions`, `SpellMisc`, `SpellCategories`) and the class lists in `Tools/data/abilities.json` (build 1.60.1.70840).

| Route | What it gives | Proof | Verdict |
| --- | --- | --- | --- |
| **R1 aura slot with a timer** | Blizzard's `CustomAuraContainer`: `AddAuraSlot(key, filter, { candidateFilters = { includeSpellIDs } })`, then `button:SetDurationCooldown(cooldown)` and `button:SetIcon(texture)`. The engine shows the button while the aura is up, sweeps the cooldown from the aura's duration object and sets the icon. | `Blizzard_AuraContainer/Blizzard_CustomAuraContainer.lua:417`; `Blizzard_CustomAuraButton.lua:159-168, 243, 598-605, 694-705` | Safe. Lua never sees the aura. Shipped use: Lightning Shield orbs (`KstyleUI_ActionBars/SlabStorm.lua:100-122`) |
| R1 filter rule | Spell-ID filters are allowed for **helpful auras on the player** and **harmful auras on a unit the player cannot assist** (an enemy target). They are refused for harmful auras on friendly units, including the player's own debuffs, unless the spell is flagged never secret. | `Blizzard_AuraContainerUtil.lua:52-88, 101-111` | Shapes every pick below |
| **R2 stacks or charges** | `button:SetApplicationBar(bar, { minApplications = i - 1, maxApplications = i })`, one bar per piece | `Blizzard_CustomAuraButton.lua:68-77, 419-431` | Safe. This is the shipped crown route (`Core/Widgets/ClassPip.lua:27-35`) |
| **R3 spell cooldown** | `C_Spell.GetSpellCooldownDuration(spell)` returns a duration object for `Cooldown:SetCooldownFromDurationObject`. "On cooldown" is `GetSpellCooldown(spell).isActive` and not `isOnGCD`, both documented `NeverSecret`. The ready flash plays from the Cooldown widget's own `OnCooldownDone`. | `Docs/SpellDocumentation.lua:309-314, 327-341`; `Docs/SpellSharedDocumentation.lua:19-31`; `Blizzard_CooldownViewer/CooldownViewer.lua:718`; event `Docs/SpellBookDocumentation.lua:927` | Safe. Same route as the essential cooldown row (`KstyleUI_Cooldowns/README.md:187-189, 209`) |
| **R4 usable now** | `C_Spell.IsSpellUsable(spell)` on `SPELL_UPDATE_USABLE`. It carries no secret-return flag. A reactive strike (Overpower, Revenge, Execute, Riposte, Hammer of Wrath) is usable only while its condition holds, which is how the action button lights. | `Docs/SpellDocumentation.lua:980-995`; `Docs/SpellBookDocumentation.lua:951` | Safe as documented. The code still checks `issecretvalue` and keeps the last state on a secret answer, as `KstyleUI_Cooldowns/README.md:457` does |
| **R5 weapon enchant** | `container:AddItemEnchantment(AuraContainerItemEnchantmentSlot.MainHand or .OffHand, options)` returns an aura button fed by the temporary enchant: time left as a duration, **charges as applications**. Blizzard reads it from `C_PaperDollInfo.GetTemporaryEnchantmentInfo`, which has no secret-return flag, and compares its numbers in plain Lua. | `Blizzard_CustomAuraContainer.lua:488-507`; `Blizzard_AuraContainerEnchantments.lua:325-343, 376-393`; `Blizzard_AuraContainerShared.lua:9-14`; `Blizzard_AuraContainerUtil.lua:206-214`; `Docs/PaperDollInfoDocumentation.lua:226-240`; `Docs/ItemDocumentation.lua:1141-1154, 1923, 1968-1978` | Safe, and never secret. KstyleUI already uses it for the aura panel (`KstyleUI_Auras/Panel.lua:394-401, 513-525`) |
| **R6 stance or form** | `GetShapeshiftFormInfo(i)` (texture, isActive, castable, spellID) on `UPDATE_SHAPESHIFT_FORM`. Not in the generated docs, so it has no secret flag; Blizzard's stance bar reads it in plain Lua. | `Blizzard_ActionBar/Shared/StanceBar.lua:62, 70, 155`; `Docs/SpellBookDocumentation.lua:992` | Safe. The stance bar and the Cooldowns module already read it |
| **R7 own casts** | The player's own `UNIT_SPELLCAST_SUCCEEDED` is readable; it only chooses where a flourish plays, never what is lit. | `Docs/UnitDocumentation.lua:4847`; `Docs/SecretPredicatesDocumentation.lua:115-117` | Safe. Same use as the storm orbs' bolts |

**Rejected for all three classes:**

- Any Lua read of an aura, its stacks or its time (`C_UnitAuras.GetPlayerAuraBySpellID` and the rest are `SecretWhenUnitAuraRestricted`, `Docs/UnitAuraDocumentation.lua:397-411`).
- **The player's own debuffs by spell ID** (Forbearance 25771, Recently Bandaged, a rogue's own Blind immunity): harmful on a friendly unit, so R1 refuses the filter.
- Reading `GetSpellCooldown`'s `startTime` or `duration` (secret when cooldowns are restricted, `Docs/SpellDocumentation.lua:312`).
- Rune abilities with no trainer row, as the class-crowns report found.
- An "about to expire" flicker (see above).

## Warrior

### What a warrior watches

| Thing | IDs | Route | Verdict | Level or talent |
| --- | --- | --- | --- | --- |
| Sunder Armor stacks on the target | 7386, 7405, 8380, 11596, 11597, 20243 | R2 on `"target"`, `"HARMFUL"` | **Shipped** as the banner crown | Trainer (Classic level 10) |
| **Battle Shout up, and its time** | 5242, 6192, 6673, 11549, 11550, 11551, 25289; Commanding Shout 403215 as a second slot | R1 on `"player"`, `"HELPFUL"` (anyone's shout counts, as it should) | **Pass** | Trainer, level 1. A fresh warrior sees this medal from the first minute |
| **A reactive strike is usable** | Overpower 7384, 7887, 11584, 11585; Revenge 6572 and ranks to 25288; Execute 5308 and ranks to 20662; Victory Rush 402927 | R4, plus R3's `isActive` so a strike on cooldown stays dark | **Pass** | Overpower 12, Revenge 14, Execute 24 (Classic levels); Victory Rush is a Forever trainer spell. Below 12 the medal does not exist |
| **Enrage window** (when Raging Blow 402911 and Enraged Regeneration 402913 work) | Enrage 12880 (talent 12317), Bloodrage 29131 (from 2687), Berserker Rage 18499 | R1 on `"player"`, `"HELPFUL"`, one slot listing all three | **Pass** | Bloodrage 10, Berserker Rage 32, Enrage is a Fury talent. Before level 10 the rim never lights |
| Stance | Battle 2457, Defensive 71, Berserker 2458 | R6 | **Pass**, used in B | Defensive 10, Berserker 30 |
| Flurry, Reckless Swings, Sweeping Strikes, Shield Block charges | 12966 (3), 1329555 (4), 12292 (5), 2565 (2) | R2 on `"player"` | Pass, **not picked**: four charge counts would crowd the crest, and Sunder already owns the crown | Talents and trainer |
| Rend, Mortal Strike, Thunder Clap, Demoralizing Shout on the target | 772 and ranks, 12294 and ranks | R1 on `"target"`, `"HARMFUL|PLAYER"` | Pass, **not picked**: the crest debuff fan already shows target debuffs | |
| Rage | | | Already the resource bar | |
| Mortal Strike, Bloodthirst, Shield Slam cooldowns | 12294, 23881, 23922 (category 971) | R3 | Pass, **not picked**: the essential cooldown row above the crest already shows them | Talents |

### Concept A, War Drums (recommended)

- **Battle Shout timer on the left shoulder.** A horn medal with a gold ring that drains over the shout. Steel means recast.
- **The opening on the right shoulder.** One medal for "a strike just became possible". It shows the icon of the strike that is usable now, in this order: Execute, then Overpower or Revenge, then Victory Rush. Dark steel when none is.
- **Enrage on the inner rim.** While Enrage, Bloodrage or Berserker Rage is up, the crest's inner rim burns red and the fire drains with the buff, the way the storm halo sits there for a shaman. A warrior with Raging Blow reads "press it now" from peripheral vision.
- **The moment** (`warrior-moment-opening.gif`): the opening medal flares with the class burst the instant the strike becomes usable (R4, on `SPELL_UPDATE_USABLE`) and goes dark when it is spent. Enrage ignites round the rim from the aura slot's shown animation.
- **Motion:** Full plays flare and fire; Calm lights without the flare and holds the fire still; Off shows lit or steel only.

### Concept B, Three Stances

- **Three stance jewels on the ring's brow** (gold Battle, blue Defensive, red Berserker), the active one lit (R6). They sit where a rogue's combo jewels sit, under the Sunder banners.
- **Battle Shout on the left shoulder**, as in A.
- **The stance's own strike on the right shoulder**: Overpower in Battle, Revenge in Defensive, Execute in Berserker, lit when usable.
- No Enrage piece.

| | A War Drums | B Three Stances |
| --- | --- | --- |
| Answers | "Is my shout up, can I punish now, am I enraged" | "Which stance am I in, is my shout up, can I punish now" |
| New information | All three pieces are new | The stance already shows on the stance bar |
| Busy-ness | Two medals and a rim that is dark most of the time | Two medals and three jewels that are always on |
| Risk | Rim fire under the emblem must stay calm at 1080 | Jewels and banners share the brow |

**Why A:** stance is something a warrior chooses, not something that slips away, and the stance bar already shows it. Enrage is a short window that decides the next button, which is exactly what a crest glance is for.

**Frames:** no crest, so the three trackers become three of the same round medals in a short forged row at the tray's end beside the stance bar (`Core/Setup/Layouts.lua:191`), in the order shout, opening, Enrage. Enrage is a medal with a red drain ring there.

## Paladin

### What a paladin watches

| Thing | IDs | Route | Verdict | Level or talent |
| --- | --- | --- | --- | --- |
| **The active Seal and its time** | Righteousness 20154, 20287 to 20293, 21084; Command 20375, 20915, 20918 to 20920; the Crusader 20162, 20305 to 20308, 21082; Light 20165, 20347 to 20349; Wisdom 20166, 20356, 20357; Justice 20164; Fury 20163 and ranks to 1311656; Martyrdom 407798 | R1 on `"player"`, `"HELPFUL"`, one slot listing every Seal; `SetIcon` shows which one | **Pass** | Seal of Righteousness at level 1; a fresh paladin has it at once |
| **Judgement cooldown** | Judgement 20271; Swift Judgement 1310994 (its own cooldown) | R3 | **Pass**. On Forever, Judgement "does not consume the Seal" (20271's text), so it is a pure cooldown button | Classic level 4 |
| **Your Judgement on the target** | of the Crusader 20188, 20300 to 20303, 21183; of Light 20185, 20344 to 20346; of Wisdom 20186, 20354, 20355; of Justice 20184 | R1 on `"target"`, `"HARMFUL|PLAYER"` | **Pass** (an enemy target). Empty with no target, by design | With the Seal |
| Vengeance stacks | 20050 (5 stacks; talent 20049) | R2 on `"player"` | **Pass**: the class-crowns pick for the five jewels | Retribution talent |
| Holy Shield charges | 20925, 20927, 20928, 1239570 (4 charges) | R2 | Pass: the jewels' feed for a Protection paladin | Protection talent |
| Reckoning | 1326084 (4 stacks; talent 20177) | R2 | Pass, runner-up for the jewels | Protection talent |
| Your Blessing on yourself | Might 19740 and ranks, Wisdom 19742 and ranks, Kings 20217, Greater 25782, 25894, 25898, 25916, 25918 | R1 on `"player"`, `"HELPFUL"` | Pass, used in B | Might at 4 |
| Aura on | Devotion 465 and ranks, Retribution 7294 and ranks, Concentration 19746, resistance auras | R1 `"HELPFUL"`, or R6 | Pass, used in B | Devotion at 1 |
| Righteous Fury on | 25780, 407627 | R1 `"HELPFUL"` | Pass, used in B | Classic level 16 |
| Hammer of Wrath usable | 24239, 24274, 24275 | R4 | Pass, **not picked**: a fourth piece, and the cooldown row shows it | Classic level 44 |
| **Forbearance** | 25771 | R1 refused: harmful on the player | **Rejected** unless `C_Secrets.GetSpellAuraSecrecy(25771)` proves never secret in game | |
| Holy Power | | | **Rejected**: Forever has no such power (class-crowns report, fact 2) | |
| Divine Favor, Avenging Wrath, Divine Shield cooldowns | 20216, 407788, 642 | R3 | Pass, **not picked**: long cooldowns belong on the cooldown row | |

**Crown today:** the five ring jewels read `UnitPower(HolyPower)` (`KstyleUI_ActionBars/SlabJewels.lua:20, 23`), which no Forever class has, so on a real paladin they never light. Both concepts keep the five jewels and assume the class-crowns follow-up feeds them: Vengeance for a paladin who knows 20049, else Holy Shield charges for one who knows 20925, else dark.

### Concept A, Seal and Gavel (recommended)

- **The Seal in a reliquary above the crest.** A round gilt medal at the crown point shows the icon of the Seal that is up, and its ring drains over the Seal's 30 seconds. Dark steel means no Seal. The paladin has no crown pieces there, so the space is free.
- **Judgement on the left shoulder.** The hammer medal is lit when Judgement is ready and carries the cooldown sweep while it is not.
- **Your Judgement on the target on the right shoulder.** Lit with a draining ring while your Judgement of the Crusader, Light, Wisdom or Justice is on the target; steel when it has fallen off or there is no target.
- **The moment** (`paladin-moment-judgement.gif`): the hammer medal flares with the class burst when the cooldown ends (`OnCooldownDone`), and the target medal flares when your Judgement lands (the aura slot's shown animation).
- **Motion:** Full plays both flares; Calm lights without them; Off shows lit or steel only.

### Concept B, Halo

- **The Seal as a halo inside the ring**: the inner rim shines gold and drains while a Seal is up, like the shaman's storm halo.
- **Judgement on the left shoulder**, as in A.
- **Your Blessing on the right shoulder**: lit with a ring while you carry your own Blessing, steel when it has run out.
- **Two jewels on the lower ring**: blue lower left while an Aura is on, amber lower right while Righteous Fury is on.

| | A Seal and Gavel | B Halo |
| --- | --- | --- |
| Answers | "Is my Seal up, can I judge, is the target judged" | "Is my Seal up, can I judge, am I buffed" |
| Rhythm | Three things that change every few seconds | One fast thing, three that change every few minutes |
| Which Seal | Shown (the icon) | Not shown |
| Busy-ness | Three medals | A halo over a bright emblem, a medal pair, two jewels |
| Risk | The reliquary sits where a future paladin crown piece might go | The gold halo fights the gold-and-pink emblem |

**Why A:** the Seal, the Judgement cooldown and the Judgement on the target are the paladin's whole fast loop on Forever, and A shows which Seal is up. Blessing, Aura and Righteous Fury change once in minutes; a missing one is better said by the buff panel than by a permanent crest piece.

**Frames:** the same three medals in a row at the tray's end, in the order Seal, Judgement, target. The jewels stay with the Frames crown above the portrait.

## Rogue

### What a rogue watches

| Thing | IDs | Route | Verdict | Level or talent |
| --- | --- | --- | --- | --- |
| Combo points | | `GetComboPoints` | **Shipped** as the blade crown and ring jewels | Level 1 |
| **Slice and Dice up, and its time** | 5171, 6774; Blade Dance 400012 as a second slot for a tank rogue | R1 on `"player"`, `"HELPFUL"` | **Pass** | Classic level 10. Before that the medal does not exist |
| **Rupture on the target** | 1943, 8639, 8640, 11273, 11274, 11275; Garrote 703, 8631 to 8633, 11289, 11290 in the same slot | R1 on `"target"`, `"HARMFUL|PLAYER"` | **Pass** (an enemy target) | Rupture 20, Garrote 14 |
| **Poison on each weapon** (missing, time left) | Not spells: the main-hand and off-hand temporary enchants | R5 | **Pass**, and never secret, so Lua may even compare the time | Poisons 2842 (Classic level 20). Before that the vials do not exist |
| Stealth | 1784 to 1787 | R6 (Stealth is a form) | Pass, used in B | Level 1 |
| Expose Armor, Saber Slash (3 stacks), Hemorrhage, Death Mark on the target | 8647 and ranks, 424785, 16511, 1316709 and ranks | R1 or R2 on `"target"`, `"HARMFUL|PLAYER"` | Pass, **not picked**: one target piece keeps the crest readable; Rupture is the one every rogue keeps up | Trainer and talents |
| Riposte usable | 14251 | R4 | Pass, **not picked** (talent only) | Combat talent |
| Cold Blood, Adrenaline Rush, Blade Flurry, Vanish, Evasion, Sprint, Kick cooldowns | 14177, 13750, 13877, 1856, 5277, 2983, 1766 | R3 | Pass, **not picked**: the cooldown row's job | |
| Flash Powder for Vanish | item 5140 | `C_Item.GetItemCount` (`Docs/ItemDocumentation.lua:451-468`, never secret) | Pass, **not picked**: a bag check, not a fight glance | |
| Energy | | | Already the resource bar | |

### Concept A, Cutthroat's Kit (recommended)

- **Slice and Dice on the left shoulder.** A medal with a yellow ring that drains over the buff. Steel means it is down.
- **Rupture on the target on the right shoulder.** A medal with a blood-red ring that drains over your bleed; steel when it has run out or there is no target.
- **A poison vial per weapon on the lower ring**: a green diamond at the lower left for the main hand and one at the lower right for the off hand, set into the ring band like the combo jewels. Lit means poisoned; an empty dark setting means that weapon has no poison. The vial can also drain as a liquid level over the poison's time (R5 gives the duration).
- **The moment** (`rogue-moment-slice-and-dice.gif`): the finisher spends the crown's blades and the Slice and Dice medal ignites with the class burst (the aura slot's shown animation, placed by the player's own cast, R7). Each timer ends in steel.
- **Motion:** Full plays the ignite flare; Calm lights without it; Off shows lit or steel only.

### Concept B, Venom and Shadow

- **A poison medal on each shoulder** (main hand left, off hand right), each showing the poison's own icon with a green ring for its time. Steel means missing.
- **Slice and Dice as a glow on the inner rim** that drains with the buff.
- **A veil in Stealth**: a shadow falls over the emblem while stealthed (R6).
- No target piece.

| | A Cutthroat's Kit | B Venom and Shadow |
| --- | --- | --- |
| Answers | "Is Slice and Dice up, is Rupture up, are both weapons poisoned" | "Which poisons, is Slice and Dice up, am I stealthed" |
| Fast things on the big pieces | Yes: both medals change every few seconds | No: the medals hold 30-minute timers |
| Which poison | Not shown (lit or empty) | Shown (the icon) |
| Busy-ness | Two medals, two small vials, under an already full crown | Two medals, a rim glow, a veil |
| Risk | The vials are small (12 px) | The veil dims the emblem the owner likes; Stealth is already obvious on screen |

**Why A:** the shoulders are the loudest seats, so they should carry the two timers a rogue refreshes all fight. A poison needs one glance before a pull, which a small vial answers; and Stealth needs no tracker at all.

**Frames:** the two medals and the two vials stand in a row at the tray's end (vials drawn as two small medals there), in the order Slice and Dice, Rupture, main hand, off hand. The blades stay with the Frames crown above the portrait.

## Fit on the crest

Measured on the 1080 renders: hub centre (960, 989), ring outer radius 69 px, inner rim 50 px.

- **Shoulder medals** sit at 65 px out and 30 px up from the centre, 28 px across with the timer ring: the seats the shaman's Ghost Wolf and Call medals use. They clear the player and target plates by about 3 px at 1080; that gap needs a clearance check at all four sizes, as the Spirit Poles' did.
- **The paladin's reliquary** sits 93 px above the centre, 34 px across, clear of the cooldown row by about 40 px. No other class in this study uses that seat, because the rogue and warrior crowns do.
- **Lower-ring jewels** sit on the band at 125 degrees either side of the top, clear of the level plaque.
- **Inner-rim pieces** stay inside 50 px, as the storm orbs do.
- **Crest debuff fan** (`KstyleUI_UnitFrames/Fan.lua`): 163 px above the slab, above everything here.
- A hunter's hawk perches and a shaman's sockets use other seats on other classes, so nothing collides.

## Open decisions for the owner

1. **Paladin jewels' feed.** Vengeance, then Holy Shield, as assumed here, or leave the jewels to the crown follow-up.
2. **Warrior Enrage for a warrior with no Raging Blow.** Show the rim for every warrior (it still means "Enraged Regeneration works"), or only when Raging Blow 402911 is known. My lean: every warrior.
3. **Anyone's Battle Shout, or only yours.** `"HELPFUL"` counts another warrior's shout, which is what the buff does. `"HELPFUL|PLAYER"` would show only your own.
4. **Rogue vial drain.** Lit or empty only, or draining with the poison's time. My lean: draining, since R5 gives it for free.
5. **Each piece gets its own Options switch**, on by default, beside Hawk perches and Lightning Shield on the crest.

## In-game checks before any build

None of these can be answered from the source.

1. `/dump C_Spell.IsSpellUsable(7384)` before and after the target dodges, in combat: it should turn true only after the dodge, and not be secret.
2. `/dump C_Spell.GetSpellCooldown(20271).isActive` in combat after a Judgement: true, then false ten seconds later, never secret.
3. With a poison on each weapon: `/dump C_PaperDollInfo.GetTemporaryEnchantmentInfo(16)` and `(17)`, in and out of combat.
4. An R1 slot on `"target"` with `"HARMFUL|PLAYER"` and Rupture's IDs lights in combat and in an instance. The crown proves the same route for Sunder.
5. `/dump C_Secrets.GetSpellAuraSecrecy(25771)`: if Forbearance is never secret, a Forbearance mark becomes possible.
6. Whether a second paladin's Judgement of the same kind on the target passes `"HARMFUL|PLAYER"` (it should not).

## How it was made

Scratch only, in `%TEMP%\orca-ctx_550dd8d3be1c\`: `q.py` (client table lookups), `mock.py` (compositor), `build.py` (sheets and GIF frames; GIFs assembled with ffmpeg at 12 fps). Five harness renders, never more than two at once. `Tools/render/out/` was created by the renders and removed afterwards; `git status` is clean.
