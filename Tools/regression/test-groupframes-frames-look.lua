-- test-groupframes-frames-look.lua: choosing Frames writes HudStyle.FRAMES_LOOK to the group frames and plates, choosing Medallions restores the defaults, a value the player set in between survives both, and the plates' preset stays put.
local G = dofile("Tools/regression/group_env.lua")
local N = dofile("Tools/regression/nameplates_env.lua")

local function Check(env, K, module, changed, value)
	local look = K.HudStyle.FRAMES_LOOK[module]
	assert(next(look), module .. " has a Frames look")
	for key in pairs(look) do
		assert(K.Options.Read(module, key) == K.Options.Default(module, key), module .. " " .. key .. " starts at its default")
	end
	K.Options.Write("HudStyle", "style", "frames")
	env.RunTimers()
	assert(K.HudStyle.Current() == "frames", "the style switches")
	for key, frames in pairs(look) do
		assert(K.Options.Read(module, key) == frames, module .. " " .. key .. " takes the Frames value " .. tostring(frames))
	end
	K.Options.Write(module, changed, value)
	K.Options.Write("HudStyle", "style", "medallions")
	env.RunTimers()
	for key in pairs(look) do
		local want = key == changed and value or K.Options.Default(module, key)
		assert(K.Options.Read(module, key) == want, module .. " " .. key .. " reads " .. tostring(want) .. " back on Medallions")
	end
	K.Options.Write("HudStyle", "style", "frames")
	env.RunTimers()
	assert(K.Options.Read(module, changed) == value, module .. " " .. changed .. ": the player's value survives Frames again")
	assert(#env._errors == 0 and K.ErrorCount() == 0, module .. ": " .. tostring(env._errors[1]))
end

do
	local env, K = G.New()
	Check(env, K, "GroupFrames", "raid.buffCount", 2)
end

do
	local env, K, ns = N.New()
	assert(ns.Settings.Get("preset") == "lumen", "the plates start on the Minimal preset")
	Check(env, K, "Nameplates", "name.size", 18)
	K.Options.Write("Nameplates", "preset", "lumen")
	assert(ns.Settings.Get("name.size") == 16 and ns.Settings.Get("debuffs.size") == 29, "Minimal on Frames restores Frames' plate look")
	K.Options.Write("HudStyle", "style", "medallions")
	env.RunTimers()
	assert(ns.Settings.Get("preset") == "lumen", "switching style leaves the preset on Minimal")
	assert(ns.Settings.Get("name.size") == 11 and ns.Settings.Get("debuffs.size") == 22, "and Medallions' look returns")
end

do
	local env, K = G.New()
	K.Options.Write("GroupFrames", "party.portrait", false)
	K.Options.Write("HudStyle", "style", "frames")
	K.Options.Write("HudStyle", "style", "medallions")
	env.RunTimers()
	assert(K.Options.Read("GroupFrames", "party.portrait") == false, "a Medallions value the player set that matches the Frames look survives Frames and back")
end

do
	local C = G.CoreEnv
	local env, K = C.New()
	C.Boot(env)
	assert(K.Store.Defaults("GroupFrames") == nil, "the group frames are not loaded")
	K.Options.Write("HudStyle", "style", "frames")
	C.Logout(env)
	local _, later = G.New({ saved = C.DeepCopy(env.KstyleUIDB) })
	assert(later.HudStyle.Current() == "frames" and later.Options.Read("GroupFrames", "party.portrait") == false, "a module loaded after Frames was chosen gets the Frames look at login")
end

print("groupframes frames look ok")
