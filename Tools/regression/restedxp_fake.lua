-- restedxp_fake.lua: a stand-in RestedXP Guides for the skin tests, written from RestedXP's public shape (frame
-- names, theme fields and hook points), not from its code.
--
--   local Fake = dofile("Tools/regression/restedxp_fake.lua")
--   local rxp = Fake.Install(env, { v2 = true, activeTheme = "DarkMode" })
--
-- Install(env, opts) puts LibStub with AceAddon-3.0 into env, and registers the addon "RXPGuides" in it, as
-- RestedXP's Locale.lua does. opts:
--   v2            the v2 guide window is on (addon.v2:IsGuideWindowEnabled())
--   activeTheme   the player's theme in the RestedXP profile (default "RXP Blue")
--   liveReload    RestedXP's enableThemeLiveReload setting (default true)
--   profileName   the RestedXP profile's name (default "Tester - Realm")
--   windows       false to build no windows; otherwise Fake.Windows builds them (opts.skip as there)
-- The addon table counts each ReloadTheme that redrew the windows in rxp.reloads, each RenderFrame in rxp.renders
-- and each LoadActiveTheme in rxp.loads. Install runs LoadActiveTheme once, as RestedXP's OnInitialize does before
-- any other addon can register a theme.
local Fake = {}

local WHITE = "Interface/BUTTONS/WHITE8X8"
local FOLDER = "Interface/AddOns/RXPGuides/Textures/"

local function Copy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in pairs(value) do
		out[k] = Copy(v)
	end
	return out
end
Fake.Copy = Copy

-- The built-in v1 themes the skin may borrow textures from. Their colours are arbitrary test values.
local function V1Themes()
	local base = {
		name = "RXP Blue", displayName = "RXP Blue", author = "RestedXP", applicable = true,
		background = { 0.05, 0.05, 0.1, 1 }, bottomFrameBG = { 0.07, 0.07, 0.15, 1 }, bottomFrameHighlight = { 0.2, 0.25, 0.4, 1 },
		mapPins = { 0.8, 0.5, 1, 1 }, tooltip = "", texturePath = FOLDER, headerTexture = "rxp-banner",
		font = "Fonts\\FRIZQT__.TTF", textColor = { 1, 1, 1 },
		bgTextures = { edge = WHITE, bottom = WHITE },
		edges = { edge = FOLDER .. "rxp-borders", guideName = FOLDER .. "rxp-borders" },
	}
	local dark = Copy(base)
	dark.name, dark.displayName, dark.author = "DarkMode", "DarkMode", "Someone"
	dark.texturePath = FOLDER .. "DarkMode/"
	dark.bgTextures, dark.edges = nil, nil
	local green = Copy(base)
	green.name, green.displayName = "RXP Green", "RXP Green"
	green.texturePath = FOLDER .. "Green/"
	return { ["RXP Blue"] = base, DarkMode = dark, ["RXP Green"] = green }
end

local function V2Base()
	return {
		name = "RXP Blue", displayName = "RXP Blue V2", author = "RestedXP", version = 2, applicable = true,
		font = "Fonts\\FRIZQT__.TTF", mapPins = { 0.1, 0.1, 0.2, 0.95 },
		headerTexture = { path = FOLDER .. "v2/header", texCoords = { 0, 1, 0, 0.98 } },
		guideWindow = { logo = FOLDER .. "v2/logo", settingsIcon = FOLDER .. "v2/cog", guideSelectIcon = FOLDER .. "v2/scroll" },
		auctionHouse = { upgradeRatioColor = "", upgradeEPColor = "", upgradeIcon = FOLDER .. "v2/up", valueIcon = FOLDER .. "v2/gold" },
		navigationArrow = FOLDER .. "v2/arrow",
		backgroundColors = {
			common = { 0.1, 0.1, 0.2, 0.95 }, guideName = { 0.1, 0.1, 0.2, 1 }, guideWindow = { 0.03, 0.03, 0.07, 0.95 },
			scrollbar = { 0, 0, 0.04, 1 }, guideSelector = { 0.2, 0.2, 0.37, 1 }, inactivePartyTab = { 0.12, 0.13, 0.19, 1 },
			activeStepCheckbox = { 0.02, 0.03, 0.07, 1 }, activeStepCheckboxChecked = { 0.07, 0.5, 1, 1 },
		},
		borderColors = {
			common = { 0.2, 0.24, 0.43, 1 }, commonEdge = { 0.72, 0.75, 0.84, 1 },
			inactivePartyTab = { 0.24, 0.26, 0.4, 1 }, activeStepCheckboxChecked = { 0.07, 0.5, 1, 1 },
		},
		edge = { edgeFile = FOLDER .. "v2/borders", edgeSize = 1, texCoords = { top = { 0, 0.25, 0, 1 }, bottom = { 0.25, 0.5, 0, 1 } } },
		textColor = { common = { 0.8, 0.8, 0.86, 1 }, title = { 0.1, 0.8, 1, 1 }, inactivePartyTab = { 0.6, 0.6, 0.7, 1 } },
	}
