-- test-colorvision-health.lua: hostile, neutral and friendly health fills on nameplates and unit frames follow the colour-vision palette, and Standard keeps the kit colours.
local N = dofile("Tools/regression/nameplates_env.lua")
local U = dofile("Tools/regression/unitframes_env.lua")

local PALETTE = {
	redGreen = { hostile = "visionRGDanger", neutral = "visionRGWarning", friendly = "visionRGCalm" },
	blueYellow = { hostile = "visionBYDanger", neutral = "visionBYWarning", friendly = "visionBYCalm" },
}

local function same(K, token, r, g, b, what)
	local tr, tg, tb = K.Tokens.Color(token)
	assert(math.abs(r - tr) < 1e-6 and math.abs(g - tg) < 1e-6 and math.abs(b - tb) < 1e-6,
		string.format("%s: paint %s, got %.3f %.3f %.3f; route the fill through K.ColorVision.Color", what, token, r, g, b))
end

for _, mode in ipairs({ "standard", "redGreen", "blueYellow" }) do
	local want = PALETTE[mode] or { hostile = "plateHostile", neutral = "neutral", friendly = "friendly" }
	local env, K, ns = N.New()
	K.Options.Write("ColorVision", "mode", mode)
	K.Options.Write("Nameplates", "threat.groupOnly", false)
	for i, unit in ipairs({ { "hostile", 2, true }, { "neutral", 4, true }, { "friendly", 5, false } }) do
		local token = "nameplate" .. i
		N.Add(env, token, { name = unit[1], health = 70, maxHealth = 100, reaction = unit[2], canAttack = unit[3] })
		local c = ns.Plates.Get(token).colorKey
		same(K, want[unit[1]], c.r, c.g, c.b, mode .. " " .. unit[1] .. " nameplate")
	end
	assert(#env._errors == 0, tostring(env._errors[1]))

	local uenv, UK, uns = U.New()
	UK.Options.Write("ColorVision", "mode", mode)
	for _, source in ipairs({ "hud", "reaction" }) do
		UK.Options.Write("UnitFrames", "target.healthColor", source)
		for _, unit in ipairs({ { "hostile", 2 }, { "neutral", 4 }, { "friendly", 5 } }) do
			U.SetUnit(uenv, "target", { name = unit[1], health = 50, healthMax = 100, reaction = unit[2], canAttack = unit[2] < 4 })
			uenv.SetTarget(true)
			uenv.RunTimers()
			local c = uns.Frames.Get("target").views[1].health.colorRGBA
			local base = unit[1] == "hostile" and (source == "hud" and "hudTargetHealth" or "healthHostile") or unit[1]
			same(UK, PALETTE[mode] and want[unit[1]] or base, c[1], c[2], c[3], mode .. " " .. source .. " " .. unit[1] .. " target")
		end
	end
	assert(#uenv._errors == 0, tostring(uenv._errors[1]))
	collectgarbage("collect")
end
print("colour vision health fills ok")
