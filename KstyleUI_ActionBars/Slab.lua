-- Slab.lua: Medallions action slabs, editable extra rows, crest hub, pet and stance plates, sockets and effects.
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
local MARGIN, HUB_LIFT = 4, 8
local SLAB = { pad = 9, stripGap = 3, strip = 3, bottom = 3 }
local SIDE = { rows = 2, gap = 4, pad = 6, clear = 12 }
local GLOW_SHARE, BLOOM_SHARE = 1.5, 1.08
local BADGE, BADGE_RISE = 18, 4
local CREST_REST = 1
local ICON_INSET, ICON_CROP, KEYBIND = 3, 0.08, 10
local PARTICLES, CALM_PARTICLES, PARTICLE_SIZE, PARTICLE_RISE = 10, 5, 7, 30
local RUNE_TURN, COMBAT_SPEED, REST_SPEED = 90, 2.25, 0.5
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

Slab.RING, Slab.MARGIN, Slab.STRATA, Slab.RUNE_TURN = RING, MARGIN, STRATA, RUNE_TURN

local state = { combat = false, built = false, class = nil, procs = {} }

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
	return (def.key == "bar1" or def.key == "bar2") and K.HudStyle.Current() == STYLE and ns.Config("slab") ~= false
end
Slab.Grouped = Grouped

function Slab.Side()
	return Layouts().MEDALLIONS_SIDE or SIDE
end

function Slab.Rows(def, cfg)
	if not Grouped(def) and cfg.rows ~= 0 then return cfg.rows end
	return select(2, Layouts().ActionBarGrid(K.Scale.Aspect(), def.element, cfg))
end

function Slab.Size(def, cfg)
	if not Grouped(def) then return cfg.size end
	return select(3, Layouts().ActionBarGrid(K.Scale.Aspect(), def.element, cfg))
end

function Slab.Spacing(def, cfg)
	if not Grouped(def) and cfg.spacing >= 0 then return cfg.spacing end
	return select(4, Layouts().ActionBarGrid(K.Scale.Aspect(), def.element, cfg))
end

function Slab.TextSize(key, cfg, size, text)
	local bar = ns.bars and ns.bars[key]
	if not (bar and Plain(cfg.size) and cfg.size > 0) then
		return size
	end
	if text == "hotkey" and K.HudStyle.Current() == STYLE then
		return (ns.Config("readableCountdown") and K.Scale.TEXT_FLOOR or KEYBIND) * K.Theme.FontScale()
	end
	local cell = Grouped(bar.def) and bar.buttons[1] and bar.buttons[1].opts.size or cfg.size
	if text == "cooldown" and ns.Config("readableCountdown") then
		return max(K.Scale.TEXT_FLOOR, cell * 0.42) * K.Theme.FontScale()
	end
	local fit = cell / cfg.size
	if not (Plain(fit) and fit < 1) then
		return size
	end
	if text == "cooldown" then
		return min(size, max(K.Scale.TEXT_FLOOR, size * fit * fit))
	end
	return max(ns.Config("readableCountdown") and K.Scale.TEXT_FLOOR or 9, size * fit)
end

function Slab.TextFlags(text, flags)
	if text == "cooldown" and ns.Config("readableCountdown") then return "OUTLINE" end
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

local CELLS = {}

local function Cells(name, default)
	if CELLS[name] then return CELLS[name] end
	if type(Tokens.Flipbook) ~= "function" then
		return default
	end
	local ok, rows, columns, frames, seconds = pcall(Tokens.Flipbook, name)
	if not ok or not (Plain(rows) and Plain(columns) and Plain(frames)) then
		return default
	end
	CELLS[name] = { rows = rows, columns = columns, frames = frames, seconds = Plain(seconds) and seconds or default.seconds }
	return CELLS[name]
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
	a:SetSmoothing(Slab.Ease(g, from, to))
	return a
end
Slab.Fade, Slab.Group = Fade, Group

function Slab.Ease(g, from, to)
	local loop = g:GetLooping()
	local s = Tokens.Smoothing
	return (loop == "REPEAT" or loop == "BOUNCE") and s.loop or to < from and s.exit or s.enter
end

