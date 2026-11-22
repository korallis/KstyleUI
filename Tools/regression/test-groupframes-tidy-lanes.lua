-- test-groupframes-tidy-lanes.lua: Medallions keeps names, fixed-size indicators, your heals and percentages apart without reading engine aura state; with your heals on the name line, the indicators move onto the bar's end.
local G = dofile("Tools/regression/group_env.lua")
local env, K, ns = G.New()
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
		assert(heal.left + heal.width <= parts.healthText.right - ns.Style.Reserve(f, ns.Settings.current[f.kind], nil, true) - 4 + 0.01, "your heals sit before the percent")
		assert(parts.name.left + parts.name.width <= heal.left - 4 + 0.01, "the name stops four units before your heals")
		assert(lane.top >= parts.name.top + parts.name.height and lane.left + lane.width <= parts.health.left + parts.health.width + 0.01, "the indicators sit on the bar's end, under the name line")
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
