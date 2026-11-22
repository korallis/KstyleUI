-- test-skins-questie.lua: Questie's independent tracker cannot draw through the quest card, and its Forever watch hooks preserve separated quest rows at every acceptance screen.
local Boot = dofile("Tools/regression/questcard_guide_env.lua")
local Questie = dofile("Tools/regression/questie_fake.lua")
local Geometry = dofile("Tools/regression/geometry.lua")
local W = dofile("Tools/regression/widget_env.lua")

for _, screen in ipairs({ { width = 1920, height = 1080 }, { width = 2560, height = 1440 }, { width = 5120, height = 1440 }, { width = 3840, height = 2160 } }) do
	local R = Boot(screen, nil, nil, true, Questie.Install)
	local env, K, ns, other = R.env, R.K, R.ns, R.questie
	assert(not (other.frame:IsVisible() and ns.Quests.Card():IsVisible()), "Questie and the quest card draw on top of each other; use Questie's tracker option to select one")
	assert(env.Questie.db.profile.trackerEnabled and other.calls == 0, "Seed the first choice from Questie without switching its tracker off")
	K.Options.Write("Integrations", "questTracker", "kstyleui")
	R.settle()
	assert(ns.QuestData.Count() == #R.quests, "the card keeps Questie-only watches when handing tracking back to the native watch list")
	other.compat.HideWatchFrame()
	R.settle()
	assert(not other.suppressed, "Questie's previously registered widget hook cannot suppress the native scenario fallback after handover")
	env.ObjectiveTrackerFrame.scenario.contentsHeight = 60
	env.ObjectiveTrackerFrame:Update()
	R.settle()
	assert(not ns.Quests.Card():IsVisible() and env.ObjectiveTrackerFrame:IsVisible() and env.ObjectiveTrackerFrame:GetAlpha() == 1, "native scenario objectives return without Questie's suppression")
	env.ObjectiveTrackerFrame.scenario.contentsHeight = 0
	env.ObjectiveTrackerFrame:Update()
	R.settle()
	assert(K.Setup.Integrations.Detected("Skins")[1] == "Questie", "the Skins overlap notice detects Questie")
	assert(K.Setup.Integrations.Note("Skins", "standard"):find("Existing addons", 1, true), "the overlap notice points to the tracker choice")
	K.Options.Write("Integrations", "notices", false)
	assert(K.Setup.Integrations.Note("Skins", "standard") == "standard", "the existing notices switch also controls Questie notices")
	local seen = {}
	for _ = 1, #R.quests do
		local previous
		for _, row in ipairs(ns.Quests.Rows()) do
			if row:IsShown() and row.questID then
				local rect = assert(Geometry.ScaledRect(row, env.UIParent, K.Scale.Root()))
				assert(not previous or rect.top <= previous.bottom, "quest rows must not overlap after Questie's watch hook")
				previous = rect
				local title = assert(Geometry.ScaledRect(row.title, env.UIParent, K.Scale.Root()))
				for _, line in ipairs(row.lines) do
					if line.text:IsShown() then
						local objective = assert(Geometry.ScaledRect(line.text, env.UIParent, K.Scale.Root()))
						assert(objective.top <= title.bottom + K.Scale.Pixel(1), "objectives stay below their quest title")
					end
				end
				seen[row.questID] = true
			end
		end
		ns.QuestCard.Scroll(1)
	end
	for _, quest in ipairs(R.quests) do assert(seen[quest.id], "all Questie-watched quests are reachable") end
	K.Options.Write("Integrations", "questTracker", "both")
	R.settle()
	assert(other.frame:IsVisible() and ns.Quests.Card():IsVisible(), "both keeps Questie's tracker and KstyleUI's quest card visible")
	K.Options.Write("Integrations", "questTracker", "questie")
	R.settle()
	assert(other.frame:IsVisible() and not ns.Quests.Card():IsVisible(), "selecting Questie relinquishes the card")
	env.C_QuestLog.RemoveQuestWatch(301)
	assert(not other.watched[301], "Questie's Forever removal hook follows native untracking")
	env.C_QuestLog.AddQuestWatch(301)
	assert(other.watched[301], "Questie's Forever addition hook follows native tracking")
	env.SetCombat(true)
	K.Options.Write("Integrations", "questTracker", "kstyleui")
	R.settle()
	assert(other.frame:IsVisible() and not ns.Quests.Card():IsVisible(), "the handover waits for combat")
	env.SetCombat(false)
	R.settle()
	assert(ns.Quests.Card():IsVisible() and not other.frame:IsVisible(), "combat exit applies the latest tracker choice")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
	print("Questie " .. screen.width .. "x" .. screen.height .. ": one tracker, separated rows, watches retained")
end

do
	local R = Boot({ width = 1920, height = 1080 }, nil, nil, true)
	local other = Questie.Install(R.env, R.log, true, false)
	R.env.FireEvent("ADDON_LOADED", "Questie")
	R.settle()
	assert(other.calls == 0, "late Questie initialization retains its watches until its first update")
	other.started = true
	other:Update()
	R.settle()
	assert(other.calls == 0 and other.frame:IsVisible() and not R.ns.Quests.Card():IsVisible(), "Late Questie initialization keeps its current tracker on")
	R.K.Options.Write("Integrations", "questTracker", "kstyleui")
	R.settle()
	R.K.Options.Write("Skins", "quests.enabled", false)
	other:Toggle()
	R.settle()
	assert(other.frame:IsVisible(), "an off quest card leaves Questie's option alone")
	R.K.Options.Write("Skins", "quests.enabled", true)
	R.settle()
	assert(not other.frame:IsVisible() and R.ns.Quests.Card():IsVisible(), "reenabling the card reconciles the tracker choice")
end

do
	local R = Boot({ width = 1920, height = 1080 }, nil, nil, true, function(env, log) return Questie.Install(env, log, false, false) end)
	R.K.Options.Write("Integrations", "questTracker", "questie")
	R.settle()
	assert(not R.questie.reloaded and R.env.Questie.db.profile.trackerEnabled, "choosing Questie saves its option through Toggle without calling the immediately reloading Enable API")
	local host = R.K.Widgets.DialogHost()
	assert(host:IsShown() and host.visibleButtons[2].isReload, "a never-initialized tracker asks through the existing secure reload confirm")
	W.Enter(host.visibleButtons[2])
	local reload
	for _, frame in ipairs(R.env._frames) do
		if frame:GetAttribute("macrotext") == "/reload" then reload = frame end
	end
	assert(reload and reload:IsShown(), "Reload now offers the shared secure /reload action")
	W.Click(host.visibleButtons[1])
	R.settle()
	assert(not host:IsShown() and not R.questie.reloaded, "Later dismisses the confirmation without reloading")
	R.questie:Update()
	R.settle()
	assert(not host:IsShown(), "ordinary Questie updates do not reopen a deferred reload prompt")
	R.K.Options.Write("Integrations", "questTracker", "kstyleui")
	R.settle()
	assert(R.ns.Quests.Card():IsVisible() and not R.env.Questie.db.profile.trackerEnabled, "a deferred switch can return to KstyleUI without a reload")
	assert(#R.env._errors == 0 and R.K.ErrorCount() == 0, tostring(R.env._errors[1]))
end

-- With the Questie skin off, Questie's own SetFont costs KstyleUI no font lookup.
do
	local R = Boot({ width = 1920, height = 1080, uiScale = 768 / 1080 }, nil, nil, nil, Questie.Install)
	R.K.Options.Write("Integrations", "questTracker", "questie")
	R.settle()
	local text
	for _, region in ipairs({ R.env.Questie_BaseFrame:GetRegions() }) do
		if region:GetObjectType() == "FontString" then
			text = region
			break
		end
	end
	R.ns.Skins.Get("questie"):OnSwitch(false)
	local style, reads = R.ns.Style, 0
	local font = style.Font
	style.Font = function(...)
		reads = reads + 1
		return font(...)
	end
	for _ = 1, 10 do
		text:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
	end
	style.Font = font
	assert(reads == 0, "with the Questie skin off, PaintFont returns before it looks up the body face, not after " .. reads .. " lookups")
	assert(#R.env._errors == 0 and R.K.ErrorCount() == 0, tostring(R.env._errors[1]))
end

print("test-skins-questie: ok")
