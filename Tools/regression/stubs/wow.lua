-- wow.lua: a stub World of Warcraft API for offline tests. Extend it additively.
--
--   local Stubs = dofile("Tools/regression/stubs/wow.lua")
--   local env = Stubs.NewEnv({ width = 2560, height = 1440 })
--
-- Frames answer only the widget methods Forever documents (widget_methods.lua) and record every call
-- in frame._calls, unless env.SetQuiet(true) has made them quiet for the performance check. Any other
-- key reads as nil, so a call to a method Forever lacks fails the test.
-- Give a method real behaviour by adding it to Object below. Lua mixins from templates, such as
-- BackdropTemplate's SetBackdrop, are not stubbed.

local unpack = unpack

local function pack(...)
	return { n = select("#", ...), ... }
end

-- Secret values ---------------------------------------------------------------------------------

local COMPARE = "attempt to compare a secret value"
local ARITH = "attempt to perform arithmetic on a secret value"
local secretValues = setmetatable({}, { __mode = "k" })

local newSecret

-- The plain value behind a secret, or the value itself.
local function plain(value)
	local box = secretValues[value]
	if box then
		return box[1]
	end
	return value
end

-- What the game allows on a secret: storing it, passing it on, type() and concatenation. What it
-- forbids raises here: comparison, arithmetic, # and indexing. Lua cannot intercept a boolean test,
-- a comparison with a non-secret (== is plain false) or use as a table key; the secret lint covers
-- those.
local secretMeta = {
	__tostring = function()
		return "<secret>"
	end,
	__index = function()
		error("attempt to index a secret value", 2)
	end,
	__newindex = function()
		error("attempt to index a secret value", 2)
	end,
	__concat = function(a, b)
		return newSecret(plain(a) .. plain(b))
	end,
}
for _, key in ipairs({ "__lt", "__le", "__eq" }) do
	secretMeta[key] = function()
		error(COMPARE, 2)
	end
end
for _, key in ipairs({ "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__unm", "__len" }) do
	secretMeta[key] = function()
		error(ARITH, 2)
	end
end

-- Lua 5.1 honours __len only on userdata, so a secret is a newproxy userdata where one exists.
local secretTemplate
if newproxy then
	secretTemplate = newproxy(true)
	for key, fn in pairs(secretMeta) do
		getmetatable(secretTemplate)[key] = fn
	end
end

-- While an environment is quiet (env.SetQuiet), one value gives one shared secret, so a fake that
-- returns a secret allocates nothing on a combat path. NIL stands for a nil value as a key.
local quietEnvs = 0
local sharedSecrets = {}
local NIL = {}

local function makeSecret(value)
	local secret = secretTemplate and newproxy(secretTemplate) or setmetatable({}, secretMeta)
	secretValues[secret] = { value }
	return secret
end

function newSecret(value)
	if quietEnvs == 0 or value ~= value then
		return makeSecret(value)
	end
	local key = value == nil and NIL or value
	local secret = sharedSecrets[key]
	if not secret then
		secret = makeSecret(value)
		sharedSecrets[key] = secret
	end
	return secret
end

-- Widgets ---------------------------------------------------------------------------------------

-- Every widget method Forever documents, as a set. Regenerate the list with
-- python3 Tools/build/gen_widget_methods.py --source <wow-ui-source on branch forever>.
local here = (debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "")
local METHODS = {}
for _, name in ipairs(dofile(here .. "widget_methods.lua")) do
	METHODS[name] = true
end

-- Values a generic Get<X>() returns before Set<X>() is called.
local DEFAULTS = { Alpha = 1 }

local Object = {}

function Object:GetName() return self._name end
function Object:GetObjectType() return self._type end
function Object:IsObjectType(t) return self._type == t end
function Object:GetParent() return self._parent end
function Object:SetParent(parent) self._parent = parent end
function Object:Show() self._shown = true end
function Object:Hide() self._shown = false end
function Object:SetShown(shown) self._shown = not not shown end
function Object:IsShown() return self._shown end
function Object:IsVisible() return self._shown and (self._parent == nil or self._parent:IsVisible()) end
function Object:SetSize(w, h) self._width, self._height = w, h end
function Object:SetWidth(w) self._width = w end
function Object:SetHeight(h) self._height = h end
function Object:GetSize() return self._width, self._height end
function Object:GetWidth() return self._width end
function Object:GetHeight() return self._height end
function Object:SetScale(scale) self._scale = scale end
function Object:GetScale() return self._scale end
function Object:GetEffectiveScale()
	return self._scale * (self._parent and self._parent:GetEffectiveScale() or 1)
