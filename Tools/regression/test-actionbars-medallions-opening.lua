-- test-actionbars-medallions-opening.lua: circular hub clips, opening-sized effects and unscaled crest texels through combat repaint on five screens.
local AB = dofile("Tools/regression/actionbars_env.lua")

for _, screen in ipairs({ { 1920, 1080 }, { 3456, 2234 }, { 5120, 1440 }, { 3840, 2160 }, { 7680, 4320 } }) do
	local env, K, ns = AB.New({ width = screen[1], height = screen[2], class = "WARLOCK" })
	env.UnitRace = function() return "Undead", "Scourge" end
	env.UnitSex = function() return 2 end
	AB.Enable(env, K)
	env.RunTimers()
	local hub = ns.Slab.hub
	assert(hub.crestPath:find("Crests\\scourge_warlock.png", 1, true), "exercise the shipped undead warlock crest")
	local function Near(a, b)
		return math.abs(a - b) < 1
	end
	for _, region in ipairs({ hub.crest, hub.bloom, hub.sheen, hub.flash }) do
		assert(region:GetNumMaskTextures() == 1, "clip crest, bloom, sheen and flash to one circular opening mask")
		local mask = region:GetMaskTexture(1)
		assert(mask:GetTexture() == K.Tokens.Texture("orbMask"), "use the circular OrbMask, not the rounded-square portrait mask")
		assert(Near(mask:GetWidth(), 118) and Near(mask:GetHeight(), 118), "size both mask axes to the 118-unit ring opening")
		assert(Near(mask:GetLeft() + mask:GetWidth() / 2, hub:GetLeft() + hub:GetWidth() / 2)
			and Near(mask:GetBottom() + mask:GetHeight() / 2, hub:GetBottom() + hub:GetHeight() / 2), "centre each mask on the hub, independently of crest pulses and sheen motion")
	end
	local size = math.min(123, K.Scale.Pixel(255) / 1.05)
	assert(Near(hub.crest:GetWidth(), size) and Near(hub.crest:GetHeight(), size), "keep both crest axes at the canvas size, capped by the bake")
	assert(Near(hub.crest:GetLeft() + hub.crest:GetWidth() / 2, hub:GetLeft() + hub:GetWidth() / 2)
		and Near(hub.crest:GetBottom() + hub.crest:GetHeight() / 2, hub:GetBottom() + hub:GetHeight() / 2), "centre the crest canvas on the hub")
	assert(Near(hub.sheen:GetWidth(), 46) and Near(hub.sheen:GetHeight(), 118), "size the sheen from the opening, not the crest canvas")
	assert(Near(hub.flash:GetWidth(), 118) and Near(hub.flash:GetHeight(), 118), "size the combat flash from the opening, not the crest canvas")
	local pixels = screen[2] * hub:GetEffectiveScale() / 768
	assert(hub.crest:GetWidth() * pixels * 1.05 <= 256, "cap the pulsed crest canvas to its original 256-pixel source")
	assert(hub.bloom:GetWidth() * pixels <= 256, "cap the bloom to its original 256-pixel source")
	for _, combat in ipairs({ true, false }) do
		ns.Slab.SetCombat(combat)
		ns.Slab.Refresh()
		local r, g, b, a = hub.crest:GetVertexColor()
		assert(r == 1 and g == 1 and b == 1 and a == 1 and hub.crest:GetAlpha() == 1, "keep full crest colour and alpha when repainting in combat and at rest")
	end
	env.UnitRace = function() return "Unknown", "Unknown" end
	ns.Slab.Refresh()
	assert(hub.crest:GetWidth() * pixels * 1.05 <= 256, "cap the missing-art fallback to its own 256-pixel source")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

print("ok actionbars medallions opening: five screens, fixed circular masks and opening-sized effects")
