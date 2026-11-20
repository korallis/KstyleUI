-- Card.lua: quest rows, compact single-quest pages, scroll hints and combat-safe item overlays.
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
local THUMB_ALPHA, TRACK_ALPHA = 0.35, 0.5
local MORE_SCALE = 0.85
local COMPACT_PAD = 6

local card, glass, cap, view, more, track, thumb, ruler, countRuler, fade
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

local function MoreRow()
	return Snap(ROW_GAP + TextSize() * MORE_SCALE + LINE_LEAD)
end

local function Gutter()
	return Snap(Lumen.Size(card, GUTTER))
end

local function TitleHeight()
	return Snap(TextSize() + TITLE_LEAD)
end

local function LineHeight()
	local size = ruler and Widgets.FontSize(ruler, TextSize()) or TextSize()
	return Snap(size + LINE_LEAD)
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
	row.title:SetTextColor(Lumen.Color("questGold"))
	row.wash:SetVertexColor(Widgets.Rgba("white", row.hover and Tokens.Share("rowHover") or 0))
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
	Widgets.Fill(row.icon, row.socket, border, border, border, border)
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
		ns.QuestParty.Show(self, self.questID)
	end)
	row:SetScript("OnLeave", function(self)
		self.hover = false
		PaintTitle(self)
		Peek()
		ns.QuestParty.Hide(self)
	end)
	row:HookScript("OnHide", function(self) ns.QuestParty.Hide(self) end)
	row.wash = row:CreateTexture(nil, "BACKGROUND")
	row.wash:SetColorTexture(Tokens.Color("white"))
	row.wash:SetAllPoints(row)
	row.index = index
	row.disc = row:CreateTexture(nil, "ARTWORK")
	row.disc:SetTexture((Tokens.Texture("dot")))
	row.numeral = Widgets.FontString(row, "OVERLAY")
	Widgets.Point(row.numeral, "CENTER", row.disc, "CENTER", 0, 0)
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
	Widgets.Point(line.text, "TOPLEFT", row, "TOPLEFT", Gutter(), -Snap(y))
	line.text:SetWidth(math.max(room, 1))
	line.text:SetSpacing(lead)
	line.text:SetHeight(Snap(lines * pitch))
	line.text:SetMaxLines(lines)
	line.count:ClearAllPoints()
	local edge = right > 0 and -right or row.rail - Snap(1)
	Widgets.Point(line.count, "TOPRIGHT", row, "TOPRIGHT", edge, -Snap(y))
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
	if entry.complete or entry.failed then
		if not limit or titleH + LineHeight() <= limit then
			used = 1
			Line(row, 1, titleH, right, entry.complete and Ready() or Failed(), nil, entry.complete and "friend" or "hostile", Room(right), 1)
		end
	else
		local y = titleH
		for i = 1, entry.count do
			local objective = entry.objectives[i]
			local room = Room(right, objective)
			local lines = Lines(objective, room)
			if limit and lines > 1 then
				lines = math.max(1, math.min(lines, math.floor((limit - y - LineHeight()) / pitch) + 1))
			end
			Line(row, i, y, right, objective.text, objective.count, objective.done and "textDisabled" or "text", room, lines)
			if limit and Snap(y + Span(lines)) > limit then
				cut = entry.count - used
				break
			end
			used = i
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
	if row.questID ~= entry.id then ns.QuestParty.Hide(row) end
	row:ClearAllPoints()
	Widgets.Point(row, "TOPLEFT", view, "TOPLEFT", 0, -y)
	Widgets.Point(row, "TOPRIGHT", view, "TOPRIGHT", -right, -y)
	row:SetHeight(height)
	row.span = height
	row.rail = right
	row.limit = limit
	row.questID = entry.id
	row.item, row.logIndex = entry.item, entry.logIndex
	local titleH = TitleHeight()
	row.disc:ClearAllPoints()
	Widgets.Point(row.disc, "TOPLEFT", row, "TOPLEFT", Snap(Lumen.Size(card, DISC_LEAD)), -Snap((titleH - row.disc:GetHeight()) / 2))
	row.numeral:SetText(position)
	row.title:ClearAllPoints()
	Widgets.Point(row.title, "TOPLEFT", row, "TOPLEFT", Gutter(), 0)
	row.title:SetHeight(titleH)
	row.title:SetShown(not limit or limit >= titleH)
	row.disc:SetShown(not limit or limit >= titleH)
	row.numeral:SetShown(not limit or limit >= titleH)
	if entry.item then
		row.socket:ClearAllPoints()
		Widgets.Point(row.socket, "TOPRIGHT", row, "TOPRIGHT", 0, 0)
		row.icon:SetTexture(entry.icon)
		row.socket:Show()
		Widgets.Point(row.title, "TOPRIGHT", row.socket, "TOPLEFT", -Snap(SOCKET_GAP), 0)
	else
		row.socket:Hide()
		Widgets.Point(row.title, "TOPRIGHT", row, "TOPRIGHT", 0, 0)
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
	Widgets.Point(thumb, "TOPRIGHT", view, "TOPRIGHT", Snap(BAR_WIDTH + BAR_GAP), -Snap(y))
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
		Card.CheckDiagnostic()
		if not pending then
			pending = true
			K.Combat.Queue(AfterCombat)
		end
		return
	end
	local total = Data.Count()
	cap:SetCount(total)
	if total == 0 then
		for i = 1, #rows do
			rows[i]:Hide()
			rows[i].questID = nil
		end
		card:Hide()
		Card.SyncButtons()
		Card.CheckDiagnostic()
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
	local top, capHeight, capGap, foot = Snap(HEAD), Snap(CAP_ROW), Snap(CAP_GAP), Foot()
	local chrome = top + capHeight + capGap + foot + (over and MoreRow() or 0)
	local room = math.max(0, maxHeight - chrome)
	if not over and not Fits(Window(total, n, gap), room) then
		over = true
		chrome = chrome + MoreRow()
		right = Snap(BAR_WIDTH + BAR_GAP)
		rowWidth = (card:GetWidth() or 0) - 2 * inset - right
		for i = 1, total do
			heights[i] = Height(Data.Get(i))
		end
		room = math.max(0, maxHeight - chrome)
	end
	local compact = not Fits(heights[math.max(1, math.min(offset, total))], room)
	if compact then
		n = 1
		foot = Snap(COMPACT_PAD)
		capHeight, capGap = 0, 0
		chrome = top + foot + MoreRow() - Snap(ROW_GAP)
		room = math.max(0, maxHeight - chrome)
	end
	cap:SetShown(not compact)
	more:ClearAllPoints()
	Widgets.Point(more, "TOP", view, "BOTTOM", 0, -Snap(compact and 0 or ROW_GAP))
	Widgets.Point(more, "BOTTOM", card, "BOTTOM", 0, foot)
	local viewHeight = Snap(math.min(Window(total, n, gap), room))
	local fit = FitFromEnd(total, n, viewHeight, gap)
	offset = math.max(1, math.min(offset, total - fit + 1))
	local y, k, cut = 0, 0, 0
	local continuation = ns.Skins.Setting("quests", "continuation")
	while k < n + (continuation and not compact and 1 or 0) and offset + k <= total and y < viewHeight do
		local h = heights[offset + k]
		if k > 0 and (y >= viewHeight or not continuation and not Fits(y + h, viewHeight)) then
			break
		end
		k = k + 1
		local row = rows[k]
		local limit = not Fits(y + h, viewHeight) and viewHeight - y or nil
		cut = Bind(row, Data.Get(offset + k - 1), offset + k - 1, y, h, right, limit)
		row.clipped = not Fits(y + h, viewHeight)
		row.itemClipped = continuation and not Fits(y + Snap(SOCKET), viewHeight)
		y = y + h + gap
	end
	for i = k + 1, #rows do
		rows[i]:Hide()
		rows[i].questID = nil
	end
	cap:ClearAllPoints()
	Widgets.Point(cap, "TOPLEFT", card, "TOPLEFT", inset, -top)
	Widgets.Point(cap, "TOPRIGHT", card, "TOPRIGHT", -inset, -top)
	cap:SetHeight(capHeight)
	view:ClearAllPoints()
	Widgets.Point(view, "TOPLEFT", card, "TOPLEFT", inset, -(top + capHeight + capGap))
	Widgets.Point(view, "TOPRIGHT", card, "TOPRIGHT", -inset, -(top + capHeight + capGap))
	view:SetHeight(viewHeight)
	fade:SetShown(continuation and not compact and y - gap > viewHeight)
	local complete = k - (continuation and rows[k] and rows[k].clipped and 1 or 0)
	Bar(total, offset, math.max(1, complete), viewHeight)
	local above, below = offset - 1, total - (offset + complete - 1)
	if compact then
		local hint = above + below > 0 and MoreText(above, below) or cut > 0 and string.format(L["%d more"], cut) or ""
		more:SetText(L["Quests"] .. " " .. total .. (hint ~= "" and ": " .. hint or ""))
		more:Show()
	elseif over and above + below > 0 then
		more:SetText(MoreText(above, below))
		more:Show()
	elseif cut > 0 then
		more:SetText(string.format(L["%d more"], cut))
		more:Show()
	else
		more:SetText("")
		more:Hide()
	end
	card:SetHeight(Snap(chrome + viewHeight))
	card:Show()
	Card.CheckDiagnostic()
	if InCombatLockdown() then
		if not waiting then
			waiting = true
			K.Combat.Queue(SyncAfterCombat)
		end
		return
	end
	Card.SyncButtons()
	local rail = ns.RestedXP and ns.RestedXP.Rail
	if rail and rail.Schedule then
		rail.Schedule()
	end
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
		if card:IsShown() and row:IsShown() and row.item and not row.itemClipped then
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

