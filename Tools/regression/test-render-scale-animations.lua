-- test-render-scale-animations.lua: the renderer draws a frame's playing Scale animations over everything under it, about each animation's origin, with the latest started Scale on a frame replacing an earlier one, ancestors' and textures' own Scales composing with it, and a group that does not loop letting go of its Scales when it ends.
-- Intent: the render tool must draw a mid-flight crest rail medal at its real size (the rail's rise is a Scale on a
-- frame), with a later-started Scale replacing an earlier one, as the task that asked for it reads Blizzard's
-- templates. Fixtures are Blizzard's and the addon's own Scale values.
local Stubs = dofile("Tools/regression/stubs/wow.lua")
local Scene = dofile("Tools/render/scene.lua")
local Guard = dofile("Tools/render/guard.lua")
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

local function scale(group, from, to, duration, order, smoothing)
	local anim = group:CreateAnimation("Scale")
	anim:SetScaleFrom(from[1], from[2])
	anim:SetScaleTo(to[1], to[2])
	anim:SetDuration(duration)
	anim:SetOrder(order or 1)
	if smoothing then
		anim:SetSmoothing(smoothing)
	end
	return anim
end

local function box(parent, w, h, x, y)
	local frame = env.CreateFrame("Frame", nil, parent)
	frame:SetSize(w, h)
	frame:SetPoint("CENTER", parent, "CENTER", x, y)
	return frame
end

local function fill(frame)
	local texture = frame:CreateTexture(nil, "ARTWORK")
	texture:SetAllPoints(frame)
	texture:SetColorTexture(1, 1, 1, 1)
	return texture
end

env._now = 10

-- The encounter timeline's pulse (Blizzard_EncounterTimeline/EncounterTimelineTrackEvent.xml:50-53) scales the icon
-- frame 1 to 1.1 and then 1 to 0.9, holding the second's end through a 0.6 s end delay, in a loop.
local icon = box(env.UIParent, 40, 40, 0, 0)
local art = fill(icon)
local label = icon:CreateFontString(nil, "OVERLAY")
label:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
label:SetPoint("CENTER", icon, "CENTER", 0, -10)
label:SetText("5")
local neighbour = env.CreateFrame("Frame", nil, env.UIParent)
neighbour:SetSize(10, 10)
neighbour:SetPoint("LEFT", icon, "RIGHT", 4, 0)
local pin = fill(neighbour)
local pulse = icon:CreateAnimationGroup()
pulse:SetLooping("REPEAT")
scale(pulse, { 1, 1 }, { 1.1, 1.1 }, 0.2, 1, "IN")
scale(pulse, { 1, 1 }, { 0.9, 0.9 }, 0.2, 2, "OUT"):SetEndDelay(0.6)

