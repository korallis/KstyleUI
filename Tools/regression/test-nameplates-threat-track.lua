-- test-nameplates-threat-track.lua: a plate's threat glow sits under the bar's track frame, so a plate with threat (the just-hit target in the mock-up's state) keeps its black edge and black empty track and only the loss band shows pale (KSTY-60 item 12); before, the glow frame shared the track frame's level and its centre slice painted the empty track red.
local N = dofile("Tools/regression/nameplates_env.lua")

for _, threat in ipairs({ 3, 2 }) do
	local env, K, ns = N.New()
	K.Options.Write("Nameplates", "threat.groupOnly", false)
	N.Add(env, "nameplate1", { name = "Galestrider", health = 1307, maxHealth = 1698, level = 6, reaction = 2, canAttack = true, threat = threat })
	N.Target(env, "nameplate1")
	local plate = ns.Plates.Get("nameplate1")
	local health = plate.health
	local glowShown = false
	for _, piece in ipairs(plate.threatGlow) do
		glowShown = glowShown or piece:IsShown()
	end
	assert(glowShown, "threat " .. threat .. ": the plate shows its threat glow")
	local function under(when)
		local glow, track = plate.glowFrame:GetFrameLevel(), health.under:GetFrameLevel()
		assert(glow < track, "threat " .. threat .. " " .. when .. ": the threat glow (level " .. glow .. ") draws under the bar's track and edge (level " .. track .. ")")
	end
	under("at rest")
	env._units.nameplate1.health = 1206
	env.FireEvent("UNIT_HEALTH", "nameplate1")
	under("just hit")
	plate:Hide()
	plate:Show()
	health:Show()
	under("shown again")
	plate:Restyle()
	under("restyled")
	assert(#env._errors == 0, tostring(env._errors[1]))
end
print("nameplates threat track ok")
