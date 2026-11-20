-- test-stubs-atlas.lua: an atlas replaces the previous file texture in recorded and quiet stubs.
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
	end
end
print("atlas replacement contract passed")
