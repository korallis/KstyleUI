-- Rules.lua: the shown rules and opacities every Layout element takes, as Lua tests and as secure state-driver macro options.
local _, ns = ...

local Layout = ns.Layout or {}
ns.Layout = Layout

local Rules = {}
Layout.Rules = Rules

Rules.SHOWN = { "always", "combat", "noCombat", "target", "mouseover", "never" }

local VALID = {}
for _, rule in ipairs(Rules.SHOWN) do
	VALID[rule] = true
end

local DRIVERS = {
	combat = "[combat] show; hide",
	noCombat = "[combat] hide; show",
	target = "[@target,exists] show; hide",
	never = "hide",
}

function Rules.IsRule(rule)
	return type(rule) == "string" and VALID[rule] == true
end

function Rules.Driver(rule)
	return DRIVERS[rule]
end

function Rules.Visible(rule, combat, target)
	if rule == "combat" then
		return combat == true
	elseif rule == "noCombat" then
		return combat ~= true
	elseif rule == "target" then
		return target == true
	elseif rule == "never" then
		return false
	end
	return true
end

function Rules.Alpha(rule, combat, hovered, alphaCombat, alphaIdle)
	if rule == "mouseover" and not hovered then
		return 0
	end
	if combat then
		return alphaCombat
	end
	return alphaIdle
end

function Rules.NeedsCombat(rule, alphaCombat, alphaIdle)
	return rule == "combat" or rule == "noCombat" or alphaCombat ~= alphaIdle
end

function Rules.NeedsTarget(rule)
	return rule == "target"
end