end

local function NewAddon(opts)
	local rxp = { reloads = 0, loads = 0, printed = {} }
	rxp.themes = V1Themes()
	rxp.settings = {
		profile = {
			activeTheme = opts.activeTheme or "RXP Blue",
			enableThemeLiveReload = opts.liveReload ~= false,
		},
		profileName = opts.profileName or "Tester - Realm",
	}
	function rxp.settings.GetSettingsDB()
		return rxp.settings.profileName
	end
	function rxp.settings.RefreshProfile(self)
		assert(self == rxp.settings, "RefreshProfile is a method")
	end
	-- SwitchProfile(name, profile) changes RestedXP's profile as AceDB's OnProfileChanged callback does.
	function rxp.SwitchProfile(name, profile)
		rxp.settings.profileName = name
		rxp.settings.profile = profile
		rxp.settings:RefreshProfile()
	end
	rxp.comms = {
		PrettyPrint = function(...)
			rxp.printed[#rxp.printed + 1] = table.concat({ ... }, " ")
		end,
	}

	local v2 = { themes = { ["RXP Blue V2"] = V2Base() }, enabled = opts.v2 == true }
	rxp.v2 = v2
	function v2.IsGuideWindowEnabled(self)
		assert(self == v2, "IsGuideWindowEnabled is a method")
		return v2.enabled
	end
	-- ConvertThemes makes a v2 theme from each v1 theme, unless a v2 theme of that name has a higher version.
	function v2.ConvertThemes(self)
		assert(self == v2, "ConvertThemes is a method")
		for name, source in pairs(rxp.themes) do
			local existing = v2.themes[name]
			local version = source.version or 1
			if name ~= "RXP Blue" and not (existing and existing.version and version < existing.version) then
				local converted = Copy(v2.themes["RXP Blue V2"])
				converted.name, converted.version, converted.converted = name, version, true
				converted.backgroundColors.common = Copy(source.background)
				converted.textColor.common = Copy(source.textColor)
				v2.themes[name] = converted
			end
		end
	end
	function v2.GetTheme(self)
		local name = rxp.settings.profile.activeTheme
		self.activeTheme = v2.themes[name] or v2.themes["RXP Blue V2"]
		return self.activeTheme
	end

	function rxp.RegisterTheme(self, theme)
		assert(self == rxp, "RegisterTheme is a method")
		if not theme or not theme.name or not theme.author then
			return
		end
		for key, value in pairs(rxp.themes["RXP Blue"]) do
			if theme[key] == nil then
				theme[key] = value
			end
		end
		rxp.themes[theme.name] = theme
		if v2:IsGuideWindowEnabled() then
			v2:ConvertThemes()
		end
	end
	function rxp.LoadActiveTheme(self)
		assert(self == rxp, "LoadActiveTheme is a method")
		rxp.loads = rxp.loads + 1
		local name = rxp.settings.profile.activeTheme
		local chosen = v2:IsGuideWindowEnabled() and v2.themes[name]
		rxp.activeTheme = rxp.themes[chosen and chosen.name or name] or rxp.themes["RXP Blue"]
		rxp.colors = rxp.activeTheme
		rxp.font = rxp.activeTheme.font
		return rxp.activeTheme
	end
	-- RenderFrame and SetupArrow redraw the windows from the active theme, as RestedXP's own start-up does.
	rxp.renders = 0
	function rxp.RenderFrame(themeUpdate)
		rxp.renders = rxp.renders + 1
		rxp.lastRender = themeUpdate
		rxp:LoadActiveTheme()
	end
	rxp.arrows = 0
	function rxp.SetupArrow()
		rxp.arrows = rxp.arrows + 1
	end
	function rxp.ReloadTheme(self)
		assert(self == rxp, "ReloadTheme is a method")
		if not rxp.settings.profile.enableThemeLiveReload then
			return
		end
		rxp.reloads = rxp.reloads + 1
		rxp.RenderFrame("themeReload")
		v2:ConvertThemes()
		rxp.SetupArrow()
		if v2:IsGuideWindowEnabled() then
			v2:GetTheme()
		end
	end
	return rxp
end

-- Windows ----------------------------------------------------------------------------------------------------
-- The fake builds each RestedXP window with the frame names, parent keys and templates RestedXP uses, and the
-- functions that make the lazy ones. Every object it makes is sealed when RestedXP's code that made it returns:
-- rxp.fake.check(hooked) fails on a field written onto one later (other than a method a hook replaced), and on
-- SetScript, Hide or SetParent called on one from outside RestedXP's own code.

local GUARDED = { "SetScript", "Hide", "SetParent" }

local function Maker(env)
	local made, sealed = {}, {}
	local m = { env = env, made = made, depth = 1, violations = {} }
	-- trust(fn) runs fn as RestedXP's own code, which may call SetScript, Hide and SetParent on its objects.
	function m.trust(fn)
		return function(...)
			m.depth = m.depth + 1
			local results = { pcall(fn, ...) }
			m.depth = m.depth - 1
			if m.depth == 0 then
				m.seal()
			end
			if not results[1] then
				error(results[2], 0)
			end
			return unpack(results, 2, table.maxn(results))
		end
	end
	local function Guard(object)
		for _, method in ipairs(GUARDED) do
			local original = object[method]
			if type(original) == "function" then
				object[method] = function(self, ...)
					if m.depth == 0 then
						m.violations[#m.violations + 1] = method .. " on a RestedXP object"
					end
					return original(self, ...)
				end
			end
		end
	end
	function m.add(object)
		Guard(object)
		made[#made + 1] = object
		return object
	end
	function m.frame(kind, parent, name, template)
		local f = env.CreateFrame(kind or "Frame", name, parent or env.UIParent, template)
		return m.add(f)
	end
	function m.texture(frame, layer, key)
		local t = frame:CreateTexture(nil, layer or "ARTWORK")
		t:SetTexture("Interface/AddOns/RXPGuides/Textures/art")
		if key then
			frame[key] = t
		end
		return m.add(t)
	end
	function m.text(frame, key)
		local t = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		if key then
			frame[key] = t
		end
		return m.add(t)
	end
	-- seal() records the fields of each object made since the last seal: RestedXP sets them as it makes them.
	function m.seal()
		for _, object in ipairs(made) do
			if not sealed[object] then
				local fields = {}
				for k in pairs(object) do
					fields[k] = true
				end
				sealed[object] = fields
			end
		end
	end
	function m.check(hooked)
		m.seal()
		assert(#m.violations == 0, m.violations[1])
		for _, object in ipairs(made) do
			for k in pairs(object) do
				if type(k) ~= "string" or k:sub(1, 1) ~= "_" then
					assert(sealed[object][k] or hooked[k], "a field was written onto a RestedXP object: " .. tostring(k))
				end
			end
		end
	end
	-- open(frame) and close(frame) show or hide a frame as RestedXP or a library does, then run its scripts.
	function m.open(frame)
		m.trust(frame.Show)(frame)
		local fn = frame:GetScript("OnShow")
		if fn then
			fn(frame)
		end
	end
	function m.close(frame)
		m.trust(frame.Hide)(frame)
		local fn = frame:GetScript("OnHide")
		if fn then
			fn(frame)
		end
	end
	return m
end

-- Backdrop(m, frame) gives a frame BackdropTemplate's methods: the first SetBackdrop makes its pieces, later ones
-- reuse them.
local function Backdrop(m, frame)
	frame.SetBackdrop = m.trust(function(self)
		if not self._pieces then
			self._pieces = { m.texture(self, "BACKGROUND"), m.texture(self, "BORDER"), m.texture(self, "BORDER") }
		end
		for _, piece in ipairs(self._pieces) do
			piece:Show()
		end
	end)
	frame.ClearBackdrop = m.trust(function(self)
		for _, piece in ipairs(self._pieces or {}) do
			piece:Hide()
		end
	end)
	function frame.SetBackdropColor(self, r, g, b, a)
		if self._pieces then
			self._pieces[1]:SetVertexColor(r, g, b, a)
		end
	end
	return frame
end

-- RxpBackdrop(m, frame) adds the child frames RestedXP's v2 ApplyFrameBackdrop and AddFrameShadow make.
local function RxpBackdrop(m, frame)
	local back = m.frame("Frame", frame)
	back.textures = { m.texture(back, "BACKGROUND") }
	frame.rxpBackground = back
	local border = m.frame("Frame", frame)
	border.textures = { m.texture(border, "BORDER"), m.texture(border, "BORDER"), m.texture(border, "BORDER"), m.texture(border, "BORDER") }
	frame.rxpBorder = border
	local shadow = m.frame("Frame", frame)
	shadow.top = m.texture(shadow, "BACKGROUND")
	frame.rxpShadow = shadow
	return frame
end

-- ScrollBar(m, parent, name) is a UIPanelScrollBarTemplate or RXPV2ScrollBarTemplate slider.
local function ScrollBar(m, parent, name)
	local bar = m.frame("Slider", parent, name)
	for _, key in ipairs({ "ScrollUpButton", "ScrollDownButton" }) do
		local button = m.frame("Button", bar)
		m.texture(button, "ARTWORK", "Normal")
		bar[key] = button
	end
	m.texture(bar, "OVERLAY", "ThumbTexture")
	bar:SetThumbTexture(bar.ThumbTexture)
	return bar
end

local function PanelButton(m, parent, name, label)
	local button = m.frame("Button", parent, name, "UIPanelButtonTemplate")
	for _, key in ipairs({ "Left", "Middle", "Right" }) do
		m.texture(button, "BACKGROUND", key)
	end
	local text = m.text(button)
	button:SetFontString(text)
	button:SetText(label or "Button")
	return button
end

local function V1Window(m, rxp)
	local f = Backdrop(m, m.frame("Frame", nil, "RXPFrame"))
	f.backdrop = { edge = {}, guideName = {}, bottom = {} }
	f.BottomFrame = Backdrop(m, m.frame("Frame", f, "RXPFrame_bottomFrame"))
	local name = Backdrop(m, m.frame("Frame", f, "RXPFrameGuideName"))
	f.GuideName = name
	m.text(name, "text")
	m.texture(name, "BACKGROUND", "bg")
	m.texture(name, "ARTWORK", "icon")
	m.texture(name, "ARTWORK", "classIcon")
	local footer = Backdrop(m, m.frame("Frame", f, "RXPFrameGuideName"))
	f.Footer = footer
	m.texture(footer, "BACKGROUND", "bg")
	footer.icon = m.frame("Button", footer, "RXPFrameGuideNameResize")
	m.texture(footer.icon, "ARTWORK", "Normal")
	footer.cog = m.frame("Button", f, "RXPFrameGuideNameCogwheel")
	m.texture(footer.cog, "ARTWORK", "Normal")
	footer.text = m.text(name)
	local scroll = m.frame("ScrollFrame", f.BottomFrame, "RXPFrame_bottomFrameScrollFrame", "UIPanelScrollFrameTemplate")
	scroll.ScrollBar = ScrollBar(m, scroll, "RXPFrame_bottomFrameScrollFrameScrollBar")
	f.ScrollFrame = scroll
	f.ScrollChild = m.frame("Frame", scroll, "RXPFrame_bottomFrame_steps")
	f.ScrollChild.framePool = {}
	f.CurrentStepFrame = m.frame("Frame", f)
	f.CurrentStepFrame.framePool = {}
	f.CurrentStepFrame.anchor = "TOP"
	f.MenuFrame = m.frame("Frame", nil, "RXPG_MenuFrame", "UIDropDownMenuTemplate")
	m.frame("Button", f, "RXPFrameCogwheel")
	-- RestedXP's own anchors (GuideWindow.lua 466-476, 1405-1428, 1508): a 235 by 125 window left of centre, the
	-- list inset 3 at the top and sides and 14 at the bottom, the 35-unit header hanging 9 into the list's top, the
	-- active steps stacked 2 above the header, and the 20-unit footer on the window's foot.
	f:SetSize(235, 125)
	f:SetPoint("LEFT", m.env.UIParent, "LEFT", 0, 35)
	f.BottomFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 3, -3)
	f.BottomFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -3, 14)
	name:SetPoint("BOTTOMLEFT", f.BottomFrame, "TOPLEFT", 0, -9)
	name:SetPoint("BOTTOMRIGHT", f.BottomFrame, "TOPRIGHT", 0, -9)
	name:SetHeight(35)
	f.CurrentStepFrame:SetPoint("BOTTOMLEFT", name, "TOPLEFT", 0, 2)
	f.CurrentStepFrame:SetPoint("BOTTOMRIGHT", name, "TOPRIGHT", 0, 2)
	f.CurrentStepFrame:SetHeight(25)
	footer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 3, 0)
	footer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -3, 0)
	footer:SetHeight(20)
	scroll:SetPoint("TOPLEFT", f.BottomFrame, "TOPLEFT", 5, -5)
	scroll:SetPoint("BOTTOMRIGHT", f.BottomFrame, "BOTTOMRIGHT", -20, 7)
	function f.UpdateVisuals(self)
		for _, part in ipairs({ self.BottomFrame, self.GuideName, self.Footer }) do
			part:ClearBackdrop()
			part:SetBackdrop(self.backdrop.edge)
		end
	end
	f:UpdateVisuals()
	rxp.RXPFrame = f
	-- SetStep makes an active step frame per step on first use, each with a number badge and its check buttons:
	-- elements is how many a step holds (a number for every step, or one per step), default one.
	-- RestedXP sets each new element's font as it makes it (GuideWindow.lua:1117) and measures every element's
	-- height from its text in CurrentStepFrame.UpdateText before SetStep returns (1222, 1312): so a font changed
	-- after SetStep needs UpdateText again, or the text overflows its frame. The fake measures one line.
	local function GuideFont()
		local profile = rxp.settings and rxp.settings.profile
		return rxp.font or "Fonts\\FRIZQT__.TTF", (profile and profile.guideFontSize) or 9
	end
	local function LineHeight(text)
		local _, size = text:GetFont()
		return math.ceil((type(size) == "number" and size or 0) * 1.1) + 1
	end
	rxp.measured = { steps = 0, rows = 0 }
	function f.CurrentStepFrame.UpdateText()
		rxp.measured.steps = rxp.measured.steps + 1
		for _, step in ipairs(f.CurrentStepFrame.framePool) do
			for _, element in ipairs(step.elements) do
				element:SetHeight(LineHeight(element.text))
			end
		end
	end
	-- UpdateFrame also hides the list when the window leaves it under 30 units, as RestedXP does (GuideWindow.lua 2363).
	f.BottomFrame.UpdateFrame = m.trust(function()
		rxp.measured.rows = rxp.measured.rows + 1
		for _, row in ipairs(f.ScrollChild.framePool) do
			row:SetHeight(LineHeight(row.text) + 8)
		end
		local height = f:GetHeight() - 3 - 14
		f.BottomFrame:SetShown(height >= 30)
	end)
	-- RestedXP caps its list's scroll at the child's height plus 10, less the list's, after every SetValue
	-- (GuideWindow.lua:1528): a range that assumes its own 5-unit top and 7-unit bottom inset.
	m.env.hooksecurefunc(scroll.ScrollBar, "SetValue", function(self)
		local range = math.floor(f.ScrollChild:GetHeight() + 10) - f.BottomFrame:GetHeight()
		self:SetMinMaxValues(0, math.max(0, range))
	end)
	rxp.SetStep = m.trust(function(count, elements)
		local pool = f.CurrentStepFrame.framePool
		for i = 1, count or 1 do
			local step = pool[i]
			if not step then
				step = Backdrop(m, m.frame("Frame", f.CurrentStepFrame))
				step.number = Backdrop(m, m.frame("Frame", step))
				m.text(step.number, "text")
				local plateFont, plateSize = GuideFont()
				step.number.text:SetFont(plateFont, plateSize, "")
				step.elements = {}
				local wanted = type(elements) == "table" and elements[i] or elements or 1
				for e = 1, wanted do
					local element = m.frame("Frame", step)
					element.button = m.frame("CheckButton", element, nil, "ChatConfigCheckButtonTemplate")
					m.texture(element.button, "ARTWORK", "NormalArt")
					element.text = m.text(element)
					local path, size = GuideFont()
					element.text:SetFont(path, size + 2, "")
					step.elements[e] = element
				end
				pool[i] = step
				m.seal()
				step:SetBackdrop(f.backdrop.edge)
				step.number:SetBackdrop(f.backdrop.edge)
			end
		end
		f.CurrentStepFrame.UpdateText()
		-- Each step is its elements plus 18 tall, stacked 5 apart from the top of CurrentStepFrame (1262-1395); its
		-- plate reads "Step N" (1275), as RestedXP writes it.
		local total = 0
		for i, step in ipairs(pool) do
			local height = 18
			step.number.text:SetText(string.format("Step %d", i))
			step.number:SetAlpha(1)
			for _, element in ipairs(step.elements) do
				height = height + element:GetHeight()
			end
			step:ClearAllPoints()
			if i == 1 then
				step:SetPoint("TOPLEFT", f.CurrentStepFrame, "TOPLEFT", 0, 0)
				step:SetPoint("TOPRIGHT", f.CurrentStepFrame, "TOPRIGHT", 0, 0)
			else
				step:SetPoint("TOPLEFT", pool[i - 1], "BOTTOMLEFT", 0, -5)
				step:SetPoint("TOPRIGHT", pool[i - 1], "BOTTOMRIGHT", 0, -5)
			end
			step:SetHeight(height)
			step:SetShown(i <= (count or 1))
			if i <= (count or 1) then
				total = total + height + 5
			end
		end
		f.CurrentStepFrame:SetHeight(math.max(0, total - 5))
	end)
	-- Step list rows: RestedXP draws them flat in the theme's bottomFrameBG colour, each with its text and a
	-- number at its bottom right. m.rows(count) makes more as the guide list grows.
	function m.rows(count)
		local pool = f.ScrollChild.framePool
		for n = #pool + 1, count do
			local row = Backdrop(m, m.frame("Frame", f.ScrollChild, "RXPFrame_bottomFrame_steps_frame_" .. n))
			row.text = m.text(row)
			local path, size = GuideFont()
			row.text:SetFont(path, size, "")
			row.number = m.frame("Frame", row)
			m.text(row.number, "text")
			pool[n] = row
			m.seal()
			row:SetBackdrop(f.backdrop.bottom)
		end
	end
	m.rows(1)
	return f
