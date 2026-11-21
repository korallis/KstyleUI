-- Drawer.lua: the addon-button drawer: LibDBIcon buttons and any other addon's named button on the minimap collected into a glass flyout beside the button column, and the addon compartment's list.
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
local OWN_PREFIX = "^KstyleUI"

local hooked = setmetatable({}, { __mode = "k" })
local crystals = setmetatable({}, { __mode = "k" })
local Watch, OnIconCreated
local waiting = false

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

function Drawer.Label(name)
	return (tostring(name):gsub("^LibDBIcon10_", ""))
end

function Drawer.Shown(frame)
	local shown = frame:IsShown()
	return not IsSecret(shown) and shown == true
end

local function Reseat()
	waiting = false
	local drawer = ns.Map and ns.Map.drawer
	if drawer and drawer.active then
		drawer:Layout()
		drawer.column:Refresh()
	end
end

local function Movable(button)
	if Widgets.MayMove(button) then
		return true
	end
	if not waiting then
		waiting = true
		K.Combat.Queue(Reseat)
	end
	return false
end

local function Seat(button, parent)
	if button:GetParent() ~= parent then
		button:SetParent(parent)
		button:SetFrameStrata(parent:GetFrameStrata())
		button:SetFrameLevel(parent:GetFrameLevel() + LEVEL_BUTTON)
	end
end

local function Present(button, state)
	local column = state.place == "column"
	if state.tile then
		state.tile:SetShown(not column)
	end
	if column and not crystals[button] then
		crystals[button] = Widgets.CrystalDisc(button)
	end
	if crystals[button] then
		crystals[button]:SetShown(column and Settings.Get("column.backgrounds"))
	end
end

local function Usable(data)
	return type(data) == "table" and Data.IsText(data.text) and type(data.func) == "function"
end

function Drawer.CompartmentCount()
	local frame, count = AddonCompartmentFrame, 0
	local list = frame and frame.registeredAddons
	for i = 1, type(list) == "table" and #list or 0 do
		if Usable(list[i]) then
			count = count + 1
		end
	end
	return count
end

function Drawer.CompartmentEntries()
	local out = {}
	local frame = AddonCompartmentFrame
	local list = frame and frame.registeredAddons
	if type(list) ~= "table" then
		return out
	end
	for _, data in ipairs(list) do
		if Usable(data) then
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
		labels = {},
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
	drawer.attic = CreateFrame("Frame", nil, column.holder)
	drawer.attic:Hide()
	return drawer
end

function Drawer:Toggle()
	if self.open then
		self:Close()
	else
		self:Open()
	end
end

function Drawer:PlaceOf(button)
	local place = Settings.Get("column.drawer") and Settings.Get("drawer.places")[self.adopted[button].name]
	return (place == "column" or place == "hidden") and place or "drawer"
end

function Drawer:Count()
	local count = 0
	for _, button in ipairs(self.order) do
		if Drawer.Shown(button) and self:PlaceOf(button) == "drawer" then
			count = count + 1
		end
	end
	return count
end

function Drawer:PutInColumn(button, home, point, area, x, y, size)
	if Movable(button) then
		Seat(button, home)
		self.adopted[button].spot = { point, area, x, y, size }
		self:Place(button)
	end
end

function Drawer:HasContent()
	if self.preview then
		return true
	end
	if self:Count() > 0 then
		return true
	end
	return Settings.Get("drawer.compartment") and Drawer.CompartmentCount() > 0
end

local function Toggle(column)
	return column.buttons.drawer
end

function Drawer:Size()
	local minimum = 31
	for _, state in pairs(self.adopted) do
		minimum = math.max(minimum, state.nativeSize or 0)
	end
	return Settings.IconSize(self.panel, "drawer.size", minimum)
end

