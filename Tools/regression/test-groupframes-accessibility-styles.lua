local G = dofile("Tools/regression/group_env.lua")
local function Check(style)
	local env, K = G.New()
	G.SetRoster(env, "raid", G.Members(40))
	K.Modules.Enable("GroupFrames")
	env.RunTimers()
	K.Options.Write("HudStyle", "style", style)
	G.SetRoster(env, "party", { { name = "Tank", role = "TANK", class = "WARRIOR" } })
	env.RunTimers()
	G.SetRoster(env, "raid", G.Members(40))
	env.RunTimers()
	assert(#env._errors == 0, style .. ": " .. tostring(env._errors[1]))
end
for _, style in ipairs({ "frames", "orbs", "medallions" }) do
	Check(style)
	collectgarbage("collect")
end
print("group accessibility styles ok")
