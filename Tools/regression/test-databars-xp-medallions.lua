-- test-databars-xp-medallions.lua: under the Medallions HUD style the experience and reputation bars are a flat strip of ten segments with the percent and rested share right-aligned under it, the experience strip moves to the slab's LOW strata so the crest hub draws over it, and Frames and Orbs get their own look and strata back.
local D = dofile("Tools/regression/databars_env.lua")
local W = D.W

local function eq(got, want, what)
	assert(got == want, what .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end

local env, K, ns, game = D.New({ game = { level = 11, xp = 3400, xpMax = 10000, rested = 1400 } })
local xp, rep = ns.Bars.views.xp, ns.Bars.views.rep
local flat = K.Tokens.Texture("barFlat")
local DOT = " \194\183 "
local RESTED = "rested " .. math.ceil(1400 / 10000 * 100) .. "%"

local function shownTicks(view)
	local count = 0
	for _, tick in ipairs(view.ticks) do
		count = count + (tick:IsShown() and 1 or 0)
	end
	return count
end

local function noErrors(where)
	assert(#env._errors == 0, where .. ": " .. tostring(env._errors[1]))
	assert(K.ErrorCount() == 0, where .. ": KstyleUI caught an error")
end

eq(xp.text:GetText(), "Level 11" .. DOT .. "34%" .. DOT .. RESTED, "Frames keeps the level caption")
local framesPath, framesSize = xp.text:GetFont()
eq(select(1, xp.text:GetPoint(1)), "TOP", "Frames centres the caption under the bar")
eq(shownTicks(rep), 0, "the Frames reputation bar has no ticks")
eq(rep.edge:IsShown(), false, "the Frames reputation bar has no strip edge")
eq(rep.track.lit:IsShown(), true, "the Frames reputation track keeps its lit edge")
local repPoint = rep.text:GetPoint(1)
xp.holder:SetFrameStrata("HIGH")

K.Options.Write("HudStyle", "style", "medallions")
eq(K.HudStyle.Current(), "medallions", "the style switched")
W.Settle(env)

eq(xp.fill:GetValue(), 3400, "the strip fills with the earned share, 34%")
eq(xp.track:GetValue(), 4800, "and the rested share runs on to 48%")
local r, g, b = K.Tokens.Color("hudRested")
local rested = K.Options.Read("DataBars", "xp.restedColor")
assert(rested.r == r and rested.g == g and rested.b == b and rested.a == 0.55, "the rested segment is the blue shade")
local pr, pg, pb = K.Tokens.Color("epic")
local call = W.LastCall(xp.fill, "SetStatusBarColor")
assert(call and call[1] == pr and call[2] == pg and call[3] == pb, "the XP fill is the flat purple")
eq(xp.fill.texturePath, flat, "a flat fill")
eq(xp.track.texturePath, flat, "and a flat rested segment")
eq(xp.track.backgroundName, "track", "on the dark track")
eq(xp.edge:IsShown(), true, "with the one-pixel black edge")
local last = W.LastCall(xp.edge, "SetColorTexture")
assert(last and last[1] == 0 and last[2] == 0 and last[3] == 0 and last[4] == 1, "solid black")
eq(xp.track.barEdge.hard:IsShown(), false, "and no second frame")

eq(shownTicks(xp), 9, "ticks every ten percent")
local border = K.Widgets.Border(xp.holder)
local w = xp.holder:GetWidth()
for i = 1, 9 do
	local tick = xp.ticks[i]
	local _, _, _, x = tick:GetPoint(1)
	eq(x, K.Widgets.Snap(xp.holder, w * i / 10), "tick " .. i .. " stands on the pixel grid at " .. i * 10 .. " percent")
	eq(tick:GetWidth(), border, "tick " .. i .. " is one pixel wide")
	local tr, tg, tb = K.Tokens.Color("edgeOuter")
	assert(W.SameRGB(tick, tr, tg, tb), "tick " .. i .. " is dark")
end
eq(xp.ticks[1]:GetParent(), xp.overlay, "the ticks lie over the fill")

eq(xp.text:GetText(), "34%" .. DOT .. RESTED, "the caption is the percent and the rested share")
local point, relative, relPoint, x, y = xp.text:GetPoint(1)
eq(point, "TOPRIGHT", "the caption hangs from its right edge")
eq(relative, xp.holder, "on the strip")
eq(relPoint, "BOTTOMRIGHT", "under its right end")
eq(x, 0, "flush right")
eq(y, -K.Widgets.Snap(xp.holder, 3), "three units under the strip")
local path, size, flags = xp.text:GetFont()
eq(path, (K.Tokens.Font("caps")), "in the instrument caps face")
local ref = K.Widgets.FontString(K.Scale.Root(), "OVERLAY")
K.Widgets.ApplyFont(ref, path, 11 * K.Theme.FontScale(), flags)
eq(size, select(2, ref:GetFont()), "small, eleven units through the font setter")
K.Options.Write("DataBars", "xp.instrumentText", false)
eq(xp.text:GetFont(), (K.Tokens.Font("prose")), "off restores the original prose face")
K.Options.Write("DataBars", "xp.instrumentText", true)
eq(xp.text:IsShown(), true, "shown")

eq(rep.fill.texturePath, flat, "the reputation strip is flat too")
eq(rep.edge:IsShown(), true, "with the black edge")
eq(rep.fill.innerEdgeOn, true, "and the fill's inner edge")
eq(shownTicks(rep), 9, "ticked every ten percent")
eq(rep.track.lit:IsShown(), false, "with no lit edge")
local fr, fg, fb = K.Theme.ReactionColor(5)
call = W.LastCall(rep.fill, "SetStatusBarColor")
assert(call and call[1] == fr and call[2] == fg and call[3] == fb, "in its standing colour")
eq(rep.text:GetText(), "Stormwind 25%", "the reputation caption keeps its text")
eq(select(1, rep.text:GetPoint(1)), "TOPRIGHT", "under the strip, right-aligned")
eq(select(1, ns.Bars.views.honor.text:GetPoint(1)), "CENTER", "the honour bar is not part of the Medallions strips")

game.xp, game.rested = 5000, 0
env.FireEvent("PLAYER_XP_UPDATE")
env.FireEvent("UPDATE_EXHAUSTION")
eq(xp.text:GetText(), "50%", "with no rested share the caption is the percent alone")
game.xp, game.rested = 3400, 1400
env.FireEvent("PLAYER_XP_UPDATE")
env.FireEvent("UPDATE_EXHAUSTION")

K.Options.Write("DataBars", "xp.text", "none")
eq(xp.text:IsShown(), false, "a player who turned the caption off still sees none")
K.Options.Write("DataBars", "xp.text", "levelRested")
noErrors("medallions strips")
eq(xp.holder:GetFrameStrata(), "LOW", "under Medallions the experience strip sits at the slab's strata, under the hub")

K.Options.Write("HudStyle", "style", "frames")
eq(xp.text:GetText(), "Level 11" .. DOT .. "34%" .. DOT .. RESTED, "Frames gets the level caption back")
eq(select(1, xp.text:GetPoint(1)), "TOP", "centred under the bar again")
local backPath, backSize = xp.text:GetFont()
eq(backPath, framesPath, "the face is back")
eq(backSize, framesSize, "and the size")
eq(shownTicks(xp), 9, "the XP bar keeps its own ten segments")
eq(shownTicks(rep), 0, "the reputation bar has no ticks again")
eq(rep.edge:IsShown(), false, "no strip edge")
eq(rep.fill.innerEdgeOn, false, "no inner edge")
eq(rep.track.lit:IsShown(), true, "and its lit edge is back")
eq(select(1, rep.text:GetPoint(1)), repPoint, "the reputation caption is where it was")
eq(rep.fill.texturePath, K.Options.Read("DataBars", "rep.texture"), "with the texture its settings name")
eq(xp.holder:GetFrameStrata(), "HIGH", "back in Frames the experience strip gets the strata it had before Medallions")

K.Options.Write("HudStyle", "style", "orbs")
eq(select(1, xp.text:GetPoint(1)), "TOP", "Orbs keeps the Frames caption")
eq(shownTicks(rep), 0, "and the Orbs reputation bar has no ticks")
noErrors("switch back")
print("databars xp medallions ok")
