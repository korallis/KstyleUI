-- test-ornament-crests.lua: a kit window's crest is seated on its top edge, 1 physical pixel clear of the title, the close button, the content and anything else the window lists, taking a smaller tier where the larger one would touch them and none below Crest20, draws nothing for a window that lists nothing, measures a short band down to the frame below it, follows the level, restyles on a resize and on a drop but never during a drag, drops at the screen's top edge and on secret geometry, and only hides in lockdown.
local W = dofile("Tools/regression/widget_env.lua")
local env, K = W.New()
local Widgets, Scale = K.Widgets, K.Scale
assert(Widgets.Setting("ornaments") == "Full", "a profile without a stored level is Full")

local createFrame = env.CreateFrame
env.CreateFrame = function(...)
	local frame = createFrame(...)
	for _, pair in ipairs({ { "Show", "OnShow", true }, { "Hide", "OnHide", false } }) do
		local method, script, shown = pair[1], pair[2], pair[3]
		local original = frame[method]
		frame[method] = function(self, ...)
			local was = self:IsVisible()
			original(self, ...)
			if was ~= shown and self:IsVisible() == shown and self._scripts[script] then
				self._scripts[script](self)
			end
		end
	end
	return frame
end

local panel = Widgets.Panel(Scale.Root(), { title = "Kstyle window", close = true, movable = true, width = 600, height = 420 })
panel:ClearAllPoints()
panel:SetPoint("CENTER", Scale.Root(), "CENTER", 0, 0)
panel:Show()
env.RunTimers()
local crest = panel.chrome.ornament
assert(crest and crest.kind == "crest", "a titled window carries a crest handle")
local listed = {}
for _, region in ipairs(crest.inside or {}) do listed[region] = true end
assert(listed[panel.titleText] and listed[panel.closeButton] and listed[panel.content], "a kit window lists its title, close button and content as the crest's neighbours")
crest:Restyle()

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

