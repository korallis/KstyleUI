-- test-cooldowns-bars.lua: a tracked buff bar on the mirror path is a glass tile, 195 by 24, with a dark icon tile at its left, the name 10 units in, the countdown right-aligned 10 units from the right end, a subtle fill over the glass, and the first bar at the top.
local C = dofile("Tools/regression/cooldowns_env.lua")
local W = C.W

local FILL_ALPHA = 0.15
local TEXT_INSET = 10

local function LastArg(frame, method, n)
	local call = W.LastCall(frame, method)
	return call and call[n or 1]
end

-- Point(object, point) -> the arguments of the last SetPoint call that placed the given point.
local function Point(object, point)
	local calls = W.Calls(object, "SetPoint")
	for i = #calls, 1, -1 do
		if calls[i][1] == point then
			return calls[i]
		end
	end
end

local env, K, ns = C.New({ setup = C.Game })
local cdm = env._cdm
cdm.auras[4001] = { auraInstanceID = 81 }
cdm.auras[4002] = { auraInstanceID = 82 }
K.Options.Write("Cooldowns", "path", "mirror")
C.Enable(env, K)
env.FireEvent("UNIT_AURA", "player", { isFullUpdate = true })
env.RunTimers()

local row = ns.Mirror.Row("bars")
assert(row.count == 2, "two active bars show, got " .. tostring(row.count))
local holder = row.holder
local width, height = holder:GetSize()
assert(width == 195 and height == 43, "two bars of 195 by 20 fill a 195 by 43 footprint, the mockup's two bars at the owner's in-game scale, got " .. tostring(width) .. " by " .. tostring(height))

-- The countdown reads "24s", as the mockup writes it, through the same one-letter formatter as the cooldown rows.
do
	local formatter = W.LastCall(row.bars[1].timer, "SetCountdownFormatter")
	assert(formatter and type(formatter[1]) == "table" and formatter[1]:Format(24) == "24s", "a bar's countdown has the one-letter formatter")
end

-- The first bar sits at the top of the holder and the second below it: the mockup lists Battle Shout above Enrage.
local first, second = row.bars[1], row.bars[2]
assert(ns.Settings.current.bars.growth == "down", "bars grow downward by default")
assert(LastArg(first, "SetPoint", 5) == 0, "the first bar sits at the top of the holder")
assert(LastArg(second, "SetPoint", 5) == -K.Widgets.Snap(holder, 23), "the second bar sits one 20-unit bar and one 3-unit gap below")

-- The bar is a glass tile with no accent edge; the icon sits on its own dark button tile, inset inside it.
assert(first.chrome.fillName == "surface", "a bar is a glass tile, got " .. tostring(first.chrome.fillName))
local er, eg, eb, ea = K.Widgets.Rgba("edgeBar")
assert(W.Near(first.chrome.edge[1], er) and W.Near(first.chrome.edge[2], eg) and W.Near(first.chrome.edge[3], eb) and W.Near(first.chrome.edge[4], ea), "the bar wears the mockup's faint bar edge")
local tile = first.iconTile
assert(tile and tile.chrome.fillName == "buttonFill", "the icon sits on a dark button tile")
local tw, th = tile:GetSize()
assert(tw == 20 and th == 20, "the icon tile is a square as tall as the 20-unit bar, got " .. tostring(tw) .. " by " .. tostring(th))
local iconPoint = Point(first.icon, "TOPLEFT")
assert(iconPoint and iconPoint[2] == tile and iconPoint[4] > 0, "the icon is inset inside its tile")

-- The fill is the bar colour at a low alpha over the glass, with no track of its own.
assert(first.status.background == nil, "the bar has no dark track; the glass shows through")
local r, g, b = K.Theme.ClassColor(K.Theme.Class())
local color = W.LastCall(first.status, "SetStatusBarColor")
assert(color and W.Near(color[1], r) and W.Near(color[2], g) and W.Near(color[3], b), "the fill takes the class colour")
assert(W.Near(color[4], FILL_ALPHA), "the fill is subtle: alpha " .. tostring(color[4]))
local br, bg, bb, ba = ns.Settings.BarColor()
assert(W.Near(br, r) and W.Near(bg, g) and W.Near(bb, b) and W.Near(ba, FILL_ALPHA), "Settings.BarColor carries the fill alpha for the reskin too")

-- The countdown is right-aligned at the bar's right end; the name runs from the icon tile to the countdown.
local inset = K.Widgets.Snap(holder, TEXT_INSET)
local countdown = first.timer:GetCountdownFontString()
assert(countdown, "the stub's Cooldown gives its countdown font string")
local timerPoint = Point(countdown, "RIGHT")
assert(timerPoint and timerPoint[2] == first and timerPoint[3] == "RIGHT" and timerPoint[4] == -inset, "the countdown is anchored to the bar's right end, 10 units in")
assert(LastArg(countdown, "SetJustifyH") == "RIGHT", "the countdown is right-aligned")
assert(LastArg(countdown, "SetFont", 2) == ns.Settings.current.bars.timerSize, "the countdown takes the timer size")
assert(LastArg(first.timer, "SetAllPoints") == first.status, "the timer frame covers the status bar")
local nameLeft = Point(first.name, "LEFT")
assert(nameLeft and nameLeft[2] == tile and nameLeft[3] == "RIGHT" and nameLeft[4] == inset, "the name starts 10 units right of the icon tile")
local nameRight = Point(first.name, "RIGHT")
assert(nameRight and nameRight[2] == countdown and nameRight[3] == "LEFT" and nameRight[4] == -inset, "the name ends before the countdown")

-- Without the icon, the name starts at the bar's left end.
K.Options.Write("Cooldowns", "bars.icon", false)
assert(not tile:IsShown(), "the icon tile hides with the icon")
nameLeft = Point(first.name, "LEFT")
assert(nameLeft and nameLeft[2] == first and nameLeft[3] == "LEFT" and nameLeft[4] == inset, "without the icon the name starts at the bar's left end")
K.Options.Write("Cooldowns", "bars.icon", true)
assert(tile:IsShown(), "the icon tile shows again")

print("cooldowns bars ok")
