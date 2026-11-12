-- test-ornament-unitframe-bars.lua: the unit frames draw no ornament on or around their health, power and cast bars at Subtle or Full, as before the ornament work (Lee, 2026-11-12: "I liked our unit frames before we added the textures around health and power bars"); the portrait band still draws at Full, at 1920x1080 and 5120x1440.
local Hud = dofile("Tools/render/scenes/hud.lua")

local function names(handle)
	local list = {}
	for i = 1, handle.used do
		local texture = handle.textures[i]
		if texture:IsShown() then list[#list + 1] = tostring(texture:GetTexture()):match("([%w]+)%.png$") or "Fill" end
	end
	table.sort(list)
	return table.concat(list, " ")
end

local old, oldLevel = rawget(_G, "RENDER_SCREEN"), rawget(_G, "RENDER_ORNAMENTS")
local checked = 0
for _, level in ipairs({ "Subtle", "Full" }) do
	for _, screen in ipairs({ { 1920, 1080 }, { 5120, 1440 } }) do
		rawset(_G, "RENDER_ORNAMENTS", level)
		rawset(_G, "RENDER_SCREEN", { width = screen[1], height = screen[2] })
		local opts = { class = "ROGUE", layout = "DPS", applyPreset = true, settings = Hud.PresetSettings("DPS"),
			target = { name = "Shadowgale Poacher", creature = "Humanoid", classification = "elite", power = 240, powerMax = 345 },
			spec = { cast = { "First Aid", 135966, 746, 8 } } }
		local scene, U = Hud.Module("unitframes", opts)
		local env = Hud.envs[scene]
		local label = string.format("%s %dx%d", level, screen[1], screen[2])
		for _, kind in ipairs({ "player", "target" }) do
			local view = U.Frames.Get(kind).views[1]
			view.health.ornament:Restyle()
			local block = names(view.health.ornament)
			assert(block == "", label .. ": the " .. kind .. " block draws " .. block .. " around its bars")
			for _, cb in ipairs(kind == "player" and U.CastBars.Get(kind) or U.CastBars.Inline(kind)) do
				cb.ornament:Restyle()
				local cast = names(cb.ornament)
				assert(cast == "", label .. ": the " .. kind .. " cast bar draws " .. cast)
			end
			if level == "Full" then
				local ring = names(view.portraitOrnament)
				assert(ring:find("Ring", 1, true), label .. ": the " .. kind .. " portrait keeps its band: " .. ring)
			end
			checked = checked + 1
		end
		assert(#env._errors == 0, label .. ": " .. tostring(env._errors[1]))
		collectgarbage("collect")
	end
end
rawset(_G, "RENDER_SCREEN", old)
rawset(_G, "RENDER_ORNAMENTS", oldLevel)
print("ok the player and target blocks and their cast bars draw no bar ornament, and keep their portrait bands, on " .. checked .. " blocks")
