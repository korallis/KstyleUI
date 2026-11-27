-- test-render-scale-animations.lua: the renderer draws a frame's playing Scale animations over everything under it, about each animation's origin, with started Scales multiplying as the client composes them and a group that does not loop letting go of its Scales when it ends.
-- Intent: the render tool must draw a mid-flight crest rail medal at its real size (the rail's rise is a Scale on the
-- seat frame), and the fixtures are Blizzard's own chains from the Forever UI source plus the rail seat's press.
local Stubs = dofile("Tools/regression/stubs/wow.lua")
local Scene = dofile("Tools/render/scene.lua")
local env = Stubs.NewEnv({ width = 1920, height = 1080 })

local function near(actual, expected, fix)
	assert(type(actual) == "number" and math.abs(actual - expected) < 0.001, fix .. ": expected " .. expected .. ", got " .. tostring(actual))
end

local function find(object, time)
	for _, item in ipairs(Scene.Build(env, { time = time }).items) do
		if item.object == object then
			return item
		end
	end
	error("nothing drawn for the object at " .. tostring(time))
end

local function centre(rect)
	return rect[1] + rect[3] / 2, rect[2] + rect[4] / 2
end

local function scale(group, from, to, duration, order)
	local anim = group:CreateAnimation("Scale")
	anim:SetScaleFrom(from[1], from[2])
	anim:SetScaleTo(to[1], to[2])
	anim:SetDuration(duration)
	anim:SetOrder(order or 1)
	return anim
end

env._now = 10

-- The encounter timeline's pulse (Blizzard_EncounterTimeline/EncounterTimelineTrackEvent.xml:50-53) scales the icon
-- frame 1 to 1.1 and then 1 to 0.9 in a loop, so the client multiplies the second onto the first's end.
local icon = env.CreateFrame("Frame", nil, env.UIParent)
icon:SetSize(40, 40)
icon:SetPoint("CENTER", env.UIParent, "CENTER", 0, 0)
local art = icon:CreateTexture(nil, "ARTWORK")
art:SetAllPoints(icon)
art:SetColorTexture(1, 1, 1, 1)
local label = icon:CreateFontString(nil, "OVERLAY")
label:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
label:SetPoint("CENTER", icon, "CENTER", 0, -10)
label:SetText("5")
local neighbour = env.CreateFrame("Frame", nil, env.UIParent)
neighbour:SetSize(10, 10)
neighbour:SetPoint("LEFT", icon, "RIGHT", 4, 0)
local pin = neighbour:CreateTexture(nil, "ARTWORK")
pin:SetAllPoints(neighbour)
pin:SetColorTexture(1, 1, 1, 1)
local pulse = icon:CreateAnimationGroup()
pulse:SetLooping("REPEAT")
scale(pulse, { 1, 1 }, { 1.1, 1.1 }, 0.2, 1):SetSmoothing("IN")
local shrink = scale(pulse, { 1, 1 }, { 0.9, 0.9 }, 0.2, 2)
shrink:SetSmoothing("OUT")
shrink:SetEndDelay(0.6)

local rest, restText, restPin = find(art, 9.9).rect, find(label, 9.9), find(pin, 9.9).rect
local restX, restY = centre(rest)
local _, restTextY = centre(restText.rect)
pulse:Play()
-- IN smoothing at half of 1 to 1.1 is 1 + 0.1 * 0.25.
near(find(art, 10.1).rect[3] / rest[3], 1.025, "a frame's Scale draws the textures under it")
local grown = find(art, 10.2).rect
near(grown[3] / rest[3], 1.1, "the frame's first Scale ends at 1.1")
near(grown[4] / rest[4], 1.1, "the frame's Scale grows its texture's height too")
near(select(1, centre(grown)), restX, "a Scale with no origin keeps the frame's centre still")
local text = find(label, 10.2)
near(text.font.size / restText.font.size, 1.1, "a frame's Scale draws the text under it at the scaled size")
local _, textY = centre(text.rect)
near((textY - restY) / (restTextY - restY), 1.1, "text set below the frame's centre moves out with the Scale")
local still = find(pin, 10.2).rect
near(still[1], restPin[1], "a frame anchored to a scaled frame stays where its anchors put it")
-- OUT smoothing at half of 1 to 0.9 is 1 - 0.1 * 0.75; replacing the first Scale would draw 0.925.
near(find(art, 10.3).rect[3] / rest[3], 1.1 * 0.925, "a later Scale multiplies the end of an earlier one")
near(find(art, 10.5).rect[3] / rest[3], 1.1 * 0.9, "both Scales hold their end through the end delay")
near(find(art, 11.1).rect[3] / rest[3], 1.025, "a repeating group starts its Scales over each loop")
pulse:Stop()

