-- test-groupframes-parity-r4.lua: EllesmereUI parity round 4: v0.2.8 profiles keep every default and build nothing new; role place, icon offsets, missing buff glow and offsets, name line height, heal icon offsets, class order, class first and centred groups each apply when on, follow their events and combat, reach the preview and switch back exactly.
local H = dofile("Tools/regression/groupframes_r3a.lua")
local G, MODULE = H.G, H.MODULE
local write, frame, noErrors = H.write, H.frame, H.noErrors

local function saved(own)
	own = own or {}
	own.enabled = true
	return { version = 42, profiles = { Default = { [MODULE] = own } }, characters = {}, layouts = {} }
end

local function point(region)
	local p, rel, relPoint, x, y = region:GetPoint(1)
	return table.concat({ tostring(p), tostring(rel), tostring(relPoint), tostring(x), tostring(y) }, " ")
end

local function offset(region)
	local _, _, _, x, y = region:GetPoint(1)
	return x, y
end

local function near(a, b)
	return math.abs(a - b) < 1e-3
end

local function moved(region, write1, dx, dy, label)
	local x0, y0 = offset(region)
	write1()
	local x1, y1 = offset(region)
	assert(near(x1 - x0, dx) and near(y1 - y0, dy), label .. " moves " .. dx .. ", " .. dy .. ": got " .. (x1 - x0) .. ", " .. (y1 - y0))
end

local function boot(setup)
	local env, K, ns = G.New({ setup = setup or H.setup })
	H.party(env)
	K.Modules.Enable(MODULE)
	env.RunTimers()
	return env, K, ns
end

-- A v0.2.8-shaped profile keeps every default and builds nothing new.
do
	local env, K, ns = G.New({ saved = saved({ party = { width = 259 }, icons = { role = true } }), setup = H.setup })
	H.party(env)
	K.Modules.Enable(MODULE)
	env.RunTimers()
	local get = ns.Settings.Get
	assert(get("icons.rolePlace") == "AUTO" and get("icons.roleX") == 0 and get("icons.markerY") == 0 and get("icons.readyX") == 0 and get("icons.combatY") == 0, "icons keep their places")
	assert(get("reminders.glow") == false and get("reminders.x") == 0 and get("status.y") == 0 and get("dispel.x") == 0, "missing buffs, status text and the type icon stay put without a glow")
	assert(get("names.height") == 0 and get("party.buffX") == 0 and get("raid.buffY") == 0 and get("raid.center") == false, "the name line, heal icons and raid groups keep today's layout")
	assert(get("sort.classFirst") == false, "class first starts off")
	for i, class in ipairs(env.CLASS_SORT_ORDER) do assert(get("sort.class" .. i) == class, "the class order is the game's") end
	local f = frame(ns, "party1")
	assert(f.reminder == nil and f.role:GetPoint(1) == "TOPLEFT" and select(2, f.role:GetPoint(1)) == f, "the role icon keeps its lane and nothing new is made")
	assert(ns.Headers.party:GetAttribute("groupBy") == nil, "party frames keep group order")
	noErrors(env, K)
end
collectgarbage()

-- Role icon place pins the icon on the bar at its size, the letters follow it, offsets move it and Automatic restores it.
do
	local env, K, ns = boot()
	local f = frame(ns, "party1")
	local lane = point(f.role)
	write(env, K, "icons.rolePlace", "TOPRIGHT")
	local p, rel, relPoint = f.role:GetPoint(1)
	assert(p == "TOPRIGHT" and rel == f.health and relPoint == "TOPRIGHT" and f.role:IsShown(), "the role icon sits on the bar's top right")
	assert(H.width(env, f.role) <= H.reveal(env, f.health:GetHeight()) + 1e-3, "never taller than the bar")
	moved(f.role, function() write(env, K, "icons.roleX", -6) write(env, K, "icons.roleY", 3) end, -6, 3, "the role icon")
	write(env, K, "icons.roleText", true)
	assert(select(2, f.roleLetter:GetPoint(1)) == f.role and f.roleLetter:IsShown(), "role letters ride the placed icon")
	env._roster.units.party1.role = "HEALER"
	env.FireEvent("PLAYER_ROLES_ASSIGNED")
	env.RunTimers()
	assert(f.roleLetter:GetText() == "H" and select(2, f.roleLetter:GetPoint(1)) == f.role, "a role change keeps the place")
	write(env, K, "icons.roleText", false)
	env.SetCombat(true)
	write(env, K, "icons.rolePlace", "AUTO")
	env.SetCombat(false)
	env.RunTimers()
	write(env, K, "icons.roleX", 0)
	write(env, K, "icons.roleY", 0)
	assert(point(f.role) == lane, "Automatic restores the lane exactly, after combat")
	noErrors(env, K)
