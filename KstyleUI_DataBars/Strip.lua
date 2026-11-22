-- Strip.lua: the data strip: frame rate, latency, gold, durability and time as clickable texts, one right-aligned line by default or cells on glass, each with a KstyleUI tooltip.
local _, ns = ...

local K, L = ns.K, ns.L
local Widgets, Tokens = K.Widgets, K.Tokens
local Format, Font, Sources = ns.Format, ns.Font, ns.Sources
local Call, IsNumber = Sources.Call, ns.IsNumber
local floor, ceil, max, min, abs, format = math.floor, math.ceil, math.max, math.min, math.abs, string.format

local Strip = {}
ns.Strip = Strip

local KEY, KEY2 = "databars.strip", "databars.strip2"
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
local CHAR_WIDTH_SHARE = 0.6
local VERTICAL_WIDTH = 160
local ROW_ASPECT = 3
local MIN_WIDTH, MIN_HEIGHT, MAX_WIDTH, MAX_HEIGHT = 40, 8, 1600, 800
local FPS_GOOD, FPS_OK = 60, 30
local MS_GOOD, MS_OK = 150, 300
local DURABILITY_GOOD, DURABILITY_OK = 50, 25


local LABELS = {
	fps = { full = L["Frame rate"], short = L["FPS"], inline = L["fps"] },
	latency = { full = L["Latency"], short = L["MS"], inline = L["ms"] },
	gold = { full = L["Gold"], short = "", inline = "" },
	durability = { full = L["Durability"], short = L["DUR"], inline = L["armour"] },
	time = { full = L["Time"], short = "", inline = "" },
}
Strip.LABELS = LABELS
local UNIT_GAP = 2
local MENU_GAP = 6
local LINE = 12
local CELL_LINE = 30
local CELLS_HEIGHT = 42
local DOT_GAP_EM = 1 / 3
local LINE_LIFT = 1
local DOT = "\194\183"
local MENU_PAD = 3
local GLYPHS = "Interface\\AddOns\\KstyleUI_DataBars\\Media\\Glyphs.png"
local GLYPH_COLUMNS, GLYPH_ROWS = 4, 8
local GLYPH_CELLS = { fps = 0, latency = 1, gold = 2, durability = 3, time = 4, spec = 5, hearth = 6, guild = 7, friends = 8, bags = 9, currencies = 10, xp = 11, location = 12, itemLevel = 13,
	coords = 14, combat = 15, played = 16, audio = 17, prof1 = 18, prof2 = 21, broker = 19, reagents = 20 }
local SEGMENT_PAD, GLYPH_GAP, GLYPH_SHARE = 4, 3, 1.1
local PLATE_RISE, PLATE_DROP, RULE_SHARE, RULE_ALPHA, HOVER_ALPHA = 2, 4, 0.7, 0.45, 0.14
Strip.UNIT_GAP = UNIT_GAP
Strip.DOT_GAP_EM = DOT_GAP_EM
Strip.LINE = LINE
Strip.COMPACT = LINE
Strip.GLYPH_CELLS = GLYPH_CELLS

local CELL_WEIGHT = { fps = 0.8, latency = 0.9, gold = 1.4, durability = 1.25, time = 0.85 }

local TITLES = {
	fps = L["Frame rate"], latency = L["Latency"], gold = L["Gold"], durability = L["Durability"], time = L["Time"],
}

Strip.TITLES = TITLES
Strip.TOOLTIPS, Strip.TOOLTIP_EXTRA = {}, {}
local GRADE_TOKEN = { good = "friendly", ok = "neutral", bad = "hostile" }
local HIGHLIGHTED = { fps = true }

local DURABILITY_SLOTS = {
	{ 1, L["Head"] }, { 3, L["Shoulder"] }, { 5, L["Chest"] }, { 6, L["Waist"] }, { 7, L["Legs"] }, { 8, L["Feet"] },
	{ 9, L["Wrist"] }, { 10, L["Hands"] }, { 16, L["Main hand"] }, { 17, L["Off hand"] }, { 18, L["Ranged"] },
}

local TIMED = { fps = true, latency = true, time = true }
Strip.TIMED = TIMED
local WIDTH = {}
Strip.WIDTH = WIDTH

local function LineMode(s)
	return s.line ~= false and s.orientation ~= "VERTICAL"
end
Strip.LineMode = LineMode

function Strip.OneLine(s)
	return s.placement ~= "rail" or LineMode(s)
end

local running = false
local fpsReady = true
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
			local percent = Format.Percent(current, most)
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
	local hour, minute = Call(date, "%H"), Call(date, "%M")
	if ns.IsSecret(hour) or ns.IsSecret(minute) then return end
	hour, minute = tonumber(hour), tonumber(minute)
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
		local fps = fpsReady and Call(GetFramerate) or nil
		if not IsNumber(fps) then
			return nil
		end
		local whole = floor(fps + 0.5)
		return tostring(whole), Grade(whole, FPS_GOOD, FPS_OK, true)
	end,
	latency = function(s)
		local home, world = Latencies()
		local ms = home
		if s.latency == "world" then ms = world end
		if not ms then
			return nil
		end
		if s.labels == "short" or s.labels == "inline" or (s.labels ~= "none" and LineMode(s)) then
			return tostring(ms), Grade(ms, MS_GOOD, MS_OK)
		end
		return format(L["%d ms"], ms), Grade(ms, MS_GOOD, MS_OK)
	end,
	gold = function(s)
		local money = Money()
		if not sessionStart then sessionStart = money end
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

function Strip.Modules(s)
	return s.placement == "rail" and s.railModules or s.dockModules
end

