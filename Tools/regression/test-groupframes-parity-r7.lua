-- test-groupframes-parity-r7.lua: EllesmereUI parity round 7 on party frames: a v0.2.8 profile keeps every new default; paladin blessings by role and class, indicators by your role and class and your frame's place in a party apply when on, follow their events and combat, refuse secrets, reach the preview and switch back. The raid checks are in test-groupframes-parity-r7-raid.lua and the pets in test-groupframes-parity-r7-pets.lua.
local H = dofile("Tools/regression/groupframes_r3a.lua")
local G = H.G
local write, frame, noErrors, boot, shown, icon, near = H.write, H.frame, H.noErrors, H.boot, H.shown, H.icon, H.near

local BLESSINGS = { [19740] = "Blessing of Might", [25782] = "Greater Blessing of Might", [19742] = "Blessing of Wisdom",
	[25894] = "Greater Blessing of Wisdom", [20217] = "Blessing of Kings", [25898] = "Greater Blessing of Kings" }
local function setup(env)
	H.setup(env)
	local name = env.C_Spell.GetSpellName
	env.C_Spell.GetSpellName = function(id) return BLESSINGS[id] or name(id) end
end

-- A v0.2.8-shaped profile keeps every new default and makes nothing new.
do
	local env, K, ns = boot({ setup = setup, saved = H.saved({ party = { width = 259 }, reminders = { place = "NONE" }, indicator1 = { category = "EXTERNAL" } }) })
	local get = ns.Settings.Get
	assert(get("party.selfPosition") == "SORTED" and get("pets.icons") == false and get("tanks.icons") == false and get("boss.icons") == false
		and get("indicator1.role") == "ANY" and get("indicator1.class") == "ANY" and get("reminders.blessWARRIOR") == "ROLE"
		and get("reminders.tankBlessing") == "KINGS", "every new option starts at today's behaviour")
	assert(ns.Headers.me == nil and ns.Extras.pick == nil, "no new frame until an option needs it")
	assert(ns.Headers.party:GetAttribute("showPlayer") == true, "your frame stays in the party header")
	noErrors(env, K)
end
collectgarbage()

-- Blessings: a paladin is reminded of the role's blessing, a class exception replaces it, and Off shows none.
do
	local env, K, ns = boot({ setup = setup })
	env._known = { [19740] = true, [19742] = true }
	env.FireEvent("SPELLS_CHANGED")
	write(env, K, "reminders.place", "TOP")
	for _, key in ipairs({ "fortitude", "intellect", "thorns" }) do write(env, K, "reminders." .. key, false) end
	local tank, healer, dps = frame(ns, "party1"), frame(ns, "party2"), frame(ns, "party3")
	assert(not shown(tank), "Kings for tanks: a paladin without it is never reminded")
	assert(shown(healer) and icon(healer) == 119742, "Wisdom on the healer")
	assert(shown(dps) and icon(dps) == 119740, "Might on the damage dealer")
	env._buffs.party3 = { ["Greater Blessing of Might"] = true }
	env.FireEvent("UNIT_AURA", "party3", { isFullUpdate = true })
	assert(not shown(dps), "the greater blessing counts")
	write(env, K, "reminders.blessSHAMAN", "WISDOM")
	assert(shown(dps) and icon(dps) == 119742, "a class exception replaces the role's blessing")
	write(env, K, "reminders.tankBlessing", "MIGHT")
	assert(shown(tank) and icon(tank) == 119740, "the tank's blessing follows its row")
	env._roster.units.party1.role = "HEALER"
	env.FireEvent("PLAYER_ROLES_ASSIGNED")
	assert(shown(tank) and icon(tank) == 119742, "a role change follows")
	write(env, K, "reminders.blessWARRIOR", "NONE")
	assert(not shown(tank), "Off leaves the class out")
	env._aurasSecret = true
	env.FireEvent("UNIT_AURA", "party2", { isFullUpdate = true })
	assert(not shown(healer), "secret auras show nothing")
	env._aurasSecret = false
	env.FireEvent("UNIT_AURA", "party2", { isFullUpdate = true })
	assert(shown(healer), "readable again")
	local pv = H.preview(env, K)
	write(env, K, "reminders.salvation", false)
	write(env, K, "reminders.wild", false)
	write(env, K, "reminders.spirit", false)
	pv:Refresh()
	local sample = pv.partyFrames[2]
	assert(sample.reminder and sample.reminder:IsShown() and sample.reminder.tile.icon:GetTexture() == 119742, "the preview's healer shows the healer's blessing")
	write(env, K, "reminders.blessDRUID", "KINGS")
	pv:Refresh()
	assert(sample.reminder.tile.icon:GetTexture() == 120217, "and its class exception")
	write(env, K, "reminders.place", "NONE")
	ns.Unit.ForEach(function(f) assert(not shown(f), "off hides every reminder") end)
	noErrors(env, K)
