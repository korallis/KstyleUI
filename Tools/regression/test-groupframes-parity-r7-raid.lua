-- test-groupframes-parity-r7-raid.lua: EllesmereUI parity round 7 in a raid: extra frames' icons grow with their extra height on Frames, each group on its own, and the tank frames' key adds your target, waits for combat, refuses secret names and takes them out again.
local H = dofile("Tools/regression/groupframes_r3a.lua")
local G = H.G
local write, frame, noErrors, boot = H.write, H.frame, H.noErrors, H.boot
local setup = H.setup

-- Extra frames' icons grow with their extra height on Frames, each group on its own, and switch back; Medallions tiles keep their lanes.
do
	local env, K, ns = boot({ setup = setup })
	G.SetRoster(env, "raid", G.Members(10, function(i, m) m.role = i == 2 and "TANK" or m.role end))
	env.RunTimers()
	write(env, K, "tanks.enabled", true)
	write(env, K, "tanks.height", 36)
	write(env, K, "tanks.icons", true)
	local f = ns.Button.Content(ns.Extras.groups.tanks.header:GetAttribute("child1"))
	assert(f.extra == "tanks" and ns.Style.Scaled(f, 12) > 12 and ns.Style.Scaled(frame(ns, "raid1"), 12) == 12, "Medallions: the scale reaches tank frames only")
	K.Options.Write("HudStyle", "style", "frames")
	env.RunTimers()
	write(env, K, "tanks.icons", false)
	local raid = frame(ns, "raid1")
	local before = ns.Auras.Block(f, ns.Settings.current.raid).size
	assert(before == ns.Auras.Block(raid, ns.Settings.current.raid).size, "off, tank frames keep the raid's icon size")
	write(env, K, "tanks.icons", true)
	assert(ns.Auras.Block(f, ns.Settings.current.raid).size > before and ns.Slots.Placements(f)[1].size > ns.Slots.Placements(raid)[1].size, "on, debuffs and indicators grow with the frame")
	assert(ns.Auras.Block(raid, ns.Settings.current.raid).size == before, "raid frames keep theirs")
	write(env, K, "pets.enabled", true)
	write(env, K, "pets.height", 36)
	assert(ns.Style.Scaled({ extra = "pets" }, 12) == 12 and ns.Style.Scaled(f, 12) > 12, "each group follows its own row")
	write(env, K, "tanks.icons", false)
	assert(ns.Auras.Block(f, ns.Settings.current.raid).size == before and ns.Style.Scaled(f, 12) == 12, "off restores it")
	noErrors(env, K)
end
collectgarbage()

-- The tank frames' key adds your target, waits for combat, refuses secret names and takes them out again.
do
	local env, K, ns = boot({ setup = setup })
	local members = G.Members(10, function(i, m) m.role = i == 2 and "TANK" or m.role end)
	G.SetRoster(env, "raid", members)
	env.RunTimers()
	assert(env.KstyleUI_GroupFramesTankPick == nil, "no key button until tank frames are on")
	write(env, K, "tanks.enabled", true)
	local header, key = ns.Extras.groups.tanks.header, env.KstyleUI_GroupFramesTankPick
	assert(key and env["BINDING_NAME_CLICK KstyleUI_GroupFramesTankPick:LeftButton"], "the key has a button and a name in Key Bindings")
	local target = "Member5"
	local name, inRaid = env.UnitName, env.UnitInRaid
	env.UnitName = function(unit) if unit == "target" then return target, nil end return name(unit) end
	env.UnitInRaid = function(unit) if unit == "target" then return target and 5 or nil end return inRaid(unit) end
	key._scripts.OnClick(key)
	local picked = function() return table.concat(G.Shown(ns.Extras.groups.tanks.picks), ",") end
	assert(table.concat(G.Shown(header), ",") == "raid2" and header:GetAttribute("roleFilter") == "MAINTANK,TANK" and picked() == "raid5", "your target joins the tanks in a header of its own; the tanks keep their role filter")
	local _, rel = ns.Extras.groups.tanks.picks:GetPoint(1)
	assert(rel == header, "after the tanks")
	env.SetCombat(true)
	target = "Member7"
	key._scripts.OnClick(key)
	members[6].role = "TANK"
	G.SetRoster(env, "raid", members)
	env.FireEvent("PLAYER_ROLES_ASSIGNED")
	assert(#env._blocked == 0 and picked() == "raid5" and table.concat(G.Shown(header), ",") == "raid2,raid6", "in combat, a new tank joins at once and the pick waits")
	env.SetCombat(false)
	env.RunTimers()
	assert(picked() == "raid5,raid7", "and the pick follows after")
	target = env.Secret("Member9")
	key._scripts.OnClick(key)
	assert(picked() == "raid5,raid7", "a secret name is refused")
	target = "Tester"
	write(env, K, "tanks.excludeSelf", true)
	key._scripts.OnClick(key)
	assert(picked() == "raid5,raid7", "Leave yourself out keeps you out of the picks too")
	K.Modules.Disable("GroupFrames")
	env.RunTimers()
	target = "Member5"
	key._scripts.OnClick(key)
	K.Modules.Enable("GroupFrames")
	env.RunTimers()
	assert(picked() == "raid5,raid7", "the key does nothing while the frames are off")
	write(env, K, "tanks.excludeSelf", false)
	key._scripts.OnClick(key)
	target = "Member7"
	key._scripts.OnClick(key)
	target = "Tester"
	key._scripts.OnClick(key)
	assert(picked() == "" and table.concat(G.Shown(header), ",") == "raid2,raid6" and header:GetAttribute("roleFilter") == "MAINTANK,TANK", "pressed again, they leave; the tanks never changed")
	env.UnitName, env.UnitInRaid = name, inRaid
	noErrors(env, K)
end
print("groupframes parity round 7 raid ok: extra frames' icons on Frames and Medallions, the tank frames' key with combat and secrets")
