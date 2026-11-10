-- native_menu_fixture.lua: Forever 1.60.1.70862's native menu pipeline on the stub environment, written from Blizzard_Menu's Menu.lua, MenuUtil.lua, Compositor.lua, MenuTemplates.lua and MenuVariants.lua (commit 9dc84f0). It models behaviour, not Blizzard code.
--
--   local Native = dofile("Tools/regression/native_menu_fixture.lua")
--   local nm = Native.Install(env, { variant = "mainline", measure = function(text, path, size) return width end })
--   local menu = env.MenuUtil.CreateContextMenu(owner, function(owner, root) root:CreateButton("Go", fn) end)
--   nm.Close(menu)
--
-- What it keeps from the game:
--   * MenuUtil.CreateContextMenu builds a root description, runs the generator and then every Menu.ModifyMenu callback
--     registered for the description's tag (Menu.PopulateDescription), and opens it through a menu manager.
--   * A menu frame comes from a pool. Its compositor replaces the metatable of the frame and of every texture, font
--     string and frame attached through it: CreateTexture, CreateFontString and the like raise, a font string's SetFont
--     raises, and AttachTexture and AttachFontString take regions from pools. The style's Generate attaches the
--     background, then the menu-acquired callbacks run, then the elements are made and initialised (the description's
--     initializers in order, then its final initializer), then the menu is laid out and shown.
--   * Closing runs the released callbacks, detaches every compositor (the original metatables come back and the
--     attachments go back to their pools, which reset them: SetToDefaults clears anchors, state, scripts and the call
--     history) and returns the menu frame to its pool. A pooled region comes back by the next acquisition, in whatever
--     menu asks for one.
--   * nm.Reinitialize (a checkbox answers MenuResponse.Refresh) clears each element's compositor and runs its
--     initializers again over fresh regions.
--
-- Submenus are modelled as Menu.lua does: a button description that has elements opens a second menu from the same pool, the
-- child shares the root's acquired, released and response callbacks, closing a parent closes its children first, and a
-- leaf answered in a child closes every menu.
--
-- Layout follows Menu.lua's PerformLayout: every row is as wide as the widest row (at least the menu's 50-unit minimum element
-- width, rounded) plus the style's child extent padding (Mainline/MenuTemplates.lua: 20 wide, none high; the variants built on the
-- mainline style carry it, the others have none), and the menu is that width plus the style's left and right insets, and the
-- rows' heights plus its top and bottom insets. The 68 x 68 unit common-dropdown-bg is drawn stretched to its anchors; whether the
-- game stretches its transparent margin too is not known, so how far its rim sits inside the menu frame is not claimed.
--
-- What it does not model: grids, scrolling, gamepad focus, tooltips, narration, taint, the real frame
-- hierarchy of MenuTemplateBase beyond its four hidden child frames, or the engine's text layout. Text widths come from
-- opts.measure or a fixed advance, and SetTextToFit is taken to set the string's width to its text's width in the font
-- it has at that moment, an inference from the name and from Compositor's 150-unit default width.
--
-- A stub frame answers IsForbidden and IsProtected with nothing; Forever answers booleans, and the context-menu skin writes only
-- to objects that answer false, so Install gives every frame the environment makes (and has made) real answers: a frame made
-- from a Secure template is protected.
--
-- nm.Guard(object, kind) makes an object protected, forbidden or secret ("trap" only watches) and makes every method that
-- writes raise when the caller is KstyleUI's code (a chunk under Core/ or KstyleUI_*/). The fixture's own writes, which
-- stand for the engine's, still go through, as do the helpers in Tools/ that drive a test. A fourth argument maps method names to replacements, such as a GetAtlas that answers
-- a secret, for as long as the guard lasts.
--
-- nm.Snapshot(menu) returns a text of every visible fact of a menu, so two openings compare equal.
local Methods = dofile("Tools/regression/stubs/widget_methods.lua")

local Fixture = {}

local NATIVE_FONT = { "Fonts\\FRIZQT__.TTF", 12, "" }
local DISABLED = { 0.5, 0.5, 0.5 }

