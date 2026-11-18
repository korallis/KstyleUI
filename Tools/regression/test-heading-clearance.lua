-- test-heading-clearance.lua: heading rules stay below their wanted font line when native text measurements are unavailable.
local S = dofile("Tools/regression/skins_env.lua")

for _, locale in ipairs({ "enUS", "deDE", "zhCN" }) do
	local env, K, skin = S.New({ locale = locale })
	K.Options.Write("HudStyle", "style", "medallions")
	K.Modules.Enable("Skins")
	local W = K.Widgets
	local cap = W.SectionCap(K.Scale.Root(), { text = K.L["Feedback"] })
	local panel = W.Panel(K.Scale.Root(), { width = 320, height = 200, title = K.L["Feedback"] })
	local story = skin.Lumen.SectionCap(K.Scale.Root())
	story.row:SetSize(320, 24)
	story:SetTitle(K.L["Feedback"])
	for _, unknown in ipairs({ function() return nil end, function() return 0 end, function() return env.Secret(30) end }) do
		for _, label in ipairs({ cap.label, panel.cap.label, story.title }) do label.GetStringHeight = unknown end
		cap:Restyle()
		panel:Restyle()
		story:Restyle()
		for _, item in ipairs({ { cap.label, cap.rule, cap, W.Snap(cap, 2) }, { panel.cap.label, panel.cap.rule, panel, W.Snap(panel, 2) }, { story.title, story.rule, story.row, W.Snap(story.row, skin.Lumen.Size(story.row, 2)) } }) do
			local label, rule, owner, gap = unpack(item)
			local _, _, _, _, y = rule:GetPoint(1)
			local halfRule = rule:GetHeight() / 2
			assert(y + halfRule <= -W.LineHeight(label) / 2 - gap + W.Border(owner) / 2 + 0.001, locale .. ": place the rule below the whole wanted font line, never through its baseline")
		end
	end
	assert(#env._errors == 0, tostring(env._errors[1]))
end
print("heading clearance: nil, zero and secret heights preserve the font line in every locale")