function Slab.Flicker(target, alpha)
	local f, g = Tokens.Flicker, Group(target, "REPEAT")
	alpha = alpha or 1
	Fade(g, alpha, alpha * f.low, f.step, 1)
	Fade(g, alpha * f.low, alpha, f.step, 2)
	g.target, g.low = target, alpha * f.low
	return g
end

function Slab.Still(g)
	if not g.still then
		g.still = Group(g.target, "REPEAT")
		Fade(g.still, g.low, g.low, 1)
	end
	return g.still
end

function Slab.Warn(g, on)
	local move = on and K.Effects.Allows("pulse")
	local hold = on and not move and K.Effects.Allows("flare")
	if not move then
		g:Stop()
	elseif not g:IsPlaying() then
		g:Play()
	end
	if not hold then
		if g.still then g.still:Stop() end
	elseif not Slab.Still(g):IsPlaying() then
		g.still:Play()
	end
end

local function Grow(g, from, to, duration, order, smoothing)
	local s = g:CreateAnimation("Scale")
	s:SetScaleFrom(from, from)
	s:SetScaleTo(to, to)
	s:SetDuration(duration)
	s:SetOrder(order or 1)
	s:SetSmoothing(smoothing or Slab.Ease(g, from, to))
	return s
end
Slab.Grow = Grow

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
	local texels = K.Scale.Pixel(256 - 1)
	local canvas = ns.Config("seatedCrest") and 123 or CREST
	local crest, bloom = min(canvas, texels / PULSE_SCALE), min(canvas * BLOOM_SHARE, texels)
	Widgets.Size(hub.crest, crest, crest)
	Widgets.Size(hub.bloom, bloom, bloom)
	if hub.seat then
		hub.seat:SetShown(ns.Config("seatedCrest") == true)
		Widgets.ShowSlice(hub.seatRing, ns.Config("seatedCrest") == true)
	end
end

local function BuildCrest(hub)
	local socket = Region(hub, "ARTWORK", -4, Slab.Texture("medHubSocket"))
	Widgets.Size(socket, OPENING, OPENING)
	socket:SetPoint("CENTER", hub, "CENTER", 0, 0)
	if not Known("medHubSocket") then
		Widgets.Tint(socket, "deep")
	end
	hub.socket = socket
	local seat = Region(hub, "ARTWORK", -3)
	Widgets.Size(seat, OPENING, OPENING)
	seat:SetPoint("CENTER", hub, "CENTER", 0, 0)
	hub.seat = seat
	hub.seatRing = Widgets.NineSlice(hub, "ringLine32", "ARTWORK", -3)
	Widgets.ColorSlice(hub.seatRing, Tokens.Color("medSocketLip"))
	Widgets.LayoutSlice(hub.seatRing, seat, OPENING / 2, 0)

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
	hub:HookScript("OnHide", function()
		if K.Effects.StopModels then K.Effects.StopModels("hub") end
	end)
	BuildRing(hub)
	BuildCrest(hub)
	hub.particles = BuildParticles(hub)
	BuildMoments(hub)
	Slab.frame, Slab.hub = slab, hub
	K.Layout.Rest.Follow("actionbars.bar1", slab, hub)
	Slab.PaintPlaque(false)
	state.built = true
end

local function Loops()
	local hub = Slab.hub
	hub.loops = hub.loops or { hub.glow.breath, hub.bloom.breath, hub.runes.turn, hub.sheen.run }
	return hub.loops
end

local function SizeBadge(hub)
	local numbered = ns.Config("hubNumber") ~= false
	local scale = hub:GetScale()
	if not numbered then hub:SetScale(1) end
	Widgets.Size(hub.plaque, numbered and 20 or BADGE, numbered and 20 or BADGE)
	local path, size, flags = Tokens.Font(numbered and "number" or "caption")
	Widgets.ApplyFont(hub.level, path, numbered and 10 * K.Theme.FontScale() or size, flags)
	if not numbered then hub:SetScale(scale) end
	Widgets.StyleText(hub.caption)
end

function Slab.PaintPlaque(gold)
	local hub = Slab.hub
	if not hub then
		return
	end
	SizeBadge(hub)
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
	if cells then r, g, b = Tokens.Color("white") end
	local fresh = Slab.hub.particlePath ~= path
	Slab.hub.particlePath = path
	for _, p in ipairs(Slab.hub.particles) do
		if fresh then p:SetTexture(path) end
		if cells then
			local col, row = p.cell % cells.columns, floor(p.cell / cells.columns) % cells.rows
			p:SetTexCoord(col / cells.columns, (col + 1) / cells.columns, row / cells.rows, (row + 1) / cells.rows)
		end
		p:SetVertexColor(r, g, b, p:GetAlpha())
	end
