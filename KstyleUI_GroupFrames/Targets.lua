-- Targets.lua: party targets: a small secure button beside each party frame for that member's target, built out of combat once switched on, its health read on a short timer while one shows.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens
local Settings, Style, Unit, Geometry = ns.Settings, ns.Style, ns.Unit, ns.Geometry

local Targets = {}
ns.Targets = Targets

local OWNER = "GroupFrames.Targets"
local SUFFIX = "target"
local REF = "kstyle-target"
local POLL = 0.2
local TEXT_LEVEL = 4
local HOSTILE = 2
local SAMPLE_HEALTH = 0.64
local WRAP = [[
	if name == "unit" then
		local t = self:GetFrameRef("kstyle-target")
		if t then t:SetAttribute("useparent-unit", value ~= "player" or t:GetAttribute("kstyle-self") == true) end
	end
]]

local issecretvalue = issecretvalue or function()
	return false
end

local built = {}
local waiting = setmetatable({}, { __mode = "k" })
local ticker, listening

local function Look(t)
	t.chrome = Widgets.Chrome(t, { shape = "tile", fill = "surface" })
	t.health = Widgets.UnitBar(t, { loss = false, spark = false })
	t.text = CreateFrame("Frame", nil, t)
	t.text:SetAllPoints(t)
	t.text:SetFrameLevel(t:GetFrameLevel() + TEXT_LEVEL)
	t.name = Widgets.FontString(t.text, "OVERLAY")
	t.name:SetWordWrap(false)
	t.name:SetJustifyH("CENTER")
end

local function Room(k)
	local cfg, gap = Settings.current.targets, Tokens.Size("gapSmall")
	if Geometry.IsVertical(k.growth) then
		local geo = Geometry.Party(k)
		return geo.memberWidth + (geo.laneSide == "RIGHT" and geo.lane or 0) + gap + cfg.x, cfg.y
	end
	return cfg.x, cfg.y - k.height - gap
end

function Targets.Room(k)
	local cfg = Settings.current.targets
	if not cfg.enabled then
		return 0, 0
	end
	local gap = Tokens.Size("gapSmall")
	if Geometry.IsVertical(k.growth) then
		return math.max(0, gap + cfg.x + cfg.width), 0
	end
	return 0, math.max(0, gap + cfg.height - cfg.y)
end

local function Layout(t, anchor)
	local f, cfg, k = t.content, Settings.current.targets, Settings.current.party
	local x, y = Room(k)
	t:ClearAllPoints()
	t:SetPoint("TOPLEFT", anchor, "TOPLEFT", Widgets.Snap(f, x), Widgets.Snap(f, y))
	t:SetSize(Widgets.Snap(f, cfg.width), Widgets.Snap(f, cfg.height))
	t.chrome:Restyle()
	local pad = Tokens.Size("gapSmall")
	local rect = { left = pad, top = pad, width = math.max(1, cfg.width - 2 * pad), height = math.max(1, cfg.height - 2 * pad) }
	t.health:SetBarTexture(Settings.current.health.texture)
	Style.PlaceBar(t, t.health, rect)
	local text = Settings.current.text
	Style.SetFont(t.name, text.nameFont, math.max(6, math.min(k.nameSize, rect.height)), text.nameOutline == "NONE" and "OUTLINE" or text.nameOutline, "names")
	t.name:ClearAllPoints()
	t.name:SetPoint("CENTER", t.health, "CENTER", 0, 0)
	t.name:SetWidth(Widgets.Snap(f, math.max(1, rect.width - 2 * Tokens.Size("gapTiny"))))
end

local function NameColor(t, player, class)
	local cfg = Settings.current.targets
	if cfg.nameColor == "custom" then
		t.name:SetTextColor(cfg.color.r, cfg.color.g, cfg.color.b)
	elseif cfg.nameColor == "class" and player then
		t.name:SetTextColor(Unit.NameColor(class))
	else
		t.name:SetTextColor(Tokens.Color("textEmphasis"))
	end
end

local function Health(t, unit)
	t.health:SetBarRange(0, UnitHealthMax(unit))
	t.health:SetHealth(UnitHealth(unit), true)
end

local function Paint(t)
	local owner = t.content.unit
	if not owner or not t:IsVisible() then
		return
	end
	local unit = owner .. SUFFIX
	local player = UnitIsPlayer and UnitIsPlayer(unit)
	player = not issecretvalue(player) and player == true
	local _, class = UnitClass(unit)
	local reaction = UnitReaction and UnitReaction(unit, "player")
	t.reaction = not issecretvalue(reaction) and reaction or nil
	local r, g, b
	if player then
		r, g, b = Unit.ClassColor(class)
	else
		r, g, b = K.ColorVision.ReactionColor(reaction)
	end
	t.health:SetBarColor(r, g, b, Settings.current.health.alpha)
	t.name:SetText(UnitName(unit))
	NameColor(t, player, class)
	Health(t, unit)
