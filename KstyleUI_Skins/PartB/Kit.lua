-- Kit.lua: part B's helpers on KstyleUI.Skin and the module's Style and Parts: item rims, dropdowns, side tabs, arrows, rows, skill bars, one-line titles and windows whose glass docks their bottom tabs.
local _, ns = ...

local K = KstyleUI

local Kit = {}
ns.PartBKit = Kit

local max, pi = math.max, math.pi

local MODULE = "Skins"
local OWNER = "Skins.PartB"
local ICON_CROP = 0.07
local NEUTRAL_SPREAD = 0.05
local QUARTER_TURN = pi / 2
local THUMB_ALPHA = 0.45
local ITEM_OVERLAYS = { "IconOverlay", "IconOverlay2", "ProfessionQualityOverlay", "ItemContextOverlay", "searchOverlay", "IconQuestTexture", "JunkIcon" }

local logged = {}
local items = setmetatable({}, { __mode = "k" })
local listening = false

function Kit.Log(message)
	K.DevTest.Log(MODULE, message)
end

function Kit.LogOnce(key, message)
	if logged[key] then
		return
	end
	logged[key] = true
	Kit.Log(message)
end

local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

local function IsTexture(region)
	return type(region) == "table" and type(region.GetObjectType) == "function" and region:GetObjectType() == "Texture"
end

function Kit.Have(frame, name)
	if frame == nil then
		Kit.LogOnce("missing:" .. name, name .. " is missing on this client; its part of the skin is skipped")
		return false
	end
	if type(frame) ~= "table" then
		Kit.LogOnce("type:" .. name, name .. " is not a frame; its part of the skin is skipped")
		return false
	end
	if type(frame.IsForbidden) == "function" and frame:IsForbidden() == true then
		Kit.LogOnce("forbidden:" .. name, name .. " is forbidden; its part of the skin is skipped")
		return false
	end
	return true
end

local function Locked(frame)
	if not InCombatLockdown() or type(frame.IsProtected) ~= "function" then
		return false
	end
	local protected = frame:IsProtected()
	return IsSecret(protected) or protected == true
end

local function Guard(name, fn)
	return function(frame, ...)
		if not Kit.Have(frame, name) then
			return nil
		end
		if Locked(frame) then
			local n, args = select("#", ...), { ... }
			K.Combat.Queue(function()
				fn(frame, unpack(args, 1, n))
			end)
			Kit.Log(name .. " waits for combat to end")
			return nil
		end
		return fn(frame, ...)
	end
end

local function Side(frame)
	return K.Safe.Side(frame)
end

local function Track(object)
	ns.Style.Track(object)
	return K.Widgets.Track(object)
end

local function AccentRGBA()
	local r, g, b = ns.Style.Accent()
	return r, g, b, 1
end

local function MixAccent(name, alphaScale, t)
	local Widgets = K.Widgets
	local r1, g1, b1, a1 = Widgets.Rgba(name, alphaScale)
	local r2, g2, b2 = ns.Style.Accent()
	return Widgets.Mix(r1, g1, b1, a1, r2, g2, b2, 1, t)
end

function Kit.AccentEdge(chrome, t)
	chrome:SetEdgeRGBA(MixAccent("edgeInner", 1, t or 1))
end

local function HoverHooks(frame, widget)
	frame:HookScript("OnEnter", function()
		K.Widgets.Hover(widget, true)
	end)
	frame:HookScript("OnLeave", function()
		K.Widgets.Hover(widget, false)
	end)
end

function Kit.Rehover(frame, widget)
	if type(frame) == "table" and type(widget) == "table" then
		HoverHooks(frame, widget)
	end
end

local function Enabled(frame)
	return type(frame.IsEnabled) ~= "function" or frame:IsEnabled() ~= false
end

