-- databars_menus.lua: the standalone micro menu and bag tray on their shared popup chrome.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local D = dofile("Tools/regression/databars_env.lua")

return Common.Run(function()
	local env, K, ns = D.New({
		saved = Gallery.Saved({ "DataBars" }),
		setup = function(env)
			Gallery.Setup(env)
			D.Menus(env, {
				bags = { [31] = 133634, [32] = 133635, [33] = 133636, [34] = 133634 }, backpack = 133633, keyring = 134237,
				portrait = function(texture)
					texture:SetTexture(Common.StandIn("portrait-player.png"))
				end,
			})
		end,
	})
	K.Options.Write("DataBars", "strip.menus", false)
	K.Options.Write("DataBars", "menus.always", true)
	K.Options.Write("DataBars", "micro.shown", true)
	K.Options.Write("DataBars", "bags.shown", true)
	env.RunTimers()
	D.W.Settle(env)
	assert(not Common.Errors(env, K), Common.Errors(env, K))
	assert(ns.Menus.Content("micro"):IsShown() and ns.Menus.Content("bags"):IsShown())
	for _, id in ipairs({ "micro", "bags" }) do
		assert(ns.Menus.Content(id):GetAlpha() == 1 and Common.Scene.Rect(env, ns.Menus.Glass(id)), "menu tray must be visible and placed")
	end
	return Common.Scene.Build(env, { iconDirs = Common.IconDirs() })
end)
