-- _classes.lua: what the HUD scene varies by class: the nine classes of WoW: Forever, each with its colour, its
-- power, its cast, its spells on the bars and in the cooldown cluster, its buffs, its stance bar and its pet.
--
--   local Classes = dofile("Tools/render/scenes/_classes.lua")
--   local spec = Classes.Get("MAGE")            -- or Classes.Get(nil) for RENDER_CLASS, then WARRIOR
--   for _, class in ipairs(Classes.ORDER) do ... end
--
-- Every spell is { "Name", iconFileID } with the icon Tools/data/abilities.json gives that class's spell, so set B
-- paints it; Tools/tests/test_render_classes.py checks each pair against the data. The colours are the values
-- RAID_CLASS_COLORS holds in the game (Blizzard_SharedXML/ClassColors.lua fills it from C_ClassColor), the power
-- tokens and types those of Enum.PowerType, the state a level 38 character fighting the mockup's crocolisk.
local Classes = {}

Classes.ORDER = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }

-- The game's power bar colours (Blizzard_UnitFrame/Mainline/PowerBarColorUtil.lua), which the unit frames
-- brighten through Theme.Brighten before they paint the power bar.
Classes.POWER_COLORS = {
	MANA = { 0, 0, 1 },
	RAGE = { 1, 0, 0 },
	FOCUS = { 1, 0.5, 0.25 },
	ENERGY = { 1, 1, 0 },
}

local MANA = { type = 0, token = "MANA", value = 1860, max = 3000 }
local RAGE = { type = 1, token = "RAGE", value = 45, max = 100 }
local ENERGY = { type = 3, token = "ENERGY", value = 80, max = 100 }

-- A cast is { "Name", icon, spellID, seconds }. A cooldown entry's third value is its state: { total, left } for a running cooldown or an aura, "proc" for
-- the activation glow, nil when ready. A buff row entry's third value is the time left the tile shows.

Classes.WARRIOR = {
	title = "Warrior", name = "Valerin", colour = { 0.78, 0.61, 0.43 }, power = RAGE,
	cast = { "Slam", 132340, 1464, 1.5 },
	bar1 = {
		{ "Heroic Strike", 132282 }, { "Slam", 132340 }, { "Charge", 132337 }, { "Rend", 132155 }, { "Thunder Clap", 136105 },
		{ "Execute", 135358 }, { "Overpower", 132223 }, { "Hamstring", 132316 }, { "Cleave", 132338 }, { "Whirlwind", 132369 },
		{ "Mortal Strike", 132355 },
	},
	bar2 = {
		{ "Battle Shout", 132333 }, { "Bloodrage", 132277 }, { "Demoralizing Shout", 132366 }, { "Sunder Armor", 132363 },
		{ "Shield Block", 132110 }, { "Taunt", 136080 }, { "Berserker Rage", 136009 }, { "Intercept", 132307 }, { "Pummel", 132938 },
		{ "Revenge", 132353 }, { "Disarm", 132343 }, { "Blood Fury", 135726 },
	},
	essential = {
		{ "Mortal Strike", 132355, { 6, 4 } }, { "Whirlwind", 132369, { 10, 8 } }, { "Overpower", 132223, { 5, 3 } },
		{ "Execute", 135358 }, { "Retaliation", 132336, { 300, 118 } }, { "Sweeping Strikes", 132306, "proc" },
	},
	utility = { { "Intercept", 132307 }, { "Hamstring", 132316 }, { "Pummel", 132938 }, { "Berserker Rage", 136009 } },
	buffs = {
		{ "Bloodrage", 132277, { 30, 24 } }, { "Blood Fury", 135726, { 25, 17 } }, { "Victory Rush", 132342, { 20, 12 } },
		{ "Shield Block", 132110, { 600, 480 } }, { "Demoralizing Shout", 132366, { 300, 180 } },
	},
	bars = { { "Battle Shout", 132333, { 120, 24 } }, { "Enrage", 136224, { 12, 12 } } },
	buffRow = {
		{ "Battle Shout", 132333, "24s" }, { "Berserker Rage", 136009, "17s" }, { "Bloodrage", 132277, "12s" },
		{ "Shield Block", 132110, "8m" }, { "Blood Fury", 135726, "3m" },
	},
	forms = { { "Battle Stance", 132349, true }, { "Defensive Stance", 132341 }, { "Berserker Stance", 132275 } },
}

