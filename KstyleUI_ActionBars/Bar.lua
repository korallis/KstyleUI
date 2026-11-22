-- Bar.lua: one bar: a Layout holder, a secure state header that pages and shows it, its buttons in a grid, and its mouseover fade; a stance bar folded into rows keeps a full row's width, so a few forms sit in one row on the bar's baseline, and its backing hugs the shown forms.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens
local max, min, floor, ceil = math.max, math.min, math.floor, math.ceil

local Bar = {}
Bar.__index = Bar
ns.BarClass = Bar

local FADE_DELAY = 0.2
local BACKING_MARGIN = 3
local FLYOUT_DIRECTIONS = { TOPLEFT = "DOWN", TOP = "DOWN", TOPRIGHT = "DOWN", LEFT = "RIGHT", RIGHT = "LEFT" }
local PET_DRIVER = "[@pet,exists] show; hide"
local SPECIAL_STATES = { vehicle = true, override = true, possess = true, shapeshift = true }

local function NumForms()
	if type(GetNumShapeshiftForms) ~= "function" then
		return 0
	end
	local n = GetNumShapeshiftForms()
	if ns.IsSecret(n) or type(n) ~= "number" then
		return 0
	end
	return n
end
ns.NumForms = NumForms

local function DriverWorks(driver)
	if type(SecureCmdOptionParse) ~= "function" then
		return true, "unknown"
	end
	local ok, value = pcall(SecureCmdOptionParse, driver)
	if not ok then
		return false, tostring(value)
	end
	if ns.IsSecret(value) or value == nil or tonumber(value) or SPECIAL_STATES[value] then
		return true, tostring(value)
	end
	return false, "it reads " .. tostring(value) .. ", which is not a page"
end

function ns.NewBar(def)
	local bar = setmetatable({ def = def, buttons = {}, hovered = 0, alpha = 1, target = 1, count = 0 }, Bar)
	local holder = CreateFrame("Frame", nil, K.Scale.Root())
	bar.gate = ns.VisibilityGate(holder, def.key)
	local header = CreateFrame("Frame", "KstyleUI_" .. def.name, bar.gate, "SecureHandlerStateTemplate")
	header:SetAllPoints(holder)
	bar.holder, bar.header = holder, header
	bar.gateHidden = bar.gate:GetAttribute("toggle-hidden") == true
	bar.gate:HookScript("OnShow", function() bar.gateHidden = nil; bar:RefreshSlab() end)
	bar.gate:HookScript("OnHide", function() bar.gateHidden = true; bar:RefreshSlab() end)
	holder:HookScript("OnShow", function()
		bar.holderHidden = nil
		bar:RefreshSlab()
	end)
	holder:HookScript("OnHide", function()
		bar.holderHidden = true
		bar:RefreshSlab()
	end)
	header:HookScript("OnShow", function()
		bar.headerHidden = nil
		bar:RefreshSlab()
	end)
	header:HookScript("OnHide", function()
		bar.headerHidden = true
		bar:RefreshSlab()
	end)
	local backing = CreateFrame("Frame", nil, header)
	backing:SetFrameLevel(header:GetFrameLevel())
	backing.chrome = Widgets.Chrome(backing, { shape = "tile", fill = "buttonFill", shadow = false })
	bar.backing = backing
	if def.kind == "action" then
		header:SetAttribute("actionpage", def.page)
		header:SetAttribute("_onstate-page", ns.PAGE_SNIPPET)
		header:HookScript("OnAttributeChanged", function(_, name)
			if name == "actionpage" then
				bar:UpdateSlots()
			end
		end)
	end
	bar.setAlpha = function(frame, value)
		frame:SetAlpha(value)
		bar.alpha = value
	end
	bar.checkFade = function()
		bar:CheckFade()
	end
	for i = 1, def.max do
		bar.buttons[i] = ns.Button.New(bar, i)
	end
	bar:Apply()
	local Layout = K.Layout
	if Layout and type(Layout.Register) == "function" then
		local Layouts = K.Setup.Layouts
		Layout.Register(holder, def.element, Layouts.Default(def.element), {
			label = ns.Label(def),
			module = "ActionBars",
			scalable = true,
		})
		bar.registered = true
		bar.groupedWidth = ns.Slab.Grouped(def) and Layouts.ActionBarFootprint(K.Scale.Aspect(), def.element, K.HudStyle.Current()) or nil
		if def.key == "bar3" then bar.finished = Layouts.ThirdBarFinished() end
		if Widgets.ScaleFactor(header) ~= bar.factor then
			bar:Layout()
		end
		bar:UpdateLive()
	else
		ns.LogOnce("noLayout", "KstyleUI.Layout is missing; the action bars stay at their default place")
		Widgets.Place(holder, def.element, K.Setup.Layouts.Default(def.element))
	end
	return bar
