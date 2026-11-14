-- Pins.lua: the pins other addons place on the minimap through HereBeDragons: one that floats on the map's edge for a place off the map is hidden while it rides the edge of KstyleUI's square map, unless the player keeps edge pins.
local _, ns = ...

local K = KstyleUI
local Settings = ns.Settings

local Pins = {}
ns.Pins = Pins

local LIB = "HereBeDragons-Pins-2.0"
local EDGE, SLACK = 0.9, 0.001

local watched = setmetatable({}, { __mode = "k" })
local hidden = setmetatable({}, { __mode = "k" })
local state = { active = false, add = nil, logged = false }

function Pins.Lib()
	local stub = rawget(_G, "LibStub")
	if stub == nil then
		return nil
	end
	local ok, lib = pcall(stub, LIB, true)
	if ok and type(lib) == "table" and type(lib.minimapPins) == "table" then
		return lib
	end
	return nil
end

function Pins.Is(frame)
	local lib = Pins.Lib()
	return lib ~= nil and lib.minimapPins[frame] ~= nil
end

local function Plain(value)
	return type(value) == "number" and not K.Widgets.IsSecret(value) and value == value
end

local function OnEdge(pin, data)
	if type(data) ~= "table" or not data.floatOnEdge then
		return false
	end
	local minimap = Minimap
	local point, relative, relativePoint, x, y = pin:GetPoint(1)
	if point ~= "CENTER" or relative ~= minimap or relativePoint ~= "CENTER" or not (Plain(x) and Plain(y)) then
		return false
	end
	local width, height = minimap:GetWidth(), minimap:GetHeight()
	if not (Plain(width) and Plain(height)) or width <= 0 or height <= 0 then
		return false
	end
	return math.max(math.abs(x) / (width / 2), math.abs(y) / (height / 2)) >= EDGE - SLACK
end

local function Check(pin)
	local lib = Pins.Lib()
	local data = lib and lib.minimapPins[pin]
	if state.active and not Settings.Get("drawer.edgePins") and OnEdge(pin, data) then
		if pin:IsShown() then
			hidden[pin] = true
			pin:Hide()
			if not state.logged then
				state.logged = true
				K.DevTest.Log("Minimap", "hid an addon's map pin riding the map's edge; Addon pins on the map's edge shows them")
			end
		end
	elseif hidden[pin] then
		hidden[pin] = nil
		if data and type(lib.activeMinimapPins) == "table" and lib.activeMinimapPins[pin] then
			pin:Show()
		end
	end
end

local function Watch(pin)
	if type(pin) ~= "table" or watched[pin] or type(pin.SetPoint) ~= "function" then
		return
	end
	watched[pin] = true
	hooksecurefunc(pin, "SetPoint", Check)
end

function Pins.Sync(running)
	state.active = running == true
	local lib = Pins.Lib()
	if lib and lib.AddMinimapIconWorld ~= state.add and type(lib.AddMinimapIconWorld) == "function" then
		hooksecurefunc(lib, "AddMinimapIconWorld", function(_, _, icon)
			Watch(icon)
		end)
		state.add = lib.AddMinimapIconWorld
	end
	for pin in pairs(lib and lib.minimapPins or {}) do
		Watch(pin)
	end
	for pin in pairs(watched) do
		Check(pin)
	end
end
