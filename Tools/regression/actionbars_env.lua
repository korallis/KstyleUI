-- actionbars_env.lua: load the core and KstyleUI_ActionBars into a stub game with action slots, bindings, a pet, forms and secure frames.
--
--   local AB = dofile("Tools/regression/actionbars_env.lua")
--   local env, K, ns = AB.New({ class = "WARRIOR" })   -- core booted, the module loaded but off
--   AB.Enable(env, K)                                    -- switch the module on, run the deferred hides
--   AB.Slot(env, 1, { texture = 135489, type = "spell", id = 100 })
--   AB.PressKey(env, "1")                                -- the override binding clicks the button
--
-- The fake game lives in env._game. Secure frames (any template with "Secure" in its name) are
-- protected, and so are their parents, as in the game: every protected call made in combat outside
-- secure code and outside the login window lands in env._blocked, the way the game raises
-- ADDON_ACTION_BLOCKED. A SecureHandlerStateTemplate frame runs its "_onstate-<state>" snippet in a
-- fake restricted environment when a state driver sets "state-<state>", then runs its OnAttributeChanged.

local W = dofile("Tools/regression/widget_env.lua")
local TocFiles = dofile("Tools/regression/toc_files.lua")
local Load = dofile("Tools/regression/load_files.lua")
local CoreEnv = W.CoreEnv

local AB = {}
AB.W = W
AB.CoreEnv = CoreEnv

local PROTECTED_METHODS = {
	"SetPoint", "ClearAllPoints", "SetAllPoints", "SetSize", "SetWidth", "SetHeight", "SetScale", "SetFrameStrata",
	"Show", "Hide", "SetShown", "SetAttribute", "SetID", "RegisterForClicks", "RegisterForDrag", "SetParent",
	"EnableMouse", "SetMouseMotionEnabled", "SetFrameLevel",
}
local PROTECTED_FUNCTIONS = {
	"SetOverrideBindingClick", "ClearOverrideBindings", "RegisterStateDriver", "UnregisterStateDriver",
	"PickupAction", "PlaceAction", "PickupPetAction",
}

