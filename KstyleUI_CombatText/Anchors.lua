-- Anchors.lua: which places show numbers for a unit token: KstyleUI unit and group frames found by their unit attribute, your field, and nameplates.
local _, ns = ...

local K = KstyleUI
local FIELD_KEY = "combattext.player"
local Display = ns.Display

local Anchors = {}
ns.Anchors = Anchors

local SOURCES = {
	{ key = "unitframes.player", kind = "unit", setting = "player", unit = "player", player = true },
	{ key = "unitframes.target", kind = "unit", setting = "target", unit = "target" },
	{ key = "unitframes.targettarget", kind = "unit", setting = "targettarget", unit = "targettarget" },
	{ key = "unitframes.focus", kind = "unit", setting = "focus", unit = "focus" },
	{ key = "unitframes.focustarget", kind = "unit", setting = "focustarget", unit = "focustarget" },
	{ key = "unitframes.pet", kind = "unit", setting = "pet", unit = "pet" },
	{ key = "unitframes.boss", kind = "unit", setting = "boss" },
	{ key = "groupframes.party", kind = "group", setting = "party" },
	{ key = "groupframes.raid", kind = "group", setting = "raid" },
}
local MAX_DEPTH = 4
local MAX_VISITS = 400
local MISS_INTERVAL = 2
local MAX_PARTY, MAX_RAID, MAX_BOSS, MAX_NAMEPLATES = 4, 40, 5, 40
local NAMEPLATES_MODULE = "Nameplates"

local byUnit = {}
local emitters = setmetatable({}, { __mode = "k" })
local GROUP_TOKENS = {}
local NAMEPLATES = {}
for i = 1, MAX_PARTY do
	GROUP_TOKENS["party" .. i] = "party"
end
for i = 1, MAX_RAID do
	GROUP_TOKENS["raid" .. i] = "raid"
end
for i = 1, MAX_BOSS do
	GROUP_TOKENS["boss" .. i] = "boss"
end
for i = 1, MAX_NAMEPLATES do
	NAMEPLATES["nameplate" .. i] = true
end
Anchors.NAMEPLATES = NAMEPLATES

local SOURCE_KEY = {}
for _, source in ipairs(SOURCES) do
	SOURCE_KEY[source.setting] = source.key
end

local state = { field = nil, pool = nil, cfg = nil, pending = false, lastMiss = -math.huge, counts = { unit = 0, group = 0 } }
local lastSummary

local function IsSecret(v)
	return issecretvalue ~= nil and issecretvalue(v) == true
end

local function Log(message)
	K.DevTest.Log("CombatText", message)
end

local logged = {}
local function LogOnce(key, message)
	if not logged[key] then
		logged[key] = true
		Log(message)
	end
end

local function UnitOf(frame)
	if type(frame) ~= "table" or type(frame.GetAttribute) ~= "function" then
		return nil
	end
	local ok, unit = pcall(frame.GetAttribute, frame, "unit")
	if ok and not IsSecret(unit) and type(unit) == "string" and unit ~= "" then
		return unit
	end
	return nil
end

local function Live(key)
	local Layout = K.Layout
	if not (Layout and Layout.Live and Layout.Element) or not Layout.Live(key) then
		return nil
	end
	local element = Layout.Element(key)
	return element and element.frame
end

local function Emitter(frame, kind, pool)
	local emitter = emitters[frame]
	if not emitter or emitter.kind ~= kind or emitter.pool ~= pool then
		emitter = Display.NewEmitter(frame, kind, pool)
		emitters[frame] = emitter
	end
	return emitter
end

