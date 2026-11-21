-- databars_tooltip.lua: the data bar with one item hovered and its tooltip open, where the screen clamp puts it.
-- RENDER_HOVER names a readout (time, gold, ...); without it the Guild & Communities micro button is hovered.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local D = dofile("Tools/regression/databars_env.lua")

return Common.Run(function()
	local env, K, ns = D.New({
		saved = Gallery.Saved({ "DataBars" }),
		setup = function(env)
			Gallery.Setup(env)
			D.Menus(env, { bags = { [31] = 133634, [32] = 133635, [33] = 133636, [34] = 133634 }, backpack = 133633, keyring = 134237 })
		end,
	})
	K.Options.Write("DataBars", "menus.always", true)
	K.Options.Write("DataBars", "micro.shown", true)
	env.RunTimers()
	local hover = os.getenv("RENDER_HOVER")
	local owner = hover and ns.Strip.view.items[hover].button
	for _, button in ipairs(ns.Menus.Shown("micro")) do
		if not hover and button:GetAttribute("clickbutton") == env.GuildMicroButton then owner = button end
	end
	env.GuildMicroButton.tooltipText = "Guild & Communities |cffffd200(J)|r"
	D.W.Enter(assert(owner, "the hovered item exists"))
	D.W.Settle(env)
	assert(not Common.Errors(env, K), Common.Errors(env, K))
	return Common.Scene.Build(env, { iconDirs = Common.IconDirs() })
end)