local function PaintButton(parts)
	local Widgets = K.Widgets
	local enabled = Enabled(parts.frame)
	local hover = parts.hoverT or 0
	local chrome = parts.backdrop and parts.backdrop.chrome
	if chrome then
		if enabled then
			chrome:SetEdgeRGBA(MixAccent("edgeInner", 1, hover))
		else
			chrome:SetEdge("edgeInner")
		end
	end
	local text = parts.text
	if text then
		if enabled then
			text:SetTextColor(Widgets.MixTokens("text", 1, "textHover", 1, hover))
		else
			Widgets.TextColor(text, "textDisabled")
		end
	end
end

local function PaintCheck(parts)
	local Widgets = K.Widgets
	local enabled = Enabled(parts.frame)
	parts.mark:SetShown(parts.checked == true)
	if enabled then
		parts.mark:SetVertexColor(AccentRGBA())
		parts.box.chrome:SetEdgeRGBA(MixAccent("edgeInner", 1, parts.hoverT or 0))
	else
		Widgets.Tint(parts.mark, "textDisabled")
		parts.box.chrome:SetEdge("edgeInner")
	end
end

local function PaintTab(parts)
	local Widgets = K.Widgets
	local tab, text = parts.frame, parts.text
	parts.underline:SetShown(parts.selected == true)
	parts.underline:SetVertexColor(AccentRGBA())
	if not text then
		return
	end
	if tab.isDisabled then
		Widgets.TextColor(text, "textDisabled")
	elseif parts.selected then
		text:SetTextColor(Widgets.MixTokens("textEmphasis", 1, "textHover", 1, parts.hoverT or 0))
	else
		text:SetTextColor(Widgets.MixTokens("text", 1, "textHover", 1, parts.hoverT or 0))
	end
end

local function PaintScroll(parts)
	local Widgets = K.Widgets
	if parts.track then
		Widgets.Tint(parts.track, "track")
	end
	if parts.thumb then
		parts.thumb:SetVertexColor(MixAccent("text", THUMB_ALPHA, parts.hoverT or 0))
	end
	if parts.back then
		Widgets.Tint(parts.back, "text")
	end
	if parts.forward then
		Widgets.Tint(parts.forward, "text")
	end
end

local PAINTERS = {
	{ "CheckBox", PaintCheck },
	{ "Tab", PaintTab },
	{ "ScrollBar", PaintScroll },
	{ "Button", PaintButton },
}

function Kit.Accent(frame)
	local parts = type(frame) == "table" and K.Skin.Parts(frame) or nil
	if not parts or parts.partBAccent then
		return parts
	end
	for _, entry in ipairs(PAINTERS) do
		if parts.kinds[entry[1]] then
			parts.Paint = entry[2]
			parts.partBAccent = true
			ns.Style.Track(parts)
			parts:Paint()
			return parts
		end
	end
	return parts
end

local function FocusAccent(box)
	local parts = K.Skin.Parts(box)
	local panel = parts and parts.backdrop
	if not panel or parts.partBAccent then
		return
	end
	parts.partBAccent = true
	box:HookScript("OnEditFocusGained", function()
		Kit.AccentEdge(panel.chrome, 1)
	end)
end

local function CropIcon(icon)
	if not IsTexture(icon) then
		return
	end
	local atlas = type(icon.GetAtlas) == "function" and icon:GetAtlas() or nil
	if atlas ~= nil then
		return
	end
	icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
end

Kit.CropIcon = CropIcon

local function Repaint(object, region)
	local function repaint()
		object:Paint()
	end
	for _, method in ipairs({ "SetVertexColor", "Show", "Hide", "SetShown" }) do
		if type(region[method]) == "function" then
			hooksecurefunc(region, method, repaint)
		end
	end
end

local function IsShown(region)
	local shown = region:IsShown()
	return not IsSecret(shown) and shown == true
end

local function Neutral(r, g, b)
	return math.abs(r - g) < NEUTRAL_SPREAD and math.abs(g - b) < NEUTRAL_SPREAD and math.abs(r - b) < NEUTRAL_SPREAD
end

