-- test-groupframes-parity-r8-review.lua: the PR #736 review's FrameSort probes: a visible raid header falls back to group order without an invalid grouping, name events refresh the list, an unreadable roster or a missing API gives group order without an error, a hidden header is not scanned, and the stub ranks a repeated name last as Forever does.
local H = dofile("Tools/regression/groupframes_r3a.lua")
local G = H.G
local write, noErrors, boot = H.write, H.noErrors, H.boot

local calls = 0
local function setup(env)
	H.setup(env)
	env.C_AddOns = { IsAddOnLoaded = function(name) return name == "FrameSort", name == "FrameSort" end }
	env.FrameSortApi = { v3 = { Sorting = { GetFriendlyUnits = function()
		calls = calls + 1
		return { "raid2", "raid1", "party2", "party1" }
	end } } }
end

local function shown(header)
	return table.concat(G.Shown(header), ",")
end

-- A raid on FrameSort's order: every fallback and refresh on the visible header.
do
	local env, K, ns = boot({ setup = setup })
	G.SetRoster(env, "raid", G.Members(10))
	env.RunTimers()
	write(env, K, "raid.sortBy", "FRAMESORT")
	local header = ns.Headers.raid[1]
	assert(header:IsShown() and header:GetAttribute("sortMethod") == "NAMELIST" and shown(header):find("^raid2,raid1,raid3"), "FrameSort's order on the visible raid header")
	local info = env.GetRaidRosterInfo
	local function readAs(fn)
		env.GetRaidRosterInfo = function(i)
			local r = { info(i) }
			if i == 2 then fn(r) end
			return unpack(r, 1, 12)
		end
	end
	readAs(function(r) r[1] = env.Secret(r[1]) end)
	env.FireEvent("GROUP_ROSTER_UPDATE")
	env.RunTimers()
	assert(#env._errors == 0 and header:GetAttribute("nameList") == nil and header:GetAttribute("groupBy") == "GROUP" and header:GetAttribute("groupingOrder") ~= nil,
		"a secret name falls back to group order without grouping the visible header before its order: " .. tostring(env._errors[1]))
	assert(shown(header) == "raid1,raid2,raid3,raid4,raid5,raid6,raid7,raid8,raid9,raid10", "everyone shows in group order")
	env.GetRaidRosterInfo = info
	env.FireEvent("UNIT_NAME_UPDATE", "raid2")
	env.RunTimers()
	assert(header:GetAttribute("sortMethod") == "NAMELIST", "a name that becomes readable follows on its name event")
	env._member("raid2").name = "Newname"
	env.FireEvent("UNIT_NAME_UPDATE", "raid2")
	env.RunTimers()
	assert(header:GetAttribute("nameList"):find("Newname", 1, true) and shown(header):find("raid2", 1, true), "a renamed member stays on the list")
	local before = calls
	env.FireEvent("UNIT_NAME_UPDATE", "nameplate1")
	env.RunTimers()
	assert(calls == before, "other units' name changes are not followed")
	readAs(function(r) r[3] = nil end)
	ns.Headers.Resort()
	env.RunTimers()
	assert(header:GetAttribute("nameList") == nil and shown(header):find("raid2", 1, true), "a member without a readable group gives group order, so they still show")
	for _, api in ipairs({ "GetRaidRosterInfo", "UnitName", "IsInRaid", "GetNumGroupMembers", "InCombatLockdown" }) do
		local saved = env[api]
		env[api] = nil
		ns.Headers.Resort()
		local ok, err = pcall(env.RunTimers)
		env[api] = saved
		assert(ok and #env._errors == 0 and header:GetAttribute("nameList") == nil, "without " .. api .. " the sort refuses quietly: " .. tostring(err or env._errors[1]))
	end
	env.GetRaidRosterInfo = info
	ns.Headers.Resort()
	env.RunTimers()
	assert(header:GetAttribute("sortMethod") == "NAMELIST", "and follows FrameSort again once everything reads")
	noErrors(env, K)
end
collectgarbage()

-- In a party with both kinds on FrameSort, a FrameSort change asks FrameSort once and never scans the hidden raid header.
do
	local env, K, ns = boot({ setup = setup })
	write(env, K, "party.sortBy", "FRAMESORT")
	write(env, K, "raid.sortBy", "FRAMESORT")
	local info, probes = env.GetRaidRosterInfo, 0
	env.GetRaidRosterInfo = function(i)
		probes = probes + 1
		return info(i)
	end
	calls = 0
	ns.Headers.Resort()
	env.RunTimers()
	assert(not ns.Headers.raid[1]:IsShown() and probes == 0 and calls == 1, "one FrameSort call and no raid roster reads: " .. probes .. " reads, " .. calls .. " calls")
	assert(ns.Headers.raid[1]:GetAttribute("nameList") == nil and shown(ns.Headers.party) == "party2,party1,player,party3", "the hidden raid header keeps group order and the party follows FrameSort")
	G.SetRoster(env, "raid", G.Members(10))
	env.RunTimers()
	assert(ns.Headers.raid[1]:GetAttribute("sortMethod") == "NAMELIST" and ns.Headers.party:GetAttribute("nameList") == nil, "joining a raid swaps which header follows FrameSort")
	noErrors(env, K)
end
collectgarbage()

-- The stub's secure header ranks a repeated name at its last place, as Forever's doubleFillTable does.
do
	local env, K, ns = boot({ setup = setup })
	G.SetRoster(env, "raid", G.Members(3))
	local header = ns.Headers.New(ns.Headers.holders.raid, "raid")
	header:SetAttribute("showRaid", true)
	header:SetAttribute("sortMethod", "NAMELIST")
	header:SetAttribute("nameList", "Member1,Member2,Member1")
	header:Show()
	assert(shown(header) == "raid2,raid1", "a repeated name takes its last place")
	noErrors(env, K)
end

print("groupframes parity round 8 review ok: FrameSort fallbacks on a visible header, name events, missing APIs, hidden headers and the stub's name ranks")
