-- actionbars_shortcuts.lua: a contested key and a distant action beside a healing potion with two bindings.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local AB = dofile("Tools/regression/actionbars_env.lua")
return Common.Run(function()
	local env, K, ns = AB.New(Common.ScreenOpts({ saved = Gallery.Saved({ ActionBars = { slab = false, consumables = { attached = false, count = false, hotkey = true, size = 40 } } }), setup = function(e)
		Gallery.Setup(e)
		e._game.slots[1] = { texture = 132337, type = "spell", id = 100, count = "3" }
		e._game.bindings.ACTIONBUTTON1 = { "Q" }
		e._game.bindings.JUMP = { "SPACE" }
		e.BINDING_NAME_JUMP = "Jump"
		e.C_Container = { GetContainerNumSlots = function(bag) return bag == 0 and 1 or 0 end,
			GetContainerItemInfo = function() return { itemID = 118, stackCount = 3, iconFileID = 134829 } end }
		e.IsBindingForGamePad = function(key) return key == "PAD2" end
		e.C_GamePad = { GetActiveDeviceID = function() return 1 end, GetDeviceMappedState = function() return { labelStyle = "Letters" } end }
		e.C_Texture = e.C_Texture or {}
		e.C_Texture.GetAtlasInfo = Common.Scene.AtlasInfo
	end }))
	AB.Enable(env, K)
	local b = ns.Consumables.buttons[1]
	env._game.bindings[b.binding] = { "F9", "PAD2" }
	env.FireEvent("UPDATE_BINDINGS")
	env.FireEvent("GAME_PAD_ACTIVE_CHANGED", true)
	env.RunTimers(); AB.W.Settle(env)
	env.FireEvent("ACTION_RANGE_CHECK_UPDATE", 1, false, true)
	if os.getenv("RENDER_SHORTCUT") == "binding" then
		env._resolveRects = true
		assert(ns.Keybind.Enter())
		local o = ns.Keybind.overlays[ns.bars.bar1.buttons[1]]
		o:GetScript("OnEnter")(o)
		ns.Keybind.Input("SPACE")
	end
	assert(#env._errors == 0, AB.Errors(env))
	return Gallery.Build(env)
end)
