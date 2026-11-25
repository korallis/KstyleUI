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
| Hunter | Intimidation 19577 | 60 s | Row candidate | As above, cast through the pet |
| Rogue | Blind 2094 | 300 s | Row candidate | As above |
| Priest | Chastise 1277331 | 120 s | Row candidate | As above |
| Priest | Confounding Flash 1277455 | 120 s | Row candidate | As above |
| Druid | Challenging Roar 5209 | 600 s | Row candidate | A taunt on enemies; no buff on the player |
| Paladin | Holy Wrath 2812 | 60 s | Row candidate | An attack with no lasting effect on the player |
| Warlock | Soul Fire 6353 | 60 s | Row candidate | A cast attack; the cast ring shows it while it casts |
| Warlock | Inferno 1122 | 3600 s | Row candidate | A summon used once an hour; the pet's own frame carries it |
| Paladin | Lay on Hands 633 | 1200 s | Row candidate | An instant emergency heal with no buff to time |
| Paladin | Divine Intervention 19752 | 3600 s | Row candidate | A sacrifice on another player, used once an hour |
| Priest | Desperate Prayer 13908 | 600 s | Row candidate | An instant emergency heal with no buff to time |
| Priest | Divine Grace 1277370 | 600 s | Row candidate | Its effect is not confirmed in the live client; it stays on the row until it is |
| Druid | Rebirth 20484 | 1800 s | Row candidate | A resurrection on another player, out of the combat rotation |
| Rogue | Preparation 14185 | 600 s | Row candidate | Its effect is a reset, which the crest shows on the cooldowns it resets |
| Rogue | Premeditation 14183 | 120 s | Row candidate | Adds combo points, which the crest's combo pips already show |
| Mage | Cold Snap 12472 | 600 s | Row candidate | Its effect is a reset, which the crest shows on the cooldowns it resets |

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
| Paladin | Infusion of Light 426065 | No | Row candidate | Changes a heal the player presses; the button's overlay glow shows it |
| Paladin | Redoubt 20127 | No | Deliberately quiet | A passive block chance |
| Paladin | Unsealed Wrath 1310735 | No | Row candidate | Its trigger is not confirmed in the live client |
| Hunter | Entrapment 19184 | Yes | Deliberately quiet | A passive root chance |
| Hunter | Improved Concussive Shot 19407 | Yes | Deliberately quiet | A passive stun chance |
| Hunter | Expose Prey 1310532 | No | Row candidate | Its trigger is not confirmed in the live client |
| Hunter | Frenzy 19621 | No | Deliberately quiet | A passive on the pet |
| Hunter | Lacerating Strikes 1310533 | No | Row candidate | Its trigger is not confirmed in the live client |
| Hunter | Rapid Killing 415405 | No | Row candidate | Its effect lands on Rapid Fire's cooldown, which the crest already tracks |
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
| Mage | Fingers of Frost 400647 | No | Row candidate | Changes the next frost spell; the button's overlay glow shows it |
| Mage | Heating Up 400624 | No | Row candidate | The step before a proc, with no button of its own to press |
| Mage | Missile Barrage 400588 | No | Row candidate | Changes Arcane Missiles; the button's overlay glow shows it |
| Warlock | Aftermath 18119 | Yes | Deliberately quiet | A passive daze chance |
| Warlock | Decimation 440870 | Yes | Deliberately quiet | Hidden by the client; changes Soul Fire, whose button glows |
| Warlock | Demonic Brand 1293695 | No | Row candidate | Its trigger is not confirmed in the live client |
| Warlock | Improved Shadow Bolt 17793 | No | Deliberately quiet | A passive debuff on the target |
| Warlock | Soul Harvest 437032 | No | Row candidate | Its trigger is not confirmed in the live client |
| Druid | Improved Starfire 16850 | Yes | Deliberately quiet | Hidden by the client; a passive |
| Druid | Leader of the Pack 17007 | Yes | Deliberately quiet | A passive party aura |
| Druid | Eclipse 408248 | No | Row candidate | Changes which spell to press; the buttons' overlay glow shows it |
| Druid | Nature's Grace 16880 | No | Deliberately quiet | A passive haste after a critical hit |

## Conditional racials

Some racial spells sit in every class's set but only for the race that owns them. Those with a buff the player times are shared crest sigils (Blood Fury, Berserking, Stoneform, Perception, Will of the Forsaken, Shatter Curse, Elune's Light, Eureka!, Rapid Regeneration). The rest, Walk on Air 1259416, War Stomp, Escape Artist, Cannibalize, Shadowmeld, Will to Survive, Read Leyline and Skysight, are movement, escape or utility spells with no buff to time, so they are row candidates.

## Shorter cooldowns not classified here

The ledger covers majors of 60 s or more and procs. Rotational spells under 60 s without a crest piece are not classified yet; the role-critical ones need the same review. One example is the hunter's Strider Kick 1317257 (8 s cooldown, a 3 s buff), which sits in the hunter's Essential set with no crest piece.

## Not yet proved

These classes come from build 71091's data tables, not from play in the supported build. Where a row says "not confirmed in the live client", the spell's trigger or stack feed still needs one in-game check before a crest piece is built for it. Every row candidate also still needs that check that the Cooldown Manager row shows it; until both are done, the crest does not claim it.
