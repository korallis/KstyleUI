-- test-actionbars.lua: KstyleUI_ActionBars builds its secure bars on Enable, pages bar 1, mirrors keybinds, hides Blizzard's bars and stays out of gamepad mode's way.
local AB = dofile("Tools/regression/actionbars_env.lua")
local W = AB.W

local function near(a, b)
	return math.abs(a - b) < 1e-6
end

local function logged(env, text)
	for _, entry in ipairs(env.KstyleUIDB.devlog) do
		if tostring(entry.message):find(text, 1, true) then
			return true
		end
	end
	return false
end

-- Off by default: the module registers, builds nothing and binds nothing until it is switched on.
do
	local env, K, ns = AB.New()
	assert(K.Modules.IsEnabled("ActionBars") == false, "the module is off in code")
	assert(ns.bars == nil or next(ns.bars) == nil, "no bars while off")
	assert(next(env._game.overrides) == nil, "no override bindings while off")
	assert(K.Options.Get("ActionBars"), "the settings schema is registered")
	assert(type(K.Options.Preview("ActionBars")) == "function", "the settings window gets a live preview")
	assert(#env._errors == 0, AB.Errors(env))
end

-- Enable builds bars 1 and 2 and the pet and stance bars, each a scalable Layout element at the v3 position.
do
	local env, K, ns = AB.New()
	AB.Enable(env, K)
	assert(K.Modules.IsRunning("ActionBars"), "Enable ran: " .. AB.Errors(env))
	for _, key in ipairs({ "bar1", "bar2", "pet", "stance" }) do
		assert(ns.bars[key], key .. " is built")
	end
	for _, key in ipairs({ "bar3", "bar4", "bar5", "bar6" }) do
		assert(ns.bars[key] == nil, key .. " is off by default and costs nothing")
	end
	local found = {}
	for _, element in ipairs(K.Layout.Elements()) do
		found[element.key] = element
	end
	for _, key in ipairs({ "actionbars.bar1", "actionbars.bar2", "actionbars.pet", "actionbars.stance" }) do
		local element = found[key]
		assert(element, key .. " registered with Layout")
		assert(element.module == "ActionBars" and element.opts.scalable == true, key .. " is a scalable ActionBars element")
		assert(element.label == K.Setup.Layouts.Element(key).label, key .. " uses the setup's label")
		local settings = K.Layout.Get(key)
		local default = K.Setup.Layouts.Default(key)
		assert(settings.anchor == default.anchor and settings.x == default.x and settings.y == default.y, key .. " starts at the v3 position")
	end
	local bar1 = ns.bars.bar1
	assert(near(bar1.holder:GetWidth(), 489) and near(bar1.holder:GetHeight(), 38), "bar 1 is 12 buttons of 38 with 3-unit gaps, as the mockup measures")
	local button = bar1.buttons[3]
	assert(near(button:GetWidth(), 38), "38-unit buttons")
	local point, relative, _, x, y = button:GetPoint(1)
	assert(point == "TOPLEFT" and relative == bar1.header and near(x, 82) and near(y, 0), "the third button sits two steps right")
	assert(button._template == "SecureActionButtonTemplate", "buttons are KstyleUI's own secure action buttons")
	assert(button:GetName() == "KstyleUI_ActionBar1Button3")
	assert(button:GetAttribute("type") == "action" and button:GetAttribute("useparent-actionpage") == true and button:GetID() == 3)
	assert(bar1.header:GetAttribute("actionpage") == 1 and ns.bars.bar2.header:GetAttribute("actionpage") == 6, "bar 2 shows page 6")
	assert(near(ns.bars.pet.holder:GetWidth(), 327) and near(ns.bars.pet.holder:GetHeight(), 30), "the pet bar's 327 by 30 footprint")
	assert(#env._blocked == 0 and #env._errors == 0, AB.Errors(env))
end

-- Blizzard's main, multi, pet and stance bars are reparented to a hidden frame through Safe, deferred a frame.
do
	local env, K = AB.New()
	K.Modules.Enable("ActionBars")
	assert(not K.Safe.IsHidden(env.MainActionBar), "hiding waits a frame")
	env.RunTimers()
	for _, name in ipairs({ "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft", "MultiBar5", "MultiBar6", "MultiBar7", "StanceBar", "PetActionBar" }) do
		assert(K.Safe.IsHidden(env[name]), name .. " is hidden")
	end
	K.Modules.Disable("ActionBars")
	env.RunTimers()
	assert(not K.Safe.IsHidden(env.MainActionBar) and env.MainActionBar:GetParent() == env.UIParent, "turning the module off restores Blizzard's bars")
	assert(next(env._game.overrides) == nil, "and clears the override bindings")
	assert(#env._errors == 0, AB.Errors(env))
end

-- Keybinds mirror Blizzard's binding names: every key the player bound clicks KstyleUI's button instead.
do
	local env, K, ns = AB.New({
		setup = function(e)
			e._game.bindings.ACTIONBUTTON1 = { "1", "SHIFT-Q" }
			e._game.bindings.MULTIACTIONBAR1BUTTON2 = { "CTRL-2" }
			e._game.bindings.ACTIONBUTTON2 = { "BUTTON4" }
		end,
	})
	AB.Slot(env, 1, { texture = 135489, type = "spell", id = 100 })
	AB.Enable(env, K)
	assert(AB.PressKey(env, "1") and AB.Used(env) == 1, "key 1 uses slot 1")
	assert(AB.PressKey(env, "SHIFT-Q") and AB.Used(env) == 1, "a second key for the same binding works too")
	assert(AB.PressKey(env, "CTRL-2") and AB.Used(env) == 62, "bar 2's second button uses slot 62")
	local b1 = AB.Button(ns, "bar1", 1)
	assert(b1.hotkey:GetText() == "1", "the first key is the hotkey text")
	assert(AB.Button(ns, "bar1", 2).hotkey:GetText() == "M4", "mouse buttons are shortened")
	env._game.bindings.ACTIONBUTTON1 = { "F" }
	env.SetCombat(true)
	env.FireEvent("UPDATE_BINDINGS")
	assert(#env._blocked == 0, "a binding change in combat waits: " .. table.concat(env._blocked, ", "))
	assert(AB.PressKey(env, "1"), "the old key still works until combat ends")
	env.SetCombat(false)
	assert(AB.PressKey(env, "F") and not AB.PressKey(env, "1"), "after combat the new key replaces the old one")
	assert(b1.hotkey:GetText() == "F")
	assert(#env._errors == 0, AB.Errors(env))
end

-- Paging: stance, form, stealth and possess bonus bars swap bar 1 through a secure state driver, in combat too.
do
	local env, K, ns = AB.New({
		class = "WARRIOR",
		setup = function(e)
			e._game.bindings.ACTIONBUTTON1 = { "1" }
		end,
	})
	AB.Slot(env, 73, { texture = 132355, type = "spell", id = 2457 })
	AB.Enable(env, K)
	local header = ns.bars.bar1.header
	assert(env.Driver(header, "page"):find("[bonusbar:1] 7", 1, true), "bar 1 has a paging driver")
	assert(env.Driver(ns.bars.bar2.header, "page") == nil, "bar 2 does not page")
	local b1 = AB.Button(ns, "bar1", 1)
	assert(b1.slot == 1)
	env.SetCombat(true)
	env._game.bonusbar, env._game.bonus = 1, 7
	env.RunStateDrivers()
	assert(header:GetAttribute("actionpage") == 7, "battle stance shows page 7")
	assert(b1.slot == 73, "the button follows the page")
	assert(W.LastCall(b1.icon, "SetTexture")[1] == 132355, "and shows the paged action's icon")
	assert(AB.PressKey(env, "1") and AB.Used(env) == 73, "the key casts what the button shows")
	env._game.bonusbar, env._game.bonus = nil, nil
	env._game.possess = true
	env._game.bonus = 11
	env.RunStateDrivers()
	assert(header:GetAttribute("actionpage") == 11, "a possess shows the possess page")
	env._game.possess, env._game.bonus = false, nil
	env.RunStateDrivers()
	assert(header:GetAttribute("actionpage") == 1 and b1.slot == 1, "back to page 1")
	assert(#env._blocked == 0, "paging in combat makes no protected call: " .. table.concat(env._blocked, ", "))
	env.SetCombat(false)
	assert(#env._errors == 0, AB.Errors(env))
end

-- Paging rules are settings: switching stance paging off rebuilds the driver out of combat; bad custom conditions fall back.
do
	local env, K, ns = AB.New({ class = "ROGUE" })
	AB.Enable(env, K)
	local header = ns.bars.bar1.header
	assert(env.Driver(header, "page"):find("[bonusbar:1] 7", 1, true), "a rogue's stealth pages bar 1")
	env.SetCombat(true)
	K.Options.Write("ActionBars", "bar1.pageStealth", false)
	assert(#env._blocked == 0, "a paging change in combat waits")
	env.SetCombat(false)
	assert(not env.Driver(header, "page"):find("bonusbar:1", 1, true), "stealth paging is off after combat")
	K.Options.Write("ActionBars", "bar1.paging", "[mod:alt] 2; 1")
	assert(env.Driver(header, "page") == "[mod:alt] 2; 1", "custom conditions replace the rules")
	env._game.mod = "alt"
	env.RunStateDrivers()
	assert(header:GetAttribute("actionpage") == 2)
	K.Options.Write("ActionBars", "bar1.paging", "[bogus 2; 1")
	assert(env.Driver(header, "page") ~= "[bogus 2; 1", "conditions the game cannot parse are not used")
	assert(logged(env, "paging conditions"), "and the fallback is logged")
	K.Options.Write("ActionBars", "bar2.paging", "[mod:alt] 4; 6")
	assert(env.Driver(ns.bars.bar2.header, "page") == "[mod:alt] 4; 6", "any bar can take custom paging")
	assert(#env._errors == 0, AB.Errors(env))
end

-- The v3 mockup drew a dark glass strip behind each action bar row, 3 units beyond the buttons with 6-unit
-- chamfers. Lumen's sockets float with no strip, so every bar starts without one; the toggle still draws it.
do
	local env, K, ns = AB.New()
	AB.Enable(env, K)
	local bar1, pet = ns.bars.bar1, ns.bars.pet
	local backing = bar1.backing
	assert(backing and not backing:IsShown(), "bar 1 has no strip by default: the Lumen sockets float")
	K.Options.Write("ActionBars", "bar1.backing", true)
	assert(backing:IsShown() and backing:GetParent() == bar1.header, "switched on, bar 1's strip sits on its header, so it fades with the bar")
	assert(backing.chrome and backing.chrome.fillName == "buttonFill" and near(backing.chrome:Chamfer(), 8), "the strip is the button body, its ends rounded by the shared rule: the tile radius, 8 units on a 40-unit strip")
	local p1, p2 = backing._points[1], backing._points[2]
	assert(p1[1] == "TOPLEFT" and p1[2] == bar1.header and near(p1[4], -3) and near(p1[5], 3), "the strip starts 3 units outside the buttons' top left, the mockup's 3 units above the buttons")
	assert(p2[1] == "BOTTOMRIGHT" and p2[2] == bar1.header and near(p2[4], 3) and near(p2[5], -3), "and ends 3 units outside their bottom right")
	assert(backing:GetFrameLevel() < bar1.buttons[1]:GetFrameLevel(), "the strip draws behind the buttons")
	assert(pet.backing and not pet.backing:IsShown(), "the pet bar has no strip by default")
	K.Options.Write("ActionBars", "bar1.backing", false)
	assert(not backing:IsShown(), "the toggle hides the strip")
	K.Options.Write("ActionBars", "pet.backing", true)
	assert(pet.backing:IsShown(), "and shows it on another bar")
	assert(K.Options.Row("ActionBars", "bar1.backing") and K.Options.Row("ActionBars", "bar1.backing").type == "toggle", "the strip is a per-bar toggle")
	assert(#env._errors == 0, AB.Errors(env))
end

-- Settings reshape a bar out of combat: buttons shown, rows, size and spacing; enabling bar 3 builds it.
do
	local env, K, ns = AB.New()
	AB.Enable(env, K)
	local bar1 = ns.bars.bar1
	env.SetCombat(true)
	K.Options.Write("ActionBars", "bar1.buttons", 6)
	assert(#env._blocked == 0, "a layout change in combat waits: " .. table.concat(env._blocked, ", "))
	env.SetCombat(false)
	assert(near(bar1.holder:GetWidth(), 6 * 38 + 5 * 3), "six buttons wide")
	assert(bar1.buttons[6]:IsShown() and not bar1.buttons[7]:IsShown(), "buttons past the count hide")
	K.Options.Write("ActionBars", "bar1.rows", 2)
	assert(near(bar1.holder:GetWidth(), 3 * 38 + 2 * 3) and near(bar1.holder:GetHeight(), 2 * 38 + 3), "two rows of three")
	K.Options.Write("ActionBars", "bar1.size", 40)
	K.Options.Write("ActionBars", "bar1.spacing", 6)
	assert(near(bar1.buttons[1]:GetWidth(), 40) and near(bar1.holder:GetWidth(), 3 * 40 + 2 * 6))
	K.Options.Write("ActionBars", "bar3.enabled", true)
	local bar3 = ns.bars.bar3
	assert(bar3 and near(bar3.holder:GetWidth(), 38) and near(bar3.holder:GetHeight(), 489), "bar 3 is a column of 12")
	assert(bar3.header:GetAttribute("actionpage") == 5)
	assert(K.Layout.Live("actionbars.bar3"), "a bar switched on has a mover in Layout Mode")
	K.Options.Write("ActionBars", "bar3.enabled", false)
	assert(env.Driver(bar3.header, "visibility") == "hide", "a bar switched off hides")
	assert(not K.Layout.Live("actionbars.bar3"), "and leaves Layout Mode and the Elements page")
	assert(#env._errors == 0, AB.Errors(env))
end

-- Gamepad mode (Review Focus 4): KstyleUI hides its bars and drops its bindings, waits for combat to end, and never touches the gamepad bars.
do
	local env, K, ns = AB.New({
		setup = function(e)
			e._game.bindings.ACTIONBUTTON1 = { "1" }
		end,
	})
	AB.Enable(env, K)
	assert(AB.PressKey(env, "1"))
	env.SetCombat(true)
	env._game.style = 1
	env.FireEvent("INPUT_DEVICE_INTERFACE_TRANSITION", 1, 0)
	assert(#env._blocked == 0, "a transition in combat makes no protected call: " .. table.concat(env._blocked, ", "))
	env.SetCombat(false)
	assert(not AB.PressKey(env, "1"), "gamepad mode drops KstyleUI's override bindings")
	for key, bar in pairs(ns.bars) do
		assert(env.Driver(bar.header, "visibility") == "hide", key .. " hides in gamepad mode")
	end
	assert(logged(env, "gamepad"), "the switch is logged")
	env._game.style = 0
	env.FireEvent("INPUT_DEVICE_INTERFACE_TRANSITION", 0, 1)
	assert(AB.PressKey(env, "1"), "keyboard mode brings the bindings back")
	assert(env.Driver(ns.bars.bar1.header, "visibility") == "show")
	assert(#env._errors == 0, AB.Errors(env))
end

do
	local env, K, ns = AB.New({
		setup = function(e)
			e._game.style = 1
			e._game.bindings.ACTIONBUTTON1 = { "1" }
		end,
	})
	AB.Enable(env, K)
	assert(not AB.PressKey(env, "1") and env.Driver(ns.bars.bar1.header, "visibility") == "hide", "starting in gamepad mode binds and shows nothing")
end

-- The module's code never names a frame or function of Blizzard_GamepadActionBars.
do
	local names = {}
	local pipe = assert(io.popen("grep -rhoE 'name=\"[A-Za-z_][A-Za-z0-9_]*\"|^function [A-Za-z_][A-Za-z0-9_]*|^[A-Za-z_][A-Za-z0-9_]* = ' ~/.local/share/wow-dev/wow-ui-source/Interface/AddOns/Blizzard_GamepadActionBars 2>/dev/null"))
	for line in pipe:lines() do
		local name = line:match('name="([%w_]+)"') or line:match("^function ([%w_]+)") or line:match("^([%w_]+) = ")
		if name and #name > 6 then
			names[name] = true
		end
	end
	pipe:close()
	local files = assert(io.popen("ls KstyleUI_ActionBars/*.lua"))
	for path in files:lines() do
		local handle = assert(io.open(path, "rb"))
		local text = handle:read("*a")
		handle:close()
		assert(not text:find("Gamepad[%w_]*ActionBar"), path .. " names a gamepad action bar")
		for word in text:gmatch("[%a_][%w_]*") do
			assert(not names[word], path .. " names " .. word .. " from Blizzard_GamepadActionBars")
		end
	end
	files:close()
end

-- A reload in combat: Enable at PLAYER_LOGIN builds the secure bars at once, the one time that is allowed.
do
	local env, K, ns = AB.New({
		combatAtLogin = true,
		saved = { version = 2, profiles = { Default = { ActionBars = { enabled = true } } }, characters = { ["Realm-Tester"] = "Default" } },
		setup = function(e)
			e._game.bindings.ACTIONBUTTON1 = { "1" }
		end,
	})
	assert(K.Modules.IsRunning("ActionBars"), "the module started at login: " .. AB.Errors(env))
	assert(ns.bars.bar1 and AB.PressKey(env, "1"), "the bars and bindings exist during the fight")
	assert(#env._blocked == 0, "nothing was blocked: " .. table.concat(env._blocked, ", "))
	env.SetCombat(false)
	assert(#env._errors == 0, AB.Errors(env))
end

-- A client with fewer action slots: bar 6's page does not exist, so its buttons stay empty without errors.
do
	local env, K, ns = AB.New({ maxSlot = 132 })
	AB.Enable(env, K)
	K.Options.Write("ActionBars", "bar6.enabled", true)
	env.FireEvent("ACTIONBAR_UPDATE_COOLDOWN")
	env.FireEvent("ACTIONBAR_SLOT_CHANGED", 0)
	assert(ns.bars.bar6 and #env._errors == 0, AB.Errors(env))
	assert(logged(env, "slot 145"), "the missing slots are logged")
end

-- The settings page: the bar picker shows one bar's rows at a time, and the window opens the page with its preview.
do
	local env, K, ns = AB.New()
	AB.Enable(env, K)
	assert(K.Options.Open("ActionBars"), "the settings window opens on the action bars page")
	local Model = env._addons.KstyleUI_Options.Model
	local function VisibleKeys()
		local keys = {}
		for _, item in ipairs(Model.Visible(Model.SchemaItems("ActionBars", K.Options.Get("ActionBars"), "ActionBars"))) do
			if item.key then
				keys[item.key] = true
			end
		end
		return keys
	end
	local keys = VisibleKeys()
	assert(keys["bar1.buttons"] and keys["bar1.pageStealth"] and keys["text.count.size"] and keys.accent, "bar 1's rows and the shared rows show")
	assert(not keys["bar2.buttons"] and not keys["pet.size"], "other bars' rows hide")
	assert(not keys["bar1.fadeAlpha"], "the faded opacity shows only with the fade on")
	K.Options.Write("ActionBars", "editBar", "pet")
	keys = VisibleKeys()
	assert(keys["pet.buttons"] and not keys["bar1.buttons"] and not keys["pet.paging"], "the pet bar has no paging rows")
	assert(#env._errors == 0, AB.Errors(env))
	assert(#ns.actionButtons > 0)
end

print("action bars ok")
