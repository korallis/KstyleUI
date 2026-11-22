-- test-perf-path-budgets.lua: the audit's reload, resize, strip and object ceilings name the work to remove on regression.
local Suite = dofile("Tools/regression/suite_env.lua")
local Budget = dofile("Tools/regression/path_budget.lua")
local reload, initial = Suite.Prepare(5120, 1440)
local env, K
local login = Budget.Count(initial, function() env, K = reload() end)
Budget.Check(login, 13000000, 500000, "P3/P4/P5/P12: reject undersized story cards before fitting HUD rectangles; defer unused slices and skip unchanged inputs on reload")
local _, regions = Budget.Objects(env)
assert(regions <= 11271, "P3/P12: build nine-slices only when drawn; reload keeps " .. regions .. " regions, budget 11271")
local resize = Budget.Count(env, function()
	env.GetPhysicalScreenSize = function() return 3440, 1440 end
	env.UIParent._width = 768 * 3440 / 1440 / env.UIParent._scale
	env.FireEvent("DISPLAY_SIZE_CHANGED")
	env.RunTimers()
end)
Budget.Check(resize, 16700000, 143000, "P4/P5/P12: cache scale factors and skip unchanged widget inputs on display changes")
assert(#env._errors == 0 and K.ErrorCount() == 0, "performance budgets must exercise a successful reload and resize")
local D = dofile("Tools/regression/databars_env.lua")
local stripEnv, _, ns = D.New()
local tick = Budget.Count(stripEnv, ns.Strip.Tick)
Budget.Check(tick, 24900, 701, "P2/P12: cache formatted strip text and move only after a measured width changes")
ns.Strip.view.items.fps.button.hoverT = 0.5
local hover = Budget.Count(stripEnv, ns.Strip.view.items.fps.button.Paint, 1)
Budget.Check(hover, 400, 3, "P2: paint only the hovered readout's glyph and highlight on the dock")
local ok, err = pcall(Budget.Check, { instructions = 13000100, calls = 0 }, 13000000, 500000, "P3: defer unused slices")
assert(not ok and tostring(err):find("P3: defer unused slices", 1, true), "P12: an instruction overrun must fail and name its fix")
ok, err = pcall(Budget.Check, { instructions = 0, calls = 702 }, 24900, 701, "P2: cache strip text")
assert(not ok and tostring(err):find("P2: cache strip text", 1, true), "P12: a widget-call overrun must fail and name its fix")
print(string.format("perf path budgets ok: reload %d instructions/%d calls/%d regions; resize %d/%d; strip %d/%d", login.instructions, login.calls, regions, resize.instructions, resize.calls, tick.instructions, tick.calls))
