-- Rail.lua: puts RestedXP's guide window in the layout's story rail: its glass on the rail's left edge and width, its footer one rail gap above the quests with its head and active steps stacked up from there, its step list folded by RestedXP's own rule so the rail reads the path and then the quests; re-placed after each step and on entering the world, out of combat, and never in RestedXP's saved settings.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, L = K.Widgets, K.Tokens, K.L

local RestedXP = ns.RestedXP
local LogOnce = RestedXP.LogOnce

local Rail = {}
RestedXP.Rail = Rail

local MODULE = "Skins"
local KEY = "restedXP"
local FIELD = "rail"
local OWNER = "Skins.RestedXP.Rail"
local DEFAULT_PRESET = "DPS"
local SIDE, FOOTER, HEAD_HEIGHT, HEADER_OVERLAP, STEP_GAP = 3, 20, 35, 9, 2
local MIN_HEIGHT, LIST_SHOWN = 28, 30
local FOOT_GAP = "gapSmall"
local MOVED = 1

local state = { rxp = nil, placed = nil, original = nil, queued = false, hooked = false, tracked = false }

local function Log(message)
	K.DevTest.Log(MODULE, "restedXP rail: " .. message)
end

local function IsTable(value)
	return type(value) == "table"
end

local function Plain(value)
	return type(value) == "number" and not Widgets.IsSecret(value) and value == value
end

local function On()
	return K.Modules.IsRunning(MODULE) and ns.Skins.IsOn(KEY) and ns.Skins.Setting(KEY, FIELD) == true
end

local function Frame()
	local rxp = state.rxp
	local f = IsTable(rxp) and rxp.RXPFrame
	if not IsTable(f) or not IsTable(f.GuideName) or not IsTable(f.CurrentStepFrame) then
		return nil
	end
	if IsTable(rxp.v2) and type(rxp.v2.IsGuideWindowEnabled) == "function" then
		local ok, v2 = pcall(rxp.v2.IsGuideWindowEnabled, rxp.v2)
		if ok and v2 == true then
			LogOnce("rail v2", "RestedXP's v2 guide window is on; the story rail places only the v1 guide window")
			return nil
		end
	end
	return f
end

function Rail.Band()
	local Layout, Setup = K.Layout, K.Setup
	local preset = Layout and type(Layout.Setting) == "function" and Layout.Setting("preset") or DEFAULT_PRESET
	local story = Setup and type(Setup.Story) == "function" and Setup.Story(preset, true)
	return story and story.guide or nil
end

local function Remember(f)
	if state.original then
		return
	end
	local points = {}
	for i = 1, f:GetNumPoints() do
		points[i] = { f:GetPoint(i) }
	end
	state.original = { points = points, width = f:GetWidth(), height = f:GetHeight() }
end

local function StepsAbove(f)
	local steps = f.CurrentStepFrame
	if not steps:IsShown() or steps.anchor == "BOTTOM" then
		return 0, steps:IsShown() and steps:GetHeight() or 0
	end
	local height = steps:GetHeight()
	if not Plain(height) or height <= 0 then
		return 0, 0
	end
	return height + STEP_GAP, 0
end

local function Refresh(f)
	local list = f.BottomFrame
	if IsTable(list) and type(list.UpdateFrame) == "function" then
		RestedXP.Try("BottomFrame.UpdateFrame", list.UpdateFrame)
	end
end

