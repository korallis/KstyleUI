-- Medallions.lua: the Medallions HUD style on the group frames: painted badge medallions in a steel ring on the party, class-coloured raid tiles with the name on the fill, and a steel target ring, laid over the saved settings.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens
local Settings, Style, Unit, Frames, Geometry = ns.Settings, ns.Style, ns.Unit, ns.Frames, ns.Geometry

local Medallions = {}
ns.Medallions = Medallions

local STYLE = "medallions"
local OWNER = "GroupFrames.Medallions"
local STEEL_LIT = { Tokens.Color("steelLit") }
local TILE_INSET = 2
local LINE_EXTRA = 2
local MIN_CELL = 8
local PIP_SHARE = 0.6
local PIP_ROOM = 0.25
local TILE_TEXT = "NONE"
local INK_LUMINANCE = 0.75
local INK_SHADOW_ALPHA = 0.4
local LOW_STEP = 0.001
local CHIP_ALPHA = 0.72
local LABEL_FACE = Tokens.FontPath("InterSemiBold")
local NUMBER_FACE = Tokens.FontPath("PTSerifBold")
local LOOK = {
	party = { portrait = true, roleRing = false },
	raid = { textLayout = "INSIDE", power = false, buffCount = 0 },
}
Medallions.LOOK = LOOK

function Medallions.Active()
	local hud = K.HudStyle
	return hud ~= nil and type(hud.Current) == "function" and hud.Current() == STYLE
end

local function Overlay(cfg)
	if not Medallions.Active() then
		return cfg
	end
	for section, values in pairs(LOOK) do
		local out, defaults = cfg[section], Settings.defaults[section]
		for name, value in pairs(values) do
			if Settings.Get(section .. "." .. name) == defaults[name] then
				out[name] = value
			end
		end
	end
	return cfg
end
Medallions.Overlay = Overlay

local refresh = Settings.Refresh
function Settings.Refresh()
	return Overlay(refresh())
end

local colorSources = Unit.ColorSources
function Unit.ColorSources(f)
	if f and f.kind == "raid" and Medallions.Active() then
		return "class", "text"
	end
	return colorSources(f)
end

local function Line(count, size, spacing)
	return count * size + math.max(0, count - 1) * spacing
end

local function Pips(block, room, height, spacing)
	if not block or block.cells <= 0 then
		return nil
	end
	local size = math.floor(math.min(block.size, math.max(MIN_CELL, height * PIP_SHARE)))
	local columns = math.min(block.cells, math.floor((room + spacing) / (size + spacing)))
	if size < MIN_CELL or columns <= 0 then
		return nil
	end
	return {
		position = block.position, columns = columns, rows = 1, cells = columns, size = size,
		width = Line(columns, size, spacing), height = size, left = 0, top = 0,
	}
end

local function TileParts(out, w, h, o)
	local pad, gap = Tokens.Size("gapSmall"), Tokens.Size("gapTiny")
	local inset = TILE_INSET
	local spacing = o.aura and o.aura.spacing or 0
	local nameLine, line = (o.nameHeight or 0) - LINE_EXTRA, (o.healthLine or 0) - LINE_EXTRA
	local full = h - 2 * pad
	local width = w - 2 * pad
	local heal = o.healRow and math.min(o.healRow, full - nameLine - 2 * inset) or nil
	local stacked = full >= nameLine + math.max(line, heal or 0) + 2 * inset
	if not stacked then
		heal = o.healRow
	end
	local bar = { left = pad, top = pad, width = width, height = full }
	out.healRow = nil
	if heal and stacked then
		out.healRow = { left = pad + inset, top = pad + full - inset - heal, width = math.floor((width - 2 * inset) / 2), height = heal }
	elseif heal and full - heal - gap >= line then
		bar.height = full - heal - gap
		out.healRow = { left = pad, top = pad + bar.height + gap, width = width, height = heal }
	end
	out.health = bar
	local right = pad + width - inset
	out.block = Pips(out.block, width * PIP_ROOM, stacked and nameLine or bar.height - 2 * inset, spacing)
	local lane = width - 2 * inset - (out.block and out.block.width + gap or 0)
	out.name = { left = pad + inset, top = pad, width = lane, height = bar.height }
	out.tile = { stacked = stacked, inset = inset, gap = gap, right = right }
	out.icons.roleInRing = true
	return out
