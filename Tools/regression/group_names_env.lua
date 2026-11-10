local G = dofile("Tools/regression/group_env.lua")
local Common = dofile("Tools/render/scenes/_common.lua")

local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local NAME = "Thaldrenwick"

return function(screens)
	local previous = rawget(_G, "RENDER_SCREEN")
	for _, screen in ipairs(screens) do
		rawset(_G, "RENDER_SCREEN", { width = screen[1], height = screen[2], uiScale = 768 / 1080 })
		for _, preset in ipairs({ "Default", "DPS", "Tank", "Healer" }) do
			local env, K, ns = G.New({ setup = Common.ForceScreen })
			env.SetQuiet(true)
			if preset ~= "Default" then
				assert(K.Setup.Apply({ layout = preset, modules = { GroupFrames = true } }))
			end
			for batch = 0, 2 do
				local roster = {}
				for i = 1, 4 do
					local class = CLASSES[batch * 4 + i]
					if class then
						roster[#roster + 1] = { name = NAME, class = class, health = 80, maxHealth = 100, role = "DAMAGER" }
					end
				end
				G.SetRoster(env, "party", roster, { name = NAME, class = "HUNTER", health = 80, maxHealth = 100 })
				assert(K.Modules.Enable("GroupFrames"))
				env.RunTimers()
				local sharedSize, count = nil, 0
				local context = preset .. " at " .. screen[1] .. "x" .. screen[2]
				ns.Unit.ForEach(function(f)
					if f.kind == "party" and f.unit then
						local path, size = f.name:GetFont()
						assert(path == ns.Settings.COMPACT_NAME_FONT, context .. ": the captioned group keeps its measured compact face")
						assert(not sharedSize or math.abs(sharedSize - size) < 0.00001, context .. ": one size across the entire group")
						assert(f.name:GetText() == NAME, context .. ": the twelve-letter name stays whole")
						assert(ns.Names.Width(f.name, NAME, size) <= f.nameWidth + f.nameFit.slack, context .. ": the full advance fits its snapped lane")
						assert(size >= K.Widgets.FontSize(f.name, f.nameFit.min) - 0.00001, context .. ": the existing floor is unchanged")
						sharedSize, count = size, count + 1
					end
				end)
				assert(count == #roster + 1, context .. ": roster arrival and departure leave only the current members")
				assert(#env._errors == 0, tostring(env._errors[1]))
			end
			collectgarbage()
		end
	end
	rawset(_G, "RENDER_SCREEN", previous)
end
