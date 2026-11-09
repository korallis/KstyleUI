-- auras_env.lua: load the core and KstyleUI_Auras into a stub environment with a fake AuraContainer engine.
--
--   local A = dofile("Tools/regression/auras_env.lua")
--   local env, K, ns = A.New()            -- core booted, module loaded, engine faked
--   K.Modules.Enable("Auras")
--   local buffs = A.Container(env, "HELPFUL")
--
-- The fake engine follows Blizzard_AuraContainer on the forever branch: CustomAuraContainerTemplate's
-- inbound methods validate their arguments as the real asserts do, AddAuraGroup creates a batch of ten
-- aura buttons and runs initializeFrame on each before access restrictions apply, and an aura button
-- answers the CustomAuraButton inbound methods. While env._aurasSecret is true, any call that reaches a
-- restricted aura button raises "access denied", as DenyTaintedAccessWhenAurasAreSecret does.
local W = dofile("Tools/regression/widget_env.lua")
local TocFiles = dofile("Tools/regression/toc_files.lua")
local Load = dofile("Tools/regression/load_files.lua")

local A = { W = W }

local BATCH = 10
local FILTER_WORDS = { HELPFUL = true, HARMFUL = true, PLAYER = true, RAID = true, CANCELABLE = true }
-- The rest of AuraUtil.AuraFilters, which nameplate debuff groups use.
for _, word in ipairs({ "INCLUDE_NAME_PLATE_ONLY", "MAW", "EXTERNAL_DEFENSIVE", "CROWD_CONTROL", "RAID_IN_COMBAT", "RAID_PLAYER_DISPELLABLE", "BIG_DEFENSIVE", "IMPORTANT", "DISPELLABLE" }) do
	FILTER_WORDS[word] = true
end