local function QualityRGB(item)
	local border = item.border
	if not border or not IsShown(border) then
		return nil
	end
	if item.window and ns.Skins.Setting(item.window, "qualityRims") ~= true then
		return nil
	end
	local r, g, b = border:GetVertexColor()
	if IsSecret(r) or IsSecret(g) or IsSecret(b) or type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
		return nil
	end
	if Neutral(r, g, b) then
		return nil
	end
	return K.Theme.Brighten(r, g, b)
end

local function PaintItem(item)
	local rim = item.rim
	if not rim then
		return
	end
	local r, g, b = QualityRGB(item)
	rim:SetRimColor(r, g, b)
	local hover = item.hoverT or 0
	if hover > 0 then
		local Widgets = K.Widgets
		local ar, ag, ab = ns.Style.Accent()
		if r then
			rim.chrome:SetEdgeRGBA(Widgets.Mix(r, g, b, 1, ar, ag, ab, 1, hover))
		else
			Kit.AccentEdge(rim.chrome, hover)
		end
	end
end

local function RepaintItems(_, module, key)
	if module ~= MODULE or type(key) ~= "string" or not key:match("%.qualityRims$") then
		return
	end
	for item in pairs(items) do
		item:Paint()
	end
end

local function ListenForRims()
	if listening then
		return
	end
	listening = true
	K.Callbacks.Register("SettingChanged", OWNER, RepaintItems)
	K.Callbacks.Register("ProfileChanged", OWNER, function()
		RepaintItems(nil, MODULE, ".qualityRims")
	end)
end

local function Item(button, opts)
	opts = opts or {}
	local side = Side(button)
	if side.partBItem then
		return side.partBItem
	end
	local keep = {}
	for _, region in ipairs(opts.keep or {}) do
		if IsTexture(region) then
			keep[region] = true
		end
	end
	for _, key in ipairs(ITEM_OVERLAYS) do
		if IsTexture(button[key]) then
			keep[button[key]] = true
		end
	end
	if opts.normal then
		local normal = type(button.GetNormalTexture) == "function" and button:GetNormalTexture() or nil
		if IsTexture(normal) then
			keep[normal] = true
			CropIcon(normal)
		end
		if type(button.SetNormalTexture) == "function" then
			hooksecurefunc(button, "SetNormalTexture", function(self)
				CropIcon(self:GetNormalTexture())
			end)
		end
	else
		local icon = opts.icon or button.icon or button.Icon
		if IsTexture(icon) then
			keep[icon] = true
			CropIcon(icon)
		end
	end
	K.Skin.Strip(button, { keep = keep, watch = false })
	local item = { frame = button, window = opts.window, Paint = PaintItem, Restyle = PaintItem }
	item.rim = ns.Parts.Rim(button, { outset = opts.outset or 0 })
	if IsTexture(button.IconBorder) then
		item.border = button.IconBorder
		Repaint(item, button.IconBorder)
	end
	HoverHooks(button, item)
	side.partBItem = item
	items[item] = true
	ListenForRims()
	item:Paint()
	return Track(item)
end

local function Dropdown(dropdown)
	return ns.Parts.Dropdown(dropdown)
end

local function SideTab(frame)
	return ns.Parts.SideTab(frame)
end

local ARROWS = { left = -QUARTER_TURN, right = QUARTER_TURN }

local function Arrow(button, direction)
	local side = Side(button)
	if side.partBArrow then
		return side.partBArrow
	end
	side.partBArrow = ns.Parts.Glyph(button, "glyphChevron", { rotation = ARROWS[direction] })
	return side.partBArrow
end

local function PaintSquare(square)
	local chrome = square.backdrop and square.backdrop.chrome
	if chrome then
		Kit.AccentEdge(chrome, square.hoverT or 0)
	end
end

