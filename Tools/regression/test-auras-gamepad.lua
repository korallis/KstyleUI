-- test-auras-gamepad.lua: KstyleUI_Auras in Forever's gamepad interface (Review Focus 4): Blizzard's buff frames stay
-- usable, because the gamepad "View buffs" shortcut and radial segment give focus to BuffFrame and DebuffFrame.
local A = dofile("Tools/regression/auras_env.lua")

local GAMEPAD, MKB = 1, 0

local function check(cond, message)
	if not cond then
		error(message, 2)
	end
end

local function find(list, fn)
	for _, item in ipairs(list) do
		if fn(item) then
			return item
		end
	end
end

local function registered(env, key)
	return find(env._layout, function(entry)
		return entry.key == key
	end)
end

local function devlog(env, text)
	for _, entry in ipairs(env.KstyleUIDB.devlog or {}) do
		if tostring(entry.message):find(text, 1, true) then
			return entry
		end
	end
end

local function start(opts)
	local env, K, ns = A.New(opts)
	K.Modules.Enable("Auras")
	env.RunTimers()
	return env, K, ns
end

local function switch(env, style)
	local old = env._interfaceStyle
	env._interfaceStyle = style
	env.FireEvent("INPUT_DEVICE_INTERFACE_TRANSITION", style, old)
	env.RunTimers()
end

local function hosts(env)
	local buffs, debuffs = A.Container(env, "HELPFUL"), A.Container(env, "HARMFUL")
	return buffs:GetParent(), debuffs:GetParent()
end

local function blizzardShown(env)
	return env.BuffFrame:GetParent() == env.UIParent and env.DebuffFrame:GetParent() == env.UIParent
end

local function blizzardHidden(env)
	return A.Hidden(env, env.BuffFrame) and A.Hidden(env, env.DebuffFrame)
end

