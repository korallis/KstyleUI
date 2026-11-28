-- SlabOrb.lua: each class's centrepiece in the crest's opening, the mage's power orb and the hunter's bow (docs/medallions-effects.md#mage-power-orb, #hunters-bow).
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens
local Medals = ns.SlabMedals

local Orb = {}
local NONE = {}
ns.SlabOrb = Orb

local OPENING, VESSEL, LIGHT, CORE, BURST, MENISCUS = 118, 1.05, 2.05, 2.9, 1.5, 8
local GLOW, GLOW_ALPHA, COVER, RIM = 1.3, 0.55, 2, 1.3
local HUNTER_BURST = 1.35
local RACES = { Human = 0.78, Gnome = 0.72, Orc = 0.74, Scourge = 0.76, Troll = 0.74, Skyborne = 0.74, Dwarf = 0.74, NightElf = 0.76, Tauren = 0.72 }
local IDLE = 3
local CLASSES = {
	MAGE = {
		art = "orb", overlay = "orbGlass", blend = "ADD", burst = "medBurstMage", flare = BURST,
		levels = { spent = 3, ready = 3, timer = 3, flare = 4, procs = 5, overlay = 26 },
		trees = {
			{ school = "Arcane", color = "schoolArcane", great = { 12042 } },
			{ school = "Fire", color = "schoolFire", great = { 11129 } },
			{ school = "Frost", color = "schoolFrost", great = { 12472, 11958 } },
		},
		fallback = { { 12051 }, { 25306, 10151, 10150, 10149, 10148, 8402, 8401, 8400, 3140, 145, 143, 133 } },
		procs = {
			{ token = "orbClear", spells = { 12536 } },
			{ token = "orbBarrage", spells = { 400589, 1326083 } },
			{ token = "orbHeat", spells = { 400625 }, stacks = 3, bands = true, school = "Fire" },
			{ token = "orbRime", spells = { 400670 }, stacks = 2, school = "Frost" },
		},
	},
	HUNTER = {
		art = "bow", overlay = "bowFrame", blend = "BLEND", burst = "medBurstHunter", flare = HUNTER_BURST,
		levels = { spent = 2, overlay = 3, ready = 4, timer = 4, flare = 5, procs = 6 },
		trees = {
			{ school = "Beast", great = { 19574 } },
			{ school = "Marks", great = { 3045 } },
			{ school = "Survival", window = { 1310726 }, talent = { 1310532 } },
		},
		fallback = { { 3045 }, { 75 } },
		procs = {
			{ token = "bowRapid", spells = { 415407 }, school = "Marks" },
		},
	},
}
Orb.RACES, Orb.CLASSES = RACES, CLASSES

local function Class()
	return CLASSES[ns.class] or CLASSES.MAGE
end

local function Tree()
	local trees = Class().trees
	return trees[ns.SlabRail.Tree()] or trees[1]
end

function Orb.School()
	return Tree().school
end

local function On()
	if Orb.on == nil or not Medals.Locked() then
		Orb.on = ns.SlabRail.form == "crest" and ns.Config("crestOrb") ~= false
	end
	return Orb.on
end

function Orb.Window()
	local tree = Tree()
	return tree.window and On() and Medals.Known(tree.talent) or nil
end

function Orb.Spell()
	local tree = Tree()
	if tree.window and Medals.Known(tree.talent) then
		return nil
	end
	local id = tree.great and Medals.Known(tree.great)
	for _, spells in ipairs(Class().fallback) do
		id = id or Medals.Known(spells)
	end
	return id
end

function Orb.Want()
	return CLASSES[ns.class] and On() and Orb.Spell() or nil
end

function Orb.Held()
	return Orb.held
end

function Orb.Holding()
	return Orb.held ~= nil and Medals.Locked()
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

function Orb.Choices(class)
	local choices = {}
	for _, tree in ipairs(CLASSES[class].trees) do
		local school = tree.school
		choices[#choices + 1] = { school = school, known = function() return Orb.School() == school and Orb.Want() or nil end }
		if tree.window then
			choices[#choices + 1] = { school = school, feed = "aura", unit = "player", filter = "HELPFUL", spells = tree.window, window = true,
				known = function() return Orb.School() == school and Orb.Window() or nil end }
		end
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

local function Proc(p, each, level, class)
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
	Medals.Flare(p, lit, level + 4, class.burst, p.light * class.flare)
	return lit
end


function Orb.Build(parent, spec, level)
	local class, race = Class(), Race()
	local art, at = class.art, class.levels
	local units = OPENING / 2 * RACES[race]
	local p = Medals.Piece(parent, level, OPENING)
	p.race, p.radius, p.light = race, units, units * LIGHT
	p.add(Medals.Texture(p, "BACKGROUND", -1, "dot", "black", OPENING + COVER))
	p.add(Medals.Texture(p, "BORDER", 0, "orbVessel" .. race, "white", OPENING * VESSEL))
	local lit = Medals.Lit(p, spec, level + 1)
	p.bar = Band(p, lit, level + 1, units)
	if spec.window then
		local timer = Enum and Enum.StatusBarTimerDirection
		lit:SetDurationBar(p.bar, { direction = timer and timer.RemainingTime or 1 })
	else
		p.keeps = true
		p.bar:SetValue(1)
	end
	local school = spec.school or Orb.School()
	p.school, p.window = school, spec.window
	p.fill = Medals.Aura(p, Clip(lit, p.bar, p), art .. "Light" .. school, p.light, "white")
	if not spec.window then
		p.fill.slow = Medals.Flip(p.fill, art .. "Light" .. school, IDLE)
	end
	p.spent = Medals.Layer(lit, level + at.spent)
	p.spent:SetShown(spec.window == true)
	p.meniscus = p.spent:CreateTexture(nil, "ARTWORK")
	p.meniscus:SetTexture(Path(art .. "Meniscus" .. school))
	p.meniscus:SetBlendMode("ADD")
	p.meniscus:SetSize(Widgets.Snap(p, p.light), Widgets.Snap(p, p.light / MENISCUS))
	p.meniscus:SetPoint("CENTER", p.bar:GetStatusBarTexture(), "TOP", 0, 0)
	local mask = p.spent:CreateMaskTexture()
	mask:SetTexture(Path("orbMask"), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetSize(Widgets.Snap(p, 2 * units), Widgets.Snap(p, 2 * units))
	mask:SetPoint("CENTER", p, "CENTER", 0, 0)
	p.meniscus:AddMaskTexture(mask)
	p.ready = Medals.Layer(lit, level + at.ready)
	local tree = Tree()
	if tree.color then
		p.glow = p.add(Medals.Texture(p.ready, "BACKGROUND", 0, "glow", "white", p.light * GLOW, "ADD"))
		p.glow:SetAlpha(GLOW_ALPHA)
		p.glow:SetVertexColor(Tokens.Color(tree.color))
	end
	p.core = Medals.Aura(p, p.ready, art .. "Core" .. school, units * CORE, "white")
	if not spec.window then
		p.core.slow = Medals.Flip(p.core, art .. "Core" .. school, IDLE)
		p.timer = p.add(Medals.Timer(lit, level + at.timer, "orbRing", "white"), 8)
		p.timer:SetDrawSwipe(false)
		p.timer:SetScript("OnCooldownDone", function()
			if p.cooled then
				Medals.Confirm(p, false)
			end
		end)
	end
	Medals.Flare(p, lit, level + at.flare, class.burst, p.light * class.flare)
	p.procs = {}
	for i, each in ipairs(class.procs) do
		if not each.school or each.school == school then
			p.procs[#p.procs + 1] = Proc(p, each, level + at.procs + 5 * (i - 1), class)
		end
	end
	local over = Medals.Layer(p, level + at.overlay)
	p.over = p.add(Medals.Texture(over, "OVERLAY", 0, class.overlay, "white", p.light, class.blend))
	return p
end

function Orb.Place(p, anchor)
	Medals.Place(p, anchor, 0, 0)
	Orb.piece = p
end
