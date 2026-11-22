-- test-groupframes-parity-r6-review.lua: the round 6 review's probes: an indicator bar with no room on its edge reports it does not fit on four screens, one bar per edge, the icon's square without the engine's duration bar, the Options sample's texture and the icon size row in Bar mode, the own raid size over the larger frames, a tank list that refuses unreadable rosters and an unknown lockdown and scans once per roster change, and party frames that follow the raid as the automatic layout and the HUD style leave it, medallion party frames keeping their names above the bar.
local H = dofile("Tools/regression/groupframes_r3a.lua")
local G, MODULE = H.G, H.MODULE
local write, frame, noErrors, near = H.write, H.frame, H.noErrors, H.near

-- A 16-unit party frame with a 20-line shield on the bar's edge leaves no room: the bar reports it does not fit and keeps a positive size.
local env, K, ns
for _, screen in ipairs(H.SCREENS) do
	local e, k, n = H.boot(H.screen(screen))
	local button = frame(n, "party1").indicators._slots.indicator1.frame
	for key, value in pairs({ ["indicator1.style"] = "BAR", ["indicator1.position"] = "BOTTOM", ["party.height"] = 16, ["prediction.shieldLines"] = 20 }) do write(e, k, key, value) end
	local where = screen[1] .. "x" .. screen[2]
	assert(n.Slots.Misfit("party", 1) and button:GetHeight() > 0, where .. ": a bar with no room reports it does not fit, height " .. button:GetHeight())
	write(e, k, "prediction.shieldLines", 2)
	assert(not n.Slots.Misfit("party", 1) and button:GetHeight() > 0, where .. ": and fits with room")
	noErrors(e, k)
	env, K, ns = env or e, K or k, ns or n
end
write(env, K, "party.height", ns.Settings.defaults.party.height)

-- Two bars on one edge, or both shipped slots across the middle, would draw on one rectangle: the second reports it does not fit.
do
	for i = 1, 2 do write(env, K, "indicator" .. i .. ".style", "BAR") end
	write(env, K, "indicator2.position", "BOTTOM")
	assert(not ns.Slots.Misfit("party", 1) and ns.Slots.Misfit("party", 2), "a second bar on the bottom edge does not fit")
	for i = 1, 2 do write(env, K, "indicator" .. i .. ".position", "CENTER") end
	assert(not ns.Slots.Misfit("party", 1) and ns.Slots.Misfit("party", 2), "nor across the middle")
	write(env, K, "indicator2.style", "ICON")
	assert(not ns.Slots.Misfit("party", 2), "an icon there still fits")
	noErrors(env, K)
end

-- Without the engine's duration bar, a bar slot is the icon's square at the icon's place and size.
do
	local button = frame(ns, "party1").indicators._slots.indicator1.frame
	local p = ns.Auras.Parts(button)
	write(env, K, "indicator1.style", "ICON")
	local w, h, at = button:GetWidth(), button:GetHeight(), H.point(button)
	local setBar = button.SetDurationBar
	button.SetDurationBar = nil
	write(env, K, "indicator1.style", "BAR")
	assert(p.square:IsShown() and not p.bar:IsShown() and near(button:GetWidth(), w) and near(button:GetHeight(), h) and H.point(button) == at,
		"the square keeps the icon's place and size: " .. button:GetWidth() .. "x" .. button:GetHeight())
	button.SetDurationBar = setBar
	write(env, K, "indicator1.style", "ICON")
	noErrors(env, K)
end

-- In Bar mode the icon size row hides, and the Options sample's bar uses the live bar's texture.
do
	local row = K.Options.Row(MODULE, "indicator1.size")
	write(env, K, "indicator1.style", "BAR")
	assert(not row.showWhen(K.Store.Module(MODULE)), "a bar has no icon size")
	local asset = K.Tokens.MediaList("statusbar")[2].path
	write(env, K, "health.texture", asset)
	local live = ns.Auras.Parts(frame(ns, "party1").indicators._slots.indicator1.frame).bar
	local sample = H.preview(env, K).partyFrames[1].sampleSlots[1].bar
	assert(live:GetStatusBarTexture():GetTexture() == asset and sample:GetTexture() == asset, "the sample's texture: " .. tostring(sample:GetTexture()))
	write(env, K, "indicator1.style", "ICON")
	assert(row.showWhen(K.Store.Module(MODULE)), "an icon has")
	write(env, K, "health.texture", ns.Settings.defaults.health.texture)
	noErrors(env, K)