end
collectgarbage()

-- Offsets move the raid marker, ready check, combat icon, status text, type icon and missing buff by the units chosen.
do
	local env, K, ns = boot()
	local f = frame(ns, "party1")
	write(env, K, "icons.markerPlace", "LEFT")
	moved(f.marker, function() write(env, K, "icons.markerX", 5) end, 5, 0, "the raid marker")
	write(env, K, "icons.readyPlace", "RIGHT")
	moved(f.ready, function() write(env, K, "icons.readyY", -4) end, 0, -4, "the ready check")
	moved(f.statusIcons.afk, function() write(env, K, "icons.readyX", 2) end, 2, 0, "the AFK icon with it")
	write(env, K, "icons.combat", true)
	moved(f.combatIcon, function() write(env, K, "icons.combatX", 7) write(env, K, "icons.combatY", 2) end, 7, 2, "the combat icon")
	write(env, K, "dispel.icon", "TOPRIGHT")
	moved(f.typeIcon, function() write(env, K, "dispel.x", -3) end, -3, 0, "the type icon")
	write(env, K, "reminders.place", "TOPRIGHT")
	moved(f.reminder, function() write(env, K, "reminders.y", -2) end, 0, -2, "the missing buff beside the type icon")
	write(env, K, "status.place", "CENTER")
	env._roster.units.party1.dead = true
	env.FireEvent("UNIT_HEALTH", "party1")
	env.RunTimers()
	moved(f.healthText, function() write(env, K, "status.x", 9) end, 9, 0, "Dead")
	for _, key in ipairs({ "icons.markerX", "icons.readyX", "icons.readyY", "icons.combatX", "icons.combatY", "dispel.x", "reminders.y", "status.x" }) do
		write(env, K, key, 0)
	end
	local _, _, _, mx = f.marker:GetPoint(1)
	local _, _, _, sx = f.healthText:GetPoint(1)
	assert(near(mx, 2) and near(sx, 0), "zero puts them back at their places")
	noErrors(env, K)
end
collectgarbage()

-- Missing buff glow lights the reminder only while it shows, and off hides it.
do
	local env, K, ns = boot()
	local tank = frame(ns, "party1")
	write(env, K, "reminders.place", "TOP")
	assert(tank.reminder:IsShown() and tank.reminder.glow == nil, "no glow until switched on")
	write(env, K, "reminders.glow", true)
	local glow = tank.reminder.glow
	assert(glow and glow.holder:IsShown() and glow.holder:GetParent() == tank.reminder, "the glow rings the missing buff")
	env._buffs.party1 = { [H.FORTITUDE] = true, [H.THORNS] = true }
	env.FireEvent("UNIT_AURA", "party1")
	assert(not tank.reminder:IsShown() and not glow.holder:IsVisible(), "a buffed member shows neither")
	env._buffs.party1 = nil
	env.FireEvent("UNIT_AURA", "party1")
	assert(tank.reminder:IsShown() and glow.holder:IsVisible(), "and it returns with the reminder")
	write(env, K, "reminders.glow", false)
	assert(not glow.holder:IsShown(), "off hides the glow")
	noErrors(env, K)
end
collectgarbage()

-- Name line height sets the lane above the bar, never shorter than the name, and 0 restores it.
do
	local env, K, ns = boot()
	local f = frame(ns, "party1")
	local before, bar = f.parts.name.height, f.parts.health.top
	write(env, K, "names.height", 22)
	assert(near(f.parts.name.height, 22) and f.parts.health.top > bar, "the name line is 22 tall and the bar starts lower")
	write(env, K, "names.height", 4)
	assert(f.parts.name.height >= ns.Settings.current.party.nameSize, "never shorter than the name")
	write(env, K, "names.height", 0)
	assert(near(f.parts.name.height, before) and near(f.parts.health.top, bar), "0 restores the name line")
	G.SetRoster(env, "raid", G.Members(10))
	env.RunTimers()
	local r = frame(ns, "raid1")
	local raidBar = r.parts.health.top
	write(env, K, "names.height", 20)
	assert(r.parts.health.top > raidBar and r.parts.name.height > 12, "raid frames take it too")
	write(env, K, "names.height", 0)
	noErrors(env, K)
