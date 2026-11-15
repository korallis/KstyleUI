-- test-medallions-steel.lua: the Medallions HUD style dresses the kit in steel (cards, caps, close buttons) and leaves Frames and Orbs as they were.
local W = dofile("Tools/regression/widget_env.lua")

local function SetStyle(K, style)
	K.Store.Module("HudStyle").style = style
	K.Callbacks.Fire("SettingChanged", "HudStyle", "style")
	assert(K.HudStyle.Current() == style, "the style applies out of combat")
end

local function Same(a, b)
	for i = 1, 4 do
		if math.abs((a[i] or 1) - (b[i] or 1)) > 0.000001 then
			return false
		end
	end
	return true
end

for _, screen in ipairs({ { 1920, 1080 }, { 5120, 1440 }, { 2383, 1540 } }) do
	local env, K = W.New({ width = screen[1], height = screen[2] })
	local Widgets = K.Widgets
	local panel = Widgets.Panel(K.Scale.Root(), { width = 320, height = 200, title = "Quests", close = true })
	local chrome = panel.chrome
	local frameCap = { panel.cap.gem._state.VertexColor[1], panel.cap.gem._state.VertexColor[2], panel.cap.gem._state.VertexColor[3] }

	for _, style in ipairs({ "frames", "orbs" }) do
		SetStyle(K, style)
		assert(not Widgets.Medallions())
		assert(Widgets.ColorName("gilt") == "gilt" and Widgets.ColorName("capsGold") == "capsGold")
		assert(chrome:Material() == K.Tokens.Material(Widgets.Setting("cardMaterial")), "Frames and Orbs keep the player's card material")
		assert(not chrome.steelCorners or not chrome.steelCorners[1]:IsShown(), "no steel corners outside Medallions")
		assert(chrome.materialBrackets[1]:IsShown(), "the forged brackets stay")
		assert(not panel.closeButton.closeRing or not panel.closeButton.closeRing.chrome.fill[5]:IsShown(), "the close button stays a bare glyph")
	end

	SetStyle(K, "medallions")
	assert(Widgets.Medallions())
	assert(Widgets.ColorName("gilt") ~= "gilt" and Widgets.ColorName("giltLit") ~= "giltLit" and Widgets.ColorName("capsGold") ~= "capsGold", "gilt becomes steel")
	assert(Widgets.ColorName("text") == "text" and Widgets.ColorName("accent") == "accent", "other colours are untouched")
	local material = chrome:Material()
	assert(material == Widgets.SteelMaterial(), "every card takes the steel material")
	assert(chrome.steel and chrome.cornersWanted)
	assert(#chrome.steelCorners == 4)
	for i, corner in ipairs(chrome.steelCorners) do
		assert(corner:IsShown(), "steel corner " .. i .. " shows")
		local point = corner._points[1]
		assert(point[1] == point[3] and point[2] == chrome.owner, "each corner sits flush in its own corner")
	end
	assert(not chrome.materialFrame[1]:IsShown() and not chrome.materialBrackets[1]:IsShown(), "no forged frame or gilt brackets")
	for _, tick in ipairs(chrome.gilt) do
		assert(not tick:IsShown(), "no gilt ticks")
	end
	assert(chrome.rim[1]:IsShown() and chrome.line[1]:IsShown(), "the steel card keeps its procedural hairline and black edge")
	local fr, fg, fb = Widgets.Rgba(material.fill)
	local fill = chrome.fill[5]._state.VertexColor
	assert(Same({ fill[1], fill[2], fill[3] }, { fr, fg, fb }), "the card fill is dark steel")
	local gem = panel.cap.gem._state.VertexColor
	local ar, ag, ab = K.Tokens.Color("accent")
	assert(math.abs(gem[1] - ar) < 0.000001 and math.abs(gem[2] - ag) < 0.000001 and math.abs(gem[3] - ab) < 0.000001, "the caps pip takes the accent")
	local ring = panel.closeButton.closeRing
	assert(ring and ring.chrome.fill[5]:IsShown(), "the close button sits in a round steel ring")
	local side = math.min(panel.closeButton:GetWidth(), panel.closeButton:GetHeight())
	assert(math.abs(ring.chrome:Radius() - side / 2) < 0.01 * side, "the ring is a circle: " .. ring.chrome:Radius() .. " of " .. side)

	local tile = Widgets.Chrome(panel, { shape = "tile" })
	assert(tile:Material() == nil and not tile.steelCorners, "tiles and sockets keep their own surface")

	SetStyle(K, "frames")
	assert(not chrome.steelCorners[1]:IsShown() and chrome.materialBrackets[1]:IsShown(), "switching back restores the forged brackets")
	assert(not ring.chrome.fill[5]:IsShown(), "and the bare close glyph")
	local back = panel.cap.gem._state.VertexColor
	assert(back[1] == frameCap[1] and back[2] == frameCap[2] and back[3] == frameCap[3], "and the gilt pip")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

do
	local env, K = W.New()
	local fired = 0
	K.Callbacks.Register("ThemeChanged", "test-medallions-steel", function()
		fired = fired + 1
	end)
	SetStyle(K, "orbs")
	assert(fired == 0, "Frames to Orbs repaints nothing new")
	SetStyle(K, "medallions")
	assert(fired == 1, "entering Medallions repaints every module's colours")
	SetStyle(K, "frames")
	assert(fired == 2, "leaving Medallions repaints them back")
	assert(#env._errors == 0)
end

print("test-medallions-steel: ok")
