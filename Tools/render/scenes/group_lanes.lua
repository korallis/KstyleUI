-- group_lanes.lua: the party and raid frames as the KSTY-44 and KSTY-47 mock-ups draw them, on the owner's screen:
-- RENDER_GROUP is party (the player and four members, bare on the world) or 10, 20 or 40 (a raid of that size in
-- groups of five, seated in its card); RENDER_HUD_STYLE picks the HUD style and RENDER_SCREEN the screen. The
-- members, health and roles are the mock-ups' own, and the frames sit where the mock-ups put them.
local Common = dofile("Tools/render/scenes/_common.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
local Scene = Common.Scene

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
local AT = { party = { 24, 392 }, raid = { 14, 330 } }

local function place(K, key, x, y)
	assert(K.Layout.Set(key, "anchor", "TOPLEFT"))
	assert(K.Layout.Set(key, "x", x))
	assert(K.Layout.Set(key, "y", -y))
end

return Common.Run(function()
	local G = dofile("Tools/regression/group_env.lua")
	local group = os.getenv("RENDER_GROUP") or "20"
	local env, K = G.New(Common.ScreenOpts({
		saved = Hud.Saved({}, "GroupFrames"),
		setup = function(env)
			local unitClass = env.UnitClass
			Common.ForceScreen(env)
			env.RAID_CLASS_COLORS = {}
			for class, c in pairs(COLOURS) do
				env.RAID_CLASS_COLORS[class] = { r = c[1], g = c[2], b = c[3] }
			end
			env.UnitClass = unitClass
		end,
	}))
	local kind, members = "party", {}
	if group == "party" then
		for i, m in ipairs(PARTY) do
			members[i] = { name = m[1], class = m[2], health = m[3], maxHealth = 100, power = m[5], maxPower = 100, role = m[4] }
		end
	else
		kind = "raid"
		local n = tonumber(group)
		assert(n == 10 or n == 20 or n == 40, "RENDER_GROUP must be party, 10, 20 or 40")
		members = G.Members(n, function(i, m)
			m.name = NAMES[i]
			m.class = CLASSES[(i - 1) % #CLASSES + 1]
			m.health, m.maxHealth = HEALTH[i], 100
			m.power, m.maxPower = POWER[(i - 1) % 5 + 1], 100
			m.role = ROLES[(i - 1) % 5 + 1]
		end)
	end
	G.SetRoster(env, kind, members, PLAYER)
	if not K.Modules.IsRunning("GroupFrames") then
		assert(K.Modules.Enable("GroupFrames"))
	end
	env.RunTimers()
	place(K, "groupframes." .. kind, AT[kind][1], AT[kind][2])
	env.RunTimers()
	Hud.Tick(env, 1)
	env.RunTimers()
	local scene = Scene.Build(env, { iconDirs = Common.IconDirs() })
	local err = Common.Errors(env, K)
	if err then
		scene.log[#scene.log + 1] = "group_lanes error: " .. err
	end
	return scene
end)
