-- material_study.lua: five card materials at two local scales, for the nine-screen density study.
local Common = dofile("Tools/render/scenes/_common.lua")
local W = dofile("Tools/regression/widget_env.lua")

return Common.Run(function()
	local scenes = {}
	for index, name in ipairs({ "ForgedBrackets", "ForgedTicks", "Flat", "Slate", "Glass" }) do
		local env, K = W.New(Common.ScreenOpts({ setup = Common.ForceScreen }))
		K.Store.Module("Widgets").cardMaterial = name
		for row, scale in ipairs({ 1, 0.65 }) do
			local panel = K.Widgets.Panel(K.Scale.Root(), { width = 280, height = 280, title = name })
			panel:SetScale(scale)
			panel:Restyle()
			panel:SetPoint("TOPLEFT", K.Scale.Root(), "TOPLEFT", (40 + (index - 1) * 300) / scale, -(180 + (row - 1) * 340) / scale)
			panel.chrome:Restyle()
			local text = K.Widgets.Text(panel.content, "body", "text")
			text:SetPoint("TOPLEFT", panel.content, "TOPLEFT")
			text:SetText("One physical pixel per texel")
			local caption = K.Widgets.Text(panel.content, "body", "muted")
			caption:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -20)
			caption:SetText("Window scale: " .. scale)
		end
		assert(not Common.Errors(env, K))
		scenes[#scenes + 1] = Common.Scene.Build(env)
	end
	return Common.Scene.Merge(scenes)
end)
