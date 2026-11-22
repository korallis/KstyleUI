-- test-groupframes-parity-r8-sort.lua: EllesmereUI parity round 8: Sort by FrameSort. Offered only while FrameSort is loaded; party and raid frames take its order as a name list, follow roster, role and FrameSort changes out of combat, wait in combat, keep members it leaves out, and fall back to group order on a secret name, a missing API or a saved choice without the addon.
local H = dofile("Tools/regression/groupframes_r3a.lua")
local G = H.G
local write, noErrors, boot = H.write, H.noErrors, H.boot

local function Api(env, order)
	local api = { callbacks = {}, order = order }
	local function register(_, fn)
		api.callbacks[#api.callbacks + 1] = fn
		return true
	end
	api.v3 = {
		Sorting = { RegisterPostSortCallback = register, GetFriendlyUnits = function()
			local out = {}
			for i, unit in ipairs(api.order) do out[i] = unit end
			return out
		end },
		Options = { RegisterConfigurationChangedCallback = register },
	}
	env.FrameSortApi = api
	return api
end

local function setup(env)
	H.setup(env)
	env.C_AddOns = env.C_AddOns or {}
	env.C_AddOns.IsAddOnLoaded = function(name) return name == "FrameSort", name == "FrameSort" end
	Api(env, { "party3", "player", "party1" })
end

local function shown(header)
	return table.concat(G.Shown(header), ",")
end

local function offered(ns, key)
	for _, row in ipairs(ns.Settings.Schema(true)) do
		for _, option in ipairs(row.key == key and row.options or {}) do
			if option.value == "FRAMESORT" then return true end
		end
	end
	return false
end

-- Without FrameSort the choice is not offered, and a saved choice reads as group order.
do
	local env, K, ns = boot({ saved = H.saved({ party = { sortBy = "FRAMESORT" }, raid = { sortBy = "FRAMESORT" } }) })
	assert(not offered(ns, "party.sortBy") and not offered(ns, "raid.sortBy"), "no FrameSort choice without the addon")
	assert(ns.Settings.Get("party.sortBy") == "INDEX" and ns.Settings.Get("raid.sortBy") == "GROUP", "a saved FrameSort choice falls back to group order")
	assert(ns.Headers.party:GetAttribute("nameList") == nil and ns.Headers.party:GetAttribute("sortMethod") == "INDEX", "the party header keeps group order")
	noErrors(env, K)
end
collectgarbage()

-- Party frames: FrameSort's order, a member it leaves out kept at the end, its callbacks and the roster followed, combat waits,
-- a secret name or a missing API falls back to group order, and group order comes back exactly.
do
	local env, K, ns = boot({ setup = setup })
	local header, api = ns.Headers.party, env.FrameSortApi
	local base = shown(header)
	assert(offered(ns, "party.sortBy") and offered(ns, "raid.sortBy"), "FrameSort is offered while it is loaded")
	assert(#api.callbacks == 0, "nothing is registered with FrameSort until its order is chosen")
	write(env, K, "party.sortBy", "FRAMESORT")
	assert(shown(header) == "party3,player,party1,party2" and header:GetAttribute("sortMethod") == "NAMELIST", "FrameSort's order, with the member it leaves out at the end")
	assert(#api.callbacks == 2, "its sort and settings callbacks are registered once")
	api.order = { "party2", "party1", "party3", "player" }
	api.callbacks[1]()
	assert(shown(header) == "party3,player,party1,party2", "a callback waits a frame for FrameSort")
	env.RunTimers()
	assert(shown(header) == "party2,party1,party3,player", "and then follows")
	local members = { { name = "Thaldren", class = "WARRIOR", role = "TANK" }, { name = "Sylaen", class = "DRUID", role = "HEALER" },
		{ name = "Kragar", class = "SHAMAN", role = "DAMAGER" }, { name = "Brisa", class = "MAGE", role = "DAMAGER" } }
	api.order = { "party4", "party2", "party1", "party3", "player" }
	env.SetCombat(true)
	G.SetRoster(env, "party", members)
	env.RunTimers()
	assert(#env._blocked == 0 and not shown(header):find("party4", 1, true), "in combat a new member waits without a protected call")
	env.SetCombat(false)
	env.RunTimers()
	assert(shown(header) == "party4,party2,party1,party3,player", "and joins in FrameSort's place when combat ends")
	api.order = { "party1", "party2", "party3", "party4", "player" }
	members[1].role = "HEALER"
	env.FireEvent("PLAYER_ROLES_ASSIGNED")
	env.RunTimers()
	assert(shown(header) == "party1,party2,party3,party4,player", "a role change follows")
	local name = env.UnitName
	env.UnitName = function(unit) if unit == "party2" then return env.Secret("Sylaen"), nil end return name(unit) end
	env.FireEvent("GROUP_ROSTER_UPDATE")
	env.RunTimers()
	assert(header:GetAttribute("nameList") == nil and header:GetAttribute("sortMethod") == "INDEX" and shown(header) == "player,party1,party2,party3,party4", "a secret name falls back to group order")
	env.UnitName = name
	env.FireEvent("GROUP_ROSTER_UPDATE")
	env.RunTimers()
	assert(header:GetAttribute("sortMethod") == "NAMELIST", "readable again")
	env.FrameSortApi = nil
	env.FireEvent("GROUP_ROSTER_UPDATE")
	env.RunTimers()
	assert(header:GetAttribute("nameList") == nil and shown(header) == "player,party1,party2,party3,party4", "without FrameSort's API the frames keep group order")
	env.FrameSortApi = api
	G.SetRoster(env, "party", { members[1], members[2], members[3] })
	env.RunTimers()
	write(env, K, "party.sortBy", "INDEX")
	assert(header:GetAttribute("nameList") == nil and header:GetAttribute("sortMethod") == "INDEX" and shown(header) == base, "group order comes back exactly")
	api.callbacks[1]()
	env.RunTimers()
	assert(header:GetAttribute("nameList") == nil, "a late FrameSort callback changes nothing")
	local pv = H.preview(env, K)
	write(env, K, "party.sortBy", "FRAMESORT")
	pv:Refresh()
	noErrors(env, K)
end
collectgarbage()

-- Raid frames: FrameSort's order in the shown groups only, falling back to group order with the groups' filter.
do
	local env, K, ns = boot({ setup = setup })
	local api = env.FrameSortApi
	G.SetRoster(env, "raid", G.Members(10))
	env.RunTimers()
	api.order = { "raid7", "raid2", "raid9", "raid1" }
	write(env, K, "raid.sortBy", "FRAMESORT")
	local header = ns.Headers.raid[1]
	assert(shown(header) == "raid7,raid2,raid9,raid1,raid3,raid4,raid5,raid6,raid8,raid10", "FrameSort's order first, then the rest in roster order")
	write(env, K, "groups.show2", false)
	assert(shown(header) == "raid2,raid1,raid3,raid4,raid5", "hidden groups stay hidden")
	env.FrameSortApi = nil
	env.FireEvent("GROUP_ROSTER_UPDATE")
	env.RunTimers()
	assert(header:GetAttribute("groupFilter") == "1,3,4,5,6,7,8" and header:GetAttribute("groupBy") == "GROUP" and shown(header) == "raid1,raid2,raid3,raid4,raid5", "without the API, group order with the groups' filter")
	noErrors(env, K)
end

print("groupframes parity round 8 sort ok: FrameSort's order on party and raid frames, its fallbacks and combat")
