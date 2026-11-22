-- test-unitframes-medallions-player-auras.lua: the Medallions player frame leaves buffs to the Auras rows by default; a saved choice stays.
local U = dofile("Tools/regression/unitframes_env.lua")

local function Boot(style, player)
	local env, K, ns = U.New({
		saved = { version = 2, profiles = { Default = { UnitFrames = { enabled = true, player = player }, HudStyle = { style = style } } }, characters = {} },
	})
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
	local auras = ns.Frames.Get("player").views[1].auras
	return ns.Settings.Value("player", "auras"), auras and auras.container._enabled
end

local value, shown = Boot("medallions", nil)
assert(value == false and not shown, "an old profile on the old default shows no buffs on the Medallions player frame")
value, shown = Boot("medallions", { medallionsAuras = true })
assert(value == true and shown, "a player who turns the Medallions player auras on keeps them")
value, shown = Boot("medallions", { medallionsAuras = false })
assert(value == false and not shown, "a player who turned them off keeps them off")
for _, style in ipairs({ "frames", "orbs" }) do
	assert(Boot(style, nil) == false and Boot(style, { auras = true }) == true, style .. " keeps its own player aura setting")
end
print("medallions player auras ok: off by default, saved choices kept, Frames and Orbs unchanged")
