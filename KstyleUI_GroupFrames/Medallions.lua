-- Medallions.lua: the Medallions HUD style on the group frames: painted badge medallions in a steel ring on the party, class-coloured raid tiles with the name on the fill, and a steel target ring.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens
local Settings, Style, Unit, Frames, Geometry = ns.Settings, ns.Style, ns.Unit, ns.Frames, ns.Geometry

local Medallions = {}
ns.Medallions = Medallions

local OWNER = "GroupFrames.Medallions"
local STEEL_LIT = { Tokens.Color("steelLit") }
local TILE_INSET = 2
local LINE_EXTRA = 2
local MIN_CELL = 8
local PARTY_LANE = 14
local NAME_EM = 6.5
local PIP_SHARE = 0.6
local PIP_ROOM = 0.25
local TILE_TEXT = "NONE"
local INK_SHADOW_ALPHA = 0.25
local LOW_STEP = 0.001
local CHIP_ALPHA = 0.55
local CHIP_WIDTH = 30
local READABLE_SCRIM, READABLE_CHIP = 0.7, 0.85
Medallions.Active = K.Widgets.Medallions

local colorSources = Unit.ColorSources
function Unit.ColorSources(f)
	if f and f.kind == "raid" and Medallions.Active() then
		return colorSources(f) == "gradient" and "gradient" or "class", "text"
	end
	return colorSources(f)
end

local function Pips(block, room, height, spacing, px)
	if not block or block.cells <= 0 or block.size < MIN_CELL then
		return nil
	end
	local size = math.floor(math.min(block.size, math.max(MIN_CELL, height * PIP_SHARE)))
	size = math.floor(size / px + 0.5) * px
	local columns = math.min(block.cells, math.floor((room + spacing) / (size + spacing)))
	if columns <= 0 then
		return nil
	end
	return {
		position = block.position, columns = columns, rows = 1, cells = columns, size = size,
		width = Geometry.Line(columns, size, spacing), height = size, left = 0, top = 0,
	}
end

local function TileParts(out, w, h, o)
	local pad, gap = Tokens.Size("gapSmall"), Tokens.Size("gapTiny")
	local inset = TILE_INSET
	local spacing = o.aura and o.aura.spacing or 0
	local nameLine, line = (o.nameHeight or 0) - LINE_EXTRA, (o.healthLine or 0) - LINE_EXTRA
	local full = (out.power and out.power.top - gap or h - pad) - pad
	local width = w - 2 * pad
	local heal = o.healRow and math.min(o.healRow, full - nameLine - 2 * inset) or nil
	local stacked = full + (o.pixel or 0) >= nameLine + math.max(line, heal or 0) + 2 * inset
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
	out.block = Pips(out.block, width * PIP_ROOM, stacked and nameLine or bar.height - 2 * inset, spacing, o.pixel or 1)
	local lane = width - 2 * inset - (out.block and out.block.width + gap or 0)
	out.name = { left = pad + inset, top = pad, width = lane, height = bar.height }
	out.tile = { stacked = stacked, inset = inset, gap = gap, right = right }
	out.icons.roleInRing = true
	return out
end

local function PartyParts(out, o)
	local badge, crown = out.portrait, out.icons.leader
	local right = badge.left + badge.width - Geometry.EDGE
	local size = math.min(Style.BOSS_SLOT, right - crown.left - crown.width, badge.height - Geometry.EDGE - PARTY_LANE)
	if Settings.current.auras.enabled and size >= Geometry.MIN_ICON then
		out.boss = { left = right - size, top = badge.top + Geometry.EDGE, width = size, height = size }
	end
	local icons, name, spot = out.icons, out.name, out.healthText
	if not (icons and name and spot and spot.right and icons.role and o.role and not icons.roleInRing) then
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
	styling = Medallions.Active() and f or nil
	apply(f, ...)
	styling = nil
end

