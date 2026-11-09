-- test-groupframes-raid-tile.lua: the raid tile at Cell's standard (rank R5 T1): a whole name lane over a full-width health bar that fills most of the tile, debuffs at 12 units over the bar's right end, a centred 16-unit boss slot, the deficit in its own micro lane on the bar, Dead and Offline off the name lane, your heals never on the fill; and the party tank's heals on the name line, never in the pill's row.
local G = dofile("Tools/regression/group_env.lua")
local Scene = dofile("Tools/render/scene.lua")

local SIZES = { { width = 72, height = 40 }, { width = 77, height = 40 }, { width = 77, height = 46 } }
local LONG = { "Thaldrenwick", "Brightblades", "Dreadwalkers", "Hammerfeldt", "Kragar" }

local function eq(got, want, what)
	assert(got == want, what .. ": want " .. tostring(want) .. ", got " .. tostring(got))
end

local function intersects(a, b)
	return a[1] < b[1] + b[3] - 0.01 and b[1] < a[1] + a[3] - 0.01 and a[2] < b[2] + b[4] - 0.01 and b[2] < a[2] + a[4] - 0.01
end

local function describe(r)
	return string.format("[x %.1f to %.1f, y %.1f to %.1f]", r[1], r[1] + r[3], r[2], r[2] + r[4])
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

local function find(scene, object)
	for _, item in ipairs(scene.items) do
		if item.object == object then
			return item
		end
	end
end

