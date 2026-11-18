-- test-hard-edges.lua: final skin and chat edges snap after inherited scale, and the Appearance switch restores their original anchors.
local W = dofile("Tools/regression/widget_env.lua")
local C = dofile("Tools/regression/chat_env.lua")
local Audit = dofile("Tools/regression/pixel_audit_lib.lua")
local Scene = dofile("Tools/render/scene.lua")

local function whole(value)
	return math.abs(value - math.floor(value + 0.5)) < 1e-6
end

local function edges(K, region, label)
	local pixel = K.Scale.Pixel(1) / K.Widgets.ScaleFactor(region)
	local values = { region:GetLeft(), region:GetRight(), region:GetTop(), region:GetBottom() }
	for i = 1, 4 do
		local value = values[i]
		assert(type(value) == "number", label .. ": resolve all four edges before judging them")
		assert(whole(value / pixel), label .. ": snap final edges after inherited scale, then derive the width from those edges (got " .. tostring(value / pixel) .. ")")
	end
end

for _, screen in ipairs({ {1920, 1080}, {3456, 2234} }) do
	local env, K = W.New({ width = screen[1], height = screen[2] })
	env._resolveRects = true
	local frame = env.CreateFrame("Frame", nil, env.UIParent)
	frame:SetPoint("TOPLEFT", env.UIParent, "TOPLEFT", 100.26, -100.37)
	frame:SetSize(230.41, 180.63)
	frame:SetScale(0.87)
	local panel = K.Skin.Backdrop(frame)
	edges(K, panel, "skin backdrop")
	local bad = Audit.Check(Scene.Build(env), screen[2])
	assert(#bad == 0, "judge final hard edges against the screen, even when their native window origin is fractional")
	K.Options.Write("Appearance", "snapEdges", false)
	env.RunTimers()
	assert(math.abs(panel:GetLeft() - frame:GetLeft()) < 1e-6, "off restores the original skin origin")
	K.Options.Write("Appearance", "snapEdges", true)
	env.RunTimers()
	edges(K, panel, "skin re-enabled")
	frame:SetWidth(247.83)
	edges(K, panel, "skin resized")
	assert(#env._errors == 0, tostring(env._errors[1]))

	local chat, kit = C.New({ width = screen[1], height = screen[2], setup = function(e)
		e._textWidth = function(text, _, size) return #text * size * 0.537 end
		e.ChatFrame1Tab.Text:SetHeight(12)
	end })
	chat._resolveRects = true
	C.Enable(chat, kit)
	chat.RunTimers()
	C.Dock(chat, function(text, size) return #text * size * 0.537 end)
	local tab = chat.ChatFrame1Tab
	local parts = kit.Skin.Parts(tab)
	for _, readable in ipairs({ true, false }) do
		kit.Options.Write("Appearance", "chatTabs", readable)
		chat.RunTimers()
		edges(kit, parts.underline, "chat underline")
		tab.Text:SetText("A different tab")
		edges(kit, parts.underline, "renamed chat underline")
		kit.Options.Write("Appearance", "snapEdges", false)
		chat.RunTimers()
		local _, relative, _, x = parts.underline:GetPoint(1)
		assert(relative == (readable and tab.Text or tab), "off restores the original underline target")
		assert(x == (readable and -kit.Widgets.Snap(tab, 2) or 0), "off restores the original underline inset")
		tab.Text:SetText("Renamed while snapping is off")
		assert(select(4, parts.underline:GetPoint(1)) == x, "off keeps the original anchor when a tab is renamed")
		kit.Options.Write("Appearance", "snapEdges", true)
		chat.RunTimers()
		edges(kit, parts.underline, "chat re-enabled")
	end
	assert(#chat._errors == 0, tostring(chat._errors[1]))
end
print("hard edges: skins and chat, two screens, resize, rename and original placement off ok")
