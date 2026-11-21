-- AutoLayout.lua: raid frames sized by raid size (larger up to 10, compact over 25) and healer-first debuffs while the player heals, switched out of combat on top of the saved settings.
local _, ns = ...

local K = KstyleUI
local Settings, Unit, Frames, Geometry = ns.Settings, ns.Unit, ns.Frames, ns.Geometry

local AutoLayout = { state = { bracket = "MEDIUM", healer = false }, shiftX = 0, shiftY = 0 }
ns.AutoLayout = AutoLayout

local HEALER_DISPELS = 2
local HEALER_HEALS = 3
local HEALER_WIDTH = 20
local MIN_WIDTH = 40
local MIN_HEIGHT = 16
local MIN_NAME = 6
local SMALL_RAID = 10
local queued = false

function AutoLayout.Bracket(members)
	local auto = Settings.current.auto
	if Unit.IsSecret(members) or type(members) ~= "number" then
		return "MEDIUM"
	elseif members >= auto.largeLeast then
		return "LARGE"
	elseif auto.customLeast > 0 and members >= auto.customLeast then
		return "CUSTOM"
	elseif members > 0 and members <= auto.smallMost then
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

local function Mythic()
	local id = DifficultyUtil and DifficultyUtil.ID and DifficultyUtil.ID.PrimaryRaidMythic
	local difficulty = id and type(GetInstanceInfo) == "function" and select(3, GetInstanceInfo())
	return id ~= nil and not Unit.IsSecret(difficulty) and difficulty == id
end

local function Counted(cfg, state)
	local sizes = cfg.auto.shownOnly and state.sizes
	if not sizes then
		return state.members
	end
	local count = 0
	for g = 1, 8 do
		if cfg.groups["show" .. g] then count = count + (sizes[g] or 0) end
	end
	return count
end

local function Custom(cfg, size, base)
	local auto, raid = cfg.auto, cfg.raid
	if auto[size .. "Width"] == nil then
		return
	end
	if auto[size .. "Width"] > 0 then raid.width = math.max(MIN_WIDTH, auto[size .. "Width"]) end
	if auto[size .. "Height"] > 0 then raid.height = math.max(MIN_HEIGHT, auto[size .. "Height"]) end
	AutoLayout.shiftX, AutoLayout.shiftY = auto[size .. "X"], auto[size .. "Y"]
	local ratio = raid.height / base
	local function Scale(t, key) t[key] = math.max(1, math.floor(t[key] * ratio + 0.5)) end
	if auto.icons then
		Scale(raid, "auraSize")
		for i = 1, Settings.INDICATOR_SLOTS do Scale(cfg["indicator" .. i], "size") end
	end
	if auto.heals then Scale(raid, "buffSize") end
end

function AutoLayout.Overlay(cfg, state)
	state = state or AutoLayout.state
	AutoLayout.shiftX, AutoLayout.shiftY = 0, 0
	if cfg.groups and not cfg.groups.mythicBench and Mythic() then
		for g = 5, 8 do cfg.groups["show" .. g] = false end
	end
	if cfg.presets and cfg.presets.raid == "Healer" then
		local party, raid = cfg.party, cfg.raid
		party.width, party.height, party.spacing = 200, 44, 6
		party.portrait = false
		raid.width, raid.height, raid.groupsPerRow, raid.unitsPerColumn = 128, 44, 4, 5
		for _, kind in ipairs({ "party", "raid" }) do
			cfg[kind].healthText, cfg[kind].healthTextSize = "DEFICIT", 12
			cfg[kind].textLayout, cfg[kind].healthTextPlace = kind == "raid" and "INSIDE" or "ABOVE", "BAR"
			cfg[kind].iconSize = 16
		end
		for i = 1, Settings.INDICATOR_SLOTS do cfg["indicator" .. i].size = 16 end
		return cfg
	end
	local auto = cfg.auto
	if K.Store.Module("Readability").preset == "Readable" then
		cfg.party.height, cfg.raid.height = math.max(44, cfg.party.height), math.max(44, cfg.raid.height)
		auto.size = false
	end
	if auto.role and state.healer then
		for _, kind in ipairs({ "party", "raid" }) do
			local k = cfg[kind]
			k.auraDispelCount = math.max(k.auraDispelCount, HEALER_DISPELS)
			k.buffCount = math.max(k.buffCount, HEALER_HEALS)
		end
		cfg.raid.width = cfg.raid.width + HEALER_WIDTH
	end
	local bracket = state.members and AutoLayout.Bracket(Counted(cfg, state)) or state.bracket
	local base = cfg.raid.height
	if state.smallRaid then
		return cfg
	elseif auto.size and bracket == "SMALL" then
		Small(cfg.raid)
		Custom(cfg, "small", base)
	elseif auto.size and bracket == "LARGE" then
		Large(cfg.raid)
		Custom(cfg, "large", base)
	elseif auto.size and bracket == "CUSTOM" then
		Custom(cfg, "custom", base)
	end
	return cfg
