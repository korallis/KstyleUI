-- test-stubs-atlas.lua: atlas and file/colour replacements in recorded and quiet stubs.
local Stubs = dofile("Tools/regression/stubs/wow.lua")
for _, quiet in ipairs({ false, true }) do
	local env = Stubs.NewEnv()
	env.SetQuiet(quiet)
	local texture = env.CreateFrame("Frame"):CreateTexture()
	for _, asset in ipairs({ "Media/Textures/Dot.png", 136243 }) do
		texture:SetTexture(asset)
		texture:SetAlpha(0.25)
		texture:SetAtlas("UI-Test-Glyph", true)
		assert(texture:GetTexture() == nil and texture:GetTextureFileID() == nil,
			"SetAtlas must clear the previous file texture; the renderer resolves the atlas sheet")
		assert(texture:GetAtlas() == "UI-Test-Glyph", "SetAtlas must retain the new atlas name")
		assert(texture:GetAlpha() == 0.25, "replacing the file with an atlas must preserve texture alpha")
		texture:SetVertexColor(1, 1, 1, 0.25)
		assert(texture:GetAtlas() == "UI-Test-Glyph", "SetVertexColor must preserve the atlas it tints")
		texture:SetTexture(asset, "REPEAT", "CLAMP")
		assert(texture:GetAtlas() == nil, "SetTexture must clear the previous atlas")
		local file, wrapH, wrapV = texture:GetTexture()
		assert(file == asset and wrapH == "REPEAT" and wrapV == "CLAMP", "SetTexture must retain its arguments")
		assert(texture:GetTextureFileID() == (type(asset) == "number" and asset or nil), "SetTexture must expose the new file ID")
		assert(texture:GetAlpha() == 0.25, "replacing the atlas with a file must preserve texture alpha")
	end
	texture:SetAtlas("UI-Test-Glyph", true)
	texture:SetTexture(nil)
	assert(texture:GetAtlas() == nil and texture:GetTexture() == nil and texture:GetTextureFileID() == nil,
		"SetTexture(nil) must clear the previous atlas and file")
	for _, alpha in ipairs({ 0.4, false }) do
		texture:SetAtlas("UI-Test-Glyph", true)
		if alpha then
			texture:SetColorTexture(0.2, 0.3, 0.4, alpha)
		else
			texture:SetColorTexture(0.2, 0.3, 0.4)
		end
		assert(texture:GetAtlas() == nil, "SetColorTexture must clear the previous atlas")
		assert(texture:GetAlpha() == (alpha or 1), "SetColorTexture must still write alpha, defaulting to one")
	end
end
print("atlas replacement contract passed")