local button = Geometry.Button
local function TidyParts(out, f, o)
	if not Settings.current.layout.tidyLanes then return out end
	local kind = f.kind
	local health, name = out.health, out.name
	if not (health and name) then return out end
	local right = health.left + health.width
	local size = kind == "party" and PARTY_LANE or 10
	local count = 0
	for i = 1, Settings.INDICATOR_SLOTS do
		if ns.Slots.Category(Settings.current["indicator" .. i], kind, true) then count = count + 1 end
	end
	count = math.min(3, count)
	local reserve = o.reserve or 0
	local top = name.top + math.max(0, (name.height - size) / 2)
	if out.tile and out.tile.stacked and Widgets.Readability("readableBars") then
		reserve, top = 0, health.top
	end
	local heal = out.healRow and out.healRow.side == "RIGHT" and out.healRow
	local gap = heal and Tokens.Size("gapTiny") or 4
	local endName = right - reserve - (reserve > 0 and gap or 0)
	if heal then
		local step, keep = heal.height + (o.healSpacing or 0), NAME_EM * Widgets.FontSize(f.name, o.nameMin) - (o.pixel or 0)
		while heal.width > step + heal.height and endName - heal.width - gap - name.left < keep do
			heal.width = heal.width - step
		end
		heal.left = endName - heal.width
		endName = heal.left - gap
	else
		count = math.max(0, math.min(count, math.floor((endName - name.left + 1) / (size + 1))))
	end
	local width = Geometry.Line(count, size, 1)
	out.indicatorLane = { left = endName - width, top = top, width = width, height = size, size = size, count = count, step = size + 1, fromRight = true, legible = true }
	if heal then
		out.indicatorLane.left, out.indicatorLane.top = right - width, health.top + (health.height - size) / 2
	end
	if out.tile then
		out.tile.percentRight, out.tile.gap = right, gap
	else
		out.healthText.right, out.healthText.markedRight = right, right
	end
	local nameRight = heal and endName or endName - width - (width > 0 and gap or 0)
	out.name = { left = name.left, top = name.top, width = math.max(1, nameRight - name.left), height = name.height }
	out.tidyLanes = true
	return out
end

function Geometry.Button(w, h, o)
	local out = button(w, h, o)
	local kind = styling and styling.kind
	if not styling then
		return out
	elseif kind == "raid" and out.nameInside then
		TileParts(out, w, h, o)
	elseif kind == "party" and out.portrait and not out.overlay then
		PartyParts(out, o)
	end
	return TidyParts(out, styling, o)
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
		local zoom = Settings.current.party.portraitZoom
		f.portrait:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
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
	local key = class .. (Widgets.Readability("readableBars") and ":readable" or ":original")
	local value = inked[key]
	if value == nil then
		local r, g, b = Unit.ClassColor(class)
		if Widgets.Readability("readableBars") then
			value = select(5, Widgets.InkFor(r, g, b)) == ""
		else
			value = not (Unit.IsSecret(r) or Unit.IsSecret(g) or Unit.IsSecret(b)) and type(r) == "number"
				and 0.2126 * r + 0.7152 * g + 0.0722 * b >= 0.75
		end
		inked[key] = value
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
	local refined = Widgets.Readability("readableBars")
	local r, g, b = Tokens.Color(refined and "textEmphasis" or "white")
	text:SetShadowColor(r, g, b, refined and INK_SHADOW_ALPHA or 0.4)
end

local nameColored = Unit.NameColored
function Unit.NameColored(f, class)
	nameColored(f, class)
	if not (f.parts and f.parts.tile and Medallions.Active()) then
		f.medInked = nil
		return
	end
	local ink = not f.status and Medallions.Inked(class)
	local refined = Widgets.Readability("readableBars")
	local path, size = f.name:GetFont()
	Widgets.ApplyFont(f.name, path, size, (not refined or ink) and "" or "OUTLINE")
	if ink then
		local curves = f.unit and InkCurves()
		if curves then
			f.name:SetTextColor(UnitHealthPercent(f.unit, true, curves[1]), UnitHealthPercent(f.unit, true, curves[2]), UnitHealthPercent(f.unit, true, curves[3]))
		else
			f.name:SetTextColor(Tokens.Color("slabBottom"))
		end
	end
	f.medInked = ink or nil
	Widgets.TextShadow(f.name, (not refined or ink) and "" or "OUTLINE")
	if ink then
		InkShadow(f.name)
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
	if not Widgets.Readability("readableBars") then
		local r, g, b = Tokens.Color("steelFill")
		chip:SetColorTexture(r, g, b, 0.72)
		if f.medChipGradient then
			chip:SetColorTexture(Tokens.Color("white"))
			chip:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.72), CreateColor(r, g, b, 0.72))
		end
		local pad = Widgets.Snap(f, Tokens.Size("gapTiny"))
		chip:ClearAllPoints()
		chip:SetPoint("TOPLEFT", f.healthText, "TOPLEFT", -pad, 0)
		chip:SetPoint("BOTTOMRIGHT", f.healthText, "BOTTOMRIGHT", pad, 0)
		return
	end
	local r, g, b = Tokens.Color("slabBottom")
	local alpha = Settings.current.readable.text and READABLE_CHIP or CHIP_ALPHA
	chip:SetColorTexture(Tokens.Color("white"))
	if type(chip.SetGradient) == "function" and type(CreateColor) == "function" then
		f.medChipGradient = true
		chip:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, alpha))
	else
		chip:SetColorTexture(r, g, b, alpha)
	end
	chip:ClearAllPoints()
	chip:SetPoint("TOPRIGHT", f.health, "TOPRIGHT")
	chip:SetPoint("BOTTOMRIGHT", f.health, "BOTTOMRIGHT")
	chip:SetWidth(Widgets.Snap(f, CHIP_WIDTH))
