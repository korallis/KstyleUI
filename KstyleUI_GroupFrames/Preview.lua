-- Preview.lua: the settings window's live preview: sample party frames scaled to fit the pane and four raid tiles at true scale, with pet, tank and friendly boss samples under them while those groups are on, drawn with the same look as the real ones, stacked over the click casting panel and refitted whenever the pane's size resolves or changes.
local _, ns = ...

local K = KstyleUI
local Tokens, Theme, L = K.Tokens, K.Theme, K.L
local Settings, Geometry, Style, Unit = ns.Settings, ns.Geometry, ns.Style, ns.Unit

local Preview = {}
ns.Preview = Preview

local build
function Preview.Build(...)
	if build then return build(...) end
	local PARTY_SHOWN = 3
	local RAID_GROUPS_SHOWN = 2
	local GROUP_SIZE = 2
	local RAID_SAMPLES = { 1, 2, 6, 4 }
	local SECTION_GAP = 16
	local SAMPLE_LEVEL = 60
	local SAMPLE_MAX = 41800
	local PERCENT = 100

	local SAMPLES = {
		{
			name = "Thaldren", follower = "Thaldren Ironvow", class = "WARRIOR", health = 0.72, power = 0.35, role = "TANK", leader = true, threat = 3, absorb = 0.05, shield = 0.3,
			healAbsorb = 0.18, debuffs = 2, hots = 2, boss = true, indicators = { EXTERNAL = true }, combat = true, overshield = 0.4, targetName = "Gorvak", you = true,
		},
		{ name = "Sylaen", class = "DRUID", health = 0.87, power = 0.8, far = true, role = "HEALER", dispel = "Magic", debuffs = 1, hots = 1, indicators = { CROWD_CONTROL = true }, targetName = "Thaldren", targetClass = "WARRIOR" },
		{ name = "Kragar", class = "SHAMAN", health = 0.76, power = 0.6, target = true, role = "DAMAGER", marker = 1, incoming = 0.12, healAbsorb = 0.1, maxLoss = 0.15, targetName = "Gorvak" },
		{ name = "Lunara", class = "MAGE", health = 0, power = 0, dead = true },
		{ name = "Vexen", class = "PRIEST", health = 0.94, power = 0.9 },
		{ name = "Orrin", class = "PALADIN", health = 0.55, power = 0.5, debuffs = 9, dispel = "Curse", hots = 3, shield = 0.2, healAbsorb = 0.12, indicators = { EXTERNAL = true } },
		{ name = "Kesh", class = "ROGUE", health = 1, power = 1 },
		{ name = "Maela", class = "HUNTER", health = 0.68, power = 0.7 },
		{ name = "Durn", class = "WARLOCK", health = 0.81, power = 0.4, offline = true },
		{ name = "Ysra", class = "PRIEST", health = 0.33, power = 0.6 },
	}
	local EXTRAS = {
		pets = { { name = "Grawl", class = "HUNTER", health = 0.76, power = 0.5 }, { name = "Imp", class = "WARLOCK", health = 0.58, power = 0.9 } },
		tanks = { { name = "Thaldren", class = "WARRIOR", role = "TANK", health = 0.72, power = 0.35 }, { name = "Brannoc", class = "PALADIN", role = "TANK", health = 0.64, power = 0.4 } },
		boss = { { name = "Valithria", class = "DRUID", health = 0.62, power = 0.8 } },
	}

	local function Low(sample)
		return not (sample.dead or sample.offline) and sample.health < K.Widgets.LOW_HEALTH_SHARE
	end

	local function Gradient(share)
		local stops = Unit.GradientStops()
		for i = 2, #stops do
			local a, b = stops[i - 1], stops[i]
			if share <= b[1] then
				local t = (share - a[1]) / (b[1] - a[1])
				local ca, cb = a[2], b[2]
				return ca.r + (cb.r - ca.r) * t, ca.g + (cb.g - ca.g) * t, ca.b + (cb.b - ca.b) * t
			end
		end
	end

	local function HealthText(f, sample)
		local text = f.healthText
		text:SetAlpha(1)
		text:SetTextColor(Tokens.Color(Low(sample) and "healthLow" or "textEmphasis"))
		if sample.offline then
			text:SetText(L["Offline"])
			return
		elseif sample.dead then
			text:SetText(L["Dead"])
			return
		end
		local format = Settings.current[f.kind].healthText
		local current = math.floor(SAMPLE_MAX * sample.health + 0.5)
		local percent = K.Widgets.WholePercent(PERCENT * sample.health)
		if format == "NONE" then
			text:SetText("")
		elseif format == "PERCENT" then
			text:SetFormattedText("%d%%", percent)
		elseif format == "DEFICIT" then
			text:SetText("-" .. Unit.Abbreviate(SAMPLE_MAX - current, f.kind))
			text:SetAlpha(sample.health < 1 and 1 or 0)
		elseif format == "CURRENT_MAX" then
			text:SetFormattedText("%s / %s", Unit.Abbreviate(current, f.kind), Unit.Abbreviate(SAMPLE_MAX, f.kind))
		elseif format == "CURRENT_PERCENT" then
			text:SetFormattedText("%s  %d%%", Unit.Abbreviate(current, f.kind), percent)
		else
			text:SetText(Unit.Abbreviate(current, f.kind))
		end
	end

	local function Paint(f, sample)
		local cfg = Settings.current
		f.status = (sample.offline and "offline") or (sample.dead and "dead") or nil
		if cfg[f.kind].classLine == true then
			f.classCaption = sample.class .. " " .. SAMPLE_LEVEL
			f.classLine:SetText(f.classCaption)
		end
		Style.PlaceRowEnd(f)
		local cr, cg, cb = Theme.ClassColor(sample.class)
		f.health:SetBarRange(0, 1)
		f.health:SetBarValue(f.missingFill and 1 - sample.health or sample.health)
		local alpha, source = cfg.health.alpha, Unit.ColorSources(f)
		local r, g, b
		if sample.dead or sample.offline then
			r, g, b = Unit.StatusColor(sample.offline and "offline" or "dead")
		elseif source == "gradient" then
			r, g, b = Gradient(sample.health)
		elseif Low(sample) then
			r, g, b = Tokens.Color("healthLow")
		elseif source == "class" then
			r, g, b = cr, cg, cb
		elseif source == "reaction" then
			r, g, b = Tokens.Color("friendly")
		else
			local c = cfg.health.color
			r, g, b = c.r, c.g, c.b
		end
		f.health:SetBarColor(r, g, b, alpha)
		f.health.fillClip:SetAlpha(alpha)
		if f.showPower then
			f.power:SetBarRange(0, 1)
			f.power:SetBarValue(sample.power)
			local c = cfg.power.color
			if cfg.power.colorSource == "custom" then
				f.power:SetBarColor(c.r, c.g, c.b)
			elseif cfg.power.colorSource == "class" then
				f.power:SetBarColor(cr, cg, cb)
			else
				f.power:SetBarColor(Tokens.Color("rare"))
			end
		end
		ns.Names.Set(f, cfg[f.kind].nameFormat ~= "FULL" and sample.follower or sample.name)
		if f.status then
			f.name:SetTextColor(Tokens.Color("textDisabled"))
		elseif cfg.text.nameColorSource == "class" then
			f.name:SetTextColor(Unit.NameColor(sample.class))
		end
		Unit.NameColored(f, sample.class)
		if f.showPortrait or f.showRoleRing then
			f.ring:SetVertexColor(cr, cg, cb, cfg[f.kind].portraitRingAlpha or 1)
		end
		if f.showPortrait then
			f.portrait:SetTexture((Tokens.Texture("logo")))
			local zoom = cfg[f.kind].portraitZoom
			f.portrait:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
			f.level:SetText(SAMPLE_LEVEL)
		elseif f.showRoleRing then
			f.roleText:SetText(Style.ROLE_LETTERS[sample.role] or "")
		end
		HealthText(f, sample)
		local fade = cfg.range.fade and sample.far
		f:SetAlpha(fade and cfg.range.alpha or 1)
		f.target:SetAlpha(sample.target and cfg.accent.target and 1 or 0)
		if f.extra1 or f.extra2 then
			Unit.TextSlots(f, nil, { name = sample.name, health = sample.health * SAMPLE_MAX, healthMax = SAMPLE_MAX,
				power = sample.power and sample.power * 100 or 0, powerMax = 100, level = sample.level or 60, class = sample.class, own = true })
		end
		for _, hook in ipairs(Style.painters) do
			hook(f, sample)
		end
	end

	local SAMPLE_NAMES = {}
	for i, sample in ipairs(SAMPLES) do
		SAMPLE_NAMES[i] = sample.name
	end

	local function Sample(parent, kind, index, sample)
		local f = CreateFrame("Frame", nil, parent)
		Style.Build(f, kind)
		local pick = kind == "raid" and RAID_SAMPLES[index] or index
		f.sample, f.order = sample or SAMPLES[(pick - 1) % #SAMPLES + 1], index
		f.others = SAMPLE_NAMES
		for _, hook in ipairs(ns.Button.built) do
			hook(f)
		end
		return f
	end

	local function PlaceRun(frames, holder, s, growth, count, x0, y0, corner, width, spacing)
		width, spacing = width or s.width, spacing or s.spacing
		local dx, dy = Geometry.Offset(growth, 1)
		local stepX = Geometry.IsVertical(growth) and 0 or (width + spacing)
		local stepY = Geometry.IsVertical(growth) and (s.height + spacing) or 0
		for i = 1, count do
			local f = frames[i]
			f:ClearAllPoints()
			f:SetSize(width, s.height)
			f:SetPoint(corner, holder, corner, x0 + dx * stepX * (i - 1), y0 + dy * stepY * (i - 1))
		end
	end

	local function Order(frames, byClass, per, kind)
		local rank, list = {}, Settings.ClassList(kind)
		for i = #Settings.CLASSES, 1, -1 do rank[Settings.current.sort[list .. i]] = i end
		local function Key(f)
			return (per and math.ceil(f.order / per) or 0) * 100 + (byClass and rank[f.sample.class] or 0)
		end
		table.sort(frames, function(a, b)
			local ka, kb = Key(a), Key(b)
			if ka ~= kb then return ka < kb end
			return a.order < b.order
		end)
	end

	local function Sized(value)
		return not Unit.IsSecret(value) and type(value) == "number" and value == value and value > 0 and value < math.huge
	end

	local function Layout(preview)
		local availW, availH = preview:GetWidth(), preview:GetHeight()
		if not Sized(availW) or not Sized(availH) then
			return
		end
		local cfg = Settings.Refresh()
		local party, raid = cfg.party, cfg.raid
		local partyGeo = Geometry.Party(party)
		local count = math.min(PARTY_SHOWN, partyGeo.count)
		local pw = Geometry.IsVertical(party.growth) and party.width or Geometry.Line(count, party.width, party.spacing)
		local ph = Geometry.IsVertical(party.growth) and Geometry.Line(count, party.height, party.spacing) or party.height
		local tw, th = ns.Targets.Room(party)
		pw, ph = pw + tw, ph + th
		preview.party:SetSize(pw, ph)
		preview.party:ClearAllPoints()
		preview.party:SetPoint("TOPLEFT", preview.canvas, "TOPLEFT", 0, 0)
		local memberSpacing = Geometry.IsVertical(party.growth) and party.spacing or (party.spacing + partyGeo.lane)
		local x0 = partyGeo.laneSide == "LEFT" and partyGeo.lane or 0
		local separate = raid.sortBy == "GROUP" and not raid.merge
		Order(preview.partyFrames, Settings.ClassFirst("party") and party.sortBy ~= "ROLE", nil, "party")
		Order(preview.raidFrames, raid.sortBy == "CLASS" or separate and Settings.ClassFirst("raid"), separate and GROUP_SIZE, "raid")
		PlaceRun(preview.partyFrames, preview.party, party, party.growth, count, x0, 0, partyGeo.corner, partyGeo.memberWidth, memberSpacing)
		local total = GROUP_SIZE * RAID_GROUPS_SHOWN
		local size = raid.sortBy == "GROUP" and raid.merge and math.min(raid.unitsPerColumn, total) or GROUP_SIZE
		local shownGroups = math.ceil(total / size)
		local gw, gh
		if Geometry.IsVertical(raid.growth) then
			gw, gh = raid.width, Geometry.Line(size, raid.height, raid.spacing)
		else
			gw, gh = Geometry.Line(size, raid.width, raid.spacing), raid.height
		end
		local groupsWide = not Geometry.IsVertical(Geometry.Perpendicular(raid.growth, raid.groupGrowth))
		local numberRoom = cfg.numbers.show and raid.sortBy == "GROUP" and not raid.merge and cfg.numbers.size + 2 or 0
		local groupSpacing = raid.groupSpacing + numberRoom
		local groups = 0
		for g = 1, 8 do groups = groups + (cfg.groups["show" .. g] and 1 or 0) end
		local centre = math.max(0, ((raid.center and separate and math.min(raid.groupsPerRow, groups) or 0) - shownGroups) / 2)
		local rw = groupsWide and Geometry.Line(shownGroups + 2 * centre, gw, groupSpacing) or gw
		local rh = (groupsWide and gh or Geometry.Line(shownGroups + 2 * centre, gh, groupSpacing)) + numberRoom
		preview.raid:SetSize(rw, rh)
		preview.raid:ClearAllPoints()
		preview.raid:SetPoint("TOPLEFT", preview.raidCanvas, "TOPLEFT", 0, 0)
		local corner = Geometry.Corner(raid.growth, raid.groupGrowth)
		for g = 1, shownGroups do
			local frames = {}
			for m = 1, math.min(size, total - (g - 1) * size) do
				frames[m] = preview.raidFrames[(g - 1) * size + m]
			end
			local ox, oy = Geometry.Offset(Geometry.Perpendicular(raid.growth, raid.groupGrowth), (g - 1 + centre) * ((groupsWide and gw or gh) + groupSpacing))
			PlaceRun(frames, preview.raid, raid, raid.growth, #frames, ox, oy - (corner:find("TOP", 1, true) and numberRoom or 0), corner)
			local number = preview.numbers[g]
			if cfg.numbers.show and not number then
				number = K.Widgets.FontString(preview.raid, "OVERLAY")
				preview.numbers[g] = number
			end
			if number then
				number:SetShown(cfg.numbers.show and raid.sortBy == "GROUP" and not raid.merge)
				Style.SetFont(number, cfg.text.healthFont, cfg.numbers.size, "OUTLINE")
				number:SetTextColor(Tokens.Color("text"))
				number:SetText(g)
				number:ClearAllPoints()
				number:SetPoint("BOTTOM", frames[raid.growth == "UP" and #frames or 1], "TOP", cfg.numbers.x, 1 + cfg.numbers.y)
			end
		end
		local ex, eh = 0, 0
		for _, name in ipairs({ "pets", "tanks", "boss" }) do
			local list, s = preview.extras[name], cfg[name]
			local on = s.enabled or name == "boss" and s.display ~= "NEVER"
			list.holder:SetShown(on)
			if on then
				local w, h, spacing = ns.Extras.Size(name)
				local growth = name == "tanks" and s.growth or raid.growth
				local wrap = Geometry.Perpendicular(growth, name == "tanks" and s.wrap or "RIGHT")
				local items = name == "tanks" and s.excludeSelf and { list[2] } or list
				if name == "tanks" then list[1]:SetShown(not s.excludeSelf) end
				local per = name == "tanks" and s.wrapAfter > 0 and s.wrapAfter or #items
				local vertical, lines = Geometry.IsVertical(growth), math.ceil(#items / per)
				local along, across = Geometry.Line(math.min(per, #items), vertical and h or w, spacing), Geometry.Line(lines, vertical and w or h, spacing)
				local bw, bh = vertical and across or along, vertical and along or across
				list.holder:SetSize(bw, bh)
				list.holder:ClearAllPoints()
				list.holder:SetPoint("TOPLEFT", preview.raid, "TOPLEFT", ex, -(rh + groupSpacing))
				for line = 1, lines do
					local run = {}
					for m = 1, per do run[m] = items[(line - 1) * per + m] end
					local ox, oy = Geometry.Offset(wrap, (line - 1) * ((vertical and w or h) + spacing))
					PlaceRun(run, list.holder, { height = h }, growth, #run, ox, oy, Geometry.Corner(growth, wrap), w, spacing)
				end
				for _, f in ipairs(items) do
					Style.Apply(f, w, h)
					Paint(f, f.sample)
				end
				ex, eh = ex + bw + groupSpacing, math.max(eh, bh)
			end
		end
		if eh > 0 then
			rw, rh = math.max(rw, ex - groupSpacing), rh + groupSpacing + eh
			preview.raid:SetSize(rw, rh)
		end
		preview.canvas:SetSize(pw, ph)
		preview.raidCanvas:SetSize(rw, rh)
		local top = math.min(Tokens.Size("gapTiny"), availH / 4)
		local gap = math.min(SECTION_GAP, availH / 4)
		local showClick = availH > top + ns.ClickCast.HEIGHT + 2 * gap
		local manaHeight, labelHeight = ns.Readouts.Sample(preview.mana, preview.label)
		local readouts = (manaHeight > 0 and manaHeight + gap / 2 or 0) + (labelHeight > 0 and labelHeight + gap / 2 or 0)
		local room = availH - top - gap - readouts - (showClick and ns.ClickCast.HEIGHT + gap or 0)
		local raidScale = math.min(1, availW / rw)
		local scale = math.min(1, availW / pw)
		if room <= rh * raidScale then
			local fit = room / (ph * scale + rh * raidScale)
			scale, raidScale = scale * fit, raidScale * fit
		else
			scale = math.min(scale, (room - rh * raidScale) / ph)
		end
		preview.canvas:SetScale(scale)
		preview.canvas:ClearAllPoints()
		preview.canvas:SetPoint("TOPLEFT", preview, "TOPLEFT", 0, -top / scale)
		local raidTop = top + ph * scale + gap
		preview.raidCanvas:SetScale(raidScale)
		preview.raidCanvas:ClearAllPoints()
		preview.raidCanvas:SetPoint("TOPLEFT", preview, "TOPLEFT", 0, -raidTop / raidScale)
		for i, f in ipairs(preview.partyFrames) do
			f:SetShown(i <= count)
			Style.Apply(f, partyGeo.memberWidth, party.height)
			Paint(f, f.sample)
		end
		for i, f in ipairs(preview.raidFrames) do
			f:SetShown(i <= math.min(groups, RAID_GROUPS_SHOWN) * GROUP_SIZE)
			Style.Apply(f, raid.width, raid.height)
			Paint(f, f.sample)
		end
		local height = raidTop + rh * raidScale
		for _, part in ipairs({ { preview.mana, manaHeight }, { preview.label, labelHeight } }) do
			if part[2] > 0 then
				part[1]:ClearAllPoints()
				part[1]:SetPoint("TOPLEFT", preview, "TOPLEFT", 0, -(height + gap / 2))
				height = height + gap / 2 + part[2]
			end
		end
		preview.clickCast:ClearAllPoints()
		preview.clickCast:SetPoint("TOPLEFT", preview, "TOPLEFT", 0, -(height + gap))
		preview.clickCast:SetPoint("RIGHT", preview, "RIGHT", 0, 0)
		preview.clickCast:SetHeight(ns.ClickCast.HEIGHT)
		preview.clickCast:SetShown(showClick)
		preview.clickCast:Refresh()
	end

	build = function(parent)
		local preview = CreateFrame("Frame", nil, parent)
		preview:SetAllPoints(parent)
		preview.canvas = K.Widgets.MarkPreview(CreateFrame("Frame", nil, preview))
		preview.raidCanvas = K.Widgets.MarkPreview(CreateFrame("Frame", nil, preview))
		preview.party = CreateFrame("Frame", nil, preview.canvas)
		preview.raid = CreateFrame("Frame", nil, preview.raidCanvas)
		preview.partyFrames, preview.raidFrames, preview.numbers, preview.extras = {}, {}, {}, {}
		preview.mana, preview.label = CreateFrame("Frame", nil, preview), CreateFrame("Frame", nil, preview)
		for i = 1, PARTY_SHOWN do
			preview.partyFrames[i] = Sample(preview.party, "party", i)
			preview.partyFrames[i].nameGroup = preview.partyFrames
		end
		for i = 1, RAID_GROUPS_SHOWN * GROUP_SIZE do
			preview.raidFrames[i] = Sample(preview.raid, "raid", i)
		end
		for name, samples in pairs(EXTRAS) do
			local holder = CreateFrame("Frame", nil, preview.raid)
			holder.kstyleExtra = name
			preview.extras[name] = { holder = holder }
			for i, sample in ipairs(samples) do preview.extras[name][i] = Sample(holder, "raid", i, sample) end
		end
		preview.clickCast = ns.ClickCast.Panel(preview)
		preview.Refresh = Layout
		preview:SetScript("OnSizeChanged", function(self)
			if not self.refitPending and C_Timer and type(C_Timer.After) == "function" then
				self.refitPending = true
				C_Timer.After(0, function()
					self.refitPending = nil
					Layout(self)
				end)
			end
		end)
		Layout(preview)
		return preview
	end
	return build(...)
end