end

function Bar:Config()
	return ns.Config(self.def.key)
end

function Bar:UpdateLive()
	local Layout = K.Layout
	if self.registered and Layout and type(Layout.SetLive) == "function" then
		Layout.SetLive(self.def.element, ns.running and self:Config().enabled == true)
	end
end

function Bar:Shown()
	local cfg = self:Config()
	return ns.running and cfg.enabled == true and not ns.gamepad
end

function Bar:Visibility()
	local kind = self.def.kind
	if not self:Shown() or kind == "stance" and ns.Totems.state.shown then
		return "hide"
	end
	local custom = self:Config().visibility
	if custom and custom:match("%S") and (kind ~= "stance" or self.count > 0) then
		return (kind == "pet" and "[@pet,noexists] hide; " or "") .. custom
	end
	if kind == "pet" then
		return PET_DRIVER
	elseif kind == "stance" then
		return self.count > 0 and "show" or "hide"
	end
	return "show"
end

function Bar:Driver()
	local def, cfg = self.def, self:Config()
	if def.kind ~= "action" then
		return nil
	end
	local driver
	if def.paged then
		driver = ns.PagingDriver(cfg, ns.class)
	else
		local custom = ns.PagingDriver({ paging = cfg.paging }, ns.class)
		driver = custom ~= "1" and custom or nil
	end
	if driver then
		local works, reads = DriverWorks(driver)
		if not works then
			ns.LogOnce("badDriver:" .. def.key .. driver, def.key .. ": the paging conditions " .. driver .. " do not work (" .. reads .. "); using the default rules")
			if def.paged then
				local rules = {}
				for key, value in pairs(cfg) do
					rules[key] = value
				end
				rules.paging = ""
				driver = ns.PagingDriver(rules, ns.class)
			else
				driver = nil
			end
		else
			ns.LogOnce("driver:" .. def.key .. driver, def.key .. " pages with " .. driver .. ", which reads " .. reads .. " now")
		end
	end
	return driver
end

local function FormSpell(i)
	if type(GetShapeshiftFormInfo) ~= "function" then
		return nil
	end
	local spell = select(4, GetShapeshiftFormInfo(i))
	if ns.IsSecret(spell) then
		return nil
	end
	return spell
end

function Bar:FormsChanged()
	local cfg = self:Config()
	if self.count ~= min(self.def.max, max(1, floor(cfg.buttons or self.def.max)), NumForms()) then
		return true
	end
	for i = 1, self.count do
		if self.buttons[i]:GetAttribute("spell") ~= FormSpell(i) then
			return true
		end
	end
	return false
end

local CUMULATIVE = { bar1 = true, bar2 = true, bar3 = true, bar4 = true, bar5 = true, bar6 = true }

