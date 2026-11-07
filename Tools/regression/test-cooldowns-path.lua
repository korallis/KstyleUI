-- test-cooldowns-path.lua: each Cooldowns group picks the mirror or the reskin path from what the client allows and the path setting, and logs the choice.
local C = dofile("Tools/regression/cooldowns_env.lua")

local function Paths(ns)
	local out = {}
	for _, group in ipairs({ "essential", "utility", "buffs", "bars" }) do
		out[#out + 1] = group .. "=" .. tostring(ns.Path.Get(group))
	end
	return table.concat(out, " ")
end

local function Expect(ns, wanted, what)
	assert(Paths(ns) == wanted, what .. ": expected " .. wanted .. ", got " .. Paths(ns))
end

local function Logged(env, text)
	for _, line in ipairs(env.KstyleUIDB.devlog) do
		if line.module == "Cooldowns" and tostring(line.message):find(text, 1, true) then
			return true
		end
	end
	return false
end

-- Automatic on Forever: cooldown rows mirror; tracked buffs, whose aura data can turn secret in combat, restyle Blizzard's viewers.
do
	local env, K, ns = C.New({ setup = C.Viewers })
	C.Enable(env, K)
	Expect(ns, "essential=mirror utility=mirror buffs=reskin bars=reskin", "automatic with secret auras")
	assert(Logged(env, "buffs: reskin path"), "the reskin choice is logged")
	assert(Logged(env, "aura data can turn secret"), "the reason for the reskin is logged")
	local listening = false
	for _, frame in ipairs(env._frames) do
		listening = listening or frame:IsEventRegistered("UNIT_AURA")
	end
	assert(not listening, "with no buff group mirrored, the module does not listen to UNIT_AURA")
end

-- Automatic on a client without aura secrets: every group mirrors.
do
	local env, K, ns = C.New({ setup = function(env)
		C.Viewers(env)
		env.C_Secrets = nil
	end })
	C.Enable(env, K)
	Expect(ns, "essential=mirror utility=mirror buffs=mirror bars=mirror", "automatic without aura secrets")
end

-- No duration API: automatic restyles every group in place.
do
	local env, K, ns = C.New({ noDuration = true, setup = C.Viewers })
	C.Enable(env, K)
	Expect(ns, "essential=reskin utility=reskin buffs=reskin bars=reskin", "automatic without duration objects")
end

-- The path setting forces a path; forcing the mirror where it cannot run falls back to the reskin.
do
	local env, K, ns = C.New({ setup = C.Viewers })
	K.Options.Write("Cooldowns", "path", "reskin")
	C.Enable(env, K)
	Expect(ns, "essential=reskin utility=reskin buffs=reskin bars=reskin", "forced reskin")
	for _, frame in ipairs(env._frames) do
		assert(not frame:IsEventRegistered("SPELL_UPDATE_COOLDOWN"), "the reskin path listens to no cooldown events")
	end
	K.Options.Write("Cooldowns", "path", "mirror")
	Expect(ns, "essential=mirror utility=mirror buffs=mirror bars=mirror", "forced mirror applies at once")
end

-- No Blizzard viewer and no mirror: the group is off and says so.
do
	local env, K, ns = C.New({ noViewer = true, noDuration = true })
	C.Enable(env, K)
	Expect(ns, "essential=off utility=off buffs=off bars=off", "nothing available")
end

print("cooldowns path ok")