end

-- LibUIDropDownMenu's lists: RestedXP shows its menus in them, and so may other addons.
local function MenuLists(m, env)
	local lists = {}
	for level = 1, 3 do
		local name = "L_DropDownList" .. level
		local list = m.frame("Button", nil, name)
		list:Hide()
		m.frame("Frame", list, name .. "Backdrop")
		m.frame("Frame", list, name .. "MenuBackdrop")
		m.texture(env[name .. "MenuBackdrop"], "BACKGROUND", "Art")
		local button = m.frame("Button", list, name .. "Button1")
		local text = m.text(button)
		env[name .. "Button1NormalText"] = text
		lists[level] = list
	end
	return lists
end

local function Arrow(m, rxp)
	local arrow = m.frame("Frame", nil, "RXPG_ARROW")
	m.texture(arrow, "ARTWORK", "texture")
	m.text(arrow, "text")
	function arrow.UpdateVisuals(self)
		self.texture:SetTexture("Interface/AddOns/RXPGuides/Textures/arrow")
	end
	rxp.arrowFrame = arrow
end

local function IconFrame(m, name)
	local f = Backdrop(m, m.frame("Frame", nil, name))
	f.title = Backdrop(m, m.frame("Frame", f, name .. "_title"))
	m.text(f.title, "text")
	f:SetBackdrop()
	f.title:SetBackdrop()
	return f
