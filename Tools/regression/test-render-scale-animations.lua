-- test-render-scale-animations.lua: the renderer draws a frame's playing Scale animations over everything under it, about each animation's origin, every started Scale on a frame multiplying the others once and holding its end until its group's pass ends, ancestors' and textures' own Scales composing with them, and a group that does not loop letting go of its Scales when it ends.
-- Intent: the render tool must draw a mid-flight crest rail medal at its real size (the rail's rise is a Scale on a
-- frame), multiplying a frame's started Scales as the crest's chains are written for and as Forever's own relative
-- chains assume. Fixtures are Blizzard's and the addon's own Scale values.
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

-- lands(rect, rest, sx, sy, ox, oy, fix): rect is rest drawn sx times across and sy times down about the point ox, oy
-- of rest (fractions of its size from its left and top edges), checked by its left and top edges as well as its size.
local function lands(rect, rest, sx, sy, ox, oy, fix)
	local px, py = rest[1] + rest[3] * ox, rest[2] + rest[4] * oy
	near(rect[3], rest[3] * sx, fix .. ", by its width")
	near(rect[4], rest[4] * sy, fix .. ", by its height")
	near(rect[1], px + (rest[1] - px) * sx, fix .. ", by its left edge")
	near(rect[2], py + (rest[2] - py) * sy, fix .. ", by its top edge")
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
-- frame 1 to 1.1 and then 1 to 0.9 on top, holding both ends through a 0.6 s end delay, in a loop.
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
local _, restY = centre(rest)
local _, restTextY = centre(restText.rect)
pulse:Play()
local k = 1 + 0.1 * 0.5 * 0.5
lands(find(art, 10.1).rect, rest, k, k, 0.5, 0.5, "a frame's Scale draws the textures under it")
k = 1 + 0.1 * 0.95 * 0.95
lands(find(art, 10.19).rect, rest, k, k, 0.5, 0.5, "the frame's first Scale nears 1.1 about its centre before the second starts")
local text = find(label, 10.19)
near(text.font.size, restText.font.size, "a frame's Scale leaves the text's own font size")
near(text.zoom and text.zoom[1], 1 + 0.1 * 0.95 * 0.95, "a frame's Scale draws the text under it wider")
near(text.zoom and text.zoom[2], 1 + 0.1 * 0.95 * 0.95, "a frame's Scale draws the text under it taller")
local _, textY = centre(text.rect)
near((textY - restY) / (restTextY - restY), 1 + 0.1 * 0.95 * 0.95, "text set below the frame's centre moves out with the Scale")
near(find(pin, 10.19).rect[1], restPin[1], "a frame anchored to a scaled frame stays where its anchors put it")
-- Drawing only the later Scale would draw these without the 1.1.
k = 1.1 * (1 - 0.1 * (1 - 0.95 * 0.95))
lands(find(art, 10.21).rect, rest, k, k, 0.5, 0.5, "a later Scale multiplies the earlier one's held end")
k = 1.1 * (1 - 0.1 * 0.75)
lands(find(art, 10.3).rect, rest, k, k, 0.5, 0.5, "the later Scale runs on top of the earlier one's end")
lands(find(art, 10.5).rect, rest, 1.1 * 0.9, 1.1 * 0.9, 0.5, 0.5, "both Scales hold their ends through the end delay")
k = 1 + 0.1 * 0.5 * 0.5
lands(find(art, 11.1).rect, rest, k, k, 0.5, 0.5, "a repeating group starts its Scales over each loop")
pulse:Stop()
lands(find(art, 10.1).rect, rest, 1, 1, 0.5, 0.5, "a stopped group no longer scales the frame")

-- As Blizzard writes that pulse, the event frame's group aims both Scales at its IconContainer child (childKey), which
-- a clip plays on the child: each of the two draws on it once, and the event frame itself is not scaled.
local event = box(env.UIParent, 35, 35, 300, 300)
local trail = fill(event)
local container = box(event, 35, 35, 0, 0)
local containerArt = fill(container)
local events = event:CreateAnimationGroup()
events:SetLooping("REPEAT")
scale(events, { 1, 1 }, { 1.1, 1.1 }, 0.2, 1, "IN"):SetTarget(container)
local settle = scale(events, { 1, 1 }, { 0.9, 0.9 }, 0.2, 2, "OUT")
settle:SetEndDelay(0.6)
settle:SetTarget(container)
env._clip = true
local containerRest, trailRest = find(containerArt, 9.9).rect, find(trail, 9.9).rect
events:Play()
k = 1.1 * (1 - 0.1 * 0.75)
lands(find(containerArt, 10.3).rect, containerRest, k, k, 0.5, 0.5, "a clip draws each Scale its group aims at a frame once")
lands(find(containerArt, 10.5).rect, containerRest, 1.1 * 0.9, 1.1 * 0.9, 0.5, 0.5, "a clip holds each aimed Scale's end once")
lands(find(trail, 10.5).rect, trailRest, 1, 1, 0.5, 0.5, "Scales aimed at a child leave their group's owner")
events:Stop()
env._clip = nil

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
lands(find(background, 10.1).rect, closed, 1, 1, 0.5, 0, "a Scale still in its start delay does not draw its from value")
lands(find(background, 10.13333 + 0.43333 / 2).rect, closed, 1, 0.25, 0.5, 0, "the toast is a quarter open about its top halfway through an IN Scale")

