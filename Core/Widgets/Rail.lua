-- Rail.lua: the rail cards' shared Lumen pieces: the Lumen colour names with their fallbacks until the material foundation lands, the section cap, the class pill and the crystal disc.
local _, ns = ...

local Widgets, Tokens = ns.Widgets, ns.Tokens
local max, min = math.max, math.min

local SECTION_CAP_HEIGHT = 20
local GEM_SIZE = 6
local GEM_LEAD = 2
local GEM_GAP = "gapMedium"
local RULE_GAP = "gapMedium"
local ASIDE_GAP = "gapMedium"
local TITLE_ROLE = "caption"
local ASIDE_ROLE = "body"
local ASIDE_COLOR = "text"
local PILL_HEIGHT = 4
local PILL_GLOW_OUTSET = 3
local PILL_GLOW_ALPHA = 0.35
local PILL_TRACK = "track"
local DISC_FILL = "buttonFill"
local DISC_RING_ALPHA = 2.5
local QUARTER_TURN = math.pi / 4

local FALLBACK = {
	gilt = { "neutral", 1 },
	giltDim = { "neutral", 0.45 },
	rimLight = { "edgeInner", 1 },
	glass = { "surface", 1 },
	crystal = { "buttonFill", 1 },
	hairline = { "edgeFaint", 1 },
}
local TEXTURE_FALLBACK = {
	lensMask = "dot",
}
Widgets.LUMEN_FALLBACK = FALLBACK
Widgets.LUMEN_TEXTURE_FALLBACK = TEXTURE_FALLBACK
Widgets.SECTION_CAP_HEIGHT = SECTION_CAP_HEIGHT
Widgets.GEM_SIZE = GEM_SIZE

local known = {}

local function Known(name)
	local answer = known[name]
	if answer == nil then
		answer = pcall(Tokens.Color, name)
		known[name] = answer
	end
	return answer
end

function Widgets.LumenColor(name, alphaScale)
	local r, g, b, a
	if Known(name) then
		r, g, b, a = Tokens.Color(name)
	else
		local alias = FALLBACK[name]
		if not alias then
			error("KstyleUI.Widgets.LumenColor: unknown name " .. tostring(name), 2)
		end
		r, g, b, a = Tokens.Color(alias[1])
		a = (a or 1) * alias[2]
	end
	return r, g, b, (a or 1) * (alphaScale or 1)
end

local knownTextures = {}

function Widgets.LumenTexture(name)
	local answer = knownTextures[name]
	if answer == nil then
		answer = pcall(Tokens.Texture, name)
		knownTextures[name] = answer
	end
	if answer then
		return Tokens.Texture(name)
	end
	local alias = TEXTURE_FALLBACK[name]
	if not alias then
		error("KstyleUI.Widgets.LumenTexture: unknown name " .. tostring(name), 2)
	end
	return Tokens.Texture(alias)
end

function Widgets.LumenTint(region, name, alphaScale)
	region:SetVertexColor(Widgets.LumenColor(name, alphaScale))
end

local Cap = {}
Cap.__index = Cap

function Cap:SetTitle(text)
	self.titleText = text
	Widgets.SetText(self.title, text)
end

function Cap:SetAside(text)
	self.asideText = text
	local aside = self.aside
	local shown = text ~= nil and text ~= ""
	Widgets.SetText(aside, text)
	aside:SetShown(shown)
	local rule, frame = self.rule, self.frame
	rule:ClearAllPoints()
	rule:SetPoint("LEFT", self.title, "RIGHT", Widgets.Snap(frame, Tokens.Size(RULE_GAP)), 0)
	if shown then
		rule:SetPoint("RIGHT", aside, "LEFT", -Widgets.Snap(frame, Tokens.Size(ASIDE_GAP)), 0)
	else
		rule:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
	end
end

function Cap:Layout()
	local frame, gem, title, aside = self.frame, self.gem, self.title, self.aside
	frame:SetHeight(Widgets.Snap(frame, SECTION_CAP_HEIGHT))
	local size = Widgets.Snap(frame, GEM_SIZE)
	gem:ClearAllPoints()
	gem:SetSize(size, size)
	gem:SetPoint("LEFT", frame, "LEFT", Widgets.Snap(frame, GEM_LEAD), 0)
	title:ClearAllPoints()
	title:SetPoint("LEFT", gem, "RIGHT", Widgets.Snap(frame, Tokens.Size(GEM_GAP)), 0)
	aside:ClearAllPoints()
	aside:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
	self.rule:SetHeight(Widgets.Border(frame))
	self:SetAside(self.asideText)
end

function Cap:Paint()
	Widgets.StyleText(self.title, TITLE_ROLE)
	Widgets.StyleText(self.aside, ASIDE_ROLE)
	self.title:SetTextColor(Widgets.LumenColor("gilt"))
	self.aside:SetTextColor(Tokens.Color(ASIDE_COLOR))
	Widgets.LumenTint(self.gem, "gilt")
	Widgets.LumenTint(self.rule, "rimLight")
end

function Cap:Restyle()
	self:Layout()
	self:Paint()
end

