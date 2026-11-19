-- test-actionbars-keybind.lua: stance toggles through Blizzard's secure click and hover binding transactions use persistent game commands.
local AB = dofile("Tools/regression/actionbars_env.lua")

local env, K, ns = AB.New({ class = "ROGUE", setup = function(e)
	e._game.forms = { { texture = 132320, spellID = 1784, isActive = true } }
	e._game.bindings.SHAPESHIFTBUTTON1 = { "F1" }
end })
AB.Enable(env, K)
local stance = ns.bars.stance.buttons[1]
AB.Click(env, stance, "LeftButton", true)
AB.Click(env, stance, "LeftButton", false)
assert(not env._game.forms[1].isActive, "clicking the active stealth stance must cancel it through Blizzard's form selector")
assert(AB.PressKey(env, "F1"), "Blizzard's SHAPESHIFTBUTTON1 binding must reach the visible stance")
assert(env._game.forms[1].isActive, "the mapped stance key must toggle stealth back on")
env.SetCombat(true)
AB.Click(env, stance, "LeftButton", true)
AB.Click(env, stance, "LeftButton", false)
assert(not env._game.forms[1].isActive, "stance clicks must work in combat without setting protected attributes")
assert(#env._blocked == 0, table.concat(env._blocked, ", "))
env.SetCombat(false)
print("stance click and Blizzard binding mapping ok")

assert(ns.Keybind, "provide the hover keybinding controller")
assert(ns.Keybind.Enter())
local stanceOverlay = ns.Keybind.overlays[stance]
stanceOverlay:GetScript("OnEnter")(stanceOverlay)
ns.Keybind.panel:GetScript("OnKeyDown")(ns.Keybind.panel, "F3")
ns.Keybind.Save()
assert(env.GetBindingAction("F3") == "SHAPESHIFTBUTTON1" and AB.PressKey(env, "F3") and env._game.forms[1].isActive,
	"hover binding a stance must use the native form command and preserve its toggle")
env.PossessActionBar:Show()
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

do
	local e, core, bars = AB.New({ setup = function(game)
		game._game.bindings.ACTIONBUTTON1 = { "1", "NUMPAD1" }
		game._game.bindings.JUMP = { "SPACE" }
		game._game.petExists = true
		game._game.pet[1] = { name = "Attack", texture = 132152 }
	end })
	AB.Enable(e, core)
	local mode = bars.Keybind
	local function hover(button)
		local overlay = assert(mode.overlays[button], "the hovered button must have a binding overlay")
		overlay:GetScript("OnEnter")(overlay)
		return overlay
	end
	local function input(key) mode.panel:GetScript("OnKeyDown")(mode.panel, key) end
	e.SlashCmdList.KSTYLE("kb")
	assert(mode.active and mode.panel:IsShown(), "/kstyle kb enters hover mode")
	local first = hover(bars.bars.bar1.buttons[1])
	assert(first:IsShown(), "the hovered button has a highlight overlay")
	assert(mode.panel.current:GetText():find("NUMPAD1", 1, true), "the panel identifies the hovered button and its keys")
	e._game.shift, e._game.ctrl, e._game.alt = true, true, true
	input("LSHIFT")
	input("F5")
	assert(mode.pending["ALT-CTRL-SHIFT-F5"] == "ACTIONBUTTON1", "modifier keys compose a canonical binding and never bind alone")
	e._game.shift, e._game.ctrl, e._game.alt = false, false, false
	first:GetScript("OnMouseDown")(first, "LeftButton")
	assert(mode.pending.BUTTON1 == nil, "left click preserves the camera binding without firing the underlying action")
	first:GetScript("OnMouseDown")(first, "RightButton")
	first:GetScript("OnMouseDown")(first, "Button6")
	first:GetScript("OnMouseWheel")(first, -1)
	assert(not mode.pending.BUTTON2 and mode.pending.BUTTON6 and mode.pending.MOUSEWHEELDOWN, "ignore camera mouse buttons; extra buttons and wheel bind")
	assert(AB.Used(e) == nil and e.GetBindingAction("ALT-CTRL-SHIFT-F5") == "", "mode stages changes without activating actions or changing game bindings")
	input("ESCAPE")
	assert(mode.pending["1"] == false and mode.pending.NUMPAD1 == false and mode.pending.BUTTON1 == nil, "Escape clears bindings without touching camera buttons")
	input("SPACE")
	local second = hover(bars.bars.bar1.buttons[2])
	input("SPACE")
	assert(mode.pending.SPACE == "ACTIONBUTTON2", "a key can be reassigned between buttons")
	mode.panel.character:SetValue(true)
	mode.panel.save:GetScript("OnClick")(mode.panel.save, "LeftButton")
	assert(not mode.active and not mode.panel:IsShown(), "Save leaves binding mode")
	assert(e.GetBindingAction("1") == "" and e.GetBindingAction("NUMPAD1") == "", "Save removes cleared bindings")
	assert(e.GetBindingAction("SPACE") == "ACTIONBUTTON2" and e._game.savedSet == 2, "Save writes the Blizzard command to character bindings")
	assert(AB.PressKey(e, "SPACE") and AB.Used(e) == 2, "saved bindings are mirrored to the visible action button")
	assert(not second:IsShown(), "binding overlays close with the panel")
	e.SlashCmdList.KSTYLE("keybind")
	hover(bars.bars.pet.buttons[1])
	input("F9")
	mode.panel.discard:GetScript("OnClick")(mode.panel.discard, "LeftButton")
	assert(e.GetBindingAction("F9") == "" and not mode.active, "Discard preserves the game's bindings")
	assert(mode.Enter())
	hover(bars.bars.pet.buttons[1])
	input("F9")
	mode.panel.character:SetValue(false)
	mode.Save()
	AB.W.Click(core.Widgets.DialogHost().visibleButtons[2])
	assert(e.GetBindingAction("F9") == "BONUSACTIONBUTTON1" and e._game.savedSet == 1, "pet commands save to account bindings")
	e.SetCombat(true)
	assert(not mode.Enter() and not mode.active, "entering mode is refused during combat")
	e.SetCombat(false)
	assert(mode.Enter())
	hover(bars.bars.bar1.buttons[1])
	input("F10")
	e.SetCombat(true)
	assert(not mode.active and not mode.panel:IsShown() and not first:IsShown(), "combat entry immediately closes the panel and overlays")
	assert(e.GetBindingAction("F10") == "", "combat drops unsaved changes without writing protected bindings")
	mode.Save()
	mode.Input("F11")
	assert(#e._blocked == 0, table.concat(e._blocked, ", "))
	e.SetCombat(false)
	assert(mode.Enter())
	hover(bars.bars.bar1.buttons[1])
	input("F12")
	e._combat = true
	mode.Input("G")
	assert(not mode.active and e.GetBindingAction("F12") == "", "input also refuses changes before the combat event arrives")
	e._combat = false
	assert(mode.Enter())
	hover(bars.bars.bar1.buttons[1])
	input("F8")
	e._game.failBinding = "F8"
	mode.Save()
	assert(mode.active and e.GetBindingAction("F8") == "", "a rejected binding stays reviewable without saving")
	e._game.failBinding = nil
	mode.Exit()
	assert(mode.Enter())
	hover(bars.bars.bar1.buttons[1])
	input("F7")
	input("F8")
	local setBinding, calls = e.SetBinding, 0
	e.SetBinding = function(...)
		calls = calls + 1
		if calls == 2 then return false end
		return setBinding(...)
	end
	mode.Save()
	assert(e.GetBindingAction("F7") == "" and e.GetBindingAction("F8") == "", "a partially rejected Save restores every earlier edit")
	e.SetBinding = setBinding
	mode.Exit()
	assert(mode.Enter())
	hover(bars.bars.bar1.buttons[1])
	input("F7")
	e.SaveBindings = function() return false end
	mode.Save()
	assert(mode.active and e.GetBindingAction("F7") == "", "a disk save failure restores the live binding set")
	mode.Exit()
	assert(#e._errors == 0, AB.Errors(e))
	assert(e.SLASH_KSTYLEKB1 == "/kb" and e.SLASH_KSTYLEKB2 == "/bb", "register the standalone aliases")
end

do
	local e, core, bars = AB.New({ setup = function(game)
		game.SLASH_OTHER1 = "/bb"
		game.ExtraActionButton1 = game.CreateFrame("Button", "ExtraActionButton1", game.UIParent)
		game.CanExitVehicle = function() return true end
	end })
	AB.Enable(e, core)
	assert(e.SLASH_KSTYLEKB2 == nil, "never claim another loaded addon's /bb")
	assert(bars.Keybind.Enter())
	local extra = bars.Keybind.overlays[e.ExtraActionButton1]
	assert(extra and extra.command == "EXTRAACTIONBUTTON1", "support an extra button when the client supplies it")
	assert(bars.Keybind.overlays[bars.leaveButton].command == "VEHICLEEXIT", "the leave vehicle slot uses Blizzard's vehicle binding")
	bars.Keybind.Exit()
	e.ActionButtonUtil = { IsExtraActionButtonDisabled = function() return true end }
	assert(bars.Keybind.Enter())
	assert(not extra:IsShown(), "Forever's disabled extra button has no bindable placeholder")
	core.Modules.Disable("ActionBars")
	assert(not bars.Keybind.active, "disabling the module closes binding mode")
end
print("hover binding enter, hover, modifiers, mouse, clear, save, discard and combat guards ok")