Classes.PALADIN = {
	title = "Paladin", name = "Aurelis", colour = { 0.96, 0.55, 0.73 }, power = MANA,
	cast = { "Holy Light", 135920, 635, 2.5 },
	bar1 = {
		{ "Seal of Righteousness", 132325 }, { "Judgement", 135959 }, { "Holy Light", 135920 }, { "Flash of Light", 135907 },
		{ "Hammer of Justice", 135963 }, { "Consecration", 135926 }, { "Exorcism", 135903 }, { "Hammer of Wrath", 132326 },
		{ "Purify", 135949 }, { "Blessing of Might", 135906 }, { "Devotion Aura", 135893 },
	},
	bar2 = {
		{ "Blessing of Wisdom", 135970 }, { "Retribution Aura", 135873 }, { "Seal of the Crusader", 135924 }, { "Seal of Light", 135917 },
		{ "Divine Protection", 135954 }, { "Divine Shield", 135896 }, { "Lay on Hands", 135928 }, { "Blessing of Protection", 135964 },
		{ "Blessing of Freedom", 135968 }, { "Turn Undead", 135983 }, { "Redemption", 135955 }, { "Righteous Fury", 135962 },
	},
	essential = {
		{ "Judgement", 135959, { 10, 6 } }, { "Hammer of Justice", 135963, { 60, 42 } }, { "Consecration", 135926, { 8, 5 } },
		{ "Exorcism", 135903 }, { "Hammer of Wrath", 132326, { 6, 3 } }, { "Flash of Light", 135907, "proc" },
	},
	utility = { { "Divine Protection", 135954 }, { "Lay on Hands", 135928 }, { "Blessing of Protection", 135964 }, { "Blessing of Freedom", 135968 } },
	buffs = {
		{ "Blessing of Might", 135906, { 300, 180 } }, { "Seal of Righteousness", 132325, { 30, 24 } }, { "Devotion Aura", 135893, { 600, 480 } },
		{ "Blessing of Wisdom", 135970, { 300, 120 } }, { "Righteous Fury", 135962, { 1800, 1200 } },
	},
	bars = { { "Seal of Righteousness", 132325, { 30, 24 } }, { "Blessing of Might", 135906, { 300, 180 } } },
	buffRow = {
		{ "Seal of Righteousness", 132325, "24s" }, { "Blessing of Wisdom", 135970, "2m" }, { "Blessing of Might", 135906, "3m" },
		{ "Devotion Aura", 135893, "8m" }, { "Righteous Fury", 135962, "20m" },
	},
}

Classes.HUNTER = {
	title = "Hunter", name = "Thessaly", colour = { 0.67, 0.83, 0.45 }, power = MANA,
	cast = { "Aimed Shot", 135130, 19434, 3 },
	bar1 = {
		{ "Arcane Shot", 132218 }, { "Aimed Shot", 135130 }, { "Multi-Shot", 132330 }, { "Serpent Sting", 132204 },
		{ "Concussive Shot", 135860 }, { "Hunter's Mark", 132212 }, { "Raptor Strike", 132223 }, { "Mongoose Bite", 132215 },
		{ "Wing Clip", 132309 }, { "Scorpid Sting", 132169 }, { "Distracting Shot", 135736 },
	},
	bar2 = {
		{ "Aspect of the Hawk", 136076 }, { "Aspect of the Monkey", 132159 }, { "Aspect of the Cheetah", 132242 }, { "Freezing Trap", 135834 },
		{ "Immolation Trap", 135813 }, { "Feign Death", 132293 }, { "Disengage", 132294 }, { "Rapid Fire", 132208 }, { "Mend Pet", 132179 },
		{ "Call Pet", 132161 }, { "Revive Pet", 132163 }, { "Scare Beast", 132118 },
	},
	essential = {
		{ "Aimed Shot", 135130, { 6, 4 } }, { "Multi-Shot", 132330, { 10, 8 } }, { "Concussive Shot", 135860, { 12, 3 } },
		{ "Arcane Shot", 132218 }, { "Rapid Fire", 132208, { 300, 118 } }, { "Mongoose Bite", 132215, "proc" },
	},
	utility = { { "Feign Death", 132293 }, { "Disengage", 132294 }, { "Freezing Trap", 135834 }, { "Scare Beast", 132118 } },
	buffs = {
		{ "Rapid Fire", 132208, { 15, 9 } }, { "Mend Pet", 132179, { 15, 12 } }, { "Aspect of the Hawk", 136076, { 600, 480 } },
		{ "Hunter's Mark", 132212, { 120, 90 } }, { "Track Beasts", 132328, { 600, 600 } },
	},
	bars = { { "Rapid Fire", 132208, { 15, 9 } }, { "Mend Pet", 132179, { 15, 12 } } },
	buffRow = {
		{ "Rapid Fire", 132208, "9s" }, { "Mend Pet", 132179, "12s" }, { "Hunter's Mark", 132212, "1m" },
		{ "Aspect of the Hawk", 136076, "8m" }, { "Track Beasts", 132328, "" },
	},
	pet = {
		name = "Bristleback", level = 37, health = 1240, healthMax = 1800, power = 70, powerMax = 100, powerType = 2, powerToken = "FOCUS",
		actions = {
			{ "Bite", 132278 }, { "Claw", 132140 }, { "Growl", 132270 }, { "Cower", 132118 }, { "Dash", 132120 },
			{ "Charge", 132184 }, { "Great Stamina", 136112 }, { "Natural Armor", 136094 },
		},
	},
}

