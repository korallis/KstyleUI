-- test-groupframes-lanes.lua: every signal on a group frame keeps its own room. Your heals sit in a lane that never crosses the party name or bar, and the six indicator slots take places that overlap no other indicator, the name row, the portrait, the debuff block or your heals, at party and raid sizes; a slot with no room left turns off, in the frame and in the preview alike.
local G = dofile("Tools/regression/group_env.lua")
local Scene = dofile("Tools/render/scene.lua")

local function eq(got, want, what)
	assert(got == want, what .. ": want " .. tostring(want) .. ", got " .. tostring(got))
end

local function intersects(a, b)
	return a[1] < b[1] + b[3] - 0.01 and b[1] < a[1] + a[3] - 0.01 and a[2] < b[2] + b[4] - 0.01 and b[2] < a[2] + a[4] - 0.01
end

local function inside(r, box, what)
	assert(r[1] >= box[1] - 0.01 and r[2] >= box[2] - 0.01 and r[1] + r[3] <= box[1] + box[3] + 0.01 and r[2] + r[4] <= box[2] + box[4] + 0.01,
		what .. string.format(" [%.1f %.1f %.1f %.1f] inside [%.1f %.1f %.1f %.1f]", r[1], r[2], r[3], r[4], box[1], box[2], box[3], box[4]))
end

local function describe(r)
	return string.format("[%.1f %.1f %.1f %.1f]", r[1], r[2], r[3], r[4])
end

local function content(ns, header, unit)
	local i = 1
	while header._attributes["child" .. i] do
		local button = header._attributes["child" .. i]
		if button._attributes.unit == unit and button._shown then
			return ns.Button.Content(button)
		end
		i = i + 1
	end
end

