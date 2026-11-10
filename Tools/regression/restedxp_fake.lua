-- restedxp_fake.lua: a stand-in RestedXP Guides for the skin tests. The guide window, its active steps, the timer
-- bars' footer, the waypoint arrow, the Active Items and Active Targets frames and the saving of frame places follow
-- RXPGuides 4.11.35's own code, with that file's line numbers beside each part; the themes and the other windows
-- follow RestedXP's public shape (frame names, theme fields and hook points).
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

local TEXT_COLORS = { RXP_FRIENDLY_ = "FF00FF25", RXP_ENEMY_ = "FFFF5722", RXP_LOOT_ = "FF00BCD4", RXP_WARN_ = "FFFCDC00", RXP_PICK_ = "FFDB2EEF", RXP_BUY_ = "FF0E8312" }

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
	-- addon.enabledFrames holds every frame RestedXP shows, hides and saves (RXPGuides.lua 239). SaveFramePositions
	-- writes each one's size and points into the profile, on every OnMouseUp of a RestedXP window and at
	-- PLAYER_LOGOUT (RXPGuides.lua 1831), unless the frame's savePosition field is false (SettingsPanel.lua 4327-4369).
	rxp.enabledFrames = {}
	function rxp.settings.SaveFramePositions(self)
		assert(self == rxp.settings, "SaveFramePositions is a method")
		local profile = self.profile
		profile.framePositions = profile.framePositions or {}
		profile.frameSizes = profile.frameSizes or {}
		for name, frame in pairs(rxp.enabledFrames) do
			if frame.savePosition ~= false then
				if frame.saveSize == false then
					profile.frameSizes[name] = nil
				else
					profile.frameSizes[name] = { frame:GetWidth(), frame:GetHeight() }
				end
				profile.framePositions[name] = {}
				for i = 1, frame:GetNumPoints() or 0 do
					local point, relative, relativePoint, x, y = frame:GetPoint(i)
					if type(relative) == "table" then
						relative = relative:GetName()
					end
					profile.framePositions[name][i] = { point, relative, relativePoint, x, y }
				end
			end
		end
	end
	-- The step-text colours (Themes.lua 121-131): a guide writes "|cRXP_FRIENDLY_Name|r", and ReplaceColors swaps
	-- each token for the player's colour for it, an eight-digit hex, when the step loads (SettingsPanel.lua 4127).
	rxp.guideTextColors = { default = Copy(TEXT_COLORS) }
	for token, hex in pairs(TEXT_COLORS) do
		rxp.guideTextColors[token] = hex
	end
	function rxp.settings.ReplaceColors(line)
		return (line:gsub("RXP_[A-Z]+_", function(token)
			return rxp.guideTextColors[token]
		end))
	end

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
		for _, frame in pairs(rxp.enabledFrames) do
			if frame.UpdateVisuals then
				frame:UpdateVisuals(true)
			end
		end
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
	-- check(hooked) fails on a field written onto a RestedXP object since it was sealed, other than a method a hook
	-- replaced and savePosition, the switch RestedXP itself reads off a frame to leave it out of its saved places
	-- (SettingsPanel.lua 4343, 4373; RestedXP sets it on its own frames at UI/V2/Core.lua 1911).
	function m.check(hooked)
		m.seal()
		assert(#m.violations == 0, m.violations[1])
		for _, object in ipairs(made) do
			for k in pairs(object) do
				if (type(k) ~= "string" or k:sub(1, 1) ~= "_") and k ~= "savePosition" then
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

-- The guide window, as GuideWindow.lua builds it (RXPGuides 4.11.35; line numbers are that file's). RXPFrame is a
-- BACKGROUND-strata child of UIParent, 235 by 125 (22, 466-469), in addon.enabledFrames so RestedXP saves its place
-- (26). BottomFrame, the step list, is inset 3 at the top and sides and 14 at the foot (1405); GuideName, the
-- 35-unit header, hangs its foot 9 below the list's top (1408-1410) and holds the guide's title from x 29 (1412);
-- Footer is 20 tall on the window's foot (1422-1424) and has the same global name as GuideName (33-36), its text a
-- font string of GuideName's (1425), its resize grip a child button (1441) and its cog a child of RXPFrame one level
-- above the header (1468-1472). CurrentStepFrame stacks the active steps 2 above the header (473), or under the
-- window when profile.anchorOrientation is not "top" (353-396).
local STEP_ICONS = { train = "|TInterface/GossipFrame/TrainerGossipIcon:0|t", accept = "|TInterface/GossipFrame/AvailableQuestIcon:0|t", turnin = "|TInterface/GossipFrame/ActiveQuestIcon:0|t" }
local SIZE_GRABBER = "Interface/CHATFRAME/UI-ChatIM-SizeGrabber-"

-- Art(m, button, slot, path) sets a button's Normal, Highlight, Checked or DisabledChecked texture from a path, as
-- the game's Set<slot>Texture does: the first call makes the texture region, later ones reuse it.
local function Art(m, button, slot, path)
	local texture = button["Get" .. slot .. "Texture"](button)
	if type(texture) ~= "table" then
		texture = m.texture(button, slot == "Highlight" and "HIGHLIGHT" or "ARTWORK")
		texture:SetAllPoints(button)
		button["Set" .. slot .. "Texture"](button, texture)
	end
	texture:SetTexture(path)
	return texture
end

-- StringWidth(text) and StringHeight(text): the text's measures where the environment has them (env._textWidth),
-- else a width of 60 and one line of the font's size.
local function StringWidth(text)
	local width = text:GetStringWidth()
	return type(width) == "number" and width or 60
end

local function StringHeight(text)
	local height = text:GetStringHeight()
	if type(height) == "number" and height > 0 then
		return height
	end
	local _, size = text:GetFont()
	return type(size) == "number" and size or 0
end

local function V1Window(m, rxp)
	local env = m.env
	local f = Backdrop(m, m.frame("Frame", nil, "RXPFrame"))
	rxp.RXPFrame = f
	rxp.enabledFrames.RXPFrame = f
	function f.IsFeatureEnabled()
		return not rxp.settings.profile.hideGuideWindow, false
	end
	local list = Backdrop(m, m.frame("Frame", f, "RXPFrame_bottomFrame"))
	local name = Backdrop(m, m.frame("Frame", f, "RXPFrameGuideName"))
	local footer = Backdrop(m, m.frame("Frame", f, "RXPFrameGuideName"))
	local scroll = m.frame("ScrollFrame", list, "RXPFrame_bottomFrameScrollFrame", "UIPanelScrollFrameTemplate")
	scroll.ScrollBar = ScrollBar(m, scroll, "RXPFrame_bottomFrameScrollFrameScrollBar")
	local current = m.frame("Frame", f)
	local child = Backdrop(m, m.frame("Frame", scroll, "RXPFrame_bottomFrame_steps"))
	f.BottomFrame, f.GuideName, f.Footer, f.CurrentStepFrame, f.ScrollFrame, f.ScrollChild = list, name, footer, current, scroll, child
	f.MenuFrame = m.frame("Frame", nil, "RXPG_MenuFrame", "UIDropDownMenuTemplate")
	f.backdrop = { edge = {}, guideName = {}, bottom = {} }
	child.framePool, current.framePool = {}, {}

	f:SetMovable(true)
	f:SetClampedToScreen(true)
	f:SetResizable(true)
	f:EnableMouse(true)
	f:SetSize(235, 125)
	f:SetPoint("LEFT", env.UIParent, "LEFT", 0, 35)
	f:SetFrameStrata("BACKGROUND")
	list:SetPoint("TOPLEFT", f, "TOPLEFT", 3, -3)
	list:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -3, 14)
	name:SetPoint("BOTTOMLEFT", list, "TOPLEFT", 0, -9)
	name:SetPoint("BOTTOMRIGHT", list, "TOPRIGHT", 0, -9)
	name:SetHeight(35)
	m.text(name, "text")
	name.text:SetPoint("LEFT", name, "LEFT", 29, 0)
	name.text:SetPoint("RIGHT", name, "RIGHT", 0, 0)
	name.text:SetJustifyH("CENTER")
	name.text:SetJustifyV("MIDDLE")
	name:SetFrameLevel(6)
	m.texture(name, "BACKGROUND", "bg")
	name.bg:SetPoint("TOPLEFT", name, "TOPLEFT", 4, -2)
	name.bg:SetPoint("BOTTOMRIGHT", name, "BOTTOMRIGHT", -2, 4)
	footer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 3, 0)
	footer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -3, 0)
	footer:SetHeight(20)
	footer.text = m.text(name)
	footer.text:SetPoint("LEFT", footer, "LEFT", 40, 1)
	footer.text:SetPoint("RIGHT", footer, "RIGHT", -16, 1)
	footer.text:SetJustifyH("LEFT")
	footer.text:SetJustifyV("MIDDLE")
	footer:SetFrameLevel(6)
	m.texture(footer, "BACKGROUND", "bg")
	footer.bg:SetPoint("TOPLEFT", footer, "TOPLEFT", 4, -2)
	footer.bg:SetPoint("BOTTOMRIGHT", footer, "BOTTOMRIGHT", -2, 4)
	footer.icon = m.frame("Button", footer, "RXPFrameGuideNameResize")
	footer.icon:SetFrameLevel(footer:GetFrameLevel() + 1)
	footer.icon:SetSize(16, 16)
	footer.icon:SetPoint("BOTTOMRIGHT", footer, "BOTTOMRIGHT", -1, 3)
	footer.icon.Normal = Art(m, footer.icon, "Normal", SIZE_GRABBER .. "Up")
	Art(m, footer.icon, "Highlight", SIZE_GRABBER .. "Highlight")
	m.texture(name, "ARTWORK", "icon")
	name.icon:SetPoint("CENTER", name, "LEFT", 16, 0)
	name.icon:SetSize(42, 42)
	m.texture(name, "OVERLAY", "classIcon")
	name.classIcon:SetPoint("CENTER", name.icon, "BOTTOMRIGHT", -4, 10)
	name.classIcon:SetSize(24, 24)
	footer.cog = m.frame("Button", f, "RXPFrameCogwheel")
	footer.cog:SetFrameLevel(name:GetFrameLevel() + 1)
	footer.cog:SetSize(18, 18)
	footer.cog:SetPoint("LEFT", footer, "LEFT", 1, 1)
	Art(m, footer.cog, "Highlight", "Interface/MINIMAP/UI-Minimap-ZoomButton-Highlight")
	footer.cog:Show()
	scroll:SetPoint("TOPLEFT", list, "TOPLEFT", 5, -5)
	scroll:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -20, 7)
	current:SetPoint("BOTTOMLEFT", name, "TOPLEFT", 0, 2)
	current:SetPoint("BOTTOMRIGHT", name, "TOPRIGHT", 0, 2)
	current:SetHeight(25)
	current:EnableMouse(true)
	current.anchor = "TOP"

	local function Texture(file)
		local theme = rxp.activeTheme
		return ((theme and theme.texturePath) or FOLDER) .. file
	end
	local function Color(key)
		local theme = rxp.activeTheme
		local color = theme and theme[key]
		return unpack(type(color) == "table" and color or { 1, 1, 1 })
	end
	-- UpdateScrollBar hides the list's scroll bar when the list fits (1512).
	function f.UpdateScrollBar() end
	-- UpdateVisuals redraws the window from the active theme (52-82): each call sets the three backdrops again, the
	-- header's and footer's banners, the logo, the class icon and the cog's art.
	f.UpdateVisuals = m.trust(function(self)
		if rxp.v2:IsGuideWindowEnabled() then
			return
		end
		list:ClearBackdrop()
		list:SetBackdrop(self.backdrop.edge)
		list:SetBackdropColor(Color("background"))
		name:ClearBackdrop()
		name:SetBackdrop(self.backdrop.guideName)
		name:SetBackdropColor(Color("background"))
		footer:ClearBackdrop()
		footer:SetBackdrop(self.backdrop.guideName)
		footer:SetBackdropColor(Color("background"))
		footer.bg:SetTexture(Texture("rxp-banner"))
		name.bg:SetTexture(Texture("rxp-banner"))
		name.icon:SetTexture(Texture("rxp_logo-64"))
		name.classIcon:SetTexture(Texture("SHAMAN"))
		footer.cog.Normal = Art(m, footer.cog, "Normal", Texture("rxp_cog-32"))
		self.UpdateScrollBar()
	end)
	-- SetupGuideWindow writes the header and footer as RestedXP's start-up does (140-181): the header at 11, the
	-- footer at 9 with the addon's title and release.
	rxp.SetupGuideWindow = m.trust(function()
		if rxp.v2:IsGuideWindowEnabled() then
			return
		end
		name.text:SetFont(rxp.font or "Fonts\\FRIZQT__.TTF", 11, "")
		name.text:SetText("Welcome to RestedXP Guides\nRight click to pick a guide")
		name.text:SetTextColor(Color("textColor"))
		footer.text:SetFont(rxp.font or "Fonts\\FRIZQT__.TTF", 9, "")
		footer.text:SetText("RestedXP Guides v4.11.35")
		footer.text:SetTextColor(Color("textColor"))
		f:UpdateVisuals()
	end)

	-- SetStepFrameAnchor puts the active steps above the header, or under the window (353-396).
	local function SetStepFrameAnchor()
		current:ClearAllPoints()
		if rxp.settings.profile.anchorOrientation == "bottom" then
			current:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 3, 0)
			current:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", -3, 0)
			current.anchor = "BOTTOM"
		else
			current:SetPoint("BOTTOMLEFT", name, "TOPLEFT", 0, 2)
			current:SetPoint("BOTTOMRIGHT", name, "TOPRIGHT", 0, 2)
			current.anchor = "TOP"
		end
	end
	f.SetStepFrameAnchor = m.trust(SetStepFrameAnchor)

	-- The mouse: a drag moves the window, the grip or Alt sizes it, and letting go saves every frame's place
	-- (402-426); a right click on the header or the footer, and a click on the cog, open the menu (1477-1501).
	local resizing = false
	function f.DropDownMenu()
		rxp:ShowMenu(f.menuList, f.MenuFrame, "cursor", 0, 0, "MENU")
	end
	f.OnMouseDown = m.trust(function(_, _, resize)
		if rxp.settings.profile.lockFrames then
			return
		end
		if resize or (env.IsAltKeyDown and env.IsAltKeyDown()) then
			f:StartSizing("BOTTOMRIGHT")
			resizing = true
		else
			f:StartMoving()
		end
	end)
	f.OnMouseUp = m.trust(function()
		f:StopMovingOrSizing()
		if resizing then
			rxp.settings.profile.frameHeight = f:GetHeight()
			rxp.SetStep()
		end
		SetStepFrameAnchor()
		if rxp.UpdateItemFrame then
			rxp.UpdateItemFrame()
		end
		resizing = false
		rxp.settings:SaveFramePositions()
	end)
	name.OnMouseDown = m.trust(function(self, button)
		if button == "RightButton" then
			f.DropDownMenu()
		else
			f.OnMouseDown(self, button)
		end
	end)
	name.OnMouseUp = m.trust(function(self, button)
		if button ~= "RightButton" then
			f.OnMouseUp(self, button)
		end
	end)
	for _, part in ipairs({ f, current }) do
		part:SetScript("OnMouseDown", f.OnMouseDown)
		part:SetScript("OnMouseUp", f.OnMouseUp)
	end
	for _, part in ipairs({ name, footer }) do
		part:SetScript("OnMouseDown", name.OnMouseDown)
		part:SetScript("OnMouseUp", name.OnMouseUp)
	end
	footer.icon:SetScript("OnMouseDown", m.trust(function(self, button)
		f.OnMouseDown(self, button, true)
	end))
	footer.icon:SetScript("OnMouseUp", f.OnMouseUp)
	footer.cog:SetScript("OnClick", m.trust(function()
		f.DropDownMenu()
	end))
	-- The game gives a frame the mouse when a mouse script is set on it, and a button has it from the start.
	for _, part in ipairs({ name, footer, footer.icon, footer.cog }) do
		part:EnableMouse(true)
	end

	local function GuideFont()
		local profile = rxp.settings and rxp.settings.profile
		return rxp.font or "Fonts\\FRIZQT__.TTF", (profile and profile.guideFontSize) or 9
	end
	local function LineHeight(text)
		local _, size = text:GetFont()
		return math.ceil((type(size) == "number" and size or 0) * 1.1) + 1
	end
	rxp.measured = { steps = 0, rows = 0 }
	local active = {}

	-- m.guide(steps) sets the steps SetStep activates next: a list of { title, elements = { { text, tag, textOnly,
	-- icon } } }, the step text as the guide file has it, colour tokens and "Name::npcId" included.
	function m.guide(steps)
		m.steps = steps
	end
	local function Specs(count, elements)
		if m.steps then
			return m.steps
		end
		local specs = {}
		for i = 1, count or 1 do
			local wanted = type(elements) == "table" and elements[i] or elements or 1
			local made = {}
			for e = 1, wanted do
				made[e] = { text = "Kill 8 Mottled Boars" }
			end
			specs[i] = { index = i, elements = made }
		end
		return specs
	end
	-- StepText(value) is the text RestedXP draws for an element (884, 1307): settings.ReplaceColors swaps each
	-- colour token for the player's colour, and ReplaceNpcIds drops the npc id after a name.
	local function StepText(value)
		return (rxp.settings.ReplaceColors(value):gsub("::%d+", ""))
	end

	-- UpdateText lays the active steps out (1230-1400): each step frame under the one before, 5 apart; its plate
	-- reads the step's title; each element's 12-unit check sits at (6, -1), its text 11 right of the check and 1
	-- lower, running to 5 before the step frame's right edge, its tag icon on the check's right edge; an element
	-- is its text's height times 1.1 plus 1 tall, a step its elements plus 18. A text-only element hides its check.
	-- A tip step is its own 230-wide window at the screen's bottom left (1001-1012) and adds nothing to the
	-- stack's height (1387-1391).
	current.UpdateText = m.trust(function()
		rxp.measured.steps = rxp.measured.steps + 1
		if rxp.v2:IsGuideWindowEnabled() then
			current:SetHeight(0)
			current:Hide()
			return
		end
		current:Show()
		local total, anchor = 0, nil
		for c, spec in ipairs(active) do
			local step = current.framePool[c]
			step:ClearAllPoints()
			if spec.tip then
				step:SetPoint("BOTTOMLEFT", m.env.UIParent, "BOTTOMLEFT", 0, 0)
				step:SetWidth(230)
			else
				step:SetPoint("TOPLEFT", anchor or current, anchor and "BOTTOMLEFT" or "TOPLEFT", 0, anchor and -5 or 0)
				step:SetPoint("TOPRIGHT", anchor or current, anchor and "BOTTOMRIGHT" or "TOPRIGHT", 0, anchor and -5 or 0)
				anchor = step
			end
			step.number.text:SetText(spec.title or string.format("Step %d", spec.index or c))
			step.number:SetSize(StringWidth(step.number.text) + 10, 17)
			local height = 0
			for e, element in ipairs(spec.elements) do
				local row = step.elements[e]
				local spacing = 0
				row:Show()
				if element.text then
					row:SetAlpha(1)
					row.button:ClearAllPoints()
					row.button:SetPoint("TOPLEFT", row, "TOPLEFT", 6, -1)
					row.text:ClearAllPoints()
					row.text:SetPoint("TOPLEFT", row.button, "TOPRIGHT", 11, -1)
					row.text:SetPoint("RIGHT", step, "RIGHT", -5, 0)
					if element.text ~= " " then
						row.text:SetText(StepText(element.text))
					end
					local h = math.ceil(StringHeight(row.text) * 1.1) + 1
					row:SetHeight(h)
					height = height + h
					row:EnableMouse(true)
					row.button:EnableMouse(true)
					row.icon:ClearAllPoints()
					row.icon:SetPoint("TOPLEFT", row.button, "TOPRIGHT", 0, -1)
					if element.textOnly then
						row.button:SetChecked(true)
						row.button:Hide()
					else
						row.button:Show()
					end
				else
					row:SetAlpha(0)
					row.button:Hide()
					row:SetHeight(1)
					spacing = 1
				end
				row:ClearAllPoints()
				local above = step.elements[e - 1]
				row:SetPoint("TOPLEFT", above or step, above and "BOTTOMLEFT" or "TOPLEFT", 0, (above and 0 or -10) + spacing)
				row:SetPoint("TOPRIGHT", above or step, above and "BOTTOMRIGHT" or "TOPRIGHT", 0, (above and 0 or -10) + spacing)
				if element.tag and element.text then
					row.icon:SetText(element.icon or STEP_ICONS[element.tag] or "")
					row.icon:Show()
				else
					row.icon:Hide()
				end
			end
			step:SetAlpha(1)
			step:EnableMouse(true)
			height = math.ceil(height + 18)
			step:SetHeight(height)
			total = total + (spec.tip and 0 or height + 5)
		end
		current:SetHeight(math.max(0, total - 5))
	end)

	-- UpdateFrame sizes the list's rows and hides the list when the window leaves it under 30 units, holding the
	-- window at 28 or more (2363-2364).
	list.UpdateFrame = m.trust(function()
		rxp.measured.rows = rxp.measured.rows + 1
		for _, row in ipairs(child.framePool) do
			row:SetHeight(LineHeight(row.text) + 8)
		end
		local height = f:GetHeight() - 3 - 14
		if height < 30 then
			list:Hide()
			if f:GetHeight() < 28 then
				f:SetHeight(28)
			end
		elseif not list:IsShown() then
			list:Show()
		end
	end)
	-- RestedXP caps its list's scroll at the child's height plus 10, less the list's, after every SetValue (1528):
	-- a range that assumes its own 5-unit top and 7-unit bottom inset.
	env.hooksecurefunc(scroll.ScrollBar, "SetValue", function(self)
		local range = math.floor(child:GetHeight() + 10) - list:GetHeight()
		self:SetMinMaxValues(0, math.max(0, range))
	end)

	-- SetStep(count, elements) activates the guide's steps: m.guide's, or count plain steps with that many elements
	-- each (a number, or one per step). It makes a step frame per active step on first use (990-1000), its plate
	-- (1038-1061) and its element frames, each with its check, its text and its tag icon (1087-1136), sets the
	-- check's art from the theme (1137-1141), then lays everything out in UpdateText (1222).
	rxp.SetStep = m.trust(function(count, elements)
		if count or not active[1] then
			local specs = Specs(count, elements)
			active = {}
			for i = 1, count or #specs do
				active[i] = specs[i]
			end
		end
		local pool = current.framePool
		for c, spec in ipairs(active) do
			local step = pool[c]
			if not step then
				step = Backdrop(m, m.frame("Frame", current, "RXPFrame_frame" .. c))
				step.elements = {}
				pool[c] = step
			end
			step:SetFrameStrata(f:GetFrameStrata())
			step:SetScript("OnMouseDown", nil)
			step:SetScript("OnMouseUp", nil)
			if not step.number then
				step.number = Backdrop(m, m.frame("Frame", step, "RXPFrame_frame" .. c .. "_number"))
				step.number:SetPoint("TOPLEFT", step, "TOPLEFT", 7, 5)
				m.text(step.number, "text")
				step.number.text:SetPoint("CENTER", step.number, "CENTER", 2, 1)
				step.number.text:SetJustifyH("CENTER")
				step.number.text:SetJustifyV("MIDDLE")
				step.number.text:SetTextColor(Color("textColor"))
				local plateFont, plateSize = GuideFont()
				step.number.text:SetFont(plateFont, plateSize, "")
				step:ClearBackdrop()
				step:SetBackdrop(f.backdrop.edge)
				step:SetBackdropColor(Color("background"))
				step.number:ClearBackdrop()
				step.number:SetBackdrop(f.backdrop.edge)
				step.number:SetBackdropColor(Color("background"))
			end
			step.number:SetAlpha(spec.title == "" and 0 or 1)
			step.step, step.index = spec, spec.index or c
			for e in ipairs(spec.elements) do
				local row = step.elements[e]
				if not row then
					row = m.frame("Frame", step, "RXPFrame_frame" .. c .. "_" .. e)
					local button = m.frame("CheckButton", row, "RXPFrame_frame" .. c .. "_" .. e .. "Check", "ChatConfigCheckButtonTemplate")
					row.button = button
					button:SetSize(12, 12)
					Art(m, button, "Highlight", "Interface/MINIMAP/UI-Minimap-ZoomButton-Highlight")
					row.text = m.text(row)
					row.text:SetJustifyH("LEFT")
					row.text:SetJustifyV("MIDDLE")
					row.text:SetTextColor(Color("textColor"))
					local path, size = GuideFont()
					row.text:SetFont(path, size + 2, "")
					row.icon = m.text(row)
					row.highlight = m.texture(row, "HIGHLIGHT")
					row.highlight:SetAllPoints(row.text)
					row.highlight:Hide()
					step.elements[e] = row
				end
				if row.button.theme ~= rxp.activeTheme then
					row.button.theme = rxp.activeTheme
					Art(m, row.button, "Normal", Texture("rxp-btn-blank-32"))
					Art(m, row.button, "Checked", Texture("rxp-checked-32"))
					Art(m, row.button, "DisabledChecked", Texture("rxp-checked-32"))
				end
				row.element = spec.elements[e]
				row.button:SetChecked(false)
			end
			for e = #spec.elements + 1, #step.elements do
				step.elements[e]:Hide()
			end
			step:Show()
		end
		for c = #active + 1, #pool do
			pool[c]:Hide()
		end
		if rxp.UpdateItemFrame then
			rxp.UpdateItemFrame()
		end
		current.UpdateText()
	end)

	-- LoadGuide writes the guide's name over its group in the header (1954) and makes the list's rows.
	rxp.LoadGuide = m.trust(function(self, guide)
		assert(self == rxp, "LoadGuide is a method")
		rxp.currentGuide = guide
		local title = guide.displayname or guide.name or ""
		name.text:SetText(guide.subgroup and (title .. "\n" .. guide.subgroup) or title)
		m.rows(guide.rows or 1)
	end)

	-- Step list rows: RestedXP draws them flat in the theme's bottomFrameBG colour, each with its text and a
	-- number at its bottom right. m.rows(count) makes more as the guide list grows.
	function m.rows(count)
		local pool = child.framePool
		for n = #pool + 1, count do
			local row = Backdrop(m, m.frame("Frame", child, "RXPFrame_bottomFrame_steps_frame_" .. n))
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

	-- Timers.lua: the bar container on the footer (5-16). A running timer bar hides the footer's grip, text and cog
	-- (174-176); when the last bar hides, stopped or run out, they come back at full alpha (18-25), as they do when
	-- HideTimers hides every bar (112-121). Every change sorts the bars (SortTimers, 28).
	local bars = m.frame("Frame", f, "RXPFrameBarContainer")
	bars.height, bars.bars = 16, {}
	bars:SetPoint("TOPLEFT", footer, "TOPLEFT", 4, 0)
	bars:SetPoint("BOTTOMRIGHT", footer, "BOTTOMRIGHT", 0, 1)
	f.BarContainer = bars
	local function FooterAlpha(alpha)
		footer.icon:SetAlpha(alpha)
		footer.text:SetAlpha(alpha)
		footer.cog:SetAlpha(alpha)
	end
	rxp.sorts = 0
	rxp.SortTimers = m.trust(function(self)
		assert(self == rxp, "SortTimers is a method")
		rxp.sorts = rxp.sorts + 1
	end)
	local function OnHide(label)
		bars.bars[label] = nil
		rxp:SortTimers()
		if not next(bars.bars) then
			FooterAlpha(1)
		end
	end
	rxp.StartTimer = m.trust(function(duration, label)
		if type(duration) ~= "number" or duration <= 0 or not f:IsShown() then
			return
		end
		label = label or ""
		bars.bars[label] = bars.bars[label] or m.frame("Frame", env.UIParent)
		FooterAlpha(0)
		rxp:SortTimers()
		return bars.bars[label]
	end)
	rxp.StopTimer = m.trust(function(label)
		if bars.bars[label] then
			OnHide(label)
			rxp:SortTimers()
		end
	end)
	rxp.HideTimers = m.trust(function()
		for label in pairs(bars.bars) do
			bars.bars[label] = nil
		end
		FooterAlpha(1)
	end)
	-- m.expire(label) is a bar running out: LibCandyBar hides it, and its OnHide runs.
	m.expire = m.trust(OnHide)
	-- m.logout() is PLAYER_LOGOUT: RestedXP saves every enabled frame's place (RXPGuides.lua 1831).
	function m.logout()
		rxp.settings:SaveFramePositions()
	end

	rxp.SetupGuideWindow()
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
	-- LibUIDropDownMenu.lua:58-59,1213-1248,1386 lays out 16-unit rows within 15-unit borders.
	m.menuRows = m.trust(function(values)
		local list = lists[1]
		local width = 220
		for i, value in ipairs(values) do
			local name = "L_DropDownList1Button" .. i
			local button = env[name] or m.frame("Button", list, name)
			local label = env[name .. "NormalText"] or m.text(button)
			env[name .. "NormalText"] = label
			button:SetPoint("TOPLEFT", list, "TOPLEFT", 10, -15 - (i - 1) * 16)
			button:SetSize(width - 20, 16)
			label:SetPoint("LEFT", button, "LEFT", 0, 0)
			label:SetJustifyH("LEFT")
			label:SetText(value)
		end
		list:SetSize(width, #values * 16 + 30)
		m.seal()
		return list
	end)
	return lists
end

-- The waypoint arrow, as map.lua builds it (40-98): a 32-unit movable frame at the screen's top, its texture
-- filling it and its text 5 under it, saved with the other frames. SetupArrow writes the text at 9 with an outline
-- and the theme's colour and sets the theme's arrow (93-98); DrawArrow turns the texture and writes the step's
-- title over the distance, with each colour token swapped for the player's colour (140-166).
local function Arrow(m, rxp)
	local arrow = m.frame("Frame", nil, "RXPG_ARROW")
	rxp.arrowFrame = arrow
	rxp.enabledFrames.arrowFrame = arrow
	function arrow.IsFeatureEnabled()
		return not rxp.settings.profile.disableArrow and rxp.hideArrow == false, false
	end
	arrow:SetMovable(true)
	arrow:EnableMouse(true)
	arrow:SetClampedToScreen(true)
	arrow:SetSize(32, 32)
	m.texture(arrow, "ARTWORK", "texture")
	arrow.texture:SetAllPoints(arrow)
	m.text(arrow, "text")
	arrow.text:SetJustifyH("CENTER")
	arrow.text:SetJustifyV("MIDDLE")
	arrow.text:SetPoint("TOP", arrow, "BOTTOM", 0, -5)
	arrow:SetPoint("TOP", m.env.UIParent, "TOP", 0, 0)
	arrow:Hide()
	arrow.UpdateVisuals = m.trust(function(self)
		local theme = rxp.activeTheme
		local path = ((theme and theme.texturePath) or FOLDER) .. "rxp_navigation_arrow-1"
		if rxp.v2:IsGuideWindowEnabled() then
			path = rxp.v2:GetTheme().navigationArrow
		end
		self.texture:SetTexture(path)
	end)
	arrow:SetScript("OnMouseDown", m.trust(function()
		if not rxp.settings.profile.lockFrames then
			arrow:StartMoving()
		end
	end))
	arrow:SetScript("OnMouseUp", m.trust(function()
		arrow:StopMovingOrSizing()
		rxp.settings:SaveFramePositions()
	end))
	rxp.SetupArrow = m.trust(function()
		rxp.arrows = rxp.arrows + 1
		arrow.text:SetFont(rxp.font or "Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
		arrow:UpdateVisuals()
		local theme = rxp.activeTheme
		arrow.text:SetTextColor(unpack(theme and theme.textColor or { 1, 1, 1 }))
	end)
	-- m.arrow(title, distance, orientation) draws the arrow as DrawArrow does for a waypoint.
	m.arrow = m.trust(function(title, distance, orientation)
		arrow:SetAlpha(1)
		arrow:Show()
		arrow.texture:SetRotation(orientation or 0)
		if title then
			arrow.text:SetText(string.format("%s\n(%dyd)", rxp.settings.ReplaceColors(title), distance or 0))
		else
			arrow.text:SetText(string.format("(%dyd)", distance or 0))
		end
	end)
end

-- IconFrame(m, rxp, key, name, rise, label) is the frame both icon windows share (ActiveItemFrame.lua 256-327,
-- Targeting.lua 835-898): a movable BackdropTemplate frame at the screen's centre, saved with the other frames,
-- its title plate a child hanging from (5, rise) over its top edge, 19 tall and 10 wider than its words, three
-- levels above it.
local function IconFrame(m, rxp, key, name, rise, label)
	local f = Backdrop(m, m.frame("Frame", nil, name))
	rxp.enabledFrames[key] = f
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:SetPoint("CENTER", m.env.UIParent, "CENTER", 0, 0)
	f.onMouseDown = m.trust(function()
		if rxp.settings.profile.lockFrames then
			return
		end
		f:StartMoving()
	end)
	f.onMouseUp = m.trust(function()
		f:StopMovingOrSizing()
		rxp.settings:SaveFramePositions()
	end)
	f:SetScript("OnMouseDown", f.onMouseDown)
	f:SetScript("OnMouseUp", f.onMouseUp)
	f.title = Backdrop(m, m.frame("Frame", f, name .. "_title"))
	f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 5, rise)
	f.title:SetFrameLevel(f:GetFrameLevel() + 3)
	m.text(f.title, "text")
	f.title.text:SetPoint("CENTER", f.title, "CENTER", 0, 0)
	f.title.text:SetJustifyH("CENTER")
	f.title.text:SetJustifyV("MIDDLE")
	f.title.text:SetFont(rxp.font or "Fonts\\FRIZQT__.TTF", 9, "")
	f.title.text:SetText(label)
	f.title:EnableMouse(true)
	f.title:SetScript("OnMouseDown", f.onMouseDown)
	f.title:SetScript("OnMouseUp", f.onMouseUp)
	-- Title() redraws the plate as both UpdateVisuals do: its backdrop, its font at 9, the theme's colour, its size.
	function f.Title()
		local theme = rxp.activeTheme
		f.title:ClearBackdrop()
		f.title:SetBackdrop(rxp.RXPFrame.backdrop.edge)
		f.title:SetBackdropColor(unpack(theme and theme.background or { 0, 0, 0 }))
		f.title.text:SetFont(rxp.font or "Fonts\\FRIZQT__.TTF", 9, "")
		f.title.text:SetTextColor(unpack(theme and theme.textColor or { 1, 1, 1 }))
		f.title:SetSize(StringWidth(f.title.text) + 10, 19)
	end
	return f
end

-- IconButton(m, parent, name, cooldown) is a 25-unit secure button with its icon behind it and a square highlight;
-- an item button also holds a cooldown frame (ActiveItemFrame.lua 414-447, Targeting.lua 1174-1211).
local function IconButton(m, parent, name, cooldown)
	local button = m.frame("Button", parent, name, "SecureActionButtonTemplate")
	button:SetSize(25, 25)
	m.texture(button, "BACKGROUND", "icon")
	button.icon:SetAllPoints(button)
	button.icon:SetTexture("Interface/Buttons/Button-Backpack-Up")
	Art(m, button, "Highlight", "Interface/Buttons/ButtonHilight-Square")
	if cooldown then
		button.cooldown = m.frame("Cooldown", button, name .. "Cooldown", "CooldownFrameTemplate")
		button.cooldown:SetAllPoints(button)
		button.cooldown:Hide()
	end
	return button
end

local function ItemsAndTargets(m, rxp)
	local env = m.env
	local items = IconFrame(m, rxp, "activeItemFrame", "RXPItemFrame", 10, "Active Items")
	items.buttonList = {}
	rxp.activeItemFrame = items
	m.items = 0
	function items.IsFeatureEnabled()
		return not rxp.settings.profile.disableItemWindow and m.items > 0, true
	end
	-- UpdateVisuals (ActiveItemFrame.lua 216-234): the frame's backdrop at 0.4 unless activeItemHideBG, then the
	-- title plate.
	items.UpdateVisuals = m.trust(function(self, updateFrame)
		self:ClearBackdrop()
		if not rxp.settings.profile.activeItemHideBG then
			self:SetBackdrop(rxp.RXPFrame.backdrop.edge)
			local theme = rxp.activeTheme
			local r, g, b = unpack(theme and theme.background or { 0, 0, 0 })
			self:SetBackdropColor(r, g, b, 0.4)
		end
		self.Title()
		if updateFrame and self.UpdateFrame then
			return self:UpdateFrame()
		end
	end)
	-- UpdateItemFrame(frame, count) lists the step's items (ActiveItemFrame.lua 351-506): count is how many the
	-- step has, kept until the next count. The first button sits at the frame's bottom left (4, 2), each next one
	-- 27 right of the last; the frame is as wide as its buttons, or its title plus 10, and hides with no items.
	rxp.UpdateItemFrame = m.trust(function(frame, count)
		frame = frame or items
		if env.InCombatLockdown() then
			return
		end
		m.items = count or m.items
		frame.title:SetSize(StringWidth(frame.title.text) + 10, 19)
		local list = frame.buttonList
		for i = 1, m.items do
			local button = list[i]
			if not button then
				button = IconButton(m, frame, "RXPItemFrameButton" .. i, true)
				list[i] = button
				if i == 1 then
					button:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 4, 2)
				else
					button:SetPoint("CENTER", list[i - 1], "CENTER", 27, 0)
				end
			end
			button:Show()
		end
		if m.items > 0 then
			frame:SetAlpha(1)
		end
		frame:SetShown(m.items > 0 and not rxp.settings.profile.disableItemWindow)
		for i = m.items + 1, #list do
			list[i]:Hide()
		end
		frame:SetWidth(math.max((frame.title:GetWidth() or 0) + 10, m.items * 27 + 8))
		m.seal()
	end)
	items.UpdateFrame = rxp.UpdateItemFrame
	items:UpdateVisuals()
	items:SetHeight(43)
	items:Hide()

	local targets = IconFrame(m, rxp, "activeTargetFrame", "RXPTargetFrame", 8, "Active Targets")
	targets.enemyTargetButtons, targets.friendlyTargetButtons = {}, {}
	rxp.targeting = { activeTargetFrame = targets }
	targets:Hide()
	m.targets = 0
	function targets.IsFeatureEnabled()
		return rxp.settings.profile.enableTargetFrame ~= false and m.targets > 0, true
	end
	-- RenderTargetFrameBackground (Targeting.lua 900-923) and UpdateVisuals (806-819): the frame's scale, its
	-- backdrop unless hideActiveTargetsBackground, then the title plate.
	rxp.targeting.RenderTargetFrameBackground = m.trust(function(self)
		assert(self == rxp.targeting, "RenderTargetFrameBackground is a method")
		targets:ClearBackdrop()
		if not rxp.settings.profile.hideActiveTargetsBackground then
			targets:SetBackdrop(rxp.RXPFrame.backdrop.edge)
			local theme = rxp.activeTheme
			targets:SetBackdropColor(unpack(theme and theme.background or { 0, 0, 0 }))
		end
	end)
	targets.UpdateVisuals = m.trust(function(self)
		self:SetScale(rxp.settings.profile.activeTargetScale or 1)
		rxp.targeting:RenderTargetFrameBackground()
		self.Title()
	end)
	-- UpdateTargetFrame(count, friendly) lists the step's targets (Targeting.lua 1129-1325): count enemies and
	-- friendly friends, never in combat. The first enemy sits at the frame's top left (6, -15), the first friend
	-- at its bottom left (6, 6), each next one 27 right of the last; the frame is 18 plus 25 a row tall, 5 more
	-- with both kinds, and as wide as its longer row or its title plus 10.
	rxp.targeting.UpdateTargetFrame = m.trust(function(self, count, friendly)
		assert(self == rxp.targeting, "UpdateTargetFrame is a method")
		if rxp.settings.profile.enableTargetFrame == false or env.InCombatLockdown() then
			return
		end
		local enemies, friends = count or 1, friendly or 0
		m.targets = enemies + friends
		local function Row(list, wanted, prefix, point, y)
			for i = 1, wanted do
				local button = list[i]
				if not button then
					button = IconButton(m, targets, prefix .. i)
					m.texture(button, "ARTWORK", "placeholder")
					list[i] = button
				end
				button:ClearAllPoints()
				if i == 1 then
					button:SetPoint(point, targets, point, 6, y)
				else
					button:SetPoint("CENTER", list[i - 1], "CENTER", 27, 0)
				end
				button:Show()
			end
			for i = wanted + 1, #list do
				list[i]:Hide()
			end
		end
		Row(targets.enemyTargetButtons, enemies, "RXPTargetFrame_EnemyButton", "TOPLEFT", -15)
		Row(targets.friendlyTargetButtons, friends, "RXPTargetFrame_FriendlyButton", "BOTTOMLEFT", 6)
		local rows = (enemies > 0 and 1 or 0) + (friends > 0 and 1 or 0)
		targets:SetWidth(math.max((targets.title:GetWidth() or 0) + 10, math.max(enemies, friends) * 27 + 10))
		targets:SetHeight(18 + rows * 25 + (rows == 2 and 5 or 0))
		targets:SetShown(m.targets > 0)
		m.seal()
	end)
	targets:SetHeight(40)
	targets:UpdateVisuals()
