-- Slab.lua: Medallions action slabs, one row per side of the crest hub, pet and stance plates, sockets and effects.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Motion, L = K.Widgets, K.Tokens, K.Motion, K.L
local min, max, floor, sin, cos, rad, abs = math.min, math.max, math.floor, math.sin, math.cos, math.rad, math.abs

local Slab = {}
ns.Slab = Slab

local STYLE = "medallions"
local OWNER = "ActionBars.Slab"
local STRATA = "LOW"
local RING, CREST, OPENING = 150, 150, 118
local MARGIN, HUB_LIFT, TEXT_FLOOR = 4, 8, 9
local SLAB = { pad = 9, stripGap = 3, strip = 3, bottom = 3 }
local SIDE = { rows = 2, gap = 4, pad = 6, clear = 12 }
local GLOW_SHARE, BLOOM_SHARE = 1.5, 1.08
local BADGE, BADGE_RISE = 18, 4
local CREST_REST = 1
local ICON_INSET, ICON_CROP, KEYBIND = 3, 0.08, 10
local PARTICLES, CALM_PARTICLES, PARTICLE_SIZE, PARTICLE_RISE = 10, 5, 7, 30
local RUNE_TURN, COMBAT_SPEED = 90, 2.25
local BREATH_LOW, BREATH_HIGH, COMBAT_GLOW, GLYPH_REST, RUNE_REST = 0.28, 0.43, 1.35, 0.35, 0.25
local BREATH = 4.2
local SHEEN_EVERY, SHEEN_RUN, SHEEN_W, SHEEN_ALPHA = 6, 1.2, 46, 0.5
local SWEEP_RUN, SWEEP_W, SWEEP_H = 0.5, 128, 16
local PULSE_RUN, PULSE_SCALE = 0.35, 1.05
local SHOCK_RUN, SHOCK_SCALE = 0.5, 1.6
local BURST_RUN, BURST_SHARE = 1.2, 2
local PROC_START = 0.35
local FLIP = { rows = 4, columns = 4, frames = 16, seconds = 0.96 }
local LEVEL_FLIP = { rows = 4, columns = 4, frames = 16, seconds = 1.2 }
local PARTICLE_CELLS = { rows = 2, columns = 2, frames = 4 }

local FALLBACK = {
	medHubSocket = "dot", medRingLarge = "ringBevel", medEnamelLarge = "ring", medRuneGlyphs = "ring",
	medLevelPlaque = "diamond", medPortraitSheen = "barSheen", medProcStart = "glow", medReadyFlash = "glow",
	medCombatSweep = "barSheen", medLevelUp = "glow", medProc = "glow", medParticle = "dot", medCrest = "logoLarge",
}

local CLASS_NAMES = {
	DEATHKNIGHT = "DeathKnight", DEMONHUNTER = "DemonHunter", DRUID = "Druid", HUNTER = "Hunter", MAGE = "Mage", MONK = "Monk",
	PALADIN = "Paladin", PRIEST = "Priest", ROGUE = "Rogue", SHAMAN = "Shaman", WARLOCK = "Warlock", WARRIOR = "Warrior", EVOKER = "Evoker",
}

Slab.RING, Slab.MARGIN, Slab.STRATA = RING, MARGIN, STRATA

local state = { combat = false, built = false, class = nil }

local function IsSecret(v)
	return ns.IsSecret(v)
end

local function Plain(v)
	return type(v) == "number" and not IsSecret(v)
end

function Slab.Active()
	return ns.running == true and K.HudStyle.Current() == STYLE
end

local function Layouts()
	return K.Setup and K.Setup.Layouts or {}
end

function Slab.Spec()
	return Layouts().MEDALLIONS_SLAB or SLAB
end

local function Grouped(def)
	local group = Layouts().MedallionsGroup
	return (def.key == "bar1" or def.key == "bar2") and K.HudStyle.Current() == STYLE and type(group) == "function"
end

local function Sided(def)
	return (def.key == "pet" or def.key == "stance") and K.HudStyle.Current() == STYLE
end

function Slab.Side()
	return Layouts().MEDALLIONS_SIDE or SIDE
end

function Slab.Rows(def, cfg)
	if Grouped(def) then
		local _, rows = Layouts().MedallionsGroup(K.Scale.Aspect())
		return Plain(rows) and rows or 1
	end
	if Sided(def) then
		return Slab.Side().rows
	end
	return cfg.rows
end

local function Share(def, cfg)
	local grid = Layouts().Grid and Layouts().Grid(def.element)
	if not (grid and Plain(grid.size) and grid.size > 0 and Plain(cfg.size)) then
		return nil
	end
	return cfg.size / grid.size
end

function Slab.Size(def, cfg)
	if not Grouped(def) then
		return cfg.size
	end
	local _, _, _, _, size = Layouts().MedallionsGroup(K.Scale.Aspect())
	local share = Share(def, cfg)
	if not (Plain(size) and share) then
		return cfg.size
	end
	return size * share
end

