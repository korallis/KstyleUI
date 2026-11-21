-- test-perf-medallions-switches.lua: in the idle Medallions suite at full health, the Medallions page's Low-health vignette and Ambient hub effects switches (on by default) take their art out of the draw when off, hidden rather than alpha 0, with no loop or OnUpdate left running for them, and switching them back on restores the counts.
local Suite = dofile("Tools/regression/suite_env.lua")
local FX = dofile("Tools/regression/effects_env.lua")
local SETTLE = 600

local env, K = Suite.Prepare("medallions", 1920, 1080)()
FX.Install(env)
env.FireEvent("PLAYER_ENTERING_WORLD", false, false)
local V = K.Effects.Vignette

local function Census()
	for frame = 1, SETTLE + 1 do
		local busy = false
		env._now = env._now + 1 / 60
		for _, f in ipairs(env._frames) do
			local update = f._scripts.OnUpdate
			if update and f:IsVisible() then
				busy = true
				update(f, 1 / 60)
			end
		end
		env.RunTimers()
		if not busy then break end
		assert(frame <= SETTLE, "an OnUpdate still runs after " .. SETTLE .. " idle frames; stop per-frame scripts when their work is done")
	end
	local shown, loops = 0, 0
	local function Loops(owner, visible)
		for _, group in ipairs(owner._groups or {}) do
			if visible and group:IsPlaying() and group:GetLooping() ~= "NONE" then loops = loops + 1 end
		end
	end
	for _, f in ipairs(env._frames) do
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

local shown, loops = Census()
assert(V.frame:IsShown() and V.frame.breath:IsPlaying(), "by default the vignette is shown at the curve's alpha and breathes")
Switch(false)
local shownOff, loopsOff = Census()
assert(not V.frame:IsShown() and not V.frame.breath:IsPlaying(), "the vignette switch off hides the vignette and stops its breath")
assert(loops - loopsOff == 10, string.format("the switches off stop the vignette breath and the hub's 9 ambient loops: %d loops before, %d after", loops, loopsOff))
assert(shown - shownOff >= 22, string.format("the switches off hide the vignette's 16 edge slices and the hub's sheen and live particles: %d shown before, %d after", shown, shownOff))
Switch(true)
local shownOn, loopsOn = Census()
assert(shownOn == shown and loopsOn == loops, string.format("switching back on restores %d shown and %d loops, got %d and %d", shown, loops, shownOn, loopsOn))
assert(#env._errors == 0 and K.ErrorCount() == 0, "the switches raised " .. tostring(env._errors[1]))
print(string.format("medallions switches ok: %d shown and %d loops on, %d and %d off", shown, loops, shownOff, loopsOff))
