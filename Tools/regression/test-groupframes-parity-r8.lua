-- test-groupframes-parity-r8.lua: EllesmereUI parity round 8: a v0.2.8 profile keeps every new default; the name line under the bar on party and raid rows in both HUD styles, and party heal icons outside the frame, each on and off with combat, the holder, party targets and the preview. FrameSort's order is in test-groupframes-parity-r8-sort.lua.
local H = dofile("Tools/regression/groupframes_r3a.lua")
local G = H.G
local write, frame, noErrors, boot = H.write, H.frame, H.noErrors, H.boot

local KEYS = { "name", "health", "power", "healRow", "lane", "indicatorLane", "block", "boss" }
local function snapshot(f)
	local out, icons = {}, f.parts.icons or {}
	for _, key in ipairs(KEYS) do
		local r = f.parts[key]
		out[#out + 1] = r and (r.left .. ":" .. r.top .. ":" .. r.width .. ":" .. r.height) or "-"
	end
	for _, key in ipairs({ "role", "leader", "marker" }) do
		local r = icons[key]
		out[#out + 1] = r and (r.left .. ":" .. r.top) or "-"
	end
	return table.concat(out, "|") .. "|" .. tostring(f.parts.healthText and f.parts.healthText.top)
end

local function apart(env, a, b, what)
	local dx, dy = H.overlap(env, a, b)
	assert(dx <= 1e-3 or dy <= 1e-3, what .. " overlap by " .. dx .. " x " .. dy)
end

local function under(env, f, kind, style)
	local p = f.parts
	local low = p.power or p.health
	assert(p.below and p.name.top >= low.top + low.height - 1e-6 and p.health.top < p.name.top, style .. " " .. kind .. ": the name line sits under the bars")
	apart(env, f.name, f.health, style .. " " .. kind .. ": name and health bar")
	if f.showPower then apart(env, f.name, f.power, style .. " " .. kind .. ": name and power bar") end
	if f.healthText:IsShown() and not p.nameInside and p.healthText.right then
		assert(p.healthText.top >= low.top + low.height - 1e-6, style .. " " .. kind .. ": the health text rides the name line")
	end
	local lane = p.lane or p.indicatorLane
	if lane and lane.count and lane.count > 0 and lane.top + lane.height <= p.health.top + 1e-6 then
		error(style .. " " .. kind .. ": an indicator lane was left above the bar")
	end
end

-- A v0.2.8-shaped profile keeps every new default.
do
	local env, K, ns = boot({ saved = H.saved({ party = { width = 259, sortBy = "INDEX" }, names = { divider = false } }) })
	local get = ns.Settings.Get
	assert(get("names.bottom") == false and get("party.buffAnchor") == "FRAME" and get("party.sortBy") == "INDEX" and get("raid.sortBy") == "GROUP", "every new option starts at today's behaviour")
	local f = frame(ns, "party1")
	assert(not f.parts.below and not (f.parts.healRow and f.parts.healRow.outside), "the name stays above the bar and the heals on the frame")
	local geo = ns.Geometry.Party(ns.Settings.current.party)
	assert(geo.heal == 0 and geo.healSide == nil, "the holder keeps no heal lane")
	noErrors(env, K)
end
collectgarbage()

-- The name line under the bar, party and raid rows, Medallions and Frames: every lane on the name line moves with it, nothing
-- crosses the bars, the divider follows, combat waits, the preview follows and off restores every part exactly.
for _, style in ipairs({ "medallions", "frames" }) do
	local env, K, ns = boot({})
	K.Options.Write("HudStyle", "style", style)
	env.RunTimers()
	local f = frame(ns, "party1")
	local before, portrait = snapshot(f), ns.Settings.Get("party.portrait")
	write(env, K, "names.bottom", true)
	under(env, f, "party", style)
	write(env, K, "party.portrait", not portrait)
	under(env, f, "party, portraits switched", style)
	local row = snapshot(f)
	write(env, K, "names.divider", true)
	local low = f.parts.power or f.parts.health
	local point, rel, relPoint, _, y = f.nameDivider:GetPoint(1)
	assert(f.nameDivider:IsShown() and point == "TOPLEFT" and rel == f and relPoint == "TOPLEFT" and H.near(y, -K.Widgets.Snap(f, low.top + low.height)), style .. ": the divider sits between the bars and the name")
	write(env, K, "names.divider", false)
	env.SetCombat(true)
	write(env, K, "names.bottom", false)
	assert(snapshot(f) == row and #env._blocked == 0, style .. ": in combat the change waits without a protected call")
	env.SetCombat(false)
	env.RunTimers()
	write(env, K, "party.portrait", portrait)
	assert(snapshot(f) == before and not f.parts.below, style .. ": off restores every part exactly")
	write(env, K, "names.bottom", true)
	local pv = H.preview(env, K)
	pv:Refresh()
	assert(pv.partyFrames[1].parts.below, style .. ": the preview's samples follow")
	G.SetRoster(env, "raid", G.Members(10))
	env.RunTimers()
	write(env, K, "raid.textLayout", "ABOVE")
	local r = frame(ns, "raid1")
	under(env, r, "raid", style)
	write(env, K, "raid.power", true)
	under(env, r, "raid with power", style)
	write(env, K, "names.bottom", false)
	assert(not r.parts.below and r.parts.name.top < r.parts.health.top, style .. ": raid rows go back above")
	noErrors(env, K)
	collectgarbage()
end

local function holder(ns)
	local h = ns.Headers.holders.party
	return h:GetWidth(), h:GetHeight()
end

-- Party heal icons outside the frame: right or left of stacked frames, past the outside debuffs and before party targets and
-- pets beside; above frames side by side; the holder makes room, the name takes its line back, combat waits and off restores.
for _, style in ipairs({ "medallions", "frames" }) do
	local env, K, ns = boot({})
	K.Options.Write("HudStyle", "style", style)
	env.RunTimers()
	local f = frame(ns, "party1")
	local before, w0, h0 = snapshot(f), holder(ns)
	local point0 = H.point(ns.Headers.party)
	local name0 = f.parts.name.width
	write(env, K, "party.buffAnchor", "RIGHT")
	local row, k = f.parts.healRow, ns.Settings.current.party
	local lane = ns.Geometry.AuraLane(k)
	assert(row.outside and row.side == "LEFT" and row.left >= f.width + lane, style .. ": the heals sit right of the frame, past the outside debuffs")
	apart(env, f.buffClip, f, style .. ": heals and the frame")
	apart(env, f.buffClip, f.auraClip, style .. ": heals and debuffs")
	local w1 = holder(ns)
	assert(w1 - w0 >= ns.Geometry.HealLane(k) - 1, style .. ": the holder makes room")
	if style == "frames" then assert(f.parts.name.width > name0, "frames: the name takes the heals' place back") end
	write(env, K, "targets.enabled", true)
	assert(ns.Targets.Spot(f, k) >= row.left + row.width, style .. ": party targets sit past the heals")
	write(env, K, "targets.enabled", false)
	write(env, K, "party.buffAnchor", "LEFT")
	row = f.parts.healRow
	assert(row.outside and row.side == "RIGHT" and row.left + row.width <= 0, style .. ": left of the frame")
	apart(env, f.buffClip, f, style .. ": left heals and the frame")
	local x = select(4, ns.Headers.party:GetPoint(1))
	assert(x >= ns.Geometry.HealLane(k) - 1, style .. ": the frames move right inside the holder")
	write(env, K, "party.growth", "RIGHT")
	row = f.parts.healRow
	assert(row.outside and row.top + row.height <= 0, style .. ": frames side by side put the heals above")
	local _, h2 = holder(ns)
	local y = select(5, ns.Headers.party:GetPoint(1))
	assert(y < 0 and h2 > ns.Settings.current.party.height, style .. ": the holder grows upward and the frames move down")
	local pv = H.preview(env, K)
	pv:Refresh()
	assert(pv.partyFrames[1].parts.healRow.outside, style .. ": the preview's samples follow")
	write(env, K, "party.growth", "DOWN")
	write(env, K, "buffs.enabled", false)
	assert(H.near(holder(ns), w0), style .. ": with heals off the holder keeps no lane")
	write(env, K, "buffs.enabled", true)
	env.SetCombat(true)
	write(env, K, "party.buffAnchor", "FRAME")
	assert(f.parts.healRow.outside and #env._blocked == 0, style .. ": in combat the change waits")
	env.SetCombat(false)
	env.RunTimers()
	local w3, h3 = holder(ns)
	assert(snapshot(f) == before and H.near(w3, w0) and H.near(h3, h0) and H.point(ns.Headers.party) == point0, style .. ": off restores the frame, the holder and the header")
	noErrors(env, K)
	collectgarbage()
end

print("groupframes parity round 8 ok: names under the bar, heal icons outside the frame")
