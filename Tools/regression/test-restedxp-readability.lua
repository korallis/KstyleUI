-- test-restedxp-readability.lua: the guide's list reads at KstyleUI's body size and its active steps at the quest lines' size (0.95 of it, as the owner's picture draws both), RestedXP measures them at those sizes, and its list clears the header.
local S = dofile("Tools/regression/skins_env.lua")

local function FontSize(K, text, actual, requested)
	local factor = type(text.GetEffectiveScale) == "function" and K.Widgets.ScaleFactor(text) or 1
	local pixels = actual * factor / K.Scale.Pixel(1)
	return math.abs(actual - K.Widgets.FontSize(text, requested)) < 1e-8
		and math.abs(pixels - math.floor(pixels + 0.5)) < 1e-8
end
local Fake = dofile("Tools/regression/restedxp_fake.lua")
local W = S.W

local function Boot()
	local rxp
	local env, K = S.New({ setup = function(e) rxp = Fake.Install(e, {}) end })
	K.Modules.Enable("Skins")
	env.RunTimers()
	return env, K, rxp
end

local function LineHeight(size)
	return math.ceil(size * 1.1) + 1
end

-- The picture sets the guide's steps in the size of the quest card's objective lines (Quests/Card.lua's LINE_SCALE).
local STEP = 0.95

-- Rows take the body face and at least the body size, even when RestedXP sets a smaller font later; a larger
-- font the player asked for stays larger. RestedXP's saved guideFontSize is never written.
do
	local env, K, rxp = Boot()
	local f = rxp.RXPFrame
	local row = f.ScrollChild.framePool[1]
	local body = select(2, K.Tokens.Font("body"))
	row.text:SetFont("Fonts\\FRIZQT__.TTF", 7, "OUTLINE")
	local path, size, flags = row.text:GetFont()
	assert(path == K.Tokens.Font("body") and FontSize(K, row.text, size, body) and flags == "", "a guide row uses the body face and size after RestedXP sets 7, got " .. tostring(path) .. " " .. tostring(size))
	row.text:SetFont("Fonts\\FRIZQT__.TTF", 18, "")
	assert(FontSize(K, row.text, select(2, row.text:GetFont()), 18), "a larger requested font stays larger, got " .. tostring(select(2, row.text:GetFont())))
	assert(rxp.settings.profile.guideFontSize == nil, "RestedXP's saved guideFontSize is never written")
	local _, relative, _, _, top = f.ScrollFrame:GetPoint(1)
	assert(relative == f.BottomFrame and top <= -19, "the guide's viewport clears the header and its content inset, got " .. tostring(top))
	assert(#env._errors == 0 and K.ErrorCount() == 0, "the guide restyle neither recurses nor throws")
end

-- RestedXP measures a new step's text inside SetStep, before KstyleUI's post-hook raises its font, so the hook
-- asks RestedXP to measure again: the element is as tall as its new font, not the old one.
do
	local env, K, rxp = Boot()
	K.Options.Write("Skins", "text.size", 1.25)
	env.RunTimers()
	rxp.SetStep(2)
	local body = select(2, K.Tokens.Font("body")) * 1.25 * STEP
	local element = rxp.RXPFrame.CurrentStepFrame.framePool[2].elements[1]
	local _, size = element.text:GetFont()
	assert(FontSize(K, element.text, size, body), "a new step's text takes the quest lines' size at the player's text size, got " .. tostring(size))
	assert(element:GetHeight() == LineHeight(size), "RestedXP measures a new step at its new font: " .. tostring(element:GetHeight()) .. " for " .. LineHeight(size))
	assert(#env._errors == 0 and K.ErrorCount() == 0, "a new step raises no errors")
end

-- A text size change restyles the guide's text and has RestedXP measure the steps and the list again.
do
	local env, K, rxp = Boot()
	rxp.SetStep(1)
	local element = rxp.RXPFrame.CurrentStepFrame.framePool[1].elements[1]
	local row = rxp.RXPFrame.ScrollChild.framePool[1]
	K.Options.Write("Skins", "text.size", 1.5)
	env.RunTimers()
	local size = select(2, element.text:GetFont())
	assert(FontSize(K, element.text, size, select(2, K.Tokens.Font("body")) * 1.5 * STEP), "a text size change reaches the step text, got " .. tostring(size))
	element.text:SetFont("Fonts\\FRIZQT__.TTF", 30, "")
	assert(FontSize(K, element.text, select(2, element.text:GetFont()), 30), "a larger guide font the player set in RestedXP stays larger")
	assert(element:GetHeight() == LineHeight(size), "after a text size change the step is measured at its new font: " .. tostring(element:GetHeight()) .. " for " .. LineHeight(size))
	local rowSize = select(2, row.text:GetFont())
	assert(row:GetHeight() == LineHeight(rowSize) + 8, "after a text size change the list is measured at its new font: " .. tostring(row:GetHeight()))
	assert(#env._errors == 0 and K.ErrorCount() == 0, "a text size change raises no errors")
end

-- In combat the viewport waits for combat to end.
do
	local env, K, rxp = Boot()
	local f = rxp.RXPFrame
	local top = select(5, f.ScrollFrame:GetPoint(1))
	env.SetCombat(true)
	f.ScrollFrame:ClearAllPoints()
	f.ScrollFrame:SetPoint("TOPLEFT", f.BottomFrame, "TOPLEFT", 5, -5)
	f:UpdateVisuals()
	assert(select(5, f.ScrollFrame:GetPoint(1)) == -5, "the viewport does not move in combat")
	env.SetCombat(false)
	assert(W.Near(select(5, f.ScrollFrame:GetPoint(1)), top), "the viewport clears the header once combat ends")
	assert(#env._errors == 0 and K.ErrorCount() == 0, "a queued viewport raises no errors")
end

-- RestedXP caps the list's scroll for its own 12 units of inset; the units the header reserve takes come back, so
-- the last line still scrolls into view, and RestedXP's range is extended once, not again on every scroll.
do
	local env, K, rxp = Boot()
	local f = rxp.RXPFrame
	local bar = f.ScrollFrame.ScrollBar
	f.BottomFrame:SetSize(300, 200)
	f.ScrollChild:SetHeight(500)
	bar:SetValue(0)
	local rxpMax = math.floor(500 + 10) - 200
	local taken = 200 - 5 - 7 - f.ScrollFrame:GetHeight()
	assert(taken > 0, "the header reserve takes room from the view")
	local _, max = bar:GetMinMaxValues()
	assert(W.Near(max, rxpMax + taken), "the scroll reaches the list's end: " .. tostring(max) .. " for " .. (rxpMax + taken))
	bar:SetValue(40)
	bar:SetValue(80)
	local _, again = bar:GetMinMaxValues()
	assert(W.Near(again, max), "scrolling does not grow the range, got " .. tostring(again))
	assert(#env._errors == 0 and K.ErrorCount() == 0, "the scroll range raises no errors")
end

print("restedxp readability: passed")
