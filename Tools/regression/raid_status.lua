-- raid_status.lua: shared checks for the raid tile's statuses (rank round 6): the engine played from the containers' own settings, the "+N" chip's count, the boss route and the status lane, and the presets at 20 and 40 players.
local G = dofile("Tools/regression/group_env.lua")
local A = dofile("Tools/regression/auras_env.lua")
local Scene = dofile("Tools/render/scene.lua")

local LEGIBLE = 12
local PIXEL = 0.75

local function eq(got, want, what)
	assert(got == want, what .. ": want " .. tostring(want) .. ", got " .. tostring(got))
end

local function intersects(a, b)
	return a[1] < b[1] + b[3] - 0.01 and b[1] < a[1] + a[3] - 0.01 and a[2] < b[2] + b[4] - 0.01 and b[2] < a[2] + a[4] - 0.01
end

local function inside(r, box)
	return r[1] >= box[1] - 0.01 and r[2] >= box[2] - 0.01 and r[1] + r[3] <= box[1] + box[3] + 0.01 and r[2] + r[4] <= box[2] + box[4] + 0.01
end

local function describe(r)
	return string.format("[x %.1f to %.1f, y %.1f to %.1f]", r[1], r[1] + r[3], r[2], r[2] + r[4])
end

local function Saved(settings)
	settings.enabled = true
	return { version = 2, profiles = { Default = { GroupFrames = settings } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }
end

local function Put(root, key, value)
	local node, parts = root, {}
	for part in key:gmatch("[^%.]+") do
		parts[#parts + 1] = part
	end
	for i = 1, #parts - 1 do
		node[parts[i]] = type(node[parts[i]]) == "table" and node[parts[i]] or {}
		node = node[parts[i]]
	end
	node[parts[#parts]] = value
end

local function Batch(e, K, settings)
	local root = K.Store.Module("GroupFrames")
	for _, kv in ipairs(settings) do
		Put(root, kv[1], kv[2])
	end
	e.SetQuiet(true)
	K.Callbacks.Fire("SettingChanged", "GroupFrames", settings[#settings][1], settings[#settings][2])
	e.SetQuiet(false)
end

local function Content(ns, header, unit)
	local i = 1
	while header._attributes["child" .. i] do
		local button = header._attributes["child" .. i]
		if button._attributes.unit == unit and button._shown then
			return ns.Button.Content(button)
		end
		i = i + 1
	end
end

local function Part(e, f, rect)
	local fx, fy = Scene.Rect(e, f)
	return { fx + rect.left, fy + rect.top, rect.width, rect.height }
end

-- Preset(name) -> the GroupFrames settings the setup writes for a preset ("Default" writes none), as saved values.
local function Preset(K, name)
	local out = {}
	if name ~= "Default" then
		for _, entry in ipairs(K.Setup.Layouts.Settings(name)) do
			if entry.module == "GroupFrames" then
				Put(out, entry.key, entry.value)
			end
		end
	end
	return out
end

-- Raid(settings, members) -> env, K, ns and raid1's frame, with the module running on a raid of that size.
local function Raid(settings, members, extra)
	local env, K, ns = G.New({ saved = Saved(settings) })
	G.SetRoster(env, "raid", G.Members(members, extra))
	assert(K.Modules.Enable("GroupFrames"))
	env.RunTimers()
	return env, K, ns, Content(ns, ns.Headers.raid[1], "raid1")
end

-- The engine, played from the containers' own settings ----------------------------------------------------------
-- An aura: boss, priority (important) and its processed type ("Debuff" or "Dispel"). The engine puts it in every
-- enabled group whose candidate filters it passes, up to each group's frame count, and lays the groups out in their
-- layout order; an aura slot shows the first aura it takes.
local function Passes(env, candidates, aura)
	if not candidates then
		return true
	end
	local types = env.AuraUtil.AuraUpdateChangedType
	if candidates.isBossAura ~= nil and candidates.isBossAura ~= aura.boss then
		return false
	end
	if candidates.isPriorityAura ~= nil and candidates.isPriorityAura ~= aura.priority then
		return false
	end
	if candidates.processedAuraType ~= nil and candidates.processedAuraType ~= types[aura.type] then
		return false
	end
	return true
end

local function Flow(env, container, auras)
	local keys = {}
	for key, group in pairs(container._groups) do
		if group.enabled then
			keys[#keys + 1] = key
		end
	end
	table.sort(keys, function(a, b)
		return (container._groups[a].layoutIndex or 0) < (container._groups[b].layoutIndex or 0)
	end)
	local out = {}
	for _, key in ipairs(keys) do
		local group, n = container._groups[key], 0
		for _, aura in ipairs(auras) do
			if n < group.maxFrameCount and Passes(env, group.candidateFilters, aura) then
				out[#out + 1] = aura
				n = n + 1
			end
		end
	end
	return out
end

local function Slot(env, container, key, auras)
	local slot = container._slots[key]
	if not slot.enabled then
		return nil
	end
	for _, aura in ipairs(auras) do
		if Passes(env, slot.candidateFilters, aura) then
			return aura
		end
	end
end

-- Read(env, f, auras) -> the auras a player sees: the boss slot's, the row's visible cells, the chip's text, and
-- every aura the row holds (shown or counted).
local function Read(env, f, auras)
	local k = f.parts and f.parts.block
	local cells = k and k.cells or 0
	local row = Flow(env, f.auras, auras)
	local chip = f.debuffChip
	assert(chip, "the frame has a debuff count chip")
	local held = Flow(env, chip.ghost, auras)
	chip.ghost:SetSize(1, math.max(1, #held * chip.pitch))
	local text, face = A.Chip(chip)
	-- Past the last label, the saturated label shows ("14+": at least that many past the cells).
	if chip.sat then
		local Geometry = dofile("Tools/regression/geometry.lua")
		local win = Geometry.Rect(chip.window, chip.window)
		local sat = Geometry.Rect(chip.sat, chip.window)
		if sat and win and sat.bottom <= win.bottom + 1e-3 and sat.top >= win.top - 1e-3 then
			assert(text == nil, "one label at a time")
			text = chip.satText:GetText()
		end
	end
	-- Past the cells, the chip covers the last one.
	local visible = {}
	local shown = #held > cells and cells - 1 or math.min(#held, cells)
	for i = 1, shown do
		visible[#visible + 1] = row[i]
	end
	return { boss = Slot(env, f.highlights, "boss", auras), visible = visible, chip = text, face = face, row = row, held = held, cells = cells }
end

local function Has(list, aura)
	for _, item in ipairs(list) do
		if item == aura then
			return true
		end
	end
	return false
end

local function Auras(spec)
	local out = {}
	for _, item in ipairs(spec) do
		for i = 1, item[1] do
			out[#out + 1] = { boss = item[2] == "boss", priority = item[2] == "important", type = item[2] == "dispel" and "Dispel" or "Debuff", name = item[2] .. i }
		end
	end
	return out
end

-- Every boss debuff reaches the player: in the centred slot, in a visible cell, or in the chip's count, and the chip
-- counts exactly the row's auras that have no cell.
local function CheckRoute(env, f, spec, what)
	local auras = Auras(spec)
	local seen = Read(env, f, auras)
	for _, aura in ipairs(seen.row) do
		assert(Has(seen.held, aura), what .. ": the chip counts " .. aura.name .. ", which the row holds")
	end
	local hidden = #seen.held - #seen.visible
	if #seen.held > seen.cells then
		local most = #f.debuffChip.labels + 1
		local want = hidden > most and (most + 1) .. "+" or "+" .. hidden
		eq(seen.chip, want, what .. ": the chip on the last cell counts the " .. hidden .. " debuffs past the cells")
		assert(seen.face, what .. ": the chip's glass covers the last cell")
	else
		eq(seen.chip, nil, what .. ": no chip while every debuff has a cell")
	end
	for _, aura in ipairs(auras) do
		if aura.boss then
			assert(Has(seen.held, aura), what .. ": " .. aura.name .. " reaches the debuff row, shown or counted")
			assert(seen.boss == aura or Has(seen.visible, aura) or hidden > 0, what .. ": " .. aura.name .. " shows or is counted")
		end
	end
	local bosses = 0
	for _, aura in ipairs(auras) do
		bosses = bosses + (aura.boss and 1 or 0)
	end
	if bosses > 0 then
		assert(seen.boss and seen.boss.boss, what .. ": the centred slot shows a boss debuff")
	else
		eq(seen.boss, nil, what .. ": the centred slot is empty without a boss debuff")
	end
	return seen
end

local BOSS_CASES = {
	{ { { 0, "boss" } }, "0 boss debuffs" },
	{ { { 1, "boss" } }, "1 boss debuff" },
	{ { { 2, "boss" } }, "2 boss debuffs" },
	{ { { 8, "boss" } }, "8 boss debuffs" },
	{ { { 3, "boss" }, { 2, "important" }, { 3, "dispel" }, { 4, "other" } }, "a mixed 12" },
}

-- The status lane --------------------------------------------------------------------------------------------------
local HELPFUL = { EXTERNAL = true, BIG_DEFENSIVE = true }

local function Statuses(env, ns, f, what)
	local parts = f.parts
	local reserved = {
		name = Part(env, f, parts.name),
		deficit = Part(env, f, { left = parts.healthText.left, top = parts.healthText.top, width = parts.healthText.right - parts.healthText.left, height = parts.healthText.height }),
		debuffs = { Scene.Rect(env, f.auraClip) },
		heals = { Scene.Rect(env, f.buffClip) },
	}
	local tile = { Scene.Rect(env, f) }
	local boss = f.highlights:GetAuraSlotFrame("boss")
	boss:Show()
	local bossRect = { Scene.Rect(env, boss) }
	boss:Hide()
	local placed = {}
	for i = 1, 3 do
		local key = "indicator" .. i
		local category = ns.Settings.current[key].category
		local slot = f.indicators._slots[key]
		assert(slot.enabled, what .. ": " .. category .. " (indicator " .. i .. ") is on")
		local place = ns.Slots.Placements(f)[i]
		-- 12 units, floored to whole pixels (11.92 at the owner's 1.426 pixels per unit).
		assert(place.size >= LEGIBLE - PIXEL, what .. ": " .. category .. " is at least " .. LEGIBLE .. " units, got " .. place.size)
		slot.frame:Show()
		local r = { Scene.Rect(env, slot.frame) }
		slot.frame:Hide()
		assert(inside(r, tile), what .. ": " .. category .. " " .. describe(r) .. " inside the tile")
		for name, rect in pairs(reserved) do
			assert(not intersects(r, rect), what .. ": " .. category .. " " .. describe(r) .. " clear of the " .. name .. " " .. describe(rect))
		end
		if HELPFUL[category] then
			assert(not intersects(r, bossRect), what .. ": " .. category .. " clear of the boss slot")
			assert(parts.lane and inside(r, Part(env, f, parts.lane)), what .. ": " .. category .. " " .. describe(r) .. " in the status lane")
		else
			-- Crowd control is harmful: it takes the centred spot under the boss slot, which draws over it.
			assert(inside(r, bossRect) and math.abs(r[1] + r[3] / 2 - bossRect[1] - bossRect[3] / 2) < 0.6 and math.abs(r[2] + r[4] / 2 - bossRect[2] - bossRect[4] / 2) < 0.6,
				what .. ": " .. category .. " centred in the boss slot's spot " .. describe(r) .. " " .. describe(bossRect))
			assert(slot.frame:GetFrameLevel() < boss:GetFrameLevel(), what .. ": the boss slot draws over " .. category)
		end
		for j, other in pairs(placed) do
			assert(not intersects(r, other), what .. ": indicators " .. j .. " and " .. i .. " apart " .. describe(other) .. " " .. describe(r))
		end
		placed[i] = r
	end
end

-- Presets at 20 and 40 players: the defensive statuses on, the boss route and the chip -------------------------------
-- Each preset starts with 20 players; 20 more join in combat while auras are secret (the automatic layout waits for
-- the end of combat), and the 40-player tile is checked after it.
local S = {}
function S.Presets(names)
	local _, K0 = G.New()
	for _, name in ipairs(names) do
		local env, _, ns, f = Raid(Preset(K0, name), 20)
		local function check(what, routes)
			local w, h = ns.Style.Size(f)
			what = what .. " (" .. w .. " by " .. h .. ")"
			assert(h >= 40, what .. ": the tile keeps the height its status lane needs")
			Statuses(env, ns, f, what)
			-- Astra #1: the boss group stays in the row, so the second and later boss debuffs have a route.
			local groups = f.auras._groups
			assert(groups.boss.enabled, what .. ": the boss group stays in the debuff row")
			eq(groups.boss.candidateFilters.isBossAura, true, what .. ": it takes boss debuffs")
			assert(f.highlights._slots.boss.enabled, what .. ": the centred boss slot is on")
			for _, case in ipairs(routes and BOSS_CASES or {}) do
				CheckRoute(env, f, case[1], what .. ", " .. case[2])
			end
		end
		check(name .. " at 20", true)
		env._aurasSecret = true
		env._combat = true
		G.SetRoster(env, "raid", G.Members(40))
		f = Content(ns, ns.Headers.raid[1], "raid1")
		for _, case in ipairs(BOSS_CASES) do
			CheckRoute(env, f, case[1], name .. ", restricted, " .. case[2])
		end
		-- Out of combat the module polls each second while auras stay secret, so the stub's timers settle only once
		-- they are readable again, as they are after a pull.
		env._combat = false
		env._aurasSecret = false
		env.FireEvent("PLAYER_REGEN_ENABLED")
		env.RunTimers()
		f = Content(ns, ns.Headers.raid[1], "raid1")
		eq(ns.AutoLayout.state.bracket, "LARGE", name .. ": the 40-player layout applies after combat")
		check(name .. " at 40", true)
		eq(#env._errors, 0, name .. ": " .. tostring(env._errors[1]))
		env, ns, f = nil, nil, nil
		collectgarbage()
	end
end

S.G, S.A, S.Scene = G, A, Scene
S.LEGIBLE = LEGIBLE
S.eq, S.intersects, S.inside, S.describe = eq, intersects, inside, describe
S.Saved, S.Batch, S.Content, S.Part, S.Preset, S.Raid = Saved, Batch, Content, Part, Preset, Raid
S.CheckRoute, S.Statuses, S.BOSS_CASES = CheckRoute, Statuses, BOSS_CASES
return S
