-- Stacking.lua: gives the game the plate's own footprint as the nameplate size it stacks and clicks by, holds the game's plate scale CVars at 1 while plates ignore that scale, out of combat, and gives the game's size and values back when the module stops.
local _, ns = ...

local K = KstyleUI
local Settings, Logic = ns.Settings, ns.Logic
local IsSecret = Logic.IsSecret
local LogOnce = ns.LogOnce
local MODULE = Settings.MODULE

local Stacking = {}
ns.Stacking = Stacking

local MARKER_GAP = K.Tokens.Size("gapSmall")
local original
local applied = { w = nil, h = nil }
local queued, hooked = false, false

local SCALE_CVARS = { "nameplateMinScale", "nameplateMaxScale", "nameplateSelectedScale" }
local HELD = {}
for _, name in ipairs(SCALE_CVARS) do
	HELD[name] = true
end
local PIN, MEMORY = "1", "nameplateScaleCVars"
local hold = { loaded = false, pinned = false, waiting = false }

local function Api(name)
	local api = C_NamePlate
	if api and type(api[name]) == "function" then
		return api[name]
	end
	LogOnce("stacking-" .. name, "C_NamePlate." .. name .. " is missing; the game keeps its own nameplate size")
	return nil
end

local function Plain(value)
	return not IsSecret(value) and type(value) == "number" and value or nil
end

function Stacking.Extent()
	local plate = ns.Preview.samplePlate
	if not plate then
		return nil
	end
	local above, below = ns.Auras.Extent(plate)
	local state = ns.state
	local Plate = ns.Plate
	local left, right = 0, 0
	if Settings.Get("name.show") then
		left, right = Plate.NAME_OVERHANG, Plate.NAME_OVERHANG
	end
	if Settings.Get("target.highlight") then
		left, right = math.max(left, Plate.BRACKET_REACH), math.max(right, Plate.BRACKET_REACH)
		local overhang = math.max(0, (Plate.BRACKET_HEIGHT - state.height) / 2)
		above, below = math.max(above, overhang), math.max(below, overhang)
	end
	local crown = Settings.Get("markers.classification") and Plate.CROWN_HEIGHT or 0
	if Settings.Get("level.show") then
		left = math.max(left, Plate.DIAMOND_REACH)
		local overhang = math.max(0, (Plate.DIAMOND_HEIGHT - state.height) / 2)
		above = math.max(above, overhang + crown)
		below = math.max(below, overhang)
	elseif crown > 0 then
		left = math.max(left, Plate.BRACKET_REACH + crown)
	end
	if Settings.Get("markers.raid") then
		right = math.max(right, Settings.Get("markers.raidSize") + MARKER_GAP)
	end
	if Settings.Get("debuffs.enabled") then
		local size, spacing, columns = ns.Auras.Grid(plate)
		local extra = math.max(0, ns.Logic.AuraLineSize(columns, size, spacing) + spacing + size - state.width)
		if Settings.Get("debuffs.growthX") == "LEFT" then
			left = math.max(left, extra)
		else
			right = math.max(right, extra)
		end
	end
	local width = state.width + left + right
	if Settings.Get("name.show") then
		width = math.max(width, K.Widgets.Snap(plate, state.width + ns.Plate.NAME_OVERHANG * 2))
	end
	return width, above, state.height, below
end

local function Footprint()
	local width, above, height, below = Stacking.Extent()
	if not width then
		return nil
	end
	local scale = Logic.PlateScale(K.Scale.Root():GetEffectiveScale(), UIParent:GetEffectiveScale())
	return Logic.Footprint(width, height, above, below, scale)
end

local function Write(w, h)
	local set = Api("SetNamePlateSize")
	if not set then
		return
	end
	local ok, err = pcall(set, w, h)
	if not ok then
		LogOnce("stacking-refused", "SetNamePlateSize refused the footprint: " .. tostring(err))
		return
	end
	applied.w, applied.h = w, h
end

local function Remember()
	if original ~= nil then
		return
	end
	local get = Api("GetNamePlateSize")
	if not get then
		original = false
		return
	end
	local ok, w, h = pcall(get)
	w, h = Plain(w), Plain(h)
	if ok and w and h then
		original = { w = w, h = h }
	else
		original = false
		LogOnce("stacking-original", "GetNamePlateSize gave no size; turning the footprint off leaves the size as it is")
	end
end

local function Apply()
	local w, h = Footprint()
	if not w then
		return
	end
	Remember()
	if applied.stale or applied.w ~= w or applied.h ~= h then
		applied.stale = nil
		Write(w, h)
		K.DevTest.Log(MODULE, "the game's nameplate size follows the plate: " .. w .. " x " .. h)
	end
end

local function Restore()
	if not applied.w then
		return
	end
	applied.w, applied.h = nil, nil
	if original then
		local set = Api("SetNamePlateSize")
		if set then
			pcall(set, original.w, original.h)
			K.DevTest.Log(MODULE, "the game's nameplate size is its own again")
		end
	end
	original = nil
end

