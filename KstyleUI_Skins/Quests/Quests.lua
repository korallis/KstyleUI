-- Quests.lua: the quest card switch: the card is a Layout element of its own, the quest card (its own mover in Layout Mode; in the story slot under the map, or in a second column beside the RestedXP guide's card while the guide holds the slot, and back in the slot with the guide in that column while the guide is shown in Frames; in Orbs on top of the guide's card in one column, the guide re-placed whenever the card's height changes, and the card giving up the room the rail asks for so the guide keeps its current step beside RestedXP's docked boxes), and shows the tracked quests in place of Blizzard's objective tracker, which it hides whole by reparenting out of combat and outside Edit Mode while all the tracker holds is quests and campaign quests; anything else the tracker holds (a scenario, dungeon or delve stage, world quests, bonus objectives, achievements, recipes) brings Blizzard's tracker back in place of the card until it ends, so nothing shows twice and nothing is lost; quest events mark the card dirty and one throttled read redraws it; switching it off gives Blizzard's tracker back untouched.
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
	"QUEST_DATA_LOAD_RESULT",
}

local state = { on = false, active = false, dirty = false, built = false, queued = false, holder = nil, guide = nil, give = 0 }
local others = false
local QuestieActive, SyncQuestie

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
	return state.on and state.built and tracker ~= nil and not QuestieActive() and not Others(tracker)
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

local function Story(guide, style, shown)
	local Setup = K.Setup
	local Layouts = Setup and Setup.Layouts
	if not (Layouts and type(Layouts.Story) == "function") then
		return nil
	end
	local rw, rh = Setup.RootSize()
	return Layouts.Story(Preset(), rh, guide, style, rw, shown) or Layouts.Story(DEFAULT_PRESET, rh, guide, style, rw, shown)
end

local function Spec(guide, style, shown)
	local story = Story(guide, style, shown)
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
	local RestedXP = ns.RestedXP
	local shown = guide and RestedXP and RestedXP.Rail and RestedXP.Rail.Shown() or false
	local spec = Spec(guide, K.HudStyle.Current(), shown)
	if not holder or not spec then
		Log("the layout has no story slot; the card keeps its last place")
		return
	end
	holder:SetSize(spec.width, spec.height)
	if state.guide ~= guide or state.shown ~= shown then
		state.guide, state.shown = guide, shown
		Register(Spec(guide, nil, shown))
	end
	Card.Place(holder, 0, spec.height, spec.width, spec.height - state.give)
end

local function Flush()
	state.dirty = false
	if not state.active then
		return
	end
	Data.Read()
	if Data.status ~= state.readStatus then
		state.readStatus = Data.status
		if Data.status ~= "ready" then
			K.DevTest.Log(OWNER, "read-deferred reason=" .. tostring(Data.status) .. " watches=" .. tostring(Data.watches)
				.. " retained=" .. tostring(Data.Count()) .. Quests.Diagnostic())
		end
	end
	if Data.status ~= "ready" and InCombatLockdown() and not state.retry then
		state.retry = true
		K.Combat.Queue(function()
			state.retry = false
			Flush()
		end)
	end
	if Data.changed then
		Card.Render()
	end
end

local function Dirty(reason)
	state.trigger = type(reason) == "string" and not IsSecret(reason) and reason or "refresh"
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

local function QuestieProfile()
	local addon = rawget(_G, "Questie")
	local db = type(addon) == "table" and addon.db
	return type(db) == "table" and type(db.profile) == "table" and db.profile or nil
end

local function UseQuestie()
	return K.Store.Module("Integrations").questTracker == "questie"
end

function QuestieActive()
	local profile = QuestieProfile()
	if not profile then return false end
	local frame = rawget(_G, "Questie_BaseFrame")
	return UseQuestie() or not IsSecret(profile.trackerEnabled) and profile.trackerEnabled == true
		or type(frame) == "table" and frame:IsShown() == true
end

