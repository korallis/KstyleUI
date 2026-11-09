-- AutoLayout.lua: compact raid frames in raids over 25 and healer-first debuffs while the player heals, switched out of combat on top of the saved settings.
local _, ns = ...

local K = KstyleUI
local Settings, Unit, Frames = ns.Settings, ns.Unit, ns.Frames

local AutoLayout = { state = { bracket = "MEDIUM", healer = false } }
ns.AutoLayout = AutoLayout

local LARGE_LEAST = 26
local LARGE_SCALE = 0.85
local HEALER_DISPELS = 2
local HEALER_HEALS = 3
local MIN_HEIGHT = 16
local queued = false

function AutoLayout.Bracket(members)
	if type(members) ~= "number" or Unit.IsSecret(members) or members < LARGE_LEAST then
		return "MEDIUM"
	end
	return "LARGE"
end

function AutoLayout.Overlay(cfg, state)
	state = state or AutoLayout.state
	local auto = cfg.auto
	if auto.role and state.healer then
		for _, kind in ipairs({ "party", "raid" }) do
			local k = cfg[kind]
			k.auraDispelCount = math.max(k.auraDispelCount, HEALER_DISPELS)
			k.buffCount = math.max(k.buffCount, HEALER_HEALS)
		end
	end
	if auto.size and state.bracket == "LARGE" then
		local raid = cfg.raid
		raid.height = math.max(MIN_HEIGHT, math.floor(raid.height * LARGE_SCALE + 0.5))
		raid.power = false
	end
	return cfg
end

local refresh = Settings.Refresh
function Settings.Refresh()
	return AutoLayout.Overlay(refresh())
end

local function Read()
	local members = type(GetNumGroupMembers) == "function" and GetNumGroupMembers() or nil
	local role = type(UnitGroupRolesAssigned) == "function" and UnitGroupRolesAssigned("player") or nil
	local healer = not Unit.IsSecret(role) and role == "HEALER"
	return { bracket = AutoLayout.Bracket(members), healer = healer }
end

local function Settle()
	queued = false
	local now, state = Read(), AutoLayout.state
	if now.bracket == state.bracket and now.healer == state.healer then
		return
	end
	AutoLayout.state = now
	K.DevTest.Log(Settings.MODULE, "automatic layout: " .. now.bracket:lower() .. " raid, " .. (now.healer and "healer" or "not healing"))
	Frames.Apply()
end

function AutoLayout.Check()
	if InCombatLockdown() then
		if not queued then
			queued = true
			K.Combat.Queue(Settle)
		end
		return
	end
	Settle()
end

local enable = Frames.Enable
function Frames.Enable()
	AutoLayout.state = Read()
	return enable()
end

local rosterChanged = Unit.RosterChanged
function Unit.RosterChanged(...)
	rosterChanged(...)
	AutoLayout.Check()
end

for _, event in ipairs({ "PLAYER_ROLES_ASSIGNED", "PLAYER_SPECIALIZATION_CHANGED" }) do
	Frames.events[#Frames.events + 1] = { event = event, fn = AutoLayout.Check }
end