Classes.ROGUE = {
	title = "Rogue", name = "Rokhan", colour = { 1, 0.96, 0.41 }, power = ENERGY, combo = 3,
	bar1 = {
		{ "Sinister Strike", 136189 }, { "Eviscerate", 132292 }, { "Slice and Dice", 132306 }, { "Backstab", 132090 }, { "Gouge", 132155 },
		{ "Kick", 132219 }, { "Kidney Shot", 132298 }, { "Rupture", 132302 }, { "Expose Armor", 132354 }, { "Feint", 132294 },
		{ "Garrote", 132297 },
	},
	bar2 = {
		{ "Stealth", 132320 }, { "Sap", 132310 }, { "Cheap Shot", 132092 }, { "Ambush", 132282 }, { "Sprint", 132307 }, { "Evasion", 136205 },
		{ "Vanish", 132331 }, { "Distract", 132289 }, { "Pick Pocket", 133644 }, { "Pick Lock", 136058 }, { "Blind", 136175 },
		{ "Riposte", 132336 },
	},
	essential = {
		{ "Kick", 132219, { 10, 6 } }, { "Gouge", 132155, { 10, 8 } }, { "Kidney Shot", 132298, { 20, 3 } },
		{ "Eviscerate", 132292 }, { "Sprint", 132307, { 300, 118 } }, { "Riposte", 132336, "proc" },
	},
	utility = { { "Evasion", 136205 }, { "Vanish", 132331 }, { "Blind", 136175 }, { "Distract", 132289 } },
	buffs = {
		{ "Slice and Dice", 132306, { 21, 14 } }, { "Sprint", 132307, { 15, 9 } }, { "Evasion", 136205, { 15, 12 } },
		{ "Blade Flurry", 132350, { 15, 10 } }, { "Adrenaline Rush", 136206, { 15, 7 } },
	},
	bars = { { "Slice and Dice", 132306, { 21, 14 } }, { "Evasion", 136205, { 15, 12 } } },
	buffRow = {
		{ "Adrenaline Rush", 136206, "7s" }, { "Sprint", 132307, "9s" }, { "Blade Flurry", 132350, "10s" },
		{ "Evasion", 136205, "12s" }, { "Slice and Dice", 132306, "14s" },
	},
	forms = { { "Stealth", 132320 } },
}