local rest, restText, restPin = find(art, 9.9).rect, find(label, 9.9), find(pin, 9.9).rect
local restX, restY = centre(rest)
local _, restTextY = centre(restText.rect)
pulse:Play()
near(find(art, 10.1).rect[3] / rest[3], 1 + 0.1 * 0.5 * 0.5, "a frame's Scale draws the textures under it")
local grown = find(art, 10.19).rect
near(grown[3] / rest[3], 1 + 0.1 * 0.95 * 0.95, "the frame's first Scale nears 1.1 before the second starts")
near(grown[4] / rest[4], 1 + 0.1 * 0.95 * 0.95, "the frame's Scale grows its texture's height too")
near(select(1, centre(grown)), restX, "a Scale with no origin keeps the frame's centre still")
local text = find(label, 10.19)
near(text.font.size, restText.font.size, "a frame's Scale leaves the text's own font size")
near(text.zoom and text.zoom[1], 1 + 0.1 * 0.95 * 0.95, "a frame's Scale draws the text under it wider")
near(text.zoom and text.zoom[2], 1 + 0.1 * 0.95 * 0.95, "a frame's Scale draws the text under it taller")
local _, textY = centre(text.rect)
near((textY - restY) / (restTextY - restY), 1 + 0.1 * 0.95 * 0.95, "text set below the frame's centre moves out with the Scale")
near(find(pin, 10.19).rect[1], restPin[1], "a frame anchored to a scaled frame stays where its anchors put it")
-- Multiplying the first Scale's end would draw 1.1 times these. The second starts at 10 + 0.2, which is the clock's
-- 10.2, though 10.2 - 10 falls short of 0.2.
near(find(art, 10.2).rect[3], rest[3], "a later Scale draws its from value at its start on the clock")
near(find(art, 10.21).rect[3] / rest[3], 1 - 0.1 * (1 - 0.95 * 0.95), "a later Scale replaces an earlier one from its start")
near(find(art, 10.3).rect[3] / rest[3], 1 - 0.1 * 0.75, "the later Scale runs on its own")
near(find(art, 10.5).rect[3] / rest[3], 0.9, "the later Scale holds its end through the end delay")
near(find(art, 11.1).rect[3] / rest[3], 1 + 0.1 * 0.5 * 0.5, "a repeating group starts its Scales over each loop")
pulse:Stop()
near(find(art, 10.1).rect[3], rest[3], "a stopped group no longer scales the frame")

-- The renown toast (Blizzard_MajorFactions/Blizzard_MajorFactionRenownToast.xml:81-83) opens from no height to full
-- height about its top after a start delay; here the Scale is on the toast frame, over its background.
local toast = box(env.UIParent, 200, 50, 0, 200)
local background = fill(toast)
local open = toast:CreateAnimationGroup()
local unfold = scale(open, { 1, 0 }, { 1, 1 }, 0.43333, 1, "IN")
unfold:SetStartDelay(0.13333)
unfold:SetOrigin("TOP", 0, 0)
local closed = find(background, 9.9).rect
open:Play()
near(find(background, 10.1).rect[4], closed[4], "a Scale still in its start delay does not draw its from value")
local half = find(background, 10.13333 + 0.43333 / 2).rect
near(half[4] / closed[4], 0.25, "the toast is a quarter open halfway through an IN Scale")
near(half[2], closed[2], "a Scale about TOP keeps the top edge still")
near(half[3], closed[3], "a Scale of 1 across leaves the width")

-- Two groups on one frame, the second created played first: the one that started last on the clock draws, not the
-- product and not the first or last in creation order. The shrink's passes end at 10 + 0.2 and 10.5 + 0.2, which are
-- the clock's 10.2 and 10.7, though each clock time less its play time falls short of 0.2; clip.lua ends them there.
local medal = box(env.UIParent, 30, 30, -300, 0)
local face = fill(medal)
local swell, shrink = medal:CreateAnimationGroup(), medal:CreateAnimationGroup()
scale(swell, { 1, 1 }, { 2, 2 }, 1, 1)
scale(shrink, { 1, 1 }, { 0.5, 0.5 }, 0.2, 1)
local plain = find(face, 9.9).rect
shrink:Play()
near(find(face, 10.1).rect[3] / plain[3], 1 - 0.5 * 0.5, "the one playing group draws")
near(find(face, 10.199).rect[3] / plain[3], 1 - 0.5 * 0.995, "a Scale holds its value until its group's pass ends")
near(find(face, 10.2).rect[3], plain[3], "a group that does not loop scales nothing from its pass's end on the clock")
env._now = 10.3
shrink:Stop()
shrink:Play()
env._now = 10.4
swell:Play()
near(find(face, 10.45).rect[3] / plain[3], 1 + 0.05, "a group started later replaces one created after it")
env._now = 10.5
shrink:Stop()
shrink:Play()
near(find(face, 10.6).rect[3] / plain[3], 1 - 0.5 * 0.5, "a group played again replaces one started before it")
near(find(face, 10.7).rect[3] / plain[3], 1 + 0.3, "a group still playing draws again once a later one's pass ends")
env._now = 10

