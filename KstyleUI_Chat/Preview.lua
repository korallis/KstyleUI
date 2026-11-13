-- Preview.lua: the chat page's live preview in the settings window, a small glass panel with tabs and sample lines drawn with the current settings, its tabs painted by the live chat's own tab look.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, L = K.Widgets, K.Tokens, K.L
local Format = ns.Format

local Preview = {}
ns.Preview = Preview

local TAB_WIDTH = 72
local TAB_TOP = 16
local UNDERLINE = 1
local LINE_GAP = 3

local SAMPLES = {
	{ event = "CHAT_MSG_GUILD", channel = "|Hchannel:GUILD|h[" .. L["Guild"] .. "]|h ", name = "Thargor", class = "WARRIOR", text = L["LFM tank for Razorfen Kraul"] },
	{ event = "CHAT_MSG_CHANNEL", channel = "|Hchannel:channel:1|h[1. " .. L["General"] .. " - " .. L["Riverglades"] .. "]|h ", name = "Lunara", class = "MAGE", text = L["Anyone for the croc hunt?"] },
	{ event = "CHAT_MSG_PARTY", channel = "|Hchannel:PARTY|h[" .. L["Party"] .. "]|h ", name = "Valerin", class = "PRIEST", text = L["Route guide:"] .. " www.wowhead.com/forever" },
	{ text = L["You receive loot: [Rugged Hide]."] },
}
local TABS = { L["General"], L["Combat Log"], L["Loot"] }

local function Line(sample, settings)
	local text = sample.text
	if sample.event then
		local name = sample.name
		if settings.classNames == true then
			local r, g, b = K.Theme.Brighten(K.Theme.ClassColor(sample.class))
			name = Format.ColorName(name, r, g, b) or name
		end
		if settings.urls == true then
			text = Format.Linkify(text, ns.Accent(settings))
		end
		text = sample.channel .. "|Hplayer:" .. sample.name .. "|h[" .. name .. "]|h: " .. text
	end
	local opts = {
		channels = settings.channels,
		numbers = settings.numbers,
		abbr = settings.abbr,
		timestamp = settings.timestamp,
		timestampColor = settings.timestampColor,
	}
	return Format.Decorate(text, sample.event, opts)
end

local function Refresh(self)
	local settings = ns.Settings()
	local glass = self.glass
	local r, g, b = Tokens.Color("surface")
	glass.chrome:SetFillRGBA(r, g, b, settings.panelOpacity)
	glass.chrome:SetShadow(settings.shadow == true)
	local path, size, flags, tabSize, tabPath = ns.Frames.Fonts(settings)
	local ar, ag, ab = ns.Accent(settings)
	local style = settings.tabStyle
	local x = Tokens.Size("gapMedium")
	local gap = Tokens.Size("gapLarge")
	for i, tab in ipairs(self.tabs) do
		ns.Frames.ApplyFont(tab, tabPath, tabSize, flags)
		local label = TABS[i]
		tab:SetText(settings.tabCase == "upper" and label:upper() or label)
		tab:ClearAllPoints()
		tab:SetPoint("LEFT", glass, "TOPLEFT", x, -TAB_TOP)
		local width = Widgets.TextWidth(tab, TAB_WIDTH)
		if i == 1 then
			self.fill:ClearAllPoints()
			self.fill:SetPoint("LEFT", tab, "LEFT", -Tokens.Size("gapSmall"), 0)
			Widgets.Size(self.fill, width + Tokens.Size("gapMedium"), TAB_TOP * 2 - UNDERLINE)
			self.underline:ClearAllPoints()
			self.underline:SetPoint("TOPLEFT", tab, "BOTTOMLEFT", 0, -2)
			Widgets.Size(self.underline, width, UNDERLINE)
		end
		x = x + width + gap
		local color = ns.Frames.TabLook(style, i == 1) or (i == 1 and "textEmphasis" or "text")
		tab:SetTextColor(Tokens.Color(color))
	end
	local _, underlined, filled = ns.Frames.TabLook(style, true)
	ns.Frames.PaintUnderline(self.underline, self.glow, underlined)
	self.fill:SetShown(filled)
	self.fill.chrome:SetEdgeRGBA(ar, ag, ab, 1)
	for i, line in ipairs(self.lines) do
		Widgets.TextColor(line, "textEmphasis")
		ns.Frames.ApplyFont(line, path, size, flags)
		line:SetText(Line(SAMPLES[i], settings))
	end
end

function Preview.Build(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetAllPoints(parent)
	local pad = Tokens.Size("gapMedium")
	local glass = Widgets.Panel(frame, {})
	glass:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -pad)
	glass:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -pad, pad)
	frame.glass = glass
	frame.fill = CreateFrame("Frame", nil, glass)
	frame.fill.chrome = Widgets.Chrome(frame.fill, { shape = "tile", fill = "buttonFill", shadow = false })
	local top = CreateFrame("Frame", nil, glass)
	top:SetAllPoints(glass)
	top:SetFrameLevel(frame.fill:GetFrameLevel() + 1)
	frame.tabs = {}
	for i = 1, #TABS do
		local tab = Widgets.FontString(top, "OVERLAY")
		tab:SetPoint("CENTER", glass, "TOPLEFT", pad + (i - 0.5) * TAB_WIDTH, -TAB_TOP)
		frame.tabs[i] = tab
	end
	frame.fill:SetPoint("CENTER", frame.tabs[1], "CENTER")
	Widgets.Size(frame.fill, TAB_WIDTH - pad, TAB_TOP * 2 - UNDERLINE)
	frame.underline = top:CreateTexture(nil, "OVERLAY")
	frame.underline:SetTexture((Tokens.Texture("divider")))
	frame.underline:SetPoint("TOPLEFT", glass, "TOPLEFT", pad + pad, -(TAB_TOP * 2))
	Widgets.Size(frame.underline, TAB_WIDTH - 2 * pad, UNDERLINE)
	frame.glow = top:CreateTexture(nil, "OVERLAY", nil, -1)
	ns.Frames.PlaceGlow(frame.glow, frame.underline)
	frame.divider = glass:CreateTexture(nil, "ARTWORK")
	frame.divider:SetTexture((Tokens.Texture("divider")))
	frame.divider:SetPoint("TOPLEFT", glass, "TOPLEFT", pad, -(TAB_TOP * 2))
	frame.divider:SetPoint("TOPRIGHT", glass, "TOPRIGHT", -pad, -(TAB_TOP * 2))
	frame.divider:SetHeight(K.Scale.Border())
	ns.Panel.PaintRule(frame.divider)
	frame.lines = {}
	local previous
	for i = 1, #SAMPLES do
		local line = Widgets.FontString(glass, "OVERLAY")
		line:SetJustifyH("LEFT")
		line:SetWordWrap(true)
		if previous then
			line:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -LINE_GAP)
		else
			line:SetPoint("TOPLEFT", glass, "TOPLEFT", pad, -(TAB_TOP * 2 + pad))
		end
		line:SetPoint("RIGHT", glass, "RIGHT", -pad, 0)
		frame.lines[i] = line
		previous = line
	end
	frame.Refresh = Refresh
	frame:Refresh()
	return frame
end
