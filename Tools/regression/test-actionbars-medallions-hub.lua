-- test-actionbars-medallions-hub.lua: under the Medallions HUD style, for Lee's undead warlock with a pet out, the action slab stands behind bars 1 and 2 and the crest hub sits in the gap between them at every CREW screen: the hub, its wings, rune ring and every hub effect draw at a lower strata than every slot and everything on it, the hub's footprint never overlaps a slot rect, the wings ride above the top row and, out in combat, stay inside the reach and height Layouts keeps clear of other elements, bars 1 and 2 are two rows of six below 21:9 and one row of twelve at 21:9 and wider, and Frames brings the bars back with the slab and hub hidden.
local AB = dofile("Tools/regression/actionbars_env.lua")

local SCREENS = {
	{ 1280, 720 }, { 1920, 1080 }, { 2383, 1540 }, { 2560, 1080 }, { 2560, 1440 }, { 3440, 1440 }, { 3840, 1080 },
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

local function Medallions(K)
	K.Options.Write("HudStyle", "style", "medallions")
	assert(K.HudStyle.Current() == "medallions", "the HUD style is Medallions")
end

local checked = 0
for _, screen in ipairs(SCREENS) do
	local width, height = screen[1], screen[2]
	local what = width .. "x" .. height
	local env, K, ns = AB.New({ width = width, height = height, class = "WARLOCK" })
	env._game.petExists = true
	for i, action in ipairs({ "Firebolt", "Fire Shield", "Blood Pact", "Phase Shift" }) do
		env._game.pet[i] = { name = action, texture = 135809 + i, spellID = 8000 + i }
	end
	AB.Enable(env, K)
	assert(not (ns.Slab.frame and ns.Slab.frame:IsShown()), what .. ": under Frames there is no slab")
	Medallions(K)
	env.RunTimers()
	local Slab = ns.Slab
	local slab, hub = Slab.frame, Slab.hub
	assert(slab and slab:IsShown() and hub:IsShown(), what .. ": the slab and the hub are shown under Medallions")
	local bar1, bar2 = ns.bars.bar1, ns.bars.bar2
	local wide = K.Scale.Aspect() ~= "16:9"
	local rows = wide and 1 or 2
	assert(Columns(bar1) == rows and Columns(bar2) == rows, what .. ": bars 1 and 2 stand in " .. rows .. " rows, got " .. Columns(bar1) .. " and " .. Columns(bar2))

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
	for _, wing in ipairs(hub.wings) do
		local s = hub:GetEffectiveScale()
		local w = { wing:GetLeft() * s, wing:GetBottom() * s, wing:GetRight() * s, wing:GetTop() * s }
		assert(w[2] >= top - 1e-6, what .. ": the wings ride above the top row of slots")
		for _, b in ipairs(slots) do
			assert(not Overlaps(w, Rect(b)), what .. ": a wing overlaps a slot")
		end
	end
	assert(hub:GetScale() <= 1 and hub:GetScale() > 0.9, what .. ": the gap holds the full ring, scale " .. hub:GetScale())
	do
		local wing = K.Setup.Layouts.MEDALLIONS_WING
		local unit = K.Scale.Root():GetEffectiveScale()
		Slab.SetCombat(true)
		Slab.hub.wings[1].anim:GetScript("OnFinished")(Slab.hub.wings[1].anim)
		local centre = (hubRect[1] + hubRect[3]) / 2
		for _, w in ipairs(hub.wings) do
			local s = hub:GetEffectiveScale()
			local far = math.max(math.abs(w:GetLeft() * s - centre), math.abs(w:GetRight() * s - centre))
			assert(far <= wing.reach * unit + 1e-6, what .. ": a wing out in combat stays inside the reach Layouts keeps clear, " .. far / unit .. " units")
			assert(w:GetTop() * s <= top + wing.top * unit + 1e-6, what .. ": a wing stays under the height Layouts keeps clear")
		end
		Slab.SetCombat(false)
		Slab.hub.wings[1].anim:GetScript("OnFinished")(Slab.hub.wings[1].anim)
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
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
	checked = checked + 1
end

do
	local env, K, ns = AB.New({ width = 1920, height = 1080, class = "SHAMAN" })
	AB.Enable(env, K)
	Medallions(K)
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