function Rail.Place()
	state.queued = false
	if not On() then
		return false
	end
	local f = Frame()
	local band = Rail.Band()
	if not f or not band then
		return false
	end
	local path = RestedXP.Chrome.Path(f)
	local scale = Widgets.ScaleFactor(f)
	local reach = RestedXP.Chrome.Reach(f.GuideName)
	local head = path and path.height or HEAD_HEIGHT
	local over = path and path.over or 0
	local above, below = StepsAbove(f)
	local headTop = HEAD_HEIGHT - HEADER_OVERLAP - SIDE
	local width = (band.right - band.left) / scale + 2 * SIDE - 2 * reach
	local left = band.left / scale - SIDE + reach
	local height = math.max(MIN_HEIGHT, head - headTop + FOOTER + Widgets.Snap(f, Tokens.Size(FOOT_GAP)))
	local top = band.bottom / scale + below + height
	Remember(f)
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
	f:SetSize(width, height)
	state.placed = { left = left, top = top, width = width, height = height }
	Refresh(f)
	if height - SIDE - (FOOTER - 6) >= LIST_SHOWN then
		LogOnce("rail list", "the guide's head is tall enough that RestedXP keeps a sliver of its step list")
	end
	local stackTop = (top + headTop + (above > 0 and above or over)) * scale
	if stackTop > band.top + 0.5 then
		Log(string.format("the guide's steps reach %.0f units above its half of the story rail", stackTop - band.top))
	end
	return true
end

local function Schedule()
	if state.queued or not On() then
		return
	end
	state.queued = true
	C_Timer.After(0, function()
		K.Combat.Queue(Rail.Place)
	end)
end

Rail.Schedule = Schedule

local function Restore()
	local f = Frame()
	local original = state.original
	state.placed = nil
	if not f or not original then
		return
	end
	state.original = nil
	K.Combat.Queue(function()
		f:ClearAllPoints()
		for _, point in ipairs(original.points) do
			f:SetPoint(unpack(point))
		end
		if Plain(original.width) and Plain(original.height) then
			f:SetSize(original.width, original.height)
		end
		Refresh(f)
	end)
end

local function Shifted(f, placed)
	local scale = Widgets.ScaleFactor(f)
	local root = K.Scale.Root()
	local l, t, rl, rb = f:GetLeft(), f:GetTop(), root:GetLeft(), root:GetBottom()
	if Plain(l) and Plain(t) and Plain(rl) and Plain(rb) then
		return math.abs((l - rl / scale) - placed.left) > MOVED or math.abs((t - rb / scale) - placed.top) > MOVED
	end
	local point, relative, relativePoint, x, y = f:GetPoint(1)
	if point ~= "TOPLEFT" or relative ~= UIParent or relativePoint ~= "BOTTOMLEFT" or not (Plain(x) and Plain(y)) then
		return true
	end
	return math.abs(x - placed.left) > MOVED or math.abs(y - placed.top) > MOVED
end

local function Moved(f)
	local placed = state.placed
	if not placed or not On() then
		return
	end
	local width, height = f:GetWidth(), f:GetHeight()
	local resized = Plain(width) and Plain(height) and (math.abs(width - placed.width) > MOVED or math.abs(height - placed.height) > MOVED)
	if Shifted(f, placed) or resized then
		state.placed, state.original = nil, nil
		K.Options.Write(MODULE, KEY .. "." .. FIELD, false)
		Log("the player moved the guide; the story rail lets it be")
		K.Print(L["KstyleUI leaves the RestedXP guide where you put it. Turn Story rail back on in the RestedXP skin's settings."])
	end
end

local function Hook(f)
	if state.hooked then
		return
	end
	state.hooked = true
	local function Check()
		Moved(f)
	end
	for _, part in ipairs({ f, f.CurrentStepFrame, f.GuideName, f.Footer }) do
		if IsTable(part) and type(part.HookScript) == "function" then
			part:HookScript("OnMouseUp", Check)
		end
	end
	local rxp = state.rxp
	if type(rxp.SetStep) == "function" then
		hooksecurefunc(rxp, "SetStep", Schedule)
	end
	K.Events.Register(OWNER, "PLAYER_ENTERING_WORLD", Schedule)
end

function Rail.Start(rxp)
	state.rxp = rxp
	local f = Frame()
	if not f then
		return
	end
	Hook(f)
	RestedXP.Chrome.OnHead = Schedule
	if not state.tracked then
		state.tracked = { Restyle = Schedule }
		Widgets.Track(state.tracked)
	end
	K.Combat.Queue(Rail.Place)
end

function Rail.Switch(on)
	if on then
		Schedule()
	else
		Restore()
	end
end

function Rail.Placed()
	return state.placed
end
