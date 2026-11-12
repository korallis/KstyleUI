-- Card.lua: the quest card's frames: Lumen glass, the QUESTS section cap with the tracked count, a clipped view, never taller than the card's Layout element, of a set number of quests (accent disc, gold title with its level, objectives that wrap onto up to three lines with their counts in near white on the first line's right, an item socket; the title and the lines in the story card's one text size, Lumen.TEXT_SIZE) that the wheel scrolls one quest at a time (a quest too tall for the card shows the objectives that fit and the more line counts the rest), a more line that always says how many quests wait (the Captain's ruling on KSTY-33: a hidden overflow line hid content from the owner), and a slim scroll bar that rests unseen until the pointer is over the card, as the owner's picture draws it (LEE-20); quest items are secure item buttons parented to UIParent that cover their sockets and change only out of combat, and while one shows in combat the rows hold still and only their words repaint.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, L = K.Widgets, K.Tokens, K.L
local Style, Lumen, Data = ns.Style, ns.Lumen, ns.QuestData

local Card = {}
ns.QuestCard = Card

local MAX_SHOWN, MAX_LINES, MAX_WRAP = 8, 6, 3
local GUTTER, DISC, DISC_LEAD, NUMERAL = 25.5, 16, 1, 10
local TITLE_LEAD, LINE_LEAD, ROW_GAP = 5.5, 4, 7
local CAP_ROW, CAP_GAP, HEAD, FOOT = 21, 6.5, 11, 12.5
local SOCKET, SOCKET_GAP = 20, 4
local BAR_WIDTH, BAR_GAP, THUMB_MIN = 3, 5, 10
local THUMB_ALPHA, TRACK_ALPHA, HOVER_MIX = 0.35, 0.5, 0.18
local MORE_SCALE = 0.85

local card, glass, cap, view, more, track, thumb, ruler, countRuler
local rows, buttons, heights = {}, {}, {}
local pitch, lead, rowWidth = 0, 0, 0
local offset, wanted, maxHeight = 1, 4, 0
local pending, waiting, active = false, false, false
local pointed = false

local function Snap(units)
	return Widgets.Snap(card, units)
end

local function TextSize()
	return Lumen.Size(card, Lumen.TEXT_SIZE)
end

local function Foot()
	return Snap(FOOT * math.max(1, Style.Setting("text", "size")))
end

local function Gutter()
	return Snap(Lumen.Size(card, GUTTER))
end

local function TitleHeight()
	return Snap(TextSize() + TITLE_LEAD)
end

local function LineHeight()
	return Snap(TextSize() + LINE_LEAD)
end

local function Inset()
	return Lumen.Inset(card)
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
	row.disc:SetVertexColor(Tokens.Color("questDisc"))
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
		if type(root.SetTag) == "function" then
			root:SetTag("KSTYLEUI_QUEST")
		end
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
	local disc = Lumen.Size(card, DISC)
	Widgets.Size(row.disc, disc, disc)
	Style.ApplyFont(row.numeral, "number", Lumen.Size(card, NUMERAL))
	row.numeral:SetShadowOffset(0, 0)
	Widgets.TextColor(row.numeral, "white")
	local size = TextSize()
	Style.ApplyFont(row.title, "body", size)
	for _, line in ipairs(row.lines) do
		Style.ApplyFont(line.text, "body", size)
		Style.ApplyFont(line.count, "number", size)
	end
	Widgets.Size(row.socket, SOCKET, SOCKET)
	local border = Widgets.Border(row.socket)
	row.icon:ClearAllPoints()
	row.icon:SetPoint("TOPLEFT", row.socket, "TOPLEFT", border, -border)
	row.icon:SetPoint("BOTTOMRIGHT", row.socket, "BOTTOMRIGHT", -border, border)
	PaintTitle(row)
	PaintDisc(row)
end

local function PaintRest()
	local alpha = pointed and 1 or 0
	track:SetAlpha(alpha)
	thumb:SetAlpha(alpha)
	more:SetAlpha(1)
end

local function Peek()
	local ok, value = pcall(card.IsMouseOver, card)
	local now = ok and not Widgets.IsSecret(value) and value == true
	if now ~= pointed then
		pointed = now
		PaintRest()
	end
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
		Peek()
	end)
	row:SetScript("OnLeave", function(self)
		self.hover = false
		PaintTitle(self)
		Peek()
	end)
	row.index = index
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
		text:SetJustifyV("TOP")
		text:SetWordWrap(true)
		local count = Widgets.FontString(row, "OVERLAY")
		count:SetJustifyH("RIGHT")
		row.lines[i] = { text = text, count = count }
	end
	row.socket = CreateFrame("Frame", nil, row)
	row.socket.chrome = Widgets.Chrome(row.socket, { shape = "socket" })
	row.icon = row.socket:CreateTexture(nil, "ARTWORK")
	row.Restyle = RestyleRow
	RestyleRow(row)
	Style.Track(row)
	Widgets.Track(row)
	row:Hide()
	return row
