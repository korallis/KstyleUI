-- test-unitframes-cast-parity.lua: on the Medallions player cast bar, smoothing, channel colour and total duration preserve legacy defaults; uninterruptible colour keeps priority, including secret flags; on Frames the icon side and the total's wider column hold on the plate and the caption cast.
local U = dofile("Tools/regression/unitframes_env.lua")
local env, K, ns = U.New({ plate = true, saved = { version = 42, profiles = { Default = { UnitFrames = { enabled = true } } }, characters = {} } })
local W, settings = U.W, ns.Settings
local cb = ns.CastBars.Inline("player")[1]
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
assert(not settings.Value("player", "castbarTotal"), "v0.2.8 keeps the remaining time")
local function timer()
	start(false, false)
	cb.frame:GetScript("OnUpdate")(cb.frame, 1)
	return W.LastCall(cb.timer, "SetFormattedText")[1]
end
assert(timer() ~= "%.1f / %.1f", "the timer counts down by default")
write("castbarTotal", true)
assert(timer() == "%.1f / %.1f", "the timer shows elapsed and total time")
write("castbarTotal", false)
assert(timer() ~= "%.1f / %.1f", "the cast option restores")
assert(#env._errors == 0 and K.ErrorCount() == 0, "cast options apply without errors")

local function frames(plate)
	return U.New({ frames = true, plate = plate, saved = { version = 42, profiles = { Default = { UnitFrames = { enabled = true } } }, characters = {} } })
end
local penv, PK, pns = frames(true)
local pcb = pns.CastBars.Get("player")[1]
local function pwrite(key, value)
	PK.Options.Write("UnitFrames", "player." .. key, value)
	penv.RunTimers()
end
local function ptimer()
	penv._units.player.cast = { name = "Frostbolt", texture = 135846, start = 1000, finish = 4000, spellID = 116 }
	penv.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-1", 116)
	pcb.frame:GetScript("OnUpdate")(pcb.frame, 1)
	return W.LastCall(pcb.timer, "SetFormattedText")[1]
end
assert(not pns.Settings.Value("player", "castbarIconRight"), "v0.2.8 keeps the icon left")
local geo = pcb.geometry
assert(geo.icon.x == 0 and geo.panel.x > 0 and ptimer() ~= "%.1f / %.1f", "the icon leads and the timer counts down by default")
local column, width = geo.timer.w, geo.panel.x + geo.panel.w
pwrite("castbarIconRight", true)
geo = pcb.geometry
assert(geo.panel.x == 0 and geo.icon.x > geo.bar.x + geo.bar.w and geo.icon.x + geo.icon.w == width, "the icon moves to the right end")
assert(W.LastCall(pcb.iconFrame, "SetPoint")[4] > 0, "the icon frame is placed at the right")
assert(PK.Store.Module("UnitFrames").player.castbarIconRight, "the icon side is saved")
pwrite("castbarTotal", true)
assert(ptimer() == "%.1f / %.1f" and pcb.geometry.timer.w > column, "the timer shows elapsed and total time in a wider column")
pwrite("castbarIconRight", false)
pwrite("castbarTotal", false)
geo = pcb.geometry
assert(geo.icon.x == 0 and geo.timer.w == column and ptimer() ~= "%.1f / %.1f", "both cast options restore")
assert(#penv._errors == 0 and PK.ErrorCount() == 0, "Frames cast options apply without errors")
local cenv, CK, cns = frames(false)
local caption = cns.CastBars.Get("player")[1]
local function cast()
	cenv._units.player.cast = { name = "Frostbolt", texture = 135846, start = 1000, finish = 4000, spellID = 116 }
	cenv.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-1", 116)
end
cast()
assert(caption.mode == "inside" and caption.geometry.icon.x == 0, "the caption cast leads with its icon by default")
CK.Options.Write("UnitFrames", "player.castbarIconRight", true); cenv.RunTimers(); cast()
local icon = caption.geometry.icon
assert(icon.x > 0 and W.LastCall(caption.bar, "SetPoint")[4] == 0, "the caption cast puts its icon after the bar")
CK.Options.Write("UnitFrames", "player.castbarInside", false); cenv.RunTimers(); cast()
icon = caption.geometry.icon
local point = W.LastCall(caption.timer, "SetPoint")
assert(caption.mode == "above" and point[2] == caption.frame and icon.x + icon.w + point[4] <= icon.x, "the caption timer ends before a right-hand icon")
assert(#cenv._errors == 0 and CK.ErrorCount() == 0, "the caption icon side applies without errors")
print("cast parity ok")