local function one(handle, why)
	local pieces = drawn(handle)
	assert(#pieces == 1, why .. ": one crest, got " .. #pieces)
	assert(pieces[1]:GetTexture():find("ForgedOrnaments\\Crest%d+%.png$"), why .. ": a crest piece, got " .. tostring(pieces[1]:GetTexture()))
	return pieces[1]
end

local piece = one(crest, "Full")
local pl, pr, pt, pb = box(piece)
local wl, wr, wt = box(panel)
assert(math.abs((pl + pr) / 2 - (wl + wr) / 2) <= 1, "the crest is centred on the window")
assert(pt > wt and pb < wt, "the crest is seated on the top edge, its point sunk into the window's own top band")
for _, region in ipairs({ panel.titleText, panel.closeButton, panel.content }) do
	assert(gap(piece, region) >= 1, "the crest keeps 1 physical pixel from the title, the close button and the content, got " .. gap(piece, region))
end

for _, level in ipairs({ "Subtle", "Off" }) do
	K.Options.Write("Widgets", "ornaments", level)
	env.RunTimers()
	assert(#drawn(crest) == 0, "a window draws no crest at " .. level)
end
K.Options.Write("Widgets", "ornaments", "Full")
env.RunTimers()
one(crest, "Full again")

local Handle = getmetatable(crest)
local restyles = 0
local restyle = Handle.Restyle
Handle.Restyle = function(self, ...)
	if self == crest then restyles = restyles + 1 end
	return restyle(self, ...)
end

local before = piece:GetTexture()
panel:SetSize(1200, 700)
assert(restyles >= 1, "a resize restyles the crest")
local wide = one(crest, "resized")
assert(wide:GetTexture() ~= before, "a wider window takes a larger crest: " .. before .. " then " .. wide:GetTexture())
panel:SetSize(150, 420)
assert(#drawn(crest) == 0, "a window narrower than 180 units draws no crest")
panel:SetSize(600, 420)
one(crest, "back to 600")

restyles = 0
panel:StartMoving()
for i = 1, 20 do
	panel:ClearAllPoints()
	panel:SetPoint("CENTER", Scale.Root(), "CENTER", i * 7, -i * 3)
end
assert(restyles == 0, "a drag moves the anchored crest and never restyles it, got " .. restyles)
panel:StopMovingOrSizing()
assert(restyles == 1, "the drop restyles once, got " .. restyles)
one(crest, "dropped")

local rootHeight = Scale.Root():GetHeight()
panel:StartMoving()
panel:ClearAllPoints()
panel:SetPoint("TOP", Scale.Root(), "TOP", 0, 0)
panel:StopMovingOrSizing()
assert(#drawn(crest) == 0, "a window dropped against the screen's top edge draws no crest, never a cut one")
panel:StartMoving()
panel:ClearAllPoints()
panel:SetPoint("TOP", Scale.Root(), "TOP", 0, -rootHeight / 4)
panel:StopMovingOrSizing()
local high = one(crest, "dropped back below the top edge")
local _, _, highTop = box(high)
local highName = high:GetTexture()
local _, _, edgeTop = box(panel)
panel:StartMoving()
panel:ClearAllPoints()
panel:SetPoint("TOP", Scale.Root(), "TOP", 0, -(highTop - edgeTop + 0.5) * Scale.Pixel(1) / Widgets.ScaleFactor(panel))
panel:StopMovingOrSizing()
local fits = one(crest, "a window whose seated crest only just fits under the screen's top edge")
assert(fits:GetTexture() == highName, "a window whose seated crest only just fits under the screen's top edge keeps its tier")
assert(select(3, box(fits)) <= select(3, box(Scale.Root())), "the seated crest stays on screen")
panel:StartMoving()
panel:ClearAllPoints()
panel:SetPoint("TOP", Scale.Root(), "TOP", 0, -(highTop - edgeTop - 2) * Scale.Pixel(1) / Widgets.ScaleFactor(panel))
panel:StopMovingOrSizing()
local lower = one(crest, "a window too close to the screen's top for its tier")
assert(lower:GetTexture() ~= highName and select(3, box(lower)) <= select(3, box(Scale.Root())), "a window too close to the screen's top for its tier takes a smaller one that stays on screen")
panel:StartMoving()
panel:ClearAllPoints()
panel:SetPoint("TOP", Scale.Root(), "TOP", 0, -rootHeight / 4)
panel:StopMovingOrSizing()
one(crest, "dropped back again")

local getTop = panel.GetTop
panel.GetTop = function()
	return env.Secret(getTop(panel))
end
crest:Restyle()
assert(#drawn(crest) == 0, "a secret top edge drops the crest")
panel.GetTop = getTop
crest:Restyle()
one(crest, "plain again")

local getLeft = panel.GetLeft
panel.GetLeft = function()
	return env.Secret(getLeft(panel))
end
crest:Restyle()
assert(#drawn(crest) == 0, "a secret left edge drops the crest")
panel.GetLeft = getLeft
crest:Restyle()
local seatedPiece = one(crest, "plain regions again")
local seated, seatBottom = seatedPiece:GetTexture(), select(4, box(seatedPiece))

local probe = env.CreateFrame("Frame", nil, panel)
probe:SetSize(240, 12)
probe:SetPoint("TOP", panel, "TOP", 0, -6)
probe:Show()
local own = crest.inside
crest.inside = { probe }
crest:Restyle()
local smaller = one(crest, "a region high in the top band")
assert(smaller:GetTexture() ~= seated and gap(smaller, probe) >= 1, "a region high in the top band takes a smaller tier that keeps 1 physical pixel from it, got " .. smaller:GetTexture() .. " at " .. gap(smaller, probe))
probe:SetPoint("TOP", panel, "TOP", 0, -(select(3, box(panel)) - seatBottom + 0.5) * Scale.Pixel(1) / Widgets.ScaleFactor(panel))
crest:Restyle()
local near = drawn(crest)[1]
assert(near and near:GetTexture() ~= seated and gap(near, probe) >= 1, "a region half a pixel under the seated crest's point pushes it down a tier, 1 physical pixel clear")
probe:SetPoint("TOP", panel, "TOP", 0, -1)
crest:Restyle()
assert(#drawn(crest) == 0, "where even Crest20 would touch a listed region, the crest drops")
probe:Hide()
crest:Restyle()
assert(one(crest, "a hidden listed region"):GetTexture() == seated, "a hidden listed region leaves the seated tier")
probe:Show()
crest.inside = nil
crest:Restyle()
assert(#drawn(crest) == 0, "a window that lists nothing draws no crest")
crest.inside = {}
crest:Restyle()
assert(#drawn(crest) == 0, "a window whose list is empty draws no crest")
local loose = env.CreateFrame("Frame", nil, panel)
loose:Show()
crest.inside = { loose }
crest:Restyle()
assert(one(crest, "a listed region that is not placed"):GetTexture() == seated, "a listed region that is not placed draws nothing, so it leaves the seated tier")
loose.GetLeft = function() return 0 / 0 end
loose.GetRight, loose.GetTop, loose.GetBottom = function() return 10 end, function() return 10 end, function() return 0 end
crest:Restyle()
assert(#drawn(crest) == 0, "a listed region with a non-finite edge drops the crest")
crest.inside = own
probe:Hide()
local titleLeft = panel.titleText.GetLeft
panel.titleText.GetLeft = function(self)
	return env.Secret(titleLeft(self))
end
crest:Restyle()
assert(#drawn(crest) == 0, "a listed region's secret edge drops the crest")
panel.titleText.GetLeft = titleLeft
crest:Restyle()
one(crest, "the window's own regions again")
local titleVisible = panel.titleText.IsVisible
panel.titleText.IsVisible = function() return env.Secret(true) end
crest:Restyle()
assert(#drawn(crest) == 0, "a listed region whose visibility is secret drops the crest")
panel.titleText.IsVisible = titleVisible
crest:Restyle()
one(crest, "the title's visibility plain again")
panel:SetSize(320, 420)
assert(#drawn(crest) == 0, "a window whose 6% share is under Crest20 draws none, never a Crest12")
panel:SetSize(600, 420)
one(crest, "back to 600 wide")
local unit = Scale.Pixel(1) / Widgets.ScaleFactor(panel)
panel:SetWidth(599.002 * unit)
panel:ClearAllPoints()
panel:SetPoint("TOPLEFT", Scale.Root(), "TOPLEFT", 400.499 * unit, -300 * unit)
crest:Restyle()
local frac = one(crest, "a window at a fractional position")
local fracName = frac:GetTexture()
local fl, fr = box(frac)
local panelLeft = box(panel)
crest.inside = { probe }
probe:Show()
probe:SetSize(10 * unit, 4 * unit)
for _, side in ipairs({ { "TOPRIGHT", fl - 1 }, { "TOPLEFT", fr + 1 } }) do
	probe:ClearAllPoints()
	probe:SetPoint(side[1], panel, "TOPLEFT", (side[2] - panelLeft) * unit, -unit)
	crest:Restyle()
	local beside = one(crest, "a region 1 pixel beside the drawn crest")
	assert(beside:GetTexture() == fracName and gap(beside, probe) >= 1, "the seat is checked where the crest is drawn, so a region 1 pixel beside it keeps the tier")
end
probe:Hide()
crest.inside = own
panel:SetSize(600, 420)
panel:ClearAllPoints()
panel:SetPoint("CENTER", Scale.Root(), "CENTER", 0, 0)
crest:Restyle()
local centred = one(crest, "centred again")
local centredName = centred:GetTexture()
local rise = select(3, box(centred)) - select(3, box(panel))
local neighbour = Widgets.Panel(Scale.Root(), { width = 300, height = 90 })
neighbour:Show()
local function above(px)
	neighbour:ClearAllPoints()
	neighbour:SetPoint("BOTTOM", panel, "TOP", 0, px * unit)
	crest:Restyle()
	return drawn(crest)[1]
end
local over = above(0)
assert(over and over:GetTexture() == centredName, "a window flush against the top edge leaves the crest its tier, drawn over it")
over = above(rise + 1)
assert(over and over:GetTexture() == centredName and gap(over, neighbour) >= 1, "a window standing 1 pixel clear of the crest's top leaves its tier")
over = above(rise)
assert(over and over:GetTexture() ~= centredName and gap(over, neighbour) >= 1, "a window standing above with a gap the crest would touch pushes it down a tier, 1 physical pixel clear")
assert(above(2) == nil, "a window 2 pixels above the top edge leaves no room for Crest20, so the crest drops")
K.Options.Write("Widgets", "shadows", true)
env.RunTimers()
over = above(rise + 1)
assert(not over or over:GetTexture() ~= centredName and gap(over, neighbour) >= 1 + 14 / Scale.Pixel(1) * Widgets.ScaleFactor(neighbour) - 0.001, "the crest keeps 1 physical pixel from a shadowed window's shadow too")
K.Options.Write("Widgets", "shadows", false)
env.RunTimers()
neighbour:Hide()
crest:Restyle()
assert(one(crest, "the window above hidden"):GetTexture() == centredName, "a hidden window above does not block")

local band = Widgets.Panel(Scale.Root(), { title = "Band", width = 500, height = 40 })
band:ClearAllPoints()
band:SetPoint("CENTER", Scale.Root(), "CENTER", 0, 200)
band:Show()
env.RunTimers()
band.chrome.ornament:Restyle()
assert(#drawn(band.chrome.ornament) == 0, "a 40 unit tall window draws no crest")
local steps = env.CreateFrame("Frame", nil, Scale.Root())
steps:SetPoint("TOPLEFT", band, "BOTTOMLEFT", 0, 0)
steps:SetSize(500, 200)
band.chrome.ornament.body = steps
band.chrome.ornament:Restyle()
one(band.chrome.ornament, "a short band measured down to the frame below it")
band:ClearAllPoints()
band:SetPoint("BOTTOM", Scale.Root(), "BOTTOM", 0, 200)
band.chrome.ornament:Restyle()
assert(math.abs(steps:GetBottom()) < 1e-6, "the frame below the band reaches the screen's bottom edge")
one(band.chrome.ornament, "a band whose frame below reaches the screen's bottom edge")

local calls = {}
for _, texture in ipairs(crest.textures) do
	for _, method in ipairs({ "SetPoint", "ClearAllPoints", "SetSize", "SetWidth", "SetHeight", "SetTexture", "SetTexCoord", "Show" }) do
		local original = texture[method]
		texture[method] = function(self, ...)
			if env.InCombatLockdown() then calls[#calls + 1] = method end
			return original(self, ...)
		end
	end
end
panel.IsProtected = function() return true end
env._combat = true
panel:SetSize(700, 460)
assert(#calls == 0, "in lockdown a protected window's crest is never anchored, sized or shown: " .. table.concat(calls, ", "))
assert(#drawn(crest) == 0, "in lockdown a resize hides the protected window's crest until combat ends")
assert(crest.queued, "the restyle waits for the end of combat")
env._combat = false
env.FireEvent("PLAYER_REGEN_ENABLED")
env.RunTimers()
one(crest, "after combat")
panel.IsProtected = function() return false end

local opened = Widgets.Panel(Scale.Root(), { title = "Opened in combat", close = true, width = 500, height = 300, hidden = true })
opened:ClearAllPoints()
opened:SetPoint("CENTER", Scale.Root(), "CENTER", 0, -200)
env._combat = true
opened:Show()
env.RunTimers()
one(opened.chrome.ornament, "a kit window, which the game never protects, opened in combat")
env._combat = false

local untitled = Widgets.Panel(Scale.Root(), { width = 500, height = 300 })
assert(untitled.chrome.ornament == nil, "an untitled panel carries no crest")

assert(#env._errors == 0 and K.ErrorCount() == 0, "no errors: " .. tostring(env._errors[1]))

local env2, K2 = W.New({ setup = function(e) e.GetPhysicalScreenSize = function() return 3456, 2234 end end })
local narrow = K2.Widgets.Panel(K2.Scale.Root(), { title = "Narrow at 3456", close = true, width = 175, height = 300 })
narrow:ClearAllPoints()
narrow:SetPoint("CENTER", K2.Scale.Root(), "CENTER", 0, 0)
narrow:Show()
env2.RunTimers()
narrow.chrome.ornament:Restyle()
assert(175 / K2.Scale.Pixel(1) * 0.06 >= 20, "at 3456x2234 a 175 unit window is wide enough in pixels for Crest20's 6% share")
assert(#drawn(narrow.chrome.ornament) == 0, "a window narrower than 180 root units draws no crest at any screen size")
narrow:SetWidth(200)
narrow.chrome.ornament:Restyle()
one(narrow.chrome.ornament, "a 200 unit window at 3456x2234")
assert(#env2._errors == 0 and K2.ErrorCount() == 0, "no errors at 3456x2234: " .. tostring(env2._errors[1]))
print("ok a window's crest sits on its top edge, follows resizes and drops, and only hides in lockdown")
