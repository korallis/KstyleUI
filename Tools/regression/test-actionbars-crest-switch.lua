-- test-actionbars-crest-switch.lua: Show the crest off builds no crest and starts no crest listener; on, off, on again, combat, restriction, profile and Frames.
local AB = dofile("Tools/regression/actionbars_env.lua")

-- Source: the KSTY-191 plan, part 1 (a crest switch that keeps the crest's code loaded but builds no crest frames,
-- textures or events until it is switched on).
local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local MAKERS = { CreateTexture = true, CreateMaskTexture = true, CreateFontString = true, CreateAnimationGroup = true, CreateAnimation = true, CreateLine = true, SetTexture = true, SetAtlas = true }
-- The hub's PLAYER_ENTERING_WORLD dresses the buttons and stays; its HudStyleChanged, SettingChanged and
-- EffectsLevelChanged callbacks restyle the buttons. Everything else these owners hold belongs to the crest.
local KEPT_EVENTS = { ["ActionBars.Slab PLAYER_ENTERING_WORLD"] = true }
local KEPT_CALLBACKS = { ["ActionBars.Slab"] = true }

local function CrestOwner(owner)
	return owner == "ActionBars.Slab" or owner:find("^ActionBars%.Slab") ~= nil or owner:find("^ActionBars%.Travel") ~= nil or owner == "SlabEffects"
end

-- The nearest action bars file on the stack owns a call; crest files are every Slab*.lua but the slab and dressing
-- file itself, and the travel button's files.
local function CrestFile()
	for level = 3, 40 do
		local info = debug.getinfo(level, "S")
		if not info then return false end
		local file = (info.source or ""):match("KstyleUI_ActionBars/([%w_]+)%.lua")
		if file then
			return file ~= "Slab" and (file:find("^Slab") ~= nil or file:find("^Travel") ~= nil)
		end
	end
	return false
end

local function Watch(env, K)
	local seen = { made = 0, live = {}, callbacks = {} }
	local create = env.CreateFrame
	env.CreateFrame = function(...)
		if CrestFile() then seen.made = seen.made + 1 end
		return create(...)
	end
	local meta = getmetatable(env.UIParent)
	local index, wrapped = meta.__index, {}
	meta.__index = function(object, key)
		local fn = index(object, key)
		if type(fn) ~= "function" or not MAKERS[key] then return fn end
		wrapped[key] = wrapped[key] or function(self, first, ...)
			if CrestFile() and (first ~= nil or key ~= "SetTexture" and key ~= "SetAtlas") then seen.made = seen.made + 1 end
			return index(self, key)(self, first, ...)
		end
		return wrapped[key]
	end
	local Events = K.Events
	local reg, regUnit, unreg, unregAll = Events.Register, Events.RegisterUnit, Events.Unregister, Events.UnregisterAll
	Events.Register = function(owner, event, ...)
		seen.live[owner .. " " .. event] = owner
		return reg(owner, event, ...)
	end
	Events.RegisterUnit = function(owner, event, ...)
		seen.live[owner .. " " .. event] = owner
		return regUnit(owner, event, ...)
	end
	Events.Unregister = function(owner, event, ...)
		seen.live[owner .. " " .. event] = nil
		return unreg(owner, event, ...)
	end
	Events.UnregisterAll = function(owner, ...)
		for key, who in pairs(seen.live) do
			if who == owner then seen.live[key] = nil end
		end
		return unregAll(owner, ...)
	end
	local cbReg, cbUnreg = K.Callbacks.Register, K.Callbacks.Unregister
	K.Callbacks.Register = function(name, owner, ...)
		seen.callbacks[owner .. " " .. name] = owner
		return cbReg(name, owner, ...)
	end
	K.Callbacks.Unregister = function(name, owner, ...)
		seen.callbacks[owner .. " " .. name] = nil
		return cbUnreg(name, owner, ...)
	end
	return seen
end

