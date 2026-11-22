-- test-actionbars-medallions-hub.lua: the crest fills the hub at full brightness, below the ring and action slots on every screen.
local AB = dofile("Tools/regression/actionbars_env.lua")

local SCREENS = {
	{ 1280, 720 }, { 1920, 1080 }, { 2383, 1540 }, { 3456, 2234 }, { 2560, 1080 }, { 2560, 1440 }, { 3440, 1440 }, { 3840, 1080 },
	{ 3840, 2160 }, { 5120, 1440 },
}
local RANK = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }

local function Strata(frame)
	while frame do
		local strata = frame.GetFrameStrata and frame:GetFrameStrata()
		if strata then
			return strata
		end
		frame = frame.GetParent and frame:GetParent()
	end
	return "MEDIUM"
end

local function Rect(region)
	local s = region.GetEffectiveScale and region:GetEffectiveScale() or region:GetParent():GetEffectiveScale()
	return { region:GetLeft() * s, region:GetBottom() * s, region:GetRight() * s, region:GetTop() * s }
end

local function Overlaps(a, b)
	return a[1] < b[3] - 1e-6 and b[1] < a[3] - 1e-6 and a[2] < b[4] - 1e-6 and b[2] < a[4] - 1e-6
end

local LAYER = { BACKGROUND = 1, BORDER = 2, ARTWORK = 3, OVERLAY = 4, HIGHLIGHT = 5 }

local function Below(region, text)
	local a, b = region:GetParent(), text:GetParent()
	if a:GetFrameLevel() ~= b:GetFrameLevel() then
		return a:GetFrameLevel() < b:GetFrameLevel()
	end
	if a ~= b then
		return false
	end
	local layerA, subA = region:GetDrawLayer()
	local layerB, subB = text:GetDrawLayer()
	if LAYER[layerA] ~= LAYER[layerB] then
		return LAYER[layerA] < LAYER[layerB]
	end
	return (subA or 0) < (subB or 0)
end

