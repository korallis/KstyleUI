-- test-groupframes-tidy-lanes.lua: Medallions keeps names, fixed-size indicators, your heals and percentages apart without reading engine aura state; a name short of its floor runs under the indicators, as on Frames rows.
local G = dofile("Tools/regression/group_env.lua")
local env, K, ns = G.New()
K.Options.Write("HudStyle", "style", "medallions")
G.SetRoster(env, "party", { { name = "Thaldrenwick", class = "PALADIN", role = "TANK", health = 92, maxHealth = 100 } })
assert(K.Modules.Enable("GroupFrames"))
env.RunTimers()
local function check(f)
	local parts = f.parts
	assert(parts.tidyLanes, "Medallions opts into tidy lanes")
	local lane = parts.indicatorLane
	assert(lane.size == (f.kind == "party" and 14 or 10), "party indicators are 14 units and raid indicators 10")
	local heal = parts.healRow and parts.healRow.side == "RIGHT" and parts.healRow
	if heal then
		assert(lane.left + lane.width <= heal.left - 4 + 0.01 and heal.left + heal.width <= parts.healthText.right - ns.Style.Reserve(f, ns.Settings.current[f.kind], nil, true) - 4 + 0.01, "your heals sit between the indicators and the percent")
		assert(parts.name.left + parts.name.width <= math.max(lane.left - 4, parts.name.left + ns.Geometry.NAME_EM * ns.Style.NameMin(ns.Settings.current[f.kind])) + 0.01, "the name stops four units before the indicators, or keeps its floor under them")
	else
		assert(parts.name.left + parts.name.width <= lane.left - 4 + 0.01, "leave four units between the name and indicators")
	end
	if not parts.tile then assert(math.abs(parts.healthText.right - parts.health.left - parts.health.width) < 0.01, "right-align percent with the bar end") end
	local places = ns.Slots.Placements(f)
	for i = 1, 3 do assert(places[i].fits and places[i].size <= lane.size, "the configured priority indicators fit the lane") end
end
ns.Unit.ForEach(function(f) if f.unit and f.kind == "party" then check(f) end end)
G.SetRoster(env, "raid", G.Members(20))
env.RunTimers()
ns.Unit.ForEach(function(f) if f.unit and f.kind == "raid" then check(f) end end)
K.Options.Write("GroupFrames", "layout.tidyLanes", false)
env.RunTimers()
ns.Unit.ForEach(function(f) if f.unit then assert(not f.parts.tidyLanes, "off restores the previous layout") end end)
assert(#env._errors == 0, tostring(env._errors[1]))
print("ok tidy group lanes: party, raid and previous layout")
