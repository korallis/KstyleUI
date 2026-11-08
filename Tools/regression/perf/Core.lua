-- Core.lua: the core's combat paths, with their time budgets in microseconds per call, for test-perf.lua.
local W = dofile("Tools/regression/widget_env.lua")

local function Bar()
	local env, K = W.New()
	local bar = K.Widgets.StatusBar(K.Scale.Root(), { width = 200, height = 18, spark = true, smooth = true })
	return env, bar
end

return {
	{
		name = "Glow Start and Stop",
		budget = 20,
		setup = function()
			local env, K = W.New()
			local glow = K.Widgets.Glow(K.Widgets.Panel(K.Scale.Root(), {}), { kind = "proc" })
			return env, function()
				glow:Start()
				glow:Stop()
			end
		end,
	},
	{
		name = "StatusBar SetBarColor",
		budget = 10,
		setup = function()
			local env, bar = Bar()
			return env, function()
				bar:SetBarColor(0.2, 0.5, 0.9)
			end
		end,
	},
	{
		name = "StatusBar SetBarTexture",
		budget = 10,
		setup = function()
			local env, bar = Bar()
			local flat = false
			return env, function()
				flat = not flat
				bar:SetBarTexture(flat and "Flat" or "Glass")
			end
		end,
	},
}
