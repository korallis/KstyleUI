-- test-setup-polish.lua: layout pictures follow the picked HUD style; wrapping notes remain readable at 0.65 and the old diagram and note style remain selectable.
local W = dofile("Tools/regression/widget_env.lua")
local Scene = dofile("Tools/render/scene.lua")
local env, K = W.New({ boot = false, setup = function(e)
	e.C_AddOns = { DoesAddOnExist = function() return true end, LoadAddOn = function() return false, "MISSING" end }
	e._textWidth = function(text, path, size) return Scene.TextWidth(Scene.PlainText(text), size, path) end
end })
for _, entry in ipairs(K.Setup.PICKER) do K.Modules.Register(W.CoreEnv.Module(entry.name)) end
W.CoreEnv.Boot(env)
K.Setup.Open()
local panel = K.Setup.window
local function settle()
	env.RunTimers(); W.Settle(env); env.RunTimers()
end
K.Setup.Go(3)
settle()
assert(not panel.preview:IsShown(), "G4: the picture choice replaces the grey footprint preview")
for _, style in ipairs({ "frames", "orbs", "medallions" }) do
	K.Setup.Choice().hudStyle = style
	K.Setup.Go(3)
	settle()
	for _, role in ipairs({ "DPS", "Tank", "Healer" }) do
		local card = panel.cards[role]
		local name = "Layout" .. style:sub(1, 1):upper() .. style:sub(2) .. role .. ".tga"
		assert(card.picture:IsShown() and card.picture:GetTexture():find(name, 1, true), "G4: each layout picture follows the chosen style: " .. name)
		assert(card.picture:GetWidth() == 180 and card.picture:GetHeight() == 90, "layout pictures have enough room to read")
		W.Click(card)
		assert(K.Setup.Choice().layout == role, "the picture card chooses " .. role)
	end
end
K.Layout.Set("setup.window", "scale", 0.65)
K.Theme.SetFontScale(1.3)
settle()
Scene.Build(env)
for _, card in pairs(panel.cards) do
	local _, pictureY, _, pictureH = Scene.Rect(env, card.picture)
	local _, titleY = Scene.Rect(env, card.title)
	assert(titleY >= pictureY + pictureH, "G4: layout labels stay below their picture after text and window scale changes")
end
K.Theme.SetFontScale(1)
K.Options.Write("Setup", "layoutPictures", false)
settle()
assert(panel.preview:IsShown() and panel.previewName:IsShown(), "G4: Off restores the footprint diagram and legend")
for _, card in pairs(panel.cards) do assert(not card.picture:IsShown(), "Off hides the layout pictures") end
K.Setup.Go(4)
K.Layout.Set("setup.window", "scale", 0.65)
settle()
local long = panel.toggles.Skins.note
long:SetText("A long module note that must wrap and stay fully readable rather than running into the next module or out of its column.")
K.Options.Write("Setup", "readableNotes", true)
settle()
local wrapped = false
for _, entry in ipairs(K.Setup.PICKER) do
	local note = panel.toggles[entry.name].note
	local _, size = note:GetFont()
	local pixels = size * K.Widgets.ScaleFactor(note:GetParent()) / K.Scale.Pixel(1)
	assert(pixels >= K.Scale.TextFloor() - 0.01, "G4: setup notes keep the reading floor at 0.65")
	assert(W.LastCall(note, "SetWordWrap")[1] == true, "G4: module notes wrap")
	if K.Widgets.WrappedHeight(note, note:GetWidth()) > K.Widgets.LineHeight(note) then wrapped = true end
end
assert(wrapped and panel.moduleBody:GetHeight() > panel.moduleScroll:GetHeight(), "G4: wrapping notes grow a scrollable module list")
assert(panel.moduleBar:IsShown(), "a module list that scrolls shows its scroll thumb")
local wheel = panel.moduleScroll:GetScript("OnMouseWheel")
wheel(panel.moduleScroll, -10)
assert(panel.moduleScroll:GetVerticalScroll() > 0, "long notes can be reached without clipping")
K.Options.Write("Setup", "readableNotes", false)
settle()
assert(W.LastCall(long, "SetWordWrap")[1] == false and K.Widgets.IsFitted(long), "G4: Off restores the single-line small-note style")
assert(#env._errors == 0, table.concat(env._errors, "\n"))
print("setup polish ok")
