-- test-nameplates-target-cost.lua: target and focus swaps update only their old and new plates, while target acquisition/loss still updates optional dimming.
local N = dofile("Tools/regression/nameplates_env.lua")
local env, K, ns = N.New()
local touched, reads = {}, 0
for i = 1, 40 do
	local token = "nameplate" .. i
	N.Add(env, token)
	local plate = ns.Plates.Get(token)
	local update = plate.UpdateHighlight
	plate.UpdateHighlight = function(self, ...)
		touched[self] = (touched[self] or 0) + 1
		return update(self, ...)
	end
end
local running = K.Modules.IsRunning
K.Modules.IsRunning = function(name)
	if name == "UnitFrames" then reads = reads + 1 end
	return running(name)
end
K.Options.Write("Nameplates", "cast.hideOnTarget", true)
local function reset()
	touched, reads = {}, 0
end
local function count()
	local total = 0
	for _, n in pairs(touched) do total = total + n end
	return total
end
N.Target(env, "nameplate1")
reset()
N.Target(env, "nameplate2")
assert(count() == 2, "P7: update only the old and new target plates, got " .. count())
assert(reads <= 1, "P7: read SigilCasts once per highlight event, got " .. reads)
assert(touched[ns.Plates.Get("nameplate1")] == 1 and touched[ns.Plates.Get("nameplate2")] == 1, "both changed plates update once")
reset()
N.Target(env, "nameplate2")
assert(count() == 0, "the same target changes no plate")
N.Focus(env, "nameplate3")
reset()
N.Focus(env, "nameplate4")
assert(count() == 2, "a focus swap updates only its old and new plates")

K.Options.Write("Nameplates", "target.dimOthers", 0.4)
N.Target(env, nil)
for i = 1, 40 do assert(ns.Plates.Get("nameplate" .. i):GetAlpha() == 1, "clearing the target restores every plate") end
N.Target(env, "nameplate1")
reset()
N.Target(env, "nameplate2")
assert(count() == 2, "a target swap with dimming still updates only two plates")
assert(ns.Plates.Get("nameplate1"):GetAlpha() == 0.4 and ns.Plates.Get("nameplate2"):GetAlpha() == 1, "the old target dims and the new target brightens")
assert(ns.Plates.Get("nameplate30"):GetAlpha() == 0.4, "other plates stay dim")

env.C_NamePlate.GetNamePlateForUnit = function() return nil end
reset()
N.Target(env, "nameplate3")
assert(count() == 2, "the UnitIsUnit fallback still paints only the changed plates")
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("nameplates target cost ok")
