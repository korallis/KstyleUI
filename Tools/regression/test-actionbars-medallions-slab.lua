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

local function Rows(bar)
	local seen, rows = {}, 0
	for i = 1, 12 do
		local key = math.floor(bar.buttons[i]:GetBottom() * 100 + 0.5)
		if not seen[key] then
			seen[key], rows = true, rows + 1
		end
	end
	return rows
end

local checked = 0
for _, screen in ipairs(SCREENS) do
	local width, height = screen[1], screen[2]
	local what = width .. "x" .. height
	local env, K, ns = AB.New({ width = width, height = height, class = "WARLOCK" })
	env._game.petExists = true
	for i = 1, 10 do env._game.forms[i] = { texture = 135036, isCastable = true, spellID = 15473 + i } end
	env._game.pet[1] = { name = "Firebolt", texture = 135809, spellID = 8001 }
	AB.Enable(env, K)
	local strip = env.CreateFrame("Frame", nil, K.Scale.Root())
	K.Layout.Register(strip, "databars.xp", K.Setup.Layouts.Default("databars.xp"), { label = "Experience", module = "DataBars", resizable = true })
	K.Options.Write("HudStyle", "style", "medallions")
	env.RunTimers()
	local Slab, Layouts = ns.Slab, K.Setup.Layouts
	local slab, hub = Slab.frame, Slab.hub
	assert(slab and slab:IsShown() and hub:IsShown(), what .. ": the slab and the hub are shown under Medallions")
	assert(hub.wings == nil, what .. ": the hub has no wings")
	local unit = K.Scale.Root():GetEffectiveScale()
	local px = math.max(1, 768 / height / unit * 1.01)

	local _, rows, _, _, size, spacing = Layouts.MedallionsGroup(K.Scale.Aspect())
	assert(rows == 1, what .. ": Layouts gives each group one row")
	if K.Scale.Aspect() ~= "16:9" then
		assert(size == 42 and spacing == 5, what .. ": 21:9 and wider must keep 42-unit sockets and five-unit gaps")
	end
	local bar1, bar2 = ns.bars.bar1, ns.bars.bar2
	local hubRect = Rect(hub)
	for _, bar in ipairs({ bar1, bar2 }) do
		assert(Rows(bar) == rows, what .. ": " .. bar.def.key .. " stands in " .. rows .. " row(s), got " .. Rows(bar))
		for i = 1, 12 do
			local b = bar.buttons[i]
			assert(b:IsShown(), what .. ": " .. bar.def.key .. " shows all twelve slots")
			local r = Rect(b)
			assert(math.abs((r[3] - r[1]) / unit - size) < px, what .. ": a socket is " .. (r[3] - r[1]) / unit .. " units")
			local icon = Rect(b.icon)
			assert(math.abs((icon[1] - r[1]) / unit - 3 * size / Layouts.MEDALLIONS_SLOT.size) < px, what .. ": the icon sits 3/42 of the socket inside it")
			assert(not b.chrome.visible, what .. ": the socket replaces the slot's own chrome")
			if bar == bar1 then
				assert(r[3] <= hubRect[1] + EPS, what .. ": bar 1's slot " .. i .. " stands left of the hub")
			else
				assert(r[1] >= hubRect[3] - EPS, what .. ": bar 2's slot " .. i .. " stands right of the hub")
			end
		end
		local pitch = (bar.buttons[2]:GetLeft() - bar.buttons[1]:GetLeft()) * bar.buttons[1]:GetEffectiveScale() / unit
		assert(math.abs(pitch - size - spacing) < px, what .. ": the sockets stand " .. pitch .. " units apart")
	end
	assert(math.abs(bar1.buttons[1]:GetBottom() - bar2.buttons[1]:GetBottom()) < EPS, what .. ": both groups share one baseline")

	for _, combat in ipairs({ false, true }) do
		local state = combat and "in combat" or "at rest"
		Slab.SetCombat(combat)
		local slabRect, xp = Rect(slab), Rect(strip)
		local pieces = { slab = slabRect, hub = Rect(hub), xp = xp }
		for _, pair in ipairs({ { "slab", "hub" }, { "slab", "xp" } }) do
			local gap = Gap(pieces[pair[1]], pieces[pair[2]])
			assert(gap <= EPS, string.format("%s %s: the %s and the %s stand %.3f apart", what, state, pair[1], pair[2], gap))
		end
		local lowest = math.huge
		for _, bar in ipairs({ bar1, bar2 }) do
			for i = 1, 12 do
				lowest = math.min(lowest, bar.buttons[i]:GetBottom() * bar.buttons[i]:GetEffectiveScale())
			end
		end
		assert(xp[1] >= slabRect[1] - EPS and xp[3] <= slabRect[3] + EPS and xp[2] >= slabRect[2] - EPS and xp[4] <= lowest + EPS,
			what .. " " .. state .. ": the experience strip lies inside the slab, under the slots")
		assert(xp[3] - xp[1] >= (slabRect[3] - slabRect[1]) * 0.95, what .. " " .. state .. ": the experience strip runs the slab's whole width")
		for k, edge in ipairs(slabRect) do
			assert(Whole(edge, height), what .. ": the slab's " .. ({ "left", "bottom", "right", "top" })[k] .. " edge is on a whole physical pixel")
		end
	end
	Slab.SetCombat(false)

	local pet = ns.bars.pet
	local plate = Slab.sides and Slab.sides.pet
	assert(pet.buttons[1]:IsVisible() and plate and plate:IsVisible(), what .. ": the imp's bar is out in its own small slab")
	assert(plate:GetFrameStrata() == Slab.STRATA, what .. ": the pet slab draws at the slab's strata, under its slots")
	local petRect, slabRect = Rect(plate), Rect(slab)
	for _, b in ipairs(pet.buttons) do
		if b:IsShown() then
			local r = Rect(b)
			assert(r[1] >= petRect[1] - EPS and r[3] <= petRect[3] + EPS and r[2] >= petRect[2] - EPS and r[4] <= petRect[4] + EPS, what .. ": the pet slab holds every pet slot")
		end
	end
	local stanceRect = Rect(assert(Slab.sides.stance))
	local apart = (slabRect[1] - petRect[3]) / unit
	if K.Scale.Aspect() == Layouts.ASPECTS[1] then apart = apart + select(3, Layouts.MedallionsSide(K.Scale.Aspect(), "actionbars.pet")) - Layouts.GAP - K.Tokens.Size("gapSmall") end
	assert(math.abs(apart - Layouts.MEDALLIONS_SIDE.clear) < 2 * px, what .. ": both side bars dock to the slab's left edge")
	assert(math.abs(petRect[1] - stanceRect[1]) < 2 * px * unit and math.abs(petRect[3] - stanceRect[3]) < 2 * px * unit,
		what .. ": align pet and stance slab edges; derive both positions from the action slab")
	assert(stanceRect[2] >= petRect[4] - EPS, what .. ": keep the stacked pet and stance slabs apart")
	if K.Scale.Aspect() ~= Layouts.ASPECTS[1] then
		assert(math.abs((petRect[2] - slabRect[2]) / unit + 8) < 2 * px, what .. ": the pet slab sits eight units below the action slab's lower edge")
	end
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
	checked = checked + 1
end

print("ok actionbars medallions slab: " .. checked .. " screens")
