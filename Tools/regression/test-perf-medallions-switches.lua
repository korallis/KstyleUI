-- test-perf-medallions-switches.lua: in the idle Medallions suite at full health, the resting crest runs only its two breaths (Calm crest at rest off adds back the rune turn, the sheen and five sparks), and the Medallions page's Low-health vignette and Ambient hub effects switches (on by default) take their art out of the draw when off, hidden rather than alpha 0, with no loop or OnUpdate left running for them (the vignette's breath runs on only for the portrait ring that breathes on it) and no player health event reaching the vignette, switching them back on restores the counts, and a fresh load saved with both off matches the switched-off counts.
local Suite = dofile("Tools/regression/suite_env.lua")
local FX = dofile("Tools/regression/effects_env.lua")
local SETTLE = 600

local env, K = Suite.Prepare(1920, 1080)()
FX.Install(env)
env.FireEvent("PLAYER_ENTERING_WORLD", false, false)
local V = K.Effects.Vignette

local function Census(e)
	for frame = 1, SETTLE + 1 do
		local busy = false
		e._now = e._now + 1 / 60
		e.RunTimers()
		for _, f in ipairs(e._frames) do
			local update = f._scripts.OnUpdate
			if update and f:IsVisible() then
				busy = true
				update(f, 1 / 60)
			end
		end
		if not busy then break end
		assert(frame <= SETTLE, "an OnUpdate still runs after " .. SETTLE .. " idle frames; stop per-frame scripts when their work is done")
	end
	local shown, loops = 0, 0
	local function Loops(owner, visible)
		for _, group in ipairs(owner._groups or {}) do
			if visible and group:IsPlaying() and group:GetLooping() ~= "NONE" then loops = loops + 1 end
		end
	end
	for _, f in ipairs(e._frames) do
		local visible = f:IsVisible()
		Loops(f, visible)
		for _, r in ipairs(f._regions) do
			Loops(r, visible and r._shown ~= false)
			if visible and r._shown ~= false and r._type ~= "MaskTexture" then shown = shown + 1 end
		end
	end
	return shown, loops
end

local function Switch(on)
	K.Options.Write("Medallions", "vignette", on)
	K.Options.Write("Medallions", "ambient", on)
end

-- Health(e, vignette) -> the SetAlpha calls the vignette makes for ten player health changes.
local function Health(e, vignette)
	local before = #vignette.frame._calls
	for _ = 1, 10 do e.FireEvent("UNIT_HEALTH", "player") end
	local writes = 0
	for k = before + 1, #vignette.frame._calls do
		if vignette.frame._calls[k].method == "SetAlpha" then writes = writes + 1 end
	end
	return writes
end

local function Edge()
	for _, t in ipairs({ V.frame.layer:GetRegions() }) do
		if t:IsShown() then return true end
	end
	return false
end

local shown, loops = Census(env)
assert(Edge() and V.frame.breath:IsPlaying(), "by default the vignette's edge is shown at the curve's alpha and breathes")
K.Options.Write("Medallions", "restingCrest", false)
local shownAwake, loopsAwake = Census(env)
assert(loopsAwake - loops == 7 and shownAwake - shown == 5, string.format("the resting crest stops the rune turn, the sheen and 5 sparks: %d loops and %d shown awake, %d and %d at rest", loopsAwake, shownAwake, loops, shown))
K.Options.Write("Medallions", "restingCrest", true)
assert(select(2, Census(env)) == loops, "Calm crest at rest back on settles the crest again")
local probe = env.CreateFrame("Frame", nil, env.UIParent)
env.C_Timer.After(0, function() probe:SetScript("OnUpdate", function() end) end)
assert(not pcall(Census, env), "the census must see an OnUpdate that a timer starts; run timers before scanning")
probe:SetScript("OnUpdate", nil)
Switch(false)
local shownOff, loopsOff = Census(env)
assert(not Edge() and V.frame.breath:IsPlaying(), "the vignette switch off hides the edge textures and keeps the breath the portrait ring breathes on")
local healthOff = Health(env, V)
assert(healthOff == 0, "the vignette switch off still set the vignette's alpha " .. healthOff .. " times for 10 health changes; unregister UNIT_HEALTH while it is off (Core/Vignette.lua Listen)")
assert(loops - loopsOff == 2, string.format("the switches off stop the resting hub's 2 breaths: %d loops before, %d after", loops, loopsOff))
assert(shown - shownOff >= 17, string.format("the switches off hide the vignette's 16 edge slices and the hub's sheen: %d shown before, %d after", shown, shownOff))
Switch(true)
local shownOn, loopsOn = Census(env)
assert(Health(env, V) == 10, "switched back on, every health change sets the vignette's alpha again")
assert(shownOn == shown and loopsOn == loops, string.format("switching back on restores %d shown and %d loops, got %d and %d", shown, loops, shownOn, loopsOn))
assert(#env._errors == 0 and K.ErrorCount() == 0, "the switches raised " .. tostring(env._errors[1]))

Switch(false)
env.FireEvent("PLAYER_LOGOUT")
local fresh = Suite.New(env.KstyleUIDB, 1920, 1080)
FX.Install(fresh)
fresh.FireEvent("PLAYER_ENTERING_WORLD", false, true)
local shownFresh, loopsFresh = Census(fresh)
local VF = fresh.KstyleUI.Effects.Vignette
assert(VF.frame.body == nil and Health(fresh, VF) == 0, "a fresh load saved off builds no edge slices and leaves player health alone")
assert(shownFresh == shownOff and loopsFresh == loopsOff, string.format("a fresh load saved off gives %d shown and %d loops, got %d and %d", shownOff, loopsOff, shownFresh, loopsFresh))
assert(#fresh._errors == 0 and fresh.KstyleUI.ErrorCount() == 0, "the fresh load raised " .. tostring(fresh._errors[1]))
print(string.format("medallions switches ok: %d shown and %d loops on, %d and %d off", shown, loops, shownOff, loopsOff))