function A.ModuleFiles()
	local files = {}
	for _, path in ipairs(TocFiles("%.lua$")) do
		if path:match("^KstyleUI_Auras/") then
			files[#files + 1] = path
		end
	end
	assert(#files > 0, "KstyleUI_Auras has no Lua files")
	return files
end

local function enumValid(enum, value)
	for _, v in pairs(enum) do
		if v == value then
			return true
		end
	end
	return false
end

local function validFilter(filter)
	if type(filter) ~= "string" or filter == "" then
		return false
	end
	for word in filter:gmatch("[^|%s]+") do
		if not FILTER_WORDS[word:gsub("^!", "")] then
			return false
		end
	end
	return true
end

local function checkLayout(layout)
	if layout == nil then
		return
	end
	assert(type(layout) == "table", "layout must be a table or nil.")
	for _, key in ipairs({ "elementSpacing", "lineSpacing", "groupSpacing", "groupLineSpacing", "layoutIndex" }) do
		assert(layout[key] == nil or type(layout[key]) == "number", key .. " must be a number.")
	end
	for _, key in ipairs({ "elementWidth", "elementHeight" }) do
		assert(layout[key] == nil or (type(layout[key]) == "number" and layout[key] >= 0), key .. " must be a non-negative number.")
	end
end

local function checkCount(n)
	assert(n == math.huge or (type(n) == "number" and n >= 0 and n == math.floor(n)), "maxFrameCount must be a non-negative integer or infinity.")
end

-- Descendants(object) -> the object and every frame and region made on it, depth first.
function A.Descendants(object, out)
	out = out or {}
	out[#out + 1] = object
	for _, kid in ipairs(object._kids or {}) do
		A.Descendants(kid, out)
	end
	for _, region in ipairs(object._regions or {}) do
		A.Descendants(region, out)
	end
	return out
end

-- CallCount(object) -> the number of method calls on the object and everything made on it.
function A.CallCount(object)
	local n = 0
	for _, o in ipairs(A.Descendants(object)) do
		n = n + #o._calls
	end
	return n
end

local function isDescendant(object, owner)
	local parent = object:GetParent()
	while parent do
		if parent == owner then
			return true
		end
		parent = parent:GetParent()
	end
	return false
end

local function newButton(env, container)
	local button = env.CreateFrame("Button", nil, container)
	button._aura = { dispel = {} }
	local aura = button._aura
	local function guard(name)
		if button._restricted and env._aurasSecret then
			error("access denied: " .. name .. " on an aura button while auras are secret", 3)
		end
		button._calls[#button._calls + 1] = { method = name }
	end
	local function element(object, kind)
		assert(object ~= button and isDescendant(object, button), "bad object in function call (must be the owner or a direct or indirect descendant of owner)")
		assert(object:GetObjectType() == kind, "bad object in function call (expected object type '" .. kind .. "')")
	end
	function button.SetIcon(_, texture)
		guard("SetIcon")
		element(texture, "Texture")
		aura.icon = texture
	end
	function button.SetDurationText(_, text, options)
		guard("SetDurationText")
		element(text, "FontString")
		aura.timer, aura.timerOptions = text, options or {}
	end
	function button.SetDurationCooldown(_, cooldown)
		guard("SetDurationCooldown")
		element(cooldown, "Cooldown")
		aura.cooldown = cooldown
	end
	function button.ClearDurationText()
		guard("ClearDurationText")
		aura.timer, aura.timerOptions = nil, nil
	end
	function button.SetApplicationCount(_, text, options)
		guard("SetApplicationCount")
		element(text, "FontString")
		aura.count, aura.countOptions = text, options
	end
	function button.ClearApplicationCount()
		guard("ClearApplicationCount")
		aura.count = nil
	end
	function button.AddDispelTypeTexture(_, texture, options)
		guard("AddDispelTypeTexture")
		element(texture, "Texture")
		for _, entry in ipairs(aura.dispel) do
			assert(entry.texture ~= texture, "Display element has already been added.")
		end
		aura.dispel[#aura.dispel + 1] = { texture = texture, options = options or {} }
	end
	function button.ClearDispelTypeTextures()
		guard("ClearDispelTypeTextures")
		aura.dispel = {}
	end
	function button.SetCancelAuraButtons(_, buttons)
		guard("SetCancelAuraButtons")
		assert(buttons == nil or type(buttons) == "string", "cancelAuraButtons must be a string or nil.")
		aura.cancel = buttons
	end
	function button.SetTooltipAnchorPoint(_, point)
		guard("SetTooltipAnchorPoint")
		aura.tooltip = point
	end
	for _, name in ipairs({ "SetSize", "SetWidth", "SetHeight", "SetPoint", "ClearAllPoints", "GetEffectiveScale", "IsProtected", "HookScript", "SetScript", "IsMouseOver", "GetChildren" }) do
		local method = button[name]
		button[name] = function(self, ...)
			if button._restricted and env._aurasSecret then
				error("access denied: " .. name .. " on an aura button while auras are secret", 2)
			end
			return method(self, ...)
		end
	end
	return button
end

local function makeButton(env, container, initializeFrame)
	local button = newButton(env, container)
	if initializeFrame then
		initializeFrame(button)
	end
	button._restricted = true
	button._shown = false
	container._buttons[#container._buttons + 1] = button
	return button
end

local function installContainer(env, container)
	container._groups, container._buttons, container._enchants, container._flow = {}, {}, {}, {}
	-- The engine lays an empty flow container out at its one-unit floor (AnchorUtil.ApplyFlowLayout), so an overflow
	-- chip's counting container never reads as a count before a test or a scene plays its layout pass.
	container:SetSize(1, 1)
	container._order = {}
	function container.SetUnit(self, unit)
		assert(type(unit) == "string")
		self._unit = unit
	end
	function container.AddAuraGroup(self, key, filter, options)
		assert(type(key) == "string" and key ~= "", "groupKey must be a non-empty string.")
		assert(validFilter(filter), "invalid filter string " .. tostring(filter))
		assert(not self._groups[key], "aura group '" .. key .. "' already exists with this key.")
		options = options or {}
		local sortMethod = options.sortMethod or env.AuraContainerSortMethod.Default
		local sortDirection = options.sortDirection or env.AuraContainerSortDirection.Normal
		assert(enumValid(env.AuraContainerSortMethod, sortMethod), "sortMethod must be a valid AuraContainerSortMethod.")
		assert(enumValid(env.AuraContainerSortDirection, sortDirection), "sortDirection must be a valid AuraContainerSortDirection.")
		local maxFrameCount = options.maxFrameCount or math.huge
		checkCount(maxFrameCount)
		checkLayout(options.layout)
		assert(options.initializeFrame == nil or type(options.initializeFrame) == "function", "initializeFrame must be a function or nil.")
		local candidates = options.candidateFilters
		assert(candidates == nil or type(candidates) == "table", "candidateFilters must be a table or nil.")
		for _, field in ipairs({ "includeDispelTypes", "excludeDispelTypes", "includeSpellIDs", "excludeSpellIDs" }) do
			assert(candidates == nil or candidates[field] == nil or type(candidates[field]) == "table", field .. " must be a table or nil")
		end
		local group = {
			key = key, filter = filter, enabled = true, maxFrameCount = maxFrameCount, candidateFilters = candidates,
			sortMethod = sortMethod, sortDirection = sortDirection, layout = options.layout, frames = {},
			initializeFrame = options.initializeFrame,
		}
		self._groups[key] = group
		self._order[#self._order + 1] = key
		env._initializers[key] = options.initializeFrame
		for _ = 1, BATCH do
			group.frames[#group.frames + 1] = makeButton(env, self, options.initializeFrame)
		end
	end
	function container.HasAuraGroup(self, key)
		return self._groups[key] ~= nil
	end
	function container.GetAuraGroupFrameCount(self, key)
		local group = self._groups[key]
		return group and #group.frames or 0
	end
	function container.GetAuraGroupFrame(self, key, index)
		local group = self._groups[key]
		return group and group.frames[index]
	end
	local function required(self, key)
		local group = self._groups[key]
		assert(group, "aura group '" .. tostring(key) .. "' was not found with this key.")
		return group
	end
	function container.SetAuraGroupEnabled(self, key, enabled)
		assert(type(enabled) == "boolean", "enabled must be a boolean.")
		required(self, key).enabled = enabled
	end
	function container.SetAuraGroupCandidateFilters(self, key, candidates)
		assert(candidates == nil or type(candidates) == "table", "candidateFilters must be a table or nil.")
		required(self, key).candidateFilters = candidates
	end
	function container.SetAuraGroupFilterString(self, key, filter)
		assert(validFilter(filter), "invalid filter string " .. tostring(filter))
		required(self, key).filter = filter
	end
	function container.SetEditModePreviewEnabled(self, enabled)
		self._editModePreview = enabled
	end
	function container.SetAuraGroupMaxFrameCount(self, key, n)
		checkCount(n)
		required(self, key).maxFrameCount = n
	end
	function container.SetAuraGroupSortMethod(self, key, method, direction)
		assert(enumValid(env.AuraContainerSortMethod, method), "sortMethod must be a valid AuraContainerSortMethod.")
		assert(enumValid(env.AuraContainerSortDirection, direction), "sortDirection must be a valid AuraContainerSortDirection.")
		local group = required(self, key)
		group.sortMethod, group.sortDirection = method, direction
	end
	function container.SetAuraGroupLayout(self, key, layout)
		checkLayout(layout)
		required(self, key).layout = layout
	end
	function container.SetFlowLayoutAnchorPoint(self, point)
		assert(type(point) == "string", "anchorPoint must be a string.")
		self._flow.anchor = point
	end
	function container.SetFlowLayoutGrowthDirection(self, h, v)
		assert(enumValid(env.AnchorUtil.FlowDirection, h), "horizontalDirection must be valid.")
		assert(enumValid(env.AnchorUtil.FlowDirection, v), "verticalDirection must be valid.")
		self._flow.horizontal, self._flow.vertical = h, v
	end
	function container.SetFlowLayoutAxis(self, axis)
		assert(enumValid(env.AnchorUtil.FlowLayoutAxis, axis), "layoutAxis must be valid.")
		self._flow.axis = axis
	end
	function container.SetFlowLayoutMaximumLineSize(self, size)
		assert(size == nil or type(size) == "number", "maximumLineSize must be a number or nil.")
		self._flow.lineSize = size
	end
	function container.AddItemEnchantment(self, slot, options)
		assert(enumValid(env.AuraContainerItemEnchantmentSlot, slot), "itemEnchantmentSlot must be a valid AuraContainerItemEnchantmentSlot.")
		assert(not self._enchants[slot], "item enchantment already exists with this slot.")
		options = options or {}
		local button = makeButton(env, self, options.initializeFrame)
		self._enchants[slot] = { enabled = true, frame = button, hidePermanent = options.hidePermanent }
		return button
	end
	function container.SetItemEnchantmentEnabled(self, slot, enabled)
		assert(type(enabled) == "boolean", "enabled must be a boolean.")
		assert(self._enchants[slot], "item enchantment was not found with this slot.")
		self._enchants[slot].enabled = enabled
	end
	function container.SetItemEnchantmentLayout(self, layout)
		checkLayout(layout)
		if layout and layout.placement ~= nil then
			assert(enumValid(env.CustomAuraContainerItemEnchantmentPlacement, layout.placement), "placement must be a valid CustomAuraContainerItemEnchantmentPlacement.")
		end
		self._enchantLayout = layout
	end
end

local function fakeFormatter(env, name)
	local f = { name = name, calls = {} }
	local mt = {
		__index = function(_, method)
			return function(_, ...)
				f.calls[#f.calls + 1] = { method = method, args = { ... } }
			end
		end,
	}
	setmetatable(f, mt)
	env._formatters[#env._formatters + 1] = f
	return f
end

-- Engine(env, opts) installs the engine's globals in env. opts.noContainer makes CreateFrame refuse the
-- AuraContainer type, as a client without Blizzard_AuraContainer would.
function A.Engine(env, opts)
	opts = opts or {}
	env._formatters = {}
	env._containers = {}
	env._initializers = {}
	env._aurasSecret = false
	env._enchants = {}
	env.Enum = env.Enum or {}
	env.Enum.CustomAuraButtonDispelTypeTextureStyle = { Border = 0, BorderWithIcon = 1, Icon = 2, PreserveAsset = 3, CustomAsset = 4 }
	env.Enum.LuaCurveType = { Linear = 0, Step = 1, Cosine = 2, Cubic = 3 }
	env.Enum.DurationTextBindingProperty = { RemainingDuration = 0, RemainingPercent = 1 }
	env.Enum.SecondsFormatterAbbreviation = { None = 0, Truncate = 1, OneLetter = 2 }
	env.Enum.SecondsFormatterInterval = { Seconds = 0, Minutes = 1, Hours = 2, Days = 3 }
	env.Enum.SecondsFormatterRounding = { RoundUp = 0, Truncate = 1 }
	env.AuraContainerSortMethod = {
		Default = 0, BigDefensive = 1, UnitFrameDebuff = 2, ImportantOnly = 3, Expiration = 4,
		ExpirationOnly = 5, Name = 6, NameOnly = 7, AuraInstanceIDOnly = 8,
	}
	env.AuraContainerSortDirection = { Normal = 0, Reverse = 1 }
	env.AuraContainerItemEnchantmentSlot = { MainHand = 0, OffHand = 1, Ranged = 2 }
	env.CustomAuraContainerItemEnchantmentPlacement = { BeforeAuraGroups = 0, AfterAuraGroups = 1 }
	env.AnchorUtil = {
		FlowLayoutAxis = { Horizontal = 0, Vertical = 1 },
		FlowDirection = { Left = -1, Right = 1, Up = 1, Down = -1 },
	}
	env.INVSLOT_MAINHAND, env.INVSLOT_OFFHAND, env.INVSLOT_RANGED = 16, 17, 18
	-- Blizzard_SharedXML/Mainline/InputUtil.lua and C_InputInterfaceStyle. env._interfaceStyle is the
	-- current style; fire INPUT_DEVICE_INTERFACE_TRANSITION after changing it, as the client does.
	env.Enum.InputDeviceInterfaceType = { Mkb = 0, Gamepad = 1 }
	env._interfaceStyle = env.Enum.InputDeviceInterfaceType.Mkb
	env.C_InputInterfaceStyle = {
		GetCurrentStyle = function()
			return env._interfaceStyle
		end,
	}
	env.InputUtil = {
		IsGamepadUIEnabled = function()
			return env.C_InputInterfaceStyle.GetCurrentStyle() == env.Enum.InputDeviceInterfaceType.Gamepad
		end,
	}
	env.C_Secrets = {
		ShouldAurasBeSecret = function()
			return env._aurasSecret == true
		end,
	}
	env.C_PaperDollInfo = {
		GetTemporaryEnchantmentInfo = function(slot)
			return env._enchants[slot]
		end,
	}
	env.C_StringUtil = {
		CreateSecondsFormatter = function()
			return fakeFormatter(env, "seconds")
		end,
	}
	local default = fakeFormatter(env, "default")
	env.AuraContainerInbound = {
		GetDefaultAuraDurationFormatter = function()
			return default
		end,
	}
	env.C_CurveUtil = {
		CreateColorCurve = function()
			local curve = { points = {} }
			function curve.SetType(self, t)
				self.type = t
			end
			function curve.AddPoint(self, x, color)
				self.points[#self.points + 1] = { x = x, color = color }
			end
			return curve
		end,
	}
	env.CreateColor = function(r, g, b, a)
		return {
			r = r, g = g, b = b, a = a,
			GetRGB = function(self)
				return self.r, self.g, self.b
			end,
			GetRGBA = function(self)
				return self.r, self.g, self.b, self.a
			end,
		}
	end
	env.DEBUFF_TYPE_MAGIC_COLOR = env.CreateColor(0.2, 0.6, 1, 1)
	env.DEBUFF_TYPE_CURSE_COLOR = env.CreateColor(0.6, 0, 1, 1)
	env.DEBUFF_TYPE_POISON_COLOR = env.CreateColor(0, 0.6, 0, 1)
	env.DEBUFF_TYPE_DISEASE_COLOR = env.CreateColor(0.6, 0.4, 0, 1)
	env.DEBUFF_TYPE_NONE_COLOR = env.CreateColor(0.8, 0, 0, 1)
	local create = env.CreateFrame
	env.CreateFrame = function(frameType, name, parent, template)
		if frameType == "AuraContainer" then
			if opts.noContainer then
				error("CreateFrame: Unknown frame type 'AuraContainer'")
			end
			local container = create(frameType, name, parent, template)
			if template == "CustomAuraContainerTemplate" then
				installContainer(env, container)
				env._containers[#env._containers + 1] = container
			end
			return container
		end
		return create(frameType, name, parent, template)
	end
	env.BuffFrame = create("Frame", "BuffFrame", env.UIParent)
	env.DebuffFrame = create("Frame", "DebuffFrame", env.UIParent)
	return env
end

-- New(opts) -> env, KstyleUI, the module's addon table. opts: W.New options, plus engine (A.Engine
-- options) and boot (false to load without ADDON_LOADED and PLAYER_LOGIN).
function A.New(opts)
	opts = opts or {}
	local setup = opts.setup
	local boot = opts.boot
	opts.boot = false
	opts.setup = function(env)
		A.Engine(env, opts.engine)
		if setup then
			setup(env)
		end
	end
	local env, K = W.New(opts)
	Load(A.ModuleFiles(), env)
	if boot ~= false then
		W.CoreEnv.Boot(env)
	end
	return env, K, env._addons.KstyleUI_Auras
end

-- Container(env, filter) -> the fake container whose aura group uses filter, or nil.
-- Container(env, filter, nth) -> the nth container (the first by default) with a group on the filter, and that
-- group: the first group in the order the module added them.
-- Rows(env) -> the containers that show auras: every container but the overflow chips' counting ones, whose one
-- group is keyed "count" (K.Widgets.Overflow).
function A.Rows(env)
	local out = {}
	for _, container in ipairs(env._containers) do
		if not container._groups.count then
			out[#out + 1] = container
		end
	end
	return out
end

function A.Container(env, filter, nth)
	local seen = 0
	for _, container in ipairs(A.Rows(env)) do
		for _, key in ipairs(container._order) do
			local group = container._groups[key]
			if group.filter == filter then
				seen = seen + 1
				if seen == (nth or 1) then
					return container, group
				end
				break
			end
		end
	end
end

-- MakeButton(env, container, initializeFrame) -> a new aura button, made as the engine makes a later batch.
-- Assign(env, container, key, count) -> the frames shown. Assigns `count` auras to a group as the engine's
-- frame refresh does: the first min(count, maxFrameCount) frames show and the rest hide, frames are made in
-- batches as needed, and a frame whose visibility changes runs OnShow or OnHide on itself and on every shown
-- descendant, as the game does when a parent shows or hides.
local function fireVisibility(frame, script)
	local fn = frame._scripts and frame._scripts[script]
	if fn then
		fn(frame)
	end
	for _, kid in ipairs(frame._kids or {}) do
		if kid._shown then
			fireVisibility(kid, script)
		end
	end
end

function A.Assign(env, container, key, count)
	local group = assert(container._groups[key], "no aura group " .. tostring(key))
	local want = math.min(count, group.maxFrameCount)
	while #group.frames < want do
		for _ = 1, BATCH do
			group.frames[#group.frames + 1] = makeButton(env, container, group.initializeFrame)
		end
	end
	for i, frame in ipairs(group.frames) do
		local shown = i <= want
		if frame._shown ~= shown then
			frame._shown = shown
			fireVisibility(frame, shown and "OnShow" or "OnHide")
		end
	end
	group.assigned = count
	return want
end

-- Ghosts(chip, counts) plays the engine's layout pass for an overflow chip's counting containers (K.Widgets.Overflow):
-- counts[g] auras pass the chip's g-th group (a number counts the first), each counting container holds as many as
-- its group allows while it is enabled, one line of chip.pitch units each, and an empty one keeps one unit.
function A.Ghosts(chip, counts)
	if type(counts) == "number" then
		counts = { counts }
	end
	local function lay(ghost, n)
		local group = ghost._groups.count
		local held = group.enabled and ghost._enabled ~= false and math.min(n, group.maxFrameCount) or 0
		ghost:SetSize(1, math.max(1, held * chip.pitch))
	end
	for g, pair in ipairs(chip.pairs) do
		local n = counts[g] or 0
		lay(pair.a, n)
		if pair.b then
			lay(pair.b, n)
		end
	end
end

-- Counters(ns, counts) lays out the Blessings card's counting containers, its cap's and its full list's, for counts
-- auras in each group (buffs, dispellable debuffs, the rest), as the engine's layout pass would.
function A.Counters(ns, counts)
	local desc = ns.Panel.Group("buffs")
	local card = desc and desc.card
	for _, chip in ipairs({ card and card.counter or false, card and card.moreCounter or false }) do
		if chip then
			A.Ghosts(chip, counts)
		end
	end
end

-- Chip(chip) -> the text the chip's window shows (nil when no label sits in it), and whether its face fills the
-- window. Geometry runs from the window, so the chip reads the same wherever its host sits.
function A.Chip(chip)
	local Geometry = dofile("Tools/regression/geometry.lua")
	if not chip.window:IsShown() then
		return nil, false
	end
	local root = chip.window
	local win = assert(Geometry.Rect(root, root))
	local eps = 1e-3
	local strip = Geometry.Rect(chip.strip, root)
	local face = strip ~= nil and strip.bottom <= win.bottom + eps and strip.top >= win.top - eps
	for i, label in ipairs(chip.labels) do
		local r = Geometry.Rect(label, root)
		if r and math.abs(r.top - win.top) < eps and math.abs(r.bottom - win.bottom) < eps then
			return chip.texts[i]:GetText(), face
		end
	end
	return nil, face
end

function A.MakeButton(env, container, initializeFrame)
	return makeButton(env, container, initializeFrame)
end

-- Buttons(container) -> every aura button the container made, groups and enchantments alike.
function A.Buttons(container)
	return container._buttons
end

function A.Hidden(env, frame)
	local parent = frame:GetParent()
	return parent ~= nil and parent ~= env.UIParent and parent:IsShown() == false
end

return A
