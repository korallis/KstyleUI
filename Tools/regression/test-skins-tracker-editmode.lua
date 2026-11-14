-- test-skins-tracker-editmode.lua: dragging Blizzard's objective tracker in Edit Mode keeps its selection's rect, so Edit Mode's snap preview never does arithmetic on a nil rect, with the quest card off (the tracker skin and the RestedXP dock) and on, at Apply's place and at Blizzard's default place in the right managed container; KstyleUI never anchors, sizes or reparents the tracker or its selection while it drags, when Blizzard's layout apply puts a tracker the card hid back on UIParent the card hides it again once Edit Mode closes, and a tracker the card hides keeps a rect even when its anchor names no frame and hangs on its parent.
local S = dofile("Tools/regression/skins_env.lua")
local Quests = dofile("Tools/regression/quests_fake.lua")
local RestedXP = dofile("Tools/regression/restedxp_fake.lua")

local MOVES = { SetPoint = true, ClearAllPoints = true, SetAllPoints = true, SetParent = true, SetSize = true, SetWidth = true, SetHeight = true, SetScale = true }
local EDIT_MODE_HEIGHT = 400

-- EditMode(env) puts Edit Mode's manager frame and EventRegistry in env, as Safe and the card read them.
local function EditMode(env)
	env.EditModeManagerFrame = env.CreateFrame("Frame", "EditModeManagerFrame", env.UIParent)
	env.EditModeManagerFrame:Hide()
	function env.EditModeManagerFrame.IsEditModeActive(self)
		return self:IsShown()
	end
	local callbacks = {}
	env.EventRegistry = {
		RegisterCallback = function(_, event, fn, owner)
			callbacks[event] = callbacks[event] or {}
			callbacks[event][owner] = fn
			return owner
		end,
		UnregisterCallback = function(_, event, owner)
			if callbacks[event] then
				callbacks[event][owner] = nil
			end
		end,
		TriggerEvent = function(_, event, ...)
			for owner, fn in pairs(callbacks[event] or {}) do
				fn(owner, ...)
			end
		end,
	}
end

local function Enter(env)
	env.EditModeManagerFrame:Show()
	env.EventRegistry:TriggerEvent("EditMode.Enter")
	env.RunTimers()
end

local function Exit(env)
	env.EditModeManagerFrame:Hide()
	env.EventRegistry:TriggerEvent("EditMode.Exit")
	env.FireEvent("EDIT_MODE_LAYOUTS_UPDATED")
	env.RunTimers()
end

-- Sides(frame): Edit Mode's GetScaledSelectionSides (EditModeSystemTemplates.lua:604), arithmetic and all.
local function Sides(frame)
	local left, bottom, width, height = frame.Selection:GetRect()
	local scale = frame:GetScale()
	return left * scale, (left + width) * scale, bottom * scale, (bottom + height) * scale
end

-- Place(env, K, tracker): ApplySystemAnchor for the layout Apply wrote: BreakFromFrameManager's
-- SetParent(UIParent), then the anchor at the story slot's tracker place and the Edit Mode height.
local function Place(env, K, tracker, guide)
	local at = K.Setup.EditMode.TrackerPlace(K.Setup.Story("DPS", guide).tracker)
	local scale = K.Widgets.ScaleFactor(tracker)
	tracker:SetParent(env.UIParent)
	tracker:ClearAllPoints()
	tracker:SetPoint("TOPLEFT", env.UIParent, "BOTTOMLEFT", at.x / scale, at.y / scale)
	tracker:SetHeight(EDIT_MODE_HEIGHT)
end

-- Managed(env, tracker): ManagedFrameContainerMixin:UpdateFrame (ManagedFrameSystem.lua:46) for a tracker in its
-- default place: ClearAllPoints, SetParent(RightManagedFrameContainer), then the container's layout pins it with
-- VerticalLayoutMixin:LayoutChildren's right-aligned anchor, which names no relative frame (LayoutFrame.lua:347), so it
-- hangs on the tracker's parent.
local function Managed(env, tracker)
	tracker:ClearAllPoints()
	tracker:SetParent(env.RightManagedFrameContainer)
	tracker:SetPoint("TOPRIGHT", 0, 0)
	tracker:SetHeight(EDIT_MODE_HEIGHT)
end

