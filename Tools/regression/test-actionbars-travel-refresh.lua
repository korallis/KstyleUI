-- test-actionbars-travel-refresh.lua: open travel survives tray events and prepared refreshes keep the unprepared instruction budget.
local AB = dofile("Tools/regression/actionbars_env.lua")
local Fixture = dofile("Tools/regression/travel_fixture.lua")
local Budget = dofile("Tools/regression/path_budget.lua")
local env, K, ns = AB.New({ class = "MAGE" })
local data = Fixture.Install(env, true)
env._resolveRects = true
local read, reads = ns.TravelData.Read, 0
ns.TravelData.Read = function(...) reads = reads + 1; return read(...) end
AB.Enable(env, K)
env.RunTimers()
local function Tray() ns.bars.bar1:RefreshTray() end
local base = Budget.Count(env, Tray)
AB.W.Enter(ns.Travel.crest)
AB.W.Leave(ns.Travel.crest)
local count = reads
local prepared = Budget.Count(env, Tray)
print(string.format("travel tray: base %d instructions/%d calls; prepared %d/%d; scans %d", base.instructions, base.calls, prepared.instructions, prepared.calls, reads - count))
Budget.Check(prepared, base.instructions * 1.2, base.calls * 1.2, "keep bag/journal scans and menu rebuilding out of tray refreshes")
assert(reads == count, "a plain tray refresh must not rescan travel")
AB.Click(env, ns.Travel.crest, "RightButton", false)
count = reads
for _, event in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "BAG_UPDATE_DELAYED", "PET_BAR_UPDATE", "PET_BAR_UPDATE_USABLE", "PET_BAR_UPDATE_COOLDOWN", "UNIT_FLAGS" }) do
	env.FireEvent(event, "pet")
	assert(ns.Travel.menu:IsShown(), event .. ": keep the travel menu open across refreshes")
end
assert(reads == count + 1, "only the open bag event rescans; zone and pet events keep cached travel")
count = reads
K.Options.Write("ActionBars", "inputContinuity", false)
assert(ns.Travel.menu:IsShown() and ns.Travel.groups[1].buttons[1].opts.inputContinuity == false and reads == count, "settings update existing slots without closing or rescanning travel")
AB.Click(env, ns.Travel.crest, "RightButton", false)
count = reads
data.items = {}
env.FireEvent("BAG_UPDATE_DELAYED")
env.FireEvent("SPELLS_CHANGED")
env.FireEvent("NEW_MOUNT_ADDED")
env.FireEvent("PLAYER_ENTERING_WORLD")
Tray()
assert(reads == count, "closed travel defers and coalesces content scans until preparation")
AB.W.Enter(ns.Travel.crest)
AB.W.Leave(ns.Travel.crest)
assert(reads == count + 1 and ns.Travel.crest:GetAttribute("type1") == nil, "prepare dirty contents once before the next use")
AB.W.Enter(ns.Travel.crest)
AB.W.Leave(ns.Travel.crest)
assert(reads == count + 1, "a clean hover reuses the inventory for the tooltip")
AB.Click(env, ns.Travel.crest, "RightButton", false)
count = reads
env.SetCombat(true)
data.spells = {}
env.FireEvent("SPELLS_CHANGED")
assert(reads == count and ns.Travel.menu:IsShown(), "combat defers content changes without closing travel")
env.SetCombat(false)
assert(ns.Travel.menu:IsShown() and not ns.Travel.menu:GetAttribute("hasTravel"), "an open content refresh updates destinations without closing")
AB.Click(env, ns.Travel.crest, "RightButton", false)
assert(not ns.Travel.menu:IsShown(), "a second right-click closes even after the final destination disappears")
assert(#env._errors == 0 and #env._blocked == 0, AB.Errors(env))
print("ok crest travel refresh")
