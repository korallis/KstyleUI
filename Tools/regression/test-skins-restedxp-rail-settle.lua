-- test-skins-restedxp-rail-settle.lua: the RestedXP rail's unchanged-key return places exactly as a full placement would and the docked boxes settle to one width and place, at 1920x1080, 2560x1440, 5120x1440 and 3840x2160: the guide window, the docked Targets and Items boxes and the folded steps match a twin that places in full every time; an anchor RestedXP changes on the guide or a docked box, and a folded step RestedXP shows again, are put back by the next placement.
local Boot = dofile("Tools/regression/questcard_guide_env.lua")
local S = dofile("Tools/regression/skins_env.lua")
local Fake = dofile("Tools/regression/restedxp_fake.lua")

local SCREENS = { { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }

-- Full(ns) makes every placement skip the unchanged-key return, as staging did before it.
local function Full(ns)
	local place = ns.RestedXP.Rail.Place
	for i = 1, 60 do
		local name, value = debug.getupvalue(place, i)
		if not name then
			break
		end
		if name == "state" then
			ns.RestedXP.Rail.Place = function()
				value.key = nil
				return place()
			end
			return
		end
	end
	error("Rail.Place keeps its state in an upvalue named state")
end

local function Point(region)
	local point, relative, relativePoint, x, y = region:GetPoint(1)
	return string.format("%s %s %s %.4f %.4f %.4f %.4f", tostring(point), tostring(relative and relative:GetName()), tostring(relativePoint), x or 0, y or 0, region:GetWidth() or 0, region:GetHeight() or 0)
end

local function Shape(R)
	local rxp = R.rxp
	return table.concat({ Point(rxp.RXPFrame), Point(rxp.targeting.activeTargetFrame), Point(rxp.activeItemFrame) }, " | ")
end

for _, size in ipairs(SCREENS) do
	local screen = { width = size[1], height = size[2], uiScale = 768 / size[2] }
	local fast, full = Boot(screen), Boot(screen)
	Full(full.ns)
	for i = 1, 3 do
		for _, R in ipairs({ fast, full }) do
			R.ns.RestedXP.Rail.Place()
			R.env.RunTimers()
		end
		assert(Shape(fast) == Shape(full), string.format("%dx%d placement %d: the rail's unchanged-key return must place the guide and dock the boxes exactly as a full placement does\n  return: %s\n  full:   %s", size[1], size[2], i, Shape(fast), Shape(full)))
	end
	local rxp, env = fast.rxp, fast.env
	local settled = Shape(fast)
	rxp:SortTimers()
	env.RunTimers()
	assert(Shape(fast) == settled, string.format("%dx%d: with nothing changed, the next placement moved the docked boxes; the measured glass reach is pixel-snapped, so Dock in Rail.lua keeps a box's width and point when the new one is within a pixel\n  before: %s\n  after:  %s", size[1], size[2], settled, Shape(fast)))
	for _, region in ipairs({ rxp.RXPFrame, rxp.activeItemFrame }) do
		local point, relative, relativePoint, x, y = region:GetPoint(1)
		region:ClearAllPoints()
		region:SetPoint(point == "TOPLEFT" and "BOTTOM" or "TOPLEFT", relative, relativePoint, x, y)
		rxp:SortTimers()
		env.RunTimers()
		assert(region:GetPoint(1) == point, string.format("%dx%d: after RestedXP re-anchors %s, the next placement puts its %s back; the placement key compares the whole anchor", size[1], size[2], region:GetName(), point))
	end
	assert(#env._errors == 0 and fast.K.ErrorCount() == 0, tostring(env._errors[1]))
end

-- A step folded under the more line stays folded when RestedXP shows it again: the key compares each step's alpha.
for _, size in ipairs(SCREENS) do
	local rxp
	local env, K, ns = S.New({ width = size[1], height = size[2], setup = function(e)
		e._size, e._fitScale = "auto", true
		rxp = Fake.Install(e, {})
	end })
	K.Modules.Enable("Skins")
	rxp.SetStep(4, 14)
	env.RunTimers()
	local rail = ns.RestedXP.Rail
	rail.Place()
	rail.Place()
	local folded
	for _, step in ipairs(rxp.RXPFrame.CurrentStepFrame.framePool) do
		if rail.Cut(step) then
			folded = step
			break
		end
	end
	assert(folded, string.format("%dx%d: fourteen steps fold some under the more line", size[1], size[2]))
	folded:SetAlpha(1)
	rxp:SortTimers()
	env.RunTimers()
	assert(folded:GetAlpha() == 0, string.format("%dx%d: a folded step RestedXP shows again is folded again by the next placement", size[1], size[2]))
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

-- With the rail off, a guide whose steps' anchoring is restricted still refits its head.
do
	local R = Boot({ width = 1920, height = 1080, uiScale = 768 / 1080 })
	R.K.Options.Write("Skins", "restedXP.rail", false)
	R.env.RunTimers()
	R.env.RestrictAnchoring(R.rxp.RXPFrame.CurrentStepFrame)
	local ok, err = pcall(R.ns.RestedXP.Chrome.Refit, R.rxp.RXPFrame)
	assert(ok, "a restricted step frame must not stop the head refit; read its edges with Widgets.Edges (KstyleUI_Skins/Addons/RestedXP/Chrome.lua PlaceHead): " .. tostring(err))
end

-- A settled rail with one icon in each docked box scans each box's icons once per placement (review of #773,
-- finding 9): staging at 7b544324 spent 387 widget calls on a steady Rail.Place, the first chip version 401.
do
	local B = dofile("Tools/regression/path_budget.lua")
	local R = Boot({ width = 1920, height = 1080 })
	R.settle()
	B.Check(B.Count(R.env, function() R.ns.RestedXP.Rail.Place() end, 100), math.huge, 387, "Rail.Place: plan each docked chip's width once and keep it in its slot")
end

print("skins restedxp rail settle ok")
