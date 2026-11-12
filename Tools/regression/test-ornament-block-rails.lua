-- test-ornament-block-rails.lua: the player and target blocks draw no rail above the health bar, no rail below the power bar and no crest on the top rail at Subtle or Full (Lee, 2026-11-13, on v0.0.7); their ends and the portrait band still draw, at 1920x1080 and 5120x1440.
local Hud = dofile("Tools/render/scenes/hud.lua")

local function names(handle)
	local list = {}
	for i = 1, handle.used do
		local texture = handle.textures[i]
		if texture:IsShown() then list[#list + 1] = tostring(texture:GetTexture()):match("([%w]+)%.png$") or "Fill" end
	end
	table.sort(list)
	return list
end

local function has(list, pattern)
	for _, name in ipairs(list) do
		if name:find(pattern) then return name end
	end
end

local old, oldLevel = rawget(_G, "RENDER_SCREEN"), rawget(_G, "RENDER_ORNAMENTS")
local checked = 0
for _, level in ipairs({ "Subtle", "Full" }) do
	for _, screen in ipairs({ { 1920, 1080 }, { 5120, 1440 } }) do
		rawset(_G, "RENDER_ORNAMENTS", level)
		rawset(_G, "RENDER_SCREEN", { width = screen[1], height = screen[2] })
		local opts = { class = "PALADIN", layout = "DPS", applyPreset = true, settings = Hud.PresetSettings("DPS"),
			target = { name = "Shadowgale Poacher", creature = "Humanoid", classification = "elite", power = 240, powerMax = 345 } }
		local scene, U = Hud.Module("unitframes", opts)
		local env = Hud.envs[scene]
		local label = string.format("%s %dx%d", level, screen[1], screen[2])
		for _, kind in ipairs({ "player", "target" }) do
			local view = U.Frames.Get(kind).views[1]
			local block = names(view.health.ornament)
			local text = table.concat(block, " ")
			for _, piece in ipairs({ "^Rail", "^Forge", "^Tip", "^Crest" }) do
				local found = has(block, piece)
				assert(not found, label .. ": the " .. kind .. " block draws " .. tostring(found) .. ", a rail piece Lee asked to remove: " .. text)
			end
			assert(has(block, "^End") or has(block, "^Arrow") or has(block, "^Wing"), label .. ": the " .. kind .. " block keeps its end: " .. text)
			if level == "Full" then
				local ring = names(view.portraitOrnament)
				assert(has(ring, "^Ring"), label .. ": the " .. kind .. " portrait keeps its band: " .. table.concat(ring, " "))
			end
			checked = checked + 1
		end
		assert(#env._errors == 0, label .. ": " .. tostring(env._errors[1]))
		collectgarbage("collect")
	end
end
rawset(_G, "RENDER_SCREEN", old)
rawset(_G, "RENDER_ORNAMENTS", oldLevel)
print("ok the player and target blocks draw their ends and bands with no rails or crest on " .. checked .. " blocks")
