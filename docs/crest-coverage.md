# Crest coverage

This ledger accounts for every major cooldown and every proc in Forever's Cooldown Manager sets that the Medallions crest does not draw a piece of its own for. It was taken from the Cooldown Manager sets in the data tables of client build 71091: each class's Essential, Utility and TrackedBuff spells, matched against every spell the crest trackers, crest effects and class pips name. The supported live build is 70862, so every entry here is a candidate from that later data: a spell ID or set membership can differ in the client players run, and nothing here was traced in play. A major cooldown here is one of 60 s or more; a proc is a TrackedBuff the player does not cast. The crest pieces themselves are described in [medallions-effects.md](medallions-effects.md) and each module README.

The Cooldown Manager's own row (`KstyleUI_Cooldowns`) is the candidate fallback for a spell the crest leaves out: it draws the client's cooldown, charge and proc glow natively, secret values included, but only for a spell the client lists in the player's set, knows and does not hide, and its mirrored proc glow needs the spell's icon on that row and an overlay signal the client sends. This ledger has not traced that fallback spell by spell; where a row below says row candidate, the spell reaches the player through that row only if those conditions hold. The crest adds a piece only where a player gains something from seeing it on the centre artwork, so each spell below has one of five classes:

| Class | Meaning |
| --- | --- |
| Dedicated crest | A piece of its own on the crest |
| Shared crest | Drawn by a crest piece other spells use too, such as a shared sigil family, the cast ring or the cooldown rim |
| Row candidate | The crest has no piece for it; the Cooldown Manager row is its candidate fallback, not traced in the live client |
| Unavailable | The client gives Lua nothing to drive a piece from |
| Deliberately quiet | A passive with nothing for the player to press, so the crest never raises an alarm for it |

The crest never infers an event the client does not send. Its cooldown pieces repaint on `SPELL_UPDATE_COOLDOWN`, so a reset such as Preparation or Cold Snap moves their timers at once. A proc that makes a button usable can light that button through the client's own overlay glow on the action bar and on the Cooldown Manager row (`CooldownViewer.lua:1241` in the `forever` UI source), when the spell sits on a button and the client sends the overlay for it; the crest leaves such procs to that glow, which is a candidate until each is checked in the live client.

## Major cooldowns

Twenty-four major cooldowns in the sets had no crest piece matched by spell ID when the audit ran. Three more were matched by hand to item and totem routes; they are listed after the table.

