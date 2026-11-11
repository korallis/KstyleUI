-- test-ornament-crest-tooltips.lua: a tooltip's crest is the largest at least five times narrower than the tooltip and never under Crest20, re-centres when the tooltip changes size between two units, never comes within 1 physical pixel of the first line, drops at the screen's top edge, while the tooltip follows the cursor and on secret geometry, avoids the compare header, and only hides in lockdown.
local T = dofile("Tools/regression/tooltips_env.lua")
local anchorType = "ANCHOR_NONE"
local env, K, ns = T.New({
	setup = function(env)
		env.GameTooltip.GetAnchorType = function()
			return anchorType
		end
	end,
})
if not K.Modules.IsRunning("Tooltips") then
	assert(K.Modules.Enable("Tooltips"))
end
env.RunTimers()
local Widgets, Scale = K.Widgets, K.Scale
assert(Widgets.Setting("ornaments") == "Full", "a profile without a stored level is Full")

local tip = env.GameTooltip
local glass = ns.Style.Glass(tip)
local crest = glass.chrome.ornament
assert(crest and crest.kind == "crest", "GameTooltip's glass carries a crest handle")
local embedded = ns.Style.Glass(env.EmbeddedItemTooltip)
assert(embedded and embedded.chrome.ornament == nil, "the item tooltip embedded in another tooltip carries no crest")

local Handle = getmetatable(crest)
local restyles = 0
local restyle = Handle.Restyle
Handle.Restyle = function(self, ...)
	if self == crest then restyles = restyles + 1 end
	return restyle(self, ...)
end