-- StartMoving(env, tracker): OnDragStart for a tracker in its default place (EditModeSystemTemplates.lua:890):
-- BreakFromFrameManager takes it out of the container, whose RemoveManagedFrame keeps its anchor because the tracker
-- has IsInDefaultPosition (ManagedFrameSystem.lua:99), and puts it on UIParent (EditModeSystemTemplates.lua:343), so
-- the anchor that names no frame now hangs on UIParent; then the snap preview starts reading its selection, and the
-- engine moves it from where it stands.
local function StartMoving(env, tracker)
	tracker:SetParent(env.UIParent)
	local ok, err = pcall(Sides, tracker)
	assert(ok, "the first snap preview of the drag reads the selection's rect: " .. tostring(err))
	local left, top = tracker:GetLeft(), tracker:GetTop()
	tracker:ClearAllPoints()
	tracker:SetPoint("TOPLEFT", env.UIParent, "BOTTOMLEFT", left, top)
end

-- Boot(opts) -> env, K, ns, tracker: Skins on, RestedXP's guide in the rail, Blizzard's tracker where Apply's Edit
-- Mode layout puts it (or, with opts.managed, in the right managed container as Blizzard's default place does) with
-- the selection EditModeObjectiveTrackerSystemMixin:AnchorSelectionFrame hangs on it.
local function Boot(opts)
	local tracker
	local env, K, ns = S.New({
		saved = opts.saved,
		setup = function(env)
			env._resolveRects = true
			EditMode(env)
			Quests.Install(env, Quests.List(7))
			RestedXP.Install(env, {})
		end,
		before = function(env, K)
			tracker = Quests.Tracker(env, S.Blizzard(env))
			local selection = env.CreateFrame("Frame", nil, tracker)
			selection:SetPoint("TOPLEFT", tracker, "TOPLEFT", -30, 0)
			selection:SetPoint("BOTTOMRIGHT", tracker, "BOTTOMRIGHT", 0, 0)
			tracker.Selection = selection
			if opts.managed then
				local container = env.CreateFrame("Frame", "RightManagedFrameContainer", env.UIParent)
				container:SetPoint("TOPRIGHT", env.UIParent, "TOPRIGHT", -110, -275)
				container:SetSize(260, EDIT_MODE_HEIGHT)
				Managed(env, tracker)
			else
				Place(env, K, tracker, true)
			end
		end,
	})
	K.Modules.Enable("Skins")
	S.LoadAddOn(env, "Blizzard_ObjectiveTracker")
	env.RunTimers()
	S.W.Settle(env)
	return env, K, ns, tracker
end

local function Moves(frame, from)
	local n = 0
	for i = from + 1, #frame._calls do
		if MOVES[frame._calls[i].method] then
			n = n + 1
		end
	end
	return n
end

-- Drag(env, K, tracker, steps): the drag StartMoving runs: each frame the engine moves the tracker's top left, the
-- container updates (its OnSizeChanged marks it dirty, and Update ends in UpdateHeaderPosition, which the skin and the
-- card hook), timers run, and Edit Mode's snap preview reads the selection's sides. Only the drag itself may move
-- the tracker: two anchor calls a frame, none from KstyleUI, and none ever on the selection.
local function Drag(env, K, tracker, steps)
	local _, _, _, x, y = tracker:GetPoint(1)
	local fromTracker, fromSelection = #tracker._calls, #tracker.Selection._calls
	for i = 1, steps do
		tracker:ClearAllPoints()
		tracker:SetPoint("TOPLEFT", env.UIParent, "BOTTOMLEFT", x + 4 * i, y - 6 * i)
		tracker:Update()
		env.FireEvent("QUEST_LOG_UPDATE")
		env.RunTimers()
		env.RunTickers()
		K.Widgets.RestyleAll()
		local ok, err = pcall(Sides, tracker)
		assert(ok, "frame " .. i .. " of the drag: the selection has a rect: " .. tostring(err))
	end
	assert(Moves(tracker, fromTracker) == 2 * steps, "KstyleUI moves, sizes or reparents nothing on the tracker while it drags, got " .. Moves(tracker, fromTracker) .. " calls for " .. steps .. " frames")
	assert(Moves(tracker.Selection, fromSelection) == 0, "nor on its selection")
end

local function Clean(env, K)
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

-- The card off: the tracker skin beside the RestedXP guide, the owner's second in-game test. The selection keeps its
-- rect before, through and after the drag, and the tracker keeps its own glass beside the guide's card.

do
	local env, K, ns, tracker = Boot({ saved = { version = 2, profiles = { Default = { Skins = { enabled = true, quests = { enabled = false } } } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} } })
	assert(not ns.Quests.Active() and tracker:IsVisible(), "the card is off; Blizzard's tracker shows")
	assert(ns.Skins.IsApplied("tracker") and ns.RestedXP.Rail.Placed() and K.Skin.Parts(tracker).backdrop:IsShown(), "the tracker skin is on beside the guide's card, with its own glass")
	assert(pcall(Sides, tracker), "at rest the selection has a rect")
	Enter(env)
	Drag(env, K, tracker, 24)
	Exit(env)
	assert(pcall(Sides, tracker), "after the drag the selection has a rect")
	Place(env, K, tracker, true)
	env.FireEvent("EDIT_MODE_LAYOUTS_UPDATED")
	env.RunTimers()
	assert(ns.RestedXP.Rail.Placed() and K.Skin.Parts(tracker).backdrop:IsShown(), "back in its column, the tracker keeps its own glass and the guide its card")
	Clean(env, K)
end

-- The card on: it hides Blizzard's tracker, so Edit Mode shows no tracker to drag. When Blizzard applies a layout
-- in Edit Mode, BreakFromFrameManager puts the tracker back on UIParent; then it drags cleanly, and once Edit Mode
-- closes the card hides it again, so the quests never show twice.

do
	local env, K, ns, tracker = Boot({})
	assert(ns.Quests.Active() and not tracker:IsVisible(), "the card stands in for the tracker")
	Enter(env)
	assert(not tracker:IsVisible(), "in Edit Mode the hidden tracker shows no selection to drag")
	Place(env, K, tracker, true)
	assert(tracker:IsVisible(), "Blizzard's layout apply puts the tracker back on UIParent")
	Drag(env, K, tracker, 24)
	Exit(env)
	assert(not tracker:IsVisible(), "after Edit Mode closes the card hides Blizzard's tracker again")
	assert(ns.Quests.Active() and ns.Quests.Card():IsShown(), "and keeps the slot")
	assert(pcall(Sides, tracker), "the hidden tracker keeps a rect for Edit Mode's next look")
	Clean(env, K)
end

-- The card on, the tracker in Blizzard's default place (a preset layout, or Reset To Default Position): the card hides
-- it on Safe's hidden parent, and its anchor, which names no frame, hangs on that parent. Safe's hidden parent spans
-- UIParent, so the hidden tracker keeps a rect at rest, on Edit Mode's enter and after Edit Mode closes; this pins
-- Safe's parked state, which the snap preview (EditModeManager.lua:85, :1116) would read without asking whether the
-- frame shows. Blizzard's layout apply puts it back in its container, and the drag from there keeps its rect.

do
	local env, K, ns, tracker = Boot({ managed = true })
	assert(ns.Quests.Active() and not tracker:IsVisible(), "the card stands in for the tracker in its default place")
	assert(K.Safe.IsHidden(tracker), "the card hid Blizzard's tracker")
	assert(pcall(Sides, tracker), "the hidden tracker keeps a rect at rest")
	Enter(env)
	assert(pcall(Sides, tracker), "and on Edit Mode's enter")
	Managed(env, tracker)
	assert(tracker:IsVisible(), "Blizzard's layout apply puts the tracker back in its container")
	StartMoving(env, tracker)
	Drag(env, K, tracker, 12)
	Managed(env, tracker)
	Exit(env)
	assert(not tracker:IsVisible() and K.Safe.IsHidden(tracker), "after Edit Mode closes the card hides Blizzard's tracker again")
	assert(ns.Quests.Active() and ns.Quests.Card():IsShown(), "and keeps the slot")
	assert(pcall(Sides, tracker), "and the hidden tracker keeps a rect after Edit Mode closes")
	Clean(env, K)
end

-- The card on during a scenario: Blizzard's tracker shows in place of the card and drags like any other frame.

do
	local env, K, ns, tracker = Boot({})
	tracker.scenario.contentsHeight = 60
	tracker:Update()
	env.RunTimers()
	assert(tracker:IsVisible() and not ns.Quests.Active(), "the scenario brings Blizzard's tracker back")
	Enter(env)
	Drag(env, K, tracker, 12)
	Exit(env)
	assert(tracker:IsVisible(), "the tracker stays while the scenario runs")
	Clean(env, K)
end

print("test-skins-tracker-editmode: ok")
