-- test-meters-threat-dock.lua: the threat card docked beside the damage card in Both clears every HUD element and the story rail on every owner screen, style and layout.
local M = dofile("Tools/regression/meters_env.lua")
local Geometry = dofile("Tools/regression/geometry.lua")

local function Clear(rect, left, bottom, right, top)
	return rect.right <= left + 1 or right <= rect.left + 1 or rect.top <= bottom + 1 or top <= rect.bottom + 1
end

for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	for _, style in ipairs({ "frames", "orbs", "medallions" }) do
		for _, layout in ipairs({ "DPS", "Tank", "Healer" }) do
			local env, K, ns = M.New({ width = screen[1], height = screen[2], followRole = true,
				saved = { version = 42, account = { setupSeen = true }, profiles = { Default = { HudStyle = { style = style },
					Meters = { roles = { TANK = "both", HEALER = "both", DAMAGER = "both" }, threat = { group = false } } } } },
				setup = function(e) e._fitScale, e._size = true, "auto" end })
			assert(K.Setup.Apply({ layout = layout, modules = { Meters = true } }))
			env.RunTimers()
			local root, layouts = K.Scale.Root(), K.Setup.Layouts
			local preset = K.Store.Module("Layout").preset
			local places, enabled = layouts.Positions(preset, style, K.Scale.Aspect()), layouts.Enabled(preset)
			local what = string.format("%dx%d %s %s", screen[1], screen[2], style, layout)
			assert(ns.Threat.paired and ns.Threat.list.panel:IsVisible(), what .. ": the threat card docks beside the damage card in Both")
			local threat = assert(Geometry.Rect(ns.Threat.holder, root))
			for _, element in ipairs(layouts.ELEMENTS) do
				local key = element.key
				if enabled[key] ~= false and places[key] and not (style == "orbs" and key == "unitframes.player") then
					local w, h = layouts.StyleSize(style, K.Scale.Aspect(), key)
					if not w then w, h = layouts.Footprint(preset, key, style, K.Scale.Aspect()) end
					local styled = layouts.Aspect(K.Scale.Aspect(), style, preset, key) or layouts.Style(style, preset, key)
					if styled and styled.width then w, h = styled.width, styled.height end
					local left, bottom, right, top = layouts.Rect({ width = w, height = h }, places[key], root:GetWidth(), root:GetHeight())
					assert(Clear(threat, left, bottom, right, top), string.format("%s: the docked threat card %.1f %.1f %.1f %.1f overlaps %s %.1f %.1f %.1f %.1f", what, threat.left, threat.bottom, threat.right, threat.top, key, left, bottom, right, top))
				end
			end
			for _, guide in ipairs({ true, false }) do
				for _, card in pairs(layouts.Story(preset, root:GetHeight(), guide, style, root:GetWidth()) or {}) do
					if type(card) == "table" and card.anchor and card.width > 0 and card.height > 0 then
						assert(Clear(threat, layouts.Rect(card, card, root:GetWidth(), root:GetHeight())), what .. ": the docked threat card overlaps the story rail's " .. tostring(card.key))
					end
				end
			end
			assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
		end
	end
end
print("the docked threat card clears the HUD: 4 screens, 3 styles, 3 layouts")
