-- test-card-material.lua: material isolation, geometry, visibility and one physical pixel per grain texel on nine screens.
local W = dofile("Tools/regression/widget_env.lua")
local screens = { { 1280, 720 }, { 1366, 768 }, { 1920, 1080 }, { 2560, 1440 }, { 3440, 1440 }, { 5120, 1440 }, { 3840, 2160 }, { 2383, 1540 }, { 3456, 2234 } }
local total = 0
for _, screen in ipairs(screens) do
	for _, size in ipairs({ 0.6, 16 / 19, 1.5 }) do
		local env, K = W.New({ width = screen[1], height = screen[2], size = size })
		assert(K.Widgets.Setting("cardMaterial") == "Glass")
		local panel = K.Widgets.Panel(K.Scale.Root(), { width = 320, height = 200, title = "Material" })
		local chrome = panel.chrome
		local radius, titleX = chrome:Radius(), panel.titleText._points[1][4]
		local tile = K.Widgets.Chrome(panel, { shape = "tile" })
		local bar = K.Widgets.Chrome(panel, { shape = "bar" })
		local tileColor, barColor = tile.fill[5]._state.VertexColor, bar.fill[5]._state.VertexColor
		for _, material in ipairs({ "Flat", "Slate", "ForgedTicks", "ForgedBrackets", "Glass" }) do
			K.Store.Module("Widgets").cardMaterial = material
			K.Widgets.RestyleAll()
			assert(chrome:Radius() == radius and panel.titleText._points[1][4] == titleX)
			assert(panel:GetWidth() == K.Scale.Snap(320) and panel:GetHeight() == K.Scale.Snap(200))
			assert(chrome.gilt[1]:IsShown() == (material ~= "ForgedBrackets"))
			assert(chrome.gilt[4]:IsShown() == (material ~= "ForgedBrackets"))
			for i = 1, 4 do
				assert(tile.fill[5]._state.VertexColor[i] == tileColor[i])
				assert(bar.fill[5]._state.VertexColor[i] == barColor[i])
			end
			local spec = K.Tokens.Material(material)
			if spec.frame then
				local physical = panel:GetEffectiveScale() * screen[2] / 768
				local corner = chrome.materialFrame[1]:GetWidth() * physical
				local texels = ({ forgedFrame1 = 8, forgedFrame2 = 16, forgedFrame3 = 24 })[chrome.materialFrame.texture]
				assert(W.Near(corner, texels), "the nine-slice corner has one physical pixel per texel")
				assert(chrome.materialFrame[1]._state.SnapToPixelGrid[1] == true)
				assert(not chrome.line[1]:IsShown() and not chrome.rim[1]:IsShown())
				if spec.brackets then
					assert(#chrome.materialBrackets == 4)
					for _, bracket in ipairs(chrome.materialBrackets) do
						assert(W.Near(bracket:GetWidth() * physical, texels))
						assert(bracket._state.SnapToPixelGrid[1] == true)
						local tc = bracket._state.TexCoord
						local source = texels == 24 and 32 or texels
						assert(W.Near(math.abs(tc[2] - tc[1]) * source, texels))
					end
				end
			else
				assert(not chrome.materialFrame or not chrome.materialFrame[1]:IsShown())
			end
			if spec.texture then
				assert(chrome.grain:IsShown())
				local function density()
					local tc = chrome.grain._state.TexCoord
					local physical = chrome.grain:GetEffectiveScale() * screen[2] / 768
					assert(math.abs(chrome.grain:GetWidth() * physical / (tc[2] * spec.texels) - 1) < 0.000001)
					assert(math.abs(chrome.grain:GetHeight() * physical / (tc[4] * spec.texels) - 1) < 0.000001)
				end
				density()
				panel:SetSize(400, 220)
				chrome:OnSizeChanged()
				density()
				panel:SetScale(0.65)
				chrome:Restyle()
				density()
				panel:SetScale(1)
				panel:Restyle()
				chrome:Restyle()
				chrome:SetShown(false)
				assert(not chrome.grain:IsShown())
				chrome:SetShown(true)
				assert(chrome.grain:IsShown())
			else
				assert(not chrome.grain or not chrome.grain:IsShown())
			end
			total = total + 1
		end
		K.Store.Module("Widgets").cardMaterial = "invalid"
		assert(K.Widgets.Setting("cardMaterial") == "Glass")
		assert(#env._errors == 0)
		collectgarbage("collect")
	end
end
do
	local env, K = W.New()
	K.Store.Module("Widgets").cardMaterial = "Slate"
	for _, shape in ipairs({ "panel", "card", "window", "rail" }) do
		local owner = env.CreateFrame("Frame", nil, K.Scale.Root())
		local chrome = K.Widgets.Chrome(owner, { shape = shape })
		assert(not chrome.grain)
		owner:SetSize(400, 300)
		assert(chrome.grain and chrome.grain:IsShown(), "first native size event creates the grain")
		chrome:SetFillRGBA(K.Tokens.Color("surface"))
		assert(chrome:Material() == K.Tokens.Material("Slate"), "chat's surface RGBA shares the material")
		local alpha = chrome.fill[5]._state.VertexColor[4]
		chrome:SetFill("surface", 0.5)
		assert(W.Near(chrome.fill[5]._state.VertexColor[4], alpha * 0.5))
		chrome:SetFillRGBA(K.Tokens.Color("hostile"))
		assert(chrome:Material() == nil and not chrome.grain:IsShown(), "authored state colors are preserved")
		chrome:SetFill("surface")
		chrome:SetEdge("giltLit")
		local edge = { K.Tokens.Color("giltLit") }
		for i = 1, 4 do assert(chrome.rim[1]._state.VertexColor[i] == edge[i]) end
		local mayMove = K.Widgets.MayMove
		K.Widgets.MayMove = function() return false end
		local queue = K.Combat.Queue
		local pending
		K.Combat.Queue = function(fn) pending = fn end
		chrome:SetShown(false)
		assert(not chrome.grain:IsShown(), "visibility is applied even when geometry must wait")
		K.Widgets.MayMove, K.Combat.Queue = mayMove, queue
		pending()
		chrome:SetShown(true)
		local setTexture = chrome.grain.SetTexture
		chrome.grain.SetTexture = function() return false end
		chrome:PaintMaterial()
		assert(not chrome.grain:IsShown(), "a rejected texture falls back to the flat fill")
		chrome.grain.SetTexture = setTexture
		chrome:PaintMaterial()
		assert(chrome.grain:IsShown())
	end
	assert(#env._errors == 0)
end
do
	local env, K = W.New()
	local owner = env.CreateFrame("Frame", nil, K.Scale.Root())
	owner:SetSize(300, 180)
	local chrome = K.Widgets.Chrome(owner, { shape = "card" })
	local mayMove, queue = K.Widgets.MayMove, K.Combat.Queue
	local pending
	K.Widgets.MayMove = function() return false end
	K.Combat.Queue = function(fn) pending = fn end
	K.Store.Module("Widgets").cardMaterial = "ForgedBrackets"
	chrome:Paint()
	assert(chrome.rim[1]:IsShown() and chrome.line[1]:IsShown() and not chrome.materialFrame)
	K.Widgets.MayMove, K.Combat.Queue = mayMove, queue
	pending()
	assert(chrome.materialFrame[1]:IsShown() and not chrome.rim[1]:IsShown())
	chrome:SetEdge("hostile")
	assert(chrome.materialFrame[1]:IsShown() and chrome.rim[1]:IsShown())
	assert(chrome.rim[1]._state.DrawLayer[2] == 0, "authored focus edge draws above the forged frame")
	chrome:SetProc(true)
	assert(chrome.rim[1]:IsShown() and chrome.rim[1]._state.VertexColor[1] == (K.Tokens.Color("giltLit")))
	chrome:SetProc(false)
	chrome:SetEdge("edgeInner")
	assert(not chrome.ownEdge and not chrome.rim[1]:IsShown())
	owner:SetSize(14, 14)
	assert(not chrome.materialFrame[1]:IsShown() and chrome.rim[1]:IsShown() and chrome.line[1]:IsShown())
	K.Store.Module("Widgets").cardMaterial = "Glass"
	chrome:Restyle()
	assert(chrome.rim[1]:IsShown() and chrome.rim[1]._state.DrawLayer[2] == -2)
	local other = env.CreateFrame("Frame", nil, K.Scale.Root())
	other:SetSize(300, 180)
	local otherChrome = K.Widgets.Chrome(other, { shape = "card" })
	local getWidth = other.GetWidth
	other.GetWidth = function() return env.Secret(300) end
	K.Store.Module("Widgets").cardMaterial = "ForgedTicks"
	otherChrome:Paint()
	assert(otherChrome.line[1]:IsShown() and otherChrome.rim[1]:IsShown() and not otherChrome.materialFrame)
	other.GetWidth = getWidth
	otherChrome:Restyle()
	assert(otherChrome.materialFrame[1]:IsShown())
	local cap = K.Widgets.SectionCap(K.Scale.Root(), { text = "Quests" })
	local width, height = cap.gem:GetSize()
	assert(cap.gem:GetTexture() == K.Tokens.Texture("forgedDiamond"))
	assert(cap.rule:GetTexture() == K.Tokens.Texture("forgedRule"))
	K.Store.Module("Widgets").cardMaterial = "Glass"
	cap:Restyle()
	assert(cap.gem:GetTexture() == K.Tokens.Texture("diamond"))
	assert(cap.gem:GetWidth() == width and cap.gem:GetHeight() == height)
	assert(#env._errors == 0)
end
print("card materials: " .. total .. " screen/size/material cases passed")
