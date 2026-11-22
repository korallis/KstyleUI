-- test-colorvision-health.lua: hostile, neutral and friendly health fills on nameplates and unit frames follow the colour-vision palette, and Standard keeps the kit colours.
local N = dofile("Tools/regression/nameplates_env.lua")
local U = dofile("Tools/regression/unitframes_env.lua")
local G = dofile("Tools/regression/group_env.lua")

local PALETTE = {
	redGreen = { hostile = "visionRGDanger", neutral = "visionRGWarning", friendly = "visionRGCalm" },
	blueYellow = { hostile = "visionBYDanger", neutral = "visionBYWarning", friendly = "visionBYCalm" },
}

local function same(K, token, r, g, b, what)
	local tr, tg, tb = K.Tokens.Color(token)
	assert(math.abs(r - tr) < 1e-6 and math.abs(g - tg) < 1e-6 and math.abs(b - tb) < 1e-6,
		string.format("%s: paint %s, got %.3f %.3f %.3f; route health fills, and only them, through K.ColorVision", what, token, r, g, b))
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
		local r, g, b = K.Theme.ReactionColor(unit[2])
		local kit = { hostile = "hostile", neutral = "neutral", friendly = "friendly" }
		same(K, kit[unit[1]], r, g, b, mode .. " " .. unit[1] .. " Theme.ReactionColor (reputation bar, text, cooldowns): keep colour vision to health fills")
	end
	for _, key in ipairs({ "types.boss", "types.neutral", "types.normal" }) do K.Options.Write("Nameplates", key, true) end
	for i, unit in ipairs({ { "boss", "worldboss", 2, "hostile", "hostile" }, { "neutral", "normal", 4, "neutral", "neutral" }, { "normal", "normal", 2, "hostile", "plateHostile" } }) do
		local token = "nameplate" .. (3 + i)
		N.Add(env, token, { name = unit[1], health = 70, maxHealth = 100, reaction = unit[3], canAttack = true, classification = unit[2] })
		local c = ns.Plates.Get(token).colorKey
		same(K, PALETTE[mode] and want[unit[4]] or unit[5], c.r, c.g, c.b, mode .. " " .. unit[1] .. " unit-type nameplate colour")
	end
	assert(#env._errors == 0, tostring(env._errors[1]))

	local genv, GK, gns = G.New()
	genv.UnitReaction = function(unit) return unit == "party1" and 2 or 5 end
	G.SetRoster(genv, "party", { { name = "Hostile", class = "WARRIOR" }, { name = "Friendly", class = "DRUID" } })
	GK.Modules.Enable("GroupFrames")
	GK.Options.Write("ColorVision", "mode", mode)
	GK.Options.Write("GroupFrames", "health.colorSource", "reaction")
	genv.RunTimers()
	for i = 1, 2 do
		local button = gns.Headers.party._attributes["child" .. i]
		local unit = button._attributes.unit
		local c = gns.Button.Content(button).health.colorRGBA
		local kind = unit == "party1" and "hostile" or "friendly"
		same(GK, PALETTE[mode] and want[kind] or kind, c[1], c[2], c[3], mode .. " " .. kind .. " group frame on reaction colour")
	end
	assert(#genv._errors == 0, tostring(genv._errors[1]))

	local uenv, UK, uns = U.New()
	UK.Options.Write("ColorVision", "mode", mode)
	for _, source in ipairs({ "hud", "reaction" }) do
		UK.Options.Write("UnitFrames", "target.healthColor", source)
		for _, unit in ipairs({ { "hostile", 2 }, { "neutral", 4 }, { "friendly", 5 } }) do
			U.SetUnit(uenv, "target", { name = unit[1], health = 50, healthMax = 100, reaction = unit[2], canAttack = unit[2] < 4 })
			uenv.SetTarget(true)
			-- A new target flips the Medallions slab out and refreshes it when the flip ends.
			uenv.FireEvent("PLAYER_TARGET_CHANGED")
			U.W.Settle(uenv)
			uenv.RunTimers()
			local c = uns.Frames.Get("target").views[1].health.colorRGBA
			local base = unit[1] == "hostile" and (source == "hud" and "hudTargetHealth" or "healthHostile") or unit[1]
			same(UK, PALETTE[mode] and want[unit[1]] or base, c[1], c[2], c[3], mode .. " " .. source .. " " .. unit[1] .. " target")
		end
	end
	assert(#uenv._errors == 0, tostring(uenv._errors[1]))
	collectgarbage("collect")
end
do
	local env, K, ns = N.New()
	local filter = "0"
	local get, reads = env.C_CVar.GetCVar, 0
	env.C_CVar.GetCVar = function(key, ...)
		if key ~= "colorblindSimulator" then return get(key, ...) end
		reads = reads + 1
		return filter
	end
	N.Add(env, "nameplate1", { name = "hostile", health = 70, maxHealth = 100, reaction = 2, canAttack = true })
	local plate = ns.Plates.Get("nameplate1")
	reads = 0
	for _ = 1, 100 do plate:RefreshFlags() end
	assert(reads <= 1, "UNIT_FLAGS refreshes read the colorblindSimulator CVar " .. reads .. " times in 100; resolve the palette once and clear it on setting, profile and CVar changes")
	filter = "2"
	env.FireEvent("CVAR_UPDATE", "colorblindSimulator", filter)
	env.RunTimers()
	local c = plate.colorKey
	same(K, "visionRGDanger", c.r, c.g, c.b, "Follow the game after the game's filter changes")
	local profile = K.Store.ProfileName()
	assert(K.Store.CreateProfile("Vision") and K.Store.SetProfile("Vision"))
	K.Options.Write("ColorVision", "mode", "blueYellow")
	assert(K.ColorVision.Mode() == "blueYellow")
	assert(K.Store.SetProfile(profile))
	assert(K.ColorVision.Mode() == "redGreen", "a profile switch clears the resolved colour-vision palette")
	assert(#env._errors == 0, tostring(env._errors[1]))
end
print("colour vision health fills ok")
