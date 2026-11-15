-- MedallionAssets.lua: the Medallions portrait and crest files, written by Tools/medallions/medallions.py bake.
local _, ns = ...

local DIR = "Interface\\AddOns\\KstyleUI\\Media\\Textures\\Medallions\\"

ns.MedallionAssets = {
	portraits = {
		Human = {
			WARRIOR = {
				[2] = { badge = DIR .. "Badges\\human_warrior_male.png", bust = DIR .. "Busts\\human_warrior_male.png" },
				[3] = { badge = DIR .. "Badges\\human_warrior_female.png", bust = DIR .. "Busts\\human_warrior_female.png" },
			},
			PALADIN = {
				[2] = { badge = DIR .. "Badges\\human_paladin_male.png", bust = DIR .. "Busts\\human_paladin_male.png" },
				[3] = { badge = DIR .. "Badges\\human_paladin_female.png", bust = DIR .. "Busts\\human_paladin_female.png" },
			},
			PRIEST = {
				[2] = { badge = DIR .. "Badges\\human_priest_male.png", bust = DIR .. "Busts\\human_priest_male.png" },
				[3] = { badge = DIR .. "Badges\\human_priest_female.png", bust = DIR .. "Busts\\human_priest_female.png" },
			},
			ROGUE = {
				[2] = { badge = DIR .. "Badges\\human_rogue_male.png", bust = DIR .. "Busts\\human_rogue_male.png" },
				[3] = { badge = DIR .. "Badges\\human_rogue_female.png", bust = DIR .. "Busts\\human_rogue_female.png" },
			},
			MAGE = {
				[2] = { badge = DIR .. "Badges\\human_mage_male.png", bust = DIR .. "Busts\\human_mage_male.png" },
				[3] = { badge = DIR .. "Badges\\human_mage_female.png", bust = DIR .. "Busts\\human_mage_female.png" },
			},
			WARLOCK = {
				[2] = { badge = DIR .. "Badges\\human_warlock_male.png", bust = DIR .. "Busts\\human_warlock_male.png" },
				[3] = { badge = DIR .. "Badges\\human_warlock_female.png", bust = DIR .. "Busts\\human_warlock_female.png" },
			},
			HUNTER = {
				[2] = { badge = DIR .. "Badges\\human_hunter_male.png", bust = DIR .. "Busts\\human_hunter_male.png" },
				[3] = { badge = DIR .. "Badges\\human_hunter_female.png", bust = DIR .. "Busts\\human_hunter_female.png" },
			},
		},
		Dwarf = {
			WARRIOR = {
				[2] = { badge = DIR .. "Badges\\dwarf_warrior_male.png", bust = DIR .. "Busts\\dwarf_warrior_male.png" },
				[3] = { badge = DIR .. "Badges\\dwarf_warrior_female.png", bust = DIR .. "Busts\\dwarf_warrior_female.png" },
			},
			PALADIN = {
				[2] = { badge = DIR .. "Badges\\dwarf_paladin_male.png", bust = DIR .. "Busts\\dwarf_paladin_male.png" },
				[3] = { badge = DIR .. "Badges\\dwarf_paladin_female.png", bust = DIR .. "Busts\\dwarf_paladin_female.png" },
			},
			PRIEST = {
				[2] = { badge = DIR .. "Badges\\dwarf_priest_male.png", bust = DIR .. "Busts\\dwarf_priest_male.png" },
				[3] = { badge = DIR .. "Badges\\dwarf_priest_female.png", bust = DIR .. "Busts\\dwarf_priest_female.png" },
			},
			SHAMAN = {
				[2] = { badge = DIR .. "Badges\\dwarf_shaman_male.png", bust = DIR .. "Busts\\dwarf_shaman_male.png" },
				[3] = { badge = DIR .. "Badges\\dwarf_shaman_female.png", bust = DIR .. "Busts\\dwarf_shaman_female.png" },
			},
			ROGUE = {
				[2] = { badge = DIR .. "Badges\\dwarf_rogue_male.png", bust = DIR .. "Busts\\dwarf_rogue_male.png" },
				[3] = { badge = DIR .. "Badges\\dwarf_rogue_female.png", bust = DIR .. "Busts\\dwarf_rogue_female.png" },
			},
			HUNTER = {
				[2] = { badge = DIR .. "Badges\\dwarf_hunter_male.png", bust = DIR .. "Busts\\dwarf_hunter_male.png" },
				[3] = { badge = DIR .. "Badges\\dwarf_hunter_female.png", bust = DIR .. "Busts\\dwarf_hunter_female.png" },
			},
		},
		NightElf = {
			WARRIOR = {
				[2] = { badge = DIR .. "Badges\\nightelf_warrior_male.png", bust = DIR .. "Busts\\nightelf_warrior_male.png" },
				[3] = { badge = DIR .. "Badges\\nightelf_warrior_female.png", bust = DIR .. "Busts\\nightelf_warrior_female.png" },
			},
			PRIEST = {
				[2] = { badge = DIR .. "Badges\\nightelf_priest_male.png", bust = DIR .. "Busts\\nightelf_priest_male.png" },
				[3] = { badge = DIR .. "Badges\\nightelf_priest_female.png", bust = DIR .. "Busts\\nightelf_priest_female.png" },
			},
			DRUID = {
				[2] = { badge = DIR .. "Badges\\nightelf_druid_male.png", bust = DIR .. "Busts\\nightelf_druid_male.png" },
				[3] = { badge = DIR .. "Badges\\nightelf_druid_female.png", bust = DIR .. "Busts\\nightelf_druid_female.png" },
			},
			ROGUE = {
				[2] = { badge = DIR .. "Badges\\nightelf_rogue_male.png", bust = DIR .. "Busts\\nightelf_rogue_male.png" },
				[3] = { badge = DIR .. "Badges\\nightelf_rogue_female.png", bust = DIR .. "Busts\\nightelf_rogue_female.png" },
			},
			HUNTER = {
				[2] = { badge = DIR .. "Badges\\nightelf_hunter_male.png", bust = DIR .. "Busts\\nightelf_hunter_male.png" },
				[3] = { badge = DIR .. "Badges\\nightelf_hunter_female.png", bust = DIR .. "Busts\\nightelf_hunter_female.png" },
			},
		},
		Gnome = {
			WARRIOR = {
				[2] = { badge = DIR .. "Badges\\gnome_warrior_male.png", bust = DIR .. "Busts\\gnome_warrior_male.png" },
				[3] = { badge = DIR .. "Badges\\gnome_warrior_female.png", bust = DIR .. "Busts\\gnome_warrior_female.png" },
			},
			PRIEST = {
				[2] = { badge = DIR .. "Badges\\gnome_priest_male.png", bust = DIR .. "Busts\\gnome_priest_male.png" },
				[3] = { badge = DIR .. "Badges\\gnome_priest_female.png", bust = DIR .. "Busts\\gnome_priest_female.png" },
			},
			ROGUE = {
				[2] = { badge = DIR .. "Badges\\gnome_rogue_male.png", bust = DIR .. "Busts\\gnome_rogue_male.png" },
				[3] = { badge = DIR .. "Badges\\gnome_rogue_female.png", bust = DIR .. "Busts\\gnome_rogue_female.png" },
			},
			MAGE = {
				[2] = { badge = DIR .. "Badges\\gnome_mage_male.png", bust = DIR .. "Busts\\gnome_mage_male.png" },
				[3] = { badge = DIR .. "Badges\\gnome_mage_female.png", bust = DIR .. "Busts\\gnome_mage_female.png" },
			},
			WARLOCK = {
				[2] = { badge = DIR .. "Badges\\gnome_warlock_male.png", bust = DIR .. "Busts\\gnome_warlock_male.png" },
				[3] = { badge = DIR .. "Badges\\gnome_warlock_female.png", bust = DIR .. "Busts\\gnome_warlock_female.png" },
			},
		},
		Orc = {
			WARRIOR = {
				[2] = { badge = DIR .. "Badges\\orc_warrior_male.png", bust = DIR .. "Busts\\orc_warrior_male.png" },
				[3] = { badge = DIR .. "Badges\\orc_warrior_female.png", bust = DIR .. "Busts\\orc_warrior_female.png" },
			},
			SHAMAN = {
				[2] = { badge = DIR .. "Badges\\orc_shaman_male.png", bust = DIR .. "Busts\\orc_shaman_male.png" },
				[3] = { badge = DIR .. "Badges\\orc_shaman_female.png", bust = DIR .. "Busts\\orc_shaman_female.png" },
			},
			ROGUE = {
				[2] = { badge = DIR .. "Badges\\orc_rogue_male.png", bust = DIR .. "Busts\\orc_rogue_male.png" },
				[3] = { badge = DIR .. "Badges\\orc_rogue_female.png", bust = DIR .. "Busts\\orc_rogue_female.png" },
			},
			MAGE = {
				[2] = { badge = DIR .. "Badges\\orc_mage_male.png", bust = DIR .. "Busts\\orc_mage_male.png" },
				[3] = { badge = DIR .. "Badges\\orc_mage_female.png", bust = DIR .. "Busts\\orc_mage_female.png" },
			},
			WARLOCK = {
				[2] = { badge = DIR .. "Badges\\orc_warlock_male.png", bust = DIR .. "Busts\\orc_warlock_male.png" },
				[3] = { badge = DIR .. "Badges\\orc_warlock_female.png", bust = DIR .. "Busts\\orc_warlock_female.png" },
			},
			HUNTER = {
				[2] = { badge = DIR .. "Badges\\orc_hunter_male.png", bust = DIR .. "Busts\\orc_hunter_male.png" },
				[3] = { badge = DIR .. "Badges\\orc_hunter_female.png", bust = DIR .. "Busts\\orc_hunter_female.png" },
			},
		},
		Scourge = {
			WARRIOR = {
				[2] = { badge = DIR .. "Badges\\scourge_warrior_male.png", bust = DIR .. "Busts\\scourge_warrior_male.png" },
				[3] = { badge = DIR .. "Badges\\scourge_warrior_female.png", bust = DIR .. "Busts\\scourge_warrior_female.png" },
			},
			PALADIN = {
				[2] = { badge = DIR .. "Badges\\scourge_paladin_male.png", bust = DIR .. "Busts\\scourge_paladin_male.png" },
				[3] = { badge = DIR .. "Badges\\scourge_paladin_female.png", bust = DIR .. "Busts\\scourge_paladin_female.png" },
			},
			PRIEST = {
				[2] = { badge = DIR .. "Badges\\scourge_priest_male.png", bust = DIR .. "Busts\\scourge_priest_male.png" },
				[3] = { badge = DIR .. "Badges\\scourge_priest_female.png", bust = DIR .. "Busts\\scourge_priest_female.png" },
			},
			ROGUE = {
				[2] = { badge = DIR .. "Badges\\scourge_rogue_male.png", bust = DIR .. "Busts\\scourge_rogue_male.png" },
				[3] = { badge = DIR .. "Badges\\scourge_rogue_female.png", bust = DIR .. "Busts\\scourge_rogue_female.png" },
			},
			MAGE = {
				[2] = { badge = DIR .. "Badges\\scourge_mage_male.png", bust = DIR .. "Busts\\scourge_mage_male.png" },
				[3] = { badge = DIR .. "Badges\\scourge_mage_female.png", bust = DIR .. "Busts\\scourge_mage_female.png" },
			},
			WARLOCK = {
				[2] = { badge = DIR .. "Badges\\scourge_warlock_male.png", bust = DIR .. "Busts\\scourge_warlock_male.png" },
				[3] = { badge = DIR .. "Badges\\scourge_warlock_female.png", bust = DIR .. "Busts\\scourge_warlock_female.png" },
			},
		},
		Tauren = {
			WARRIOR = {
				[2] = { badge = DIR .. "Badges\\tauren_warrior_male.png", bust = DIR .. "Busts\\tauren_warrior_male.png" },
				[3] = { badge = DIR .. "Badges\\tauren_warrior_female.png", bust = DIR .. "Busts\\tauren_warrior_female.png" },
			},
			SHAMAN = {
				[2] = { badge = DIR .. "Badges\\tauren_shaman_male.png", bust = DIR .. "Busts\\tauren_shaman_male.png" },
				[3] = { badge = DIR .. "Badges\\tauren_shaman_female.png", bust = DIR .. "Busts\\tauren_shaman_female.png" },
			},
			DRUID = {
				[2] = { badge = DIR .. "Badges\\tauren_druid_male.png", bust = DIR .. "Busts\\tauren_druid_male.png" },
				[3] = { badge = DIR .. "Badges\\tauren_druid_female.png", bust = DIR .. "Busts\\tauren_druid_female.png" },
			},
			HUNTER = {
				[2] = { badge = DIR .. "Badges\\tauren_hunter_male.png", bust = DIR .. "Busts\\tauren_hunter_male.png" },
				[3] = { badge = DIR .. "Badges\\tauren_hunter_female.png", bust = DIR .. "Busts\\tauren_hunter_female.png" },
			},
		},
		Troll = {
			WARRIOR = {
				[2] = { badge = DIR .. "Badges\\troll_warrior_male.png", bust = DIR .. "Busts\\troll_warrior_male.png" },
				[3] = { badge = DIR .. "Badges\\troll_warrior_female.png", bust = DIR .. "Busts\\troll_warrior_female.png" },
			},
			PRIEST = {
				[2] = { badge = DIR .. "Badges\\troll_priest_male.png", bust = DIR .. "Busts\\troll_priest_male.png" },
				[3] = { badge = DIR .. "Badges\\troll_priest_female.png", bust = DIR .. "Busts\\troll_priest_female.png" },
			},
			SHAMAN = {
				[2] = { badge = DIR .. "Badges\\troll_shaman_male.png", bust = DIR .. "Busts\\troll_shaman_male.png" },
				[3] = { badge = DIR .. "Badges\\troll_shaman_female.png", bust = DIR .. "Busts\\troll_shaman_female.png" },
			},
			ROGUE = {
				[2] = { badge = DIR .. "Badges\\troll_rogue_male.png", bust = DIR .. "Busts\\troll_rogue_male.png" },
				[3] = { badge = DIR .. "Badges\\troll_rogue_female.png", bust = DIR .. "Busts\\troll_rogue_female.png" },
			},
			MAGE = {
				[2] = { badge = DIR .. "Badges\\troll_mage_male.png", bust = DIR .. "Busts\\troll_mage_male.png" },
				[3] = { badge = DIR .. "Badges\\troll_mage_female.png", bust = DIR .. "Busts\\troll_mage_female.png" },
			},
			WARLOCK = {
				[2] = { badge = DIR .. "Badges\\troll_warlock_male.png", bust = DIR .. "Busts\\troll_warlock_male.png" },
				[3] = { badge = DIR .. "Badges\\troll_warlock_female.png", bust = DIR .. "Busts\\troll_warlock_female.png" },
			},
			HUNTER = {
				[2] = { badge = DIR .. "Badges\\troll_hunter_male.png", bust = DIR .. "Busts\\troll_hunter_male.png" },
				[3] = { badge = DIR .. "Badges\\troll_hunter_female.png", bust = DIR .. "Busts\\troll_hunter_female.png" },
			},
		},
		Skyborne = {
			WARRIOR = {
				[2] = { badge = DIR .. "Badges\\skyborne_warrior_male.png", bust = DIR .. "Busts\\skyborne_warrior_male.png" },
				[3] = { badge = DIR .. "Badges\\skyborne_warrior_female.png", bust = DIR .. "Busts\\skyborne_warrior_female.png" },
			},
			SHAMAN = {
				[2] = { badge = DIR .. "Badges\\skyborne_shaman_male.png", bust = DIR .. "Busts\\skyborne_shaman_male.png" },
				[3] = { badge = DIR .. "Badges\\skyborne_shaman_female.png", bust = DIR .. "Busts\\skyborne_shaman_female.png" },
			},
			DRUID = {
				[2] = { badge = DIR .. "Badges\\skyborne_druid_male.png", bust = DIR .. "Busts\\skyborne_druid_male.png" },
				[3] = { badge = DIR .. "Badges\\skyborne_druid_female.png", bust = DIR .. "Busts\\skyborne_druid_female.png" },
			},
			ROGUE = {
				[2] = { badge = DIR .. "Badges\\skyborne_rogue_male.png", bust = DIR .. "Busts\\skyborne_rogue_male.png" },
				[3] = { badge = DIR .. "Badges\\skyborne_rogue_female.png", bust = DIR .. "Busts\\skyborne_rogue_female.png" },
			},
			MAGE = {
				[2] = { badge = DIR .. "Badges\\skyborne_mage_male.png", bust = DIR .. "Busts\\skyborne_mage_male.png" },
				[3] = { badge = DIR .. "Badges\\skyborne_mage_female.png", bust = DIR .. "Busts\\skyborne_mage_female.png" },
			},
			HUNTER = {
				[2] = { badge = DIR .. "Badges\\skyborne_hunter_male.png", bust = DIR .. "Busts\\skyborne_hunter_male.png" },
				[3] = { badge = DIR .. "Badges\\skyborne_hunter_female.png", bust = DIR .. "Busts\\skyborne_hunter_female.png" },
			},
		},
	},
	crests = {
		Human = {
			WARRIOR = { crest = DIR .. "Crests\\human_warrior.png", glow = DIR .. "Crests\\human_warrior_glow.png", metal = DIR .. "Crests\\human_warrior_metal.png" },
			PALADIN = { crest = DIR .. "Crests\\human_paladin.png", glow = DIR .. "Crests\\human_paladin_glow.png", metal = DIR .. "Crests\\human_paladin_metal.png" },
			PRIEST = { crest = DIR .. "Crests\\human_priest.png", glow = DIR .. "Crests\\human_priest_glow.png", metal = DIR .. "Crests\\human_priest_metal.png" },
			ROGUE = { crest = DIR .. "Crests\\human_rogue.png", glow = DIR .. "Crests\\human_rogue_glow.png", metal = DIR .. "Crests\\human_rogue_metal.png" },
			MAGE = { crest = DIR .. "Crests\\human_mage.png", glow = DIR .. "Crests\\human_mage_glow.png", metal = DIR .. "Crests\\human_mage_metal.png" },
			WARLOCK = { crest = DIR .. "Crests\\human_warlock.png", glow = DIR .. "Crests\\human_warlock_glow.png", metal = DIR .. "Crests\\human_warlock_metal.png" },
			HUNTER = { crest = DIR .. "Crests\\human_hunter.png", glow = DIR .. "Crests\\human_hunter_glow.png", metal = DIR .. "Crests\\human_hunter_metal.png" },
		},
		Dwarf = {
			WARRIOR = { crest = DIR .. "Crests\\dwarf_warrior.png", glow = DIR .. "Crests\\dwarf_warrior_glow.png", metal = DIR .. "Crests\\dwarf_warrior_metal.png" },
			PALADIN = { crest = DIR .. "Crests\\dwarf_paladin.png", glow = DIR .. "Crests\\dwarf_paladin_glow.png", metal = DIR .. "Crests\\dwarf_paladin_metal.png" },
			PRIEST = { crest = DIR .. "Crests\\dwarf_priest.png", glow = DIR .. "Crests\\dwarf_priest_glow.png", metal = DIR .. "Crests\\dwarf_priest_metal.png" },
			SHAMAN = { crest = DIR .. "Crests\\dwarf_shaman.png", glow = DIR .. "Crests\\dwarf_shaman_glow.png", metal = DIR .. "Crests\\dwarf_shaman_metal.png" },
			ROGUE = { crest = DIR .. "Crests\\dwarf_rogue.png", glow = DIR .. "Crests\\dwarf_rogue_glow.png", metal = DIR .. "Crests\\dwarf_rogue_metal.png" },
			HUNTER = { crest = DIR .. "Crests\\dwarf_hunter.png", glow = DIR .. "Crests\\dwarf_hunter_glow.png", metal = DIR .. "Crests\\dwarf_hunter_metal.png" },
		},
		NightElf = {
			WARRIOR = { crest = DIR .. "Crests\\nightelf_warrior.png", glow = DIR .. "Crests\\nightelf_warrior_glow.png", metal = DIR .. "Crests\\nightelf_warrior_metal.png" },
			PRIEST = { crest = DIR .. "Crests\\nightelf_priest.png", glow = DIR .. "Crests\\nightelf_priest_glow.png", metal = DIR .. "Crests\\nightelf_priest_metal.png" },
			DRUID = { crest = DIR .. "Crests\\nightelf_druid.png", glow = DIR .. "Crests\\nightelf_druid_glow.png", metal = DIR .. "Crests\\nightelf_druid_metal.png" },
			ROGUE = { crest = DIR .. "Crests\\nightelf_rogue.png", glow = DIR .. "Crests\\nightelf_rogue_glow.png", metal = DIR .. "Crests\\nightelf_rogue_metal.png" },
			HUNTER = { crest = DIR .. "Crests\\nightelf_hunter.png", glow = DIR .. "Crests\\nightelf_hunter_glow.png", metal = DIR .. "Crests\\nightelf_hunter_metal.png" },
		},
		Gnome = {
			WARRIOR = { crest = DIR .. "Crests\\gnome_warrior.png", glow = DIR .. "Crests\\gnome_warrior_glow.png", metal = DIR .. "Crests\\gnome_warrior_metal.png" },
			PRIEST = { crest = DIR .. "Crests\\gnome_priest.png", glow = DIR .. "Crests\\gnome_priest_glow.png", metal = DIR .. "Crests\\gnome_priest_metal.png" },
			ROGUE = { crest = DIR .. "Crests\\gnome_rogue.png", glow = DIR .. "Crests\\gnome_rogue_glow.png", metal = DIR .. "Crests\\gnome_rogue_metal.png" },
			MAGE = { crest = DIR .. "Crests\\gnome_mage.png", glow = DIR .. "Crests\\gnome_mage_glow.png", metal = DIR .. "Crests\\gnome_mage_metal.png" },
			WARLOCK = { crest = DIR .. "Crests\\gnome_warlock.png", glow = DIR .. "Crests\\gnome_warlock_glow.png", metal = DIR .. "Crests\\gnome_warlock_metal.png" },
		},
		Orc = {
			WARRIOR = { crest = DIR .. "Crests\\orc_warrior.png", glow = DIR .. "Crests\\orc_warrior_glow.png", metal = DIR .. "Crests\\orc_warrior_metal.png" },
			SHAMAN = { crest = DIR .. "Crests\\orc_shaman.png", glow = DIR .. "Crests\\orc_shaman_glow.png", metal = DIR .. "Crests\\orc_shaman_metal.png" },
			ROGUE = { crest = DIR .. "Crests\\orc_rogue.png", glow = DIR .. "Crests\\orc_rogue_glow.png", metal = DIR .. "Crests\\orc_rogue_metal.png" },
			MAGE = { crest = DIR .. "Crests\\orc_mage.png", glow = DIR .. "Crests\\orc_mage_glow.png", metal = DIR .. "Crests\\orc_mage_metal.png" },
			WARLOCK = { crest = DIR .. "Crests\\orc_warlock.png", glow = DIR .. "Crests\\orc_warlock_glow.png", metal = DIR .. "Crests\\orc_warlock_metal.png" },
			HUNTER = { crest = DIR .. "Crests\\orc_hunter.png", glow = DIR .. "Crests\\orc_hunter_glow.png", metal = DIR .. "Crests\\orc_hunter_metal.png" },
		},
		Scourge = {
			WARRIOR = { crest = DIR .. "Crests\\scourge_warrior.png", glow = DIR .. "Crests\\scourge_warrior_glow.png", metal = DIR .. "Crests\\scourge_warrior_metal.png" },
			PALADIN = { crest = DIR .. "Crests\\scourge_paladin.png", glow = DIR .. "Crests\\scourge_paladin_glow.png", metal = DIR .. "Crests\\scourge_paladin_metal.png" },
			PRIEST = { crest = DIR .. "Crests\\scourge_priest.png", glow = DIR .. "Crests\\scourge_priest_glow.png", metal = DIR .. "Crests\\scourge_priest_metal.png" },
			ROGUE = { crest = DIR .. "Crests\\scourge_rogue.png", glow = DIR .. "Crests\\scourge_rogue_glow.png", metal = DIR .. "Crests\\scourge_rogue_metal.png" },
			MAGE = { crest = DIR .. "Crests\\scourge_mage.png", glow = DIR .. "Crests\\scourge_mage_glow.png", metal = DIR .. "Crests\\scourge_mage_metal.png" },
			WARLOCK = { crest = DIR .. "Crests\\scourge_warlock.png", glow = DIR .. "Crests\\scourge_warlock_glow.png", metal = DIR .. "Crests\\scourge_warlock_metal.png" },
		},
		Tauren = {
			WARRIOR = { crest = DIR .. "Crests\\tauren_warrior.png", glow = DIR .. "Crests\\tauren_warrior_glow.png", metal = DIR .. "Crests\\tauren_warrior_metal.png" },
			SHAMAN = { crest = DIR .. "Crests\\tauren_shaman.png", glow = DIR .. "Crests\\tauren_shaman_glow.png", metal = DIR .. "Crests\\tauren_shaman_metal.png" },
			DRUID = { crest = DIR .. "Crests\\tauren_druid.png", glow = DIR .. "Crests\\tauren_druid_glow.png", metal = DIR .. "Crests\\tauren_druid_metal.png" },
			HUNTER = { crest = DIR .. "Crests\\tauren_hunter.png", glow = DIR .. "Crests\\tauren_hunter_glow.png", metal = DIR .. "Crests\\tauren_hunter_metal.png" },
		},
		Troll = {
			WARRIOR = { crest = DIR .. "Crests\\troll_warrior.png", glow = DIR .. "Crests\\troll_warrior_glow.png", metal = DIR .. "Crests\\troll_warrior_metal.png" },
			PRIEST = { crest = DIR .. "Crests\\troll_priest.png", glow = DIR .. "Crests\\troll_priest_glow.png", metal = DIR .. "Crests\\troll_priest_metal.png" },
			SHAMAN = { crest = DIR .. "Crests\\troll_shaman.png", glow = DIR .. "Crests\\troll_shaman_glow.png", metal = DIR .. "Crests\\troll_shaman_metal.png" },
			ROGUE = { crest = DIR .. "Crests\\troll_rogue.png", glow = DIR .. "Crests\\troll_rogue_glow.png", metal = DIR .. "Crests\\troll_rogue_metal.png" },
			MAGE = { crest = DIR .. "Crests\\troll_mage.png", glow = DIR .. "Crests\\troll_mage_glow.png", metal = DIR .. "Crests\\troll_mage_metal.png" },
			WARLOCK = { crest = DIR .. "Crests\\troll_warlock.png", glow = DIR .. "Crests\\troll_warlock_glow.png", metal = DIR .. "Crests\\troll_warlock_metal.png" },
			HUNTER = { crest = DIR .. "Crests\\troll_hunter.png", glow = DIR .. "Crests\\troll_hunter_glow.png", metal = DIR .. "Crests\\troll_hunter_metal.png" },
		},
		Skyborne = {
			WARRIOR = { crest = DIR .. "Crests\\skyborne_warrior.png", glow = DIR .. "Crests\\skyborne_warrior_glow.png", metal = DIR .. "Crests\\skyborne_warrior_metal.png" },
			SHAMAN = { crest = DIR .. "Crests\\skyborne_shaman.png", glow = DIR .. "Crests\\skyborne_shaman_glow.png", metal = DIR .. "Crests\\skyborne_shaman_metal.png" },
			DRUID = { crest = DIR .. "Crests\\skyborne_druid.png", glow = DIR .. "Crests\\skyborne_druid_glow.png", metal = DIR .. "Crests\\skyborne_druid_metal.png" },
			ROGUE = { crest = DIR .. "Crests\\skyborne_rogue.png", glow = DIR .. "Crests\\skyborne_rogue_glow.png", metal = DIR .. "Crests\\skyborne_rogue_metal.png" },
			MAGE = { crest = DIR .. "Crests\\skyborne_mage.png", glow = DIR .. "Crests\\skyborne_mage_glow.png", metal = DIR .. "Crests\\skyborne_mage_metal.png" },
			HUNTER = { crest = DIR .. "Crests\\skyborne_hunter.png", glow = DIR .. "Crests\\skyborne_hunter_glow.png", metal = DIR .. "Crests\\skyborne_hunter_metal.png" },
		},
	},
}