-- The quest tracker's glow (Blizzard_ObjectiveTracker/Blizzard_ObjectiveTrackerAnimTemplates.xml:41-43) opens across
-- from nothing about its left edge after a 0.1 s start delay; here the Scale is on a frame. It starts at 10 + 0.1,
-- which is the clock's 10.1, though 10.1 - 10 falls short of 0.1.
local strip = box(env.UIParent, 120, 20, 0, -400)
local glow = fill(strip)
local shine = strip:CreateAnimationGroup()
local wipe = scale(shine, { 0, 1 }, { 1, 1 }, 0.66, 1, "OUT")
wipe:SetStartDelay(0.1)
wipe:SetOrigin("LEFT", 0, 0)
local unlit = find(glow, 9.9).rect
shine:Play()
lands(find(glow, 10.0999).rect, unlit, 1, 1, 0, 0.5, "a Scale in its start delay leaves the frame")
lands(find(glow, 10.1).rect, unlit, 0, 1, 0, 0.5, "a delayed Scale draws its from value at its start on the clock")
lands(find(glow, 10.1 + 0.33).rect, unlit, 0.75, 1, 0, 0.5, "the glow is three quarters across about its left halfway through an OUT Scale")

-- The toast's unfold about its top and the glow's wipe about its left, in two groups on one frame: each Scale draws
-- about its own origin, so the top edge and the left edge both stay still while the frame opens down and across. One
-- pivot for both would move one of those edges.
local banner = box(env.UIParent, 160, 40, -300, 300)
local bannerArt = fill(banner)
local down, widen = banner:CreateAnimationGroup(), banner:CreateAnimationGroup()
local drop = scale(down, { 1, 0 }, { 1, 1 }, 0.43333, 1, "IN")
drop:SetStartDelay(0.13333)
drop:SetOrigin("TOP", 0, 0)
local sweep = scale(widen, { 0, 1 }, { 1, 1 }, 0.66, 1, "OUT")
sweep:SetStartDelay(0.1)
sweep:SetOrigin("LEFT", 0, 0)
local furled = find(bannerArt, 9.9).rect
down:Play()
widen:Play()
local opened = ((10.43 - 10.13333) / 0.43333) ^ 2
lands(find(bannerArt, 10.43).rect, furled, 0.75, opened, 0, 0, "two Scales about different origins each keep their own edge still")
down:Stop()
widen:Stop()

-- The soulbind node's pickup arrows (Blizzard_Soulbinds/Blizzard_SoulbindsNode.xml:186-190) shrink 1.5 to 1 in 0.3 s
-- in a loop whose fades last 1.2 s; here the Scale is on a frame and an end delay stands in for the fades. Its second
-- pass starts at 10 + 1.2, which is the clock's 11.2, though 11.2 - 10 falls short of 1.2.
local arrows = box(env.UIParent, 50, 50, 0, 400)
local arrowArt = fill(arrows)
local pickup = arrows:CreateAnimationGroup()
pickup:SetLooping("REPEAT")
scale(pickup, { 1.5, 1.5 }, { 1, 1 }, 0.3, 1):SetEndDelay(0.9)
local arrowRest = find(arrowArt, 9.9).rect
pickup:Play()
lands(find(arrowArt, 10.15).rect, arrowRest, 1.25, 1.25, 0.5, 0.5, "a repeating frame Scale runs in its first pass")
lands(find(arrowArt, 11.1).rect, arrowRest, 1, 1, 0.5, 0.5, "a repeating frame Scale holds its end until its pass ends")
lands(find(arrowArt, 11.2).rect, arrowRest, 1.5, 1.5, 0.5, 0.5, "a repeating frame Scale starts its next pass at the clock's pass boundary")
lands(find(arrowArt, 11.35).rect, arrowRest, 1.25, 1.25, 0.5, 0.5, "a repeating frame Scale runs from its clock start in a later pass")
pickup:Stop()

