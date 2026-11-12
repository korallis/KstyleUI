-- test-ornament-secret-unitframes.lua: the player and target blocks' health bars hold secret values, so the game answers their geometry as secrets; their rails, ends and crests still draw, placed from the blocks' recorded layout, exactly where plain geometry would put them, at 1920x1080 and 5120x1440.
local Hud = dofile("Tools/render/scenes/hud.lua")

local function pieces(handle)
	local list = {}
	for i = 1, handle.used do
		local texture = handle.textures[i]
		if texture:IsShown() then
			local p = texture._points[1]
			list[#list + 1] = string.format("%s@%.4f,%.4f,%.4f,%.4f", tostring(texture:GetTexture()):match("([%w]+)%.png$") or "Fill", p[4], p[5], texture._width, texture._height)
		end
	end
	table.sort(list)
	return table.concat(list, " ")
end

local checked = 0
for _, screen in ipairs({ { 1920, 1080 }, { 5120, 1440 } }) do
	rawset(_G, "RENDER_ORNAMENTS", "Full")
	rawset(_G, "RENDER_SCREEN", { width = screen[1], height = screen[2] })
	local opts = { class = "PALADIN", layout = "DPS", applyPreset = true, settings = Hud.PresetSettings("DPS"),
		target = { name = "Shadowgale Poacher", creature = "Humanoid", classification = "elite", power = 240, powerMax = 345 } }
	local scene, U = Hud.Module("unitframes", opts)
	local env = Hud.envs[scene]
	local K = env.KstyleUI
	local label = screen[1] .. "x" .. screen[2]
	local views = { player = U.Frames.Get("player").views[1], target = U.Frames.Get("target").views[1] }
	local secret = {}
	for kind, view in pairs(views) do
		assert(view.health:IsAnchoringSecret() == true, label .. ": the " .. kind .. " health bar anchors secretly, as a bar given a secret value does")
		assert(K.Widgets.IsSecret(view.health:GetLeft()) and K.Widgets.IsSecret(view.health:GetWidth()), label .. ": the " .. kind .. " health bar answers its geometry as secrets")
		view.health.ornament:Restyle()
		secret[kind] = pieces(view.health.ornament)
		assert(secret[kind]:find("Rail", 1, true) or secret[kind]:find("Forge", 1, true), label .. ": the " .. kind .. " block draws its rails: " .. secret[kind])
		assert(secret[kind]:find("End", 1, true), label .. ": the " .. kind .. " block draws its end: " .. secret[kind])
	end
	assert(#env._errors == 0, label .. ": " .. tostring(env._errors[1]))
	env.SecretAnchoring(false)
	for kind, view in pairs(views) do
		assert(view.health:IsAnchoringSecret() == false, label .. ": plain geometry for the comparison")
		view.health.ornament:Restyle()
		local plain = pieces(view.health.ornament)
		assert(plain == secret[kind], label .. ": the " .. kind .. " block places the same pieces from its layout as from plain geometry:\n" .. secret[kind] .. "\n" .. plain)
		checked = checked + 1
	end
	env.SecretAnchoring(true)
end
print("ok the player and target blocks draw their rails and ends from their recorded layout on " .. checked .. " blocks, identical to plain geometry")
