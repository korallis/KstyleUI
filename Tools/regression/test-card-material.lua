-- test-card-material.lua: cards take the Medallions steel whatever card material is saved, custom silhouettes keep their own surface, and geometry holds on nine screens.
local W = dofile("Tools/regression/widget_env.lua")
local screens = { { 1280, 720 }, { 1366, 768 }, { 1920, 1080 }, { 2560, 1440 }, { 3440, 1440 }, { 5120, 1440 }, { 3840, 2160 }, { 2383, 1540 }, { 3456, 2234 } }
local MATERIALS = { "Flat", "Slate", "ForgedTicks", "ForgedBrackets", "Glass" }
local total = 0
for _, material in ipairs({ "Steel", "RemovedMaterial" }) do
	local saved = { version = 35, profiles = { Default = { Widgets = { cardMaterial = material } } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }
	local env, K = W.New({ saved = saved })
	assert(K.Tokens.Material(material) == nil, "removed materials have no registry entry")
	assert(K.Widgets.Setting("cardMaterial") == K.Widgets.defaults.cardMaterial, "a saved removed material falls back to the schema default")
	local panel = K.Widgets.Panel(K.Scale.Root(), { width = 320, height = 200, title = "Material" })
	assert(panel.chrome:Material() == K.Widgets.SteelMaterial(), "cards render the steel after loading a removed name")
	assert(#env._errors == 0, tostring(env._errors[1]))
end
do
	local env, K = W.New()
	for _, opts in ipairs({ { radius = 10.5 }, { chamfer = 10.5 }, { share = 0.5 }, { grain = false } }) do
		local frame = env.CreateFrame("Frame", nil, K.Scale.Root())
		frame:SetSize(34, 34)
		local chrome = K.Widgets.Chrome(frame, opts)
		assert(chrome:Material() == nil, "custom silhouettes and grain opt-outs keep their authored surface")
		assert(W.SameColor(chrome.fill[5], K.Tokens.Color("surface")))
	end
	local chrome = K.Widgets.Panel(K.Scale.Root(), { width = 320, height = 200 }).chrome
	chrome:SetRadius(10.5)
	assert(chrome:Material() == nil, "a pinned corner drops the steel")
	chrome:SetRadius(nil)
	assert(chrome:Material() == K.Widgets.SteelMaterial(), "and unpinning restores it")
	assert(#env._errors == 0)
end
for _, screen in ipairs(screens) do
	for _, size in ipairs({ 0.6, 16 / 19, 1.5 }) do
		local env, K = W.New({ width = screen[1], height = screen[2], size = size })
		local panel = K.Widgets.Panel(K.Scale.Root(), { width = 320, height = 200, title = "Material" })
		local chrome = panel.chrome
		local radius, titleX = chrome:Radius(), panel.titleText._points[1][4]
		local tile = K.Widgets.Chrome(panel, { shape = "tile" })
		local bar = K.Widgets.Chrome(panel, { shape = "bar" })
		local tileColor, barColor = tile.fill[5]._state.VertexColor, bar.fill[5]._state.VertexColor
		for _, material in ipairs(MATERIALS) do
			K.Store.Module("Widgets").cardMaterial = material
			K.Widgets.RestyleAll()
			assert(chrome:Material() == K.Widgets.SteelMaterial(), material .. " leaves the card in the steel")
			assert(chrome:Radius() == radius and panel.titleText._points[1][4] == titleX)
			assert(panel:GetWidth() == K.Scale.Snap(320) and panel:GetHeight() == K.Scale.Snap(200))
			assert(not chrome.gilt[1]:IsShown() and not chrome.gilt[4]:IsShown())
			for i = 1, 4 do
				assert(tile.fill[5]._state.VertexColor[i] == tileColor[i])
				assert(bar.fill[5]._state.VertexColor[i] == barColor[i])
			end
			total = total + 1
		end
		assert(#env._errors == 0)
		collectgarbage("collect")
	end
end
do
	local env, K = W.New()
	for _, shape in ipairs({ "panel", "card", "window", "rail" }) do
		local owner = env.CreateFrame("Frame", nil, K.Scale.Root())
		local chrome = K.Widgets.Chrome(owner, { shape = shape })
		owner:SetSize(400, 300)
		chrome:SetFillRGBA(K.Tokens.Color("surface"))
		assert(chrome:Material() == K.Widgets.SteelMaterial(), "chat's surface RGBA shares the steel")
		local alpha = chrome.fill[5]._state.VertexColor[4]
		chrome:SetFill("surface", 0.5)
		assert(W.Near(chrome.fill[5]._state.VertexColor[4], alpha * 0.5))
		chrome:SetFillRGBA(K.Tokens.Color("hostile"))
		assert(chrome:Material() == nil, "authored state colors are preserved")
		chrome:SetFill("surface")
		chrome:SetEdge("giltLit")
		local edge = { K.Widgets.Rgba("giltLit") }
		for i = 1, 4 do assert(chrome.rim[1]._state.VertexColor[i] == edge[i]) end
	end
	assert(#env._errors == 0)
end
do
	local env, K = W.New()
	local cap = K.Widgets.SectionCap(K.Scale.Root(), { text = "Quests" })
	local width, height = cap.gem:GetSize()
	for _, material in ipairs({ "ForgedBrackets", "Glass" }) do
		K.Store.Module("Widgets").cardMaterial = material
		cap:Restyle()
		assert(cap.gem:GetTexture() == K.Tokens.Texture("diamond"), material .. ": the cap keeps its diamond")
		assert(cap.gem:GetWidth() == width and cap.gem:GetHeight() == height)
	end
	assert(#env._errors == 0)
end
print("card materials: " .. total .. " screen/size/material cases passed")
