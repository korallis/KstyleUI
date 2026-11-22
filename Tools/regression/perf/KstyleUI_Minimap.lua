-- KstyleUI_Minimap.lua: the minimap's per-event and layout paths at Full, with their time budgets in microseconds per call, for test-perf-hud.lua.
local Perf = ...
local M = dofile("Tools/regression/minimap_env.lua")

local function Map()
	local env, _, ns = M.New({ enabled = true })
	M.Settle(env)
	local face = ns.Map.face
	function face.zone.GetStringWidth(self)
		return #(self:GetText() or "") * 7
	end
	face:SetZone(face.zoneText, face.pvpType)
	assert(face.ring:IsShown(), "the minimap draws its Medallions ring")
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
			local env = Map()
			local zone = Perf.Event(env, "ZONE_CHANGED_NEW_AREA")
			return env, function()
				env._zone.text = env._zone.text == "Hall of Thanes" and "Riverglades" or "Hall of Thanes"
				zone()
			end
		end,
	},
	{
		name = "Minimap face layout at Full, the card and its brackets placed again",
		budget = 1000,
		calls = 200,
		setup = function()
			local env, face = Map()
			return env, function()
				face:Layout()
				assert(face.ring:IsShown())
			end
		end,
	},
}
