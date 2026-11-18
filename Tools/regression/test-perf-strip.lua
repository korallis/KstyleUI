-- test-perf-strip.lua: unchanged strip ticks touch no widgets, and changed strings only move when their measured width changes.
local D = dofile("Tools/regression/databars_env.lua")
local env, K, ns, game = D.New()
local strip = ns.Strip
local counts = {}
for _, item in pairs(strip.view.items) do
	for _, object in ipairs({ item.button, item.value, item.label, item.dot }) do
		for _, method in ipairs({ "SetText", "SetPoint", "ClearAllPoints", "SetWidth", "SetTextColor" }) do
			local original = object[method]
			object[method] = function(self, ...)
				counts[method] = (counts[method] or 0) + 1
				return original(self, ...)
			end
		end
	end
end
strip.Tick()
assert(not next(counts), "P2: cache formatted strip values; an unchanged tick must touch no widgets")
dofile("Tools/regression/instruction_budget.lua")(strip.Tick, 2000, "P2: cache strip text and re-place only after width changes")
game.fps = game.fps + 1
strip.Tick()
assert(counts.SetText == 1, "P2: set only the changed formatted value")
assert(not counts.SetPoint, "P2: re-place only when a measured width changes")
assert(#env._errors == 0 and K.ErrorCount() == 0, "strip tick must keep working")
print("perf strip ok")