end

local function TextReserve(f, k)
	local percent = k.healthText ~= "NONE" and Style.Reserve(f, k, nil, true) or 0
	local status = Style.InRow(f) and Style.StatusWidth(f, Style.StatusSize(f, k.healthTextSize)) or 0
	return math.max(percent, status) + Slack(f), percent > 0 and percent + Slack(f) or 0
end

local function TileText(f)
	local parts, k = f.parts, Settings.current[f.kind]
	local health, tile, block = parts.health, parts.tile, parts.block
	local left = Widgets.Snap(f, health.left + tile.inset)
	local right = Widgets.Snap(f, tile.percentRight or tile.right)
	local gap = Widgets.Snap(f, tile.gap)
	if tile.below and parts.healRow and Settings.current.auras.timers then
		local _, count, size, spacing = ns.Auras.HealIcons(f, k)
		if count > 0 then left = Widgets.Snap(f, parts.healRow.left + Geometry.Line(count, size, spacing)) + gap end
	end
	local reserve = TextReserve(f, k)
	Style.SetFont(f.healthText, Settings.current.text.healthFont, Style.StatusSize(f, k.healthTextSize), TILE_TEXT)
	local lines = 1.2 * (Widgets.FontSize(f.name, 12) + Widgets.FontSize(f.healthText, k.healthTextSize))
	local refined = Widgets.Readability("readableBars")
	local separated = refined and tile.stacked and health.height - 2 * tile.inset >= lines
	local nameRight = not separated and reserve > 0 and right - reserve - gap or right
	if parts.tidyLanes and parts.indicatorLane.count > 0 then nameRight = math.min(nameRight, Widgets.Snap(f, parts.indicatorLane.left) - gap) end
	if block and block.left and (not refined or not tile.stacked) then
		nameRight = math.min(nameRight, Widgets.Snap(f, block.left) - gap)
	end
	f.nameLetterCut = refined
	f.tileText = { left = left, nameRight = nameRight, textRight = right, reserve = reserve, stacked = tile.stacked }
	f.nameWidth = math.max(1, nameRight - left)
	f.name:SetWidth(f.nameWidth)
	f.name:ClearAllPoints()
	f.name:SetJustifyH("LEFT")
	f.healthText:ClearAllPoints()
	f.healthText:SetJustifyH("RIGHT")
	f.healthText:SetWidth(Settings.current.readable.text and 0 or math.max(1, reserve))
	f.healthText:SetShown(k.healthText ~= "NONE" or f.status ~= nil)
	if tile.stacked then
		local top, bottom = -Widgets.Snap(f, health.top + tile.inset), -Widgets.Snap(f, health.top + health.height - tile.inset)
		f.name:SetPoint(tile.below and "BOTTOMLEFT" or "TOPLEFT", f, "TOPLEFT", left, tile.below and bottom or top)
		f.healthText:SetPoint(tile.below and "TOPRIGHT" or "BOTTOMRIGHT", f, "TOPLEFT", right, tile.below and top or bottom)
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

