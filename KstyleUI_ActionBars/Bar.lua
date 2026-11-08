-- Bar.lua: one bar: a Layout holder, a secure state header that pages and shows it, its buttons in a grid, and its mouseover fade.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens
local max, min, floor = math.max, math.min, math.floor

local Bar = {}
Bar.__index = Bar
ns.BarClass = Bar

local FADE_DELAY = 0.2
local BACKING_MARGIN, BACKING_CHAMFER = 4, 6
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
	local header = CreateFrame("Frame", "KstyleUI_" .. def.name, holder, "SecureHandlerStateTemplate")
	header:SetAllPoints(holder)
	bar.holder, bar.header = holder, header
	local backing = CreateFrame("Frame", nil, header)
	backing:SetFrameLevel(header:GetFrameLevel())
	backing.chrome = Widgets.Chrome(backing, { shape = "tile", fill = "surface", shadow = false, chamfer = BACKING_CHAMFER })
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
	if not self:Shown() then
		return "hide"
	end
	local kind = self.def.kind
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

function Bar:Layout()
	local def, cfg = self.def, self:Config()
	local header = self.header
	local count = min(def.max, max(1, floor(cfg.buttons or def.max)))
	if def.kind == "stance" then
		count = min(count, NumForms())
	end
	self.count = count
	local size, gap = Widgets.Snap(header, cfg.size), Widgets.Snap(header, cfg.spacing)
	local width, height = ns.GridSize(count, cfg.rows, size, gap)
	self.holder:SetSize(width, height)
	local margin = Widgets.Snap(header, BACKING_MARGIN)
	self.backing:ClearAllPoints()
	self.backing:SetPoint("TOPLEFT", header, "TOPLEFT", -margin, margin)
	self.backing:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", margin, -margin)
	self.backing:SetShown(cfg.backing == true)
	for i, b in ipairs(self.buttons) do
		b.opts.size = cfg.size
		if i <= count then
			local col, row = ns.Cell(i, count, cfg.rows, cfg.orientation, cfg.growth)
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", header, "TOPLEFT", col * (size + gap), -row * (size + gap))
			b:Restyle()
			b:Show()
		else
			b:Hide()
		end
		if def.kind == "stance" then
			local spell = FormSpell(i)
			b:SetAttribute("type", spell and "spell" or nil)
			b:SetAttribute("spell", spell)
		end
	end
end

function Bar:Apply()
	if InCombatLockdown() and not ns.enabling then
		ns.QueueApply()
		return
	end
	self:Layout()
	self:UpdateLive()
	local header, def = self.header, self.def
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
	self:UpdateSlots()
	self:Refresh()
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

function Bar:Refresh()
	for _, b in ipairs(self.buttons) do
		ns.Button.StyleTexts(b)
		ns.Button.Update(b)
		ns.Button.ApplyTint(b, true)
	end
	self:RefreshFade()
end

function Bar:RestAlpha()
	local cfg = self:Config()
	if not cfg.fade or ns.grid > 0 or self.hovered > 0 then
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