function Drawer:Place(button)
	local state = self.adopted[button]
	local point, relative, x, y, size
	if not (state and Movable(button)) then
		return
	elseif state.place == "column" and state.spot then
		point, relative, x, y, size = unpack(state.spot)
	elseif state.place == "drawer" and state.slot then
		size, relative = self:Size(), self.panel
		local spacing = Widgets.Snap(self.panel, Settings.Get("drawer.spacing"))
		local pad, index = Widgets.Snap(self.panel, PAD), state.slot - 1
		if self.rows then
			point, x, y = "TOPLEFT", pad + math.floor(index / self.rows) * self.cell, -(pad + index % self.rows * (size + spacing))
		else
			point, x, y = Format.Grid(state.slot, self.columns or Settings.Get("drawer.columns"), size, spacing, Format.Direction(Settings.Get("drawer.direction"), Settings.Get("column.side")), pad)
		end
	else
		return
	end
	local compact = Settings.Get("compactIcons")
	local scale = compact and 1 or button:GetScale()
	if not Format.IsNumber(scale) or scale <= 0 then return end
	self.placing = true
	button:ClearAllPoints()
	button:SetPoint(point, relative, point, x / scale, y / scale)
	button:SetSize(size / scale, size / scale)
	local icon = state.icon
	if type(icon) == "table" and type(icon.SetPoint) == "function" then
		icon:ClearAllPoints()
		icon:SetPoint("CENTER", button, "CENTER")
		local fill = state.place == "column" and ns.Column.GLYPH_SHARE or ICON_FILL
		Widgets.Size(icon, size * fill / scale, size * fill / scale)
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
		if Movable(button) then
			state.place = self:PlaceOf(button)
			if state.place ~= "column" then
				Seat(button, state.place == "hidden" and self.attic or panel)
			end
			Present(button, state)
		end
		if Drawer.Shown(button) and state.place == "drawer" then
			slot = slot + 1
			state.slot = slot
		else
			state.slot = nil
		end
	end
	local size = self:Size()
	local spacing = Widgets.Snap(panel, Settings.Get("drawer.spacing"))
	local pad = Widgets.Snap(panel, PAD)
	local columns = Settings.Get("drawer.columns")
	local area = self.column.face.mapArea
	local reserve = toggle:GetWidth() + Widgets.Snap(panel, Format.EDGE + GAP)
	if not Settings.Get("compactIcons") then
		columns = math.max(1, math.min(columns, math.floor((area:GetWidth() - reserve - 2 * pad + spacing) / (size + spacing))))
	end
	local list = Settings.Get("drawer.list")
	self.columns, self.rows = list and 1 or columns, nil
	local width, height = Format.GridSize(slot, self.columns, size, spacing, pad)
	local gap = Widgets.Snap(panel, GAP)
	local labelWidth = 0
	for _, button in ipairs((list or self.listed) and self.order or {}) do
		local state, label = self.adopted[button], self.labels[button]
		if list and state.slot and not label then
			label = Widgets.FontString(panel, "OVERLAY")
			label:SetWordWrap(false)
			label:SetJustifyH("LEFT")
			self.labels[button] = label
		end
		if label then
			label:SetShown(list and state.slot ~= nil)
			if list and state.slot then
				Widgets.StyleText(label, "body")
				Widgets.TextColor(label, "text")
				label:SetText(Drawer.Label(state.name))
				label:ClearAllPoints()
				label:SetPoint("LEFT", button, "RIGHT", gap, 0)
				local w = label:GetStringWidth()
				labelWidth = math.max(labelWidth, Format.IsNumber(w) and w or 0)
			end
		end
	end
	self.listed = list
	Widgets.Size(panel, math.max(width, Widgets.Border(panel)), math.max(height, Widgets.Border(panel)))
	local point, relative, xs, ys = Format.DrawerAnchor(direction)
	panel:ClearAllPoints()
	if Settings.Get("compactIcons") then
		panel:SetPoint(point, toggle, relative, xs * gap, ys * gap)
	else
		local left = Settings.Get("column.side") == "left"
		local x = point:find("RIGHT") and not left and -reserve or point:find("LEFT") and left and reserve or 0
		local y = point:find("TOP") and -Widgets.Snap(panel, Format.NORTH) or 0
		panel:SetPoint(point, area, point, x, y)
	end
	if list and slot > 0 then
		local _, _, top, bottom = Widgets.Edges(panel)
		local screen = UIParent:GetHeight() * UIParent:GetEffectiveScale() / panel:GetEffectiveScale()
		local room = point:find("TOP") and top or Format.IsNumber(bottom) and screen - bottom
		self.rows = math.min(slot, Format.IsNumber(room) and math.max(1, math.floor((room - 2 * pad + spacing) / (size + spacing))) or slot)
		self.cell = size + gap + labelWidth + spacing
		Widgets.Size(panel, 2 * pad + math.ceil(slot / self.rows) * self.cell - spacing, 2 * pad + self.rows * (size + spacing) - spacing)
	end
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
	local state = drawer and drawer.active and drawer.adopted[button]
	local shown = Drawer.Shown(button)
	if state and state.shown ~= shown then
		state.shown = shown
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
	if not Widgets.MayMove(button) then
		return false
	end
	local panel = self.panel
	local state = { name = name, parent = button:GetParent(), icon = IconOf(button) }
	state.width, state.height = button:GetSize()
	if not IsSecret(state.width) and not IsSecret(state.height) and type(state.width) == "number" and type(state.height) == "number" then
		local reference = math.min(Widgets.ScaleFactor(UIParent), Widgets.ScaleFactor(button:GetParent()))
		state.nativeSize = math.max(state.width, state.height) * Widgets.ScaleFactor(button) / reference
	end
	if state.icon then
		state.iconPoints = IconPoints(state.icon, button)
		state.iconWidth, state.iconHeight = state.icon:GetSize()
	end
	if own then
		state.points = Points(button)
	end
	self.adopted[button] = state
	self.order[#self.order + 1] = button
	table.sort(self.order, function(a, b)
		return self.adopted[a].name < self.adopted[b].name
	end)
	if type(button.RegisterForDrag) == "function" then
		button:RegisterForDrag()
	end
	if type(button.SetFixedFrameStrata) == "function" then
		button:SetFixedFrameStrata(false)
	end
	if type(button.SetFixedFrameLevel) == "function" then
		button:SetFixedFrameLevel(false)
	end
	Seat(button, panel)
	button:SetAlpha(1)
	if not hooked[button] then
		hooked[button] = true
		local keep = {}
		if state.icon then
			keep[state.icon] = true
		end
		K.Skin.Strip(button, { keep = keep })
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
	state.tile = K.Skin.Backdrop(button, { shape = "tile", fill = "buttonFill" })
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
	local minimap = Minimap
	for _, child in ipairs(minimap and { minimap:GetChildren() } or {}) do
		local name = child:GetObjectType() == "Button" and (child:GetScript("OnClick") or child:GetScript("OnMouseUp") or child:GetScript("OnMouseDown")) and child:GetName()
		if type(name) == "string" and not name:find(OWN_PREFIX) and not ns.Pins.Is(child) and self:Adopt(name, child, true) then
			added = true
		end
	end
	if added then
		self:Layout()
		self.column:Layout()
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
		state.place = nil
		Present(button, state)
		button:ClearAllPoints()
		button:SetParent(state.parent)
		if type(button.RegisterForDrag) == "function" then
			button:RegisterForDrag(DRAG_BUTTON)
		end
		local width, height = state.width, state.height
		if type(width) == "number" and type(height) == "number" and not IsSecret(width) and not IsSecret(height) then
			button:SetSize(width, height)
		end
		if state.points then
			for _, point in ipairs(state.points) do
				button:SetPoint(point[1], point[2], point[3], point[4], point[5])
			end
		elseif lib and type(lib.Refresh) == "function" then
			pcall(lib.Refresh, lib, state.name)
		end
		local icon, iconWidth, iconHeight = state.icon, state.iconWidth, state.iconHeight
		if icon and state.iconPoints then
			icon:ClearAllPoints()
			if type(iconWidth) == "number" and type(iconHeight) == "number" and not IsSecret(iconWidth) and not IsSecret(iconHeight) then
				icon:SetSize(iconWidth, iconHeight)
			end
			for _, point in ipairs(state.iconPoints) do
				icon:SetPoint(point[1], point[2], point[3], point[4], point[5])
			end
		end
	end
	for _, label in pairs(self.labels) do
		label:Hide()
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
	local compartment = Settings.Get("drawer.compartment") and Drawer.CompartmentCount() > 0
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