local function Square(button, opts)
	opts = opts or {}
	local side = Side(button)
	if side.partBSquare then
		return side.partBSquare
	end
	local keep = {}
	local icon = opts.icon or button.Icon or button.icon
	if IsTexture(icon) then
		keep[icon] = true
	end
	K.Skin.Strip(button, { keep = keep })
	local square = { frame = button, Paint = PaintSquare, Restyle = PaintSquare }
	square.backdrop = K.Skin.Backdrop(button, { shape = "tile", fill = "buttonFill", shadow = false })
	HoverHooks(button, square)
	side.partBSquare = square
	square:Paint()
	return Track(square)
end

local function Hush(frame, ...)
	local count = 0
	for i = 1, select("#", ...) do
		if ns.Parts.Hush((select(i, ...))) then
			count = count + 1
		end
	end
	return count
end

local function PaintSelect(row)
	local chrome = row.backdrop and row.backdrop.chrome
	if not chrome then
		return
	end
	if row.marker and IsShown(row.marker) then
		Kit.AccentEdge(chrome, 1)
	else
		Kit.AccentEdge(chrome, row.hoverT or 0)
	end
end

local function Select(frame, marker, opts)
	opts = opts or {}
	local side = Side(frame)
	if side.partBSelect then
		return side.partBSelect
	end
	local row = { frame = frame, Paint = PaintSelect, Restyle = PaintSelect }
	row.backdrop = K.Skin.Backdrop(frame, { shape = "tile", fill = "surface", shadow = false })
	if IsTexture(marker) then
		row.marker = marker
		Repaint(row, marker)
	end
	if opts.hover ~= false then
		HoverHooks(frame, row)
	end
	side.partBSelect = row
	row:Paint()
	return Track(row)
end

local function Inset(frame, opts)
	opts = opts or {}
	K.Skin.Strip(frame, { children = { "NineSlice", "Bg" } })
	if opts.tile then
		return K.Skin.Backdrop(frame, { shape = "tile", fill = "surface", shadow = false, inset = opts.inset })
	end
	return frame
end

local function MoneyBox(box)
	local keep = {}
	if IsTexture(box.texture) then
		keep[box.texture] = true
	end
	K.Skin.Strip(box, { keep = keep })
	return Kit.EditBox(box)
end

local function InputScroll(scroll)
	K.Skin.Strip(scroll)
	local backdrop = K.Skin.Backdrop(scroll, { shape = "tile", fill = "buttonFill", shadow = false })
	if scroll.ScrollBar then
		Kit.ScrollBar(scroll.ScrollBar)
	end
	return backdrop
end

local function NumberBox(box)
	Kit.EditBox(box)
	if box.IncrementButton then
		Arrow(box.IncrementButton, "right")
	end
	if box.DecrementButton then
		Arrow(box.DecrementButton, "left")
	end
	return box
end

local function Value(value)
	if IsSecret(value) or type(value) == "number" then
		return value
	end
	return nil
end

local function PaintRankBar(bar)
	local Style = ns.Style
	local fill = bar.fill
	fill:SetBarTexture(Style.BarTexture())
	fill:SetReverseFill(Style.ReverseFill())
	local r, g, b = Style.Accent()
	fill:SetBarColor(Style.BarColor(r, g, b, 1))
end

local function RankBar(frame)
	local side = Side(frame)
	if side.partBBar then
		return side.partBBar
	end
	K.Skin.Strip(frame, { children = { "Background", "Fill", "Flare", "Border" } })
	local fill = K.Widgets.StatusBar(frame, { texture = ns.Style.BarTexture(), border = true, min = 0, max = 1, value = 0 })
	fill:ClearAllPoints()
	fill:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	fill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
	local rank = frame.Rank
	if type(rank) == "table" and type(rank.GetFrameLevel) == "function" then
		fill:SetFrameLevel(max(0, rank:GetFrameLevel() - 1))
		if type(rank.Text) == "table" then
			ns.Style.Text(rank.Text, "number", "textEmphasis")
		end
	end
	local bar = { frame = frame, fill = fill, Paint = PaintRankBar, Restyle = PaintRankBar }
	local ratio = frame.ratio
	if IsSecret(ratio) or type(ratio) == "number" then
		fill:SetBarValue(ratio)
	end
	if type(frame.Update) == "function" then
		hooksecurefunc(frame, "Update", function(_, info)
			if type(info) ~= "table" then
				return
			end
			local high, value = Value(info.maxSkillLevel), Value(info.skillLevel)
			if high == nil or value == nil then
				return
			end
			fill:SetBarRange(0, high)
			fill:SetBarValue(value)
		end)
	else
		Kit.LogOnce("rankbar-update", "a profession rank bar has no Update method; its KstyleUI bar stays empty")
	end
	side.partBBar = bar
	bar:Paint()
	return Track(bar)
