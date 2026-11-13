-- test-databars-xp-finish.lua: the overhaul's experience strip uses flat default paint, square ends, ten segments and a raised caption without changing other bars or player choices.
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
	eq(view.fill.texturePath, paths.Glass, "other fill texture")
	eq(view.track.texturePath, paths.Glass, "other track texture")
end
local _, _, _, _, y = xp.text:GetPoint(1)
eq(y, -K.Widgets.Snap(xp.holder, 6) + K.Widgets.Snap(xp.holder, 1.15), "XP caption raise")
eq(xp.text:GetText(), "Level 11 \194\183 0% \194\183 rested 5%", "level caption")
eq(xp.fill.caps, nil, "square fill: the bible's bars have no end caps")
eq(xp.track.caps, nil, "square track")
local ticks = 0
for _, tick in ipairs(xp.ticks) do
	ticks = ticks + (tick:IsShown() and 1 or 0)
end
eq(ticks, 9, "the mock-up's ten segments")
K.Options.Write("DataBars", "xp.texture", paths.Flat)
eq(xp.track.texturePath, paths.Flat, "selected flat texture")
for _, choice in ipairs({ "Glass", paths.Glass }) do
	K.Options.Write("DataBars", "xp.texture", choice)
	eq(xp.fill.texturePath, paths.Glass, "selected Glass fill texture")
	eq(xp.track.texturePath, paths.Glass, "selected Glass rested texture")
	eq(xp.fill.innerEdgeOn, false, "a chosen texture other than Flat draws as it does today")
end
local custom
for _, item in ipairs(K.Tokens.MediaList("statusbar")) do
	if item.key ~= "Flat" and item.key ~= "Glass" then custom = item.path; break end
end
assert(custom, "a custom texture is available")
K.Options.Write("DataBars", "xp.texture", custom)
eq(xp.fill.texturePath, custom, "selected XP fill texture")
eq(xp.track.texturePath, custom, "selected rested texture")
K.Options.Write("DataBars", "xp.segments", 4)
eq(xp.ticks[1]:IsShown(), true, "chosen ticks remain available")
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
