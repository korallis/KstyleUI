-- KstyleUI_DataBars.lua: the data bars' value paint and ornament paths at Full, with their time budgets in microseconds per call, for test-perf-hud.lua.
local Perf = ...
local D = dofile("Tools/regression/databars_env.lua")

-- Bars() -> env, ns, the experience view, its settings and two readings of it: the same label, and one whose
-- label has no rested share and so is narrower.
local function Bars()
	local env, K, ns = D.New()
	D.W.Settle(env)
	local xp = ns.Bars.views.xp
	assert(K.Widgets.Setting("ornaments") == "Full" and xp.ornament.used >= 3, "the experience bar places its rail and both ends at Full, not " .. xp.ornament.used .. " pieces")
	local info, plain = xp.info, {}
	for k, v in pairs(info) do plain[k] = v end
	plain.rested = 0
	return env, ns, xp, ns.Settings().xp, info, plain
end

return {
	{
		name = "DataBars PLAYER_XP_UPDATE at Full, label unchanged",
		budget = 300,
		setup = function()
			local env = Bars()
			return env, Perf.Event(env, "PLAYER_XP_UPDATE", "player")
		end,
	},
	{
		name = "DataBars experience painted at Full, label unchanged",
		budget = 150,
		setup = function()
			local env, ns, xp, s, info = Bars()
			return env, function()
				ns.Bars.PaintValues(xp, s, info, true)
			end
		end,
	},
	{
		name = "DataBars experience painted at Full, the label's width changes",
		budget = 1400,
		calls = 200,
		setup = function()
			local env, ns, xp, s, info, plain = Bars()
			local which = false
			return env, function()
				which = not which
				ns.Bars.PaintValues(xp, s, which and plain or info, true)
				assert(xp.ornament.used >= 3)
			end
		end,
	},
}
