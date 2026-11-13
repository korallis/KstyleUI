-- MinimapButtons.lua: keeps the Blackthornes and 0xgle Bugs minimap buttons on the square map's edge, in the art their addons drew.
local _, ns = ...

local K = KstyleUI
local L = K.L

local MARGIN = "gapSmall"
local WATCH_SECONDS = 5
local WATCH_STEP = 0.2

local held = setmetatable({}, { __mode = "k" })

local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

local function Square()
	local shape = GetMinimapShape and GetMinimapShape()
	return type(shape) == "string" and not IsSecret(shape) and shape ~= "ROUND"
end

local function Points(button)
	local points = {}
	for i = 1, button:GetNumPoints() do
		local point, relativeTo, relativePoint, x, y = button:GetPoint(i)
		if not point or x == nil or y == nil or IsSecret(x) or IsSecret(y) then
			return {}
		end
		points[i] = { point, relativeTo, relativePoint, x, y }
	end
	return points
end

local function Edge(button)
	if not Square() then
		return
	end
	local point, relativeTo, relativePoint, x, y = button:GetPoint(1)
	if point ~= "CENTER" or relativeTo ~= Minimap or relativePoint ~= "CENTER" or IsSecret(x) or IsSecret(y) then
		return
	end
	local reach = math.max(math.abs(x), math.abs(y))
	if reach < 1 then
		return
	end
	local grow = ((Minimap:GetWidth() or 140) / 2 + K.Tokens.Size(MARGIN)) / reach
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", x * grow, y * grow)
end

local function Hold(button)
	local state = held[button]
	if state then
		state.on = true
		state.quiet = true
		Edge(button)
		state.quiet = false
		return
	end
	state = { on = true, points = Points(button) }
	held[button] = state
	hooksecurefunc(button, "SetPoint", function(self)
		if not state.on or state.quiet then
			return
		end
		local asked = Points(self)
		if #asked > 0 then
			state.points = asked
		end
		state.quiet = true
		Edge(self)
		state.quiet = false
	end)
	state.quiet = true
	Edge(button)
	state.quiet = false
end

local function Give(button)
	local state = held[button]
	if not state or not state.on then
		return
	end
	state.on = false
	if #state.points == 0 then
		return
	end
	state.quiet = true
	button:ClearAllPoints()
	for _, point in ipairs(state.points) do
		button:SetPoint(point[1], point[2], point[3], point[4], point[5])
	end
	state.quiet = false
end

local function Adopt(def, button)
	if not button or not Square() or not ns.Skins.IsOn(def.key) then
		return
	end
	Hold(button)
end

local function Apply(def)
	local function Visit()
		if not ns.Skins.IsOn(def.key) then
			return
		end
		for _, name in ipairs(def.buttons) do
			Adopt(def, _G[name])
		end
	end
	Visit()
	if C_Timer and C_Timer.NewTicker then
		C_Timer.NewTicker(WATCH_STEP, Visit, math.floor(WATCH_SECONDS / WATCH_STEP))
	end
end

local function Switch(def, on)
	if on then
		Apply(def)
		return
	end
	for _, name in ipairs(def.buttons) do
		local button = _G[name]
		if button then
			Give(button)
		end
	end
end

ns.Skins.Add({
	key = "blackthornes",
	label = L["Blackthornes"],
	help = L["Keeps the Blackthornes minimap button on the edge of the square map."],
	live = true,
	buttons = {
		"BlackthornesMinimapButton",
		"BlackthornesButlerMinimapButton",
		"BlackthornesEquipmentMinimapButton",
		"BlackthornesPetsMinimapButton",
	},
	Apply = Apply,
	OnSwitch = Switch,
})

ns.Skins.Add({
	key = "oxgleBugs",
	label = L["0xgle Bugs"],
	help = L["Keeps the 0xgle Bugs minimap button on the edge of the square map."],
	live = true,
	buttons = { "OxgleBugsMinimapButton" },
	Apply = Apply,
	OnSwitch = Switch,
})
