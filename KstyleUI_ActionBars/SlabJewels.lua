-- SlabJewels.lua: the Medallions hub's resource jewels: up to ten cut gems in gilt settings across the top arc of the rune ring, lit one per combo point (rogue, cat-form druid), holy power (paladin) or soul shard (warlock), igniting on a gain and draining on a spend, with the whole rune ring glowing in the resource's colour at the maximum; every lit layer is a one-point status bar fed the raw value, now or the value before, so the engine compares and Lua never reads a secret.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Effects = K.Widgets, K.Tokens, K.Effects
local cos, sin, rad, max = math.cos, math.sin, math.rad, math.max
local IsSecret = Widgets.IsSecret

local Jewels = {}
ns.SlabJewels = Jewels

local OWNER = "ActionBars.SlabJewels"
local DEFAULT_COUNT, MAX_COUNT = 5, 10
local RADIUS, STEP, ARC = 62, 30, 120
local SETTING, LIP, GEM, BODY, CORE, GLINT, HALO = 12, 10, 8, 6, 3, 2, 20
local ALPHA, RING_HALO, GLINT_AT = 0.9, 1.6, 1
local FLARE_RISE, FLARE_FALL, DRAIN, FADE = 0.03, 0.09, 0.18, 0.2
local KINDS = {
	combo = { power = "ComboPoints", token = "COMBO_POINTS", color = "jewelCombo", rim = "jewelComboRim", core = "jewelComboCore" },
	holy = { power = "HolyPower", token = "HOLY_POWER", color = "jewelHoly", rim = "jewelHolyRim", core = "jewelHolyCore" },
	shard = { power = "SoulShards", token = "SOUL_SHARDS", color = "jewelShard", rim = "jewelShardRim", core = "jewelShardCore" },
}
local CLASS_KIND = { ROGUE = "combo", DRUID = "combo", PALADIN = "holy", WARLOCK = "shard" }
local POWER_IDS = { Energy = 3, ComboPoints = 4, SoulShards = 7, HolyPower = 9 }
local NOW = { "halo", "rim", "gem", "flare", "core", "glint" }
local FEEDS = {
	{ known = { 20049, 20056, 20057, 20058, 20059 }, spells = { 20050 } },
	{ known = { 20925, 20927, 20928, 1239570 }, spells = { 20925, 20927, 20928, 1239570 } },
	{ known = { 20177, 20179, 20180, 20181, 20182 }, spells = { 1326084 } },
}
local FED = { halo = true, rim = true, gem = true, core = true, glint = true }

local state = { jewels = {}, count = 0, sets = {} }
Jewels.state = state

local function PowerType(name)
	local types = Enum and Enum.PowerType
	return types and types[name] or POWER_IDS[name]
end

local function Class()
	local hub = ns.Slab and ns.Slab.hub
	if not (state.enabled and hub and hub:IsShown() and ns.Config("crestJewels") ~= false and UnitClass) then
		return nil
	end
	local _, class = UnitClass("player")
	return not IsSecret(class) and CLASS_KIND[class] and class or nil
end

local function Fed(class)
	if class ~= "PALADIN" or ns.Config("crestVengeance") == false then
		return nil
	end
	for _, feed in ipairs(FEEDS) do
		if ns.SlabMedals.Known(feed.known) then
			return feed
		end
	end
end

local function Kind(class)
	if class ~= "DRUID" then
		return CLASS_KIND[class]
	end
	local current = UnitPowerType and UnitPowerType("player")
	if not IsSecret(current) and current == PowerType("Energy") then
		return "combo"
	end
end

local function Count(kind)
	local most = UnitPowerMax and UnitPowerMax("player", PowerType(KINDS[kind].power))
	if IsSecret(most) or type(most) ~= "number" then
		return DEFAULT_COUNT
	end
	return math.max(0, math.min(MAX_COUNT, math.floor(most)))
end
Jewels.Count = Count

local Even = ns.SlabMedals.Even

local function Fade(target, from, to, duration, delay, order)
	local group = target.fade or target:CreateAnimationGroup()
	local a = group:CreateAnimation("Alpha")
	a:SetFromAlpha(from)
	a:SetToAlpha(to)
	a:SetDuration(duration)
	a:SetStartDelay(delay or 0)
	a:SetOrder(order or 1)
	target.fade = group
	return group