end

local function IconButton(m, parent, name)
	local button = m.frame("Button", parent, name, "SecureActionButtonTemplate")
	m.texture(button, "BACKGROUND", "icon")
	button.cooldown = m.frame("Cooldown", button, name .. "Cooldown", "CooldownFrameTemplate")
	m.texture(button, "HIGHLIGHT", "_highlight")
	return button
end

local function ItemsAndTargets(m, rxp)
	local items = IconFrame(m, "RXPItemFrame")
	items.buttonList = {}
	function items.UpdateVisuals() end
	rxp.activeItemFrame = items
	rxp.UpdateItemFrame = m.trust(function(frame, count)
		frame = frame or items
		for i = #frame.buttonList + 1, count or 1 do
			frame.buttonList[i] = IconButton(m, frame, "RXPItemFrameButton" .. i)
		end
		m.seal()
	end)
	local targets = IconFrame(m, "RXPTargetFrame")
	targets.enemyTargetButtons, targets.friendlyTargetButtons = {}, {}
	rxp.targeting = { activeTargetFrame = targets }
	rxp.targeting.UpdateTargetFrame = m.trust(function(self, count)
		assert(self == rxp.targeting)
		for i = #targets.enemyTargetButtons + 1, count or 1 do
			targets.enemyTargetButtons[i] = IconButton(m, targets, "RXPTargetFrame_EnemyButton" .. i)
		end
		m.seal()
	end)
	rxp.targeting.RenderTargetFrameBackground = m.trust(function(self)
		assert(self == rxp.targeting)
		targets:ClearBackdrop()
		if not rxp.settings.profile.hideActiveTargetsBackground then
			targets:SetBackdrop()
		end
	end)
