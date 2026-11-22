-- test-medallions-rails.lua: under Medallions the rails wear KSTY-110's dark card (a header band behind a top section cap, the chat at 0.80 with its tab row banded, a round N badge and bevelled plaques on the minimap, a dark tooltip rule), and Frames and Orbs keep their own look.

local function near(a, b)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-6
end

local function same(state, r, g, b, a)
	return state ~= nil and near(state[1], r) and near(state[2], g) and near(state[3], b) and (a == nil or near(state[4], a))
end

local function setStyle(K, style, settle)
	if settle then
		settle()
	end
end

-- A window's title cap sits in a header band that runs to the card's edges and ends in a divider line.
do
	local W = dofile("Tools/regression/widget_env.lua")
	for _, screen in ipairs({ { 1920, 1080 }, { 5120, 1440 }, { 2383, 1540 } }) do
		local env, K = W.New({ width = screen[1], height = screen[2] })
		local Widgets = K.Widgets
		local panel = Widgets.Panel(K.Scale.Root(), { width = 320, height = 200, title = "Quests", close = true })
		panel:SetPoint("CENTER", K.Scale.Root(), "CENTER")
		local chrome = panel.chrome
		setStyle(K, "frames")
		assert(not chrome.header or not chrome.header[1]:IsShown(), "Frames draws no header band")
		setStyle(K, "medallions")
		local header = chrome.header
		assert(header and header[1]:IsShown() and header[2]:IsShown() and header[3]:IsShown(), "the title cap sits in a header band")
		local pixel = K.Scale.Pixel(1) / Widgets.ScaleFactor(panel)
		local top = panel:GetTop()
		local _, y = panel.cap.gem:GetCenter()
		local bottom = header[3]:GetBottom()
		assert(bottom < y and y < top, "the band holds the cap")
		local reach = (top - bottom) / pixel
		assert(math.abs(reach - math.floor(reach + 0.5)) < 1e-6, "the band ends on a whole device pixel: " .. reach)
		assert(same(header[3]._state.VertexColor, K.Tokens.Color("medCardDivider")), "a divider line closes the band")
		assert(header[2]:GetLeft() - panel:GetLeft() < 2 * pixel, "the band runs to the card's edge")
		local section = Widgets.SectionCap(panel, { text = "Reagents", width = 280 })
		section:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -120)
		section:Restyle()
		assert(header[1]:IsShown() and math.abs(header[3]:GetBottom() - bottom) < 1e-6, "a section cap lower in the card leaves the title's band where it is")
		setStyle(K, "orbs")
		assert(not header[1]:IsShown() and not header[3]:IsShown(), "leaving Medallions takes the band away")
		local er, eg, eb = K.Tokens.Color("edgeInner")
		local side = chrome.rim[4]._state
		assert(side.Gradient == nil and near(side.VertexColor[1], er) and near(side.VertexColor[2], eg) and near(side.VertexColor[3], eb), "the rim's sides go back to the flat Frames edge")
		assert(#env._errors == 0, tostring(env._errors[1]))
	end
end

-- The chat card lets the world through at 0.80 and bands its tab row instead of drawing the gilt rule.
do
	local C = dofile("Tools/regression/chat_env.lua")
	local env, K, ns = C.New()
	C.Enable(env, K)
	local glass = ns.Panel.Glass()
	assert(glass, "the chat panel is built")
	local chrome = glass.chrome
	setStyle(K, "frames")
	assert(glass.divider:IsShown(), "Frames keeps the gilt rule under the tabs")
	setStyle(K, "medallions")
	local r, g, b, a = K.Tokens.Color("medChatFill")
	local _, _, _, surface = K.Tokens.Color("surface")
	local opacity = K.Store.Module("Chat").panelOpacity or surface
	assert(same(chrome.fill[5]._state.VertexColor, r, g, b, math.min(1, a * opacity / surface)), "the chat card is the 0.80 Medallions fill")
	assert(not glass.divider:IsShown(), "the gilt rule gives way to the band")
	assert(chrome.header and chrome.header[1]:IsShown() and chrome.header[3]:IsShown(), "the tab row sits in a header band")
	setStyle(K, "frames")
	assert(glass.divider:IsShown() and not chrome.header[1]:IsShown(), "Frames gets its rule back")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- The minimap's north mark is a round badge and its plaques are bevelled cards; Frames keeps the diamond.
do
	local M = dofile("Tools/regression/minimap_env.lua")
	local env, K, ns = M.New({ enabled = true })
	M.Settle(env)
	local face = ns.Map.face
	local diamond = face.plate.diamond
	local settle = function()
		M.Settle(env)
	end
	local diamondPath = (K.Tokens.Texture("diamond"))
	setStyle(K, "frames", settle)
	assert(M.W.LastCall(diamond.gilt, "SetTexture")[1] == diamondPath, "Frames keeps the north diamond")
	setStyle(K, "medallions", settle)
	local dot = (K.Tokens.Texture("dot"))
	for name, layer in pairs(diamond) do
		assert(M.W.LastCall(layer, "SetTexture")[1] == dot, "the north badge's " .. name .. " layer is round")
	end
	local pixel = K.Scale.Pixel(1) / K.Widgets.ScaleFactor(face.mapArea)
	assert(near(diamond.black:GetWidth(), K.Widgets.Snap(face.mapArea, 16)), "the badge is 16 units")
	assert(diamond.gilt:GetWidth() < diamond.black:GetWidth() and diamond.fill:GetWidth() < diamond.gilt:GetWidth(), "an outline, a gunmetal band and a dark face")
	assert(math.abs((diamond.black:GetWidth() - diamond.gilt:GetWidth()) / pixel - 2) < 1e-6, "the outline is one device pixel each side")
	assert(same(diamond.gilt._state.VertexColor, K.Tokens.Color("medGunLit")), "the band is gunmetal")
	for i, plaque in ipairs(face.plaques) do
		assert(plaque.chrome:Bevelled() and plaque.chrome.bevel[1]:IsShown(), "plaque " .. i .. " wears the bevelled card")
		assert(not plaque.chrome.ownEdge, "plaque " .. i .. " has no steel hairline")
	end
	setStyle(K, "frames", settle)
	assert(M.W.LastCall(diamond.gilt, "SetTexture")[1] == diamondPath, "switching back restores the diamond")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- The tooltip's rule is the dark card divider under Medallions and the material's rule otherwise.
do
	local T = dofile("Tools/regression/tooltips_env.lua")
	local env, K, ns = T.New()
	local rule = K.Scale.Root():CreateTexture(nil, "ARTWORK")
	setStyle(K, "frames")
	ns.Style.PaintRule(rule)
	assert(not same(rule._state.VertexColor, K.Tokens.Color("medCardDivider")), "Frames keeps its rule colour")
	setStyle(K, "medallions")
	ns.Style.PaintRule(rule)
	assert(same(rule._state.VertexColor, K.Tokens.Color("medCardDivider")), "the rule is the dark card divider")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("test-medallions-rails: ok")