end

local function Right(entry)
	return entry.item and Snap(SOCKET + SOCKET_GAP) or 0
end

local function Span(lines)
	return Snap(LineHeight() + (lines - 1) * pitch)
end

local function Room(right, objective)
	local room = rowWidth - Gutter() - right
	if objective and objective.count then
		countRuler:SetText(objective.count)
		room = room - Widgets.TextWidth(countRuler, 0) - Snap(SOCKET_GAP)
	end
	return room
end

local function Lines(objective, room)
	if room <= 0 then
		return 1
	end
	ruler:SetWidth(room)
	ruler:SetText(objective.text)
	local lines = math.floor((Widgets.TextHeight(ruler, pitch) + lead) / pitch + 0.5)
	return math.max(1, math.min(MAX_WRAP, lines))
end

local function Line(row, i, y, right, text, count, colorName, room, lines)
	local line = row.lines[i]
	line.text:ClearAllPoints()
	line.text:SetPoint("TOPLEFT", row, "TOPLEFT", Gutter(), -Snap(y))
	line.text:SetWidth(math.max(room, 1))
	line.text:SetSpacing(lead)
	line.text:SetHeight(Snap(lines * pitch))
	line.text:SetMaxLines(lines)
	line.count:ClearAllPoints()
	local edge = right > 0 and -right or row.rail - Snap(1)
	line.count:SetPoint("TOPRIGHT", row, "TOPRIGHT", edge, -Snap(y))
	line.text:SetText(text)
	line.count:SetText(count or "")
	Widgets.TextColor(line.text, colorName)
	Widgets.TextColor(line.count, colorName == "text" and "textEmphasis" or colorName)
	line.text:Show()
	line.count:SetShown(count ~= nil)
end

local function Words(row, entry, limit)
	local titleH = TitleHeight()
	local right = Right(entry)
	row.title:SetText(entry.title)
	local used, cut = 0, 0
	if entry.complete then
		used = 1
		Line(row, 1, titleH, right, Ready(), nil, "friend", Room(right), 1)
	elseif entry.failed then
		used = 1
		Line(row, 1, titleH, right, Failed(), nil, "hostile", Room(right), 1)
	else
		local y = titleH
		for i = 1, entry.count do
			local objective = entry.objectives[i]
			local room = Room(right, objective)
			local lines = Lines(objective, room)
			if limit and Snap(y + Span(lines)) > limit then
				cut = entry.count - used
				break
			end
			used = i
			Line(row, i, y, right, objective.text, objective.count, objective.done and "textDisabled" or "text", room, lines)
			y = y + Span(lines)
		end
	end
	for i = used + 1, MAX_LINES do
		row.lines[i].text:Hide()
		row.lines[i].count:Hide()
	end
	return cut
end

local function Bind(row, entry, position, y, height, right, limit)
	row:ClearAllPoints()
	row:SetPoint("TOPLEFT", view, "TOPLEFT", 0, -y)
	row:SetPoint("TOPRIGHT", view, "TOPRIGHT", -right, -y)
	row:SetHeight(height)
	row.span = height
	row.rail = right
	row.limit = limit
	row.questID = entry.id
	row.item, row.logIndex = entry.item, entry.logIndex
	local titleH = TitleHeight()
	row.disc:ClearAllPoints()
	row.disc:SetPoint("TOPLEFT", row, "TOPLEFT", Snap(Lumen.Size(card, DISC_LEAD)), -Snap((titleH - row.disc:GetHeight()) / 2))
	row.numeral:SetText(position)
	row.title:ClearAllPoints()
	row.title:SetPoint("TOPLEFT", row, "TOPLEFT", Gutter(), 0)
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
	local cut = Words(row, entry, limit)
	PaintTitle(row)
	PaintDisc(row)
	row:Show()
	return cut
end

local function Height(entry)
	local height = TitleHeight()
	if entry.complete or entry.failed then
		height = height + LineHeight()
	else
		local right = Right(entry)
		for i = 1, entry.count do
			local objective = entry.objectives[i]
			height = height + Span(Lines(objective, Room(right, objective)))
		end
	end
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

local function Fits(height, room)
	local pixel = K.Scale.Pixel(1) / Widgets.ScaleFactor(card)
	return Snap(height) <= Snap(room) + pixel + pixel * 1e-6
end

local function FitFromEnd(total, n, room, gap)
	local sum, fit = 0, 0
	for i = total, math.max(1, total - n + 1), -1 do
		local add = heights[i] + (fit > 0 and gap or 0)
		if fit > 0 and not Fits(sum + add, room) then
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
	thumb:SetPoint("TOPRIGHT", view, "TOPRIGHT", Snap(BAR_WIDTH + BAR_GAP), -Snap(y))
	thumb:SetHeight(thumbH)
end

