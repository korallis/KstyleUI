-- test-groupframes-fallbacks.lua: group frames still work on a client without UnitHealthPercent or CurveConstants, and log the path they took.
local G = dofile("Tools/regression/group_env.lua")

local function eq(got, want, what)
	assert(got == want, what .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end

local env, K, ns = G.New({
	setup = function(env)
		env.UnitHealthPercent = nil
		env.CurveConstants = nil
	end,
})
G.SetRoster(env, "party", { { name = "Thaldren", class = "WARRIOR", health = 92, maxHealth = 100 } })
K.Modules.Enable("GroupFrames")
env.RunTimers()
eq(#env._errors, 0, "Enable works without UnitHealthPercent: " .. tostring(env._errors[1]))
assert(K.Modules.IsRunning("GroupFrames"), "GroupFrames runs without UnitHealthPercent")

local content
local i = 1
while ns.Headers.party._attributes["child" .. i] do
	local button = ns.Headers.party._attributes["child" .. i]
	if button._attributes.unit == "party1" then
		content = ns.Button.Content(button)
	end
	i = i + 1
end
assert(content, "party1 has a frame")
local text = content.healthText:GetText()
assert(env.issecretvalue(text), "the health text falls back to the current health, still secret")
eq(env.Reveal(text), "92", "the current health shows instead of the percent")

local logged = false
for _, entry in ipairs(env.KstyleUIDB.devlog) do
	logged = logged or (entry.module == "GroupFrames" and entry.message:find("UnitHealthPercent", 1, true) ~= nil)
end
assert(logged, "the devlog says the percent text fell back")

print("groupframes fallbacks ok")