local function Drawn(frame, out)
	for _, region in ipairs({ frame:GetRegions() }) do
		out[#out + 1] = region
	end
	for _, child in ipairs({ frame:GetChildren() }) do
		Drawn(child, out)
	end
	return out
end

local function Columns(bar)
	local tops = {}
	for i = 1, 12 do
		local top = bar.buttons[i]:GetTop()
		tops[math.floor(top * 100 + 0.5)] = true
	end
	local rows = 0
	for _ in pairs(tops) do
		rows = rows + 1
	end
	return rows
end

local checked = 0
for _, screen in ipairs(SCREENS) do
	local width, height = screen[1], screen[2]
	local what = width .. "x" .. height
	local env, K, ns = AB.New({ width = width, height = height, class = "WARLOCK" })
	env.UnitRace = function() return "Undead", "Scourge" end
	env.UnitSex = function() return 2 end
	env.UnitLevel = function()
		return 38
	end
	env._game.petExists = true
	for i, action in ipairs({ "Firebolt", "Fire Shield", "Blood Pact", "Phase Shift" }) do
		env._game.pet[i] = { name = action, texture = 135809 + i, spellID = 8000 + i }
	end
	AB.Enable(env, K)
	env.RunTimers()
	local Slab = ns.Slab
	local slab, hub = Slab.frame, Slab.hub
	assert(slab and slab:IsShown() and hub:IsShown(), what .. ": the slab and the hub are shown under Medallions")
	local bar1, bar2 = ns.bars.bar1, ns.bars.bar2
	local _, rows = K.Setup.Layouts.MedallionsGroup(K.Scale.Aspect())
	assert(Columns(bar1) == rows and Columns(bar2) == rows, what .. ": bars 1 and 2 stand in " .. rows .. " row(s), got " .. Columns(bar1) .. " and " .. Columns(bar2))
	local floor = K.Setup.Layouts.MEDALLIONS_SLOT.floor
	for _, bar in ipairs({ bar1, bar2 }) do
		for _, b in ipairs(bar.buttons) do
			assert(b:GetWidth() >= floor - 1e-6 and b:GetHeight() >= floor - 1e-6, what .. ": a slot is " .. b:GetWidth() .. " units, under the " .. floor .. "-unit floor")
		end
	end
	assert(bar1.buttons[12]:GetRight() < bar2.buttons[1]:GetLeft(), what .. ": bar 1's twelve stand left of the hub and bar 2's twelve right of it")

	local slots = {}
	for _, bar in ipairs({ bar1, bar2 }) do
		for _, b in ipairs(bar.buttons) do
			if b:IsShown() then
				slots[#slots + 1] = b
			end
		end
	end
	assert(#slots == 24, what .. ": 24 slots on the slab")
	local petSlots = 0
	for _, b in ipairs(ns.bars.pet and ns.bars.pet.buttons or {}) do
		if b:IsVisible() then
			slots[#slots + 1] = b
			petSlots = petSlots + 1
		end
	end
	assert(petSlots > 0, what .. ": the warlock's pet is out, so its bar shows, held to the same rule")
	local hubRank = RANK[Strata(hub)]
	assert(Strata(hub) == Slab.STRATA and Strata(slab) == Slab.STRATA, what .. ": the hub and the slab draw at " .. Slab.STRATA)
	local top = -math.huge
	local hubRect = Rect(hub)
	for _, b in ipairs(slots) do
		local rank = RANK[Strata(b)]
		assert(rank and rank > hubRank, what .. ": slot " .. tostring(b:GetName()) .. " draws at " .. Strata(b) .. ", above the hub's " .. Strata(hub))
		for _, part in ipairs({ b.overlay, b.cooldown, b.medProc }) do
			if type(part) == "table" and part.GetParent then
				assert(RANK[Strata(part)] > hubRank, what .. ": everything on a slot draws above the hub")
			end
		end
		local slot = Rect(b)
		if b:GetParent() ~= ns.bars.pet.header then
			top = math.max(top, slot[4])
		end
		assert(not Overlaps(hubRect, slot), what .. ": the hub's footprint overlaps slot " .. tostring(b:GetName()))
	end
	assert(hub.wings == nil, what .. ": the hub has no wings")
	assert(Below(hub.crest, hub.ring) and Below(hub.socket, hub.crest), what .. ": the crest sits in its socket under the gunmetal ring")
	assert(math.abs(hub:GetWidth() - 150) < 1, what .. ": keep the 150-unit hub ring")
	local canvas = math.min(123, K.Scale.Pixel(255) / 1.05)
	assert(math.abs(hub.crest:GetWidth() - canvas) < 1 and math.abs(hub.crest:GetHeight() - canvas) < 1, what .. ": fill the opening while keeping the pulsed crest within its 256-pixel bake")
	assert(math.abs(hub.socket:GetWidth() / hub:GetWidth() - 118 / 150) < 0.01, what .. ": keep the socket inside the ring's opening")
	for _, combat in ipairs({ false, true, false }) do
		Slab.SetCombat(combat)
		local cr, cg, cb, ca = hub.crest:GetVertexColor()
		assert(cr == 1 and cg == 1 and cb == 1 and ca == 1 and hub.crest:GetAlpha() == 1, what .. ": keep the crest at full colour and alpha at rest, in combat and after combat")
	end
	assert(hub:GetScale() <= 1 and hub:GetScale() > 0.9, what .. ": the gap holds the full ring, scale " .. hub:GetScale())
	do
		local level = hub.level
		assert(level:IsVisible() and level:GetText() == "38", what .. ": the plaque shows the player's level, got " .. tostring(level:GetText()))
		local point, anchor, to = level:GetPoint(1)
		assert(point == "CENTER" and anchor == hub.plaque and to == "CENTER", what .. ": the level number centres on the plaque")
		local text = Rect(hub.plaque)
		local covers = 0
		for _, region in ipairs(Drawn(hub, {})) do
			if region ~= level and region ~= hub.caption and region:IsVisible() and region:GetAlpha() > 0 and region:GetLeft() and Overlaps(Rect(region), text) then
				covers = covers + 1
				local layer, sub = region:GetDrawLayer()
				assert(Below(region, level), string.format("%s: a region on %s %s at frame level %d draws over the plaque's level number (%s %s at frame level %d)", what, tostring(layer), tostring(sub), region:GetParent():GetFrameLevel(), level:GetDrawLayer(), select(2, level:GetDrawLayer()), level:GetParent():GetFrameLevel()))
			end
		end
		assert(covers > 0 and Below(hub.plaque, level), what .. ": the plaque sits under the level number")
	end
	local centre = (hubRect[1] + hubRect[3]) / 2
	local gapLeft, gapRight = Rect(bar1.holder)[3], Rect(bar2.holder)[1]
	assert(math.abs(centre - (gapLeft + gapRight) / 2) < 1, what .. ": the hub is centred in the gap")
	assert(math.abs((hubRect[2] + hubRect[4]) / 2 - top) < 1, what .. ": the hub's centre sits on the slots' top edge")
	assert(not (ns.Tray.card and ns.Tray.card:IsShown()), what .. ": the Frames tray is hidden under Medallions")
	K.Options.Write("HudStyle", "style", "frames")
	env.RunTimers()
	assert(not slab:IsShown() and not hub:IsShown(), what .. ": back to Frames the slab and hub hide")
	assert(Columns(bar1) == 1, what .. ": back to Frames bar 1 is one row again")

	env.RunTimers()
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
	checked = checked + 1
end

do
	local env, K, ns = AB.New({ width = 1920, height = 1080, class = "SHAMAN" })
	AB.Enable(env, K)
	env.RunTimers()
	local hub = ns.Slab.hub
	local bar1, bar2 = ns.bars.bar1, ns.bars.bar2
	local before = Rect(hub)
	local settings = K.Layout.Get("actionbars.bar2")
	K.Layout.Set("actionbars.bar2", "x", settings.x - 60)
	env.RunTimers()
	local slots = {}
	for _, bar in ipairs({ bar1, bar2 }) do
		for _, b in ipairs(bar.buttons) do
			slots[#slots + 1] = b
		end
	end
	assert(hub:IsShown(), "the hub stays while the bars keep one baseline")
	do
		local after = Rect(hub)
		assert(after[3] - after[1] < before[3] - before[1], "a narrower gap shrinks the hub")
		for _, b in ipairs(slots) do
			assert(not Overlaps(after, Rect(b)), "a shrunken hub still clears every slot")
		end
	end
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

print("ok actionbars medallions hub: " .. checked .. " screens")