end

local function PartyParts(out, o)
	local icons, name, spot = out.icons, out.name, out.healthText
	if not (icons and name and spot and icons.role and o.role and not icons.roleInRing) then
		return out
	end
	local gap = Tokens.Size("gapTiny")
	local reclaim = icons.role.width + gap
	local pip = math.floor(math.min(o.pip or icons.role.width, name.height))
	icons.pip = true
	icons.role = { left = name.left, top = name.top + math.floor((name.height - pip) / 2), width = pip, height = pip }
	out.name = { left = name.left + pip + gap, top = name.top, width = name.width + reclaim - pip - gap, height = name.height }
	spot.right = spot.right + reclaim
	spot.markedRight = spot.markedRight and spot.markedRight + reclaim
	if out.healRow and out.healRow.side == "RIGHT" then
		out.healRow.left = out.healRow.left + reclaim
	end
	return out
end

local styling = nil
local apply = Style.Apply
function Style.Apply(f, ...)
	styling = Medallions.Active() and f.kind or nil
	apply(f, ...)
	styling = nil
end

local button = Geometry.Button
function Geometry.Button(w, h, o)
	local out = button(w, h, o)
	if styling == "raid" and out.nameInside then
		return TileParts(out, w, h, o)
	elseif styling == "party" and out.portrait and not out.overlay then
		return PartyParts(out, o)
	end
	return out
end

local setName = ns.Names.Set
function ns.Names.Set(f, name, ...)
	if f.kind == "raid" and f.parts and f.parts.tile and type(name) == "string" and not Unit.IsSecret(name) then
		name = K.Locale.Upper(name)
	end
	return setName(f, name, ...)
end

local function Mask(f, masked)
	if (f.masked ~= false) == masked then
		f.masked = masked
		return
	end
	f.masked = masked
	if masked then
		f.portrait:AddMaskTexture(f.portraitMask)
	else
		f.portrait:RemoveMaskTexture(f.portraitMask)
	end
end

local setPortrait = Unit.SetPortrait
function Unit.SetPortrait(f)
	local api = K.Medallions
	if f.kind == "party" and Medallions.Active() and api and type(api.Portrait) == "function" then
		Mask(f, not api.Portrait(f.portrait, f.unit, "badge"))
		return
	end
	if f.masked == false then
		Mask(f, true)
	end
	setPortrait(f)
end

local function Bezel(f)
	local bezel = f.medBezel
	if not bezel then
		bezel = f.text:CreateTexture(nil, "BACKGROUND")
		f.medBezel = bezel
	end
	return bezel
end

local function Badge(f, on)
	local bezel = f.medBezel
	if not on then
		if bezel then
			f.ring:SetTexture((Tokens.Texture("ringBevel")))
			bezel:Hide()
		end
		return
	end
	f.ring:SetTexture((Tokens.Texture("medEnamel")))
	bezel = Bezel(f)
	bezel:SetTexture((Tokens.Texture("medRing")))
	bezel:ClearAllPoints()
	bezel:SetAllPoints(f.ring)
	bezel:SetDrawLayer("OVERLAY", 1)
	bezel:Show()
	f.badge:Hide()
	f.badgeRing:Hide()
	f.level:Hide()
end

local function Slack(f)
	return K.Scale.Pixel(1) / Widgets.ScaleFactor(f)
end

local inked = {}
function Medallions.Inked(class)
	if Unit.IsSecret(class) or type(class) ~= "string" then
		return false
	end
	local value = inked[class]
	if value == nil then
		local r, g, b = Unit.ClassColor(class)
		value = not (Unit.IsSecret(r) or Unit.IsSecret(g) or Unit.IsSecret(b)) and type(r) == "number"
			and 0.2126 * r + 0.7152 * g + 0.0722 * b >= INK_LUMINANCE
		inked[class] = value
	end
	return value
end