function Slab.Spacing(def, cfg)
	local gap
	if Grouped(def) then
		gap = select(6, Layouts().MedallionsGroup(K.Scale.Aspect()))
	elseif Sided(def) then
		gap = Slab.Side().gap
	end
	local share = Share(def, cfg)
	if not (Plain(gap) and share) then
		return cfg.spacing
	end
	return gap * share
end

function Slab.TextSize(key, cfg, size, text)
	local bar = ns.bars and ns.bars[key]
	if not (bar and Plain(cfg.size) and cfg.size > 0) then
		return size
	end
	if text == "hotkey" and K.HudStyle.Current() == STYLE then
		return KEYBIND * K.Theme.FontScale()
	end
	local fit = Slab.Size(bar.def, cfg) / cfg.size
	if not (Plain(fit) and fit < 1) then
		return size
	end
	if text == "cooldown" then
		return min(size, max(K.Scale.TEXT_FLOOR, size * fit * fit))
	end
	return max(TEXT_FLOOR, size * fit)
end

function Slab.TextFlags(text, flags)
	if text == "hotkey" and K.HudStyle.Current() == STYLE then
		return "OUTLINE"
	end
	return flags
end

local function Known(name)
	local ok, path = pcall(Tokens.Texture, name)
	if ok and path then
		return path
	end
	return nil
end

function Slab.Texture(name, fallback)
	return Known(name) or (Tokens.Texture(FALLBACK[fallback or name]))
end

local function ClassName()
	return CLASS_NAMES[state.class or ""]
end

local function ClassTexture(prefix)
	local class = ClassName()
	return class and Known(prefix .. class) or Slab.Texture(prefix)
end

local function Cells(name, default)
	if type(Tokens.Flipbook) ~= "function" then
		return default
	end
	local ok, rows, columns, frames, seconds = pcall(Tokens.Flipbook, name)
	if not ok or not (Plain(rows) and Plain(columns) and Plain(frames)) then
		return default
	end
	return { rows = rows, columns = columns, frames = frames, seconds = Plain(seconds) and seconds or default.seconds }
end

local function ClassRGB()
	local file = state.class
	if not file or IsSecret(file) then
		return Tokens.Color("text")
	end
	local r, g, b = K.Theme.ClassColor(file)
	if not (Plain(r) and Plain(g) and Plain(b)) then
		return Tokens.Color("text")
	end
	return r, g, b
end

local function Region(parent, layer, sublevel, path, additive)
	local t = parent:CreateTexture(nil, layer, nil, sublevel or 0)
	if path then
		t:SetTexture(path)
	end
	if additive then
		t:SetBlendMode("ADD")
	end
	return t
end

local function Group(region, looping)
	local g = region:CreateAnimationGroup()
	if looping then
		g:SetLooping(looping)
	end
	return g
end

local function Fade(g, from, to, duration, order, delay)
	local a = g:CreateAnimation("Alpha")
	a:SetFromAlpha(from)
	a:SetToAlpha(to)
	a:SetDuration(duration)
	a:SetOrder(order or 1)
	if delay then
		a:SetStartDelay(delay)
	end
	return a
end

local function Grow(g, from, to, duration, order)
	local s = g:CreateAnimation("Scale")
	s:SetScaleFrom(from, from)
	s:SetScaleTo(to, to)
	s:SetDuration(duration)
	s:SetOrder(order or 1)
	return s
end

local function Flipbook(g, cells, duration)
	local f = g:CreateAnimation("FlipBook")
	f:SetFlipBookRows(cells.rows)
	f:SetFlipBookColumns(cells.columns)
	f:SetFlipBookFrames(cells.frames)
	f:SetDuration(duration or cells.seconds)
	return f
end

local function Turn(region)
	local g = Group(region, "REPEAT")
	local r = g:CreateAnimation("Rotation")
	r:SetDegrees(-360)
	r:SetDuration(RUNE_TURN)
	return g
end

local LEVELS = { full = true, calm = true, off = true }

function Slab.Level()
	local effects = K.Effects
	if effects and type(effects.Level) == "function" then
		local ok, level = pcall(effects.Level)
		if ok and type(level) == "string" and not IsSecret(level) and LEVELS[level:lower()] then
			return level:lower()
		end
	end
	return Motion.Level() == "full" and "full" or "off"
end

local ALLOWED = { full = { ambient = true, flare = true, particle = true, pulse = true }, calm = { ambient = true, flare = true }, off = {} }

function Slab.Allows(kind)
	local effects = K.Effects
	if effects and type(effects.Allows) == "function" then
		local ok, on = pcall(effects.Allows, kind)
		if ok and type(on) == "boolean" then
			return on
		end
	end
	return ALLOWED[Slab.Level()][kind] == true
end

local function Moving()
	return Slab.Allows("flare")
end

local function Idling()
	return Slab.Allows("ambient")
end

local function Play(g, kind)
	if g and Slab.Allows(kind or "flare") then
		g:Stop()
		g:Play()
	end
end

local function Each(list, fn)
	for _, item in ipairs(list) do
		fn(item)
	end