end

local function Fleeting(target)
	target:SetAlpha(0)
	target:Hide()
	target.fleeting = true
	target.fade:SetScript("OnFinished", function()
		target:Hide()
	end)
end

local function Texture(parent, size, sublevel, texture, color)
	return ns.SlabMedals.Texture(parent, "ARTWORK", sublevel, texture, color, size)
end

local function OnePoint(parent, i, size, texture, level, additive, key)
	local slot = parent.slots and FED[key] and parent.slots:AddAuraSlot(key .. i, "HELPFUL", parent.options)
	if slot then
		pcall(slot.EnableMouse, slot, false)
		slot:SetAllPoints(parent)
		slot:SetFrameLevel(level)
	end
	local bar = CreateFrame("StatusBar", nil, slot or parent)
	bar:SetFrameLevel(level)
	bar:SetStatusBarTexture((Effects.Texture(texture, "glow")))
	if additive then
		bar:GetStatusBarTexture():SetBlendMode("ADD")
	end
	bar:SetMinMaxValues(i - 1, i)
	bar:SetValue(0)
	bar:SetPoint("CENTER", parent, "CENTER", 0, 0)
	bar.units = size
	if slot then
		slot:SetApplicationBar(bar, { minApplications = i - 1, maxApplications = i })
	end
	return bar
end

local function Build(hub, i, feed)
	local holder = CreateFrame("Frame", nil, hub.top)
	holder.units = SETTING
	if feed then
		holder.slots = feed.container
		holder.options = feed.options
	end
	local base = hub.top:GetFrameLevel() + 1
	holder:SetFrameLevel(base + 1)
	local jewel = { holder = holder }
	jewel.halo = OnePoint(holder, i, HALO, "glow", base, true, "halo")
	jewel.haloWas = OnePoint(holder, i, HALO, "glow", base, true, "haloWas")
	jewel.setting = {
		Texture(holder, SETTING, 0, "diamond", "gilt"),
		Texture(holder, LIP, 1, "diamond", "jewelSetting"),
		Texture(holder, GEM, 2, "forgedDiamond", "jewelSocket"),
	}
	jewel.setting[3]:SetTexCoord(1, 0, 0, 1)
	jewel.rim = OnePoint(holder, i, GEM, "diamond", base + 2, nil, "rim")
	jewel.gem = OnePoint(holder, i, BODY, "diamond", base + 3, nil, "gem")
	jewel.flare = OnePoint(holder, i, BODY, "diamond", base + 4, true, "flare")
	jewel.ember = OnePoint(holder, i, BODY, "diamond", base + 5, nil, "ember")
	jewel.core = OnePoint(holder, i, CORE, "diamond", base + 6, nil, "core")
	jewel.glint = OnePoint(holder, i, GLINT, "diamond", base + 6, true, "glint")
	for _, key in ipairs({ "halo", "core", "glint" }) do
		jewel[key]:SetAlpha(ALPHA)
	end
	Fade(jewel.halo, 0, ALPHA, FADE)
	Fade(jewel.haloWas, ALPHA, 0, FADE)
	Fade(jewel.flare, 0, 1, FLARE_RISE)
	Fade(jewel.flare, 1, 0, FLARE_FALL, 0, 2)
	Fade(jewel.ember, 1, 1, FLARE_RISE + FLARE_FALL)
	Fade(jewel.ember, 1, 0, DRAIN, 0, 2)
	for _, key in ipairs({ "haloWas", "flare", "ember" }) do
		Fleeting(jewel[key])
	end
	jewel.fades = { jewel.halo.fade, jewel.haloWas.fade, jewel.flare.fade, jewel.ember.fade }
	return jewel
end

local function BuildRing(hub)
	local ring = CreateFrame("Frame", nil, hub)
	ring:SetAllPoints(hub)
	local Fx = ns.SlabEffects
	ring.breath = ring:CreateAnimationGroup()
	ring.breath:SetLooping("BOUNCE")
	local a = ring.breath:CreateAnimation("Alpha")
	a:SetFromAlpha(1)
	a:SetToAlpha(Fx.CAP_LOW)
	a:SetDuration(Fx.CAP_BREATH)
	a:SetSmoothing("IN_OUT")
	for _, side in ipairs({ "now", "was" }) do
		local frame = CreateFrame("Frame", nil, ring)
		frame:SetAllPoints(ring)
		frame.glyphs = OnePoint(frame, 1, ns.Slab.RING, "medRuneGlyphs", 0, true)
		frame.halo = OnePoint(frame, 1, ns.Slab.RING * RING_HALO, "glow", 0, true)
		ring[side] = frame
	end
	Fade(ring.now, 0, 1, FADE)
	Fade(ring.was, 1, 0, FADE)
	Fleeting(ring.was)
	state.ring = ring
	return ring