Classes.PRIEST = {
	title = "Priest", name = "Brunhild", colour = { 1, 1, 1 }, power = MANA,
	cast = { "Heal", 135915, 2054, 3 },
	bar1 = {
		{ "Smite", 135924 }, { "Heal", 135915 }, { "Flash Heal", 135907 }, { "Renew", 135953 }, { "Power Word: Shield", 135940 },
		{ "Shadow Word: Pain", 136207 }, { "Mind Blast", 136224 }, { "Holy Fire", 135972 }, { "Psychic Scream", 136184 },
		{ "Dispel Magic", 135894 }, { "Power Word: Fortitude", 135987 },
	},
	bar2 = {
		{ "Inner Fire", 135926 }, { "Fade", 135994 }, { "Mind Soothe", 135933 }, { "Cure Disease", 135935 }, { "Abolish Disease", 136066 },
		{ "Resurrection", 135955 }, { "Mind Control", 136206 }, { "Mind Vision", 135934 }, { "Levitate", 135928 },
		{ "Shackle Undead", 136091 }, { "Prayer of Healing", 135943 }, { "Devouring Plague", 252997 },
	},
	essential = {
		{ "Mind Blast", 136224, { 8, 5 } }, { "Power Word: Shield", 135940, { 4, 3 } }, { "Psychic Scream", 136184, { 30, 22 } },
		{ "Holy Fire", 135972 }, { "Fade", 135994, { 30, 18 } }, { "Smite", 135924, "proc" },
	},
	utility = { { "Dispel Magic", 135894 }, { "Cure Disease", 135935 }, { "Shackle Undead", 136091 }, { "Mind Soothe", 135933 } },
	buffs = {
		{ "Renew", 135953, { 15, 9 } }, { "Power Word: Shield", 135940, { 30, 24 } }, { "Inner Fire", 135926, { 600, 480 } },
		{ "Shadow Protection", 136121, { 600, 300 } }, { "Power Word: Fortitude", 135987, { 1800, 1200 } },
	},
	bars = { { "Power Word: Shield", 135940, { 30, 24 } }, { "Renew", 135953, { 15, 9 } } },
	buffRow = {
		{ "Renew", 135953, "9s" }, { "Power Word: Shield", 135940, "24s" }, { "Shadow Protection", 136121, "5m" },
		{ "Inner Fire", 135926, "8m" }, { "Power Word: Fortitude", 135987, "20m" },
	},
}

Classes.SHAMAN = {
	title = "Shaman", name = "Gorka", colour = { 0, 0.44, 0.87 }, power = MANA,
	cast = { "Lightning Bolt", 136048, 403, 2.5 },
	bar1 = {
		{ "Lightning Bolt", 136048 }, { "Earth Shock", 136026 }, { "Flame Shock", 135813 }, { "Frost Shock", 135849 }, { "Healing Wave", 136052 },
		{ "Lesser Healing Wave", 136043 }, { "Chain Lightning", 136015 }, { "Lightning Shield", 136048 }, { "Purge", 136075 },
		{ "Searing Totem", 135825 }, { "Strength of Earth Totem", 136023 },
	},
	bar2 = {
		{ "Stoneskin Totem", 136098 }, { "Healing Stream Totem", 135127 }, { "Earthbind Totem", 136102 }, { "Stoneclaw Totem", 136097 },
		{ "Grounding Totem", 136039 }, { "Windfury Totem", 136114 }, { "Rockbiter Weapon", 136086 }, { "Windfury Weapon", 136018 },
		{ "Ghost Wolf", 136095 }, { "Ancestral Spirit", 136077 }, { "Cure Poison", 136067 }, { "Astral Recall", 136010 },
	},
	essential = {
		{ "Earth Shock", 136026, { 6, 4 } }, { "Flame Shock", 135813, { 6, 2 } }, { "Chain Lightning", 136015, { 6, 3 } },
		{ "Frost Shock", 135849 }, { "Grounding Totem", 136039, { 15, 10 } }, { "Lightning Bolt", 136048, "proc" },
	},
	utility = { { "Purge", 136075 }, { "Earthbind Totem", 136102 }, { "Ghost Wolf", 136095 }, { "Cure Poison", 136067 } },
	buffs = {
		{ "Healing Stream Totem", 135127, { 60, 40 } }, { "Stoneskin Totem", 136098, { 120, 60 } }, { "Strength of Earth Totem", 136023, { 120, 80 } },
		{ "Lightning Shield", 136048, { 600, 420 } }, { "Windfury Weapon", 136018, { 1800, 900 } },
	},
	bars = { { "Lightning Shield", 136048, { 600, 420 } }, { "Strength of Earth Totem", 136023, { 120, 80 } } },
	buffRow = {
		{ "Healing Stream Totem", 135127, "40s" }, { "Stoneskin Totem", 136098, "1m" }, { "Strength of Earth Totem", 136023, "1m" },
		{ "Lightning Shield", 136048, "7m" }, { "Windfury Weapon", 136018, "15m" },
	},
}

