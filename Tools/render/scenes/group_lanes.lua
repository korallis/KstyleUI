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
-- RENDER_PARITY_R4=1 switches on round 4's: role icons on the bar with an offset, glowing missing buffs, a taller name
-- line, heal icons nudged, class first and centred raid groups. RENDER_GROUP_LANE=1 gives the first member three of your heals and the three default indicators.
-- RENDER_PARITY_R5=1 switches on round 5's: party class order of its own, leader, name and group number offsets, the health
-- text left under icons, a heal absorb backing of its own, three heals with their own zoom, an indicator offset, and pet, tank and
-- friendly boss frames. RENDER_EXTRAS=1 switches on only pet, tank and friendly boss frames, at their defaults. RENDER_PLACES=default
-- leaves every group frame holder at its default place instead of the mock-ups'.
-- RENDER_PARITY_R6=1 switches on round 6's: the shield edge on the first member's shield, role icons under the highlights,
-- indicator 1 as a bar on the health bar's foot, filling the other way and over the debuff icons, and indicator 2 as a square (both
-- shown on the first member), party frames that take the raid's text, debuffs, heal icons, status icon size and power bar, an own
-- raid size from 16 players and tank frames that leave you out (you are the first member).
-- RENDER_PARITY_R7=1 switches on round 7's: your frame last in the party, party pets beside their owners (yours and the second
-- member's), the dispel highlight under the bar's fills on the second member's heal absorb (with RENDER_GROUP_DISPEL=1), and in a
-- raid tank frames 16 taller whose icons grow with them.
-- RENDER_PARITY_R8=1 switches on round 8's: names under the bar (Medallions raid tiles and party rows) and party heal icons
-- right of the frames past the debuffs, with the first member's three heals shown; =left puts the heals left of the frames, and
-- =above gives raid frames the name above the bar first, so the row moves under the bar too.
-- RENDER_RAID_POWER=1 switches the raid power bar on.
-- RENDER_GROUP_DISPEL=1 shows the dispel highlight on the second member as the aura engine does for a Magic debuff: every texture
-- registered with the slot shown in the Magic colour, keeping its own alpha as the options preview does.
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
local R4 = os.getenv("RENDER_PARITY_R4") == "1"
local R5 = os.getenv("RENDER_PARITY_R5") == "1"
local EXTRAS = os.getenv("RENDER_EXTRAS") == "1"
local R6 = os.getenv("RENDER_PARITY_R6") == "1"
local R7 = os.getenv("RENDER_PARITY_R7") == "1"
local R8 = os.getenv("RENDER_PARITY_R8")
local SPELLS = { [1243] = { "Power Word: Fortitude", 135987 }, [1459] = { "Arcane Intellect", 135932 }, [467] = { "Thorns", 136104 } }
local GROUP_SPELLS = { [21562] = "Prayer of Fortitude", [23028] = "Arcane Brilliance" }
local IDENTITY = {
	Valerin = { "Dwarf", 2 }, Morvane = { "Scourge", 2 }, Thessaly = { "Human", 3 }, Brannoc = { "Orc", 2 }, Ilyra = { "NightElf", 3 }, Dunmar = { "Dwarf", 2 },
}