end

local function Tick()
	local any = false
	for _, t in ipairs(built) do
		local owner = t.content.unit
		if owner and t:IsVisible() then
			any = true
			local unit = owner .. SUFFIX
			local reaction = UnitReaction and UnitReaction(unit, "player")
			if not issecretvalue(reaction) and reaction ~= t.reaction then
				Paint(t)
			else
				Health(t, unit)
			end
		end
	end
	if not any and ticker then
		ticker:Cancel()
		ticker = nil
	end
end

local function OnShow(t)
	Paint(t)
	if not ticker and C_Timer and type(C_Timer.NewTicker) == "function" then
		ticker = C_Timer.NewTicker(POLL, Tick)
	end
end

local function OnTarget(event, unit)
	if event == "PLAYER_TARGET_CHANGED" then
		unit = "player"
	end
	local all = issecretvalue(unit)
	for _, t in ipairs(built) do
		if all or t.content.unit == unit then
			Paint(t)
		end
	end
end

local function Listen(on)
	if on == (listening or false) then
		return
	end
	listening = on
	for _, event in ipairs({ "UNIT_TARGET", "PLAYER_TARGET_CHANGED" }) do
		if on then
			K.Events.Register(OWNER, event, OnTarget)
		else
			K.Events.Unregister(OWNER, event)
		end
	end
end

local function Build(f)
	local owner = f.owner
	local t = CreateFrame("Button", nil, owner, "SecureUnitButtonTemplate")
	t.content = f
	t:SetAttribute("useparent-unit", true)
	t:SetAttribute("unitsuffix", SUFFIX)
	t:SetAttribute("*type1", "target")
	t:SetAttribute("*type2", "togglemenu")
	t:RegisterForClicks("AnyUp")
	t:Hide()
	Look(t)
	t:HookScript("OnShow", OnShow)
	SecureHandlerSetFrameRef(owner, REF, t)
	f.partyTarget = t
	built[#built + 1] = t
	return t
end

local function Usable()
	return type(RegisterUnitWatch) == "function" and type(SecureHandlerWrapScript) == "function" and type(SecureHandlerSetFrameRef) == "function"
end

local function Sync(f)
	local cfg, t = Settings.current.targets, f.partyTarget
	if not (t or cfg.enabled) or not f.owner or not Usable() then
		return
	end
	if InCombatLockdown() then
		if not waiting[f] then
			waiting[f] = true
			K.Combat.Queue(function()
				waiting[f] = nil
				Sync(f)
			end)
		end
		return
	end
	t = t or Build(f)
	if cfg.enabled then Layout(t, f.owner) end
	t:SetAttribute("kstyle-self", cfg.self)
	t:SetAttribute("useparent-unit", f.owner:GetAttribute("unit") ~= "player" or cfg.self)
	if cfg.enabled ~= (t.watched or false) then
		t.watched = cfg.enabled
		if cfg.enabled then
			SecureHandlerWrapScript(f.owner, "OnAttributeChanged", f.owner, WRAP)
			RegisterUnitWatch(t)
		else
			SecureHandlerUnwrapScript(f.owner, "OnAttributeChanged")
			UnregisterUnitWatch(t)
			t:Hide()
		end
	end
	Listen(cfg.enabled)
	Paint(t)
end

local function SampleTarget(f)
	if not f.sampleTarget then
		f.sampleTarget = CreateFrame("Frame", nil, f:GetParent())
		f.sampleTarget.content = f
		Look(f.sampleTarget)
	end
	return f.sampleTarget
end

local function Applied(f)
	if f.kind ~= "party" then
		return
	elseif not f.sample then
		Sync(f)
	elseif Settings.current.targets.enabled then
		Layout(SampleTarget(f), f)
	end
end
Style.appliers[#Style.appliers + 1] = Applied

local function PaintSample(f, sample)
	local on = f.kind == "party" and Settings.current.targets.enabled and sample.targetName ~= nil and f:IsShown()
	if not on then
		if f.sampleTarget then f.sampleTarget:Hide() end
		return
	end
	local t = SampleTarget(f)
	t:Show()
	local player = sample.targetClass ~= nil
	local r, g, b
	if player then
		r, g, b = Unit.ClassColor(sample.targetClass)
	else
		r, g, b = K.ColorVision.ReactionColor(HOSTILE)
	end
	t.health:SetBarColor(r, g, b, Settings.current.health.alpha)
	t.health:SetBarRange(0, 1)
	t.health:SetHealth(SAMPLE_HEALTH, true)
	t.name:SetText(sample.targetName)
	NameColor(t, player, sample.targetClass)
end
Style.painters[#Style.painters + 1] = PaintSample

local function Changed(f)
	if f.partyTarget then
		Paint(f.partyTarget)
	end
end
Unit.changed[#Unit.changed + 1] = Changed
Unit.extra[#Unit.extra + 1] = Changed
