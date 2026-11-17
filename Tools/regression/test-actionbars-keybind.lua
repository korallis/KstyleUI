-- test-actionbars-keybind.lua: stance toggles through Blizzard's secure click and hover binding transactions use persistent game commands.
local AB = dofile("Tools/regression/actionbars_env.lua")

local env, K, ns = AB.New({ class = "ROGUE", setup = function(e)
	e._game.forms = { { texture = 132320, spellID = 1784, isActive = true } }
	e._game.bindings.SHAPESHIFTBUTTON1 = { "F1" }
end })
AB.Enable(env, K)
local stance = ns.bars.stance.buttons[1]
AB.Click(env, stance, "LeftButton", true)
assert(not env._game.forms[1].isActive, "clicking the active stealth stance must cancel it through Blizzard's form selector")
assert(AB.PressKey(env, "F1"), "Blizzard's SHAPESHIFTBUTTON1 binding must reach the visible stance")
assert(env._game.forms[1].isActive, "the mapped stance key must toggle stealth back on")
env.SetCombat(true)
AB.Click(env, stance, "LeftButton", true)
assert(not env._game.forms[1].isActive, "stance clicks must work in combat without setting protected attributes")
assert(#env._blocked == 0, table.concat(env._blocked, ", "))
env.SetCombat(false)
print("stance click and Blizzard binding mapping ok")

assert(ns.Keybind, "provide the hover keybinding controller")
assert(ns.Keybind.Enter())
local possess = ns.Keybind.overlays[env.PossessButton2]
assert(possess, "hover binding must include Blizzard's possess cancel button")
possess:GetScript("OnEnter")(possess)
ns.Keybind.panel:GetScript("OnKeyDown")(ns.Keybind.panel, "F2")
ns.Keybind.Save()
env._game.possess = true
assert(AB.PressKey(env, "F2") and not env._game.possess, "a persistent possess binding must click Blizzard's cancel button")
assert(env.GetBindingAction("F2") == "CLICK PossessButton2:LeftButton", "Forever has no POSSESSBUTTON binding: retain the native click command")
K.Modules.Disable("ActionBars")
env._game.possess = true
assert(AB.PressKey(env, "F2") and not env._game.possess, "possess bindings must survive disabling KstyleUI")
assert(#env._errors == 0, AB.Errors(env))
print("possess native click and persistent binding ok")
