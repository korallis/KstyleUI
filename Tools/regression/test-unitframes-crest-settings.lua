-- test-unitframes-crest-settings.lua: medallion aura choices subtract only the fan's set, and the fan works independently of those choices.
local U = dofile("Tools/regression/unitframes_env.lua")
local Engine = dofile("Tools/regression/aura_fixture_engine.lua")
local fixtures = {
	{ id = 1, icon = 135813, left = 3, harmful = true, mine = true },
	{ id = 2, icon = 136026, left = 6, harmful = true, mine = false },
	{ id = 3, icon = 136207, left = 9, harmful = false, mine = true },
	{ id = 4, icon = 136118, left = 12, harmful = false, mine = false },
}
local base = { mine = { 1 }, debuffs = { 1, 2 }, buffs = { 3, 4 }, both = { 1, 2, 3, 4 } }
local function Same(actual, expected, label)
	assert(table.concat(actual, ",") == table.concat(expected, ","), label .. ": " .. table.concat(actual, ","))
end
for _, style in ipairs({ "frames", "orbs", "medallions" }) do
	local env, K, ns = U.New({ before = function(_, core)
		core.Store.Module("UnitFrames").auraLayout = "fan"
		core.Store.Module("HudStyle").style = style
		core.Callbacks.Fire("SettingChanged", "HudStyle", "style")
	end })
	U.SetUnit(env, "target", { name = "Target", health = 100, healthMax = 100, reaction = 2, auras = fixtures })
	env.SetTarget(true)
	Engine.Install(env)
	local a = ns.Frames.Get("target").views[1].auras
	for _, restricted in ipairs({ false, true }) do
		env._restricted = restricted
		env.SetCombat(restricted)
		for _, enabled in ipairs({ true, false }) do
			K.Options.Write("UnitFrames", "target.auras", enabled)
			for _, fanOn in ipairs({ false, true }) do
				K.Options.Write("UnitFrames", "target.crestDebuffs", fanOn)
				for _, filter in ipairs({ "mine", "debuffs", "buffs", "both" }) do
					K.Options.Write("UnitFrames", "target.auraFilter", filter)
					env.FireEvent("UNIT_AURA", "target", { isFullUpdate = true })
					local fan = fanOn and style == "medallions"
					local expected, actual = {}, {}
					for _, id in ipairs(base[filter]) do
						if enabled and not (fan and id == 1) then expected[#expected + 1] = id end
					end
					for _, group in ipairs({ "debuffs", "buffs" }) do
						for _, id in ipairs(a.container._groups[group].assigned) do actual[#actual + 1] = id end
					end
					table.sort(actual)
					local label = style .. "/" .. filter .. "/auras=" .. tostring(enabled) .. "/fan=" .. tostring(fanOn)
					Same(actual, expected, label .. " keeps the base aura selection minus the fan")
					if a.fan then
						Same(a.fan.containers[ns.Fan.MAX]._groups.debuffs.assigned, fan and { 1 } or {}, label .. " fan assignments")
						assert(a.fan.content._shown == fan, label .. " fan visibility is independent of medallion auras")
					else
						assert(not fan, label .. " must construct the independent fan")
					end
				end
			end
		end
	end
	assert(#env._errors == 0 and K.ErrorCount() == 0, "setting matrix has no Lua or restriction errors")
end

local env, K, ns = U.New({ before = function(_, core)
	core.Store.Module("UnitFrames").auraLayout = "fan"
	core.Store.Module("HudStyle").style = "medallions"
	core.Store.Module("UnitFrames").target = { auras = false, crestDebuffs = false }
	core.Callbacks.Fire("SettingChanged", "HudStyle", "style")
end })
local view = ns.Frames.Get("target").views[1]
assert(not view.auras, "both features disabled at login allocate no aura engines")
env._restricted = true
env.SetCombat(true)
K.Options.Write("UnitFrames", "target.crestDebuffs", true)
assert(not view.auras, "an independent fan waits for the aura gate at first construction")
env._restricted = false
env.SetCombat(false)
env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED")
assert(view.auras.fan and view.auras.fan.enabled, "opening the aura gate builds the fan even with medallion auras off")
assert(view.auras.container._enabled == false, "the medallion aura engine remains off")
K.Modules.Disable("UnitFrames")
assert(not view.auras.fan.enabled and view.auras.fan.content._shown == false, "disabling the module stops the independent fan")
assert(#env._errors == 0 and K.ErrorCount() == 0, "independent construction has no errors")
print("ok crest aura settings: 96 combinations preserve the base selection minus the independent fan")
