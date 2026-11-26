-- material_study.lua: five card materials at two local scales, for the nine-screen density study.
local Common = dofile("Tools/render/scenes/_common.lua")
local W = dofile("Tools/regression/widget_env.lua")

-- The materials draw under the Frames HUD style only; each column must draw the assets Tokens.lua gives its material.
local ASSETS = { "MaterialForged", "ForgedFrame", "ForgedBracket", "MaterialSlate" }
local DRAWS = {
	ForgedBrackets = { MaterialForged = true, ForgedFrame = true, ForgedBracket = true },
	ForgedTicks = { MaterialForged = true, ForgedFrame = true },
	Flat = {},
	Slate = { MaterialSlate = true },
	Glass = {},
}

return Common.Run(function()
	local scenes = {}
	for index, name in ipairs({ "ForgedBrackets", "ForgedTicks", "Flat", "Slate", "Glass" }) do
		local env, K = W.New(Common.ScreenOpts({ setup = Common.ForceScreen }))
		K.Options.Write("HudStyle", "style", "frames")
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
		local scene = Common.Scene.Build(env)
		local drawn = {}
		for _, item in ipairs(scene.items) do
			for _, asset in ipairs(ASSETS) do
				if item.kind == "texture" and type(item.file) == "string" and item.file:find("/" .. asset, 1, true) then
					drawn[asset] = (drawn[asset] or 0) + 1
				end
			end
		end
		for _, asset in ipairs(ASSETS) do
			assert((drawn[asset] ~= nil) == (DRAWS[name][asset] == true), name .. (DRAWS[name][asset] and " draws no " or " draws ") .. asset .. ": " .. tostring(drawn[asset] or 0))
		end
		scenes[#scenes + 1] = scene
	end
	return Common.Scene.Merge(scenes)
end)