end

-- AceFrame(m) is the shape of an AceGUI "Frame" container: the widget table and its frame.
local function AceFrame(m)
	local frame = Backdrop(m, m.frame("Frame"))
	frame:SetBackdrop()
	local widget = { frame = frame }
	frame.obj = widget
	local close = PanelButton(m, frame, nil, "Close")
	close.obj = widget
	local status = m.frame("Button", frame)
	status.obj = widget
	widget.statustext = m.text(status)
	widget.titlebg = m.texture(frame, "OVERLAY")
	m.texture(frame, "OVERLAY")
	m.texture(frame, "OVERLAY")
	local title = m.frame("Frame", frame)
	widget.titletext = m.text(title)
	widget.content = m.frame("Frame", frame)
	return widget
end

local function Tracker(m, rxp, env)
	local report = AceFrame(m)
	env.RESTEDXP_TRACKER_SUMMARY_WINDOW = report.frame
	local scroll = { frame = m.frame("Frame", report.content) }
	scroll.scrollbar = ScrollBar(m, scroll.frame, "AceConfigDialogScrollFrame1ScrollBar")
	report.scrollContainer = scroll
	report.levelButton = { frame = PanelButton(m, report.content, "AceGUI30Button1", "1 to 2") }
	report.levelMenuFrame = m.frame("Frame", report.levelButton.frame, "RXPG_LevelMenuFrame", "UIDropDownMenuTemplate")
	rxp.tracker = { ui = { CharacterFrame = report } }
	rxp.tracker.CreateLevelSplits = m.trust(function(self)
		assert(self == rxp.tracker)
		local splits = Backdrop(m, m.frame("Frame", nil, "RXPLevelSplits"))
		splits.title = Backdrop(m, m.frame("Frame", splits, "RXPLevelSplits_title"))
		m.text(splits.title, "text")
		splits.title.cog = m.frame("Button", splits.title, "RXPLevelSplits_titleCogwheel")
		self.levelSplits = splits
		m.seal()
		self:RenderSplitsBackground()
	end)
	rxp.tracker.RenderSplitsBackground = m.trust(function(self)
		local splits = self.levelSplits
		splits:ClearBackdrop()
		if not rxp.settings.profile.hideSplitsBackground then
			splits:SetBackdrop()
		end
		splits.title:SetBackdrop()
	end)
