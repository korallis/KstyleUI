-- Column.lua: the mockup's column of ringed round buttons on a dark plate beside the map, or the design's raised strip inside its right edge: tracking, mail, calendar and the group finder status.
local _, ns = ...

local K = KstyleUI
local L, Tokens, Widgets = K.L, K.Tokens, K.Widgets
local Settings, Style, Data, SecureClick = ns.Settings, ns.Style, ns.Data, ns.SecureClick

local Column = {}
Column.__index = Column
ns.Column = Column

local GLYPHS = "Interface\\AddOns\\KstyleUI_Minimap\\Media\\Glyphs.png"
local GLYPH_COLUMNS, GLYPH_ROWS = 4, 2
local CELLS = { tracking = 0, mail = 1, calendar = 2, queue = 3, drawer = 4 }
local BADGE_SIZE = 6
local BADGE_INSET = 1
local STRIP_GAP = Tokens.Size("gapSmall")
local GAP = Tokens.Size("gapSmall")
local PLATE_INSET = Tokens.Size("gapSmall")
local GLYPH_SHARE = 16 / 30
local RING_ALPHA_SCALE = 2.5
local max = math.max

Column.ORDER = { "tracking", "mail", "calendar", "queue", "drawer" }
Column.GLYPHS, Column.CELLS = GLYPHS, CELLS

local TITLES = {
	tracking = L["Tracking"],
	mail = L["New mail"],
	calendar = L["Calendar"],
	queue = L["Group finder"],
	drawer = L["Addon buttons"],
}

function Column.Cell(name)
	local index = CELLS[name]
	local col, row = index % GLYPH_COLUMNS, math.floor(index / GLYPH_COLUMNS)
	return col / GLYPH_COLUMNS, (col + 1) / GLYPH_COLUMNS, row / GLYPH_ROWS, (row + 1) / GLYPH_ROWS
end

local function Anchor(button)
	if Settings.Get("column.side") == "right" then
		return "ANCHOR_RIGHT"
	end
	return "ANCHOR_LEFT"
end

local TOOLTIPS = {}

function TOOLTIPS.tracking(tip)
	tip:AddLine(L["Click to choose what the map tracks."], "text")
end

function TOOLTIPS.mail(tip)
	local senders = Data.MailSenders()
	if #senders == 0 then
		tip:AddLine(L["You have unread mail."], "text")
		return
	end
	tip:AddCaption(L["From"])
	for _, sender in ipairs(senders) do
		tip:AddLine(sender, "textEmphasis")
	end
end

function TOOLTIPS.calendar(tip)
	local invites = Data.PendingInvites()
	if invites > 0 then
		tip:AddLine(L["Pending invites: %d"]:format(invites), "accent")
	end
	tip:AddCaption(L["Click: calendar. Right-click: clock options."])
end

function TOOLTIPS.queue(tip)
	tip:AddLine(L["You are in a queue or have a listing."], "text")
	tip:AddCaption(L["Click: your queues. Right-click: queue options."])
end

function TOOLTIPS.drawer(tip)
	local drawer = ns.Map and ns.Map.drawer
	local count = drawer and drawer:Count() or 0
	if count > 0 then
		tip:AddLine(L["%d addon buttons"]:format(count), "text")
	end
	tip:AddCaption(L["Click: open the drawer. Right-click: addon compartment."])
end

function Column.Tooltip(name, tip, button)
	tip:SetOwner(button, Anchor(button))
	tip:AddTitle(TITLES[name])
	TOOLTIPS[name](tip)
end

local function AfterCombat(button)
	if InCombatLockdown() then
		K.Print(L["%s opens after combat."]:format(TITLES[button.minimapName]))
	else
		K.Print(L["%s is not available on this client."]:format(TITLES[button.minimapName]))
		K.DevTest.Log("Minimap", "the " .. button.minimapName .. " button has no Blizzard button to click")
	end
end

local function TrackingMenu(owner, root)
	root:CreateTitle(L["Tracking"])
	for _, entry in ipairs(Data.TrackingEntries()) do
		root:CreateCheckbox(entry.name, function(data)
			return Data.TrackingActive(data.index)
		end, function(data)
			Data.SetTracking(data.index, not Data.TrackingActive(data.index))
		end, entry)
	end
	root:CreateDivider()
	root:CreateButton(L["Uncheck all"], function()
		Data.ClearTracking()
	end)
end