end

-- AceFrame(m) is the shape of an AceGUI "Frame" container: the widget table and its frame.
local function AceFrame(m)
	local frame = Backdrop(m, m.frame("Frame"))
	frame:SetBackdrop()
	local widget = { frame = frame, type = "Frame", children = {} }
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
	for _ = 1, 3 do m.frame("Frame", frame) end
	widget.AddChild = m.trust(function(self, child)
		child.frame:SetParent(self.content)
		self.children[#self.children + 1] = child
	end)
	widget.Release = m.trust(function(self)
		if self.released then return end
		self.released = true
		local function ReleaseChildren(parent)
			for _, child in ipairs(parent.children or {}) do
				child.released = true
				m.close(child.frame)
				ReleaseChildren(child)
			end
		end
		ReleaseChildren(self)
		m.close(self.frame)
		self.children = {}
	end)
	frame:SetScript("OnHide", function()
		if widget.onClose then widget.onClose() end
	end)
	return widget
end

local function AceLabel(m, parent, value)
	local frame = m.frame("Frame", parent)
	local label = m.text(frame)
	-- AceGUIWidget-Label.lua:78-83 sets these before a skin leases the label's alignment.
	label:SetJustifyH("LEFT")
	label:SetJustifyV("TOP")
	label:SetText(value or "")
	return { frame = frame, label = label, type = "Label" }
end

local function AceScroll(m, parent, kind)
	local frame = m.frame("Frame", parent)
	local scrollframe = m.frame("ScrollFrame", frame)
	local prefix = kind == "RXPV2ScrollFrame" and "RXPV2ScrollFrame" or "AceConfigDialogScrollFrame"
	m.widgetCounts = m.widgetCounts or {}
	m.widgetCounts[prefix] = (m.widgetCounts[prefix] or 0) + 1
	local scrollbar = ScrollBar(m, scrollframe, prefix .. m.widgetCounts[prefix] .. "ScrollBar")
	local content = m.frame("Frame", scrollframe)
	local widget = { frame = frame, scrollframe = scrollframe, scrollbar = scrollbar, content = content, children = {}, type = kind or "ScrollFrame", layouts = 0 }
	widget.AddChild = m.trust(function(self, child)
		child.frame:SetParent(self.content)
		self.children[#self.children + 1] = child
	end)
	widget.DoLayout = function(self) self.layouts = self.layouts + 1 end
	return widget
end

local function AceGroup(m, parent)
	local frame = m.frame("Frame", parent)
	return { frame = frame, content = m.frame("Frame", frame), children = {}, type = "SimpleGroup" }
end

local function Normal(m, button, path)
	local texture = m.texture(button, "ARTWORK")
	texture:SetTexture("Interface/AddOns/RXPGuides/Textures/" .. path)
	button:SetNormalTexture(texture)
end

local function Tracker(m, rxp, env)
	rxp.tracker = { ui = {} }
	rxp.tracker.CreateGui = m.trust(function(self, attachment, target)
		assert(self == rxp.tracker, "CreateGui is a method")
		if not attachment or not attachment:GetName() or self.ui[attachment:GetName()] then return end
		local report = AceFrame(m)
		self.ui[attachment:GetName()] = report
		report.frame:Hide()
		report.titletext:SetText("RestedXP Leveling Report")
		report.frame:SetPoint("TOPLEFT", attachment, "TOPRIGHT", -38, -32)
		env.RESTEDXP_TRACKER_SUMMARY_WINDOW = report.frame
		local scroll = AceScroll(m, report.content)
		report.scrollContainer = scroll
		report:AddChild(scroll)
		local top = AceGroup(m, scroll.content)
		m.buttonCount = (m.buttonCount or 0) + 1
		report.levelButton = { frame = PanelButton(m, top.content, "AceGUI30Button" .. m.buttonCount, "1 to 2") }
		report.levelMenuFrame = m.frame("Frame", report.levelButton.frame, "RXPG_LevelMenuFrame", "UIDropDownMenuTemplate")
		report.target = AceLabel(m, top.content, target)
		-- LevelingTracker.lua:499-503 centers the target label before AceGUI lays out the top row.
		report.target.label:SetJustifyH("CENTER")
		top.children = { report.levelButton, report.target }
		scroll:AddChild(top)
		for _, key in ipairs({ "reached", "speed", "zones", "sources", "teamwork", "extras" }) do
			local group = key == "zones" and { content = scroll.content, children = {} } or AceGroup(m, scroll.content)
			group.label = AceLabel(m, group.content, key)
			group.label.type = "Heading"
			group.children = { group.label }
			if key == "sources" or key == "teamwork" then
				group.data = {}
				for _, field in ipairs(key == "sources" and { "quests", "mobs" } or { "solo", "group" }) do
					group.data[field] = AceLabel(m, group.content, field)
					group.children[#group.children + 1] = group.data[field]
				end
			else
				group.data = AceLabel(m, group.content, "In-progress")
				group.children[#group.children + 1] = group.data
			end
			report[key .. "Container"] = group
			if key == "zones" then
				scroll:AddChild(group.label)
				scroll:AddChild(group.data)
				report.zonesContainer = { label = group.label, data = group.data }
			else
				scroll:AddChild(group)
			end
		end
		attachment:HookScript("OnHide", function() m.close(report.frame) end)
	end)
	local character = env.CharacterFrame
	if character == nil then character = m.frame("Frame", env.UIParent, "CharacterFrame") end
	if rxp.settings.profile.enableTracker ~= false and character then rxp.tracker:CreateGui(character, "Tester") end
	rxp.tracker.CreateLevelSplits = m.trust(function(self)
		assert(self == rxp.tracker)
		if self.levelSplits then return end
		local splits = Backdrop(m, m.frame("Frame", env.UIParent, "RXPLevelSplits"))
		self.levelSplits = splits
		self:RenderSplitsBackground()
		splits:SetPoint("CENTER", env.UIParent, "CENTER", 0, 0)
		splits:SetSize(100, 48)
		splits.title = Backdrop(m, m.frame("Frame", splits, "RXPLevelSplits_title"))
		splits.title:SetBackdrop()
		splits.title:SetPoint("TOP", splits, "TOP", 0, 5)
		splits.title:SetSize(80, 17)
		splits.title.splitsMenuFrame = m.frame("Frame", splits.title, "RXPG_SplitsMenuFrame", "UIDropDownMenuTemplate")
		splits.title.cog = m.frame("Button", splits.title, "RXPLevelSplits_titleCogwheel")
		splits.title.cog:SetSize(18, 18)
		splits.title.cog:SetPoint("LEFT", splits.title, "LEFT", -9, 0)
		Normal(m, splits.title.cog, "rxp_cog-32")
		m.text(splits.title, "text"):SetText("Level splits")
		local previous
		for _, key in ipairs({ "history", "current", "total" }) do
			local label = AceLabel(m, splits)
			label.frame:SetPoint("TOPLEFT", previous or splits, previous and "BOTTOMLEFT" or "TOPLEFT", previous and 0 or 8, previous and (key == "current" and -8 or 0) or -10.5)
			splits[key] = label
			previous = label.frame
		end
		splits:SetAlpha(rxp.settings.profile.levelSplitsOpacity or 0.9)
		m.seal()
	end)
	rxp.tracker.RenderSplitsBackground = m.trust(function(self)
		local splits = self.levelSplits
		splits:ClearBackdrop()
		if not rxp.settings.profile.hideSplitsBackground then
			splits:SetBackdrop()
		end
	end)
	if rxp.settings.profile.enableTracker ~= false and rxp.settings.profile.enablelevelSplits then rxp.tracker:CreateLevelSplits() end
end

local function RxpButton(m, parent)
	local button = RxpBackdrop(m, m.frame("Button", parent))
	m.texture(button, "BACKGROUND", "configuratorBackground")
	button.text = m.text(button)
	button:SetFontString(button.text)
	return button
end

-- The configurator's option rows, as RestedXP's GuideConfigurator.lua renders a page: label, icon, whether
-- the row is recommended and checked. The scene draws the same three.
Fake.CONFIGURATOR_OPTIONS = {
	{ label = "Skip Deadmines", recommended = true, icon = 136169, checked = true },
	{ label = "Buy the riding skill at 40", recommended = false, icon = 132261, checked = true },
	{ label = "Do the Scarlet Monastery chain", recommended = false, icon = 135987, checked = false },
}

-- ConfiguratorOption(m, rxp, parent, option) is an RXPV2GuideConfiguratorOption widget (GuideConfigurator.lua:579):
-- a backdrop Button row with its own flat configuratorBackground, a 40-unit image and the "Recommended" line on
-- the border frame, the label, and a 17-unit checkbg frame at the right holding a tick (checkShort, checkLong)
-- and the six checkedFill pieces RestedXP tints with its theme's checked colour while the option is on.
local function ConfiguratorOption(m, rxp, parent, option)
	local frame = RxpBackdrop(m, m.frame("Button", parent))
	m.texture(frame, "BACKGROUND", "configuratorBackground")
	frame.configuratorBackground:SetAllPoints(frame)
	local image = m.texture(frame.rxpBorder, "OVERLAY")
	image:SetSize(40, 40)
	image:SetPoint("LEFT", frame, "LEFT", 2, 0)
	image:SetTexture(option.icon)
	local text = m.text(frame)
	text:SetJustifyH("LEFT")
	text:SetHeight(16)
	text:SetPoint("LEFT", image, "RIGHT", 7, 0)
	text:SetText(option.label)
	local recommendation = m.text(frame.rxpBorder)
	recommendation:SetTextColor(0.05, 0.75, 1)
	recommendation:SetPoint("BOTTOMLEFT", text, "TOPLEFT", 0, 2)
	recommendation:SetHeight(12)
	recommendation:SetText("Recommended")
	recommendation:SetShown(option.recommended == true)
	local checkbg = RxpBackdrop(m, m.frame("Frame", frame))
	checkbg:SetPoint("RIGHT", frame, "RIGHT", -11, 0)
	checkbg:SetSize(17, 17)
	m.texture(checkbg, "BACKGROUND", "configuratorBackground")
	checkbg.configuratorBackground:SetAllPoints(checkbg)
	text:SetPoint("RIGHT", checkbg, "LEFT", -5, 0)
	local check = m.frame("Frame", checkbg)
	check:SetAllPoints(checkbg)
	local checkShort, checkLong = m.texture(check, "OVERLAY"), m.texture(check, "OVERLAY")
	checkShort:SetSize(3, 1)
	checkLong:SetSize(6, 1)
	local checkedFill = {}
	for i = 1, 6 do
		checkedFill[i] = m.texture(checkbg, "ARTWORK")
		checkedFill[i]:SetTexture(WHITE)
	end
	local widget = {
		type = "RXPV2GuideConfiguratorOption", frame = frame, checkbg = checkbg, check = check, checkedFill = checkedFill,
		text = text, recommendation = recommendation, image = image, checkShort = checkShort, checkLong = checkLong,
	}
	widget.SetChecked = m.trust(function(this, checked)
		this.checked = checked
		this.check:SetShown(checked)
		for _, texture in ipairs(this.checkedFill) do
			texture:SetShown(checked)
		end
		this.checkbg.configuratorBackground:SetShown(not checked)
		this.checkbg.rxpBorder:SetShown(not checked)
	end)
	widget.GetChecked = function(this)
		return this.checked
	end
	widget.UpdateSubTheme = m.trust(function(this)
		local theme = rxp.v2:GetTheme()
		local common = theme.textColor.common
		this.text:SetFont(theme.font, select(2, this.text:GetFont()), "")
		this.text:SetTextColor(common[1], common[2], common[3], common[4] or 1)
		this.frame.configuratorBackground:SetColorTexture(unpack(theme.backgroundColors.activeStepCheckbox))
		this.checkbg.configuratorBackground:SetColorTexture(unpack(theme.backgroundColors.activeStepCheckbox))
		this.checkShort:SetColorTexture(common[1], common[2], common[3], common[4] or 1)
		this.checkLong:SetColorTexture(common[1], common[2], common[3], common[4] or 1)
		for _, texture in ipairs(this.checkedFill) do
			texture:SetVertexColor(unpack(theme.backgroundColors.activeStepCheckboxChecked))
		end
	end)
	widget.UpdateTheme = m.trust(function(this)
		this:UpdateSubTheme()
	end)
	widget:UpdateSubTheme()
	widget:SetChecked(option.checked == true)
	return widget
end

-- ConfiguratorOptions(ui) -> the option widgets a configurator page shows, in order, through the padding
-- containers RestedXP wraps the first rows in.
function Fake.ConfiguratorOptions(ui)
	local list = {}
	for _, child in ipairs(ui.scrollContainer.children or {}) do
		if child.type == "RXPV2GuideConfiguratorOption" then
			list[#list + 1] = child
		else
			for _, inner in ipairs(child.children or {}) do
				if inner.type == "RXPV2GuideConfiguratorOption" then
					list[#list + 1] = inner
				end
			end
		end
	end
	return list
end

local function Popup(m, rxp)
	local frame = m.frame("Frame")
	frame:Hide()
	local close = m.frame("Button", frame)
	Normal(m, close, "rxp-btn-close")
	local widget = { frame = frame, title = m.text(frame), message = m.text(frame), buttons = {}, type = "RXPV2Popup" }
	for i = 1, 2 do
		local button = m.frame("Button", frame)
		button.text = m.text(button)
		widget.buttons[i] = button
	end
	widget.UpdateSubTheme = m.trust(function(this)
		local theme = rxp.v2:GetTheme()
		if not this.frame.rxpBackground then RxpBackdrop(m, this.frame) end
		this.title:SetFont(theme.font, 10, "")
		this.title:SetTextColor(unpack(theme.textColor.title))
		this.message:SetFont(theme.font, 9, "")
		this.message:SetTextColor(unpack(theme.textColor.common))
		for _, button in ipairs(this.buttons) do
			if not button.rxpBackground then RxpBackdrop(m, button) end
			button.text:SetFont(theme.font, 9, "")
			button.text:SetTextColor(unpack(theme.textColor.common))
		end
	end)
	widget.UpdateTheme = function(this) this:UpdateSubTheme() end
	widget.Show = m.trust(function(this) this:UpdateSubTheme(); m.open(this.frame) end)
	widget:UpdateSubTheme()
	return widget
end

local function V2Windows(m, rxp)
	local ui = rxp.ui
	rxp.player = rxp.player or { level = 1 }
	local configurator = {}
	ui.v2.configurator = configurator
	configurator.CreateGuideConfigurator = m.trust(function(self)
		assert(self == configurator)
		if self.ui then return self.ui end
		local frame = RxpBackdrop(m, m.frame("Frame"))
		frame:Hide()
		m.texture(frame.rxpBackground, "ARTWORK", "configuratorHeader")
		m.frame("Frame", frame)
		local close = m.frame("Button", frame)
		Normal(m, close, "rxp-btn-close")
		local widget = { frame = frame }
		widget.titletext = m.text(frame)
		widget.description = m.text(frame)
		widget.topLeftIcon = m.texture(frame, "OVERLAY")
		widget.backbutton = RxpButton(m, frame)
		widget.resetbutton = RxpButton(m, frame)
		widget.submitbutton = RxpButton(m, frame)
		widget.buttonRow = m.frame("Frame", frame)
		widget.content = m.frame("Frame", frame)
		for _, art in ipairs({ "rxp-icon-cog", "icon-btn-import", "icon-btn-help" }) do
			local button = m.frame("Button", frame)
			Normal(m, button, art)
		end
		widget.scrollContainer = AceScroll(m, widget.content, "RXPV2ScrollFrame")
		widget.Refresh = function() self:ShowPage() end
		self.ui = widget
		m.seal()
		return widget
	end)
	-- LoadPages renders the page's option rows into the scroll container as GuideConfigurator.lua's renderOptions
	-- does: the rows but the last inside padding containers, then the container lays itself out.
	configurator.LoadPages = m.trust(function(self)
		local container = self.ui.scrollContainer
		container.children = {}
		local intro = AceGroup(m, container.content)
		intro.type = "RXPV2GuideConfiguratorOptionPadding"
		intro.titleLabel = AceLabel(m, intro.content, "Guide choices")
		intro.descriptionLabel = AceLabel(m, intro.content, "Choose your route")
		intro.children = { intro.titleLabel, intro.descriptionLabel }
		container.children[1] = intro
		for i, option in ipairs(Fake.CONFIGURATOR_OPTIONS) do
			if i < #Fake.CONFIGURATOR_OPTIONS then
				local padding = { type = "RXPV2GuideConfiguratorOptionPadding", frame = m.frame("Frame", container.content), children = {} }
				padding.content = m.frame("Frame", padding.frame)
				padding.children[1] = ConfiguratorOption(m, rxp, padding.content, option)
				container.children[#container.children + 1] = padding
			else
				container.children[#container.children + 1] = ConfiguratorOption(m, rxp, container.content, option)
			end
		end
		m.seal()
		container:DoLayout()
	end)
	-- UpdateTheme redraws the configurator from the theme, as RestedXP's GuideConfigurator.lua does: the title in
	-- the theme font at the guide size plus 2 in a fixed gold, each button's label in the theme font and text
	-- colour, and its own flat background texture coloured from the theme.
	configurator.UpdateTheme = m.trust(function(self)
		local widget = self.ui
		if not widget then
			return
		end
		local theme = rxp.v2:GetTheme()
		widget.titletext:SetFont(theme.font, (rxp.settings.profile.guideFontSize or 10) + 2, "")
		widget.titletext:SetTextColor(1, 0.82, 0)
		widget.description:SetFont(theme.font, 9, "")
		for _, key in ipairs({ "backbutton", "resetbutton", "submitbutton" }) do
			local button = widget[key]
			button.text:SetFont(theme.font, select(2, button.text:GetFont()), "")
			button.text:SetTextColor(1, 1, 1)
			button.configuratorBackground:SetColorTexture(unpack(key == "submitbutton" and theme.backgroundColors.activeStepCheckboxChecked or theme.backgroundColors.guideSelector))
			button.configuratorBackground:SetAlpha(1)
		end
		for _, option in ipairs(Fake.ConfiguratorOptions(widget)) do
			option:UpdateTheme()
		end
	end)
	function configurator.ShowPage(self) self:LoadPages() end
	function configurator.Open(self, login)
		if login then
			local data = m.env.RXPCData
			if data and data.currentGuideName and data.currentGuideName ~= "" then return end
			if rxp.currentGuide and not rxp.currentGuide.empty then return end
			if rxp.player.level ~= 1 then return end
		end
		local widget = self:CreateGuideConfigurator()
		widget:Refresh()
		m.open(widget.frame)
	end

	local importer = { widgets = {} }
	rxp.guideImporter = importer
	ui.v2.CreateGuideImporter = m.trust(function(self)
		assert(self == ui.v2)
		local widgets = importer.widgets
		if widgets.import then return widgets.import end
		local frame = RxpBackdrop(m, m.frame("Frame"))
		frame:Hide()
		local close = m.frame("Button", frame)
		Normal(m, close, "rxp-btn-close")
		local window = { frame = frame, title = m.text(frame), description = m.text(frame), content = m.frame("Frame", frame), children = {}, closebutton = close }
		for _, key in ipairs({ "importerBackground", "importerBody", "importerHeader" }) do
			m.texture(frame, "BACKGROUND", key)
		end
		local function ImportButton(key)
			local button = RxpBackdrop(m, m.frame("Button", window.content))
			local widget = { frame = button, text = m.text(button), type = "RXPV2GuideImporterButton" }
			widgets[key] = widget
			window.children[#window.children + 1] = widget
		end
		widgets.purgeConfirmation = Popup(m, rxp)
		widgets.importLabel = m.text(window.content)
		local boxFrame = m.frame("Frame", window.content)
		local label = m.text(boxFrame)
		local background = RxpBackdrop(m, m.frame("Frame", boxFrame))
		local box = m.frame("EditBox", background, "RXPV2GuideImporterEditBox1Edit")
		widgets.importBox = { frame = boxFrame, background = background, editBox = box, label = label, labelHeight = 0, numlines = 4 }
		widgets.importBox.GetEditBox = function(this) return this.editBox end
		widgets.importBox.label:Hide()
		window.children[#window.children + 1] = widgets.importBox
		ImportButton("importButton")
		ImportButton("importSplicedString")
		widgets.guidesLabel = m.text(window.content)
		local dropdownFrame = RxpBackdrop(m, m.frame("Frame", window.content))
		local dropdown = m.frame("Frame", dropdownFrame, "AceGUI30DropDown1", "UIDropDownMenuTemplate")
		widgets.currentGuides = { frame = dropdownFrame, dropdown = dropdown, text = m.text(dropdown), label = m.text(dropdownFrame), button = m.frame("Button", dropdown), button_cover = m.frame("Button", dropdownFrame) }
		-- LibUIDropDownMenu.lua:647-650: the selected value is right-aligned before a skin leases it.
		widgets.currentGuides.text:SetJustifyH("RIGHT")
		Normal(m, widgets.currentGuides.button, "scrollbar_down")
		widgets.currentGuides.button_cover:Hide()
		widgets.currentGuides.label:Hide()
		window.children[#window.children + 1] = widgets.currentGuides
		ImportButton("purgeButton")
		ImportButton("reloadButton")
		ImportButton("deleteButton")
		widgets.deleteConfirmation = Popup(m, rxp)
		widgets.progressLabel = m.text(window.content)
		widgets.progress = RxpBackdrop(m, m.frame("StatusBar", window.content))
		widgets.progress:SetStatusBarTexture(WHITE)
		widgets.progress:SetMinMaxValues(0, 1)
		widgets.progress:SetValue(0)
		widgets.progressBackground = m.texture(widgets.progress, "BACKGROUND")
		widgets.progressText = m.text(widgets.progress)
		widgets.history = m.text(window.content)
		widgets.import = window
		window.UpdateSubTheme = m.trust(function(this)
			local theme = rxp.v2:GetTheme()
			this.title:SetFont(theme.font, 10, "")
			this.title:SetTextColor(1, 0.82, 0)
			this.frame.importerBody:SetAlpha(1)
			this.frame.importerHeader:SetAlpha(0.5)
			for _, key in ipairs({ "importLabel", "guidesLabel", "progressLabel", "progressText", "history" }) do widgets[key]:SetFont(theme.font, 8, "") end
			for _, key in ipairs({ "importButton", "importSplicedString", "purgeButton", "reloadButton", "deleteButton" }) do
				widgets[key].text:SetFont(theme.font, 9, "")
			end
			widgets.purgeConfirmation:UpdateTheme({})
			widgets.deleteConfirmation:UpdateTheme({})
		end)
		window:UpdateSubTheme()
		m.seal()
		return window
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
	local pool, editPool = {}, {}
	local function Acquire()
		for _, widget in ipairs(pool) do
			if widget.released then
				widget.released, widget.onClose = false, nil
				widget.children = {}
				return widget
			end
		end
		local widget = AceFrame(m)
		pool[#pool + 1] = widget
		return widget
	end
	local function Edit(parent)
		local widget
		for _, candidate in ipairs(editPool) do
			if candidate.released then widget = candidate; break end
		end
		if not widget then
			local frame = m.frame("Frame", parent.content)
			local label = m.text(frame)
			-- AceGUIWidget-MultiLineEditBox.lua:290-292,338-339: defaults read by leased text and the renderer.
			label:SetJustifyH("LEFT")
			local button = PanelButton(m, frame, "MultiLineEditBox" .. (#editPool + 1) .. "Button", "Accept")
			local background = Backdrop(m, m.frame("Frame", frame))
			background:SetBackdrop()
			local scroll = m.frame("ScrollFrame", frame, "MultiLineEditBox" .. (#editPool + 1) .. "ScrollFrame", "UIPanelScrollFrameTemplate")
			local scrollbar = ScrollBar(m, scroll, scroll:GetName() .. "ScrollBar")
			local box = m.frame("EditBox", scroll, "MultiLineEditBox" .. (#editPool + 1) .. "Edit")
			box:SetFont("Fonts\\ARIALN.TTF", 12, "")
			box:SetMultiLine(true)
			widget = { type = "MultiLineEditBox", frame = frame, label = label, button = button, editBox = box, scrollBG = background, scrollFrame = scroll, scrollBar = scrollbar, labelHeight = 10, numlines = 4 }
			editPool[#editPool + 1] = widget
		end
		widget.owner = parent.owner or parent
		widget.released = false
		widget.frame:SetParent(parent.content)
		parent:AddChild(widget)
		return widget
	end
	m.dialogPool = pool
	m.acquireDialog = m.trust(Acquire)
	rxp.comms.OpenBugReport = m.trust(function(stepNumber)
		assert(stepNumber ~= rxp.comms, "OpenBugReport is a dot function")
		local widget = Acquire()
		widget.statustext:GetParent():Hide()
		widget.scrollContainer = AceScroll(m, widget.content)
		widget.scrollContainer.owner = widget
		widget:AddChild(widget.scrollContainer)
		local edit = Edit(widget.scrollContainer)
		edit.label:SetText("Join our support discord at discord.gg/RestedXP and copy paste this form into #bug-report")
		edit.editBox:SetText("Feedback for step " .. tostring(type(stepNumber) == "table" and stepNumber.arg1 or stepNumber))
		edit.button:Hide()
		widget.titletext:SetText("RestedXP Feedback Form")
		widget.titletext:SetTextColor(1, 0.82, 0)
		env.RESTEDXP_BUG_REPORT_WINDOW = widget.frame
		m.open(widget.frame)
	end)
	rxp.comms.OpenBrandedExport = m.trust(function(title, description, content, width, height, acceptCallback)
		assert(title ~= rxp.comms, "OpenBrandedExport is a dot function")
		local widget = Acquire()
		m.close(widget.frame)
		widget.statustext:GetParent():Hide()
		widget.titletext:SetText("RestedXP: " .. (title or ""))
		widget.titletext:SetTextColor(1, 0.82, 0)
		local edit = Edit(widget)
		edit.label:SetText(description or "")
		edit.editBox:SetText(content or "")
		edit.button:SetShown(acceptCallback ~= nil)
		edit.acceptCallback = acceptCallback
		widget.frame:SetSize(width or 400, height or 100)
		widget.onClose = function() widget:Release() end
		env.RESTEDXP_BRANDED_EXPORT = widget.frame
		m.open(widget.frame)
	end)
	local questMap = env.QuestMapFrame or env.CreateFrame("Frame", "QuestMapFrame", env.UIParent)
	questMap.DetailsFrame = questMap.DetailsFrame or env.CreateFrame("Frame", nil, questMap)
	m.createCleanupButton = m.trust(function()
		if rxp.cleanupBtn then return rxp.cleanupBtn end
		local button = PanelButton(m, questMap.DetailsFrame, "RXPQuestLogCleanupButton", "Clean up")
		button:SetSize(200, 22)
		rxp.cleanupBtn = button
		return button
	end)
	local driver = m.frame("Frame")
	driver:RegisterEvent("PLAYER_ENTERING_WORLD")
	driver:RegisterEvent("ADDON_LOADED")
	driver:SetScript("OnEvent", function(_, event, addon)
		if event == "PLAYER_ENTERING_WORLD" or addon == "Blizzard_QuestLog" or addon == "Blizzard_WorldMap" or addon == "RXPGuides" then m.createCleanupButton() end
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
