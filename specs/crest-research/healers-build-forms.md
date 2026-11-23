# Healer crests per form, stance and spec (Forever 1.60.1)

Form state: `GetShapeshiftFormID()` (Blizzard compares it in plain Lua, `Blizzard_NewPlayerExperience/Blizzard_TutorialServices.lua:38`) against Forever's constants (`Blizzard_FrameXMLBase/Constants.lua:327-336`, `Camelot/Constants.lua:14`): cat 1, travel 3, aquatic 4, bear 8 (Forever override; 5 kept for safety), Ghost Wolf 16, Shadowform 28, moonkin 31 and 35. Every choice whose spell is known is built out of combat; a form change only shows one choice per seat and hides the rest (no engine call), so it works in combat. A secret or unknown form keeps the last choice. Each seat's choice falls back down its list when a spell is not known yet (level bands).

## Druid

| Seat | Caster, travel, aquatic | Moonkin (talent, 40) | Cat | Bear |
| --- | --- | --- | --- | --- |
| Left shoulder | Moonfire on an enemy, Rejuvenation on a friend | Moonfire | Rake | Demoralizing Roar |
| Right shoulder | Insect Swarm (talent) on an enemy, Regrowth on a friend | Insect Swarm, else Regrowth | Rip | Faerie Fire |
| Inner rim | Clearcasting leaves | Clearcasting leaves | Clearcasting leaves | Clearcasting leaves |
| Top gem | Swiftmend, else Nature's Swiftness, else Innervate, ready | Hurricane ready, else Innervate | Faerie Fire on the target | Maul queued (`C_Spell.IsCurrentSpell`, `CURRENT_SPELL_CAST_CHANGED`) |
| Crown (existing) | none | none | combo claws | Lacerate talons |
| Cooldown rim (helper, pending) | Barkskin, Nature's Swiftness, Innervate, Dash, Nature's Grasp | same | Dash, Barkskin | Frenzied Regeneration, Enrage, Barkskin, Dash |

Faerie Fire (Feral) does not exist on Forever: 16857 and 17390 to 17392 have `SkillLineAbility` rows but no spell records in 1.60.1.71037, so the bear's right seed shows Faerie Fire (770, 778, 9749, 9907), your armour debuff on the target. Tree of Life is not in the client.

## Priest

| Seat | Holy or Discipline | Shadow, out of Shadowform | Shadowform |
| --- | --- | --- | --- |
| Left shoulder | Penance ready (Mind Blast before level 30) | Mind Blast ready | Mind Blast ready |
| Right shoulder | Shadowfiend ready | Shadowform, steel: not worn | Vampiric Embrace on the target (talent), else Shadowfiend ready |
| Inner rim | Inner Fire flames and halo | same | same |
| Top gem | Shadow Word: Pain on the target | same | same |
| Crown (existing) | none | Shadow Weaving candles | Shadow Weaving candles |
| Cooldown rim (helper, pending) | Power Infusion, Inner Focus, Fade, Fear Ward, race spells | Fade, Inner Focus, race spells | same |

## Shaman

| Seat | Elemental or Restoration | Enhancement (Stormstrike known) | Ghost Wolf |
| --- | --- | --- | --- |
| Spirit Poles, medals, storm orbs (existing) | unchanged | unchanged | unchanged |
| Lower ring | main-hand and off-hand imbue stones | same | same |
| Emblem | shock cooldown sweep | Stormstrike cooldown sweep | as the spec |
| Level plaque | Reincarnation ankh | same | same |
| Cooldown rim (helper, pending) | Lightning Mastery, Nature's Swiftness | Rage of the Farseer | as the spec |
