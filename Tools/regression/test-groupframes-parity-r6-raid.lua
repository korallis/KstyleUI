-- test-groupframes-parity-r6-raid.lua: EllesmereUI parity round 6 in a raid: an own raid size switches with the roster out of combat, and tank frames leave you out by a name list that follows roles, the roster and combat, refuses secret names, reaches the preview and switches back.
local H = dofile("Tools/regression/groupframes_r3a.lua")
local G, MODULE = H.G, H.MODULE
local write, frame, noErrors, boot, near = H.write, H.frame, H.noErrors, H.boot, H.near

local function saved(own)
	own = own or {}
	own.enabled = true
	return { version = 42, profiles = { Default = { [MODULE] = own } }, characters = {}, layouts = {} }
end

local function shownUnits(header)
	local out, i = {}, 1
	while header:GetAttribute("child" .. i) do
		local child = header:GetAttribute("child" .. i)
		if child:IsShown() and child:GetAttribute("unit") then out[#out + 1] = child:GetAttribute("unit") end
		i = i + 1
	end
	return table.concat(out, ",")
end

local function preview(env, K)
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetSize(300, 520)
	return K.Options.Preview(MODULE)(parent)
end

local env, K, ns = boot({ saved = saved({ auto = { size = true } }) })

-- An own raid size from a raid size of your choosing, switched with the roster out of combat.
do
	G.SetRoster(env, "raid", G.Members(18))
	env.RunTimers()
	local width = frame(ns, "raid1"):GetWidth()
	write(env, K, "auto.customLeast", 16)
	write(env, K, "auto.customWidth", 150)
	write(env, K, "auto.customHeight", 40)
	assert(ns.AutoLayout.state.bracket == "CUSTOM" and near(frame(ns, "raid1"):GetWidth(), 150) and near(frame(ns, "raid1"):GetHeight(), 40), "18 players take the own size")
	write(env, K, "auto.icons", true)
	assert(ns.Settings.current.raid.auraSize == math.floor(12 * 40 / 36 + 0.5), "icons scale with it")
	G.SetRoster(env, "raid", G.Members(12))
	env.RunTimers()
	assert(ns.AutoLayout.state.bracket == "MEDIUM" and near(frame(ns, "raid1"):GetWidth(), width), "12 players keep the raid size")
	env.SetCombat(true)
	G.SetRoster(env, "raid", G.Members(18))
	env.RunTimers()
	assert(near(frame(ns, "raid1"):GetWidth(), width) and #env._blocked == 0, "combat waits")
	env.SetCombat(false)
	env.RunTimers()
	assert(near(frame(ns, "raid1"):GetWidth(), 150), "and the size follows after it")
	G.SetRoster(env, "raid", G.Members(30))
	env.RunTimers()
	assert(ns.AutoLayout.state.bracket == "LARGE", "compact frames still win")
	write(env, K, "auto.customLeast", 0)
	G.SetRoster(env, "raid", G.Members(18))
	env.RunTimers()
	assert(ns.AutoLayout.state.bracket == "MEDIUM" and near(frame(ns, "raid1"):GetWidth(), width), "0 turns it off")
	write(env, K, "auto.icons", false)
	noErrors(env, K)
end

-- Tank frames leave you out by a name list built out of combat, follow role and roster changes, wait for combat, refuse secret names and switch back.
do
	local members = G.Members(10, function(i, m) m.role = (i == 3 or i == 7) and "TANK" or m.role end)
	G.SetRoster(env, "raid", members, members[3])
	env.RunTimers()
	write(env, K, "tanks.enabled", true)
	local header = ns.Extras.groups.tanks.header
	assert(shownUnits(header) == "raid3,raid7", "you are a tank among them: " .. shownUnits(header))
	write(env, K, "tanks.excludeSelf", true)
	assert(shownUnits(header) == "raid7" and header:GetAttribute("nameList") == "Member7" and header:GetAttribute("roleFilter") == nil, "you are left out: " .. shownUnits(header))
	members[5].role = "TANK"
	env.FireEvent("PLAYER_ROLES_ASSIGNED")
	assert(shownUnits(header) == "raid5,raid7", "a new tank joins: " .. shownUnits(header))
	members[9].raidRole = "MAINTANK"
	env.SetCombat(true)
	env.FireEvent("PLAYER_ROLES_ASSIGNED")
	assert(shownUnits(header) == "raid5,raid7" and #env._blocked == 0, "combat waits")
	env.SetCombat(false)
	env.RunTimers()
	assert(shownUnits(header) == "raid5,raid7,raid9", "a main tank follows after it: " .. shownUnits(header))
	members[11] = { name = "Member11", class = "WARRIOR", role = "TANK", health = 80, maxHealth = 100 }
	G.SetRoster(env, "raid", members, members[3])
	env.RunTimers()
	assert(shownUnits(header) == "raid5,raid7,raid9,raid11", "the roster's tank joins: " .. shownUnits(header))
	local name = env.UnitName
	env.UnitName = function(unit) if unit == "player" then return env.Secret("Member3"), nil end return name(unit) end
	env.FireEvent("PLAYER_ROLES_ASSIGNED")
	assert(header:GetAttribute("roleFilter") == "MAINTANK,TANK" and header:GetAttribute("nameList") == nil, "a secret name refuses the list")
	env.UnitName = name
	env.FireEvent("PLAYER_ROLES_ASSIGNED")
	assert(header:GetAttribute("nameList") ~= nil, "and it returns once names are readable")
	local pv = preview(env, K)
	local tanks = pv.extras.tanks
	assert(not tanks[1]:IsShown() and tanks[2]:IsShown(), "the preview leaves your sample out")
	write(env, K, "tanks.excludeSelf", false)
	G.SetRoster(env, "raid", members, members[3])
	env.RunTimers()
	assert(header:GetAttribute("roleFilter") == "MAINTANK,TANK" and header:GetAttribute("nameList") == nil and shownUnits(header):find("raid3", 1, true), "off brings you back: " .. shownUnits(header))
	pv:Refresh()
	assert(tanks[1]:IsShown(), "in the preview too")
	write(env, K, "tanks.enabled", false)
	noErrors(env, K)
end

print("groupframes parity round 6 in a raid ok: an own raid size and tank frames that leave you out")
