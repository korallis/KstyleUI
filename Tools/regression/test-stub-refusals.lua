-- test-stub-refusals.lua: the stubs raise or answer nil where the client does, for nil rects, nil and NaN scales and Font object methods.
local Stubs = dofile("Tools/regression/stubs/wow.lua")

local function raises(fn, message)
	local ok, err = pcall(fn)
	assert(not ok, "expected an error containing: " .. message)
	assert(tostring(err):find(message, 1, true), "wrong error: " .. tostring(err))
end

local env = Stubs.NewEnv()
env._resolveRects = true

local loose = env.CreateFrame("Frame", nil, env.UIParent)
loose:SetPoint("TOPLEFT", env.UIParent, "TOPLEFT")
assert(loose:GetRect() == nil, "a frame with one point and no size has no rect")
assert(loose:GetLeft() == nil and loose:GetRight() == nil and loose:GetTop() == nil and loose:GetBottom() == nil, "and no edges")
assert(loose:GetCenter() == nil and loose:GetWidth() == nil and loose:GetHeight() == nil, "no centre and no size")
raises(function() return loose:GetLeft() + 1 end, "attempt to perform arithmetic on a nil value")
raises(function() return loose:GetWidth() * 2 end, "attempt to perform arithmetic on a nil value")

local sized = env.CreateFrame("Frame", nil, env.UIParent)
sized:SetSize(10, 10)
sized:SetPoint("TOPLEFT", loose, "BOTTOMLEFT")
assert(sized:GetRect() == nil, "a frame anchored to a frame with no rect has no rect either")
raises(function() return sized:GetBottom() - 1 end, "attempt to perform arithmetic on a nil value")

local frame = env.CreateFrame("Frame", nil, env.UIParent)
local usage = "bad argument #1 to 'SetScale' (Usage: self:SetScale(scale))"
raises(function() frame:SetScale(nil) end, usage)
raises(function() frame:SetScale() end, usage)
raises(function() frame:SetScale(0 / 0) end, usage)
raises(function() frame:SetScale("2") end, usage)
raises(function() frame:SetScale({}) end, usage)
frame:SetScale(2)
assert(frame:GetScale() == 2, "a real number still sets the scale")
raises(function() frame:SetScale(0 / 0) end, usage)
assert(frame:GetScale() == 2, "a refused scale leaves the old one")

local font = env.CreateFont("KstyleRefusalFont")
for _, method in ipairs({ "GetParent", "GetWidth", "GetHeight", "GetPoint", "SetPoint", "SetSize", "SetScale", "Show", "Hide", "IsShown", "GetRect", "SetText" }) do
	assert(font[method] == nil, "a Font object has no " .. method)
end
raises(function() font:GetParent() end, "attempt to call method 'GetParent' (a nil value)")
raises(function() font:SetPoint("CENTER") end, "attempt to call method 'SetPoint' (a nil value)")
for _, method in ipairs({ "GetFont", "SetFont", "SetFontObject", "GetTextColor", "SetTextColor", "GetObjectType", "GetName" }) do
	assert(type(font[method]) == "function", "a Font object answers " .. method)
end
assert(font:GetObjectType() == "Font", "and is a Font")

local text = env.CreateFrame("Frame", nil, env.UIParent):CreateFontString(nil, "OVERLAY", "GameFontNormal")
local html = env.CreateFrame("SimpleHTML", nil, env.UIParent)
assert(type(text.GetParent) == "function" and type(text.SetPoint) == "function", "a FontString is a region and keeps its region methods")
for _, quiet in ipairs({ false, true }) do
	env.SetQuiet(quiet)
	html:SetFont("P", "font.ttf", 11, "")
	text:SetFont("font.ttf", 11, "")
	for _, height in ipairs({ 0, -1, 0 / 0, math.huge, -math.huge, env.Secret(11) }) do
		raises(function() text:SetFont("font.ttf", height, "") end, "Invalid font height")
		assert(select(2, text:GetFont()) == 11, "a refused height keeps the previous font")
	end
end
env.SetQuiet(false)

print("stub refusals ok")
