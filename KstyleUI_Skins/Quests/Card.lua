-- Card.lua: the quest card's frames: Lumen glass, the QUESTS section cap with the tracked count, a clipped view of a set number of quests (accent disc, gold title with its level, objectives with their counts on the right, an item socket) that the wheel scrolls one quest at a time, a slim scroll bar and a more line; quest items are secure item buttons parented to UIParent that cover their sockets and change only out of combat, and while one shows in combat the rows hold still and only their words repaint.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, L = K.Widgets, K.Tokens, K.L
local Style, Lumen, Data = ns.Style, ns.Lumen, ns.QuestData

local Card = {}
ns.QuestCard = Card

local MAX_SHOWN, MAX_LINES = 8, 6
local GUTTER, DISC, RING, NUMERAL = 18, 14, 20, 9
local TITLE_LEAD, LINE_LEAD, ROW_GAP = 5, 3, 7
local CAP_ROW, CAP_GAP, MORE_ROW = 22, 2, 16
local SOCKET, SOCKET_GAP = 20, 4
local BAR_WIDTH, BAR_GAP, THUMB_MIN = 3, 5, 10
local THUMB_ALPHA, TRACK_ALPHA, HOVER_MIX = 0.35, 0.5, 0.18
local LINE_SCALE, MORE_SCALE = 0.95, 0.85

local card, glass, cap, view, more, track, thumb
local rows, buttons, heights = {}, {}, {}
local offset, wanted, maxHeight = 1, 3, 0
local docked, pending, waiting, active = false, false, false, false

local function Snap(units)
	return Widgets.Snap(card, units)
end

local function Size(role, scale)
	local _, size = Style.Font(role)
	return size * (scale or 1)
end

local function TitleHeight()
	return Snap(Size("body") + TITLE_LEAD)
end

local function LineHeight()
	return Snap(Size("body", LINE_SCALE) + LINE_LEAD)
end

local function Inset()
	return Widgets.Inset(card, Tokens.Size("radius"))
end

local function Ready()
	local text = QUEST_WATCH_QUEST_READY or COMPLETE
	return type(text) == "string" and text or ""
end

local function Failed()
	return type(FAILED) == "string" and FAILED or ""
end

local function AnyButtonShown()
	for i = 1, #buttons do
		if buttons[i]:IsShown() then
			return true
		end
	end
	return false
end

function Card.Locked()
	return InCombatLockdown() and AnyButtonShown()
end

local function PaintTitle(row)
	local r, g, b = Lumen.Color("questGold")
	if row.hover then
		r, g, b = Widgets.Mix(r, g, b, 1, 1, 1, 1, 1, HOVER_MIX)
	end
	row.title:SetTextColor(r, g, b)
end

local function PaintDisc(row)
	Style.TintAccent(row.disc)
	Style.TintAccent(row.ring, 0.9)
	row.ring:SetShown(row.marked == true)
end

local function Open(id)
	if InCombatLockdown() or type(QuestMapFrame_OpenToQuestDetails) ~= "function" then
		return
	end
	QuestMapFrame_OpenToQuestDetails(id)
end

local function Untrack(id)
	local util = QuestUtil
	if type(util) == "table" and type(util.CanRemoveQuestWatch) == "function" and util.CanRemoveQuestWatch() ~= true then
		return
	end
	C_QuestLog.RemoveQuestWatch(id)
end

local function Word(name)
	local value = _G[name]
	return type(value) == "string" and value or nil
end

local function Menu(row, id)
	local menu = MenuUtil
	if type(menu) ~= "table" or type(menu.CreateContextMenu) ~= "function" then
		return
	end
	local title = row.title:GetText()
	menu.CreateContextMenu(row, function(_, root)
		if type(title) == "string" then
			root:CreateTitle(title)
		end
		local super = Data.super == id
		local focus = Word(super and "STOP_SUPER_TRACK_QUEST" or "SUPER_TRACK_QUEST")
		if focus and type(C_SuperTrack) == "table" and type(C_SuperTrack.SetSuperTrackedQuestID) == "function" then
			root:CreateButton(focus, function()
				C_SuperTrack.SetSuperTrackedQuestID(super and 0 or id)
			end)
		end
		local map = Word("OBJECTIVES_SHOW_QUEST_MAP")
		if map then
			root:CreateButton(map, function()
				Open(id)
			end)
		end
		local stop = Word("OBJECTIVES_STOP_TRACKING")
		if stop then
			root:CreateButton(stop, function()
				Untrack(id)
			end)
		end
		local share = Word("SHARE_QUEST")
		local util = QuestUtil
		if share and type(C_QuestLog.IsPushableQuest) == "function" and C_QuestLog.IsPushableQuest(id) == true
			and type(IsInGroup) == "function" and IsInGroup() and type(util) == "table" and type(util.ShareQuest) == "function" then
			root:CreateButton(share, function()
				util.ShareQuest(id)
			end)
		end
	end)