end
collectgarbage()

-- Indicators by your role and class: hidden while you are not that role or class, back on a role change.
do
	local env, K, ns = boot({ setup = setup })
	local tank = frame(ns, "party1")
	local placed = function() return ns.Slots.Placements(tank)[1].fits end
	assert(placed(), "external defensives show on any role")
	write(env, K, "indicator1.role", "HEALER")
	assert(not placed() and not tank.indicators._slots.indicator1.enabled, "not while you are not a healer")
	env._roster.player.role = "HEALER"
	env.FireEvent("PLAYER_ROLES_ASSIGNED")
	assert(placed(), "becoming a healer shows it")
	write(env, K, "indicator1.class", "PRIEST")
	assert(not placed(), "a hunter is not a priest")
	write(env, K, "indicator1.class", "HUNTER")
	assert(placed(), "your own class shows it")
	env._roster.player.role = "DAMAGER"
	env.SetCombat(true)
	env.FireEvent("PLAYER_ROLES_ASSIGNED")
	assert(not placed() and #env._blocked == 0, "a role change in combat follows without a protected call")
	env.SetCombat(false)
	local role = env.UnitGroupRolesAssigned
	env.UnitGroupRolesAssigned = function(unit) if unit == "player" then return env.Secret("HEALER") end return role(unit) end
	env.FireEvent("PLAYER_ROLES_ASSIGNED")
	assert(not placed(), "a secret role keeps a role-only indicator hidden")
	env.UnitGroupRolesAssigned = role
	write(env, K, "indicator1.role", "ANY")
	write(env, K, "indicator1.class", "ANY")
	assert(placed(), "Any restores it")
	noErrors(env, K)
end
collectgarbage()

-- Your frame's place: first or last in a party whatever the sort, in a button of its own, waiting for combat and back in the header when Sorted.
do
	local env, K, ns = boot({ setup = setup })
	local header = ns.Headers.party
	assert(table.concat(G.Shown(header), ",") == "player,party1,party2,party3", "sorted: you lead the group order")
	write(env, K, "party.selfPosition", "LAST")
	local me = ns.Headers.me
	assert(table.concat(G.Shown(header), ",") == "party1,party2,party3" and me:IsShown() and me:GetAttribute("unit") == "player", "last: the header leaves you out and your button shows")
	local p, rel, relPoint, _, y = me:GetPoint(1)
	assert(p == "TOP" and rel == header and relPoint == "BOTTOM" and y < 0, "after the header's last frame")
	assert(ns.Button.Content(me).unit == "player" and near(me:GetWidth(), header:GetAttribute("child1"):GetWidth()), "dressed as a party frame")
	write(env, K, "party.sortBy", "ROLE")
	assert(table.concat(G.Shown(header), ",") == "party1,party2,party3" and me:IsShown(), "whatever the sort")
	write(env, K, "party.selfPosition", "FIRST")
	p, rel = header:GetPoint(1)
	assert(p == "TOP" and rel == me and select(2, me:GetPoint(1)) == ns.Headers.holders.party, "first: the header follows your button")
	env.SetCombat(true)
	G.SetRoster(env, "party", { { name = "Thaldren", class = "WARRIOR", role = "TANK" } })
	assert(#env._blocked == 0 and me:IsShown() and table.concat(G.Shown(header), ",") == "party1", "the roster changes in combat without a protected call")
	write(env, K, "party.selfPosition", "SORTED")
	assert(#env._blocked == 0 and me:IsShown(), "a setting change waits for combat")
	env.SetCombat(false)
	env.RunTimers()
	assert(not me:IsShown() and me:GetAttribute("unit") == nil and header:GetAttribute("showPlayer") == true, "sorted again: your button goes and the header shows you")
	assert(table.concat(G.Shown(header), ",") == "party1,player" or table.concat(G.Shown(header), ",") == "player,party1", "you are back in the header")
	write(env, K, "party.selfPosition", "FIRST")
	write(env, K, "party.showSolo", true)
	G.SetRoster(env, nil, {})
	env.RunTimers()
	assert(me:IsShown() and #G.Shown(header) == 0, "solo with Show when solo: your button alone")
	write(env, K, "party.selfPosition", "LAST")
	assert(not me:IsShown() and table.concat(G.Shown(header), ",") == "player", "solo with last: the header shows you as before")
	local pv = H.preview(env, K)
	assert(pv.partyFrames[#pv.partyFrames].sample.you, "the preview puts you last")
	write(env, K, "party.selfPosition", "FIRST")
	pv:Refresh()
	assert(pv.partyFrames[1].sample.you, "and first")
	write(env, K, "party.selfPosition", "SORTED")
	noErrors(env, K)
end
print("groupframes parity round 7 ok: blessings and class exceptions, indicators by role and class, your frame's place, the preview")
