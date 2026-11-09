-- Strip.lua: the data strip: frame rate, latency, gold, durability and time as clickable texts on glass, each with a KstyleUI tooltip.
local _, ns = ...

local K, L = ns.K, ns.L
local Widgets, Tokens = K.Widgets, K.Tokens
local Format, Font, Sources = ns.Format, ns.Font, ns.Sources
local Call, IsNumber = Sources.Call, ns.IsNumber
local floor, ceil, max, min, abs, format = math.floor, math.ceil, math.max, math.min, math.abs, string.format

local Strip = {}
ns.Strip = Strip

local KEY = "databars.strip"
local SLOTS = 5
local TICK_SECONDS = 1
local LABEL_GAP = 6
local ROW_SHARE = 1.8
local SEPARATOR_SHARE = 0.4
local SEPARATOR_ALPHA = 0.35
local CAPTION_DROP = 2
local STACK_GAP = 1
local EDGE_BORDERS = 3
local CELL_EMS = 4
local MIN_GAP = 2
local CHAR_WIDTH_SHARE = 0.45
local VERTICAL_WIDTH = 160
local ROW_ASPECT = 3
local MIN_WIDTH, MIN_HEIGHT, MAX_WIDTH, MAX_HEIGHT = 40, 16, 1600, 800
local FPS_GOOD, FPS_OK = 60, 30
local MS_GOOD, MS_OK = 150, 300
local DURABILITY_GOOD, DURABILITY_OK = 50, 25

Strip.ITEMS = { "fps", "latency", "gold", "durability", "time" }
Strip.SLOTS = SLOTS

local LABELS = {
	fps = { full = L["Frame rate"], short = L["FPS"], inline = L["fps"] },
	latency = { full = L["Latency"], short = L["MS"], inline = L["ms"] },
	gold = { full = L["Gold"], short = "", inline = "" },
	durability = { full = L["Durability"], short = L["DUR"], inline = L["armour"] },
	time = { full = L["Time"], short = "", inline = "" },
}
local UNIT_GAP = 3
local MENU_GAP = 6
local LINE = 43
local MENU_PAD = 3
Strip.UNIT_GAP = UNIT_GAP

local CELL_WEIGHT = { fps = 0.8, latency = 1, gold = 1.6, durability = 1, time = 0.8 }

local TITLES = {
	fps = L["Frame rate"], latency = L["Latency"], gold = L["Gold"], durability = L["Durability"], time = L["Time"],
}

local GRADE_TOKEN = { good = "friendly", ok = "neutral", bad = "hostile" }
local HIGHLIGHTED = { fps = true }

local DURABILITY_SLOTS = {
	{ 1, L["Head"] }, { 3, L["Shoulder"] }, { 5, L["Chest"] }, { 6, L["Waist"] }, { 7, L["Legs"] }, { 8, L["Feet"] },
	{ 9, L["Wrist"] }, { 10, L["Hands"] }, { 16, L["Main hand"] }, { 17, L["Off hand"] }, { 18, L["Ranged"] },
}

local TIMED = { fps = true, latency = true, time = true }

local running = false
local ticker, ticking
local sessionStart

local function Grade(value, good, ok, higherIsBetter)
	if higherIsBetter then
		return value >= good and "good" or value >= ok and "ok" or "bad"
	end
	return value < good and "good" or value < ok and "ok" or "bad"
end

local function Latencies()
	local inBw, outBw, home, world = Call(GetNetStats)
	return IsNumber(home) and home or nil, IsNumber(world) and world or nil, IsNumber(inBw) and inBw or nil, IsNumber(outBw) and outBw or nil
end

local function Durabilities()
	local lowest
	if type(GetInventoryItemDurability) ~= "function" then
		return nil
	end
	for _, slot in ipairs(DURABILITY_SLOTS) do
		local current, most = Call(GetInventoryItemDurability, slot[1])
		if IsNumber(current) and IsNumber(most) and most > 0 then
			local percent = floor(current / most * 100)
			if not lowest or percent < lowest then
				lowest = percent
			end
		end
	end
	return lowest
end