end

local function OnClick(row, button)
	local id = row.questID
	if not id then
		return
	end
	if button == "RightButton" then
		Menu(row, id)
		return
	end
	local chat = ChatFrameUtil
	if type(chat) == "table" and type(chat.TryInsertQuestLinkForQuestID) == "function" and chat.TryInsertQuestLinkForQuestID(id) then
		return
	end
	if type(IsModifiedClick) == "function" and IsModifiedClick("QUESTWATCHTOGGLE") then
		Untrack(id)
		return
	end
	Open(id)
end

local function OnWheel(_, delta)
	Card.Scroll(delta > 0 and -1 or 1)
end

local function RestyleRow(row)
	Widgets.Size(row.disc, DISC, DISC)
	Widgets.Size(row.ring, RING, RING)
	Style.ApplyFont(row.numeral, "number", NUMERAL * Style.Setting("text", "size"))
	Widgets.TextColor(row.numeral, "black")
	Style.ApplyFont(row.title, "body")
	for _, line in ipairs(row.lines) do
		Style.ApplyFont(line.text, "body", Size("body", LINE_SCALE))
		Style.ApplyFont(line.count, "number", Size("number", LINE_SCALE))
	end
	Widgets.Size(row.socket, SOCKET, SOCKET)
	PaintTitle(row)
	PaintDisc(row)
end

local function NewRow(index)
	local row = CreateFrame("Button", nil, view)
	row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	row:EnableMouseWheel(true)
	row:SetScript("OnMouseWheel", OnWheel)
	row:SetScript("OnClick", OnClick)
	row:SetScript("OnEnter", function(self)
		self.hover = true
		PaintTitle(self)
	end)
	row:SetScript("OnLeave", function(self)
		self.hover = false
		PaintTitle(self)
	end)
	row.index = index
	row.ring = row:CreateTexture(nil, "ARTWORK", nil, -1)
	row.ring:SetTexture((Tokens.Texture("ringBevel")))
	row.disc = row:CreateTexture(nil, "ARTWORK")
	row.disc:SetTexture((Tokens.Texture("dot")))
	row.numeral = Widgets.FontString(row, "OVERLAY")
	row.numeral:SetPoint("CENTER", row.disc, "CENTER", 0, 0)
	row.title = Widgets.FontString(row, "OVERLAY")
	row.title:SetJustifyH("LEFT")
	row.title:SetWordWrap(false)
	row.lines = {}
	for i = 1, MAX_LINES do
		local text = Widgets.FontString(row, "OVERLAY")
		text:SetJustifyH("LEFT")
		text:SetWordWrap(false)
		local count = Widgets.FontString(row, "OVERLAY")
		count:SetJustifyH("RIGHT")
		row.lines[i] = { text = text, count = count }
	end
	row.socket = CreateFrame("Frame", nil, row)
	row.socket.chrome = Widgets.Chrome(row.socket, { shape = "socket" })
	row.icon = row.socket:CreateTexture(nil, "ARTWORK")
	row.icon:SetPoint("TOPLEFT", row.socket, "TOPLEFT", 1, -1)
	row.icon:SetPoint("BOTTOMRIGHT", row.socket, "BOTTOMRIGHT", -1, 1)
	row.Restyle = RestyleRow
	RestyleRow(row)
	Style.Track(row)
	Widgets.Track(row)
	row:Hide()
	return row
end