function Card.Resize(height)
	if math.abs(maxHeight - height) > 0.01 then
		maxHeight = height
		Card.Render()
	end
	card:SetHeight(Snap(height))
end

function Card.Place(root, left, top, width, height)
	card:ClearAllPoints()
	Widgets.Point(card, "TOPLEFT", root, "BOTTOMLEFT", Widgets.Snap(card, left), Widgets.Snap(card, top))
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
	Widgets.TextColor(more, "muted")
	track:SetColorTexture(Widgets.Rgba("edgeBar", TRACK_ALPHA))
	track:SetWidth(Snap(BAR_WIDTH))
	track:ClearAllPoints()
	Widgets.Point(track, "TOPRIGHT", view, "TOPRIGHT", Snap(BAR_WIDTH + BAR_GAP), 0)
	Widgets.Point(track, "BOTTOMRIGHT", view, "BOTTOMRIGHT", Snap(BAR_WIDTH + BAR_GAP), 0)
	thumb:SetColorTexture(Widgets.Rgba("text", THUMB_ALPHA))
	thumb:SetWidth(Snap(BAR_WIDTH))
	PaintRest()
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
	cap = Lumen.SectionCap(card)
	cap:SetText(L["Quests"])
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
	more:SetJustifyH("CENTER")
	PaintRest()
	local shade = CreateFrame("Frame", nil, card)
	shade:SetFrameLevel(view:GetFrameLevel() + 4)
	Widgets.Point(shade, "BOTTOMLEFT", view, "BOTTOMLEFT")
	Widgets.Point(shade, "BOTTOMRIGHT", view, "BOTTOMRIGHT")
	shade:SetHeight(Snap(12))
	fade = shade:CreateTexture(nil, "OVERLAY")
	fade:SetAllPoints(shade)
	fade:SetTexture((Tokens.Texture("ruleFade")))
	fade:SetTexCoord(1, 0, 0, 0, 1, 1, 0, 1)
	Widgets.Tint(fade, "medFillBottom")
	for i = 1, MAX_SHOWN + 1 do
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
	return { card = card, glass = glass, cap = cap, view = view, more = more, track = track, thumb = thumb, fade = fade }
