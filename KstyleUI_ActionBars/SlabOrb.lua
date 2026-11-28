-- SlabOrb.lua: the mage's power orb in the crest's opening (docs/medallions-effects.md#mage-power-orb).
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens
local Medals = ns.SlabMedals

local Orb = {}
local NONE = {}
ns.SlabOrb = Orb

local OPENING, VESSEL, LIGHT, CORE, BURST, MENISCUS = 118, 1.05, 2.05, 2.9, 1.5, 8
local GLOW, GLOW_ALPHA, COVER, RIM = 1.3, 0.55, 2, 1.3
local RACES = { Human = 0.78, Gnome = 0.72, Orc = 0.74, Scourge = 0.76, Troll = 0.74, Skyborne = 0.74 }
local SCHOOLS = { "Arcane", "Fire", "Frost" }
local COLORS = { Arcane = "schoolArcane", Fire = "schoolFire", Frost = "schoolFrost" }
local GREAT = { { 12042 }, { 11129 }, { 12472, 11958 } }
local EVOCATION = { 12051 }
local FIREBALL = { 25306, 10151, 10150, 10149, 10148, 8402, 8401, 8400, 3140, 145, 143, 133 }
local IDLE = 3
local PROCS = {
	{ token = "orbClear", spells = { 12536 } },
	{ token = "orbBarrage", spells = { 400589, 1326083 } },
	{ token = "orbHeat", spells = { 400625 }, stacks = 3, bands = true, school = "Fire" },
	{ token = "orbRime", spells = { 400670 }, stacks = 2, school = "Frost" },
}
Orb.RACES, Orb.GREAT, Orb.PROCS = RACES, GREAT, PROCS

function Orb.School()
	return SCHOOLS[ns.SlabRail.Tree()] or SCHOOLS[1]
end

function Orb.Spell()
	return Medals.Known(GREAT[ns.SlabRail.Tree()] or GREAT[1]) or Medals.Known(EVOCATION) or Medals.Known(FIREBALL)
end

function Orb.Want()
	return ns.SlabRail.form == "crest" and ns.Config("crestOrb") ~= false and Orb.Spell() or nil
end

function Orb.Held()
	return Orb.held
end

function Orb.Expected()
	return not Orb.missed and Orb.Want() or nil
end

function Orb.Commit()
	if Medals.Locked() then
		return false
	end
	local p, want = Orb.piece, Orb.Want()
	local held = p and p:IsShown() and p.school == Orb.School() and want or nil
	local missed = want ~= nil and held == nil
	local changed = held ~= Orb.held or missed ~= (Orb.missed == true)
	Orb.held, Orb.missed = held, missed
	return changed
end

function Orb.Choices()
	local choices = {}
	for i, school in ipairs(SCHOOLS) do
		choices[i] = { school = school, known = function() return Orb.School() == school and Orb.Want() or nil end }
	end
	return choices
end

function Orb.Holds(spells)
	local held = Orb.Expected()
	for _, id in ipairs(held and spells or NONE) do
		if id == held then
			return true
		end
	end
	return false
end

local function Race()
	local race = K.Medallions and K.Medallions.Identity and K.Medallions.Identity("player")
	return RACES[race] and race or "Human"
end

local function Path(token)
	return (Tokens.Texture(token))
end

local function Band(p, parent, level, radius, n, of, wide)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetFrameLevel(level)
	bar:SetOrientation("VERTICAL")
	bar:SetStatusBarTexture(Path("dot"))
	bar:GetStatusBarTexture():SetAlpha(0)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)
	local high = of and 2 * radius / of or 2 * radius
	local low, top = Widgets.Snap(p, -radius + (of and (n - 1) * high or 0)), Widgets.Snap(p, -radius + (of and n * high or high))
	bar:SetSize(Widgets.Snap(p, wide or p.light), top - low)
	bar:SetPoint("BOTTOM", p, "CENTER", 0, low)
	return bar
end

local function Clip(owner, bar, p)
	local clip = CreateFrame("Frame", nil, owner)
	clip:SetAllPoints(bar:GetStatusBarTexture())
	clip:SetClipsChildren(true)
	local seat = CreateFrame("Frame", nil, clip)
	seat:SetSize(1, 1)
	seat:SetPoint("CENTER", p, "CENTER", 0, 0)
	return seat
end

