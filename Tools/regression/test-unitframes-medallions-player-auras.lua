-- test-unitframes-medallions-player-auras.lua: the Medallions player frame leaves buffs to the Auras rows by default; a saved choice stays.
local U = dofile("Tools/regression/unitframes_env.lua")

local function Boot(saved)
	local env, K, ns = U.New({ saved = saved })
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
	local auras = ns.Frames.Get("player").views[1].auras
	return ns.Settings.Value("player", "auras"), auras and auras.container._enabled, env, K, ns
end
local function Old(style, player)
	return { version = 43, profiles = { Default = { UnitFrames = { enabled = true, player = player }, HudStyle = { style = style } } } }
end

local value, shown, env, K, ns = Boot(Old("medallions", nil))
assert(value == false and not shown, "an old profile on the old default shows no buffs on the Medallions player frame")
value, shown = Boot(Old("medallions", { medallionsAuras = true }))
assert(value == false and not shown, "an old profile that saved the old default (an import or a logout without Unit Frames) moves to off")
value, shown = Boot(Old("medallions", { medallionsAuras = false }))
assert(value == false and not shown, "a player who turned them off keeps them off")

local body = K.Codec.Serialize({ kind = "KstyleUI profile", version = 43, name = "Old", settings = Old("medallions", { medallionsAuras = true }).profiles.Default })
assert(K.Store.Import("KSUI1:" .. K.Codec.EncodeBase64("KSL1:" .. #body .. ":" .. K.Codec.Adler32(body) .. ":" .. body), "Old"))
assert(ns.Settings.Value("player", "auras") == false, "importing an old profile string that carries the old default moves it to off")

assert(K.Store.SetProfile("Default") ~= false)
K.Options.Write("UnitFrames", "player.medallionsAuras", true)
for reload = 1, 2 do
	env.FireEvent("PLAYER_LOGOUT")
	value, shown, env = Boot(env.KstyleUIDB)
	assert(value == true and shown, "a player who turns the Medallions player auras on after the update keeps them, reload " .. reload)
end
assert(Boot(Old("frames", nil)) == false and Boot(Old("frames", { auras = true })) == true, "Frames keeps its own player aura setting")
assert(Boot(Old("orbs", { auras = true })) == false, "Orbs profiles move to Medallions, whose player frame leaves buffs to the Auras rows")
print("medallions player auras ok: off by default, old saved defaults and imports move to off, new choices kept, Frames unchanged, Orbs profiles move to Medallions")
