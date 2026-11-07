-- Column.lua: the column of small monochrome buttons beside the map: tracking, mail, calendar and the group finder status.
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
	disc:SetVertexColor(Tokens.Color("surface"))
	button.disc = disc
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
	local column = setmetatable({ face = face, holder = face.holder, host = host, preview = opts.preview == true, buttons = {} }, Column)
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

function Column:Layout()
	local holder, face = self.holder, self.face
	local size = Widgets.Snap(holder, Settings.Get("column.size"))
	local spacing = Widgets.Snap(holder, Settings.Get("column.spacing"))
	local side = Settings.Get("column.side")
	local right = side == "right"
	local up = Settings.Get("column.growth") == "up"
	local vertical = up and "BOTTOM" or "TOP"
	local point = vertical .. (right and "LEFT" or "RIGHT")
	local relative = vertical .. (right and "RIGHT" or "LEFT")
	local x = right and spacing or -spacing
	local box, start = face.box, 0
	if side == "inside" then
		local strip = face.strip
		box = up and strip:IsShown() and strip or face.mapArea
		relative, start = (box == strip and "TOP" or vertical) .. "RIGHT", spacing
	end
	local slot = 0
	for _, name in ipairs(Column.ORDER) do
		local button = self.buttons[name]
		local shown = self:Wanted(name)
		button:SetShown(shown)
		if shown then
			local offset = start + slot * (size + spacing)
			if button.opts.size ~= size then
				button.opts.size = size
				button:Restyle()
			end
			button:ClearAllPoints()
			button:SetPoint(point, box, relative, x, up and offset or -offset)
			slot = slot + 1
		end
	end
end

function Column:Paint()
	local ar, ag, ab = Style.Accent()
	local tr, tg, tb = Tokens.Color("textEmphasis")
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
		button.badge:SetShown(name == "calendar" and active)
	end
end

function Column:Refresh()
	self:Layout()
	self:Paint()
end
