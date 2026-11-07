-- Settings.lua: the data bars' defaults, their rows in the settings window and the live preview the window shows.
local _, ns = ...

local K, L = ns.K, ns.L
local Tokens, Widgets = K.Tokens, K.Widgets
local Format, Font, Bars = ns.Format, ns.Font, ns.Bars

local DEFAULT_TEXTURE = "Glass"
local FONT_SIZE = 10
local SEGMENTS = 10
local MAX_SEGMENTS = 20
local RESTED_ALPHA = 0.5
local PREVIEW_BAR = 8
local PREVIEW_GAP = 22
local PREVIEW_TOP = 26

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
defaults.xp = BarDefaults("class", "accentDefault", "valuePercent")
defaults.xp.rested = true
defaults.xp.restedColor = Rgb("rare", RESTED_ALPHA)
defaults.rep = BarDefaults("reaction", "friendly", "labelPercent")
defaults.honor = BarDefaults("custom", "epic", "labelPercent")
defaults.honor.show = "pvp"

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

ns.AddRows({
	{ type = "header", label = L["Blizzard's bars"] },
	{ type = "toggle", key = "fadeBlizzard", label = L["Fade Blizzard's bars"], help = L["Fades Blizzard's experience and reputation bars while KstyleUI shows its own."] },
})
ns.AddRows(BarRows("xp", L["Experience bar"], SOURCES_PLAIN))
ns.AddRows(BarRows("rep", L["Reputation bar"], SOURCES_REACTION))
ns.AddRows(BarRows("honor", L["Honour bar"], SOURCES_PLAIN))

local SAMPLES = {
	xp = { current = 12345, max = 50000, rested = 8000, level = 38, label = L["Level 38"], kind = "xp" },
	rep = { current = 3600, max = 6000, reaction = 5, kind = "faction", name = L["Stormwind"], label = L["Stormwind"], standing = L["Friendly"] },
	honor = { current = 400, max = 1000, level = 3, kind = "rank", label = L["Rank 3"] },
}

local function PreviewSettings(s)
	return setmetatable({ orientation = "HORIZONTAL", textHover = false, textPosition = "TOP" }, { __index = s })
end

function ns.Preview(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetAllPoints(parent)
	frame.bars, frame.captions = {}, {}
	local y = PREVIEW_TOP
	for _, def in ipairs(Bars.DEFS) do
		local caption = Widgets.Text(frame, "caption", "text")
		caption:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -y + PREVIEW_TOP)
		Widgets.SetText(caption, def.title)
		local view = Bars.NewView(frame, def)
		view.holder:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -y - Tokens.Size("gapLarge"))
		view.holder:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -y - Tokens.Size("gapLarge"))
		view.holder:SetHeight(PREVIEW_BAR)
		frame.bars[def.id], frame.captions[def.id] = view, caption
		y = y + PREVIEW_BAR + PREVIEW_GAP + Tokens.Size("gapLarge")
	end
	function frame.Refresh(self)
		local settings = ns.Settings()
		for id, view in pairs(self.bars) do
			Bars.Paint(view, PreviewSettings(settings[id]), SAMPLES[id], true)
		end
	end
	frame:Refresh()
	return frame
end
