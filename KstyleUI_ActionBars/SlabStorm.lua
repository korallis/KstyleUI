-- SlabStorm.lua: the Medallions crest's storm orbs for shamans who know Lightning Shield: three ball-lightning orbs circle the emblem inside the rune ring, one per charge, over three steel studs, with a storm halo while the shield is up; Blizzard's aura slots light each orb and the halo from the aura's own charge count (an application bar per orb), so Lua never reads or compares a secret, and the player's own readable casts only choose where the flourishes play: a cast ignites the orbs, a strike throws a bolt from the spent orb, the last orb flickers and the halo crackles out.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Effects = K.Widgets, K.Tokens, K.Effects
local sin, cos, rad, floor = math.sin, math.cos, math.rad, math.floor
local IsSecret = Widgets.IsSecret
local Hawks = ns.SlabHawks

local Storm = {}
ns.SlabStorm = Storm

local OWNER = "ActionBars.SlabStorm"
local RANKS = { 10432, 10431, 8134, 945, 905, 325, 324 }
local STRIKES = { [26363] = true, [26364] = true, [26365] = true, [26366] = true, [26367] = true, [26369] = true, [26370] = true }
local CHARGES, REST, CLOUDS = 3, { 30, 150, 270 }, { 0, 4, 8, 12 }
local ORBIT, PERIOD, STEPS = 54, 9, 24
local ORB, STUD, WELL, PIN, HALO, BURST, FLARE, BOLT = 26, 12, 10, 4, 150, 160, 44, 64
local IGNITE = { { 0, 1, 0.05 }, { 1, 0, 0.4 } }
local STRIKE = { { 0, 1, 0.03 }, { 1, 0, 0.32 } }
local BLAST = { { 0, 0.4, 0.05 }, { 0.4, 0, 0.5 } }
local CRACKLE = { { 0.8, 0.2, 0.12 }, { 0.2, 0.7, 0.1 }, { 0.7, 0, 0.5 } }
local FLICKER = { { 1, 0.45, 0.06 }, { 0.45, 0.9, 0.05 }, { 0.9, 0.35, 0.07 }, { 0.35, 1, 0.08 } }
local SHIMMER = { { 1, 0.15, 0.13 }, { 0.15, 1, 0.13 } }

local CAST, IDS = {}, {}
for _, id in ipairs(RANKS) do
	CAST[id], IDS[id] = true, true
end
local SLOT = { candidateFilters = { includeSpellIDs = IDS } }

local state = { seats = {}, parts = {}, loops = {}, containers = {} }
Storm.state = state

local function Active()
	local hub = ns.Slab and ns.Slab.hub
	if not (state.enabled and hub and hub:IsShown() and ns.Config("crestStorm") ~= false and UnitClass) then
		return nil
	end
	local _, class = UnitClass("player")
	if IsSecret(class) or class ~= "SHAMAN" then
		return nil
	end
	return Hawks.Known(RANKS) and hub or nil
end

local function Restricted()
	local ask = C_Secrets and C_Secrets.ShouldAurasBeSecret
	local secret = ask and ask()
	return IsSecret(secret) or secret == true
end

local function Steps(target, steps, looping)
	local group = target:CreateAnimationGroup()
	for i, s in ipairs(steps) do
		local a = group:CreateAnimation("Alpha")
		a:SetFromAlpha(s[1])
		a:SetToAlpha(s[2])
		a:SetDuration(s[3])
		a:SetOrder(i)
	end
	if looping then
		group:SetLooping("REPEAT")
	end
	return group
end

local function Layer(parent, level, steps)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetAllPoints(parent)
	frame:SetFrameLevel(level)
	frame.play = Steps(frame, steps)
	frame.play:SetScript("OnFinished", function() frame:Hide() end)
	frame:Hide()
	return frame
end

local function Fire(frame)
	frame.play:Stop()
	frame:Show()
	frame.play:Play()
end

local function Cloud(parent, cell)
	local t = parent:CreateTexture(nil, "ARTWORK")
	t:SetTexture((Tokens.Texture("medAmbientShaman")))
	t:SetBlendMode("ADD")
	t:SetAllPoints(parent)
	local rows, columns = Tokens.Flipbook("medAmbientShaman")
	local x, y = cell % columns, floor(cell / columns)
	t:SetTexCoord(x / columns, (x + 1) / columns, y / rows, (y + 1) / rows)
	return t
end

local function Flip(texture, stretch)
	local rows, columns, frames, seconds = Tokens.Flipbook("medAmbientShaman")
	local group = texture:CreateAnimationGroup()
	group:SetLooping("REPEAT")
	local f = group:CreateAnimation("FlipBook")
	f:SetFlipBookRows(rows)
	f:SetFlipBookColumns(columns)
	f:SetFlipBookFrames(frames)
	f:SetDuration(seconds * stretch)
	return group
