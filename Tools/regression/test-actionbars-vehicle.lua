local AB = dofile("Tools/regression/actionbars_env.lua")
local U = dofile("Tools/regression/unitframes_env.lua")
local Load = dofile("Tools/regression/load_files.lua")

local function Rect(frame)
	local scale = frame:GetEffectiveScale()
	return { frame:GetLeft() * scale, frame:GetBottom() * scale, frame:GetRight() * scale, frame:GetTop() * scale }
end

local function Clear(a, b, label)
	assert(a[3] < b[1] or b[3] < a[1] or a[4] < b[2] or b[4] < a[2], label .. ": leave vehicle overlaps; place it outside the HUD surfaces")
end

for _, screen in ipairs({ { 5120, 1440 }, { 3456, 2234 }, { 1920, 1080 } }) do
	local env, K, ns = AB.New({
		width = screen[1], height = screen[2], class = "WARLOCK",
		setup = function(e)
			U.Install(e)
			e.UnitHasVehicleUI = function() return true end
			e.CanExitVehicle = function() return true end
			e._game.vehicle = 12
			e._game.petExists = true
			e._game.pet[1] = { name = "Firebolt", texture = 135809, spellID = 8001 }
			e._game.forms[1] = { texture = 132089, spellID = 7001 }
		end,
	})
	Load(U.Files(), env)
	AB.Enable(env, K)
	K.Modules.Enable("UnitFrames")
	for _, style in ipairs({ "medallions", "frames", "orbs" }) do
		env.CanExitVehicle = function() return true end
		local label = style .. " " .. screen[1] .. "x" .. screen[2]
		K.Options.Write("HudStyle", "style", style)
		assert(K.Setup.Apply({ layout = "DPS", modules = { ActionBars = true, UnitFrames = true } }))
		env.RunTimers()
		env.FireEvent("UNIT_ENTERED_VEHICLE", "player")
		local leave = ns.leaveButton
		assert(leave:IsShown(), label .. ": vehicle entry shows the leave button")
		local rect = Rect(leave)
		local root = Rect(K.Scale.Root())
		assert(rect[1] >= root[1] and rect[2] >= root[2] and rect[3] <= root[3] and rect[4] <= root[4], label .. ": leave vehicle must be on screen")
		if style == "medallions" then
			assert(ns.Slab.hub:IsShown(), label .. ": exercise the visible hub")
			Clear(rect, Rect(ns.Slab.hub), label .. " hub")
		end
		for key, bar in pairs(ns.bars) do
			if bar:Shown() then
				for _, button in ipairs(bar.buttons) do
					if button:IsShown() then
						Clear(rect, Rect(button), label .. " " .. key)
					end
				end
				local slab = ns.Slab.sides and ns.Slab.sides[key]
				if slab and slab:IsShown() then
					Clear(rect, Rect(slab), label .. " " .. key .. " slab")
				end
			end
		end
		local units = env._addons.KstyleUI_UnitFrames
		for _, kind in ipairs(U.KINDS) do
			local frame = units.Frames.Get(kind)
			if frame then
				Clear(rect, Rect(frame.holder), label .. " " .. kind)
				for _, view in ipairs(frame.views) do
					for _, key in ipairs({ "medallion", "portraitFrame", "orb" }) do
						if view[key] and view[key]:IsShown() then
							Clear(rect, Rect(view[key]), label .. " " .. kind .. " " .. key)
						end
					end
				end
			end
		end
		AB.Protect(env, leave)
		env.SetCombat(true)
		env._blocked = {}
		env.FireEvent("VEHICLE_UPDATE")
		env.FireEvent("UPDATE_VEHICLE_ACTIONBAR")
		assert(#env._blocked == 0, label .. ": vehicle updates must defer protected changes until combat ends: " .. table.concat(env._blocked, ", "))
		assert(K.Combat.Pending() > 0, label .. ": vehicle updates queue an out-of-combat refresh")
		env.SetCombat(false)
		env.RunTimers()
		for i, edge in ipairs(Rect(leave)) do
			assert(math.abs(edge - rect[i]) < 1e-6, label .. ": the leave button keeps its clear position after combat")
		end
		env.CanExitVehicle = function() return false end
		env.FireEvent("UNIT_EXITED_VEHICLE", "player")
		assert(not leave:IsShown(), label .. ": leaving the vehicle hides the button")
		assert(#env._errors == 0, AB.Errors(env))
		print("vehicle leave clear: " .. label)
	end
end