local function Records(create)
	local key = K.Store.CharacterKey()
	if type(key) ~= "string" then
		return nil
	end
	local account = K.Store.Account()
	local all = account[MEMORY]
	if type(all) ~= "table" then
		if not create then
			return nil
		end
		all = {}
		account[MEMORY] = all
	end
	local records = all[key]
	if type(records) ~= "table" then
		if not create then
			return nil
		end
		records = {}
		all[key] = records
	end
	return records, all, key
end

local function Pinning()
	return ns.Plates.running and not Settings.Get("shrinkDistant")
end

function Stacking.Holds(name)
	return HELD[name] == true and Pinning()
end

function Stacking.HandBack(name, value)
	local records = HELD[name] and type(value) == "string" and Records(true)
	if not records then
		return
	end
	local record = records[name]
	if type(record) == "table" then
		record.original = value
	else
		local current = K.CVars.Get(name)
		if current and current ~= value then
			records[name] = { original = value, written = current }
		end
	end
end

local function Pin()
	local records = Records(true)
	if not records then
		LogOnce("scale-character", "no character yet; the plate scale CVars wait")
		return
	end
	hold.pinned = true
	for _, name in ipairs(SCALE_CVARS) do
		local current = K.CVars.Get(name)
		local record = records[name]
		if not current then
			LogOnce("scale-missing:" .. name, "CVar " .. name .. " is missing on this client; the game keeps scaling the stacking box by it")
		elseif not (type(record) == "table" and record.written == current) and tonumber(current) ~= 1 then
			local written = K.CVars.Set(name, PIN) and K.CVars.Get(name)
			if written and written ~= current then
				local kept = ns.CVars.Owns(name) and K.CVars.Default(name) or current
				records[name] = { original = kept, written = written }
				K.DevTest.Log(MODULE, name .. " is held at " .. written .. " (the game had " .. current .. "), so the box the game stacks by matches the plate at every distance")
			else
				LogOnce("scale-refused:" .. name, "the game refused CVar " .. name .. "; the game keeps scaling the stacking box by it")
			end
		end
	end
end

local function Release()
	local leaving, restored = hold.pinned, false
	hold.pinned = false
	local records, all, key = Records(false)
	if not records or not (leaving or ns.Plates.running) then
		if leaving then
			ns.CVars.Schedule()
		end
		return
	end
	for name, record in pairs(records) do
		local valid = type(record) == "table" and type(record.original) == "string" and type(record.written) == "string"
		local current = valid and K.CVars.Get(name)
		if valid and current == nil then
			LogOnce("scale-read:" .. name, name .. " cannot be read; KstyleUI gives it back later")
		elseif not valid or current ~= record.written then
			records[name] = nil
		elseif K.CVars.Set(name, record.original) and K.CVars.Get(name) == record.original then
			records[name] = nil
			restored = true
			K.DevTest.Log(MODULE, name .. " is the game's own again: " .. record.original)
		else
			LogOnce("scale-back:" .. name, "the game refused " .. name .. " back; KstyleUI tries again later")
		end
	end
	hold.pinned = next(records) ~= nil
	if not hold.pinned then
		all[key] = nil
		if next(all) == nil then
			K.Store.Account()[MEMORY] = nil
		end
	end
	if leaving or restored then
		ns.CVars.Schedule()
	end
end

local function OnVariables()
	K.Events.Unregister("NameplatesScale", "VARIABLES_LOADED")
	hold.loaded = true
	Stacking.Schedule()
end

function Stacking.Sync()
	if hold.loaded or K.CVars.Loaded() then
		if Pinning() then
			Pin()
		else
			Release()
		end
	elseif Pinning() and not hold.waiting then
		hold.waiting = true
		K.Events.Register("NameplatesScale", "VARIABLES_LOADED", OnVariables)
	end
	if ns.Plates.running and Settings.Get("stacking.footprint") == "plate" then
		Apply()
	else
		Restore()
	end
end

local function Hook()
	if hooked or type(hooksecurefunc) ~= "function" then
		return
	end
	local driver = NamePlateDriverFrame
	if type(driver) ~= "table" or type(driver.UpdateNamePlateSize) ~= "function" then
		LogOnce("stacking-driver", "NamePlateDriverFrame.UpdateNamePlateSize is missing; the footprint is set once, and again on each restyle")
		return
	end
	hooked = true
	hooksecurefunc(driver, "UpdateNamePlateSize", function()
		if applied.w then
			original = nil
			Remember()
			applied.stale = true
			if InCombatLockdown() then
				local size = original and (original.w .. " x " .. original.h) or "a size it would not report"
				K.DevTest.Log(MODULE, "Blizzard reset the nameplate size in combat to " .. size .. "; the game stacks plates by it until combat ends, then KstyleUI's footprint comes back")
			end
			Stacking.Schedule()
		end
	end)
end

function Stacking.Schedule()
	Hook()
	if queued then
		return
	end
	queued = true
	K.Combat.Queue(function()
		queued = false
		Stacking.Sync()
	end)
end