local function Add(unit, emitter)
	local list = byUnit[unit]
	if not list then
		list = {}
		byUnit[unit] = list
	end
	for i = 1, #list do
		if list[i] == emitter then
			return
		end
	end
	list[#list + 1] = emitter
end

local visits, found

local function Visit(kind, depth, ...)
	for i = 1, select("#", ...) do
		visits = visits + 1
		if visits > MAX_VISITS then
			return
		end
		local child = select(i, ...)
		local unit = UnitOf(child)
		if unit then
			Add(unit, Emitter(child, kind, state.pool))
			found = found + 1
			state.counts[kind] = state.counts[kind] + 1
		elseif depth < MAX_DEPTH and type(child) == "table" and type(child.GetChildren) == "function" then
			Visit(kind, depth + 1, child:GetChildren())
		end
	end
end

local function Collect(holder, source)
	visits, found = 0, 0
	local unit = UnitOf(holder)
	if unit then
		Add(unit, Emitter(holder, source.kind, state.pool))
		state.counts[source.kind] = state.counts[source.kind] + 1
		return 1
	end
	Visit(source.kind, 1, holder:GetChildren())
	if found == 0 and source.unit then
		Add(source.unit, Emitter(holder, source.kind, state.pool))
		state.counts[source.kind] = state.counts[source.kind] + 1
		found = 1
	end
	return found
end

function Anchors.Setup(fieldEmitter, pool)
	state.field, state.pool = fieldEmitter, pool
end

function Anchors.Rebuild(cfg)
	state.cfg = cfg
	state.pending = false
	for _, list in pairs(byUnit) do
		for i = #list, 1, -1 do
			list[i] = nil
		end
	end
	local counts = state.counts
	counts.unit, counts.group = 0, 0
	local units = cfg.units
	local onPlayerFrame = false
	for _, source in ipairs(SOURCES) do
		local wanted = units[source.setting]
		if source.player then
			wanted = wanted and cfg.playerPlacement == "frame"
		end
		local holder = wanted and Live(source.key)
		if holder then
			local ok, count = pcall(Collect, holder, source)
			if not ok then
				LogOnce("collect:" .. source.key, "reading the frames of " .. source.key .. " failed: " .. tostring(count))
			elseif source.player and count > 0 then
				onPlayerFrame = true
			end
		end
	end
	local fieldUsed = units.player and state.field and not onPlayerFrame
	if fieldUsed then
		Add("player", state.field)
	end
	local Layout = K.Layout
	if Layout and type(Layout.SetLive) == "function" then
		Layout.SetLive(FIELD_KEY, fieldUsed and true or false)
	end
	local summary = counts.unit .. " unit frames, " .. counts.group .. " group frames"
	if summary ~= lastSummary then
		lastSummary = summary
		Log("numbers attach to " .. summary)
	end
end

local function RunPending()
	if state.pending and state.cfg then
		Anchors.Rebuild(state.cfg)
	end
end

function Anchors.Schedule()
	if state.pending then
		return
	end
	state.pending = true
	local timer = C_Timer
	if timer and timer.After then
		timer.After(0, RunPending)
	else
		RunPending()
	end
end

function Anchors.Lookup(unit)
	local list = byUnit[unit]
	if list and #list > 0 then
		return list
	end
	return nil
end

function Anchors.Ready(emitter, unit)
	if emitter.kind == "field" then
		return true
	end
	local frame = emitter.frame
	if emitter.kind == "group" and UnitOf(frame) ~= unit then
		Anchors.Schedule()
		return false
	end
	local visible = frame:IsVisible()
	return IsSecret(visible) or visible == true
end

function Anchors.Missed(unit)
	local setting = GROUP_TOKENS[unit]
	local cfg = state.cfg
	if not setting or not cfg or not cfg.units[setting] or not Live(SOURCE_KEY[setting]) then
		return
	end
	local now = GetTime and GetTime() or 0
	if now - state.lastMiss < MISS_INTERVAL then
		return
	end
	state.lastMiss = now
	Anchors.Schedule()
end

local function PlateFrame(unit)
	local api = C_NamePlate
	if not (api and api.GetNamePlateForUnit) then
		LogOnce("noplates", "C_NamePlate.GetNamePlateForUnit is missing; nameplates show no numbers")
		return nil
	end
	local ok, plate = pcall(api.GetNamePlateForUnit, unit)
	if ok and type(plate) == "table" then
		return plate
	end
	return nil
end

function Anchors.Plate(unit, cfg)
	if not cfg.units.nameplate or not K.Modules.IsRunning(NAMEPLATES_MODULE) then
		return nil
	end
	local plate = PlateFrame(unit)
	return plate and Emitter(plate, "plate", state.pool)
end

function Anchors.PlateRemoved(unit)
	if not NAMEPLATES[unit] then
		return
	end
	local plate = PlateFrame(unit)
	local emitter = plate and emitters[plate]
	if emitter then
		Display.Clear(emitter)
	end
end

function Anchors.Counts()
	return state.counts.unit, state.counts.group
end
