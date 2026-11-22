-- test-perf-bar-events.lua: SPELL_UPDATE_COOLDOWN and UPDATE_SHAPESHIFT_FORM touch only what changed on the action bars, the crest jewels and the cooldown mirror, under Medallions and Frames, within exact instruction and widget-call ceilings.
local AB = dofile("Tools/regression/actionbars_env.lua")
local C = dofile("Tools/regression/cooldowns_env.lua")
local Budget = dofile("Tools/regression/path_budget.lua")
local W = AB.W

local function Cost(env, run, instructions, calls, fix)
	run()
	local result = Budget.Count(env, run, 1)
	Budget.Check(result, instructions, calls, fix)
	return result
end

local function Bars(class, style)
	local env, K, ns = AB.New({
		class = class,
		setup = function(e)
			e.UnitPowerMax = function() return 5 end
			e.UnitPower = function() return 2 end
			e.GetComboPoints = function() return 2 end
			e.UnitPowerType = function() return 3 end
		end,
	})
	env._game.forms = {
		{ texture = 132349, isActive = true, spellID = 2457 },
		{ texture = 132275, isActive = false, spellID = 71 },
		{ texture = 132276, isActive = false, spellID = 2458 },
	}
	AB.Enable(env, K)
	if style then K.Options.Write("HudStyle", "style", style) end
	for n = 1, 12 do
		AB.Slot(env, n, { texture = 135000 + n, type = "spell", id = 100 + n, cooldown = { name = "cd" .. n } })
	end
	env.FireEvent("UPDATE_SHAPESHIFT_FORMS")
	env.RunTimers()
	local info = { isOnGCD = false }
	env.C_ActionBar.GetActionCooldown = function() return info end
	return env, K, ns
end

local results = {}
for _, case in ipairs({ { "WARRIOR" }, { "ROGUE" }, { "WARRIOR", "frames" } }) do
	local class, style = case[1], case[2]
	local label = class .. " " .. (style or "medallions")
	local env, _, ns = Bars(class, style)
	local sweep = Cost(env, function() env.FireEvent("SPELL_UPDATE_COOLDOWN") end, 3300, 20,
		label .. ": SPELL_UPDATE_COOLDOWN gives pet and stance buttons Button.UpdateCooldown, never a full Button.Update (staging: 6556 instructions, 73 widget calls)")
	local button, other = AB.Button(ns, "bar1", 5), AB.Button(ns, "bar1", 6)
	local bound, untouched = #W.Calls(button.cooldown, "SetCooldownFromDurationObject"), #W.Calls(other.cooldown, "SetCooldownFromDurationObject")
	local spell = Cost(env, function() env.FireEvent("SPELL_UPDATE_COOLDOWN", 105, 105, nil, 0) end, 2300, 5,
		label .. ": an off-GCD SPELL_UPDATE_COOLDOWN updates the buttons holding that spell, as OnUsableChanged does per slot (staging: 6556 instructions, 73 widget calls)")
	assert(#W.Calls(button.cooldown, "SetCooldownFromDurationObject") == bound + 2, label .. ": the spell's own button takes its cooldown")
	assert(#W.Calls(other.cooldown, "SetCooldownFromDurationObject") == untouched, label .. ": another spell's button is left alone")
	local form = Cost(env, function() env.FireEvent("UPDATE_SHAPESHIFT_FORM") end, 3500, 10,
		label .. ": UPDATE_SHAPESHIFT_FORM re-sets action icons as Blizzard's ActionButton does and leaves unchanged jewels alone (staging: 30017 instructions and 358 widget calls for a warrior, 36214 and 636 for a rogue)")
	env._game.slots[3].texture = 136000
	env._game.slots[4] = { texture = 135004, type = "macro", id = 999, subType = "spell" }
	env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	assert(AB.Button(ns, "bar1", 3).icon:GetTexture() == 136000, label .. ": a form change re-sets the icon")
	assert(AB.Button(ns, "bar1", 4).spellID == 999, label .. ": a form change that swaps a macro's spell updates the whole button")
	assert(#env._errors == 0, AB.Errors(env))
	results[#results + 1] = string.format("%s %d/%d, %d/%d, %d/%d", label, sweep.instructions, sweep.calls, spell.instructions, spell.calls, form.instructions, form.calls)
end

local env, K = C.New({ setup = C.Game })
K.Options.Write("Cooldowns", "path", "mirror")
C.Enable(env, K)
env.RunTimers()
local untracked = Cost(env, function() env.FireEvent("SPELL_UPDATE_COOLDOWN", 9999, nil, nil, 0) end, 450, 2,
	"cooldown mirror: an off-GCD SPELL_UPDATE_COOLDOWN for an untracked spell refreshes no icon (staging: 1759 instructions, 10 widget calls)")
local function Asked(spell)
	local n = 0
	for _, call in ipairs(env._cdm.calls) do
		if call.name == "GetSpellCooldownDuration" and call.args[1] == spell then n = n + 1 end
	end
	return n
end
local asked = Asked(1002)
local tracked = Cost(env, function() env.FireEvent("SPELL_UPDATE_COOLDOWN", 1002, nil, nil, 0) end, 900, 5,
	"cooldown mirror: an off-GCD SPELL_UPDATE_COOLDOWN refreshes only the icons for its spell (staging: 1759 instructions, 10 widget calls)")
assert(Asked(1002) == asked + 2, "cooldown mirror: the event's own spell refreshes")
local icon = Cost(env, function() env.FireEvent("SPELL_UPDATE_ICON") end, 900, 0,
	"cooldown mirror: SPELL_UPDATE_ICON with no icon changed writes no texture; Texture in Mirror.lua keeps each icon's file")
env.FireEvent("COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED", 1003, nil)
asked = Asked(1003)
env.FireEvent("SPELL_UPDATE_COOLDOWN", 1033, nil, nil, 0)
assert(Asked(1003) == asked + 1, "cooldown mirror: an event naming a just-removed override refreshes its base spell, as Blizzard's previousOverrideSpellID does")
assert(#env._errors == 0, tostring(env._errors[1]))
print("perf bar events ok: " .. table.concat(results, "; ") .. "; mirror untracked " .. untracked.instructions .. "/" .. untracked.calls .. ", tracked " .. tracked.instructions .. "/" .. tracked.calls .. ", retexture " .. icon.instructions .. "/" .. icon.calls)
