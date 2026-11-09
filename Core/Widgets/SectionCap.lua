-- SectionCap.lua: the rail section cap, a gilt gem, a tracked Cinzel head, a gilt rule that fades out to the right and an optional count at the right end.
local _, ns = ...

local Widgets = ns.Widgets
local Tokens, Scale = ns.Tokens, ns.Scale

local GEM_ALPHA = 1
local RULE_ALPHA = 0.6
local GEM_REACH = 5
local GEM_GAP = 10
local DEFAULT_WIDTH = 278

local Cap = {}

local function Placed(self)
	local count = self.counted
	self.rule:ClearAllPoints()
	self.rule:SetPoint("LEFT", self.label, "RIGHT", Widgets.Snap(self, GEM_GAP), 0)
	if count then
		self.rule:SetPoint("RIGHT", self.count, "LEFT", -Widgets.Snap(self, GEM_GAP), 0)
	else
		self.rule:SetPoint("RIGHT", self, "RIGHT")
	end
	self.count:SetShown(count)
end

function Cap:SetText(text)
	Widgets.SetText(self.label, text)
end

function Cap:SetCount(value)
	self.counted = value ~= nil
	Widgets.SetText(self.count, value)
	Placed(self)
end

function Cap:Paint()
	self.gem:SetVertexColor(Widgets.Rgba("giltLit", GEM_ALPHA))
	self.rule:SetVertexColor(Widgets.Rgba("gilt", RULE_ALPHA))
	Widgets.TextColor(self.label, "giltLit")
	Widgets.TextColor(self.count, "muted")
end

function Cap:Restyle()
	local opts = self.opts
	Widgets.Size(self, opts.width or DEFAULT_WIDTH, Widgets.SECTION_CAP_HEIGHT)
	local gem = Widgets.Snap(self, Tokens.Size("gem"))
	self.gem:SetSize(gem, gem)
	self.gem:ClearAllPoints()
	self.gem:SetPoint("CENTER", self, "LEFT", Widgets.Snap(self, GEM_REACH), 0)
	self.label:ClearAllPoints()
	self.label:SetPoint("LEFT", self.gem, "RIGHT", Widgets.Snap(self, GEM_GAP + GEM_REACH) - gem / 2, 0)
	self.rule:SetHeight(Widgets.Border(self))
	self.count:ClearAllPoints()
	self.count:SetPoint("RIGHT", self, "RIGHT")
	Placed(self)
	self:Paint()
end

function Widgets.SectionCap(parent, opts)
	opts = opts or {}
	local cap = CreateFrame("Frame", opts.name, parent or Scale.Root())
	for k, fn in pairs(Cap) do
		cap[k] = fn
	end
	cap.opts = opts
	cap.counted = false
	cap.gem = cap:CreateTexture(nil, "ARTWORK")
	cap.gem:SetTexture((Tokens.Texture("gem")))
	cap.rule = cap:CreateTexture(nil, "ARTWORK")
	cap.rule:SetTexture((Tokens.Texture("ruleFade")))
	cap.label = Widgets.Text(cap, "title", "giltLit")
	cap.count = Widgets.Text(cap, "number", "muted")
	cap.count:SetJustifyH("RIGHT")
	cap:Restyle()
	if opts.text then
		cap:SetText(opts.text)
	end
	if opts.count ~= nil then
		cap:SetCount(opts.count)
	end
	return Widgets.Track(cap)
end
