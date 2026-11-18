-- test-perf-health.lua: health updates keep secret ranges until maximum or identity changes, and leave running animations alone.
local U = dofile("Tools/regression/unitframes_env.lua")
local env, K, ns = U.New()
local view = ns.Frames.Get("player").views[1]
local range, stop, play = 0, 0, 0
for _, bar in ipairs({ view.health, view.health.under, view.health.recent }) do
	local original = bar.SetMinMaxValues
	bar.SetMinMaxValues = function(self, ...)
		range = range + 1
		return original(self, ...)
	end
end
env._restricted = true
env.FireEvent("UNIT_HEALTH", "player")
env.FireEvent("UNIT_HEALTH", "player")
assert(range == 0, "P8: set health ranges on maximum or identity changes, never ordinary health events")
env._units.player.healthMax = 7000
env.FireEvent("UNIT_MAXHEALTH", "player")
assert(range == 3, "P8: propagate a secret new maximum to all three health bars")
local lossGroup = view.health.lossAnim
for method, count in pairs({ Stop = function() stop = stop + 1 end, Play = function() play = play + 1 end }) do
	local original = lossGroup[method]
	lossGroup[method] = function(self, ...)
		count()
		return original(self, ...)
	end
end
env.FireEvent("UNIT_HEALTH", "player")
env.FireEvent("UNIT_HEALTH", "player")
assert(stop == 0 and play == 0, "P8: leave a running loss animation alone")
local uf = ns.Frames.Get("targettarget")
assert(not uf.holder:GetScript("OnUpdate"), "P8: poll target-of-target with a ticker, not every rendered frame")
assert(#env._errors == 0 and K.ErrorCount() == 0, "health performance changes must keep the secret path working")
local G = dofile("Tools/regression/group_env.lua")
local grouped, kit, group = G.New()
G.SetRoster(grouped, "party", { { name = "Ally", class = "WARRIOR", health = 50, maxHealth = 100 } })
kit.Modules.Enable("GroupFrames")
grouped.RunTimers()
local button = group.Headers.party:GetAttribute("child1")
local member = group.Button.Content(button)
local ranges, original = 0, member.health.SetMinMaxValues
member.health.SetMinMaxValues = function(self, ...)
	ranges = ranges + 1
	return original(self, ...)
end
grouped.FireEvent("UNIT_HEALTH", member.unit)
assert(ranges == 0, "P8: group members must keep their range on ordinary health updates")
grouped.FireEvent("UNIT_MAXHEALTH", member.unit)
assert(ranges == 1, "P8: group maximum-health events must update the range")
group.Unit.Refresh(member)
assert(ranges == 2, "P8: group identity refreshes must update the range")
assert(#grouped._errors == 0 and kit.ErrorCount() == 0, "group range invalidation must preserve health")
print("perf health ok")
