-- wow.lua: a stub World of Warcraft API for offline tests. Extend it additively.
--
--   local Stubs = dofile("Tools/regression/stubs/wow.lua")
--   local env = Stubs.NewEnv({ width = 2560, height = 1440 })
--
-- Frames answer only the widget methods Forever documents (widget_methods.lua) and record every call
-- in frame._calls. Any other key reads as nil, so a call to a method Forever lacks fails the test.
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

function newSecret(value)
	local secret = secretTemplate and newproxy(secretTemplate) or setmetatable({}, secretMeta)
	secretValues[secret] = { value }
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
function Object:IsEventRegistered(event) return self._events[event] ~= nil end

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
		return function(self, a, b, _, d)
			if childType == "Animation" then
				return newObject(self._env, a or "Animation", b, self)
			end
			local child = newObject(self._env, childType, type(a) == "string" and a or nil, self)
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

-- Any other key reads as nil, as on a real frame.
ObjectMeta.__index = function(_, key)
	if not METHODS[key] then
		return nil
	end
	local impl = Object[key] or genericMethod(key)
	return function(self, ...)
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

	-- PLAYER_REGEN_DISABLED fires before lockdown starts, and PLAYER_REGEN_ENABLED after it ends.
	function env.SetCombat(inCombat)
		if inCombat then
			env.FireEvent("PLAYER_REGEN_DISABLED")
			env._combat = true
		else
			env._combat = false
			env.FireEvent("PLAYER_REGEN_ENABLED")
		end
	end

	function env.InCombatLockdown()
		return env._combat == true
	end

	function env.GetPhysicalScreenSize()
		return width, height
	end

	env.C_Timer = {
		After = function(_, fn)
			timers[#timers + 1] = fn
		end,
	}

	function env.RunTimers()
		local rounds = 0
		while #timers > 0 do
			rounds = rounds + 1
			assert(rounds <= 1000, "RunTimers: timers keep scheduling timers")
			local batch = timers
			timers = {}
			for _, fn in ipairs(batch) do
				fn()
			end
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

	return env
end

return Stubs