end

local function RxpButton(m, parent)
	local button = RxpBackdrop(m, m.frame("Button", parent))
	m.texture(button, "BACKGROUND", "configuratorBackground")
	button.text = m.text(button)
	button:SetFontString(button.text)
	return button
end

local function V2Windows(m, rxp)
	local ui = rxp.ui
	local configurator = {}
	ui.v2.configurator = configurator
	configurator.CreateGuideConfigurator = m.trust(function(self)
		assert(self == configurator)
		local frame = RxpBackdrop(m, m.frame("Frame"))
		m.texture(frame.rxpBackground, "ARTWORK", "configuratorHeader")
		local widget = { frame = frame }
		widget.titletext = m.text(frame)
		widget.backbutton = RxpButton(m, frame)
		widget.resetbutton = RxpButton(m, frame)
		widget.submitbutton = RxpButton(m, frame)
		widget.scrollContainer = { scrollbar = ScrollBar(m, frame, "RXPV2ScrollFrame1ScrollBar") }
		self.ui = widget
		m.seal()
	end)
	-- UpdateTheme redraws the configurator from the theme, as RestedXP's GuideConfigurator.lua does: the title in
	-- the theme font at the guide size plus 2 in a fixed gold, each button's label in the theme font and text
	-- colour, and its own flat background texture coloured from the theme.
	configurator.UpdateTheme = m.trust(function(self)
		local widget = self.ui
		if not widget then
			return
		end
		widget.titletext:SetFont(rxp.font or "Fonts\\FRIZQT__.TTF", 11, "")
		widget.titletext:SetTextColor(1, 0.82, 0)
		for _, key in ipairs({ "backbutton", "resetbutton", "submitbutton" }) do
			local button = widget[key]
			button.text:SetFont(rxp.font or "Fonts\\FRIZQT__.TTF", 9, "")
			button.text:SetTextColor(1, 1, 1)
			button.configuratorBackground:SetColorTexture(0.1, 0.1, 0.2, 1)
			button.configuratorBackground:SetAlpha(1)
		end
	end)
	function configurator.Open(self)
		if not self.ui then
			self:CreateGuideConfigurator()
		end
		m.open(self.ui.frame)
	end

	local importer = { widgets = {} }
	rxp.guideImporter = importer
	ui.v2.CreateGuideImporter = m.trust(function(self)
		assert(self == ui.v2)
		local widgets = importer.widgets
		local frame = RxpBackdrop(m, m.frame("Frame"))
		for _, key in ipairs({ "importerBackground", "importerBody", "importerHeader" }) do
			m.texture(frame, "BACKGROUND", key)
		end
		local window = { frame = frame, title = m.text(frame) }
		window.closebutton = m.frame("Button", frame)
		m.texture(window.closebutton, "ARTWORK", "Art")
		widgets.import = window
		for _, key in ipairs({ "importButton", "importSplicedString", "purgeButton", "reloadButton", "deleteButton" }) do
			local button = RxpButton(m, frame)
			widgets[key] = { frame = button, text = button.text }
		end
		local background = RxpBackdrop(m, m.frame("Frame", frame))
		local box = m.frame("EditBox", background, "RXPV2GuideImporterEditBox1Edit")
		widgets.importBox = { background = background, editBox = box }
		for _, key in ipairs({ "purgeConfirmation", "deleteConfirmation" }) do
			local popup = RxpBackdrop(m, m.frame("Frame"))
			widgets[key] = { frame = popup, title = m.text(popup), message = m.text(popup), buttons = { RxpButton(m, popup), RxpButton(m, popup) } }
		end
		m.seal()
	end)
	function importer.Open(self)
		assert(self == importer)
		if not self.widgets.import then
			ui.v2:CreateGuideImporter()
		end
		m.open(self.widgets.import.frame)
	end

	if rxp.v2.enabled then
		local window = { frame = m.frame("Frame") }
		window.upperFrame = RxpBackdrop(m, m.frame("Frame", window.frame))
		window.guideStepsFrame = RxpBackdrop(m, m.frame("Frame", window.frame))
		window.title = m.text(window.upperFrame)
		window.header = m.frame("Frame", window.upperFrame)
		window.banner = m.texture(window.header, "BACKGROUND")
		window.closebutton = m.frame("Button", window.upperFrame)
		m.texture(window.closebutton, "ARTWORK", "Art")
		window.guideSteps = { scroll = { scrollbar = ScrollBar(m, window.guideStepsFrame, "RXPV2ScrollFrame2ScrollBar") } }
		-- UpdateSubTheme redraws the window from the theme; RestedXP draws the title in a fixed gold.
		window.UpdateSubTheme = m.trust(function(self)
			self.title:SetTextColor(1, 0.82, 0)
		end)
		window:UpdateSubTheme()
		rxp.v2.state = { guideWindow = window }
	end
