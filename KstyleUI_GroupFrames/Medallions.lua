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
local TILE_OUTLINE = "THICKOUTLINE"
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

local tiling = false
local apply = Style.Apply
function Style.Apply(f, ...)
	tiling = f.kind == "raid" and Medallions.Active()
	apply(f, ...)
	tiling = false
end

local button = Geometry.Button
function Geometry.Button(w, h, o)
	local out = button(w, h, o)
	if tiling and out.nameInside then
		return TileParts(out, w, h, o)
	end
	return out
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

function Medallions.TextReserve(f, k)
	local reserve = k.healthText ~= "NONE" and Style.Reserve(f, k, nil, true) or 0
	for status in pairs(Unit.STATUS_TEXT or {}) do
		local saved = f.status
		f.status = status
		reserve = math.max(reserve, Style.StatusWidth(f, k.healthTextSize) or 0)
		f.status = saved
	end
	return reserve + K.Scale.Pixel(1) / Widgets.ScaleFactor(f)
end

local function Tile(f, parts, k)
	local health, tile = parts.health, parts.tile
	f.tileless = true
	f.chrome:SetShadow(false)
	f.chrome:Restyle()
	local left = Widgets.Snap(f, health.left + tile.inset)
	local right = Widgets.Snap(f, tile.right)
	local gap = Widgets.Snap(f, tile.gap)
	local fit = f.nameFit
	if fit then
		fit.set = function(text, size, path)
			Style.SetFont(text, path or fit.path, size, TILE_OUTLINE)
		end
		fit.set(f.name, fit.size)
	end
	Style.SetFont(f.healthText, Settings.current.text.healthFont, k.healthTextSize, TILE_OUTLINE)
	local reserve = Medallions.TextReserve(f, k)
	local block = parts.block
	local textLeft = reserve > 0 and right - reserve - gap or right
	local pipsRight = textLeft
	local nameRight = textLeft
	if block then
		block.left = pipsRight - block.width
		block.top = tile.stacked and health.top + tile.inset or health.top + math.floor((health.height - block.height) / 2)
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
	if tile.stacked then
		f.name:SetPoint("TOPLEFT", f, "TOPLEFT", left, -Widgets.Snap(f, health.top + tile.inset))
		f.healthText:SetPoint("BOTTOMRIGHT", f, "TOPLEFT", right, -Widgets.Snap(f, health.top + health.height - tile.inset))
	else
		local middle = -Widgets.Snap(f, health.top + health.height / 2)
		f.name:SetPoint("LEFT", f, "TOPLEFT", left, middle)
		f.healthText:SetPoint("RIGHT", f, "TOPLEFT", right, middle)
	end
	f.nativeName = false
	ns.Names.Apply(f)
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
function Frames.Enable(...)
	K.Callbacks.Register("HudStyleChanged", OWNER, Restyle)
	return enable(...)
end

function Frames.Disable(...)
	K.Callbacks.Unregister("HudStyleChanged", OWNER)
	return disable(...)
end