| Class | Spell | Cooldown | Class in this ledger | Why |
| --- | --- | --- | --- | --- |
| Warrior | Eureka! 1259813 | 120 s | Shared crest | The gnome racial's `Gear` sigil, which now lists every class's Eureka! spell |
| Priest | Eureka! 1259823 | 120 s | Shared crest | As above |
| Mage | Eureka! 1259817 | 120 s | Shared crest | As above |
| Warlock | Eureka! 1259821 | 120 s | Shared crest | As above (the rogue's 1259812 already lit it) |
| Druid | Tranquility 740 | 300 s | Shared crest | A channel, which the crest's cast ring draws round the rim while it runs |
| Warrior | Intimidating Shout 5246 | 180 s | Row candidate | Crowd control aimed at enemies; it puts no buff on the player for a sigil to show |
| Warrior | Disarm 676 | 60 s | Row candidate | As above |
| Paladin | Repentance 20066 | 60 s | Row candidate | As above |
| Hunter | Intimidation 19577 | 60 s | Dedicated crest | A Beast Mastery seat on the crest rail, its cooldown counted on the medal; the second rail for the other trees |
| Rogue | Blind 2094 | 300 s | Row candidate | As above |
| Priest | Chastise 1277331 | 120 s | Row candidate | As above |
| Priest | Confounding Flash 1277455 | 120 s | Row candidate | As above |
| Druid | Challenging Roar 5209 | 600 s | Row candidate | A taunt on enemies; no buff on the player |
| Paladin | Holy Wrath 2812 | 60 s | Row candidate | An attack with no lasting effect on the player |
| Warlock | Soul Fire 6353 | 60 s | Dedicated crest | A seat on the crest rail in every tree (the second rail when Fel Domination takes its seat); the cast ring shows it while it casts |
| Warlock | Inferno 1122 | 3600 s | Dedicated crest | A seat on the crest rail in every tree, as the crest plan's ledger seats it; the pet's own frame carries the Infernal |
| Paladin | Lay on Hands 633 | 1200 s | Row candidate | An instant emergency heal with no buff to time |
| Paladin | Divine Intervention 19752 | 3600 s | Row candidate | A sacrifice on another player, used once an hour |
| Priest | Desperate Prayer 13908 | 600 s | Row candidate | An instant emergency heal with no buff to time |
| Priest | Divine Grace 1277370 | 600 s | Row candidate | Its effect is not confirmed in the live client; the crest adds nothing for it until it is |
| Druid | Rebirth 20484 | 1800 s | Row candidate | A resurrection on another player, out of the combat rotation |
| Rogue | Preparation 14185 | 600 s | Row candidate | Its effect is a reset, which the crest shows on the cooldowns it resets |
| Rogue | Premeditation 14183 | 120 s | Row candidate | Adds combo points, which the crest's combo pips already show |
| Mage | Cold Snap 12472 | 600 s | Dedicated crest | A Frost seat on the crest rail (the second rail for the other trees); its reset also shows on the cooldowns it resets |

Matched by hand rather than by spell ID:

| Class | Spell | Cooldown | Class in this ledger | Why |
| --- | --- | --- | --- | --- |
| Shaman | Mana Tide Totem 16190 | 300 s | Shared crest | A totem: its water socket on the Spirit Poles lights and drains its spire from the totem slot while it stands |
| Mage | Mana Gems 1318827 | 120 s | Shared crest | The hanging mana gem (`crestManaGem`) follows the gem items and their shared cooldown, not this spell ID |
| Warlock | Healthstone 1326057 | 120 s | Shared crest | The hanging Healthstone (`crestHealthstone`) follows the Healthstone items and their cooldown, not this spell ID |

## Procs

Forty-four procs in the sets had no crest piece. The Cooldown Manager hides 21 of them by default (marked hidden), so its row does not show them either; those are talent passives with nothing to press, so the crest keeps quiet about them too.

| Class | Proc | Hidden by default | Class in this ledger | Why |
| --- | --- | --- | --- | --- |
| Warrior | Blood Craze 16487 | Yes | Deliberately quiet | A passive heal with nothing to press |
| Warrior | Deep Wounds 12834 | Yes | Deliberately quiet | A passive bleed on the target |
| Warrior | Improved Hamstring 12289 | Yes | Deliberately quiet | A passive root chance |
| Warrior | Improved Shield Bash 12311 | Yes | Deliberately quiet | A passive silence chance |
| Paladin | Shieldsworn 1328544 | Yes | Deliberately quiet | Hidden by the client; a passive |
| Paladin | Infusion of Light 426065 | No | Row candidate | Changes a heal the player presses; the button's overlay glow can show it, not yet traced in the live client |
| Paladin | Redoubt 20127 | No | Deliberately quiet | A passive block chance |
| Paladin | Unsealed Wrath 1310735 | No | Row candidate | Its trigger is not confirmed in the live client |
| Hunter | Entrapment 19184 | Yes | Deliberately quiet | A passive root chance |
| Hunter | Improved Concussive Shot 19407 | Yes | Deliberately quiet | A passive stun chance |
| Hunter | Expose Prey 1310532 | No | Row candidate | Its trigger is not confirmed in the live client, and the ability catalog of the supported build (`Tools/data/abilities.json`, 70840) has no such spell |
| Hunter | Frenzy 19621 | No | Deliberately quiet | A passive on the pet |
| Hunter | Lacerating Strikes 1310533 | No | Row candidate | Its trigger is not confirmed in the live client, and the supported build's ability catalog has no such spell; Lacerate's own bleed burns on the Sting fuse |
| Hunter | Rapid Killing 415405 | No | Row candidate | Its effect lands on Rapid Fire's cooldown, which the crest already tracks; the supported build's ability catalog has no such spell |
| Hunter | Rapid Recuperation 1223987 | No | Deliberately quiet | A passive mana return |
| Priest | Inspiration 14892 | Yes | Deliberately quiet | A passive armor buff on the healed target |
| Priest | Blackout 15326 | Yes | Deliberately quiet | A passive stun chance |
| Priest | Blessed Recovery 27811 | Yes | Deliberately quiet | A passive heal over time |
| Priest | Divine Aegis 431622 | Yes | Deliberately quiet | A passive shield on the healed target |
| Priest | Spirit of Redemption 20711 | Yes | Deliberately quiet | Shows only after death |
| Priest | Martyrdom 14531 | No | Deliberately quiet | A passive cast protection after a critical hit |
| Priest | Spirit Tap 15270 | No | Deliberately quiet | A passive regeneration after a kill |
| Shaman | Ancestral Healing 16176 | Yes | Deliberately quiet | A passive armor buff on the healed target |
| Shaman | Earthbound 1222988 | Yes | Deliberately quiet | Hidden by the client; a passive |
| Shaman | Elemental Devastation 30160 | No | Deliberately quiet | A passive critical chance |
| Shaman | Elemental Focus 16164 | No | Deliberately quiet | A passive cost reduction on the next spell |
| Shaman | Flurry 16256 | No | Deliberately quiet | A passive attack speed buff |
| Shaman | Improved Stormstrike 1223031 | No | Row candidate | Its trigger is not confirmed in the live client |
| Shaman | Maelstrom Weapon 408498 | No | Row candidate | Stacks to an instant cast; a crest piece needs its stack feed checked in the live client first |
| Mage | Impact 11103 | Yes | Deliberately quiet | A passive stun chance |
| Mage | Improved Blizzard 11185 | Yes | Deliberately quiet | A passive slow |
| Mage | Improved Counterspell 11255 | Yes | Deliberately quiet | A passive silence |
| Mage | Fingers of Frost 400647 | No | Row candidate | Changes the next frost spell; the button's overlay glow can show it, not yet traced in the live client |
| Mage | Heating Up 400624 | No | Row candidate | The step before a proc, with no button of its own to press |
| Mage | Missile Barrage 400588 | No | Row candidate | Changes Arcane Missiles; the button's overlay glow can show it, not yet traced in the live client |
| Warlock | Aftermath 18119 | Yes | Deliberately quiet | A passive daze chance |
| Warlock | Decimation 440870 | Yes | Deliberately quiet | Hidden by the client; changes Soul Fire, whose button's overlay glow can show it, not yet traced in the live client |
| Warlock | Demonic Brand 1293695 | No | Row candidate | Its trigger is not confirmed in the live client |
| Warlock | Improved Shadow Bolt 17793 | No | Deliberately quiet | A passive debuff on the target |
| Warlock | Soul Harvest 437032 | No | Row candidate | Its trigger is not confirmed in the live client |
| Druid | Improved Starfire 16850 | Yes | Deliberately quiet | Hidden by the client; a passive |
| Druid | Leader of the Pack 17007 | Yes | Deliberately quiet | A passive party aura |
| Druid | Eclipse 408248 | No | Row candidate | Changes which spell to press; the buttons' overlay glow can show it, not yet traced in the live client |
| Druid | Nature's Grace 16880 | No | Deliberately quiet | A passive haste after a critical hit |

## Hunter homes

The crest needs ledger (the 25 November 2026 audit of what each class tracks, 61 hunter rows) proposes a home for every need: the medal rail, the crown and ring, a perch, inside the crest, a pendant, or a rail of round medals. This table gives each hunter row its home today, or the reason it has none. "Short rail" is the Cooldown Manager mirror's Essential or Utility row drawn as round medals (`KstyleUI_Cooldowns`, Match Medallions sockets); it shows a spell only while the game lists it in that set and does not hide it, so a "(hidden)" set entry reaches it only after the player shows it in the game's Cooldown Manager settings. "Hunter rail" is the five-seat crest rail (`SlabRail.lua`), which seats up to four abilities of the talent tree the game names and the trinket.

| # | Need | Home or reason |
| --- | --- | --- |
| 1 | Rapid Fire 3045 | Hunter rail seat; its buff rises to the crown |
| 2 | Bestial Wrath 19574 | Hunter rail seat; the pet's buff rises to the crown |
| 3 | Deterrence 19263 | Hunter rail seat; its buff rises to the crown |
| 4 | Intimidation 19577 | Hunter rail seat |
| 5 | Feign Death 5384 | Short rail (Utility); the hunter rail's per-tree order has no seat for it |
| 6 | Aimed Shot 19434 | Hunter rail seat, and its ready arrow over the emblem |
| 7 | Multi-Shot 2643 | Ready arrows over the emblem; its cooldown on the short rail (Essential) |
| 8 | Arcane Shot 3044 | Short rail (Essential); a flash over the emblem before the hunter has a pet |
| 9 | Sniper Shot 1310687 | Hunter rail seat |
| 10 | Raptor Strike 2973 | Short rail (Essential, hidden by the game until shown); a flash over the emblem before the first Aspect |
| 11 | Strider Kick 1317257 | Hunter rail seat |
| 12 | Fire trap cooldown 13795, 13813 | Hunter rail seat |
| 13 | Auto Shot and swing 75 | The Auto Shot ring round the crest |
| 14 | Summon Hawk 1293241 | The two hawk perches |
| 15 | Pet health | The light along the lower right band |
| 16 | Pet dead or missing 982 | The paw sigil on the pet's perch, standing in for the hound until its animated aura lands: steel while no pet is out, red with a breathing halo while it lies dead; a death the game marks secret shows no paw rather than a guess |
| 17 | Pet happiness 6991 | The forged haunch on the pet's perch |
| 18 | Mend Pet 136 | Motes along the pet's band |
| 19 | Pet Focus | A second, smaller light within the pet's health along the lower right band, fed the pet's focus and maximum unchanged (`UnitPower`, `UnitPowerMax` on `UNIT_POWER_UPDATE` and `UNIT_MAXPOWER`), so a secret value is never compared |
| 20 | Pet family ability cooldowns | A perch on the right trinket seat (33, -24) with a stand-in family mark, built for the first family ability the pet's spellbook knows (`C_SpellBook.IsSpellKnown` on the pet bank, refreshed on `PET_BAR_UPDATE`): lit while it is ready, dark while it cools, read from its own pet bar slot (`GetPetActionInfo` finds the slot whose spell it is, `GetPetActionCooldown` gives its cooldown, as Blizzard's pet bar reads it) on `PET_BAR_UPDATE_COOLDOWN` and `UNIT_PET`, and again when `PET_BAR_UPDATE` rebuilds the perch, as the pet action bar does. Unreadable remainder: before the pet bar fills, with no slot for the spell, or while the game marks the slot's cooldown secret, the perch cannot tell ready from cooling and stays unlit, never ready. The global cooldown flag (`isOnGCD`) counts only on `SPELL_UPDATE_COOLDOWN`, where Forever documents it as reliable, so a read elsewhere never shows an active cooldown ready, and a secret flag is never compared. |
| 21 | Pet-applied debuffs and buffs | The same perch ringed red, the ring draining with the aura, while your pet's Screech, Scorpid Poison, Rend or Dust Cloud runs on the target, and ringed gilt while its Furious Howl runs on you. The aura slots use the game's `PLAYER` filter, which takes your own and your pet's auras, so another hunter's pet never lights them |
| 22 | Pet target and Growl | Growl's mark on the lower band seat (0, -39) while a pet that knows Growl is out: red while Growl's autocast is on in a group or off alone (`C_Spell.GetSpellAutoCast`, `IsInGroup`), or while the pet attacks something other than your hostile target (`UnitIsUnit` on `pettarget`), steel otherwise; a reading the game marks secret leaves it steel |
| 23 | Armed trap on the ground | Unavailable: the Forever API contracts name no function or event for a placed hunter trap, and a trap is not a totem; the fire trap seat's cooldown starts when it is placed |
| 24 | Serpent Sting 1978 | The Sting fuse on the right band |
| 25 | Hunter's Mark 1130 | The reticle on the left band |
| 26 | Viper Sting 3034 | The Sting fuse; its cooldown on the short rail (Utility) |
| 27 | Scorpid Sting 3043 | The Sting fuse |
| 28 | Lacerate bleed | The Sting fuse burns Lacerate 24118 to 24120 and 1299332; Lacerating Strikes 1310533 is not in the supported build's ability catalog |
| 29 | Immolation Trap burn 13797 | The Sting fuse burns it in fire's colour with the fire trap's mark at its head, like the stings, through the same `HARMFUL|PLAYER` slot, so another hunter's trap never lights it. If the game credited the burn to the trap rather than to you, the fuse would stay dark; the in-game check settles which |
| 30 | Mongoose Bite 1495 | Its fangs over the emblem when usable |
| 31 | Expose Prey 1310532 | Not in the supported build's ability catalog, so no piece is drawn for it |
| 32 | Counterattack 19306 | Its blades over the emblem when usable |
| 33 | Deadly Aspects (Quick Shots) 19552 | The feathered gust round the crest |
| 34 | Sniper Shot range charges | The crown of three arrows |
| 35 | Rapid Killing 415405 | Not in the supported build's ability catalog; its effect lands on Rapid Fire's cooldown, which the rail seat shows |
| 36 | Pet Frenzy 19621 | Deliberately quiet: a passive on the pet |
| 37 | Proc roots and stuns 19184, 19407 | Deliberately quiet: passive control chances |
| 38 | Active Aspect | The perched Aspect on the lower left |
| 39 | No Aspect, or Cheetah or Pack in combat | The perch shows grey steel with no Aspect and the animal it names otherwise; no extra warning yet |
| 40 | Trueshot Aura 19506, 20905, 20906, 1299346, 1299348 | The Aimed Shot sigil on the upper left, standing in for its own mark until the animated aura lands: gold while the aura is up, steel while it is down |
| 41 | Track type matching the target 24293 | The reticle mark on the upper right with Improved Tracking, standing in for a compass until its animated aura lands: gold while the active tracking's creature type is a hostile target's (the type's number, `UnitCreatureType`'s second return), steel against a hostile target it does not match, hidden with no target or a friendly one (`UnitCanAttack`, repainted on `UNIT_FACTION`); a type the game marks secret stays steel |
| 42 | Lone Wolf (no pet out) | The steel paw on the pet's perch |
| 43 | Range and the dead zone | A ring round the emblem against a hostile target: none while Auto Shot reaches it, gilt while the game says Auto Shot does not reach and melee does (Raptor Strike or Wing Clip in range), red only while the game says neither does. The game's own range events drive it (`C_Spell.EnableSpellRangeCheck` and `SPELL_RANGE_CHECK_UPDATE`), so nothing polls; the crest turns each range check on once and off once when no ring needs it, as Blizzard's Cooldown Viewer pairs them; the game names no owner of a check, so whether another addon's check of the same spell survives that release is unproven. Unreadable remainder: inside Auto Shot's minimum range and outside melee, the dead zone, both spells read out of range, the same as too far, so the dead zone shows red and the crest cannot tell the two apart; a reading the game cannot check or marks secret is unclassified and shows no ring |
| 44 | Mana and the five-second rule | The five-second ring round the level badge; mana itself on the player frame |
| 45 | Rapid Recuperation 1223987 | Deliberately quiet: a passive mana return |
| 46 | Threat on the target | No crest piece: the crest's threat glow is for tanks; nameplates and the role meters show threat |
| 47 | Freezing Trap 1499 | Short rail (Utility) |
| 48 | Frost Trap 13809 | Short rail (Utility) |
| 49 | Tranquilizing Shot 19801 | A small glyph on the crest's lower left foot (`footLeft`, -26.4, -62.1) with a stand-in drop mark, once the spell is known: lit while it is ready, dark under a draining ring for its 20 seconds (`C_Spell.GetSpellCooldownDuration` on `SPELL_UPDATE_COOLDOWN`) |
| 50 | Scatter Shot 19503 | Short rail (Utility) |
| 51 | Concussive Shot 5116 | Short rail (Utility) |
| 52 | Wing Clip 2974 | Nothing to time: it has no cooldown, and the game lists it only as a hidden tracked buff |
| 53 | Disengage 781 | Short rail (Utility) |
| 54 | Distracting Shot 20736 | Short rail (Utility) |
| 55 | Flare 1543 | Short rail (Utility, hidden by the game until shown) |
| 56 | Scare Beast 1513 | Short rail (Utility, hidden by the game until shown) |
| 57 | Crowd control time, breaks and diminishing returns | Unavailable: breaks and diminishing returns need the combat log, which is closed to addons; the control's own debuff shows on the target frame |
| 58 | On-use trinket | The hunter rail's trinket seat |
| 59 | Racial cooldown | The shared racial sigils on the cooldown rim while the buff runs |
| 60 | Ammo | The Auto Shot ring turns amber below 200 and red with none |
| 61 | Potion and consumable cooldowns | A gem pendant on the left trinket seat (-33, -24) holding the first potion the bags carry from a best-first list of healing and mana potions, steel under a charging ring while potions cool down and ready again once they recharge, an empty bail with none (`C_Item.GetItemCount`, `GetItemCooldown`); the shared Potion sigil while the potion's buff runs |

