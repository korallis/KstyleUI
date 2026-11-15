-- Core.lua: the core's combat paths, with their time budgets in microseconds per call, for test-perf.lua.
local Perf = ...
local W = dofile("Tools/regression/widget_env.lua")
local FX = dofile("Tools/regression/effects_env.lua")

local function Bar()
	local env, K = W.New()
	local bar = K.Widgets.StatusBar(K.Scale.Root(), { width = 200, height = 18, spark = true, smooth = true })
	return env, bar
end

return {
	{
		name = "Glow Start and Stop",
		budget = 30,
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
	{
		name = "Effects Claim and Release a place",
		budget = 20,
		setup = function()
			local env, K = W.New()
			local E = K.Effects
			local stop = function() end
			E.Ambient("perf", stop, stop)
			return env, function()
				local token = E.Claim("perf", E.PRIORITY.ready, stop)
				E.Claim("perf", E.PRIORITY.proc, stop)
				E.Release("perf", token)
				E.Stop("perf")
			end
		end,
	},
	{
		name = "Effects Allows at the current level",
		budget = 20,
		setup = function()
			local env, K = W.New()
			local E = K.Effects
			return env, function()
				E.Allows("flare")
				E.Allows("model")
			end
		end,
	},
	{
		name = "Effects Burst into the 3D pool",
		budget = 120,
		setup = function()
			local env, K = W.New()
			K.Options.Write("HudStyle", "style", "medallions")
			env.RunTimers()
			local E = K.Effects
			local anchor = env.CreateFrame("Frame", nil, env.UIParent)
			local twin = function() end
			return env, function()
				E.Burst("perf", E.PRIORITY.levelUp, anchor, "levelUp", 150, 1.2, twin, twin)
				E.StopModels()
			end
		end,
	},
	{
		name = "Effects vignette UNIT_HEALTH",
		budget = 20,
		setup = function()
			local env, K = W.New({ setup = FX.Install })
			K.Options.Write("HudStyle", "style", "medallions")
			env.RunTimers()
			env._health = 0.2
			env.FireEvent("PLAYER_ENTERING_WORLD")
			assert(K.Effects.Vignette.frame:IsShown(), "the fixture shows the vignette")
			return env, Perf.Event(env, "UNIT_HEALTH", "player")
		end,
	},
}
