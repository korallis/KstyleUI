-- test-cast-outcomes.lua: outcomes hold independently of motion, channels acknowledge completion and pushback updates only the timer.
local U = dofile("Tools/regression/unitframes_env.lua")
local N = dofile("Tools/regression/nameplates_env.lua")
local W = U.W

for _, level in ipairs({ "full", "reduced", "off" }) do
	local env, K, ns = U.New({ plate = true })
	K.Motion.SetLevel(level)
	local pending = {}
	env.C_Timer.After = function(seconds, fn) pending[#pending + 1] = { seconds, fn } end
	local cb = ns.CastBars.Get("player")[1]
	local function start(channel)
		env._units.player[channel and "channel" or "cast"] = { name = "Fear", texture = 136183, start = 1000, finish = 4000, spellID = 5782 }
		env.FireEvent(channel and "UNIT_SPELLCAST_CHANNEL_START" or "UNIT_SPELLCAST_START", "player")
	end
	start()
	local sheen = 0
	cb.bar.PlaySheen = function() sheen = sheen + 1 end
	env.FireEvent("UNIT_SPELLCAST_DELAYED", "player")
	assert(sheen == 0, "E3: pushback must update the timer without replaying the start sheen")
	env._units.player.cast = nil
	env.FireEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
	assert(W.LastCall(cb.bar, "SetValue")[1] == 1, "E3: keep a full hostile bar under Interrupted")
	assert(pending[#pending][1] == 0.9 and cb.frame:IsShown(), "E3: the 0.9 s interrupt hold survives Motion Off")
	assert(W.LastCall(cb.flash.wash, "SetBlendMode")[1] == "BLEND", "E3: outcomes use a soft blend wash")
	assert(cb.flash.down._state.Duration[1] == 0.22 and cb.flash.down._state.Smoothing[1] == "OUT", "E3: the wash decays OUT over castFlash")
	W.Tick(env, 0.3)
	assert(cb.frame:IsShown(), "E3: a fade cannot consume the interrupt hold")
	pending[#pending][2]()
	W.Tick(env, 0.3)
	assert(not cb.frame:IsShown(), "E3: the bar leaves after its hold and fade")
	start(true)
	env._units.player.channel = nil
	env.FireEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
	assert(cb.landed and cb.frame:IsShown(), "E3: a completed channel gets the landed acknowledgement")
	if level == "full" then
		local c = W.LastCall(cb.flash.wash, "SetVertexColor")
		local r, g, b = K.Tokens.Color("white")
		assert(c[1] == r and c[2] == g and c[3] == b and c[4] == 0.22, "E3: landed acknowledgement is white at 22 percent")
	end
	K.Options.Write("UnitFrames", "castOutcomes", false)
	start()
	env._units.player.cast = nil
	env.FireEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
	assert(W.LastCall(cb.bar, "SetValue")[1] == 0 and pending[#pending][1] == 0.6, "E3: off restores the empty bar and original hold")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

for _, level in ipairs({ "full", "calm", "off" }) do
	local env, K, ns = U.New()
	K.Options.Write("HudStyle", "style", "medallions")
	K.Options.Write("Medallions", "motion", level)
	local cb = ns.CastBars.Inline("player")[1]
	env._units.player.cast = { name = "Fear", texture = 136183, start = 1000, finish = 4000, spellID = 5782 }
	env.FireEvent("UNIT_SPELLCAST_START", "player")
	local seconds
	env.C_Timer.After = function(delay) seconds = delay end
	env._units.player.cast = nil
	env.FireEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
	assert(seconds == 0.9 and cb.frame:IsShown() and W.LastCall(cb.bar, "SetValue")[1] == 1, "E3: Medallions keeps the full error bar at " .. level)
	if level ~= "off" then
		assert(cb.medStreak.move._state.Duration[1] == 0.35, "E3: the outcome streak travels for 350 ms")
		assert(W.LastCall(cb.medStreak.streak, "SetVertexColor")[4] == 0.6, "E3: the streak is capped at 60 percent")
	end
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

do
	local env, K, ns = N.New()
	K.Motion.SetLevel("off")
	N.Add(env, "nameplate1")
	local plate = ns.Plates.Get("nameplate1")
	local pending = {}
	env.C_Timer.After = function(seconds, fn) pending[#pending + 1] = { seconds, fn } end
	local function start()
		N.Cast(env, "nameplate1", { name = "Fear", text = "Fear", texture = 136183 })
	end
	start()
	env._units.nameplate1.cast = nil
	env.FireEvent("UNIT_SPELLCAST_INTERRUPTED", "nameplate1")
	assert(plate.cast:IsShown() and pending[#pending][1] == 0.9, "E3: nameplates hold on a timer even with Motion Off")
	local stale = pending[#pending][2]
	start()
	stale()
	assert(plate.cast:IsShown() and plate.casting, "E3: an old interrupt timer cannot hide a new cast")
	env._units.nameplate1.cast = nil
	env.FireEvent("UNIT_SPELLCAST_FAILED", "nameplate1")
	assert(plate.castInterrupted and N.Last(plate.castName, "SetText")[1] == K.Locale.Upper(K.L["Failed"]), "E3: a failed plate cast shows its own held outcome")
	pending[#pending][2]()
	assert(not plate.cast:IsShown(), "E3: a held plate leaves when its timer expires")
	K.Options.Write("Nameplates", "cast.outcomes", false)
	start()
	env._units.nameplate1.cast = nil
	env.FireEvent("UNIT_SPELLCAST_INTERRUPTED", "nameplate1")
	assert(not plate.cast:IsShown(), "E3: off restores the original Motion Off plate exit")
	K.Motion.SetLevel("full")
	K.Options.Write("Nameplates", "cast.outcomes", true)
	start()
	env._units.nameplate1.cast = nil
	env.FireEvent("UNIT_SPELLCAST_STOP", "nameplate1")
	W.Tick(env, 0.1)
	assert(math.abs(plate.cast:GetAlpha() - 0.75) < 1e-6, "E3: normal plate casts leave with an inQuad fade")
	W.Tick(env, 0.1)
	assert(not plate.cast:IsShown(), "E3: the normal plate exit finishes after 200 ms")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
print("cast outcomes ok")
