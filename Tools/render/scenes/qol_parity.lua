-- qol_parity.lua: the full HUD with the QoL parity round 1 options on (the leaving-combat and talent alerts, the durability warning, the crosshair and the cursor ring), or with RENDER_QOL_OPTIONS=1 the QoL page and its live preview.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Reference = dofile("Tools/render/scenes/_reference.lua")
local O = dofile("Tools/regression/options_env.lua")
local Load = dofile("Tools/regression/load_files.lua")
local Q = dofile("Tools/regression/qol_env.lua")

local ON = { combatAlert = true, talentAlert = true, durabilityAlert = true, deathAlert = true, crosshair = "normal", crosshairBorder = 1, cursorRing = true }

return Common.Run(function()
	local options = os.getenv("RENDER_QOL_OPTIONS") == "1"
	local env, K, ns = Q.New(Common.ScreenOpts({
		saved = Gallery.Saved({ QoL = {} }),
		setup = function(e)
			Gallery.Setup(e)
			e.C_AddOns = e.C_AddOns or {}
			e.C_AddOns.LoadAddOn = function(name)
				if name == "KstyleUI_Options" and not e._addons.KstyleUI_Options then Load(O.Files(), e) end
				return true
			end
		end,
	}))
	if not K.Modules.IsRunning("QoL") then assert(K.Modules.Enable("QoL")) end
	for key, value in pairs(ON) do assert(K.Options.Write("QoL", key, value) ~= false, key) end
	env._unspent, env._durability[5] = true, { 21, 100 }
	env.FireEvent("TRAIT_CONFIG_UPDATED", 1)
	env.FireEvent("UPDATE_INVENTORY_DURABILITY")
	env.SetCombat(true)
	env.SetCombat(false)
	local root = K.Scale.Root()
	env._cursor = { root:GetWidth() * (options and 0.85 or 0.35) * root:GetEffectiveScale(), root:GetHeight() * 0.68 * root:GetEffectiveScale() }
	local _, ring = ns.AidFrames()
	ring:GetScript("OnUpdate")(ring, 0)
	ring:SetScript("OnUpdate", nil) -- the pointer stands still for the picture, and Settle waits for every OnUpdate to stop
	env.RunTimers()
	O.W.Settle(env)
	if options then
		assert(K.Options.Open("QoL"))
		env.RunTimers()
		assert(K.Layout.Set("Options.Window", "height", 900))
		assert(K.Layout.Set("Options.Window", "width", 1240))
		assert(K.Layout.Set("Options.Window", "anchor", "TOPLEFT"))
		assert(K.Layout.Set("Options.Window", "x", 28))
		assert(K.Layout.Set("Options.Window", "y", -28))
		env._addons.KstyleUI_Options.Window.Jump({ page = "QoL", module = "QoL", key = os.getenv("RENDER_QOL_KEY") or "combatAlert" })
		env.RunTimers()
		O.W.Settle(env)
	end
	local scene = Gallery.Build(env)
	local errors = Common.Errors(env, K)
	assert(not errors, errors)
	if not options then
		scene = Common.Scene.Merge({ Reference.Build({ layout = os.getenv("RENDER_LAYOUT") or "DPS" }), scene })
	end
	scene.log[#scene.log + 1] = "qol parity: round 1 options " .. (options and "page" or "on over the HUD")
	return scene
end)
