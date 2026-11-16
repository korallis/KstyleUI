local S = dofile("Tools/regression/stubs/wow.lua")
local env = S.NewEnv()
for _, quiet in ipairs({ false, true }) do
	env.SetQuiet(quiet)
	local t = env.CreateFrame("Frame"):CreateTexture()
	t:SetAlpha(0)
	t:SetVertexColor(0.5, 0.4, 0.8, 1)
	assert(t:GetAlpha() == 1, "SetVertexColor changes the same alpha aspect as SetAlpha")
	t:SetAlpha(0.25)
	assert(select(4, t:GetVertexColor()) == 0.25, "GetVertexColor sees region alpha")
	t:SetVertexColor(0.5, 0.4, 0.8)
	assert(t:GetAlpha() == 1, "omitted vertex alpha defaults to one")
end
print("vertex alpha contract passed")
