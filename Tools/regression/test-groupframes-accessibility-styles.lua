local G = dofile("Tools/regression/group_env.lua")
local function Check(style)
	local env, K, ns = G.New()
	G.SetRoster(env, "raid", G.Members(40))
	K.Modules.Enable("GroupFrames")
	env.RunTimers()
	G.SetRoster(env, "party", { { name = "Tank", role = "TANK", class = "WARRIOR" } })
	env.RunTimers()
	if style == "medallions" then
		K.Options.Write("GroupFrames", "icons.roleShapes", false)
		env.RunTimers()
		local party
		ns.Unit.ForEach(function(f) if f.unit == "party1" then party = f end end)
		assert(party and party.pipped and party.pipFill:IsShown(), "Role shapes off keeps the party's role pip")
		local r, g, b = K.Tokens.Color("steelLit")
		local pr, pg, pb = party.pipFill:GetVertexColor()
		assert(pr == r and pg == g and pb == b, "Role shapes off keeps the tidy lanes' metal role pips")
	end
	G.SetRoster(env, "raid", G.Members(40))
	env.RunTimers()
	if style == "medallions" then
		local count = 0
		ns.Unit.ForEach(function(f)
			if f.unit and f.kind == "raid" then
				count = count + 1
				local icon = f.statusIcons.resurrection
				assert(icon:GetWidth() == 14, "status icons keep their 14-unit size in tidy lanes")
				assert(math.abs(icon:GetLeft() + icon:GetWidth() / 2 - f.ready:GetLeft() - f.ready:GetWidth() / 2) <= 1
					and math.abs(icon:GetTop() - icon:GetHeight() / 2 - f.ready:GetTop() + f.ready:GetHeight() / 2) <= 1,
					"Status icons follow the tidy lanes' ready-check slot")
			end
		end)
		assert(count == 40, "check every live raid member's merged indicators")
	end
	assert(#env._errors == 0, style .. ": " .. tostring(env._errors[1]))
end
for _, style in ipairs({ "medallions" }) do
	Check(style)
	collectgarbage("collect")
end
print("group accessibility styles ok")
