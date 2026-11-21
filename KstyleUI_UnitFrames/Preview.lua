-- Preview.lua: the settings window's live preview: the frame being customised, drawn with sample values at its current size and scaled to fill the pane, its sample auras a full grid with times, stacks and the +N chip the live row shows, or only the samples its aura filters keep.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Theme, L = K.Widgets, K.Tokens, K.Theme, K.L
local Settings, Style, Format, Geometry = ns.Settings, ns.Style, ns.Format, ns.Geometry

local Preview = {}
ns.Preview = Preview

local MARGIN = 8
local FULL_MIN_WIDTH = 120
local MIN_SCALE, MAX_SCALE = 0.5, 1.5
local INCOMING_SHARE = 0.08
local LOST_SHARE, COST_SHARE = 0.1, 0.2
local SKULL = 8
local CAST_GAP = 4
local CAST_SHARE = 0.6
local CAST_LEFT = 1.2
local CAST_ICON = 135846
local CAST_RANK, CAST_CRAFTS, CAST_TIME, CAST_LAG = 3, 3, 3, 42
local AURA_ICONS = { 135846, 136096, 135813, 136075 }
local AURA_TIMES = { "12s", "4s", "1m", "25s", "8s", "3m", "40s", "2m" }
local AURA_PRECISE = { [6] = { 168, "2m 48s" }, [8] = { 112, "1m 52s" } }
local AURA_STACKS = { [2] = "3", [5] = "2" }
local AURA_DISPEL = { "debuff", "steal", "buff" }
local AURA_TRAITS = { {}, { buff = "buffStealable" }, { buff = "buffDispellable" }, { buff = "buffDefensive" }, { id = 57723 }, { buff = "" }, {}, { buff = "" } }
local LANES = { "buffStealable", "buffDispellable", "buffDefensive" }
local AURA_MORE, GCD_SHARE = 3, 0.6
local CHIP_SHARE, CHIP_MIN, CHIP_LEVEL = 0.42, 8, 4
local THREAT_TANKING = 3
local PREVIEW_THREAT, PREVIEW_PVP = 87, 272

local SAMPLES = {
	player = { name = L["Valerin"], level = 60, health = 3120, healthMax = 3980, power = 3120, powerMax = 3980, reaction = 5, own = true, leader = true, resting = true, caption = L["Battle Stance"], class = L["Warrior"] },
	target = { name = L["Frost Howler"], level = 61, classification = "elite", creature = L["Beast"], health = 2240, healthMax = 4020, power = 40, powerMax = 100, reaction = 2, marker = true, threat = true, faction = "Horde" },
	targettarget = { name = L["Valerin"], level = 60, health = 3120, healthMax = 3980, power = 3120, powerMax = 3980, reaction = 5, own = true },
	focus = { name = L["Elunara"], level = 60, health = 2530, healthMax = 4010, power = 2900, powerMax = 4400, reaction = 2, classFile = "MAGE" },
	focustarget = { name = L["Krazhk"], level = 60, health = 3300, healthMax = 4000, power = 1800, powerMax = 3600, reaction = 2 },
	pet = { name = L["Wolf"], level = 58, health = 1460, healthMax = 2000, power = 80, powerMax = 100, reaction = 5 },
	boss = { name = L["Magmatus"], level = -1, classification = "worldboss", health = 72432, healthMax = 100600, power = 0, powerMax = 100, reaction = 2, marker = true, threat = true },
}

local function EditKind()
	local kind = Settings.Module().edit
	if Settings.defaults[kind] then
		return kind
	end
	return "player"
end

local function SampleColor(s, sample, source, custom)
	if source == "custom" then
		return custom.r, custom.g, custom.b
	end
	if source == "health" then
		return ns.Unit.ShareColor(sample.healthMax > 0 and sample.health / sample.healthMax or 0)
	end
	if source == "power" then
		return ns.Unit.PowerTypeColor(sample.own and "player" or nil, nil, sample.own and s.powerMana and "MANA" or nil)
	end
	if source == "class" and sample.own then
		return Theme.ClassColor(Theme.Class())
	end
	return ns.Unit.ReactionColor(sample.reaction, source == "hud")
end

local function Hostile(s, sample)
	return s.levelDifficulty and (sample.reaction < 5 or s.levelFriendly)
