-- test-actionbars-crest-switch.lua: Show the crest off builds no crest and starts no crest listener; on, off, on again, combat, restriction, profile and Frames.
local AB = dofile("Tools/regression/actionbars_env.lua")
local Slots = dofile("Tools/regression/aura_slots.lua")

-- Source: the KSTY-191 plan, part 1 (a crest switch that keeps the crest's code loaded but builds no crest frames,
-- textures or events until it is switched on).
local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local MAKERS = { CreateTexture = true, CreateMaskTexture = true, CreateFontString = true, CreateAnimationGroup = true, CreateAnimation = true, CreateLine = true, SetTexture = true, SetAtlas = true }
-- The hub's PLAYER_ENTERING_WORLD dresses the buttons and stays; its HudStyleChanged, SettingChanged and
-- EffectsLevelChanged callbacks restyle the buttons. Everything else these owners hold belongs to the crest.
local KEPT_EVENTS = { ["ActionBars.Slab PLAYER_ENTERING_WORLD"] = true }
local KEPT_CALLBACKS = { ["ActionBars.Slab HudStyleChanged"] = true, ["ActionBars.Slab SettingChanged"] = true, ["ActionBars.Slab EffectsLevelChanged"] = true }
-- Slab.lua also builds the slab plate, the side plates and every button's Medallions dressing and slot proc, which
-- stay with the crest off; anything else it makes belongs to the crest.
local SHARED = { Plate = true, LayPlate = true, BuildSlab = true, BuildPlate = true, PlaceSides = true, Dress = true, SlotLayer = true, Socket = true, SocketMask = true, Inset = true, Press = true, Keybind = true, ProcParts = true, ProcLoop = true }

local function CrestOwner(owner)
	return owner == "ActionBars.Slab" or owner:find("^ActionBars%.Slab") ~= nil or owner:find("^ActionBars%.Travel") ~= nil or owner == "SlabEffects"
end

-- Slab.lua's region and animation helpers serve both; the builder that called them decides.
local HELPERS = { Region = true, Group = true, Fade = true, Grow = true, Flipbook = true, Turn = true, Each = true, Play = true, Texture = true }

-- The nearest action bars file on the stack owns a call: every Slab*.lua and the travel button's files are the
-- crest's. In Slab.lua the nearest function past the helpers decides: the shared work above, or the crest's.
-- The core's event dispatch frame is the listeners' check's, not this one's.
local function CrestFile()
	if (debug.getinfo(3, "S").source or ""):find("Core/Events.lua", 1, true) then return false end
	for level = 3, 60 do
		local info = debug.getinfo(level, "Sn")
		if not info then return false end
		local file = (info.source or ""):match("KstyleUI_ActionBars/([%w_]+)%.lua")
		if file == "Slab" then
			if not HELPERS[info.name or ""] then return not SHARED[info.name or ""] end
		elseif file then
			return file:find("^Slab") ~= nil or file:find("^Travel") ~= nil
		end
	end
	return false
end

