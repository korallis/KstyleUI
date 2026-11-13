-- test-groupframes-raid-tile.lua: the raid row at the KSTY-47 mock-ups' three sizes (KSTY-57): a name line with the role pip, a name, whole or shortened, and the percent at the bar's end, a full-width bar no thinner than the mock-up draws it (12, 11 and 9 units), a thin power line under it at 10 and 20, debuffs over the bar's right end, a centred boss slot where the bar holds one, Dead and Offline in the percent's place or on the emptied bar, your heals never on the fill; and the party tank's heals on the name line, clear of its bar.
local G = dofile("Tools/regression/group_env.lua")
local Scene = dofile("Tools/render/scene.lua")

local SIZES = {
	{ members = 10, bar = 12, power = 3, percent = true },
	{ members = 20, bar = 11, power = 2, percent = true },
	{ members = 40, bar = 9 },
}
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

local function Raid(count, extra, settings)
	local env, K, ns = G.New({ saved = saved(settings or { enabled = true }) })
	G.SetRoster(env, "raid", G.Members(count, function(i, m)
		m.name = LONG[i] or m.name
		m.health = 60
		m.role = ({ "TANK", "HEALER", "DAMAGER", "DAMAGER", "DAMAGER" })[(i - 1) % 5 + 1]
		if extra then
			extra(i, m)
		end
	end))
	assert(K.Modules.Enable("GroupFrames"))
	env.RunTimers()
	return env, K, ns
end

