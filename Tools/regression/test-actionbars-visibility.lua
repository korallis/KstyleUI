-- test-actionbars-visibility.lua: the macro builder, secure toggle gates, mouse passthrough and slot-preserving reversal.
local AB = dofile("Tools/regression/actionbars_env.lua")
local env, K, ns = AB.New({ setup = function(e)
	for i = 1, 180 do e._game.slots[i] = { texture = 132355, type = "spell", id = 100 + i } end
	e._game.bindings.ACTIONBUTTON1 = { "1" }
	e._game.bindings.ACTIONBUTTON12 = { "=" }
	e._game.bindings["CLICK KstyleUI_Toggle_bar1:LeftButton"] = { "F9" }
	e._game.bindings["CLICK KstyleUI_Toggle_pet:LeftButton"] = { "F10" }
	e._game.petExists = true
end })
AB.Enable(env, K)
local declarations = assert(io.open("KstyleUI_ActionBars/Bindings.xml", "rb"))
local bindingXML = declarations:read("*a")
declarations:close()
local bindings = 0
for command, category in bindingXML:gmatch('<Binding name="([^"]+)" category="([^"]+)"') do
	assert(env["BINDING_NAME_" .. command], "each declared toggle has a localized binding label")
	assert(env[category] == "KstyleUI", "Blizzard's keybinding UI resolves the KstyleUI category")
	bindings = bindings + 1