local function Listening(seen)
	local list = {}
	for key, owner in pairs(seen.live) do
		if CrestOwner(owner) and not KEPT_EVENTS[key] then list[#list + 1] = key end
	end
	for key, owner in pairs(seen.callbacks) do
		if CrestOwner(owner) and not KEPT_CALLBACKS[owner] then list[#list + 1] = key end
	end
	table.sort(list)
	return list
end

-- A piece Blizzard's guarded aura buttons hold in combat or while auras are secret tears down when they lift.
local function OnlyWaiting(seen, when)
	for _, key in ipairs(Listening(seen)) do
		assert(key:find(" ADDON_RESTRICTION_STATE_CHANGED$") or key:find(" PLAYER_REGEN_ENABLED$"), when .. ", a crest piece waits only for the restriction to lift: " .. key)
	end
end

local function Start(class, ab, opts)
	opts = opts or {}
	local prompted = {}
	local saved = { version = 49, profiles = { Default = { HudStyle = { style = opts.style or "medallions" }, ActionBars = ab } } }
	local env, K, ns = AB.New({ width = 2560, height = 1440, class = class, saved = saved, setup = function(e)
		e.C_Secrets = { ShouldAurasBeSecret = function() return e._aurasSecret == true end }
	end })
	local seen = Watch(env, K)
	K.Widgets.ReloadPrompt = function(text) prompted[#prompted + 1] = text end
	AB.Enable(env, K)
	env.FireEvent("PLAYER_ENTERING_WORLD", true, false)
	env.RunTimers()
	return env, K, ns, seen, prompted
end

local function Clean(env, K, what)
	assert(#env._errors == 0 and K.ErrorCount() == 0, what .. ": " .. AB.Errors(env))
end

-- Off from login, every class: the slab plate seats bars 1 and 2, and no crest piece or crest listener exists.
for _, class in ipairs(CLASSES) do
	local env, K, ns, seen, prompted = Start(class, { crest = false })
	local where = class .. " with the crest off from login"
	assert(ns.Slab.frame and ns.Slab.frame:IsShown(), where .. " still shows the slab plate")
	assert(ns.Slab.hub == nil, where .. " builds no crest hub")
	assert(seen.made == 0, where .. " makes " .. seen.made .. " frames, regions, animations or texture calls in crest files")
	local left = Listening(seen)
	assert(#left == 0, where .. " still listens: " .. table.concat(left, ", "))
	assert(seen.live["ActionBars.Slab PLAYER_ENTERING_WORLD"], where .. " keeps the event that dresses the buttons")
	assert(ns.actionButtons[1].medFrame and ns.actionButtons[1].medFrame:IsShown(), where .. " keeps the Medallions button dressing")
	assert(#prompted == 0, where .. " offers no reload")
	Clean(env, K, where)
end

-- On, off, on again, out of combat.
do
	local env, K, ns, seen, prompted = Start("MAGE", { crest = false })
	K.Options.Write("ActionBars", "crest", true)
	env.RunTimers()
	local hub = ns.Slab.hub
	assert(hub and hub:IsShown(), "switched on, the crest builds and shows at once out of combat")
	assert(seen.made > 0, "switched on, the crest files build their pieces")
	assert(seen.live["ActionBars.Slab PLAYER_REGEN_DISABLED"] and seen.live["ActionBars.Travel SPELLS_CHANGED"] and seen.callbacks["ActionBars.SlabRings SettingChanged"], "switched on, the hub, travel button and rings listen")
	assert(ns.Travel.crest and ns.Travel.crest:IsShown(), "switched on, the travel button covers the crest")
	assert(ns.Slab.InCombat() == false, "the hub reads combat when it starts")

	K.Options.Write("ActionBars", "crest", false)
	env.RunTimers()
	assert(ns.Slab.hub == hub and not hub:IsShown(), "switched off, the built crest hides")
	assert(ns.Slab.frame:IsShown(), "switched off, the slab plate stays")
	assert(not hub.glow.breath:IsPlaying() and not hub.runes.turn:IsPlaying() and not hub.sheen.run:IsPlaying(), "switched off, the crest's loops stop")
	for _, p in ipairs(hub.particles) do assert(not p.anim:IsPlaying() and not p:IsShown(), "switched off, the crest's particles stop") end
	assert(K.Effects.Holder("hub") == nil, "switched off, the crest gives up its ambient effect")
	assert(not ns.Travel.crest:IsShown(), "switched off, the travel button hides")
	local left = Listening(seen)
	assert(#left == 0, "switched off, the crest still listens: " .. table.concat(left, ", "))
	assert(#prompted == 1 and prompted[1] == K.L["The crest is hidden. Reload to free its memory."], "switched off after it was built, the crest offers a reload")

	local made = seen.made
	K.Options.Write("ActionBars", "crest", true)
	env.RunTimers()
	assert(ns.Slab.hub == hub and hub:IsShown(), "switched on again, the same crest shows")
	assert(seen.made - made == 0, "switched on again, the crest builds nothing new: " .. (seen.made - made))
	assert(seen.live["ActionBars.Slab PLAYER_LEVEL_UP"] and seen.live["ActionBars.Travel BAG_UPDATE_DELAYED"], "switched on again, the crest listens again")
	assert(#prompted == 1, "switching on offers no reload")
	Clean(env, K, "on, off, on")
end

-- Combat: the switch waits for combat to end both ways, because the travel button is secure.
do
	local env, K, ns, seen, prompted = Start("WARRIOR", { crest = false })
	env.SetCombat(true)
	K.Options.Write("ActionBars", "crest", true)
	env.RunTimers()
	assert(ns.Slab.hub == nil and #Listening(seen) == 0, "switched on in combat, the crest waits")
	env.SetCombat(false)
	env.RunTimers()
	assert(ns.Slab.hub and ns.Slab.hub:IsShown() and ns.Travel.crest and ns.Travel.crest:IsShown(), "when combat ends, the crest and its travel button build")
	assert(ns.Slab.InCombat() == false, "the hub reads combat when it starts")
	env.SetCombat(true)
	K.Options.Write("ActionBars", "crest", false)
	env.RunTimers()
	assert(ns.Slab.hub:IsShown() and ns.Travel.crest:IsShown(), "switched off in combat, the crest stays until combat ends")
	env.SetCombat(false)
	env.RunTimers()
	assert(not ns.Slab.hub:IsShown() and not ns.Travel.crest:IsShown(), "when combat ends, the crest and its travel button hide")
	assert(#Listening(seen) == 0 and #prompted == 1, "when combat ends, the crest stops listening and offers a reload")

	-- A loading screen in combat applies a switch already saved: the hub hides and stops listening at once, still
	-- in combat, so it never hears that combat ended; the secure travel button waits for the end of combat.
	K.Options.Write("ActionBars", "crest", true)
	env.RunTimers()
	env.SetCombat(true)
	assert(ns.Slab.InCombat() == true, "the shown crest hears combat start")
	K.Options.Write("ActionBars", "crest", false)
	env.FireEvent("PLAYER_ENTERING_WORLD", false, false)
	env.RunTimers()
	assert(not ns.Slab.hub:IsShown(), "a loading screen in combat hides the crest at once")
	OnlyWaiting(seen, "in combat")
	assert(ns.Travel.crest:IsShown(), "the secure travel button waits for combat to end")
	env.SetCombat(false)
	env.RunTimers()
	assert(not ns.Travel.crest:IsShown() and #Listening(seen) == 0, "when combat ends, the travel button hides and nothing of the crest listens")
	K.Options.Write("ActionBars", "crest", true)
	env.RunTimers()
	assert(ns.Slab.hub:IsShown() and ns.Slab.InCombat() == false, "switched on after a fight it stopped listening in, the crest reads that combat is over")
	Clean(env, K, "combat")
end

-- Restriction: aura data goes secret before combat; switching the crest while it is secret and after it lifts.
do
	local env, K, ns, seen = Start("SHAMAN", {})
	env._aurasSecret = true
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED", 0, 1)
	K.Options.Write("ActionBars", "crest", false)
	env.RunTimers()
	assert(not ns.Slab.hub:IsShown(), "switched off while auras are secret, the crest hides")
	OnlyWaiting(seen, "while auras are secret")
	env._aurasSecret = false
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED", 1, 0)
	env.RunTimers()
	assert(#Listening(seen) == 0, "once the restriction lifts, the crest stops listening: " .. table.concat(Listening(seen), ", "))
	env._aurasSecret = true
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED", 0, 1)
	K.Options.Write("ActionBars", "crest", true)
	env.RunTimers()
	assert(ns.Slab.hub:IsShown() and seen.live["ActionBars.SlabRings ADDON_RESTRICTION_STATE_CHANGED"], "switched on while auras are secret, the crest shows and waits on the restriction")
	env._aurasSecret = false
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED", 1, 0)
	env.RunTimers()
	assert(ns.Slab.hub:IsShown(), "the crest stays once the restriction lifts")
	Clean(env, K, "restriction")
end

-- Profiles follow their own switch.
do
	local env, K, ns, seen, prompted = Start("ROGUE", {})
	assert(K.Store.CopyProfile(K.Store.ProfileName(), "Plain"))
	assert(K.Store.SetProfile("Plain"))
	K.Options.Write("ActionBars", "crest", false)
	env.RunTimers()
	assert(K.Store.SetProfile("Default"))
	env.RunTimers()
	assert(ns.Slab.hub:IsShown() and seen.live["ActionBars.Slab PLAYER_REGEN_ENABLED"], "a profile with the crest on shows it")
	assert(K.Store.SetProfile("Plain"))
	env.RunTimers()
	assert(not ns.Slab.hub:IsShown() and #Listening(seen) == 0, "a profile with the crest off hides it and stops its listeners")
	assert(#prompted == 2, "each switch off after a build offers a reload")
	Clean(env, K, "profiles")
end

-- Frames: the switch belongs to Medallions; the Frames row and its listeners run as they do with the crest on.
do
	local rows = {}
	for _, crest in ipairs({ true, false }) do
		local env, K, ns, seen = Start("WARRIOR", { crest = crest }, { style = "frames" })
		assert(ns.Slab.hub == nil, "Frames builds no crest hub")
		rows[crest] = table.concat(Listening(seen), ", ")
		Clean(env, K, "Frames")
		if not crest then
			K.Options.Write("HudStyle", "style", "medallions")
			env.RunTimers()
			assert(ns.Slab.hub == nil and #Listening(seen) == 0, "moving to Medallions with the crest off builds and starts nothing")
			Clean(env, K, "Frames to Medallions")
		end
	end
	assert(rows[true] ~= "" and rows[true] == rows[false], "Frames listens the same with the crest on or off: " .. rows[false])
end

print("ok crest switch")