end

-- The own raid size wins over the larger frames from the size chosen; compact frames still win over it.
do
	local bracket = ns.AutoLayout.Bracket
	write(env, K, "auto.customLeast", 5)
	assert(bracket(5) == "CUSTOM" and bracket(10) == "CUSTOM" and bracket(11) == "CUSTOM" and bracket(26) == "LARGE", "from 5 players: " .. bracket(5) .. " " .. bracket(10))
	write(env, K, "auto.customLeast", 0)
	assert(bracket(5) == "SMALL", "off, the larger frames return")
end

-- The tank list scans the roster once per roster change and not on a settings change, keeps the role filter for an unreadable roster and changes nothing while the lockdown is unknown.
do
	G.SetRoster(env, "raid", G.Members(25))
	env.RunTimers()
	write(env, K, "tanks.enabled", true)
	write(env, K, "tanks.excludeSelf", true)
	local header = ns.Extras.groups.tanks.header
	local roster
	for _, handler in ipairs(ns.Frames.events) do
		if handler.event == "PLAYER_ROLES_ASSIGNED" and debug.getinfo(handler.fn, "S").source:find("Extras.lua", 1, true) then roster = handler.fn end
	end
	local scans, read = 0, env.GetRaidRosterInfo
	env.GetRaidRosterInfo = function(i)
		if i == 1 and debug.getinfo(2, "S").short_src:find("Extras.lua", 1, true) then scans = scans + 1 end
		return read(i)
	end
	G.SetRoster(env, "raid", G.Members(26))
	env.RunTimers()
	assert(scans == 1, "one roster change, one scan: " .. scans)
	scans = 0
	write(env, K, "raid.nameSize", 15)
	assert(scans == 0, "a name size change reuses the list: " .. scans)
	env.GetRaidRosterInfo = read
	for name, broken in pairs({ GetNumGroupMembers = function() return env.Secret(26) end, UnitName = false }) do
		local keep = env[name]
		env[name] = broken or nil
		roster()
		assert(header:GetAttribute("roleFilter") == "MAINTANK,TANK" and header:GetAttribute("nameList") == nil, name .. ": an unreadable roster keeps the role filter")
		env[name] = keep
		roster()
		assert(header:GetAttribute("nameList") ~= nil, name .. ": and the list returns")
	end
	local lockdown, count = env.InCombatLockdown, env.GetNumGroupMembers
	env.InCombatLockdown, env.GetNumGroupMembers = nil, function() return env.Secret(26) end
	roster()
	env.InCombatLockdown, env.GetNumGroupMembers = lockdown, count
	assert(header:GetAttribute("nameList") ~= nil, "an unknown lockdown changes nothing")
	write(env, K, "raid.nameSize", ns.Settings.defaults.raid.nameSize)
	write(env, K, "tanks.excludeSelf", false)
	write(env, K, "tanks.enabled", false)
	noErrors(env, K)
end

-- Party frames take the raid's values as the compact raid layout and the Medallions style leave them; medallion party frames keep their names above the bar.
do
	local c = ns.Settings.current
	for _, section in ipairs({ "text", "heals", "power" }) do write(env, K, "follow." .. section, true) end
	G.SetRoster(env, "raid", G.Members(30))
	env.RunTimers()
	assert(c.party.nameSize == c.raid.nameSize and c.party.power == c.raid.power and c.party.healthText == c.raid.healthText, "compact raid frames: " .. c.party.nameSize .. " " .. c.raid.nameSize)
	H.party(env)
	env.RunTimers()
	env.RunTimers()
	assert(c.party.textLayout == "ABOVE" and c.raid.textLayout == "INSIDE" and c.party.power == c.raid.power and c.party.buffCount == c.raid.buffCount, "Medallions: " .. c.party.textLayout .. " " .. c.raid.textLayout)
	noErrors(env, K)
end

print("groupframes parity round 6 review ok: bars that fit on four screens, one bar per edge, the square fallback, the sample's texture, the own raid size, the tank list and party frames that follow the raid")
