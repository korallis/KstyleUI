local AB = dofile("Tools/regression/actionbars_env.lua")
local env, K, ns = AB.New({ class = "WARRIOR" })
local vehicle = false
env.UnitHasVehicleUI = function() return vehicle end
env.CanExitVehicle = function() return vehicle end
env._game.forms[1] = { texture = 132089, spellID = 7001 }
K.Options.Write("Rest", "enabled", false)
AB.Enable(env, K)
local leave, bar = ns.leaveButton, ns.bars.bar1

local function FullOpacity(reason)
	assert(leave:IsShown() and leave:IsVisible() and leave:GetAlpha() == 1 and leave:GetEffectiveAlpha() == 1,
		reason .. ": keep the vehicle leave button visible at full opacity independently of bar 1")
end

env.SetCombat(true)
env._blocked = {}
local applies = 0
for _, entry in pairs(ns.bars) do
	local apply = entry.Apply
	entry.Apply = function(self, ...)
		applies = applies + 1
		return apply(self, ...)
	end
end
env.FireEvent("UPDATE_BONUS_ACTIONBAR")
env.FireEvent("UPDATE_SHAPESHIFT_FORMS")
assert(K.Combat.Pending() == 0, "stance changes outside a vehicle must not queue an ApplyAll")
vehicle = true
env.FireEvent("UNIT_ENTERED_VEHICLE", "player")
assert(leave:IsShown(), "boarding in combat shows the leave button immediately")
vehicle = false
env.FireEvent("UNIT_EXITED_VEHICLE", "player")
assert(not leave:IsShown(), "leaving in combat hides the leave button immediately")
assert(#env._blocked == 0, "the plain leave button updates without protected calls")
env.SetCombat(false)
env.RunTimers()
assert(applies == 0, "a stance change in combat must not apply any bars at regen")

vehicle = true
env.FireEvent("UNIT_ENTERED_VEHICLE", "player")
assert(ns.Config("bar1").fadeAlpha == 0, "exercise the default faded opacity of zero")
K.Options.Write("ActionBars", "bar1.fade", true)
AB.W.Settle(env)
assert(bar.header:GetAlpha() == 0, "bar 1 actually faded to zero")
FullOpacity("bar 1 faded to zero")
AB.W.Enter(leave)
AB.W.Settle(env)
FullOpacity("hovering the leave button")
AB.W.Leave(leave)
bar.holder:SetAlpha(0)
FullOpacity("bar 1 Layout opacity is zero")
bar.holder:Hide()
FullOpacity("bar 1 is hidden after fading to zero")
vehicle = false
env.FireEvent("UNIT_EXITED_VEHICLE", "player")
vehicle = true
env.FireEvent("UNIT_ENTERED_VEHICLE", "player")
FullOpacity("boarding while bar 1 is hidden")
bar.holder:Show()
bar.holder:SetAlpha(1)
K.Options.Write("ActionBars", "bar1.fade", false)
AB.W.Settle(env)
assert(bar.holder:GetAlpha() == 1, "reset Layout opacity before testing the mouseover rule")
assert(K.Layout.Set("actionbars.bar1", "shown", "mouseover"))
env.RunTimers()
AB.W.Settle(env)
assert(bar.holder:GetAlpha() == 0, "exercise Layout's mouseover-only bar at rest")
FullOpacity("bar 1 is mouseover-only")
vehicle = false
env.FireEvent("UNIT_EXITED_VEHICLE", "player")
env.SetCombat(true)
vehicle = true
env.FireEvent("UNIT_ENTERED_VEHICLE", "player")
FullOpacity("boarding in combat with a mouseover-only bar")
env.SetCombat(false)
assert(K.Layout.Set("actionbars.bar1", "shown", "always"))
env.RunTimers()
AB.W.Settle(env)

assert(K.Layout.Set("actionbars.bar1", "scale", 1.3))
env.RunTimers()
assert(math.abs(leave:GetScale() - 1.3) < 1e-6, "Layout changes refresh the independent leave button's scale")
assert(K.Layout.Set("actionbars.bar1", "scale", 1))
env.RunTimers()
env._game.forms = {}
env.FireEvent("UPDATE_SHAPESHIFT_FORMS")
local right = ns.bars.bar2.holder
assert(select(2, leave:GetPoint()) == right, "without forms the leave button stands beside the slab's right end")
local _, _, _, gap = leave:GetPoint()
assert(math.abs(gap - K.Widgets.Snap(leave, ns.Slab.Spec().pad + K.Tokens.Size("gapMedium"))) < 1e-6, "the leave button clears the slab's padding")
env._game.forms[1] = { texture = 132089, spellID = 7001 }
env.FireEvent("UPDATE_SHAPESHIFT_FORMS")
assert(select(2, leave:GetPoint()) == right, "new forms keep the leave button beside the slab")
K.Options.Write("HudStyle", "style", "frames")
env._game.forms = {}
env.FireEvent("UPDATE_SHAPESHIFT_FORMS")
assert(select(2, leave:GetPoint()) == ns.bars.bar1.holder, "under Frames without forms the leave button stands beside bar 1")
local card = ns.Tray.card
assert(card and card:IsShown(), "exercise the actual Frames tray card")
assert(leave:GetLeft() * leave:GetEffectiveScale() > card:GetRight() * card:GetEffectiveScale(), "the leave button clears the Frames tray padding")
env._game.forms[1] = { texture = 132089, spellID = 7001 }
env.FireEvent("UPDATE_SHAPESHIFT_FORMS")
assert(select(2, leave:GetPoint()) == ns.bars.stance.holder, "new forms move the leave button beyond the stance bar")
assert(#env._errors == 0, AB.Errors(env))

local lateEnv, lateK, late = AB.New({ saved = { version = 2, profiles = { Default = { ActionBars = { bar1 = { enabled = false } } } } } })
lateEnv.CanExitVehicle = function() return true end
AB.Enable(lateEnv, lateK)
assert(not late.bars.bar1 and late.leaveButton:IsShown(), "a disabled bar 1 does not hide the vehicle leave control")
lateK.Options.Write("ActionBars", "bar1.enabled", true)
late.bars.bar1.holder:SetAlpha(0)
assert(late.leaveButton:GetEffectiveAlpha() == 1, "bar 1 enabled later must not fade the vehicle leave control")
local Budget = dofile("Tools/regression/path_budget.lua")
for _, shown in ipairs({ false, true }) do
	vehicle = shown
	ns.Vehicle.Update()
	Budget.Check(Budget.Count(env, ns.Vehicle.Update, 1), 400, 4, "an unchanged leave button is not redressed on every vehicle event")
end
print("vehicle combat, opacity, visibility, scale and forms passed")
