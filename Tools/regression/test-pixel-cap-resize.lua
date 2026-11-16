-- test-pixel-cap-resize.lua: cap regions stay on the pixel grid when their row receives its raw content height after the cap is built.
local W = dofile("Tools/regression/widget_env.lua")
local env, K = W.New()
local Widgets = K.Widgets
local row = env.CreateFrame("Frame", nil, K.Scale.Root())
local pixel = K.Scale.Pixel(1) / Widgets.ScaleFactor(row)
row:SetSize(100 * pixel, 20 * pixel)
local gem = row:CreateTexture(nil, "OVERLAY")
Widgets.Size(gem, 8 * pixel, 8 * pixel)
local title = Widgets.Text(row, "caps")
Widgets.Point(gem, "LEFT", row, "LEFT")
Widgets.Point(title, "LEFT", row, "LEFT")

local function Whole(v)
	return math.abs(v - math.floor(v + 0.5)) < 1e-6
end

for _, height in ipairs({ 21, 22, 23 }) do
	row:SetHeight(height * pixel)
	local _, _, _, _, gy = gem:GetPoint()
	local _, _, _, _, ty = title:GetPoint()
	assert(Whole(height / 2 - gy / pixel - 4), "Widgets.Point must follow a raw row resize: put the cap gem back on whole pixels")
	assert(Whole(height / 2 - ty / pixel), "Widgets.Point must follow a raw row resize: put the cap title back on whole pixels")
end

title:SetPoint("LEFT", row, "LEFT", 0, pixel / 4)
row:SetHeight(24 * pixel)
assert(select(5, title:GetPoint()) == pixel / 4, "a caller's later raw anchor still wins")

local stretched = env.CreateFrame("Frame", nil, K.Scale.Root())
stretched:SetPoint("TOPLEFT", K.Scale.Root(), "TOPLEFT")
stretched:SetPoint("TOPRIGHT", K.Scale.Root(), "TOPRIGHT")
stretched:SetHeight(21 * pixel)
local caption = Widgets.Text(stretched, "caps")
Widgets.Point(caption, "LEFT", stretched, "LEFT")
assert(Whole(21 / 2 - select(5, caption:GetPoint()) / pixel), "Widgets.Point must snap a known height even while the row's width is unresolved")
print("pixel cap resize ok")