function Widgets.SectionCap(parent, opts)
	opts = opts or {}
	local frame = CreateFrame("Frame", nil, parent)
	local gem = frame:CreateTexture(nil, "ARTWORK", nil, 1)
	gem:SetColorTexture(Tokens.Color("white"))
	gem:SetRotation(QUARTER_TURN)
	local rule = frame:CreateTexture(nil, "ARTWORK")
	rule:SetTexture((Tokens.Texture("divider")))
	local cap = setmetatable({
		frame = frame,
		gem = gem,
		rule = rule,
		title = Widgets.Text(frame, TITLE_ROLE),
		aside = Widgets.Text(frame, ASIDE_ROLE, ASIDE_COLOR),
	}, Cap)
	cap.title:SetWordWrap(false)
	cap.aside:SetWordWrap(false)
	cap.aside:SetJustifyH("RIGHT")
	cap:SetTitle(opts.title or "")
	cap:Restyle()
	cap:SetAside(opts.aside)
	return Widgets.Track(cap)
end

local Pill = {}
Pill.__index = Pill

local function Reach(pill)
	local width = pill.frame:GetWidth()
	if Widgets.IsSecret(width) or type(width) ~= "number" or width < 0 then
		return 0
	end
	return width
end

function Pill:SetShare(share)
	if Widgets.IsSecret(share) or type(share) ~= "number" or share ~= share then
		share = 0
	end
	share = min(1, max(0, share))
	self.share = share
	local width = Reach(self) * share
	self.fillBox:SetWidth(width)
	self.fillBox:SetShown(width > 0)
end

function Pill:SetColor(r, g, b)
	self.r, self.g, self.b = r, g, b
	Widgets.ColorSlice(self.fill, r, g, b, 1)
	self.glow:SetVertexColor(r, g, b, PILL_GLOW_ALPHA)
end

function Pill:Layout()
	local frame, height = self.frame, Widgets.Snap(self.frame, self.height)
	frame:SetHeight(height)
	Widgets.LayoutPill(self.track, height)
	Widgets.LayoutPill(self.fill, height)
	local outset = Widgets.Snap(frame, PILL_GLOW_OUTSET)
	self.glow:ClearAllPoints()
	self.glow:SetPoint("TOPLEFT", self.fillBox, "TOPLEFT", -outset, outset)
	self.glow:SetPoint("BOTTOMRIGHT", self.fillBox, "BOTTOMRIGHT", outset, -outset)
	self:SetShare(self.share)
end

function Pill:Paint()
	Widgets.ColorSlice(self.track, Tokens.Color(PILL_TRACK))
	if self.r then
		self:SetColor(self.r, self.g, self.b)
	end
end

function Pill:Restyle()
	self:Layout()
	self:Paint()
end

function Pill:SetPoint(...)
	self.frame:SetPoint(...)
end

function Pill:ClearAllPoints()
	self.frame:ClearAllPoints()
end

function Pill:SetWidth(width)
	self.frame:SetWidth(width)
	self:SetShare(self.share)
end

function Pill:GetHeight()
	return self.frame:GetHeight()
end

function Pill:SetShown(shown)
	self.frame:SetShown(shown)
end

function Widgets.ClassPill(parent, opts)
	opts = opts or {}
	local frame = CreateFrame("Frame", nil, parent)
	local fillBox = CreateFrame("Frame", nil, frame)
	fillBox:SetPoint("TOPLEFT", frame, "TOPLEFT")
	fillBox:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
	local pill = setmetatable({
		frame = frame,
		fillBox = fillBox,
		height = opts.height or PILL_HEIGHT,
		share = 0,
		track = Widgets.Pill(frame, "ARTWORK", 0),
		glow = frame:CreateTexture(nil, "ARTWORK", nil, 1),
		fill = Widgets.Pill(fillBox, "ARTWORK", 2),
	}, Pill)
	pill.glow:SetTexture((Tokens.Texture("pill")))
	pill.glow:SetBlendMode("ADD")
	frame:HookScript("OnSizeChanged", function()
		pill:SetShare(pill.share)
	end)
	pill:Restyle()
	return Widgets.Track(pill)
end

local Disc = {}
Disc.__index = Disc

function Disc:SetRim(r, g, b, a)
	self.rim = { r, g, b, a }
	self.ring:SetVertexColor(r, g, b, a)
end

function Disc:Paint()
	self.disc:SetVertexColor(Tokens.Color(DISC_FILL))
	if self.rim then
		local c = self.rim
		self.ring:SetVertexColor(c[1], c[2], c[3], c[4])
	else
		Widgets.LumenTint(self.ring, "rimLight", DISC_RING_ALPHA)
	end
end

function Disc:Restyle()
	self:Paint()
end

function Disc:SetShown(shown)
	self.disc:SetShown(shown)
	self.ring:SetShown(shown)
end

function Widgets.CrystalDisc(owner, opts)
	opts = opts or {}
	local disc = owner:CreateTexture(nil, opts.layer or "BACKGROUND", nil, opts.sublevel or 0)
	disc:SetTexture((Tokens.Texture("dot")))
	disc:SetAllPoints(owner)
	local ring = owner:CreateTexture(nil, opts.layer or "BACKGROUND", nil, (opts.sublevel or 0) + 1)
	ring:SetTexture((Tokens.Texture("ringBevel")))
	ring:SetAllPoints(owner)
	local crystal = setmetatable({ owner = owner, disc = disc, ring = ring }, Disc)
	crystal:Paint()
	return Widgets.Track(crystal)
end
