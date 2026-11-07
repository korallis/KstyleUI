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