Classes.MAGE = {
	title = "Mage", name = "Tinkwee", colour = { 0.25, 0.78, 0.92 }, power = MANA,
	cast = { "Fireball", 135812, 133, 3 },
	bar1 = {
		{ "Fireball", 135812 }, { "Frostbolt", 135846 }, { "Fire Blast", 135807 }, { "Arcane Missiles", 136096 }, { "Scorch", 135827 },
		{ "Frost Nova", 135848 }, { "Cone of Cold", 135852 }, { "Arcane Explosion", 136116 }, { "Flamestrike", 135826 },
		{ "Blizzard", 135857 }, { "Polymorph", 136071 },
	},
	bar2 = {
		{ "Arcane Intellect", 135932 }, { "Frost Armor", 135843 }, { "Mana Shield", 136153 }, { "Counterspell", 135856 }, { "Blink", 135736 },
		{ "Evocation", 136075 }, { "Dampen Magic", 136006 }, { "Amplify Magic", 135907 }, { "Slow Fall", 135992 },
		{ "Remove Lesser Curse", 136082 }, { "Conjure Water", 132793 }, { "Conjure Food", 133952 },
	},
	essential = {
		{ "Fire Blast", 135807, { 8, 5 } }, { "Frost Nova", 135848, { 25, 18 } }, { "Cone of Cold", 135852, { 10, 7 } },
		{ "Counterspell", 135856, { 30, 3 } }, { "Blink", 135736, { 15, 11 } }, { "Arcane Missiles", 136096, "proc" },
	},
	utility = { { "Evocation", 136075 }, { "Polymorph", 136071 }, { "Mana Shield", 136153 }, { "Remove Lesser Curse", 136082 } },
	buffs = {
		{ "Fire Ward", 135806, { 30, 20 } }, { "Mana Shield", 136153, { 60, 40 } }, { "Dampen Magic", 136006, { 600, 300 } },
		{ "Frost Armor", 135843, { 1800, 900 } }, { "Arcane Intellect", 135932, { 1800, 1200 } },
	},
	bars = { { "Mana Shield", 136153, { 60, 40 } }, { "Fire Ward", 135806, { 30, 20 } } },
	buffRow = {
		{ "Fire Ward", 135806, "20s" }, { "Mana Shield", 136153, "40s" }, { "Dampen Magic", 136006, "5m" },
		{ "Frost Armor", 135843, "15m" }, { "Arcane Intellect", 135932, "20m" },
	},
}

Classes.WARLOCK = {
	title = "Warlock", name = "Morveth", colour = { 0.53, 0.53, 0.93 }, power = MANA,
	cast = { "Shadow Bolt", 136197, 686, 3 },
	bar1 = {
		{ "Shadow Bolt", 136197 }, { "Immolate", 135817 }, { "Corruption", 136118 }, { "Curse of Weakness", 136138 },
		{ "Curse of Recklessness", 136225 }, { "Drain Life", 136169 }, { "Drain Soul", 136163 }, { "Life Tap", 136126 }, { "Fear", 136183 },
		{ "Death Coil", 136145 }, { "Searing Pain", 135827 },
	},
	bar2 = {
		{ "Demon Armor", 136185 }, { "Health Funnel", 136168 }, { "Create Healthstone", 135230 }, { "Create Soulstone", 136210 },
		{ "Summon Imp", 136218 }, { "Summon Voidwalker", 136221 }, { "Summon Succubus", 136220 }, { "Rain of Fire", 136186 },
		{ "Howl of Terror", 136147 }, { "Banish", 136135 }, { "Eye of Kilrogg", 136155 }, { "Curse of Tongues", 136140 },
	},
	essential = {
		{ "Death Coil", 136145, { 120, 42 } }, { "Howl of Terror", 136147, { 40, 18 } }, { "Shadowburn", 136191, { 15, 9 } },
		{ "Immolate", 135817 }, { "Corruption", 136118 }, { "Shadow Bolt", 136197, "proc" },
	},
	utility = { { "Fear", 136183 }, { "Banish", 136135 }, { "Health Funnel", 136168 }, { "Life Tap", 136126 } },
	buffs = {
		{ "Shadow Ward", 136121, { 30, 20 } }, { "Fire Shield", 135806, { 180, 90 } }, { "Unending Breath", 136148, { 600, 300 } },
		{ "Demon Skin", 136185, { 1800, 1200 } }, { "Blood Pact", 136124, { 1800, 1800 } },
	},
	bars = { { "Demon Skin", 136185, { 1800, 1200 } }, { "Shadow Ward", 136121, { 30, 20 } } },
	buffRow = {
		{ "Shadow Ward", 136121, "20s" }, { "Fire Shield", 135806, "1m" }, { "Unending Breath", 136148, "5m" },
		{ "Demon Skin", 136185, "20m" }, { "Blood Pact", 136124, "" },
	},
	pet = {
		name = "Zabnik", level = 38, health = 920, healthMax = 1500, power = 820, powerMax = 1100, powerType = 0, powerToken = "MANA",
		actions = { { "Firebolt", 135809 }, { "Fire Shield", 135806 }, { "Blood Pact", 136124 }, { "Phase Shift", 136164 } },
	},
}

