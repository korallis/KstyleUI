-- test-actionbars-medallions-slab.lua: the Medallions action slab is one connected piece at every CREW screen (LEE-1543): bars 1 and 2 stand in one row each, bar 1's twelve slots left of the crest hub and bar 2's twelve right of it, and the slab, the hub, both wings and the experience strip along the slab's lower edge touch or overlap with no gap between their rects, at rest and with the wings out in combat, the slab's edges and the wings' seat on whole physical pixels.
local AB = dofile("Tools/regression/actionbars_env.lua")

local SCREENS = {
	{ 1280, 720 }, { 1920, 1080 }, { 2383, 1540 }, { 3456, 2234 }, { 2560, 1080 }, { 2560, 1440 }, { 3440, 1440 },
	{ 3840, 1080 }, { 3840, 2160 }, { 5120, 1440 },
}
local EPS = 1e-6

local function Rect(region)
	local s = region.GetEffectiveScale and region:GetEffectiveScale() or region:GetParent():GetEffectiveScale()
	return { region:GetLeft() * s, region:GetBottom() * s, region:GetRight() * s, region:GetTop() * s }
end

-- Gap(a, b) -> how far apart two rects stand: 0 when they touch or overlap, else the larger of the two axis gaps.
local function Gap(a, b)
	return math.max(0, a[1] - b[3], b[1] - a[3], a[2] - b[4], b[2] - a[4])
end

local function Whole(v, height)
	local px = v * height / 768
	return math.abs(px - math.floor(px + 0.5)) < 1e-4
end

local checked = 0
for _, screen in ipairs(SCREENS) do
	local width, height = screen[1], screen[2]
	local what = width .. "x" .. height
	local env, K, ns = AB.New({ width = width, height = height, class = "WARLOCK" })
	AB.Enable(env, K)
	local strip = env.CreateFrame("Frame", nil, K.Scale.Root())
	K.Layout.Register(strip, "databars.xp", K.Setup.Layouts.Default("databars.xp"), { label = "Experience", module = "DataBars", resizable = true })
	K.Options.Write("HudStyle", "style", "medallions")
	env.RunTimers()
	local Slab = ns.Slab
	local slab, hub = Slab.frame, Slab.hub
	assert(slab and slab:IsShown() and hub:IsShown(), what .. ": the slab and the hub are shown under Medallions")

	local bar1, bar2 = ns.bars.bar1, ns.bars.bar2
	local hubRect = Rect(hub)
	local centre = (hubRect[1] + hubRect[3]) / 2
	for _, bar in ipairs({ bar1, bar2 }) do
		local bottom = bar.buttons[1]:GetBottom()
		for i = 1, 12 do
			local b = bar.buttons[i]
			assert(b:IsShown(), what .. ": " .. bar.def.key .. " shows all twelve slots")
			assert(math.abs(b:GetBottom() - bottom) < EPS, what .. ": " .. bar.def.key .. " stands in one row, slot " .. i .. " is off its baseline")
			local r = Rect(b)
			if bar == bar1 then
				assert(r[3] <= hubRect[1] + EPS, what .. ": bar 1's slot " .. i .. " stands left of the hub")
			else
				assert(r[1] >= hubRect[3] - EPS, what .. ": bar 2's slot " .. i .. " stands right of the hub")
			end
		end
	end
	assert(math.abs(bar1.buttons[1]:GetBottom() - bar2.buttons[1]:GetBottom()) < EPS, what .. ": both groups share one baseline")

	for _, combat in ipairs({ false, true }) do
		local state = combat and "in combat" or "at rest"
		Slab.SetCombat(combat)
		hub.wings[1].anim:GetScript("OnFinished")(hub.wings[1].anim)
		local slabRect, xp = Rect(slab), Rect(strip)
		local pieces = { slab = slabRect, hub = Rect(hub), xp = xp }
		for i, wing in ipairs(hub.wings) do
			local s = hub:GetEffectiveScale()
			pieces["wing" .. i] = { wing:GetLeft() * s, wing:GetBottom() * s, wing:GetRight() * s, wing:GetTop() * s }
		end
		for _, pair in ipairs({ { "slab", "hub" }, { "slab", "wing1" }, { "slab", "wing2" }, { "hub", "wing1" }, { "hub", "wing2" }, { "slab", "xp" } }) do
			local gap = Gap(pieces[pair[1]], pieces[pair[2]])
			assert(gap <= EPS, string.format("%s %s: the %s and the %s stand %.3f apart", what, state, pair[1], pair[2], gap))
		end
		assert(xp[1] >= slabRect[1] - EPS and xp[3] <= slabRect[3] + EPS and xp[2] >= slabRect[2] - EPS and xp[4] <= bar1.buttons[1]:GetBottom() * bar1.buttons[1]:GetEffectiveScale() + EPS,
			what .. " " .. state .. ": the experience strip lies inside the slab, under the slots")
		assert(xp[3] - xp[1] >= (slabRect[3] - slabRect[1]) * 0.95, what .. " " .. state .. ": the experience strip runs the slab's whole width")
		for i = 1, 2 do
			local wing = pieces["wing" .. i]
			assert(wing[2] < slabRect[4] - EPS, what .. " " .. state .. ": wing " .. i .. " is seated into the slab's top edge, not over it")
			assert(math.abs((wing[1] + wing[3]) / 2 - centre) > 0 and (i == 1) == (wing[3] < centre + EPS), what .. ": wing " .. i .. " grows out of its own side of the hub")
			assert(Whole(wing[2], height), what .. " " .. state .. ": wing " .. i .. " sits on a whole physical pixel")
		end
		for k, edge in ipairs(slabRect) do
			assert(Whole(edge, height), what .. ": the slab's " .. ({ "left", "bottom", "right", "top" })[k] .. " edge is on a whole physical pixel")
		end
	end
	Slab.SetCombat(false)
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
	checked = checked + 1
end

print("ok actionbars medallions slab: " .. checked .. " screens")