-- Gamepad interface at login: Blizzard's buff frames stay, and KstyleUI's panel steps aside so buffs show once.
do
	local env, K, ns = start({
		layout = true,
		setup = function(e)
			e._interfaceStyle = GAMEPAD
		end,
	})
	check(K.Modules.IsRunning("Auras"), "the module runs")
	check(#A.Rows(env) == 4, "the containers are still built")
	check(blizzardShown(env), "Blizzard's buff and debuff frames keep their parent, so the gamepad can focus them")
	check(not K.Safe.IsHidden(env.BuffFrame) and not K.Safe.IsHidden(env.DebuffFrame), "Safe holds neither frame")
	local bh, dh = hosts(env)
	check(not bh:IsShown() and not dh:IsShown(), "KstyleUI's aura panels hide, so the player sees one set of buffs")
	check(registered(env, "auras.buffs") and registered(env, "auras.debuffs"), "the Layout elements stay registered")
	check(devlog(env, "gamepad"), "the gamepad path is logged")
	local ok, status = ns.Panel.Status()
	check(ok and status:find("gamepad", 1, true), "the /kstyle test check names the gamepad path, got " .. tostring(status))
	check(#env._errors == 0, "no errors: " .. tostring(env._errors[1]))
end

-- Switching to the gamepad and back swaps Blizzard's frames and KstyleUI's panels.
do
	local env, K = start({ layout = true })
	local bh, dh = hosts(env)
	check(blizzardHidden(env), "keyboard and mouse: Blizzard's frames are hidden")
	check(bh:IsShown() and dh:IsShown(), "keyboard and mouse: KstyleUI's panels show")
	switch(env, GAMEPAD)
	check(blizzardShown(env), "gamepad: Blizzard's frames come back")
	check(not bh:IsShown() and not dh:IsShown(), "gamepad: KstyleUI's panels hide")
	check(devlog(env, "gamepad"), "the switch is logged")
	switch(env, MKB)
	check(blizzardHidden(env), "back to keyboard and mouse: Blizzard's frames hide again")
	check(bh:IsShown() and dh:IsShown(), "back to keyboard and mouse: KstyleUI's panels show again")
	check(K.Safe.IsHidden(env.BuffFrame), "Safe holds BuffFrame again")
	check(#env._errors == 0, "no errors: " .. tostring(env._errors[1]))
end

-- A switch in combat waits for combat to end, so one set of buffs shows throughout.
do
	local env = start({ layout = true })
	local bh = hosts(env)
	env.SetCombat(true)
	switch(env, GAMEPAD)
	check(blizzardHidden(env), "Blizzard's frames are not reparented in combat")
	check(bh:IsShown(), "KstyleUI's panel stays until Blizzard's frames can come back")
	env.SetCombat(false)
	env.RunTimers()
	check(blizzardShown(env), "after combat Blizzard's frames come back")
	check(not bh:IsShown(), "and KstyleUI's panel hides")
	check(#env._errors == 0, "no errors: " .. tostring(env._errors[1]))
end

-- In the gamepad interface a Layout show of the element does not bring KstyleUI's panel back.
do
	local env = start({ layout = true })
	local bh = hosts(env)
	local holder = registered(env, "auras.buffs").frame
	switch(env, GAMEPAD)
	holder:Hide()
	holder:Show()
	check(not bh:IsShown(), "the host stays hidden while the gamepad interface is on")
	holder:Hide()
	switch(env, MKB)
	check(not bh:IsShown(), "back on keyboard and mouse the host follows the hidden element")
	holder:Show()
	check(bh:IsShown(), "and shows with it")
end

-- The hide setting and a profile change cannot hide Blizzard's frames in the gamepad interface.
do
	local env, K = start({ layout = true })
	switch(env, GAMEPAD)
	K.Options.Write("Auras", "hideBlizzard", false)
	env.RunTimers()
	K.Options.Write("Auras", "hideBlizzard", true)
	env.RunTimers()
	check(blizzardShown(env), "turning the hide setting on leaves Blizzard's frames in gamepad mode")
	K.Callbacks.Fire("ProfileChanged")
	env.RunTimers()
	check(blizzardShown(env), "a profile change leaves them too")
end

-- Off: Blizzard's frames come back and stay whatever the interface; on again in gamepad mode keeps them.
do
	local env, K = start({ layout = true })
	K.Modules.Disable("Auras")
	env.RunTimers()
	env._interfaceStyle = GAMEPAD
	K.Modules.Enable("Auras")
	env.RunTimers()
	check(blizzardShown(env), "enabling in gamepad mode keeps Blizzard's frames")
	local bh = hosts(env)
	check(not bh:IsShown(), "and KstyleUI's panel stays hidden")
	switch(env, MKB)
	check(blizzardHidden(env) and bh:IsShown(), "the keyboard switch after re-enabling still swaps them")
end

-- Fallback: without InputUtil the module asks C_InputInterfaceStyle; without either it keeps the keyboard path and logs it.
do
	local env = start({
		layout = true,
		setup = function(e)
			e.InputUtil = nil
			e._interfaceStyle = GAMEPAD
		end,
	})
	check(blizzardShown(env), "C_InputInterfaceStyle alone still finds the gamepad interface")
	check(#env._errors == 0, "no errors: " .. tostring(env._errors[1]))
end
do
	local env = start({
		layout = true,
		setup = function(e)
			e.InputUtil = nil
			e.C_InputInterfaceStyle = nil
		end,
	})
	check(blizzardHidden(env), "with no interface API the keyboard path runs")
	check(devlog(env, "interface style"), "the missing API is logged")
	check(#env._errors == 0, "no errors: " .. tostring(env._errors[1]))
end

-- A secret answer never reaches a comparison: the module keeps the keyboard path.
do
	local env = start({
		layout = true,
		setup = function(e)
			local secret = {}
			e.issecretvalue = function(value)
				return value == secret
			end
			e.InputUtil.IsGamepadUIEnabled = function()
				return secret
			end
			e.C_InputInterfaceStyle.GetCurrentStyle = function()
				return secret
			end
		end,
	})
	check(blizzardHidden(env), "a secret style counts as keyboard and mouse")
	check(#env._errors == 0, "no errors: " .. tostring(env._errors[1]))
end

print("auras gamepad ok")
