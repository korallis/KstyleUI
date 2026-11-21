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
	local CHEVRON = 8
	local LINE_GAP = 3
	local SLOT, TILE, GLYPH, SPARE = 32, 20, 8, 6
	local MENU, FRIENDS = "ChatFrameMenuButton", "QuickJoinToastButton"
	local NAMES = { channels = { "ChatFrameChannelButton" }, voice = { "ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton" }, menu = { MENU } }

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

	local function Tile(self, n, kind, scale)
		local tile = self.icons[n]
		if not tile then
			tile = CreateFrame("Frame", nil, self)
			tile:SetFrameLevel(self.glass:GetFrameLevel() + 3)
			tile.chrome = Widgets.Chrome(tile, { shape = "tile", fill = "buttonFill", shadow = false })
			tile.glyph = tile:CreateTexture(nil, "OVERLAY")
			tile.glyph:SetPoint("CENTER", tile, "CENTER")
			Widgets.Tint(tile.glyph, "text")
			self.icons[n] = tile
		end
		tile.glyph:SetShown(kind == MENU or kind == "scroll")
		tile.glyph:SetTexture((Tokens.Texture(kind == MENU and "glyphClose" or "glyphChevron")))
		tile.glyph:SetRotation(kind == MENU and math.pi / 4 or 0)
		Widgets.Size(tile.glyph, GLYPH * scale, GLYPH * scale)
		Widgets.Size(tile, TILE * scale, TILE * scale)
		tile:SetAlpha(self.glass:GetAlpha())
		tile:Show()
		return tile
	end

	local function Buttons(self, settings, cx, right, from, foot)
		local n, scale = 0, tonumber(settings.sideScale) or 1
		local pitch, edge = SLOT * scale + (tonumber(settings.sideSpacing) or 0), right and "RIGHT" or "LEFT"
		local x = right and -cx or cx
		if settings.buttons == true then
			local icons, ids, top, bottom, free = settings.sideIcons or {}, {}, {}, {}, {}
			local spots = settings.sideFree == true and type(settings.sidePositions) == "table" and settings.sidePositions or {}
			local function Add(list, name)
				local spot = spots[name]
				list = type(spot) == "table" and type(spot.x) == "number" and type(spot.y) == "number" and free or list
				list[#list + 1] = name
			end
			for id in tostring(settings.sideOrder):gmatch("%a+") do ids[#ids + 1] = id end
			if icons.friends ~= false then Add(top, FRIENDS) end
			for i, id in ipairs(ids) do
				for _, name in ipairs(icons[id] ~= false and NAMES[id] or {}) do Add(i == #ids and bottom or top, name) end
			end
			if settings.sideScroll == true then table.insert(bottom, "scroll") end
			for side, list in ipairs({ top, bottom }) do
				for i, kind in ipairs(list) do
					n = n + 1
					local tile = Tile(self, n, kind, scale)
					tile:ClearAllPoints()
					Widgets.Point(tile, "CENTER", self.glass, (side == 1 and "TOP" or "BOTTOM") .. edge, x, side == 1 and -(from + (i - 0.5) * pitch) or foot + (#list - i + 0.5) * pitch)
				end
			end
			local w, h = self.glass:GetWidth(), self.glass:GetHeight()
			local left = (right and w - cx or cx) - ((tonumber(settings.sideWidth) or ns.defaults.sideWidth) - SPARE) / 2
			local below = from + (top[1] == FRIENDS and pitch or 0)
			for _, name in ipairs(free) do
				n = n + 1
				local tile = Tile(self, n, name, scale)
				local px, py = left + spots[name].x, spots[name].y - below
				if w > 0 and h > 0 then px, py = math.min(w, math.max(0, px)), math.max(-h, math.min(0, py)) end
				tile:ClearAllPoints()
				Widgets.Point(tile, "CENTER", self.glass, "TOPLEFT", px, py)
			end
		end
		for i = n + 1, #self.icons do self.icons[i]:Hide() end
	end

	local function Refresh(self)
		local settings = ns.Settings()
		local glass, card = self.glass, self.card
		local r, g, b = Tokens.Color("surface")
		for _, panel in ipairs({ card, self.strip }) do
			panel.chrome:SetFillRGBA(r, g, b, settings.panelOpacity)
			panel.chrome:SetShadow(settings.shadow == true)
		end
		local path, size, flags, tabSize, tabPath = ns.Frames.Fonts(settings)
		local ar, ag, ab = ns.Accent(settings)
		local style = settings.tabStyle
		local inset = Tokens.Size("gapMedium")
		local gap = Tokens.Size("gapLarge") + ns.Frames.TabGap(settings) - ns.defaults.tabSpacing
		local pad = Tokens.Size("gapSmall") * ns.Frames.TilePad(settings) / ns.defaults.tabPadding
		local top = ((tonumber(settings.tabHeight) or ns.defaults.tabHeight) - 2) / 2
		local room = settings.buttons == true and (tonumber(settings.sideWidth) or ns.defaults.sideWidth) or 0
		local beside = room > 0 and (settings.sideStyle == "glass" or settings.sideStyle == "bare")
		local strip = beside and 2 * inset + room - SPARE or 0
		local apart = beside and strip + (tonumber(settings.sideGap) or 0) or 0
		local right = settings.sideRight == true
		room = beside and 0 or room
		local band = right and room + apart or 0
		local separate = settings.editFont ~= "messages" or settings.editFontSize ~= ns.FOLLOW
		local left, always = inset + (right and 0 or room + apart), settings.editBox == "always" or separate
		local tall = tonumber(settings.editHeight) or ns.defaults.editHeight
		local lift = always and settings.inputOnTop == true and tall + inset or 0
		local above = settings.tabsAbove == true and top * 2 or 0
		local edge = inset + (beside and band or room)
		if settings.idleFade == true or self.faded then
			self.faded = settings.idleFade == true
			local alpha = self.faded and 1 - math.min(1, tonumber(settings.idleStrength) or 0) or 1
			glass:SetAlpha(alpha)
			card:SetAlpha(alpha)
			self.strip:SetAlpha(alpha)
		end
		card:ClearAllPoints()
		Widgets.Point(card, "TOPLEFT", glass, "TOPLEFT", right and 0 or apart, -above)
		Widgets.Point(card, "BOTTOMRIGHT", glass, "BOTTOMRIGHT", right and -apart or 0, 0)
		self.strip:ClearAllPoints()
		Widgets.Point(self.strip, right and "TOPRIGHT" or "TOPLEFT", glass, right and "TOPRIGHT" or "TOPLEFT", 0, -above)
		Widgets.Point(self.strip, right and "BOTTOMRIGHT" or "BOTTOMLEFT", glass, right and "BOTTOMRIGHT" or "BOTTOMLEFT", 0, 0)
		self.strip:SetWidth(math.max(1, strip))
		self.strip:SetShown(beside and settings.sideStyle == "glass" and not ns.Panel.Bare(settings))
		Buttons(self, settings, beside and strip / 2 or inset + (room - SPARE) / 2, right, top * 2 + inset, inset)
		self.divider:SetShown(above == 0)
		self.divider:ClearAllPoints()
		Widgets.Point(self.divider, "TOPLEFT", glass, "TOPLEFT", left, -(top * 2))
		Widgets.Point(self.divider, "TOPRIGHT", glass, "TOPRIGHT", -edge, -(top * 2))
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
		self.edit.text:SetShown(separate)
		if separate then
			local editPath, editSize = ns.Frames.EditFont(settings)
			ns.Frames.ApplyFont(self.edit.text, editPath, editSize, flags)
			self.edit.text:SetText((type(CHAT_SAY_SEND) == "string" and CHAT_SAY_SEND or "") .. L["Anyone for the croc hunt?"])
		end
		local x = left
		local limit = glass:GetWidth() > 0 and glass:GetWidth() - edge or math.huge
		local spare = limit - x
		for i, tab in ipairs(self.tabs) do
			ns.Frames.ApplyFont(tab, tabPath, tabSize, flags)
			local label = TABS[i]
			tab:SetText(settings.tabCase == "upper" and label:upper() or label)
			spare = spare - Widgets.TextWidth(tab, TAB_WIDTH)
		end
		local fits = spare >= math.min(gap, Tokens.Size("gapSmall")) * (#self.tabs - 1)
		local stop = fits and limit or limit - CHEVRON - Tokens.Size("gapSmall")
		gap = math.max(math.min(gap, Tokens.Size("gapSmall")), math.min(gap, spare / (#self.tabs - 1)))
		for i, tab in ipairs(self.tabs) do
			tab:ClearAllPoints()
			Widgets.Point(tab, "LEFT", glass, "TOPLEFT", x, -top)
			local width = Widgets.TextWidth(tab, TAB_WIDTH)
			if above > 0 or tab.sized then
				tab.sized = above > 0
				tab:SetSize(tab.sized and width + Widgets.TrackPad(tab) or 0, tab.sized and top * 2 or 0)
			end
			if i == 1 then
				self.fill:ClearAllPoints()
				Widgets.Point(self.fill, "LEFT", tab, "LEFT", -pad, 0)
				Widgets.Size(self.fill, width + 2 * pad, top * 2 - UNDERLINE)
				self.underline:ClearAllPoints()
				Widgets.Point(self.underline, "TOPLEFT", tab, "BOTTOMLEFT", 0, -2)
				Widgets.Size(self.underline, width, UNDERLINE)
			end
			tab:SetShown(i == 1 or self.tabs[i - 1]:IsShown() and x + width <= stop)
			if tab:IsShown() then x = x + width + gap end
			local color = ns.Frames.TabLook(style, i == 1) or (i == 1 and "textEmphasis" or "text")
			tab:SetTextColor(Widgets.Rgba(color))
		end
		self.more:SetShown(not fits)
		Widgets.Point(self.more, "RIGHT", glass, "TOPRIGHT", -edge, -top)
		Widgets.Tint(self.more, ns.Frames.TabLook(style, false) or "text")
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
		frame.card = Widgets.Panel(frame, {})
		frame.strip = Widgets.Panel(frame, {})
		local glass = CreateFrame("Frame", nil, frame)
		glass:SetFrameLevel(frame.card:GetFrameLevel() + 2)
		Widgets.Point(glass, "TOPLEFT", frame, "TOPLEFT", pad, -pad)
		Widgets.Point(glass, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -pad, pad)
		frame.glass, frame.icons = glass, {}
		frame.fill = CreateFrame("Frame", nil, glass)
		frame.fill.chrome = Widgets.Chrome(frame.fill, { shape = "tile", fill = "buttonFill", shadow = false })
		frame.fill.wash = frame.fill:CreateTexture(nil, "ARTWORK")
		frame.fill.wash:SetAllPoints(frame.fill)
		frame.fill.wash:SetColorTexture(Tokens.Color("white"))
		frame.edit = CreateFrame("Frame", nil, glass)
		frame.edit.chrome = Widgets.Chrome(frame.edit, { shape = "tile", fill = "buttonFill", shadow = false })		frame.edit.text = Widgets.FontString(frame.edit, "OVERLAY")
		Widgets.Point(frame.edit.text, "LEFT", frame.edit, "LEFT", Tokens.Size("gapSmall"), 0)
		Widgets.Point(frame.edit.text, "RIGHT", frame.edit, "RIGHT", -Tokens.Size("gapSmall"), 0)
		frame.edit.text:SetJustifyH("LEFT")
		frame.edit.text:Hide()
		local top = CreateFrame("Frame", nil, glass)
		top:SetAllPoints(glass)
		top:SetFrameLevel(frame.fill:GetFrameLevel() + 1)
		frame.tabs = {}
		for i = 1, #TABS do
			frame.tabs[i] = Widgets.FontString(top, "OVERLAY")
		end
		frame.more = top:CreateTexture(nil, "OVERLAY")
		frame.more:SetTexture((Tokens.Texture("glyphChevron")))
		Widgets.Size(frame.more, CHEVRON, CHEVRON)
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
