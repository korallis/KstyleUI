-- test-groupframes-gamepad.lua: in Forever's gamepad interface the group frames stand down. Gamepad group targeting walks Blizzard's CompactPartyFrame (inside PartyFrame) and CompactRaidFrameContainer, so those come back and KstyleUI's headers hide, in or out of combat, and a switch back to keyboard and mouse returns KstyleUI's frames.
local G = dofile("Tools/regression/group_env.lua")

local function eq(got, want, what)
	assert(got == want, what .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end

local MKB, GAMEPAD = 0, 1

-- opts.gamepad starts in the gamepad interface; opts.inputUtil = false leaves InputUtil out;
-- opts.style adds C_InputInterfaceStyle and Enum.InputDeviceInterfaceType.
local function setup(opts)
	opts = opts or {}
	local env, K, ns = G.New({
		setup = function(e)
			e._gamepad = opts.gamepad == true
			e.InputUtil, e.C_InputInterfaceStyle = nil, nil
			if opts.inputUtil ~= false then
				e.InputUtil = {
					IsGamepadUIEnabled = function()
						return e._gamepad
					end,
				}
			end
			if opts.style then
				e.Enum = e.Enum or {}
				e.Enum.InputDeviceInterfaceType = { Mkb = MKB, Gamepad = GAMEPAD }
				e.C_InputInterfaceStyle = {
					GetCurrentStyle = function()
						return e._gamepad and GAMEPAD or MKB
					end,
				}
			end
		end,
	})
	G.SetRoster(env, "party", { { name = "Thaldren", class = "WARRIOR" }, { name = "Sylaen", class = "DRUID" } })
	K.Modules.Enable("GroupFrames")
	env.RunTimers()
	return env, K, ns
end

local function switch(env, gamepad)
	env._gamepad = gamepad
	env.FireEvent("INPUT_DEVICE_INTERFACE_TRANSITION", gamepad and GAMEPAD or MKB, gamepad and MKB or GAMEPAD)
	env.RunTimers()
end

local BLIZZARD = { "PartyFrame", "CompactRaidFrameContainer", "CompactRaidFrameManager" }

local function blizzardHidden(env, K, want, what)
	for _, name in ipairs(BLIZZARD) do
		eq(K.Safe.IsHidden(env[name]), want, what .. ": " .. name .. (want and " is hidden" or " is Blizzard's again"))
	end
end

local function oursShown(env, ns, want, what)
	local driver = env.Driver(ns.Headers.party, "visibility")
	eq(driver ~= nil, want, what .. ": the party header's state driver")
	eq(ns.Headers.holders.party:IsShown(), want, what .. ": the party holder")
	eq(ns.Headers.holders.raid:IsShown(), want, what .. ": the raid holder")
	if not want then
		eq(ns.Headers.party:IsShown(), false, what .. ": the party header is hidden")
		for g, header in ipairs(ns.Headers.raid) do
			eq(env.Driver(header, "visibility"), nil, what .. ": raid header " .. g .. " has no state driver")
		end
	end
end

local function logged(env, text)
	for _, entry in ipairs(env.KstyleUIDB.devlog) do
		if entry.module == "GroupFrames" and entry.message:find(text, 1, true) then
			return true
		end
	end
	return false
end

-- Keyboard and mouse: KstyleUI's frames show and Blizzard's are hidden, as before.
do
	local env, K, ns = setup()
	blizzardHidden(env, K, true, "keyboard and mouse")
	oursShown(env, ns, true, "keyboard and mouse")

	local f = ns.Button.Content(ns.Headers.party._attributes.child2)
	eq(f.unit, "party1", "the second party button shows party1")
	eq(f.auras._unit, "party1", "its debuffs follow party1")

	-- A switch to the controller gives Blizzard's targetable frames back and hides KstyleUI's.
	switch(env, true)
	blizzardHidden(env, K, false, "gamepad")
	oursShown(env, ns, false, "gamepad")
	assert(logged(env, "gamepad"), "the stand-down is logged")
	eq(next(f._events), nil, "a hidden frame listens to no unit event")
	eq(f.auras._unit, "none", "and its debuff container lets the unit go")

	-- Settings changes while standing down neither show KstyleUI's headers nor hide Blizzard's frames.
	K.Options.Write("GroupFrames", "party.width", 200)
	K.Options.Write("GroupFrames", "blizzard.party", true)
	K.Callbacks.Fire("ProfileChanged")
	env.FireEvent("ADDON_LOADED", "Blizzard_CompactRaidFrames")
	env.RunTimers()
	blizzardHidden(env, K, false, "gamepad after settings changes")
	oursShown(env, ns, false, "gamepad after settings changes")

	-- Back to keyboard and mouse: KstyleUI's frames return with the new width and Blizzard's hide again.
	switch(env, false)
	blizzardHidden(env, K, true, "back to keyboard and mouse")
	oursShown(env, ns, true, "back to keyboard and mouse")
	eq(ns.Headers.party._attributes["kstyle-width"], 200, "the width set while standing down applies")
	assert(next(f._events) ~= nil, "unit events come back")
	eq(f.auras._unit, "party1", "and the debuffs follow party1 again")
	eq(#env._errors, 0, "no errors: " .. tostring(env._errors[1]))
end

-- In combat: nothing protected moves until combat ends, then the state settles on the last switch.
-- Until then KstyleUI's frames are still the ones on screen, so they keep following their units.
do
	local env, K, ns = setup()
	local f = ns.Button.Content(ns.Headers.party._attributes.child2)
	env.SetCombat(true)
	switch(env, true)
	eq(#env._blocked, 0, "a switch in combat makes no protected call: " .. tostring(env._blocked[1]))
	blizzardHidden(env, K, true, "gamepad in combat, before combat ends")
	oursShown(env, ns, true, "gamepad in combat, before combat ends")
	env._roster.units.party1.health = 10
	env.FireEvent("UNIT_HEALTH", "party1")
	local value = f.health._state.Value
	eq(value and env.Reveal(value[1]), 10, "the frame still on screen follows its unit's health")
	eq(f.auras._unit, "party1", "and its debuffs")
	env.SetCombat(false)
	env.RunTimers()
	blizzardHidden(env, K, false, "gamepad after combat")
	oursShown(env, ns, false, "gamepad after combat")
	eq(next(f._events), nil, "the hidden frame stops listening once combat ends")

	env.SetCombat(true)
	switch(env, false)
	switch(env, true)
	switch(env, false)
	eq(#env._blocked, 0, "switches back and forth in combat make no protected call: " .. tostring(env._blocked[1]))
	env.SetCombat(false)
	env.RunTimers()
	blizzardHidden(env, K, true, "keyboard and mouse after combat")
	oursShown(env, ns, true, "keyboard and mouse after combat")
	eq(#env._errors, 0, "no errors: " .. tostring(env._errors[1]))
end

-- Enabled while the controller is in use: Blizzard's frames are never hidden and KstyleUI's never show.
do
	local env, K, ns = setup({ gamepad = true })
	blizzardHidden(env, K, false, "enabled in gamepad")
	assert(ns.Headers.built, "the headers are still built, ready for keyboard and mouse")
	oursShown(env, ns, false, "enabled in gamepad")
	switch(env, false)
	blizzardHidden(env, K, true, "keyboard and mouse after enabling in gamepad")
	oursShown(env, ns, true, "keyboard and mouse after enabling in gamepad")

	-- Disable while standing down leaves Blizzard's frames and KstyleUI's hidden headers alone.
	switch(env, true)
	K.Modules.Disable("GroupFrames")
	env.RunTimers()
	blizzardHidden(env, K, false, "disabled")
	oursShown(env, ns, false, "disabled")
	switch(env, false)
	blizzardHidden(env, K, false, "a switch after Disable changes nothing")
	oursShown(env, ns, false, "a switch after Disable changes nothing")
	eq(#env._errors, 0, "no errors: " .. tostring(env._errors[1]))
end

-- Without InputUtil the interface style comes from C_InputInterfaceStyle.
do
	local env, K, ns = setup({ inputUtil = false, style = true, gamepad = true })
	blizzardHidden(env, K, false, "C_InputInterfaceStyle reports the gamepad")
	oursShown(env, ns, false, "C_InputInterfaceStyle reports the gamepad")
	switch(env, false)
	blizzardHidden(env, K, true, "C_InputInterfaceStyle reports keyboard and mouse")
	eq(#env._errors, 0, "no errors: " .. tostring(env._errors[1]))
end

-- A secret answer counts as keyboard and mouse, and a client with neither API keeps the old behaviour.
do
	local env, K, ns = setup({ gamepad = true })
	blizzardHidden(env, K, false, "a plain gamepad answer")
	env.InputUtil.IsGamepadUIEnabled = function()
		return env.Secret(true)
	end
	env.FireEvent("INPUT_DEVICE_INTERFACE_TRANSITION", GAMEPAD, MKB)
	env.RunTimers()
	blizzardHidden(env, K, true, "a secret interface style")
	oursShown(env, ns, true, "a secret interface style")

	env, K, ns = setup({ inputUtil = false })
	blizzardHidden(env, K, true, "no interface style API")
	oursShown(env, ns, true, "no interface style API")
	eq(#env._errors, 0, "no errors: " .. tostring(env._errors[1]))
end

print("groupframes gamepad ok")