end

local function BuildParticles(hub)
	local list = {}
	for i = 1, PARTICLES do
		local p = Region(hub.top, "OVERLAY", 2, nil, true)
		Widgets.Size(p, PARTICLE_SIZE, PARTICLE_SIZE)
		local angle = rad((i - 1) * 360 / PARTICLES + 18)
		local radius = CREST * (0.22 + 0.06 * (i % 3))
		p:SetPoint("CENTER", hub, "CENTER", Widgets.Snap(hub, cos(angle) * radius), Widgets.Snap(hub, sin(angle) * radius * 0.6))
		p:SetAlpha(0)
		local g = Group(p, "REPEAT")
		local run, delay = 2.4 + (i % 4) * 0.4, (i - 1) * 0.37
		local lift = g:CreateAnimation("Translation")
		lift:SetOffset(0, PARTICLE_RISE)
		lift:SetDuration(run)
		lift:SetStartDelay(delay)
		Fade(g, 0, 0.9, run * 0.3, 1, delay)
		Fade(g, 0.9, 0, run * 0.7, 1, delay + run * 0.3)
		p.cell = (i - 1) % PARTICLE_CELLS.frames
		p.anim = g
		list[i] = p
	end
	return list
end

local function Plate(parent)
	local plate = CreateFrame("Frame", nil, parent)
	plate:SetFrameStrata(STRATA)
	plate:Hide()
	local ok, slice = pcall(Widgets.NineSlice, plate, "medActionSlab", "BACKGROUND")
	if ok and slice then
		plate.slice = slice
	else
		local fill = pcall(Tokens.Color, "medFillBottom") and "medFillBottom" or "buttonFill"
		plate.chrome = Widgets.Chrome(plate, { shape = "tile", fill = fill, shadow = false })
	end
	return plate
end

local function LayPlate(plate)
	if plate.slice then
		local _, _, corner = Tokens.Texture("medActionSlab")
		Widgets.LayoutSlice(plate.slice, plate, corner or Slab.Spec().pad)
	else
		plate.chrome:Restyle()
	end
end

local function BuildSlab(root)
	local slab = Plate(root)
	slab.sweeps = {}
	for i = 1, 2 do
		local sweep = Region(slab, "OVERLAY", 0, Slab.Texture("medCombatSweep"), true)
		if i == 1 then
			sweep:SetTexCoord(1, 0, 0, 1)
		end
		Widgets.Size(sweep, SWEEP_W, SWEEP_H)
		sweep:SetAlpha(0)
		sweep.side = i == 1 and -1 or 1
		local g = Group(sweep)
		sweep.move = g:CreateAnimation("Translation")
		sweep.move:SetDuration(SWEEP_RUN)
		Fade(g, 0, 1, SWEEP_RUN * 0.25)
		Fade(g, 1, 0, SWEEP_RUN * 0.75, 1, SWEEP_RUN * 0.25)
		sweep.anim = g
		slab.sweeps[i] = sweep
	end
	slab.gap = CreateFrame("Frame", nil, slab)
	return slab
end

local function BuildRing(hub)
	local glow = Region(hub, "BACKGROUND", 0, Slab.Texture("glow", "medProc"), true)
	Widgets.Size(glow, RING * GLOW_SHARE, RING * GLOW_SHARE)
	glow:SetPoint("CENTER", hub, "CENTER", 0, 0)
	glow.breath = Group(glow, "BOUNCE")
	Fade(glow.breath, BREATH_LOW, BREATH_HIGH, BREATH / 2)
	hub.glow = glow

	local ring = Region(hub, "ARTWORK", 3, Slab.Texture("medRingLarge"))
	ring:SetAllPoints(hub)
	if not Known("medRingLarge") then
		Widgets.Tint(ring, "deep")
	end
	hub.ring = ring

	local glyphs = Region(hub, "ARTWORK", 4, Slab.Texture("medEnamelLarge"))
	glyphs:SetAllPoints(hub)
	glyphs:SetAlpha(GLYPH_REST)
	glyphs.flash = Group(glyphs)
	Fade(glyphs.flash, GLYPH_REST, 1, PULSE_RUN)
	Fade(glyphs.flash, 1, GLYPH_REST, PULSE_RUN, 2)
	hub.glyphs = glyphs

	local runes = Region(hub, "ARTWORK", 5, Slab.Texture("medRuneGlyphs"), true)
	runes:SetAllPoints(hub)
	runes:SetAlpha(RUNE_REST)
	runes.turn = Turn(runes)
	hub.runes = runes
end