end

local function GlowAlpha(share)
	local points = ns.Unit.GLOW_POINTS
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		if share <= b[1] then
			return a[2] + (b[2] - a[2]) * (share - a[1]) / (b[1] - a[1])
		end
	end
	return points[#points][2]
end

local function PaintLumen(view, kind, sample)
	local s, form = view.s, view.form
	local share = sample.healthMax > 0 and sample.health / sample.healthMax or 0
	if form == "vitals" then
		local split = s.healthText == "both" or s.healthText == "currentMax"
		Format.Sample(view.healthText, split and "current" or s.healthText, sample.health, sample.healthMax, s.healthDecimal)
		if split then
			Format.SampleMax(view.healthSub, sample.healthMax)
		else
			view.healthSub:SetText("")
		end
		view.caption:SetText(sample.caption or "")
		view.levelText:SetText(sample.level)
		if view.geometry.portrait then
			local r, g, b = Tokens.Color("healthHostile")
			view.ringGlow:SetVertexColor(r, g, b, GlowAlpha(share))
			view.ringGlow:Show()
		end
	elseif form == "column" then
		local mirror = view.geometry.mirror
		local split = not mirror and (s.healthText == "both" or s.healthText == "currentMax")
		if mirror then
			Format.Sample(view.healthText, Format.Main(s.healthText), sample.health, sample.healthMax, s.healthDecimal)
			view.caption:SetText(sample.creature or "")
		else
			Format.Sample(view.healthText, split and "current" or s.healthText, sample.health, sample.healthMax, s.healthDecimal)
			view.caption:SetText(sample.class or "")
		end
		if split then
			Format.SampleMax(view.healthSub, sample.healthMax)
		else
			view.healthSub:SetText("")
		end
		view.levelText:SetText(sample.level)
	elseif form == "card" then
		Format.Sample(view.healthText, Format.Main(s.healthText), sample.health, sample.healthMax, s.healthDecimal)
		ns.Unit.LevelText(view.caption, sample.level, sample.classification, nil, true, nil, Hostile(s, sample))
		view.capLabel:SetText(Settings.CAP_LABELS[kind] or "")
	elseif form == "sigil" then
		ns.Unit.LevelText(view.caption, sample.level, sample.classification, sample.creature, false, nil, Hostile(s, sample))
	else
		Format.Sample(view.healthText, s.healthText, sample.health, sample.healthMax, s.healthDecimal)
	end
end

local function Paint(view, kind)
	local s, sample = view.s, SAMPLES[kind]
	view.health:SetBarRange(0, sample.healthMax / (s.maxHealthLoss and 1 - LOST_SHARE or 1))
	view.health:SetHealth(sample.health, true)
	local r, g, b = SampleColor(s, sample, s.healthColor, s.healthCustom)
	ns.Unit.SetColor(view.health, r, g, b, s.healthAlpha)
	Style.HealthTint(view, r, g, b)
	local split = view.geometry and view.geometry.healthSub
	if view.form == "plate" then
		Format.Sample(view.healthText, split and Format.Main(s.healthText) or s.healthText, sample.health, sample.healthMax, s.healthDecimal)
		Format.SampleDetail(view.healthSub, split and s.healthText or "none", sample.health, sample.healthMax)
	end
	view.power:SetBarRange(0, sample.powerMax)
	view.power:SetValue(sample.power)
	Style.PowerFill(view, SampleColor(s, sample, s.powerColor, s.powerCustom))
	Style.PowerText(view, SampleColor(s, sample, "power"))
	Format.Sample(view.powerText, s.powerText, sample.power, sample.powerMax, nil, not s.powerPercentSign)
	if s.healPrediction then
		view.incoming:SetBarRange(0, sample.healthMax)
		view.incoming:SetValue(sample.healthMax * INCOMING_SHARE)
		view.incoming:Show()
	else
		view.incoming:Hide()
	end
	view.absorb:SetBarRange(0, sample.healthMax)
	view.absorb:SetValue(sample.healthMax * INCOMING_SHARE)
	view.absorb:SetShown(s.healPrediction == true and s.absorbs ~= false)
	if s.healPrediction and s.healAbsorbs then
		local eaten = view.healAbsorb or ns.Style.HealAbsorb(view)
		eaten:SetBarRange(0, sample.healthMax)
		eaten:SetValue(sample.healthMax * INCOMING_SHARE)
		eaten:Show()
	elseif view.healAbsorb then
		view.healAbsorb:Hide()
	end
	local glow = s.absorbGlow and Style.ShieldGlow(view) or view.shieldGlow
	if glow then
		glow:SetAlpha(1)
		glow:SetShown(s.absorbGlow == true)
	end
	local strip = Style.AbsorbBar(view)
	if strip then
		strip:SetBarRange(0, sample.healthMax)
		strip:SetValue(sample.healthMax * INCOMING_SHARE)
		strip:Show()
	end
	local lost = s.maxHealthLoss and Style.LossBar(view) or view.lossBar
	if lost then
		lost:SetValue(LOST_SHARE)
		lost:SetShown(s.maxHealthLoss == true)
	end
	local power = s.power == true
	local cost = power and s.powerCost and Style.CostBar(view) or view.costBar
	if cost then
		cost:SetBarRange(0, sample.powerMax)
		cost:SetValue(sample.power * COST_SHARE)
		cost:SetShown(power and s.powerCost == true)
	end
	local spark = power and s.manaSpark and Style.Spark(view) or view.manaSpark
	if spark then spark:SetShown(power and s.manaSpark == true) end
	ns.Unit.SetName(view, sample.name)
	view.levelText:SetText(sample.level > 0 and sample.level or "??")
	view.levelText:SetTextColor(ns.Unit.LevelColor(nil, nil, Hostile(s, sample) and sample.level))
	if view.form ~= "plate" then
		PaintLumen(view, kind, sample)
	end
	if view.form == "slab" then
		ns.Slab.SetCaption(view, sample.creature or sample.class or "")
		ns.Unit.Refit(view)
	end
	ns.Unit.TextTags(view, nil, nil, sample)
	if view.textBar then ns.Unit.BarIcon(view, nil, sample) end
	if s.portraitStyle == "class" and GetClassAtlas and Theme.Class() then
		ns.Unit.ClassArt(view.portrait, Theme.Class(), s)
	elseif SetPortraitTexture then
		view.portrait:SetTexCoord(0, 1, 0, 1)
		SetPortraitTexture(view.portrait, "player", s.portraitShape ~= "round")
		ns.Unit.Crop(view.portrait, s, 0, 1, 0, 1)
	end
end

local function PaintIndicators(view, s, sample)
	local icons = view.icons
	for _, key in ipairs(ns.Indicators.SLOTS) do
		icons[key]:SetAlpha(1)
		icons[key]:SetShown(s[key] == true and sample[key] == true)
	end
	local own = UnitFactionGroup and UnitFactionGroup("player")
	local pvp = s.pvp and sample.faction and not s.pvpPlayersOnly and not (s.pvpEnemyOnly and (issecretvalue and issecretvalue(own) or own == sample.faction))
	icons.pvp:SetShown(pvp == true)
	if pvp then icons.pvp:SetAtlas(ns.Indicators.ATLAS[sample.faction]) end
	if s.combat and s.combatClassColor then
		icons.combat:Show()
		ns.Indicators.Tint(icons.combat, Theme.Class())
	end
	ns.Indicators.ThreatText(view, nil, s.threatPercent and PREVIEW_THREAT or false)
	local badge = view.kind == "player" and s.pvp and s.pvpTimer and not s.pvpEnemyOnly and not (issecretvalue and issecretvalue(own)) and ns.Indicators.ATLAS[own]
	if badge then
		icons.pvp:SetAtlas(badge)
		icons.pvp:Show()
	end
	ns.Indicators.PvPTimer(view, badge and PREVIEW_PVP or false)
	ns.Indicators.Extra(view, nil, view.kind == "pet" and 3 or sample.classification or "normal")
	ns.Frames.Edge(view, true)
	if s.raidMarker and sample.marker then
		view.marker:SetSpriteSheetCell(SKULL, 4, 4)
		view.marker:Show()
	else
		view.marker:Hide()
	end
	ns.Indicators.Fit(view)
	local r, g, b
	if s.threat and (sample.threat or view.kind == "player" and s.threatNonTank) then
		r, g, b = K.Theme.ThreatColor(THREAT_TANKING)
	end
	if r then
		K.Widgets.ColorSlice(view.glow, r, g, b, 0.9)
		view.glowFrame:Show()
	else
		view.glowFrame:Hide()
	end
end

local function CastHeight(kind)
	local key = Settings.CAST_ELEMENTS[kind]
	if not key then
		return Settings.Value(kind, "castbarHeight")
	end
	local saved = K.Layout and K.Layout.Get and K.Layout.Get(key)
	if saved and type(saved.height) == "number" then
		return saved.height
	end
	return K.Setup.Layouts.Element(key).height
end

local function PaintCast(frame, view, kind, height)
	local cb = frame.casts[kind]
	if not (Settings.CASTBAR[kind] and Settings.Value(kind, "castbar")) then
		if cb then
			cb.frame:Hide()
		end
		return 0
	end
	if not cb then
		cb = ns.CastBars.NewBar(frame.holders[kind], kind, true)
		frame.casts[kind] = cb
	end
	local g = view.geometry
	local castH = CastHeight(kind)
	local x, y, w, extra = g.panel.x, height + CAST_GAP, g.panel.w, castH + CAST_GAP
	if kind == "pet" then
		w, y = view.s.castbarWidth > 0 and view.s.castbarWidth or w, math.max(height, g.medal and g.medal.y + g.medal.h or 0) + CAST_GAP
	elseif g.form == "plate" or g.form == "slab" and not Settings.CAST_ELEMENTS[kind] then
		w = (view.s.castbarWidth or 0) > 0 and math.min(view.s.castbarWidth, w) or w
	elseif g.cast then
		x, y, w, castH, extra = g.cast.x, g.cast.y, g.cast.w, g.cast.h, 0
	elseif not (kind == "player" and Settings.Value(kind, "castbarGcd")) then
		cb.frame:Hide()
		return 0
	end
	cb.frame:ClearAllPoints()
	cb.frame:SetPoint("TOPLEFT", frame.holders[kind], "TOPLEFT", x, -y)
	cb.frame:SetSize(w, castH)
	cb.sampleReaction = SAMPLES[kind].reaction
	cb.outOfRange = kind == "player" and Settings.Value(kind, "castbarRangeGrey") or nil
	ns.CastBars.Restyle(cb)
	ns.CastBars.Layout(cb, w, castH)
	cb.bar:SetMinMaxValues(0, 1)
	cb.bar:SetValue(CAST_SHARE)
	local name, player = L["Frostbolt"], kind == "player"
	cb.lag, cb.batch = player and Settings.Value(kind, "castbarLagText") and CAST_LAG or nil, nil
	if player and Settings.Value(kind, "castbarRank") then name = name .. " (" .. string.format(L["Rank %d"], CAST_RANK) .. ")" end
	local merge = player and Settings.Value(kind, "castbarCraftBar")
	if player and (merge or Settings.Value(kind, "castbarCraft")) then name, cb.batch = name .. " (" .. CAST_CRAFTS .. ")", GetTime() + CAST_LEFT + (CAST_CRAFTS - 1) * CAST_TIME end
	if merge then cb.bar:SetValue((CAST_TIME - CAST_LEFT) / (CAST_CRAFTS * CAST_TIME)) end
	ns.CastBars.SetName(cb, name, Settings.Value(kind, "castbarTarget") and SAMPLES.player.name or nil)
	ns.CastBars.Important(cb, nil, true)
	if cb.lag or cb.batch then
		ns.CastBars.WriteTimer(cb, CAST_TIME - CAST_LEFT, CAST_TIME, CAST_LEFT)
	else
		cb.timer:SetFormattedText("%.1fs", CAST_LEFT)
	end
	cb.icon:SetTexture(CAST_ICON)
	local gcd = player and Settings.Value(kind, "castbarGcd")
	if gcd or not Settings.Value(kind, "castbarHideIdle") then
		cb.bar:SetValue(gcd and GCD_SHARE or 0)
		ns.CastBars.SetName(cb, "")
		ns.CastBars.Important(cb)
		cb.timer:SetText("")
		cb.icon:SetTexture(nil)
	end
	cb.frame:SetAlpha(1)
	cb.frame:Show()
	return extra
end

local function Chip(frame, kind, host)
	local chip = frame.auraChips[kind]
	if not chip then
		chip = CreateFrame("Frame", nil, host)
		chip.chrome = Widgets.IconChrome(chip)
		chip.text = Widgets.FontString(chip, "OVERLAY")
		chip.text:SetAllPoints(chip)
		chip.text:SetJustifyH("CENTER")
		chip.text:SetJustifyV("MIDDLE")
		frame.auraChips[kind] = chip
	end
	return chip
end

local function PaintChip(frame, kind, host, last, size, after, gap)
	local chip = Chip(frame, kind, host)
	chip:ClearAllPoints()
	if not after then
		chip:SetPoint("TOPLEFT", last.skin, "TOPLEFT", 0, 0)
	elseif gap < 0 then
		chip:SetPoint("TOPRIGHT", last.skin, "TOPLEFT", gap, 0)
	else
		chip:SetPoint("TOPLEFT", last.skin, "TOPRIGHT", gap, 0)
	end
	chip:SetSize(size, size)
	chip:SetFrameLevel(last.skin:GetFrameLevel() + CHIP_LEVEL)
	chip.chrome:Restyle()
	local r, g, b = Tokens.Color("buttonFill")
	chip.chrome:SetFillRGBA(r, g, b, 1)
	chip.chrome:SetRimAccent(Settings.Accent())
	Widgets.ApplyFont(chip.text, Tokens.Font("number"), math.max(CHIP_MIN, math.floor(size * CHIP_SHARE + 0.5)), "")
	pcall(chip.text.SetTextColor, chip.text, Tokens.Color("textEmphasis"))
	chip.text:SetText("+" .. AURA_MORE)
	if not after then
		last.timer:Hide()
		last.count:Hide()
		last.countBadge:Hide()
	end
	chip:Show()
end

local function PlaceTile(skin, host, kind, i, count, size, spacing, pitch, corner, growth)
	local columns = Settings.Value(kind, "auraColumns")
	local col, row = (i - 1) % columns, math.floor((i - 1) / columns)
	skin:ClearAllPoints()
	if Settings.Value(kind, "auraPosition") == "CENTER" then
		local inRow = math.min(columns, count - row * columns)
		local start = -(inRow * size + (inRow - 1) * spacing) / 2
		skin:SetPoint("TOPLEFT", host, "TOP", start + col * (size + spacing), -row * pitch)
	else
		local sx = growth[2] == "Left" and -1 or 1
		local sy = growth[3] == "Up" and 1 or -1
		skin:SetPoint(corner, host, corner, sx * col * (size + spacing), sy * row * pitch)
	end
	skin:SetSize(size, size)
end

local function Samples(kind)
	local friend = SAMPLES[kind].reaction >= 5
	local ids = K.Options.AuraCandidates({ blockSpells = Settings.Value(kind, "auraHidden"),
		allowSpells = friend and Settings.Value(kind, "auraTrackedOnly") and Settings.Value(kind, "auraTracked") or "" }) or {}
	local filter = Settings.Value(kind, "auraFilter")
	local foes = not friend and filter ~= "buffs" and Settings.Value(kind, "auraTrackedDebuffs") and K.Options.AuraCandidates({ allowSpells = Settings.Value(kind, "auraTracked") })
	local kept = {}
	for p, t in ipairs(AURA_TRAITS) do
		local keep = not (t.id and Settings.Value(kind, "auraHideLockout") or ids.excludeSpellIDs and ids.excludeSpellIDs[t.id])
		if (not t.buff or filter == "debuffs") and foes and foes.includeSpellIDs then
			keep = keep and foes.includeSpellIDs[t.id] == true
		elseif t.buff then
			keep = keep and not (ids.includeSpellIDs and not ids.includeSpellIDs[t.id])
			for _, lane in ipairs(LANES) do
				local mode = Settings.Value(kind, lane)
				keep = keep and not (mode == "only" and t.buff ~= lane or mode == "hide" and t.buff == lane)
			end
		end
		if keep then kept[#kept + 1] = p end
	end
	return kept
end

local function PaintAuras(frame, view, kind)
	local tiles = frame.auraTiles[kind]
	if not tiles then
		tiles = {}
		frame.auraTiles[kind], frame.auraIcons[kind] = tiles, {}
	end
	local icons = frame.auraIcons[kind]
	local holder = frame.holders[kind]
	local host = frame.auraHosts[kind]
	if not host then
		host = CreateFrame("Frame", nil, holder)
		frame.auraHosts[kind] = host
	end
	local on = Settings.AURAS[kind] and Settings.Value(kind, "auras")
	local kept = on and Samples(kind) or {}
	local apart = on and ns.Auras.Apart(kind)
	local rows = Settings.Value(kind, "auraRows") * (Settings.Value(kind, "auraFilter") == "both" and not apart and 2 or 1)
	local full, cap = #kept == #AURA_TRAITS, Settings.Value(kind, "auraColumns") * rows
	local picks, slots, n = {}, { 0, 0 }, 0
	while on and slots[1] + slots[2] < (apart and 2 or 1) * cap and (full or n < #kept) do
		n = n + 1
		local into = apart and AURA_TRAITS[kept[n] or (n - 1) % #AURA_TRAITS + 1].buff and 2 or 1
		if slots[into] < cap then slots[into], picks[#picks + 1] = slots[into] + 1, n end
	end
	local count = #picks
	local filter = on and Settings.Value(kind, "auraFilter")
	local chip, more = frame.auraChips[kind], frame.auraChips[kind .. "+"]
	if count > 0 then
		local width, height, corner, _, growth = ns.Auras.Footprint(kind, host)
		local size = Widgets.Snap(host, Settings.Value(kind, "auraSize"))
		local spacing, across = Widgets.Snap(host, Settings.Value(kind, "auraSpacing")), Widgets.Snap(host, ns.Auras.Spacing(kind))
		local room = Widgets.Snap(host, ns.Auras.TimerRoom(kind))
		local gap = Widgets.Snap(host, Settings.Value(kind, "auraRowGap"))
		local timers = Settings.Value(kind, "auraTimer") == true
		local precise = Settings.Value(kind, "auraPrecise") * 60
		host:SetSize(width, math.min(height, rows * (size + room) + (rows - 1) * (spacing + gap)))
		ns.Auras.Anchor(host, holder, kind, view.geometry.panel.x, view.geometry.aura)
		host:Show()
		if apart then
			apart = frame.buffHosts[kind] or CreateFrame("Frame", nil, holder)
			frame.buffHosts[kind] = apart
			apart:SetSize(host:GetSize())
			ns.Auras.Anchor(apart, holder, kind, view.geometry.panel.x, nil, true)
			apart:Show()
		end
		local seen, last = { 0, 0 }, {}
		for j, i in ipairs(picks) do
			local tile = tiles[j]
			if not tile then
				tile = ns.Auras.SampleTile(host)
				tiles[j], icons[j] = tile, tile.skin
			end
			local p = kept[i] or (i - 1) % #AURA_TRAITS + 1
			tile.buff = filter == "buffs" or filter == "both" and (AURA_DISPEL[kept[i]] == "steal" or AURA_DISPEL[kept[i]] == "buff")
			tile.icon:SetTexture(AURA_ICONS[(p - 1) % #AURA_ICONS + 1])
			local into = apart and AURA_TRAITS[p].buff and 2 or 1
			seen[into], last[into] = seen[into] + 1, tile
			PlaceTile(tile.skin, into == 2 and apart or host, kind, seen[into], slots[into], size, across, size + room + spacing + gap, corner, growth)
			ns.Auras.LayoutTile(tile)
			ns.Auras.StyleSample(tile, kind, AURA_DISPEL[kept[i]])
			local exact = AURA_PRECISE[p]
			tile.timer:SetText(exact and exact[1] < precise and exact[2] or AURA_TIMES[p])
			tile.timer:SetShown(timers)
			local stack = AURA_STACKS[kept[i]]
			tile.count:SetText(stack or "")
			tile.count:SetShown(stack ~= nil)
			tile.countBadge:SetShown(stack ~= nil)
			tile.skin:Show()
		end
		local after = timers and room > 0
		local centred = Settings.Value(kind, "auraPosition") == "CENTER"
		local dx = (not centred and growth[2] == "Left") and -across or across
		if full then
			PaintChip(frame, kind, host, last[1], size, after, dx)
		elseif chip then
			chip:Hide()
		end
		if full and apart then PaintChip(frame, kind .. "+", apart, last[2], size, after, dx) elseif more then more:Hide() end
	else
		host:Hide()
		if chip then
			chip:Hide()
		end
	end
	if frame.buffHosts[kind] and not (count > 0 and apart) then frame.buffHosts[kind]:Hide() end
	for i = count + 1, #icons do
		icons[i]:Hide()
	end
	return count
end

local function Room(value)
	if type(value) ~= "number" or (issecretvalue and issecretvalue(value)) or value <= 2 * MARGIN then
		return nil
	end
	return value - 2 * MARGIN
end

local function Size(frame, kind, s)
	local key = Settings.ELEMENTS[kind]
	local element = K.Setup.Layouts.Element(key)
	local width, height = element.width, element.height
	local saved = K.Layout and K.Layout.Get and K.Layout.Get(key)
	if saved and type(saved.width) == "number" and type(saved.height) == "number" then
		width, height = saved.width, saved.height
	end
	if kind == "boss" then
		height = Geometry.Slots(Geometry.BOSS_COUNT, s.gap, width, height)[1].h
	end
	local room = Room(frame:GetWidth())
	if room then
		local left, right = Geometry.Reach(s)
		width = math.min(width, math.max(FULL_MIN_WIDTH, room / MIN_SCALE - left - right))
	end
	return width, height
end

local OFFSET = {
	TOPLEFT = { 0, 0 }, TOP = { 0.5, 0 }, TOPRIGHT = { 1, 0 },
	LEFT = { 0, 0.5 }, CENTER = { 0.5, 0.5 }, RIGHT = { 1, 0.5 },
	BOTTOMLEFT = { 0, 1 }, BOTTOM = { 0.5, 1 }, BOTTOMRIGHT = { 1, 1 },
}

local function PaintResource(frame, view, kind, sample)
	local box, format = frame.resource, Settings.Resource("manaText")
	if kind ~= "player" or format == "none" or not (Settings.Resource("enabled") and Settings.Resource("druidMana")) then
		if box then box:Hide() end
		return
	end
	if not box then
		box = CreateFrame("Frame", nil, frame.holders.player)
		box.bar = K.Widgets.UnitBar(box, { loss = false, spark = false })
		box.text = K.Widgets.FontString(box, "OVERLAY")
		box.text:SetWordWrap(false)
		box.text:SetAllPoints(box)
		frame.resource = box
	end
	local element, bar = K.Setup.Layouts.Element(ns.Resource.KEY), box.bar
	box:SetSize(element.width, element.height)
	box:ClearAllPoints()
	box:SetPoint("BOTTOM", frame.holders.player, "TOP", 0, CAST_GAP)
	bar.opts.width, bar.opts.height = element.width, ns.Resource.MANA_MAX
	bar:ClearAllPoints()
	bar:SetPoint("CENTER", box, "CENTER")
	bar:Restyle()
	ns.Resource.StyleBar(bar, view.s.powerMana)
	bar:SetBarRange(0, sample.powerMax)
	bar:SetValue(sample.power)
	ns.Resource.StyleText(box.text)
	Format.Sample(box.text, format, sample.power, sample.powerMax)
	box:Show()
end

local function PaintTotems(frame, kind)
	local row = frame.totems
	if kind ~= "player" or not Settings.Value("player", "totems") then
		if row then row:Hide() end
		return
	end
	row = row or ns.Totems.Row(frame.holders.player)
	frame.totems = row
	ns.Totems.Place(row, frame.holders.player, frame.views.player.geometry)
	for i, button in ipairs(row.buttons) do
		button:SetIcon(AURA_ICONS[(i - 1) % #AURA_ICONS + 1])
		button:SetCooldown(GetTime() - i * 5, 60)
	end
	row:Show()
end

local function Box(region, holder, width, height)
	if not (region and region:IsShown()) then
		return nil
	end
	local point, relative, relPoint, x, y = region:GetPoint(1)
	local from, to = OFFSET[point], OFFSET[relPoint]
	if relative ~= holder or not (from and to) then
		return nil
	end
	local w, h = region:GetSize()
	local left = to[1] * width + (x or 0) - from[1] * w
	local top = to[2] * height - (y or 0) - from[2] * h
	return left, top, left + w, top + h
end

local function Fit(frame, holder, kind, width, height)
	local l, t, r, b = 0, 0, width, height
	local view = frame.views[kind]
	local regions = { frame.auraHosts[kind], frame.casts[kind] and frame.casts[kind].frame, view.portraitFrame, frame.resource, kind == "player" and frame.totems or nil, frame.buffHosts[kind],
		view.s.powerDetach ~= "" and view.power or nil }
	for i = 1, 7 do
		local rl, rt, rr, rb = Box(regions[i], holder, width, height)
		if rl then
			l, t, r, b = math.min(l, rl), math.min(t, rt), math.max(r, rr), math.max(b, rb)
		end
	end
	local scale = MAX_SCALE
	local reserve = frame.reserve
	local rl, rr, rt, rb = reserve and reserve[1] or 0, reserve and reserve[2] or 0, reserve and reserve[3] or 0, reserve and reserve[4] or 0
	local roomW, roomH = Room(frame:GetWidth() - rl - rr), Room(frame:GetHeight() - rt - rb)
	if roomW then
		scale = math.min(scale, roomW / (r - l))
	end
	if roomH then
		scale = math.min(scale, roomH / (b - t))
	end
	holder:SetScale(scale)
	holder:ClearAllPoints()
	K.Widgets.Point(holder, "CENTER", frame, "CENTER", (width - l - r) / 2 + (rl - rr) / 2 / scale, (t + b - height) / 2 + (rb - rt) / 2 / scale)
end

local function Refresh(frame)
	local kind = EditKind()
	for other, holder in pairs(frame.holders) do
		holder:SetShown(other == kind)
	end
	local holder = frame.holders[kind]
	if not holder then
		holder = CreateFrame("Frame", nil, frame)
		frame.holders[kind] = holder
		frame.views[kind] = Style.New(holder, kind)
	end
	local view = frame.views[kind]
	view.s = Settings.Snapshot(kind)
	local width, height = Size(frame, kind, view.s)
	if Settings.CASTBAR[kind] and not Settings.CAST_ELEMENTS[kind] and kind ~= "pet" and view.s.castbar and (view.s.form == "plate" or view.s.form == "slab") then
		height = math.max(0, height - view.s.castbarHeight - CAST_GAP)
	end
	holder:SetSize(width, height)
	holder:Show()
	Style.Restyle(view, kind)
	Style.Layout(view, view.s, width, height)
	Paint(view, kind)
	PaintResource(frame, view, kind, SAMPLES[kind])
	PaintIndicators(view, view.s, SAMPLES[kind])
	PaintCast(frame, view, kind, height)
	PaintTotems(frame, kind)
	frame.auraCount = PaintAuras(frame, view, kind)
	Fit(frame, holder, kind, width, height)
	Style.Layout(view, view.s, width, height)
	ns.Unit.TextTags(view, nil, nil, SAMPLES[kind])
	ns.Dispel.Sample(view, holder, kind)
	PaintCast(frame, view, kind, height)
	Fit(frame, holder, kind, width, height)
	frame.kind = kind
end

function Preview.Build(parent)
	local frame = Widgets.MarkPreview(CreateFrame("Frame", nil, parent))
	frame:SetAllPoints(parent)
	frame.holders, frame.views, frame.casts, frame.auraIcons, frame.auraTiles, frame.auraHosts, frame.auraChips, frame.buffHosts = {}, {}, {}, {}, {}, {}, {}, {}
	frame.Refresh = Refresh
	function frame.Reserve(self, left, right, top, bottom)
		local reserve = self.reserve or { 0, 0, 0, 0 }
		reserve[1], reserve[2], reserve[3], reserve[4] = reserve[1] + left, reserve[2] + right, reserve[3] + top, reserve[4] + bottom
		self.reserve = reserve
		if self.kind then
			Refresh(self)
		end
	end
	frame:SetScript("OnSizeChanged", function(self)
		if self.kind then
			Refresh(self)
		end
	end)
	Refresh(frame)
	return frame
end