end

local function Paint()
	local hub = Slab.hub
	local crest, glow = Crest()
	glow = glow or Slab.Texture("glow", "medProc")
	local r, g, b = ClassRGB()
	if hub.crestPath == crest and hub.bloomPath == glow and hub.r == r and hub.g == g and hub.b == b then
		return
	end
	if hub.crestPath ~= crest then hub.crest:SetTexture(crest) end
	hub.crest:SetVertexColor(CREST_REST, CREST_REST, CREST_REST, 1)
	if hub.bloomPath ~= glow then hub.bloom:SetTexture(glow) end
	hub.crestPath, hub.bloomPath, hub.r, hub.g, hub.b = crest, glow, r, g, b
	hub.tinted = hub.tinted or { hub.glow, hub.bloom, hub.glyphs, hub.runes, hub.shock, hub.flash }
	for _, region in ipairs(hub.tinted) do
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
		p:Hide()
	end)
	hub.sheen:Hide()
	hub.glow:SetAlpha(BREATH_HIGH)
	hub.bloom:SetAlpha(BREATH_LOW)
end

local function Held()
	local effects = K.Effects
	return effects ~= nil and effects.Holder ~= nil and effects.Holder("hub") ~= nil
end

local function Resting(held)
	local cfg = K.Store.Module("Medallions")
	if held or state.combat or next(state.procs) or cfg.restingCrest == false or cfg.ambient == false or not Slab.Allows("ambient") then
		return false
	end
	local target = UnitExists and UnitExists("target")
	return not IsSecret(target) and not target
end

function Slab.Resting()
	return state.rest == true
end

local function Animate()
	local hub = Slab.hub
	local held = Held()
	local rest = Resting(held)
	local changed = rest ~= state.rest
	state.rest = rest
	if changed then
		ns.SlabMedals.Rest()
	end
	if not (Slab.Allows("ambient") and K.Store.Module("Medallions").ambient ~= false and hub:IsShown()) then
		Motionless()
		return
	end
	local speed = state.combat and COMBAT_SPEED or rest and REST_SPEED or 1
	hub.sheen:Show()
	for _, g in ipairs(Loops()) do
		g:SetAnimationSpeedMultiplier(speed)
		if rest and g == hub.runes.turn then
			g:Pause()
		elseif rest and g == hub.sheen.run then
			if g:IsPlaying() then g:Finish() end
		elseif not (held and g == hub.sheen.run) then
			if g.IsPendingFinish and g:IsPendingFinish() then g:Stop() end
			if not g:IsPlaying() then g:Play() end
		end
	end
	local alive = (held or rest or not Slab.Allows("particle")) and 0 or state.combat and PARTICLES or CALM_PARTICLES
	for i, p in ipairs(hub.particles) do
		p:SetShown(i <= alive)
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
	hub.bloom:SetAlpha(1)
end

local function Wake()
	if state.built and Resting(Held()) ~= state.rest and Slab.hub:IsShown() then Animate() end
end

local function Edges(frame)
	local left, right, top, bottom = Widgets.Edges(frame)
	local s = frame:GetEffectiveScale()
	if not (Plain(left) and Plain(right) and Plain(top) and Plain(bottom) and Plain(s)) then
		return nil
	end
	return left * s, right * s, top * s, bottom * s
end