local function place(K, key, x, y)
	if os.getenv("RENDER_PLACES") == "default" then return end
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
			if R3A or R4 then
				env.C_SpellBook = { IsSpellKnown = function(id) return SPELLS[id] ~= nil end }
				env.C_Spell = env.C_Spell or {}
				env.C_Spell.GetSpellName = function(id) return SPELLS[id] and SPELLS[id][1] or GROUP_SPELLS[id] end
				env.C_Secrets.ShouldSpellAuraBeSecret = function() return false end
				env.C_Spell.GetSpellTexture = function(id) return SPELLS[id] and SPELLS[id][2] end
				env.C_UnitAuras = env.C_UnitAuras or {}
				env.C_UnitAuras.GetAuraDataBySpellName = function(unit, name)
					local n = tonumber(unit:match("%d+$") or 0)
					return not (n % 3 == 1 and name:find("Fortitude") or n % 2 == 1 and name:find("Arcane")) and {} or nil
				end
				env.UnitPowerPercent = function(_, _, _, curve) return curve and curve:Evaluate(0.64) or 0.64 end
				env.UnitInRaid = function(unit) return unit == "player" and env._roster.kind == "raid" and 1 or nil end
				env.GROUP_NUMBER = "Group %d"
			end
			if R7 then
				G.Secure(env)
				env._units = { pet = { name = "Wolf", class = "HUNTER", health = 70, maxHealth = 100 }, partypet2 = { name = "Treant", class = "DRUID", health = 55, maxHealth = 100 } }
			end
			if os.getenv("RENDER_PARITY_R2") == "1" then
				env.UnitAffectingCombat = function(unit) return unit == "party1" or unit == "raid1" or unit == "raid7" end
			end
			env.C_Secrets = env.C_Secrets or {}
			env.C_Secrets.ShouldUnitIdentityBeSecret = function()
				return false
			end
			if R5 or EXTRAS then
				G.Secure(env)
				env._units = env._units or {}
				env._units.pet = { name = "Grawl", class = "HUNTER", health = 76, maxHealth = 100 }
				env._units.partypet2 = { name = "Imp", class = "WARLOCK", health = 58, maxHealth = 100 }
				env._units.raidpet3 = { name = "Fang", class = "HUNTER", health = 88, maxHealth = 100 }
				env._units.raidpet9 = { name = "Imp", class = "WARLOCK", health = 58, maxHealth = 100 }
				env._units.boss1 = { name = "Valithria", class = "DRUID", health = 41, maxHealth = 100 }
				env.UnitCanAssist = function(_, unit) return unit == "boss1" end
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
	if R5 then members[1].healAbsorb = 20 end
	if R6 then members[1].absorb = 25 end
	if R7 then members[2].healAbsorb = 20 end
	G.SetRoster(env, r3c ~= "solo" and kind or nil, r3c ~= "solo" and members or {}, R6 and kind == "raid" and members[1] or PLAYER)
	if not K.Modules.IsRunning("GroupFrames") then
		assert(K.Modules.Enable("GroupFrames"))
	end
	env.RunTimers()
	if os.getenv("RENDER_HEALER_PRESET") == "1" and K.Options.Row("GroupFrames", "presets.raid") then
		K.Options.Write("GroupFrames", "presets.raid", "Healer")
	end
	if os.getenv("RENDER_RAID_POWER") == "1" then K.Options.Write("GroupFrames", "raid.power", true) end
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
	if R4 then
		for key, value in pairs({ ["icons.rolePlace"] = "LEFT", ["icons.roleX"] = 2, ["reminders.place"] = "TOPRIGHT", ["reminders.glow"] = true,
			["names.height"] = 18, ["party.buffX"] = -4, ["raid.buffY"] = 2, ["sort.classFirst"] = true, ["raid.center"] = true }) do
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
	if R5 then
		for key, value in pairs({ ["sort.classFirst"] = true, ["sort.classFirstIn"] = "PARTY", ["sort.partyOwn"] = true, ["sort.partyClass1"] = "PRIEST",
			["icons.leaderX"] = 3, ["names.x"] = 2, ["numbers.show"] = true, ["numbers.y"] = 2, ["text.above"] = true, ["text.aboveHealth"] = false,
			["prediction.healAbsorbStyle"] = "STRIPES", ["prediction.backingOwn"] = true, ["prediction.healAbsorbBacking"] = 0.3,
			["auras.zoomEach"] = true, ["buffs.zoom"] = 0.15, ["indicator1.x"] = -1, ["pets.enabled"] = true, ["tanks.enabled"] = true,
			["tanks.growth"] = "RIGHT", ["boss.display"] = "ALWAYS", ["boss.dungeons"] = true }) do
			K.Options.Write("GroupFrames", key, value)
		end
		env.RunTimers()
		env.RunStateDrivers()
		place(K, "groupframes.pets", AT[kind][1], kind == "party" and AT.party[2] + 290 or 40)
		place(K, "groupframes.tanks", AT[kind][1] + 520, 40)
		place(K, "groupframes.boss", AT[kind][1] + 1000, 40)
	end
	if R7 then
		for key, value in pairs({ ["party.selfPosition"] = "LAST", ["pets.enabled"] = true, ["pets.beside"] = true, ["auras.dispelUnder"] = true,
			["tanks.enabled"] = true, ["tanks.height"] = 16, ["tanks.icons"] = true }) do
			K.Options.Write("GroupFrames", key, value)
		end
		env.RunTimers()
		env.RunStateDrivers()
		place(K, "groupframes.tanks", AT[kind][1] + 760, 40)
	end
	if R8 then
		for key, value in pairs({ ["names.bottom"] = true, ["raid.textLayout"] = R8 == "above" and "ABOVE" or nil, ["party.buffAnchor"] = R8 == "left" and "LEFT" or "RIGHT" }) do
			K.Options.Write("GroupFrames", key, value)
		end
		env.RunTimers()
	end
	if R6 then
		for key, value in pairs({ ["prediction.edge"] = true, ["icons.roleBehind"] = true, ["indicator1.style"] = "BAR", ["indicator1.position"] = "BOTTOM",
			["indicator1.color"] = { r = 0.35, g = 0.85, b = 0.55 }, ["indicator1.reverse"] = true, ["indicator1.over"] = true, ["indicator2.style"] = "SQUARE", ["indicator2.color"] = { r = 0.95, g = 0.7, b = 0.2 },
			["follow.text"] = true, ["follow.auras"] = true, ["follow.heals"] = true, ["follow.icons"] = true, ["follow.power"] = true, ["auto.customLeast"] = 16, ["auto.customWidth"] = 130,
			["auto.customHeight"] = 40, ["tanks.enabled"] = true, ["tanks.excludeSelf"] = true }) do
			K.Options.Write("GroupFrames", key, value)
		end
		env.RunTimers()
		env.RunStateDrivers()
		place(K, "groupframes.tanks", AT[kind][1] + 760, 40)
	end
	if EXTRAS then
		for key, value in pairs({ ["pets.enabled"] = true, ["tanks.enabled"] = true, ["boss.display"] = "ALWAYS", ["boss.dungeons"] = true }) do
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
	if os.getenv("RENDER_GROUP_DISPEL") == "1" then
		ns.Unit.ForEach(function(f)
			local slot = f.highlights and f.highlights._slots.dispel
			if slot and (f.unit == "party2" or f.unit == "raid2") then
				for _, entry in ipairs(slot.frame._aura.dispel) do
					entry.texture:SetVertexColor(0.2, 0.6, 1, entry.texture:GetAlpha())
					entry.texture:Show()
				end
				slot.frame:Show()
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
	local lane = os.getenv("RENDER_GROUP_LANE") == "1"
	if lane or R5 or R8 then
		local A = dofile("Tools/regression/auras_env.lua")
		ns.Unit.ForEach(function(f)
			if (f.unit == "party1" or f.unit == "raid1") and f.buffs then
				local heals = f.buffs._groups.buffs
				A.Assign(env, f.buffs, "buffs", 3)
				for i, button in ipairs(heals.active) do button._aura.icon:SetTexture(({ 136081, 135953, 136076 })[i]) end
				Hud.PlaceAuras(f.buffs, heals, heals.active, 3)
				for i = 1, lane and 3 or 0 do
					local slot = f.indicators and f.indicators._slots["indicator" .. i]
					if slot and slot.enabled then
						slot.frame:Show()
						if slot.frame._aura then slot.frame._aura.icon:SetTexture(({ 135936, 136071, 135940 })[i]) end
					end
				end
			end
		end)
	end
	if R6 then
		ns.Unit.ForEach(function(f)
			for i = 1, (f.unit == "party1" or f.unit == "raid1") and 2 or 0 do
				local slot = f.indicators and f.indicators._slots["indicator" .. i]
				if slot and slot.enabled then
					slot.frame:Show()
					slot.frame._aura.icon:SetTexture(({ 135936, 136071 })[i])
					local bar = ns.Auras.Parts(slot.frame).bar
					if bar then
						bar:SetMinMaxValues(0, 1)
						bar:SetValue(0.6)
					end
				end
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