end

-- Windows(env, rxp, opts) builds every window RestedXP makes at start-up, and the functions that make the rest.
-- opts.skip names parts to leave out, as an older or newer RestedXP might: { targeting = true }.
function Fake.Windows(env, rxp, opts)
	opts = opts or {}
	local skip = opts.skip or {}
	local m = Maker(env, rxp)
	rxp.ui = { v2 = {} }
	V1Window(m, rxp)
	rxp.menuLists = MenuLists(m, env)
	-- ShowMenu opens a RestedXP menu in L_DropDownList1, as LibUIDropDownMenu's EasyMenu does on Forever.
	function rxp.ShowMenu(self)
		assert(self == rxp, "ShowMenu is a method")
		m.open(rxp.menuLists[1])
	end
	Arrow(m, rxp)
	ItemsAndTargets(m, rxp)
	Tracker(m, rxp, env)
	V2Windows(m, rxp)
	if skip.targeting then
		rxp.targeting = nil
	end
	if skip.tracker then
		rxp.tracker = nil
	end
	-- OpenBugReport and OpenBrandedExport show an AceGUI frame from AceGUI's shared pool, as RestedXP's feedback form
	-- and export box do; closing the export box gives its frame back to the pool for any addon to use.
	local pool = AceFrame(m)
	pool.frame:Hide()
	rxp.pooledFrame = pool.frame
	rxp.comms.OpenBugReport = m.trust(function()
		env.RESTEDXP_BUG_REPORT_WINDOW = pool.frame
		pool.titletext:SetText("RestedXP Feedback Form")
		pool.titletext:SetTextColor(1, 0.82, 0)
		pool.frame:SetBackdrop()
		pool.frame:Show()
	end)
	rxp.comms.OpenBrandedExport = m.trust(function()
		env.RESTEDXP_BRANDED_EXPORT = pool.frame
		pool.titletext:SetTextColor(1, 0.82, 0)
		pool.frame:SetBackdrop()
		pool.frame:Show()
	end)
	-- CreateCleanupButton puts RestedXP's button on the quest log, as RestedXP does at PLAYER_ENTERING_WORLD.
	rxp.CreateCleanupButton = m.trust(function()
		local button = PanelButton(m, env.UIParent, "RXPQuestLogCleanupButton", "Clean up")
		rxp.cleanupBtn = button
		m.seal()
		return button
	end)
	m.seal()
	m.depth = 0
	rxp.fake = m
	return m