local function Line(row, i, y, right, text, count, colorName)
	local line = row.lines[i]
	line.text:ClearAllPoints()
	line.text:SetPoint("TOPLEFT", row, "TOPLEFT", Snap(GUTTER), -y)
	line.count:ClearAllPoints()
	line.count:SetPoint("TOPRIGHT", row, "TOPRIGHT", -right, -y)
	if count then
		line.text:SetPoint("RIGHT", line.count, "LEFT", -Snap(SOCKET_GAP), 0)
	else
		line.text:SetPoint("RIGHT", row, "RIGHT", -right, 0)
	end
	line.text:SetText(text)
	line.count:SetText(count or "")
	Widgets.TextColor(line.text, colorName)
	Widgets.TextColor(line.count, colorName)
	line.text:Show()
	line.count:SetShown(count ~= nil)
end

local function LinesOf(entry)
	if entry.complete or entry.failed then
		return 1
	end
	return entry.count
end

local function Words(row, entry)
	local titleH, lineH = TitleHeight(), LineHeight()
	local right = entry.item and Snap(SOCKET + SOCKET_GAP) or 0
	row.title:SetText(entry.title)
	local used = 0
	if entry.complete then
		used = 1
		Line(row, 1, titleH, right, Ready(), nil, "friend")
	elseif entry.failed then
		used = 1
		Line(row, 1, titleH, right, Failed(), nil, "hostile")
	else
		for i = 1, entry.count do
			local objective = entry.objectives[i]
			used = i
			Line(row, i, titleH + (i - 1) * lineH, right, objective.text, objective.count, objective.done and "textDisabled" or "text")
		end
	end
	for i = used + 1, MAX_LINES do
		row.lines[i].text:Hide()
		row.lines[i].count:Hide()
	end
end

local function Bind(row, entry, position, y, height, right)
	row:ClearAllPoints()
	row:SetPoint("TOPLEFT", view, "TOPLEFT", 0, -y)
	row:SetPoint("TOPRIGHT", view, "TOPRIGHT", -right, -y)
	row:SetHeight(height)
	row.questID = entry.id
	row.item, row.logIndex = entry.item, entry.logIndex
	row.marked = entry.id == Data.super
	local titleH = TitleHeight()
	row.disc:ClearAllPoints()
	row.disc:SetPoint("CENTER", row, "TOPLEFT", Snap(DISC / 2), -titleH / 2)
	row.ring:ClearAllPoints()
	row.ring:SetPoint("CENTER", row.disc, "CENTER")
	row.numeral:SetText(position)
	row.title:ClearAllPoints()
	row.title:SetPoint("TOPLEFT", row, "TOPLEFT", Snap(GUTTER), 0)
	row.title:SetHeight(titleH)
	if entry.item then
		row.socket:ClearAllPoints()
		row.socket:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
		row.icon:SetTexture(entry.icon)
		row.socket:Show()
		row.title:SetPoint("RIGHT", row.socket, "LEFT", -Snap(SOCKET_GAP), 0)
	else
		row.socket:Hide()
		row.title:SetPoint("RIGHT", row, "RIGHT", 0, 0)
	end
	Words(row, entry)
	PaintTitle(row)
	PaintDisc(row)
	row:Show()
end

local function Height(entry)
	local height = TitleHeight() + LinesOf(entry) * LineHeight()
	if entry.item and height < SOCKET then
		height = SOCKET
	end
	return Snap(height)
end

local function Window(total, n, gap)
	local best = 0
	for start = 1, math.max(1, total - n + 1) do
		local sum = 0
		for i = start, math.min(total, start + n - 1) do
			sum = sum + heights[i] + (i > start and gap or 0)
		end
		if sum > best then
			best = sum
		end
	end
	return best
end

local function FitFromEnd(total, n, room, gap)
	local sum, fit = 0, 0
	for i = total, math.max(1, total - n + 1), -1 do
		local add = heights[i] + (fit > 0 and gap or 0)
		if fit > 0 and sum + add > room then
			break
		end
		sum, fit = sum + add, fit + 1
	end
	return math.max(1, fit)
end

local function MoreText(above, below)
	if below > 0 then
		return string.format(L["%d more, scroll down"], below)
	end
	return string.format(L["%d above, scroll up"], above)
end

local function Bar(total, from, count, viewHeight)
	local over = total > count
	track:SetShown(over)
	thumb:SetShown(over)
	if not over then
		return
	end
	local thumbH = math.max(Snap(THUMB_MIN), Snap(viewHeight * count / total))
	local travel = viewHeight - thumbH
	local y = total > count and travel * (from - 1) / (total - count) or 0
	thumb:ClearAllPoints()
	thumb:SetPoint("TOPRIGHT", view, "TOPRIGHT", 0, -Snap(y))
	thumb:SetHeight(thumbH)
