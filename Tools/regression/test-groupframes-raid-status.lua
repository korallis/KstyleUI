-- test-groupframes-raid-status.lua: a raid tile keeps every status it is configured for (rank round 6): the debuff cluster ends in an engine-counted "+N" chip (Grok #2), every boss debuff past the centred slot still reaches the row or the chip (Astra #1), the shipped raid presets show their defensive indicators at 20 and 40 players in a status lane on the bar (Astra #2), a configuration with no room says so in its settings row, the party's indicators are legible (Opus), and the missing health keeps clear of the debuffs (Muse).
local S = dofile("Tools/regression/raid_status.lua")
local G, A, Scene = S.G, S.A, S.Scene
local LEGIBLE = S.LEGIBLE
local eq, intersects, describe = S.eq, S.intersects, S.describe
local Saved, Batch, Part, Raid, CheckRoute, Content = S.Saved, S.Batch, S.Part, S.Raid, S.CheckRoute, S.Content
local _ = A

-- The Default preset, 20 then 40 players (test-groupframes-raid-presets.lua takes DPS, Tank and Healer).
S.Presets({ "Default" })
collectgarbage()

-- The owner's screen (2383 by 1540 at UI scale 768/1080, 1.426 pixels per unit): whole-pixel snapping must not floor
-- the 12-unit status lane under the legibility floor and switch the defensives off.
do
	local env, K, ns = G.New({ width = 2383, height = 1540, uiScale = 768 / 1080, saved = Saved({}) })
	G.SetRoster(env, "raid", G.Members(20))
	assert(K.Modules.Enable("GroupFrames"))
	env.RunTimers()
	S.Statuses(env, ns, Content(ns, ns.Headers.raid[1], "raid1"), "the owner's screen")
end

-- Grok #2: eight and twelve debuffs on the default tile read three icons and "+5", "+9" --------------------------------
do
	local env, _, _, f = Raid({}, 20)
	local seen = CheckRoute(env, f, { { 8, "other" } }, "eight others")
	eq(seen.chip, "+5", "eight debuffs on four cells: three shown and +5")
	seen = CheckRoute(env, f, { { 12, "other" } }, "twelve others")
	eq(seen.chip, "+9", "twelve debuffs: +9")
	-- Codex review: past the labels the chip saturates instead of vanishing.
	seen = CheckRoute(env, f, { { 16, "other" } }, "sixteen others")
	eq(seen.chip, "+13", "sixteen debuffs: +13, the last label")
	seen = CheckRoute(env, f, { { 17, "other" } }, "seventeen others")
	eq(seen.chip, "14+", "seventeen debuffs: 14+")
	seen = CheckRoute(env, f, { { 18, "other" } }, "eighteen others")
	eq(seen.chip, "14+", "eighteen debuffs: 14+, at least fourteen past the cells")
	seen = CheckRoute(env, f, { { 12, "boss" }, { 12, "important" }, { 12, "other" } }, "thirty-six")
	eq(seen.chip, "14+", "thirty-six debuffs: still 14+")
	seen = CheckRoute(env, f, { { 4, "other" } }, "four others")
	eq(seen.chip, nil, "four debuffs fill the four cells with no chip")
	-- The chip sits on the cluster's last cell, inside the tile, over the icons.
	local chip = f.debuffChip
	local block = f.parts.block
	local last = Part(env, f, { left = block.left + block.width - block.size, top = block.top + block.height - block.size, width = block.size, height = block.size })
	local win = { Scene.Rect(env, chip.window) }
	assert(math.abs(win[1] - last[1]) < 0.6 and math.abs(win[2] - last[2]) < 0.6 and math.abs(win[3] - last[3]) < 0.6, "the chip covers the last cell " .. describe(win) .. " " .. describe(last))
	assert(chip.window:GetFrameLevel() > f.auras:GetFrameLevel(), "the chip draws over the debuff icons")
	assert(chip.ghostHost:GetAlpha() == 0, "the counting container draws nothing")
	-- The counting container watches exactly what the row does.
	for key, group in pairs(f.auras._groups) do
		local ghost = chip.ghost._groups[key]
		assert(ghost, "the chip counts the " .. key .. " group")
		eq(ghost.filter, group.filter, key .. ": the same filter")
		eq(ghost.enabled, group.enabled, key .. ": on when the row's is")
		for field, value in pairs(group.candidateFilters or {}) do
			eq((ghost.candidateFilters or {})[field], value, key .. ": candidate " .. field)
		end
	end
	eq(chip.ghost._groups.dispels.maxFrameCount, f.auras._groups.dispels.maxFrameCount, "dispellable debuffs past the dispel count are the blue mark's, not the chip's")
	eq(#env._errors, 0, tostring(env._errors[1]))
end

-- Codex review: an indicator in the status lane keeps the smaller size the player picks.
do
	local env, K, ns, f = Raid({}, 5)
	Batch(env, K, { { "indicator1.size", 8 } })
	local place = ns.Slots.Placements(f)[1]
	assert(place.fits and place.size <= 8 + 0.01 and place.size >= 7, "a lane indicator set to 8 units is drawn at 8, got " .. place.size)
	eq(#env._errors, 0, tostring(env._errors[1]))
end

-- Muse: the missing health keeps clear of the boss slot and the debuffs ----------------------------------------------
for _, size in ipairs({ { 72, 40 }, { 77, 40 }, { 77, 46 } }) do
	local env, _, ns, f = Raid({ raid = { width = size[1], height = size[2] } }, 5, function(_, m)
		m.maxHealth = 41800
		m.health = 30600
	end)
	local scene = Scene.Build(env)
	local text
	for _, item in ipairs(scene.items) do
		if item.object == f.healthText then
			text = item
		end
	end
	assert(text and text.text and text.text:find("^%-"), "the missing health shows, got " .. tostring(text and text.text))
	local boss = f.highlights:GetAuraSlotFrame("boss")
	boss:Show()
	local bossRect = { Scene.Rect(env, boss) }
	boss:Hide()
	local gap = ns.Geometry.INSET
	local clear = { bossRect[1] - gap, bossRect[2], bossRect[3] + gap, bossRect[4] }
	assert(not intersects(text.rect, clear), size[1] .. " by " .. size[2] .. ": the missing health " .. describe(text.rect) .. " keeps a gap from the boss slot " .. describe(bossRect))
	assert(not intersects(text.rect, { Scene.Rect(env, f.auraClip) }), "and from the debuffs")
end

-- A configuration with no room says so in its settings row, with a remedy -----------------------------------------
do
	local env, K, ns = Raid({ raid = { width = 44, height = 26 } }, 5)
	-- Each indicator's rows end in two notes, one for party frames and one for raid frames.
	local notes, slot = {}, 0
	for _, row in ipairs(ns.Settings.schema) do
		if row.key and row.key:match("^indicator%d+%.category$") then
			slot = slot + 1
			notes[slot] = {}
		elseif row.type == "note" and slot > 0 then
			notes[slot][row.label:find("raid frames", 1, true) and "raid" or "party"] = row
		end
	end
	eq(#notes, ns.Settings.INDICATOR_SLOTS, "every indicator slot has its notes")
	local settings = K.Store.Module("GroupFrames")
	local function shown(i, kind)
		local row = assert(notes[i][kind], "indicator " .. i .. " has a " .. kind .. " note")
		return row.showWhen(settings) == true, row
	end
	local on, row = shown(1, "raid")
	assert(on, "a 44 by 26 raid tile has no room for the external defensives, and the note says so")
	assert(row.label:find("raid", 1, true), "the note names raid frames: " .. row.label)
	assert(not shown(4, "raid"), "an indicator that is off raises no note")
	Batch(env, K, { { "raid.width", 72 }, { "raid.height", 40 } })
	assert(not shown(1, "raid"), "at 72 by 40 the external defensives fit and the note goes")
end

-- Opus: the party's indicators are legible, at 40 and 46 units tall -------------------------------------------------
for _, height in ipairs({ 40, 46 }) do
	local env, K, ns = G.New({ saved = Saved({ party = { height = height } }) })
	G.SetRoster(env, "party", G.Members(4))
	assert(K.Modules.Enable("GroupFrames"))
	env.RunTimers()
	local f = Content(ns, ns.Headers.party, "party1")
	local plan = ns.Slots.Placements(f)
	for i = 1, 3 do
		assert(plan[i].fits, "party " .. height .. ": indicator " .. i .. " fits")
		assert(plan[i].size >= LEGIBLE, "party " .. height .. ": indicator " .. i .. " is at least " .. LEGIBLE .. " units, got " .. plan[i].size)
	end
	eq(#env._errors, 0, tostring(env._errors[1]))
end

print("groupframes raid status ok")