end
assert(bindings == 9, "every picker bar has a declared toggle key")
local cfg, bar = ns.Config("bar1"), ns.bars.bar1
local function Write(key, value) K.Options.Write("ActionBars", "bar1." .. key, value) end
local function Check()
	assert(#env._blocked == 0, table.concat(env._blocked, "\n"))
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

for _, mode in ipairs({ "show", "hide" }) do
	for _, condition in ipairs(ns.VISIBILITY_CONDITIONS) do
		local builder = ns.VisibilityDefaults()
		builder.mode, builder[condition[1]] = mode, true
		local macro = "[" .. condition[2] .. "] " .. mode .. "; " .. (mode == "show" and "hide" or "show")
		assert(ns.VisibilityMacro(builder) == macro)
		assert(ns.VisibilityMacro(assert(ns.ParseVisibility(macro))) == macro, "each condition round-trips")
	end
end
assert(ns.VisibilityMacro(ns.ParseVisibility("")) == "")
for _, macro in ipairs({ "[combat,mod:shift] show; hide", "[unknown] hide; show", "[combat] show; show", "show", "[combat]junk[mod:alt] hide; show" }) do
	assert(ns.ParseVisibility(macro) == nil, "advanced or malformed macros remain in the text editor")
end
Write("visibilityBuilder.mode", "hide")
Write("visibilityBuilder.combat", true)
Write("visibilityBuilder.target", true)
assert(cfg.visibility == "[combat][@target,exists] hide; show", "builder writes the existing macro, including mode selected before a tick")
Write("visibility", "[mounted][group][mod:alt] show; hide")
assert(cfg.visibilityBuilder.mounted and cfg.visibilityBuilder.group and cfg.visibilityBuilder.alt and not cfg.visibilityBuilder.combat)
Write("visibility", "[combat,mod:shift] show; hide")
assert(K.Options.Row("ActionBars", "bar1.visibilityBuilder.combat").disableWhen(K.Store.Module("ActionBars")), "advanced text is never silently replaced")
Write("visibility", "")

assert(AB.PressKey(env, "F9") and not bar.gate:IsShown(), "key hides bar out of combat")
local character = K.Store.CharacterKey()
assert(K.Store.Account().actionBarToggles[character].bar1, "the secure attribute hook persists the character's toggle")
env._combat = true
assert(AB.PressKey(env, "F9") and bar.gate:IsShown(), "key shows bar in combat")
assert(AB.PressKey(env, "F9") and not bar.gate:IsShown(), "key hides bar in combat")
Write("visibility", "[combat] show; hide")
Write("clickThrough", true)
Write("reverse", true)
assert(env.Driver(bar.header, "visibility") == "show" and bar.buttons[1]:IsMouseEnabled(), "protected settings wait in combat")
env._combat = false
env.FireEvent("PLAYER_REGEN_ENABLED")
assert(env.Driver(bar.header, "visibility") == "[combat] show; hide")
assert(not bar.gate:IsShown(), "settings do not reset the toggle")
assert(K.Layout.Enter())
local x = K.Layout.Get("actionbars.bar1").x
K.Layout.Set("actionbars.bar1", "x", x + 20)
assert(K.Layout.Get("actionbars.bar1").x == x + 20, "a mouse-passthrough bar can still move through its layout holder")
assert(not bar.gate:IsShown(), "Layout Mode retains the toggle")
env._combat = true
env.FireEvent("PLAYER_REGEN_DISABLED")
assert(not bar.gate:IsShown(), "entering combat during Layout Mode preserves hidden state")
env._combat = false
env.FireEvent("PLAYER_REGEN_ENABLED")
K.Layout.Exit()
assert(not bar.gate:IsShown(), "leaving Layout Mode retains the toggle")
AB.PressKey(env, "F9")
Write("visibility", "")
for _, b in ipairs(bar.buttons) do assert(not b:IsMouseEnabled(), "click-through removes the mouse hit") end
assert(bar.buttons[1]:GetLeft() > bar.buttons[12]:GetLeft(), "reverse places slot 1 at the other end")
AB.PressKey(env, "1")
assert(AB.Used(env) == 1, "click-through and reversal retain slot 1's key")
AB.PressKey(env, "=")
assert(AB.Used(env) == 12, "slot 12 keeps its key")
Write("paging", "[mod:alt] 2; 1")
env._combat, env._game.mod = true, "alt"
env.RunStateDrivers()
AB.PressKey(env, "1")
assert(AB.Used(env) == 13, "paging still maps button 1 to page 2's first action")
AB.PressKey(env, "=")
assert(AB.Used(env) == 24, "paging still maps button 12 to page 2's last action")
env._combat, env._game.mod = false, nil
env.RunStateDrivers()
Write("clickThrough", false)
assert(bar.buttons[1]:IsMouseEnabled(), "turning click-through off restores mouse interaction")
AB.W.Enter(bar.buttons[1])
assert(bar.hovered > 0, "hover still works with click-through off")
AB.W.Leave(bar.buttons[1])
assert(bar.hovered == 0)

K.Options.Write("HudStyle", "style", "medallions")
assert(not K.Options.Row("ActionBars", "bar1.reverse").showWhen(K.Store.Module("ActionBars")), "the slab hides fixed order controls")
assert(bar.buttons[1]:GetLeft() < bar.buttons[12]:GetLeft(), "the connected slab fixes button order")
env._combat = true
AB.PressKey(env, "F9")
AB.PressKey(env, "F9")
env._combat = false
Check()
K.Options.Write("ActionBars", "slab", false)
assert(bar.buttons[1]:GetLeft() > bar.buttons[12]:GetLeft(), "freeing the slab restores the saved reversal")

local pet = ns.bars.pet
AB.PressKey(env, "F10")
env._game.petExists = false
env.RunStateDrivers()
AB.PressKey(env, "F10")
assert(not pet.header:IsShown(), "the toggle cannot override an absent pet")
AB.PressKey(env, "F9")
K.Modules.Disable("ActionBars")
K.Modules.Enable("ActionBars")
assert(not bar.gate:IsShown(), "disable and enable retain the character toggle")
AB.CoreEnv.Logout(env)
local saved = env.KstyleUIDB
local reloaded, _, reloadedBars = AB.New({ saved = saved })
assert(not reloadedBars.bars.bar1.gate:IsShown(), "the character toggle survives a reload")
local _, _, otherBars = AB.New({ saved = saved, setup = function(e) e.UnitName = function() return "Other" end end })
assert(otherBars.bars.bar1.gate:IsShown(), "another character using the same profile starts visible")
assert(#reloaded._errors == 0)
K.Modules.Disable("ActionBars")
Write("visibility", "")
Write("visibilityBuilder.group", true)
assert(cfg.visibility == "[group] show; hide", "the builder edits macros while the module is disabled")
cfg.visibility = "[mounted] hide; show"
K.Callbacks.Fire("ProfileChanged")
assert(cfg.visibilityBuilder.mounted and cfg.visibilityBuilder.mode == "hide", "profile changes rebuild ticks even while the module is disabled")
Check()
print("actionbars visibility ok: macro round-trips, secure combat keys, character persistence, mouse passthrough and slot-preserving reversal")