local function drawn(handle)
	local list = {}
	for i = 1, handle.used do
		local texture = handle.textures[i]
		if texture:IsShown() then list[#list + 1] = texture end
	end
	return list
end

local function box(region)
	local pixel, f = Scale.Pixel(1), Widgets.ScaleFactor(region)
	return region:GetLeft() * f / pixel, region:GetRight() * f / pixel, region:GetTop() * f / pixel, region:GetBottom() * f / pixel
end

local function gap(a, b)
	local al, ar, at, ab = box(a)
	local bl, br, bt, bb = box(b)
	return math.max(bl - ar, al - br, ab - bt, bb - at)
end

local function show(width, height, point, x, y, anchor)
	T.BlizzardShow(tip, false)
	anchorType = anchor or "ANCHOR_NONE"
	tip:ClearAllPoints()
	tip:SetPoint(point or "BOTTOMRIGHT", Scale.Root(), point or "BOTTOMRIGHT", x or -120, y or 240)
	tip:SetSize(width, height)
	tip.TextLeft1:SetText("Shadowgale Poacher")
	tip.TextLeft1:ClearAllPoints()
	tip.TextLeft1:SetPoint("TOPLEFT", tip, "TOPLEFT", 10, -10)
	tip.TextLeft1:SetSize(width - 20, 14)
	T.BlizzardShow(tip, true)
	glass._scripts.OnSizeChanged(glass, width, height)
end

local function one(why)
	local pieces = drawn(crest)
	assert(#pieces == 1, why .. ": one crest, got " .. #pieces)
	assert(pieces[1]:GetTexture():find("ForgedOrnaments\\Crest%d+%.png$"), why .. ": a crest piece")
	local pl, pr = box(pieces[1])
	local tl, tr = box(tip)
	assert(math.abs((pl + pr) / 2 - (tl + tr) / 2) <= 1, why .. ": the crest is centred on the tooltip")
	assert(gap(pieces[1], tip.TextLeft1) >= 1, why .. ": the crest keeps 1 physical pixel from the first line, got " .. gap(pieces[1], tip.TextLeft1))
	return pieces[1]
end

show(260, 110)
local first = one("a unit tooltip")
local firstLeft = box(first)
restyles = 0
show(380, 160)
local second = one("a wider unit tooltip")
assert(box(second) ~= firstLeft, "the crest moves to the new centre when the tooltip changes size")
assert(restyles >= 1 and restyles <= 2, "a tooltip show restyles its crest once or twice, got " .. restyles)

for _, case in ipairs({ { 150, "Crest20" }, { 200, "Crest32" }, { 310, "Crest48" }, { 400, "Crest64" } }) do
	show(case[1], 110)
	tip.TextLeft1:SetPoint("TOPLEFT", tip, "TOPLEFT", 10, -20)
	crest:Restyle()
	local piece = one("a " .. case[1] .. " wide tooltip")
	assert(piece:GetTexture():find(case[2] .. "%.png$"), "a tooltip at least five crest widths wide takes the largest such crest, " .. case[2] .. " at " .. case[1] .. ", got " .. piece:GetTexture())
end
show(310, 110)
assert(drawn(crest)[1]:GetTexture():find("Crest32%.png$"), "where Crest48's seat would touch a first line 10 below the top, the tooltip takes Crest32")
show(120, 110)
assert(#drawn(crest) == 0, "a tooltip narrower than five Crest20 widths draws none, never a Crest12")
show(150, 110)
tip.TextLeft1:SetPoint("TOPLEFT", tip, "TOPLEFT", 10, -2)
crest:Restyle()
assert(#drawn(crest) == 0, "a first line too high for Crest20's seat drops the crest")
tip.TextLeft1:SetPoint("TOPLEFT", tip, "TOPLEFT", 10, -10)

show(260, 110, "TOP", 0, 0)
assert(#drawn(crest) == 0, "a tooltip anchored at the screen's top edge draws no crest, never a cut one")
show(260, 110)
one("back at the default anchor")

show(260, 110, "BOTTOMRIGHT", -120, 240, "ANCHOR_CURSOR_RIGHT")
assert(#drawn(crest) == 0, "a tooltip that follows the cursor draws no crest")
show(260, 110)
one("anchored again")

local getWidth = tip.GetWidth
local glassWidth = glass.GetWidth
glass.GetWidth = function(self)
	return env.Secret(glassWidth(self))
end
crest:Restyle()
assert(#drawn(crest) == 0, "a secret width, as the game gives a tooltip anchored to a secret frame, draws no crest")
glass.GetWidth = glassWidth
tip.GetWidth = getWidth
crest:Restyle()
one("plain again")

local calls = {}
for _, texture in ipairs(crest.textures) do
	for _, method in ipairs({ "SetPoint", "ClearAllPoints", "SetSize", "SetTexture", "SetTexCoord", "Show" }) do
		local original = texture[method]
		texture[method] = function(self, ...)
			if env.InCombatLockdown() then calls[#calls + 1] = method end
			return original(self, ...)
		end
	end
end
glass.IsProtected = function() return true end
env._combat = true
tip:SetSize(300, 140)
glass._scripts.OnSizeChanged(glass, 300, 140)
assert(#calls == 0, "in lockdown a protected tooltip's crest is never anchored, sized or shown: " .. table.concat(calls, ", "))
assert(#drawn(crest) == 0, "in lockdown a protected tooltip that changes size hides its crest")
env._combat = false
env.FireEvent("PLAYER_REGEN_ENABLED")
env.RunTimers()
glass.IsProtected = function() return false end
one("after combat")

restyles = 0
local bar = tip.StatusBar
assert(bar, "GameTooltip has its health bar")
for i = 1, 40 do
	bar:SetValue(i / 40)
	tip:AddLine("Line " .. i)
	tip:AddDoubleLine("Left", "Right")
end
assert(restyles == 0, "the health bar and the lines a tooltip adds never restyle its crest, got " .. restyles)

local shopping = env.ShoppingTooltip1
local shopGlass = ns.Style.Glass(shopping)
local shopCrest = shopGlass.chrome.ornament
assert(shopCrest and shopCrest.avoid and shopCrest.avoid[1] == shopping.CompareHeader, "a shopping tooltip's crest avoids its compare header")
shopping:ClearAllPoints()
shopping:SetPoint("CENTER", Scale.Root(), "CENTER", 0, 0)
shopping:SetSize(300, 160)
shopping.CompareHeader:ClearAllPoints()
shopping.CompareHeader:SetPoint("BOTTOMLEFT", shopping, "TOPLEFT", 0, -1)
shopping.CompareHeader:SetSize(100, 22)
T.BlizzardShow(shopping, true)
T.BlizzardShow(shopping.CompareHeader, true)
shopGlass._scripts.OnSizeChanged(shopGlass, 300, 160)
assert(#drawn(shopCrest) == 1, "a short compare header leaves room for the crest")
for _, piece in ipairs(drawn(shopCrest)) do
	assert(gap(piece, shopping.CompareHeader) >= 3, "the crest keeps the group gap from the compare header")
end
shopping.CompareHeader:SetSize(200, 22)
assert(#drawn(shopCrest) == 0, "a compare header that reaches the centre drops the crest")

assert(#env._errors == 0 and K.ErrorCount() == 0, "no errors: " .. tostring(env._errors[1]))
print("ok a tooltip's crest re-centres, keeps clear of the first line, and drops where it cannot sit whole")