end

function Object:SetPoint(point, ...)
	for i, existing in ipairs(self._points) do
		if existing[1] == point then
			self._points[i] = pack(point, ...)
			return
		end
	end
	self._points[#self._points + 1] = pack(point, ...)
end
function Object:ClearAllPoints() self._points = {} end
function Object:GetNumPoints() return #self._points end
function Object:GetPoint(i)
	local p = self._points[i or 1]
	if p then
		return unpack(p, 1, p.n)
	end
end

function Object:SetScript(name, fn) self._scripts[name] = fn end
function Object:GetScript(name) return self._scripts[name] end
function Object:HookScript(name, fn)
	local original = self._scripts[name]
	self._scripts[name] = original and function(...)
		original(...)
		fn(...)
	end or fn
end

function Object:RegisterEvent(event) self._events[event] = true end
function Object:RegisterUnitEvent(event, ...) self._events[event] = select("#", ...) > 0 and { ... } or true end
function Object:UnregisterEvent(event) self._events[event] = nil end
function Object:UnregisterAllEvents() self._events = {} end
function Object:IsEventRegistered(event)
	local registered = self._events[event]
	if type(registered) == "table" then
		return true, unpack(registered)
	end
	return registered ~= nil
end

function Object:SetAttribute(key, value) self._attributes[key] = value end
function Object:GetAttribute(key) return self._attributes[key] end

-- A frame starts one level above its parent, as in the game.
function Object:SetFrameLevel(level) self._level = level end
function Object:GetFrameLevel()
	if self._level then
		return self._level
	end
	return self._parent and self._parent:GetFrameLevel() + 1 or 0
end

-- The frames and regions made on a frame, in creation order.
function Object:GetChildren() return unpack(self._kids) end
function Object:GetRegions() return unpack(self._regions) end

-- Buttons and other controls are enabled until Disable. A change runs OnEnable or OnDisable.
local function setEnabled(self, enabled)
	enabled = not not enabled
	if self._enabled == enabled then
		return
	end
	self._enabled = enabled
	local script = self._scripts[enabled and "OnEnable" or "OnDisable"]
	if script then
		script(self)
	end
end
function Object:Enable() setEnabled(self, true) end
function Object:Disable() setEnabled(self, false) end
function Object:SetEnabled(enabled) setEnabled(self, enabled) end
function Object:IsEnabled() return self._enabled end

-- The pointer is over a frame while a test sets frame._mouseOver.
function Object:IsMouseOver() return self._mouseOver == true end

-- An object's own alpha times its parent's effective alpha, unless it ignores its parent's alpha.
function Object:SetIgnoreParentAlpha(ignore) self._ignoreParentAlpha = not not ignore end
function Object:IsIgnoringParentAlpha() return self._ignoreParentAlpha == true end
function Object:GetEffectiveAlpha()
	local own = self._state.Alpha
	local alpha = own and own[1] or 1
	if self._ignoreParentAlpha or not self._parent then
		return alpha
	end
	return alpha * self._parent:GetEffectiveAlpha()
end

-- A test sets frame._denied to model an object enforcing access restrictions, such as an aura button
-- while auras are secret: CanBeAccessedInContext reads false and every other method raises an error.
function Object:CanBeAccessedInContext() return self._denied ~= true end

local ObjectMeta = {}

local function newObject(env, objectType, name, parent)
	return setmetatable({
		_env = env, _type = objectType, _name = name, _parent = parent, _calls = {}, _state = {},
		_scripts = {}, _events = {}, _attributes = {}, _points = {}, _scale = 1, _shown = true,
		_kids = {}, _regions = {}, _enabled = true,
	}, ObjectMeta)
end

-- A status bar draws its fill with a texture region that GetStatusBarTexture returns.
function Object:SetStatusBarTexture(asset)
	if not self._barTexture then
		self._barTexture = newObject(self._env, "Texture", nil, self)
		self._regions[#self._regions + 1] = self._barTexture
	end
	self._barTexture:SetTexture(asset)
end
function Object:GetStatusBarTexture() return self._barTexture end

-- A FontString has a font once it inherits a template or SetFont or SetFontObject gives it one.
-- Until then SetText and SetFormattedText raise the game's "Font not set" error.
local function needFont(self, method)
	if self._type == "FontString" and not self._font then
		error("FontString:" .. method .. "(): Font not set", 3)
	end
end
local function fontGiven(self, method, font)
	if method == "SetFont" then
		self._font = type(font) == "string" and font ~= ""
	else
		self._font = font ~= nil
	end
end
for _, method in ipairs({ "SetText", "SetFormattedText" }) do
	local field = method:sub(4)
	Object[method] = function(self, ...)
		needFont(self, method)
		self._state[field] = pack(...)
	end
end
for _, method in ipairs({ "SetFont", "SetFontObject" }) do
	local field = method:sub(4)
	Object[method] = function(self, ...)
		fontGiven(self, method, ...)
		self._state[field] = pack(...)
	end
end

-- A texture's masks, in the order AddMaskTexture added them.
function Object:AddMaskTexture(mask)
	self._masks = self._masks or {}
	self._masks[#self._masks + 1] = mask
end
function Object:RemoveMaskTexture(mask)
	for i, existing in ipairs(self._masks or {}) do
		if existing == mask then
			table.remove(self._masks, i)
			return
		end
	end
end
function Object:GetNumMaskTextures() return self._masks and #self._masks or 0 end
function Object:GetMaskTexture(i) return self._masks and self._masks[i] end

for name in pairs(Object) do
	assert(METHODS[name], "stub method " .. name .. " is not a Forever widget method")
end

-- Create<Type> methods that make a region, which GetRegions lists.
local REGIONS = { Texture = true, FontString = true, MaskTexture = true, Line = true }

-- A documented method with no hand-written behaviour: Create<Type> makes a child, Set<X> stores its
-- arguments for Get<X>, and any other method does nothing.
local function genericMethod(key)
	local childType = key:match("^Create(%u%w*)$")
	if childType then
		return function(self, a, b, c, d)
			if childType == "Animation" then
				return newObject(self._env, a or "Animation", b, self)
			end
			local child = newObject(self._env, childType, type(a) == "string" and a or nil, self)
			if childType == "FontString" then
				child._font = type(c) == "string" and c ~= ""
			end
			if REGIONS[childType] then
				self._regions[#self._regions + 1] = child
				if type(b) == "string" then
					child._state.DrawLayer = pack(b, d or 0)
				end
			end
			return child
		end
	end
	local setField = key:match("^Set(%u%w*)$")
	if setField then
		return function(self, ...)
			self._state[setField] = pack(...)
		end
	end
	local getField = key:match("^Get(%u%w*)$")
	if getField then
		return function(self)
			local stored = self._state[getField]
			if stored then
				return unpack(stored, 1, stored.n)
			end
			return DEFAULTS[getField]
		end
	end
	return function() end
end

-- Quiet mode (env.SetQuiet) is for the performance check: a lookup returns one shared function per
-- method that records nothing, a repeated Set<X> refills its stored table, and anchors reuse their
-- point tables, so the stubs allocate nothing once a path has run.
local quietMethods = {}

local function refill(stored, ...)
	local n = select("#", ...)
	for i = 1, n do
		stored[i] = (select(i, ...))
	end
	for i = n + 1, stored.n do
		stored[i] = nil
	end
	stored.n = n
end

local function quietSetter(field)
	return function(self, ...)
		local stored = self._state[field]
		if stored then
			refill(stored, ...)
		else
			self._state[field] = pack(...)
		end
	end
end

local Quiet = {}

function Quiet:SetPoint(point, ...)
	local points = self._points
	for i = 1, #points do
		if points[i][1] == point then
			refill(points[i], point, ...)
			return
		end
	end
	local spare = self._sparePoints
	local slot = spare and spare[#spare]
	if slot then
		spare[#spare] = nil
		refill(slot, point, ...)
	else
		slot = pack(point, ...)
	end
	points[#points + 1] = slot
end

function Quiet:ClearAllPoints()
	local points = self._points
	if #points == 0 then
		return
	end
	local spare = self._sparePoints
	if not spare then
		spare = {}
		self._sparePoints = spare
	end
	for i = #points, 1, -1 do
		spare[#spare + 1] = points[i]
		points[i] = nil
	end
end

for _, method in ipairs({ "SetText", "SetFormattedText" }) do
	local set = quietSetter(method:sub(4))
	Quiet[method] = function(self, ...)
		needFont(self, method)
		set(self, ...)
	end
end
for _, method in ipairs({ "SetFont", "SetFontObject" }) do
	local set = quietSetter(method:sub(4))
	Quiet[method] = function(self, ...)
		fontGiven(self, method, ...)
		set(self, ...)
	end
end

local function quietMethod(key)
	local fn = quietMethods[key]
	if not fn then
		local setField = not Object[key] and key:match("^Set(%u%w*)$")
		fn = Quiet[key] or Object[key] or (setField and quietSetter(setField)) or genericMethod(key)
		quietMethods[key] = fn
	end
	return fn
end

-- Any other key reads as nil, as on a real frame.
ObjectMeta.__index = function(object, key)
	if not METHODS[key] then
		return nil
	end
	if object._env and object._env._quiet then
		return quietMethod(key)
	end
	local impl = Object[key] or genericMethod(key)
	return function(self, ...)
		if self._denied == true and key ~= "CanBeAccessedInContext" then
			error("Attempt to access a restricted object with " .. key, 2)
		end
		self._calls[#self._calls + 1] = { method = key, args = pack(...) }
		return impl(self, ...)
	end
end

-- Environment -----------------------------------------------------------------------------------

local Stubs = {}

-- Stubs.NewEnv(opts) -> env. opts: width, height (physical pixels, default 1920x1080), uiScale (1).
function Stubs.NewEnv(opts)
	opts = opts or {}
	local width, height, uiScale = opts.width or 1920, opts.height or 1080, opts.uiScale or 1
	local env = setmetatable({}, { __index = _G })
	env._G = env
	env._combat = false
	env._frames = {}
	local timers = {}

	env.UIParent = newObject(env, "Frame", "UIParent", nil)
	env.UIParent._scale = uiScale
	env.UIParent._width, env.UIParent._height = 768 * width / height / uiScale, 768 / uiScale

	function env.CreateFrame(frameType, name, parent, template)
		local frame = newObject(env, frameType, name, parent)
		frame._template = template
		if parent then
			parent._kids[#parent._kids + 1] = frame
		end
		env._frames[#env._frames + 1] = frame
		if name then
			env[name] = frame
		end
		return frame
	end

	-- CreateFont(name) makes a Font object, which SetFontObject and templates use.
	function env.CreateFont(name)
		local font = newObject(env, "Font", name, nil)
		if name then
			env[name] = font
		end
		return font
	end

	function env.FireEvent(event, ...)
		local frames = { unpack(env._frames) }
		for _, frame in ipairs(frames) do
			local registered = frame._events[event]
			local wanted = registered == true
			if type(registered) == "table" then
				for _, unit in ipairs(registered) do
					wanted = wanted or unit == (...)
				end
			end
			local handler = frame._scripts.OnEvent
			if wanted and handler then
				handler(frame, event, ...)
			end
		end
	end

	-- PLAYER_REGEN_DISABLED fires before lockdown starts, and PLAYER_REGEN_ENABLED after it ends. The
	-- secure state drivers rescan after each, as SecureStateDriverManager does on those events.
	function env.SetCombat(inCombat)
		if inCombat then
			env.FireEvent("PLAYER_REGEN_DISABLED")
			env._combat = true
		else
			env._combat = false
			env.FireEvent("PLAYER_REGEN_ENABLED")
		end
		env.RunStateDrivers()
	end

	function env.InCombatLockdown()
		return env._combat == true
	end

	-- SetQuiet(true) makes the stubs quiet for the performance check: frames stop recording their calls
	-- in _calls, and the stubs stop allocating once a path has run.
	function env.SetQuiet(quiet)
		quiet = quiet and true or false
		if quiet ~= (env._quiet == true) then
			quietEnvs = quietEnvs + (quiet and 1 or -1)
		end
		env._quiet = quiet
	end

	-- Forever's xpcall passes extra arguments to the function. Lua 5.1's does not, so on Lua 5.1 the
	-- stub's runs the function with pcall and hands an error to the handler after the stack unwinds.
	if select(2, xpcall(function(value)
		return value
	end, function() end, true)) ~= true then
		local function settle(handler, ok, ...)
			if ok then
				return true, ...
			end
			return false, handler((...))
		end
		function env.xpcall(fn, handler, ...)
			return settle(handler, pcall(fn, ...))
		end
	end

	function env.GetPhysicalScreenSize()
		return width, height
	end

	-- C_Timer.NewTicker returns a ticker with Cancel and IsCancelled; RunTickers runs each live one once.
	local tickers = {}
	env.C_Timer = {
		After = function(_, fn)
			timers[#timers + 1] = fn
		end,
		NewTicker = function(interval, fn)
			local ticker = { interval = interval, fn = fn, cancelled = false }
			function ticker.Cancel(self)
				self.cancelled = true
			end
			function ticker.IsCancelled(self)
				return self.cancelled
			end
			tickers[#tickers + 1] = ticker
			return ticker
		end,
	}

	function env.RunTickers()
		for _, ticker in ipairs({ unpack(tickers) }) do
			if not ticker.cancelled then
				ticker.fn(ticker)
			end
		end
	end
	function env.LiveTickers()
		local n = 0
		for _, ticker in ipairs(tickers) do
			if not ticker.cancelled then
				n = n + 1
			end
		end
		return n
	end

	-- A batch runs from its own list while new timers go to the other one, which the last batch freed.
	local spareTimers = {}
	function env.RunTimers()
		local rounds = 0
		while #timers > 0 do
			rounds = rounds + 1
			assert(rounds <= 1000, "RunTimers: timers keep scheduling timers")
			local batch = timers
			timers = spareTimers or {}
			spareTimers = nil
			for i = 1, #batch do
				batch[i]()
			end
			for i = #batch, 1, -1 do
				batch[i] = nil
			end
			spareTimers = batch
		end
	end

	function env.hooksecurefunc(a, b, c)
		local target, name, hook = a, b, c
		if type(a) == "string" then
			target, name, hook = env, a, b
		end
		local original = target[name]
		assert(type(original) == "function", "hooksecurefunc: no function " .. tostring(name))
		target[name] = function(...)
			local results = pack(original(...))
			hook(...)
			return unpack(results, 1, results.n)
		end
	end

	env.Secret = newSecret

	-- type() sees through a secret, as in the game.
	function env.type(value)
		return type(plain(value))
	end

	function env.issecretvalue(value)
		return secretValues[value] ~= nil
	end

	-- Reveal(secret) -> the value a test stored in it. Tests only: addon code never sees this.
	function env.Reveal(secret)
		return assert(secretValues[secret], "Reveal: not a secret value")[1]
	end

	-- The player and realm (opts.player, opts.realm), the clock (env._now, read by time()), the error
	-- handler (the default one records each error in env._errors) and the slash command table.
	function env.UnitName(unit)
		if unit == "player" then
			return opts.player or "Tester"
		end
	end
	function env.GetRealmName()
		return opts.realm or "Realm"
	end
	env._now = opts.now or 1700000000
	function env.time()
		return env._now
	end
	env._errors = {}
	local errorHandler = function(message)
		env._errors[#env._errors + 1] = message
	end
	function env.geterrorhandler()
		return errorHandler
	end
	function env.seterrorhandler(handler)
		errorHandler = handler
	end
	env.SlashCmdList = {}

	-- Input: the cursor (env._cursor, in the units GetCursorPosition returns: UIParent units times
	-- UIParent's effective scale) and the modifier keys (env._modifiers.shift and .ctrl).
	env._cursor = { 0, 0 }
	function env.GetCursorPosition()
		return env._cursor[1], env._cursor[2]
	end
	env._modifiers = {}
	function env.IsShiftKeyDown()
		return env._modifiers.shift == true
	end
	function env.IsControlKeyDown()
		return env._modifiers.ctrl == true
	end

	-- The player always exists; the target exists while env._target is true. SetTarget fires
	-- PLAYER_TARGET_CHANGED, then the state drivers rescan.
	env._target = false
	function env.UnitExists(unit)
		if unit == "player" then
			return true
		end
		return unit == "target" and env._target == true
	end
	function env.SetTarget(exists)
		env._target = exists and true or false
		env.FireEvent("PLAYER_TARGET_CHANGED")
		env.RunStateDrivers()
	end

	-- Macro options: "[cond,cond] value; [cond] value; default". The conditions known here are combat,
	-- nocombat, exists, noexists and a unit as @unit or target=unit (the default unit is the target).
	-- A test adds more by setting env.Condition(part, unit) -> true, false, or nil for an unknown part.
	local function holds(group)
		local unit, ok = "target", true
		for part in group:gmatch("[^,]+") do
			part = part:match("^%s*(.-)%s*$")
			local named = part:match("^@(.+)$") or part:match("^target=(.+)$")
			if named then
				unit = named
			elseif part == "combat" then
				ok = ok and env._combat == true
			elseif part == "nocombat" then
				ok = ok and env._combat ~= true
			elseif part == "exists" then
				ok = ok and env.UnitExists(unit) == true
			elseif part == "noexists" then
				ok = ok and env.UnitExists(unit) ~= true
			elseif env.Condition and env.Condition(part, unit) ~= nil then
				ok = ok and env.Condition(part, unit) == true
			else
				error("SecureCmdOptionParse stub: unknown condition " .. part)
			end
		end
		return ok
	end
	function env.SecureCmdOptionParse(options)
		for clause in (options .. ";"):gmatch("([^;]*);") do
			local rest = clause:match("^%s*(.-)%s*$")
			local groups = {}
			while rest:sub(1, 1) == "[" do
				local group, after = rest:match("^%[([^%]]*)%]%s*(.*)$")
				assert(group, "SecureCmdOptionParse stub: unclosed [ in " .. options)
				groups[#groups + 1] = group
				rest = after
			end
			if #groups == 0 then
				return rest
			end
			for _, group in ipairs(groups) do
				if holds(group) then
					return rest
				end
			end
		end
		return nil
	end

	-- State drivers, as SecureStateDriver.lua runs them: a "visibility" driver shows or hides the
	-- frame from secure code (env._secure is true meanwhile) and sets "statehidden"; any other state
	-- sets the attribute "state-<state>". A driver resolves when registered and on RunStateDrivers.
	env._drivers = {}
	local function resolveDriver(entry)
		local value = env.SecureCmdOptionParse(entry.values)
		local frame = entry.frame
		env._secure = true
		if entry.state == "visibility" then
			if value == "show" then
				frame:Show()
				frame:SetAttribute("statehidden", nil)
			elseif value == "hide" then
				frame:Hide()
				frame:SetAttribute("statehidden", true)
			end
		elseif value ~= nil then
			frame:SetAttribute("state-" .. entry.state, tonumber(value) or value)
		end
		env._secure = false
	end
	function env.UnregisterStateDriver(frame, state)
		for i = #env._drivers, 1, -1 do
			local entry = env._drivers[i]
			if entry.frame == frame and entry.state == state then
				table.remove(env._drivers, i)
			end
		end
	end
	function env.RegisterStateDriver(frame, state, values)
		env.UnregisterStateDriver(frame, state)
		if values == nil or values == "" then
			return
		end
		local entry = { frame = frame, state = state, values = values }
		env._drivers[#env._drivers + 1] = entry
		resolveDriver(entry)
	end
	function env.RunStateDrivers()
		for _, entry in ipairs({ unpack(env._drivers) }) do
			resolveDriver(entry)
		end
	end
	-- Driver(frame, state) -> the macro options registered for the frame's state, or nil.
	function env.Driver(frame, state)
		for _, entry in ipairs(env._drivers) do
			if entry.frame == frame and entry.state == state then
				return entry.values
			end
		end
	end

	return env
end

return Stubs
