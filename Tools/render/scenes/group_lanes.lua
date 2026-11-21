-- group_lanes.lua: the party and raid frames as the KSTY-44 and KSTY-47 mock-ups draw them, on the owner's screen:
-- RENDER_GROUP is party (the player and four members, bare on the world) or 10, 20, 25 or 40 (a raid of that size in
-- groups of five, seated in its card); RENDER_HUD_STYLE picks the HUD style and RENDER_SCREEN the screen. The
-- members, health and roles are the mock-ups' own, and the frames sit where the mock-ups put them. RENDER_PARITY_R1=1
-- switches on the EllesmereUI parity round 1 options that show without extra state; RENDER_PARITY_R2=1 switches on round 2's,
-- with the first member in combat, shielded past the missing health and the fourth carrying a heal absorb.
-- RENDER_PARITY_R3C=1 switches on round 3c's striped shields, shield glow, lost maximum health, threat edge and merged
-- raid groups (party frames with portraits, so the threat edge has a tile), with the first member shielded and on aggro and the second missing a fifth of their maximum health;
-- RENDER_PARITY_R3C=missing also fills the bars with missing health; =layout (RENDER_GROUP=10) gives the larger frames a custom size
-- and offset with icons that scale and two hover lines on the hovered first frame; =solo (RENDER_GROUP=party) shows you alone, centred;
-- =small (RENDER_GROUP=10) keeps six players, group 1 shown as party frames.
-- RENDER_PARITY_R3B=1 switches on round 3b's party targets (an enemy, a player and an enemy), text above icons, a party debuff
-- offset, the thick icon text outline and indicator 1 kept to raid frames.
-- RENDER_PARITY_R3A=1 switches on round 3a's: missing buffs, Dead on the bar, the dispel type letter, centred names
-- with a divider, group numbers, healer mana and your group label.
local Common = dofile("Tools/render/scenes/_common.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
local Scene = Common.Scene
Scene.ATLAS_DIR = os.getenv("RENDER_ATLAS_CACHE") or Scene.ATLAS_DIR

local NAMES = {
	"Thessaly", "Brannoc", "Ilyra", "Dunmar", "Kerrith", "Vosk", "Aelwyn", "Morrow", "Tamsin", "Hadric",
	"Seren", "Oskar", "Lyse", "Garrow", "Nimue", "Ffion", "Rook", "Elsbet", "Corvin", "Maelis",
	"Druce", "Yvaine", "Torvald", "Ashe", "Brisa", "Cael", "Dorne", "Emrys", "Faye", "Gideon",
	"Halle", "Isolde", "Jory", "Kael", "Lark", "Mira", "Nell", "Orrin", "Pell", "Quill",
}
local HEALTH = {
	92, 64, 100, 38, 77, 100, 55, 23, 88, 100, 71, 100, 96, 45, 100, 82, 67, 100, 59, 100,
	92, 100, 31, 78, 100, 85, 62, 100, 100, 48, 94, 100, 73, 100, 57, 100, 88, 100, 66, 100,
}
local POWER = { 80, 100, 46, 30, 60 }
local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local COLOURS = {
	WARRIOR = { 0.78, 0.61, 0.43 }, PALADIN = { 0.96, 0.55, 0.73 }, HUNTER = { 0.67, 0.83, 0.45 },
	ROGUE = { 1, 0.96, 0.41 }, PRIEST = { 1, 1, 1 }, SHAMAN = { 0, 0.44, 0.87 }, MAGE = { 0.25, 0.78, 0.92 },
	WARLOCK = { 0.53, 0.53, 0.93 }, DRUID = { 1, 0.49, 0.04 },
}
local ROLES = { "TANK", "HEALER", "DAMAGER", "DAMAGER", "DAMAGER" }
local PARTY = {
	{ "Thessaly", "PALADIN", 92, "TANK", 80 }, { "Brannoc", "HUNTER", 64, "DAMAGER", 100 },
	{ "Ilyra", "PRIEST", 100, "HEALER", 46 }, { "Dunmar", "WARRIOR", 38, "DAMAGER", 30 },
}
local PLAYER = { name = "Valerin", class = "SHAMAN", health = 82, maxHealth = 100, power = 70, maxPower = 100, role = "HEALER" }
if os.getenv("RENDER_PLAYER") == "warlock" then
	PLAYER = { name = "Morvane", class = "WARLOCK", health = 82, maxHealth = 100, power = 70, maxPower = 100, role = "DAMAGER" }
end
local AT = { party = { 24, 392 }, raid = { 14, 330 } }
local R3A = os.getenv("RENDER_PARITY_R3A") == "1"
local SPELLS = { [1243] = { "Power Word: Fortitude", 135987 }, [1459] = { "Arcane Intellect", 135932 }, [467] = { "Thorns", 136104 } }
local IDENTITY = {
	Valerin = { "Dwarf", 2 }, Morvane = { "Scourge", 2 }, Thessaly = { "Human", 3 }, Brannoc = { "Orc", 2 }, Ilyra = { "NightElf", 3 }, Dunmar = { "Dwarf", 2 },
}

local function place(K, key, x, y)
	assert(K.Layout.Set(key, "anchor", "TOPLEFT"))
	assert(K.Layout.Set(key, "x", x))
	assert(K.Layout.Set(key, "y", -y))
end

return Common.Run(function()
	local G = dofile("Tools/regression/group_env.lua")
	local group = os.getenv("RENDER_GROUP") or "20"
	local env, K, ns = G.New(Common.ScreenOpts({
		saved = Hud.Saved({}, "GroupFrames"),
		setup = function(env)
			local unitClass = env.UnitClass
			Common.ForceScreen(env)
			if os.getenv("RENDER_GROUP_STATUS") == "1" then
				env.UnitHasIncomingResurrection = function(unit) return env.Secret(unit == "party1" or unit == "raid1") end
				env.UnitIsAFK = function(unit) return env.Secret(unit == "party3" or unit == "raid3") end
				env.C_IncomingSummon = { HasIncomingSummon = function(unit) return env.Secret(unit == "party2" or unit == "raid2") end }
			end
			env.RAID_CLASS_COLORS = {}
			for class, c in pairs(COLOURS) do
				env.RAID_CLASS_COLORS[class] = { r = c[1], g = c[2], b = c[3] }
			end
			env.UnitClass = unitClass
			local function identity(unit)
				return IDENTITY[env.UnitName(unit) or ""]
			end
			env.UnitRace = function(unit)
				local id = identity(unit)
				if id then
					return id[1], id[1], 1
				end
			end
			env.UnitSex = function(unit)
				local id = identity(unit)
				return id and id[2] or 2
			end
			if R3A then
				env.C_SpellBook = { IsSpellKnown = function(id) return SPELLS[id] ~= nil end }
				env.C_Spell = env.C_Spell or {}
				env.C_Spell.GetSpellName = function(id) return SPELLS[id] and SPELLS[id][1] end
				env.C_Spell.GetSpellTexture = function(id) return SPELLS[id] and SPELLS[id][2] end
				env.C_UnitAuras = env.C_UnitAuras or {}
				env.C_UnitAuras.GetAuraDataBySpellName = function(unit, name)
					local n = tonumber(unit:match("%d+$") or 0)
					return (n % 3 ~= 1 or name ~= "Power Word: Fortitude") and (n % 2 == 0 or name ~= "Arcane Intellect") and {} or nil
				end
				env.UnitPowerPercent = function(_, _, _, curve) return curve and curve:Evaluate(0.64) or 0.64 end
				env.UnitInRaid = function(unit) return unit == "player" and env._roster.kind == "raid" and 1 or nil end
				env.GROUP_NUMBER = "Group %d"
			end
			if os.getenv("RENDER_PARITY_R2") == "1" then
				env.UnitAffectingCombat = function(unit) return unit == "party1" or unit == "raid1" or unit == "raid7" end
			end
			env.C_Secrets = env.C_Secrets or {}
			env.C_Secrets.ShouldUnitIdentityBeSecret = function()
				return false
			end
			if os.getenv("RENDER_PARITY_R3B") == "1" then
				G.Secure(env)
				env._units = env._units or {}
				env._units.party1target = { name = "Gorvak", class = "WARRIOR", reaction = 2, health = 64, maxHealth = 100 }
				env._units.party2target = { name = "Thessaly", class = "PALADIN", player = true, health = 92, maxHealth = 100 }
				env._units.party3target = { name = "Gorvak", class = "WARRIOR", reaction = 2, health = 64, maxHealth = 100 }
				env.UnitIsPlayer = function(unit)
					local m = env._member(unit)
					return m ~= nil and m.player == true
				end
			end
		end,
	}))
	local kind, members = "party", {}
	if group == "party" then
		for i, m in ipairs(PARTY) do
			members[i] = { name = m[1], class = m[2], health = m[3], maxHealth = 100, power = m[5], maxPower = 100, role = m[4] }
		end
		if R3A then members[4].dead = true end
	else
		kind = "raid"
		local n = tonumber(group)
		assert(n == 10 or n == 20 or n == 25 or n == 40, "RENDER_GROUP must be party, 10, 20, 25 or 40")
		members = G.Members(n, function(i, m)
			m.name = NAMES[i]
			m.class = CLASSES[(i - 1) % #CLASSES + 1]
			m.health, m.maxHealth = HEALTH[i], 100
			m.power, m.maxPower = POWER[(i - 1) % 5 + 1], 100
			m.role = ROLES[(i - 1) % 5 + 1]
		end)
	end
	if os.getenv("RENDER_PARITY_R2") == "1" then
		members[1].absorb, members[4].healAbsorb, members[3].marker = 30, 15, 2
	end
	local r3c = os.getenv("RENDER_PARITY_R3C")
	if r3c then
		members[1].absorb, members[1].threat, members[2].maxLoss, members[4].healAbsorb = 70, 3, 0.2, 15
		if r3c == "small" then for i = #members, 7, -1 do members[i] = nil end end
	end
	G.SetRoster(env, r3c ~= "solo" and kind or nil, r3c ~= "solo" and members or {}, PLAYER)
	if not K.Modules.IsRunning("GroupFrames") then
		assert(K.Modules.Enable("GroupFrames"))
	end
	env.RunTimers()
	if os.getenv("RENDER_HEALER_PRESET") == "1" and K.Options.Row("GroupFrames", "presets.raid") then
		K.Options.Write("GroupFrames", "presets.raid", "Healer")
	end
	if os.getenv("RENDER_TEXT_PRESET") == "Readable" and K.Profiles then K.Profiles.Readable("Readable") end
	if os.getenv("RENDER_PARITY_R1") == "1" then
		for key, value in pairs({ ["health.colorSource"] = "gradient", ["health.alpha"] = 0.85, ["icons.roleDamager"] = false,
			["power.damagers"] = false, ["groups.show2"] = false, ["auras.dispelAlpha"] = 0.3, ["auras.dispelLines"] = 1 }) do
			K.Options.Write("GroupFrames", key, value)
		end
	end
	if R3A then
		for key, value in pairs({ ["reminders.place"] = "TOPRIGHT", ["status.place"] = "CENTER", ["dispel.icon"] = "LEFT", ["names.align"] = "CENTER",
			["names.divider"] = true, ["numbers.show"] = true, ["mana.mode"] = "BOTH", ["label.enabled"] = true }) do
			K.Options.Write("GroupFrames", key, value)
		end
	end
	if os.getenv("RENDER_PARITY_R2") == "1" then
		for key, value in pairs({ ["icons.roleText"] = true, ["icons.combat"] = true, ["icons.combatClass"] = true, ["icons.markerPlace"] = "TOPRIGHT",
			["prediction.overshield"] = true, ["prediction.absorbPlace"] = "END", ["prediction.healAbsorbLine"] = true, ["prediction.shieldPlace"] = "TOP",
			["accent.targetLines"] = 1, ["power.behind"] = true }) do
			K.Options.Write("GroupFrames", key, value)
		end
	end
	if r3c then
		for key, value in pairs({ ["prediction.absorbStyle"] = "STRIPES", ["prediction.healAbsorbStyle"] = "STRIPES", ["prediction.glow"] = true,
			["prediction.maxLoss"] = "STRIPES", ["threat.edge"] = true, ["party.portrait"] = true, ["raid.merge"] = true, ["health.missing"] = r3c == "missing" }) do
			K.Options.Write("GroupFrames", key, value)
		end
		for key, value in pairs(({ solo = { ["party.showSolo"] = true, ["party.centerSolo"] = true }, small = { ["party.smallRaid"] = true },
			layout = { ["auto.smallWidth"] = 150, ["auto.smallHeight"] = 48, ["auto.smallX"] = 40, ["auto.smallY"] = -30, ["auto.icons"] = true,
				["auto.heals"] = true, ["accent.hoverLines"] = 2 } })[r3c] or {}) do
			K.Options.Write("GroupFrames", key, value)
		end
	end
	if os.getenv("RENDER_PARITY_R3B") == "1" then
		for key, value in pairs({ ["targets.enabled"] = true, ["text.above"] = true, ["party.auraX"] = 12, ["auras.textOutline"] = "THICKOUTLINE", ["indicator1.show"] = "RAID" }) do
			K.Options.Write("GroupFrames", key, value)
		end
		env.RunTimers()
		env.RunStateDrivers()
	end
	place(K, "groupframes." .. kind, AT[kind][1], AT[kind][2])
	if r3c == "small" then place(K, "groupframes.party", AT.party[1], AT.party[2]) end
	env.RunTimers()
	if r3c == "layout" then
		local button = ns.Headers.raid[1]:GetAttribute("child1")
		button:GetScript("OnEnter")(button)
	end
	Hud.Tick(env, 1)
	env.RunTimers()
	if R3A then
		ns.Unit.ForEach(function(f)
			local slot = f.highlights and f.highlights._slots.dispelType
			if slot and (f.unit == "party2" or f.unit == "raid2") then
				slot.frame:Show()
				dofile("Tools/regression/auras_env.lua").Dispel(slot.frame, "Magic")
			end
		end)
	end
	if os.getenv("RENDER_GROUP_STATUS") == "1" then
		local A = dofile("Tools/regression/auras_env.lua")
		ns.Unit.ForEach(function(f)
			if f.unit == "party1" or f.unit == "raid1" then
				A.Assign(env, f.auras, "debuffs", 1)
				local button = f.auras._groups.debuffs.frames[1]
				button._aura.icon:SetTexture(135813)
				if A.Dispel then A.Dispel(button, "Magic") end
			end
		end)
	end
	dofile("Tools/render/scenes/_audit.lua").Apply(K)
	env.RunTimers()
	Hud.Tick(env, 1)
	local scene = Scene.Build(env, { iconDirs = Common.IconDirs() })
	local err = Common.Errors(env, K)
	assert(not err, tostring(err))
	return scene
end)