-- Two groups on one frame, the second created played first: every started Scale multiplies, whichever group holds it.
-- The shrink's passes end at 10 + 0.2 and 10.5 + 0.2, which are the clock's 10.2 and 10.7, though each clock time less
-- its play time falls short of 0.2; clip.lua ends them there.
local medal = box(env.UIParent, 30, 30, -300, 0)
local face = fill(medal)
local swell, shrink = medal:CreateAnimationGroup(), medal:CreateAnimationGroup()
scale(swell, { 1, 1 }, { 2, 2 }, 1, 1)
scale(shrink, { 1, 1 }, { 0.5, 0.5 }, 0.2, 1)
local plain = find(face, 9.9).rect
shrink:Play()
lands(find(face, 10.1).rect, plain, 1 - 0.5 * 0.5, 1 - 0.5 * 0.5, 0.5, 0.5, "the one playing group draws")
lands(find(face, 10.199).rect, plain, 1 - 0.5 * 0.995, 1 - 0.5 * 0.995, 0.5, 0.5, "a Scale runs until its group's pass ends")
lands(find(face, 10.2).rect, plain, 1, 1, 0.5, 0.5, "a group that does not loop scales nothing from its pass's end on the clock")
env._now = 10.3
shrink:Stop()
shrink:Play()
env._now = 10.4
swell:Play()
k = (1 + 0.05) * (1 - 0.5 * 0.75)
lands(find(face, 10.45).rect, plain, k, k, 0.5, 0.5, "Scales in two playing groups multiply")
env._now = 10.5
shrink:Stop()
shrink:Play()
k = (1 - 0.5 * 0.5) * (1 + 0.2)
lands(find(face, 10.6).rect, plain, k, k, 0.5, 0.5, "a group played again multiplies the other group's Scale")
lands(find(face, 10.7).rect, plain, 1.3, 1.3, 0.5, 0.5, "a group still playing draws alone once the other's pass ends")
env._now = 10

-- The rail seat's press (KstyleUI_ActionBars/SlabRail.lua, Slab.Ease's smoothing) dips the seat frame 1 to 0.86 and,
-- written for multiplying, 1 to 1 / 0.86 on top, while the burst texture under it grows 0.85 to 1.45 on its own.
local seat = box(env.UIParent, 28, 28, 0, -200)
local layer = env.CreateFrame("Frame", nil, seat)
layer:SetAllPoints(seat)
local burst = layer:CreateTexture(nil, "OVERLAY")
burst:SetSize(35, 35)
burst:SetPoint("CENTER", seat, "CENTER", 0, 0)
burst:SetColorTexture(1, 1, 1, 1)
local dip = seat:CreateAnimationGroup()
scale(dip, { 1, 1 }, { 0.86, 0.86 }, 0.12, 1, "IN")
scale(dip, { 1, 1 }, { 1 / 0.86, 1 / 0.86 }, 0.12, 2, "OUT")
local bursting = burst:CreateAnimationGroup()
scale(bursting, { 0.85, 0.85 }, { 1.45, 1.45 }, 0.4, 1, "OUT")
local calm = find(burst, 9.9).rect
dip:Play()
bursting:Play()
k = (1 - 0.14 * 0.25) * (0.85 + 0.6 * (1 - 0.85 * 0.85))
lands(find(burst, 10.06).rect, calm, k, k, 0.5, 0.5, "a texture's own Scale composes with its ancestor frame's")
k = 0.86 * (1 + (1 / 0.86 - 1) * 0.75) * (0.85 + 0.6 * (1 - 0.55 * 0.55))
lands(find(burst, 10.18).rect, calm, k, k, 0.5, 0.5, "the dip's second Scale multiplies its first under the burst")
k = 0.85 + 0.6 * (1 - 0.25 * 0.25)
lands(find(burst, 10.3).rect, calm, k, k, 0.5, 0.5, "an ended dip leaves the burst at its own Scale")

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
lands(flipping.rect, still.rect, across, 1, 0.5, 0.5, "the level text's box narrows about its centre with the flip")
near(flipping.font.size, still.font.size, "the level text keeps its font size through the flip")
local need = Scene.TextWidth("60", flipping.font.size, flipping.font.path)
assert(need <= still.rect[3] and need > 2 * flipping.rect[3], "the fixture's text fits its box at rest and not twice over at the flip's width")
for _, finding in ipairs(Guard.Check(scene)) do
	assert(not (finding.kind == "ellipsis" and finding.object == level), "the guard measures a flipping text at its unscaled width: " .. tostring(finding.detail))
end
near(Guard.Ink(flipping)[3] / Guard.Ink(still)[3], across, "the guard draws a flipping text's ink through the flip")

print("ok render scale animations: frame Scales draw their children about their own origins, every started one multiplies the others once until its group's pass ends, and they end with their groups")