end

local function FitBarLabel(bar)
	local frame, label, rank = bar.frame, bar.label, bar.frame.rankText
	if not label or bar.labelText == nil then
		return
	end
	local inset = K.Widgets.Snap(frame, K.Tokens.Size("gapMedium"))
	local gap = K.Widgets.Snap(frame, K.Tokens.Size("gapSmall"))
	local width = frame:GetWidth()
	local need = K.Widgets.TextWidth(label, nil)
	if IsSecret(width) or type(width) ~= "number" or need == nil then
		label:Show()
		return
	end
	local taken = type(rank) == "table" and (K.Widgets.TextWidth(rank, 0) + gap) or 0
	label:SetShown(need <= width - 2 * inset - taken)
end

local function PlaceBarTexts(bar)
	local frame, label, rank = bar.frame, bar.label, bar.frame.rankText
	local inset = K.Widgets.Snap(frame, K.Tokens.Size("gapMedium"))
	local gap = K.Widgets.Snap(frame, K.Tokens.Size("gapSmall"))
	if type(rank) == "table" then
		rank:ClearAllPoints()
		rank:SetPoint("RIGHT", frame, "RIGHT", -inset, 0)
		rank:SetJustifyH("RIGHT")
	end
	if label then
		label:ClearAllPoints()
		label:SetPoint("LEFT", frame, "LEFT", inset, 0)
		if type(rank) == "table" then
			label:SetPoint("RIGHT", rank, "LEFT", -gap, 0)
		else
			label:SetPoint("RIGHT", frame, "RIGHT", -inset, 0)
		end
		FitBarLabel(bar)
	end
end

local function SetBarLabel(bar, text)
	if not bar.label then
		return
	end
	if IsSecret(text) or type(text) ~= "string" or text == "" then
		bar.labelText = nil
		bar.label:SetText("")
		bar.label:Hide()
		return
	end
	bar.labelText = text
	bar.label:SetText(text)
	FitBarLabel(bar)
end

local function Bar(frame, opts)
	opts = opts or {}
	local side = Side(frame)
	if side.partBBar then
		return side.partBBar
	end
	local keep = {}
	local fill = frame:GetStatusBarTexture()
	if IsTexture(fill) then
		keep[fill] = true
	end
	K.Skin.Strip(frame, { keep = keep })
	local bar = { frame = frame, SetLabel = SetBarLabel, Restyle = PlaceBarTexts }
	bar.backdrop = K.Skin.Backdrop(frame, { shape = "tile", fill = "surface", edge = "edgeBar", shadow = false })
	ns.Style.StatusBar(frame, { accent = opts.accent == true })
	if type(frame.rankText) == "table" then
		ns.Style.Text(frame.rankText, "number", "textEmphasis")
	end
	if opts.label then
		local overlay = CreateFrame("Frame", nil, frame)
		overlay:SetAllPoints(frame)
		overlay:SetFrameLevel(frame:GetFrameLevel() + 1)
		bar.label = K.Widgets.FontString(overlay, "OVERLAY")
		ns.Style.Text(bar.label, "body", "textEmphasis")
		bar.label:SetJustifyH("LEFT")
		bar.label:SetWordWrap(false)
		SetBarLabel(bar, opts.label)
	end
	PlaceBarTexts(bar)
	side.partBBar = bar
	return Track(bar)
