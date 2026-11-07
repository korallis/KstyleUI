-- test-bags-gamepad.lua: KstyleUI_Bags gives Blizzard back its bags and bank when the player switches to the gamepad interface style mid-session, and takes them again on the switch back, without a reload (Review Focus 4).
local B = dofile("Tools/regression/bags_env.lua")
local W = B.W

local function Run(env)
	env.RunTimers()
	W.Settle(env)
end

local function NoErrors(env)
	assert(#env._errors == 0, "errors:\n" .. table.concat(env._errors, "\n"))
end

-- Taken(env, K) is true when Blizzard's bag frames sit under Safe's hidden parent.
local function Taken(env, K)
	return K.Safe.IsHidden(env.ContainerFrameCombinedBags) and K.Safe.IsHidden(env.ContainerFrameContainer)
end

-- Returned(env, K) is true when Blizzard's bag frames and bank are back under their own parent.
local function Returned(env, K)
	for _, frame in ipairs({ env.ContainerFrameCombinedBags, env.ContainerFrameContainer, env.BankFrame }) do
		if K.Safe.IsHidden(frame) or frame:GetParent() ~= env.UIParent then
			return false
		end
	end
	return true
end

local function Logged(env, text)
	for _, entry in ipairs(env.KstyleUIDB.devlog) do
		if entry.module == "Bags" and entry.message:find(text, 1, true) then
			return true
		end
	end
	return false
end

local function Result(env, prefix)
	for i = #env.KstyleUIDB.devlog, 1, -1 do
		local message = env.KstyleUIDB.devlog[i].message
		if message:find(prefix, 1, true) == 1 then
			return message
		end
	end
end

-- Keyboard, then gamepad: Blizzard's bags come back and the gamepad's bag button opens them ---------

do
	local env, K, ns = B.New({ bags = { [0] = { size = 16, items = { [1] = B.Item("junk") } } } })
	assert(K.Options.Write("Bags", "autoSellJunk", true) ~= false, "turning on Sell junk by itself")
	assert(Taken(env, K) and K.Safe.IsHidden(env.BankFrame), "the keyboard style starts with Blizzard's bags and bank hidden")
	env.ToggleAllBags()
	Run(env)
	assert(ns.Inventory.IsOpen(), "KstyleUI's bag window is open")

	env.SetGamepad(true)
	Run(env)
	assert(Returned(env, K), "the switch to the gamepad style gives Blizzard back its bags and bank, under their own parent")
	assert(not ns.Inventory.IsOpen() and not ns.Inventory.window.panel:IsShown(), "and closes KstyleUI's bag window")
	assert(not env._blizzOpen(), "Blizzard's bags were closed while hidden, so they return closed and none of their scripts ran in KstyleUI's code")
	assert(Logged(env, "gamepad"), "the switch is logged to the devlog")

	env.ToggleAllBags()
	Run(env)
	assert(env._blizzOpen() and B.Shown(env.ContainerFrameCombinedBags), "the gamepad's bag button (ToggleAllBags) opens Blizzard's bags, which its D-pad navigates")
	assert(not ns.Inventory.IsOpen() and not ns.Inventory.window.panel:IsShown(), "and leaves KstyleUI's window closed")
	env.ToggleAllBags()
	Run(env)
	assert(not env._blizzOpen(), "and closes them again")

	env.SetMerchant(true)
	Run(env)
	assert(B.Count(env, "SellAllJunkItems") == 0, "nothing of the module runs while it stands down: junk does not sell by itself")
	env.SetMerchant(false)

	K.DevTest.Run()
	local line = Result(env, "PASS bags")
	assert(line and line:find("gamepad", 1, true), "/kstyle test reports the stand-down: " .. tostring(line))
	NoErrors(env)
end

-- Gamepad at login, then keyboard: the module takes over without a reload ---------------------------

do
	local env, K, ns = B.New({ gamepad = true, bags = { [0] = { size = 16, items = { [1] = B.Item("potion") } } } })
	assert(not Taken(env, K) and not K.Safe.IsHidden(env.BankFrame), "the gamepad style at login keeps Blizzard's bags and bank")

	env.SetGamepad(false)
	Run(env)
	assert(Taken(env, K) and K.Safe.IsHidden(env.BankFrame), "the switch to the keyboard style hides Blizzard's bags and bank, without a reload")
	env.ToggleAllBags()
	Run(env)
	assert(ns.Inventory.IsOpen() and ns.Inventory.window.panel:IsShown(), "and the bag key opens KstyleUI's window")
	assert(ns.Inventory.Slot(0, 1), "with its slots built")
	assert(Logged(env, "keyboard"), "the switch back is logged to the devlog")

	B.Put(env, 0, 2, B.Item("sword"))
	Run(env)
	assert(ns.Inventory.Slot(0, 2).record.itemID == 1000, "the module's events came back with it: a bag change refreshes the window")
	env.SetBank(true)
	Run(env)
	assert(ns.Bank.IsOpen(), "and the bank window opens at a banker")
	NoErrors(env)
end

-- In combat the switch waits for Combat.Queue -------------------------------------------------------

do
	local env, K, ns = B.New()
	env.SetCombat(true)
	env.SetGamepad(true)
	Run(env)
	assert(Taken(env, K), "a switch in combat changes nothing until combat ends")
	env.ToggleAllBags()
	Run(env)
	assert(ns.Inventory.IsOpen(), "KstyleUI's window still serves the bags in combat")
	env.SetCombat(false)
	Run(env)
	assert(Returned(env, K), "when combat ends Blizzard gets its bags and bank back")
	assert(not ns.Inventory.IsOpen() and not env._blizzOpen(), "with both closed")
	NoErrors(env)
end

do
	local env, K, ns = B.New()
	env.SetCombat(true)
	env.SetGamepad(true)
	env.SetGamepad(false)
	env.SetCombat(false)
	Run(env)
	assert(Taken(env, K) and K.Safe.IsHidden(env.BankFrame), "a switch and a switch back in one fight end where they started")
	env.ToggleAllBags()
	Run(env)
	assert(ns.Inventory.IsOpen(), "and one key press opens the bag window")
	env.SetGamepad(false)
	Run(env)
	env.ToggleAllBags()
	Run(env)
	assert(not ns.Inventory.IsOpen(), "a repeated keyboard transition changes nothing")
	NoErrors(env)
end

-- At the bank: the switch ends the visit, and Blizzard's bank returns when it ends ------------------

do
	local env, K, ns = B.New()
	env.SetBank(true)
	Run(env)
	assert(ns.Bank.IsOpen(), "KstyleUI's bank window serves the visit")
	env.SetGamepad(true)
	Run(env)
	assert(not ns.Bank.IsOpen() and not ns.Bank.window.panel:IsShown(), "the switch closes KstyleUI's bank window")
	assert(B.Count(env, "CloseBankFrame") == 1, "and ends the visit, so Blizzard's bank never moves while it is shown")
	assert(K.Safe.IsHidden(env.BankFrame), "Blizzard's bank stays hidden until the visit ends")
	env.SetBank(false)
	Run(env)
	assert(Returned(env, K), "and returns under its own parent when the visit ends")
	env.SetBank(true)
	Run(env)
	assert(not ns.Bank.IsOpen() and B.Shown(env.BankFrame), "the next visit shows Blizzard's bank")
	NoErrors(env)
end

-- The module off: a style change does nothing ------------------------------------------------------

do
	local env, K = B.New({ gamepad = true })
	K.Modules.Disable("Bags")
	Run(env)
	env.SetGamepad(false)
	Run(env)
	assert(not Taken(env, K) and not K.Safe.IsHidden(env.BankFrame), "a module that is off ignores the style change")
	K.Modules.Enable("Bags")
	Run(env)
	assert(Taken(env, K), "turning it on in the keyboard style hides Blizzard's bags")
	env.SetGamepad(true)
	Run(env)
	K.Modules.Disable("Bags")
	Run(env)
	assert(Returned(env, K), "turning it off while it stands down leaves Blizzard's bags and bank where they are")
	NoErrors(env)
end

do
	local env, K = B.New({ gamepad = true })
	env.SetCombat(true)
	K.Modules.Disable("Bags")
	env.SetGamepad(false)
	env.SetCombat(false)
	Run(env)
	assert(not K.Modules.IsRunning("Bags"), "the module turned off when combat ended")
	assert(not Taken(env, K) and not K.Safe.IsHidden(env.BankFrame), "a switch queued in the same fight after the module turned off does nothing")
	NoErrors(env)
end

print("bags gamepad ok")
