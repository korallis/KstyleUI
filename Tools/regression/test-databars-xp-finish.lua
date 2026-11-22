-- test-databars-xp-finish.lua: the Medallions experience strip uses flat paint, square ends, ten segments and a caption under its right end whatever the player's texture and segment choices, without changing other bars.
local D = dofile("Tools/regression/databars_env.lua")
local env, K, ns = D.New({ game = { level = 11, xp = 0, xpMax = 10000, rested = 500 } })
local xp, rep, honor = ns.Bars.views.xp, ns.Bars.views.rep, ns.Bars.views.honor
local function eq(got, want, what)
	assert(got == want, what .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end
local paths = {}
for _, item in ipairs(K.Tokens.MediaList("statusbar")) do
	paths[item.key] = item.path
end
eq(xp.fill.texturePath, paths.Flat, "default XP fill texture")
eq(xp.track.texturePath, paths.Flat, "default rested texture")
eq(xp.fill.innerEdgeOn, true, "the flat XP fill keeps a dark inner edge")
eq(xp.fill.innerEdgeToken, "barEdge", "the XP edge is the bar-edge token")
for _, view in ipairs({ rep, honor }) do
	eq(view.fill.texturePath, paths.Flat, "other fill texture follows the shared default")
	eq(view.track.texturePath, paths.Flat, "other track texture follows the shared default")
end
local _, _, _, _, y = xp.text:GetPoint(1)
eq(y, -K.Widgets.Snap(xp.holder, 3), "the Medallions caption hangs three units under the line")
eq(xp.text:GetText(), "0% \194\183 rested 5%", "the Medallions caption reads the percent and the rested share")
eq(xp.fill.caps, nil, "square fill: the bible's bars have no end caps")
eq(xp.track.caps, nil, "square track")
local ticks = 0
for _, tick in ipairs(xp.ticks) do
	ticks = ticks + (tick:IsShown() and 1 or 0)
end
eq(ticks, 9, "the mock-up's ten segments")
for _, choice in ipairs({ "Glass", paths.Glass, paths.Soft }) do
	K.Options.Write("DataBars", "xp.texture", choice)
	local want = choice == "Glass" and paths.Glass or choice
	eq(xp.fill.texturePath, want, "the strip takes its texture setting")
	eq(xp.track.texturePath, want, "and so does its rested reach")
	eq(xp.fill.innerEdgeOn, want == paths.Flat, "with its dark inner edge only on the flat fill")
end
K.Options.Write("DataBars", "xp.texture", paths.Flat)
K.Options.Write("DataBars", "xp.segments", 4)
ticks = 0
for _, tick in ipairs(xp.ticks) do
	ticks = ticks + (tick:IsShown() and 1 or 0)
end
eq(ticks, 3, "the segments setting applies: four segments, three ticks")
eq(#env._errors, 0, "no game errors")
local screens = { {1280, 720}, {1366, 768}, {1920, 1080}, {2560, 1440}, {3440, 1440}, {5120, 1440}, {3840, 2160}, {2383, 1540}, {3456, 2234} }
for _, screen in ipairs(screens) do
	local e, SK, sns = D.New({ width = screen[1], height = screen[2], size = "default", fit = true })
	local view = sns.Bars.views.xp
	local pixel = SK.Scale.Pixel(1) / SK.Widgets.ScaleFactor(view.holder)
	local function snapped(value)
		local count = value / pixel
		assert(math.abs(count - math.floor(count + 0.5)) < 0.00001, "XP paint and caption offsets land on physical pixels")
	end
	local width, height = view.fill:GetSize()
	snapped(width)
	snapped(height)
	local _, _, _, x, captionY = view.text:GetPoint(1)
	snapped(x)
	snapped(captionY)
	assert(#e._errors == 0 and SK.ErrorCount() == 0, "the nine-screen XP matrix has no errors")
end
print("databars XP finish ok")