local inkCurves, inkTried
local function InkCurves()
	if inkTried then
		return inkCurves
	end
	inkTried = true
	local util, kinds = C_CurveUtil, Enum and Enum.LuaCurveType
	if not (util and type(util.CreateCurve) == "function" and UnitHealthPercent) then
		Style.LogOnce("inkCurve", "C_CurveUtil.CreateCurve or UnitHealthPercent is missing; dark tile names stay dark at low health")
		return nil
	end
	local light, dark, low = { Tokens.Color("textEmphasis") }, { Tokens.Color("slabBottom") }, Widgets.LOW_HEALTH_SHARE
	inkCurves = {}
	for i = 1, 3 do
		local curve = util.CreateCurve()
		if kinds and kinds.Step and curve.SetType then
			curve:SetType(kinds.Step)
		end
		curve:AddPoint(0, light[i])
		curve:AddPoint(low, light[i])
		curve:AddPoint(low + LOW_STEP, dark[i])
		curve:AddPoint(1, dark[i])
		inkCurves[i] = curve
	end
	return inkCurves
end

local function InkShadow(text)
	text:SetShadowColor(1, 1, 1, INK_SHADOW_ALPHA)
end

local nameColored = Unit.NameColored
function Unit.NameColored(f, class)
	nameColored(f, class)
	local ink = f.parts and f.parts.tile and not f.status and Medallions.Active() and Medallions.Inked(class)
	if ink then
		local curves = f.unit and InkCurves()
		if curves then
			f.name:SetTextColor(UnitHealthPercent(f.unit, true, curves[1]), UnitHealthPercent(f.unit, true, curves[2]), UnitHealthPercent(f.unit, true, curves[3]))
		else
			f.name:SetTextColor(Tokens.Color("slabBottom"))
		end
	end
	if (ink or false) ~= (f.medInked or false) then
		f.medInked = ink or nil
		Widgets.TextShadow(f.name, "")
		if ink then
			InkShadow(f.name)
		end
	end
end

local function Chip(f, shown)
	local chip = f.medChip
	if not chip then
		if not shown then
			return
		end
		chip = f.text:CreateTexture(nil, "ARTWORK", nil, -1)
		f.medChip = chip
	end
	chip:SetShown(shown)
	if not shown then
		return
	end
	local r, g, b = Tokens.Color("steelFill")
	chip:SetColorTexture(r, g, b, CHIP_ALPHA)
	local pad = Widgets.Snap(f, Tokens.Size("gapTiny"))
	chip:ClearAllPoints()
	chip:SetPoint("TOPLEFT", f.healthText, "TOPLEFT", -pad, 0)
	chip:SetPoint("BOTTOMRIGHT", f.healthText, "BOTTOMRIGHT", pad, 0)
end

local function ShowCap(f, shown)
	local bar = f.health
	if bar.sparkLine then
		bar.sparkLine:SetAlpha(shown and 1 or 0)
		bar.sparkGlow:SetAlpha(shown and 1 or 0)
	end
	f.medSparkHidden = not shown or nil
end

local function TextReserve(f, k)
	local percent = k.healthText ~= "NONE" and Style.Reserve(f, k, nil, true) or 0
	local status = f.status and Style.StatusWidth(f, k.healthTextSize) or 0
	return math.max(percent, status) + Slack(f), percent > 0 and percent + Slack(f) or 0
end