function Column.OpenTracking(button)
	local menu = MenuUtil
	if not (menu and type(menu.CreateContextMenu) == "function") then
		K.DevTest.Log("Minimap", "MenuUtil.CreateContextMenu is missing; the tracking menu cannot open")
		return
	end
	menu.CreateContextMenu(button, TrackingMenu)
end

local RESOLVE = {
	calendar = function()
		return GameTimeFrame, TimeManagerClockButton
	end,
	queue = function()
		return QueueStatusButton, QueueStatusButton
	end,
}

local function NewButton(column, name)
	local button = Widgets.IconButton(column.host, {
		size = Settings.Get("column.size"),
		crop = false,
		hideNumbers = true,
		tooltip = function(tip, frame)
			Column.Tooltip(name, tip, frame)
		end,
	})
	button.minimapName = name
	button:SetIcon(GLYPHS)
	button.icon:SetTexCoord(Column.Cell(name))
	button:RegisterForClicks("AnyUp")
	button.chrome:SetShown(false)
	local disc = button:CreateTexture(nil, "BACKGROUND")
	disc:SetTexture((Tokens.Texture("dot")))
	disc:SetAllPoints(button)
	disc:SetVertexColor(Tokens.Color("buttonFill"))
	button.disc = disc
	local ring = button:CreateTexture(nil, "BACKGROUND", nil, 1)
	ring:SetTexture((Tokens.Texture("ring")))
	ring:SetAllPoints(button)
	button.ring = ring
	local badge = button.overlay:CreateTexture(nil, "OVERLAY")
	badge:SetTexture((Tokens.Texture("dot")))
	badge:SetSize(BADGE_SIZE, BADGE_SIZE)
	badge:SetPoint("TOPRIGHT", button, "TOPRIGHT", -BADGE_INSET, -BADGE_INSET)
	badge:Hide()
	button.badge = badge
	if not column.preview then
		if name == "drawer" then
			button.onClick = function(_, mouseButton)
				if column.drawer then
					column.drawer:OnToggleClick(mouseButton)
				end
			end
			button:HookScript("OnEnter", function()
				if column.drawer then
					column.drawer:OnToggleEnter()
				end
			end)
		elseif name == "tracking" then
			button.onClick = Column.OpenTracking
		elseif RESOLVE[name] then
			button.onClick = AfterCombat
			SecureClick.Bind(button, RESOLVE[name], function(tip, frame)
				Column.Tooltip(name, tip, frame)
			end)
		end
	end
	return button
end

function Column.New(face, opts)
	opts = opts or {}
	local host = CreateFrame("Frame", nil, face.holder)
	host:SetAllPoints(face.holder)
	host:SetFrameLevel(face.overlay:GetFrameLevel() + 1)
	local strip = CreateFrame("Frame", nil, host)
	strip.fill = strip:CreateTexture(nil, "BACKGROUND")
	strip.fill:SetColorTexture(Tokens.Color("white"))
	strip.fill:SetAllPoints(strip)
	local plate = CreateFrame("Frame", nil, host)
	plate:SetFrameLevel(host:GetFrameLevel())
	plate.chrome = Widgets.Chrome(plate, { shape = "panel", edge = "edgeInner" })
	plate:Hide()
	local column = setmetatable({ face = face, holder = face.holder, host = host, strip = strip, plate = plate, preview = opts.preview == true, buttons = {} }, Column)
	for _, name in ipairs(Column.ORDER) do
		column.buttons[name] = NewButton(column, name)
	end
	return column
end

function Column:Wanted(name)
	if not Settings.Get("column." .. name) then
		return false
	end
	if self.preview then
		return true
	end
	if name == "tracking" then
		return Data.HasTracking() and not Data.RuleActive("IngameTrackingDisabled")
	elseif name == "mail" then
		return Data.HasMail() and not Data.RuleActive("IngameMailNotificationDisabled")
	elseif name == "calendar" then
		return not Data.RuleActive("IngameCalendarDisabled")
	elseif name == "queue" then
		return Data.Queued()
	elseif name == "drawer" then
		return not Settings.Get("drawer.hideEmpty") or (self.drawer ~= nil and self.drawer:HasContent())
	end
	return true
end

function Column:Active(name)
	if name == "mail" or name == "queue" then
		return true
	end
	if name == "drawer" then
		return self.drawer ~= nil and self.drawer.open == true
	end
	if name == "calendar" then
		return not self.preview and Data.PendingInvites() > 0
	end
	return false
