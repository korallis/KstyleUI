-- test-groupframes-raid-tile.lua: the Medallions raid tile at the KSTY-47 mock-ups' three sizes (KSTY-57): a class-coloured bar filling the tile no thinner than the mock-up draws it (12, 11 and 9 units), the name on the fill in caps keeping its head, the percent at the bar's end, a row of debuff pips over the bar, no power line, role icon, boss slot or heals on the tile, Dead and Offline in the percent's place; and the party tank's heals on the name line, clear of its bar.
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

-- ShortOrWhole: the name is whole in the Medallions tile's caps, or, when even the text floor cannot hold it, its head;
-- never under the floor.
local function ShortOrWhole(f, full, what)
	local K = f._env.KstyleUI
	local text = f.name:GetText()
	full = K.Locale.Upper(full)
	local _, size = f.name:GetFont()
	local px = size * K.Widgets.ScaleFactor(f) / K.Scale.Pixel(1)
	assert(px >= K.Scale.TextFloor() - 0.01, what .. ": " .. full .. " is at least the " .. K.Scale.TextFloor() .. " px floor, got " .. px)
	if text == full then
		return
	end
	assert(#text >= 4 and full:sub(1, #text) == text, what .. ": " .. full .. " is whole or keeps its head, got " .. tostring(text))
	assert(size <= f.nameFit.min + 1e-6 or px <= K.Scale.TextFloor() + 0.01, what .. ": " .. full .. " shortens only at its smallest size")
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
	local px, pad = K.Scale.Pixel(1), K.Tokens.Size("gapSmall")

	-- The Medallions tile: the class-coloured bar fills the tile inside its padding, never thinner than the mock-up
	-- draws the bar, with no power line and no role icon.
	assert(bar[4] >= size.bar - px, what .. ": the bar is at least the mock-up's " .. size.bar .. " units tall, got " .. bar[4])
	assert(math.abs(bar[1] - (frame[1] + pad)) <= px and math.abs(bar[1] + bar[3] - (frame[1] + frame[3] - pad)) <= px, what .. ": the bar spans the tile " .. describe(bar))
	eq(f.power:IsShown(), false, what .. ": no power line")
	assert(f.roleInRing and not f.role:IsShown(), what .. ": no role icon on the tile")
	local scene = Scene.Build(env)
	local name = find(scene, f.name)
	assert(name and intersects(name.rect, bar), what .. ": the name draws on the fill")

	-- Debuffs: a row of pips over the bar's right end.
	local block = ns.Auras.Block(f, k)
	assert(block.cells >= 1 and block.rows == 1, what .. ": one row of debuff pips")
	local clip = { Scene.Rect(env, f.auraClip) }
	assert(intersects(clip, bar), what .. ": the debuffs " .. describe(clip) .. " overlay the bar " .. describe(bar))
	assert(not intersects(clip, name.rect), what .. ": clear of the name")

	-- The boss glow stays on; a Medallions raid tile shows none of your heals.
	assert(f.highlights and f.highlights:GetAuraSlotFrame("boss"), what .. ": a boss debuff slot exists")
	assert(f.highlights._slots.glowBoss and f.highlights._slots.glowBoss.enabled, what .. ": the boss glow stays on")
	local _, heals = ns.Auras.HealIcons(f, k)
	eq(heals, 0, what .. ": no heals on the tile")

	-- Long names keep their head in the tile's caps.
	for i = 1, #LONG do
		local member = content(ns, ns.Headers.raid[1], "raid" .. i)
		local text, whole = member.name:GetText(), K.Locale.Upper(LONG[i])
		assert(#text > 0 and whole:sub(1, #text) == text, what .. ": " .. LONG[i] .. " keeps its head, got " .. text)
	end
	if size.percent then
		eq(content(ns, ns.Headers.raid[2], "raid7").name:GetText(), "MEMBER7", what .. ": a short name stays whole")
	end

	-- The percent at the bar's end, on the fill, clear of the name and the debuffs; over 25 members there is none.
	if size.percent then
		local percent = find(scene, f.healthText)
		assert(percent, what .. ": the percent draws")
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
		ShortOrWhole(f, LONG[tonumber(case[1]:match("%d+"))], what .. ", beside the status")
	end
	eq(#env._errors, 0, tostring(env._errors[1]))
end

-- Codex review: the boss slot follows the player's debuff filter, though the Medallions tile lays it out nowhere; a
-- wide health format is never cut to its lane.
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
	assert(f.parts.boss == nil, "the Medallions tile lays out no boss slot")
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
	for _, region in ipairs({ tank.name, tank.healthText, tank.role }) do
		local item = find(scene, region)
		assert(item and not intersects(item.rect, heals), "party tank: the name line's " .. describe(item.rect) .. " keeps clear of your heals")
	end
	assert(tank.role:IsShown() and not tank.pipFill:IsShown(), "party tank: the shield shape carries the role")
	eq(#env._errors, 0, tostring(env._errors[1]))
end

print("groupframes raid tile ok")
