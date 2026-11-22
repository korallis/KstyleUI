-- test-groupframes-updates.lua: roster and unit events have a zero-frame paint budget once the secure header supplies the unit.
local G = dofile("Tools/regression/group_env.lua")
local W = dofile("Tools/regression/widget_env.lua")
local A = dofile("Tools/regression/auras_env.lua")
local failures = {}

-- Forever 9dc84f0: Blizzard_RestrictedAddOnEnvironment/SecureGroupHeaders.lua configures unit,
-- then Show, on GROUP_ROSTER_UPDATE and UNIT_NAME_UPDATE. SecureStateDriver.lua resets its
-- throttle on roster/regen and resolves visibility on the next OnUpdate. The C client's order
-- between GROUP_JOINED, roster, roles and unit events is not specified by the Lua source.
for _, kind in ipairs({ "party", "raid" }) do
	for _, combat in ipairs({ false, true }) do
		local env, K, ns = G.New()
		K.Options.Write("GroupFrames", kind .. ".roleRing", true)
		K.Options.Write("GroupFrames", "party.portrait", true)
		assert(K.Modules.Enable("GroupFrames"))
		env.RunTimers()
		local timers, frame, ticks = {}, 0, 0
		env.C_Timer.After = function(_, fn)
			timers[#timers + 1] = fn
		end
		local function step()
			frame, ticks = frame + 1, ticks + 1
			local batch = timers
			timers = {}
			for _, fn in ipairs(batch) do fn() end
		end
		local prefix = kind .. (combat and " combat " or " outside ")
		local function budget(event, ready)
			local start, startTicks = frame, ticks
			while not ready() and frame - start < 2 do step() end
			local delay = ready() and frame - start or "pending"
			print(prefix .. event .. ": frames=" .. tostring(delay) .. " timer-ticks=" .. (ticks - startTicks))
			if delay ~= 0 then failures[#failures + 1] = prefix .. event .. " must paint in the event/secure-show frame" end
		end
		local function content(unit)
			for _, f in ipairs(ns.Unit.frames) do
				if f.unit == unit and f.owner:IsVisible() then return f end
			end
		end
		local function value(bar)
			local call = W.LastCall(bar, "SetValue")
			return call and env.Reveal(call[1])
		end
		-- The Medallions raid tile names in caps and draws no role and no power line.
		local function named(f, name)
			return f.rawName == (f.parts.tile and K.Locale.Upper(name) or name)
		end
		local function roleReady(f, role)
			if f.parts.tile then return not f.role:IsShown() end
			if f.showRoleRing then return f.roleText:GetText() == ns.Style.ROLE_LETTERS[role] end
			if ns.Settings.current.icons.roleShapes then
				return f.role:IsShown() and f.role:GetAtlas() == env.GetMicroIconForRole(role)
			end
			local token = ({ TANK = "rare", HEALER = "friendly", DAMAGER = "hostile" })[role]
			local r, g, b = K.Tokens.Color(token)
			local pr, pg, pb = f.pipFill:GetVertexColor()
			return f.pipFill:IsShown() and W.Near(pr, r) and W.Near(pg, g) and W.Near(pb, b)
		end
		local members = { { name = "Thaldren", class = "DRUID", health = 72, power = 36, role = "DAMAGER" } }
		local token = kind .. "1"
		if combat then env.SetCombat(true) end
		G.SetRoster(env, kind, members, nil, true)
		if not combat then env.FireEvent("GROUP_JOINED", 1) end
		env.FireEvent("GROUP_ROSTER_UPDATE")
		if combat then env.FireEvent("GROUP_JOINED", 1) end
		env.FireEvent("PLAYER_ROLES_ASSIGNED")
		env.FireEvent("UNIT_NAME_UPDATE", token)
		if not content(token) then
			frame = frame + 1
			env.RunStateDrivers()
			env.UpdateHeaders()
		end
		print(prefix .. "client visibility rescan: frames=" .. frame .. " addon-timer-ticks=0")
		local f = assert(content(token), "secure headers supply the new unit even in combat")
		budget("GROUP_ROSTER_UPDATE join/show/name/health", function()
			return named(f, "Thaldren") and value(f.health) == 72 and (f.tileless or f.chrome.drawReady)
		end)
		budget("GROUP_ROSTER_UPDATE count", function() return ns.Headers.cards[kind].members == env.GetNumGroupMembers() end)
		env.FireEvent("PLAYER_ROLES_ASSIGNED")
		budget("PLAYER_ROLES_ASSIGNED initial", function() return roleReady(f, "DAMAGER") end)

		-- The header reassigns the same token and fires OnAttributeChanged for the new member.
		members[1] = { name = "Ysra", class = "PRIEST", health = 43, power = 21, role = "HEALER" }
		G.SetRoster(env, kind, members)
		budget("GROUP_ROSTER_UPDATE swap", function() return named(f, "Ysra") and value(f.health) == 43 end)
		members[2] = { name = "Kragar", class = "WARRIOR", health = 91 }
		G.SetRoster(env, kind, members)
		local second = assert(content(kind .. "2"))
		budget("GROUP_ROSTER_UPDATE member joins", function() return named(second, "Kragar") and value(second.health) == 91 end)
		budget("GROUP_ROSTER_UPDATE member count", function() return ns.Headers.cards[kind].members == env.GetNumGroupMembers() end)

		members[1].role = "TANK"
		env.FireEvent("PLAYER_ROLES_ASSIGNED")
		budget("PLAYER_ROLES_ASSIGNED change", function() return roleReady(f, "TANK") end)
		members[1].name = "Sylaen"
		env.FireEvent("UNIT_NAME_UPDATE", token)
		budget("UNIT_NAME_UPDATE", function() return named(f, "Sylaen") end)
		members[1].health = 18
		env.FireEvent("UNIT_HEALTH", token)
		budget("UNIT_HEALTH", function() return value(f.health) == 18 end)
		members[1].power = 12
		env.FireEvent("UNIT_POWER_UPDATE", token, "MANA")
		if f.showPower then
			budget("UNIT_POWER_UPDATE", function() return value(f.power) == 12 end)
		end
		members[1].online = false
		env.FireEvent("UNIT_CONNECTION", token)
		budget("UNIT_CONNECTION", function() return f.healthText:GetText() == "Offline" end)
		members[1].online, members[1].dead = true, true
		env.FireEvent("UNIT_FLAGS", token)
		budget("UNIT_FLAGS dead", function() return f.healthText:GetText() == "Dead" end)
		members[1].dead, members[1].inRange = false, false
		env.FireEvent("UNIT_FLAGS", token)
		env.FireEvent("UNIT_IN_RANGE_UPDATE", token)
		budget("UNIT_IN_RANGE_UPDATE", function() return env.Reveal(f:GetAlpha()) == ns.Settings.current.range.alpha end)
		members[1].ready = "ready"
		env.FireEvent("READY_CHECK", "player", 30)
		env.FireEvent("READY_CHECK_CONFIRM", token, true)
		budget("READY_CHECK_CONFIRM", function() return f.ready:IsShown() and f.ready:GetAtlas() == "UI-LFG-ReadyMark" end)

		if combat then
			env.SetCombat(false)
			budget("PLAYER_REGEN_ENABLED aura build/bind", function()
				return f.auras and f.auras._unit == token and f.buffs and f.buffs._unit == token
			end)
		end
		budget("aura engine follows unit", function() return f.auras and f.auras._unit == token and f.buffs._unit == token end)
		A.Assign(env, f.auras, "debuffs", 1)
		budget("aura engine assignment", function() return f.auras._groups.debuffs.active[1]:IsShown() end)
		members[2] = nil
		G.SetRoster(env, kind, members)
		budget("GROUP_ROSTER_UPDATE leave", function()
			return not content(kind .. "2") and ns.Headers.cards[kind].members == env.GetNumGroupMembers()
		end)
		G.SetRoster(env, nil, {})
		env.FireEvent("GROUP_LEFT", 1)
		budget("GROUP_LEFT hide", function() return not f.owner:IsVisible() end)
		assert(#env._blocked == 0, "no protected work in combat: " .. tostring(env._blocked[1]))
		assert(#env._errors == 0, "no event errors: " .. tostring(env._errors[1]))
	end
end
do
	local env, K, ns = G.New()
	assert(K.Modules.Enable("GroupFrames"))
	env.RunTimers()
	env.SetQuiet(true)
	G.SetRoster(env, "raid", G.Members(40))
	env.RunTimers()
	local refreshes, rosterReads = 0, 0
	local refresh, rosterInfo = ns.Unit.Refresh, env.GetRaidRosterInfo
	ns.Unit.Refresh = function(f)
		refreshes = refreshes + 1
		return refresh(f)
	end
	env.GetRaidRosterInfo = function(...)
		rosterReads = rosterReads + 1
		return rosterInfo(...)
	end
	for _ = 1, 10 do
		env.FireEvent("GROUP_ROSTER_UPDATE")
		env.RunStateDrivers()
		env.UpdateHeaders()
	end
	env.RunTimers()
	print("40 raid members x 10 roster events: Unit.Refresh=" .. refreshes .. " GetRaidRosterInfo=" .. rosterReads .. " (base limits 840 / 40)")
	assert(refreshes <= 840, "Roster storms must rely on secure-header refreshes; remove per-event Unit.RefreshAll")
	assert(rosterReads <= 40, "Roster storms must coalesce GetRaidRosterInfo scans while updating counts synchronously")
	assert(#env._blocked == 0 and #env._errors == 0, "roster storm must not raise errors")
end
assert(#failures == 0, table.concat(failures, "\n"))
print("groupframes update frame budgets ok")
