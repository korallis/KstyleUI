-- test-combattext-anchors.lua: KstyleUI_CombatText puts numbers on KstyleUI unit, group and nameplate frames, found by their unit attribute and kept current as the group changes.
local CT = dofile("Tools/regression/combattext_env.lua")
local Hit, On, Shown, Anim, Finish = CT.Hit, CT.On, CT.Shown, CT.Anim, CT.Finish

local function near(a, b)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-6
end

local PARTY = { "player", "party1", "party2", "party3" }
local BOSSES = { "boss1", "boss2", "boss3", "boss4", "boss5" }

-- Running(env, K, name, build) starts a stand-in module whose Enable builds its frames, as the real ones do.
local function Running(env, K, name, build)
	local result = {}
	local def = CT.CoreEnv.Module(name, {
		onEnable = function()
			if build and not result.built then
				result.built = true
				result.holder, result.buttons = build()
			end
		end,
	})
	K.Modules.Register(def)
	K.Modules.Enable(name)
	env.RunTimers()
	assert(K.Modules.IsRunning(name), name .. " did not start")
	return result
end

-- Unit frames: numbers ride the secure button whose unit attribute matches -------------------------

do
	local env, K, ns = CT.New()
	local uf = Running(env, K, "UnitFrames", function()
		return CT.UnitHolder(env, K, "unitframes.target", "UnitFrames", { "target" })
	end)
	CT.Enable(env, K)
	local button = uf.buttons[1]
	Hit(env, "target", "WOUND", "", env.Secret(300), 4)
	local on = On(ns, button)
	assert(#on == 1, "a hit on the target shows on the target frame, got " .. #on)
	local number = on[1]
	assert(number.frame:GetParent() == ns.Module.layer, "numbers on frames live in the module's own layer")
	local point, _, relPoint = number.frame:GetPoint(1)
	assert(point == "CENTER" and relPoint == "CENTER", "numbers start at the frame's centre by default")
	assert(near(Anim(number, "move").offsetY, 40), "numbers on frames travel the distance setting, got " .. tostring(Anim(number, "move").offsetY))
	assert(CT.Text(env, number) == "secret:short(300)", "the amount is untouched")
	assert(#On(ns, ns.Module.field) == 0, "the target's numbers stay off your field")

	K.Options.Write("CombatText", "framePoint", "TOP")
	K.Options.Write("CombatText", "distance", 80)
	Hit(env, "target", "WOUND", "", env.Secret(300), 4)
	local top = On(ns, button)[2]
	local _, _, topPoint, _, y = top.frame:GetPoint(1)
	assert(topPoint == "TOP" and y > 0, "numbers can start just above the frame")
	assert(near(Anim(top, "move").offsetY, 80), "a longer distance moves them further")

	K.Options.Write("CombatText", "units.target", false)
	Hit(env, "target", "WOUND", "", env.Secret(300), 4)
	assert(#On(ns, button) == 2, "the target frame can be switched off")
	Hit(env, "focus", "WOUND", "", env.Secret(300), 4)
	assert(#Shown(ns) == 2, "a unit with no KstyleUI frame shows nothing")
	assert(env._errors[1] == nil, tostring(env._errors[1]))
end

-- A module that starts after CombatText is found; one that stops is dropped -------------------------

do
	local env, K, ns = CT.New()
	CT.Enable(env, K)
	local uf = Running(env, K, "UnitFrames", function()
		return CT.UnitHolder(env, K, "unitframes.focus", "UnitFrames", { "focus" })
	end)
	Hit(env, "focus", "HEAL", "", env.Secret(80), 2)
	assert(#On(ns, uf.buttons[1]) == 1, "frames built after CombatText started still get numbers")
	K.Modules.Disable("UnitFrames")
	env.RunTimers()
	Hit(env, "focus", "HEAL", "", env.Secret(80), 2)
	assert(#On(ns, uf.buttons[1]) == 1, "a stopped module's frames get no new numbers")
end

-- Your numbers: the field by default, or the player frame, with the field as the fallback ---------

do
	local env, K, ns = CT.New()
	local uf = Running(env, K, "UnitFrames", function()
		return CT.UnitHolder(env, K, "unitframes.player", "UnitFrames", { "player" })
	end)
	CT.Enable(env, K)
	local button = uf.buttons[1]
	Hit(env, "player", "WOUND", "", env.Secret(5), 1)
	assert(#On(ns, ns.Module.field) == 1 and #On(ns, button) == 0, "your numbers go to your field by default")
	assert(K.Layout.Live("combattext.player"), "the field has a mover while it holds your numbers")
	K.Options.Write("CombatText", "playerPlacement", "frame")
	Hit(env, "player", "WOUND", "", env.Secret(5), 1)
	assert(#On(ns, button) == 1 and #On(ns, ns.Module.field) == 1, "your numbers can ride your player frame")
	env.RunTimers()
	assert(not K.Layout.Live("combattext.player"), "an unused field has no mover in Layout Mode")
	K.Options.Write("CombatText", "units.player", false)
	Hit(env, "player", "WOUND", "", env.Secret(5), 1)
	assert(#Shown(ns) == 2, "your numbers can be switched off")
end

do
	local env, K, ns = CT.New()
	CT.Enable(env, K)
	K.Options.Write("CombatText", "playerPlacement", "frame")
	Hit(env, "player", "WOUND", "", env.Secret(5), 1)
	assert(#On(ns, ns.Module.field) == 1, "without a KstyleUI player frame your numbers use the field")
	env.RunTimers()
	assert(K.Layout.Live("combattext.player"), "so the field keeps its mover")
end

-- Group frames: found inside their header, smaller, and kept current as the roster changes -----------

do
	local env, K, ns = CT.New()
	local gf = Running(env, K, "GroupFrames", function()
		return CT.UnitHolder(env, K, "groupframes.party", "GroupFrames", PARTY, true)
	end)
	CT.Enable(env, K)
	local buttons = gf.buttons
	Hit(env, "party2", "WOUND", "", env.Secret(70), 1)
	local on = On(ns, buttons[3])
	assert(#on == 1, "a hit on party2 shows on party2's frame")
	assert(near(on[1].frame:GetScale(), 14 / 18), "numbers on group frames use the group size, got " .. tostring(on[1].frame:GetScale()))

	Hit(env, "player", "HEAL", "", env.Secret(70), 2)
	assert(#On(ns, buttons[1]) == 1 and #On(ns, ns.Module.field) == 1, "your party frame and your field both show your numbers")

	buttons[3]:SetAttribute("unit", "party3")
	buttons[4]:SetAttribute("unit", "party2")
	env.FireEvent("GROUP_ROSTER_UPDATE")
	env.RunTimers()
	Hit(env, "party2", "WOUND", "", env.Secret(70), 1)
	assert(#On(ns, buttons[4]) == 1, "after a roster change party2's numbers follow its new frame")

	buttons[4]:SetAttribute("unit", "party1")
	buttons[2]:SetAttribute("unit", "party2")
	Hit(env, "party2", "WOUND", "", env.Secret(70), 1)
	assert(#On(ns, buttons[4]) == 1, "a frame whose unit changed gets no numbers for its old unit")
	env.RunTimers()
	Hit(env, "party2", "WOUND", "", env.Secret(70), 1)
	assert(#On(ns, buttons[2]) == 1, "the stale frame triggers a rescan, and the next hit finds the right frame")

	local late = env.CreateFrame("Button", nil, buttons[1]:GetParent(), "SecureUnitButtonTemplate")
	late:SetAttribute("unit", "party4")
	Hit(env, "party4", "WOUND", "", env.Secret(70), 1)
	assert(#On(ns, late) == 0, "a frame the header made just now is not known yet")
	env.RunTimers()
	Hit(env, "party4", "WOUND", "", env.Secret(70), 1)
	assert(#On(ns, late) == 1, "a hit on an unknown group unit rescans, so the new frame shows the next number")

	buttons[2]:Hide()
	Hit(env, "party2", "WOUND", "", env.Secret(70), 1)
	assert(#On(ns, buttons[2]) == 1, "a hidden frame shows no numbers")

	buttons[2]:SetAttribute("unit", "party9")
	buttons[3]:SetAttribute("unit", "party2")
	Hit(env, "party2", "WOUND", "", env.Secret(70), 1)
	env.RunTimers()
	Hit(env, "party2", "WOUND", "", env.Secret(70), 1)
	assert(#On(ns, buttons[3]) == 2, "a hidden frame whose unit moved still triggers the rescan, got " .. #On(ns, buttons[3]))
	buttons[2]:SetAttribute("unit", "party2")
	buttons[3]:SetAttribute("unit", "party3")
	env.FireEvent("GROUP_ROSTER_UPDATE")
	env.RunTimers()

	buttons[4].GetEffectiveAlpha = function()
		return 0.3
	end
	Hit(env, "party1", "WOUND", "", env.Secret(70), 1)
	local faded = On(ns, buttons[4])
	assert(near(CT.LastCall(faded[#faded].text, "SetAlpha"), 0.3), "numbers take the frame's opacity, such as a range fade")
	local secretAlpha = env.Secret(0.5)
	buttons[4].GetEffectiveAlpha = function()
		return secretAlpha
	end
	Hit(env, "party1", "WOUND", "", env.Secret(70), 1)
	faded = On(ns, buttons[4])
	assert(CT.LastCall(faded[#faded].text, "SetAlpha") == secretAlpha, "a secret opacity reaches SetAlpha untouched")
	Hit(env, "player", "WOUND", "", env.Secret(70), 1)
	local mine = On(ns, ns.Module.field)
	assert(CT.LastCall(mine[#mine].text, "SetAlpha") == 1, "your field's numbers take its opacity as its children")

	K.Options.Write("CombatText", "groupSize", 20)
	Hit(env, "party3", "WOUND", "", env.Secret(70), 1)
	local bigger = On(ns, buttons[3])
	assert(near(bigger[#bigger].frame:GetScale(), 20 / 18), "the group size setting applies")

	buttons[2]:Show()
	local function storm()
		for i = 1, 200 do
			Hit(env, PARTY[i % 4 + 1], i % 3 == 0 and "HEAL" or "WOUND", "", env.Secret(i), 1)
			if i % 5 == 0 then
				for _, number in ipairs(Shown(ns)) do
					Finish(number)
				end
			end
		end
	end
	storm()
	local frames = #env._frames
	storm()
	assert(#env._frames == frames, "numbers on frames come from the pool: " .. (#env._frames - frames) .. " frames were made")
	assert(env._errors[1] == nil, tostring(env._errors[1]))
end

-- Raid frames are off until switched on ------------------------------------------------------------

do
	local env, K, ns = CT.New()
	local gf = Running(env, K, "GroupFrames", function()
		return CT.UnitHolder(env, K, "groupframes.raid", "GroupFrames", { "raid1", "raid2" }, true)
	end)
	CT.Enable(env, K)
	Hit(env, "raid2", "WOUND", "", env.Secret(9), 1)
	assert(#On(ns, gf.buttons[2]) == 0, "raid frames show no numbers by default")
	K.Options.Write("CombatText", "units.raid", true)
	Hit(env, "raid2", "WOUND", "", env.Secret(9), 1)
	assert(#On(ns, gf.buttons[2]) == 1, "raid frames show numbers once switched on")
end

-- Boss frames: each boss button by its unit --------------------------------------------------------

do
	local env, K, ns = CT.New()
	local uf = Running(env, K, "UnitFrames", function()
		return CT.UnitHolder(env, K, "unitframes.boss", "UnitFrames", BOSSES)
	end)
	CT.Enable(env, K)
	Hit(env, "boss3", "WOUND", "CRITICAL", env.Secret(4000), 32)
	assert(#On(ns, uf.buttons[3]) == 1 and #On(ns, uf.buttons[1]) == 0, "boss3's numbers show on boss3's frame")
end

-- A frame Layout scales up gets larger numbers that travel further ---------------------------------

do
	local env, K, ns = CT.New()
	local uf = Running(env, K, "UnitFrames", function()
		return CT.UnitHolder(env, K, "unitframes.pet", "UnitFrames", { "pet" })
	end)
	uf.holder:SetScale(1.5)
	CT.Enable(env, K)
	Hit(env, "pet", "WOUND", "", env.Secret(9), 1)
	local number = On(ns, uf.buttons[1])[1]
	assert(near(number.frame:GetScale(), 1.5), "numbers follow the frame's scale, got " .. tostring(number.frame:GetScale()))
	assert(near(Anim(number, "move").offsetY * 1.5, 60), "and travel the distance in the frame's units")
end

-- Nameplates: Blizzard's base plate, while KstyleUI's Nameplates module runs ------------------------

do
	local env, K, ns = CT.New()
	CT.Enable(env, K)
	local plate = CT.Plate(env, "nameplate3")
	Hit(env, "nameplate3", "WOUND", "", env.Secret(12), 4)
	assert(#On(ns, plate) == 0, "plates show no numbers while KstyleUI's nameplates are off")
	Running(env, K, "Nameplates")
	Hit(env, "nameplate3", "WOUND", "", env.Secret(12), 4)
	local on = On(ns, plate)
	assert(#on == 1, "a nameplate unit's numbers show on its plate")
	assert(near(on[1].frame:GetScale(), 1), "plate numbers keep their own size")
	env.FireEvent("NAME_PLATE_UNIT_REMOVED", "nameplate3")
	assert(#On(ns, plate) == 0, "a plate's numbers go when its unit leaves")
	Hit(env, "nameplate7", "WOUND", "", env.Secret(12), 4)
	assert(#Shown(ns) == 0, "a nameplate unit with no plate shows nothing")
	K.Options.Write("CombatText", "units.nameplate", false)
	Hit(env, "nameplate3", "WOUND", "", env.Secret(12), 4)
	assert(#On(ns, plate) == 0, "plate numbers can be switched off")
	K.Options.Write("CombatText", "units.nameplate", true)
	env.C_NamePlate = nil
	Hit(env, "nameplate3", "WOUND", "", env.Secret(12), 4)
	assert(#On(ns, plate) == 0 and env._errors[1] == nil, "without C_NamePlate plates show nothing and nothing fails")
end

-- The smoke check says how many frames show numbers ------------------------------------------------

do
	local env, K = CT.New()
	Running(env, K, "GroupFrames", function()
		return CT.UnitHolder(env, K, "groupframes.party", "GroupFrames", PARTY, true)
	end)
	CT.Enable(env, K)
	K.DevTest.Run()
	local line
	for _, entry in ipairs(env.KstyleUIDB.devlog) do
		if entry.message:find("combat text", 1, true) then
			line = entry.message
		end
	end
	assert(line and line:find("4 group frames", 1, true), "the smoke check counts the frames found: " .. tostring(line))
end

print("combat text anchors ok")
