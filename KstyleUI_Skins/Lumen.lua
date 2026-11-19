-- Lumen.lua: skin colours, root-sized text, shared card caps and insets, and ring check boxes.
local _, ns = ...

local K = KstyleUI
local Tokens, Widgets, Skin = K.Tokens, K.Widgets, K.Skin
local Style = ns.Style

local Lumen = {}
ns.Lumen = Lumen

local FALLBACKS = { gilt = "neutral", questGold = "neutral", rimLight = "edgeInner" }
local S1_NAMES = { rimLight = "rim" }
local QUEST_GOLD_LIFT = 0.3
local TEXTURES = { gem = "diamond", checkRing = "ringBevel", gemFill = "dot" }
local CAP_SIZE, TEXT_SIZE = 12, 13
local RING_UNITS, RING_FILL, RING_LEVEL = 14, 8, 2
local THIN_SPACE = "\226\128\137"
local CODEPOINT = "([\1-\127\194-\244][\128-\191]*)"

local WEAK = { __mode = "k" }
local rings = setmetatable({}, WEAK)

Lumen.FALLBACKS, Lumen.TEXTURES = FALLBACKS, TEXTURES
Lumen.CAP_SIZE, Lumen.TEXT_SIZE = CAP_SIZE, TEXT_SIZE
Lumen.RING_UNITS, Lumen.RING_FILL = RING_UNITS, RING_FILL

local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

function Lumen.Color(name)
	local ok, r, g, b, a = pcall(Tokens.Color, Widgets.ColorName(S1_NAMES[name] or name))
	if ok then
		return r, g, b, a
	end
	local fallback = FALLBACKS[name]
	if not fallback then
		error("KstyleUI_Skins Lumen.Color: unknown name " .. tostring(name), 2)
	end
	if name == "questGold" then
		return Widgets.MixTokens(fallback, 1, "textEmphasis", 1, QUEST_GOLD_LIFT)
	end
	return Tokens.Color(fallback)
end

function Lumen.Size(frame, units)
	return units * Style.Setting("text", "size") / Widgets.ScaleFactor(frame)
end

function Lumen.Inset(frame)
	return Widgets.Inset(frame, Tokens.Size("radius"))
end

function Lumen.Tint(region, name, alpha)
	local r, g, b, a = Lumen.Color(name)
	region:SetVertexColor(r, g, b, (a or 1) * (alpha or 1))
end

function Lumen.Texture(name)
	local ok, path = pcall(Tokens.Texture, name)
	if ok then
		return path, true
	end
	return (Tokens.Texture(TEXTURES[name])), false
end

function Lumen.Tracked(value)
	local path = Style.Font("caps")
	if type(path) ~= "string" or not path:find("KstyleUI", 1, true) or K.Locale.TrackMode(path) ~= "space" then
		return value
	end
	return (value:gsub(CODEPOINT, "%1" .. THIN_SPACE):sub(1, -#THIN_SPACE - 1))
end

function Lumen.Plain(value)
	if IsSecret(value) or value == nil then
		return ""
	end
	if type(value) == "number" then
		return tostring(value)
	end
	if type(value) ~= "string" then
		return ""
	end
	return value
end

function Lumen.Gem(owner, layer, sublevel)
	local gem = owner:CreateTexture(nil, layer or "OVERLAY", nil, sublevel)
	gem:SetTexture((Tokens.Texture(TEXTURES.gem)))
	Lumen.Tint(gem, "gilt")
	return gem
end

local function TextScale()
	return Style.Setting("text", "size")
end

function Lumen.CapColumn(frame)
	return Widgets.CapColumn(frame, TextScale())
end

function Lumen.SectionCap(parent, opts)
	opts = opts or {}
	opts.textScale = TextScale
	local cap = Widgets.SectionCap(parent, opts)
	Style.Track(cap)
	return cap
end

local function Enabled(frame)
	return type(frame.IsEnabled) ~= "function" or frame:IsEnabled() ~= false
end

local function PaintRing(ring)
	local check = ring.check
	local enabled = Enabled(check)
	ring.fill:SetShown(ring.checked == true)
	if not enabled then
		Widgets.Tint(ring.fill, "textDisabled")
		Widgets.Tint(ring.ring, "textDisabled")
		return
	end
	Lumen.Tint(ring.fill, "gilt")
	if ring.checked then
		Lumen.Tint(ring.ring, "gilt")
		return
	end
	local er, eg, eb, ea = Widgets.Rgba("edgeInner")
	local gr, gg, gb = Lumen.Color("gilt")
	ring.ring:SetVertexColor(Widgets.Mix(er, eg, eb, ea, gr, gg, gb, 1, ring.hoverT or 0))
end

local function LayoutRing(ring)
	Widgets.Size(ring.box, RING_UNITS, RING_UNITS)
	Widgets.Size(ring.ring, RING_UNITS, RING_UNITS)
	Widgets.Size(ring.fill, RING_FILL, RING_FILL)
	Widgets.Point(ring.box, "CENTER", ring.check, "CENTER")
	Widgets.Point(ring.ring, "CENTER", ring.box, "CENTER")
	Widgets.Point(ring.fill, "CENTER", ring.box, "CENTER")
end

local function RestyleRing(ring)
	LayoutRing(ring)
	PaintRing(ring)
end

function Lumen.RingOf(check)
	return rings[check]
end

local function Checked(value)
	return not IsSecret(value) and value == true
end

local function SetRingChecked(ring, checked)
	ring.checked = Checked(checked)
	PaintRing(ring)
end

function Lumen.Ring(host, checked)
	local ring = rings[host]
	if ring then
		return ring
	end
	Skin.Strip(host)
	local box = CreateFrame("Frame", nil, host)
	box:SetFrameLevel(host:GetFrameLevel() + RING_LEVEL)
	local ringTexture = box:CreateTexture(nil, "ARTWORK")
	ringTexture:SetTexture((Lumen.Texture("checkRing")))
	local fill = box:CreateTexture(nil, "OVERLAY")
	fill:SetTexture((Lumen.Texture("gemFill")))
	ring = { check = host, box = box, ring = ringTexture, fill = fill, hoverT = 0, checked = Checked(checked), Paint = PaintRing, Restyle = RestyleRing, SetChecked = SetRingChecked }
	RestyleRing(ring)
	Style.Track(ring)
	Widgets.Track(ring)
	rings[host] = ring
	return ring
end

function Lumen.RingCheck(check)
	if rings[check] then
		return rings[check]
	end
	local ring = Lumen.Ring(check, check:GetChecked())
	local function update()
		ring:SetChecked(check:GetChecked())
	end
	hooksecurefunc(check, "SetChecked", update)
	check:HookScript("OnClick", update)
	check:HookScript("OnShow", update)
	check:HookScript("OnEnter", function()
		Widgets.Hover(ring, true)
	end)
	check:HookScript("OnLeave", function()
		Widgets.Hover(ring, false)
	end)
	return ring
end
