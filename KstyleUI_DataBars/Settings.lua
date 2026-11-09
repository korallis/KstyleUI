-- Settings.lua: the data bars' defaults, their rows in the settings window and the live preview the window shows.
local _, ns = ...

local K, L = ns.K, ns.L
local Tokens, Widgets = K.Tokens, K.Widgets
local Format, Font, Bars, Strip = ns.Format, ns.Font, ns.Bars, ns.Strip
local max = math.max

local DEFAULT_TEXTURE = "Glass"
local FONT_SIZE = Tokens.Size("caption")
local XP_FONT_SIZE = 12
local SEGMENTS = 0
local MAX_SEGMENTS = 20
local RESTED_ALPHA = 0.5
local PREVIEW_BAR = 8
local PREVIEW_GAP = 22
local PREVIEW_TOP = 26
local PREVIEW_STRIP = 36
local PREVIEW_STRIP_PAD = 12
local STRIP_FONT_SIZE = 12
local STRIP_SPACING = 16
local MAX_SPACING = 32
local MICRO_SIZE = 26
local BAG_SIZE = 26
local MENU_SPACING = 4
local MENU_SIZE_MIN, MENU_SIZE_MAX = 12, 48
local MENU_SPACING_MAX = 12

local function Texture(key)
	for _, item in ipairs(Tokens.MediaList("statusbar")) do
		if item.key == key then
			return item.path
		end
	end
	return Tokens.MediaList("statusbar")[1].path
end

local function Rgb(name, alpha)
	local r, g, b = Tokens.Color(name)
	return { r = r, g = g, b = b, a = alpha }
end

local function BarDefaults(colorSource, colorToken, text)
	return {
		texture = Texture(DEFAULT_TEXTURE),
		colorSource = colorSource,
		color = Rgb(colorToken),
		orientation = "HORIZONTAL",
		reverse = false,
		segments = SEGMENTS,
		border = true,
		text = text,
		textHover = true,
		textPosition = "CENTER",
		font = Font.DEFAULT,
		fontSize = FONT_SIZE,
		outline = "OUTLINE",
	}
end

local defaults = ns.defaults
defaults.fadeBlizzard = true
defaults.accentSource = "class"
defaults.accentColor = Rgb("accentDefault")
defaults.xp = BarDefaults("class", "accentDefault", "shortPercent")
defaults.xp.textHover = false
defaults.xp.fontSize = XP_FONT_SIZE
defaults.xp.rested = true
defaults.xp.restedColor = Rgb("rare", RESTED_ALPHA)
defaults.rep = BarDefaults("reaction", "friendly", "labelPercent")
defaults.honor = BarDefaults("custom", "epic", "labelPercent")
defaults.honor.show = "pvp"
defaults.strip = {
	labels = "full", valueColor = "highlight", accentEdge = false, backdrop = true, separators = false,
	spacing = STRIP_SPACING, orientation = "HORIZONTAL",
	font = Font.DEFAULT, fontSize = STRIP_FONT_SIZE, outline = "NONE",
	money = "full", latency = "home", timeSource = "local", clock24 = true,
}
for i, id in ipairs(Strip.ITEMS) do
	defaults.strip["slot" .. i] = id
end
defaults.micro = { enabled = true, size = MICRO_SIZE, spacing = MENU_SPACING, rows = 1, backdrop = true, tint = "none" }
defaults.bags = { enabled = true, size = BAG_SIZE, spacing = MENU_SPACING, rows = 1, backdrop = true, freeSlots = true }

local SOURCES_PLAIN = {
	{ value = "class", label = L["Class colour"] },
	{ value = "custom", label = L["Custom colour"] },
}
local SOURCES_REACTION = {
	{ value = "class", label = L["Class colour"] },
	{ value = "reaction", label = L["Reaction colour"] },
	{ value = "custom", label = L["Custom colour"] },
}
local ORIENTATIONS = {
	{ value = "HORIZONTAL", label = L["Sideways"] },
	{ value = "VERTICAL", label = L["Upright"] },
}
local TEXT_POSITIONS = {
	{ value = "CENTER", label = L["On the bar"] },
	{ value = "TOP", label = L["Above the bar"] },
	{ value = "BOTTOM", label = L["Below the bar"] },
	{ value = "LEFT", label = L["Left of the bar"] },
	{ value = "RIGHT", label = L["Right of the bar"] },
}
local HONOR_SHOW = {
	{ value = "pvp", label = L["In battlegrounds and world PvP"] },
	{ value = "always", label = L["Always"] },
}

local function Get(settings, id)
	return settings[id] or {}
end

