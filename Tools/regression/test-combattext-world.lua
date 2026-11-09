-- test-combattext-world.lua: KstyleUI_CombatText sets DAMAGE_TEXT_FONT at load while it is switched on, so the game's own numbers use the KstyleUI font from the next login.
local CT = dofile("Tools/regression/combattext_env.lua")

local BLIZZARD = "Fonts\\FRIZQT__.TTF"

-- Switched on: the font is set while the module's files load, before PLAYER_LOGIN ------------------

do
	local seen
	local env, K = CT.New({
		saved = CT.Saved({ enabled = true }),
		login = false,
	})
	seen = env.DAMAGE_TEXT_FONT
	assert(seen == (K.Tokens.Font("number")), "the switched-on module sets DAMAGE_TEXT_FONT at load, got " .. tostring(seen))
	assert(not K.Modules.IsRunning("CombatText"), "setting the font starts nothing before login")
	CT.CoreEnv.Login(env)
	env.RunTimers()
	assert(K.Modules.IsRunning("CombatText"), "the module starts at login")
	assert(env.DAMAGE_TEXT_FONT == seen, "login keeps the font")
	K.Modules.Disable("CombatText")
	assert(env.DAMAGE_TEXT_FONT == BLIZZARD, "turning the module off puts Blizzard's font back for the next login")
end

-- Switched off: nothing changes ------------------------------------------------------------------

do
	local env = CT.New()
	assert(env.DAMAGE_TEXT_FONT == BLIZZARD, "a module that is off leaves DAMAGE_TEXT_FONT alone")
end

-- The world font can be turned off or changed ----------------------------------------------------

do
	local env = CT.New({ saved = CT.Saved({ enabled = true, worldFont = false }) })
	assert(env.DAMAGE_TEXT_FONT == BLIZZARD, "worldFont = false leaves the game's font")
end

do
	local inter = "Interface\\AddOns\\KstyleUI\\Media\\Fonts\\Inter-SemiBold.ttf"
	local env, K = CT.New({ saved = CT.Saved({ enabled = true, worldFace = inter }) })
	assert(env.DAMAGE_TEXT_FONT == inter, "the chosen world font is used")
	local before = #env._printed
	K.Options.Write("CombatText", "worldFace", K.Tokens.FontPath("SourceSans3Regular"))
	assert(env.DAMAGE_TEXT_FONT == K.Tokens.FontPath("SourceSans3Regular"), "a new choice applies to the next login")
	assert(#env._printed == before + 1 and env._printed[#env._printed]:find("next login", 1, true), "the player is told it changes at the next login")
	K.Options.Write("CombatText", "worldFont", false)
	assert(env.DAMAGE_TEXT_FONT == BLIZZARD, "switching the world font off restores Blizzard's")
end

-- A saved path that is not a font falls back to the default --------------------------------------

do
	local env, K = CT.New({ saved = CT.Saved({ enabled = true, worldFace = "Interface\\Icons\\Spell.blp" }) })
	assert(env.DAMAGE_TEXT_FONT == (K.Tokens.Font("number")), "a saved world font that is not a font file uses the default")
end

-- The setting's help text says the change waits for the next login -------------------------------

do
	local _, K = CT.New()
	local row = K.Options.Row("CombatText", "worldFont")
	assert(row and row.help:find("next login", 1, true), "the world font option says it applies at the next login")
end

print("combat text world font ok")
