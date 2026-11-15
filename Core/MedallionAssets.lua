-- MedallionAssets.lua: the Medallions portrait and crest files, written by Tools/medallions/medallions.py bake.
local _, ns = ...

local DIR = "Interface\\AddOns\\KstyleUI\\Media\\Textures\\Medallions\\"

ns.MedallionAssets = {
	portraits = {
		Human = {
			MAGE = {
				[3] = { badge = DIR .. "Badges\\human_mage_female.png", bust = DIR .. "Busts\\human_mage_female.png" },
			},
		},
		NightElf = {
			PRIEST = {
				[3] = { badge = DIR .. "Badges\\nightelf_priest_female.png", bust = DIR .. "Busts\\nightelf_priest_female.png" },
			},
		},
		Gnome = {
			ROGUE = {
				[2] = { badge = DIR .. "Badges\\gnome_rogue_male.png", bust = DIR .. "Busts\\gnome_rogue_male.png" },
			},
		},
		Orc = {
			WARRIOR = {
				[2] = { badge = DIR .. "Badges\\orc_warrior_male.png", bust = DIR .. "Busts\\orc_warrior_male.png" },
			},
		},
	},
	crests = {
		Human = {
			WARRIOR = { crest = DIR .. "Crests\\human_warrior.png", glow = DIR .. "Crests\\human_warrior_glow.png", metal = DIR .. "Crests\\human_warrior_metal.png" },
			PALADIN = { crest = DIR .. "Crests\\human_paladin.png", glow = DIR .. "Crests\\human_paladin_glow.png", metal = DIR .. "Crests\\human_paladin_metal.png" },
			MAGE = { crest = DIR .. "Crests\\human_mage.png", glow = DIR .. "Crests\\human_mage_glow.png", metal = DIR .. "Crests\\human_mage_metal.png" },
		},
		Troll = {
			PRIEST = { crest = DIR .. "Crests\\troll_priest.png", glow = DIR .. "Crests\\troll_priest_glow.png", metal = DIR .. "Crests\\troll_priest_metal.png" },
			SHAMAN = { crest = DIR .. "Crests\\troll_shaman.png", glow = DIR .. "Crests\\troll_shaman_glow.png", metal = DIR .. "Crests\\troll_shaman_metal.png" },
			ROGUE = { crest = DIR .. "Crests\\troll_rogue.png", glow = DIR .. "Crests\\troll_rogue_glow.png", metal = DIR .. "Crests\\troll_rogue_metal.png" },
		},
	},
}