local function Proc(p, each, level)
	local spec = { feed = "aura", unit = "player", filter = "HELPFUL", spells = each.spells }
	local lit = Medals.Lit(p, spec, level)
	lit.fires = {}
	if not each.stacks then
		local lights = Medals.Lights(p, lit, level + 1, p)
		lit.fires[1] = Medals.Aura(p, lights.flame, each.token, p.light, "white", nil, nil, nil, lights)
	else
		local hosts = Medals.Lights(p, lit, level + 1, false)
		local flame, calm = hosts.flame, hosts.calm
		if not flame.layers then
			flame.layers, calm.layers = Medals.Layer(flame, level + 2), Medals.Layer(calm, level + 2)
		end
		for n = 1, lit.container and each.stacks or 0 do
			local slot = lit.container:AddAuraSlot("stack" .. n, spec.filter, spec.options)
			pcall(slot.EnableMouse, slot, false)
			slot:SetAllPoints(p)
			slot:SetFrameLevel(level + 1)
			slot.container, slot.hold = lit.container, lit.hold
			local reach = each.bands and RIM or 1
			local bar = Band(p, slot, level + 1, p.radius * reach, n, each.bands and each.stacks, p.light * reach)
			local token = each.bands and each.token or each.token .. n
			lit.fires[n] = Medals.Aura(p, flame.layers, token, p.light * reach, "white", nil, nil, nil, { flame = Clip(flame.layers, bar, p), calm = Clip(calm.layers, bar, p) })
			slot.bar = bar
			slot:SetApplicationBar(bar, { minApplications = n - 1, maxApplications = n })
			p.lits[#p.lits + 1] = slot
		end
	end
	Medals.Flare(p, lit, level + 4, "medBurstMage", p.light * BURST)
	return lit
end


function Orb.Build(parent, spec, level)
	local race = Race()
	local units = OPENING / 2 * RACES[race]
	local p = Medals.Piece(parent, level, OPENING)
	p.race, p.radius, p.light = race, units, units * LIGHT
	p.add(Medals.Texture(p, "BACKGROUND", -1, "dot", "black", OPENING + COVER))
	p.add(Medals.Texture(p, "BORDER", 0, "orbVessel" .. race, "white", OPENING * VESSEL))
	local lit = Medals.Lit(p, spec, level + 1)
	p.bar = Band(p, lit, level + 1, units)
	p.keeps = true
	p.bar:SetValue(1)
	local school = spec.school or Orb.School()
	p.school = school
	p.fill = Medals.Aura(p, Clip(lit, p.bar, p), "orbLight" .. school, p.light, "white")
	p.fill.slow = Medals.Flip(p.fill, "orbLight" .. school, IDLE)
	p.spent = Medals.Layer(lit, level + 3)
	p.spent:Hide()
	p.meniscus = p.spent:CreateTexture(nil, "ARTWORK")
	p.meniscus:SetTexture(Path("orbMeniscus" .. school))
	p.meniscus:SetBlendMode("ADD")
	p.meniscus:SetSize(Widgets.Snap(p, p.light), Widgets.Snap(p, p.light / MENISCUS))
	p.meniscus:SetPoint("CENTER", p.bar:GetStatusBarTexture(), "TOP", 0, 0)
	local mask = p.spent:CreateMaskTexture()
	mask:SetTexture(Path("orbMask"), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetSize(Widgets.Snap(p, 2 * units), Widgets.Snap(p, 2 * units))
	mask:SetPoint("CENTER", p, "CENTER", 0, 0)
	p.meniscus:AddMaskTexture(mask)
	p.ready = Medals.Layer(lit, level + 3)
	p.glow = p.add(Medals.Texture(p.ready, "BACKGROUND", 0, "glow", "white", p.light * GLOW, "ADD"))
	p.glow:SetAlpha(GLOW_ALPHA)
	p.glow:SetVertexColor(Tokens.Color(COLORS[school]))
	p.core = Medals.Aura(p, p.ready, "orbCore" .. school, units * CORE, "white")
	p.core.slow = Medals.Flip(p.core, "orbCore" .. school, IDLE)
	p.timer = p.add(Medals.Timer(lit, level + 3, "orbRing", "white"), 8)
	p.timer:SetDrawSwipe(false)
	p.timer:SetScript("OnCooldownDone", function()
		if p.cooled then
			Medals.Confirm(p, false)
		end
	end)
	Medals.Flare(p, lit, level + 4, "medBurstMage", p.light * BURST)
	p.procs = {}
	for i, each in ipairs(PROCS) do
		if not each.school or each.school == school then
			p.procs[#p.procs + 1] = Proc(p, each, level + 5 + 5 * (i - 1))
		end
	end
	local glass = Medals.Layer(p, level + 26)
	p.add(Medals.Texture(glass, "OVERLAY", 0, "orbGlass", "white", p.light, "ADD"))
	return p
end

function Orb.Place(p, anchor)
	Medals.Place(p, anchor, 0, 0)
	Orb.piece = p
end
