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
-- StringUtil(env) gives the environment C_StringUtil.CreateSecondsFormatter and the SecondsFormatter enums.
-- The fake formatter records every setter and formats as the game's one-letter mode does with whitespace
-- stripped and the last unit rounded up: "4s" under a minute, "2m" under an hour, "3h" beyond.
function C.StringUtil(env)
	env.Enum = env.Enum or {}
	env.Enum.SecondsFormatterAbbreviation = env.Enum.SecondsFormatterAbbreviation or { None = 0, Truncate = 1, OneLetter = 2 }
	env.Enum.SecondsFormatterInterval = env.Enum.SecondsFormatterInterval or { Seconds = 0, Minutes = 1, Hours = 2, Days = 3 }
	env.Enum.SecondsFormatterRounding = env.Enum.SecondsFormatterRounding or { RoundUp = 0, Truncate = 1 }
	env.Enum.SecondsFormatterIntervalWhitespace = env.Enum.SecondsFormatterIntervalWhitespace or { Preserve = 0, Strip = 1, StripIgnoreLocale = 2 }
	env.C_StringUtil = env.C_StringUtil or {}
	env.C_StringUtil.CreateSecondsFormatter = env.C_StringUtil.CreateSecondsFormatter or function()
		local f = { calls = {} }
		function f.Format(_, seconds)
			seconds = math.max(0, seconds)
			if seconds < 60 then
				return string.format("%ds", math.ceil(seconds))
			elseif seconds < 3600 then
				return string.format("%dm", math.ceil(seconds / 60))
			end
			return string.format("%dh", math.ceil(seconds / 3600))
		end
		f.FormatNumber = f.Format
		return setmetatable(f, {
			__index = function(_, method)
				return function(_, ...)
					f.calls[#f.calls + 1] = { method = method, args = { ... } }
				end
			end,
		})
	end
end

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
	C.StringUtil(env)
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
	return Own(env, frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightHugeOutline"))
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
	-- UpdateShownState shows an item while it is active (item._active), or always while the viewer's Edit Mode Hide
	-- When Inactive is off (viewer._hideWhenInactive == false), as CooldownViewerItemMixin:ShouldBeShown does through
	-- SetShown. IsActive is the mixin's plain getter of the same state.
	item.UpdateShownState = function(self)
		self._shown = self._active ~= false or viewer._hideWhenInactive == false
	end
	item.IsActive = function(self)
		return self._active ~= false
	end
	viewer._items[#viewer._items + 1] = item
	item.layoutIndex = #viewer._items
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
		viewer.GetHideWhenInactive = function(self)
			return self._hideWhenInactive ~= false
		end
		viewer.Layout = function() end
		for i = 1, 2 do
			C.Item(env, viewer, i)
		end
		env._viewers[name] = viewer
	end
end

-- Native(env, name, entry, items, format) lays Blizzard's tracked buff viewer out as the game would under the Edit
-- Mode entry Layout > Apply wrote (Tools/regression/editmode_fake.lua), from Blizzard_CooldownViewer at 1.60.1:
-- RefreshLayout acquires one item per tracked cooldown (at least two) and GridLayoutFrame puts them in one row, or
-- for bars, or icons with a Vertical Orientation, one column (GetStride is the item count), a vertical icon column
-- growing up when its IconDirection is Right; each item is 40 by 40 (a bar 220 by 30, its 30-unit icon on the
-- left and a 19-unit bar after a 2-unit gap, the width times BarWidthScale%, stored as percent - 50) scaled by
-- IconSize%, stored as (percent - 50) / 10; items pitch by
-- IconPadding less 4 (bars 2); a horizontal row with IconDirection Left starts at the right; hidden (inactive) items
-- keep their slot (includeAsLayoutChildWhenHidden), and with viewer._hideWhenInactive == false every item shows,
-- active or not; the viewer hangs from the entry's anchor on UIParent; each item
-- goes through OnAcquireItemFrame after its scale is set, as RefreshLayout acquires it. items: one
-- { id, icon, name, left, total } per tracked cooldown, active when left is set; format(seconds) is the countdown
-- text the engine draws through the countdown formatter. The game's own calls are made through the stub's fields so
-- the forbidden-call checks see only what the module does.
function C.Native(env, name, entry, items, format)
	local viewer = env._viewers[name]
	local bars = viewer._bars
	local function setting(id)
		for _, saved in ipairs(entry.settings) do
			if saved.setting == id then
				return saved.value
			end
		end
	end
	local scale = (setting(3) * 10 + 50) / 100
	local pad = setting(4) - (bars and 2 or 4)
	local n = math.max(2, #items)
	while #viewer._items < n do
		C.Item(env, viewer, #viewer._items + 1)
	end
	local w, h = bars and 220 * (setting(11) + 50) / 100 or 40, bars and 30 or 40
	local column = bars or setting(0) == 1
	local leftward = not column and setting(2) == 0
	local upward = not bars and column and setting(2) == 1
	local across = n * (column and h or w) * scale + (n - 1) * pad
	local a = entry.anchorInfo
	viewer._points, viewer._width, viewer._height = {}, column and w * scale or across, column and across or h * scale
	viewer._points[1] = { a.point, env.UIParent, a.relativePoint, a.offsetX, a.offsetY, n = 5 }
	for i, item in ipairs(viewer._items) do
		local it = items[i]
		item._scale = scale
		item._width, item._height = w, h
		local step = (i - 1) * ((column and h or w) * scale + pad)
		local x, y = 0, 0
		if upward then
			y = -(across - h * scale - step)
		elseif column then
			y = -step
		elseif leftward then
			x = across - w * scale - step
		else
			x = step
		end
		item._points = { { "TOPLEFT", viewer, "TOPLEFT", x / scale, y / scale, n = 5 } }
		item.layoutIndex = i
		item._active = i <= n and it ~= nil and it.left ~= nil
		item._shown = item._active or (i <= n and viewer._hideWhenInactive == false)
		if it then
			item.GetCooldownID = function()
				return it.id
			end
			item.GetSpellID = function()
				return it.id
			end
		end
		local text = it and it.left and format(it.left) or nil
		if bars then
			local icon, bar = item.Icon, item.Bar
			icon._width, icon._height = 30, 30
			icon._points = { { "LEFT", item, "LEFT", 0, 0, n = 5 } }
			icon.Icon._points = { { "TOPLEFT", icon, "TOPLEFT", 0, 0, n = 5 }, { "BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0, n = 5 } }
			icon.Icon._state.Texture = { it and it.icon, n = 1 }
			bar._height = 19
			bar._points = { { "LEFT", icon, "RIGHT", 2, 0, n = 5 }, { "RIGHT", item, "RIGHT", 0, 0, n = 5 } }
			bar.Name._points = { { "TOPLEFT", bar, "TOPLEFT", 5, 0, n = 5 }, { "BOTTOMRIGHT", bar, "BOTTOMRIGHT", -25, 0, n = 5 } }
			bar.Name._state.Text = { it and it.name, n = 1 }
			bar.Name._state.JustifyH = { "LEFT", n = 1 }
			bar.Duration._points = { { "RIGHT", bar, "RIGHT", -8, 0, n = 5 } }
			bar.Duration._state.Text = { text, n = 1 }
			bar._state.MinMaxValues = { 0, it and it.total or 1, n = 2 }
			bar._state.Value = { it and it.left or 0, n = 1 }
		else
			item.Icon._points = { { "TOPLEFT", item, "TOPLEFT", 0, 0, n = 5 }, { "BOTTOMRIGHT", item, "BOTTOMRIGHT", 0, 0, n = 5 } }
			item.Icon._state.Texture = { it and it.icon, n = 1 }
			item.Cooldown._points = { { "TOPLEFT", item, "TOPLEFT", 0, 0, n = 5 }, { "BOTTOMRIGHT", item, "BOTTOMRIGHT", 0, 0, n = 5 } }
			local countdown = item.Cooldown:GetCountdownFontString()
			countdown._points = { { "CENTER", item.Cooldown, "CENTER", 0, 0, n = 5 } }
			countdown._state.Text = { text, n = 1 }
		end
		if i <= n then
			viewer:OnAcquireItemFrame(item)
		end
	end
	viewer:Layout()
	return viewer
end

-- Clean(env, forbidden) fails when a Blizzard object got a call named in the forbidden set.
function C.Clean(env, forbidden)
	for _, object in ipairs(env._blizzard or {}) do
		for _, call in ipairs(object._calls) do
			assert(not forbidden[call.method], "a Blizzard object got " .. call.method)
		end
	end
end

-- A GameTooltip stand-in that records its owner, spell, lines (tip.lines, { left, right } each) and visibility.
function C.Tooltip(env)
	local tip = { shown = false }
	function tip.SetOwner(self, owner, anchor)
		self.owner, self.anchor = owner, anchor
		self.lines = {}
	end
	function tip.SetSpellByID(self, spell)
		self.spell = spell
	end
	function tip.SetText(self, text)
		self.lines = { { left = text } }
	end
	function tip.AddLine(self, text)
		self.lines = self.lines or {}
		self.lines[#self.lines + 1] = { left = text }
	end
	function tip.AddDoubleLine(self, left, right)
		self.lines = self.lines or {}
		self.lines[#self.lines + 1] = { left = left, right = right }
	end
	function tip.ClearLines(self)
		self.lines = {}
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
