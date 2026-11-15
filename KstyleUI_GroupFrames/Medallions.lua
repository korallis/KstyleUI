-- Medallions.lua: the Medallions HUD style on the group frames: painted badge medallions in a steel ring on the party, class-coloured raid tiles with the name on the fill, and a steel target ring, laid over the saved settings.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens
local Settings, Style, Unit, Frames = ns.Settings, ns.Style, ns.Unit, ns.Frames

local Medallions = {}
ns.Medallions = Medallions

local STYLE = "medallions"
local OWNER = "GroupFrames.Medallions"
local STEEL_LIT = { 0.902, 0.925, 0.953 }
local TILE_INSET = 3
local LOOK = {
	party = { portrait = true, roleRing = false },
	raid = { textLayout = "INSIDE", power = false, buffCount = 0 },
}
Medallions.LOOK = LOOK

function Medallions.Active()
	local hud = K.HudStyle
	return hud ~= nil and type(hud.Current) == "function" and hud.Current() == STYLE
end

local function Texture(name, fallback)
	local ok, path = pcall(Tokens.Texture, name)
	if ok then
		return path
	end
	Style.LogOnce("texture:" .. name, "the " .. name .. " texture is missing; Medallions group frames use " .. fallback)
	return (Tokens.Texture(fallback))
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
	f.ring:SetTexture(Texture("medEnamel", "ringBevel"))
	bezel = Bezel(f)
	bezel:SetTexture(Texture("medRing", "ringBevel"))
	bezel:ClearAllPoints()
	bezel:SetAllPoints(f.ring)
	bezel:SetDrawLayer("OVERLAY", 1)
	bezel:Show()
	f.badge:Hide()
	f.badgeRing:Hide()
	f.level:Hide()
end

local function Tile(f, parts, k)
	local health = parts.health
	local inset = Widgets.Snap(f, TILE_INSET)
	f.tileless = true
	f.chrome:SetShadow(false)
	f.chrome:Restyle()
	local width = Widgets.Snap(f, health.width) - 2 * inset
	local stacked = health.height >= k.nameSize + k.healthTextSize + 2 * TILE_INSET
	if k.healthText ~= "NONE" and not stacked then
		width = width - (Style.Reserve(f, k, nil, true) or 0) - inset
	end
	f.nameWidth = math.max(1, width)
	f.name:SetWidth(f.nameWidth)
	f.name:ClearAllPoints()
	f.name:SetJustifyH("LEFT")
	f.name:SetPoint("TOPLEFT", f, "TOPLEFT", Widgets.Snap(f, health.left) + inset, -(Widgets.Snap(f, health.top) + inset))
	f.healthText:ClearAllPoints()
	f.healthText:SetJustifyH("RIGHT")
	f.healthText:SetWidth(0)
	if stacked then
		f.healthText:SetPoint("BOTTOMRIGHT", f, "TOPLEFT", Widgets.Snap(f, health.left + health.width) - inset, -(Widgets.Snap(f, health.top + health.height) - inset))
	else
		f.healthText:SetPoint("RIGHT", f, "TOPLEFT", Widgets.Snap(f, health.left + health.width) - inset, -Widgets.Snap(f, health.top + health.height / 2))
		f.name:ClearAllPoints()
		f.name:SetPoint("LEFT", f, "TOPLEFT", Widgets.Snap(f, health.left) + inset, -Widgets.Snap(f, health.top + health.height / 2))
	end
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
	elseif on and parts.nameInside then
		Tile(f, parts, k)
	end
end
Style.appliers[#Style.appliers + 1] = Applied

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