-- The rail seat's press (KstyleUI_ActionBars/SlabRail.lua, Slab.Ease's smoothing) dips the seat frame 1 to 0.86 and
-- back while the burst texture under it grows 0.85 to 1.45 on its own.
local seat = box(env.UIParent, 28, 28, 0, -200)
local layer = env.CreateFrame("Frame", nil, seat)
layer:SetAllPoints(seat)
local burst = layer:CreateTexture(nil, "OVERLAY")
burst:SetSize(35, 35)
burst:SetPoint("CENTER", seat, "CENTER", 0, 0)
burst:SetColorTexture(1, 1, 1, 1)
local dip = seat:CreateAnimationGroup()
scale(dip, { 1, 1 }, { 0.86, 0.86 }, 0.12, 1, "IN")
scale(dip, { 0.86, 0.86 }, { 1, 1 }, 0.12, 2, "OUT")
local bursting = burst:CreateAnimationGroup()
scale(bursting, { 0.85, 0.85 }, { 1.45, 1.45 }, 0.4, 1, "OUT")
local calm = find(burst, 9.9).rect
dip:Play()
bursting:Play()
near(find(burst, 10.06).rect[3] / calm[3], (1 - 0.14 * 0.25) * (0.85 + 0.6 * (1 - 0.85 * 0.85)), "a texture's own Scale composes with its ancestor frame's")
near(find(burst, 10.18).rect[3] / calm[3], (0.86 + 0.14 * 0.75) * (0.85 + 0.6 * (1 - 0.55 * 0.55)), "the dip's second Scale replaces its first under the burst")
near(find(burst, 10.3).rect[3] / calm[3], 0.85 + 0.6 * (1 - 0.25 * 0.25), "an ended dip leaves the burst at its own Scale")

-- The medallion's flip (Core/Widgets/Medallion.lua) opens it across from 0.05 in 0.18 s OUT, so its level text is
-- drawn narrower, not rewrapped or cut at its unscaled font.
local medallion = box(env.UIParent, 60, 60, 300, 0)
local level = medallion:CreateFontString(nil, "OVERLAY")
level:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
level:SetSize(16, 14)
level:SetPoint("CENTER", medallion, "CENTER", 0, 0)
level:SetWordWrap(false)
level:SetText("60")
local flip = medallion:CreateAnimationGroup()
local turn = scale(flip, { 0.05, 1 }, { 1, 1 }, 0.18, 1, "OUT")
turn:SetOrigin("CENTER", 0, 0)
local still = find(level, 9.9)
flip:Play()
local scene = Scene.Build(env, { time = 10.03 })
local flipping
for _, item in ipairs(scene.items) do
	if item.object == level then
		flipping = item
	end
end
local across = 0.05 + 0.95 * (1 - (5 / 6) * (5 / 6))
near(flipping.zoom and flipping.zoom[1], across, "the flip draws the level text narrower")
near(flipping.zoom and flipping.zoom[2], 1, "the flip leaves the level text's height")
near(flipping.rect[3] / still.rect[3], across, "the level text's box narrows with the flip")
near(flipping.font.size, still.font.size, "the level text keeps its font size through the flip")
local need = Scene.TextWidth("60", flipping.font.size, flipping.font.path)
assert(need <= still.rect[3] and need > 2 * flipping.rect[3], "the fixture's text fits its box at rest and not twice over at the flip's width")
for _, finding in ipairs(Guard.Check(scene)) do
	assert(not (finding.kind == "ellipsis" and finding.object == level), "the guard measures a flipping text at its unscaled width: " .. tostring(finding.detail))
end
near(Guard.Ink(flipping)[3] / Guard.Ink(still)[3], across, "the guard draws a flipping text's ink through the flip")

print("ok render scale animations: frame Scales draw their children, the latest started replaces an earlier one about its origin, and they end with their groups")
