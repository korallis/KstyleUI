-- test-unitframes-cast-parity.lua: player cast smoothing and channel colour preserve legacy defaults and uninterruptible priority, including secret flags.
local U = dofile("Tools/regression/unitframes_env.lua")
local env, K, ns = U.New({ plate = true, saved = { version = 42, profiles = { Default = { UnitFrames = { enabled = true } } }, characters = {} } })
local W, settings = U.W, ns.Settings
local cb = ns.CastBars.Get("player")[1]
local function start(channel, locked)
	env._units.player.cast, env._units.player.channel = nil, nil
	env._units.player[channel and "channel" or "cast"] = { name = "Frostbolt", texture = 135846, start = 1000, finish = 4000, spellID = 116, notInterruptible = locked }
	env.FireEvent(channel and "UNIT_SPELLCAST_CHANNEL_START" or "UNIT_SPELLCAST_START", "player", "Cast-1", 116)
end
local function write(key, value)
	K.Options.Write("UnitFrames", "player." .. key, value); env.RunTimers(); start(true, false)
end
assert(not settings.Value("player", "castbarSmooth") and not settings.Value("player", "castbarChannelOverride"), "v0.2.8 defaults stay immediate and use the normal colour")
start(false, false)
assert(W.LastCall(cb.bar, "SetTimerDuration")[2] == env.Enum.StatusBarInterpolation.Immediate, "default interpolation")
write("castbarSmooth", true)
assert(W.LastCall(cb.bar, "SetTimerDuration")[2] == env.Enum.StatusBarInterpolation.ExponentialEaseOut, "native channel smoothing applies")
start(false, false)
assert(W.LastCall(cb.bar, "SetTimerDuration")[2] == env.Enum.StatusBarInterpolation.ExponentialEaseOut, "native cast smoothing applies")
env._units.player.cast = nil
env.C_DurationUtil = { CreateDuration = function() return { SetTimeSpan = function() end } end }
env.FireEvent("UNIT_SPELLCAST_STOP", "player", "Cast-1", 116)
assert(W.LastCall(cb.bar, "SetTimerDuration")[2] == env.Enum.StatusBarInterpolation.Immediate, "completion snaps immediately even when cast progress is smoothed")
assert(#env._errors == 0 and K.ErrorCount() == 0, "completion accepts the interpolation helper's default")
write("castbarSmooth", false)
assert(W.LastCall(cb.bar, "SetTimerDuration")[2] == env.Enum.StatusBarInterpolation.Immediate, "immediate interpolation restores")
local r, g, b = K.Tokens.Color("hostile")
write("castbarChannelColor", { r = r, g = g, b = b })
write("castbarChannelOverride", true)
local color = W.LastCall(cb.bar, "SetStatusBarColor")
assert(color[1] == r and color[2] == g and color[3] == b, "channel colour applies")
start(false, false)
local ordinary = W.LastCall(cb.bar, "SetStatusBarColor")
assert(ordinary[1] ~= r or ordinary[2] ~= g or ordinary[3] ~= b, "ordinary casts keep their colour")
start(true, true)
local locked = settings.Value("player", "castbarLockedColor")
color = W.LastCall(cb.bar, "SetStatusBarColor")
assert(color[1] == locked.r and color[2] == locked.g and color[3] == locked.b, "uninterruptible colour takes priority")
env._units.player.secretCast = true
start(true, false)
local call = W.LastCall(cb.bar:GetStatusBarTexture(), "SetVertexColorFromBoolean")
assert(call and env.issecretvalue(call[1]), "secret interruptibility goes straight to the native boolean setter")
env._units.player.secretCast = nil
write("castbarChannelOverride", false)
color = W.LastCall(cb.bar, "SetStatusBarColor")
assert(color[1] == ordinary[1] and color[2] == ordinary[2] and color[3] == ordinary[3], "normal channel colour restores")
env.Enum.StatusBarInterpolation.ExponentialEaseOut = nil
write("castbarSmooth", true)
assert(W.LastCall(cb.bar, "SetTimerDuration")[2] == env.Enum.StatusBarInterpolation.Immediate, "missing smoothing falls back")
assert(K.Store.Module("UnitFrames").player.castbarSmooth, "the smoothing choice is saved")
assert(#env._errors == 0 and K.ErrorCount() == 0, "cast options apply without errors")
print("cast parity ok")
