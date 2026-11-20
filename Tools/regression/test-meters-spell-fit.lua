-- test-meters-spell-fit.lua: default meter spell names fit beside their figures on every owner screen and HUD style.
local Reference = dofile("Tools/render/scenes/_reference.lua")
local Scene = dofile("Tools/render/scene.lua")

for _, screen in ipairs({ { 2560, 1440 }, { 1920, 1080 }, { 5120, 1440 }, { 3840, 2160 } }) do
	Reference.SCREEN = { width = screen[1], height = screen[2], uiScale = 768 / 1080, size = "auto" }
	for _, style in ipairs({ "Orbs", "Frames", "Medallions" }) do
		rawset(_G, "RENDER_HUD_STYLE", style)
		local scene = Reference.Build({ layout = "Tank", modules = { "meters" } })
		local found = false
		for _, item in ipairs(scene.items) do
			if item.kind == "text" and item.text:upper() == "LIGHTNING BOLT" then
				found = true
				local need = Scene.TextWidth(item.text, item.font.size, item.font.path)
				assert(need <= item.rect[3], string.format(
					"%s %dx%d: widen the shared default meter cards so Lightning Bolt fits beside its figures (needs %.1f, has %.1f)",
					style, screen[1], screen[2], need, item.rect[3]))
			end
		end
		assert(found, style .. " " .. screen[1] .. "x" .. screen[2] .. ": exercise the actual spell drill-down in the Tank meter")
	end
end
rawset(_G, "RENDER_HUD_STYLE", nil)
print("meter spell fit ok: 3 HUD styles, 4 screens")