for _, size in ipairs(SIZES) do
	local what = "raid of " .. size.members
	local env, K, ns = Raid(size.members)
	local f = content(ns, ns.Headers.raid[1], "raid1")
	local k = ns.Settings.current.raid
	local frame = { Scene.Rect(env, f) }
	local bar = { Scene.Rect(env, f.health) }
	local px, edge = K.Scale.Pixel(1), ns.Geometry.EDGE

	-- The bar spans the row inside its rim's room and is never thinner than the mock-up draws it.
	assert(bar[4] >= size.bar - px, what .. ": the bar is at least the mock-up's " .. size.bar .. " units tall, got " .. bar[4])
	assert(math.abs(bar[1] - (frame[1] + edge)) <= px and math.abs(bar[1] + bar[3] - (frame[1] + frame[3] - edge)) <= px, what .. ": the bar spans the row " .. describe(bar))
	-- The name line sits over the bar: the pip, the name and the percent.
	local scene = Scene.Build(env)
	local pip, name = find(scene, f.pipEdge), find(scene, f.name)
	assert(pip and name, what .. ": the pip and the name draw")
	for _, item in ipairs({ pip, name }) do
		assert(item.rect[2] + item.rect[4] <= bar[2] + 0.01, what .. ": " .. describe(item.rect) .. " sits on the name line over the bar")
	end
	assert(pip.rect[1] + pip.rect[3] <= name.rect[1] + 0.01, what .. ": the pip comes before the name")
	-- The power line: under the bar at its width at 10 and 20, none at 40.
	if size.power then
		eq(k.power, true, what .. ": a power line")
		local power = { Scene.Rect(env, f.power) }
		assert(math.abs(power[4] - size.power) <= px, what .. ": " .. size.power .. " units thin, got " .. power[4])
		assert(power[2] >= bar[2] + bar[4] - 0.01 and math.abs(power[3] - bar[3]) <= px, what .. ": under the bar, at its width")
	else
		eq(f.power:IsShown(), false, what .. ": no power line")
	end

	-- Debuffs: three of them at 12 units over the bar's right end.
	local block = ns.Auras.Block(f, k)
	assert(block.size >= 12, what .. ": debuff icons are at least 12 units, got " .. block.size)
	eq(block.cells, 3, what .. ": three debuffs show")
	local clip = { Scene.Rect(env, f.auraClip) }
	assert(intersects(clip, bar), what .. ": the debuffs " .. describe(clip) .. " overlay the bar " .. describe(bar))
	assert(math.abs(clip[1] + clip[3] - (bar[1] + bar[3])) <= px, what .. ": at the bar's right end")
	assert(clip[2] >= name.rect[2] + name.rect[4] - 0.01, what .. ": below the name line")

	-- A centred boss slot where the bar holds one, with the boss glow kept.
	local slot = f.highlights and f.highlights:GetAuraSlotFrame("boss")
	assert(slot, what .. ": a boss debuff slot exists")
	assert(f.highlights._slots.glowBoss and f.highlights._slots.glowBoss.enabled, what .. ": the boss glow stays on")
	if f.parts.boss then
		slot:Show()
		local boss = { Scene.Rect(env, slot) }
		assert(boss[3] >= ns.Geometry.MIN_ICON - px, what .. ": the boss slot is at least " .. ns.Geometry.MIN_ICON .. " units, got " .. boss[3])
		assert(math.abs(boss[1] + boss[3] / 2 - (bar[1] + bar[3] / 2)) < 1, what .. ": centred on the bar " .. describe(boss))
		assert(math.abs(boss[2] + boss[4] / 2 - (bar[2] + bar[4] / 2)) < 1, what .. ": vertically too")
		assert(not intersects(boss, clip), what .. ": the boss slot and the debuffs keep apart")
		slot:Hide()
	else
		assert(size.bar < 2 * 1 + ns.Geometry.MIN_ICON, what .. ": only a bar too thin for a legible boss icon goes without the slot")
	end

	-- Your heals keep off the fill: on the name line, never on the bar.
	local _, heals = ns.Auras.HealIcons(f, k)
	assert(heals >= 1, what .. ": your heals have room, got " .. heals)
	local healRect = { Scene.Rect(env, f.buffClip) }
	assert(not intersects(healRect, bar), what .. ": your heals " .. describe(healRect) .. " never paint on the bar " .. describe(bar))

	-- Grok #2, Muse #1: a name steps its size down before any ellipsis. KSTY-60 item 11 sets raid names in the party's
	-- Cinzel names face, which no 12-letter name fits at these widths, so a long name ends shortened, never spilled.
	for i = 1, #LONG do
		local member = content(ns, ns.Headers.raid[1], "raid" .. i)
		local shown = member.name:GetText()
		local head = shown:match("^(.-)%.%.%.$")
		assert(shown == LONG[i] or (head and #head >= 3 and LONG[i]:sub(1, #head) == head), what .. ": " .. LONG[i] .. " is whole or shortened from its start, got " .. tostring(shown))
		local item = find(scene, member.name)
		local own = { Scene.Rect(env, member.buffClip) }
		assert(item and not intersects(item.rect, own), what .. ": " .. LONG[i] .. " " .. describe(item.rect) .. " keeps clear of the heals " .. describe(own))
	end
	local _, nameSize = f.name:GetFont()
	assert(nameSize >= 8, what .. ": a long name steps down no further than 8, got " .. tostring(nameSize))

	-- The percent: at the name line's end, ending at the bar's end, clear of the name, the debuffs and the boss slot.
	-- Over 25 members there is none, as the 40-player mock-up draws it.
	if size.percent then
		local percent = find(scene, f.healthText)
		assert(percent, what .. ": the percent draws")
		assert(percent.rect[2] + percent.rect[4] <= bar[2] + 0.01, what .. ": the percent " .. describe(percent.rect) .. " sits on the name line")
		assert(math.abs(percent.rect[1] + percent.rect[3] - (bar[1] + bar[3])) <= 1, what .. ": at the bar's end")
		assert(not intersects(percent.rect, name.rect) and not intersects(percent.rect, clip), what .. ": clear of the name and the debuffs")
	else
		eq(k.healthText, "NONE", what .. ": no percent")
	end
	eq(#env._errors, 0, tostring(env._errors[1]))
end

-- Dead and Offline never go in the name: in the percent's place at the row's end, or centred on the emptied bar when
-- the row has no percent.
for _, size in ipairs(SIZES) do
	local env, _, ns = Raid(size.members, function(i, m)
		if i == 2 then
			m.dead, m.health = true, 0
		elseif i == 3 then
			m.online = false
		end
	end)
	local scene = Scene.Build(env)
	for _, case in ipairs({ { "raid2", "Dead" }, { "raid3", "Offline" } }) do
		local what = "raid of " .. size.members .. ", " .. case[1]
		local f = content(ns, ns.Headers.raid[1], case[1])
		eq(f.healthText:GetText(), case[2], what .. ": says " .. case[2])
		local item = find(scene, f.healthText)
		assert(item, what .. ": the status draws")
		assert(not intersects(item.rect, find(scene, f.name).rect), what .. ": " .. case[2] .. " " .. describe(item.rect) .. " stays out of the name")
		local long, shown = LONG[tonumber(case[1]:match("%d+"))], f.name:GetText()
		local head = shown:match("^(.-)%.%.%.$")
		assert(shown == long or (head and #head >= 3 and long:sub(1, #head) == head), what .. ": the name beside the status is whole or shortened from its start, got " .. tostring(shown))
	end
	eq(#env._errors, 0, tostring(env._errors[1]))
end

-- Codex review: the boss slot follows the player's debuff filter; the health text keeps clear of the boss slot in
-- either place setting (KSTY-57's lanes keep it on the name line); a wide health format is never cut to its lane.
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
		assert(env.Look(f.healthText:GetWidth()) + 0.5 >= Scene.TextWidth(case[2], size, path), case[1] .. ": the lane holds its widest value whole, width " .. env.Look(f.healthText:GetWidth()))
	end
	eq(#env._errors, 0, tostring(env._errors[1]))
end

-- Grok R5 #1: the party tank with three of your heals and heals on. Their rects never met the bar in round 4, yet the
-- icons sat in the bar's own row, so they read as the bar's end. Your heals ride the name line: wholly above the bar.
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
	assert(heals[2] + heals[4] <= bar[2] - ns.Geometry.PAD + 0.01, "party tank: your heals " .. describe(heals) .. " sit wholly above the bar " .. describe(bar) .. ", not in its row")
	local frame = { Scene.Rect(env, tank) }
	assert(heals[1] + heals[3] <= frame[1] + frame[3] + 0.01, "party tank: inside the row")
	local scene = Scene.Build(env)
	for _, region in ipairs({ tank.name, tank.healthText, tank.pipEdge }) do
		local item = find(scene, region)
		assert(item and not intersects(item.rect, heals), "party tank: the name line's " .. describe(item.rect) .. " keeps clear of your heals")
	end
	assert(not tank.role:IsShown(), "party tank: the pip carries the role, so no role atlas sits on the name line")
	eq(#env._errors, 0, tostring(env._errors[1]))
end

print("groupframes raid tile ok")
