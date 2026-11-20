-- Preview.lua: the settings window's live sample: an item and a unit tooltip drawn with the module's fonts, colours, edges, icon, health bar, away tag, level, faction, mount and item level lines and buff icons.
local _, ns = ...

local K = KstyleUI
local Tokens, Widgets, Theme, L = K.Tokens, K.Widgets, K.Theme, K.L
local Logic, Settings, Style = ns.Logic, ns.Settings, ns.Style

local Preview = {}
ns.Preview = Preview

local build
function Preview.Build(...)
	if build then return build(...) end
	local SAMPLE_WIDTH = 190
	local SAMPLE_QUALITY = 3
	local SAMPLE_HEALTH = 0.72
	local SAMPLE_ICON = 135499
	local SAMPLE_GAP = 24
	local LINE_GAP = 2
	local DIVIDER_GAP = 1
	local DIVIDER_SUBLEVEL = 7
	local BAR_EDGE = 8
	local FRIENDLY = 5
	local PAIR_MIN_SIZE = 8
	local SAMPLE_BUFFS = { 136076, 132212, 132328, 135987, 135906 }

	local ITEM = {
		header = 2,
		{ left = L["Ranger's Long Bow"], role = "title", color = "quality" },
		{ left = Logic.Caption(38, L["Rare"]), role = "small", color = "text" },
		{ left = L["Binds when equipped"], color = "highlight" },
		{ left = L["Two-Hand"], right = L["Bow"], color = "highlight" },
		{ left = L["142 - 198 Damage"], right = L["Speed 1.80"], color = "highlight" },
		{ left = L["+24 Agility"], color = "bonus" },
		{ left = L["Durability 96 / 100"], color = "highlight" },
		{ left = L["Requires Level 38"], color = "highlight" },
		{ left = L["Sold by a ranger in Thunder Bluff."], role = "small", color = "normal" },
	}

	local UNIT = {
		{ left = L["Valerin"], role = "title", kit = "names", color = "class" },
		{ left = "", color = "guild", key = "guildLine" },
		{ left = L["Level 60 Hunter (Player)"], color = "highlight" },
		{ left = L["Horde"], color = "faction", key = "factionColor" },
		{ left = L["Target"], right = L["You"], color = "text", rightColor = "accent", key = "targetLine" },
		{ left = L["Mount"], right = L["Swift Brown Wolf"], color = "text", rightColor = "textEmphasis", key = "mountLine" },
		{ left = L["Item level"], right = "62", color = "text", rightColor = "textEmphasis", key = "itemLevel" },
	}

	local BLIZZARD = { highlight = "HIGHLIGHT_FONT_COLOR", normal = "NORMAL_FONT_COLOR", bonus = "GREEN_FONT_COLOR" }
	local FALLBACK = { highlight = "textEmphasis", normal = "text", bonus = "friendly" }

	local function ClassColor()
		local class = Theme.Class()
		if class then
			return Theme.ClassColor(class)
		end
		return Theme.Accent()
	end

	local function LineColor(kind)
		if kind == "quality" then
			return Theme.QualityColor(SAMPLE_QUALITY, Settings.Get("qualityColors"))
		elseif kind == "class" then
			if Settings.Get("classNames") then
				if Settings.Get("qualityColors") then return Tokens.Color("friendly") end
				return ClassColor()
			end
			kind = "highlight"
		elseif kind == "accent" then
			return Settings.Accent()
		elseif kind == "faction" then
			local c = type(GetFactionColor) == "function" and GetFactionColor("Horde")
			if type(c) == "table" and type(c.GetRGB) == "function" then return c:GetRGB() end
			return Tokens.Color("hostile")
		elseif kind == "guild" or kind == "text" or kind == "textEmphasis" then
			return Tokens.Color(kind == "guild" and "friendly" or kind)
		end
		local color = _G[BLIZZARD[kind]]
		local r, g, b
		if type(color) == "table" and type(color.GetRGB) == "function" then
			r, g, b = color:GetRGB()
		else
			r, g, b = Tokens.Color(FALLBACK[kind])
		end
		if Settings.Get("softColors") then
			local token = Logic.Soften(r, g, b, Style.Palette())
			if token then
				r, g, b = Tokens.Color(token)
			end
		end
		return r, g, b
	end

	local function Sample(frame, spec)
		local glass = CreateFrame("Frame", nil, frame)
		glass.chrome = Widgets.Chrome(glass, { shape = "window", fill = "surface", popup = true })
		glass.divider = glass:CreateTexture(nil, "BORDER", nil, DIVIDER_SUBLEVEL)
		glass.gem = glass:CreateTexture(nil, "OVERLAY")
		glass.spec, glass.rows = spec, {}
		for i, line in ipairs(spec) do
			local row = { left = Widgets.FontString(glass, "OVERLAY") }
			row.left:SetJustifyH("LEFT")
			row.left:SetText(line.left)
			if line.right then
				row.right = Widgets.FontString(glass, "OVERLAY")
				row.right:SetJustifyH("RIGHT")
				row.right:SetText(line.right)
			end
			glass.rows[i] = row
		end
		return glass
	end

	local function Shown(line)
		return line.key == nil or Settings.Get(line.key)
	end

	local function FitPair(row, available, gap)
		local leftPath, leftSize, leftFlags = row.left:GetFont()
		local rightPath, rightSize, rightFlags = row.right:GetFont()
		if Logic.IsSecret(leftPath) or Logic.IsSecret(rightPath) or Logic.IsSecret(leftFlags) or Logic.IsSecret(rightFlags)
			or type(leftPath) ~= "string" or type(rightPath) ~= "string" or type(leftFlags) ~= "string" or type(rightFlags) ~= "string"
			or not Logic.IsNumber(leftSize) or not Logic.IsNumber(rightSize) then
			return
		end
		local originalLeft, originalRight = leftSize, rightSize
		local pixel = Widgets.FontSize(row.left, 0)
		local minimum = Widgets.FontSize(row.left, PAIR_MIN_SIZE * Theme.FontScale())
		local function Restore()
			Widgets.ApplyFont(row.left, leftPath, originalLeft, leftFlags)
			Widgets.ApplyFont(row.right, rightPath, originalRight, rightFlags)
		end
		while true do
			local leftWidth, rightWidth = Widgets.TextWidth(row.left), Widgets.TextWidth(row.right)
			if not Logic.IsNumber(leftWidth) or not Logic.IsNumber(rightWidth) or leftWidth < 0 or rightWidth < 0
				or leftWidth == math.huge or rightWidth == math.huge then
				Restore()
				return
			end
			if leftWidth + rightWidth + gap <= available or leftSize <= minimum and rightSize <= minimum then
				return
			end
			leftSize, rightSize = math.max(minimum, leftSize - pixel), math.max(minimum, rightSize - pixel)
			if not Widgets.ApplyFont(row.left, leftPath, leftSize, leftFlags) or not Widgets.ApplyFont(row.right, rightPath, rightSize, rightFlags) then
				Restore()
				return
			end
		end
	end

	local function Headed(glass)
		if not Settings.Get("divider") then
			return false
		end
		local count = 0
		for _, line in ipairs(glass.spec) do
			count = count + (Shown(line) and 1 or 0)
		end
		return count >= 2
	end

	local function Room(glass)
		return Headed(glass) and Widgets.Snap(glass, Style.GEM_ROOM) or 0
	end

	local function LayoutSample(glass)
		local hierarchy = Settings.Get("hierarchy")
		local pad = Widgets.Snap(glass, Tokens.Size("gapMedium"))
		local gap = Widgets.Snap(glass, LINE_GAP)
		local headed = Headed(glass)
		local x = pad + (glass.indent or 0)
		local reserve = glass.reserve or {}
		local width = Widgets.Snap(glass, SAMPLE_WIDTH + (glass.indent or 0) + (reserve.right or 0))
		local y = pad
		for i, row in ipairs(glass.rows) do
			local line = glass.spec[i]
			local role = line.role or "body"
			local visible = Shown(line)
			row.left:SetShown(visible)
			if row.right then
				row.right:SetShown(visible)
			end
			if visible then
				if row.right then
					Widgets.Fitted(row.left, hierarchy)
					Widgets.Fitted(row.right, hierarchy)
				end
				Style.StyleFont(row.left, role, nil, line.kit)
				row.left:SetTextColor(LineColor(line.color))
				if role == "small" and hierarchy then row.left:SetTextColor(Tokens.Color("medTextMuted")) end
				row.left:ClearAllPoints()
				if hierarchy then
					Widgets.Point(row.left, "TOPLEFT", glass, "TOPLEFT", x, -y)
					Widgets.Point(row.left, "TOPRIGHT", glass, "TOPRIGHT", -pad, -y)
				else
					row.left:SetPoint("TOPLEFT", glass, "TOPLEFT", x, -y)
					row.left:SetPoint("RIGHT", glass, "RIGHT", -pad, 0)
				end
				local _, size = Style.FontSpec(role)
				local height = Widgets.TextHeight(row.left, size)
				if row.right then
					Style.StyleFont(row.right, role)
					row.right:SetTextColor(LineColor(line.rightColor or line.color))
					row.right:ClearAllPoints()
					if hierarchy then Widgets.Point(row.right, "TOPRIGHT", glass, "TOPRIGHT", -pad, -y)
					else row.right:SetPoint("TOPRIGHT", glass, "TOPRIGHT", -pad, -y) end
					FitPair(row, width - x - pad, Widgets.Snap(glass, Tokens.Size("gapSmall")))
				end
				y = y + height + gap
			end
		end
		if glass.spec[2] and glass.spec[2].key == "guildLine" then
			local away = Settings.Get("awayTag") and type(CHAT_FLAG_AFK) == "string"
			glass.rows[1].left:SetText(away and L["Valerin"] .. " " .. CHAT_FLAG_AFK or L["Valerin"])
			glass.rows[2].left:SetText(Settings.Get("guildRank") and Logic.GuildText(L["Kstyle"], L["Officer"]) or Logic.GuildText(L["Kstyle"]))
			local level = L["Level 60 Hunter (Player)"]
			local byLevel = Settings.Get("levelColor") and type(GetCreatureDifficultyColor) == "function" and GetCreatureDifficultyColor(60) or nil
			local r, g, b = Theme.ClassColor("HUNTER")
			local byClass = Settings.Get("classLine") and r and { r = r, g = g, b = b } or nil
			level = Logic.LevelLine(level, TOOLTIP_UNIT_LEVEL, Settings.Get("compactLevel"), PLAYER, byLevel, L["Hunter"], byClass) or level
			glass.rows[3].left:SetText(level)
		end
		Widgets.Size(glass, width, y - gap + pad + (reserve.bottom or 0))
		local divider = glass.divider
		divider:ClearAllPoints()
		Widgets.Point(divider, "TOPLEFT", glass.rows[glass.spec.header or 1].left, "BOTTOMLEFT", 0, -Widgets.Snap(glass, DIVIDER_GAP))
		Widgets.Point(divider, "RIGHT", glass, "RIGHT", -pad, 0)
		divider:SetHeight(Widgets.Border(glass))
		Style.PaintRule(divider)
		divider:SetShown(headed)
		if headed then
			Style.PlaceGem(glass.gem, glass.rows[1].left, glass.spec[1].role)
		else
			glass.gem:Hide()
		end
		glass.chrome:Restyle()
		return width
	end

	local function Edge(glass, on, r, g, b)
		if on then
			glass.chrome:SetEdgeRGBA(r, g, b, 1)
		else
			glass.chrome:SetEdge("edgeInner")
		end
	end

	local function BarColor()
		local source = Settings.Get("bar.color")
		if source == "custom" then
			local c = Settings.Get("bar.custom")
			return c.r, c.g, c.b
		elseif source == "reaction" then
			return Theme.ReactionColor(FRIENDLY)
		end
		return ClassColor()
	end

	local function BarReserve()
		if not Settings.Get("healthBar") then
			return {}
		end
		local room = Settings.Get("bar.size") + ns.Health.GAP
		if Settings.Get("bar.orientation") == "VERTICAL" then
			return { right = room }
		end
		return { bottom = room }
	end

	local function LayoutBar(frame)
		local bar, unit = frame.bar, frame.unit
		local size = Settings.Get("bar.size")
		local edge = Widgets.Snap(unit, BAR_EDGE)
		local side = Widgets.Snap(unit, Tokens.Size("gapMedium"))
		local vertical = Settings.Get("bar.orientation") == "VERTICAL"
		bar:SetOrientation(vertical and "VERTICAL" or "HORIZONTAL")
		bar:SetReverseFill(Settings.Get("bar.reverse"))
		bar:SetBarTexture(Settings.Get("bar.texture"))
		bar:SetBarColor(BarColor())
		bar:ClearAllPoints()
		if vertical then
			bar.opts.width = size
			Widgets.Point(bar, "TOPRIGHT", unit, "TOPRIGHT", -edge, -side)
			Widgets.Point(bar, "BOTTOMRIGHT", unit, "BOTTOMRIGHT", -edge, side)
		else
			bar.opts.height = size
			Widgets.Point(bar, "BOTTOMLEFT", unit, "BOTTOMLEFT", side, edge)
			Widgets.Point(bar, "BOTTOMRIGHT", unit, "BOTTOMRIGHT", -side, edge)
		end
		bar:Restyle()
		bar:SetShown(Settings.Get("healthBar"))
	end

	local function LayoutIcon(frame)
		local icon = frame.icon
		local size = Settings.Get("iconSize")
		Style.PlaceIcon(icon, frame.item, size)
		Style.PaintIcon(icon, SAMPLE_QUALITY)
		icon:SetShown(Settings.Get("icon"))
	end

	local function LayoutBuffs(frame)
		local on = Settings.Get("buffs.shown")
		if on and not frame.buffs then
			frame.buffs = {}
			for i, id in ipairs(SAMPLE_BUFFS) do
				frame.buffs[i] = Style.IconTile(frame)
				frame.buffs[i].texture:SetTexture(id)
			end
		end
		for i, icon in ipairs(frame.buffs or {}) do
			if on then
				Style.PlaceBuff(icon, frame.unit, i)
				Style.PaintIcon(icon)
			end
			icon:SetShown(on)
		end
		local side = Settings.Get("buffs.position")
		if not on or side == "BOTTOM" then
			return 0
		end
		local rows = math.ceil(#SAMPLE_BUFFS / Settings.Get("buffs.perRow"))
		return math.max(0, Settings.Get("buffs.y") + (side == "TOP" and rows * (Settings.Get("buffs.size") + Tokens.Size("gapSmall")) or 0))
	end

	local function Refresh(frame)
		frame.item.indent = (Settings.Get("icon") and Settings.Get("iconSize") + Tokens.Size("gapLarge") or 0) + Room(frame.item)
		if Settings.Get("hierarchy") then frame.item.indent = Widgets.Snap(frame.item, frame.item.indent) end
		local width = LayoutSample(frame.item)
		frame.item:ClearAllPoints()
		local available = frame:GetWidth()
		if Settings.Get("hierarchy") and Logic.IsNumber(available) and available > 0 and available < math.huge then
			Widgets.Point(frame.item, "TOPLEFT", frame, "TOPLEFT", Widgets.Snap(frame, (available - width) / 2), -Tokens.Size("gapLarge"))
		else
			Widgets.Point(frame.item, "TOP", frame, "TOP", 0, -Tokens.Size("gapLarge"))
		end
		frame.unit.indent = Room(frame.unit)
		frame.unit.reserve = BarReserve()
		LayoutSample(frame.unit)
		local qr, qg, qb = Theme.QualityColor(SAMPLE_QUALITY, Settings.Get("qualityColors"))
		Edge(frame.item, Settings.Get("qualityEdge"), qr, qg, qb)
		local cr, cg, cb = ClassColor()
		Edge(frame.unit, Settings.Get("unitEdge"), cr, cg, cb)
		LayoutIcon(frame)
		LayoutBar(frame)
		local rise = LayoutBuffs(frame)
		frame.unit:ClearAllPoints()
		Widgets.Point(frame.unit, "TOPLEFT", frame.item, "BOTTOMLEFT", 0, -Widgets.Snap(frame.unit, SAMPLE_GAP + rise))
	end

	build = function(parent)
		local frame = CreateFrame("Frame", nil, parent)
		Widgets.Fill(frame, parent, 0, 0, 0, 0)
		frame.item = Sample(frame, ITEM)
		frame.unit = Sample(frame, UNIT)
		frame.icon = Style.IconTile(frame.item)
		frame.icon.texture:SetTexture(SAMPLE_ICON)
		frame.bar = Widgets.StatusBar(frame.unit, { background = "track", border = true, min = 0, max = 1, value = SAMPLE_HEALTH })
		frame.glass, frame.title, frame.caption = frame.item, frame.item.rows[1].left, frame.item.rows[2].left
		frame.Refresh = Refresh
		Refresh(frame)
		return frame
	end
	return build(...)
end