function SyncQuestie()
	if state.questieSync or state.questieQueued then return end
	state.questieQueued = true
	K.Combat.Queue(function()
		state.questieQueued = false
		if state.questieSync then return end
		local profile, loader = QuestieProfile(), rawget(_G, "QuestieLoader")
		if not profile or IsSecret(profile.trackerEnabled) or type(loader) ~= "table" or type(loader.ImportModule) ~= "function" then return end
		local ok, addon = pcall(loader.ImportModule, loader, "QuestieTracker")
		if not ok or type(addon) ~= "table" or type(addon.Update) ~= "function" or type(addon.Toggle) ~= "function" then return end
		state.questieSync = true
		if state.questie ~= addon then
			state.questie = addon
			hooksecurefunc(addon, "Update", SyncQuestie)
		end
		local frame = rawget(_G, "Questie_BaseFrame")
		if type(frame) == "table" and state.questieFrame ~= frame then
			state.questieFrame = frame
			frame:HookScript("OnShow", SyncQuestie)
			frame:HookScript("OnHide", function() Evaluate(); Dirty("Questie") end)
		end
		local enabled = not IsSecret(profile.trackerEnabled) and profile.trackerEnabled == true
		if state.on and enabled ~= UseQuestie() then
			if enabled and addon.started == true then
				if K.Call(Data.ImportQuestie, addon) then K.Call(addon.Toggle, addon) end
			elseif not enabled then
				if addon.started == true then K.Call(addon.Toggle, addon)
				elseif type(addon.Enable) == "function" then K.Call(addon.Enable, addon) end
			end
		end
		local hasCompat, compat = pcall(loader.ImportModule, loader, "QuestieCompat")
		if hasCompat and type(compat) == "table" then
			if state.questieCompat ~= compat and type(compat.HideWatchFrame) == "function" then
				state.questieCompat = compat
				hooksecurefunc(compat, "HideWatchFrame", SyncQuestie)
			end
			local visibility = UseQuestie() and compat.HideWatchFrame or compat.ShowWatchFrame
			if state.on and type(visibility) == "function" then K.Call(visibility) end
		end
		state.questieSync = false
		Evaluate()
		Dirty("Questie")
	end)
end

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
	if module == "Integrations" and key == "questTracker" then SyncQuestie() end
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
		K.Events.Register(OWNER, event, function(name)
			Dirty(name)
			Evaluate()
		end)
	end
	K.Events.RegisterUnit(OWNER, "UNIT_QUEST_LOG_CHANGED", Dirty, "player")
	K.Events.Register(OWNER, "PLAYER_ENTERING_WORLD", function()
		SyncQuestie()
		Replace()
		Dirty()
		Evaluate()
	end)
	K.Events.Register(OWNER .. ".Questie", "ADDON_LOADED", function(_, name) if name == "Questie" then SyncQuestie() end end)
	K.Callbacks.Register("SettingChanged", OWNER, OnSettingChanged)
	K.Callbacks.Register("HudStyleChanged", OWNER, Replace)
	K.Widgets.Track({ Restyle = Replace })
	state.built = true
	K.DevTest.AddCheck("quest card diagnostics", Card.Diagnose)
	K.Events.Register(OWNER .. ".Diagnostics", "PLAYER_REGEN_DISABLED", function()
		C_Timer.After(0, Card.CheckDiagnostic)
	end)
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
	SyncQuestie()
	Evaluate()
end

local function OnSwitch(_, on)
	state.on = on == true
	if state.built then SyncQuestie() end
	Evaluate()
end

local function OnSetting(_, field)
	if field == nil or field == "shown" or field == "continuation" then
		Card.SetShownCount(Shown())
		if state.active then
			Card.Render()
		end
	end
end

function Quests.Give(units)
	units = math.max(0, units or 0)
	if math.abs(units - state.give) < 0.01 then
		return
	end
	state.give = units
	Place()
	if state.active then
		Card.Render()
	end
end

function Quests.Given()
	return state.give
end

function Quests.Active()
	return state.active
end

function Quests.Diagnostic()
	return " trigger=" .. tostring(state.trigger) .. " dirty=" .. tostring(state.dirty)
		.. " evaluateQueued=" .. tostring(state.queued) .. " replaceQueued=" .. tostring(state.replacing)
		.. " guide=" .. tostring(state.guide) .. " guideShown=" .. tostring(state.shown) .. " give=" .. tostring(state.give)
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
Quests.Replace = Replace

Skins.Add({
	key = KEY,
	label = L["Quest card"],
	help = L["Shows your tracked quests in the story rail, a few at a time; the wheel scrolls to the rest."],
	addon = "Blizzard_ObjectiveTracker",
	live = true,
	defaults = { shown = DEFAULT_SHOWN, continuation = true },
	rows = {
		{ type = "toggle", key = "continuation", label = L["Show the next quest"], help = L["Let the next quest continue under a soft fade. Off shows only complete quest rows."] },
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