end

local refresh = Settings.Refresh
function Settings.Refresh()
	local cfg = AutoLayout.Overlay(refresh())
	for section, keys in pairs(Settings.FOLLOW) do
		if cfg.follow[section] then
			for _, key in ipairs(keys) do cfg.party[key] = cfg.raid[key] end
		end
	end
	return cfg
end

local function Read(sizes)
	local cfg = Settings.current
	local raid = type(IsInRaid) == "function" and IsInRaid()
	local count = type(GetNumGroupMembers) == "function" and GetNumGroupMembers()
	local members = not Unit.IsSecret(raid) and raid == true and count or nil
	if Unit.IsSecret(members) or type(members) ~= "number" then members = nil end
	local role = type(UnitGroupRolesAssigned) == "function" and UnitGroupRolesAssigned("player") or nil
	local healer = not Unit.IsSecret(role) and role == "HEALER"
	sizes = members and (sizes or (cfg.groups.hideEmpty or cfg.auto.shownOnly or cfg.raid.center) and Unit.GroupSizes(members)) or nil
	local filled = sizes and ""
	for g = 1, sizes and 8 or 0 do
		filled = filled .. ((sizes[g] or 0) > 0 and g or "")
	end
	local party = cfg.party
	local small = party.smallRaid and members ~= nil and members < SMALL_RAID
	local kind = small and type(IsInInstance) == "function" and select(2, IsInInstance())
	local state = { members = members, sizes = sizes, filled = filled, healer = healer, mythic = not cfg.groups.mythicBench and Mythic(),
		solo = party.centerSolo and party.showSolo and not Unit.IsSecret(count) and count == 0,
		smallRaid = small and not Unit.IsSecret(kind) and type(kind) == "string" and kind ~= "pvp" }
	state.bracket = AutoLayout.Bracket(Counted(cfg, state))
	return state
end

local function Settle(sizes)
	queued = false
	local cfg, state = Settings.current, AutoLayout.state
	local now = Read(sizes)
	AutoLayout.state = now
	if now.bracket == AutoLayout.Bracket(Counted(cfg, state)) and now.healer == state.healer and now.mythic == state.mythic
		and (now.filled == state.filled or not (cfg.groups.hideEmpty or cfg.raid.center and cfg.raid.sortBy == "GROUP" and not cfg.raid.merge)) and now.solo == state.solo and now.smallRaid == state.smallRaid then
		return
	end
	K.DevTest.Log(Settings.MODULE, "automatic layout: " .. now.bracket:lower() .. " raid, " .. (now.healer and "healer" or "not healing"))
	Frames.Apply()
end

function AutoLayout.Check(sizes)
	if InCombatLockdown() then
		if not queued then
			queued = true
			K.Combat.Queue(Settle)
		end
		return
	end
	Settle(sizes)
end

local function Recheck()
	AutoLayout.Check()
end

local function OnSetting(_, module, key)
	if module == Settings.MODULE and type(key) == "string" and (key:match("^auto%.") or key:match("^groups%.") or key:match("^party%.") or key == "raid.center") and Frames.Active() then
		Recheck()
	end
end

local enable = Frames.Enable
function Frames.Enable()
	AutoLayout.state = Read()
	enable()
	K.Callbacks.Register("SettingChanged", "GroupFrames.AutoLayout", OnSetting)
	K.Callbacks.Register("ProfileChanged", "GroupFrames.AutoLayout", Recheck)
	local cfg = Settings.current
	if cfg.groups.hideEmpty or cfg.auto.shownOnly or cfg.party.centerSolo or cfg.party.smallRaid or cfg.raid.center then Recheck() end
end

local flush = Unit.FlushRoster
function Unit.FlushRoster()
	AutoLayout.Check(flush())
end

for _, event in ipairs({ "PLAYER_ROLES_ASSIGNED", "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_DIFFICULTY_CHANGED", "ZONE_CHANGED_NEW_AREA" }) do
	Frames.events[#Frames.events + 1] = { event = event, fn = Recheck }
end