local function Watch(env, K)
	local seen = { made = 0, live = {}, callbacks = {}, rest = {} }
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
		if CrestOwner(owner) and not KEPT_CALLBACKS[key] then list[#list + 1] = key end
	end
	for fn in pairs(seen.rest) do list[#list + 1] = "rest callback " .. tostring(debug.getinfo(fn, "S").short_src) .. ":" .. debug.getinfo(fn, "S").linedefined end
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
	local seen
	local env, K, ns = AB.New({ width = 2560, height = 1440, class = class, saved = saved, setup = function(e)
		e.C_Secrets = { ShouldAurasBeSecret = function() return e._aurasSecret == true end }
		if opts.setup then opts.setup(e) end
	end, beforeAddon = function(e, core)
		seen = Watch(e, core)
		core.Widgets.ReloadPrompt = function(text) prompted[#prompted + 1] = text end
		-- The rest callbacks' subscribe and unsubscribe are wrapped as SlabMedals.lua defines them, so a file that
		-- subscribes while it loads is seen too.
		local rest = {
			OnRest = function(fn) return function(each)
				if CrestFile() then seen.rest[each] = true end
				return fn(each)
			end end,
			OffRest = function(fn) return function(each)
				seen.rest[each] = nil
				return fn(each)
			end end,
		}
		e._addons = e._addons or {}
		e._addons.KstyleUI_ActionBars = setmetatable({}, { __newindex = function(ns, key, value)
			if key == "SlabMedals" then
				setmetatable(value, { __newindex = function(medals, name, fn)
					rawset(medals, name, rest[name] and rest[name](fn) or fn)
				end })
			end
			rawset(ns, key, value)
		end })
	end })
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

-- A mage who can conjure a mana gem and carries one: the crest hangs the gem with its low-mana glow.
local function Mage(e)
	e._known = { [759] = true }
	e.C_SpellBook = e.C_SpellBook or {}
	e.C_SpellBook.IsSpellKnown = function(id) return e._known[id] == true end
	e.C_Item = e.C_Item or {}
	e.C_Item.GetItemCount = function(id) return id == 5514 and 1 or 0 end
	e.C_Item.GetItemIconByID = function(id) return 5000000 + id end
	e.C_Item.GetItemCooldown = function() return 0, 0, true end
	e.C_Spell.IsSpellUsable = function() return false, false end
	e.C_Spell.GetSpellCooldown = function() return { isActive = false, isOnGCD = false } end
	e.C_Spell.GetSpellCooldownDuration = function() return { start = 0, finish = 0 } end
	e.Enum.PowerType = e.Enum.PowerType or { Mana = 0 }
	e.UnitPowerPercent = function() return 0.25 end
	e.C_CurveUtil = { CreateCurve = function() return { AddPoint = function() end, SetType = function() end } end }
	e.C_DurationUtil = { CreateDuration = function() return { SetTimeFromStart = function(d, start, duration) d.start, d.duration = start, duration end } end }
end

local function Gem(ns)
	local form = ns.SlabTrackers.state.forms.crest
	for _, p in pairs(form and form.pieces or {}) do
		if p.lowMana then return p end
	end
end

-- On, off, on again, out of combat.
do
	local env, K, ns, seen, prompted = Start("MAGE", { crest = false }, { setup = Mage })
	K.Options.Write("ActionBars", "crest", true)
	env.RunTimers()
	assert(Gem(ns), "switched on, the mage's crest hangs the mana gem with its low-mana glow")
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

-- Combat: switching on waits for combat to end, even through a loading screen or a bar refresh, because the
-- travel button is secure; switching off hides the crest and stops its listeners at once, and only the secure
-- travel button waits for combat to end.
do
	local env, K, ns, seen, prompted = Start("WARRIOR", { crest = false })
	env.SetCombat(true)
	K.Options.Write("ActionBars", "crest", true)
	env.RunTimers()
	assert(ns.Slab.hub == nil and #Listening(seen) == 0, "switched on in combat, the crest waits")
	env.FireEvent("PLAYER_ENTERING_WORLD", false, false)
	ns.bars.bar1:RefreshSlab(true)
	env.RunTimers()
	assert(ns.Slab.hub == nil and seen.made == 0 and #Listening(seen) == 0, "a loading screen or a bar refresh in combat does not build the waiting crest")
	env.SetCombat(false)
	env.RunTimers()
	assert(ns.Slab.hub and ns.Slab.hub:IsShown() and ns.Travel.crest and ns.Travel.crest:IsShown(), "when combat ends, the crest and its travel button build")
	assert(ns.Slab.InCombat() == false, "the hub reads combat when it starts")

	env.SetCombat(true)
	assert(ns.Slab.InCombat() == true, "the shown crest hears combat start")
	local sweeps = ns.Slab.frame.sweeps
	assert(sweeps and sweeps[1].anim:IsPlaying(), "combat starts the crest's sweeps along the slab")
	K.Options.Write("ActionBars", "crest", false)
	env.RunTimers()
	assert(not ns.Slab.hub:IsShown(), "switched off in combat, the crest hides at once")
	assert(not ns.Slab.hub.glow.breath:IsPlaying() and K.Effects.Holder("hub") == nil, "switched off in combat, its motion and effects stop at once")
	for _, sweep in ipairs(sweeps) do assert(not sweep.anim:IsPlaying() and sweep:GetAlpha() == 0, "switched off in combat, the sweeps stop at once") end
	OnlyWaiting(seen, "switched off in combat")
	assert(ns.Travel.crest:IsShown(), "the secure travel button waits for combat to end")
	env.SetCombat(false)
	env.RunTimers()
	assert(not ns.Travel.crest:IsShown() and #Listening(seen) == 0, "when combat ends, the travel button hides and nothing of the crest listens")
	assert(#prompted == 1, "switched off after it was built, the crest offers a reload")

	-- The hub stopped listening in that fight, so it never heard it end: it reads combat again before its first paint.
	local breath = ns.Slab.hub.glow.breath
	local before = #AB.W.Calls(breath, "SetAnimationSpeedMultiplier")
	K.Options.Write("ActionBars", "crest", true)
	env.RunTimers()
	local first = AB.W.Calls(breath, "SetAnimationSpeedMultiplier")[before + 1]
	assert(ns.Slab.hub:IsShown() and ns.Slab.InCombat() == false, "switched on after a fight it stopped listening in, the crest reads that combat is over")
	assert(first and first[1] ~= 2.25, "and its first paint breathes at the calm speed, not combat's 2.25")
	Clean(env, K, "combat")
end

-- A hidden hub claims nothing: a proc while the slab hides the crest, or after the switch is off, lights only its
-- slot; switching off releases a claim already running; the rings stop listening whenever the hub hides.
do
	local env, K, ns, seen = Start("PALADIN", {})
	local b = ns.actionButtons[1]
	local function Rings()
		return seen.live["ActionBars.SlabRings UNIT_SPELLCAST_START"] ~= nil
	end
	assert(Rings(), "the shown crest's cast ring listens")
	K.Options.Write("ActionBars", "slab", false)
	env.RunTimers()
	assert(not ns.Slab.hub:IsShown() and not Rings(), "with the slab off the hub hides and its cast ring stops listening")
	ns.Button.SetProc(b, true)
	assert(K.Effects.Holder("hub") == nil, "a proc claims nothing on the hub the slab hides")
	ns.Button.SetProc(b, false)
	K.Options.Write("ActionBars", "slab", true)
	env.RunTimers()
	ns.Button.SetProc(b, true)
	assert(K.Effects.Holder("hub") ~= nil, "a proc claims the shown hub")
	K.Options.Write("ActionBars", "crest", false)
	assert(K.Effects.Holder("hub") == nil, "switching off releases the hub's running claim")
	ns.Button.SetProc(b, false)
	env.RunTimers()
	ns.Button.SetProc(b, true)
	assert(b.medProc and b.medProc:IsShown(), "the slot still lights its proc")
	assert(K.Effects.Holder("hub") == nil, "the switched-off crest claims no effect for it")
	ns.Button.SetProc(b, false)
	Clean(env, K, "hidden hub")
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
	assert(K.Store.SetProfile("Default"))
	env.RunTimers()
	env.SetCombat(true)
	assert(K.Store.SetProfile("Plain"))
	assert(not ns.Slab.hub:IsShown(), "a profile with the crest off, picked in combat, hides the crest at once")
	OnlyWaiting(seen, "a profile picked in combat")
	env.SetCombat(false)
	env.RunTimers()
	assert(#Listening(seen) == 0, "when combat ends, nothing of the crest listens")
	Clean(env, K, "profiles")
end

-- Frames: the switch belongs to Medallions; the Frames row, the totem bar, the stance rim and their listeners run
-- as they do with the crest on.
local function Warrior(e)
	e._known = { [25289] = true, [20662] = true, [2687] = true }
	e.C_SpellBook = e.C_SpellBook or {}
	e.C_SpellBook.IsSpellKnown = function(id) return e._known[id] == true end
	e.C_Spell.IsSpellUsable = function() return false, false end
	e.C_Spell.GetSpellCooldown = function() return { isActive = false, isOnGCD = false } end
	e.C_Spell.GetSpellCooldownDuration = function() return { start = 0, finish = 0 } end
	e.C_Spell.GetSpellTexture = function(id) return 100000 + id end
	e.C_DurationUtil = { CreateDuration = function() return { SetTimeFromStart = function(d, start, duration) d.start, d.duration = start, duration end } end }
	e.GetShapeshiftFormID = function() return 18 end
	e._slotGroups = true
	Slots.Install(e)
	e.AuraContainerSortMethod, e.AuraContainerSortDirection = { Default = 0, AuraInstanceIDOnly = 8 }, { Normal = 0, Reverse = 1 }
	e._game.forms = { { texture = 1, isActive = false, spellID = 2457 }, { texture = 2, isActive = true, spellID = 71 }, { texture = 3, isActive = false, spellID = 2458 } }
end

local function Shaman(e)
	local spells = { [1] = { 3599, 8190, 8227 }, [2] = { 8075, 8071, 2484 }, [3] = { 5394 }, [4] = { 8512 } }
	e._known = { [66842] = true, [36936] = true }
	e.C_ActionBar.GetMultiCastBarIndex = function() return 12 end
	e.GetMultiCastTotemSpells = function(slot) return unpack(spells[slot] or {}) end
	e.GetTotemInfo = function() return false, "", 0, 0, 0 end
	e.GetTotemDuration = function() return { start = 0, finish = 0 } end
	e.C_SpellBook = e.C_SpellBook or {}
	e.C_SpellBook.IsSpellKnown = function(id) return e._known[id] == true end
	e._game.forms[1] = { texture = 136095, isActive = false, spellID = 2645 }
	e.CreateFrame("Frame", "MultiCastActionBarFrame", e.UIParent)
end

do
	local rows = {}
	for _, crest in ipairs({ true, false }) do
		local where = "Frames with the crest " .. (crest and "on" or "off")
		local env, K, ns, seen = Start("WARRIOR", { crest = crest }, { style = "frames", setup = Warrior })
		env.FireEvent("UPDATE_SHAPESHIFT_FORMS")
		env.FireEvent("UPDATE_SHAPESHIFT_FORM")
		env.RunTimers()
		assert(ns.Slab.hub == nil, where .. " builds no crest hub")
		local row, seats = ns.SlabTrackers.state.forms.row, {}
		for key, p in pairs(row and row.pieces or {}) do
			if p:IsVisible() then seats[tonumber(key:match("^(%d+)"))] = true end
		end
		assert(row and row.frame:IsShown() and seats[1] and seats[2] and seats[3] and not seats[4], where .. " shows the three medals of the tracker row")
		assert(ns.stanceButtons[2].mantle and not ns.stanceButtons[1].mantle, where .. " tints the active stance button's rim")
		rows[crest] = table.concat(Listening(seen), ", ")
		Clean(env, K, where)
		if not crest then
			K.Options.Write("HudStyle", "style", "medallions")
			env.RunTimers()
			assert(ns.Slab.hub == nil and #Listening(seen) == 0, "moving to Medallions with the crest off builds and starts nothing")
			Clean(env, K, "Frames to Medallions")
		end
	end
	assert(rows[true] ~= "" and rows[true] == rows[false], "Frames listens the same with the crest on or off: " .. rows[false])

	local env, K, ns, seen = Start("SHAMAN", { crest = false }, { style = "frames", setup = Shaman })
	local st = ns.Totems.state
	assert(st.shown and st.header:IsShown() and #st.sockets == 4, "Frames with the crest off keeps the shaman's totem bar")
	K.Options.Write("HudStyle", "style", "medallions")
	env.RunTimers()
	assert(ns.Slab.hub == nil and not st.shown and not st.header:IsShown(), "moving to Medallions with the crest off closes the totem row with no crest to seat it")
	assert(not seen.live["ActionBars.Totems PLAYER_TOTEM_UPDATE"], "and the totem row stops listening")
	Clean(env, K, "Frames totems to Medallions")
end

-- A shaman's totems sit on the crest in secure frames anchored to it. Switched off in combat, the crest and the
-- totems fade and stop listening at once; the protected hide and the totem frames wait for combat to end.
do
	local env, K, ns, seen = Start("SHAMAN", {}, { setup = Shaman })
	local st, hub = ns.Totems.state, ns.Slab.hub
	assert(st.shown and ns.Totems.OnCrest() and st.header:IsShown(), "the shaman's totems sit on the crest")
	env.SetCombat(true)
	K.Options.Write("ActionBars", "crest", false)
	assert(hub:GetAlpha() == 0 and st.header:GetAlpha() == 0, "switched off in combat, the crest and its totems fade at once")
	assert(hub:IsShown() and st.header:IsShown(), "the crest the totems are anchored to and the secure totems themselves wait for combat to end to hide")
	assert(not seen.live["ActionBars.Totems PLAYER_TOTEM_UPDATE"] and not hub.glow.breath:IsPlaying(), "the totems stop listening and the crest stops moving at once")
	OnlyWaiting(seen, "a shaman switched off in combat")
	assert(#env._blocked == 0, "nothing protected is touched in combat: " .. table.concat(env._blocked, ", "))
	env.SetCombat(false)
	env.RunTimers()
	AB.W.Tick(env, 1)
	assert(not hub:IsShown() and not st.shown and not st.header:IsShown(), "when combat ends, the crest and the totems hide")
	assert(hub:GetAlpha() == K.Layout.Rest.Level("actionbars.bar1"), "and the crest takes back its rest opacity")
	assert(#Listening(seen) == 0 and not seen.live["ActionBars.Totems PLAYER_TOTEM_UPDATE"], "and nothing of them listens")
	K.Options.Write("ActionBars", "crest", true)
	env.RunTimers()
	assert(hub:IsShown() and hub:GetAlpha() == K.Layout.Rest.Level("actionbars.bar1") and st.shown and st.header:IsShown() and st.header:GetAlpha() == 1, "switched on again, the crest and its totems come back whole")
	Clean(env, K, "shaman in combat")
end

-- The clean screen eases the crest with bar 1. Its rest opacity stands through a bar refresh, and a rest wake still
-- easing as combat starts never shows a crest switched off in combat.
do
	local env, K, ns = Start("SHAMAN", {}, { setup = Shaman })
	local hub, Rest = ns.Slab.hub, K.Layout.Rest
	env.SetCombat(true)
	env.SetCombat(false)
	env.RunTimers()
	AB.W.Tick(env, 1)
	assert(Rest.Quiet() and Rest.Level("actionbars.bar1") == 0.35 and hub:GetAlpha() == 0.35, "at rest the crest sits at the clean screen's opacity")
	ns.bars.bar1:RefreshSlab()
	assert(hub:GetAlpha() == 0.35, "a bar refresh keeps the crest at its rest opacity")
	env.SetCombat(true)
	K.Options.Write("ActionBars", "crest", false)
	AB.W.Tick(env, 1)
	assert(hub:IsShown() and hub:GetAlpha() == 0, "the wake that combat started leaves the crest switched off in combat unseen")
	Clean(env, K, "the crest at rest")
end

-- The secure totems anchored to the crest pin its place in combat. A bar refresh in combat leaves the crest where it
-- is until combat ends; totems switched off let go of the crest, so it then hides at once.
do
	local env, K, ns = Start("SHAMAN", {}, { setup = Shaman })
	local hub, st = ns.Slab.hub, ns.Totems.state
	local function Moves()
		return #AB.W.Calls(hub, "SetPoint") + #AB.W.Calls(hub, "SetScale") + #AB.W.Calls(hub, "Show")
	end
	env.SetCombat(true)
	local moves = Moves()
	ns.bars.bar1:RefreshSlab()
	assert(Moves() == moves, "with the totems on it, a bar refresh in combat neither moves nor shows the crest")
	env.SetCombat(false)
	env.RunTimers()
	assert(Moves() > moves, "the crest takes its place when combat ends")
	K.Options.Write("ActionBars", "totemBar", false)
	env.RunTimers()
	local held = st.header:GetNumPoints() + st.wolf:GetNumPoints() + st.call:GetNumPoints()
	for _, b in ipairs(st.sockets) do
		held = held + b:GetNumPoints() + b.spire:GetNumPoints() + b.fan:GetNumPoints()
		for _, f in ipairs(b.fan.buttons) do held = held + f:GetNumPoints() end
	end
	assert(not st.shown and held == 0 and not ns.Totems.OnCrest(), "totems switched off let go of the crest")
	env.SetCombat(true)
	K.Options.Write("ActionBars", "crest", false)
	assert(not hub:IsShown(), "so the crest switched off in combat hides at once")
	Clean(env, K, "totems pin the crest")
end

print("ok crest switch")
