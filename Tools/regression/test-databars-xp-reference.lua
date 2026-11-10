-- test-databars-xp-reference.lua: the reference XP line has rounded fill and track, an unframed dark trough and a level caption below it, without removing player choices.
local D = dofile("Tools/regression/databars_env.lua")
local W = D.W

local function eq(got, want, what)
	assert(got == want, what .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end

local env, K, ns, game = D.New({ game = { level = 11, xp = 0, xpMax = 10000, rested = 500 } })
local xp = ns.Bars.views.xp
eq(xp.holder:GetWidth(), 491, "the XP line spans the reference's centre column")
eq(xp.holder:GetHeight(), 8, "the XP line is eight root units thick")
assert(xp.fill.caps and xp.track.caps, "both the earned fill and the rested track have rounded ends")
eq(xp.fill.pillOn, true, "the fill uses the kit's pill masks")
eq(xp.track.pillOn, true, "the rested reach uses the kit's pill masks")
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
eq(rested.a, 1, "the reference blue is not dimmed by a second alpha")
eq(xp.text:GetText(), "Level 11 \194\183 0% \194\183 rested 5%", "the reference caption restores the level under LEE-20")
local point, relative, relativePoint, x, y = xp.text:GetPoint(1)
eq(point, "TOP", "the caption starts below the bar")
eq(relative, xp.holder, "the holder owns the caption")
eq(relativePoint, "BOTTOM", "the caption follows the bottom edge")
eq(x, 0, "the caption is centred")
eq(y, -K.Widgets.Snap(xp.holder, 6), "the caption clears the bar by six root units")
for _, tick in ipairs(xp.ticks) do
	eq(tick:IsShown(), false, "the default XP line has no ticks")
end
local path, size, flags = xp.text:GetFont()
eq(path, (K.Tokens.Font("body")), "the caption uses the interface body face")
eq(size, 12 * K.Theme.FontScale(), "the caption stays at body size")
eq(flags, "", "the caption has no outline")

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
eq(xp.fill:GetReverseFill(), true, "the rounded fill can reverse")
K.Options.Write("DataBars", "xp.orientation", "VERTICAL")
eq(xp.fill.pillOn, false, "an upright fill uses the kit's vertical fallback")
K.Options.Write("DataBars", "xp.orientation", "HORIZONTAL")
eq(xp.fill.pillOn, true, "returning horizontal restores rounded ends")
eq(xp.fill.sheenTop:IsShown(), false, "changing orientation does not restore the sheen")
K.Layout.Update("databars.xp", { width = 612, height = 12 })
W.Settle(env)
eq(xp.fill:GetHeight(), xp.holder:GetHeight(), "the rounded fill inherits the layout height")
eq(xp.fill.caps[1]:GetWidth(), K.Widgets.Snap(xp.fill, xp.fill:GetHeight()), "the cap radius follows a resize")
eq(#env._errors, 0, "no game errors")
eq(K.ErrorCount(), 0, "no caught errors")

print("databars XP reference ok")
