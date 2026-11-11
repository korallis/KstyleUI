-- KstyleUI_Minimap.lua: the minimap's per-event and ornament paths at Full, with their time budgets in microseconds per call, for test-perf-hud.lua.
local Perf = ...
local M = dofile("Tools/regression/minimap_env.lua")

local function Map()
	local env, K, ns = M.New({ enabled = true })
	M.Settle(env)
	local face = ns.Map.face
	function face.zone.GetStringWidth(self)
		return #(self:GetText() or "") * 7
	end
	face:SetZone(face.zoneText, face.pvpType)
	assert(K.Widgets.Setting("ornaments") == "Full" and face.ornament.used >= 2 and face.plaqueOrnament.used == 1, "the minimap places its corners and its plaque at Full, not " .. face.ornament.used .. " and " .. face.plaqueOrnament.used)
	return env, face
end

return {
	{
		name = "Minimap clock tick at Full",
		budget = 50,
		setup = function()
			local env = Map()
			return env, function()
				M.RunTickers(env)
			end
		end,
	},
	{
		name = "Minimap zone change at Full, the name's width changes",
		budget = 400,
		calls = 200,
		setup = function()
			local env, face = Map()
			local zone = Perf.Event(env, "ZONE_CHANGED_NEW_AREA")
			return env, function()
				env._zone.text = env._zone.text == "Hall of Thanes" and "Riverglades" or "Hall of Thanes"
				zone()
				assert(face.ornament.used >= 2)
			end
		end,
	},
	{
		name = "Minimap face layout at Full, corners and plaque placed again",
		budget = 1000,
		calls = 200,
		setup = function()
			local env, face = Map()
			return env, function()
				face:Layout()
				assert(face.ornament.used >= 2 and face.plaqueOrnament.used == 1)
			end
		end,
	},
}
