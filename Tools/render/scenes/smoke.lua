-- smoke.lua: a glass panel, a status bar, text and an icon button from the widget kit, to check the pipeline.
local Common = dofile("Tools/render/scenes/_common.lua")
local W = dofile("Tools/regression/widget_env.lua")

return Common.Run(function()
	local env, K = W.New(Common.ScreenOpts())
	local root = K.Scale.Root()
	local panel = env.CreateFrame("Frame", "SmokePanel", root)
	panel:SetSize(320, 160)
	panel:SetPoint("CENTER", root, "CENTER", 0, 0)
	panel.chrome = K.Widgets.Chrome(panel, { shape = "panel" })
	local title = K.Widgets.Text(panel, "heading", "textEmphasis")
	title:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -24)
	K.Widgets.SetText(title, "Panel Title")
	local body = K.Widgets.Text(panel, "body", "text")
	body:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	body:SetWidth(272)
	body:SetJustifyH("LEFT")
	K.Widgets.SetText(body, "A clean, minimal panel with subtle depth and refined edges.")
	local bar = K.Widgets.StatusBar(panel, { width = 272, height = 12, min = 0, max = 100, value = 78, color = "accent", spark = true })
	bar:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 24, 24)
	local button = K.Widgets.IconButton(root, { icon = 132355 })
	button:SetPoint("TOP", panel, "BOTTOM", 0, -24)
	env.RunTimers()
	W.Settle(env)
	local scene = Common.Scene.Build(env)
	local err = Common.Errors(env, K)
	if err then
		scene.log[#scene.log + 1] = "error: " .. err
	end
	return scene
end)
