-- Drawer.lua: the addon-button drawer: LibDBIcon buttons collected into a glass flyout beside the button column, and the addon compartment's list.
local _, ns = ...

local K = KstyleUI
local L, Tokens, Widgets, Motion = K.L, K.Tokens, K.Widgets, K.Motion
local Settings, Format, Data = ns.Settings, ns.Format, ns.Data

local Drawer = {}
Drawer.__index = Drawer
ns.Drawer = Drawer

local LIB = "LibDBIcon-1.0"
local CREATED = "LibDBIcon_IconCreated"
local PAD = Tokens.Size("gapSmall")
local GAP = Tokens.Size("gapSmall")
local LEVEL_BUTTON = 2
local ICON_FILL = 0.72
local HOVER_GRACE = 0.5
local DRAG_BUTTON = "LeftButton"
local OWN_BUTTONS = {
	"BlackthornesMinimapButton",
	"BlackthornesButlerMinimapButton",
	"BlackthornesEquipmentMinimapButton",
	"BlackthornesFarmerMinimapButton",
	"BlackthornesPathfinderMinimapButton",
	"BlackthornesPetsMinimapButton",
	"BlackthornesTSMinimapButton",
	"OxgleBugsMinimapButton",
}

local hooked = setmetatable({}, { __mode = "k" })
local Watch, OnIconCreated

local function Log(message)
	K.DevTest.Log("Minimap", message)
end

function Drawer.Lib()
	local stub = rawget(_G, "LibStub")
	if stub == nil then
		return nil
	end
	local ok, lib = pcall(stub, LIB, true)
	if ok and type(lib) == "table" then
		return lib
	end
	return nil
end

