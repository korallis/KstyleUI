-- test-actionbars-crest-slot-scripts.lua: no Action Bars code assigns an OnShow or OnHide handler to a Blizzard aura slot. The client refuses them on a slot's button ("blocked by secret aspects"), and on Forever 1.60.1 one such hook in SlabUnleashed.lua threw inside the crest's build and stopped the whole module at login on Medallions. Every class logs in with Action Bars already on, under Medallions and under Frames, and the module must start with no error; aura_slots.lua refuses the handlers as the client does.
local AB = dofile("Tools/regression/actionbars_env.lua")
local Slots = dofile("Tools/regression/aura_slots.lua")

local CLASSES = { "WARRIOR", "ROGUE", "HUNTER", "MAGE", "WARLOCK", "PRIEST", "PALADIN", "DRUID", "SHAMAN" }

local function Setup(e)
	e.C_SpellBook = e.C_SpellBook or {}
	e.C_SpellBook.IsSpellKnown = function() return true end
	e.C_Secrets = { ShouldAurasBeSecret = function() return false end }
	e.C_UnitAuras = e.C_UnitAuras or {}
	e.C_UnitAuras.GetUnitAuraBySpellID = function() return nil end
	e.C_Spell.GetSpellTexture = function(id) return 100000 + id end
	e._slotGroups = true
	Slots.Install(e)
	e.AuraContainerSortMethod, e.AuraContainerSortDirection = { Default = 0, AuraInstanceIDOnly = 8 }, { Normal = 0, Reverse = 1 }
end

-- The fake refuses both handlers on a slot button, by either method and in any case, with the client's message, and leaves other scripts alone.
do
	local env = AB.New({ class = "WARRIOR", setup = Setup })
	local container = env.CreateFrame("AuraContainer", nil, env.UIParent)
	local slot = container:AddAuraSlot("lit", "HELPFUL")
	for _, call in ipairs({ { "HookScript", "OnShow" }, { "SetScript", "OnHide" }, { "HookScript", "onhide" } }) do
		local ok, err = pcall(slot[call[1]], slot, call[2], function() end)
		local want = "Button:" .. call[1] .. "(): Cannot assign script handler for '" .. call[2]:lower() .. "' (blocked by secret aspects)"
		assert(not ok and tostring(err):find(want, 1, true), call[1] .. " " .. call[2] .. " on an aura slot is refused: " .. tostring(err))
	end
	assert(pcall(slot.SetScript, slot, "OnEnter", function() end), "a slot takes other scripts")
end

-- A player logs in with Action Bars on, as in the report: the module starts from PLAYER_LOGIN with its saved data and builds every crest piece then.
for _, class in ipairs(CLASSES) do
	for _, style in ipairs({ "medallions", "frames" }) do
		local first, FK = AB.New({ class = class, setup = Setup })
		AB.Enable(first, FK)
		if style == "frames" then
			FK.Options.Write("HudStyle", "style", "frames")
			first.RunTimers()
		end
		assert(FK.ErrorCount() == 0, class .. " " .. style .. ", switching Action Bars on: " .. AB.Errors(first))
		local env, K = AB.New({ class = class, setup = Setup, saved = AB.CoreEnv.DeepCopy(first.KstyleUIDB) })
		env.RunTimers()
		assert(#env._errors == 0 and K.ErrorCount() == 0, class .. " " .. style .. ", logging in: " .. AB.Errors(env))
		assert(K.Modules.IsRunning("ActionBars") and not K.Modules.HasFailed("ActionBars"), class .. " " .. style .. ": Action Bars runs after login")
	end
end

print("actionbars crest slot scripts ok")
