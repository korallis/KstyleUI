-- test-unitframes-cast-flashes.lua: a cast bar reports how its cast ended with a short flash the client animates: gilt over the bar when the cast lands, red over the emptied track when it is interrupted or fails; a channel's start or another cast's success does not flash, and with motion off nothing flashes.
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W

local env, K, ns = U.New({ plate = true })
local player = ns.CastBars.Get("player")[1]
local flash = assert(player.flash, "the cast bar has a flash layer")
assert(W.LastCall(flash.wash, "SetBlendMode")[1] == "ADD" and not flash:IsShown(), "an additive wash, hidden at rest")

local function color(name, alpha)
	local r, g, b, a = flash.wash:GetVertexColor()
	local er, eg, eb, ea = K.Widgets.Rgba(name, alpha)
	return W.Near(r, er) and W.Near(g, eg) and W.Near(b, eb) and W.Near(a, ea)
end

local function cast(id, bar)
	env._units.player.cast = { name = "Frostbolt", texture = 135846, start = 1000, finish = 3500, spellID = 116, barID = bar }
	env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-" .. id, 116, bar)
end

env._time = 1
cast(1, 4)
env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-9", 2139, 9)
assert(not flash.group:IsPlaying(), "another cast's success does not flash")
env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 116, 4)
assert(flash:IsShown() and flash.group:IsPlaying() and color("giltLit", 0.6), "a landed cast flashes gilt")
local anims = flash.group._anims
assert(#anims == 2 and W.Near(W.LastCall(anims[1], "SetDuration")[1], K.Tokens.Duration("pressIn")) and W.Near(W.LastCall(anims[2], "SetDuration")[1], K.Tokens.Duration("readyFlash")), "in at pressIn, out at readyFlash")
for _, frame in ipairs(env._frames) do
	assert(frame ~= flash or not frame:GetScript("OnUpdate"), "the flash runs no OnUpdate")
end
env._units.player.cast = nil
env.FireEvent("UNIT_SPELLCAST_STOP", "player", "Cast-1", 116, 4)
flash.group:Stop()
flash.group:GetScript("OnFinished")(flash.group)
assert(not flash:IsShown(), "the flash hides when it ends")
env.RunTimers()
W.Settle(env)

cast(2, 5)
env._units.player.cast = nil
env.FireEvent("UNIT_SPELLCAST_INTERRUPTED", "player", "Cast-2", 116, 5)
assert(W.LastCall(player.bar, "SetValue")[1] == 0, "an interrupted cast empties the bar")
assert(flash.group:IsPlaying() and color("hostile", 0.55), "and flashes red")
flash.group:Stop()
env.RunTimers()
W.Settle(env)

env._units.player.channel = { name = "Arcane Missiles", texture = 136096, start = 1000, finish = 4000, spellID = 5143, barID = 6 }
env.FireEvent("UNIT_SPELLCAST_CHANNEL_START", "player", "Cast-3", 5143, 6)
env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3", 5143, 6)
assert(not flash.group:IsPlaying(), "a channel's start success does not flash")
env._units.player.channel = nil
env.FireEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player", "Cast-3", 5143, 6)
env.RunTimers()
W.Settle(env)

K.Motion.SetLevel("off")
cast(4, 8)
env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-4", 116, 8)
assert(not flash.group:IsPlaying(), "with motion off a landed cast does not flash")
K.Motion.SetLevel("full")
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("unitframes cast flashes ok")
