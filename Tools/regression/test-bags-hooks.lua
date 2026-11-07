-- test-bags-hooks.lua: KstyleUI_Bags opens and closes with Blizzard's bag functions through secure hooks, hides Blizzard's bags safely and stands down for the gamepad style.
local B = dofile("Tools/regression/bags_env.lua")
local W = B.W

local function Shown(ns)
	return ns.Inventory.IsOpen()
end

local function Run(env)
	env.RunTimers()
	W.Settle(env)
end

-- Blizzard's bags go under a hidden parent ----------------------------------------------------------

do
	local env, K = B.New()
	local combined, holder = env.ContainerFrameCombinedBags, env.ContainerFrameContainer
	assert(K.Safe.IsHidden(combined) and K.Safe.IsHidden(holder), "Enable hides Blizzard's combined bags and the frame that holds the single bags")
	assert(combined:GetParent() ~= env.UIParent and not combined:GetParent():IsShown(), "through Safe, under a hidden parent")
	assert(#W.Calls(combined, "Hide") == 1 and #W.Calls(holder, "Hide") == 0, "no Hide on Blizzard's frames beyond the fake game's own")
	for _, frame in ipairs({ combined, holder }) do
		assert(#W.Calls(frame, "SetScript") == 0, "no SetScript on Blizzard's frames")
	end
end

-- Toggle, open and close ----------------------------------------------------------------------------

do
	local env, _, ns = B.New()
	assert(not Shown(ns), "closed at first")
	env.ToggleAllBags()
	assert(not Shown(ns), "the hook waits for the end of the frame, so nested Blizzard calls settle first")
	Run(env)
	assert(Shown(ns) and ns.Inventory.window.panel:IsShown(), "ToggleAllBags opens the window")
	env.ToggleAllBags()
	Run(env)
	assert(not Shown(ns) and not ns.Inventory.window.panel:IsShown(), "and closes it again")

	env.ToggleBackpack()
	Run(env)
	assert(Shown(ns), "ToggleBackpack opens it")
	ns.Inventory.window.panel.closeButton:GetScript("OnClick")(ns.Inventory.window.panel.closeButton, "LeftButton")
	Run(env)
	assert(not Shown(ns), "the close button closes it")
	assert(not env._blizzOpen(), "and closes Blizzard's hidden bags too, so the next toggle opens")
	assert(#W.Calls(env.ContainerFrameCombinedBags, "Hide") >= 2, "Blizzard's frame was hidden while it was not visible, so none of its scripts ran")
	env.ToggleBackpack()
	Run(env)
	assert(Shown(ns), "one key press opens the bags again")

	ns.Inventory.window.panel:Close()
	Run(env)
	env.OpenAllBags(env.MerchantFrame)
	Run(env)
	assert(Shown(ns), "a merchant's OpenAllBags opens the window")
	env.CloseAllBags(env.BankFrame)
	Run(env)
	assert(Shown(ns), "CloseAllBags from a window that did not open the bags leaves them open")
	env.CloseAllBags(env.MerchantFrame)
	Run(env)
	assert(not Shown(ns), "CloseAllBags from the merchant closes them")

	env.ToggleBag(1)
	Run(env)
	assert(Shown(ns), "ToggleBag opens the combined window")
	env.CloseBag(1)
	Run(env)
	assert(not Shown(ns), "CloseBag closes it")

	env._bagsAllowed = false
	env.ToggleAllBags()
	Run(env)
	assert(not Shown(ns), "nothing opens while Blizzard does not allow bags")
	env._bagsAllowed = true

	env.OpenAllBags()
	Run(env)
	local panel = ns.Inventory.window.panel
	assert(Shown(ns), "open again")
	W.Key(panel, "ESCAPE")
	Run(env)
	assert(not Shown(ns) and not env._blizzOpen(), "Escape closes the window and Blizzard's hidden bags")
end

-- Combat ------------------------------------------------------------------------------------------

do
	local env, _, ns = B.New()
	env.SetCombat(true)
	env.ToggleAllBags()
	Run(env)
	assert(Shown(ns), "bags open in combat")
	env.ToggleAllBags()
	Run(env)
	assert(not Shown(ns), "and close in combat")
	env.SetCombat(false)
end

-- Turning the module off ----------------------------------------------------------------------------

do
	local env, K, ns = B.New()
	env.ToggleAllBags()
	Run(env)
	K.Modules.Disable("Bags")
	Run(env)
	assert(not ns.Inventory.window.panel:IsShown(), "Disable closes the window")
	assert(not K.Safe.IsHidden(env.ContainerFrameCombinedBags) and not K.Safe.IsHidden(env.ContainerFrameContainer), "Disable gives Blizzard its bags back")
	assert(env.ContainerFrameCombinedBags:GetParent() == env.UIParent, "under their own parent")
	assert(not env.ContainerFrameCombinedBags:IsShown(), "closed, so no Blizzard script ran in KstyleUI's code")
	env.ToggleAllBags()
	Run(env)
	assert(not ns.Inventory.window.panel:IsShown(), "the hooks do nothing while the module is off")
	K.Modules.Enable("Bags")
	Run(env)
	assert(K.Safe.IsHidden(env.ContainerFrameCombinedBags), "turning it on again hides Blizzard's bags again")
	env.CloseAllBags()
	env.ToggleAllBags()
	Run(env)
	assert(Shown(ns), "and the hooks work again, installed once")
end

-- Gamepad ---------------------------------------------------------------------------------------------

do
	local env, K, ns = B.New({ gamepad = true })
	assert(not K.Safe.IsHidden(env.ContainerFrameCombinedBags), "the gamepad style keeps Blizzard's bags, which its D-pad navigates")
	env.ToggleAllBags()
	Run(env)
	assert(not Shown(ns), "and KstyleUI's window stays closed")
	assert(env._blizzOpen(), "Blizzard's bags open as usual")
	local logged = false
	for _, entry in ipairs(env.KstyleUIDB.devlog) do
		logged = logged or (entry.module == "Bags" and entry.message:find("gamepad", 1, true) ~= nil)
	end
	assert(logged, "the stand-down is logged to the devlog")
end

-- /kstyle test ---------------------------------------------------------------------------------------

local function Result(env, prefix)
	for i = #env.KstyleUIDB.devlog, 1, -1 do
		local message = env.KstyleUIDB.devlog[i].message
		if message:find(prefix, 1, true) == 1 then
			return message
		end
	end
end

do
	local env, K = B.New({ enable = false })
	K.DevTest.Run()
	assert(Result(env, "PASS bags"), "the bag check passes while the module is off")
	B.Enable(env, K)
	K.DevTest.Run()
	local line = Result(env, "PASS bags")
	assert(line and line:find("Blizzard's bags hidden", 1, true), "the bag check reports the window and Blizzard's hidden bags: " .. tostring(line))
	K.Safe.RestoreBlizzard(env.ContainerFrameCombinedBags)
	env.RunTimers()
	K.DevTest.Run()
	assert(Result(env, "FAIL bags"), "the bag check fails when Blizzard's bags are not hidden")
end

print("bags hooks ok")