end

local function Repaint()
	for i = 1, #rows do
		local row = rows[i]
		if row:IsShown() and row.questID then
			for n = 1, Data.Count() do
				local entry = Data.Get(n)
				if entry.id == row.questID then
					if LinesOf(entry) == row.used then
						Words(row, entry)
					end
					break
				end
			end
		end
	end
end

local function AfterCombat()
	pending = false
	Card.Render()
end

local function SyncAfterCombat()
	waiting = false
	Card.SyncButtons()
end

function Card.Render()
	if not card or not active then
		return
	end
	if Card.Locked() then
		Repaint()
		if not pending then
			pending = true
			K.Combat.Queue(AfterCombat)
		end
		return
	end
	local total = Data.Count()
	cap:SetTrail(total)
	if total == 0 then
		for i = 1, #rows do
			rows[i]:Hide()
			rows[i].questID = nil
		end
		card:Hide()
		Card.SyncButtons()
		return
	end
	local n = math.min(wanted, total)
	local gap = Snap(ROW_GAP)
	for i = 1, total do
		heights[i] = Height(Data.Get(i))
	end
	local over = total > n
	local inset = Inset()
	local top, bottom = Snap(Tokens.Size("gapSmall")), Snap(Tokens.Size("gapSmall"))
	local chrome = top + Snap(CAP_ROW) + Snap(CAP_GAP) + bottom + (over and Snap(MORE_ROW) or 0)
	local room = math.max(heights[1], maxHeight - chrome)
	local viewHeight = math.min(Window(total, n, gap), room)
	local fit = FitFromEnd(total, n, viewHeight, gap)
	offset = math.max(1, math.min(offset, total - fit + 1))
	local right = over and Snap(BAR_WIDTH + BAR_GAP) or 0
	local y, k = 0, 0
	while k < n and offset + k <= total do
		local h = heights[offset + k]
		if k > 0 and y + h > viewHeight then
			break
		end
		k = k + 1
		local row = rows[k]
		Bind(row, Data.Get(offset + k - 1), offset + k - 1, y, h, right)
		row.used = LinesOf(Data.Get(offset + k - 1))
		y = y + h + gap
	end
	for i = k + 1, #rows do
		rows[i]:Hide()
		rows[i].questID = nil
	end
	cap.row:ClearAllPoints()
	cap.row:SetPoint("TOPLEFT", card, "TOPLEFT", 0, -top)
	cap.row:SetPoint("TOPRIGHT", card, "TOPRIGHT", 0, -top)
	cap.row:SetHeight(Snap(CAP_ROW))
	view:ClearAllPoints()
	view:SetPoint("TOPLEFT", card, "TOPLEFT", inset, -(top + Snap(CAP_ROW) + Snap(CAP_GAP)))
	view:SetPoint("TOPRIGHT", card, "TOPRIGHT", -inset, -(top + Snap(CAP_ROW) + Snap(CAP_GAP)))
	view:SetHeight(viewHeight)
	Bar(total, offset, k, viewHeight)
	local above, below = offset - 1, total - (offset + k - 1)
	if over and above + below > 0 then
		more:SetText(MoreText(above, below))
		more:Show()
	else
		more:SetText("")
		more:Hide()
	end
	card:SetHeight(chrome + viewHeight)
	card:Show()
	if InCombatLockdown() then
		if not waiting then
			waiting = true
			K.Combat.Queue(SyncAfterCombat)
		end
		return
	end
	Card.SyncButtons()
end

function Card.Scroll(steps)
	if not card or Card.Locked() then
		return
	end
	local before = offset
	offset = math.max(1, offset + steps)
	Card.Render()
	if offset ~= before then
		Widgets.Sound("U_CHAT_SCROLL_BUTTON")
	end
end

local function ButtonEnter(button)
	local tip = GameTooltip
	if type(tip) ~= "table" or not button.logIndex then
		return
	end
	tip:SetOwner(button, "ANCHOR_RIGHT")
	if type(tip.SetQuestLogSpecialItem) == "function" then
		tip:SetQuestLogSpecialItem(button.logIndex)
	end
	tip:Show()
end

