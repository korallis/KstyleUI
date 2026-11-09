-- Logic.lua: the nameplates' pure rules: threat states, colour sources, markers, level text, plate scale and the CVar plan.
local _, ns = ...

local Logic = {}
ns.Logic = Logic

local format = string.format

local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end
Logic.IsSecret = IsSecret

local function IsNumber(value)
	return not IsSecret(value) and type(value) == "number" and value == value
end

local THREAT_TANK = { [0] = "danger", [1] = "warning", [2] = "warning", [3] = "safe" }
local THREAT_OTHER = { [1] = "warning", [2] = "danger", [3] = "danger" }

function Logic.ThreatState(status, isTank)
	if not IsNumber(status) then
		return nil
	end
	local map = isTank and THREAT_TANK or THREAT_OTHER
	return map[status]
end

function Logic.ColorKind(source, isPlayer, tapped)
	if tapped then
		return "tapped"
	elseif source == "custom" then
		return "custom"
	elseif source == "class" and isPlayer then
		return "class"
	end
	return "reaction"
end

local MARKERS = { worldboss = "hostile", elite = "neutral", rareelite = "rare", rare = "rare" }

function Logic.MarkerColor(classification)
	if IsSecret(classification) or type(classification) ~= "string" then
		return nil
	end
	return MARKERS[classification]
end

local ELITE_KINDS = { worldboss = true, elite = true }
local RARE_KINDS = { rareelite = true, rare = true }

function Logic.UnitType(enabled, unit)
	if unit.isPlayer or unit.tapped then
		return nil
	end
	if enabled.quest and unit.quest then
		return "quest"
	end
	local kind = unit.classification
	if enabled.rare and RARE_KINDS[kind] then
		return "rare"
	elseif enabled.elite and ELITE_KINDS[kind] then
		return "elite"
	elseif enabled.caster and unit.caster then
		return "caster"
	end
	return nil
end

function Logic.IsCaster(powerType, powerMax, mana)
	if not IsNumber(powerType) or powerType ~= mana then
		return false
	end
	if not IsNumber(powerMax) then
		return nil
	end
	return powerMax > 0
end

local INTERRUPTS = {
	WARRIOR = { 6554, 6552, 1672, 1671, 72 },
	ROGUE = { 1769, 1768, 1767, 1766 },
	MAGE = { 2139 },
	SHAMAN = { 10414, 10413, 10412, 8046, 8045, 8044, 8042 },
	PRIEST = { 15487 },
	WARLOCK = { 19647, 19244 },
	PALADIN = { 425609 },
	DRUID = { 410176, 1238122, 16979 },
}
Logic.INTERRUPTS = INTERRUPTS

function Logic.InterruptSpell(class, known)
	local list = type(class) == "string" and INTERRUPTS[class]
	if not list then
		return nil
	end
	for i = 1, #list do
		local id = list[i]
		if known(id) == true then
			return id
		end
	end
	return nil
end

function Logic.InterruptReady(info)
	if IsSecret(info) or type(info) ~= "table" then
		return nil
	end
	local active, gcd = info.isActive, info.isOnGCD
	if IsSecret(active) or type(active) ~= "boolean" or IsSecret(gcd) then
		return nil
	end
	return not active or gcd == true
end

function Logic.Footprint(width, height, above, below, scale)
	if not IsNumber(scale) or scale <= 0 then
		return nil
	end
	return math.ceil(width * scale), math.ceil((above + height + below) * scale)
end

local SKULL_LEVEL = -1

function Logic.LevelText(level)
	if not IsNumber(level) then
		return nil
	end
	if level == SKULL_LEVEL then
		return "??"
	elseif level > 0 then
		return format("%d", level)
	end
	return nil
end

function Logic.PlateScale(rootScale, parentScale)
	if not IsNumber(rootScale) or not IsNumber(parentScale) or rootScale <= 0 or parentScale <= 0 then
		return 1
	end
	return rootScale / parentScale
end

function Logic.ShrinkReference(parentScale, uiScale)
	if not IsNumber(parentScale) or not IsNumber(uiScale) or parentScale <= 0 or uiScale <= 0 then
		return nil
	end
	return parentScale * uiScale
end

local STACK_ENEMY, STACK_FRIENDLY = 1, 2
local STACKING = {
	none = { enemy = false, friendly = false, motion = "0" },
	enemy = { enemy = true, friendly = false, motion = "1" },
	all = { enemy = true, friendly = true, motion = "1" },
}
Logic.STACKING = STACKING

local function Number(value)
	return format("%.4g", value)
end

local VALUE_CVARS = {
	{ name = "nameplateMaxDistance", key = "maxDistance" },
	{ name = "nameplateMaxVerticalDistance", key = "verticalDistance" },
	{ name = "nameplateSelectedScale", key = "selectedScale" },
	{ name = "nameplateMinScale", key = "minScale" },
	{ name = "nameplateSize", key = "clickSize" },
}

Logic.STACKING_CVAR = "nameplateStackingTypes"
Logic.MOTION_CVAR = "nameplateMotion"

function Logic.CVarPlan(cvars)
	local plan = {}
	for _, entry in ipairs(VALUE_CVARS) do
		plan[#plan + 1] = { name = entry.name, value = Number(cvars[entry.key]) }
	end
	local stacking = STACKING[cvars.stacking] or STACKING.enemy
	plan[#plan + 1] = { name = Logic.STACKING_CVAR, index = STACK_ENEMY, value = stacking.enemy }
	plan[#plan + 1] = { name = Logic.STACKING_CVAR, index = STACK_FRIENDLY, value = stacking.friendly }
	plan[#plan + 1] = { name = Logic.MOTION_CVAR, value = stacking.motion, fallback = Logic.STACKING_CVAR }
	return plan
end

local AURA_FILTER = "HARMFUL|PLAYER"
local AURA_FILTER_PLATES = "HARMFUL|PLAYER|INCLUDE_NAME_PLATE_ONLY"

function Logic.AuraFilter(includePlateOnly)
	return includePlateOnly and AURA_FILTER_PLATES or AURA_FILTER
end

local GROWTH_X = { RIGHT = { "LEFT", "Right", 1 }, LEFT = { "RIGHT", "Left", -1 } }
local GROWTH_Y = { UP = { "BOTTOM", "Up", 1 }, DOWN = { "TOP", "Down", -1 } }

function Logic.AuraGrowth(growthX, growthY)
	local x = GROWTH_X[growthX] or GROWTH_X.RIGHT
	local y = GROWTH_Y[growthY] or GROWTH_Y.UP
	return y[1] .. x[1], x[2], y[2]
end

function Logic.AuraLineSize(columns, size, spacing)
	return columns * size + (columns - 1) * spacing
end

function Logic.AuraOffset(index, columns, size, spacing, growthX, growthY)
	local x = GROWTH_X[growthX] or GROWTH_X.RIGHT
	local y = GROWTH_Y[growthY] or GROWTH_Y.UP
	local slot = index - 1
	local column = slot % columns
	local row = (slot - column) / columns
	local step = size + spacing
	return column * step * x[3], row * step * y[3]
end
