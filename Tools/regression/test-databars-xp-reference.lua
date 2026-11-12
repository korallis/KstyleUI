-- test-databars-xp-reference.lua: the overhaul's experience strip (KSTY-44: 5 units, square ends, ten segments, a 55% rested shade, the caption on the world) over an unframed dark trough with a level caption below it, without removing player choices.
local D = dofile("Tools/regression/databars_env.lua")
local W = D.W

local function eq(got, want, what)
	assert(got == want, what .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end

local env, K, ns, game = D.New({ game = { level = 11, xp = 0, xpMax = 10000, rested = 500 } })
local xp = ns.Bars.views.xp
eq(xp.holder:GetWidth(), 491, "the XP line spans the reference's centre column")
eq(xp.holder:GetHeight(), 5, "the experience strip is five root units thick")
eq(xp.fill.pillOn, false, "the fill has square ends: the bible's bars have no caps")
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
eq(xp.fill:GetHeight(), xp.holder:GetHeight(), "the fill inherits the layout height")
eq(#env._errors, 0, "no game errors")
eq(K.ErrorCount(), 0, "no caught errors")

print("databars XP reference ok")