function Slab.Pair(cfg)
	local bars = ns.bars
	local left, right = bars and bars.bar1, bars and bars.bar2
	cfg = cfg or K.Store.Module("ActionBars")
	if not (left and right and ns.running and not ns.gamepad and cfg.bar1.enabled == true and cfg.bar2.enabled == true) or left.holderHidden or right.holderHidden or left.gateHidden or right.gateHidden then
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
	if ns.Travel then ns.Travel.Refresh() end
	if K.Effects and K.Effects.Ambient then
		K.Effects.Ambient("hub", nil, nil)
	end
	Motionless()
	ns.SlabEffects.UpdateCap()
	ns.SlabJewels.Update()
	ns.SlabHawks.Update()
	ns.SlabStorm.Update()
	ns.SlabTrackers.Update()
	ns.SlabTarget.Update()
	ns.SlabCrown.Update()
	ns.Totems.Update()
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
	local cfg = K.Store.Module("ActionBars")
	state.extra = cfg.extraBarsApplied ~= "off"
	if cfg.slab == false then
		Hide()
		Slab.PlaceSides(true, cfg)
		return false
	end
	local left, right, gapWidth, l1, r2 = Slab.Pair(cfg)
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
	local rise = 0
	Slab.joined = Slab.joined or {}
	for key in pairs(Slab.joined) do Slab.joined[key] = nil end
	if cfg.extraBarsApplied == "rows" then
		for i, key in ipairs({ "bar4", "bar5" }) do
			local bar, base = ns.bars[key], i == 1 and left or right
			if bar and bar:Shown() and not bar.holderHidden and not bar.gateHidden then
				local l, r, t, b = Edges(bar.holder)
				local bl, br, bt = Edges(base.holder)
				local _, _, _, spacing = Layouts().ActionBarGrid(K.Scale.Aspect(), base.def.element, nil, STYLE)
				local unit = K.Scale.Root():GetEffectiveScale()
				local slack = 2 * K.Scale.Pixel(1) * unit
				if l and abs(l - bl) <= slack and abs(r - br) <= slack and abs(b - bt - spacing * unit) <= slack then
					Slab.joined[key], rise = true, max(rise, (t - bt) / unit)
				end
			end
		end
	end
	slab:ClearAllPoints()
	slab:SetPoint("TOPLEFT", left.holder, "TOPLEFT", -pad, pad + Widgets.Snap(slab, rise))
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
	local lift = rise > 0 and (rise - left.holder:GetHeight() * Widgets.ScaleFactor(left.holder)) / 2 or 0
	hub:SetPoint("CENTER", gap, "TOP", 0, Widgets.Snap(hub, lift))
	slab:SetFrameLevel(K.Scale.Root():GetFrameLevel())
	hub:SetFrameLevel(slab:GetFrameLevel() + HUB_LIFT)
	hub.top:SetFrameLevel(hub:GetFrameLevel() + 2)
	local slabScale = slab:GetEffectiveScale()
	PlaceSweeps(slab, (r2 - l1) / 2 / (Plain(slabScale) and slabScale > 0 and slabScale or 1))
	Paint()
	SizeCrest(hub)
	PaintLevel()
	SizeBadge(hub)
	slab:Show()
	hub:Show()
	if K.Effects and K.Effects.Ambient then
		K.Effects.Ambient("hub", Animate, Yield)
	end
	Animate()
	Slab.PlaceSides(true, cfg)
	ns.SlabEffects.UpdateCap()
	ns.SlabJewels.Update()
	ns.SlabHawks.Update()
	ns.SlabStorm.Update()
	ns.SlabTrackers.Update()
	ns.SlabTarget.Update()
	ns.SlabCrown.Update()
	ns.Totems.Update()
	if ns.Travel then ns.Travel.Refresh() end
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

local sides, SIDE_BARS = {}, { "pet", "stance", "bar3", "bar4", "bar5" }