end

local function Place(hub, count, feed)
	local set = feed or "power"
	for key, jewels in pairs(state.sets) do
		if key ~= set then
			for _, jewel in ipairs(jewels) do
				jewel.holder:Hide()
			end
		end
	end
	state.sets[set] = state.sets[set] or {}
	state.jewels = state.sets[set]
	local mid, step = (count + 1) / 2, count > 5 and ARC / (count - 1) or STEP
	for i = 1, math.max(count, #state.jewels) do
		local jewel = state.jewels[i]
		if i <= count then
			jewel = jewel or Build(hub, i, feed)
			state.jewels[i] = jewel
			local a = rad(90 + (mid - i) * step)
			local holder = jewel.holder
			holder:ClearAllPoints()
			holder:SetPoint("CENTER", hub, "CENTER", Widgets.Snap(hub, RADIUS * cos(a)), Widgets.Snap(hub, RADIUS * sin(a)))
			Even(holder)
			for _, t in ipairs(jewel.setting) do
				Even(t)
			end
			for _, key in ipairs({ "halo", "haloWas", "rim", "gem", "flare", "ember", "core", "glint" }) do
				Even(jewel[key])
			end
			local glint = Widgets.Snap(holder, GLINT_AT)
			jewel.glint:SetPoint("CENTER", holder, "CENTER", -glint, glint)
			holder:Show()
		else
			jewel.holder:Hide()
		end
	end
	state.count = count
	local ring = state.ring
	local glow = count > 0 and ns.Config("crestJewelGlow") ~= false and not feed
	if glow and not ring then
		ring = BuildRing(hub)
	end
	if ring then
		local under = max(0, hub:GetFrameLevel() - 1)
		ring:SetFrameLevel(under)
		for _, side in ipairs({ ring.now, ring.was }) do
			side:SetFrameLevel(under)
			side.glyphs:SetFrameLevel(hub:GetFrameLevel() + 1)
			side.halo:SetFrameLevel(under)
			for _, bar in ipairs({ side.glyphs, side.halo }) do
				bar:SetMinMaxValues(count - 1, count)
				Widgets.Size(bar, bar.units, bar.units)
			end
		end
		ring:SetShown(glow)
		if glow and Effects.Allows("pulse") then
			if not ring.breath:IsPlaying() then
				ring.breath:Play()
			end
		else
			ring.breath:Stop()
		end
	end
end

local function Paint(kind)
	local def = KINDS[kind]
	local r, g, b = Tokens.Color(def.color)
	local rr, rg, rb = Tokens.Color(def.rim)
	local cr, cg, cb = Tokens.Color(def.core)
	for _, jewel in ipairs(state.jewels) do
		for _, key in ipairs({ "gem", "ember", "halo", "haloWas" }) do
			jewel[key]:SetStatusBarColor(r, g, b)
		end
		jewel.rim:SetStatusBarColor(rr, rg, rb)
		jewel.core:SetStatusBarColor(cr, cg, cb)
		jewel.flare:SetStatusBarColor(cr, cg, cb)
		jewel.glint:SetStatusBarColor(Tokens.Color("white"))
	end
	local ring = state.ring
	if ring then
		for _, side in ipairs({ ring.now, ring.was }) do
			side.glyphs:SetStatusBarColor(r, g, b)
			side.halo:SetStatusBarColor(r, g, b)
		end
	end
end

local function Restart(group, moving)
	group:Stop()
	local target = group:GetParent()
	if target.fleeting then
		target:SetShown(moving)
	end
	if moving then
		group:Play()
	end
end

local function Points(event)
	local kind = state.kind
	if not kind or state.count == 0 or state.feed then
		return
	end
	local points
	if kind == "combo" and GetComboPoints then
		points = GetComboPoints("player", "target")
	elseif UnitPower then
		points = UnitPower("player", PowerType(KINDS[kind].power))
	else
		return
	end
	local was = points
	if state.seen then
		was = state.points
		if event and issecretvalue and not issecretvalue(points) and not issecretvalue(was) and points == was then
			return
		end
	end
	state.points, state.seen = points, true
	local moving = Effects.Allows("flare")
	for i = 1, state.count do
		local jewel = state.jewels[i]
		for _, key in ipairs(NOW) do
			jewel[key]:SetValue(points)
		end
		jewel.haloWas:SetValue(was)
		jewel.ember:SetValue(was)
		for _, group in ipairs(jewel.fades) do
			Restart(group, moving)
		end
	end
	local ring = state.ring
	if ring and ring:IsShown() then
		ring.now.glyphs:SetValue(points)
		ring.now.halo:SetValue(points)
		ring.was.glyphs:SetValue(was)
		ring.was.halo:SetValue(was)
		Restart(ring.now.fade, moving)
		Restart(ring.was.fade, moving)
	end
end

local function OnPower(_, _, token)
	if token == KINDS[state.kind].token then
		Points()
	end
end

local function Listen(class, kind)
	if class == state.class and kind == state.kind then
		return
	end
	state.class, state.kind = class, kind
	local Events = K.Events
	Events.UnregisterAll(OWNER)
	if class then
		Events.RegisterUnit(OWNER, "UNIT_MAXPOWER", Jewels.Update, "player")
		Events.RegisterUnit(OWNER, "UNIT_DISPLAYPOWER", Jewels.Update, "player")
		Events.Register(OWNER, "UPDATE_SHAPESHIFT_FORM", Jewels.Update)
	end
	if kind then
		Events.RegisterUnit(OWNER, "UNIT_POWER_FREQUENT", OnPower, "player")
	end
	if kind == "combo" then
		Events.Register(OWNER, "PLAYER_TARGET_CHANGED", Points)
		Events.Register(OWNER, "COMBO_TARGET_CHANGED", Points)
	end
end

function Jewels.Update(event)
	local class = Class()
	local kind = class and Kind(class)
	local feed = Fed(class)
	local count = feed and DEFAULT_COUNT or class == "PALADIN" and ns.Config("crestVengeance") ~= false and 0 or kind and Count(kind) or 0
	if event == "UPDATE_SHAPESHIFT_FORM" and class == state.class and kind == state.kind and count == state.count and feed == state.feed then
		return
	end
	local waiting = false
	if feed and not feed.container then
		if ns.SlabMedals.Locked() then
			feed, waiting = nil, true
		else
			local ids = {}
			for _, id in ipairs(feed.spells) do
				ids[id] = true
			end
			feed.frame = CreateFrame("Frame", nil, ns.Slab.hub.top)
			local container = CreateFrame("AuraContainer", nil, feed.frame, "CustomAuraContainerTemplate")
			if type(container.AddAuraSlot) ~= "function" then
				feed = nil
			else
				Widgets.KeepOut(container)
				container:SetUnit("player")
				feed.container, feed.options = container, { candidateFilters = { includeSpellIDs = ids } }
			end
		end
	end
	for _, f in ipairs(FEEDS) do
		if f.frame then
			f.frame:SetShown(f == feed)
		end
		if f.container and f.on ~= (f == feed) then
			if ns.SlabMedals.Restricted() then
				waiting = true
			else
				f.on = f == feed
				f.container:SetEnabled(f.on)
			end
		end
	end
	if waiting then
		K.Events.Register(OWNER .. ".Feed", "PLAYER_REGEN_ENABLED", Jewels.Update)
	else
		K.Events.Unregister(OWNER .. ".Feed", "PLAYER_REGEN_ENABLED")
	end
	state.feed = feed
	Listen(class, kind)
	Place(ns.Slab and ns.Slab.hub, count, feed)
	if kind then
		Paint(kind)
		Points()
	end
end

function Jewels.Recheck()
	if Fed(Class()) ~= state.feed then
		Jewels.Update()
	end
end

function Jewels.SetEnabled(on)
	state.enabled = on
	if on then
		K.Callbacks.Register("EffectsLevelChanged", OWNER, Jewels.Update)
	else
		K.Callbacks.Unregister("EffectsLevelChanged", OWNER)
	end
	Jewels.Update()
end