local function Block(env, what)
	if env._combat and not env._secure and not env._login then
		env._blocked[#env._blocked + 1] = what
	end
end

-- Protect(env, frame) marks a frame protected and records protected calls on it in combat.
function AB.Protect(env, frame)
	if frame._protectedWrap then
		return
	end
	frame._protectedWrap = true
	frame.IsProtected = function()
		return true, true
	end
	for _, method in ipairs(PROTECTED_METHODS) do
		local original = frame[method]
		if original then
			frame[method] = function(self, ...)
				Block(env, (self:GetName() or "frame") .. ":" .. method)
				return original(self, ...)
			end
		end
	end
end

local function RestrictedEnv(env)
	local g = env._game
	return {
		tonumber = tonumber,
		GetActionInfo = function(n)
			local s = g.slots[n]
			if s then
				return s.type, s.id, s.subType
			end
		end,
		HasVehicleActionBar = function() return g.vehicle ~= nil end,
		GetVehicleBarIndex = function() return g.vehicle end,
		HasOverrideActionBar = function() return g.override ~= nil end,
		GetOverrideBarIndex = function() return g.override end,
		HasTempShapeshiftActionBar = function() return g.temp ~= nil end,
		GetTempShapeshiftBarIndex = function() return g.temp end,
		HasBonusActionBar = function() return g.bonus ~= nil end,
		GetBonusBarIndex = function() return g.bonus end,
		GetActionBarPage = function() return g.page end,
		IsShiftKeyDown = function() return g.shift == true end,
	}
end

-- Handle(env, frame) -> the restricted environment's view of a protected frame, with the methods the
-- bars' snippets use. Calls go to the frame as secure code, so they are never blocked.
local function Handle(env, frame)
	if frame == nil then
		return nil
	end
	env._handles = env._handles or setmetatable({}, { __mode = "k" })
	local existing = env._handles[frame]
	if existing then
		return existing
	end
	local h = { _frame = frame }
	local function secure(fn)
		return function(_, ...)
			local was = env._secure
			env._secure = true
			local a, b = fn(...)
			env._secure = was
			return a, b
		end
	end
	h.GetAttribute = function(_, key) return frame:GetAttribute(key) end
	h.SetAttribute = secure(function(key, value) frame:SetAttribute(key, value) end)
	h.GetID = function() return frame:GetID() end
	h.GetName = function() return frame:GetName() end
	h.GetWidth = function() return frame:GetWidth() end
	h.GetHeight = function() return frame:GetHeight() end
	h.IsShown = function() return frame:IsShown() == true end
	h.Show = secure(function()
		local was = frame:IsShown()
		frame:Show()
		if not was and frame._scripts.OnShow then
			frame._scripts.OnShow(frame)
		end
	end)
	h.Hide = secure(function()
		local was = frame:IsShown()
		frame:Hide()
		if was and frame._scripts.OnHide then
			frame._scripts.OnHide(frame)
		end
	end)
	h.SetWidth = secure(function(w) frame:SetWidth(w) end)
	h.SetHeight = secure(function(v) frame:SetHeight(v) end)
	h.ClearAllPoints = secure(function() frame:ClearAllPoints() end)
	h.SetPoint = secure(function(point, rel, relPoint, x, y)
		frame:SetPoint(point, rel and rel._frame or rel, relPoint, x, y)
	end)
	h.GetParent = function()
		local parent = frame:GetParent()
		if parent and parent.IsProtected and parent:IsProtected() then
			return Handle(env, parent)
		end
	end
	h.GetFrameRef = function(_, label)
		return Handle(env, frame:GetAttribute("frameref-" .. label))
	end
	h.RegisterAutoHide = function(_, seconds)
		frame._autoHide = seconds
	end
	h.SetBindingClick = secure(function(priority, key, name, button)
		env.SetOverrideBindingClick(frame, priority, key, name, button)
	end)
	h.ClearBindings = secure(function() env.ClearOverrideBindings(frame) end)
	h.AddToAutoHide = function(_, other)
		frame._autoHideWith = other and other._frame
	end
	env._handles[frame] = h
	return h
end
AB.Handle = Handle

-- RunSnippet(env, args, body, header, self, ...) runs a wrapped-script body as the restricted environment does.
local function RunSnippet(env, args, body, header, selfFrame, ...)
	local fenv = RestrictedEnv(env)
	fenv.control = Handle(env, header)
	local chunk = assert(loadstring("local " .. args .. " = ...\n" .. body))
	setfenv(chunk, fenv)
	local was = env._secure
	env._secure = true
	local a, b = chunk(Handle(env, selfFrame), ...)
	env._secure = was
	return a, b
end

local function MakeStateHandler(env, frame)
	local set = frame.SetAttribute
	frame.SetAttribute = function(self, name, value)
		set(self, name, value)
		local state = type(name) == "string" and name:match("^state%-(.+)$")
		local snippet = state and self._attributes["_onstate-" .. state]
		if snippet then
			local handle = {
				SetAttribute = function(_, key, v)
					self:SetAttribute(key, v)
				end,
				GetAttribute = function(_, key)
					return self:GetAttribute(key)
				end,
			}
			local chunk = assert(loadstring("local self, stateid, newstate = ...\n" .. snippet))
			setfenv(chunk, RestrictedEnv(env))
			local was = env._secure
			env._secure = true
			chunk(handle, state, value)
			env._secure = was
		end
		local script = self._scripts.OnAttributeChanged
		if script then
			script(self, name, value)
		end
	end
end

local function InstallGame(env, opts)
	local g = {
		slots = {}, bindings = {}, overrides = {}, used = {}, pet = {}, petExists = false, forms = {},
		procs = {}, page = 1, style = 0, cursor = nil, rangeChecks = {}, picked = {}, placed = {},
		autocastToggled = {}, lockActionBars = true, modified = false, maxSlot = opts.maxSlot or 180, spells = {},
	}
	env._game = g
	env._blocked = {}

	env.UnitClass = function()
		local class = opts.class or "WARRIOR"
		return class, class, 1
	end
	-- Macro conditions the paging and pet drivers use: bonusbar:N, bar:N, vehicleui, overridebar,
	-- possessbar, shapeshift, stealth and mod:<key>, each with a "no" form.
	local function Known(part)
		local name, arg = part:match("^(%a+):?(.*)$")
		local value
		if name == "bonusbar" then
			value = g.bonusbar ~= nil and (arg == "" or tonumber(arg) == g.bonusbar)
		elseif name == "bar" then
			value = tonumber(arg) == g.page
		elseif name == "vehicleui" then
			value = g.vehicle ~= nil
		elseif name == "overridebar" then
			value = g.override ~= nil
		elseif name == "possessbar" then
			value = g.possess == true
		elseif name == "shapeshift" then
			value = g.temp ~= nil
		elseif name == "stealth" then
			value = g.stealth == true
		elseif name == "mod" then
			value = g.mod == arg
		elseif name == "mounted" then
			value = g.mounted == true
		else
			return nil
		end
		return value
	end
	env.Condition = function(part)
		local value = Known(part)
		if value == nil and part:sub(1, 2) == "no" then
			value = Known(part:sub(3))
			if value ~= nil then
				value = not value
			end
		end
		return value
	end
	local unitExists = env.UnitExists
	env.UnitExists = function(unit)
		if unit == "pet" then
			return g.petExists
		end
		return unitExists(unit)
	end

	local function slot(n)
		if type(n) ~= "number" or n < 1 or n > g.maxSlot then
			error("invalid action slot " .. tostring(n), 2)
		end
		return g.slots[n]
	end

	env.C_ActionBar = {
		HasAction = function(n) return slot(n) ~= nil end,
		GetActionTexture = function(n)
			local s = slot(n)
			return s and s.texture
		end,
		GetActionCooldownDuration = function(n)
			local s = slot(n)
			return s and s.cooldown or g.zeroDuration
		end,
		GetActionCharges = function(n)
			local s = slot(n)
			return s and s.charges or { currentCharges = 0, maxCharges = 0, isActive = false }
		end,
		GetActionChargeDuration = function(n)
			local s = slot(n)
			return s and s.chargeDuration or g.zeroDuration
		end,
		GetActionDisplayCount = function(n)
			local s = slot(n)
			return s and s.count or ""
		end,
		UsesActionText = function(n)
			local s = slot(n)
			return s ~= nil and s.text ~= nil
		end,
		GetActionText = function(n)
			local s = slot(n)
			return s and s.text
		end,
		IsUsableAction = function(n)
			local s = slot(n)
			if not s then
				return false, false
			end
			return s.usable ~= false, s.noMana == true
		end,
		IsCurrentAction = function(n)
			local s = slot(n)
			return s ~= nil and s.current == true
		end,
		IsAutoRepeatAction = function(n)
			local s = slot(n)
			return s ~= nil and s.autorepeat == true
		end,
		IsActionInRange = function(n)
			local s = slot(n)
			return s and s.inRange
		end,
		EnableActionRangeCheck = function(n, on)
			slot(n)
			g.rangeChecks[n] = (g.rangeChecks[n] or 0) + (on and 1 or -1)
		end,
		GetActionBarPage = function() return g.page end,
		HasBonusActionBar = function() return g.bonus ~= nil end,
	}
	env.GetActionInfo = function(n)
		local s = slot(n)
		if s then
			return s.type, s.id, s.subType
		end
	end
	env.C_SpellActivationOverlay = {
		IsSpellOverlayed = function(id)
			return g.procs[id] == true
		end,
	}
	env.C_Spell = {
		GetSpellCooldownDuration = function()
			return g.zeroDuration
		end,
	}
	env.Constants = { SpellCooldownConsts = { GLOBAL_RECOVERY_CATEGORY = 133 } }
	env.GetBindingKey = function(name)
		local keys = g.bindings[name]
		if keys then
			return unpack(keys)
		end
	end
	env.GetBindingText = function(key)
		return "text:" .. tostring(key)
	end
	env.GetCurrentBindingSet = function() return g.bindingSet or 1 end
	local function CopyBindings(bindings)
		local copy = {}
		for command, keys in pairs(bindings) do copy[command] = { unpack(keys) } end
		return copy
	end
	g.bindingSets = {}
	env.LoadBindings = function(set)
		Block(env, "LoadBindings")
		local current = env.GetCurrentBindingSet()
		g.bindingSets[current] = g.bindingSets[current] or CopyBindings(g.bindings)
		g.bindings = CopyBindings(g.bindingSets[set] or g.bindings)
		return true
	end
	env.GetBindingAction = function(key)
		for name, keys in pairs(g.bindings) do
			for _, value in ipairs(keys) do
				if value == key then return name end
			end
		end
		return ""
	end
	env.SetBinding = function(key, command)
		Block(env, "SetBinding")
		if g.failBinding == key then return false end
		local set = env.GetCurrentBindingSet()
		g.bindingSets[set] = g.bindingSets[set] or CopyBindings(g.bindings)
		for _, keys in pairs(g.bindings) do
			for i = #keys, 1, -1 do
				if keys[i] == key then table.remove(keys, i) end
			end
		end
		if command then
			g.bindings[command] = g.bindings[command] or {}
			table.insert(g.bindings[command], key)
		end
		env.FireEvent("UPDATE_BINDINGS")
		return true
	end
	env.SaveBindings = function(set)
		Block(env, "SaveBindings")
		g.bindingSets[set] = CopyBindings(g.bindings)
		g.savedSet, g.bindingSet = set, set
		return true
	end
	env.IsShiftKeyDown = function() return g.shift == true end
	env.IsControlKeyDown = function() return g.ctrl == true end
	env.IsAltKeyDown = function() return g.alt == true end
	env.IsMetaKeyDown = function() return g.meta == true end
	env.SetOverrideBindingClick = function(owner, priority, key, buttonName, mouse)
		Block(env, "SetOverrideBindingClick")
		g.overrides[owner] = g.overrides[owner] or {}
		g.overrides[owner][key] = { name = buttonName, mouse = mouse or "LeftButton", priority = priority }
	end
	env.ClearOverrideBindings = function(owner)
		Block(env, "ClearOverrideBindings")
		g.overrides[owner] = nil
	end
	env.PickupAction = function(n)
		Block(env, "PickupAction")
		g.picked[#g.picked + 1] = n
		g.cursor, g.slots[n] = g.slots[n], g.cursor
	end
	env.PlaceAction = function(n)
		Block(env, "PlaceAction")
		g.placed[#g.placed + 1] = n
		if type(g.cursor) == "table" and not (g.refuse and g.refuse[n]) then
			g.cursor, g.slots[n] = g.slots[n], g.cursor
		end
	end
	env.PickupPetAction = function(n)
		Block(env, "PickupPetAction")
		g.picked[#g.picked + 1] = "pet" .. n
		g.cursor = { type = "petaction", index = n }
	end
	env.GetCursorInfo = function()
		if type(g.cursor) == "table" and g.cursor.type == "spell" then
			return "spell", 1, "spell", g.cursor.id
		end
		return type(g.cursor) == "table" and g.cursor.type or g.cursor
	end
	env.ClearCursor = function()
		Block(env, "ClearCursor")
		g.cursor = nil
	end
	env.GetCVarBool = function(name)
		if name == "lockActionBars" then
			return g.lockActionBars
		end
		if name == "ActionButtonUseKeyDown" then return g.useKeyDown ~= false end
		return false
	end
	env.IsModifiedClick = function()
		return g.modified
	end
	env.GetPetActionInfo = function(i)
		local p = g.pet[i]
		if p then
			return p.name, p.texture, p.isToken, p.isActive, p.autoCastAllowed, p.autoCastEnabled, p.spellID, p.checksRange, p.inRange
		end
	end
	env.GetPetActionSlotUsable = function(i)
		local p = g.pet[i]
		return p ~= nil and p.usable ~= false
	end
	env.GetPetActionCooldown = function(i)
		local p = g.pet[i]
		if p and p.cooldown then
			return p.cooldown[1], p.cooldown[2], 1
		end
		return 0, 0, 1
	end
	env.PetHasActionBar = function()
		return g.petExists
	end
	env.GetNumShapeshiftForms = function()
		return #g.forms
	end
	env.GetShapeshiftFormInfo = function(i)
		local f = g.forms[i]
		if f then
			return f.texture, f.isActive, f.isCastable ~= false, f.spellID
		end
	end
	env.GetShapeshiftFormCooldown = function()
		return 0, 0, 1
	end
	env.Enum = env.Enum or {}
	env.Enum.InputDeviceInterfaceType = { Mkb = 0, Gamepad = 1 }
	env.Enum.StatusBarInterpolation = env.Enum.StatusBarInterpolation or { Immediate = 0, ExponentialEaseOut = 1 }
	env.Enum.StatusBarTimerDirection = env.Enum.StatusBarTimerDirection or { ElapsedTime = 0, RemainingTime = 1 }
	env.C_InputInterfaceStyle = {
		GetCurrentStyle = function()
			return g.style
		end,
	}
	env.GameTooltip = {
		_calls = {},
		SetOwner = function(self, owner)
			self.owner = owner
			self._calls[#self._calls + 1] = "SetOwner"
		end,
		GetOwner = function(self)
			return self.owner
		end,
		SetAction = function(self, n)
			self._calls[#self._calls + 1] = "SetAction:" .. n
		end,
		SetPetAction = function(self, n)
			self._calls[#self._calls + 1] = "SetPetAction:" .. n
		end,
		SetShapeshift = function(self, n)
			self._calls[#self._calls + 1] = "SetShapeshift:" .. n
		end,
		Show = function() end,
		Hide = function(self)
			self.owner = nil
			self._calls[#self._calls + 1] = "Hide"
		end,
	}
	env.SecureHandlerWrapScript = function(frame, script, header, pre, post)
		Block(env, "SecureHandlerWrapScript")
		frame._wraps = frame._wraps or {}
		frame._wraps[script] = { header = header, pre = pre, post = post }
	end
	env.SecureHandlerSetFrameRef = function(frame, label, ref)
		Block(env, "SecureHandlerSetFrameRef")
		frame:SetAttribute("frameref-" .. label, ref)
	end
	g.flyouts = {}
	env.GetFlyoutInfo = function(id)
		local f = g.flyouts[id]
		if f then
			return f.name, "", #f.slots, f.known ~= false
		end
	end
	env.GetFlyoutSlotInfo = function(id, i)
		local f = g.flyouts[id]
		local s = f and f.slots[i]
		if s then
			return s.spellID, s.overrideSpellID or s.spellID, s.known ~= false, s.name, 0
		end
	end
	env.C_Spell.GetSpellTexture = function(id)
		return 1000000 + id
	end
	for api, field in pairs({ GetSpellName = "name", GetSpellSubtext = "subtext" }) do
		env.C_Spell[api] = function(id) return g.spells[id] and g.spells[id][field] end
	end
	env.C_Spell.PickupSpell = function(id)
		Block(env, "C_Spell.PickupSpell")
		g.cursor = { type = "spell", id = id, texture = 1000000 + id }
	end
	g.bookSpells, g.professions = {}, {}
	env.C_SpellBook = env.C_SpellBook or {}
	env.Enum.SpellBookItemType = env.Enum.SpellBookItemType or { Spell = 1, FutureSpell = 2, Flyout = 3 }
	env.Enum.SpellBookSpellBank = env.Enum.SpellBookSpellBank or { Player = 0, Pet = 1 }
	env.C_SpellBook.FindSpellBookSlotForSpell = function(id)
		for index, info in pairs(g.bookSpells) do
			if info.spellID == id then return index, env.Enum.SpellBookSpellBank.Player end
		end
	end
	env.C_SpellBook.GetSpellBookItemInfo = function(index) return g.bookSpells[index] end
	env.GetProfessions = function() return unpack(g.professions.indices or {}) end
	env.GetProfessionInfo = function(index)
		local profession = g.professions[index]
		return "Profession", 1, 1, 300, profession.count, profession.offset
	end
	-- A spell with no entry in g.spells has not loaded. RequestLoadSpellData records the ID in
	-- g.loadRequests; a test then adds the entry and fires SPELL_DATA_LOAD_RESULT itself.
	g.loadRequests = {}
	env.C_Spell.IsSpellDataCached = function(id)
		return g.spells[id] ~= nil
	end
	env.C_Spell.RequestLoadSpellData = function(id)
		g.loadRequests[#g.loadRequests + 1] = id
	end
	env.GameTooltip_SetDefaultAnchor = function(tooltip, owner)
		tooltip:SetOwner(owner)
	end
	env.C_AddOns = {
		LoadAddOn = function(name)
			if name ~= "KstyleUI_Options" then
				return false, "MISSING"
			end
			if not env._addons.KstyleUI_Options then
				local files = {}
				for _, path in ipairs(TocFiles("%.lua$")) do
					if path:match("^KstyleUI_Options/") then
						files[#files + 1] = path
					end
				end
				Load(files, env)
			end
			return true
		end,
	}

	for _, name in ipairs({ "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft", "MultiBar5", "MultiBar6", "MultiBar7", "StanceBar", "PetActionBar" }) do
		env.CreateFrame("Frame", name, env.UIParent)
	end
	local petBar = env.PetActionBar
	env.StanceBar.actionButtons = {}
	for i = 1, 10 do
		local button = env.CreateFrame("CheckButton", "StanceButton" .. i, env.StanceBar)
		button.Click = function()
			local form = g.forms[i]
			if form then
				form.isActive = not form.isActive
				g.used[#g.used + 1] = "form" .. i
			end
		end
		env.StanceBar.actionButtons[i] = button
	end
	env.CreateFrame("Frame", "PossessActionBar", env.UIParent)
	env.PossessActionBar:SetSize(64, 30)
	env.PossessActionBar:SetPoint("BOTTOM", env.UIParent, "BOTTOM", 0, 0)
	env.PossessActionBar:Hide()
	AB.Protect(env, env.PossessActionBar)
	env.PossessActionBar.actionButtons = {}
	for i = 1, 2 do
		local button = env.CreateFrame("CheckButton", "PossessButton" .. i, env.PossessActionBar)
		button:SetSize(30, 30)
		button:SetPoint("LEFT", env.PossessActionBar, "LEFT", (i - 1) * 34, 0)
		button.icon = button:CreateTexture(nil, "ARTWORK")
		button.icon:SetAllPoints(button)
		button.cooldown = env.CreateFrame("Cooldown", nil, button)
		AB.Protect(env, button)
		button:SetID(i)
		button.Click = function()
			if i == 2 then g.possess = false; g.used[#g.used + 1] = "cancelpossess" end
		end
		env.PossessActionBar.actionButtons[i] = button
	end
	petBar.actionButtons = {}
	for i = 1, 10 do
		petBar.actionButtons[i] = {
			Click = function()
				env._game.autocastToggled[#env._game.autocastToggled + 1] = i
			end,
		}
	end

	for _, name in ipairs(PROTECTED_FUNCTIONS) do
		if name == "RegisterStateDriver" or name == "UnregisterStateDriver" then
			local original = env[name]
			env[name] = function(...)
				Block(env, name)
				return original(...)
			end
		end
	end

	local create = env.CreateFrame
	env.CreateFrame = function(frameType, name, parent, template)
		local frame = create(frameType, name, parent, template)
		if type(template) == "string" and template:find("Secure", 1, true) then
			AB.Protect(env, frame)
			local up = parent
			while up and up ~= env.UIParent do
				AB.Protect(env, up)
				up = up:GetParent()
			end
			if template:find("SecureHandlerStateTemplate", 1, true) or template:find("SecureHandlerBaseTemplate", 1, true) then
				MakeStateHandler(env, frame)
			end
			if template:find("SecureHandlerClickTemplate", 1, true) then frame._secureClick = true end
			local hide = frame.Hide
			frame.Hide = function(self)
				local wrap = self._wraps and self._wraps.OnHide
				local shown = self:IsShown()
				hide(self)
				if shown and wrap then RunSnippet(env, "self", wrap.pre, wrap.header, self) end
			end
		end
		return frame
	end
end

-- New(opts) -> env, KstyleUI, ns. opts: class, maxSlot, saved, setup(env), and the widget_env options.
AB.InstallGame = InstallGame

function AB.New(opts)
	opts = opts or {}
	local setup = opts.setup
	local env, K = W.New({
		boot = false,
		saved = opts.saved,
		width = opts.width,
		height = opts.height,
		setup = function(e)
			function e.CreateColor(r, g, b, a)
				return { r = r, g = g, b = b, a = a }
			end
			InstallGame(e, opts)
			if setup then
				setup(e)
			end
		end,
	})
	env.UnitClass = function()
		local class = opts.class or "WARRIOR"
		return class, class, 1
	end
	local files = {}
	for _, path in ipairs(TocFiles("%.lua$")) do
		if path:match("^KstyleUI_ActionBars/") then
			files[#files + 1] = path
		end
	end
	Load(files, env)
	CoreEnv.LoadSaved(env)
	if opts.combatAtLogin then
		env._combat = true
	end
	env._login = true
	CoreEnv.Login(env)
	env._login = false
	return env, K, env._addons.KstyleUI_ActionBars
end

-- Enable(env, K) switches the module on and runs the deferred work (the Blizzard bar hides).
function AB.Enable(env, K)
	K.Modules.Enable("ActionBars")
	env.RunTimers()
end

-- Slot(env, n, fields) puts an action in slot n (nil clears it) and fires ACTIONBAR_SLOT_CHANGED.
function AB.Slot(env, n, fields)
	env._game.slots[n] = fields
	env.FireEvent("ACTIONBAR_SLOT_CHANGED", n)
end

-- Button(ns, barKey, index) -> one of the module's buttons.
function AB.Button(ns, barKey, index)
	return ns.bars[barKey].buttons[index]
end

-- Attr(env, button, name, suffix) reads a modified attribute as SecureButton_GetModifiedAttribute does with
-- Shift held or not: shift-name2, *name2, shift-name*, *name*, then name; "" (ATTRIBUTE_NOOP) reads as nil.
local function Attr(env, button, name, suffix)
	local prefix = env._game.shift and "shift-" or ""
	for _, key in ipairs({ prefix .. name .. suffix, "*" .. name .. suffix, prefix .. name .. "*", "*" .. name .. "*", name }) do
		local value = button:GetAttribute(key)
		if value ~= nil then
			if value == "" then return nil end
			return value
		end
	end
end

-- Click(env, button, mouse, down) runs the secure action the button's attributes describe, as
-- SecureActionButton_OnClick does, then the button's hooked OnClick and PostClick scripts.
function AB.Click(env, button, mouse, down)
	mouse = mouse or "LeftButton"
	if button._secureClick then
		if not down then RunSnippet(env, "self, button, down", button:GetAttribute("_onclick"), button, button, mouse, down) end
		return
	end
	local wrap = button._wraps and button._wraps.OnClick
	local message
	if wrap then
		local newButton
		newButton, message = RunSnippet(env, "self, button, down", wrap.pre, wrap.header, button, mouse, down)
		if newButton == false then
			return
		end
		if newButton then mouse = tostring(newButton) end
	end
	local suffix = mouse == "RightButton" and "2" or "1"
	local kind = Attr(env, button, "type", suffix)
	local g = env._game
	local useOnKeyDown = button:GetAttribute("useOnKeyDown")
	if useOnKeyDown == nil then useOnKeyDown = env.GetCVarBool("ActionButtonUseKeyDown") end
	local acts = (down == true) == (useOnKeyDown == true)
	if not acts then kind = nil end
	if kind == "action" then
		local page = button:GetAttribute("actionpage")
		if page == nil and button:GetAttribute("useparent-actionpage") then
			page = button:GetParent():GetAttribute("actionpage")
		end
		local id = button:GetID() or 0
		local slot = id > 0 and (id + ((page or 1) - 1) * 12) or button:GetAttribute("action")
		g.used[#g.used + 1] = slot
	elseif kind == "pet" then
		g.used[#g.used + 1] = "pet" .. tostring(button:GetAttribute("action"))
	elseif kind == "spell" then
		g.used[#g.used + 1] = "spell" .. tostring(Attr(env, button, "spell", suffix))
	elseif kind == "multispell" then
		local spell = Attr(env, button, "spell", suffix)
		g.used[#g.used + 1] = "multispell" .. tostring(button:GetAttribute("action")) .. ":" .. tostring(spell)
		if env.SetMultiCastSpell then env.SetMultiCastSpell(button:GetAttribute("action"), spell) end
	elseif kind == "destroytotem" then
		g.used[#g.used + 1] = "destroytotem" .. tostring(Attr(env, button, "totem-slot", suffix))
	elseif kind == "item" then
		g.used[#g.used + 1] = Attr(env, button, "item", suffix)
	elseif kind == "click" then
		local delegate = button:GetAttribute("clickbutton")
		if delegate then
			delegate:Click(mouse)
		end
	end
	for _, script in ipairs({ "OnClick", "PostClick" }) do
		local fn = button._scripts[script]
		if fn then
			fn(button, mouse, down)
		end
	end
	if wrap and wrap.post and message ~= nil then
		RunSnippet(env, "self, message, button, down", wrap.post, wrap.header, button, message, mouse, down)
	end
end

-- PressKey(env, key, down) sends a full key press, or just the requested edge when down is supplied.
-- It returns false when no override binding holds the key.
function AB.PressKey(env, key, down)
	for _, bindings in pairs(env._game.overrides) do
		local binding = bindings[key]
		if binding then
			local button = env[binding.name]
			assert(button, "the override binding names a button that does not exist: " .. tostring(binding.name))
			if down == nil or down then AB.Click(env, button, binding.mouse, true) end
			if down == nil or not down then AB.Click(env, button, binding.mouse, false) end
			return true
		end
	end
	local command = env.GetBindingAction(key)
	local name, mouse = command:match("^CLICK (.-):(%w+)$")
	if name and env[name] then
		if env[name]._secureClick then AB.Click(env, env[name], mouse, false)
		elseif Attr(env, env[name], "type", mouse == "RightButton" and "2" or "1") then
			AB.Click(env, env[name], mouse, true)
			AB.Click(env, env[name], mouse, false)
		else env[name]:Click(mouse) end
		return true
	end
	return false
end

-- Used(env) -> the last action the game used, or nil.
function AB.Used(env)
	local used = env._game.used
	return used[#used]
end

function AB.Errors(env)
	return table.concat(env._errors, "\n")
end

return AB
