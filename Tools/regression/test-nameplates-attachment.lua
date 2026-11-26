-- The nameplate audit requires bounded stacking refusals and one visible plate after late native setup.
local N = dofile("Tools/regression/nameplates_env.lua")
for _, combat in ipairs({ false, true }) do
	local env, _, ns = N.New({ stackingBounds = true })
	local base, calls = N.Base(env), 0
	local set = base.SetStackingBoundsFrame
	base.SetStackingBoundsFrame = function(...)
		calls = calls + 1
		if calls <= 32 then error("stacking bounds refused") end
		return set(...)
	end
	if combat then env.SetCombat(true) end
	N.Add(env, "nameplate1", nil, { base = base })
	assert(ns.Plates.Get("nameplate1"):IsShown() and calls == 1, "attachment made " .. calls .. " stacking attempts")
	if combat then env.SetCombat(false) end
	assert(calls == (combat and 2 or 1), "only a combat refusal gets one deferred attempt")
	print("bounds attempts after attach and combat end", combat, calls)
end
local env = N.New()
local base = N.Add(env, "nameplate1", nil, { lateUnitFrame = true })
local native = base.UnitFrame
base.UnitFrame = nil
env.RunTimers()
env.RunTickers()
base.UnitFrame = native
env.RunTickers()
assert(native:GetAlpha() == 0, "a frame arriving after the first callback still fades")
N.Remove(env, "nameplate1")
assert(native:GetAlpha() == 1, "detaching restores the native plate")
print("late native alpha: 0 attached, 1 detached")
local spare = N.Add(env, "nameplate2", nil, { lateUnitFrame = true })
spare.UnitFrame = nil
env.RunTimers()
N.Remove(env, "nameplate2")
local visible = N.Base(env).UnitFrame
spare.UnitFrame = visible
env.RunTickers()
assert(visible:GetAlpha() == 1, "a retired attachment cannot fade its replacement")
local missing = N.Add(env, "nameplate3", nil, { lateUnitFrame = true })
missing.UnitFrame = nil
local idle = env.LiveTickers()
env.RunTimers()
for _ = 1, 20 do env.RunTickers() end
assert(env.LiveTickers() == idle, "an absent native frame leaves no polling behind")
