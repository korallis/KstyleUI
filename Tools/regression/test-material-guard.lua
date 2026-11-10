-- test-material-guard.lua: card borders remain chrome at low resolution without excusing spilled content or displaced borders.
local W = dofile("Tools/regression/widget_env.lua")
local Scene = dofile("Tools/render/scene.lua")
local Guard = dofile("Tools/render/guard.lua")
local screens = { { 1280, 720 }, { 1366, 768 }, { 1920, 1080 }, { 2560, 1440 }, { 3440, 1440 }, { 5120, 1440 }, { 3840, 2160 }, { 2383, 1540 }, { 3456, 2234 } }
for _, screen in ipairs(screens) do
	local env, K = W.New({ width = screen[1], height = screen[2] })
	Guard.ppu = screen[2] / 1080
	local panel = K.Widgets.Panel(K.Scale.Root(), { width = 320, height = 200 })
	panel:SetPoint("CENTER", K.Scale.Root(), "CENTER")
	panel:SetScale(0.65)
	for _, material in ipairs({ "Glass", "Flat", "Slate", "ForgedTicks", "ForgedBrackets" }) do
		K.Store.Module("Widgets").cardMaterial = material
		K.Widgets.RestyleAll()
		local findings = Guard.Check(Scene.Build(env))
		assert(#findings == 0, material .. " chrome is not content: " .. (#findings > 0 and findings[1].subject or ""))
	end
	local icon = panel:CreateTexture(nil, "ARTWORK")
	icon:SetSize(10, 10)
	icon:SetColorTexture(1, 1, 1, 1)
	icon:SetPoint("TOPLEFT", panel, "TOPLEFT", -5, 0)
	local found = false
	for _, finding in ipairs(Guard.Check(Scene.Build(env))) do
		found = found or finding.kind == "outside" and finding.object == icon
	end
	assert(found, "an ordinary texture spilling past the card must still fail")
	icon:Hide()
	local bracket = panel.chrome.materialBrackets[1]
	bracket:ClearAllPoints()
	bracket:SetPoint("TOPLEFT", panel, "TOPLEFT", -5, 5)
	found = false
	for _, finding in ipairs(Guard.Check(Scene.Build(env))) do
		found = found or finding.kind == "outside" and finding.object == bracket
	end
	assert(found, "a forged bracket outside its frame must still fail")
	K.Store.Module("Widgets").cardMaterial = "Glass"
	K.Widgets.RestyleAll()
	local line = panel.chrome.line[2]
	line:SetPoint("TOPLEFT", panel.chrome.line[1], "TOPRIGHT", 0, 5)
	found = false
	for _, finding in ipairs(Guard.Check(Scene.Build(env))) do
		found = found or finding.kind == "outside" and finding.object == line
	end
	assert(found, "a solid border displaced outside its frame must still fail")
end
print("material guard: five materials on nine screens; spilled content and displaced borders rejected")
