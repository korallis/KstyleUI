local W = dofile("Tools/regression/widget_env.lua")
for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	local env, K = W.New({ width = screen[1], height = screen[2] })
	local frame = env.CreateFrame("Frame")
	local texture = frame:CreateTexture(nil, "BACKGROUND")
	local keep = frame:CreateTexture(nil, "BACKGROUND")
	K.Skin.Strip(frame, { keep = { [keep] = true } })
	for _, setter in ipairs({ "SetVertexColor", "SetColorTexture" }) do
		texture[setter](texture, 1, 1, 1, 1)
		assert(texture:GetAlpha() == 0, "Hush must hook " .. setter .. " so recolouring cannot revive stripped art")
		texture[setter](texture, 0.5, 0.5, 0.5)
		assert(texture:GetAlpha() == 0, "Hush must hook " .. setter .. " when recolouring omits alpha")
		keep[setter](keep, 1, 1, 1, 0.5)
		assert(keep:GetAlpha() == 0.5, "Hush must leave kept textures free to change colour and alpha")
	end
	assert(K.Skin.Strip(frame) == 0, "Hush must not install duplicate recolour hooks")
	assert(#env._errors == 0, "Hush recolour hooks must not recurse or raise errors")
end
print("stripped texture recolour alpha passed at all four owner screens")
