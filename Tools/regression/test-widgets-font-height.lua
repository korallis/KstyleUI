-- test-widgets-font-height.lua: ApplyFont never forwards an invalid height, even in a tiny preview (#444).
local W = dofile("Tools/regression/widget_env.lua")
local env, K = W.New()
local parent = K.Widgets.MarkPreview(env.CreateFrame("Frame", nil, K.Scale.Root()))
local text = K.Widgets.FontString(parent, "OVERLAY")
local path = K.Tokens.Font("body")

K.Widgets.ApplyFont(text, path, 11, "")
for _, scale in ipairs({ 0.006993, 1, 1e-300 }) do
	parent:SetScale(scale)
	for _, size in ipairs({ 11, 0, -1, 0 / 0, math.huge, -math.huge, env.Secret(11), "11", false }) do
		K.Widgets.ApplyFont(text, path, size, "")
		local _, height = text:GetFont()
		assert(not env.issecretvalue(height) and type(height) == "number" and height == height and height > 0 and height < math.huge,
			"ApplyFont must keep a finite positive height for every caller")
	end
end

print("widgets font height ok")