local function saved(settings)
	return { version = 2, profiles = { Default = { GroupFrames = settings } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }
end

local function Raid(size, extra)
	local settings = { enabled = true, raid = { width = size.width, height = size.height } }
	local env, K, ns = G.New({ saved = saved(settings) })
	G.SetRoster(env, "raid", G.Members(6, function(i, m)
		m.name = LONG[i] or m.name
		m.health = 60
		if extra then
			extra(i, m)
		end
	end))
	assert(K.Modules.Enable("GroupFrames"))
	env.RunTimers()
	return env, K, ns
end

-- The name lane: the band from the tile's top to the bar, across the whole tile.
local function NameLane(env, f)
	local frame = { Scene.Rect(env, f) }
	local bar = { Scene.Rect(env, f.health) }
	return { frame[1], frame[2], frame[3], bar[2] - frame[2] }
end

for _, size in ipairs(SIZES) do
	local what = "raid " .. size.width .. " by " .. size.height
	local env, _, ns = Raid(size)
	local f = content(ns, ns.Headers.raid[1], "raid1")
	local k = ns.Settings.current.raid
	local frame = { Scene.Rect(env, f) }
	local bar = { Scene.Rect(env, f.health) }
	local pad = ns.Geometry.INSET

	-- Opus #1, Muse #1: health fills most of the tile, at its full width under the name lane.
	assert(bar[3] * bar[4] >= 0.45 * frame[3] * frame[4], what .. ": the bar " .. describe(bar) .. " covers at least 45% of the tile " .. describe(frame))
	assert(bar[4] >= 0.55 * frame[4] - 0.01, what .. ": the bar is at least 55% of the tile's height, got " .. bar[4])
	assert(math.abs(bar[1] - (frame[1] + pad)) < 0.01 and math.abs(bar[1] + bar[3] - (frame[1] + frame[3] - pad)) < 0.01, what .. ": the bar spans the tile's width " .. describe(bar))

	-- Debuffs: 12 units or more, four of them, over the bar's right end.
	local block = ns.Auras.Block(f, k)
	assert(block.size >= 12, what .. ": debuff icons are at least 12 units, got " .. block.size)
	eq(block.cells, 4, what .. ": four debuffs show")
	local clip = { Scene.Rect(env, f.auraClip) }
	assert(intersects(clip, bar), what .. ": the debuffs " .. describe(clip) .. " overlay the bar " .. describe(bar))
	assert(math.abs(clip[1] + clip[3] - (bar[1] + bar[3])) < 0.01, what .. ": at the bar's right end")

	-- A centred boss slot at 16 units, with the boss glow kept.
	local slot = f.highlights and f.highlights:GetAuraSlotFrame("boss")
	assert(slot, what .. ": a boss debuff slot exists")
	local candidates = f.highlights._slots.boss.candidateFilters
	assert(candidates and candidates.isBossAura == true, what .. ": it takes boss debuffs")
	assert(f.highlights._slots.boss.enabled, what .. ": and it is on")
	slot:Show()
	local boss = { Scene.Rect(env, slot) }
	assert(math.abs(boss[3] - 16) < 0.01, what .. ": the boss slot is 16 units, got " .. boss[3])
	assert(math.abs(boss[1] + boss[3] / 2 - (bar[1] + bar[3] / 2)) < 0.6, what .. ": centred on the bar " .. describe(boss))
	assert(math.abs(boss[2] + boss[4] / 2 - (bar[2] + bar[4] / 2)) < 0.6, what .. ": vertically too")
	assert(not intersects(boss, clip), what .. ": the boss slot and the debuffs keep apart")
	assert(f.highlights._slots.glowBoss and f.highlights._slots.glowBoss.enabled, what .. ": the boss glow stays on")
	slot:Hide()

	-- Your heals keep off the fill: on the name line, never on the bar, two or more of them.
	local _, heals = ns.Auras.HealIcons(f, k)
	assert(heals >= 2, what .. ": two or more of your heals have room, got " .. heals)
	local healRect = { Scene.Rect(env, f.buffClip) }
	assert(not intersects(healRect, bar), what .. ": your heals " .. describe(healRect) .. " never paint on the bar " .. describe(bar))

	-- Grok #2, Muse #1: names up to 12 letters stay whole, stepping the size down before any ellipsis.
	local scene = Scene.Build(env)
	local lane = NameLane(env, f)
	for i = 1, #LONG do
		local member = content(ns, ns.Headers.raid[1], "raid" .. i)
		eq(member.name:GetText(), LONG[i], what .. ": " .. LONG[i] .. " is whole")
		local item = find(scene, member.name)
		local own = { Scene.Rect(env, member.buffClip) }
		assert(item and not intersects(item.rect, own), what .. ": " .. LONG[i] .. " " .. describe(item.rect) .. " keeps clear of the heals " .. describe(own))
	end
	local _, nameSize = f.name:GetFont()
	assert(nameSize >= 8, what .. ": a long name steps down no further than 8, got " .. tostring(nameSize))

	-- The deficit has its own micro lane on the bar, out of the name lane, clear of the debuffs and the boss slot.
	local deficit = find(scene, f.healthText)
	assert(deficit, what .. ": the deficit draws")
	assert(not intersects(deficit.rect, lane), what .. ": the deficit " .. describe(deficit.rect) .. " is out of the name lane " .. describe(lane))
	assert(not intersects(deficit.rect, clip) and not intersects(deficit.rect, boss), what .. ": and clear of the debuffs and the boss slot")
	eq(#env._errors, 0, tostring(env._errors[1]))
end

-- Dead and Offline go in the status lane, never the name lane.
do
	local env, _, ns = Raid(SIZES[1], function(i, m)
		if i == 2 then
			m.dead, m.health = true, 0
		elseif i == 3 then
			m.online = false
		end
	end)
	local scene = Scene.Build(env)
	for _, case in ipairs({ { "raid2", "Dead" }, { "raid3", "Offline" } }) do
		local f = content(ns, ns.Headers.raid[1], case[1])
		eq(f.healthText:GetText(), case[2], case[1] .. ": says " .. case[2])
		local item = find(scene, f.healthText)
		assert(item, case[1] .. ": the status draws")
		assert(not intersects(item.rect, NameLane(env, f)), case[1] .. ": \"" .. case[2] .. "\" " .. describe(item.rect) .. " stays out of the name lane")
		eq(f.name:GetText(), LONG[tonumber(case[1]:match("%d+"))], case[1] .. ": the name stays whole beside the status")
	end
	eq(#env._errors, 0, tostring(env._errors[1]))
end

-- Codex review: the boss slot follows the player's debuff filter; "On the bar" health text keeps clear of the boss
-- slot; a wide health format is never cut to its lane.
do
	local settings = { enabled = true, auras = { filter = "DISPELLABLE" }, raid = { healthTextPlace = "BAR" } }
	local env, K, ns = G.New({ saved = saved(settings) })
	G.SetRoster(env, "raid", G.Members(5, function(_, m)
		m.health = 30
	end))
	assert(K.Modules.Enable("GroupFrames"))
	env.RunTimers()
	local f = content(ns, ns.Headers.raid[1], "raid1")
	eq(f.highlights._slots.boss.filter, "HARMFUL|RAID", "the boss slot takes the selected filter")
	local slot = f.highlights:GetAuraSlotFrame("boss")
	slot:Show()
	local scene = Scene.Build(env)
	local text = find(scene, f.healthText)
	assert(text and not intersects(text.rect, { Scene.Rect(env, slot) }), "on the bar, the health text " .. describe(text.rect) .. " keeps clear of the boss slot")
	slot:Hide()
	for _, case in ipairs({ { "CURRENT_MAX", "88.8k / 88.8k" }, { "CURRENT_PERCENT", "88.8k  100%" } }) do
		K.Options.Write("GroupFrames", "raid.healthText", case[1])
		env.RunTimers()
		local path, size = f.healthText:GetFont()
		assert(f.healthText:GetWidth() + 0.5 >= Scene.TextWidth(case[2], size, path), case[1] .. ": the lane holds its widest value whole, width " .. f.healthText:GetWidth())
	end
	eq(#env._errors, 0, tostring(env._errors[1]))
end

-- Grok R5 #1: the party tank with three of your heals and heals on. Their rects never met the bar in round 4, yet the
-- icons sat in the pill's own row, 4 units past a dark track the glass swallows, so they read as the bar's end. Your
-- heals now ride the name line: wholly above the pill, with the pill free to run the row.
do
	local env, K, ns = G.New({ saved = saved({ enabled = true, party = { buffCount = 3 }, buffs = { enabled = true } }) })
	G.SetRoster(env, "party", { { name = "Thaldren", class = "WARRIOR", role = "TANK", health = 72 } })
	assert(K.Modules.Enable("GroupFrames"))
	env.RunTimers()
	local tank = content(ns, ns.Headers.party, "party1")
	local k = ns.Settings.current.party
	local _, count = ns.Auras.HealIcons(tank, k)
	eq(count, 3, "party tank: all three of your heals have room")
	local heals = { Scene.Rect(env, tank.buffClip) }
	local bar = { Scene.Rect(env, tank.health) }
	assert(heals[2] + heals[4] <= bar[2] - ns.Geometry.PAD + 0.01, "party tank: your heals " .. describe(heals) .. " sit wholly above the pill " .. describe(bar) .. ", not in its row")
	local frame = { Scene.Rect(env, tank) }
	assert(heals[1] + heals[3] <= frame[1] + frame[3] + 0.01, "party tank: inside the row")
	local scene = Scene.Build(env)
	for _, region in ipairs({ tank.name, tank.classLine }) do
		local item = find(scene, region)
		assert(item and not intersects(item.rect, heals), "party tank: the name line's text " .. describe(item.rect) .. " keeps clear of your heals")
	end
	assert(not tank.role:IsShown(), "party tank: the role ring carries the role, so no second role icon sits where the heals go")
	eq(#env._errors, 0, tostring(env._errors[1]))
end

print("groupframes raid tile ok")
