-- SlabStorm.lua: the Medallions crest's storm orbs for shamans who know Lightning Shield: three ball-lightning orbs circle the emblem inside the rune ring, one per charge, over three steel studs, with a storm halo while the shield is up; Blizzard's aura slots light each orb and the halo from the aura's own charge count (an application bar per orb), so Lua never reads or compares a secret, and Lua's own count, read from the aura while it is readable and counted from the player's own casts while it is secret, only chooses where the flourishes play: a cast ignites the orbs, each spent charge throws a bolt from its orb, one charge left dims the halo and flickers the last orb, and the halo crackles out when the shield ends.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Effects = K.Widgets, K.Tokens, K.Effects
local sin, cos, rad = math.sin, math.cos, math.rad
local IsSecret = Widgets.IsSecret
local Medals = ns.SlabMedals
local Restricted, Steps = Medals.Restricted, Medals.Steps

local Storm = {}
ns.SlabStorm = Storm

local OWNER = "ActionBars.SlabStorm"
local RANKS = { 10432, 10431, 8134, 945, 905, 325, 324 }
local STRIKES = { [26363] = true, [26364] = true, [26365] = true, [26366] = true, [26367] = true, [26369] = true, [26370] = true }
local CHARGES, REST, CLOUDS, DIM = 3, { 30, 150, 270 }, { 0, 4, 8, 12 }, 0.5
local ORBIT, PERIOD, STEPS = 54, 9, 24
local ORB, STUD, WELL, PIN, HALO, BURST, FLARE, BOLT = 26, 12, 10, 4, 150, 160, 44, 64
local IGNITE = { { 0, 1, 0.05 }, { 1, 0, 0.4 } }
local STRIKE = { { 0, 1, 0.03 }, { 1, 0, 0.32 } }
local BLAST = { { 0, 0.4, 0.05 }, { 0.4, 0, 0.5 } }
local CRACKLE = { { 0.8, 0.2, 0.12 }, { 0.2, 0.7, 0.1 }, { 0.7, 0, 0.5 } }
local FLICKER = { { 1, 0.45, 0.06 }, { 0.45, 0.9, 0.05 }, { 0.9, 0.35, 0.07 }, { 0.35, 1, 0.08 } }
local SHIMMER = { { 1, 0.15, 0.13 }, { 0.15, 1, 0.13 } }

local CAST = {}
for _, id in ipairs(RANKS) do CAST[id] = true end
local SLOT = { candidateFilters = { includeSpellIDs = CAST } }

local state = { seats = {}, parts = {}, loops = {}, containers = {}, feeds = {}, flares = {} }
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
	return Medals.Known(RANKS) and hub or nil
end

