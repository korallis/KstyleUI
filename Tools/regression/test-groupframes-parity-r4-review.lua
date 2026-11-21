-- test-groupframes-parity-r4-review.lua: the eight review regressions from #642 for group frames parity round 4.
local H = dofile("Tools/regression/groupframes_r3a.lua")
local G, MODULE = H.G, H.MODULE
local write, frame, noErrors = H.write, H.frame, H.noErrors
local boot, point, offset, near = H.boot, H.point, H.offset, H.near

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
	for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
		local env, K, ns = boot({ width = screen[1], height = screen[2], uiScale = 768 / 1080, size = "auto" })
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

print("groupframes parity round 4 review fixes ok")