function Slab.PlaceSides(on, cfg)
	local active = Slab.Active()
	cfg = cfg or (on or active) and K.Store.Module("ActionBars")
	local extra = on and state.extra
	for _, key in ipairs(SIDE_BARS) do
		local bar = ns.bars and ns.bars[key]
		local plate = sides[key]
		local wanted = key == "bar3" and active and cfg.bar3.finished or key ~= "bar3" and on
		if key == "bar4" or key == "bar5" then
			wanted = extra and not (Slab.joined and Slab.joined[key] and Slab.frame:IsShown())
		end
		if bar and wanted and not plate then
			plate = Plate(bar.header)
			sides[key] = plate
		end
		if plate then
			local shown = wanted and bar:Shown() and not bar.holderHidden and not bar.gateHidden and not cfg[key].backing
			if shown then
				local action = key == "bar3" or key == "bar4" or key == "bar5"
				local pad = Widgets.Snap(plate, action and Slab.Spec().pad or Slab.Side().pad)
				local vertical = pad - (key ~= "bar4" and key ~= "bar5" and K.Scale.Aspect() == "16:9" and Widgets.Border(plate) or 0)
				plate:ClearAllPoints()
				plate:SetPoint("TOPLEFT", bar.holder, "TOPLEFT", bar.insetLeft - pad, vertical)
				plate:SetPoint("BOTTOMRIGHT", bar.holder, "BOTTOMRIGHT", pad - bar.insetRight, -vertical)
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
		local frame = CreateFrame("Frame", nil, b.overlay)
		frame:SetAllPoints(b)
		frame.body = CreateFrame("Frame", nil, frame)
		frame.body:SetAllPoints(frame)
		Widgets.ProcMotion(frame, frame.body)
		b.medProcFrame = frame
		local loop = Region(frame.body, "OVERLAY", 6, nil, true)
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
		local edge = Region(b.medProcFrame.body, "OVERLAY", 7, Slab.Texture("medSlotChecked"), true)
		edge:SetAllPoints(b)
		edge:Hide()
		b.medProc, b.medProcStart, b.medProcEdge = loop, start, edge
		b.medProcFrame.onProcHidden = function()
			loop.anim:Stop()
			loop:Hide()
			edge:Hide()
		end
	end
	return b.medProc, b.medProcStart, b.medProcEdge
end

local function ProcLoop(loop)
	local path = ClassTexture("medProc")
	local polished = ns.Config("procTransitions") == true
	if loop.path == path and loop.polished == polished then
		return
	end
	loop.path, loop.polished = path, polished
	loop:SetTexture(path)
	loop:SetTexCoord(0, 1, 0, 1)
	if loop.anim then
		loop.anim:Stop()
	end
	loop.anim = Group(loop, "REPEAT")
	if ClassName() and path ~= Slab.Texture("medProc") then
		Flipbook(loop.anim, Cells("medProc" .. ClassName(), FLIP), ns.Config("procTransitions") and 2 * Tokens.Duration("glowBreath") or nil)
	else
		Fade(loop.anim, 0.5, 1, FLIP.seconds / 2)
		Fade(loop.anim, 1, 0.5, FLIP.seconds / 2, 2)
	end
end

function Slab.SetProc(b, on, refresh)
	if b.kind ~= "action" then
		return
	end
	local active = Slab.Active()
	state.procs[b] = on and active or nil
	Wake()
	ns.SlabEffects.SlotProc(b, on and active)
	if b.lumenGlow then
		b.slabProc = active
		local glowing = b.proc == true and not active
		if b.opts.procTransitions then
			Widgets.ShowProc(b.lumenGlow, glowing, true, glowing and not K.Motion.ReducedMotion())
			if active then b.lumenGlow:Hide() end
		else
			b.lumenGlow:SetShown(glowing)
		end
	end
	if not (on and active) then
		if b.medProc then
			Widgets.ShowProc(b.medProcFrame, false, ns.Config("procTransitions") and active and Moving(), false)
			if not b.medProcFrame.leave:IsPlaying() then
				b.medProc.anim:Stop()
				b.medProc:Hide()
			end
			b.medProcStart.anim:Stop()
			b.medProcStart:SetAlpha(0)
			if not b.medProcFrame.leave:IsPlaying() then b.medProcEdge:Hide() end
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
	local polished = ns.Config("procTransitions") == true and Moving()
	local fresh = not b.medProcFrame.procShown
	Widgets.ShowProc(b.medProcFrame, true, polished, Slab.Allows("pulse"))
	if Slab.Allows("pulse") then
		if not loop.anim:IsPlaying() then
			loop:SetTexCoord(0, 1, 0, 1)
			loop.anim:Play()
		end
	else
		loop.anim:Stop()
		if not Moving() then start.anim:Stop() end
		if loop.path ~= Slab.Texture("medProc") then
			local cells = Cells("medProc" .. ClassName(), FLIP)
			loop:SetTexCoord(0, 1 / cells.columns, 0, 1 / cells.rows)
		end
	end
	if not refresh and (fresh or not polished) then
		Play(start.anim)
		local holder = K.Effects.Holder and K.Effects.Holder("hub")
		if not polished or not holder or holder >= K.Effects.PRIORITY.proc then Slab.Pulse() end
		ns.SlabEffects.Proc(Slab.hub)
	end
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

