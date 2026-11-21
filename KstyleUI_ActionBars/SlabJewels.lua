-- SlabJewels.lua: the Medallions hub's resource jewels: up to ten gilt-set diamonds across the top arc of the rune ring, lit one per combo point (rogue, cat-form druid), holy power (paladin) or soul shard (warlock); each gem is a one-point status bar so the engine compares the value and Lua never reads it.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens
local cos, sin, rad = math.cos, math.sin, math.rad
local IsSecret = Widgets.IsSecret

local Jewels = {}
ns.SlabJewels = Jewels

local OWNER = "ActionBars.SlabJewels"
local DEFAULT_COUNT, MAX_COUNT = 5, 10
local RADIUS, STEP, ARC = 62, 30, 120
local SETTING, LIP, GEM, CORE, HALO = 11, 8, 7, 3, 20
local ALPHA = 0.9
local KINDS = {
	combo = { power = "ComboPoints", token = "COMBO_POINTS", color = "jewelCombo", core = "jewelComboCore" },
	holy = { power = "HolyPower", token = "HOLY_POWER", color = "jewelHoly", core = "jewelHolyCore" },
	shard = { power = "SoulShards", token = "SOUL_SHARDS", color = "jewelShard", core = "jewelShardCore" },
}
local CLASS_KIND = { ROGUE = "combo", DRUID = "combo", PALADIN = "holy", WARLOCK = "shard" }
local POWER_IDS = { Energy = 3, ComboPoints = 4, SoulShards = 7, HolyPower = 9 }

local state = { jewels = {}, count = 0 }
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

local function Texture(parent, size, sublevel, color)
	local t = parent:CreateTexture(nil, "ARTWORK", nil, sublevel)
	t:SetTexture((Tokens.Texture("diamond")))
	t:SetPoint("CENTER", parent, "CENTER", 0, 0)
	Widgets.Size(t, size, size)
	t:SetVertexColor(Tokens.Color(color))
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
	Texture(holder, SETTING, 0, "gilt")
	Texture(holder, LIP, 1, "jewelSetting")
	Texture(holder, GEM, 2, "jewelSocket")
	jewel.gem = OnePoint(holder, i, GEM, "diamond", base + 2)
	jewel.core = OnePoint(holder, i, CORE, "diamond", base + 3)
	jewel.core:SetAlpha(ALPHA)
	jewel.halo:SetAlpha(ALPHA)
	return jewel
end

local function Place(hub, count)
	local mid, step = (count + 1) / 2, count > 5 and ARC / (count - 1) or STEP
	for i = 1, math.max(count, #state.jewels) do
		local jewel = state.jewels[i]
		if i <= count then
			jewel = jewel or Build(hub, i)
			state.jewels[i] = jewel
			local a = rad(90 + (mid - i) * step)
			jewel.holder:ClearAllPoints()
			jewel.holder:SetPoint("CENTER", hub, "CENTER", Widgets.Snap(hub, RADIUS * cos(a)), Widgets.Snap(hub, RADIUS * sin(a)))
			jewel.holder:Show()
		else
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

local function Points()
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

function Jewels.Update()
	local class = Class()
	local kind = class and Kind(class)
	Listen(class, kind)
	Place(ns.Slab and ns.Slab.hub, kind and Count(kind) or 0)
	if kind then
		Paint(kind)
		Points()
	end
end

function Jewels.SetEnabled(on)
	state.enabled = on
	Jewels.Update()
end
