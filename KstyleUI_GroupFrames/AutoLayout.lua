-- AutoLayout.lua: raid frames sized by raid size (larger up to 10, compact over 25) and healer-first debuffs while the player heals, switched out of combat on top of the saved settings.
local _, ns = ...

local K = KstyleUI
local Settings, Unit, Frames, Geometry = ns.Settings, ns.Unit, ns.Frames, ns.Geometry

local AutoLayout = { state = { bracket = "MEDIUM", healer = false } }
ns.AutoLayout = AutoLayout

local SMALL_MOST = 10
local LARGE_LEAST = 26
local HEALER_DISPELS = 2
local HEALER_HEALS = 3
local HEALER_WIDTH = 20
local MIN_HEIGHT = 16
local MIN_NAME = 6
local queued = false

function AutoLayout.Bracket(members)
	if Unit.IsSecret(members) or type(members) ~= "number" then
		return "MEDIUM"
	elseif members >= LARGE_LEAST then
		return "LARGE"
	elseif members > 0 and members <= SMALL_MOST then
		return "SMALL"
	end
	return "MEDIUM"
end

local function Small(raid)
	local step = 2 + (raid.power and 1 or 0)
	raid.width = raid.width + 16
	raid.height = raid.height + step
	raid.spacing = raid.spacing + 4
	raid.nameSize = raid.nameSize + 1
	raid.healthTextSize = raid.healthTextSize + 1
	if raid.power then
		raid.powerHeight = raid.powerHeight + 1
	end
end

local function Large(raid)
	local step = 3 + (raid.power and raid.powerHeight + Geometry.POWER_GAP or 0)
	raid.width = math.max(raid.height, raid.width - 20)
	raid.height = math.max(MIN_HEIGHT, raid.height - step)
	raid.spacing = math.max(0, raid.spacing - 3)
	raid.nameSize = math.max(MIN_NAME, raid.nameSize - 1)
	raid.power = false
	raid.healthText = "NONE"
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
		cfg.raid.width = cfg.raid.width + HEALER_WIDTH
	end
	if auto.size and state.bracket == "SMALL" then
		Small(cfg.raid)
	elseif auto.size and state.bracket == "LARGE" then
		Large(cfg.raid)
	end
	return cfg
end

local refresh = Settings.Refresh
function Settings.Refresh()
	return AutoLayout.Overlay(refresh())
end

local function Read()
	local raid = type(IsInRaid) == "function" and IsInRaid()
	local members = not Unit.IsSecret(raid) and raid == true and type(GetNumGroupMembers) == "function" and GetNumGroupMembers() or nil
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