local function Order(s)
	local out, seen = {}, {}
	for _, entry in ipairs(Strip.Modules(s)) do
		local id = entry.id
		if entry.shown and VALUES[id] and not seen[id] and (not ns.Readouts or ns.Readouts.Visible(id, s)) then
			seen[id] = true
			out[#out + 1] = id
		end
	end
	return out
end
Strip.Order = Order

local function Block(s, id)
	local block = GLYPH_CELLS[id] and type(s.blocks) == "table" and s.blocks[id]
	return type(block) == "table" and block or nil
end

local function Shows(s, id)
	if not GLYPH_CELLS[id] then return false, false end
	local block = Block(s, id)
	local mode = block and block.show or "bar"
	if mode == "bar" then return s.icons == "beside" or s.icons == "only", s.icons == "only" end
	return mode ~= "value", mode == "icon"
end

Strip.Shows = Shows

local function Glyph(parent, id)
	local icon = parent:CreateTexture(nil, "OVERLAY")
	local index = GLYPH_CELLS[id] or 0
	local col, row = index % GLYPH_COLUMNS, floor(index / GLYPH_COLUMNS)
	icon:SetTexture(GLYPHS)
	icon:SetTexCoord(col / GLYPH_COLUMNS, (col + 1) / GLYPH_COLUMNS, row / GLYPH_ROWS, (row + 1) / GLYPH_ROWS)
	return icon
end

local function PaintItem(item)
	local view = item.view
	local s, t = view.s or {}, item.button.hoverT or 0
	if s.hover == false then t = 0 end
	if item.icon and view.deco then
		item.icon:SetVertexColor(Widgets.MixTokens("medTextMuted", 1, "giltLit", 1, t))
		item.hover:SetAlpha(t * HOVER_ALPHA)
	end
	local c = s.labelCustom and not view.slab and not view.docked and s.labelColor
	local r, g, b, a
	if type(c) == "table" then
		local hr, hg, hb = Widgets.Rgba("textHover", 1)
		r, g, b, a = Widgets.Mix(c.r, c.g, c.b, 1, hr, hg, hb, 1, t)
	else
		r, g, b, a = Widgets.MixTokens(view.slab and "medTextMuted" or (view.docked or Widgets.Readability("worldText")) and "labelMuted" or "text", 1, "textHover", 1, t)
	end
	item.label:SetTextColor(r, g, b, a)
	if item.iconOn and not view.deco then
		local block = Block(s, item.id)
		local own = block and block.iconColor ~= "bar" and block.iconColor
		local mode, custom = not view.docked and (own or s.iconColor), own and block.iconCustom or s.iconCustom
		if mode == "accent" then
			r, g, b = ns.Accent()
		elseif mode == "custom" and type(custom) == "table" then
			r, g, b = custom.r, custom.g, custom.b
		end
		item.icon:SetVertexColor(r, g, b)
	end
end

local function ValueColor(item, s, grade)
	local mode = s.valueColor
	if grade == "low" then
		Widgets.TextColor(item.value, "hostile")
	elseif item.view.slab then
		Widgets.TextColor(item.value, "medTextMuted")
	elseif item.view.docked then
		Widgets.TextColor(item.value, "labelMuted")
	elseif mode == "custom" and type(s.valueCustom) == "table" then
		item.value:SetTextColor(s.valueCustom.r, s.valueCustom.g, s.valueCustom.b)
	elseif mode == "accent" then
		item.value:SetTextColor(ns.Accent())
	elseif mode == "threshold" and grade then
		Widgets.TextColor(item.value, GRADE_TOKEN[grade])
	elseif mode == "highlight" and grade and grade ~= "good" then
		Widgets.TextColor(item.value, GRADE_TOKEN[grade])
	elseif mode == "highlight" and grade == "good" and HIGHLIGHTED[item.id] then
		item.value:SetTextColor(ns.Accent())
	else
		Widgets.TextColor(item.value, item.view.lineMode and "text" or "textEmphasis")
	end
end

local function NewItem(view, id)
	local button = CreateFrame("Button", nil, view.frame)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	local item = { id = id, button = button, view = view }
	button.kItem = item
	item.label = Widgets.FontString(button, "OVERLAY")
	item.value = Widgets.FontString(button, "OVERLAY")
	item.dot = Widgets.FontString(view.frame, "OVERLAY")
	item.dot:SetText(DOT)
	item.separator = view.frame:CreateTexture(nil, "ARTWORK")
	item.separator:SetColorTexture(Tokens.Color("white"))
	if id == "spacer" then button:EnableMouse(false) end
	button.Paint = function()
		PaintItem(item)
	end
	Widgets.HookPointer(button)
	button:HookScript("OnHide", function()
		ns.Click.Release(item)
	end)
	return item
end

local function TopBar(view)
	if view.zones then return end
	local frame = view.frame
	view.zones = {}
	for _, zone in ipairs({ "left", "centre", "right" }) do
		local holder = CreateFrame("Frame", nil, frame)
		holder:SetAllPoints(frame)
		view.zones[zone] = holder
	end
end

function Strip.NewView(parent)
	local frame = CreateFrame("Frame", nil, parent)
	local card = CreateFrame("Frame", nil, frame)
	card:SetFrameLevel(frame:GetFrameLevel())
	Widgets.Point(card, "TOPLEFT", frame, "TOPLEFT")
	Widgets.Point(card, "TOPRIGHT", frame, "TOPRIGHT")
	Widgets.Point(card, "BOTTOM", frame, "BOTTOM", 0, 0)
	local view = { frame = frame, card = card, items = {}, order = {}, values = {} }
	frame.kView = view
	view.chrome = Widgets.Chrome(card, { shape = "panel", fill = "surface" })
	frame:HookScript("OnHide", function()
		view.visible = false
		if ns.Readouts and view == Strip.view then ns.Readouts.Sync(false) elseif ns.Readouts and view == Strip.second then ns.Readouts.Sync() end
		for _, item in pairs(view.items) do
			ns.Click.Release(item)
		end
	end)
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
		total = total + (CELL_WEIGHT[id] or 1)
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
		Widgets.Point(button, "TOPLEFT", frame, "TOPLEFT", pad, -Widgets.Snap(frame, top + (i - 1) * rowHeight))
		button:SetSize(max(1, w - 2 * pad), rowHeight)
		item.label:SetShown(item.caption ~= "")
		local labelWidth = item.caption ~= "" and TextWidth(item.label, CaptionSize(s)) or 0
		item.label:ClearAllPoints()
		Widgets.Point(item.label, "LEFT", button, "LEFT")
		item.label:SetWidth(max(1, labelWidth))
		item.label:SetJustifyH("LEFT")
		item.value:ClearAllPoints()
		Widgets.Point(item.value, "RIGHT", button, "RIGHT")
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

local function Labels(id, s)
	local labels = LABELS[id]
	return type(labels) == "function" and labels(s) or labels
end

local function FitCaption(item, s, valueWidth, unitGap)
	local label = item.label
	local room = (item.cell or item.inner or 1) - 2 * MIN_GAP
	local labels = Labels(item.id, s)
	for _, form in ipairs({ labels.inline, labels.short, "" }) do
		if form == "" then
			return form, 0
		end
		label:SetText(form)
		local width = TextWidth(label, CaptionSize(s))
		if valueWidth + unitGap + width <= room then
			return form, width
		end
	end
	return "", 0
end

local function PlaceInline(item, s)
	local frame, button = item.view.frame, item.button
	local unitGap = Widgets.Snap(frame, UNIT_GAP)
	local valueWidth = TextWidth(item.value, s.fontSize)
	local caption, labelWidth = FitCaption(item, s, valueWidth, unitGap)
	item.caption = caption
	item.label:SetText(caption)
	item.label:SetShown(caption ~= "")
	if caption == "" then
		labelWidth, unitGap = 0, 0
	end
	item.value:ClearAllPoints()
	local side = ((item.cell or 0) - (item.inner or 0)) / 2
	if s.align == "LEFT" then
		Widgets.Point(item.value, "LEFT", button, "LEFT", Widgets.Snap(item.value, side), 0)
	elseif s.align == "RIGHT" then
		Widgets.Point(item.value, "RIGHT", button, "RIGHT", -Widgets.Snap(item.value, side + labelWidth + unitGap), 0)
	else
		Widgets.Point(item.value, "CENTER", button, "CENTER", Widgets.Snap(item.value, -(labelWidth + unitGap) / 2), 0)
	end
	item.value:SetWidth(Widgets.Snap(item.value, max(1, valueWidth + 2)))
	item.value:SetJustifyH("RIGHT")
	item.label:ClearAllPoints()
	Widgets.Point(item.label, "LEFT", item.value, "RIGHT", unitGap, 0)
	item.label:SetWidth(Widgets.Snap(item.label, max(1, labelWidth + 2)))
	item.label:SetJustifyH("LEFT")
end

local function CompactGold(item, s)
	if item.id ~= "gold" or s.money ~= "full" or not item.cell then
		return
	end
	local full = item.view.values[item.id]
	if full and full[1] then
		item.value:SetText(full[1])
	end
	local room = item.cell - 2 * MIN_GAP
	if TextWidth(item.value, s.fontSize) <= room then
		return
	end
	local money = Money()
	if money then
		item.value:SetText(Format.Money(money, "gold"))
	end
end

local function Rule(texture, anchor, relative, point, h)
	texture:ClearAllPoints()
	Widgets.Point(texture, "CENTER", anchor, point, 0, Widgets.Snap(texture, (PLATE_RISE - PLATE_DROP) / 2) - relative)
	Widgets.Size(texture, Widgets.Border(texture), Widgets.Snap(texture, (h + PLATE_RISE + PLATE_DROP) * RULE_SHARE))
	texture:SetVertexColor(Widgets.Rgba("gilt", RULE_ALPHA))
	texture:Show()
end

local function Segment(view, item, rule, glyph, glyphGap, h, icons)
	local button = item.button
	item.separator:Hide()
	local on, was = icons == true, item.iconOn
	item.iconOn = on
	if icons and not item.icon then
		item.icon, item.hover = Glyph(button, item.id), button:CreateTexture(nil, "BACKGROUND")
		item.hover:SetColorTexture(Tokens.Color("giltLit"))
		PaintItem(item)
	elseif on and not was then
		PaintItem(item)
	end
	if not item.icon then return end
	item.icon:SetShown(on)
	item.hover:SetShown(view.deco)
	if not icons then return end
	item.icon:ClearAllPoints()
	Widgets.Point(item.icon, "RIGHT", item.value, "LEFT", -glyphGap, 0)
	Widgets.Size(item.icon, glyph, glyph)
	if not view.deco then return end
	item.hover:ClearAllPoints()
	local border = Widgets.Border(button)
	Widgets.Point(item.hover, "TOPLEFT", button, "TOPLEFT", 0, Widgets.Snap(button, PLATE_RISE) - border)
	Widgets.Point(item.hover, "BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, border - Widgets.Snap(button, PLATE_DROP))
	if rule then Rule(item.separator, button, 0, "LEFT", h) end
end

local function CaptionSegment(view, on, rule, glyph, glyphGap, h)
	if not view.xpGlyph then
		if not on then return end
		view.xpGlyph = Glyph(view.frame, "xp")
		view.xpRule = view.frame:CreateTexture(nil, "ARTWORK")
		view.xpRule:SetColorTexture(Tokens.Color("white"))
	end
	view.xpGlyph:SetShown(on)
	view.xpRule:Hide()
	if not on then return end
	local text = view.slab.text
	view.xpGlyph:ClearAllPoints()
	Widgets.Point(view.xpGlyph, "RIGHT", text, "LEFT", -glyphGap, 0)
	Widgets.Size(view.xpGlyph, glyph, glyph)
	Widgets.Tint(view.xpGlyph, "medTextMuted")
	if rule then Rule(view.xpRule, view.zones.right, Widgets.Snap(view.frame, h / 2), "TOPRIGHT", h) end
end

local function PlaceLine(view, s)
	local frame = view.frame
	local _, h = Size(frame)
	if view.line and view.line < h then
		h = view.line
	end
	local edge = view.slab and 0 or (view.bare and 0 or Pad(frame))
	local unitGap, lift = Widgets.Snap(frame, UNIT_GAP), Widgets.Snap(frame, LINE_LIFT)
	local order = view.order
	local step = K.Scale.Pixel(1) / Widgets.ScaleFactor(frame)
	local dotSize = s.fontSize * K.Theme.FontScale()
	local sample = order[1] and view.items[order[1]]
	if sample and sample.dot.GetFont then
		local _, size = sample.dot:GetFont()
		if IsNumber(size) and size > 0 then
			dotSize = size
		end
	end
	local padding = Widgets.Snap(frame, IsNumber(s.padding) and s.padding or 0)
	local dotGap = Widgets.DotGap(dotSize, step, DOT_GAP_EM) + padding
	local seg = view.deco
	local pad = seg and Widgets.Snap(frame, SEGMENT_PAD) + padding or 0
	local glyph = Widgets.Snap(frame, dotSize * GLYPH_SHARE)
	local glyphGap = Widgets.Snap(frame, GLYPH_GAP)
	local glyphRun = glyph + glyphGap
	local x = edge + (view.rail and Widgets.Snap(frame, EDGE_BORDERS) or 0)
	local positions, widths, zones = {}, { left = 0, centre = 0, right = 0 }, {}
	local limits, hidden, last = {}, { left = {}, right = {} }, {}
	local captionGap = LABEL_GAP
	if view.slab then
		local layouts = K.Setup.Layouts
		local left = layouts.ActionBarFootprint(K.Scale.Aspect(), "actionbars.bar1")
		local right = layouts.ActionBarFootprint(K.Scale.Aspect(), "actionbars.bar2")
		local ratio = frame:GetWidth() / (left + right + layouts.MEDALLIONS_HUB_GAP)
		view.wingLeft, view.wingRight = left * ratio, right * ratio
		limits.left = max(0, view.wingLeft - LABEL_GAP)
		captionGap = seg and glyphRun + pad or sample and TextWidth(sample.dot, dotSize) + 2 * dotGap or LABEL_GAP
		limits.right = max(0, view.wingRight - LABEL_GAP - (view.slab.text:IsVisible() and TextWidth(view.slab.text, dotSize) + captionGap or 0))
	elseif view.rail then
		limits.right = max(0, frame:GetWidth() - 2 * edge - EDGE_BORDERS)
	end
	local signature = { tostring(view.slab), tostring(view.deco), tostring(view.docked), frame:GetWidth(), h, edge, unitGap, lift, dotGap, step, limits.left or 0, limits.right or 0 }
	for _, entry in ipairs(Strip.Modules(s) or {}) do zones[entry.id] = widths[entry.zone] and entry.zone or "right" end
	for _, id in ipairs(order) do
		local item = view.items[id]
		local icon, bare = GLYPH_CELLS[id] ~= nil, false
		if not seg then icon, bare = Shows(s, id) end
		local label = not bare and item.caption ~= "" and TextWidth(item.label, s.fontSize) or 0
		local value = bare and 0 or WIDTH[id] and WIDTH[id](s) or TextWidth(item.value, s.fontSize)
		local width = Widgets.Snap(frame, value + (label > 0 and unitGap + label or 0)) + (icon and (bare and glyph or glyphRun) or 0) + 2 * pad
		if item.bare ~= bare then
			item.bare = bare
			item.value:SetShown(not bare)
		end
		local zone = zones[id] or "right"
		if view.rail then zone = "right" end
		if view.slab and zone == "centre" then zone = "left" end
		local joined = widths[zone] > 0 and id ~= "spacer" and last[zone] ~= "spacer"
		local gap = joined and not seg and Widgets.Snap(frame, TextWidth(item.dot, s.fontSize) + 2 * dotGap) or 0
		local overflow = (view.slab or view.rail) and (#hidden[zone] > 0 or widths[zone] + gap + width + 2 > limits[zone])
		positions[id] = { zone, widths[zone] + gap, width, joined, value, label, overflow, icon }
		if overflow then
			hidden[zone][#hidden[zone] + 1] = id
		else
			widths[zone] = widths[zone] + gap + width
			last[zone] = id
		end
		signature[#signature + 1] = id .. ":" .. zone .. ":" .. value .. ":" .. label .. (icon and ":i" or "") .. (bare and "b" or "")
	end
	signature = table.concat(signature, "|")
	if view.lineLayout == signature then return end
	view.lineLayout = signature
	if view.slab then
		view.zones.right:ClearAllPoints()
		Widgets.Point(view.zones.right, "TOPRIGHT", view.slab.text:IsVisible() and view.slab.text or frame, view.slab.text:IsVisible() and "TOPLEFT" or "TOPRIGHT", -(view.slab.text:IsVisible() and captionGap or LABEL_GAP), 0)
		Widgets.Point(view.zones.right, "BOTTOMLEFT", frame, "BOTTOMLEFT")
	end
	for _, item in pairs(view.items) do item.hiddenReadouts = nil end
	for zone, ids in pairs(hidden) do
		if last[zone] and #ids > 0 then view.items[last[zone]].hiddenReadouts = ids end
	end
	for i = #order, 1, -1 do
		local item = view.items[order[i]]
		local button = item.button
		local position = positions[item.id]
		local valueWidth, labelWidth, width = position[5], position[6], position[3]
		local run = pad + (position[8] and glyphRun or 0)
		item.valueWidth = valueWidth
		item.overflow = position[7]
		button:SetShown(not item.overflow)
		item.cell, item.inner = nil, nil
		button:ClearAllPoints()
		if view.slab then
			local zone, offset = position[1], position[2]
			local anchor = zone == "centre" and "TOP" or zone == "left" and "TOPLEFT" or "TOPRIGHT"
			local start = zone == "centre" and -widths[zone] / 2 or zone == "left" and edge - (seg and pad - padding or 0) or -edge - widths[zone] - (view.slab and 2 or 0)
			Widgets.Point(button, "TOPLEFT", view.zones[zone], anchor, Widgets.Snap(frame, start + offset), 0)
		else
			Widgets.Point(button, "TOPRIGHT", frame, "TOPRIGHT", -Widgets.Snap(frame, x), 0)
		end
		Widgets.Size(button, max(1, width), max(1, h))
		item.value:ClearAllPoints()
		Widgets.Point(item.value, view.slab and "TOPLEFT" or "LEFT", button, view.slab and "TOPLEFT" or "LEFT", run, view.slab and 0 or lift)
		item.value:SetWidth(Widgets.Snap(item.value, max(1, valueWidth + 2)))
		item.value:SetJustifyH("LEFT")
		item.label:SetShown(labelWidth > 0)
		item.label:ClearAllPoints()
		Widgets.Point(item.label, view.slab and "TOPLEFT" or "LEFT", button, view.slab and "TOPLEFT" or "LEFT", run + Widgets.Snap(button, valueWidth + unitGap), view.slab and 0 or lift)
		item.label:SetWidth(Widgets.Snap(item.label, max(1, labelWidth + 2)))
		item.label:SetJustifyH("LEFT")
		local follows = view.slab and position[4] or not view.slab and i > 1 and order[i] ~= "spacer" and order[i - 1] ~= "spacer"
		Segment(view, item, seg and not item.overflow and follows, glyph, glyphGap, h, position[8])
		if not item.overflow then x = x + width end
		local captionDot = not seg and view.slab and position[1] == "right" and position[2] == 0 and view.slab.text:IsVisible()
		local dot = not seg and not item.overflow and (captionDot or follows)
		item.dot:SetShown(dot)
		if dot then
			local dotWidth = TextWidth(item.dot, s.fontSize)
			item.dot:ClearAllPoints()
			Widgets.Point(item.dot, view.slab and "TOP" or "CENTER", captionDot and view.slab.text or button, view.slab and "TOPLEFT" or "LEFT", -(dotWidth / 2 + dotGap), view.slab and 0 or lift)
			item.dot:SetWidth(Widgets.Snap(item.dot, max(1, dotWidth + 2)))
			item.dot:SetJustifyH("CENTER")
			x = x + Widgets.Snap(frame, dotWidth + 2 * dotGap)
		end
	end
	view.contentWidth = Widgets.Snap(frame, x - edge)
	CaptionSegment(view, seg and view.slab ~= nil and view.slab.text:IsVisible(), widths.right > 0, glyph, glyphGap, h)
	if view.docked then
		if view.dockWidth ~= view.contentWidth then
			frame:SetWidth(view.contentWidth)
			view.dockWidth = view.contentWidth
		end
		view.docked:ReserveTitle(view.contentWidth + Widgets.Snap(frame, LABEL_GAP))
	end
end

local function PlaceItems(view, s)
	local frame = view.frame
	local w, h = Size(frame)
	local pad = Pad(frame)
	if view.line and view.line < h then
		h = view.line
	end
	local order = view.order
	if view.lineMode then
		PlaceLine(view, s)
		return
	end
	view.lineLayout = nil
	for _, item in pairs(view.items) do
		item.dot:Hide()
		Segment(view, item)
		if item.bare then
			item.bare = nil
			item.value:Show()
		end
	end
	CaptionSegment(view, false)
	local total = Weight(order)
	view.contentWidth = Widgets.Snap(frame, total * CELL_EMS * s.fontSize)
	if s.orientation == "VERTICAL" then
		for _, id in ipairs(order) do
			view.items[id].cell = nil
		end
		PlaceColumn(view, s, w, h, pad)
		return
	end
	local unit = total > 0 and max(0, w - 2 * pad) / total or 0
	local gap = Widgets.Snap(frame, max(MIN_GAP, s.spacing))
	local lefts, cells, used = {}, {}, 0
	local natural, rest = CELL_EMS * s.fontSize, nil
	for _, id in ipairs(order) do
		if id == s.fill then rest = max(0, w - 2 * pad) - (total - (CELL_WEIGHT[id] or 1)) * natural end
	end
	if rest and rest <= (CELL_WEIGHT[s.fill] or 1) * natural then rest = nil end
	for i, id in ipairs(order) do
		local x = Widgets.Snap(frame, pad + (rest and used or used * unit))
		used = used + (rest and (id == s.fill and rest or (CELL_WEIGHT[id] or 1) * natural) or CELL_WEIGHT[id] or 1)
		lefts[i], cells[i] = x, max(1, Widgets.Snap(frame, pad + (rest and used or used * unit)) - x)
	end
	local captioned = Captioned(view, s, h, cells, gap)
	local stack = Widgets.Snap(frame, STACK_GAP)
	for i, id in ipairs(order) do
		local item = view.items[id]
		local button, separator = item.button, item.separator
		button:ClearAllPoints()
		Widgets.Point(button, "TOPLEFT", frame, "TOPLEFT", lefts[i], 0)
		button:SetSize(cells[i], max(1, h))
		local inner = max(1, cells[i] - gap)
		local inline = s.labels == "inline" and Labels(id, s).inline ~= ""
		item.label:SetShown((captioned or inline) and item.caption ~= "")
		item.label:ClearAllPoints()
		item.value:ClearAllPoints()
		item.cell = cells[i]
		CompactGold(item, s)
		if inline then
			item.inner = inner
			PlaceInline(item, s)
		else
			item.inner = nil
			Widgets.Point(item.label, "BOTTOM", button, "CENTER", 0, stack)
			item.label:SetWidth(inner)
			item.label:SetJustifyH(s.align or "CENTER")
			if captioned then
				Widgets.Point(item.value, "TOP", button, "CENTER", 0, -stack)
			else
				Widgets.Point(item.value, "CENTER", button, "CENTER")
			end
			item.value:SetWidth(Widgets.Snap(item.value, max(inner, TextWidth(item.value, s.fontSize) + 2)))
			item.value:SetJustifyH(s.align or "CENTER")
		end
		separator:ClearAllPoints()
		Widgets.Point(separator, "LEFT", button, "LEFT")
		separator:SetSize(Widgets.Border(frame), Widgets.Snap(frame, h * SEPARATOR_SHARE))
		separator:SetVertexColor(Widgets.Rgba("text", SEPARATOR_ALPHA))
		separator:SetShown(i > 1 and s.separators == true)
	end
end

local function SetValues(view, s, values, only, force)
	local place = false
	for _, id in ipairs(view.order) do
		if not only or only == id or only == true and TIMED[id] then
			local item, value = view.items[id], values[id]
			local text, grade = value and value[1], value and value[2]
			text = text or L["--"]
			if force or item.grade ~= grade then
				item.grade = grade
				ValueColor(item, s, grade or nil)
			end
			if force or item.text ~= text then
				item.text = text
				item.value:SetText(text)
				CompactGold(item, s)
				local width = WIDTH[id] and WIDTH[id](s) or TextWidth(item.value, s.fontSize)
				if force or item.valueWidth ~= width then
					item.valueWidth = width
					if view.lineMode then
						item.inner, place = nil, true
					elseif item.inner and s.labels == "inline" then
						PlaceInline(item, s)
					elseif item.inner == nil and s.orientation ~= "VERTICAL" then
						local w = item.value:GetWidth()
						item.value:SetWidth(Widgets.Snap(item.value, max(IsNumber(w) and w or 1, width + 2)))
					end
				end
			end
		end
	end
	if place and not force then
		PlaceLine(view, s)
	end
end

local function Layer(view, strata, level)
	view.frame:SetFrameStrata(strata)
	for _, frame in ipairs({ view.frame, view.card, view.wingCard }) do frame:SetFrameLevel(level) end
end

function Strip.Paint(view, s, values)
	local order = Order(s)
	view.order, view.s = order, s
	view.rail = s.placement == "rail" and not view.docked
	local plate, wings = view.deco, view.deco and view.slab ~= nil
	if wings and not view.wing then
		view.wingCard = CreateFrame("Frame", nil, view.frame)
		view.wing = Widgets.Chrome(view.wingCard, { shape = "panel", fill = "surface" })
	end
	view.lineMode = plate or view.slab ~= nil or LineMode(s)
	view.bare = view.slab ~= nil or view.lineMode and s.backdrop == false
	local inOrder = {}
	for _, id in ipairs(order) do
		inOrder[id] = true
		if not view.items[id] then
			view.items[id] = NewItem(view, id)
			if view.bind then view.bind(view.items[id]) end
		end
	end
	for _, chrome in ipairs({ view.chrome, view.wing }) do
		chrome.materialOn = not (plate and s.artwork == "plain")
		chrome.shadowOn = not plate
		chrome:SetShown(chrome == view.wing and wings or chrome == view.chrome and (plate or not view.slab and s.backdrop ~= false))
		if plate then
			local r, g, b = Tokens.Color("surface")
			chrome:SetFillRGBA(r, g, b, (s.background or 85) / 100)
		else
			chrome:SetFill("surface")
		end
		if s.accentEdge then
			chrome:SetEdgeRGBA(ns.Accent())
		else
			chrome:SetEdge("edgeInner")
		end
	end
	local caption = view.slab and ns.Bars.Settings(view.slab)
	local f = caption or s
	local size = f.fontSize
	local fontSize = size * K.Theme.FontScale()
	for id, item in pairs(view.items) do
		local on = inOrder[id] == true
		item.button:SetShown(on and not item.overflow)
		if not on then
			item.grade, item.overflow = nil, nil
			ns.Click.Release(item)
			item.separator:Hide()
			item.dot:Hide()
		else
			if item.font ~= f.font or item.fontSize ~= fontSize or item.outline ~= f.outline or item.lineMode ~= view.lineMode or item.slab ~= view.slab or item.instrument ~= f.instrumentText then
				if view.slab then
					Font.Caption(item.label, caption, caption.medal)
					Font.Caption(item.value, caption, caption.medal)
					Font.Caption(item.dot, caption, caption.medal)
				else
					Font.Apply(item.label, s.font, view.lineMode and size or CaptionSize(s), s.outline)
					Font.Apply(item.value, s.font, size, s.outline)
					Font.Apply(item.dot, s.font, size, s.outline)
				end
				item.font, item.fontSize, item.outline, item.lineMode = f.font, fontSize, f.outline, view.lineMode
				item.slab, item.instrument = view.slab, f.instrumentText
			end
			Widgets.TextColor(item.dot, view.slab and "medTextMuted" or view.lineMode and "text" or "textEmphasis")
			item.dot:SetWordWrap(false)
			local label = s.labels ~= "none" and Labels(id, s)[view.lineMode and "inline" or s.labels] or ""
			item.caption = label
			item.label:SetText(label)
			item.label:SetWordWrap(false)
			item.value:SetWordWrap(false)
			PaintItem(item)
		end
	end
	local force = view.paintColor ~= s.valueColor or view.paintDock ~= view.docked or view.paintLine ~= view.lineMode
	SetValues(view, s, values, nil, force)
	view.paintColor, view.paintDock, view.paintLine = s.valueColor, view.docked, view.lineMode
	if not view.combat then Strip.DockMenus(view, s) end
	PlaceItems(view, s)
	if wings then
		local frame, holder, pad = view.frame, view.slab.holder, Widgets.Snap(view.frame, SEGMENT_PAD)
		local strata, level = holder:GetFrameStrata(), holder:GetFrameLevel()
		if not ns.IsSecret(strata) and not ns.IsSecret(level) then
			view.layer = view.layer or { frame:GetFrameStrata(), frame:GetFrameLevel() }
			Layer(view, strata, max(0, level - 2))
		end
		view.card:ClearAllPoints()
		Widgets.Point(view.card, "TOPLEFT", frame, "TOPLEFT", -pad, PLATE_RISE)
		Widgets.Point(view.card, "BOTTOMRIGHT", frame, "BOTTOMLEFT", Widgets.Snap(frame, view.wingLeft), -PLATE_DROP)
		view.wingCard:ClearAllPoints()
		Widgets.Point(view.wingCard, "TOPRIGHT", frame, "TOPRIGHT", pad, PLATE_RISE)
		Widgets.Point(view.wingCard, "BOTTOMLEFT", frame, "BOTTOMRIGHT", -Widgets.Snap(frame, view.wingRight), -PLATE_DROP)
	elseif view.layer then
		Layer(view, view.layer[1], view.layer[2])
		view.layer = nil
	end
	for _, item in pairs(view.items) do
		Widgets.TextScrim(item.label, view.bare and item.button:IsShown() and item.label:IsShown())
		Widgets.TextScrim(item.value, view.bare and item.button:IsShown() and not item.bare)
	end
end

local DOCK = {
	micro = { "TOPRIGHT", "TOPRIGHT", -1 },
	bags = { "TOPRIGHT", "TOPRIGHT", -1 },
}
local MENU_MIN = 22
Strip.MENU_MIN = MENU_MIN

local function DockCount(Menus, id)
	if not Menus.Visible(id) then
		return 0
	end
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
		plan.height, plan.oneRow = 0, true
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

local dockQueued = false

local function DockAfterCombat()
	if dockQueued then
		return
	end
	dockQueued = true
	K.Combat.Queue(function()
		dockQueued = false
		Strip.Refresh()
	end)
end

function Strip.DockMenus(view, s)
	local Menus = ns.Menus
	local frame, card = view.frame, view.card
	local docked = s.enabled ~= false and not view.slab and s.menus == true and Menus ~= nil and view == Strip.view and Menus.Holder("micro") ~= nil
	view.pad = view.bare and 0 or Pad(frame)
	local pad, gap = view.pad, Widgets.Snap(frame, MENU_GAP)
	local line = Widgets.Snap(frame, view.lineMode and LINE or CELL_LINE)
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
	local bagCount = DockCount(Menus, "bags")
	local plan = Strip.MenuPlan(w - 2 * pad, { micro = DockCount(Menus, "micro"), bags = bagCount },
		{ micro = settings.micro.size, bags = settings.bags.size }, Widgets.Snap(frame, settings.micro.spacing), gap)
	local height = plan.height > 0 and (line + gap + plan.height + pad) or (view.lineMode and line or line + pad)
	if InCombatLockdown() and not Near(frame:GetHeight(), height) then
		DockAfterCombat()
		return
	end
	view.wrapMenus = not plan.oneRow
	local rowTop = -(line + gap)
	local bagGap = Widgets.Snap(frame, settings.bags.spacing)
	local beside = plan.oneRow and bagCount > 0 and (bagCount * plan.tile + (bagCount - 1) * bagGap + 2 * MENU_PAD + gap) or 0
	view.line = plan.height > 0 and line or nil
	view.lineTop = nil
	for id, spec in pairs(DOCK) do
		local drop = (not plan.oneRow and id == "bags") and (plan.microHeight + gap) or 0
		local shift = id == "micro" and beside or 0
		Menus.SetDock(id, function(content, width, contentHeight)
			content:ClearAllPoints()
			Widgets.Point(content, spec[1], frame, spec[2], spec[3] * (pad + shift), rowTop - drop)
			content:SetSize(width, contentHeight)
		end, frame, plan.tile, plan.rows[id] > 0 and plan.rows[id] or nil)
	end
	card:ClearAllPoints()
	card:SetAllPoints(frame)
	if not SetHeight(view, height) and not Near(frame:GetHeight(), height) then
		frame:SetHeight(height)
	end
end

local reads = 0
local function Read(view, s, only, shared)
	local values = view.values
	for _, id in ipairs(view.order) do
		if not only or only == id or only == true and TIMED[id] then
			local slot, from = values[id] or {}, shared and shared[id]
			values[id] = slot
			if from and from[3] == reads then
				slot[1], slot[2] = from[1], from[2]
			else
				local text, grade = VALUES[id](s)
				slot[1], slot[2] = text or false, grade or false
			end
			slot[3] = reads
		end
	end
	return values
end

local function Tooltip(item, tip)
	local id, s = item.id, ns.Settings().strip
	tip:AddTitle(TITLES[id])
	if Strip.TOOLTIPS[id] then
		Strip.TOOLTIPS[id](item, tip)
		return
	end
	if id == "fps" then
		local fps = fpsReady and Call(GetFramerate) or nil
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
		if money and sessionStart and s.goldSession ~= false then
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
					tip:AddDoubleLine(slot[2], Format.Percent(current, most) .. "%")
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
		if not ns.IsSecret(now) and type(now) == "table" and IsNumber(now.hour) and IsNumber(now.min) then
			tip:AddDoubleLine(L["Local time"], Format.Clock(now.hour, now.min, s.clock24))
		end
		local hour, minute = Call(GetGameTime)
		if IsNumber(hour) and IsNumber(minute) then
			tip:AddDoubleLine(L["Realm time"], Format.Clock(hour, minute, s.clock24))
		end
		local today = Call(date, L["%A %d %B"])
		if not ns.IsSecret(today) and type(today) == "string" then
			tip:AddLine(today, "text")
		end
		tip:AddDivider()
		if ns.Click.Target("time") then
			tip:AddLine(InCombatLockdown() and L["The calendar opens from here out of combat."] or L["Click: open the calendar."], "text")
		end
		tip:AddLine(L["Right-click: switch between 12 and 24 hours."], "text")
	end
	if Strip.TOOLTIP_EXTRA[id] then Strip.TOOLTIP_EXTRA[id](item, tip) end
end

function Strip.ShowTooltip(item)
	local tip = Widgets.Tooltip()
	tip:SetOwner(item.button, "ANCHOR_TOP")
	K.Call(Tooltip, item, tip)
	if item.hiddenReadouts then
		tip:AddDivider()
		tip:AddLine(L["Hidden readouts"], "textEmphasis")
		for _, id in ipairs(item.hiddenReadouts) do
			local value = VALUES[id](ns.Settings().strip)
			tip:AddDoubleLine(TITLES[id], value or L["--"])
		end
	end
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

local secondBase, secondSettings
local function SecondSettings(s)
	if secondBase ~= s then
		secondBase, secondSettings = s, setmetatable({ placement = "rail", orientation = "HORIZONTAL" }, { __index = s })
	end
	secondSettings.railModules = s.secondModules
	return secondSettings
end
Strip.SecondSettings = SecondSettings

function Strip.Update(only)
	if not running then return end
	reads = reads + 1
	local view, s, shared = Strip.view, ns.Settings().strip, nil
	if view and view.visible ~= false and s.enabled ~= false then
		shared = Read(view, s, only)
		SetValues(view, s, shared, only)
	end
	view = Strip.second
	if view and view.visible then
		local second = SecondSettings(s)
		SetValues(view, second, Read(view, second, only, LineMode(s) == LineMode(second) and shared), only)
	end
end

function Strip.Tick()
	fpsReady = true
	Strip.Update(true)
end

local function DockMeter(view, s)
	local side = K.Safe.Side(K.Scale.Root())
	local meter = side.meterCards and side.meterCards["meters.damage"]
	local layout = K.Layout.Get(KEY)
	local element = K.Layout.Element(KEY)
	local default = element and element.default
	local on = not K.Setup.Layouts.DataBarDock() and s.enabled ~= false and s.dockMeter ~= false and LineMode(s) and not s.menus and meter and meter.holder:IsVisible() and meter.cap.frame:IsShown() and layout and default and layout.anchor == default.anchor and layout.x == default.x and layout.y == default.y and not K.Layout.IsActive()
	if on then
		meter:ReserveTitle((view.contentWidth or 0) + Widgets.Snap(view.frame, LABEL_GAP))
		local width = math.max(1, view.contentWidth or 1)
		if view.docked == meter and view.dockWidth == width then return false end
		local changed = view.docked ~= meter
		view.frame:ClearAllPoints()
		Widgets.Point(view.frame, "RIGHT", meter.column, "LEFT", -LABEL_GAP, 0)
		Widgets.Size(view.frame, width, LINE)
		view.docked, view.dockWidth = meter, width
		return changed
	elseif view.docked then
		view.docked:ReserveTitle(nil)
		view.docked, view.dockWidth = nil, nil
		view.frame:ClearAllPoints()
		view.frame:SetPoint(layout.anchor, K.Scale.Root(), layout.anchor, layout.x, layout.y)
		view.frame:SetSize(layout.width, layout.height)
		return true
	end
	return false
end

local function DockInk(view)
	if view.docked then
		for _, item in pairs(view.items) do
			Widgets.TextColor(item.label, "labelMuted")
			Widgets.TextColor(item.value, item.grade == "low" and "hostile" or "labelMuted")
			Widgets.TextColor(item.dot, "labelMuted")
		end
	end
end

local function PaintSecond(s)
	local view = Strip.second
	if not (view and view.visible) then return end
	local second = SecondSettings(s)
	view.order = Order(second)
	Strip.Paint(view, second, Read(view, second))
end

local function Footprint(key)
	local layouts = K.Setup and K.Setup.Layouts
	local element = layouts and layouts.Element(key)
	if element then
		return element.width, element.height, element.label, layouts.Default(key)
	end
	ns.LogOnce("footprint:" .. key, key .. " has no footprint in Setup.Layouts; using the fallback size and position")
	return 278, LINE, key, { anchor = "BOTTOMRIGHT", x = -17, y = 180 }
end

local function Register(frame, key)
	local width, height, label, position = Footprint(key)
	frame:SetSize(width, height)
	K.Layout.Register(frame, key, position, {
		label = label, module = ns.MODULE, resizable = true,
		minWidth = MIN_WIDTH, minHeight = MIN_HEIGHT, maxWidth = max(MAX_WIDTH, K.Layout.RootSize()), maxHeight = MAX_HEIGHT,
	})
end

local function RefreshSecond()
	local s = ns.Settings().strip
	local on = running and s.second == true
	local view = Strip.second
	if on and not view then
		local holder = CreateFrame("Frame", nil, K.Scale.Root())
		view = Strip.NewView(holder)
		view.frame:SetAllPoints(holder)
		view.bind = Strip.view.bind
		Register(holder, KEY2)
		Strip.second = view
		holder:HookScript("OnShow", RefreshSecond)
		holder:HookScript("OnHide", RefreshSecond)
	end
	if not view then return end
	K.Layout.SetLive(KEY2, on)
	view.frame:SetShown(on)
	view.visible = on and view.frame:IsVisible()
	PaintSecond(s)
	ns.Readouts.Sync()
end

local function RefreshMain()
	local view = Strip.view
	local s = ns.Settings().strip
	if s.enabled == false then
		K.Layout.SetLive(KEY, false)
		ns.Readouts.Sync(false)
		if ns.Menus then ns.Menus.SetDock("micro", nil) ns.Menus.SetDock("bags", nil) end
		return
	end
	view.order = Order(s)
	Strip.order = view.order
	DockMeter(view, s)
	local xp = ns.Bars and ns.Bars.views.xp
	local dock = K.Setup.Layouts.DataBarDock()
	K.Layout.SetLive(KEY, s.enabled ~= false and not dock)
	view.slab = dock and xp or nil
	view.deco = view.slab ~= nil
	if view.slab then
		TopBar(view)
		view.frame:ClearAllPoints()
		Widgets.Point(view.frame, "TOPLEFT", xp.holder, "BOTTOMLEFT", 0, -3)
		Widgets.Size(view.frame, xp.holder:GetWidth(), LINE)
		view.zones.left:SetAllPoints(view.frame)
		view.zones.centre:SetAllPoints(view.frame)
	elseif view.zones then
		for _, zone in pairs(view.zones) do zone:SetAllPoints(view.frame) end
	end
	view.visible = view.frame:IsVisible()
	if not view.visible then ns.Readouts.Sync(false) return end
	Strip.Paint(view, s, Read(view, s))
	DockInk(view)
	ns.Readouts.Sync(true)
end

function Strip.Refresh()
	if not Strip.view or not running then
		return
	end
	if InCombatLockdown() then DockAfterCombat() return end
	RefreshMain()
	RefreshSecond()
end

function Strip.Reorder()
	local view, s = Strip.view, ns.Settings().strip
	if not InCombatLockdown() then return Strip.Refresh() end
	if view and running and view.visible and s.enabled ~= false then
		view.order, view.combat = Order(s), true
		Strip.Paint(view, s, Read(view, s))
		view.combat = nil
		DockInk(view)
	else
		DockAfterCombat()
	end
	PaintSecond(s)
end

function Strip.Dock()
	local view = Strip.view
	if view and running and DockMeter(view, ns.Settings().strip) then
		Strip.Refresh()
	end
end

local function NeedsTicker(s)
	for _, list in ipairs({ s.enabled ~= false and Strip.Modules(s) or {}, s.second and s.secondModules or {} }) do
		for _, entry in ipairs(list) do
			if entry.shown and TIMED[entry.id] then
				return true
			end
		end
	end
	return false
end

local function StopTicker()
	if ticker then
		ticker:Cancel()
		ticker = nil
	end
	if ticking then ticking:SetScript("OnUpdate", nil) end
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
	ticking = ticking or CreateFrame("Frame", nil, K.Scale.Root())
	ticking:SetScript("OnUpdate", function(_, dt)
		elapsed = elapsed + dt
		if elapsed >= TICK_SECONDS then
			elapsed = 0
			Strip.Tick()
		end
	end)
end

local function Build()
	local view = Strip.NewView(K.Scale.Root())
	local frame = view.frame
	view.bind = function(item)
		item.button:HookScript("OnEnter", OnEnter)
		item.button:HookScript("OnLeave", OnLeave)
		item.button.onClick = OnClick
	end
	Register(frame, KEY)
	Strip.view = view
	frame:HookScript("OnShow", Strip.Refresh)
	K.Safe.Side(K.Scale.Root()).dockDataStrip = Strip.Dock
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
		local width, height = Footprint(KEY)
		K.Layout.Update(KEY, { width = width, height = LineMode(s) and height or max(height, CELLS_HEIGHT) })
	end
end

local function MatchLine(s)
	local layout = K.Layout.Get(KEY)
	if not layout or s.orientation == "VERTICAL" then
		return
	end
	local _, height = Footprint(KEY)
	K.Layout.Update(KEY, { width = layout.width, height = LineMode(s) and height or max(layout.height, CELLS_HEIGHT) })
end

function Strip.Enable()
	running = true
	ns.FillModules(ns.Settings().strip)
	local view = Strip.view or Build()
	view.frame:Show()
	local s = ns.Settings().strip
	MatchOrientation(s, false)
	if not LineMode(s) then
		MatchLine(s)
	end
	Strip.Refresh()
	StartTicker()
end

function Strip.Disable()
	running = false
	StopTicker()
	ns.Click.Detach()
	if InCombatLockdown() then
		K.Combat.Queue(function() if not running then Strip.Disable() end end)
		return
	end
	if Strip.view then
		if ns.Menus then ns.Menus.SetDock("micro", nil) ns.Menus.SetDock("bags", nil) end
		DockMeter(Strip.view, { line = false, orientation = "VERTICAL" })
		for _, item in pairs(Strip.view.items) do
			Strip.HideTooltip(item)
		end
		Strip.view.frame:Hide()
	end
	if Strip.second then Strip.second.frame:Hide() end
end

function Strip.Setting(key)
	if key:match("^xp%.") then Strip.Refresh() return end
	local field = key:match("^strip%.(.+)$")
	if not field and key ~= "accentSource" and key ~= "accentColor" then
		return
	end
	local s = ns.Settings().strip
	if not field or field == "valueCustom" then
		for _, view in ipairs({ Strip.view, Strip.second }) do view.paintColor = nil end
	end
	if field == "second" and s.second then
		local any = false
		for _, entry in ipairs(s.secondModules) do any = any or entry.shown end
		if not any then
			local copy = {}
			for _, entry in ipairs(Strip.Modules(s)) do
				if entry.id ~= "micro" then copy[#copy + 1] = { id = entry.id, shown = entry.shown, zone = entry.zone } end
			end
			K.Options.Write(ns.MODULE, "strip.secondModules", copy)
		end
	end
	if field == "placement" and s.placement == "rail" then
		K.Options.Write(ns.MODULE, "strip.menus", false)
		MatchLine(s)
	end
	if field == "orientation" then
		MatchOrientation(s, true)
	elseif field == "line" then
		MatchLine(s)
	end
	Strip.Refresh()
	if field and field:find("^hearth") then ns.Click.Refresh() end
	if field == "dockModules" or field == "railModules" or field == "secondModules" or field == "second" or field == "enabled" or field == "placement" then
		StartTicker()
	end
end

ns.Listen("PLAYER_ENTERING_WORLD", function()
	fpsReady = false
	Strip.Update()
	StartTicker()
end)

ns.Subscribe("LayoutChanged", function(key)
	if (key == KEY or key == KEY2 or key == "meters.damage" or key == "databars.xp") and running then
		Strip.Refresh()
	end
end)

ns.Subscribe("ModuleChanged", function(module)
	if module == "Meters" and running then
		Strip.Refresh()
	end
end)

ns.AddPart({
	Enable = Strip.Enable,
	Disable = Strip.Disable,
	Setting = Strip.Setting,
	Refresh = function()
		ns.FillModules(ns.Settings().strip)
		for _, view in ipairs({ Strip.view, Strip.second }) do
			view.paintColor = nil
			for _, item in pairs(view.items) do item.font = nil end
		end
		Strip.Refresh()
		StartTicker()
	end,
})