local DRESSED = { action = true, pet = true, stance = true, travel = true, totem = true, vehicle = true }

function Slab.Keybind(b, wanted)
	local cfg = K.Store.Module("ActionBars")
	if wanted == nil then
		wanted = b.kbar and cfg[b.kbar.def.key].hotkey == true or b.kind == "totem"
	end
	b.hotkey:SetShown(wanted and not (b.hasAction == false and Slab.Active() and DRESSED[b.kind] == true))
	b.hotkey:SetAlpha(cfg.readableCountdown and b.realCooldown and 0.6 or 1)
end

local function Inset(b)
	local slot = Layouts().MEDALLIONS_SLOT
	if state.extra and slot and b.kbar and (b.kbar.def.key == "bar4" or b.kbar.def.key == "bar5") then
		return ICON_INSET * b.opts.size / slot.size
	end
	if not (slot and b.kbar and Grouped(b.kbar.def)) then
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
	ns.PlaceTexts(b)
end

local function Press(b)
	if b.medSocketOn and b.pressHeld then
		b.medPushed.release:Stop()
		b.medPushed:SetAlpha(ns.Config("inputContinuity") and 0.6 or 1)
		b.medPushed:Show()
	elseif b.medSocketOn and ns.Config("inputContinuity") and Moving() and b.medPushed:IsShown() then
		if not b.medPushed.release:IsPlaying() then b.medPushed.release:Play() end
	else
		b.medPushed:Hide()
	end
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
		b.medPushed:Hide()
		b.medPushed.release = Group(b.medPushed)
		Fade(b.medPushed.release, 0.6, 0, 0.1):SetSmoothing("IN")
		b.medPushed.release:SetScript("OnFinished", function() b.medPushed:Hide() end)
		if type(hooksecurefunc) == "function" then
			hooksecurefunc(b, "SetSelected", Slab.Dress)
			hooksecurefunc(b, "AnimatePress", Press)
		end
	end
	if b.SetSlabDress then b:SetSlabDress(on) end
	Socket(b, on)
	if b.chrome.visible ~= (not on) then b.chrome:SetShown(not on) end
	b.medFrame:SetShown(on)
	b.medWell:SetShown(on)
	b.medChecked:SetShown(on and b.selected == true)
	if b.medHover then
		b.medHover:SetShown(on)
	end
	Press(b)
	Slab.Keybind(b)
end

local function OnStyle()
	Slab.Refresh()
	for _, list in ipairs({ ns.actionButtons, ns.petButtons, ns.stanceButtons, { ns.leaveButton } }) do
		for _, b in ipairs(list or {}) do
			Slab.Dress(b)
			Slab.SetProc(b, b.proc == true)
		end
	end
end

local function OnMotion(_, module, key)
	local restyle = module == "ActionBars" and (key == "procTransitions" or key == "inputContinuity")
	if restyle or module == nil then
		for _, list in ipairs({ ns.actionButtons, ns.petButtons, ns.stanceButtons }) do
			for _, b in ipairs(list or {}) do
				b.opts.procTransitions = ns.Config("procTransitions") == true
				b.opts.inputContinuity = ns.Config("inputContinuity") == true
				if restyle then b:Restyle() end
				Slab.Dress(b)
				Slab.SetProc(b, b.proc == true, true)
			end
		end
	end
	if state.built and Slab.hub:IsShown() then
		SizeBadge(Slab.hub)
		Animate()
	end
end

function Slab.Enable()
	state.combat = InCombatLockdown() == true
	K.Events.Register(OWNER, "PLAYER_REGEN_DISABLED", OnCombat)
	K.Events.Register(OWNER, "PLAYER_REGEN_ENABLED", OnCombat)
	K.Events.Register(OWNER, "PLAYER_LEVEL_UP", OnLevel)
	K.Events.Register(OWNER, "PLAYER_TARGET_CHANGED", Wake)
	K.Events.Register(OWNER, "PLAYER_ENTERING_WORLD", OnStyle)
	K.Callbacks.Register("HudStyleChanged", OWNER, OnStyle)
	K.Callbacks.Register("SettingChanged", OWNER, OnMotion)
	if K.Effects then
		K.Callbacks.Register("EffectsLevelChanged", OWNER, function() OnMotion() end)
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