end

local function DiagnosticText(value)
	if Widgets.IsSecret(value) then
		return "<secret>"
	end
	local text = tostring(value)
	return #text > 80 and text:sub(1, 80) or text
end

local function DiagnosticRead(frame, method)
	if Widgets.IsSecret(frame) or type(frame) ~= "table" or type(frame[method]) ~= "function" then
		return "<unavailable>"
	end
	local ok, value = pcall(frame[method], frame)
	return ok and DiagnosticText(value) or "<unavailable>"
end

local function DiagnosticPart(label, frame)
	local fields = { "part=" .. label }
	local parentOK, parent = pcall(function() return frame:GetParent() end)
	fields[#fields + 1] = "parent=" .. (parentOK and DiagnosticRead(parent, "GetName") or "<unavailable>")
	for _, method in ipairs({ "GetName", "IsShown", "IsVisible", "GetAlpha", "GetEffectiveAlpha", "GetFrameStrata", "GetFrameLevel", "DoesClipChildren", "GetFlattensRenderLayers" }) do
		fields[#fields + 1] = method .. "=" .. DiagnosticRead(frame, method)
	end
	local ok, left, bottom, width, height = pcall(function()
		return frame:GetRect()
	end)
	fields[#fields + 1] = "rect=" .. (ok and table.concat({ DiagnosticText(left), DiagnosticText(bottom), DiagnosticText(width), DiagnosticText(height) }, ",") or "<unavailable>")
	K.DevTest.Log("Skins.Quests", table.concat(fields, " "))
end

function Card.Diagnose()
	local rxp = ns.RestedXP and ns.RestedXP.Addon()
	K.DevTest.Log("Skins.Quests", "combat=" .. DiagnosticText(InCombatLockdown()) .. " active=" .. DiagnosticText(active)
		.. " total=" .. DiagnosticText(Data.Count()) .. " offset=" .. DiagnosticText(offset) .. " wanted=" .. DiagnosticText(wanted)
		.. " maxHeight=" .. DiagnosticText(maxHeight) .. " rowWidth=" .. DiagnosticText(rowWidth)
		.. " pending=" .. DiagnosticText(pending) .. " waiting=" .. DiagnosticText(waiting)
		.. " watches=" .. DiagnosticText(Data.watches) .. " read=" .. DiagnosticText(Data.status)
		.. " style=" .. DiagnosticText(K.HudStyle.Current()) .. " guideIsShown=" .. DiagnosticRead(rxp and rxp.RXPFrame, "IsShown")
		.. ns.Quests.Diagnostic())
	DiagnosticPart("holder", card and card:GetParent())
	DiagnosticPart("card", card)
	DiagnosticPart("glass", glass)
	DiagnosticPart("cap", cap)
	DiagnosticPart("cap.title", cap and cap.label)
	DiagnosticPart("cap.count", cap and cap.count)
	DiagnosticPart("view", view)
	DiagnosticPart("more", more)
	local row = rows[1]
	DiagnosticPart("row.1", row)
	DiagnosticPart("row.1.title", row and row.title)
	DiagnosticPart("row.1.objective", row and row.lines[1].text)
	DiagnosticPart("row.1.count", row and row.lines[1].count)
	return true, "quest card render state recorded in devlog"
end

local automaticDiagnostics, diagnosticKeys = 0, {}

local function DiagnosticPixels(frame, clipLeft, clipBottom, clipWidth, clipHeight)
	local ok, visible = pcall(frame.IsVisible, frame)
	if not ok or Widgets.IsSecret(visible) then
		return nil
	end
	if not visible then
		return false
	end
	local alphaOK, alpha = pcall(frame.GetEffectiveAlpha, frame)
	if not alphaOK or Widgets.IsSecret(alpha) or type(alpha) ~= "number" then
		return nil
	end
	if alpha <= 0 then
		return false
	end
	local rectOK, left, bottom, width, height = pcall(frame.GetRect, frame)
	if not rectOK then
		return nil
	end
	if Widgets.IsSecret(left) or Widgets.IsSecret(bottom) or Widgets.IsSecret(width) or Widgets.IsSecret(height) then
		return nil
	end
	if type(left) ~= "number" or type(bottom) ~= "number" or type(width) ~= "number" or type(height) ~= "number" then
		return false
	end
	if width <= 0 or height <= 0 then
		return false
	end
	if clipLeft then
		return left < clipLeft + clipWidth and left + width > clipLeft and bottom < clipBottom + clipHeight and bottom + height > clipBottom
	end
	return true, left, bottom, width, height
end

function Card.CheckDiagnostic()
	if not active or not card or automaticDiagnostics >= 3 or (Data.Count() == 0 and not (Data.watches and Data.watches > 0)) then
		return
	end
	local clip, left, bottom, width, height = DiagnosticPixels(view)
	local measured, unknown = 0, clip == nil
	for _, row in ipairs(rows) do
		if row.questID then
			measured = measured + 1
			local pixels = clip and DiagnosticPixels(row, left, bottom, width, height)
			if pixels == nil then
				unknown = true
			elseif pixels then
				return
			end
		end
	end
	local reason = unknown and "measurement-unavailable" or "no-visible-rows"
	local key = reason .. ":" .. DiagnosticText(InCombatLockdown()) .. ":" .. DiagnosticText(Data.Count()) .. ":" .. DiagnosticText(maxHeight) .. ":" .. DiagnosticText(measured)
	if diagnosticKeys[key] then
		return
	end
	diagnosticKeys[key] = true
	automaticDiagnostics = automaticDiagnostics + 1
	K.DevTest.Log("Skins.Quests", "automatic=" .. reason .. " measuredRows=" .. measured .. " slotHeight=" .. DiagnosticText(maxHeight))
	Card.Diagnose()
end