local function Slab(f, shown)
	if not (f.medSlab or shown) then
		return
	end
	f.medSlab = f.medSlab or Widgets.NineSlice(f, "medGroupTile", "BACKGROUND", 1)
	Widgets.ShowSlice(f.medSlab, shown)
	if shown then
		Widgets.LayoutSlice(f.medSlab, f, select(3, Tokens.Texture("medGroupTile")))
	end
end

local function Tile(f, parts, k)
	local health, tile, block = parts.health, parts.tile, parts.block
	f.tileless = true
	f.chrome:SetShadow(false)
	f.chrome:Restyle()
	Slab(f, true)
	local fit = f.nameFit
	if fit then
		local face = K.Theme.FollowsKit(Settings.current.text.nameFont) and Widgets.LabelFace() or fit.path
		fit.path, fit.kit = face, false
		if Widgets.Readability("readableBars") then fit.size, fit.min = 12, 11 end
		fit.set = function(text, size)
			Style.SetFont(text, face, size, (not Widgets.Readability("readableBars") or f.medInked) and TILE_TEXT or "OUTLINE")
			if f.medInked then
				InkShadow(text)
			end
		end
		fit.set(f.name, fit.size)
	end
	Style.SetFont(f.healthText, Settings.current.text.healthFont, k.healthTextSize, TILE_TEXT)
	if block then
		local _, percent = TextReserve(f, k)
		local right = Widgets.Snap(f, tile.right)
		block.left = (percent > 0 and right - percent - Widgets.Snap(f, tile.gap) or right) - block.width
		block.top = tile.stacked and ((not Widgets.Readability("readableBars")) == (tile.below == true) and health.top + health.height - tile.inset - block.height or health.top + tile.inset) or health.top + math.floor((health.height - block.height) / 2)
	end
	TileText(f)
end

local placeRowEnd = Style.PlaceRowEnd
function Style.PlaceRowEnd(f)
	if f.parts and f.parts.tile and Medallions.Active() then
		TileText(f)
		Style.PinStatus(f)
		return
	end
	return placeRowEnd(f)
end

local function Applied(f, parts, k)
	f.nameLetterCut = false
	local on = Medallions.Active()
	if f.kind == "party" then
		Badge(f, on and f.showPortrait)
		if on then
			f.tileless = true
			f.chrome:SetShadow(false)
			f.chrome:Restyle()
		end
		local backed = on or Settings.current.readable.text and f.tileless
		if backed or f.medPartyScrim then
			f.medPartyScrim = f.medPartyScrim or Widgets.NineSlice(f, "chamferTile", "BACKGROUND", -1)
			Widgets.ShowSlice(f.medPartyScrim, backed and Widgets.Readability("worldText"))
			if backed then
				Widgets.ColorSlice(f.medPartyScrim, Widgets.Rgba("slabBottom", Settings.current.readable.text and READABLE_SCRIM or 0.5))
				if not f.medPartyInk then
					f.medPartyInk = CreateFrame("Frame", nil, f)
					f.medPartyInk:SetFrameLevel(f:GetFrameLevel())
				end
				local box, pad = f.medPartyInk, Widgets.Snap(f, 4)
				box:ClearAllPoints()
				if Settings.current.readable.text then
					box:SetPoint("TOPLEFT", f, "TOPLEFT", 0, math.min(0, pad - Widgets.Snap(f, parts.name.top)))
				else
					box:SetPoint("TOPLEFT", f.name, "TOPLEFT", -pad, pad)
				end
				box:SetPoint("BOTTOMRIGHT", f.health, "BOTTOMRIGHT", pad, -pad)
				Widgets.LayoutSlice(f.medPartyScrim, box, Tokens.Size("radiusTile"), 0)
			end
		end
	elseif on and parts.tile then
		Tile(f, parts, k)
		return
	end
	Slab(f, false)
	Chip(f, false)
	if f.auraClip then
		f.auraClip:SetAlpha(1)
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
	if Settings.current.health.colorSource ~= "gradient" then
		local r, g, b = K.Theme.ClassColor(sample.class)
		f.health:SetBarColor(r, g, b, Settings.current.health.alpha)
	end
	if Widgets.Readability("readableBars") then Unit.NameColored(f, sample.class) else f.name:SetTextColor(Tokens.Color("textEmphasis")) end
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
