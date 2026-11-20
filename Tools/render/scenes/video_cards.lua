-- video_cards.lua: the video's three-line guide, eight quests and native durability doll beside the live Medallions minimap.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Boot = dofile("Tools/regression/questcard_guide_env.lua")
local M = dofile("Tools/regression/minimap_env.lua")
local F = dofile("Tools/regression/editmode_fake.lua")
return Common.Run(function()
	local R = Boot(Common.DEFAULT_SCREEN, nil, nil, true)
	local env, K, rxp = R.env, R.K, R.rxp
	M.Blizzard(env, { position = { 0.725, 0.396 } })
	dofile("Tools/regression/load_files.lua")(M.Files(), env)
	K.Modules.Enable("Minimap"); M.Settle(env)
	rxp.currentGuide.name = "6-12 Tirisfal Glades"
	rxp.RXPFrame.GuideName.text:SetText("6-12 Tirisfal Glades")
	rxp.fake.guide({ { index = 97, elements = {
		{ text = "Talk to Carendin in the Magic Quarter", textOnly = true },
		{ text = "Turn in Halgar's Summons", textOnly = true },
		{ text = "Accept Creature of the Void", textOnly = true },
	} } })
	rxp.SetStep(); R.settle()
	local doll = env.CreateFrame("Frame", "DurabilityFrame", env.UIParent)
	doll:SetSize(58, 75)
	-- Body geometry and UVs: Blizzard_DurabilityFrame/DurabilityFrame.xml; alert colours: DurabilityFrame.lua.
	local pieces = {
		{ "Head", 18,22, "TOPRIGHT", "", "TOPRIGHT", -20,0, 0,0.140625,0,0.171875 },
		{ "Shoulders",48,22,"TOP","Head","BOTTOM",0,16, 0.140625,0.515625,0,0.171875 },
		{ "Chest",20,22,"TOP","Shoulders","TOP",0,-7, 0.515625,0.6640625,0,0.171875 },
		{ "Wrists",44,22,"TOP","Shoulders","BOTTOM",0,7, 0.6640625,1,0,0.171875 },
		{ "Hands",42,18,"TOP","Wrists","BOTTOM",0,15, 0,0.328125,0.171875,0.3046875 },
		{ "Waist",16,5,"TOP","Chest","BOTTOM",0,6, 0.328125,0.46875,0.171875,0.203125 },
		{ "Legs",29,20,"TOP","Waist","BOTTOM",0,2, 0.46875,0.6875,0.171875,0.3203125 },
		{ "Feet",41,32,"TOP","Legs","BOTTOM",0,8, 0.6875,1,0.171875,0.4140625 },
	}
	for _, p in ipairs(pieces) do
		local texture = doll:CreateTexture(nil, "BACKGROUND")
		doll[p[1]] = texture
		texture:SetSize(p[2], p[3]); texture:SetPoint(p[4], doll[p[5]] or doll, p[6], p[7], p[8])
		texture:SetTexture("Interface\\Durability\\UI-Durability-Icons")
		texture:SetTexCoord(p[9], p[10], p[11], p[12])
		texture:SetVertexColor(1, 0.82, 0.18, 1)
	end
	-- Start at the video's managed position, touching the guide's top, before Apply places this native system.
	local guide = K.Skin.Parts(rxp.RXPFrame).backdrop
	local k = K.Scale.Root():GetEffectiveScale() / env.UIParent:GetEffectiveScale()
	local state = { saved = {}, active = 1 }
	F.Install(env, state)
	local modern = F.Modern
	F.Modern = function()
		local layout = modern()
		F.Find(layout, 16).anchorInfo = { point = "BOTTOMRIGHT", relativeTo = "UIParent", relativePoint = "BOTTOMLEFT", offsetX = guide:GetRight() * guide:GetEffectiveScale() / env.UIParent:GetEffectiveScale(), offsetY = guide:GetTop() * guide:GetEffectiveScale() / env.UIParent:GetEffectiveScale() }
		return layout
	end
	assert(K.Setup.EditMode.Write("DPS", K.Setup.Story("DPS", true)))
	local a = F.Find(F.Named(state, "KstyleUI DPS"), 16).anchorInfo
	doll:SetPoint(a.point, env.UIParent, a.relativePoint, a.offsetX, a.offsetY)
	assert(k > 0 and not Common.Errors(env, K), tostring(Common.Errors(env, K)))
	return Gallery.Build(env)
end)