local function Clock(s)
	if s.timeSource == "realm" then
		local hour, minute = Call(GetGameTime)
		if IsNumber(hour) and IsNumber(minute) then
			return hour, minute
		end
	end
	local hour, minute = tonumber((Call(date, "%H"))), tonumber((Call(date, "%M")))
	if IsNumber(hour) and IsNumber(minute) then
		return hour, minute
	end
	hour, minute = Call(GetGameTime)
	if IsNumber(hour) and IsNumber(minute) then
		return hour, minute
	end
end

local function Money()
	local money = Call(GetMoney)
	return IsNumber(money) and money or nil
end

local VALUES = {
	fps = function()
		local fps = Call(GetFramerate)
		if not IsNumber(fps) then
			return nil
		end
		local whole = floor(fps + 0.5)
		return tostring(whole), Grade(whole, FPS_GOOD, FPS_OK, true)
	end,
	latency = function(s)
		local home, world = Latencies()
		local ms = s.latency == "world" and world or home
		if not ms then
			return nil
		end
		if s.labels == "short" or s.labels == "inline" then
			return tostring(ms), Grade(ms, MS_GOOD, MS_OK)
		end
		return format(L["%d ms"], ms), Grade(ms, MS_GOOD, MS_OK)
	end,
	gold = function(s)
		local money = Money()
		return money and Format.Money(money, s.money) or nil
	end,
	durability = function()
		local lowest = Durabilities()
		if not lowest then
			return nil
		end
		return lowest .. "%", Grade(lowest, DURABILITY_GOOD, DURABILITY_OK, true)
	end,
	time = function(s)
		local hour, minute = Clock(s)
		if not hour then
			return nil
		end
		return Format.Clock(hour, minute, s.clock24)
	end,
}
Strip.VALUES = VALUES

local function TextWidth(text, fontSize)
	local value = text:GetText()
	local fallback = type(value) == "string" and #value * fontSize * CHAR_WIDTH_SHARE or 0
	return Widgets.TextWidth(text, fallback)
end