function Bar:Layout()
	local def, cfg = self.def, self:Config()
	local header = self.header
	local grouped = ns.Slab.Grouped(def)
	if cfg.clickThrough then ns.Flyout.Close() end
	local orientation, growth = grouped and "HORIZONTAL" or cfg.orientation, grouped and "RIGHTDOWN" or cfg.growth
	self.factor = Widgets.ScaleFactor(header)
	local count = min(def.max, max(1, floor(cfg.buttons or def.max)))
	if def.kind == "stance" then
		count = min(count, NumForms())
	end
	self.count = count
	local _, rows, cell, spacing = K.Setup.Layouts.ActionBarGrid(K.Scale.Aspect(), def.element, cfg, K.HudStyle.Current())
	local wide, wideGap = cell, spacing
	cell, spacing = ns.Tray.Grid(def, cell, spacing)
	local size, gap = Widgets.Snap(header, cell), Widgets.Snap(header, spacing)
	local width, height = ns.GridSize(count, rows, size, gap)
	local pitch, drop = size + gap, 0
	if CUMULATIVE[def.key] and (def.key ~= "bar3" or cfg.finished) then
		local _, _, columns, used = ns.GridSize(count, rows, cell, spacing)
		pitch = cell + spacing
		width = Widgets.Snap(header, (columns - 1) * pitch) + size
		height = Widgets.Snap(header, (used - 1) * pitch) + size
		if cell ~= wide then
			local tall = Widgets.Snap(header, (used - 1) * (wide + wideGap)) + Widgets.Snap(header, wide)
			drop, height = def.key == "bar2" and tall - height or 0, tall
		end
	end
	local cols, used
	if def.kind == "stance" and (rows or 1) > 1 then
		local _, _, full = ns.GridSize(min(def.max, max(1, floor(cfg.buttons or def.max))), rows, 1, 0)
		cols, used = full, max(1, ceil(count / full))
		width, height = cols * size + (cols - 1) * gap, used * size + (used - 1) * gap
	end
	local split = not grouped and cfg.split == "on" and K.Setup.Layouts.SPLIT_GAP or 0
	local half = math.huge
	if split > 0 and def.kind == "action" then
		local _, _, columns = ns.GridSize(count, rows, 1, 0)
		if columns > 1 then
			half = ceil(columns / 2)
			split = Widgets.Snap(header, split)
			width = width + split
		end
	end
	self.holder:SetSize(width, height)
	local spare = cols and count > 0 and (cols - (orientation == "VERTICAL" and ceil(count / used) or min(cols, count))) * pitch or 0
	self.insetLeft = (growth == "LEFTUP" or growth == "LEFTDOWN") and spare or 0
	self.insetRight = spare - self.insetLeft
	local margin = Widgets.Snap(header, BACKING_MARGIN)
	self.backing:ClearAllPoints()
	self.backing:SetPoint("TOPLEFT", header, "TOPLEFT", self.insetLeft - margin, margin)
	self.backing:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", margin - self.insetRight, -margin)
	self.backing:SetShown(not grouped and cfg.backing == true)
	for i, b in ipairs(self.buttons) do
		b.opts.size = cell
		b:EnableMouse(cfg.clickThrough ~= true)
		if i <= count then
			local position = cfg.reverse and not grouped and count + 1 - i or i
			local col, row
			if cols then
				if orientation == "VERTICAL" then
					row, col = (position - 1) % used, floor((position - 1) / used)
				else
					col, row = (position - 1) % cols, floor((position - 1) / cols)
				end
				if growth == "LEFTDOWN" or growth == "LEFTUP" then
					col = cols - 1 - col
				end
				if growth == "RIGHTUP" or growth == "LEFTUP" then
					row = used - 1 - row
				end
			else
				col, row = ns.Cell(position, count, rows, orientation, growth)
			end
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", header, "TOPLEFT", Widgets.Snap(header, col * pitch) + (col >= half and split or 0), -Widgets.Snap(header, row * pitch) - drop)
			b:Restyle()
			b:Show()
		else
			b:Hide()
		end
		if def.kind == "stance" then
			local spell = FormSpell(i)
			local delegate = StanceBar and StanceBar.actionButtons and StanceBar.actionButtons[i]
			b:SetAttribute("type", delegate and "click" or nil)
			b:SetAttribute("clickbutton", delegate)
			b:SetAttribute("spell", spell)
		end
		b:SetAttribute("safeDragging", ns.Config("safeDragging") == true)
	end
end

function Bar:Register()
	self.holder:SetScale(1)
	K.Layout.Register(self.holder, self.def.element, K.Setup.Layouts.Default(self.def.element), { label = ns.Label(self.def), module = "ActionBars", scalable = true })
end

