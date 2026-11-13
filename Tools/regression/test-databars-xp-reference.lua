-- test-databars-xp-reference.lua: the overhaul's experience strip (KSTY-44: the mock-up's 7 px, square ends, ten segments, a 55% rested shade, the caption on the world) over an unframed dark trough with a level caption below it, without removing player choices.
local D = dofile("Tools/regression/databars_env.lua")
local W = D.W

local function eq(got, want, what)
	assert(got == want, what .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end

local env, K, ns, game = D.New({ game = { level = 11, xp = 0, xpMax = 10000, rested = 500 } })
local xp = ns.Bars.views.xp
eq(xp.holder:GetWidth(), 491, "the XP line spans the reference's centre column")
assert(math.abs(xp.holder:GetHeight() - 7 * 19 / 16) <= K.Widgets.Border(xp.holder) / 2 + 1e-6, "the experience strip is the mock-up's 7 px, 8.3125 units snapped to the pixel, got " .. tostring(xp.holder:GetHeight()))
eq(xp.fill.pillOn, false, "the fill has square ends: the bible's bars have no caps")
-- KSTY-60 item 28, the Captain's ruling: the mock-up's strip is a one-pixel dark edge round the fill.
do
	local edge = K.Widgets.Border(xp.holder)
	assert(xp.edge:IsShown(), "the strip draws its dark edge")
	for _, bar in ipairs({ xp.track, xp.fill }) do
		local p1, rel1, _, x1, y1 = bar:GetPoint(1)
		local p2, rel2, _, x2, y2 = bar:GetPoint(2)
		assert(p1 == "TOPLEFT" and rel1 == xp.content and math.abs(x1 - edge) < 1e-6 and math.abs(y1 + edge) < 1e-6
			and p2 == "BOTTOMRIGHT" and rel2 == xp.content and math.abs(x2 + edge) < 1e-6 and math.abs(y2 - edge) < 1e-6, "the trough and the fill stand one pixel inside it")
	end
	local last = W.LastCall(xp.edge, "SetColorTexture")
	assert(last and last[1] == 0 and last[2] == 0 and last[3] == 0 and last[4] == 1, "the edge is solid black, as the mock-up draws it")
end
eq(xp.track.pillOn, false, "and so does the rested reach")
eq(xp.fill.borderFrame:IsShown(), false, "the earned fill adds no second frame")
eq(xp.track.borderFrame:IsShown(), false, "the reference track is unframed by default")
for _, bar in ipairs({ xp.track, xp.fill }) do
	eq(bar.sheenTop:IsShown(), false, "the flat reference line has no sheen")
	for _, piece in ipairs(bar.glow) do
		eq(piece:IsShown(), false, "the reference line has no glow outside its footprint")
	end
end
eq(xp.track.backgroundName, "track", "the empty trough uses the dark track token")
eq(xp.fill:GetValue(), 0, "the reference has no earned XP")
eq(xp.track:GetValue(), 500, "the blue rested reach is five percent")
local r, g, b = K.Tokens.Color("hudRested")
local rested = K.Options.Read("DataBars", "xp.restedColor")
eq(rested.r, r, "the rested fill uses the reference colour token's red")
eq(rested.g, g, "the rested fill uses the reference colour token's green")
eq(rested.b, b, "the rested fill uses the reference colour token's blue")
eq(rested.a, 0.55, "the rested shade is the mock-up's 55%")
eq(xp.text:GetText(), "Level 11 \194\183 0% \194\183 rested 5%", "the reference caption restores the level under LEE-20")
local point, relative, relativePoint, x, y = xp.text:GetPoint(1)
eq(point, "TOP", "the caption starts below the bar")
eq(relative, xp.holder, "the holder owns the caption")
eq(relativePoint, "BOTTOM", "the caption follows the bottom edge")
eq(x, 0, "the caption is centred")
eq(y, -K.Widgets.Snap(xp.holder, 6) + K.Widgets.Snap(xp.holder, 1.15), "the caption's six-unit gap includes the picture's snapped optical raise")
local ticks = 0
for _, tick in ipairs(xp.ticks) do
	ticks = ticks + (tick:IsShown() and 1 or 0)
end
eq(ticks, 9, "the strip is ticked into ten segments")
local path, size, flags = xp.text:GetFont()
eq(path, (K.Tokens.Font("prose")), "the caption uses the interface prose face: the picture's digits are proportional, and the caption does not tick")
eq(size, 12 * K.Theme.FontScale(), "the caption stays at body size")
eq(flags, "OUTLINE", "the caption stands on the world: an outline, with the kit's shadow")

K.Options.Write("DataBars", "xp.border", true)
eq(xp.track.borderFrame:IsShown(), true, "the existing border setting still works")
eq(xp.fill.borderFrame:IsShown(), false, "a chosen border is drawn only once")
K.Options.Write("DataBars", "xp.text", "percentRested")
eq(xp.text:GetText(), "0% \194\183 rested 5%", "the old caption remains a player choice")
K.Options.Write("DataBars", "xp.text", "levelRested")
game.level, game.xp, game.rested = 12, 2500, 0
env.FireEvent("PLAYER_LEVEL_UP", 12)
eq(xp.text:GetText(), "Level 12 \194\183 25%", "the level caption follows game values without a stale rested share")

K.Options.Write("DataBars", "xp.reverse", true)
eq(xp.fill:GetReverseFill(), true, "the fill can reverse")
K.Options.Write("DataBars", "xp.orientation", "VERTICAL")
eq(xp.fill.pillOn, false, "an upright fill uses the kit's vertical fallback")
K.Options.Write("DataBars", "xp.orientation", "HORIZONTAL")
eq(xp.fill.pillOn, false, "returning horizontal keeps square ends")
eq(xp.fill.sheenTop:IsShown(), false, "changing orientation does not restore the sheen")
K.Layout.Update("databars.xp", { width = 612, height = 12 })
W.Settle(env)
eq(xp.fill:GetHeight(), xp.holder:GetHeight() - 2 * K.Widgets.Border(xp.holder), "the fill inherits the layout height inside its one-pixel edge")
eq(#env._errors, 0, "no game errors")
eq(K.ErrorCount(), 0, "no caught errors")

print("databars XP reference ok")