local function Repaint()
	for i = 1, #rows do
		local row = rows[i]
		if row:IsShown() and row.questID then
			for n = 1, Data.Count() do
				local entry = Data.Get(n)
				if entry.id == row.questID then
					if Height(entry) == row.span then
						Words(row, entry, row.limit)
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
	local over = total > n
	local inset = Inset()
	local right = over and Snap(BAR_WIDTH + BAR_GAP) or 0
	rowWidth = (card:GetWidth() or 0) - 2 * inset - right
	for i = 1, total do
		heights[i] = Height(Data.Get(i))
	end
	local top = Snap(HEAD)
	local chrome = top + Snap(CAP_ROW) + Snap(CAP_GAP) + Foot()
	local room = math.max(0, maxHeight - chrome)
	if not over and not Fits(Window(total, n, gap), room) then
		over = true
		right = Snap(BAR_WIDTH + BAR_GAP)
		rowWidth = (card:GetWidth() or 0) - 2 * inset - right
		for i = 1, total do
			heights[i] = Height(Data.Get(i))
		end
		room = math.max(0, maxHeight - chrome)
	end
	local viewHeight = math.min(Window(total, n, gap), room)
	local fit = FitFromEnd(total, n, viewHeight, gap)
	offset = math.max(1, math.min(offset, total - fit + 1))
	local y, k, cut = 0, 0, 0
	while k < n and offset + k <= total do
		local h = heights[offset + k]
		if k > 0 and not Fits(y + h, viewHeight) then
			break
		end
		k = k + 1
		local row = rows[k]
		local limit = not Fits(h, viewHeight) and viewHeight or nil
		cut = Bind(row, Data.Get(offset + k - 1), offset + k - 1, y, h, right, limit)
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
	elseif cut > 0 then
		more:SetText(string.format(L["%d more"], cut))
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
	button:HookScript("OnEnter", Peek)
	button:HookScript("OnLeave", Peek)
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
	wanted = math.max(1, math.min(MAX_SHOWN, math.floor(tonumber(n) or 4)))
end

function Card.Place(root, left, top, width, height)
	card:ClearAllPoints()
	card:SetPoint("TOPLEFT", root, "BOTTOMLEFT", Widgets.Snap(card, left), Widgets.Snap(card, top))
	card:SetWidth(Widgets.Snap(card, width))
	maxHeight = height
end

local function Restyle()
	Style.ApplyFont(ruler, "body", TextSize())
	Style.ApplyFont(countRuler, "number", TextSize())
	ruler:SetSpacing(0)
	ruler:SetWidth(0)
	ruler:SetText("Ag")
	local natural = Widgets.TextHeight(ruler, (Widgets.LineHeight(ruler)))
	pitch = math.max(LineHeight(), natural)
	lead = pitch - natural
	ruler:SetSpacing(lead)
	Style.ApplyFont(more, "body", TextSize() * MORE_SCALE)
	more:ClearAllPoints()
	more:SetPoint("CENTER", view, "BOTTOM", 0, -Foot() / 2)
	more:SetHeight(Foot())
	Widgets.TextColor(more, "muted")
	track:SetColorTexture(Widgets.Rgba("edgeBar", TRACK_ALPHA))
	track:SetWidth(Snap(BAR_WIDTH))
	track:ClearAllPoints()
	track:SetPoint("TOPRIGHT", view, "TOPRIGHT", Snap(BAR_WIDTH + BAR_GAP), 0)
	track:SetPoint("BOTTOMRIGHT", view, "BOTTOMRIGHT", Snap(BAR_WIDTH + BAR_GAP), 0)
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
	card:SetMouseMotionEnabled(true)
	card:SetScript("OnEnter", Peek)
	card:SetScript("OnLeave", Peek)
	card:Hide()
	glass = CreateFrame("Frame", nil, card)
	glass:SetAllPoints(card)
	glass:SetFrameLevel(card:GetFrameLevel())
	glass.chrome = Widgets.Chrome(glass, { shape = "window", fill = "surface" })
	cap = Lumen.SectionCap(card, { left = function()
		return Inset()
	end, right = function()
		return Inset()
	end, y = 0 })
	cap:SetTitle(L["Quests"])
	view = CreateFrame("Frame", nil, card)
	view:SetClipsChildren(true)
	view:SetFrameLevel(card:GetFrameLevel() + 2)
	local rail = CreateFrame("Frame", nil, card)
	rail:SetAllPoints(view)
	rail:SetFrameLevel(view:GetFrameLevel())
	track = rail:CreateTexture(nil, "BACKGROUND")
	thumb = rail:CreateTexture(nil, "ARTWORK")
	ruler = Widgets.FontString(card, "OVERLAY")
	ruler:SetWordWrap(true)
	ruler:Hide()
	countRuler = Widgets.FontString(card, "OVERLAY")
	countRuler:Hide()
	more = Widgets.FontString(card, "OVERLAY")
	more:SetPoint("CENTER", view, "BOTTOM", 0, -Foot() / 2)
	more:SetJustifyH("CENTER")
	PaintRest()
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