function Bar:Apply(geometryOnly)
	if InCombatLockdown() and not ns.enabling then
		ns.QueueApply()
		return
	end
	if self.def.key == "bar3" and self.registered and self.finished ~= K.Setup.Layouts.ThirdBarFinished() then
		self.finished = K.Setup.Layouts.ThirdBarFinished()
		self:Register()
	end
	self:Layout()
	local groupedWidth = ns.Slab.Grouped(self.def) and K.Setup.Layouts.ActionBarFootprint(K.Scale.Aspect(), self.def.element, K.HudStyle.Current()) or nil
	if self.registered and self.groupedWidth ~= groupedWidth then
		self:Register()
		local strip = K.Layout.Element("databars.xp")
		if strip then K.Layout.Register(strip.frame, strip.key, K.Setup.Layouts.Default(strip.key), strip.opts) end
	end
	self.groupedWidth = groupedWidth
	self:UpdateLive()
	local header, def = self.header, self.def
	if not geometryOnly then
		if type(RegisterStateDriver) == "function" then
			RegisterStateDriver(header, "visibility", self:Visibility())
			if def.kind == "action" then
				local driver = self:Shown() and self:Driver() or nil
				if driver then
					RegisterStateDriver(header, "page", driver)
				else
					if type(UnregisterStateDriver) == "function" then
						UnregisterStateDriver(header, "page")
					end
					header:SetAttribute("actionpage", def.page)
				end
			end
		else
			ns.LogOnce("noDriver", "RegisterStateDriver is missing; bars show without paging")
			header:SetShown(self:Shown())
		end
	end
	if self.registered and type(K.Layout.Restore) == "function" then
		K.Layout.Restore(def.element)
	end
	if def.kind == "action" then
		local settings = self.registered and K.Layout.Get(def.element)
		local direction = settings and FLYOUT_DIRECTIONS[settings.anchor] or "UP"
		header:SetAttribute("flyoutDirection", direction)
		for _, b in ipairs(self.buttons) do
			ns.Button.PlaceArrow(b, direction)
		end
	end
	if geometryOnly then
		for _, button in ipairs(self.buttons) do ns.Button.StyleTexts(button) end
		self:RefreshSlab(true)
	else
		self:UpdateSlots()
		self:Refresh()
	end
end

function Bar:UpdateSlots()
	if self.def.kind ~= "action" then
		return
	end
	local page = self.header:GetAttribute("actionpage")
	if ns.IsSecret(page) or type(page) ~= "number" then
		page = tonumber(page) or self.def.page
	end
	for i, b in ipairs(self.buttons) do
		ns.Button.SetSlot(b, ns.Slot(i, page))
	end
end

function Bar:Update()
	for _, b in ipairs(self.buttons) do
		ns.Button.Update(b)
	end
end

local function Steady(bar)
	local Layout = K.Layout
	local el = bar.registered and Layout and type(Layout.Element) == "function" and Layout.Element(bar.def.element)
	local s = el and el.settings
	if not s then
		return true, 1, 1
	end
	return s.shown ~= "mouseover", s.alphaCombat, s.alphaIdle
end

function Bar:RefreshSlab(force)
	local bars = ns.bars
	if not bars or ns.slabHeld then
		return
	end
	local main = self.def.key == "bar1" and self or bars.bar1
	local second = self.def.key == "bar2" and self or bars.bar2
	if not (main and second) then
		return
	end
	if ns.Tray.card or K.HudStyle.Current() == "frames" then
		local mainSteady, mainCombat, mainIdle = Steady(main)
		local secondSteady, secondCombat, secondIdle = Steady(second)
		ns.Tray.Refresh(main, second, mainSteady and secondSteady and mainCombat == secondCombat and mainIdle == secondIdle, force)
	end
	ns.Slab.Refresh()
end

function Bar:Refresh()
	self:RefreshSlab(true)
	for _, b in ipairs(self.buttons) do
		ns.Button.StyleTexts(b)
		ns.Button.Update(b)
		ns.Button.ApplyTint(b, true)
	end
	self:RefreshFade()
end

function Bar:RestAlpha()
	local cfg = self:Config()
	if not cfg.fade or ns.grid > 0 or ns.layout or self.hovered > 0 then
		return 1
	end
	local alpha = cfg.fadeAlpha
	if ns.IsSecret(alpha) or type(alpha) ~= "number" then
		return 0
	end
	return max(0, min(1, alpha))
end

function Bar:FadeTo(alpha)
	if self.target == alpha then
		return
	end
	self.target = alpha
	K.Motion.Tween(self.header, self.setAlpha, self.alpha, alpha, Tokens.Duration("fade"), Tokens.Easing("fade"))
end

function Bar:RefreshFade()
	self:FadeTo(self:RestAlpha())
end

function Bar:CheckFade()
	if self.hovered == 0 then
		self:RefreshFade()
	end
end

function Bar:SetHovered(on)
	if on then
		self.hovered = self.hovered + 1
		self:RefreshFade()
	else
		self.hovered = max(0, self.hovered - 1)
		if self.hovered == 0 and self.target ~= self:RestAlpha() then
			if C_Timer and C_Timer.After then
				C_Timer.After(FADE_DELAY, self.checkFade)
			else
				self:RefreshFade()
			end
		end
	end
end

function Bar:Release()
	for _, b in ipairs(self.buttons) do
		ns.Button.Release(b)
	end
end