end
collectgarbage()

-- Heal icon offsets move each kind's heal icons on their own, and zero restores the anchor.
do
	local env, K, ns = boot()
	local f = frame(ns, "party2")
	local before = point(f.buffClip)
	moved(f.buffClip, function() write(env, K, "party.buffX", -10) write(env, K, "party.buffY", 4) end, -10, 4, "the heal icons")
	local partyPoint = point(f.buffClip)
	write(env, K, "raid.buffX", 30)
	assert(point(f.buffClip) == partyPoint, "a raid offset leaves party heals alone")
	write(env, K, "raid.buffX", 0)
	write(env, K, "party.buffX", 0)
	write(env, K, "party.buffY", 0)
	assert(point(f.buffClip) == before, "zero restores the anchor exactly")
	noErrors(env, K)
end
collectgarbage()

-- Class order and class first sort party and raid groups by class; role order wins; off restores; combat waits.
do
	local env, K, ns = boot()
	local header = ns.Headers.party
	assert(table.concat(G.Shown(header), ",") == "player,party1,party2,party3", "group order first")
	write(env, K, "sort.classFirst", true)
	assert(header:GetAttribute("groupBy") == "CLASS", "class first groups the party by class")
	assert(table.concat(G.Shown(header), ",") == "party1,player,party3,party2", "warrior, hunter, shaman, druid: " .. table.concat(G.Shown(header), ","))
	write(env, K, "sort.class1", "DRUID")
	assert(header:GetAttribute("groupingOrder"):find("^DRUID,PALADIN,HUNTER") and header:GetAttribute("groupingOrder"):find("WARRIOR$"), "a repeat's place goes to the class left out: " .. header:GetAttribute("groupingOrder"))
	assert(G.Shown(header)[1] == "party2", "the druid leads")
	write(env, K, "party.sortBy", "ROLE")
	assert(header:GetAttribute("groupBy") == "ASSIGNEDROLE", "role order still wins")
	write(env, K, "party.sortBy", "INDEX")
	env.SetCombat(true)
	write(env, K, "sort.classFirst", false)
	assert(header:GetAttribute("groupBy") == "CLASS" and #env._blocked == 0, "in combat the header waits")
	env.SetCombat(false)
	env.RunTimers()
	assert(header:GetAttribute("groupBy") == nil and table.concat(G.Shown(header), ",") == "player,party1,party2,party3", "off restores group order after combat")
	G.SetRoster(env, "raid", G.Members(10))
	env.RunTimers()
	write(env, K, "sort.classFirst", true)
	for g = 1, 2 do assert(ns.Headers.raid[g]:GetAttribute("groupBy") == "CLASS", "each raid group sorts by class") end
	local group1 = G.Shown(ns.Headers.raid[1])
	assert(group1[1] == "raid2" and group1[5] == "raid1", "group 1 runs paladin first and warrior last: " .. table.concat(group1, ","))
	write(env, K, "sort.classFirst", false)
	write(env, K, "raid.sortBy", "CLASS")
	assert(ns.Headers.raid[1]:GetAttribute("groupingOrder"):find("^DRUID"), "raid class order follows the list")
	write(env, K, "raid.sortBy", "GROUP")
	write(env, K, "sort.class1", env.CLASS_SORT_ORDER[1])
	noErrors(env, K)
end
collectgarbage()

-- Centre groups centres the groups with members, re-centres on roster changes out of combat, and off restores.
do
	local env, K, ns = boot()
	G.SetRoster(env, "raid", G.Members(10))
	env.RunTimers()
	local h1, card = ns.Headers.raid[1], ns.Headers.cards.raid.frame
	local before, cardBefore = point(h1), point(card)
	local x0 = offset(h1)
	write(env, K, "raid.center", true)
	local pitch = ns.Settings.current.raid.width + ns.Settings.current.raid.groupSpacing
	local x1 = offset(h1)
	assert(x1 - x0 > 2 * pitch and x1 - x0 < 4 * pitch, "two groups of eight slots move three slots in: " .. (x1 - x0))
	assert(point(card) ~= cardBefore, "the card moves with them")
	G.SetRoster(env, "raid", G.Members(20))
	env.RunTimers()
	local x2 = offset(h1)
	assert(x2 < x1 and x2 > x0, "four groups move in less: " .. x2)
	env.SetCombat(true)
	G.SetRoster(env, "raid", G.Members(40))
	env.RunTimers()
	assert(near(offset(h1), x2) and #env._blocked == 0, "in combat the groups stay put")
	env.SetCombat(false)
	env.RunTimers()
	assert(near(offset(h1), x0), "eight groups need no centring")
	write(env, K, "raid.center", false)
	G.SetRoster(env, "raid", G.Members(10))
	env.RunTimers()
	assert(point(h1) == before and point(card) == cardBefore, "off restores the groups and card exactly")
	noErrors(env, K)
end
collectgarbage()

-- The preview follows the role place, icon offsets, the glow, the name line and heal offsets.
do
	local env, K = G.New({ setup = H.setup })
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetSize(300, 520)
	local preview = K.Options.Preview(MODULE)(parent)
	local tank, healer = preview.partyFrames[1], preview.partyFrames[2]
	local role, nameHeight = point(tank.role), tank.parts.name.height
	local _, _, _, bx = healer.sampleBuffs[1]:GetPoint(1)
	write(env, K, "icons.rolePlace", "BOTTOMRIGHT")
	write(env, K, "reminders.place", "TOPLEFT")
	write(env, K, "reminders.glow", true)
	write(env, K, "names.height", 24)
	write(env, K, "party.buffX", -8)
	preview:Refresh()
	assert(tank.role:GetPoint(1) == "BOTTOMRIGHT" and select(2, tank.role:GetPoint(1)) == tank.health, "the sample role icon moves onto the bar")
	assert(healer.reminder:IsShown() and healer.reminder.glow.holder:IsShown(), "the sample missing buff glows")
	assert(near(tank.parts.name.height, 24), "the sample name line grows")
	assert(near(select(4, healer.sampleBuffs[1]:GetPoint(1)) - bx, -8), "the sample heals move")
	for key, value in pairs({ ["icons.rolePlace"] = "AUTO", ["reminders.place"] = "NONE", ["reminders.glow"] = false, ["names.height"] = 0, ["party.buffX"] = 0 }) do
		write(env, K, key, value)
	end
	preview:Refresh()
	assert(point(tank.role) == role and near(tank.parts.name.height, nameHeight), "switching back restores the preview")
	noErrors(env, K)
end
collectgarbage()

-- Review of #642, finding 1: a tall name line stays above a Medallions party bar, as tall as the room allows, and leaves the name-on-bar raid tile alone.
do
	local env, K, ns = boot()
	K.Options.Write("HudStyle", "style", "medallions")
	env.RunTimers()
	local f = frame(ns, "party1")
	local line = f.parts.name.height
	write(env, K, "names.height", 40)
	assert(not f.parts.nameInside and f.parts.name.height > line, "the name stays above the bar, as tall as the room allows")
	noErrors(env, K)
	write(env, K, "names.height", 0)
	write(env, K, "party.height", 85)
	G.SetRoster(env, "raid", G.Members(10, function(_, m) m.role = "TANK" end))
	env.RunTimers()
	write(env, K, "raid.height", 40)
	local r = frame(ns, "raid1")
	local stacked, block = r.parts.tile.stacked, r.parts.block and r.parts.block.size
	write(env, K, "names.height", 40)
	assert(r.parts.nameInside and r.parts.tile.stacked == stacked and (r.parts.block and r.parts.block.size) == block, "the name-on-bar tile keeps its layout")
	noErrors(env, K)
end
collectgarbage()

-- Review of #642, finding 2: Centre groups centres each row's groups with members: a part row under a full one, and a lone group far along its row inside its card.
do
	local env, K, ns = boot()
	local h, card = ns.Headers.raid, ns.Headers.cards.raid.frame
	write(env, K, "raid.groupsPerRow", 4)
	G.SetRoster(env, "raid", G.Members(25))
	env.RunTimers()
	local x1, x5, pitch, cardAt = offset(h[1]), offset(h[5]), offset(h[2]) - offset(h[1]), point(card)
	write(env, K, "raid.center", true)
	assert(near(offset(h[1]), x1) and point(card) == cardAt, "the full first row and the card stay put")
	assert(math.abs(offset(h[5]) - x5 - 1.5 * pitch) <= 1, "group 5 centres under the full row: " .. (offset(h[5]) - x5))
	write(env, K, "raid.center", false)
	write(env, K, "raid.groupsPerRow", 8)
	G.SetRoster(env, "raid", G.Members(5, function(_, m) m.group = 8 end))
	env.RunTimers()
	local x8 = offset(h[8])
	pitch, cardAt = offset(h[2]) - offset(h[1]), point(card)
	write(env, K, "raid.center", true)
	assert(math.abs(offset(h[8]) - x8 + 3.5 * pitch) <= 1 and point(card) == cardAt, "a lone group 8 moves to the middle of its card: " .. (offset(h[8]) - x8))
	noErrors(env, K)
end
collectgarbage()

-- Review of #642, finding 3: heal icons moved by their offset keep clear of an indicator, at every test screen size.
do
	local Scene = dofile("Tools/render/scene.lua")
	local previous = rawget(_G, "RENDER_SCREEN")
	for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
		rawset(_G, "RENDER_SCREEN", { width = screen[1], height = screen[2], uiScale = 768 / 1080, size = "auto" })
		local env, K, ns = boot()
		local f = frame(ns, "party1")
		local indicator = f.indicators._slots.indicator1
		write(env, K, "party.buffX", -12)
		indicator.frame:Show()
		local a, b = { Scene.Rect(env, f.buffClip) }, { Scene.Rect(env, indicator.frame) }
		local w = math.min(a[1] + a[3], b[1] + b[3]) - math.max(a[1], b[1])
		local h = math.min(a[2] + a[4], b[2] + b[4]) - math.max(a[2], b[2])
		assert(indicator.enabled and (w <= 0 or h <= 0), screen[1] .. "x" .. screen[2] .. ": the heal icons cover the indicator by " .. w .. " x " .. h)
		noErrors(env, K)
		collectgarbage()
	end
	rawset(_G, "RENDER_SCREEN", previous)
	local env, K, ns = boot()
	K.Options.Write("HudStyle", "style", "medallions")
	write(env, K, "party.buffX", -12)
	local f = frame(ns, "party1")
	local a = { Scene.Rect(env, f.buffClip) }
	for i = 1, 2 do
		local indicator = f.indicators._slots["indicator" .. i]
		indicator.frame:Show()
		local b = { Scene.Rect(env, indicator.frame) }
		local w = math.min(a[1] + a[3], b[1] + b[3]) - math.max(a[1], b[1])
		local h = math.min(a[2] + a[4], b[2] + b[4]) - math.max(a[2], b[2])
		assert(ns.Slots.Placements(f)[i].fits and (w <= 0 or h <= 0), "Medallions finds indicator " .. i .. " a place clear of the moved heal icons")
	end
	noErrors(env, K)
end
collectgarbage()

-- Review of #642, finding 4: a placed role icon shows on Medallions raid tiles, where Automatic leaves the role to the ring.
do
	local env, K, ns = boot()
	K.Options.Write("HudStyle", "style", "medallions")
	G.SetRoster(env, "raid", G.Members(10, function(_, m) m.role = "TANK" end))
	env.RunTimers()
	local r = frame(ns, "raid1")
	assert(not r.role:IsShown() and not r.pipEdge:IsShown(), "Automatic leaves the role to the ring")
	write(env, K, "icons.rolePlace", "LEFT")
	assert(r.role:GetPoint(1) == "LEFT" and (r.role:IsShown() or r.pipEdge:IsShown()), "the placed role icon shows")
	write(env, K, "icons.rolePlace", "AUTO")
	assert(not r.role:IsShown() and not r.pipEdge:IsShown(), "Automatic hands it back to the ring")
	noErrors(env, K)
end
collectgarbage()

-- Review of #642, finding 5: a class picked for a place swaps with the class that held it, so the pickers show the order the frames use.
do
	local env, K, ns = boot()
	local order, get = env.CLASS_SORT_ORDER, ns.Settings.Get
	write(env, K, "sort.classFirst", true)
	write(env, K, "sort.class1", order[5])
	assert(get("sort.class1") == order[5] and get("sort.class5") == order[1], "the displaced class takes the picked class's old place")
	local picks = {}
	for i = 1, #order do picks[i] = get("sort.class" .. i) end
	assert(ns.Headers.party:GetAttribute("groupingOrder") == table.concat(picks, ","), "the frames use the order the pickers show: " .. ns.Headers.party:GetAttribute("groupingOrder"))
	write(env, K, "sort.class1", order[1])
	for i = 1, #order do assert(get("sort.class" .. i) == order[i], "picking back restores the order") end
	noErrors(env, K)
end
collectgarbage()

-- Review of #642, finding 6: the preview sorts its samples by class first and the class order, and centres its raid groups.
do
	local env, K = G.New({ setup = H.setup })
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetSize(300, 520)
	local preview = K.Options.Preview(MODULE)(parent)
	local function at(list, name)
		for _, f in ipairs(list) do if f.sample.name == name then return point(f) end end
	end
	local party, raid = {}, {}
	for _, name in ipairs({ "Thaldren", "Sylaen", "Kragar" }) do party[name] = at(preview.partyFrames, name) end
	for _, name in ipairs({ "Thaldren", "Sylaen" }) do raid[name] = at(preview.raidFrames, name) end
	write(env, K, "sort.classFirst", true)
	write(env, K, "sort.class1", "DRUID")
	preview:Refresh()
	assert(at(preview.partyFrames, "Sylaen") == party.Thaldren and at(preview.partyFrames, "Kragar") == party.Sylaen and at(preview.partyFrames, "Thaldren") == party.Kragar, "the druid leads the party samples and the warrior trails")
	assert(at(preview.raidFrames, "Sylaen") == raid.Thaldren, "the druid leads its raid group")
	write(env, K, "sort.class1", "WARRIOR")
	write(env, K, "sort.classFirst", false)
	preview:Refresh()
	local x0 = select(4, preview.raidFrames[1]:GetPoint(1))
	write(env, K, "raid.center", true)
	preview:Refresh()
	assert(select(4, preview.raidFrames[1]:GetPoint(1)) > x0, "the sample raid groups move to the middle of their row")
	write(env, K, "raid.center", false)
	preview:Refresh()
	assert(at(preview.partyFrames, "Thaldren") == party.Thaldren and at(preview.raidFrames, "Thaldren") == raid.Thaldren, "off restores the samples")
	noErrors(env, K)
end
collectgarbage()

-- Review of #642, finding 7: Centre groups saved on does no work while the groups cannot sit apart, and centres the current roster once they can.
do
	local env, K, ns = boot()
	G.SetRoster(env, "raid", G.Members(10))
	env.RunTimers()
	local h1 = ns.Headers.raid[1]
	local x0, pitch = offset(h1), offset(ns.Headers.raid[2]) - offset(h1)
	write(env, K, "raid.center", true)
	write(env, K, "raid.sortBy", "CLASS")
	local calls, apply = 0, ns.Frames.Apply
	ns.Frames.Apply = function(...) calls = calls + 1 return apply(...) end
	G.SetRoster(env, "raid", G.Members(10, function(i, m) m.group = i < 6 and 1 or 3 end))
	env.RunTimers()
	ns.Frames.Apply = apply
	assert(calls == 0, "sorted by class, a subgroup move rebuilds nothing: " .. calls)
	write(env, K, "raid.sortBy", "GROUP")
	assert(math.abs(offset(h1) - x0 - 2.5 * pitch) <= 1, "back in groups, groups 1 to 3 centre on today's roster: " .. (offset(h1) - x0))
	noErrors(env, K)
end
collectgarbage()

-- Review of #642, finding 8: offsets hide with the icon they move.
do
	local env, K, ns = boot()
	ns.Settings.Schema(true)
	local rows, s = ns.Settings.rows, K.Store.Module(MODULE)
	local function shown(key) return rows[key].showWhen(s) end
	write(env, K, "icons.rolePlace", "LEFT")
	write(env, K, "icons.readyPlace", "LEFT")
	assert(shown("icons.roleX") and shown("icons.roleY") and shown("icons.readyX") and shown("icons.readyY"), "placed icons offer offsets")
	write(env, K, "icons.role", false)
	assert(not shown("icons.rolePlace") and not shown("icons.roleX") and not shown("icons.roleY"), "role icons off hides their place and offsets")
	write(env, K, "icons.readyCheck", false)
	write(env, K, "icons.statuses", false)
	assert(not shown("icons.readyPlace") and not shown("icons.readyX") and not shown("icons.readyY"), "ready checks and statuses off hide their place and offsets")
	noErrors(env, K)
end
collectgarbage()

print("groupframes parity round 4 ok: defaults, role place, icon offsets, missing buff glow, name line height, heal offsets, class order, class first, centred groups, the preview and the review fixes")
