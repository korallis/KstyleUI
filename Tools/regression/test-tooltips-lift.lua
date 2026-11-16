-- test-tooltips-lift.lua: the fixed tooltip lifts over a shown threat card or target of target that sits in its column above the anchor (LEE-1535: under every HUD style the item tooltip covered the threat card), and stays at the anchor when they are hidden, out of its column, or the anchor grows down.
local T = dofile("Tools/regression/tooltips_env.lua")
local Near = T.Near

local env, K, ns = T.New()
assert(K.Modules.Enable("Tooltips") and K.Modules.IsRunning("Tooltips"), "the module runs: " .. tostring(env._errors[1]))
local Layout, Layouts, Root = K.Layout, K.Setup.Layouts, K.Scale.Root()
local KEY = "tooltips.anchor"
local tip, holder = env.GameTooltip, ns.Anchor.Frame()
local gap = K.Tokens.Size("gapLarge")

local function Card(key, width, height)
	local frame = env.CreateFrame("Frame", nil, Root)
	frame:SetSize(width, height)
	Layout.Register(frame, key, Layouts.Default(key), { label = key })
	return frame
end

local function Offset()
	env.GameTooltip_SetDefaultAnchor(tip, env.UIParent)
	assert(tip:GetNumPoints() == 1, "one point")
	local point, relative, relativePoint, x, y = tip:GetPoint(1)
	assert(relative == holder and point == relativePoint, "the tooltip hangs on the anchor by one corner")
	return point, x or 0, y or 0
end

local function Put(key, x, y)
	assert(Layout.Set(key, "anchor", "BOTTOMRIGHT") and Layout.Set(key, "x", x) and Layout.Set(key, "y", y))
end

local threat = Card("meters.threat", 200, 112)
local tot = Card("unitframes.targettarget", 120, 40)
local _, anchorBottom = Layout.Rect(KEY)
local anchorX, anchorY, anchorPoint = Layout.Get(KEY).x, Layout.Get(KEY).y, Layout.Get(KEY).anchor
local ratio = Root:GetEffectiveScale() / tip:GetEffectiveScale()

do
	Put("meters.threat", anchorX - 150, anchorBottom + 60)
	threat:Hide()
	tot:Hide()
	local point, x, y = Offset()
	assert(point == "BOTTOMRIGHT" and Near(x, 0) and Near(y, 0), "with nothing shown the tooltip sits on the anchor")

	threat:Show()
	point, x, y = Offset()
	local want = (anchorBottom + 60 + 112 + gap - anchorBottom) * ratio
	assert(point == "BOTTOMRIGHT" and Near(x, 0) and Near(y, want), string.format("a shown threat card in the column lifts the tooltip clear of it: %s, wants %s", y, want))

	Put("unitframes.targettarget", anchorX - 10, anchorBottom + 10)
	tot:Show()
	_, _, y = Offset()
	assert(Near(y, want), "a target of target under the threat card lifts it no higher than the card")

	threat:Hide()
	_, _, y = Offset()
	assert(Near(y, (10 + 40 + gap) * ratio), "the target of target alone lifts it over itself: " .. tostring(y))
	tot:Hide()
end

do
	threat:Show()
	Put("meters.threat", anchorX - ns.Anchor.COLUMN - 20, anchorBottom + 60)
	local _, _, y = Offset()
	assert(Near(y, 0), "a card left of the tooltip's column stays uncovered and moves nothing")
	Put("meters.threat", anchorX - 150, anchorBottom + ns.Anchor.REACH + 40)
	_, _, y = Offset()
	assert(Near(y, 0), "a card above the tooltip's reach moves nothing")
	Put("meters.threat", anchorX - 150, anchorBottom - 200)
	_, _, y = Offset()
	assert(Near(y, 0), "a card under the anchor moves nothing")
end

do
	Put("meters.threat", anchorX - 150, anchorBottom + 60)
	assert(Layout.Set(KEY, "anchor", "TOPRIGHT") and Layout.Set(KEY, "y", -80))
	local point, _, y = Offset()
	assert(point == "TOPRIGHT" and Near(y, 0), "an anchor that grows down never lifts")
end

do
	assert(Layout.Set(KEY, "anchor", anchorPoint) and Layout.Set(KEY, "x", anchorX) and Layout.Set(KEY, "y", anchorY))
	Put("meters.threat", anchorX - 150, anchorBottom + 60)
	threat:Show()
	assert(select(3, Offset()) > 0, "the anchor is back where the card lifts it")
	local isVisible = threat.IsVisible
	threat.IsVisible = function()
		return env.Secret(true)
	end
	local _, _, y = Offset()
	assert(Near(y, 0), "a card whose shown state is secret is never read as shown")
	threat.IsVisible = isVisible
	local scale = tip.GetEffectiveScale
	tip.GetEffectiveScale = function()
		return env.Secret(1)
	end
	_, _, y = Offset()
	assert(Near(y, 0), "a secret tooltip scale keeps the tooltip on the anchor")
	tip.GetEffectiveScale = scale
	threat:Hide()
end

do
	local Logic = ns.Logic
	assert(Logic.Lift(100, 0, 300, {}, 12, 240) == 0, "no cards, no lift")
	assert(Logic.Lift(100, 0, 300, { { 50, 150, 250, 260 } }, 12, 240) == 172, "over the card and its gap")
	assert(Logic.Lift(100, 0, 300, { { 50, 120, 250, 160 }, { 50, 170, 250, 280 } }, 12, 240) == 192, "over a stack of cards, whichever order they come in")
	assert(Logic.Lift(100, 0, 300, { { 50, 170, 250, 280 }, { 50, 120, 250, 160 } }, 12, 240) == 192, "the order of the cards does not matter")
	assert(Logic.Lift(100, 0, 300, { { 300, 150, 400, 260 } }, 12, 240) == 0, "a card touching the column's edge is outside it")
	assert(Logic.Lift(env.Secret(100), 0, 300, { { 50, 150, 250, 260 } }, 12, 240) == 0, "a secret is never compared")
	assert(Logic.Lift(100, 0, 300, { { 50, 150, 250, 260 } }, -1, 240) == 0, "a negative gap lifts nothing, so the loop always ends")
end

assert(#env._errors == 0, tostring(env._errors[1]))
print("tooltips lift ok")
