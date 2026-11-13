-- test-unitframes-cast-flashes.lua: a cast bar reports how its cast ended with a short flash the client animates: gilt over the full bar when the cast stops complete, red over the emptied track when it is interrupted or fails, with the engine's timer replaced by a zero duration; another cast's stop and a channel's end do not flash, a new cast clears a flash still running, and with motion off nothing flashes.
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

local ended = {}
function ended:SetTimeSpan(startTime, endTime)
	self.span = { startTime, endTime }
end
env.C_DurationUtil = { CreateDuration = function()
	return ended
end }
local ELAPSED, REMAINING = env.Enum.StatusBarTimerDirection.ElapsedTime, env.Enum.StatusBarTimerDirection.RemainingTime

local function ended_as(direction)
	local timer = W.LastCall(player.bar, "SetTimerDuration")
	return timer and timer[1] == ended and timer[3] == direction and ended.span and ended.span[2] <= env._time
end

local function emptied()
	return ended_as(REMAINING)
end

env._time = 1
cast(1, 4)
assert(not emptied(), "a cast runs the engine's timer")
env.FireEvent("UNIT_SPELLCAST_STOP", "player", "Cast-9", 2139, 9)
assert(player.active and not flash.group:IsPlaying(), "another cast's stop does not flash")
env._units.player.cast = nil
env.FireEvent("UNIT_SPELLCAST_STOP", "player", "Cast-1", 116, 4)
assert(flash:IsShown() and flash.group:IsPlaying() and color("giltLit", 0.6), "a landed cast flashes gilt")
assert(ended_as(ELAPSED) and W.LastCall(player.bar, "SetValue")[1] == 1, "the engine's timer is bound to a span that has ended, read as elapsed, so the bar stays full under the flash")
assert(U.Shown(env, player.timer) == "", "the time text clears")
assert(player.frame:IsShown(), "the bar holds while the flash plays")
local anims = flash.group._anims
assert(#anims == 2 and W.Near(W.LastCall(anims[1], "SetDuration")[1], K.Tokens.Duration("pressIn")) and W.Near(W.LastCall(anims[2], "SetDuration")[1], K.Tokens.Duration("readyFlash")), "in at pressIn, out at readyFlash")
for _, frame in ipairs(env._frames) do
	assert(frame ~= flash or not frame:GetScript("OnUpdate"), "the flash runs no OnUpdate")
end
flash.group:Stop()
flash.group:GetScript("OnFinished")(flash.group)
assert(not flash:IsShown(), "the flash hides when it ends")
env.RunTimers()
W.Settle(env)
assert(not player.frame:IsShown(), "and the bar goes after its hold")

cast(2, 5)
env._units.player.cast = nil
env.FireEvent("UNIT_SPELLCAST_INTERRUPTED", "player", "Cast-2", 116, 5)
assert(emptied() and W.LastCall(player.bar, "SetValue")[1] == 0, "an interrupted cast stops the timer and empties the bar")
assert(flash.group:IsPlaying() and color("hostile", 0.55), "and flashes red")
env.FireEvent("UNIT_SPELLCAST_STOP", "player", "Cast-2", 116, 5)
assert(color("hostile", 0.55), "the stop after an interrupt keeps the red")
cast(3, 7)
assert(not flash:IsShown() and not flash.group:IsPlaying(), "a new cast clears the flash still running")
env._units.player.cast = nil
env.FireEvent("UNIT_SPELLCAST_STOP", "player", "Cast-3", 116, 7)
env.FireEvent("UNIT_SPELLCAST_INTERRUPTED", "player", "Cast-3", 116, 7)
assert(W.LastCall(player.bar, "SetValue")[1] == 0 and color("hostile", 0.55), "an interrupt that follows the stop still turns the bar red")
flash.group:Stop()
env.RunTimers()
W.Settle(env)

cast(6, 9)
env._units.player.cast = nil
env.FireEvent("UNIT_SPELLCAST_STOP", "player", "Cast-6", 116, 9)
env.FireEvent("UNIT_SPELLCAST_FAILED", "player", "Cast-7", 2139, nil)
assert(color("giltLit", 0.6) and W.LastCall(player.bar, "SetValue")[1] == 1, "another spell's failure during the hold leaves the landed bar gilt")
env.FireEvent("UNIT_SPELLCAST_INTERRUPTED", "player", "Cast-6", 116, nil, nil)
assert(color("hostile", 0.55), "the landed spell's own interrupt with no bar id still turns it red")
flash.group:Stop()
env.RunTimers()
W.Settle(env)

env._units.player.nilDuration = true
cast(7, 10)
local timers = #W.Calls(player.bar, "SetTimerDuration")
env._units.player.cast = nil
env.FireEvent("UNIT_SPELLCAST_INTERRUPTED", "player", "Cast-7", 116, nil, 10)
assert(#W.Calls(player.bar, "SetTimerDuration") == timers and W.LastCall(player.bar, "SetValue")[1] == 0, "a bar run on the cast times empties with SetValue and binds no timer")
env._units.player.nilDuration = nil
flash.group:Stop()
env.RunTimers()
W.Settle(env)

env._units.player.channel = { name = "Arcane Missiles", texture = 136096, start = 1000, finish = 4000, spellID = 5143, barID = 6 }
env.FireEvent("UNIT_SPELLCAST_CHANNEL_START", "player", "Cast-5", 5143, 6)
env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-5", 5143, 6)
env._units.player.channel = nil
env.FireEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player", "Cast-5", 5143, nil, 6)
assert(not flash.group:IsPlaying() and emptied(), "a channel's end does not flash, and its timer is let go")
env.RunTimers()
W.Settle(env)
env._units.player.channel = { name = "Arcane Missiles", texture = 136096, start = 1000, finish = 4000, spellID = 5143, barID = 11 }
env.FireEvent("UNIT_SPELLCAST_CHANNEL_START", "player", "Cast-8", 5143, 11)
env._units.player.channel = nil
env.FireEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player", "Cast-8", 5143, "Creature-0-1-2-3-4-5", 11)
assert(flash.group:IsPlaying() and color("hostile", 0.55) and emptied(), "a channel stopped by someone turns red")
flash.group:Stop()
env.RunTimers()
W.Settle(env)

K.Motion.SetLevel("off")
cast(4, 8)
env._units.player.cast = nil
env.FireEvent("UNIT_SPELLCAST_STOP", "player", "Cast-4", 116, 8)
assert(not flash.group:IsPlaying(), "with motion off a landed cast does not flash")
K.Motion.SetLevel("full")
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("unitframes cast flashes ok")
