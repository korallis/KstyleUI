-- Rail.lua: puts RestedXP's guide window in the layout's story rail: its card on the rail's left edge and width, hanging from the slot's top (the whole slot while the guide is alone, its upper half while Blizzard's tracker holds the lower), the cap, the active steps and the route row stacked down from there with RestedXP's window folded to its floor behind them, its step list folded by RestedXP's own rule and its footer at rest (the footer comes back while a RestedXP timer bar runs); the quest card follows right under the last step and the guide's card reaches down over it, so the rail reads as one card, and when Apply's Edit Mode layout holds Blizzard's tracker under the guide the guide hugs it instead and the tracker's own glass yields; re-placed after each step, on entering the world and after an Edit Mode change, out of combat, and kept out of RestedXP's saved settings by RestedXP's own savePosition switch while the rail holds the window.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, L = K.Widgets, K.Tokens, K.L

local RestedXP = ns.RestedXP
local LogOnce = RestedXP.LogOnce

local Rail = {}
RestedXP.Rail = Rail

local MODULE = "Skins"
local KEY = "restedXP"
local FIELD, DOCK = "rail", "dock"
local OWNER = "Skins.RestedXP.Rail"
local DEFAULT_PRESET = "DPS"
local SIDE, FOOTER, HEAD_HEIGHT, HEADER_OVERLAP, STEP_GAP = 3, 20, 35, 9, 2
local MIN_HEIGHT, LIST_SHOWN = 28, 30
local SAVE = "savePosition"
local FOOT_GAP = "gapSmall"
local MOVED = 1
local SLOT_TOLERANCE = 2

local state = { rxp = nil, placed = nil, original = nil, queued = false, hooked = false, tracked = false, docked = false }

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

local function Docks()
	return ns.Skins.Setting(KEY, DOCK) == true
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

local function Company()
	if state.standIn then
		return true
	end
	local Quests = ns.Quests
	if Quests and type(Quests.Active) == "function" and Quests.Active() then
		return Quests.Fit() ~= nil
	end
	local tracker = _G.ObjectiveTrackerFrame
	if not IsTable(tracker) or type(tracker.IsVisible) ~= "function" then
		return false
	end
	local visible = tracker:IsVisible()
	return not Widgets.IsSecret(visible) and visible == true
end

function Rail.Story()
	local Layout, Setup = K.Layout, K.Setup
	local preset = Layout and type(Layout.Setting) == "function" and Layout.Setting("preset") or DEFAULT_PRESET
	return Setup and type(Setup.Story) == "function" and Setup.Story(preset, true, not Company()) or nil
end

function Rail.Band()
	local story = Rail.Story()
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

local function Hold(f, on)
	if on and not state.held then
		state.held = { value = f[SAVE] }
		f[SAVE] = false
	elseif not on and state.held then
		f[SAVE] = state.held.value
		state.held = nil
	end
end

local function Bars(f)
	local bars = IsTable(f.BarContainer) and f.BarContainer.bars
	return IsTable(bars) and next(bars) ~= nil
end

local function StepsAbove(f)
	local steps = f.CurrentStepFrame
	if not steps:IsShown() or steps.anchor == "BOTTOM" then
		local height = steps:IsShown() and steps:GetHeight() or 0
		return 0, Plain(height) and height or 0
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

local function Fit()
	if state.standIn then
		return state.standIn, state.standIn, state.standInCard
	end
	local Quests = ns.Quests
	if Quests and type(Quests.Active) == "function" and Quests.Active() then
		local card = Quests.Fit()
		if card then
			return card, card, true
		end
		return nil
	end
	local Tracker = ns.Tracker
	local fit = Tracker and type(Tracker.Fit) == "function" and Tracker.Fit() or nil
	local tracker = IsTable(fit) and fit:GetParent() or nil
	if not IsTable(tracker) or not ns.Skins.IsOn("tracker") or ns.Skins.Setting("tracker", "panel") ~= true then
		return nil
	end
	return fit, tracker
end

local function InSlot(tracker, band)
	local EditMode = K.Setup and K.Setup.EditMode
	if not (EditMode and type(EditMode.TrackerPlace) == "function") or not tracker:IsShown() then
		return false
	end
	local point, relative, relativePoint, x, y = tracker:GetPoint(1)
	if point ~= "TOPLEFT" or relativePoint ~= "BOTTOMLEFT" or relative ~= UIParent or not (Plain(x) and Plain(y)) then
		return false
	end
	local place = EditMode.TrackerPlace(band)
	local scale = Widgets.ScaleFactor(tracker)
	return math.abs(x - place.x / scale) <= SLOT_TOLERANCE and math.abs(y - place.y / scale) <= SLOT_TOLERANCE
end

local function WillDock(f, story)
	local fit, tracker, card = Fit()
	if fit == nil or not Docks() or not f:IsShown() or story == nil or story.tracker == nil then
		return false, nil, false
	end
	if state.standIn or card then
		return true, fit, card == true
	end
	return InSlot(tracker, story.tracker), fit, false
end

local function DockCard(on)
	local Quests = ns.Quests
	if Quests and type(Quests.Dock) == "function" then
		Quests.Dock(on)
	end
end

local function CardUnder(top)
	local Quests = ns.Quests
	if Quests and type(Quests.Under) == "function" then
		Quests.Under(top)
	end
end

local function Dock(f, story)
	local Tracker = ns.Tracker
	local docked, fit, card = WillDock(f, story)
	local inset = docked and not card and type(Tracker.Inset) == "function" and Tracker.Inset() or nil
	RestedXP.Chrome.Dock(f, docked and fit or nil, inset and -inset.bottom or 0)
	if Tracker and type(Tracker.Dock) == "function" then
		Tracker.Dock(docked and not card)
	end
	DockCard(docked and card)
	state.docked = docked
	return docked
end

function Rail.DockTo(frame, card)
	state.standIn = IsTable(frame) and frame or nil
	state.standInCard = card == true
	return Rail.Place()
end

function Rail.Undock()
	local Tracker = ns.Tracker
	if state.rxp and IsTable(state.rxp.RXPFrame) then
		RestedXP.Chrome.Dock(state.rxp.RXPFrame, nil)
	end
	if Tracker and type(Tracker.Dock) == "function" then
		Tracker.Dock(false)
	end
	DockCard(false)
	if state.docked then
		Rail.Schedule()
	end
	state.docked = false
end

function Rail.Place()
	state.queued = false
	if not On() then
		return false
	end
	local f = Frame()
	local story = Rail.Story()
	local band = story and story.guide
	if not f or not band then
		return false
	end
	local path = RestedXP.Chrome.Path(f)
	local scale = Widgets.ScaleFactor(f)
	local reach = RestedXP.Chrome.Reach(f.GuideName)
	local head = path and path.height or HEAD_HEIGHT
	local above, below = StepsAbove(f)
	local headTop = head - HEADER_OVERLAP - SIDE
	local folded = path ~= nil and below == 0 and not Bars(f)
	local gap = Tokens.Size(FOOT_GAP)
	local height = Widgets.Snap(f, folded and MIN_HEIGHT or HEADER_OVERLAP + SIDE + FOOTER + gap)
	if height < MIN_HEIGHT then
		height = height + Widgets.Border(f)
	end
	local foot = height + below
	if folded then
		foot = HEADER_OVERLAP + SIDE - (path.metaShown and 0 or head + (above > 0 and STEP_GAP or 0))
	end
	local cap = path and path.capHeight or 0
	local top = band.top / scale - headTop - above - cap
	local docks, _, card = WillDock(f, story)
	if docks and not card then
		top = math.min(top, (story.tracker.top + gap) / scale + foot)
	end
	local width = Widgets.Snap(f, (band.right - band.left) / scale + 2 * SIDE - 2 * reach)
	local left = Widgets.Snap(f, band.left / scale - SIDE + reach)
	top = Widgets.Snap(f, top)
	CardUnder(docks and card and (top - foot) * scale - (folded and 0 or gap) or nil)
	Remember(f)
	Hold(f, true)
	f:ClearAllPoints()
	f:SetSize(width, height)
	f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
	state.placed = { left = left, top = top, width = width, height = height }
	RestedXP.Chrome.Rest(f, true, folded)
	Refresh(f)
	if height - SIDE - (FOOTER - 6) >= LIST_SHOWN then
		LogOnce("rail list", "the guide's head is tall enough that RestedXP keeps a sliver of its step list")
	end
	local reached = band.bottom - (top - foot) * scale
	if reached > 0.5 then
		Log(string.format("the guide's steps reach %.0f units under its part of the story rail", reached))
	end
	Dock(f, story)
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
	Rail.Undock()
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
		Hold(f, false)
		RestedXP.Chrome.Rest(f, false)
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
		Hold(f, false)
		RestedXP.Chrome.Rest(f, false)
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
	f:HookScript("OnHide", Rail.Undock)
	f:HookScript("OnShow", Schedule)
	local rxp = state.rxp
	if type(rxp.SetStep) == "function" then
		hooksecurefunc(rxp, "SetStep", Schedule)
	end
	if type(rxp.SortTimers) == "function" then
		hooksecurefunc(rxp, "SortTimers", Schedule)
	end
	K.Events.Register(OWNER, "PLAYER_ENTERING_WORLD", Schedule)
	K.Events.Register(OWNER, "EDIT_MODE_LAYOUTS_UPDATED", Schedule)
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

function Rail.Docked()
	return state.docked == true
end
