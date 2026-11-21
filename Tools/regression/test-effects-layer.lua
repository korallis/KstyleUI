-- test-effects-layer.lua: the Medallions effects layer: the motion level is the lower of the Medallions setting and the Appearance motion setting and says what each kind of motion may do; EffectsLevelChanged fires once per change; the arbiter gives each place to the higher priority, lets an equal one replace, refuses a lower one and suspends ambient motion while any effect holds the place; the 3D pool never holds more than three live models, evicts only an equal or lower priority, plays the 2D twin when it refuses, when a file is refused or never loads, and below Full; the low-health vignette follows a health curve under Medallions only and its switch hides it and stops its breath; and secondary frames rest three seconds after combat.
local W = dofile("Tools/regression/widget_env.lua")

local FX = dofile("Tools/regression/effects_env.lua")

local function New()
	local env, K = W.New({ setup = FX.Install })
	return env, K
end

local function Medallions(env, K)
	K.Options.Write("HudStyle", "style", "medallions")
	env.RunTimers()
	assert(K.HudStyle.Current() == "medallions", "the style switches to Medallions")
end

local function Errors(env, K)
	assert(#env._errors == 0 and K.ErrorCount() == 0, "no errors: " .. tostring(env._errors[1]))
end

do
	local env, K = New()
	local E = K.Effects
	assert(E.Level() == "full", "Full is the default")
	local fired = {}
	K.Callbacks.Register("EffectsLevelChanged", "test", function(_, level, old)
		fired[#fired + 1] = old .. ">" .. level
	end)
	K.Options.Write("Medallions", "motion", "calm")
	assert(E.Level() == "calm", "the Medallions setting picks Calm")
	assert(not E.Allows("ambient") and E.Allows("flare"), "Calm keeps one-shot flares without ambient loops")
	assert(not E.Allows("pulse") and not E.Allows("particle") and not E.Allows("model"), "Calm drops loops, particles and 3D")
	K.Options.Write("Medallions", "motion", "full")
	K.Options.Write("Appearance", "motion", "reduced")
	assert(E.Level() == "calm", "the Appearance setting's Reduced caps the level at Calm")
	K.Options.Write("Appearance", "motion", "off")
	assert(E.Level() == "off", "the Appearance setting's Off turns every effect off")
	for _, kind in ipairs({ "ambient", "flare", "pulse", "particle", "model" }) do
		assert(not E.Allows(kind), "Off allows no " .. kind)
	end
	K.Options.Write("Appearance", "motion", "full")
	assert(E.Level() == "full" and E.Allows("model"), "Full allows 3D")
	assert(table.concat(fired, ",") == "full>calm,calm>full,full>calm,calm>off,off>full", "one notice per change: " .. table.concat(fired, ","))
	Errors(env, K)
end

do
	local env, K = New()
	local E, P = K.Effects, K.Effects.PRIORITY
	assert(P.lowHealth < P.proc and P.proc < P.ready and P.ready < P.cap and P.cap < P.combat and P.combat < P.rest and P.rest < P.ambient, "the priorities follow KSTY-87's table")
	local log = {}
	local function Stop(name)
		return function()
			log[#log + 1] = "stop " .. name
		end
	end
	local ambient = 0
	E.Ambient("slot", function()
		ambient = ambient + 1
	end, function()
		ambient = ambient - 1
	end)
	assert(ambient == 1, "ambient motion runs while the place is free")
	local ready = E.Claim("slot", P.ready, Stop("ready"))
	assert(ready and E.Holder("slot") == P.ready and ambient == 0, "an effect takes the place and ambient yields")
	assert(E.Claim("slot", P.cap, Stop("cap")) == nil, "a lower priority is refused")
	local proc = E.Claim("slot", P.proc, Stop("proc"))
	assert(proc and E.Holder("slot") == P.proc and log[1] == "stop ready", "a higher priority replaces the holder")
	assert(not E.Release("slot", ready), "the replaced effect cannot release the place")
	local again = E.Claim("slot", P.proc, Stop("proc2"))
	assert(again and log[2] == "stop proc", "an equal priority replaces the holder")
	assert(ambient == 0, "ambient stays suspended while any effect holds the place")
	assert(E.Release("slot", again) and E.Holder("slot") == nil and ambient == 1, "release frees the place and ambient resumes")
	E.ClaimFor("slot", P.combat, 0.5, nil)
	assert(E.Holder("slot") == P.combat and ambient == 0, "a timed claim holds the place")
	env.RunTimers()
	assert(E.Holder("slot") == nil and ambient == 1, "a timed claim frees the place when its time is up")
	K.Options.Write("Medallions", "motion", "off")
	assert(ambient == 0, "Off stops ambient motion")
	K.Options.Write("Medallions", "motion", "calm")
	assert(ambient == 0, "Calm leaves ambient loops stopped")
	K.Options.Write("Medallions", "motion", "full")
	assert(ambient == 1, "Full brings ambient motion back")
	Errors(env, K)
end

do
	local env, K = New()
	local E = K.Effects
	Medallions(env, K)
	local anchor = env.CreateFrame("Frame", nil, env.UIParent)
	anchor:SetSize(100, 100)
	anchor:SetFrameStrata("LOW")
	local twins = 0
	local function Twin()
		twins = twins + 1
	end
	local keys = { "levelUp", "SHAMAN", "MAGE", "PALADIN" }
	for i = 1, 3 do
		assert(E.Model(anchor, keys[i], 100, 1.2, E.PRIORITY.proc, Twin), "model " .. i .. " plays while the pool has room")
	end
	assert(E.LiveModels() == 3, "three models are live")
	assert(not E.Model(anchor, keys[4], 100, 1.2, E.PRIORITY.cap, Twin), "a lower priority is refused when the pool is full")
	assert(E.Model(anchor, keys[4], 100, 1.2, E.PRIORITY.lowHealth, Twin), "a higher priority evicts the oldest of the lowest")
	assert(twins == 1, "the evicted effect plays its 2D twin")
	assert(E.LiveModels() == 3, "the pool never holds more than three live models")
	local scenes = 0
	for _, frame in ipairs(env._frames) do
		if frame:GetObjectType() == "ModelScene" then
			scenes = scenes + 1
			if frame:IsShown() then
				assert(frame:GetFrameStrata() == "LOW", "a model takes its anchor's strata, so it stays under the action slots")
				local w, h = frame:GetSize()
				assert(w == 160 and h == 160, "a scene is larger than its effect so the model never clips")
			end
		end
	end
	assert(scenes == 3, "the pool makes no more than three scenes")
	E.StopModels()
	assert(E.LiveModels() == 0, "stopping frees every model")
	for _, frame in ipairs(env._frames) do
		if frame:GetObjectType() == "ModelScene" then
			assert(not frame:IsShown(), "an idle scene is hidden")
			assert(frame._state.Paused and frame._state.Paused[1] == true, "an idle scene is paused")
		end
	end

	for _, frame in ipairs(env._frames) do
		if frame:GetObjectType() == "ModelScene" then
			frame.actor.IsLoaded = function()
				return false
			end
		end
	end
	assert(E.Model(anchor, "WARLOCK", 100, 1.2, E.PRIORITY.proc, Twin), "the model starts loading")
	env.RunTimers()
	assert(twins == 2 and E.LiveModels() == 0, "a model that does not load in time gives way to its 2D twin")
	assert(not E.ModelFailed("WARLOCK"), "one slow load does not rule a file out")
	assert(E.Model(anchor, "WARLOCK", 100, 1.2, E.PRIORITY.proc, Twin), "the file is tried again")
	env.RunTimers()
	assert(twins == 3 and E.ModelFailed("WARLOCK"), "a file that misses twice is not tried again")
	assert(not E.Model(anchor, "WARLOCK", 100, 1.2, E.PRIORITY.proc, Twin), "the failed file plays nothing")

	for _, frame in ipairs(env._frames) do
		if frame:GetObjectType() == "ModelScene" then
			frame.actor.SetModelByFileID = function()
				return false
			end
		end
	end
	assert(not E.Model(anchor, "ROGUE", 100, 1.2, E.PRIORITY.proc, Twin), "a refused file plays no model")
	assert(E.ModelFailed("ROGUE"), "a refused file is not tried again")

	local played = E.Burst("hub", E.PRIORITY.levelUp, anchor, "DRUID", 100, 1.2, Twin, nil)
	assert(played == "2d" and twins == 4, "a burst falls back to its 2D twin when no model plays")
	K.Options.Write("Medallions", "motion", "calm")
	assert(not E.Model(anchor, "levelUp", 100, 1.2, E.PRIORITY.levelUp, Twin), "Calm plays no 3D")
	env.RunTimers()
	assert(E.Burst("hub", E.PRIORITY.levelUp, anchor, "levelUp", 100, 1.2, Twin, nil) == "2d" and twins == 5, "Calm plays the 2D twin")
	K.Options.Write("Medallions", "motion", "off")
	env.RunTimers()
	assert(not E.Burst("hub", E.PRIORITY.levelUp, anchor, "levelUp", 100, 1.2, Twin, nil) and twins == 5, "Off plays nothing")
	Errors(env, K)
end

do
	local env, K = New()
	local V = K.Effects.Vignette
	env.FireEvent("PLAYER_ENTERING_WORLD")
	assert(not (V.frame and V.frame:IsShown()), "no vignette under Frames")
	Medallions(env, K)
	env._health = 0.1
	env.FireEvent("PLAYER_ENTERING_WORLD")
	assert(V.frame and V.frame:IsShown(), "the vignette shows under Medallions")
	assert(V.frame:GetFrameStrata() == "BACKGROUND", "the vignette sits under every frame")
	assert(env.Reveal(V.frame._lastAlpha.args[1]) == 1, "low health shows the vignette in full through the curve")
	env._health = 0.9
	env.FireEvent("UNIT_HEALTH", "player")
	assert(env.Reveal(V.frame._lastAlpha.args[1]) == 0, "high health clears it, with no threshold in Lua")
	assert(V.frame.breath:IsPlaying(), "it breathes at Full")
	K.Options.Write("Medallions", "motion", "calm")
	assert(V.frame:IsShown() and not V.frame.breath:IsPlaying(), "it holds still at Calm")
	K.Options.Write("Medallions", "motion", "full")
	assert(K.Store.Module("Medallions").vignette == true and V.frame.breath:IsPlaying(), "the low-health vignette's switch is on by default")
	K.Options.Write("Medallions", "vignette", false)
	assert(not V.frame:IsShown() and not V.frame.breath:IsPlaying(), "the switch off hides the vignette and stops its breath")
	env.FireEvent("UNIT_HEALTH", "player")
	env.FireEvent("PLAYER_ENTERING_WORLD")
	assert(not V.frame:IsShown(), "health and a reload keep it hidden")
	K.Options.Write("Medallions", "vignette", true)
	assert(V.frame:IsShown() and V.frame.breath:IsPlaying(), "the switch on brings it back breathing")
	env._dead = true
	env.FireEvent("PLAYER_DEAD")
	assert(not V.frame:IsShown(), "no vignette while dead")
	Errors(env, K)
end

do
	local env, K = New()
	local Rest = K.Layout.Rest
	env.SetCombat(true)
	env.SetCombat(false)
	env.RunTimers()
	assert(not Rest.Resting(), "under Frames nothing rests after combat")
	Medallions(env, K)
	env.SetCombat(true)
	assert(not Rest.Resting(), "nothing rests in combat")
	env.SetCombat(false)
	assert(not Rest.Resting(), "secondary frames wait before they rest")
	env.RunTimers()
	assert(Rest.Resting() and Rest.Level("unitframes.focus") == Rest.ALPHA, "secondary frames rest after combat")
	assert(Rest.Level("unitframes.player") == 1 and Rest.Level("actionbars.bar1") == 1, "the player frame and the action bars never rest")
	env.SetCombat(true)
	assert(not Rest.Resting() and Rest.Level("unitframes.focus") == 1, "combat wakes them at once")
	env.SetCombat(false)
	env.SetCombat(true)
	env.RunTimers()
	assert(not Rest.Resting(), "a fade that combat interrupted does not land")
	Errors(env, K)
end

do
	local env, K = New()
	local E, P = K.Effects, K.Effects.PRIORITY
	local pending = {}
	env.C_Timer.After = function(seconds, fn)
		pending[#pending + 1] = { seconds = seconds, fn = fn }
	end
	local function Fire(i)
		local timer = table.remove(pending, i)
		timer.fn()
	end
	local stops = {}
	local function Stop(name)
		return function()
			stops[#stops + 1] = name
		end
	end
	E.ClaimFor("hub", P.levelUp, 1.2, Stop("levelup"))
	assert(not E.ClaimFor("hub", P.proc, 0.9, Stop("proc")), "a proc cannot displace level-up")
	assert(#stops == 0 and E.Holder("hub") == P.levelUp, "level-up keeps the hub")
	Fire(1)
	assert(#stops == 1 and stops[1] == "levelup" and E.Holder("hub") == nil, "the level-up's own timer frees the hub")
	E.ClaimFor("hub", P.proc, 0.9, Stop("a"))
	local held = E.Claim("hub", P.lowHealth, Stop("b"))
	Fire(1)
	assert(E.Holder("hub") == P.lowHealth and E.Release("hub", held), "a timer never frees a claim it did not make")

	Medallions(env, K)
	local anchor = env.CreateFrame("Frame", nil, env.UIParent)
	local twins = {}
	local function Twin(name)
		return function()
			twins[#twins + 1] = name
		end
	end
	for _, key in ipairs({ "levelUp", "SHAMAN", "MAGE" }) do
		assert(E.Model(anchor, key, 100, 1.2, P.cap, Twin(key)))
	end
	assert(E.Model(anchor, "PALADIN", 100, 1.2, P.proc, Twin("PALADIN")), "a higher priority takes a full pool")
	assert(twins[1] == "levelUp", "the evicted model's effect falls back to its 2D twin")
	K.Options.Write("Medallions", "motion", "calm")
	assert(E.LiveModels() == 0 and #twins == 4, "a switch to Calm turns every live model into its 2D twin")
	K.Options.Write("Medallions", "motion", "full")
	for _, frame in ipairs(env._frames) do
		if frame:GetObjectType() == "ModelScene" then
			frame.actor.IsLoaded = function()
				return false
			end
		end
	end
	twins = {}
	assert(E.Burst("burst", P.burst, anchor, "DRUID", 100, 1.2, Twin("druid"), nil) == "model", "the burst starts as a model")
	for i = #pending, 1, -1 do
		if pending[i].seconds == E.MODEL_GRACE then
			Fire(i)
		end
	end
	assert(twins[1] == "druid" and E.Holder("burst") == P.burst, "a model that misses its load hands over to the twin, which holds the place for its own run")
	Errors(env, K)
end

print("test-effects-layer: ok")