local function Layer(parent, level, steps)
	local frame = Medals.Layer(parent, level)
	frame.play = Steps(frame, steps)
	frame.play:SetScript("OnFinished", function() frame:Hide() end)
	frame:Hide()
	state.flares[#state.flares + 1] = frame
	return frame
end

local function Fire(frame)
	frame.play:Stop()
	frame:Show()
	frame.play:Play()
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
	state.feeds[#state.feeds + 1] = { button = button, bar = bar, low = low, ease = ease }
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
	holder:Hide()
	local base = hub.top:GetFrameLevel() + 1
	holder:SetFrameLevel(base)
	local function add(part) state.parts[#state.parts + 1] = part return part end
	local ring = add(CreateFrame("Frame", nil, holder))
	ring:SetPoint("CENTER", hub, "CENTER", 0, 0)
	ring.units = HALO
	state.halo = Medals.Layer(holder, base)
	local halo = Slot(Container(state.halo), "halo", ring)
	state.crackle = Layer(ring, base + 1, CRACKLE)
	for k, cell in ipairs(CLOUDS) do
		state.loops[#state.loops + 1] = { button = halo, group = Medals.Flip(Medals.Cloud(halo, "medAmbientShaman", cell), "medAmbientShaman", 1 + (k - 1) / 3) }
		Medals.Cloud(state.crackle, "medAmbientShaman", cell)
	end
	state.blast = Layer(holder, base + 6, BLAST)
	add(Medals.Texture(state.blast, "ARTWORK", 0, "medBurstShaman", "white", BURST, "ADD"))
	for i, angle in ipairs(REST) do
		local pin = add(CreateFrame("Frame", nil, holder))
		pin:SetFrameLevel(base + 2)
		pin.units, pin.angle = ORB, angle
		add(Medals.Texture(pin, "BACKGROUND", 0, "dot", "medSocket", WELL))
		add(Medals.Texture(pin, "BORDER", 0, "ring", "gilt", STUD))
		add(Medals.Texture(pin, "BORDER", 1, "dot", "steel", PIN)):SetAlpha(0.6)
		local seat = CreateFrame("Frame", nil, pin)
		seat:SetAllPoints(pin)
		seat:SetFrameLevel(base + 3)
		local s = { frame = seat, pin = pin, orbit = Orbit(seat, angle) }
		local container = Container(seat)
		s.orb = select(2, Slot(container, "orb", seat, i - 1, "stormOrb", true))
		local spark, bar = Slot(container, "spark", seat, i - 1, "stormOrbSpark", false)
		state.loops[#state.loops + 1] = { button = spark, group = Steps(bar, SHIMMER, true) }
		s.ignite = Layer(seat, base + 6, IGNITE)
		add(Medals.Texture(s.ignite, "ARTWORK", 0, "glow", "jewelStormCore", FLARE, "ADD"))
		s.strike = add(Layer(holder, base + 6, STRIKE))
		s.strike.units, s.strike.angle = ORB, angle
		add(Medals.Texture(s.strike, "ARTWORK", 0, "glow", "jewelStormCore", FLARE, "ADD"))
		s.bolt = add(Medals.Texture(s.strike, "OVERLAY", 0, "stormBolt", "white", BOLT, "ADD"))
		state.seats[i] = s
	end
	ns.SlabHeat.Fed(Container(holder), "HELPFUL", SLOT, CHARGES, state.feeds)
	state.flicker = Steps(state.seats[1].frame, FLICKER, true)
	state.holder = holder
end

local function Seat(part, hub)
	local a = rad(part.angle)
	part:ClearAllPoints()
	part:SetPoint("CENTER", hub, "CENTER", Widgets.Snap(hub, ORBIT * sin(a)), Widgets.Snap(hub, ORBIT * cos(a)))
end

local function Place(hub)
	for _, part in ipairs(state.parts) do
		if part.angle then
			Seat(part, hub)
		end
		Medals.Even(part)
	end
	state.holder:Show()
end

local function Engine(on, loops, eased)
	if Restricted() then
		return
	end
	if state.eased ~= eased then
		local modes = Enum and Enum.StatusBarInterpolation or {}
		for _, f in ipairs(state.feeds) do
			f.button:SetApplicationBar(f.bar, {
				minApplications = f.low, maxApplications = f.low + 1,
				interpolation = f.ease and eased and (modes.ExponentialEaseOut or 1) or (modes.Immediate or 0),
			})
		end
		state.eased = eased
	end
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
	local moving, last = Effects.Allows("ambient") and state.count ~= 0, state.count == 1
	for _, s in ipairs(state.seats) do
		if not moving then
			s.orbit:Stop()
		elseif not s.orbit:IsPlaying() then
			s.orbit:Play()
			state.orbitAt = GetTime and GetTime()
		end
	end
	if moving and last then
		if not state.flicker:IsPlaying() then
			state.flicker:Play()
		end
	else
		state.flicker:Stop()
	end
	state.halo:SetAlpha(last and DIM or 1)
end

local function Count(n)
	if n ~= state.count then
		state.count = n
		Motion()
	end
end

local function Read()
	local read = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
	if not read or Restricted() then
		return nil
	end
	local aura = state.rank and read(state.rank)
	if not aura then
		for _, id in ipairs(RANKS) do
			aura = read(id)
			if aura then
				state.rank = id
				break
			end
		end
	end
	if not aura then
		return 0
	end
	local n = aura.applications
	if not IsSecret(n) and type(n) == "number" then
		return n
	end
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
	s.strike.angle = a
	Seat(s.strike, ns.Slab.hub)
	Fire(s.strike)
end

local function Spend(n)
	local was = state.count
	if was and n < was and Effects.Allows("flare") then
		if was - n == 1 then
			Strike(was)
		end
		if n == 0 then
			Fire(state.crackle)
		end
	end
	Count(n)
end

local function OnCast(_, _, _, spellID)
	if IsSecret(spellID) then
		return
	end
	if CAST[spellID] then
		if Effects.Allows("flare") then
			Fire(state.blast)
			for _, s in ipairs(state.seats) do
				Fire(s.ignite)
			end
		end
		Count(CHARGES)
	elseif STRIKES[spellID] and state.count and state.count > 0 and Restricted() then
		Spend(state.count - 1)
	end
end

local function OnAura()
	if state.count ~= 0 then
		local n = Read()
		if n then
			Spend(n)
		end
	end
end

local function Stop()
	if state.listening ~= false then
		K.Events.UnregisterAll(OWNER)
		K.Callbacks.Unregister("EffectsLevelChanged", OWNER)
		state.listening = false
	end
	state.count = nil
	if state.holder then
		for _, s in ipairs(state.seats) do
			s.orbit:Stop()
		end
		state.flicker:Stop()
		state.holder:Hide()
		Engine(false, state.looping, state.eased)
	end
end

function Storm.Update()
	local hub = Active()
	if not hub then
		return Stop()
	end
	if not (state.holder or state.failed) then
		if Restricted() then
			state.listening = nil
			K.Events.Register(OWNER, "ADDON_RESTRICTION_STATE_CHANGED", Storm.Update)
			return K.Events.Register(OWNER, "PLAYER_REGEN_ENABLED", Storm.Update)
		end
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
		K.Events.Register(OWNER, "ADDON_RESTRICTION_STATE_CHANGED", Storm.Update)
		K.Callbacks.Register("EffectsLevelChanged", OWNER, Storm.Update)
		state.listening = true
	end
	Place(hub)
	local flare = Effects.Allows("flare")
	Engine(true, Effects.Allows("ambient"), flare)
	if not flare then
		for _, f in ipairs(state.flares) do
			f.play:Stop()
			f:Hide()
		end
	end
	state.count = Read() or state.count
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
