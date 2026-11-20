-- options_actionbars.lua: the real Action Bars page opened on bar 2 through its picker.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local AB = dofile("Tools/regression/actionbars_env.lua")
local O = dofile("Tools/regression/options_env.lua")
local Load = dofile("Tools/regression/load_files.lua")
return Common.Run(function()
	local env, K = AB.New({ width = Common.SCREEN.width, height = Common.SCREEN.height,
		saved = Gallery.Saved({ "ActionBars" }), setup = function(e)
			Gallery.Setup(e)
			for i = 1, 180 do e._game.slots[i] = { texture = 132355, type = "spell", id = 100 + i } end
			e.C_AddOns.LoadAddOn = function(name)
				if name == "KstyleUI_Options" and not e._addons[name] then Load(O.Files(), e) end
				return true
			end
		end })
	AB.Enable(env, K)
	assert(K.Options.Open("ActionBars"))
	env.RunTimers(); AB.W.Settle(env)
	local ns = env._addons.KstyleUI_Options
	ns.Window.Jump({ page = "ActionBars", module = "ActionBars", key = "editBar" })
	env.RunTimers(); AB.W.Settle(env)
	for _, row in ipairs({ ns.Window.Parts().picker }) do
		if row:IsShown() and row.item and row.item.key == "editBar" then
			local picker = row.controls[row.item.kind]
			if row.item.kind == "segmented" then picker:Select("bar2") else picker:SetValue("bar2") end
		end
	end
	env.RunTimers(); AB.W.Settle(env)
	assert(K.Store.Module("ActionBars").editBar == "bar2", "render must select bar 2 through its picker")
	if os.getenv("RENDER_VISIBILITY_BUILDER") == "1" then
		K.Options.Write("ActionBars", "bar2.visibilityBuilder.combat", true)
		K.Options.Write("ActionBars", "bar2.visibilityBuilder.target", true)
		ns.Window.Jump({ page = "ActionBars", module = "ActionBars", key = "bar2.visibilityBuilder.mode" })
		env.RunTimers(); AB.W.Settle(env)
	end
	local target = os.getenv("RENDER_OPTIONS_KEY")
	if target then ns.Window.Jump({ page = "ActionBars", module = "ActionBars", key = target }); env.RunTimers(); AB.W.Settle(env) end
	assert(not Common.Errors(env, K), tostring(Common.Errors(env, K)))
	return Gallery.Build(env)
end)