Classes.DRUID = {
	title = "Druid", name = "Tahoma", colour = { 1, 0.49, 0.04 }, power = MANA,
	cast = { "Wrath", 136006, 5176, 2 },
	bar1 = {
		{ "Wrath", 136006 }, { "Moonfire", 136096 }, { "Starfire", 135753 }, { "Entangling Roots", 136100 }, { "Faerie Fire", 136033 },
		{ "Healing Touch", 136041 }, { "Regrowth", 136085 }, { "Rejuvenation", 136081 }, { "Thorns", 136104 },
		{ "Mark of the Wild", 136078 }, { "Hibernate", 136090 },
	},
	bar2 = {
		{ "Bear Form", 132276 }, { "Cat Form", 132115 }, { "Travel Form", 132144 }, { "Aquatic Form", 132112 }, { "Remove Curse", 135952 },
		{ "Abolish Poison", 136068 }, { "Rebirth", 136080 }, { "Tranquility", 136107 }, { "Soothe Animal", 132163 },
		{ "Barkskin", 136097 }, { "Innervate", 136048 }, { "Dash", 132120 },
	},
	essential = {
		{ "Barkskin", 136097, { 60, 42 } }, { "Tranquility", 136107, { 600, 118 } }, { "Innervate", 136048, { 360, 200 } },
		{ "Faerie Fire", 136033 }, { "Moonfire", 136096 }, { "Starfire", 135753, "proc" },
	},
	utility = { { "Hibernate", 136090 }, { "Remove Curse", 135952 }, { "Abolish Poison", 136068 }, { "Rebirth", 136080 } },
	buffs = {
		{ "Rejuvenation", 136081, { 12, 8 } }, { "Barkskin", 136097, { 15, 12 } }, { "Regrowth", 136085, { 21, 15 } },
		{ "Thorns", 136104, { 600, 480 } }, { "Mark of the Wild", 136078, { 1800, 1200 } },
	},
	bars = { { "Rejuvenation", 136081, { 12, 8 } }, { "Regrowth", 136085, { 21, 15 } } },
	buffRow = {
		{ "Rejuvenation", 136081, "8s" }, { "Barkskin", 136097, "12s" }, { "Regrowth", 136085, "15s" },
		{ "Thorns", 136104, "8m" }, { "Mark of the Wild", 136078, "20m" },
	},
	forms = { { "Bear Form", 132276 }, { "Aquatic Form", 132112 }, { "Cat Form", 132115 }, { "Travel Form", 132144 } },
}

-- Get(class) -> the class token and its entry: the given class, else RENDER_CLASS, else WARRIOR. An unknown
-- class is an error that names the nine.
function Classes.Get(class)
	class = tostring(class or os.getenv("RENDER_CLASS") or "WARRIOR"):upper()
	local spec = Classes[class]
	if type(spec) ~= "table" or spec == Classes.POWER_COLORS then
		error("RENDER_CLASS must be one of " .. table.concat(Classes.ORDER, ", ") .. ", not " .. class)
	end
	return class, spec
end

-- Hex(colour) -> the colour's six-digit hex, as RAID_CLASS_COLORS.<class>.colorStr spells it without the alpha.
function Classes.Hex(colour)
	return string.format("%02X%02X%02X", math.floor(colour[1] * 255 + 0.5), math.floor(colour[2] * 255 + 0.5), math.floor(colour[3] * 255 + 0.5))
end

return Classes
