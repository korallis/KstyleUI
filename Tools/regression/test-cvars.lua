-- test-cvars.lua: at login the core puts back the player's own value of each CVar that KstyleUI_CombatText or KstyleUI_Chat hid, on a character where that module is off, from the memory the module keeps in KstyleUIDB.account.
local CoreEnv = dofile("Tools/regression/core_env.lua")
local C = dofile("Tools/regression/chat_env.lua")

local SELF = "enableFloatingCombatText"
local DAMAGE, HEALING = "floatingCombatTextCombatDamage_v2", "floatingCombatTextCombatHealing_v2"
local PET_MELEE, PET_SPELL = "floatingCombatTextPetMeleeDamage_v2", "floatingCombatTextPetSpellDamage_v2"
local STAMPS, OURS = "showTimestamps", "|cffe6e6e6[%H:%M]|r "
local MAIN, ALT = "Realm-Tester", "Realm-Alt"

local failures = {}
local function Case(name, fn)
	local ok, err = pcall(fn)
	if not ok then
		failures[#failures + 1] = name .. ": " .. tostring(err)
	end
end

-- Hidden(original, written) -> the memory a module keeps for one CVar it wrote.
local function Hidden(original, written)
	return { original = original, written = written or "0" }
end

-- Saved(account, profile) -> a KstyleUIDB with the modules' memories; every character uses the Default profile.
local function Saved(account, profile)
	return { version = 2, profiles = { Default = profile or {} }, characters = {}, account = account }
end

local function Variables(env)
	env.FireEvent("VARIABLES_LOADED")
	env.RunTimers()
end

-- Start(opts) -> env, K: the core with opts.saved, the game's CVars in opts.cvars and a stand-in module for each
-- name in opts.running, then VARIABLES_LOADED and PLAYER_LOGIN, as a reload fires them. opts.late fires
-- VARIABLES_LOADED after PLAYER_LOGIN, as a first login can; opts.login = false stops before PLAYER_LOGIN.
-- SetCVar records each write, refuses a name in opts.secure as the client refuses a secure CVar, and fires
-- CVAR_UPDATE inside the call; opts.noSetCVar leaves it out. opts.combat logs in during combat.
local function Start(opts)
	local env, K = CoreEnv.New({ saved = opts.saved, player = opts.player, setup = function(e)
		e._cvars, e._cvarWrites = opts.cvars, {}
		e.C_CVar = { GetCVar = function(name) return e._cvars[name] end }
		if not opts.noSetCVar then
			e.C_CVar.SetCVar = function(name, value)
				e._cvarWrites[#e._cvarWrites + 1] = { name = name, value = value }
				if not (opts.secure and opts.secure[name]) then
					e._cvars[name] = value
					e.FireEvent("CVAR_UPDATE", name, value)
					return true
				end
			end
		end
	end })
	CoreEnv.LoadSaved(env)
	for _, name in ipairs(opts.running or {}) do
		K.Modules.Register(CoreEnv.Module(name))
	end
	env._combat = opts.combat == true
	if not opts.late then
		Variables(env)
	end
	if opts.login ~= false then
		CoreEnv.Login(env)
		env.RunTimers()
	end
	return env, K
end

local function Memory(env, key, owner)
	return env.KstyleUIDB.account[key][owner]
end

local function Logged(env, text)
	local n = 0
	for _, entry in ipairs(env.KstyleUIDB.devlog) do
		n = n + (entry.message:find(text, 1, true) and 1 or 0)
	end
	return n
end

local function NoErrors(env)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

Case("an alt whose CombatText is off gets the numbers over targets back, which another character hid for every character", function()
	local env = Start({
		player = "Alt", login = false,
		saved = Saved({ combatTextCVars = { ["*"] = { [DAMAGE] = Hidden("1"), [HEALING] = Hidden("0"), [PET_MELEE] = Hidden("1"), [PET_SPELL] = Hidden("1") } } }),
		cvars = { [SELF] = "1", [DAMAGE] = "0", [HEALING] = "0", [PET_MELEE] = "0", [PET_SPELL] = "0" },
	})
	assert(#env._cvarWrites == 0, "nothing is written before PLAYER_LOGIN, when the modules start")
	CoreEnv.Login(env)
	env.RunTimers()
	assert(env._cvars[DAMAGE] == "1" and env._cvars[PET_MELEE] == "1" and env._cvars[PET_SPELL] == "1", "the player's values are back")
	assert(env._cvars[HEALING] == "0" and #env._cvarWrites == 3, "a CVar the player had off stays off and is not written")
	assert(env._cvars[SELF] == "1", "the alt's own text over it is left alone")
	assert(next(Memory(env, "combatTextCVars", "*")) == nil, "the memory is cleared")
	NoErrors(env)
end)

Case("a character whose CombatText was turned off on another character gets its own text over it back", function()
	local env = Start({
		saved = Saved({ combatTextCVars = { [MAIN] = { [SELF] = Hidden("1") }, [ALT] = { [SELF] = Hidden("1") } } }),
		cvars = { [SELF] = "0", [DAMAGE] = "1" },
	})
	assert(env._cvars[SELF] == "1" and Memory(env, "combatTextCVars", MAIN)[SELF] == nil, "its own value is back and its memory cleared")
	local alt = Memory(env, "combatTextCVars", ALT)[SELF]
	assert(alt and alt.original == "1" and alt.written == "0", "another character's memory waits for that character")
	NoErrors(env)
end)

Case("a character whose Chat is off gets its own chat timestamps back", function()
	local env = Start({ saved = Saved({ chatTimestamps = { [MAIN] = Hidden("%I:%M ", OURS), [ALT] = Hidden("none", OURS) } }), cvars = { [STAMPS] = OURS } })
	assert(env._cvars[STAMPS] == "%I:%M ", "the player's format is back: " .. tostring(env._cvars[STAMPS]))
	assert(Memory(env, "chatTimestamps", MAIN) == nil and Memory(env, "chatTimestamps", ALT), "only this character's memory is cleared")
	NoErrors(env)
end)

Case("a module that runs keeps what it hid; only a module that is off gets its values back", function()
	local env, K = Start({
		running = { "CombatText" },
		saved = Saved({
			combatTextCVars = { ["*"] = { [DAMAGE] = Hidden("1") }, [MAIN] = { [SELF] = Hidden("1") } },
			chatTimestamps = { [MAIN] = Hidden("%H:%M ", OURS) },
		}, { CombatText = { enabled = true } }),
		cvars = { [SELF] = "0", [DAMAGE] = "0", [STAMPS] = OURS },
	})
	assert(K.Modules.IsRunning("CombatText"), "the stand-in CombatText runs")
	assert(env._cvars[SELF] == "0" and env._cvars[DAMAGE] == "0", "the running module's CVars stay hidden")
	assert(Memory(env, "combatTextCVars", "*")[DAMAGE] and Memory(env, "combatTextCVars", MAIN)[SELF], "and its memory stays")
	assert(env._cvars[STAMPS] == "%H:%M ", "Chat, which is off, gets its value back")
	NoErrors(env)
end)

Case("a CVar the player changed since keeps the player's value, and its memory goes, as a damaged memory does", function()
	local env = Start({
		saved = Saved({
			combatTextCVars = { ["*"] = { [DAMAGE] = "0", [HEALING] = { original = 1, written = "0" } }, [MAIN] = { [SELF] = Hidden("1") } },
			chatTimestamps = { [MAIN] = Hidden("%I:%M ", OURS) },
		}),
		cvars = { [SELF] = "1", [STAMPS] = "none", [DAMAGE] = "0", [HEALING] = "0" },
	})
	assert(#env._cvarWrites == 0, "nothing is written")
	assert(env._cvars[SELF] == "1" and env._cvars[STAMPS] == "none", "the player's values stay")
	assert(Memory(env, "combatTextCVars", MAIN)[SELF] == nil and Memory(env, "chatTimestamps", MAIN) == nil, "the memories are cleared")
	assert(next(Memory(env, "combatTextCVars", "*")) == nil, "the damaged memories are cleared")
	NoErrors(env)
end)

Case("in combat at login the values wait for combat to end", function()
	local env = Start({ combat = true, saved = Saved({ combatTextCVars = { [MAIN] = { [SELF] = Hidden("1") } } }), cvars = { [SELF] = "0" } })
	assert(#env._cvarWrites == 0 and env._cvars[SELF] == "0", "no CVar write in combat")
	env.SetCombat(false)
	env.RunTimers()
	assert(env._cvars[SELF] == "1" and Memory(env, "combatTextCVars", MAIN)[SELF] == nil, "written when combat ends")
	NoErrors(env)
end)

Case("CVars the game loads after PLAYER_LOGIN are read only once VARIABLES_LOADED fires", function()
	local env = Start({ late = true, saved = Saved({ combatTextCVars = { [MAIN] = { [SELF] = Hidden("1") } } }), cvars = { [SELF] = "1" } })
	assert(#env._cvarWrites == 0, "nothing is written before the character's CVars load")
	assert(Memory(env, "combatTextCVars", MAIN)[SELF], "the game's default is not taken as the player's change")
	env._cvars[SELF] = "0"
	Variables(env)
	assert(env._cvars[SELF] == "1" and Memory(env, "combatTextCVars", MAIN)[SELF] == nil, "the loaded value is put back")
	NoErrors(env)
end)

Case("a client without C_CVar.SetCVar keeps every memory and logs once; a client with it puts the value back", function()
	local env = Start({
		noSetCVar = true,
		saved = Saved({ combatTextCVars = { [MAIN] = { [SELF] = Hidden("1") } }, chatTimestamps = { [MAIN] = Hidden("none", OURS) } }),
		cvars = { [SELF] = "0", [STAMPS] = OURS },
	})
	assert(env._cvars[SELF] == "0" and env._cvars[STAMPS] == OURS, "nothing changes")
	assert(Memory(env, "combatTextCVars", MAIN)[SELF] and Memory(env, "chatTimestamps", MAIN), "the memories stay")
	assert(Logged(env, "SetCVar") == 1, "the missing API is logged once, got " .. Logged(env, "SetCVar"))
	NoErrors(env)
	CoreEnv.Logout(env)
	env = Start({ saved = env.KstyleUIDB, cvars = { [SELF] = "0", [STAMPS] = OURS } })
	assert(env._cvars[SELF] == "1" and env._cvars[STAMPS] == "none", "the next login with SetCVar puts the values back")
end)

Case("a refused write keeps the memory and logs once; the next login tries again", function()
	local env = Start({ secure = { [SELF] = true }, saved = Saved({ combatTextCVars = { [MAIN] = { [SELF] = Hidden("1") } } }), cvars = { [SELF] = "0" } })
	assert(env._cvars[SELF] == "0" and Memory(env, "combatTextCVars", MAIN)[SELF], "the refused CVar and its memory stay")
	assert(Logged(env, SELF) == 1, "the refusal is logged once, got " .. Logged(env, SELF))
	NoErrors(env)
	CoreEnv.Logout(env)
	env = Start({ saved = env.KstyleUIDB, cvars = { [SELF] = "0" } })
	assert(env._cvars[SELF] == "1", "the next login puts the value back")
end)

Case("with the real Chat module switched off on another character, the character's timestamps come back at login", function()
	local env, K = C.New({ setup = function(e) e._cvars[STAMPS] = "%I:%M " end })
	C.Enable(env, K)
	local ours = env._cvars[STAMPS]
	assert(ours ~= "%I:%M ", "on: KstyleUI's format")
	CoreEnv.Logout(env)
	local saved = env.KstyleUIDB
	saved.profiles.Default.Chat.enabled = nil
	env, K = C.New({ saved = saved, setup = function(e) e._cvars[STAMPS] = ours end })
	assert(not K.Modules.IsRunning("Chat"), "Chat is off at login")
	Variables(env)
	assert(env._cvars[STAMPS] == "%I:%M ", "the player's format is back: " .. tostring(env._cvars[STAMPS]))
	assert(env.KstyleUIDB.account.chatTimestamps[K.Store.CharacterKey()] == nil, "the memory is cleared")
	NoErrors(env)
end)

assert(#failures == 0, #failures .. " failed:\n" .. table.concat(failures, "\n"))
print("test-cvars: ok")