end

function Fake.Install(env, opts)
	opts = opts or {}
	local rxp = NewAddon(opts)
	local addons = { RXPGuides = rxp }
	local ace = {}
	function ace.GetAddon(self, name, silent)
		assert(self == ace, "GetAddon is a method")
		local found = addons[name]
		if not found and not silent then
			error("Cannot find an AceAddon '" .. tostring(name) .. "'.")
		end
		return found
	end
	local libs = { ["AceAddon-3.0"] = ace }
	env.LibStub = setmetatable({ libs = libs }, {
		__call = function(_, major, silent)
			local lib = libs[major]
			if not lib and not silent then
				error("Cannot find a library instance of " .. tostring(major) .. ".")
			end
			return lib
		end,
	})
	env._loaded = env._loaded or {}
	env._loaded.RXPGuides = true
	if opts.windows ~= false then
		Fake.Windows(env, rxp, opts)
	end
	rxp:LoadActiveTheme()
	return rxp
end

-- Bare(env) installs LibStub and AceAddon without RestedXP, as when another addon ships the libraries.
function Fake.Bare(env)
	local ace = {
		GetAddon = function(_, name, silent)
			if not silent then
				error("Cannot find an AceAddon '" .. tostring(name) .. "'.")
			end
		end,
	}
	env.LibStub = setmetatable({}, {
		__call = function(_, major, silent)
			if major == "AceAddon-3.0" then
				return ace
			end
			if not silent then
				error("Cannot find a library instance of " .. tostring(major) .. ".")
			end
		end,
	})
end

return Fake
