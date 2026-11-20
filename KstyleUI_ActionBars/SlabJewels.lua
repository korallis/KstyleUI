-- SlabJewels.lua: the Medallions hub's resource jewels: up to ten gilt-set diamonds across the top arc of the rune ring, lit one per combo point (rogue, cat-form druid), holy power (paladin) or soul shard (warlock); each gem is a one-point status bar so the engine compares the value and Lua never reads it.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens
local cos, sin, rad = math.cos, math.sin, math.rad

local Jewels = {}
ns.SlabJewels = Jewels

local OWNER = "ActionBars.SlabJewels"
local DEFAULT_COUNT, MAX_COUNT = 5, 10
local RADIUS, STEP = 62, 30
local SETTING, LIP, GEM, CORE, HALO = 11, 8, 7, 3, 20
local HALO_ALPHA, CORE_ALPHA = 0.9, 0.9
local KINDS = {
	combo = { power = "ComboPoints", color = "jewelCombo", core = "jewelComboCore" },
	holy = { power = "HolyPower", color = "jewelHoly", core = "jewelHolyCore" },
	shard = { power = "SoulShards", color = "jewelShard", core = "jewelShardCore" },
}
local CLASS_KIND = { ROGUE = "combo", DRUID = "combo", PALADIN = "holy", WARLOCK = "shard" }
local POWER_IDS = { Energy = 3, ComboPoints = 4, SoulShards = 7, HolyPower = 9 }

local state = { jewels = {}, count = 0, listening = false }
Jewels.state = state

local function IsSecret(v)
	return issecretvalue ~= nil and issecretvalue(v) == true
end

local function PowerType(name)
	local types = Enum and Enum.PowerType
	return types and types[name] or POWER_IDS[name]
end

function Jewels.Kind()
	local _, class = UnitClass("player")
	if IsSecret(class) then
		return nil
	end
	local kind = CLASS_KIND[class]
	if class == "DRUID" then
		local current = UnitPowerType and UnitPowerType("player")
		if IsSecret(current) or current ~= PowerType("Energy") then
			return nil
		end
	end
	return kind
end

local function Count(kind)
	local most = UnitPowerMax and UnitPowerMax("player", PowerType(KINDS[kind].power))
	if IsSecret(most) or type(most) ~= "number" then
		return DEFAULT_COUNT
	end
	if most <= 0 then
		return 0
	end
	return math.min(MAX_COUNT, math.floor(most))
end

local function Texture(parent, name, size, layer, sublevel, color, additive)
	local t = parent:CreateTexture(nil, layer, nil, sublevel)
	t:SetTexture((Tokens.Texture(name)))
	if additive then
		t:SetBlendMode("ADD")
	end
	t:SetPoint("CENTER", parent, "CENTER", 0, 0)
	Widgets.Size(t, size, size)
	if color then
		t:SetVertexColor(Tokens.Color(color))
	end
	return t
end

local function OnePoint(parent, i, size, texture, level, additive)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetFrameLevel(level)
	bar:SetStatusBarTexture((Tokens.Texture(texture)))
	if additive then
		bar:GetStatusBarTexture():SetBlendMode("ADD")
	end
	bar:SetMinMaxValues(i - 1, i)
	bar:SetValue(0)
	bar:SetPoint("CENTER", parent, "CENTER", 0, 0)
	Widgets.Size(bar, size, size)
	return bar
end

local function Build(hub, i)
	local holder = CreateFrame("Frame", nil, hub.top)
	Widgets.Size(holder, SETTING, SETTING)
	local base = hub.top:GetFrameLevel() + 1
	holder:SetFrameLevel(base + 1)
	local jewel = { holder = holder }
	jewel.halo = OnePoint(holder, i, HALO, "glow", base, true)
	jewel.setting = Texture(holder, "diamond", SETTING, "ARTWORK", 0, "gilt")
	jewel.lip = Texture(holder, "diamond", LIP, "ARTWORK", 1, "jewelSetting")
	jewel.socket = Texture(holder, "diamond", GEM, "ARTWORK", 2, "jewelSocket")
	jewel.gem = OnePoint(holder, i, GEM, "diamond", base + 2)
	jewel.core = OnePoint(holder, i, CORE, "diamond", base + 3)
	jewel.core:SetAlpha(CORE_ALPHA)
	jewel.halo:SetAlpha(HALO_ALPHA)
	return jewel
end

local function Place(hub, count)
	local mid = (count + 1) / 2
	for i = 1, math.max(count, #state.jewels) do
		local jewel = state.jewels[i]
		if i <= count then
			jewel = jewel or Build(hub, i)
			state.jewels[i] = jewel
			local a = rad(90 + (mid - i) * STEP)
			jewel.holder:ClearAllPoints()
			jewel.holder:SetPoint("CENTER", hub, "CENTER", Widgets.Snap(hub, RADIUS * cos(a)), Widgets.Snap(hub, RADIUS * sin(a)))
			jewel.holder:Show()
		elseif jewel then
			jewel.holder:Hide()
		end
	end
	state.count = count
end

local function Paint(kind)
	local def = KINDS[kind]
	local r, g, b = Tokens.Color(def.color)
	local cr, cg, cb = Tokens.Color(def.core)
	for _, jewel in ipairs(state.jewels) do
		jewel.gem:SetStatusBarColor(r, g, b)
		jewel.halo:SetStatusBarColor(r, g, b)
		jewel.core:SetStatusBarColor(cr, cg, cb)
	end
end

function Jewels.Points()
	local kind = state.kind
	if not kind or state.count == 0 then
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
	for i = 1, state.count do
		local jewel = state.jewels[i]
		jewel.gem:SetValue(points)
		jewel.core:SetValue(points)
		jewel.halo:SetValue(points)
	end
end

local function OnPower()
	Jewels.Points()
end

local function Listen(on)
	if on == state.listening then
		return
	end
	state.listening = on
	local Events = K.Events
	if on then
		Events.RegisterUnit(OWNER, "UNIT_POWER_FREQUENT", OnPower, "player")
		Events.RegisterUnit(OWNER, "UNIT_MAXPOWER", Jewels.Update, "player")
		Events.RegisterUnit(OWNER, "UNIT_DISPLAYPOWER", Jewels.Update, "player")
		Events.Register(OWNER, "PLAYER_TARGET_CHANGED", OnPower)
		Events.Register(OWNER, "UPDATE_SHAPESHIFT_FORM", Jewels.Update)
	else
		Events.UnregisterAll(OWNER)
	end
end

local function HideAll()
	for _, jewel in ipairs(state.jewels) do
		jewel.holder:Hide()
	end
	state.count, state.kind = 0, nil
end

function Jewels.Update()
	local slab = ns.Slab
	local hub = slab and slab.hub
	if not (state.enabled and hub and hub:IsShown()) then
		HideAll()
		Listen(false)
		return
	end
	Listen(true)
	local kind = Jewels.Kind()
	if not kind then
		HideAll()
		return
	end
	state.kind = kind
	Place(hub, Count(kind))
	Paint(kind)
	Jewels.Points()
end

function Jewels.Enable()
	state.enabled = true
	Jewels.Update()
end

function Jewels.Disable()
	state.enabled = false
	Jewels.Update()
end