local WRITES = {}
for _, name in ipairs(Methods) do
	local writes = name:match("^Set") or name:match("^Clear") or name:match("^Add") or name:match("^Remove") or name:match("^Create")
		or name:match("^Attach") or name:match("^Register") or name:match("^Unregister") or name:match("^Enable")
		or name:match("^Disable") or name == "Hide" or name == "Show" or name == "HookScript"
	if writes and name ~= "SetToDefaults" then
		WRITES[#WRITES + 1] = name
	end
end
WRITES[#WRITES + 1] = "NewTicker"

local FRAME_DISALLOWED = {
	SetForbidden = true, CreateTexture = true, CreateMaskTexture = true, CreateFontString = true,
	CreateAnimationGroup = true, CreateLine = true,
}

local VARIANTS = {}

function VARIANTS.mainline(menu)
	local background = menu:AttachTexture()
	background:SetAtlas("common-dropdown-bg")
	background:SetPoint("TOPLEFT", -10, 3)
	background:SetPoint("BOTTOMRIGHT", 10, -3)
	background:SetAlpha(0.925)
	return { left = 8, top = 8, right = 8, bottom = 15 }
end

function VARIANTS.classic(menu)
	local background = menu:AttachTexture()
	background:SetAtlas("common-dropdown-classic-bg")
	background:SetPoint("TOPLEFT", -3, 3)
	background:SetPoint("BOTTOMRIGHT", 3, -4)
	local inner = menu:AttachTexture()
	inner:SetColorTexture(0, 0, 0, 0.8)
	inner:SetPoint("TOPLEFT", background, "TOPLEFT", 6, -6)
	inner:SetPoint("BOTTOMRIGHT", background, "BOTTOMRIGHT", -6, 6)
	local layer, sub = background:GetDrawLayer()
	inner:SetDrawLayer(layer, sub - 1)
	return { left = 16, top = 10, right = 16, bottom = 10 }
end

function VARIANTS.unknown(menu)
	local texture = menu:AttachTexture()
	texture:SetAllPoints()
	texture:SetColorTexture(0, 1, 0, 0.5)
	return { left = 0, top = 0, right = 0, bottom = 0 }
end

function VARIANTS.foreign(menu)
	local background = menu:AttachTexture()
	background:SetAtlas("tooltip-nineslice-center")
	background:SetAllPoints()
	return { left = 8, top = 8, right = 8, bottom = 8 }
end

function VARIANTS.twobackgrounds(menu)
	for _ = 1, 2 do
		local background = menu:AttachTexture()
		background:SetAtlas("common-dropdown-bg")
		background:SetPoint("TOPLEFT", -10, 3)
		background:SetPoint("BOTTOMRIGHT", 10, -3)
	end
	return { left = 8, top = 8, right = 8, bottom = 15 }
end

function VARIANTS.threeregions(menu)
	local inset = VARIANTS.mainline(menu)
	for _ = 1, 2 do
		local extra = menu:AttachTexture()
		extra:SetColorTexture(1, 1, 1, 0.1)
		extra:SetAllPoints()
	end
	return inset
end

Fixture.VARIANTS = VARIANTS

local PADDING = { mainline = 20, twobackgrounds = 20, threeregions = 20 }

local ATLAS_SIZES = { ["common-dropdown-ticksquare"] = { 12, 12 }, ["common-dropdown-icon-checkmark-yellow"] = { 15, 14 } }

function Fixture.Install(env, opts)
	opts = opts or {}
	local nm = {
		env = env,
		variant = opts.variant or "mainline",
		events = {},
		hooks = opts.hooks or {},
		at = opts.at,
		created = { Texture = 0, FontString = 0, Button = 0, Frame = 0, Menu = 0 },
		trapped = {},
		menus = {},
		staleCloses = 0,
		pooled = setmetatable({}, { __mode = "k" }),
		measure = opts.measure,
	}

	env.TextureKitConstants = env.TextureKitConstants or { UseAtlasSize = true, IgnoreAtlasSize = false }
	if not env.GameFontHighlight then
		local font = env.CreateFont("GameFontHighlight")
		font:SetFont(NATIVE_FONT[1], NATIVE_FONT[2], NATIVE_FONT[3])
	end
	local nativeFont = env.GameFontHighlight

	local function answer(frame)
		if rawget(frame, "IsForbidden") == nil then
			rawset(frame, "IsForbidden", function()
				return false
			end)
		end
		if rawget(frame, "IsProtected") == nil then
			rawset(frame, "IsProtected", function(self)
				local template = self._template
				return type(template) == "string" and template:find("Secure", 1, true) ~= nil, false
			end)
		end
	end
	for _, frame in ipairs(env._frames) do
		answer(frame)
	end
	answer(env.UIParent)
	local create = env.CreateFrame
	env.CreateFrame = function(...)
		local frame = create(...)
		answer(frame)
		return frame
	end

	local dummy = env.CreateFrame("Frame", nil, env.UIParent)
	dummy:Hide()

	local function event(text)
		nm.events[#nm.events + 1] = text
	end

	local function width(text, path, size)
		if nm.measure then
			return nm.measure(text, path, size)
		end
		return #text * size * 0.5
	end

	-- Regions and frames: what every Blizzard widget answers --------------------------------------------------------

	local function reset(self)
		self._state, self._points, self._scripts, self._calls = {}, {}, {}, {}
		self._masks, self._alpha, self._lastAlpha, self._enabled = nil, nil, false, true
		self._width, self._height = 0, 0
	end

	local function identity(object)
		rawset(object, "IsForbidden", function()
			return false
		end)
		rawset(object, "IsProtected", function()
			return false, false
		end)
		rawset(object, "SetToDefaults", reset)
		return object
	end

	local function regionParent(self, parent)
		self._parent = parent
	end

	local function newTexture()
		local texture = identity(dummy:CreateTexture(nil, "ARTWORK", nil, 7))
		rawset(texture, "SetParent", regionParent)
		nm.created.Texture = nm.created.Texture + 1
		nm.pooled[texture] = "Texture"
		return texture
	end

	local function newFontString()
		local text = identity(dummy:CreateFontString(nil, "ARTWORK", nil))
		text._font = false
		rawset(text, "SetParent", regionParent)
		rawset(text, "SetTextToFit", function(self, value)
			if nm.staleFit and self._fitted then
				return
			end
			self:SetText(value)
			local path, size = self:GetFont()
			self:SetWidth(width(value, path or NATIVE_FONT[1], size or NATIVE_FONT[2]))
		end)
		nm.created.FontString = nm.created.FontString + 1
		nm.pooled[text] = "FontString"
		return text
	end

	local function newFrame(kind)
		local frame = identity(env.CreateFrame(kind, nil, dummy))
		nm.created[kind] = (nm.created[kind] or 0) + 1
		nm.pooled[frame] = kind
		return frame
	end

	-- Pools -----------------------------------------------------------------------------------------------------------

	local function newPool(make, resetFn)
		local pool = { free = {} }
		function pool.Acquire()
			local object = table.remove(pool.free)
			if not object then
				object = make()
				resetFn(object, true)
			end
			return object
		end
		function pool.Release(object)
			resetFn(object, false)
			pool.free[#pool.free + 1] = object
		end
		return pool
	end

	local function regionReset(region, new)
		region:SetToDefaults()
		region:Hide()
		if not new then
			region:SetParent(dummy)
		end
	end

	local function frameReset(frame, new)
		frame:SetToDefaults()
		frame:Hide()
		if not new then
			frame:SetParent(dummy)
		end
	end

	local textures = newPool(newTexture, regionReset)
	local fontStrings = newPool(newFontString, regionReset)
	local buttons = newPool(function()
		return newFrame("Button")
	end, frameReset)
	local plainFrames = newPool(function()
		return newFrame("Frame")
	end, frameReset)
	local menuFrames = newPool(function()
		local frame = newFrame("Frame")
		nm.created.Menu = nm.created.Menu + 1
		nm.children = nm.children or {}
		for _, name in ipairs({ "FrameGlow", "LeftJumpHint", "RightJumpHint", "FocusJumpHint" }) do
			local child = env.CreateFrame("Frame", nil, frame)
			child:Hide()
			frame[name] = child
			nm.children[#nm.children + 1] = child
		end
		return frame
	end, function(frame, new)
		frame:SetToDefaults()
		frame:SetSize(1, 1)
		frame:Hide()
		if not new then
			frame:SetParent(dummy)
		end
	end)
	nm.pools = { textures = textures, fontStrings = fontStrings, buttons = buttons, frames = plainFrames, menus = menuFrames }

	-- Compositor ------------------------------------------------------------------------------------------------------

	local function configure(compositor, region, kind)
		local original = getmetatable(region)
		local values = {}
		local disallowed = {}
		if kind == "FontString" then
			disallowed = { SetFont = true }
		elseif kind ~= "Texture" then
			disallowed = FRAME_DISALLOWED
			values.AttachTexture = function(parent)
				return compositor:Attach(parent, textures, "Texture")
			end
			values.AttachFontString = function(parent)
				return compositor:Attach(parent, fontStrings, "FontString")
			end
			values.NewTicker = function(_, seconds, callback)
				compositor.ticker = { seconds = seconds, callback = callback }
			end
		end
		setmetatable(region, {
			__index = function(tbl, key)
				if disallowed[key] then
					error("Use of function '" .. key .. "' is disallowed on a compositor region", 2)
				end
				local value = values[key]
				if value ~= nil then
					return value
				end
				local index = original.__index
				if type(index) == "function" then
					return index(tbl, key)
				end
				return index[key]
			end,
			__newindex = values,
		})
		compositor.replaced[#compositor.replaced + 1] = { region = region, original = original }
	end

	local COMPOSITOR = {}
	COMPOSITOR.__index = COMPOSITOR

	local function newCompositor(target)
		local compositor = setmetatable({ attachments = {}, replaced = {}, target = target }, COMPOSITOR)
		configure(compositor, target, target:GetObjectType())
		return compositor
	end

	local DEFAULTS = {
		Texture = function(region)
			region:SetToDefaults()
			region:SetSize(1, 1)
			region:SetDrawLayer("ARTWORK", 0)
		end,
		FontString = function(region)
			region:SetToDefaults()
			region:SetSize(1, 1)
			region:SetFontObject(nativeFont)
			region:SetTextColor(1, 1, 1, 1)
			region:SetWidth(150)
			region:SetMaxLines(1)
			region:SetJustifyH("LEFT")
			region:SetJustifyV("MIDDLE")
		end,
	}

	function COMPOSITOR:Attach(parent, pool, kind)
		local region = pool.Acquire()
		self.attachments[#self.attachments + 1] = region
		region:SetParent(parent)
		DEFAULTS[kind](region)
		configure(self, region, kind)
		region:Show()
		return region
	end

	local function release(compositor)
		for _, region in ipairs(compositor.attachments) do
			if nm.pooled[region] == "Texture" then
				textures.Release(region)
			else
				fontStrings.Release(region)
			end
		end
		compositor.attachments = {}
	end

	function COMPOSITOR:Clear()
		for _, entry in ipairs(self.replaced) do
			if entry.region ~= self.target then
				setmetatable(entry.region, entry.original)
			end
		end
		release(self)
		self.replaced = { self.replaced[1] }
	end

	function COMPOSITOR:Detach()
		for _, entry in ipairs(self.replaced) do
			setmetatable(entry.region, entry.original)
		end
		self.replaced = {}
		release(self)
	end

	-- Guards ----------------------------------------------------------------------------------------------------------

	local function fromAddon()
		local info = debug.getinfo(3, "S")
		return info ~= nil and (info.source:find("^@Core/") ~= nil or info.source:find("^@KstyleUI_") ~= nil)
	end

	local function raiser(object, label, name)
		local ok, original = pcall(function()
			return object[name]
		end)
		if not ok then
			original = function()
				error("Use of function '" .. name .. "' is disallowed on a compositor region", 2)
			end
		end
		return function(...)
			if fromAddon() then
				error("a write reached " .. label .. ": " .. name, 2)
			end
			return original(...)
		end
	end

	local function trap(object, label, permanent)
		local saved = {}
		for _, name in ipairs(WRITES) do
			saved[name] = rawget(object, name)
			rawset(object, name, raiser(object, label, name))
		end
		if not permanent then
			nm.trapped[#nm.trapped + 1] = { object = object, saved = saved }
		end
	end

	function nm.Guard(object, kind, label, overrides)
		label = label or tostring(kind)
		local protected, forbidden = false, false
		if kind == "protected" then
			protected = true
		elseif kind == "forbidden" then
			forbidden = true
		elseif kind == "secretprotected" then
			protected = env.Secret(false)
		elseif kind == "secretforbidden" then
			forbidden = env.Secret(false)
		elseif kind ~= "trap" then
			error("nm.Guard: unknown kind " .. tostring(kind))
		end
		local keep = { IsProtected = rawget(object, "IsProtected"), IsForbidden = rawget(object, "IsForbidden") }
		if kind ~= "trap" then
			rawset(object, "IsProtected", function()
				return protected, false
			end)
			rawset(object, "IsForbidden", function()
				return forbidden
			end)
		end
		trap(object, label)
		local overridden = {}
		for name, fn in pairs(overrides or {}) do
			overridden[name] = { rawget(object, name) }
			rawset(object, name, fn)
		end
		nm.trapped[#nm.trapped].keep = keep
		nm.trapped[#nm.trapped].overridden = overridden
		return object
	end

	local function unguard()
		for _, entry in ipairs(nm.trapped) do
			for _, name in ipairs(WRITES) do
				rawset(entry.object, name, entry.saved[name])
			end
			for name, fn in pairs(entry.keep) do
				rawset(entry.object, name, fn)
			end
			for name, previous in pairs(entry.overridden) do
				rawset(entry.object, name, previous[1])
			end
		end
		nm.trapped = {}
	end

	-- Descriptions ----------------------------------------------------------------------------------------------------

	local Description = {}
	Description.__index = Description

	local function newDescription(kind, text, data)
		return setmetatable({ kind = kind, text = text, data = data, initializers = {}, elements = {}, enabled = true }, Description)
	end

	function Description:HasElements()
		return #self.elements > 0
	end
	function Description:EnumerateElementDescriptions()
		return ipairs(self.elements)
	end
	function Description:AddInitializer(initializer, index)
		table.insert(self.initializers, index or (#self.initializers + 1), initializer)
	end
	function Description:SetFinalInitializer(initializer)
		self.finalInitializer = initializer
	end
	function Description:GetFinalInitializer()
		return self.finalInitializer
	end
	function Description:SetTag(tag, contextData)
		self.tag, self.contextData = tag, contextData
	end
	function Description:GetTag()
		return self.tag, self.contextData
	end
	function Description:SetOnEnter(fn)
		self.onEnter = fn
	end
	function Description:SetOnLeave(fn)
		self.onLeave = fn
	end
	function Description:SetEnabled(enabled)
		self.enabled = enabled
	end
	function Description:IsEnabled()
		local enabled = self.enabled
		if type(enabled) == "function" then
			return enabled(self)
		end
		return enabled ~= false
	end
	function Description:SetResponder(fn)
		self.responder = fn
	end
	function Description:IsSelected()
		return self.isSelected ~= nil and self.isSelected(self.data) == true
	end
	function Description:CanOpenSubmenu()
		return #self.elements > 0
	end

	local Root = setmetatable({}, { __index = Description })
	Root.__index = Root
	function Root:AddMenuAcquiredCallback(callback)
		self.acquired[#self.acquired + 1] = callback
	end
	function Root:AddMenuReleasedCallback(callback)
		self.released[#self.released + 1] = callback
	end
	function Root:AddMenuResponseCallback(callback)
		self.response[#self.response + 1] = callback
	end

	-- Element templates -----------------------------------------------------------------------------------------------

	local function textInit(text)
		return function(frame)
			local fontString = frame:AttachFontString()
			local lead = frame.leftTexture1
			frame.fontString = fontString
			if lead then
				fontString:SetPoint("LEFT", lead, "RIGHT", 7, 1)
			else
				fontString:SetPoint("LEFT")
			end
			fontString:SetHeight(20)
			fontString._fitted = nil
			fontString:SetTextToFit(text)
			fontString._fitted = true
		end
	end

	local function createHighlight(button)
		local highlight = button:AttachTexture()
		button.highlight = highlight
		highlight:SetAllPoints()
		highlight:SetBlendMode("ADD")
		highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
		highlight:SetDrawLayer("BACKGROUND")
		highlight:Hide()
	end

	local function setHierarchyEnabled(frame, enabled)
		for _, region in ipairs({ frame:GetRegions() }) do
			if region:IsObjectType("FontString") and region.autoEnableTextColors then
				local color = region.autoEnableTextColors[enabled]
				region:SetTextColor(color[1], color[2], color[3], color[4])
			elseif region:IsObjectType("Texture") then
				region:SetDesaturation(enabled and 0 or 1)
			end
		end
		for _, child in ipairs({ frame:GetChildren() }) do
			setHierarchyEnabled(child, enabled)
		end
	end

	local function recurseSetupFontString(frame)
		for _, region in ipairs({ frame:GetRegions() }) do
			if region:IsObjectType("FontString") and not region.autoEnableTextColors then
				local enabled = { region:GetTextColor() }
				enabled[4] = enabled[4] or 1
				local colors = { [true] = enabled, [false] = { DISABLED[1], DISABLED[2], DISABLED[3], 1 } }
				local original = getmetatable(region).__index(region, "SetTextColor")
				region.SetTextColor = function(self, r, g, b, a)
					if not (r == DISABLED[1] and g == DISABLED[2] and b == DISABLED[3]) then
						colors[true] = { r, g, b, a or 1 }
					end
					original(self, r, g, b, a)
				end
				region.autoEnableTextColors = colors
			end
		end
		for _, child in ipairs({ frame:GetChildren() }) do
			recurseSetupFontString(child)
		end
	end

	local function buttonFinal(button, description, menu)
		recurseSetupFontString(button)
		local enabled = description:IsEnabled()
		button:SetEnabled(enabled)
		setHierarchyEnabled(button, enabled)
		button.owningMenu = menu
	end

	local function buttonInit(button)
		createHighlight(button)
		button.OnEnter = function(frame, desc)
			frame.highlight:Show()
			frame.highlight:SetAlpha(desc:IsEnabled() and 1 or 0.4)
		end
		button.OnLeave = function(frame)
			frame.highlight:Hide()
		end
		button:SetMotionScriptsWhileDisabled(true)
		button:SetScript("OnEnable", function(frame)
			setHierarchyEnabled(frame, true)
		end)
		button:SetScript("OnDisable", function(frame)
			setHierarchyEnabled(frame, false)
		end)
		button:SetScript("OnClick", function(frame, buttonName)
			nm.Pick(frame, buttonName)
		end)
	end

	local function checkInit(text)
		return function(frame, description)
			local box = frame:AttachTexture()
			frame.leftTexture1 = box
			box:SetAtlas("common-dropdown-ticksquare", env.TextureKitConstants.UseAtlasSize)
			box:SetSize(ATLAS_SIZES["common-dropdown-ticksquare"][1], ATLAS_SIZES["common-dropdown-ticksquare"][2])
			box:SetPoint("LEFT")
			frame.leftTexture2 = nil
			if description:IsSelected() then
				local mark = frame:AttachTexture()
				frame.leftTexture2 = mark
				local layer, sub = box:GetDrawLayer()
				mark:SetDrawLayer(layer, sub + 1)
				mark:SetAtlas("common-dropdown-icon-checkmark-yellow", env.TextureKitConstants.UseAtlasSize)
				mark:SetSize(ATLAS_SIZES["common-dropdown-icon-checkmark-yellow"][1], ATLAS_SIZES["common-dropdown-icon-checkmark-yellow"][2])
				mark:SetPoint("CENTER", box, "CENTER", 2, 1)
			end
			textInit(text)(frame)
		end
	end

	local function dividerInit(frame)
		local divider = frame:AttachTexture()
		frame.divider = divider
		divider:SetPoint("LEFT")
		divider:SetPoint("RIGHT")
		divider:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent")
		divider:SetHeight(13)
	end

	local function buttonDescription(kind, text, callback, data)
		local description = newDescription(kind, text, data)
		description.frameType = "Button"
		description:AddInitializer(buttonInit)
		description:SetFinalInitializer(buttonFinal)
		description:SetResponder(callback)
		return description
	end

	local function adopt(parent)
		function parent:CreateTitle(text)
			local description = newDescription("title", text)
			description.frameType = "Frame"
			description:AddInitializer(textInit(text))
			self.elements[#self.elements + 1] = description
			return description
		end
		function parent:CreateButton(text, callback, data)
			local description = buttonDescription("button", text, callback, data)
			description:AddInitializer(textInit(text))
			self.elements[#self.elements + 1] = description
			return description
		end
		function parent:CreateCheckbox(text, isSelected, onSelect, data)
			local description = buttonDescription("checkbox", text, onSelect, data)
			description.isSelected = isSelected
			description.response = "Refresh"
			description:AddInitializer(checkInit(text))
			self.elements[#self.elements + 1] = description
			return description
		end
		function parent:CreateDivider()
			local description = newDescription("divider")
			description.frameType = "Frame"
			description:AddInitializer(dividerInit)
			self.elements[#self.elements + 1] = description
			return description
		end
	end
	adopt(Root)
	adopt(Description)

	-- Menu.ModifyMenu and Menu.PopulateDescription --------------------------------------------------------------------

	local registry, generated = {}, {}
	env.Menu = env.Menu or {}
	function env.Menu.ModifyMenu(tag, callback)
		assert(type(tag) == "string")
		local entry = generated[tag]
		if entry then
			callback(entry[2], entry[1], entry[1].contextData)
		end
		registry[tag] = registry[tag] or {}
		registry[tag][#registry[tag] + 1] = callback
	end
	function env.Menu.PopulateDescription(generator, owner, description, ...)
		generator(owner, description, ...)
		local tag = description.tag
		if not tag then
			return
		end
		generated[tag] = { description, owner }
		for _, callback in ipairs(registry[tag] or {}) do
			callback(owner, description, description.contextData)
		end
	end
	nm.registry = registry

	-- Menus -----------------------------------------------------------------------------------------------------------

	local function extent(frame)
		local widest, tallest = 0, 0
		local function span(region)
			local w, h = region._width or 0, region._height or 0
			local point = region._points[1]
			if not point then
				return 0, 0, h
			end
			if #region._points > 1 then
				return 0, 1, h
			end
			local relative, x = point[2], point[4] or 0
			local base = 0
			if type(relative) == "table" and relative ~= frame then
				local left, right = span(relative)
				base = (point[3] or point[1]):find("RIGHT", 1, true) and right or left
			end
			return base + x, base + x + w, h
		end
		for _, region in ipairs({ frame:GetRegions() }) do
			local _, right, h = span(region)
			widest = math.max(widest, right)
			tallest = math.max(tallest, h)
		end
		return widest, tallest
	end

	local function callInitializers(menu, frame, description)
		frame:SetSize(1, 1)
		for index, initializer in ipairs(description.initializers) do
			event("init " .. tostring(description.kind) .. " " .. index)
			initializer(frame, description, menu.frame)
		end
		local w, h = extent(frame)
		if w > 0 and h > 0 then
			frame:SetSize(math.floor(w + 0.5), math.floor(h + 0.5))
		end
		if description.finalInitializer then
			event("final " .. tostring(description.kind))
			description.finalInitializer(frame, description, menu.frame)
		end
	end

	local function performLayout(menu)
		local frame, inset = menu.frame, menu.inset
		local widest, total = frame.minimumElementWidth, 0
		for _, row in ipairs(menu.rows) do
			widest = math.max(widest, row:GetWidth())
			total = total + row:GetHeight()
		end
		widest = math.floor(widest + 0.5) + menu.padding
		local y = inset.top
		for _, row in ipairs(menu.rows) do
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", frame, "TOPLEFT", inset.left, -y)
			row:SetWidth(widest)
			y = y + row:GetHeight()
		end
		frame:SetSize(widest + inset.left + inset.right, total + inset.top + inset.bottom)
	end

	local function initializeRows(menu)
		for _, element in ipairs(menu.description.elements) do
			local frame = (element.frameType == "Button" and buttons or plainFrames).Acquire()
			rawset(frame, "GetRegions", function(self)
				local out = {}
				for _, region in ipairs(menu.compositors[self].attachments) do
					if region._parent == self then
						out[#out + 1] = region
					end
				end
				return unpack(out)
			end)
			frame:SetID(1001)
			frame:SetParent(menu.frame)
			frame.includeInLayout = true
			frame:SetFrameLevel(menu.frame:GetFrameLevel() + 20)
			frame:Show()
			menu.rows[#menu.rows + 1] = frame
			menu.elements[frame] = element
			menu.compositors[frame] = newCompositor(frame)
			frame:SetScript("OnEnter", function(self)
				local hover = self.OnEnter
				if hover then
					hover(self, menu.elements[self])
				end
				if menu.elements[self].onEnter then
					menu.elements[self].onEnter(self)
				end
			end)
			frame:SetScript("OnLeave", function(self)
				local leave = self.OnLeave
				if leave then
					leave(self, menu.elements[self])
				end
				if menu.elements[self].onLeave then
					menu.elements[self].onLeave(self)
				end
			end)
		end
		for _, frame in ipairs(menu.rows) do
			callInitializers(menu, frame, menu.elements[frame])
		end
	end

	local function discardRows(menu)
		for _, frame in ipairs(menu.rows) do
			menu.compositors[frame]:Detach()
			frame:SetScript("OnEnter", nil)
			frame:SetScript("OnLeave", nil)
			;(menu.elements[frame].frameType == "Button" and buttons or plainFrames).Release(frame)
		end
		menu.rows, menu.elements, menu.compositors = {}, {}, {}
	end

	function nm.Reinitialize(menu)
		for _, frame in ipairs(menu.rows) do
			menu.compositors[frame]:Clear()
			callInitializers(menu, frame, menu.elements[frame])
		end
		performLayout(menu)
	end

	function nm.Close(menu, reason)
		if type(menu) == "table" and menu.frame == nil then
			menu = nm.menus[menu]
		end
		if not menu or not menu.open then
			return
		end
		if menu.child then
			nm.Close(menu.child, reason)
		end
		if menu.parent then
			menu.parent.child = nil
		end
		unguard()
		menu.open = false
		event("released")
		for _, callback in ipairs(menu.shared.released) do
			callback(menu.frame, reason)
		end
		menu.frame:SetScript("OnEnter", nil)
		menu.frame:SetScript("OnLeave", nil)
		menu.frame:Hide()
		discardRows(menu)
		menu.compositor:Detach()
		nm.menus[menu.frame] = nil
		menu.frame:SetParent(dummy)
		menuFrames.Release(menu.frame)
		event("closed")
	end

	function nm.Pick(frame, buttonName)
		local menu
		for _, candidate in pairs(nm.menus) do
			if candidate.elements[frame] then
				menu = candidate
			end
		end
		assert(menu, "nm.Pick: the row is not in an open menu")
		local description = menu.elements[frame]
		if description:CanOpenSubmenu() then
			return nm.OpenSubmenu(frame)
		end
		if description.responder then
			description.responder(description.data, buttonName)
		end
		for _, callback in ipairs(menu.shared.response) do
			callback(menu.frame, description)
		end
		if description.response == "Refresh" then
			nm.Reinitialize(menu)
			return
		end
		while menu.parent do
			menu = menu.parent
		end
		nm.Close(menu)
	end

	function nm.OpenSubmenu(frame)
		local menu
		for _, candidate in pairs(nm.menus) do
			if candidate.elements[frame] then
				menu = candidate
			end
		end
		assert(menu, "nm.OpenSubmenu: the row is not in an open menu")
		if menu.child then
			nm.Close(menu.child)
		end
		local child = nm.Open(frame, menu.elements[frame], menu)
		menu.child = child
		return child
	end

	function nm.Open(owner, description, parent)
		if not description:HasElements() then
			return nil
		end
		local frame = menuFrames.Acquire()
		local menu = {
			frame = frame, description = description, parent = parent, shared = parent and parent.shared or description,
			rows = {}, elements = {}, compositors = {}, open = true,
		}
		menu.compositor = newCompositor(frame)
		nm.menus[frame] = menu
		rawset(frame, "Close", function()
			if not menu.open then
				nm.staleCloses = nm.staleCloses + 1
			end
			nm.Close(menu)
		end)
		rawset(frame, "GetRegions", function(self)
			local out = {}
			for _, region in ipairs(menu.compositor.attachments) do
				if region._parent == self then
					out[#out + 1] = region
				end
			end
			return unpack(out)
		end)
		for _, child in ipairs(nm.children) do
			if child._parent == frame and not rawget(child, "_guarded") then
				trap(child, "a Blizzard child of the menu", true)
				child._guarded = true
			end
		end
		frame:SetID(1000)
		frame:SetParent(env.UIParent)
		frame.minimumElementWidth = 50
		frame.ownerRegion = owner
		frame:SetFrameStrata("FULLSCREEN_DIALOG")
		frame:SetScale(env.UIParent:GetScale())
		event("generate")
		local variant = menu.shared.style
		menu.inset = (type(variant) == "function" and variant or VARIANTS[variant])(frame)
		menu.padding = PADDING[variant] or 0
		if nm.hooks.generated then
			nm.hooks.generated(menu, frame)
		end
		event("acquired")
		for _, callback in ipairs(menu.shared.acquired) do
			callback(frame)
		end
		frame:ClearAllPoints()
		if parent then
			frame:SetPoint("TOPLEFT", owner, "TOPRIGHT", 0, 0)
		elseif nm.at then
			frame:SetPoint("TOPLEFT", env.UIParent, "TOPLEFT", nm.at[1], -nm.at[2])
		else
			frame:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, 0)
		end
		-- the engine's SetFrameLevel carries a frame's children with it; the stub's does not, so the level is set before the rows are made
		frame:SetFrameLevel((owner.GetFrameLevel and owner:GetFrameLevel() or 0) + 500)
		initializeRows(menu)
		performLayout(menu)
		frame:Show()
		event("shown")
		if not parent then
			nm.last = menu
		end
		return menu
	end

	env.MenuUtil = {
		TraverseMenu = function(description, op)
			local function walk(node)
				for _, child in node:EnumerateElementDescriptions() do
					if op(child) or walk(child) then
						return true
					end
				end
				return false
			end
			return walk(description)
		end,
		GetElementText = function(description)
			return description.text
		end,
		SetElementText = function(description, text)
			description.text = text
		end,
		CreateContextMenu = function(owner, generator, ...)
			owner = owner or env.UIParent
			local root = setmetatable({ initializers = {}, elements = {}, acquired = {}, released = {}, response = {}, style = nm.variant }, Root)
			env.Menu.PopulateDescription(generator, owner, root, ...)
			return nm.Open(owner, root)
		end,
	}

	local manager = {}
	function manager.IsMenuOpen(_, menu)
		return type(menu) == "table" and menu.open == true
	end
	function env.Menu.GetManager()
		return manager
	end
	nm.original = {
		CreateContextMenu = env.MenuUtil.CreateContextMenu,
		TraverseMenu = env.MenuUtil.TraverseMenu,
		GetElementText = env.MenuUtil.GetElementText,
		PopulateDescription = env.Menu.PopulateDescription,
		ModifyMenu = env.Menu.ModifyMenu,
		GetManager = env.Menu.GetManager,
		Menu = env.Menu,
		MenuUtil = env.MenuUtil,
	}

	-- Reading ---------------------------------------------------------------------------------------------------------

	local function value(v)
		if type(v) ~= "table" then
			return tostring(v)
		end
		if v._type then
			return "<" .. v._type .. " " .. tostring(v._name) .. ">"
		end
		local keys = {}
		for k in pairs(v) do
			keys[#keys + 1] = k
		end
		table.sort(keys, function(a, b)
			return tostring(a) < tostring(b)
		end)
		local out = {}
		for _, k in ipairs(keys) do
			out[#out + 1] = tostring(k) .. "=" .. value(v[k])
		end
		return "{" .. table.concat(out, ",") .. "}"
	end

	function nm.Snapshot(menu)
		local lines = {}
		local function describe(label, o)
			local fields = {}
			for key, stored in pairs(o._state) do
				fields[#fields + 1] = key .. "=" .. value(stored)
			end
			table.sort(fields)
			local points = {}
			for _, p in ipairs(o._points) do
				points[#points + 1] = value(p)
			end
			lines[#lines + 1] = label .. " " .. o._type .. " shown=" .. tostring(o._shown) .. " size=" .. tostring(o._width) .. "x"
				.. tostring(o._height) .. " " .. table.concat(fields, ";") .. " points=" .. table.concat(points, "|")
		end
		describe("menu", menu.frame)
		for i, region in ipairs({ menu.frame:GetRegions() }) do
			describe("menu.region" .. i, region)
		end
		for r, row in ipairs(menu.rows) do
			describe("row" .. r, row)
			for i, region in ipairs({ row:GetRegions() }) do
				describe("row" .. r .. ".region" .. i, region)
			end
		end
		return table.concat(lines, "\n")
	end

	return nm
end

return Fixture
