-- health.lua: the load check on a client whose AddOn list turned Meters off, that holds an older Chat and lost World map routes: its notice over the reference HUD (RENDER_HEALTH=notice, the default) or About > Status in the settings window (RENDER_HEALTH=about).
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Reference = dofile("Tools/render/scenes/_reference.lua")
local O = dofile("Tools/regression/options_env.lua")

local ON = { "UnitFrames", "ActionBars", "Cooldowns", "GroupFrames", "Auras", "Nameplates", "CombatText", "Minimap", "Chat", "Bags", "Tooltips", "DataBars", "Skins" }

local function Client(env)
	env.ADDON_DISABLED = "Disabled"
	local api = env.C_AddOns
	api.DoesAddOnExist = function(folder) return folder ~= "KstyleUI_Routes" end
	api.IsAddOnLoaded = function(folder)
		if folder == "KstyleUI_Options" then return env._addons[folder] ~= nil end
		return folder:match("^KstyleUI_") ~= nil and folder ~= "KstyleUI_Meters" and folder ~= "KstyleUI_Routes"
	end
	api.GetAddOnMetadata = function(folder) return folder == "KstyleUI_Chat" and "0.2.14" or "@project-version@" end
	api.GetAddOnInfo = function(folder)
		local reason = folder == "KstyleUI_Meters" and "DISABLED" or folder == "KstyleUI_Options" and "DEMAND_LOADED" or nil
		return folder, folder, "", false, reason, "INSECURE"
	end
	env.GetBuildInfo = function() return "1.60.1", "70862", "Nov 18 2026", 16001 end
end

local about = os.getenv("RENDER_HEALTH") == "about"

local function Register(_, K)
	for _, name in ipairs(ON) do K.Modules.Register(O.W.CoreEnv.Module(name)) end
	K.Modules.Register(O.W.CoreEnv.Module("QoL"))
	K.Store.Account().healthChecks = not about
end

return Common.Run(function()
	local env, K, ns = O.New(Common.ScreenOpts({
		saved = Gallery.Saved(ON),
		setup = function(e)
			Gallery.Setup(e)
			Client(e)
		end,
		before = Register,
		load = about,
	}))
	env.RunTimers()
	K.Store.Account().healthChecks = true
	if about then
		assert(K.Options.Open("About"))
		assert(K.Layout.Update("Options.Window", { width = 1240, height = 860, scale = 1 }))
		Gallery.Ticks(O.W, env, 30)
		env.RunTimers()
		for i, item in ipairs(ns.Window.State().items) do
			if item.label == "Status" then ns.Window.Parts().content:ScrollToIndex(i, true, "TOP") end
		end
		Gallery.Ticks(O.W, env, 40)
		assert(not Common.Errors(env, K), tostring(Common.Errors(env, K)))
		return Gallery.Build(env)
	end
	Gallery.Ticks(O.W, env, 40)
	assert(not Common.Errors(env, K), tostring(Common.Errors(env, K)))
	local notice = Gallery.Build(env)
	local hud = Reference.Build({ layout = os.getenv("RENDER_LAYOUT") or "DPS" })
	return Common.Scene.Merge({ hud, notice })
end)
