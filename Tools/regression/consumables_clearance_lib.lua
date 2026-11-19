-- consumables_clearance_lib.lua: the default maximum grid clears the drawn player aura row, including its timers.
local Hud = dofile("Tools/render/scenes/hud.lua")
local Scene = dofile("Tools/render/scene.lua")
local function Overlap(a, b)
	return a[1] < b[1] + b[3] - 0.01 and b[1] < a[1] + a[3] - 0.01 and a[2] < b[2] + b[4] - 0.01 and b[2] < a[2] + a[4] - 0.01
end
return function(style, preset)
	rawset(_G, "RENDER_CONSUMABLES", 12)
	for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
		rawset(_G, "RENDER_SCREEN", { width = screen[1], height = screen[2], size = "auto" })
		for _, arrangement in ipairs({ "centred", "spread" }) do
			rawset(_G, "RENDER_ARRANGEMENT", arrangement)
			rawset(_G, "RENDER_HUD_STYLE", style)
			local opts = { class = "SHAMAN", layout = preset, applyPreset = true, spec = {
				buffs = { { "Nature's Swiftness", 136076, { 10, 8 } }, { "Elemental Mastery", 136115, { 30, 14 } }, { "Buff 3", 136076, { 30, 14 } }, { "Buff 4", 136076, { 30, 14 } }, { "Buff 5", 136076, { 30, 14 } }, { "Buff 6", 136076, { 30, 14 } } },
			} }
			local bars, ns = Hud.Module("actionbars", opts)
			local env = Hud.envs[bars]
			local rect = { Scene.Rect(env, ns.Consumables.header) }
			local label = string.format("%dx%d %s", screen[1], screen[2], style .. " " .. preset .. " " .. arrangement)
			assert(#ns.Consumables.selected == 12 and ns.Consumables.header:IsShown(), "exercise the maximum occupied footprint")
			assert(rect[1] >= 0 and rect[2] >= 0 and rect[1] + rect[3] <= 1080 * screen[1] / screen[2] and rect[2] + rect[4] <= 1080, label .. ": keep consumables on screen")
			local timers = 0
			for _, module in ipairs({ "unitframes", "cooldowns" }) do
				local scene = Hud.Module(module, opts)
				for _, item in ipairs(scene.items) do
					if item.text == "8s" or item.text == "14s" then timers = timers + 1 end
					local light = item.file and (item.file:find("Glow.png", 1, true) or item.file:find("Shadow", 1, true))
					assert(light or not Overlap(rect, item.rect), label .. ": consumables overlap " .. module .. " " .. (item.text or item.file or item.kind) .. " " .. table.concat(item.rect, ","))
				end
			end
			assert(timers >= 2, label .. ": guard includes the player aura row's 8s/14s timers")
			assert(#env._errors == 0, tostring(env._errors[1]))
		end
	end
	rawset(_G, "RENDER_CONSUMABLES", nil)
	rawset(_G, "RENDER_SCREEN", nil)
	rawset(_G, "RENDER_HUD_STYLE", nil)
	rawset(_G, "RENDER_ARRANGEMENT", nil)
	print("consumables clearance ok: maximum grid clears drawn units, auras and timers at four sizes x both arrangements: " .. style .. " " .. (preset))
end
