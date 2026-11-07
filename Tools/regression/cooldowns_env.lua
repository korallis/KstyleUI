-- cooldowns_env.lua: load the core and KstyleUI_Cooldowns into a stub environment with a fake Cooldown Manager.
--
--   local C = dofile("Tools/regression/cooldowns_env.lua")
--   local env, K, ns = C.New({ cooldowns = C.Sample() })  -- core booted, module registered, not enabled
--   C.Enable(env, K)                                       -- Modules.Enable("Cooldowns")
--
-- The fake game keeps its state on env._cdm: cooldown info by ID, the category sets, the Blizzard settings
-- provider, spell cooldown state, durations and the calls the module made.
local W = dofile("Tools/regression/widget_env.lua")
local TocFiles = dofile("Tools/regression/toc_files.lua")
local Load = dofile("Tools/regression/load_files.lua")
local CoreEnv = W.CoreEnv

local C = {}
C.W = W
C.CoreEnv = CoreEnv

C.CATEGORY = {
	Essential = 0, Utility = 1, TrackedBuff = 2, TrackedBar = 3, GroupBuff = 4,
	SpecAgnosticEssential = 5, SpecAgnosticTracked = 6, EquipSlotEssential = 7, EquipSlotTracked = 8,
}
C.FLAGS = { HideAura = 1, HideByDefault = 2, SelectHighestLevelLinkedSpell = 4 }
-- Blizzard's settings provider moves a cooldown hidden by default into a pseudo-category outside the enum.
C.HIDDEN = -1

