-- Preview.lua: the chat page's live preview in the settings window, a small glass panel with tabs and sample lines drawn with the current settings, its tabs painted by the live chat's own tab look.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, L = K.Widgets, K.Tokens, K.L
local Format = ns.Format

local Preview = {}
ns.Preview = Preview

local build
function Preview.Build(...)
	if build then return build(...) end
	local TAB_WIDTH = 72
	local UNDERLINE = 1
	local LINE_GAP = 3

	local SAMPLES = {
		{ event = "CHAT_MSG_GUILD", channel = "|Hchannel:GUILD|h[" .. L["Guild"] .. "]|h ", name = "Thargor", class = "WARRIOR", text = L["LFM tank for Razorfen Kraul"] },
		{ event = "CHAT_MSG_CHANNEL", channel = "|Hchannel:channel:1|h[1. " .. L["General"] .. " - " .. L["Riverglades"] .. "]|h ", name = "Lunara", class = "MAGE", text = L["Anyone for the croc hunt?"] },
		{ event = "CHAT_MSG_PARTY", channel = "|Hchannel:PARTY|h[" .. L["Party"] .. "]|h ", name = "Valerin", class = "PRIEST", text = L["Route guide:"] .. " www.wowhead.com/forever", mention = L["Thargor, the route guide:"] .. " www.wowhead.com/forever" },
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
			if settings.classMentions == true and sample.mention then
				text = Format.Mentions(sample.mention, { thargor = Format.Hex(K.Theme.Brighten(K.Theme.ClassColor("WARRIOR"))) })
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
		local inset = Tokens.Size("gapMedium")
		local gap = Tokens.Size("gapLarge") + ns.Frames.TabGap(settings) - ns.defaults.tabSpacing
		local pad = Tokens.Size("gapSmall") * ns.Frames.TilePad(settings) / ns.defaults.tabPadding
		local top = ((tonumber(settings.tabHeight) or ns.defaults.tabHeight) - 2) / 2
		local room = settings.buttons == true and (tonumber(settings.sideWidth) or ns.defaults.sideWidth) or 0
		local band = settings.sideRight == true and room or 0
		local left, always = inset + room - band, settings.editBox == "always"
		local tall = tonumber(settings.editHeight) or ns.defaults.editHeight
		local lift = always and settings.inputOnTop == true and tall + inset or 0
		if settings.idleFade == true or self.faded then
			self.faded = settings.idleFade == true
			glass:SetAlpha(self.faded and 1 - math.min(1, tonumber(settings.idleStrength) or 0) or 1)
		end
		self.divider:ClearAllPoints()
		Widgets.Point(self.divider, "TOPLEFT", glass, "TOPLEFT", left, -(top * 2))
		Widgets.Point(self.divider, "TOPRIGHT", glass, "TOPRIGHT", -(inset + room), -(top * 2))
		self.lines[1]:ClearAllPoints()
		Widgets.Point(self.lines[1], "TOPLEFT", glass, "TOPLEFT", left, -(top * 2 + inset + lift))
		self.edit:ClearAllPoints()
		if lift > 0 then
			Widgets.Point(self.edit, "TOPLEFT", glass, "TOPLEFT", left, -(top * 2 + inset))
		else
			Widgets.Point(self.edit, "BOTTOMLEFT", glass, "BOTTOMLEFT", left, inset)
		end
		Widgets.Point(self.edit, "RIGHT", glass, "RIGHT", -(inset + band), 0)
		self.edit:SetHeight(Widgets.Snap(self.edit, tall))
		self.edit:SetShown(always)
		local x = left
		for i, tab in ipairs(self.tabs) do
			ns.Frames.ApplyFont(tab, tabPath, tabSize, flags)
			local label = TABS[i]
			tab:SetText(settings.tabCase == "upper" and label:upper() or label)
			tab:ClearAllPoints()
			Widgets.Point(tab, "LEFT", glass, "TOPLEFT", x, -top)
			local width = Widgets.TextWidth(tab, TAB_WIDTH)
			if i == 1 then
				self.fill:ClearAllPoints()
				Widgets.Point(self.fill, "LEFT", tab, "LEFT", -pad, 0)
				Widgets.Size(self.fill, width + 2 * pad, top * 2 - UNDERLINE)
				self.underline:ClearAllPoints()
				Widgets.Point(self.underline, "TOPLEFT", tab, "BOTTOMLEFT", 0, -2)
				Widgets.Size(self.underline, width, UNDERLINE)
			end
			x = x + width + gap
			local color = ns.Frames.TabLook(style, i == 1) or (i == 1 and "textEmphasis" or "text")
			tab:SetTextColor(Widgets.Rgba(color))
		end
		local _, underlined, filled = ns.Frames.TabLook(style, true)
		ns.Frames.PaintUnderline(self.underline, self.glow, underlined)
		self.fill:SetShown(filled)
		self.fill.chrome:SetFill("buttonFill", settings.tabOpacity ~= 1 and settings.tabOpacity or nil)
		self.fill.wash:SetVertexColor(Widgets.Rgba("accent", K.Skin.TAB_WASH_ALPHA * settings.tabOpacity))
		if settings.tabEdge == "panel" then
			self.fill.chrome:SetEdge("edgeInner")
		else
			self.fill.chrome:SetEdgeRGBA(ar, ag, ab, 1)
		end
		for i, line in ipairs(self.lines) do
			Widgets.Point(line, "RIGHT", glass, "RIGHT", -(inset + band), 0)
			Widgets.TextColor(line, "textEmphasis")
			ns.Frames.ApplyFont(line, path, size, flags)
			line:SetText(Line(SAMPLES[i], settings))
		end
	end

	build = function(parent)
		local frame = CreateFrame("Frame", nil, parent)
		Widgets.Fill(frame, parent, 0, 0, 0, 0)
		local pad = Tokens.Size("gapMedium")
		local glass = Widgets.Panel(frame, {})
		Widgets.Point(glass, "TOPLEFT", frame, "TOPLEFT", pad, -pad)
		Widgets.Point(glass, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -pad, pad)
		frame.glass = glass
		frame.fill = CreateFrame("Frame", nil, glass)
		frame.fill.chrome = Widgets.Chrome(frame.fill, { shape = "tile", fill = "buttonFill", shadow = false })
		frame.fill.wash = frame.fill:CreateTexture(nil, "ARTWORK")
		frame.fill.wash:SetAllPoints(frame.fill)
		frame.fill.wash:SetColorTexture(Tokens.Color("white"))
		frame.edit = CreateFrame("Frame", nil, glass)
		frame.edit.chrome = Widgets.Chrome(frame.edit, { shape = "tile", fill = "buttonFill", shadow = false })
		local top = CreateFrame("Frame", nil, glass)
		top:SetAllPoints(glass)
		top:SetFrameLevel(frame.fill:GetFrameLevel() + 1)
		frame.tabs = {}
		for i = 1, #TABS do
			frame.tabs[i] = Widgets.FontString(top, "OVERLAY")
		end
		frame.underline = top:CreateTexture(nil, "OVERLAY")
		frame.underline:SetTexture((Tokens.Texture("divider")))
		frame.glow = top:CreateTexture(nil, "OVERLAY", nil, -1)
		ns.Frames.PlaceGlow(frame.glow, frame.underline)
		frame.divider = glass:CreateTexture(nil, "ARTWORK")
		frame.divider:SetTexture((Tokens.Texture("divider")))
		frame.divider:SetHeight(K.Scale.Border())
		ns.Panel.PaintRule(frame.divider)
		frame.lines = {}
		local previous
		for i = 1, #SAMPLES do
			local line = Widgets.FontString(glass, "OVERLAY")
			line:SetJustifyH("LEFT")
			line:SetWordWrap(true)
			if previous then
				Widgets.Point(line, "TOPLEFT", previous, "BOTTOMLEFT", 0, -LINE_GAP)
			end
			frame.lines[i] = line
			previous = line
		end
		frame.Refresh = Refresh
		frame:Refresh()
		return frame
	end
	return build(...)
end
