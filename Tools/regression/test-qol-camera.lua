-- test-qol-camera.lua: max camera distance writes the game's own maximum to cameraDistanceMaxZoomFactor, out of combat, and puts the player's value back when it stops.
local Q = dofile("Tools/regression/qol_env.lua")

local CVAR = "cameraDistanceMaxZoomFactor"

local function Writes(env)
	local out = {}
	for _, call in ipairs(Q.Calls(env, "SetCVar")) do
		if call[1] == CVAR then
			out[#out + 1] = tostring(call[2])
		end
	end
	return table.concat(out, ",")
end

-- The module on writes Forever's maximum, 2, and remembers the player's value on this character.
do
	local env, K = Q.New()
	Q.Enable(env, K)
	assert(Writes(env) == "2", "the game's maximum is written, got " .. Writes(env))
	assert(tonumber(env._cvars[CVAR]) == 2, "the camera reaches the maximum")
	local memory = K.Store.Account().qolCamera
	local record = memory and memory[K.Store.CharacterKey()]
	assert(record and record.original == "1.9" and record.written == env._cvars[CVAR], "the player's value is remembered with what KstyleUI wrote")

	Q.Write(env, K, "maxCamera", false)
	assert(tonumber(env._cvars[CVAR]) == 1.9, "turning it off puts the player's value back")
	assert(K.Store.Account().qolCamera[K.Store.CharacterKey()] == nil, "and forgets the record")

	Q.Write(env, K, "maxCamera", true)
	Q.Disable(env, K)
	assert(tonumber(env._cvars[CVAR]) == 1.9, "turning the module off puts it back too")
end

-- Already at the maximum: nothing to write and nothing to put back later.
do
	local env, K = Q.New({ setup = function(env)
		env._cvars[CVAR] = "2.000000"
	end })
	Q.Enable(env, K)
	assert(Writes(env) == "", "a camera already at the maximum is left alone")
	assert(K.Store.Account().qolCamera == nil or next(K.Store.Account().qolCamera) == nil, "nothing is remembered")
end

-- Combat: the write waits for combat to end.
do
	local env, K = Q.New()
	Q.Enable(env, K)
	Q.Write(env, K, "maxCamera", false)
	Q.Reset(env)
	env.SetCombat(true)
	Q.Write(env, K, "maxCamera", true)
	assert(Writes(env) == "", "nothing is written in combat")
	env.SetCombat(false)
	env.RunTimers()
	assert(Writes(env) == "2", "the write runs when combat ends, got " .. Writes(env))
	Q.Reset(env)
	env.SetCombat(true)
	Q.Write(env, K, "maxCamera", false)
	assert(Writes(env) == "", "putting the value back waits for combat to end too")
	env.SetCombat(false)
	env.RunTimers()
	assert(tonumber(env._cvars[CVAR]) == 1.9, "and runs when it ends")
end

-- The game refuses the value: nothing is remembered, and nothing is put back.
do
	local env, K = Q.New({ setup = function(env)
		env._refuseCVar = true
	end })
	Q.Enable(env, K)
	assert(env._cvars[CVAR] == "1.9", "the player's value stays")
	assert(K.Store.Account().qolCamera == nil or next(K.Store.Account().qolCamera) == nil, "a refused write is not remembered")
end

-- The player changes the slider after KstyleUI wrote: turning the feature off keeps the player's new value.
do
	local env, K = Q.New()
	Q.Enable(env, K)
	env._cvars[CVAR] = "1.500000"
	Q.Write(env, K, "maxCamera", false)
	assert(env._cvars[CVAR] == "1.500000", "a value the player set later is kept")
end

-- The login sweep puts the value back on a character whose QoL module is off, as it does for Chat's timestamps.
do
	local cvars = assert(io.open("Core/CVars.lua", "rb")):read("*a")
	assert(cvars:find('module = "QoL", key = "qolCamera", cvar = "cameraDistanceMaxZoomFactor"', 1, true), "Core/CVars.lua sweeps qolCamera")
end

print("qol camera ok")