end

local function Container(parent)
	local container = CreateFrame("AuraContainer", nil, parent, "CustomAuraContainerTemplate")
	Widgets.KeepOut(container)
	container:SetUnit("player")
	state.containers[#state.containers + 1] = container
	return container
end

local function Slot(container, key, anchor, low, art, ease)
	local button = container:AddAuraSlot(key, "HELPFUL", SLOT)
	pcall(button.EnableMouse, button, false)
	button:SetAllPoints(anchor)
	if not art then
		return button
	end
	local bar = CreateFrame("StatusBar", nil, button)
	bar:SetAllPoints(button)
	bar:SetStatusBarTexture((Tokens.Texture(art)))
	bar:SetOrientation("VERTICAL")
	bar:GetStatusBarTexture():SetBlendMode("ADD")
	local modes = Enum and Enum.StatusBarInterpolation or {}
	button:SetApplicationBar(bar, {
		minApplications = low, maxApplications = low + 1,
		interpolation = ease and (modes.ExponentialEaseOut or 1) or (modes.Immediate or 0),
	})
	return button, bar
end

local function Orbit(seat, angle)
	local group = seat:CreateAnimationGroup()
	group:SetLooping("REPEAT")
	for k = 1, STEPS do
		local a, b = rad(angle + (k - 1) * 360 / STEPS), rad(angle + k * 360 / STEPS)
		local t = group:CreateAnimation("Translation")
		t:SetOffset(ORBIT * (sin(b) - sin(a)), ORBIT * (cos(b) - cos(a)))
		t:SetDuration(PERIOD / STEPS)
		t:SetOrder(k)
	end
	return group
end

local function Build(hub)
	local holder = CreateFrame("Frame", nil, hub.top)
	holder:SetAllPoints(hub)
	local base = hub.top:GetFrameLevel() + 1
	holder:SetFrameLevel(base)
	state.holder = holder
	local function add(part) state.parts[#state.parts + 1] = part return part end
	local ring = add(CreateFrame("Frame", nil, holder))
	ring:SetPoint("CENTER", hub, "CENTER", 0, 0)
	ring.units = HALO
	local halo = Slot(Container(holder), "halo", ring)
	state.crackle = Layer(ring, base + 1, CRACKLE)
	for k, cell in ipairs(CLOUDS) do
		state.loops[#state.loops + 1] = { button = halo, group = Flip(Cloud(halo, cell), 1 + (k - 1) / 3) }
		Cloud(state.crackle, cell)
	end
	state.blast = Layer(holder, base + 6, BLAST)
	add(Hawks.Texture(state.blast, "ARTWORK", 0, "medBurstShaman", "white", BURST, "ADD"))
	for i, angle in ipairs(REST) do
		local pin = add(CreateFrame("Frame", nil, holder))
		pin:SetFrameLevel(base + 2)
		pin.units, pin.angle = ORB, angle
		add(Hawks.Texture(pin, "BACKGROUND", 0, "dot", "medSocket", WELL))
		add(Hawks.Texture(pin, "BORDER", 0, "ring", "gilt", STUD))
		add(Hawks.Texture(pin, "BORDER", 1, "dot", "steel", PIN)):SetAlpha(0.6)
		local seat = CreateFrame("Frame", nil, pin)
		seat:SetAllPoints(pin)
		seat:SetFrameLevel(base + 3)
		local s = { frame = seat, pin = pin, orbit = Orbit(seat, angle) }
		local container = Container(seat)
		s.orb = select(2, Slot(container, "orb", seat, i - 1, "stormOrb", true))
		local spark, bar = Slot(container, "spark", seat, i - 1, "stormOrbSpark", false)
		state.loops[#state.loops + 1] = { button = spark, group = Steps(bar, SHIMMER, true) }
		s.ignite = Layer(seat, base + 6, IGNITE)
		add(Hawks.Texture(s.ignite, "ARTWORK", 0, "glow", "jewelStormCore", FLARE, "ADD"))
		s.strike = Layer(seat, base + 6, STRIKE)
		add(Hawks.Texture(s.strike, "ARTWORK", 0, "glow", "jewelStormCore", FLARE, "ADD"))
		s.bolt = add(Hawks.Texture(s.strike, "OVERLAY", 0, "stormBolt", "white", BOLT, "ADD"))
		state.seats[i] = s
	end
	state.flicker = Steps(state.seats[1].frame, FLICKER, true)
end

local function Place(hub)
	for _, part in ipairs(state.parts) do
		if part.angle then
			local a = rad(part.angle)
			part:ClearAllPoints()
			part:SetPoint("CENTER", hub, "CENTER", Widgets.Snap(hub, ORBIT * sin(a)), Widgets.Snap(hub, ORBIT * cos(a)))
		end
		Hawks.Even(part)
	end
	state.holder:Show()
end

local function Engine(on, loops)
	if Restricted() then
		state.pending = true
		return
	end
	state.pending = nil
	if state.looping ~= loops then
		for _, loop in ipairs(state.loops) do
			if loops then
				loop.button:AddAuraShownAnimation(loop.group)
			else
				loop.button:RemoveAuraShownAnimation(loop.group)
				loop.group:Stop()
			end
		end
		state.looping, state.fed = loops, nil
	end
	if state.fed ~= on then
		for _, container in ipairs(state.containers) do
			if state.fed == nil then
				container:SetEnabled(false)
			end
			container:SetEnabled(on)
		end
		state.fed = on
	end
end

local function Motion()
	local moving = Effects.Allows("ambient") and state.count ~= 0
	for _, s in ipairs(state.seats) do
		if not moving then
			s.orbit:Stop()
		elseif not s.orbit:IsPlaying() then
			s.orbit:Play()
			state.orbitAt = GetTime and GetTime()
		end
	end
	if moving and state.count == 1 then
		if not state.flicker:IsPlaying() then
			state.flicker:Play()
		end
	else
		state.flicker:Stop()
	end
end

local function Count(n)
	state.count = n
	Motion()
end

local function Sync()
	local read = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
	if not read or Restricted() then
		return
	end
	for _, id in ipairs(RANKS) do
		local aura = read(id)
		if aura then
			local n = aura.applications
			if not IsSecret(n) and type(n) == "number" then
				Count(n)
			end
			return
		end
	end
	Count(0)
end

local function Strike(i)
	local s = state.seats[i]
	if not s then
		return
	end
	local a = REST[i]
	if s.orbit:IsPlaying() and state.orbitAt and GetTime then
		a = a + 360 * ((GetTime() - state.orbitAt) / PERIOD % 1)
	end
	a = a % 360
	local aim = (a >= 120 and a <= 240) and a or (a < 180 and 100 or 260)
	s.bolt:SetRotation(rad(90 - aim))
	Fire(s.strike)
end

local function OnCast(_, _, _, spellID)
	if IsSecret(spellID) then
		return
	end
	local flare = Effects.Allows("flare")
	if CAST[spellID] then
		if flare then
			Fire(state.blast)
			for _, s in ipairs(state.seats) do
				Fire(s.ignite)
			end
		end
		Count(CHARGES)
	elseif STRIKES[spellID] and state.count and state.count > 0 then
		local i = state.count
		if flare then
			Strike(i)
			if i == 1 then
				Fire(state.crackle)
			end
		end
		Count(i - 1)
	end
end

local function OnAura()
	if state.count ~= 0 then
		Sync()
	end
end

local function Stop()
	if state.listening then
		K.Events.UnregisterAll(OWNER)
		K.Callbacks.Unregister("EffectsLevelChanged", OWNER)
		state.listening = false
	end
	if state.holder then
		for _, s in ipairs(state.seats) do
			s.orbit:Stop()
		end
		state.flicker:Stop()
		state.holder:Hide()
		Engine(false, state.looping)
	end
end

function Storm.Update()
	local hub = Active()
	if not hub then
		return Stop()
	end
	if not (state.holder or state.failed) then
		local ok, err = pcall(Build, hub)
		if not ok then
			state.failed = true
			K.DevTest.Log("ActionBars", "Lightning Shield orbs unavailable: " .. tostring(err))
		end
	end
	if state.failed then
		return Stop()
	end
	if not state.listening then
		K.Events.RegisterUnit(OWNER, "UNIT_SPELLCAST_SUCCEEDED", OnCast, "player")
		K.Events.RegisterUnit(OWNER, "UNIT_AURA", OnAura, "player")
		K.Events.Register(OWNER, "PLAYER_REGEN_ENABLED", Storm.Update)
		K.Callbacks.Register("EffectsLevelChanged", OWNER, Storm.Update)
		state.listening = true
	end
	Place(hub)
	Engine(true, Effects.Allows("ambient"))
	Sync()
	Motion()
end

function Storm.Recheck()
	if (Active() ~= nil) ~= (state.listening == true) then
		Storm.Update()
	end
end

function Storm.SetEnabled(on)
	state.enabled = on
	Storm.Update()
end