local function TileText(f)
	local parts, k = f.parts, Settings.current[f.kind]
	local health, tile, block = parts.health, parts.tile, parts.block
	local left = Widgets.Snap(f, health.left + tile.inset)
	local right = Widgets.Snap(f, tile.right)
	local gap = Widgets.Snap(f, tile.gap)
	local reserve = TextReserve(f, k)
	local nameRight = reserve > 0 and right - reserve - gap or right
	if block and block.left then
		nameRight = math.min(nameRight, Widgets.Snap(f, block.left) - gap)
	end
	f.tileText = { left = left, nameRight = nameRight, textRight = right, reserve = reserve, stacked = tile.stacked }
	f.nameWidth = math.max(1, nameRight - left)
	f.name:SetWidth(f.nameWidth)
	f.name:ClearAllPoints()
	f.name:SetJustifyH("LEFT")
	f.healthText:ClearAllPoints()
	f.healthText:SetJustifyH("RIGHT")
	f.healthText:SetWidth(math.max(1, reserve))
	f.healthText:SetShown(k.healthText ~= "NONE" or f.status ~= nil)
	if tile.stacked then
		f.name:SetPoint("TOPLEFT", f, "TOPLEFT", left, -Widgets.Snap(f, health.top + tile.inset))
		f.healthText:SetPoint("BOTTOMRIGHT", f, "TOPLEFT", right, -Widgets.Snap(f, health.top + health.height - tile.inset))
	else
		local middle = -Widgets.Snap(f, health.top + health.height / 2)
		f.name:SetPoint("LEFT", f, "TOPLEFT", left, middle)
		f.healthText:SetPoint("RIGHT", f, "TOPLEFT", right, middle)
	end
	if f.auraClip then
		f.auraClip:SetAlpha(f.status and 0 or 1)
	end
	Chip(f, f.healthText:IsShown())
	f.nativeName = false
	ns.Names.Apply(f)
end

local function Tile(f, parts, k)
	local health, tile, block = parts.health, parts.tile, parts.block
	f.tileless = true
	f.chrome:SetShadow(false)
	f.chrome:Restyle()
	local fit = f.nameFit
	if fit then
		fit.path, fit.kit = LABEL_FACE, false
		fit.set = function(text, size)
			Style.SetFont(text, LABEL_FACE, size, TILE_TEXT)
			if f.medInked then
				InkShadow(text)
			end
		end
		fit.set(f.name, fit.size)
	end
	Style.SetFont(f.healthText, NUMBER_FACE, k.healthTextSize, TILE_TEXT)
	ShowCap(f, false)
	if block then
		local _, percent = TextReserve(f, k)
		local right = Widgets.Snap(f, tile.right)
		block.left = (percent > 0 and right - percent - Widgets.Snap(f, tile.gap) or right) - block.width
		block.top = tile.stacked and health.top + tile.inset or health.top + math.floor((health.height - block.height) / 2)
	end
	TileText(f)
end

local placeRowEnd = Style.PlaceRowEnd
function Style.PlaceRowEnd(f)
	if f.parts and f.parts.tile and Medallions.Active() then
		TileText(f)
		return
	end
	return placeRowEnd(f)
end

local function Applied(f, parts, k)
	local on = Medallions.Active()
	if f.kind == "party" then
		Badge(f, on and f.showPortrait)
		if on then
			f.tileless = true
			f.chrome:SetShadow(false)
			f.chrome:Restyle()
		end
	elseif on and parts.tile then
		Tile(f, parts, k)
	elseif f.medSparkHidden then
		ShowCap(f, true)
		Chip(f, false)
		if f.auraClip then
			f.auraClip:SetAlpha(1)
		end
	end
end
table.insert(Style.appliers, 1, Applied)

local paint = Style.Paint
function Style.Paint(f)
	paint(f)
	if Medallions.Active() then
		Style.ColorRing(f.targetRing, STEEL_LIT[1], STEEL_LIT[2], STEEL_LIT[3], 1)
	end
end

local function PaintSample(f, sample)
	if not Medallions.Active() or f.kind ~= "raid" or f.status then
		return
	end
	f.health:SetBarColor(K.Theme.ClassColor(sample.class))
	f.name:SetTextColor(Tokens.Color("textEmphasis"))
end
Style.painters[#Style.painters + 1] = PaintSample

local function Restyle()
	if Frames.running then
		Frames.Apply()
	end
end

local enable, disable = Frames.Enable, Frames.Disable
local function Repaint()
	for class in pairs(inked) do
		inked[class] = nil
	end
end

function Frames.Enable(...)
	K.Callbacks.Register("HudStyleChanged", OWNER, Restyle)
	K.Callbacks.Register("ThemeChanged", OWNER, Repaint)
	return enable(...)
end

function Frames.Disable(...)
	K.Callbacks.Unregister("HudStyleChanged", OWNER)
	K.Callbacks.Unregister("ThemeChanged", OWNER)
	return disable(...)
end