local function Order(s)
	local out, seen = {}, {}
	for i = 1, SLOTS do
		local id = s["slot" .. i]
		if VALUES[id] and not seen[id] then
			seen[id] = true
			out[#out + 1] = id
		end
	end
	return out
end
Strip.Order = Order

local function PaintItem(item)
	item.label:SetTextColor(Widgets.MixTokens("text", 1, "textHover", 1, item.button.hoverT or 0))
end

local function ValueColor(item, s, grade)
	local mode = s.valueColor
	if mode == "accent" then
		item.value:SetTextColor(ns.Accent())
	elseif mode == "threshold" and grade then
		Widgets.TextColor(item.value, GRADE_TOKEN[grade])
	elseif mode == "highlight" and grade and grade ~= "good" then
		Widgets.TextColor(item.value, GRADE_TOKEN[grade])
	elseif mode == "highlight" and grade == "good" and HIGHLIGHTED[item.id] then
		item.value:SetTextColor(ns.Accent())
	else
		Widgets.TextColor(item.value, "textEmphasis")
	end
end

local function NewItem(view, id)
	local button = CreateFrame("Button", nil, view.frame)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	local item = { id = id, button = button, view = view }
	button.kItem = item
	item.label = Widgets.FontString(button, "OVERLAY")
	item.value = Widgets.FontString(button, "OVERLAY")
	item.separator = view.frame:CreateTexture(nil, "ARTWORK")
	item.separator:SetColorTexture(Tokens.Color("white"))
	button.Paint = function()
		PaintItem(item)
	end
	Widgets.HookPointer(button)
	button:HookScript("OnHide", function()
		ns.Click.Release(item)
	end)
	return item
end

function Strip.NewView(parent)
	local frame = CreateFrame("Frame", nil, parent)
	local card = CreateFrame("Frame", nil, frame)
	card:SetFrameLevel(frame:GetFrameLevel())
	card:SetPoint("TOPLEFT", frame, "TOPLEFT")
	card:SetPoint("TOPRIGHT", frame, "TOPRIGHT")
	card:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
	local view = { frame = frame, card = card, items = {}, order = {}, values = {} }
	frame.kView = view
	view.chrome = Widgets.Chrome(card, { shape = "panel", fill = "surface" })
	frame:HookScript("OnHide", function()
		for _, item in pairs(view.items) do
			ns.Click.Release(item)
		end
	end)
	for _, id in ipairs(Strip.ITEMS) do
		view.items[id] = NewItem(view, id)
		view.values[id] = { false, false }
	end
	return view
end

local function Size(frame)
	local w, h = frame:GetWidth(), frame:GetHeight()
	return IsNumber(w) and w or 0, IsNumber(h) and h or 0
end

local function Pad(frame)
	return Widgets.Inset(frame, Tokens.Size("chamferPanel"))
end

local function CaptionSize(s)
	return max(Tokens.Size("caption"), s.fontSize - CAPTION_DROP)
end

local function Weight(order)
	local total = 0
	for _, id in ipairs(order) do
		total = total + CELL_WEIGHT[id]
	end
	return total
end

local function PlaceColumn(view, s, w, h, pad)
	local frame = view.frame
	local rowHeight = Widgets.Snap(frame, s.fontSize * ROW_SHARE)
	local labelGap = Widgets.Snap(frame, LABEL_GAP)
	local top = max(pad, (h - #view.order * rowHeight) / 2)
	for i, id in ipairs(view.order) do
		local item = view.items[id]
		local button = item.button
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -Widgets.Snap(frame, top + (i - 1) * rowHeight))
		button:SetSize(max(1, w - 2 * pad), rowHeight)
		item.label:SetShown(item.caption ~= "")
		local labelWidth = item.caption ~= "" and TextWidth(item.label, CaptionSize(s)) or 0
		item.label:ClearAllPoints()
		item.label:SetPoint("LEFT", button, "LEFT")
		item.label:SetWidth(max(1, labelWidth))
		item.label:SetJustifyH("LEFT")
		item.value:ClearAllPoints()
		item.value:SetPoint("RIGHT", button, "RIGHT")
		item.value:SetWidth(max(1, w - 2 * pad - labelWidth - (labelWidth > 0 and labelGap or 0)))
		item.value:SetJustifyH("RIGHT")
		item.separator:Hide()
	end
end

local function Captioned(view, s, h, cells, gap)
	local frame = view.frame
	local scale = K.Theme.FontScale()
	local caption, value = CaptionSize(s) * scale, s.fontSize * scale
	if s.labels == "none" or s.labels == "inline" or caption + value + 2 * STACK_GAP > h - 2 * EDGE_BORDERS * Widgets.Border(frame) then
		return false
	end
	for i, id in ipairs(view.order) do
		local item = view.items[id]
		if item.caption ~= "" and TextWidth(item.label, caption) > cells[i] - gap then
			return false
		end
	end
	return true
end

local function PlaceInline(item, s)
	local frame, button = item.view.frame, item.button
	local inner = item.inner or 1
	local unitGap = Widgets.Snap(frame, UNIT_GAP)
	local labelWidth = TextWidth(item.label, CaptionSize(s))
	local valueWidth = TextWidth(item.value, s.fontSize)
	item.value:ClearAllPoints()
	item.value:SetPoint("CENTER", button, "CENTER", -(labelWidth + unitGap) / 2, 0)
	item.value:SetWidth(max(1, min(inner, valueWidth + 2)))
	item.value:SetJustifyH("RIGHT")
	item.label:ClearAllPoints()
	item.label:SetPoint("LEFT", item.value, "RIGHT", unitGap, 0)
	item.label:SetWidth(max(1, labelWidth + 2))
	item.label:SetJustifyH("LEFT")
end

local function PlaceItems(view, s)
	local frame = view.frame
	local w, h = Size(frame)
	local pad = Pad(frame)
	if view.line and view.line < h then
		h = view.line
	end
	local order = view.order
	local total = Weight(order)
	view.contentWidth = Widgets.Snap(frame, total * CELL_EMS * s.fontSize)
	if s.orientation == "VERTICAL" then
		PlaceColumn(view, s, w, h, pad)
		return
	end
	local unit = total > 0 and max(0, w - 2 * pad) / total or 0
	local gap = Widgets.Snap(frame, max(MIN_GAP, s.spacing))
	local lefts, cells, used = {}, {}, 0
	for i, id in ipairs(order) do
		local x = Widgets.Snap(frame, pad + used * unit)
		used = used + CELL_WEIGHT[id]
		lefts[i], cells[i] = x, max(1, Widgets.Snap(frame, pad + used * unit) - x)
	end
	local captioned = Captioned(view, s, h, cells, gap)
	local stack = Widgets.Snap(frame, STACK_GAP)
	for i, id in ipairs(order) do
		local item = view.items[id]
		local button, separator = item.button, item.separator
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", frame, "TOPLEFT", lefts[i], 0)
		button:SetSize(cells[i], max(1, h))
		local inner = max(1, cells[i] - gap)
		local inline = s.labels == "inline" and item.caption ~= ""
		item.label:SetShown((captioned or inline) and item.caption ~= "")
		item.label:ClearAllPoints()
		item.value:ClearAllPoints()
		if inline then
			item.inner = inner
			PlaceInline(item, s)
		else
			item.inner = nil
			item.label:SetPoint("BOTTOM", button, "CENTER", 0, stack)
			item.label:SetWidth(inner)
			item.label:SetJustifyH("CENTER")
			if captioned then
				item.value:SetPoint("TOP", button, "CENTER", 0, -stack)
			else
				item.value:SetPoint("CENTER", button, "CENTER")
			end
			item.value:SetWidth(inner)
			item.value:SetJustifyH("CENTER")
		end
		separator:ClearAllPoints()
		separator:SetPoint("LEFT", button, "LEFT")
		separator:SetSize(Widgets.Border(frame), Widgets.Snap(frame, h * SEPARATOR_SHARE))
		separator:SetVertexColor(Widgets.Rgba("text", SEPARATOR_ALPHA))
		separator:SetShown(i > 1 and s.separators == true)
	end
end

local function SetValues(view, s, values, timedOnly)
	for _, id in ipairs(view.order) do
		if not timedOnly or TIMED[id] then
			local item, value = view.items[id], values[id]
			local text, grade = value and value[1], value and value[2]
			item.value:SetText(text or L["--"])
			ValueColor(item, s, grade or nil)
			if item.inner and s.labels == "inline" then
				PlaceInline(item, s)
			end
		end
	end
end

function Strip.Paint(view, s, values)
	local order = Order(s)
	view.order = order
	local inOrder = {}
	for _, id in ipairs(order) do
		inOrder[id] = true
	end
	view.chrome:SetShown(s.backdrop ~= false)
	if s.accentEdge then
		view.chrome:SetEdgeRGBA(ns.Accent())
	else
		view.chrome:SetEdge("edgeInner")
	end
	for id, item in pairs(view.items) do
		local on = inOrder[id] == true
		item.button:SetShown(on)
		if not on then
			ns.Click.Release(item)
			item.separator:Hide()
		else
			Font.Apply(item.label, s.font, CaptionSize(s), s.outline)
			Font.Apply(item.value, s.font, s.fontSize, s.outline)
			local label = s.labels ~= "none" and LABELS[id][s.labels] or ""
			item.caption = label
			item.label:SetText(label)
			item.label:SetWordWrap(false)
			item.value:SetWordWrap(false)
			PaintItem(item)
		end
	end
	SetValues(view, s, values)
	Strip.DockMenus(view, s)
	PlaceItems(view, s)
end

local DOCK = {
	micro = { "TOPLEFT", "TOPLEFT", 1 },
	bags = { "TOPRIGHT", "TOPRIGHT", -1 },
}
local MENU_MIN = 22
Strip.MENU_MIN = MENU_MIN

local function DockCount(Menus, id)
	local shown = #Menus.Shown(id)
	return shown > 0 and shown or #Menus.All(id)
end

local function RowsFor(count, tile, spacing, inner)
	if count == 0 then
		return 0
	end
	local perRow = max(1, floor((inner + spacing) / (tile + spacing)))
	return ceil(count / perRow)
end

local function BarHeight(rows, tile, spacing)
	if rows == 0 then
		return 0
	end
	return rows * tile + (rows - 1) * spacing + 2 * MENU_PAD
end

function Strip.MenuPlan(inner, counts, sizes, spacing, gap)
	local total = counts.micro + counts.bags
	local tile = min(sizes.micro, sizes.bags)
	local plan = { tile = tile, rows = { micro = 1, bags = 1 }, oneRow = false }
	if total == 0 then
		plan.height = 0
		return plan
	end
	local together = counts.micro > 0 and counts.bags > 0 and gap or 0
	local fit = floor((inner - together - (total - 1) * spacing) / total)
	if fit >= tile then
		plan.oneRow = true
	elseif fit >= MENU_MIN then
		plan.tile, plan.oneRow = fit, true
	end
	if plan.oneRow then
		plan.height = BarHeight(1, plan.tile, spacing)
		plan.rows.micro, plan.rows.bags = counts.micro > 0 and 1 or 0, counts.bags > 0 and 1 or 0
		return plan
	end
	plan.rows.micro = RowsFor(counts.micro, tile, spacing, inner)
	plan.rows.bags = RowsFor(counts.bags, tile, spacing, inner)
	plan.microHeight = BarHeight(plan.rows.micro, tile, spacing)
	plan.bagsHeight = BarHeight(plan.rows.bags, tile, spacing)
	local between = plan.rows.micro > 0 and plan.rows.bags > 0 and gap or 0
	plan.height = plan.microHeight + between + plan.bagsHeight
	return plan
end

local function Near(a, b)
	return IsNumber(a) and IsNumber(b) and abs(a - b) < 0.5
end

local function SetHeight(view, height)
	local layout = K.Layout.Get(KEY)
	if not layout or view ~= Strip.view or Near(layout.height, height) then
		return false
	end
	return K.Layout.Update(KEY, { width = layout.width, height = height }) == true
end

function Strip.DockMenus(view, s)
	local Menus = ns.Menus
	local frame, card = view.frame, view.card
	local docked = s.menus == true and Menus ~= nil and view == Strip.view and Menus.Holder("micro") ~= nil
	view.pad = Pad(frame)
	local pad, gap = view.pad, Widgets.Snap(frame, MENU_GAP)
	local line = Widgets.Snap(frame, LINE)
	if not docked then
		if Menus and view == Strip.view then
			for id in pairs(DOCK) do
				Menus.SetDock(id, nil)
			end
		end
		view.line, view.lineTop, view.wrapMenus = nil, nil, nil
		card:ClearAllPoints()
		card:SetAllPoints(frame)
		return
	end
	local w = Size(frame)
	local settings = ns.Settings()
	local plan = Strip.MenuPlan(w - 2 * pad, { micro = DockCount(Menus, "micro"), bags = DockCount(Menus, "bags") },
		{ micro = settings.micro.size, bags = settings.bags.size }, Widgets.Snap(frame, settings.micro.spacing), gap)
	view.wrapMenus = not plan.oneRow
	local rowTop = -(pad + line + gap)
	local height = pad + line + gap + plan.height + pad
	view.line = line
	view.lineTop = nil
	for id, spec in pairs(DOCK) do
		local drop = (not plan.oneRow and id == "bags") and (plan.microHeight + gap) or 0
		Menus.SetDock(id, function(content, width, contentHeight)
			content:ClearAllPoints()
			content:SetPoint(spec[1], frame, spec[2], spec[3] * pad, rowTop - drop)
			content:SetSize(width, contentHeight)
		end, frame, plan.tile, plan.rows[id] > 0 and plan.rows[id] or nil)
	end
	card:ClearAllPoints()
	card:SetAllPoints(frame)
	if not SetHeight(view, height) and not Near(frame:GetHeight(), height) then
		frame:SetHeight(height)
	end
end

local function Read(view, s, timedOnly)
	local values = view.values
	for _, id in ipairs(view.order) do
		if not timedOnly or TIMED[id] then
			local slot = values[id]
			local text, grade = VALUES[id](s)
			slot[1], slot[2] = text or false, grade or false
		end
	end
	return values
end

local function Tooltip(item, tip)
	local id, s = item.id, ns.Settings().strip
	tip:AddTitle(TITLES[id])
	if id == "fps" then
		local fps = Call(GetFramerate)
		tip:AddDoubleLine(L["Frame rate"], IsNumber(fps) and format(L["%d fps"], floor(fps + 0.5)) or L["--"])
		tip:AddDivider()
		tip:AddLine(L["Click: open the data bar settings."], "text")
	elseif id == "latency" then
		local home, world, inBw, outBw = Latencies()
		tip:AddDoubleLine(L["Home"], home and format(L["%d ms"], home) or L["--"])
		tip:AddDoubleLine(L["World"], world and format(L["%d ms"], world) or L["--"])
		if inBw and outBw then
			tip:AddDoubleLine(L["Bandwidth"], format(L["%.1f KB/s in, %.1f KB/s out"], inBw, outBw))
		end
		tip:AddDivider()
		tip:AddLine(s.latency == "world" and L["Click: show home latency."] or L["Click: show world latency."], "text")
	elseif id == "gold" then
		local money = Money()
		tip:AddDoubleLine(L["Gold"], money and Format.Money(money, "full") or L["--"])
		if money and sessionStart then
			tip:AddDoubleLine(L["This session"], Format.Money(money - sessionStart, "full"))
		end
		if ns.Click.Target("gold") then
			tip:AddDivider()
			tip:AddLine(InCombatLockdown() and L["Bags open from here out of combat."] or L["Click: open your bags."], "text")
		end
	elseif id == "durability" then
		local any = false
		if type(GetInventoryItemDurability) == "function" then
			for _, slot in ipairs(DURABILITY_SLOTS) do
				local current, most = Call(GetInventoryItemDurability, slot[1])
				if IsNumber(current) and IsNumber(most) and most > 0 then
					any = true
					tip:AddDoubleLine(slot[2], floor(current / most * 100) .. "%")
				end
			end
		end
		if not any then
			tip:AddLine(L["Nothing you wear can break."], "textDisabled")
		end
		if ns.Click.Target("durability") then
			tip:AddDivider()
			tip:AddLine(InCombatLockdown() and L["Your character opens from here out of combat."] or L["Click: open your character."], "text")
		end
	elseif id == "time" then
		local now = Call(date, "*t")
		if type(now) == "table" and IsNumber(now.hour) and IsNumber(now.min) then
			tip:AddDoubleLine(L["Local time"], Format.Clock(now.hour, now.min, s.clock24))
		end
		local hour, minute = Call(GetGameTime)
		if IsNumber(hour) and IsNumber(minute) then
			tip:AddDoubleLine(L["Realm time"], Format.Clock(hour, minute, s.clock24))
		end
		local today = Call(date, L["%A %d %B"])
		if type(today) == "string" then
			tip:AddLine(today, "text")
		end
		tip:AddDivider()
		if ns.Click.Target("time") then
			tip:AddLine(InCombatLockdown() and L["The calendar opens from here out of combat."] or L["Click: open the calendar."], "text")
		end
		tip:AddLine(L["Right-click: switch between 12 and 24 hours."], "text")
	end
end

function Strip.ShowTooltip(item)
	local tip = Widgets.Tooltip()
	tip:SetOwner(item.button, "ANCHOR_TOP")
	K.Call(Tooltip, item, tip)
	tip:Show()
end

function Strip.HideTooltip(item)
	local tip = Widgets.Tooltip()
	if tip:IsOwned(item.button) then
		tip:Hide()
	end
end

local function Toggle(key, a, b)
	local current = K.Options.Read(ns.MODULE, key)
	K.Options.Write(ns.MODULE, key, current == a and b or a)
end

local ACTIONS = {
	fps = function(_, mouse)
		if mouse ~= "RightButton" then
			K.Options.Open(ns.MODULE)
		end
	end,
	latency = function(_, mouse)
		if mouse ~= "RightButton" then
			Toggle("strip.latency", "world", "home")
		end
	end,
	time = function(_, mouse)
		if mouse == "RightButton" then
			K.Options.Write(ns.MODULE, "strip.clock24", not K.Options.Read(ns.MODULE, "strip.clock24"))
		end
	end,
}
Strip.ACTIONS = ACTIONS

local function OnEnter(button)
	local item = button.kItem
	Strip.ShowTooltip(item)
	ns.Click.Attach(item)
end

local function OnLeave(button)
	local item = button.kItem
	if not ns.Click.Covers(item) then
		Strip.HideTooltip(item)
	end
end

local function OnClick(button, mouse)
	local action = ACTIONS[button.kItem.id]
	if action then
		action(button.kItem, mouse)
	end
end

function Strip.Update(timedOnly)
	local view = Strip.view
	if not view or not running then
		return
	end
	local s = ns.Settings().strip
	timedOnly = timedOnly == true
	SetValues(view, s, Read(view, s, timedOnly), timedOnly)
end

function Strip.Tick()
	Strip.Update(true)
end

function Strip.Refresh()
	local view = Strip.view
	if not view or not running then
		return
	end
	local s = ns.Settings().strip
	view.order = Order(s)
	Strip.order = view.order
	Strip.Paint(view, s, Read(view, s))
end

local function NeedsTicker(s)
	for _, id in ipairs(Order(s)) do
		if TIMED[id] then
			return true
		end
	end
	return false
end

local function StopTicker()
	if ticker then
		ticker:Cancel()
		ticker = nil
	end
	if ticking and Strip.view then
		Strip.view.frame:SetScript("OnUpdate", nil)
		ticking = false
	end
end

local function StartTicker()
	StopTicker()
	if not running or not NeedsTicker(ns.Settings().strip) then
		return
	end
	if type(C_Timer) == "table" and type(C_Timer.NewTicker) == "function" then
		ticker = C_Timer.NewTicker(TICK_SECONDS, Strip.Tick)
		return
	end
	ns.LogOnce("strip-ticker", "C_Timer.NewTicker is missing; the strip counts seconds with OnUpdate")
	local elapsed = 0
	ticking = true
	Strip.view.frame:SetScript("OnUpdate", function(_, dt)
		elapsed = elapsed + dt
		if elapsed >= TICK_SECONDS then
			elapsed = 0
			Strip.Tick()
		end
	end)
end

local function Footprint()
	local layouts = K.Setup and K.Setup.Layouts
	local element = layouts and layouts.Element(KEY)
	if element then
		return element.width, element.height, element.label, layouts.Default(KEY)
	end
	ns.LogOnce("footprint:" .. KEY, KEY .. " has no footprint in Setup.Layouts; using the fallback size and position")
	return 430, 36, KEY, { anchor = "BOTTOMRIGHT", x = -16, y = 16 }
end

local function Build()
	local view = Strip.NewView(K.Scale.Root())
	local frame = view.frame
	local width, height, label, position = Footprint()
	frame:SetSize(width, height)
	for _, item in pairs(view.items) do
		item.button:HookScript("OnEnter", OnEnter)
		item.button:HookScript("OnLeave", OnLeave)
		item.button.onClick = OnClick
	end
	K.Layout.Register(frame, KEY, position, {
		label = label, module = ns.MODULE, resizable = true,
		minWidth = MIN_WIDTH, minHeight = MIN_HEIGHT, maxWidth = MAX_WIDTH, maxHeight = MAX_HEIGHT,
	})
	Strip.view = view
	return view
end

local function MatchOrientation(s, changed)
	local layout = K.Layout.Get(KEY)
	if not layout then
		return
	end
	local vertical = s.orientation == "VERTICAL"
	if vertical and (changed or layout.width >= ROW_ASPECT * layout.height) then
		local rows = max(1, #Order(s))
		K.Layout.Update(KEY, { width = VERTICAL_WIDTH, height = Widgets.Snap(Strip.view.frame, rows * s.fontSize * ROW_SHARE + 2 * Pad(Strip.view.frame)) })
	elseif not vertical and (changed or layout.height > layout.width) then
		local width, height = Footprint()
		K.Layout.Update(KEY, { width = width, height = height })
	end
end

function Strip.Enable()
	running = true
	if not sessionStart then
		sessionStart = Money()
	end
	local view = Strip.view or Build()
	view.frame:Show()
	MatchOrientation(ns.Settings().strip, false)
	Strip.Refresh()
	StartTicker()
end

function Strip.Disable()
	running = false
	StopTicker()
	ns.Click.Detach()
	if Strip.view then
		for _, item in pairs(Strip.view.items) do
			Strip.HideTooltip(item)
		end
		Strip.view.frame:Hide()
	end
end

function Strip.Setting(key)
	local field = key:match("^strip%.(.+)$")
	if not field and key ~= "accentSource" and key ~= "accentColor" then
		return
	end
	local s = ns.Settings().strip
	if field == "orientation" then
		MatchOrientation(s, true)
	end
	Strip.Refresh()
	if field and field:match("^slot%d$") then
		StartTicker()
	end
end

ns.Listen("PLAYER_MONEY", Strip.Update)
ns.Listen("UPDATE_INVENTORY_DURABILITY", Strip.Update)
ns.Listen("PLAYER_EQUIPMENT_CHANGED", Strip.Update)
ns.Listen("PLAYER_ENTERING_WORLD", Strip.Update)

ns.Subscribe("LayoutChanged", function(key)
	if key == KEY and running then
		Strip.Refresh()
	end
end)

ns.AddPart({
	Enable = Strip.Enable,
	Disable = Strip.Disable,
	Setting = Strip.Setting,
	Refresh = function()
		Strip.Refresh()
		StartTicker()
	end,
})
