-- test-tooltips-combat-anchor.lua: cursor placement outside combat, the placed anchor in combat, and saved position choices.
local T = dofile("Tools/regression/tooltips_env.lua")
local MODE = "cursorOutOfCombat"

local function Enabled(opts)
	local env, K, ns = T.New(opts)
	assert(K.Modules.Enable("Tooltips") and K.Modules.IsRunning("Tooltips"), tostring(env._errors[1]))
	return env, K, ns
end

local function Place(env)
	env.GameTooltip_SetDefaultAnchor(env.GameTooltip, env.UIParent)
end

local function Cursor(env, x, y)
	local tip = env.GameTooltip
	assert(tip:GetOwner() == env.UIParent and tip._anchor[1] == "ANCHOR_CURSOR_RIGHT", "outside combat the tooltip follows the cursor")
	assert(tip._anchor[2] == x and tip._anchor[3] == y, "cursor placement keeps both offsets")
end

local function Fixed(env, ns)
	local tip = env.GameTooltip
	assert(tip._anchor[1] == "ANCHOR_NONE" and select(2, tip:GetPoint(1)) == ns.Anchor.Frame(), "the tooltip sits at the placed anchor")
end

do
	local env, K, ns = Enabled()
	assert(ns.Settings.Get("anchor") == MODE, "a fresh profile defaults to Mouse cursor out of combat")
	local rows = {}
	for _, row in ipairs(K.Options.Get("Tooltips")) do
		rows[row.key or ""] = row
	end
	local choices = {}
	for _, option in ipairs(rows.anchor.options) do
		choices[option.value] = option.label
	end
	assert(choices[MODE] == "Mouse cursor out of combat" and choices.fixed and choices.cursor, "Options offers the new choice and both previous behaviours")
	for _, mode in ipairs({ MODE, "cursor", "fixed" }) do
		for _, key in ipairs({ "cursorX", "cursorY" }) do
			assert(rows[key].showWhen({ anchor = mode }) == (mode ~= "fixed"), "both cursor choices expose the offset sliders")
		end
	end
	K.Options.Write("Tooltips", "cursorX", 12)
	K.Options.Write("Tooltips", "cursorY", -4)
	Place(env)
	Cursor(env, 12, -4)
	env.SetCombat(true)
	Place(env)
	Fixed(env, ns)
	env.SetCombat(false)
	Place(env)
	Cursor(env, 12, -4)
	for _, combat in ipairs({ false, true }) do
		env.SetCombat(combat)
		K.Options.Write("Tooltips", "anchor", "fixed")
		Place(env)
		Fixed(env, ns)
		K.Options.Write("Tooltips", "anchor", "cursor")
		Place(env)
		Cursor(env, 12, -4)
	end
	env.SetCombat(false)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

do
	local _, core = T.New()
	local saved = { version = core.Store.DB_VERSION, profiles = {
		Default = { Tooltips = { cursorX = 7 } },
		Fixed = { Tooltips = { anchor = "fixed" } },
		Cursor = { Tooltips = { anchor = "cursor" } },
	} }
	local env, K, ns = Enabled({ saved = saved })
	assert(ns.Settings.Get("anchor") == MODE and ns.Settings.Get("cursorX") == 7, "an existing profile without a saved anchor inherits the new default")
	for name, mode in pairs({ Fixed = "fixed", Cursor = "cursor" }) do
		assert(K.Store.SetProfile(name))
		assert(ns.Settings.Get("anchor") == mode, "an explicitly saved position is preserved")
	end
	T.W.CoreEnv.Logout(env)
	local env2, K2, ns2 = Enabled({ saved = env.KstyleUIDB })
	assert(K2.Store.SetProfile("Fixed") and ns2.Settings.Get("anchor") == "fixed", "the previous default survives saving and loading when explicitly chosen")
	assert(K2.Store.SetProfile("Cursor") and ns2.Settings.Get("anchor") == "cursor", "the saved cursor choice survives saving and loading")
	assert(#env._errors == 0 and #env2._errors == 0, "profile choices raise no errors")
end

do
	local env, K, ns = Enabled()
	K.Options.Write("Tooltips", "anchor", MODE)
	local api = env.InCombatLockdown
	env.InCombatLockdown = nil
	Place(env)
	Fixed(env, ns)
	env.InCombatLockdown = function() return env.Secret(false) end
	Place(env)
	Fixed(env, ns)
	env.InCombatLockdown = api
	assert(#env._errors == 0, "an unavailable or secret combat state safely uses the placed anchor")
end

print("tooltips combat anchor ok")