local function OpeningMask(parent, hub)
	local mask = parent:CreateMaskTexture()
	mask:SetTexture((Tokens.Texture("orbMask")), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	Widgets.Size(mask, OPENING, OPENING)
	mask:SetPoint("CENTER", hub, "CENTER", 0, 0)
	return mask
end

local function SizeCrest(hub)
	local resolution = hub.crestPath == Slab.Texture("medCrest") and 256 or 512
	local texels = K.Scale.Pixel(resolution - 1)
	local crest, bloom = min(CREST, texels / PULSE_SCALE), min(CREST * BLOOM_SHARE, texels)
	Widgets.Size(hub.crest, crest, crest)
	Widgets.Size(hub.bloom, bloom, bloom)
end

local function BuildCrest(hub)
	local socket = Region(hub, "ARTWORK", -4, Slab.Texture("medHubSocket"))
	Widgets.Size(socket, OPENING, OPENING)
	socket:SetPoint("CENTER", hub, "CENTER", 0, 0)
	if not Known("medHubSocket") then
		Widgets.Tint(socket, "deep")
	end
	hub.socket = socket

	local mask = OpeningMask(hub, hub)
	local crest = Region(hub, "ARTWORK", 0)
	crest:SetPoint("CENTER", hub, "CENTER", 0, 0)
	crest:AddMaskTexture(mask)
	crest.pulse = Group(crest)
	Grow(crest.pulse, 1, PULSE_SCALE, PULSE_RUN)
	Grow(crest.pulse, PULSE_SCALE, 1, PULSE_RUN, 2)
	hub.crest = crest

	local bloom = Region(hub, "ARTWORK", 1, nil, true)
	bloom:SetPoint("CENTER", hub, "CENTER", 0, 0)
	bloom:AddMaskTexture(mask)
	bloom.breath = Group(bloom, "BOUNCE")
	Fade(bloom.breath, BREATH_LOW, BREATH_HIGH, BREATH / 2)
	hub.bloom = bloom
	SizeCrest(hub)

	local sheen = Region(hub, "OVERLAY", 0, Slab.Texture("medPortraitSheen"), true)
	Widgets.Size(sheen, SHEEN_W, OPENING)
	sheen:SetPoint("RIGHT", hub, "CENTER", Widgets.Snap(hub, -OPENING / 2), 0)
	sheen:AddMaskTexture(mask)
	sheen:SetAlpha(SHEEN_ALPHA)
	sheen.run = Group(sheen, "REPEAT")
	local pass = sheen.run:CreateAnimation("Translation")
	pass:SetOffset(OPENING + SHEEN_W, 0)
	pass:SetDuration(SHEEN_RUN)
	pass:SetStartDelay(SHEEN_EVERY - SHEEN_RUN)
	hub.sheen = sheen
end

local function BuildMoments(hub)
	local flash = Region(hub.top, "OVERLAY", 0, Slab.Texture("medReadyFlash"), true)
	Widgets.Size(flash, OPENING, OPENING)
	flash:SetPoint("CENTER", hub, "CENTER", 0, 0)
	flash:AddMaskTexture(OpeningMask(hub.top, hub))
	flash:SetAlpha(0)
	flash.anim = Group(flash)
	Fade(flash.anim, 0, 0.8, SHOCK_RUN * 0.3)
	Fade(flash.anim, 0.8, 0, SHOCK_RUN * 0.7, 2)
	hub.flash = flash

	local shock = Region(hub.top, "OVERLAY", 1, Slab.Texture("ring", "medProc"), true)
	Widgets.Size(shock, RING, RING)
	shock:SetPoint("CENTER", hub, "CENTER", 0, 0)
	shock:SetAlpha(0)
	shock.anim = Group(shock)
	Grow(shock.anim, 1, SHOCK_SCALE, SHOCK_RUN)
	Fade(shock.anim, 0.8, 0, SHOCK_RUN)
	hub.shock = shock

	local burst = Region(hub, "BACKGROUND", 1, Slab.Texture("medLevelUp"), true)
	Widgets.Size(burst, RING * BURST_SHARE, RING * BURST_SHARE)
	burst:SetPoint("CENTER", hub, "CENTER", 0, 0)
	burst:SetAlpha(0)
	burst.anim = Group(burst)
	if Known("medLevelUp") then
		Flipbook(burst.anim, Cells("medLevelUp", LEVEL_FLIP), BURST_RUN)
	else
		Grow(burst.anim, 0.6, 1.2, BURST_RUN)
	end
	Fade(burst.anim, 0, 1, BURST_RUN * 0.2)
	Fade(burst.anim, 1, 0, BURST_RUN * 0.8, 1, BURST_RUN * 0.2)
	burst.anim:SetScript("OnFinished", function(_, requested)
		if not requested then
			Slab.PaintPlaque(false)
		end
	end)
	burst.play = function()
		Play(burst.anim)
	end
	burst.stop = function()
		burst.anim:Stop()
		burst:SetAlpha(0)
		Slab.PaintPlaque(false)
	end
	hub.burst = burst

	local plaque = Region(hub.top, "OVERLAY", 3, Slab.Texture("medLevelPlaque"))
	Widgets.Size(plaque, BADGE, BADGE)
	plaque:SetPoint("CENTER", hub, "BOTTOM", 0, Widgets.Snap(hub, BADGE_RISE))
	hub.plaque = plaque
	local level = Widgets.Text(hub.top, "caption", "text")
	level:SetDrawLayer("OVERLAY", select(2, plaque:GetDrawLayer()) + 1)
	level:SetPoint("CENTER", plaque, "CENTER", 0, 0)
	level:SetJustifyH("CENTER")
	hub.level = level
	local caption = Widgets.Text(hub.top, "caps", "text")
	caption:SetPoint("BOTTOM", hub, "TOP", 0, Widgets.Snap(hub, 4))
	caption:SetAlpha(0)
	caption.anim = Group(caption)
	Fade(caption.anim, 0, 1, BURST_RUN * 0.2)
	Fade(caption.anim, 1, 0, BURST_RUN * 0.4, 1, BURST_RUN * 0.6)
	hub.caption = caption
end

local function Build()
	local root = K.Scale.Root()
	local slab = BuildSlab(root)
	local hub = CreateFrame("Frame", nil, root)
	hub:SetFrameStrata(STRATA)
	Widgets.Size(hub, RING, RING)
	hub:Hide()
	hub.top = CreateFrame("Frame", nil, hub)
	hub.top:SetAllPoints(hub)
	BuildRing(hub)
	BuildCrest(hub)
	hub.particles = BuildParticles(hub)
	BuildMoments(hub)
	Slab.frame, Slab.hub = slab, hub
	Slab.PaintPlaque(false)
	state.built = true
end

local function Loops()
	local hub = Slab.hub
	return { hub.glow.breath, hub.bloom.breath, hub.runes.turn, hub.sheen.run }
end

function Slab.PaintPlaque(gold)
	local hub = Slab.hub
	if not hub then
		return
	end
	if gold then
		Widgets.Tint(hub.plaque, "capsGold")
		hub.level:SetTextColor(Tokens.Color("capsGold"))
	else
		Widgets.Tint(hub.plaque, Known("medLevelPlaque") and "white" or "buttonFill")
		hub.level:SetTextColor(Tokens.Color("text"))
	end
end

local function PlayerLevel()
	local level = type(UnitLevel) == "function" and UnitLevel("player")
	if not Plain(level) then
		return nil
	end
	return level
end

local function PaintLevel(level)
	level = level or PlayerLevel()
	Slab.hub.level:SetText(level and tostring(level) or "")
end

local function Crest()
	local medallions = K.Medallions
	if medallions and type(medallions.Crest) == "function" then
		local ok, crest, glow = pcall(medallions.Crest, "player")
		if ok and crest and not IsSecret(crest) then
			return crest, not IsSecret(glow) and glow or nil
		end
	end
	return Slab.Texture("medCrest"), nil
end

local function PaintParticles(r, g, b)
	local path = ClassTexture("medParticle")
	local cells = ClassName() and Known("medParticle" .. ClassName()) and Cells("medParticle" .. ClassName(), PARTICLE_CELLS)
	for _, p in ipairs(Slab.hub.particles) do
		p:SetTexture(path)
		if cells then
			local col, row = p.cell % cells.columns, floor(p.cell / cells.columns) % cells.rows
			p:SetTexCoord(col / cells.columns, (col + 1) / cells.columns, row / cells.rows, (row + 1) / cells.rows)
		end
		if cells then
			local wr, wg, wb = Tokens.Color("white")
			p:SetVertexColor(wr, wg, wb, p:GetAlpha())
		else
			p:SetVertexColor(r, g, b, p:GetAlpha())
		end
	end
end

local function Paint()
	local hub = Slab.hub
	local crest, glow = Crest()
	hub.crest:SetTexture(crest)
	hub.crest:SetVertexColor(CREST_REST, CREST_REST, CREST_REST, 1)
	hub.crestPath = crest
	hub.bloom:SetTexture(glow or Slab.Texture("glow", "medProc"))
	local r, g, b = ClassRGB()
	for _, region in ipairs({ hub.glow, hub.bloom, hub.glyphs, hub.runes, hub.shock, hub.flash }) do
		region:SetVertexColor(r, g, b, region:GetAlpha())
	end
	for _, sweep in ipairs(Slab.frame.sweeps) do
		sweep:SetVertexColor(r, g, b, sweep:GetAlpha())
	end
	PaintParticles(r, g, b)
end

local function Motionless()
	local hub = Slab.hub
	Each(Loops(), function(g)
		g:Stop()
	end)
	Each(hub.particles, function(p)
		p.anim:Stop()
		p:SetAlpha(0)
	end)
	hub.glow:SetAlpha(BREATH_HIGH)
	hub.bloom:SetAlpha(BREATH_LOW)
end

local function Held()
	local effects = K.Effects
	return effects ~= nil and effects.Holder ~= nil and effects.Holder("hub") ~= nil
end

local function Animate()
	local hub = Slab.hub
	if not (Idling() and hub:IsShown()) then
		Motionless()
		return
	end
	local speed = state.combat and COMBAT_SPEED or 1
	local held = Held()
	for _, g in ipairs(Loops()) do
		g:SetAnimationSpeedMultiplier(speed)
		if not g:IsPlaying() and not (held and g == hub.sheen.run) then
			g:Play()
		end
	end
	local alive = (held or not Slab.Allows("particle")) and 0 or state.combat and PARTICLES or CALM_PARTICLES
	for i, p in ipairs(hub.particles) do
		if i <= alive then
			if not p.anim:IsPlaying() then
				p.anim:Play()
			end
		else
			p.anim:Stop()
			p:SetAlpha(0)
		end
	end
	hub.glow:SetAlpha(state.combat and min(1, BREATH_HIGH * COMBAT_GLOW) or BREATH_HIGH)
end

local function Edges(frame)
	local left, right, top, bottom = Widgets.Edges(frame)
	local s = frame:GetEffectiveScale()
	if not (Plain(left) and Plain(right) and Plain(top) and Plain(bottom) and Plain(s)) then
		return nil
	end
	return left * s, right * s, top * s, bottom * s
end

function Slab.Pair()
	local bars = ns.bars
	local left, right = bars and bars.bar1, bars and bars.bar2
	if not (left and right and left:Shown() and right:Shown()) or left.holderHidden or right.holderHidden then
		return nil
	end
	local l1, r1, t1, b1 = Edges(left.holder)
	local l2, r2, t2, b2 = Edges(right.holder)
	if not (l1 and l2) then
		return nil
	end
	local unit = K.Scale.Root():GetEffectiveScale()
	local slack = 2 * K.Scale.Pixel(1) * (Plain(unit) and unit or 1)
	if abs(b1 - b2) > slack or abs(t1 - t2) > slack or r1 >= l2 then
		return nil
	end
	return left, right, l2 - r1, l1, r2
end

local function Yield()
	local hub = Slab.hub
	hub.sheen.run:Pause()
	for _, p in ipairs(hub.particles) do
		p.anim:Pause()
	end
end

local function Hide()
	Slab.PlaceSides(false)
	if not state.built then
		return
	end
	Slab.frame:Hide()
	Slab.hub:Hide()
	if K.Effects and K.Effects.Ambient then
		K.Effects.Ambient("hub", nil, nil)
	end
	Motionless()
	ns.SlabEffects.UpdateCap()
end

local function PlaceSweeps(slab, half)
	local inset = Widgets.Snap(slab, Slab.Spec().pad)
	for _, sweep in ipairs(slab.sweeps) do
		sweep:ClearAllPoints()
		sweep:SetPoint(sweep.side < 0 and "RIGHT" or "LEFT", slab, "TOP", 0, -inset)
		sweep.move:SetOffset(sweep.side * max(0, half - SWEEP_W), 0)
	end
end

function Slab.Refresh()
	if not Slab.Active() then
		Hide()
		return false
	end
	local left, right, gapWidth, l1, r2 = Slab.Pair()
	if not left then
		Hide()
		return false
	end
	if not state.built then
		Build()
	end
	local slab, hub = Slab.frame, Slab.hub
	state.class = select(2, UnitClass("player"))
	local spec = Slab.Spec()
	local pad = Widgets.Snap(slab, spec.pad)
	slab:ClearAllPoints()
	slab:SetPoint("TOPLEFT", left.holder, "TOPLEFT", -pad, pad)
	slab:SetPoint("BOTTOMRIGHT", right.holder, "BOTTOMRIGHT", pad, -Widgets.Snap(slab, spec.stripGap + spec.strip + spec.bottom))
	LayPlate(slab)
	local gap = slab.gap
	gap:ClearAllPoints()
	gap:SetPoint("TOPLEFT", left.holder, "TOPRIGHT", 0, 0)
	gap:SetPoint("BOTTOMRIGHT", right.holder, "BOTTOMLEFT", 0, 0)
	local unit = K.Scale.Root():GetEffectiveScale()
	if not (Plain(unit) and unit > 0) then
		unit = 1
	end
	hub:SetScale(max(0.01, min(1, (gapWidth / unit - 2 * MARGIN) / RING)))
	hub:ClearAllPoints()
	hub:SetPoint("CENTER", gap, "TOP", 0, 0)
	slab:SetFrameLevel(K.Scale.Root():GetFrameLevel())
	hub:SetFrameLevel(slab:GetFrameLevel() + HUB_LIFT)
	hub.top:SetFrameLevel(hub:GetFrameLevel() + 2)
	local slabScale = slab:GetEffectiveScale()
	PlaceSweeps(slab, (r2 - l1) / 2 / (Plain(slabScale) and slabScale > 0 and slabScale or 1))
	Paint()
	SizeCrest(hub)
	PaintLevel()
	slab:Show()
	hub:Show()
	if K.Effects and K.Effects.Ambient then
		K.Effects.Ambient("hub", Animate, Yield)
	end
	Animate()
	Slab.PlaceSides(true)
	ns.SlabEffects.UpdateCap()
	return true
end

function Slab.SetCombat(on)
	on = on == true
	if state.combat == on then
		return
	end
	state.combat = on
	if not (state.built and Slab.hub:IsShown()) then
		return
	end
	if on and Moving() then
		local hub = Slab.hub
		Play(hub.shock.anim)
		Play(hub.flash.anim)
		Each(Slab.frame.sweeps, function(sweep)
			Play(sweep.anim)
		end)
	end
	Animate()
end

function Slab.InCombat()
	return state.combat
end

function Slab.Pulse()
	if not (state.built and Slab.hub:IsShown()) then
		return
	end
	Play(Slab.hub.crest.pulse)
	Play(Slab.hub.glyphs.flash)
end

function Slab.LevelUp(level)
	if not (state.built and Slab.hub:IsShown()) then
		return
	end
	local hub = Slab.hub
	level = Plain(level) and level or PlayerLevel()
	PaintLevel(level)
	if level then
		hub.caption:SetText(string.format(L["Level %d"], level))
	end
	if Moving() then
		Slab.PaintPlaque(true)
		ns.SlabEffects.LevelUp(hub, hub.burst.play, hub.burst.stop)
		Play(hub.caption.anim)
		Play(hub.shock.anim)
	end
end

local sides, SIDE_BARS = {}, { "pet", "stance" }

function Slab.PlaceSides(on)
	for _, key in ipairs(SIDE_BARS) do
		local bar = ns.bars and ns.bars[key]
		local plate = sides[key]
		if bar and on and not plate then
			plate = Plate(bar.header)
			sides[key] = plate
		end
		if plate then
			local shown = on and bar:Shown() and not bar.holderHidden
			if shown then
				local pad = Widgets.Snap(plate, Slab.Side().pad)
				local vertical = pad - (K.Scale.Aspect() == "16:9" and Widgets.Border(plate) or 0)
				plate:ClearAllPoints()
				plate:SetPoint("TOPLEFT", bar.holder, "TOPLEFT", -pad, vertical)
				plate:SetPoint("BOTTOMRIGHT", bar.holder, "BOTTOMRIGHT", pad, -vertical)
				LayPlate(plate)
			end
			plate:SetShown(shown)
		end
	end
	Slab.sides = sides
end

local function SocketMask()
	return Known("medSlotMask") or (Tokens.Texture("iconMask"))
end

local function ProcParts(b)
	if not b.medProc then
		local mask = b.overlay:CreateMaskTexture()
		mask:SetTexture(SocketMask(), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		mask:SetAllPoints(b.icon)
		local loop = Region(b.overlay, "OVERLAY", 6, nil, true)
		loop:SetAllPoints(b.icon)
		loop:AddMaskTexture(mask)
		loop:Hide()
		local start = Region(b.overlay, "OVERLAY", 7, Slab.Texture("medProcStart"), true)
		start:SetAllPoints(b.icon)
		start:AddMaskTexture(mask)
		start:SetAlpha(0)
		start.anim = Group(start)
		Grow(start.anim, 0.7, 1.1, PROC_START)
		Fade(start.anim, 1, 0, PROC_START)
		local edge = Region(b.overlay, "OVERLAY", 7, Slab.Texture("medSlotChecked"), true)
		edge:SetAllPoints(b)
		edge:Hide()
		b.medProc, b.medProcStart, b.medProcEdge = loop, start, edge
	end
	return b.medProc, b.medProcStart, b.medProcEdge
end

local function ProcLoop(loop)
	local path = ClassTexture("medProc")
	if loop.path == path then
		return
	end
	loop.path = path
	loop:SetTexture(path)
	if loop.anim then
		loop.anim:Stop()
	end
	loop.anim = Group(loop, "REPEAT")
	if ClassName() and path ~= Slab.Texture("medProc") then
		Flipbook(loop.anim, Cells("medProc" .. ClassName(), FLIP))
	else
		Fade(loop.anim, 0.5, 1, FLIP.seconds / 2)
		Fade(loop.anim, 1, 0.5, FLIP.seconds / 2, 2)
	end
end

function Slab.SetProc(b, on)
	if b.kind ~= "action" then
		return
	end
	ns.SlabEffects.SlotProc(b, on and Slab.Active())
	if b.lumenGlow then
		b.lumenGlow:SetShown(b.proc == true and not Slab.Active())
	end
	if not (on and Slab.Active()) then
		if b.medProc then
			b.medProc.anim:Stop()
			b.medProc:Hide()
			b.medProcStart.anim:Stop()
			b.medProcStart:SetAlpha(0)
			b.medProcEdge:Hide()
		end
		return
	end
	if b.procGlow then
		b.procGlow:Stop()
	end
	state.class = state.class or select(2, UnitClass("player"))
	local loop, start, edge = ProcParts(b)
	ProcLoop(loop)
	local r, g, bl = ClassRGB()
	if loop.path == Slab.Texture("medProc") then
		loop:SetVertexColor(r, g, bl, 1)
	else
		Widgets.Tint(loop, "white")
	end
	start:SetVertexColor(r, g, bl, start:GetAlpha())
	edge:SetVertexColor(r, g, bl, 1)
	edge:Show()
	loop:Show()
	if Slab.Allows("pulse") then
		loop.anim:Play()
	end
	Play(start.anim)
	Slab.Pulse()
	ns.SlabEffects.Proc(Slab.hub)
end

local function OnCombat(event)
	Slab.SetCombat(event == "PLAYER_REGEN_DISABLED")
end

local function OnLevel(_, level)
	Slab.LevelUp(not IsSecret(level) and level or nil)
end

local function SlotLayer(parent, layer, sublevel, name, owner)
	local t = parent:CreateTexture(nil, layer, nil, sublevel)
	t:SetTexture((Tokens.Texture(name)))
	t:SetAllPoints(owner)
	return t
end

local DRESSED = { action = true, pet = true, stance = true }

function Slab.Keybind(b, wanted)
	if wanted == nil then
		wanted = ns.Config(b.kbar.def.key).hotkey == true
	end
	b.hotkey:SetShown(wanted and not (b.hasAction == false and Slab.Active() and DRESSED[b.kind] == true))
end

local function Inset(b)
	local slot = Layouts().MEDALLIONS_SLOT
	if not (slot and Grouped(b.kbar.def)) then
		return ICON_INSET
	end
	local _, _, _, _, size = Layouts().MedallionsGroup(K.Scale.Aspect())
	return Plain(size) and ICON_INSET * size / slot.size or ICON_INSET
end

local function Socket(b, on)
	local inset = on and Inset(b) or nil
	if (b.medSocketOn == true) == on and b.opts.iconInset == inset then
		return
	end
	b.medSocketOn = on
	if not b.medCoords then
		b.medCoords = { b.icon:GetTexCoord() }
	end
	b.chrome:SetShown(not on)
	b.opts.iconInset = inset
	if on then
		b.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
	else
		b.icon:SetTexCoord(unpack(b.medCoords))
	end
	b.placedOffset = nil
	b:Paint()
end

function Slab.Dress(b)
	local on = Slab.Active() and DRESSED[b.kind] == true and Known("medSlot") ~= nil
	if not b.medFrame then
		if not on then
			return
		end
		b.medWell = b:CreateTexture(nil, "BACKGROUND", nil, 2)
		b.medWell:SetAllPoints(b)
		local well = Known("medSlotSocket")
		if well then
			b.medWell:SetTexture(well)
		else
			b.medWell:SetColorTexture(Tokens.Color("medSocket"))
		end
		b.medFrame = SlotLayer(b, "OVERLAY", 2, "medSlot", b)
		b.medChecked = SlotLayer(b, "OVERLAY", 3, "medSlotChecked", b)
		b.medChecked:SetBlendMode("ADD")
		b.medHover = b.hoverLayer and SlotLayer(b.hoverLayer, "OVERLAY", 2, "medSlotHighlight", b)
		if b.medHover then
			b.medHover:SetBlendMode("ADD")
		end
		b.medPushed = SlotLayer(b, "OVERLAY", 3, "medSlotPushed", b)
		if type(hooksecurefunc) == "function" then
			for _, method in ipairs({ "SetSelected", "AnimatePress" }) do
				if type(b[method]) == "function" then
					hooksecurefunc(b, method, Slab.Dress)
				end
			end
		end
	end
	Socket(b, on)
	b.medFrame:SetShown(on)
	b.medWell:SetShown(on)
	b.medChecked:SetShown(on and b.selected == true)
	if b.medHover then
		b.medHover:SetShown(on)
	end
	b.medPushed:SetShown(on and b.pressHeld == true)
	Slab.Keybind(b)
end

local function OnStyle()
	Slab.Refresh()
	for _, list in ipairs({ ns.actionButtons, ns.petButtons, ns.stanceButtons }) do
		for _, b in ipairs(list or {}) do
			Slab.Dress(b)
			Slab.SetProc(b, b.proc == true)
		end
	end
end

local function OnMotion()
	if state.built and Slab.hub:IsShown() then
		Animate()
	end
end

function Slab.Enable()
	state.combat = InCombatLockdown() == true
	K.Events.Register(OWNER, "PLAYER_REGEN_DISABLED", OnCombat)
	K.Events.Register(OWNER, "PLAYER_REGEN_ENABLED", OnCombat)
	K.Events.Register(OWNER, "PLAYER_LEVEL_UP", OnLevel)
	K.Events.Register(OWNER, "PLAYER_ENTERING_WORLD", OnStyle)
	K.Callbacks.Register("HudStyleChanged", OWNER, OnStyle)
	K.Callbacks.Register("SettingChanged", OWNER, OnMotion)
	if K.Effects then
		K.Callbacks.Register("EffectsLevelChanged", OWNER, OnMotion)
	end
	OnStyle()
end

function Slab.Disable()
	K.Events.UnregisterAll(OWNER)
	K.Callbacks.Unregister("HudStyleChanged", OWNER)
	K.Callbacks.Unregister("SettingChanged", OWNER)
	if K.Effects then
		K.Callbacks.Unregister("EffectsLevelChanged", OWNER)
	end
	Hide()
end
