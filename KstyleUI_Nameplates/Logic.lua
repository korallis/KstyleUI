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

function Logic.ThreatState(status, isTank, calm)
	if not IsNumber(status) then
		return nil
	end
	if calm and not isTank and status == 0 then
		return "safe"
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
local SKULL_LEVEL = -1

function Logic.UnitType(enabled, unit)
	if unit.isPlayer or unit.tapped then
		return nil
	end
	if enabled.quest and unit.quest then
		return "quest"
	end
	local kind = unit.classification
	local level = IsNumber(unit.level) and unit.level or nil
	if enabled.boss and (kind == "worldboss" or level == SKULL_LEVEL) then
		return "boss"
	elseif enabled.rare and RARE_KINDS[kind] then
		return "rare"
	elseif enabled.miniBoss and (kind == "elite" or kind == "rareelite") and level and IsNumber(unit.playerLevel) and level > unit.playerLevel then
		return "miniBoss"
	elseif enabled.elite and ELITE_KINDS[kind] then
		return "elite"
	elseif enabled.caster and unit.caster then
		return "caster"
	elseif enabled.neutral and IsNumber(unit.reaction) and unit.reaction == 4 then
		return "neutral"
	elseif enabled.minor and kind == "minus" then
		return "minor"
	elseif enabled.normal and (kind == "normal" or kind == "trivial") then
		return "normal"
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

function Logic.InterruptReady(info, fromCooldownEvent)
	if IsSecret(info) or type(info) ~= "table" then
		return nil
	end
	local active = info.isActive
	if IsSecret(active) or type(active) ~= "boolean" then
		return nil
	end
	if not active or fromCooldownEvent ~= true then
		return not active
	end
	local gcd = info.isOnGCD
	if IsSecret(gcd) then
		return nil
	end
	return gcd == true
end

function Logic.Footprint(width, height, above, below, scale)
	if not IsNumber(scale) or scale <= 0 then
		return nil
	end
	return math.ceil(width * scale), math.ceil((above + height + below) * scale)
end

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

function Logic.Ramp(r, g, b)
	return KstyleUI.Widgets.FillRamp(r, g, b)
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
	none = { enemy = false, friendly = false },
	enemy = { enemy = true, friendly = false },
	all = { enemy = true, friendly = true },
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

local SHOW_CVARS = {
	{ name = "nameplateShowEnemies", key = "showEnemies" },
	{ name = "nameplateShowFriendlyPlayers", key = "showFriends" },
	{ name = "nameplateShowEnemyMinions", key = "enemyMinions" },
	{ name = "nameplateShowFriendlyPlayerMinions", key = "friendlyMinions" },
	{ name = "nameplateShowFriendlyNpcs", key = "friendlyNpcs" },
	{ name = "nameplateShowOnlyNameForFriendlyPlayerUnits", key = "friendlyNameOnly" },
}

function Logic.CVarPlan(cvars)
	local plan = {}
	for _, entry in ipairs(VALUE_CVARS) do
		plan[#plan + 1] = { name = entry.name, value = Number(cvars[entry.key]) }
	end
	local stacking = STACKING[cvars.stacking] or STACKING.enemy
	plan[#plan + 1] = { name = Logic.STACKING_CVAR, index = STACK_ENEMY, value = stacking.enemy }
	plan[#plan + 1] = { name = Logic.STACKING_CVAR, index = STACK_FRIENDLY, value = stacking.friendly }
	for _, entry in ipairs(SHOW_CVARS) do
		local choice = cvars[entry.key]
		if entry.key == "showEnemies" and cvars.enemiesInCombat then
			choice = cvars.inCombat and "show" or "hide"
		end
		plan[#plan + 1] = { name = entry.name, value = choice == "show" and "1" or choice == "hide" and "0" or nil }
	end
	return plan
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

function Logic.AuraOffset(index, columns, size, spacing, growthX, growthY, lane, height)
	local x = GROWTH_X[growthX] or GROWTH_X.RIGHT
	local y = GROWTH_Y[growthY] or GROWTH_Y.UP
	local slot = index - 1
	local column = slot % columns
	local row = (slot - column) / columns
	return column * (size + spacing) * x[3], row * ((height or size) + spacing + (lane or 0)) * y[3]
end
