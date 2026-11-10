-- Lumen.lua: the Lumen pieces the skins share, and the one place that switches to S1's names: the gilt and quest gold colours, the story card's text sizes in root units whatever scale the frame that draws them has, the gem, the section cap (gem, tracked title, fading rule, trailing count) and the ring check box.
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
local GEM_UNITS, GEM_GAP, INSET = 8, 7, 15
local CAP_SIZE, TEXT_SIZE = 12, 13
local RULE_LEAD, RULE_TRAIL, RULE_UNITS, RULE_ALPHA = 11, 9, 1, 0.5
local RING_UNITS, RING_FILL, RING_LEVEL = 14, 8, 2
local THIN_SPACE = "\226\128\137"
local CODEPOINT = "([\1-\127\194-\244][\128-\191]*)"

local WEAK = { __mode = "k" }
local rings = setmetatable({}, WEAK)

Lumen.FALLBACKS, Lumen.TEXTURES = FALLBACKS, TEXTURES
Lumen.GEM_UNITS, Lumen.GEM_GAP, Lumen.INSET, Lumen.CAP_SIZE, Lumen.TEXT_SIZE = GEM_UNITS, GEM_GAP, INSET, CAP_SIZE, TEXT_SIZE
Lumen.RULE_LEAD, Lumen.RULE_TRAIL, Lumen.RULE_ALPHA = RULE_LEAD, RULE_TRAIL, RULE_ALPHA
Lumen.RING_UNITS, Lumen.RING_FILL = RING_UNITS, RING_FILL

local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

local function PlainSize(value)
	if IsSecret(value) or type(value) ~= "number" or value <= 0 then
		return nil
	end
	return value
end

function Lumen.Color(name)
	local ok, r, g, b, a = pcall(Tokens.Color, S1_NAMES[name] or name)
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
	return Widgets.Snap(frame, INSET / Widgets.ScaleFactor(frame))
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

function Lumen.CapColumn(row)
	return Widgets.Snap(row, Lumen.Size(row, GEM_UNITS)) + Widgets.Snap(row, Lumen.Size(row, GEM_GAP))
end

local function Units(value, row)
	if type(value) == "function" then
		return value(row)
	end
	return value or 0
end

local Cap = {}
Cap.__index = Cap

function Cap:Fit()
	local row, opts = self.row, self.opts
	local rowWidth = PlainSize(row:GetWidth())
	local titleWidth = Widgets.TextWidth(self.title)
	if not rowWidth or not titleWidth then
		self.title:SetWidth(0)
		return
	end
	local trailWidth = Widgets.TextWidth(self.trail, 0)
	local taken = Units(opts.left, row) + Lumen.CapColumn(row) + Lumen.Size(row, RULE_LEAD + RULE_TRAIL) + trailWidth + Units(opts.right, row)
	local room = rowWidth - taken
	if titleWidth <= room then
		self.title:SetWidth(0)
		return
	end
	self.title:SetWidth(math.max(0, room) + Widgets.TrackPad(self.title))
end

function Cap:SetTitle(value)
	self.titleValue = Lumen.Plain(value)
	self.title:SetText(Lumen.Tracked(self.titleValue:upper()))
	self:Fit()
end

function Cap:SetTrail(value)
	self.trailValue = Lumen.Plain(value)
	self.trail:SetText(self.trailValue)
	self:Fit()
end

function Cap:SetShown(shown)
	self.row:SetShown(shown)
end

function Cap:Paint()
	Lumen.Tint(self.gem, "gilt")
	local r, g, b = Lumen.Color("gilt")
	self.title:SetTextColor(Tokens.Color("capsGold"))
	Widgets.TextColor(self.trail, "textEmphasis")
	self.rule:SetColorTexture(r, g, b, RULE_ALPHA)
	Widgets.PaintCapMaterial(self.gem, self.rule, RULE_ALPHA)
end

function Cap:Restyle()
	local row, opts = self.row, self.opts
	local y = Widgets.Snap(row, Units(opts.y, row))
	Style.ApplyFont(self.title, "caps", Lumen.Size(row, CAP_SIZE))
	Style.ApplyFont(self.trail, "number", Lumen.Size(row, CAP_SIZE))
	local left = Widgets.Snap(row, Units(opts.left, row))
	local gem = Lumen.Size(row, GEM_UNITS)
	Widgets.Size(self.gem, gem, gem)
	self.gem:ClearAllPoints()
	self.gem:SetPoint("LEFT", row, "LEFT", left, y)
	self.title:ClearAllPoints()
	self.title:SetPoint("LEFT", row, "LEFT", left + Lumen.CapColumn(row), y)
	self.title:SetJustifyH("LEFT")
	self.title:SetWordWrap(false)
	self.trail:ClearAllPoints()
	self.trail:SetPoint("RIGHT", row, "RIGHT", -Widgets.Snap(row, Units(opts.right, row)), y)
	self.trail:SetJustifyH("RIGHT")
	self.rule:ClearAllPoints()
	self.rule:SetPoint("LEFT", self.title, "RIGHT", Widgets.Snap(row, Lumen.Size(row, RULE_LEAD) - Widgets.TrackPad(self.title)), 0)
	self.rule:SetPoint("RIGHT", self.trail, "LEFT", -Widgets.Snap(row, Lumen.Size(row, RULE_TRAIL)), 0)
	self.rule:SetHeight(math.max(Widgets.Border(row), Widgets.Snap(row, Lumen.Size(row, RULE_UNITS))))
	self:Paint()
	self:SetTitle(self.titleValue)
	self:SetTrail(self.trailValue)
end

function Lumen.SectionCap(parent, opts)
	local row = CreateFrame("Frame", nil, parent)
	local cap = setmetatable({
		row = row,
		opts = opts or {},
		gem = Lumen.Gem(row, "OVERLAY"),
		title = Widgets.FontString(row, "OVERLAY"),
		trail = Widgets.FontString(row, "OVERLAY"),
		rule = row:CreateTexture(nil, "ARTWORK"),
		titleValue = "",
		trailValue = "",
	}, Cap)
	row:HookScript("OnSizeChanged", function()
		cap:Fit()
	end)
	cap:Restyle()
	Style.Track(cap)
	Widgets.Track(cap)
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
	box:SetPoint("CENTER", host, "CENTER")
	box:SetFrameLevel(host:GetFrameLevel() + RING_LEVEL)
	local ringTexture = box:CreateTexture(nil, "ARTWORK")
	ringTexture:SetTexture((Lumen.Texture("checkRing")))
	ringTexture:SetPoint("CENTER", box, "CENTER")
	local fill = box:CreateTexture(nil, "OVERLAY")
	fill:SetTexture((Lumen.Texture("gemFill")))
	fill:SetPoint("CENTER", box, "CENTER")
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
