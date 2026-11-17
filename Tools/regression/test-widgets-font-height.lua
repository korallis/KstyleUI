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
		local _, previous = text:GetFont()
		local ok = K.Widgets.ApplyFont(text, path, size, "")
		local _, height = text:GetFont()
		assert(not env.issecretvalue(height) and type(height) == "number" and height == height and height > 0 and height < math.huge,
			"ApplyFont must keep a finite positive height for every caller")
		if size == 11 then
			assert(ok, "a valid height still applies at a tiny preview scale")
		else
			assert(ok == false and height == previous, "an invalid request keeps the previous font")
		end
	end
end
local _, previous = text:GetFont()
assert(K.Widgets.ApplyFont(text, path, nil, "") == false and select(2, text:GetFont()) == previous, "a missing height keeps the previous font")
for _, factor in ipairs({ 0, -1, 0 / 0, math.huge, -math.huge, env.Secret(1) }) do
	K.Widgets.ScaleFactor = function() return factor end
	assert(K.Widgets.ApplyFont(text, path, 11, "") == false and select(2, text:GetFont()) == previous, "an invalid scale factor keeps the previous font")
end

print("widgets font height ok")