-- The renown toast (Blizzard_MajorFactions/Blizzard_MajorFactionRenownToast.xml:81-83) opens its background from
-- no height to full height about its top, after a start delay.
local toast = env.CreateFrame("Frame", nil, env.UIParent)
toast:SetSize(200, 50)
toast:SetPoint("CENTER", env.UIParent, "CENTER", 0, 200)
local background = toast:CreateTexture(nil, "BACKGROUND")
background:SetAllPoints(toast)
background:SetColorTexture(1, 1, 1, 1)
local open = background:CreateAnimationGroup()
local unfold = scale(open, { 1, 0 }, { 1, 1 }, 0.43333, 1)
unfold:SetStartDelay(0.13333)
unfold:SetSmoothing("IN")
unfold:SetOrigin("TOP", 0, 0)
local closed = find(background, 9.9).rect
open:Play()
local waiting = find(background, 10.1).rect
near(waiting[4], closed[4], "a Scale still in its start delay does not draw its from value")
local half = find(background, 10.13333 + 0.43333 / 2).rect
near(half[4] / closed[4], 0.25, "the toast is a quarter open halfway through an IN Scale")
near(half[2], closed[2], "a Scale about TOP keeps the top edge still")
near(half[3], closed[3], "a Scale of 1 across leaves the width")
near(find(background, 10.6).rect[4], closed[4], "the finished toast draws at full height")

-- The rail seat's press (KstyleUI_ActionBars/SlabRail.lua) dips the seat frame 1 to 0.86 and back while the burst
-- under it grows 0.85 to 1.45, so the burst draws at both Scales.
local seat = env.CreateFrame("Frame", nil, env.UIParent)
seat:SetSize(28, 28)
seat:SetPoint("CENTER", env.UIParent, "CENTER", 0, -200)
local layer = env.CreateFrame("Frame", nil, seat)
layer:SetAllPoints(seat)
local burst = layer:CreateTexture(nil, "OVERLAY")
burst:SetSize(35, 35)
burst:SetPoint("CENTER", seat, "CENTER", 0, 0)
burst:SetColorTexture(1, 1, 1, 1)
local dip = seat:CreateAnimationGroup()
scale(dip, { 1, 1 }, { 0.86, 0.86 }, 0.12, 1)
scale(dip, { 0.86, 0.86 }, { 1, 1 }, 0.12, 2)
local bursting = burst:CreateAnimationGroup()
scale(bursting, { 0.85, 0.85 }, { 1.45, 1.45 }, 0.4, 1)
local calm = find(burst, 9.9).rect
dip:Play()
bursting:Play()
near(find(burst, 10.06).rect[3] / calm[3], 0.94 * 0.93, "a texture's own Scale multiplies its ancestor frame's")
near(find(burst, 10.18).rect[3] / calm[3], 1.12 * 0.86 * 0.93, "the dip's second Scale multiplies the first's end")
near(find(burst, 10.3).rect[3] / calm[3], 1.3, "an ended group that does not loop no longer scales what it drew")
near(find(burst, 10.5).rect[3] / calm[3], 1, "the burst draws at its own size once its group ends")

print("ok render scale animations: frame Scales draw their children, multiply about their origins and end with their groups")
