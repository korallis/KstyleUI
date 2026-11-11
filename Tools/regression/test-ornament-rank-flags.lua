-- test-ornament-rank-flags.lua: the portrait pendants follow UnitClassification on every frame style, and a secret classification draws none, on a boss card too.
local U = dofile("Tools/regression/unitframes_env.lua")

local function pieces(handle)
	local names = {}
	for i = 1, handle.used do
		local texture = handle.textures[i]
		if texture:IsShown() then names[#names + 1] = texture:GetTexture():match("([%w]+)%.png$") end
	end
	return table.concat(names, " ")
end

local env, K, ns = U.New({ plate = true })
U.SetUnit(env, "target", { name = "Shadowgale Poacher", level = 12, health = 50, healthMax = 100, reaction = 2, canAttack = true, classification = "elite" })
env.FireEvent("PLAYER_TARGET_CHANGED")
env.FireEvent("UNIT_CLASSIFICATION_CHANGED", "target")
env.RunTimers()
local view = ns.Frames.Get("target").views[1]
assert(view.form == "plate", "the classic plate style")
local ring = view.portraitOrnament
assert(ring.elite == true and ring.boss == false, "a plate target reads its classification")
assert(pieces(ring):find("ElitePendantR"), "an elite plate target wears the elite pendant, got " .. pieces(ring))
assert(#env._errors == 0 and K.ErrorCount() == 0, "plate: " .. tostring(env._errors[1]))

env, K, ns = U.New()
U.SetUnit(env, "boss1", { name = "Boss 1", level = 62, classification = "elite", health = 500, healthMax = 1000, reaction = 2, canAttack = true })
U.SetUnit(env, "boss2", { name = "Boss 2", level = 62, classification = "elite", health = 500, healthMax = 1000, reaction = 2, canAttack = true })
local classify = env.UnitClassification
env.UnitClassification = function(unit)
	local value = classify(unit)
	if unit == "boss2" then return env.Secret(value) end
	return value
end
env.FireEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
env.RunTimers()
local views = ns.Frames.Get("boss").views
assert(views[1].portraitOrnament.boss == true, "a boss card ranks as a boss when its classification is readable")
assert(views[2].portraitOrnament.boss == false and views[2].portraitOrnament.elite == false, "a secret classification ranks nothing, on a boss card too")
assert(#env._errors == 0 and K.ErrorCount() == 0, "boss: " .. tostring(env._errors[1]))
print("ok ornament rank flags")
