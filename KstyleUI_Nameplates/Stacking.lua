-- Stacking.lua: gives the game the plate's own footprint as the nameplate size it stacks and clicks by, out of combat, and gives the game's size back when the module stops.
local _, ns = ...

local K = KstyleUI
local Settings, Logic = ns.Settings, ns.Logic
local IsSecret = Logic.IsSecret
local LogOnce = ns.LogOnce
local MODULE = Settings.MODULE

local Stacking = {}
ns.Stacking = Stacking

local MARKER_SIZE, GAP, MARKER_GAP = 12, K.Tokens.Size("gapTiny"), K.Tokens.Size("gapSmall")
local original
local applied = { w = nil, h = nil }
local queued, hooked = false, false

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
	local width = state.width + ns.Plate.BADGE_SIZE
	if Settings.Get("level.show") then
		local overhang = math.max(0, (plate.level:GetHeight() - state.height) / 2)
		local crown = Settings.Get("markers.classification") and MARKER_SIZE + GAP or 0
		above = math.max(above, overhang + crown)
		below = math.max(below, overhang)
	end
	if Settings.Get("markers.raid") then
		width = width + Settings.Get("markers.raidSize") + MARKER_GAP
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

function Stacking.Sync()
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
