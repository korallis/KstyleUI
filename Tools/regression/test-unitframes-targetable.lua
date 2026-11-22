-- test-unitframes-targetable.lua: only boss targetability changes refresh the boss column, with the same health, name, cast and Targeted chip state as an encounter refresh.
local U = dofile("Tools/regression/unitframes_env.lua")

for _, style in ipairs({ "medallions" }) do
	local env, K, ns = U.New()
	env.RunTimers()
	local views = ns.Frames.Get("boss").views
	for i = 1, #views do
		U.SetUnit(env, "boss" .. i, { name = "Boss " .. i, health = 500, healthMax = 1000, level = 62, reaction = 2, canAttack = true })
	end
	env.FireEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
	env.RunTimers()
	local refreshes, casts, marks = 0, 0, 0
	local all, cast, mark = ns.Unit.All, ns.CastBars.Refresh, ns.Frames.MarkTargets
	ns.Unit.All = function(...)
		refreshes = refreshes + 1
		return all(...)
	end
	ns.CastBars.Refresh = function(...)
		casts = casts + 1
		return cast(...)
	end
	ns.Frames.MarkTargets = function(...)
		marks = marks + 1
		return mark(...)
	end
	local function state()
		local out = {}
		for _, view in ipairs(views) do
			local value, low, high = U.Bar(env, view.health)
			out[#out + 1] = table.concat({ U.Shown(env, view.name), value, low, high,
				tostring(view.castbar.active), tostring(view.chip:IsShown()), view.body:GetAlpha(),
				U.Shown(env, view.chip.name), tostring(view.button:IsShown()) }, ":")
		end
		return table.concat(out, "|")
	end
	for _, combat in ipairs({ false, true }) do
		env.SetCombat(combat)
		env._restricted = combat
		for _, token in ipairs({ "raid7", "nameplate3", "target", "boss0", "boss9", "boss10", "boss1target" }) do
			local before = state()
			refreshes, casts, marks = 0, 0, 0
			env.FireEvent("UNIT_TARGETABLE_CHANGED", token)
			assert(refreshes == 0 and casts == 0 and marks == 0, token .. ": filter non-boss targetability changes before refreshing bosses or marking targets")
			assert(state() == before, token .. ": unrelated targetability leaves the boss column intact")
		end
		for i = 1, 8 do
			env._units.boss1.health = 400 + i
			env._units.boss1.name = "Changed " .. i
			env._units.boss1.cast = { name = "Frostbolt", texture = 135846, start = 1000, finish = 3500, spellID = 116 }
			env._units.target = env._units.boss1
			refreshes, casts, marks = 0, 0, 0
			env.FireEvent("UNIT_TARGETABLE_CHANGED", "boss" .. i)
			assert(refreshes == #views and casts == 1 and marks == 1, "boss" .. i .. ": refresh the whole boss column, casts and target markers")
			assert(U.Bar(env, views[1].health) == 400 + i and views[1].castbar.active, "the boss change reaches health and cast widgets")
			assert(views[1].chip:IsShown() and views[1].body:GetAlpha() == 0, "the targeted boss still folds to its chip")
			local actual = state()
			env.FireEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
			assert(state() == actual, style .. ": targetability keeps the unchanged encounter-refresh result")
		end
	end
	refreshes, marks = 0, 0
	env.FireEvent("UNIT_TARGETABLE_CHANGED")
	assert(refreshes == #views and marks == 1, style .. ": a missing unit keeps the old refresh instead of raising")
	assert(#env._errors == 0 and K.ErrorCount() == 0, style .. ": no event errors")
end

print("unitframes targetable ok")
