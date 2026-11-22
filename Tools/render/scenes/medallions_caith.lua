-- medallions_caith.lua: five player-owned target debuffs and player buffs on the real Medallions HUD.
local Common = dofile("Tools/render/scenes/_common.lua")
local Lumen = dofile("Tools/render/scenes/_lumen.lua")
local Reference = dofile("Tools/render/scenes/_reference.lua")

return Common.Run(function()
	local state = {}
	for key, value in pairs(Reference.STATE) do state[key] = value end
	state.targetAuras = { { 135813, "3s" }, { 136026, "6s" }, { 136207, "9s" }, { 136197, "12s" }, { 136118, "15s" } }
	state.player = {}
	for key, value in pairs(Reference.STATE.player) do state.player[key] = value end
	state.player.auras = {
		{ id = 101, icon = 135932, left = 120, harmful = false, mine = true },
		{ id = 102, icon = 136078, left = 540, harmful = false, mine = true },
		{ id = 103, icon = 135987, left = 1680, harmful = false, mine = true },
	}
	return Lumen.Build("questing", {
		class = "SHAMAN", layout = os.getenv("RENDER_LAYOUT") or "DPS", applyPreset = true, state = state,
		settings = { UnitFrames = { auraLayout = os.getenv("RENDER_AURA_LAYOUT") or "rows", player = { auras = true, auraFilter = "buffs", medallionsAuras = os.getenv("RENDER_PLAYER_AURAS") == "on" or nil } } },
		modules = { "nameplates", "chat", "minimap", "auras", "databars", "tracker", "meters", "unitframes", "actionbars", "cooldowns", "lootfeed" },
	})
end)