## Crest rail

The crest rail ([medallions-effects.md](medallions-effects.md#crest-rail)) seats each talent tree's long cooldowns, then its rotation cooldowns, for the hunter, the mage and the warlock, from Forever class guides checked against Forever's spell data; the other classes have no rail yet. Long cooldowns beyond the four seats and the racials above stand on its second rail. These abilities have no rail medal, each for a recorded reason:

| Class | Ability | Why it has no rail medal |
| --- | --- | --- |
| Hunter | Readiness | Not confirmed for any Forever tree by the guides or the client's spell data |
| Mage | Icy Veins | As above |
| Mage | Arcane Wrath | Already the crest's own charge piece (`crestSchool`); a medal would show it twice |
| Mage | Blast Wave | A Fire rotation button under 60 s, outside the ledger's rail order; Cone of Cold fills Fire's free seat |
| Warlock | Metamorphosis, Demonic Howl | Not confirmed for any Forever tree by the guides or the client's spell data |
| Warlock | Conflagrate | Already the crest's own socket (`crestConflagrate`) |
| Warlock | Bane of Doom | Already the crest's Bane torment spire, which times it; a medal would show it twice |
| Warlock | Shadowburn | A Destruction rotation button under 60 s, outside the ledger's rail order |
| Warlock | Ritual of Doom | A summoning ritual the ledger leaves unseated in every tree |
| Warlock | Soulstone | A resurrection kept on an ally before a fight; the ledger leaves it unseated, and its 30-minute cooldown needs its own piece |

## Conditional racials

Some racial spells sit in every class's set but only for the race that owns them. Those with a buff the player times are shared crest sigils (Blood Fury, Berserking, Stoneform, Perception, Will of the Forsaken, Shatter Curse, Elune's Light, Eureka!, Rapid Regeneration). The rest, Walk on Air 1259416, War Stomp, Escape Artist, Cannibalize, Shadowmeld, Will to Survive, Read Leyline and Skysight, are movement, escape or utility spells with no buff to time, so they are row candidates.

## Shorter cooldowns not classified here

The ledger covers majors of 60 s or more and procs. Rotational spells under 60 s without a crest piece are not classified yet; the role-critical ones need the same review. The rotation cooldowns that fill a tree's free rail seats have seats on the crest rail (`KstyleUI_ActionBars/SlabRail.lua`): the hunter's Strider Kick 1317257 (8 s cooldown, a 3 s buff), Sniper Shot, Aimed Shot and the fire traps, the mage's Fire Blast (Arcane), Cone of Cold (Fire) and Ice Barrier (Frost). Each fills only the free seats of the tree the ledger names it for.

## Not yet proved

These classes come from build 71091's data tables, not from play in the supported build. Where a row says "not confirmed in the live client", the spell's trigger or stack feed still needs one in-game check before a crest piece is built for it. Every row candidate also still needs that check that the Cooldown Manager row shows it; until both are done, the crest does not claim it.