local function Names(lib)
	local names = {}
	if type(lib.GetButtonList) == "function" then
		local ok, list = pcall(lib.GetButtonList, lib)
		if ok and type(list) == "table" then
			for _, name in ipairs(list) do
				names[#names + 1] = name
			end
		end
	elseif type(lib.objects) == "table" then
		for name in pairs(lib.objects) do
			names[#names + 1] = name
		end
	end
	return names
end

local function ButtonFor(lib, name)
	if type(lib.GetMinimapButton) == "function" then
		local ok, button = pcall(lib.GetMinimapButton, lib, name)
		if ok and type(button) == "table" then
			return button
		end
	end
	return type(lib.objects) == "table" and lib.objects[name] or nil
end

local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

local function Points(button)
	local points = {}
	for i = 1, button:GetNumPoints() do
		local point, relativeTo, relativePoint, x, y = button:GetPoint(i)
		if not point or IsSecret(x) or IsSecret(y) or type(x) ~= "number" or type(y) ~= "number" then
			return {}
		end
		points[i] = { point, relativeTo, relativePoint, x, y }
	end
	return points
end

local function IconPoints(icon, button)
	local points = {}
	for i = 1, icon:GetNumPoints() do
		local point, relativeTo, relativePoint, x, y = icon:GetPoint(i)
		if not point or IsSecret(x) or IsSecret(y) then
			return {}
		end
		points[i] = { point, relativeTo or button, relativePoint or point, x or 0, y or 0 }
	end
	return points
end

local function IconOf(button)
	if type(button.icon) == "table" then
		return button.icon
	end
	for _, region in ipairs({ button:GetRegions() }) do
		if region:GetObjectType() == "Texture" and region:GetDrawLayer() == "ARTWORK" then
			return region
		end
	end
	return nil
end

local function SortKey(text)
	local util = C_StringUtil
	if util and type(util.StripHyperlinks) == "function" then
		local ok, plain = pcall(util.StripHyperlinks, text)
		if ok and type(plain) == "string" then
			text = plain
		end
	end
	return text:lower()
end

function Drawer.CompartmentEntries()
	local out = {}
	local frame = AddonCompartmentFrame
	local list = frame and frame.registeredAddons
	if type(list) ~= "table" then
		return out
	end
	for _, data in ipairs(list) do
		if type(data) == "table" and Data.IsText(data.text) and type(data.func) == "function" then
			out[#out + 1] = data
		end
	end
	table.sort(out, function(a, b)
		return SortKey(a.text) < SortKey(b.text)
	end)
	return out
end

local function TakeAnyClick(button)
	if type(button.RegisterForClicks) == "function" then
		button:RegisterForClicks("AnyUp")
	end
end

local function CompartmentMenu(_, root)
	if type(root.SetTag) == "function" then
		root:SetTag("KSTYLEUI_COMPARTMENT")
	end
	root:CreateTitle(L["Addons"])
	for _, data in ipairs(Drawer.CompartmentEntries()) do
		local entry = root:CreateButton(data.text, data.func)
		if entry and type(entry.AddInitializer) == "function" then
			entry:AddInitializer(TakeAnyClick)
		end
		if entry then
			if data.funcOnEnter and type(entry.SetOnEnter) == "function" then
				entry:SetOnEnter(data.funcOnEnter)
			end
			if data.funcOnLeave and type(entry.SetOnLeave) == "function" then
				entry:SetOnLeave(data.funcOnLeave)
			end
		end
	end
end

function Drawer.OpenCompartment(owner)
	local menu = MenuUtil
	if not (menu and type(menu.CreateContextMenu) == "function") then
		Log("MenuUtil.CreateContextMenu is missing; the addon compartment list cannot open")
		return
	end
	local open = menu.CreateContextMenu(owner, CompartmentMenu)
	if ns.Map and ns.Map.SetMenu then
		ns.Map.SetMenu(open)
	end
end

function Drawer.New(column, opts)
	opts = opts or {}
	local drawer = setmetatable({
		column = column,
		holder = column.holder,
		preview = opts.preview == true,
		adopted = {},
		order = {},
		active = false,
		open = false,
		graceLeft = 0,
	}, Drawer)
	local panel = CreateFrame("Frame", nil, column.holder)
	panel:SetFrameStrata("MEDIUM")
	panel:EnableMouse(true)
	panel:Hide()
	drawer.chrome = Widgets.Chrome(panel, { shape = "panel", popup = true })
	drawer.panel = panel
	return drawer
end

function Drawer:Toggle()
	if self.open then
		self:Close()
	else
		self:Open()
	end
end

function Drawer:Count()
	local count = 0
	for _, button in ipairs(self.order) do
		if button:IsShown() == true then
			count = count + 1
		end
	end
	return count
end

function Drawer:HasContent()
	if self.preview then
		return true
	end
	if self:Count() > 0 then
		return true
	end
	return Settings.Get("drawer.compartment") and #Drawer.CompartmentEntries() > 0
end

local function Toggle(column)
	return column.buttons.drawer
end

function Drawer:Place(button)
	local state = self.adopted[button]
	if not state or not state.slot then
		return
	end
	local size = Widgets.Snap(self.panel, Settings.Get("drawer.size"))
	local spacing = Widgets.Snap(self.panel, Settings.Get("drawer.spacing"))
	local direction = Format.Direction(Settings.Get("drawer.direction"), Settings.Get("column.side"))
	local point, x, y = Format.Grid(state.slot, Settings.Get("drawer.columns"), size, spacing, direction, Widgets.Snap(self.panel, PAD))
	self.placing = true
	button:ClearAllPoints()
	button:SetPoint(point, self.panel, point, x, y)
	button:SetSize(size, size)
	local icon = state.icon
	if type(icon) == "table" and type(icon.SetPoint) == "function" then
		icon:ClearAllPoints()
		icon:SetPoint("CENTER", button, "CENTER")
		Widgets.Size(icon, size * ICON_FILL, size * ICON_FILL)
	end
	self.placing = false
end

function Drawer:Layout()
	local panel = self.panel
	local toggle = Toggle(self.column)
	local direction = Format.Direction(Settings.Get("drawer.direction"), Settings.Get("column.side"))
	local slot = 0
	for _, button in ipairs(self.order) do
		local state = self.adopted[button]
		if button:IsShown() == true then
			slot = slot + 1
			state.slot = slot
		else
			state.slot = nil
		end
	end
	local size = Widgets.Snap(panel, Settings.Get("drawer.size"))
	local spacing = Widgets.Snap(panel, Settings.Get("drawer.spacing"))
	local width, height = Format.GridSize(slot, Settings.Get("drawer.columns"), size, spacing, Widgets.Snap(panel, PAD))
	Widgets.Size(panel, math.max(width, Widgets.Border(panel)), math.max(height, Widgets.Border(panel)))
	local point, relative, xs, ys = Format.DrawerAnchor(direction)
	local gap = Widgets.Snap(panel, GAP)
	panel:ClearAllPoints()
	panel:SetPoint(point, toggle, relative, xs * gap, ys * gap)
	for _, button in ipairs(self.order) do
		self:Place(button)
	end
	if slot == 0 and self.open then
		self:Close()
	end
end

local function OnMoved(button)
	local drawer = ns.Map and ns.Map.drawer
	local state = drawer and drawer.active and not drawer.placing and drawer.adopted[button]
	if not state then
		return
	end
	if state.points then
		local asked = Points(button)
		if #asked > 0 then
			state.points = asked
		end
	end
	drawer:Place(button)
end

local function KeepOpaque(button, alpha)
	local drawer = ns.Map and ns.Map.drawer
	if drawer and drawer.active and drawer.adopted[button] and alpha ~= 1 then
		button:SetAlpha(1)
	end
end

local function OnShownChanged(button)
	local drawer = ns.Map and ns.Map.drawer
	if drawer and drawer.active and drawer.adopted[button] then
		drawer:Layout()
		drawer.column:Refresh()
	end
end

local function OnAddonClick()
	local drawer = ns.Map and ns.Map.drawer
	if drawer and drawer.active and drawer.open and Settings.Get("drawer.autoClose") then
		drawer:Close()
	end
end

function Drawer:Adopt(name, button, own)
	if self.adopted[button] then
		return false
	end
	if InCombatLockdown() and button:IsProtected() ~= false then
		return false
	end
	local panel = self.panel
	local state = { name = name, parent = button:GetParent(), icon = IconOf(button) }
	if own then
		state.points = Points(button)
		state.width, state.height = button:GetSize()
		if state.icon then
			state.iconPoints = IconPoints(state.icon, button)
			state.iconWidth, state.iconHeight = state.icon:GetSize()
		end
	end
	self.adopted[button] = state
	self.order[#self.order + 1] = button
	table.sort(self.order, function(a, b)
		return self.adopted[a].name < self.adopted[b].name
	end)
	button:SetParent(panel)
	if type(button.RegisterForDrag) == "function" then
		button:RegisterForDrag()
	end
	if type(button.SetFixedFrameStrata) == "function" then
		button:SetFixedFrameStrata(false)
	end
	if type(button.SetFixedFrameLevel) == "function" then
		button:SetFixedFrameLevel(false)
	end
	button:SetFrameStrata(panel:GetFrameStrata())
	button:SetFrameLevel(panel:GetFrameLevel() + LEVEL_BUTTON)
	button:SetAlpha(1)
	if not hooked[button] then
		hooked[button] = true
		local keep = {}
		if state.icon then
			keep[state.icon] = true
		end
		K.Skin.Strip(button, { keep = keep })
		K.Skin.Backdrop(button, { shape = "tile", fill = "buttonFill" })
		hooksecurefunc(button, "SetPoint", OnMoved)
		hooksecurefunc(button, "SetAlpha", KeepOpaque)
		local fade = button.fadeOut
		if type(fade) == "table" and type(fade.Play) == "function" and type(fade.Stop) == "function" then
			hooksecurefunc(fade, "Play", function(group)
				local drawer = ns.Map and ns.Map.drawer
				if drawer and drawer.active and drawer.adopted[button] then
					group:Stop()
					button:SetAlpha(1)
				end
			end)
		end
		hooksecurefunc(button, "Show", OnShownChanged)
		hooksecurefunc(button, "Hide", OnShownChanged)
		button:HookScript("OnClick", OnAddonClick)
	end
	Log("collected the minimap button " .. tostring(name) .. " into the drawer")
	return true
end

function Drawer:Subscribe(lib)
	if not self.listening and type(lib.RegisterCallback) == "function" then
		self.listening = pcall(lib.RegisterCallback, Drawer, CREATED, OnIconCreated)
	end
end

function Drawer:Collect()
	if self.preview or not self.active then
		return
	end
	local added = false
	local lib = Drawer.Lib()
	if lib then
		self:Subscribe(lib)
		for _, name in ipairs(Names(lib)) do
			local button = ButtonFor(lib, name)
			if button and self:Adopt(name, button) then
				added = true
			end
		end
	end
	for _, name in ipairs(OWN_BUTTONS) do
		local button = rawget(_G, name)
		if type(button) == "table" and type(button.GetParent) == "function" and button:GetParent() == Minimap and self:Adopt(name, button, true) then
			added = true
		end
	end
	if added then
		self:Layout()
	end
	return added
end

function OnIconCreated(_, button, name)
	local drawer = ns.Map and ns.Map.drawer
	if drawer and drawer.active and type(button) == "table" and type(name) == "string" and drawer:Adopt(name, button) then
		drawer:Layout()
		drawer.column:Refresh()
	end
end

function Drawer:Start()
	self.active = true
	self:Collect()
	self:Layout()
	if Settings.Get("drawer.behaviour") == "open" then
		self:Open()
	end
end

function Drawer:Stop()
	self:Close(true)
	self.active = false
	local lib = Drawer.Lib()
	if self.listening and lib and type(lib.UnregisterCallback) == "function" then
		pcall(lib.UnregisterCallback, Drawer, CREATED)
	end
	self.listening = false
	for _, button in ipairs(self.order) do
		local state = self.adopted[button]
		button:ClearAllPoints()
		button:SetParent(state.parent)
		if type(button.RegisterForDrag) == "function" then
			button:RegisterForDrag(DRAG_BUTTON)
		end
		if state.points then
			local width, height = state.width, state.height
			if type(width) == "number" and type(height) == "number" and not IsSecret(width) and not IsSecret(height) then
				button:SetSize(width, height)
			end
			for _, point in ipairs(state.points) do
				button:SetPoint(point[1], point[2], point[3], point[4], point[5])
			end
			local icon, iconWidth, iconHeight = state.icon, state.iconWidth, state.iconHeight
			if icon and state.iconPoints and #state.iconPoints > 0 then
				icon:ClearAllPoints()
				if type(iconWidth) == "number" and type(iconHeight) == "number" and not IsSecret(iconWidth) and not IsSecret(iconHeight) then
					icon:SetSize(iconWidth, iconHeight)
				end
				for _, point in ipairs(state.iconPoints) do
					icon:SetPoint(point[1], point[2], point[3], point[4], point[5])
				end
			end
		elseif lib and type(lib.Refresh) == "function" then
			pcall(lib.Refresh, lib, state.name)
		end
	end
	self.adopted, self.order = {}, {}
end

function Watch(panel, elapsed)
	local drawer = ns.Map and ns.Map.drawer
	if not drawer then
		panel:SetScript("OnUpdate", nil)
		return
	end
	local toggle = Toggle(drawer.column)
	if panel:IsMouseOver() or toggle:IsMouseOver() then
		drawer.graceLeft = HOVER_GRACE
		return
	end
	drawer.graceLeft = drawer.graceLeft - elapsed
	if drawer.graceLeft <= 0 then
		drawer:Close()
	end
end

function Drawer:Open()
	if self.open or not self:HasContent() then
		return
	end
	self:Collect()
	self:Layout()
	if self:Count() == 0 then
		return
	end
	self.open = true
	for _, button in ipairs(self.order) do
		local fade = button.fadeOut
		if type(fade) == "table" and type(fade.Stop) == "function" then
			fade:Stop()
		end
		button:SetAlpha(1)
	end
	Motion.FadeIn(self.panel, Tokens.Duration("fade"))
	if Settings.Get("drawer.behaviour") == "hover" then
		self.graceLeft = HOVER_GRACE
		self.panel:SetScript("OnUpdate", Watch)
	end
end

function Drawer:Close(instant)
	self.panel:SetScript("OnUpdate", nil)
	if not self.open then
		return
	end
	self.open = false
	if instant then
		self.panel:Hide()
	else
		Motion.FadeOut(self.panel, Tokens.Duration("fade"))
	end
	if ns.Map and ns.Map.CheckHover then
		ns.Map.CheckHover()
	end
end

function Drawer:OnToggleEnter()
	if self.active and Settings.Get("drawer.behaviour") == "hover" then
		self:Open()
	end
end

function Drawer:OnToggleClick(mouseButton)
	if not self.active then
		return
	end
	local compartment = Settings.Get("drawer.compartment") and #Drawer.CompartmentEntries() > 0
	if compartment and (mouseButton == "RightButton" or self:Count() == 0) then
		Drawer.OpenCompartment(Toggle(self.column))
		return
	end
	self:Toggle()
end

function Drawer:Sync(running)
	local wanted = running and Settings.Get("column.drawer")
	if wanted and not self.active then
		self:Start()
	elseif not wanted and self.active then
		self:Stop()
	end
	self:Refresh()
end

function Drawer:Refresh()
	if not self.active then
		return
	end
	self:Layout()
	self:Paint()
	local behaviour = Settings.Get("drawer.behaviour")
	if behaviour ~= "hover" then
		self.panel:SetScript("OnUpdate", nil)
	end
	if behaviour == "open" then
		self:Open()
	elseif self.open and behaviour == "hover" and not self.panel:GetScript("OnUpdate") then
		self.graceLeft = HOVER_GRACE
		self.panel:SetScript("OnUpdate", Watch)
	end
end

function Drawer:Reposition()
	local lib = Drawer.Lib()
	if not lib or type(lib.Refresh) ~= "function" then
		return
	end
	for _, name in ipairs(Names(lib)) do
		local button = ButtonFor(lib, name)
		if button and not self.adopted[button] then
			pcall(lib.Refresh, lib, name)
		end
	end
end

function Drawer:Paint()
	local r, g, b = ns.Style.Accent()
	self.chrome:SetEdgeRGBA(r, g, b, 1)
end