end

local function PlaceStrip(self, size)
	local face, strip = self.face, self.strip
	local inset = face.inset or Widgets.Snap(face.box, Tokens.Size("gapSmall"))
	local gap = Widgets.Snap(face.box, STRIP_GAP)
	strip:ClearAllPoints()
	strip:SetPoint("TOPRIGHT", face.box, "TOPRIGHT", -inset, -inset)
	if face.strip:IsShown() then
		strip:SetPoint("BOTTOMRIGHT", face.strip, "TOPRIGHT", 0, 0)
	else
		strip:SetPoint("BOTTOMRIGHT", face.box, "BOTTOMRIGHT", -inset, inset)
	end
	strip:SetWidth(size + 2 * gap)
	return gap
end

local function PlacePlate(self, size, spacing, count, up, right)
	local face, plate = self.face, self.plate
	local gap = Widgets.Snap(face.box, GAP)
	local pad = Widgets.Snap(face.box, ns.Format.COLUMN_PAD)
	local inset = Widgets.Snap(face.box, PLATE_INSET)
	local vertical = up and "BOTTOM" or "TOP"
	local y = up and gap or -gap
	plate:ClearAllPoints()
	if right then
		plate:SetPoint(vertical .. "LEFT", face.box, vertical .. "RIGHT", gap, y)
	else
		plate:SetPoint(vertical .. "RIGHT", face.box, vertical .. "LEFT", -gap, y)
	end
	count = max(count, 1)
	plate:SetWidth(size + 2 * pad)
	plate:SetHeight(2 * inset + count * size + (count - 1) * spacing)
	return inset
end

local function Fit(button, size, inset)
	if button.opts.size ~= size or button.opts.iconInset ~= inset then
		button.opts.size, button.opts.iconInset = size, inset
		button:Restyle()
	end
end

function Column:Layout()
	local holder = self.holder
	local size = Widgets.Snap(holder, Settings.Get("column.size"))
	local spacing = Widgets.Snap(holder, Settings.Get("column.spacing"))
	local side = Settings.Get("column.side")
	local inside = side == "inside"
	local up = Settings.Get("column.growth") == "up"
	local vertical = up and "BOTTOM" or "TOP"
	local shown = {}
	for _, name in ipairs(Column.ORDER) do
		local button = self.buttons[name]
		local wanted = self:Wanted(name)
		button:SetShown(wanted)
		if wanted then
			shown[#shown + 1] = button
		end
	end
	self.strip:SetShown(inside)
	self.plate:SetShown(not inside and #shown > 0)
	local box, start, inset
	local face = self.face
	if inside then
		box, start = self.strip, PlaceStrip(self, size)
		local footer = face.strip:IsShown() and face.strip:GetHeight() or 0
		local occupied = start + #shown * size + max(#shown - 1, 0) * spacing
		face:PlaceSlider(up, (face.mapSize or 0) - footer - occupied)
	else
		box, start = self.plate, PlacePlate(self, size, spacing, #shown, up, side == "right")
		inset = Widgets.Snap(holder, size * (1 - GLYPH_SHARE) / 2)
		face:PlaceSlider(false, nil)
	end
	for slot, button in ipairs(shown) do
		local offset = start + (slot - 1) * (size + spacing)
		Fit(button, size, inset)
		button.disc:SetShown(not inside)
		button.ring:SetShown(not inside)
		button:ClearAllPoints()
		button:SetPoint(vertical, box, vertical, 0, up and offset or -offset)
	end
end

function Column:Paint()
	local ar, ag, ab = Style.Accent()
	local tr, tg, tb = Tokens.Color("textEmphasis")
	local sr, sg, sb = Tokens.Color("surface")
	self.strip.fill:SetVertexColor(sr, sg, sb, Settings.Get("strip.opacity"))
	for _, name in ipairs(Column.ORDER) do
		local button = self.buttons[name]
		local active = self:Active(name)
		button:SetAccent(ar, ag, ab)
		if active then
			button:SetTint(ar, ag, ab)
		else
			button:SetTint(tr, tg, tb)
		end
		button.badge:SetVertexColor(ar, ag, ab)
		Widgets.Tint(button.ring, "edgeInner", RING_ALPHA_SCALE)
		button.badge:SetShown(name == "calendar" and active)
	end
end

function Column:Refresh()
	self:Layout()
	self:Paint()
end
