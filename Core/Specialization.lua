-- Specialization.lua: character-specific profile assignments and settled player roles.
local _, ns = ...

local Service = {}
ns.Specialization = Service
local OWNER = "Specialization"
local role, queued, appliedKey, requested
local ROLES = { "TANK", "HEALER", "DAMAGER" }

local function Plain(value)
	if not (issecretvalue and issecretvalue(value)) then
		return value
	end
end

local function ValidRole(value)
	value = Plain(value)
	if value == "TANK" or value == "HEALER" or value == "DAMAGER" then
		return value
	end
end

local function Spec(index)
	local api = C_SpecializationInfo
	if api and type(api.GetSpecializationInfo) == "function" and index then
		local id, name, _, _, specRole = api.GetSpecializationInfo(index)
		id, name = Plain(id), Plain(name)
		if type(id) == "number" and id > 0 and type(name) == "string" and name ~= "" then
			return "spec:" .. id, name, ValidRole(specRole)
		end
	end
end

local function CurrentSpec()
	local api = C_SpecializationInfo
	if api and type(api.GetSpecialization) == "function" then
		local index = Plain(api.GetSpecialization())
		if type(index) == "number" and index > 0 then
			return Spec(index)
		end
	end
end

local function AssignedRole()
	if type(UnitGroupRolesAssigned) == "function" then
		return ValidRole(UnitGroupRolesAssigned("player"))
	end
end

local function ReadRole()
	local _, _, specRole = CurrentSpec()
	return AssignedRole() or specRole or "DAMAGER"
end

function Service.Role()
	return role or ReadRole()
end

function Service.Choices()
	local choices = {}
	local count = type(GetNumSpecializations) == "function" and Plain(GetNumSpecializations())
	if type(count) == "number" and count > 0 and count <= 20 then
		for index = 1, count do
			local key, name = Spec(index)
			if key then
				choices[#choices + 1] = { key = key, label = name }
			end
		end
	end
	if #choices == 0 then
		for i, label in ipairs({ ns.L["Tank"], ns.L["Healer"], ns.L["Damage"] }) do
			choices[#choices + 1] = { key = "role:" .. ROLES[i], label = label }
		end
	end
	return choices
end

local function Config()
	local key = ns.Store.CharacterKey()
	if not key then
		return nil
	end
	local account = ns.Store.Account()
	if type(account.specializationProfiles) ~= "table" then
		account.specializationProfiles = {}
	end
	local config = account.specializationProfiles[key]
	if type(config) ~= "table" then
		config = {}
		account.specializationProfiles[key] = config
	end
	if type(config.profiles) ~= "table" then
		config.profiles = {}
	end
	if next(config.profiles) then
		for _, choice in ipairs(Service.Choices()) do
			local name = config.profiles[choice.key]
			if type(name) ~= "string" or type((ns.Store.Data().profiles[name])) ~= "table" then
				config.profiles[choice.key] = ns.Store.ProfileName()
			end
		end
	end
	return config
end

function Service.Enabled()
	local config = Config()
	return not config or config.enabled ~= false
end

function Service.Profile(key)
	local config = Config()
	return config and config.profiles[key] or ns.Store.ProfileName()
end

local function Settle()
	queued = false
	if not ns.Store.IsLoaded() then
		return
	end
	local previous = role
	role = ReadRole()
	local config = Config()
	local key = CurrentSpec()
	if Service.Choices()[1].key:match("^role:") then
		local assigned = AssignedRole()
		key = assigned and "role:" .. assigned
	end
	if config and config.enabled ~= false and (key ~= appliedKey or requested) then
		local name = key and config.profiles[key]
		if name then
			ns.Store.SetProfile(name)
		end
	end
	appliedKey, requested = key, false
	if previous ~= role then
		ns.Callbacks.Fire("PlayerRoleChanged", role)
	end
end

function Service.Check()
	if not queued then
		queued = true
		ns.Combat.Queue(Settle)
	end
end

function Service.SetEnabled(enabled)
	local config = Config()
	if config then
		config.enabled = enabled == true
		requested = true
		Service.Check()
	end
end

function Service.Assign(key, name)
	local config = Config()
	if not config or type(name) ~= "string" or type((ns.Store.Data().profiles[name])) ~= "table" then
		return false
	end
	for _, choice in ipairs(Service.Choices()) do
		if key == choice.key then
			config.profiles[key] = name
			Config()
			requested = requested or key == appliedKey
			Service.Check()
			return true
		end
	end
	return false
end

ns.Events.Register(OWNER, "PLAYER_LOGIN", Service.Check)
ns.Events.Register(OWNER, "PLAYER_ENTERING_WORLD", Service.Check)
ns.Events.Register(OWNER, "PLAYER_ROLES_ASSIGNED", Service.Check)
ns.Events.Register(OWNER, "GROUP_ROSTER_UPDATE", Service.Check)
ns.Events.Register(OWNER, "ACTIVE_TALENT_GROUP_CHANGED", Service.Check)
ns.Events.RegisterUnit(OWNER, "PLAYER_SPECIALIZATION_CHANGED", Service.Check, "player")
