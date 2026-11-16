-- test-options-slider-bounds.lua: scaled options sliders reserve room for their rendered value and endpoints above the description.
local O = dofile("Tools/regression/options_env.lua")
local Scene = dofile("Tools/render/scene.lua")
local env, K, ns = O.New()
K.Options.Open("General")
local list = env.CreateFrame("Frame", nil, K.Scale.Root())
list.view = list
list.GetViewWidth = function() return 340 end
local row = ns.Rows.Create(list)
row:SetPoint("CENTER")
for _, scale in ipairs({ 1, 0.65 }) do
	list:SetScale(scale)
	K.Widgets.RestyleUnder({ [list] = true })
	for _, range in ipairs({ { -1985, 1985, 30 }, { 0.5, 1, 0.75 }, { 0.75, 1.5, 1 } }) do
		local item = { kind = "slider", label = "Panel opacity", help = "How solid the selected material looks. Glass keeps the giant small-screen glass opacity.", min = range[1], max = range[2], get = function() return range[3] end }
		local height = ns.Rows.Measure(item, nil, list, 340)
		row:SetSize(340, height)
		ns.Rows.Update(row, item, nil, list)
		Scene.Build(env)
		local slider = row.controls.slider
		assert(math.abs(slider:GetHeight() - list.measureRow.controls.slider:GetHeight()) < 0.01, "measure the options slider with the same scaled fonts as its visible row")
		local _, sy, _, sh = Scene.Rect(env, slider)
		local _, hy = Scene.Rect(env, row.help)
		for _, text in ipairs({ slider.readout, slider.minText, slider.maxText }) do
			local _, y, _, h = Scene.Rect(env, text)
			assert(y >= sy - 0.01 and y + h <= sy + sh + 0.01, string.format("size the options slider for its actual fonts: %s at %.2f..%.2f escapes %.2f..%.2f at scale %.2f", text:GetText(), y, y + h, sy, sy + sh, scale))
			assert(y + h <= hy + 0.01, "reserve slider endpoints above the description at scale " .. scale)
		end
	end
end
print("options slider bounds ok")
