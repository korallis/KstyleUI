-- test-nameplates-height.lua: a nameplate's health bar is exactly as tall as the target sigil's health bar, in every nameplate preset, every setup layout and at every interface size, so the two read as one family.
local N = dofile("Tools/regression/nameplates_env.lua")
local U = dofile("Tools/regression/unitframes_env.lua")

local USER_SCALES = { 0.75, 1, 1.25 }

local function near(a, b)
	return math.abs(a - b) < 1e-6
end

-- The sigil's drawn health bar in root units, per setup layout and interface size. Both frames draw in
-- KstyleUI root units, so equal units are equal pixels; each half checks its own effective scale.
local sigil = {}
for _, name in ipairs({ "DPS", "Tank", "Healer" }) do
	sigil[name] = {}
	local env, K, ns = U.New()
	local sizes = K.Setup.Layouts.Sizes(name)
	local size = sizes and sizes["unitframes.target"]
	if size then
		assert(K.Layout.Set("unitframes.target", "width", size.width))
		assert(K.Layout.Set("unitframes.target", "height", size.height))
	end
	env.RunTimers()
	for _, user in ipairs(USER_SCALES) do
		K.Scale.SetUserScale(user)
		env.RunTimers()
		local view = ns.Frames.Get("target").views[1]
		local h = view.health:GetHeight()
		assert(h > 0, "the sigil draws a health bar in the " .. name .. " layout")
		assert(near(view.health:GetEffectiveScale(), K.Scale.Root():GetEffectiveScale()), "the sigil draws in root units")
		sigil[name][user] = h
	end
end

for _, preset in ipairs({ "lumen", "compact", "tank", "healer" }) do
	local env, K, ns = N.New()
	K.Options.Write("Nameplates", "preset", preset)
	env.RunTimers()
	N.Add(env, "nameplate1", { name = "Bloodtalon Matriarch" })
	for _, user in ipairs(USER_SCALES) do
		K.Scale.SetUserScale(user)
		env.RunTimers()
		local plate = ns.Plates.Get("nameplate1")
		plate:Restyle()
		assert(near(plate.health:GetEffectiveScale(), K.Scale.Root():GetEffectiveScale()), "the plate draws in root units at size " .. user)
		local px = plate.health:GetHeight()
		for name, byScale in pairs(sigil) do
			assert(
				near(px, byScale[user]),
				("the %s plate's health bar is %.3f units, the %s sigil's is %.3f units at size %s"):format(preset, px, name, byScale[user], tostring(user))
			)
		end
	end
end

print("nameplates height: ok")