local function Batch(e, K, settings)
	local root = K.Store.Module("GroupFrames")
	for _, kv in ipairs(settings) do
		local node, parts = root, {}
		for part in kv[1]:gmatch("[^%.]+") do
			parts[#parts + 1] = part
		end
		for i = 1, #parts - 1 do
			node[parts[i]] = type(node[parts[i]]) == "table" and node[parts[i]] or {}
			node = node[parts[i]]
		end
		node[parts[#parts]] = kv[2]
	end
	e.SetQuiet(true)
	K.Callbacks.Fire("SettingChanged", "GroupFrames", settings[#settings][1], settings[#settings][2])
	e.SetQuiet(false)
end

-- A raid tile with room for indicators beside its bar's signals (rank R5).
local BIG = { width = 110, height = 56 }

local function Saved(settings)
	settings.enabled = true
	return { version = 2, profiles = { Default = { GroupFrames = settings } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }
end

-- A part of the frame in screen units, from the layout's own rect (left and top inside the frame).
local function Part(e, f, rect)
	local fx, fy = Scene.Rect(e, f)
	return { fx + rect.left, fy + rect.top, rect.width, rect.height }
end

-- The rects every indicator must leave alone: the name row, the portrait, the debuff block and your heals.
local function Reserved(e, f)
	local parts, out = f.parts, {}
	if not parts.nameInside then
		out.name = Part(e, f, parts.name)
	end
	if parts.portrait then
		out.portrait = Part(e, f, parts.portrait)
	end
	if f.auraClip and f.auraClip:IsShown() then
		out.debuffs = { Scene.Rect(e, f.auraClip) }
	end
	if f.buffClip then
		out.heals = { Scene.Rect(e, f.buffClip) }
	end
	-- Rank R5: a raid tile's boss slot and its deficit lane are reserved too.
	if parts.boss then
		out.boss = Part(e, f, parts.boss)
	end
	if parts.overlay then
		local spot = parts.healthText
		out.deficit = Part(e, f, { left = spot.left, top = spot.top, width = spot.right - spot.left, height = spot.height })
	end
	return out
end

local function Indicators(e, ns, f, what)
	local tile = { Scene.Rect(e, f) }
	local reserved = Reserved(e, f)
	local placed, plan = {}, ns.Slots.Placements(f)
	for i = 1, 6 do
		local slot = f.indicators._slots["indicator" .. i]
		local place = plan[i]
		if slot.enabled then
			assert(place.fits, what .. ": slot " .. i .. " is on only when it fits")
			slot.frame:Show()
			local r = { Scene.Rect(e, slot.frame) }
			inside(r, tile, what .. ": indicator " .. i .. " inside the tile")
			for name, rect in pairs(reserved) do
				assert(not intersects(r, rect), what .. ": indicator " .. i .. " " .. describe(r) .. " clear of the " .. name .. " " .. describe(rect))
			end
			-- Rank R5: a helpful indicator never paints on a raid tile's bar; a harmful one may, as the debuffs do.
			if f.parts.overlay and ns.Slots.Helpful(ns.Settings.current["indicator" .. i].category) then
				local bar = { Scene.Rect(e, f.health) }
				assert(not intersects(r, bar), what .. ": helpful indicator " .. i .. " " .. describe(r) .. " stays off the bar " .. describe(bar))
			end
			for j, other in pairs(placed) do
				assert(not intersects(r, other), what .. ": indicators " .. j .. " and " .. i .. " apart " .. describe(other) .. " " .. describe(r))
			end
			placed[i] = r
		end
	end
	return placed
end

local POSITIONS = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }

local function Sweep(e, K, ns, f, what, onByDefault, category)
	category = category or "EXTERNAL"
	-- The defaults: the default indicators that fit keep apart. Round 4 (Grok #1): no indicator sits on the bar, so a
	-- 72 by 40 raid tile, whose bar, debuff block and heal row fill the space under the name, keeps one.
	local placed = Indicators(e, ns, f, what .. ", defaults")
	local n = 0
	for _ in pairs(placed) do
		n = n + 1
	end
	eq(n, onByDefault, what .. ": the default indicators that fit are on")
	-- Astra R3 #3A: six indicators at one place, at the default size and the largest. (A smaller size only finds room
	-- more easily; the fractional-scale block below covers the shrink floor.)
	for _, size in ipairs({ 14, 32 }) do
		for _, position in ipairs(POSITIONS) do
			local settings = {}
			for i = 1, 6 do
				settings[#settings + 1] = { "indicator" .. i .. ".category", category }
				settings[#settings + 1] = { "indicator" .. i .. ".position", position }
				settings[#settings + 1] = { "indicator" .. i .. ".size", size }
			end
			Batch(e, K, settings)
			placed = Indicators(e, ns, f, what .. ", six at " .. position .. " size " .. size)
			assert(placed[1], what .. ": the first slot at " .. position .. " size " .. size .. " finds room")
		end
	end
	-- Mixed places, as a healer sets them.
	Batch(e, K, {
		{ "indicator1.position", "TOPLEFT" }, { "indicator2.position", "TOPRIGHT" }, { "indicator3.position", "BOTTOMRIGHT" },
		{ "indicator4.position", "CENTER" }, { "indicator5.position", "CENTER" }, { "indicator6.position", "LEFT" },
	})
	Indicators(e, ns, f, what .. ", mixed")
	-- Back to the defaults for the next block.
	local reset = {}
	local defaults = ns.Settings.defaults
	for i = 1, 6 do
		local d = defaults["indicator" .. i]
		reset[#reset + 1] = { "indicator" .. i .. ".category", d.category }
		reset[#reset + 1] = { "indicator" .. i .. ".position", d.position }
		reset[#reset + 1] = { "indicator" .. i .. ".size", d.size }
	end
	Batch(e, K, reset)
end

-- Party: the tank.
local env, K, ns = G.New()
G.SetRoster(env, "party", {
	{ name = "Thaldren", class = "WARRIOR", role = "TANK", health = 92 },
	{ name = "Sylaen", class = "DRUID", role = "HEALER", health = 87 },
})
assert(K.Modules.Enable("GroupFrames"))
env.RunTimers()
local tank = content(ns, ns.Headers.party, "party1")

-- Grok R3 #1, Opus #14, R5 #1: your heals on a party frame sit in their own lane at the name line's right end, inside
-- the tile, clear of the name text and wholly above the pill (round 4 put them in the pill's row, where they read as
-- the bar's end).
do
	local heals = { Scene.Rect(env, tank.buffClip) }
	local bar = { Scene.Rect(env, tank.health) }
	inside(heals, { Scene.Rect(env, tank) }, "party: your heals")
	assert(not intersects(heals, bar), "party: your heals " .. describe(heals) .. " never cross the bar " .. describe(bar))
	assert(not intersects(heals, Part(env, tank, tank.parts.name)), "party: nor the name text's lane")
	assert(heals[2] + heals[4] <= bar[2] - 0.01, "party: the lane sits above the pill, not in its row")
	local _, count = ns.Auras.HealIcons(tank, ns.Settings.current.party)
	eq(count, ns.Settings.current.party.buffCount, "party: every heal you may show has room")
end
Sweep(env, K, ns, tank, "party", 3)
eq(#env._errors, 0, tostring(env._errors[1]))

-- The preview draws the same places: a slot that does not fit is not drawn there either.
do
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetSize(280, 700)
	parent:SetPoint("TOPLEFT", K.Scale.Root(), "TOPLEFT", 40, -40)
	-- Rank R5: a 72 by 40 raid tile is full (status icons, deficit lane, boss slot and debuffs on its bar, the name and
	-- your heals on its name line), so indicators get room on a larger tile.
	Batch(env, K, { { "raid.width", BIG.width }, { "raid.height", BIG.height } })
	local preview = K.Options.Preview("GroupFrames")(parent)
	local sample = preview.raidFrames[1]
	local settings = {}
	for i = 1, 6 do
		settings[#settings + 1] = { "indicator" .. i .. ".category", "EXTERNAL" }
		settings[#settings + 1] = { "indicator" .. i .. ".position", "CENTER" }
		settings[#settings + 1] = { "indicator" .. i .. ".size", 14 }
	end
	Batch(env, K, settings)
	-- A helpful indicator finds no room off a raid tile's bar, so it turns off rather than paint on the fill; a harmful
	-- one, crowd control, may sit on the bar as the debuffs do.
	eq(ns.Slots.Placements(sample)[1].fits, false, "preview: a helpful indicator turns off on a raid tile")
	for i = 1, 6 do
		settings[(i - 1) * 3 + 1] = { "indicator" .. i .. ".category", "CROWD_CONTROL" }
	end
	Batch(env, K, settings)
	preview:Refresh()
	sample.sample.indicators = { CROWD_CONTROL = true }
	ns.Style.Paint(sample)
	for _, painter in ipairs(ns.Style.painters) do
		painter(sample, sample.sample)
	end
	local plan = ns.Slots.Placements(sample)
	local placed = {}
	for i, icon in ipairs(sample.sampleSlots) do
		eq(icon:IsShown(), plan[i].fits, "preview: slot " .. i .. " shows exactly when it fits")
		if icon:IsShown() then
			local r = { Scene.Rect(env, icon) }
			for j, other in pairs(placed) do
				assert(not intersects(r, other), "preview: indicators " .. j .. " and " .. i .. " apart")
			end
			placed[i] = r
		end
	end
	assert(placed[1], "preview: the first slot fits a raid tile")
	Batch(env, K, { { "raid.width", 72 }, { "raid.height", 40 } })
end

-- Raid: a 72 by 40 tile is full, so the default indicators turn off rather than cover anything; a larger tile places
-- them, a harmful one on the bar, a helpful one never.
do
	local renv, RK, rns = G.New()
	G.SetRoster(renv, "raid", G.Members(5))
	assert(RK.Modules.Enable("GroupFrames"))
	renv.RunTimers()
	local f = content(rns, rns.Headers.raid[1], "raid1")
	local heals = { Scene.Rect(renv, f.buffClip) }
	assert(not intersects(heals, Part(renv, f, f.parts.name)), "raid: your heals stay off the name row")
	assert(not intersects(heals, { Scene.Rect(renv, f.auraClip) }), "raid: and off the debuffs")
	local placed = Indicators(renv, rns, f, "raid 72 by 40")
	eq(next(placed), nil, "raid 72 by 40: the full tile turns its default indicators off")
	Batch(renv, RK, { { "raid.width", BIG.width }, { "raid.height", BIG.height } })
	Sweep(renv, RK, rns, f, "raid " .. BIG.width .. " by " .. BIG.height, 1, "CROWD_CONTROL")
	eq(#renv._errors, 0, tostring(renv._errors[1]))
end

-- Codex review, round 3: at fractional pixel scales (1440 and 1600 lines tall) whole-pixel snapping must not squeeze
-- the default indicators off a raid tile. These checks read state only, so the stubs keep no call log.
for _, height in ipairs({ 1440, 1600 }) do
	local renv, RK, rns = G.New({ width = height * 16 / 9, height = height, saved = Saved({ raid = BIG }), setup = function(e)
		e.SetQuiet(true)
	end })
	G.SetRoster(renv, "raid", G.Members(5))
	assert(RK.Modules.Enable("GroupFrames"))
	renv.RunTimers()
	local f = content(rns, rns.Headers.raid[1], "raid1")
	local placed = Indicators(renv, rns, f, "raid at " .. height)
	local n = 0
	for _ in pairs(placed) do
		n = n + 1
	end
	eq(n, 1, "raid at " .. height .. ": the default indicator that fits at scale 1 stays on")
	-- A shrunk indicator styles its count at the size it is drawn, so the count stays inside the icon.
	local plan = rns.Slots.Placements(f)
	local slot = f.indicators._slots.indicator1.frame
	rns.Auras.StyleIcon(slot)
	local parts = rns.Auras.Parts(slot)
	local _, fontSize = parts.count:GetFont()
	assert(fontSize <= plan[1].size, "raid at " .. height .. ": the count's " .. tostring(fontSize) .. " fits the " .. plan[1].size .. "-unit icon")
	eq(#renv._errors, 0, tostring(renv._errors[1]))
end

print("groupframes lanes ok")