end

local function Rows(scrollBox, skinRow)
	local side = Side(scrollBox)
	if side.partBRows == nil then
		side.partBRows = ns.Parts.EachRow(scrollBox, skinRow) == true
	end
	return side.partBRows
end

local function WindowTabs(frame)
	local list = {}
	if type(frame.Tabs) == "table" then
		for _, tab in ipairs(frame.Tabs) do
			list[#list + 1] = tab
		end
	elseif type(frame.numTabs) == "number" and type(frame.GetName) == "function" and frame:GetName() then
		for i = 1, frame.numTabs do
			list[#list + 1] = _G[frame:GetName() .. "Tab" .. i]
		end
	end
	return list
end

Kit.WindowTabs = WindowTabs

function Kit.Title(frame)
	local container = frame.TitleContainer
	local title = type(container) == "table" and container.TitleText or nil
	if not title and type(frame.GetTitleText) == "function" then
		title = frame:GetTitleText()
	end
	if type(title) == "table" and type(title.SetFont) == "function" then
		return ns.Style.Title(title)
	end
	return nil
end

local function Window(frame, opts)
	opts = opts or {}
	local panel = K.Skin.Window(frame, { inset = opts.inset, tabs = opts.tabs, title = false })
	local title = Kit.Title(frame)
	local tabs = WindowTabs(frame)
	for _, tab in ipairs(tabs) do
		Kit.Accent(tab)
	end
	if opts.tabs ~= false and #tabs > 0 then
		ns.Parts.Dock(frame, tabs, { title = title })
	end
	return panel
end

local function Button(button)
	local backdrop = K.Skin.Button(button)
	Kit.Accent(button)
	local text = type(button.GetFontString) == "function" and button:GetFontString() or nil
	if type(text) == "table" and type(text.SetFont) == "function" then
		ns.Style.Text(text, "body")
	end
	return backdrop
end

local function Tab(tab)
	K.Skin.Tab(tab)
	Kit.Accent(tab)
	local parts = K.Skin.Parts(tab)
	if parts and type(parts.text) == "table" and type(parts.text.SetFont) == "function" then
		ns.Style.Text(parts.text, "body")
	end
	return parts
end

local function CheckBox(check)
	K.Skin.CheckBox(check)
	return Kit.Accent(check)
end

local function ScrollBar(bar)
	K.Skin.ScrollBar(bar)
	return Kit.Accent(bar)
end

local function EditBox(box, opts)
	local panel = K.Skin.EditBox(box, opts)
	FocusAccent(box)
	return panel
end

local function Text(text, role, colorName)
	return ns.Style.Text(text, role, colorName)
end

Kit.Window = Guard("Window", Window)
Kit.Button = Guard("Button", Button)
Kit.Tab = Guard("Tab", Tab)
Kit.CheckBox = Guard("CheckBox", CheckBox)
Kit.ScrollBar = Guard("ScrollBar", ScrollBar)
Kit.EditBox = Guard("EditBox", EditBox)
Kit.Text = Guard("Text", Text)
Kit.Item = Guard("Item", Item)
Kit.Dropdown = Guard("Dropdown", Dropdown)
Kit.SideTab = Guard("SideTab", SideTab)
Kit.Arrow = Guard("Arrow", Arrow)
Kit.Square = Guard("Square", Square)
Kit.Hush = Guard("Hush", Hush)
Kit.Select = Guard("Select", Select)
Kit.Inset = Guard("Inset", Inset)
Kit.MoneyBox = Guard("MoneyBox", MoneyBox)
Kit.InputScroll = Guard("InputScroll", InputScroll)
Kit.NumberBox = Guard("NumberBox", NumberBox)
Kit.RankBar = Guard("RankBar", RankBar)
Kit.Bar = Guard("Bar", Bar)
Kit.Rows = Guard("Rows", Rows)
