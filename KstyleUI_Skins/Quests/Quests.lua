-- Quests.lua: the quest card switch: the card is a Layout element of its own, the quest card (its own mover in Layout Mode; in the story slot under the map, or in a second column beside the RestedXP guide's card while the guide holds the slot; in Orbs on top of the guide's card in one column, the guide re-placed whenever the card's height changes), and shows the tracked quests in place of Blizzard's objective tracker, which it hides whole by reparenting out of combat and outside Edit Mode while all the tracker holds is quests and campaign quests; anything else the tracker holds (a scenario, dungeon or delve stage, world quests, bonus objectives, achievements, recipes) brings Blizzard's tracker back in place of the card until it ends, so nothing shows twice and nothing is lost; quest events mark the card dirty and one throttled read redraws it; switching it off gives Blizzard's tracker back untouched.
local _, ns = ...

local K = KstyleUI
local L = K.L
local Skins, Card, Data = ns.Skins, ns.QuestCard, ns.QuestData

local Quests = {}
ns.Quests = Quests

local KEY = "quests"
local OWNER = "Skins.Quests"
local THROTTLE = 0.1
local DEFAULT_PRESET = "DPS"
local DEFAULT_SHOWN, MIN_SHOWN, MAX_SHOWN = 4, 1, 8
local EVENTS = {
	"QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED", "SUPER_TRACKING_CHANGED", "QUEST_ACCEPTED", "QUEST_REMOVED",
	"QUEST_TURNED_IN", "QUEST_AUTOCOMPLETE",
}

local state = { on = false, active = false, dirty = false, built = false, queued = false, holder = nil, guide = nil }
local others = false

local function Log(message)
	K.DevTest.Log("Skins", KEY .. ": " .. message)
end

local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

local function Tracker()
	local tracker = _G.ObjectiveTrackerFrame
	return type(tracker) == "table" and tracker or nil
end

local function Check(module)
	if others or type(module) ~= "table" or module == _G.QuestObjectiveTracker or module == _G.CampaignQuestObjectiveTracker then
		return
	end
	local height = type(module.GetContentsHeight) == "function" and module:GetContentsHeight()
	if not IsSecret(height) and type(height) == "number" and height > 0 then
		others = true
		return
	end
	local states, current = ObjectiveTrackerModuleState, module.state
	if type(states) == "table" and not IsSecret(current) and current ~= nil and current == states.NotShown then
		others = true
	end
end

local function Popups()
	if type(GetNumAutoQuestPopUps) ~= "function" then
		return false
	end
	local n = GetNumAutoQuestPopUps()
	return not IsSecret(n) and type(n) == "number" and n > 0
end

local function Others(tracker)
	others = Popups()
	if not others and type(tracker.ForEachModule) == "function" then
		tracker:ForEachModule(Check)
	end
	return others
end

local function Wanted()
	local tracker = Tracker()
	return state.on and state.built and tracker ~= nil and not Others(tracker)
end

local function Rail()
	local RestedXP = ns.RestedXP
	local rail = RestedXP and RestedXP.Rail
	if rail and type(rail.Schedule) == "function" then
		rail.Schedule()
	end
end

local function Guide()
	local Setup = K.Setup
	return type(Setup.GuideLoaded) == "function" and Setup.GuideLoaded() and Skins.IsOn("restedXP") and Skins.Setting("restedXP", "rail") == true
end

local function Preset()
	local Layout = K.Layout
	return Layout and type(Layout.Setting) == "function" and Layout.Setting("preset") or DEFAULT_PRESET
end

local function Story(guide, style)
	local Setup = K.Setup
	local Layouts = Setup and Setup.Layouts
	if not (Layouts and type(Layouts.Story) == "function") then
		return nil
	end
	local rw, rh = Setup.RootSize()
	return Layouts.Story(Preset(), rh, guide, style, rw) or Layouts.Story(DEFAULT_PRESET, rh, guide, style, rw)
end

local function Spec(guide, style)
	local story = Story(guide, style)
	return story and story.quests
end

local function Follow()
	local story = state.guide and Story(true, K.HudStyle.Current())
	if story and story.stacked then
		Rail()
	end
end

local function Register(spec)
	K.Widgets.Place(state.holder, spec.key, { anchor = spec.anchor, x = spec.x, y = spec.y }, { label = L["Quest card"], module = "Skins" })
end

local function Place()
	local holder = state.holder
	local guide = Guide()
	local spec = Spec(guide, K.HudStyle.Current())
	if not holder or not spec then
		Log("the layout has no story slot; the card keeps its last place")
		return
	end
	holder:SetSize(spec.width, spec.height)
	if state.guide ~= guide then
		state.guide = guide
		Register(Spec(guide))
	end
	Card.Place(holder, 0, spec.height, spec.width, spec.height)
end

local function Flush()
	state.dirty = false
	if not state.active then
		return
	end
	Data.Read()
	Card.Render()
end

local function Dirty()
	if state.dirty or not state.active then
		return
	end
	state.dirty = true
	C_Timer.After(THROTTLE, Flush)
end

local function Shown()
	local value = Skins.Setting(KEY, "shown")
	if type(value) ~= "number" then
		return DEFAULT_SHOWN
	end
	return math.max(MIN_SHOWN, math.min(MAX_SHOWN, math.floor(value)))
end

local Evaluate

local function Later()
	state.queued = false
	Evaluate()
end

function Evaluate()
	local active = Wanted()
	if active == state.active then
		return
	end
	if InCombatLockdown() then
		if not state.queued then
			state.queued = true
			K.Combat.Queue(Later)
		end
		return
	end
	state.active = active
	Card.SetActive(active)
	local tracker = Tracker()
	if active then
		K.Safe.HideBlizzard(tracker)
		Place()
		Card.SetShownCount(Shown())
		Data.Read()
		Card.Render()
		Log("the card shows the tracked quests in place of Blizzard's tracker")
	else
		Card.Frame():Hide()
		Card.HideButtons()
		if tracker then
			K.Safe.RestoreBlizzard(tracker)
		end
		Log(state.on and "Blizzard's tracker holds more than quests, so it shows in place of the card" or "the card is off; Blizzard's tracker shows")
	end
	Rail()
end

local function OnTrackerUpdate()
	Evaluate()
end

local function OnTrackerParent()
	local tracker = Tracker()
	if state.active and tracker then
		K.Safe.HideBlizzard(tracker)
	end
end

local Replace

local function ReplaceLater()
	state.replacing = false
	Replace()
end

function Replace()
	if not state.active then
		return
	end
	if Card.Locked() then
		if not state.replacing then
			state.replacing = true
			K.Combat.Queue(ReplaceLater)
		end
		return
	end
	Place()
	Card.Render()
	Rail()
end

local function OnSettingChanged(_, module, key)
	if type(key) ~= "string" then
		return
	end
	if (module == "Layout" and key == "preset") or (module == "Skins" and key:find("^restedXP%.")) then
		Replace()
	end
end

local function Build()
	local tracker = Tracker()
	local holder = CreateFrame("Frame", "KstyleUI_QuestSlot", K.Scale.Root())
	holder:EnableMouse(false)
	state.holder = holder
	local card = Card.Build(holder)
	Place()
	card:HookScript("OnShow", Rail)
	card:HookScript("OnHide", Rail)
	card:HookScript("OnSizeChanged", Follow)
	if type(tracker.UpdateHeaderPosition) == "function" then
		hooksecurefunc(tracker, "UpdateHeaderPosition", OnTrackerUpdate)
	else
		Log("UpdateHeaderPosition is missing; the card checks Blizzard's tracker on quest events only")
	end
	hooksecurefunc(tracker, "SetParent", OnTrackerParent)
	for _, event in ipairs(EVENTS) do
		K.Events.Register(OWNER, event, function()
			Dirty()
			Evaluate()
		end)
	end
	K.Events.RegisterUnit(OWNER, "UNIT_QUEST_LOG_CHANGED", Dirty, "player")
	K.Events.Register(OWNER, "PLAYER_ENTERING_WORLD", function()
		Replace()
		Dirty()
		Evaluate()
	end)
	K.Callbacks.Register("SettingChanged", OWNER, OnSettingChanged)
	K.Callbacks.Register("HudStyleChanged", OWNER, Replace)
	K.Widgets.Track({ Restyle = Replace })
	state.built = true
end

local function Apply()
	if not Data.Available() then
		Log("the quest API is missing on this client; the quest card stays off and Blizzard's tracker keeps the quests")
		return
	end
	if not Tracker() then
		Log("ObjectiveTrackerFrame is missing on this client; the quest card stays off")
		return
	end
	Build()
	state.on = Skins.IsOn(KEY)
	Evaluate()
end

local function OnSwitch(_, on)
	state.on = on == true
	Evaluate()
end

local function OnSetting(_, field)
	if field == nil or field == "shown" then
		Card.SetShownCount(Shown())
		if state.active then
			Card.Render()
		end
	end
end

function Quests.Active()
	return state.active
end

function Quests.Card()
	return Card.Frame()
end

function Quests.Holder()
	return state.holder
end

function Quests.Fit()
	local card = Card.Frame()
	if state.active and card and card:IsShown() then
		return card
	end
	return nil
end

Quests.Rows = Card.Rows
Quests.Buttons = Card.Buttons
Quests.Parts = Card.Parts
Quests.Offset = Card.Offset
Quests.Refresh = Dirty

Skins.Add({
	key = KEY,
	label = L["Quest card"],
	help = L["Shows your tracked quests in the story rail, a few at a time; the wheel scrolls to the rest."],
	addon = "Blizzard_ObjectiveTracker",
	live = true,
	defaults = { shown = DEFAULT_SHOWN },
	rows = {
		{
			type = "slider", key = "shown", label = L["Quests shown"],
			help = L["How many quests the card shows at once."],
			min = MIN_SHOWN, max = MAX_SHOWN, step = 1,
		},
	},
	Apply = Apply,
	OnSwitch = OnSwitch,
	OnSetting = OnSetting,
})
