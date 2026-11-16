local AB = dofile("Tools/regression/actionbars_env.lua")
local env, K, ns = AB.New({ class = "WARRIOR" })
local vehicle = false
env.UnitHasVehicleUI = function() return vehicle end
env.CanExitVehicle = function() return vehicle end
env._game.forms[1] = { texture = 132089, spellID = 7001 }
AB.Enable(env, K)
local leave, bar = ns.leaveButton, ns.bars.bar1

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
K.Options.Write("ActionBars", "bar1.fadeAlpha", 0.35)
K.Options.Write("ActionBars", "bar1.fade", true)
AB.W.Settle(env)
bar.holder:SetAlpha(0.4)
assert(math.abs(leave:GetAlpha() - 0.14) < 1e-6, "the leave button follows Layout opacity and action-bar fade")
AB.W.Enter(bar.buttons[1])
AB.W.Settle(env)
assert(math.abs(leave:GetAlpha() - 0.4) < 1e-6, "the leave button follows the bar's hover fade immediately")
bar.holder:SetAlpha(env.Secret(0.4))
assert(math.abs(leave:GetAlpha() - 0.4) < 1e-6, "a restricted alpha keeps the last readable opacity")
bar.holder:SetAlpha(0.4)
bar.holder:Hide()
assert(leave:IsVisible(), "a vehicle leave control stays visible when bar 1 is hidden")
vehicle = false
env.FireEvent("UNIT_EXITED_VEHICLE", "player")
vehicle = true
env.FireEvent("UNIT_ENTERED_VEHICLE", "player")
assert(leave:IsVisible(), "boarding while bar 1 is hidden still shows the leave control")
bar.holder:Show()
K.Options.Write("ActionBars", "bar1.fade", false)
AB.W.Settle(env)

assert(K.Layout.Set("actionbars.bar1", "scale", 1.3))
env.RunTimers()
assert(math.abs(leave:GetScale() - 1.3) < 1e-6, "Layout changes refresh the independent leave button's scale")
assert(K.Layout.Set("actionbars.bar1", "scale", 1))
env.RunTimers()
env._game.forms = {}
env.FireEvent("UPDATE_SHAPESHIFT_FORMS")
assert(select(2, leave:GetPoint()) == bar.holder, "removing the forms returns the leave button beside bar 1")
local _, _, _, gap = leave:GetPoint()
local card = ns.Tray.card
assert(card and card:IsShown(), "exercise the actual Frames tray card")
local scale = leave:GetEffectiveScale()
assert(leave:GetLeft() * scale > card:GetRight() * card:GetEffectiveScale(), "the leave button clears the Frames tray padding")
assert(gap > K.Tokens.Size("gapMedium"), "the tray reserves padding outside its action slots")
env._game.forms[1] = { texture = 132089, spellID = 7001 }
env.FireEvent("UPDATE_SHAPESHIFT_FORMS")
assert(select(2, leave:GetPoint()) == ns.bars.stance.holder, "new forms move the leave button beyond the stance bar")
assert(#env._errors == 0, AB.Errors(env))
print("vehicle combat, opacity, visibility, scale and forms passed")