local moduleFiles
function C.Files()
	if not moduleFiles then
		moduleFiles = {}
		for _, path in ipairs(TocFiles("%.lua$")) do
			if path:match("^KstyleUI_Cooldowns/") then
				moduleFiles[#moduleFiles + 1] = path
			end
		end
	end
	return moduleFiles
end

-- Sample() -> cooldown info by ID: four essential spells (one with charges, one overridden, one hidden by
-- default), two utility spells, an unlearned one, two tracked buffs and two tracked bars.
function C.Sample()
	local E, U, B, R = C.CATEGORY.Essential, C.CATEGORY.Utility, C.CATEGORY.TrackedBuff, C.CATEGORY.TrackedBar
	return {
		[101] = { spellID = 1001, category = E },
		[102] = { spellID = 1002, category = E, charges = true },
		[103] = { spellID = 1003, category = E, overrideSpellID = 1033 },
		[104] = { spellID = 1004, category = E, flags = C.FLAGS.HideByDefault },
		[201] = { spellID = 2001, category = U },
		[202] = { spellID = 2002, category = U },
		[203] = { spellID = 2003, category = U, isKnown = false },
		[301] = { spellID = 3001, category = B, selfAura = true, hasAura = true },
		[302] = { spellID = 3002, category = B, selfAura = true, hasAura = true },
		[401] = { spellID = 4001, category = R, selfAura = true, hasAura = true },
		[402] = { spellID = 4002, category = R, selfAura = true, hasAura = true },
	}
end

local function sorted(t)
	local keys = {}
	for k in pairs(t) do
		keys[#keys + 1] = k
	end
	table.sort(keys)
	return keys
end

local function info(id, def)
	return {
		cooldownID = id,
		spellID = def.spellID,
		overrideSpellID = def.overrideSpellID,
		overrideTooltipSpellID = def.overrideTooltipSpellID,
		linkedSpellIDs = def.linkedSpellIDs or {},
		selfAura = def.selfAura == true,
		hasAura = def.hasAura == true,
		charges = def.charges == true,
		isKnown = def.isKnown ~= false,
		isInvisible = def.isInvisible == true,
		flags = def.flags or 0,
		category = def.category,
		equipSlot = def.equipSlot,
		spellCategoryID = def.spellCategoryID,
	}
end

-- A duration object stand-in: the module only passes it on to widget setters.
function C.Duration(spell, kind)
	return { kind = kind or "cooldown", spell = spell }
end

-- Install(env, opts) puts the fake game on env. opts:
--   cooldowns   info by cooldown ID (C.Sample() by default)
--   noViewer    true: no C_CooldownViewer at all
--   layout      { order = { ids }, category = { [id] = category } }: a clean Blizzard settings provider
--   dirty       true: the provider exists but its data is dirty
--   noDuration  true: C_Spell has no GetSpellCooldownDuration
function C.Install(env, opts)
	opts = opts or {}
	local cdm = {
		cooldowns = opts.cooldowns or C.Sample(),
		calls = {},
		cooldown = {},
		charges = {},
		usable = {},
		overlay = {},
		textures = {},
		categorySource = {},
		auras = {},
		targetAuras = {},
		auraDurations = {},
		stacks = {},
		permanent = {},
		durations = {},
		chargeDurations = {},
		available = true,
	}
	env._cdm = cdm
	local function record(name, ...)
		cdm.calls[#cdm.calls + 1] = { name = name, args = { ... } }
	end
	env.Enum = env.Enum or {}
	env.Enum.CooldownViewerCategory = C.CATEGORY
	env.Enum.CooldownSetSpellFlags = C.FLAGS
	env.Enum.StatusBarInterpolation = { Immediate = 0, ExponentialEaseOut = 1 }
	env.Enum.StatusBarTimerDirection = { ElapsedTime = 0, RemainingTime = 1 }
	env._time = 1000
	env.GetTime = function()
		return env._time
	end
	if not opts.noViewer then
		env.C_CooldownViewer = {
			GetCooldownViewerCategorySet = function(category, allowUnlearned)
				record("GetCooldownViewerCategorySet", category, allowUnlearned)
				if cdm.secretSet then
					return env.Secret({})
				end
				local out = {}
				for _, id in ipairs(sorted(cdm.cooldowns)) do
					local def = cdm.cooldowns[id]
					if def.category == category and (allowUnlearned or def.isKnown ~= false) then
						out[#out + 1] = id
					end
				end
				return out
			end,
			GetCooldownViewerCooldownInfo = function(id)
				record("GetCooldownViewerCooldownInfo", id)
				local def = cdm.cooldowns[id]
				return def and info(id, def) or nil
			end,
			IsCooldownViewerAvailable = function()
				return cdm.available, cdm.available and "" or "not yet"
			end,
		}
	end
	env.C_Spell = {
		GetSpellCooldown = function(spell)
			local state = cdm.cooldown[spell] or {}
			return { startTime = env.Secret(0), duration = env.Secret(0), isEnabled = true, isActive = state.active == true, isOnGCD = state.gcd == true, modRate = 1 }
		end,
		GetSpellCharges = function(spell)
			local state = cdm.charges[spell]
			if not state then
				return nil
			end
			return { currentCharges = env.Secret(state.current), maxCharges = state.max, cooldownStartTime = env.Secret(0), cooldownDuration = env.Secret(0), chargeModRate = 1, isActive = state.current < state.max }
		end,
		GetSpellChargeDuration = function(spell)
			record("GetSpellChargeDuration", spell)
			local d = cdm.chargeDurations[spell]
			if d == nil then
				d = C.Duration(spell, "charge")
				cdm.chargeDurations[spell] = d
			end
			return d
		end,
		GetSpellTexture = function(spell)
			return cdm.textures[spell] or (500000 + spell), 500000 + spell
		end,
		GetLastCategoryCooldownSource = function(category)
			return cdm.categorySource[category], nil
		end,
		IsSpellUsable = function(spell)
			local state = cdm.usable[spell]
			if state == nil then
				return true, false
			end
			return state.usable, state.noMana
		end,
	}
	if not opts.noDuration then
		env.C_Spell.GetSpellCooldownDuration = function(spell, ignoreGCD)
			record("GetSpellCooldownDuration", spell, ignoreGCD)
			if cdm.durationError then
				error(cdm.durationError)
			end
			local d = cdm.durations[spell]
			if d == nil then
				d = C.Duration(spell)
				cdm.durations[spell] = d
			end
			return d
		end
	end
	-- Auras: cdm.auras[spell] and cdm.targetAuras[name] hold { auraInstanceID } (or a secret); the
	-- duration and stack text of an instance come from cdm.auraDurations[id] and cdm.stacks[id].
	env.C_Spell.GetSpellName = function(spell)
		return "Spell " .. tostring(spell)
	end
	env.C_UnitAuras = {
		GetPlayerAuraBySpellID = function(spell)
			record("GetPlayerAuraBySpellID", spell)
			return cdm.auras[spell]
		end,
		GetAuraDataBySpellName = function(unit, name, filter)
			record("GetAuraDataBySpellName", unit, name, filter)
			if unit == "target" then
				return cdm.targetAuras[name]
			end
		end,
		GetAuraDuration = function(unit, id)
			record("GetAuraDuration", unit, id)
			if cdm.auraDurationError then
				error(cdm.auraDurationError)
			end
			local d = cdm.auraDurations[id]
			if d == nil then
				d = C.Duration(id, "aura")
				cdm.auraDurations[id] = d
			end
			return d
		end,
		DoesAuraHaveExpirationTime = function(_, id)
			return not cdm.permanent[id]
		end,
		GetAuraApplicationDisplayCount = function(_, id)
			return cdm.stacks[id] or ""
		end,
	}
	env.C_SpellActivationOverlay = {
		IsSpellOverlayed = function(spell)
			return cdm.overlay[spell] == true
		end,
	}
	env.C_Secrets = {
		ShouldAurasBeSecret = function()
			return cdm.secretAuras == true
		end,
		ShouldCooldownsBeSecret = function()
			return cdm.secretCooldowns == true
		end,
	}
	env.CDM_HIDE_INVISIBLE_ITEMS = false

	-- EventRegistry: owner-keyed callbacks, fired with C.Trigger.
	local callbacks = {}
	cdm.callbacks = callbacks
	env.EventRegistry = {
		RegisterCallback = function(_, event, fn, owner)
			callbacks[event] = callbacks[event] or {}
			callbacks[event][owner or fn] = fn
		end,
		UnregisterCallback = function(_, event, owner)
			if callbacks[event] then
				callbacks[event][owner] = nil
			end
		end,
	}

	-- Blizzard's settings provider, read-only from the module's side.
	if opts.layout or opts.dirty then
		local layout = opts.layout or { order = sorted(cdm.cooldowns) }
		local byID = {}
		for id, def in pairs(cdm.cooldowns) do
			byID[id] = info(id, def)
			if (def.flags or 0) % (2 * C.FLAGS.HideByDefault) >= C.FLAGS.HideByDefault then
				byID[id].category = C.HIDDEN
			end
			if layout.category and layout.category[id] then
				byID[id].category = layout.category[id]
			end
		end
		local provider = {
			displayData = { orderedCooldownIDs = layout.order, cooldownInfoByID = byID },
			dirty = opts.dirty == true,
		}
		function provider.IsDirty(self)
			return self.dirty
		end
		function provider.GetDisplayData(self)
			return self.displayData
		end
		function provider.CheckBuildDisplayData()
			error("the module must never make Blizzard rebuild its data")
		end
		function provider.GetOrderedCooldownIDs()
			error("the module must never call GetOrderedCooldownIDs, which can rebuild Blizzard's data")
		end
		cdm.provider = provider
		env.CooldownViewerSettings = {
			GetDataProvider = function()
				return provider
			end,
		}
	end
end

-- Trigger(env, event, ...) runs every EventRegistry callback registered for the event.
function C.Trigger(env, event, ...)
	for owner, fn in pairs(env._cdm.callbacks[event] or {}) do
		fn(owner, ...)
	end
end

-- New(opts) -> env, K, ns: the core loaded with the fake game, the module's files loaded, then the core booted.
-- opts.saved is KstyleUIDB; opts.setup(env) runs after the fake game is installed.
function C.New(opts)
	opts = opts or {}
	local env, K = W.New({
		boot = false,
		saved = opts.saved,
		setup = function(env)
			C.Install(env, opts)
			if opts.setup then
				opts.setup(env)
			end
		end,
	})
	Load(C.Files(), env)
	if opts.boot ~= false then
		CoreEnv.Boot(env)
	end
	return env, K, env._addons.KstyleUI_Cooldowns
end

function C.Enable(_, K)
	K.Modules.Enable("Cooldowns")
	assert(K.Modules.IsRunning("Cooldowns"), "the Cooldowns module did not start")
end

-- Calls(env, name) -> the argument lists of the fake game's calls by name, oldest first.
function C.Calls(env, name)
	local out = {}
	for _, call in ipairs(env._cdm.calls) do
		if call.name == name then
			out[#out + 1] = call.args
		end
	end
	return out
end

-- Blizzard's four viewers as the module sees them: named frames whose item children carry the regions
-- the XML templates give them (Icon, the unnamed overlay as item.Overlay, OutOfRange, Cooldown,
-- ChargeCount.Current, Applications.Applications), Edit Mode's opacity through SetAlpha, and the mixin
-- methods the module hooks. Bar items carry Icon (a frame with Icon, Overlay and Applications) and Bar
-- (a status bar with BarBG, Pip, Name and Duration). viewer._items lists each viewer's items, and
-- env._blizzard every object the fake game made, for checks that Blizzard objects get no forbidden call.
local function Own(env, object)
	env._blizzard[#env._blizzard + 1] = object
	return object
end

local function Texture(env, frame, layer)
	return Own(env, frame:CreateTexture(nil, layer or "ARTWORK"))
end

local function FontString(env, frame)
	return Own(env, frame:CreateFontString(nil, "OVERLAY"))
end

local function Frame(env, frameType, parent)
	return Own(env, env.CreateFrame(frameType, nil, parent))
end

function C.Item(env, viewer, id)
	local item = Frame(env, "Frame", viewer)
	item.GetCooldownID = function()
		return id
	end
	if viewer._bars then
		local icon = Frame(env, "Frame", item)
		icon.Icon = Texture(env, icon)
		icon.Overlay = Texture(env, icon, "OVERLAY")
		icon.Applications = FontString(env, icon)
		item.Icon = icon
		local bar = Frame(env, "StatusBar", item)
		bar:SetStatusBarTexture("bar-atlas")
		Own(env, bar:GetStatusBarTexture())
		bar.BarBG = Texture(env, bar, "BACKGROUND")
		bar.Pip = Texture(env, bar, "OVERLAY")
		bar.Name = FontString(env, bar)
		bar.Duration = FontString(env, bar)
		item.Bar = bar
	else
		item.Icon = Texture(env, item)
		item.Overlay = Texture(env, item, "OVERLAY")
		item.OutOfRange = Texture(env, item, "OVERLAY")
		item.Cooldown = Frame(env, "Cooldown", item)
		local countdown = FontString(env, item.Cooldown)
		item.Cooldown.GetCountdownFontString = function()
			return countdown
		end
		item.ChargeCount = Frame(env, "Frame", item)
		item.ChargeCount.Current = FontString(env, item.ChargeCount)
		item.Applications = Frame(env, "Frame", item)
		item.Applications.Applications = FontString(env, item.Applications)
	end
	item:SetMouseMotionEnabled(true)
	viewer._items[#viewer._items + 1] = item
	return item
end

function C.Viewers(env)
	env._viewers = {}
	env._blizzard = env._blizzard or {}
	for _, name in ipairs({ "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer", "BuffBarCooldownViewer" }) do
		local viewer = Own(env, env.CreateFrame("Frame", name, env.UIParent))
		viewer._items = {}
		viewer._bars = name == "BuffBarCooldownViewer"
		viewer.tooltipsShown = true
		viewer.OnAcquireItemFrame = function(self, item)
			item:SetMouseMotionEnabled(self.tooltipsShown)
		end
		viewer.SetTooltipsShown = function(self, shown)
			self.tooltipsShown = shown
		end
		for i = 1, 2 do
			C.Item(env, viewer, i)
		end
		env._viewers[name] = viewer
	end
end

-- Clean(env, forbidden) fails when a Blizzard object got a call named in the forbidden set.
function C.Clean(env, forbidden)
	for _, object in ipairs(env._blizzard or {}) do
		for _, call in ipairs(object._calls) do
			assert(not forbidden[call.method], "a Blizzard object got " .. call.method)
		end
	end
end

-- A GameTooltip stand-in that records its owner, spell and visibility.
function C.Tooltip(env)
	local tip = { shown = false }
	function tip.SetOwner(self, owner, anchor)
		self.owner, self.anchor = owner, anchor
	end
	function tip.SetSpellByID(self, spell)
		self.spell = spell
	end
	function tip.Show(self)
		self.shown = true
	end
	function tip.Hide(self)
		self.shown = false
		self.owner = nil
	end
	function tip.IsOwned(self, frame)
		return self.owner == frame
	end
	env.GameTooltip = tip
end

-- Game(env) installs the viewers and the tooltip, for opts.setup.
function C.Game(env)
	C.Viewers(env)
	C.Tooltip(env)
end

return C
