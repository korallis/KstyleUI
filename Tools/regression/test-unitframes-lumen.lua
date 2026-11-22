-- test-unitframes-lumen.lua: every frame takes the Medallions slab with the classic plate as a choice, and the plate keeps its glass.
local U = dofile("Tools/regression/unitframes_env.lua")

local env, K, ns = U.New({ lumen = true })
K.Options.Write("UnitFrames", "player.powerSeparate", false)
local Settings, Geometry = ns.Settings, ns.Geometry

local function noErrors(where)
	assert(#env._errors == 0, where .. ": " .. tostring(env._errors[1]))
	assert(K.ErrorCount() == 0, where .. ": KstyleUI caught an error")
end

noErrors("enable")

-- Every frame draws the Medallions slab; the classic plate stays a choice.
for _, kind in ipairs(Settings.KINDS) do
	assert(Settings.Form(kind) == "slab" and Settings.Snapshot(kind).form == "slab", kind .. " takes the Medallions slab, got " .. tostring(Settings.Form(kind)))
end
K.Options.Write("UnitFrames", "pet.style", "plate")
assert(Settings.Form("pet") == "plate", "the classic plate is a choice")
K.Options.Write("UnitFrames", "pet.style", "nonsense")
assert(Settings.Form("pet") == "slab", "a value that is not a choice falls back to the slab")
K.Options.Write("UnitFrames", "pet.style", "lumen")
assert(Settings.Value("player", "powerColor") == "power", "power bars keep the power type's colour")
assert(Settings.Value("player", "portraitShape") == "round", "portraits stay round by default")

local function lumen(form, overrides)
	local s = {
		form = form, portrait = true, portraitSide = "LEFT", level = true, name = true, power = true, powerHeight = 5,
		healthText = "both", powerText = "none", castbar = true,
		fonts = { name = { size = 17 }, health = { size = 15 }, power = { size = 10 }, level = { size = 12 } },
	}
	for k, v in pairs(overrides or {}) do
		s[k] = v
	end
	return s
end

-- The classic plate is unchanged: a full frame with its glass.
local plate = Geometry.Frame(lumen("plate"), 220, 70, 1)
assert(plate.form == "plate" and plate.chrome == true and plate.glass.x > 0 and plate.cast == nil, "the plate keeps its glass under the portrait")
noErrors("geometry")

print("unitframes lumen ok")