local function BarRows(id, title, sources)
	local function custom(settings)
		return Get(settings, id).colorSource ~= "custom"
	end
	local function noText(settings)
		return Get(settings, id).text == "none"
	end
	local rows = {
		{ type = "header", label = title },
		{ type = "dropdown", key = id .. ".colorSource", label = L["Colour"], help = L["Fill the bar with the class colour or your own colour."], options = sources },
		{ type = "color", key = id .. ".color", label = L["Custom colour"], help = L["The bar's colour when its colour is set to custom."], showWhen = function(settings)
			return not custom(settings)
		end },
		{ type = "texture", key = id .. ".texture", label = L["Texture"], help = L["The texture that fills the bar."] },
		{ type = "dropdown", key = id .. ".orientation", label = L["Orientation"], help = L["A bar that fills sideways, or one that stands upright."], options = ORIENTATIONS },
		{ type = "toggle", key = id .. ".reverse", label = L["Fill from the other end"], help = L["Fills from right to left, or from top to bottom."] },
		{ type = "slider", key = id .. ".segments", label = L["Segments"], help = L["Ticks that split the bar into equal parts. 0 draws none."], min = 0, max = MAX_SEGMENTS, step = 1 },
		{ type = "toggle", key = id .. ".border", label = L["Frame"], help = L["Draws the chamfered frame around the bar."] },
	}
	if sources == SOURCES_REACTION then
		rows[2].help = L["Fill the bar with the class colour, your standing's colour or your own colour."]
	end
	if id == "xp" then
		rows[#rows + 1] = { type = "toggle", key = "xp.rested", label = L["Rested overlay"], help = L["Shows how far your rested experience reaches past your current experience."] }
		rows[#rows + 1] = { type = "color", key = "xp.restedColor", label = L["Rested colour"], help = L["The colour of the rested overlay."], hasAlpha = true, showWhen = function(settings)
			return Get(settings, "xp").rested == true
		end }
	elseif id == "honor" then
		rows[#rows + 1] = { type = "dropdown", key = "honor.show", label = L["Show"], help = L["Shows honour only in battlegrounds and world PvP, or all the time."], options = HONOR_SHOW }
	end
	local textRows = {
		{ type = "dropdown", key = id .. ".text", label = L["Text"], help = L["What the text on the bar says."], options = Format.BAR_TEXTS },
		{ type = "toggle", key = id .. ".textHover", label = L["Text on hover only"], help = L["Shows the text only while the pointer is over the bar."], disableWhen = noText },
		{ type = "dropdown", key = id .. ".textPosition", label = L["Text position"], help = L["Where the text sits around the bar."], options = TEXT_POSITIONS, disableWhen = noText },
		{ type = "dropdown", key = id .. ".font", label = L["Font"], help = L["The font of the bar's text."], options = Font.Faces, disableWhen = noText },
		{ type = "slider", key = id .. ".fontSize", label = L["Font size"], help = L["The size of the bar's text."], min = Font.MIN_SIZE, max = Font.MAX_SIZE, step = Font.STEP, disableWhen = noText },
		{ type = "dropdown", key = id .. ".outline", label = L["Outline"], help = L["A thin or thick outline, or a soft shadow, around the text."], options = Font.OUTLINES, disableWhen = noText },
	}
	for _, row in ipairs(textRows) do
		rows[#rows + 1] = row
	end
	return rows
end

local ACCENT_SOURCES = {
	{ value = "class", label = L["Class colour"] },
	{ value = "custom", label = L["Custom colour"] },
}

ns.AddRows({
	{ type = "header", label = L["General"] },
	{ type = "toggle", key = "fadeBlizzard", label = L["Fade Blizzard's bars"], help = L["Fades Blizzard's experience and reputation bars while KstyleUI shows its own."] },
	{ type = "dropdown", key = "accentSource", label = L["Accent"], help = L["The colour of the strip's accent touches: your class colour or your own."], options = ACCENT_SOURCES },
	{ type = "color", key = "accentColor", label = L["Accent colour"], help = L["The accent colour when the accent is set to custom."], showWhen = function(settings)
		return settings.accentSource == "custom"
	end },
})
ns.AddRows(BarRows("xp", L["Experience bar"], SOURCES_PLAIN))
ns.AddRows(BarRows("rep", L["Reputation bar"], SOURCES_REACTION))
ns.AddRows(BarRows("honor", L["Honour bar"], SOURCES_PLAIN))

local STRIP_ITEMS = {
	{ value = "none", label = L["Empty"] },
	{ value = "fps", label = L["Frame rate"] },
	{ value = "latency", label = L["Latency"] },
	{ value = "gold", label = L["Gold"] },
	{ value = "durability", label = L["Durability"] },
	{ value = "time", label = L["Time"] },
}
local STRIP_LABELS = {
	{ value = "full", label = L["Full: Frame rate, Durability"] },
	{ value = "short", label = L["Short: FPS, MS, DUR"] },
	{ value = "none", label = L["None"] },
}
local VALUE_COLORS = {
	{ value = "highlight", label = L["Highlight and warnings"] },
	{ value = "threshold", label = L["Good, fair or poor"] },
	{ value = "accent", label = L["Accent colour"] },
	{ value = "plain", label = L["Plain"] },
}
local MONEY_STYLES = {
	{ value = "full", label = L["Gold, silver and copper"] },
	{ value = "gold", label = L["Gold only"] },
	{ value = "icons", label = L["Coin icons"] },
}
local LATENCIES = {
	{ value = "home", label = L["Home"] },
	{ value = "world", label = L["World"] },
}
local TIME_SOURCES = {
	{ value = "local", label = L["Local time"] },
	{ value = "realm", label = L["Realm time"] },
}

local stripRows = { { type = "header", label = L["Data strip"] } }
for i = 1, Strip.SLOTS do
	stripRows[#stripRows + 1] = {
		type = "dropdown", key = "strip.slot" .. i, label = string.format(L["Place %d"], i),
		help = L["What this place on the strip shows, counted from the left or the top."], options = STRIP_ITEMS,
	}
end
for _, row in ipairs({
	{ type = "dropdown", key = "strip.labels", label = L["Labels"], help = L["Full labels, short ones like the dungeon mockup, or values alone."], options = STRIP_LABELS },
	{ type = "dropdown", key = "strip.valueColor", label = L["Value colour"], help = L["Frame rate in the accent and warnings in theirs, every value by grade, all in the accent, or plain."], options = VALUE_COLORS },
	{ type = "toggle", key = "strip.accentEdge", label = L["Accent edge"], help = L["Draws the strip's inner edge in the accent colour."] },
	{ type = "toggle", key = "strip.backdrop", label = L["Glass"], help = L["Draws the strip on smoked glass."] },
	{ type = "toggle", key = "strip.separators", label = L["Separators"], help = L["Draws a thin line between the cells."] },
	{ type = "slider", key = "strip.spacing", label = L["Spacing"], help = L["The room inside each cell, split between its sides."], min = 0, max = MAX_SPACING, step = 1 },
	{ type = "dropdown", key = "strip.orientation", label = L["Direction"], help = L["Items in a row, or stacked in a column."], options = {
		{ value = "HORIZONTAL", label = L["In a row"] }, { value = "VERTICAL", label = L["In a column"] },
	} },
	{ type = "dropdown", key = "strip.font", label = L["Font"], help = L["The font of the strip's text."], options = Font.Faces },
	{ type = "slider", key = "strip.fontSize", label = L["Font size"], help = L["The size of the strip's text."], min = Font.MIN_SIZE, max = Font.MAX_SIZE, step = Font.STEP },
	{ type = "dropdown", key = "strip.outline", label = L["Outline"], help = L["A thin or thick outline, or a soft shadow, around the text."], options = Font.OUTLINES },
	{ type = "dropdown", key = "strip.money", label = L["Gold format"], help = L["How the strip writes your money."], options = MONEY_STYLES },
	{ type = "dropdown", key = "strip.latency", label = L["Latency shown"], help = L["Home latency for chat and logins, or world latency for combat."], options = LATENCIES },
	{ type = "dropdown", key = "strip.timeSource", label = L["Clock"], help = L["Your computer's time or the realm's time."], options = TIME_SOURCES },
	{ type = "toggle", key = "strip.clock24", label = L["24-hour clock"], help = L["Shows 14:32 instead of 2:32 PM."] },
}) do
	stripRows[#stripRows + 1] = row
end
ns.AddRows(stripRows)

local TINTS = {
	{ value = "none", label = L["Blizzard's colours"] },
	{ value = "accent", label = L["Accent colour"] },
	{ value = "white", label = L["White"] },
}

local function MenuRows(id, title, enabledHelp)
	local function off(settings)
		return not (settings[id] and settings[id].enabled)
	end
	local count = #ns.Menus.GROUPS[id].buttons
	local rows = {
		{ type = "header", label = title },
		{ type = "toggle", key = id .. ".enabled", label = L["Replace Blizzard's"], help = enabledHelp },
		{ type = "slider", key = id .. ".size", label = L["Button size"], help = L["The height of each button. Layout Mode moves and scales the bar."], min = MENU_SIZE_MIN, max = MENU_SIZE_MAX, step = 1, disableWhen = off },
		{ type = "slider", key = id .. ".spacing", label = L["Spacing"], help = L["The gap between buttons."], min = 0, max = MENU_SPACING_MAX, step = 1, disableWhen = off },
		{ type = "slider", key = id .. ".rows", label = L["Rows"], help = L["How many rows the buttons fill; the columns follow."], min = 1, max = count, step = 1, disableWhen = off },
		{ type = "toggle", key = id .. ".backdrop", label = L["Glass"], help = L["Draws smoked glass behind the buttons."], disableWhen = off },
	}
	if id == "micro" then
		rows[#rows + 1] = { type = "dropdown", key = "micro.tint", label = L["Icon colour"], help = L["Keeps Blizzard's icon colours, or tints the icons in the accent colour or white."], options = TINTS, disableWhen = off }
	else
		rows[#rows + 1] = { type = "toggle", key = "bags.freeSlots", label = L["Free slots"], help = L["Shows on the backpack how many slots are free in all your bags."], disableWhen = off }
	end
	return rows
end

ns.AddRows(MenuRows("micro", L["Micro menu"], L["Shows KstyleUI's micro menu in place of Blizzard's. Off, Blizzard's returns."]))
ns.AddRows(MenuRows("bags", L["Bag bar"], L["Shows KstyleUI's bag bar in place of Blizzard's. Off, Blizzard's returns."]))

local SAMPLES = {
	xp = { current = 12345, max = 50000, rested = 8000, level = 38, label = L["Level 38"], kind = "xp" },
	rep = { current = 3600, max = 6000, reaction = 5, kind = "faction", name = L["Stormwind"], label = L["Stormwind"], standing = L["Friendly"] },
	honor = { current = 400, max = 1000, level = 3, kind = "rank", label = L["Rank 3"] },
}

local function PreviewSettings(s)
	return setmetatable({ orientation = "HORIZONTAL", textHover = false, textPosition = "TOP" }, { __index = s })
end

local SAMPLE_FPS, SAMPLE_MS, SAMPLE_MONEY, SAMPLE_DURABILITY = 144, 34, 1438217, 96
local SAMPLE_HOUR, SAMPLE_MINUTE = 14, 32

local PREVIEW_FALLBACK_WIDTH = 248

local function Width(frame)
	local w = frame:GetWidth()
	if ns.IsNumber(w) and w > 0 then
		return w
	end
	return nil
end

local function StripSamples(s)
	return {
		fps = { tostring(SAMPLE_FPS), "good" },
		latency = { s.labels == "short" and tostring(SAMPLE_MS) or string.format(L["%d ms"], SAMPLE_MS), "good" },
		gold = { Format.Money(SAMPLE_MONEY, s.money) },
		durability = { SAMPLE_DURABILITY .. "%", "good" },
		time = { Format.Clock(SAMPLE_HOUR, SAMPLE_MINUTE, s.clock24) },
	}
end

function ns.Preview(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetAllPoints(parent)
	frame.bars, frame.captions = {}, {}
	local y = PREVIEW_TOP
	for _, def in ipairs(Bars.DEFS) do
		local caption = Widgets.Text(frame, "caption", "text")
		caption:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -(y - PREVIEW_TOP))
		Widgets.SetText(caption, def.title)
		local view = Bars.NewView(frame, def)
		view.holder:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -y)
		view.holder:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -y)
		view.holder:SetHeight(PREVIEW_BAR)
		frame.bars[def.id], frame.captions[def.id] = view, caption
		y = y + PREVIEW_BAR + PREVIEW_GAP + PREVIEW_TOP
	end
	local caption = Widgets.Text(frame, "caption", "text")
	caption:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -(y - PREVIEW_TOP))
	Widgets.SetText(caption, L["Data strip"])
	local strip = Strip.NewView(frame)
	strip.top = y
	frame.strip, frame.captions.strip = strip, caption
	function frame.Refresh(self)
		local settings = ns.Settings()
		for id, view in pairs(self.bars) do
			Bars.Paint(view, PreviewSettings(settings[id]), SAMPLES[id], true)
		end
		local s = setmetatable({ orientation = "HORIZONTAL" }, { __index = settings.strip })
		local sample, samples = self.strip, StripSamples(s)
		local available = Width(self) or Width(parent) or PREVIEW_FALLBACK_WIDTH
		sample.frame:SetScale(1)
		sample.frame:SetSize(available, PREVIEW_STRIP)
		Strip.Paint(sample, s, samples)
		local needed = Widgets.Snap(sample.frame, (sample.contentWidth or 0) + 2 * PREVIEW_STRIP_PAD)
		local scale = needed > available and available / needed or 1
		sample.frame:SetScale(scale)
		sample.frame:SetSize(max(needed, available / scale), PREVIEW_STRIP)
		sample.frame:ClearAllPoints()
		sample.frame:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -sample.top / scale)
		Strip.Paint(sample, s, samples)
	end
	frame:Refresh()
	return frame
end
