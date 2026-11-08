-- Core.lua: the core's combat paths, with their time budgets in microseconds per call, for test-perf.lua.
local W = dofile("Tools/regression/widget_env.lua")

local function Bar()
	local env, K = W.New()
	local bar = K.Widgets.StatusBar(K.Scale.Root(), { width = 200, height = 18, spark = true, smooth = true })
	return env, bar
end

-- A watched icon texture with set B on, as every aura tile is: the engine redraws it on each aura update.
local ICON, OTHER_ICON = 132333, 136224
local PATH = "Interface\\AddOns\\KstyleUI_IconsColour\\Icons\\"
local function Watched()
	local env, K = W.New({
		setup = function(env)
			env.C_AddOns = {
				LoadAddOn = function()
					env.KstyleUIIconData = { set = "B", icons = { [ICON] = PATH .. ICON .. ".png", [OTHER_ICON] = PATH .. OTHER_ICON .. ".png" } }
					return true
				end,
				IsAddOnLoaded = function()
					return true
				end,
			}
		end,
	})
	K.Options.Write("Icons", "enabled", true)
	local texture = K.Scale.Root():CreateTexture(nil, "ARTWORK")
	K.Icons.Watch(texture)
	return env, texture
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
		name = "Icons follow a secret aura icon",
		budget = 5,
		setup = function()
			local env, texture = Watched()
			local secret = env.Secret(ICON)
			return env, function()
				texture:SetTexture(secret)
			end
		end,
	},
	{
		name = "Icons follow a known aura icon",
		budget = 20,
		setup = function()
			local env, texture = Watched()
			local flip = false
			return env, function()
				flip = not flip
				texture:SetTexture(flip and ICON or OTHER_ICON)
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