local function ButtonLeave()
	if type(GameTooltip_Hide) == "function" then
		GameTooltip_Hide()
	end
end

local function NewButton()
	local button = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
	button:RegisterForClicks("AnyUp")
	button:SetAttribute("useOnKeyDown", false)
	button:SetAttribute("type", "item")
	button:SetFrameStrata(card:GetFrameStrata())
	button:SetFrameLevel(card:GetFrameLevel() + 10)
	button:HookScript("OnEnter", ButtonEnter)
	button:HookScript("OnLeave", ButtonLeave)
	button:Hide()
	buttons[#buttons + 1] = button
	return button
end

function Card.SyncButtons()
	if InCombatLockdown() then
		return
	end
	local used = 0
	for i = 1, #rows do
		local row = rows[i]
		if card:IsShown() and row:IsShown() and row.item then
			used = used + 1
			local button = buttons[used] or NewButton()
			if button:GetAttribute("item") ~= row.item then
				button:SetAttribute("item", row.item)
			end
			button.logIndex = row.logIndex
			button:Show()
			if not Widgets.Cover(button, row.socket) then
				button:Hide()
			end
		end
	end
	for i = used + 1, #buttons do
		buttons[i]:Hide()
	end
end

function Card.HideButtons()
	K.Combat.Queue(function()
		for i = 1, #buttons do
			buttons[i]:Hide()
		end
	end)
end

function Card.SetActive(on)
	active = on == true
end

function Card.SetShownCount(n)
	wanted = math.max(1, math.min(MAX_SHOWN, math.floor(tonumber(n) or 3)))
end

function Card.Place(root, left, top, width, height)
	card:ClearAllPoints()
	card:SetPoint("TOPLEFT", root, "BOTTOMLEFT", left, top)
	card:SetWidth(width)
	maxHeight = height
end

function Card.SetDocked(on)
	docked = on == true
	glass:SetShown(not docked)
end

function Card.Docked()
	return docked
end

local function Restyle()
	Style.ApplyFont(more, "body", Size("body", MORE_SCALE))
	Widgets.TextColor(more, "muted")
	track:SetColorTexture(Widgets.Rgba("edgeBar", TRACK_ALPHA))
	track:SetWidth(Snap(BAR_WIDTH))
	thumb:SetColorTexture(Widgets.Rgba("text", THUMB_ALPHA))
	thumb:SetWidth(Snap(BAR_WIDTH))
	Card.Render()
end

function Card.Build(root)
	if card then
		return card
	end
	card = CreateFrame("Frame", "KstyleUI_QuestCard", root)
	card:SetFrameStrata("LOW")
	card:EnableMouseWheel(true)
	card:SetScript("OnMouseWheel", OnWheel)
	card:Hide()
	glass = CreateFrame("Frame", nil, card)
	glass:SetAllPoints(card)
	glass:SetFrameLevel(card:GetFrameLevel())
	glass.chrome = Widgets.Chrome(glass, { shape = "window", fill = "surface", gilt = false })
	cap = Lumen.SectionCap(card, { left = function()
		return Inset()
	end, right = function()
		return Inset()
	end, y = 0 })
	cap:SetTitle(L["Quests"])
	view = CreateFrame("Frame", nil, card)
	view:SetClipsChildren(true)
	view:SetFrameLevel(card:GetFrameLevel() + 2)
	track = view:CreateTexture(nil, "BACKGROUND")
	track:SetPoint("TOPRIGHT", view, "TOPRIGHT")
	track:SetPoint("BOTTOMRIGHT", view, "BOTTOMRIGHT")
	thumb = view:CreateTexture(nil, "ARTWORK")
	more = Widgets.FontString(card, "OVERLAY")
	more:SetPoint("TOP", view, "BOTTOM", 0, -Snap(CAP_GAP))
	more:SetJustifyH("CENTER")
	for i = 1, MAX_SHOWN do
		rows[i] = NewRow(i)
	end
	local restyler = { Restyle = Restyle }
	Style.Track(restyler)
	Widgets.Track(restyler)
	Restyle()
	return card
end

function Card.Frame()
	return card
end

function Card.Rows()
	return rows
end

function Card.Buttons()
	return buttons
end

function Card.Offset()
	return offset
end

function Card.Parts()
	return { card = card, glass = glass, cap = cap, view = view, more = more, track = track, thumb = thumb }
end
