-- test-skins-questcard-diagnostics.lua: /kstyle test records a bounded, read-only quest-card snapshot in combat, redacts secret measurements and survives refused native getters without claiming the native render is correct.
local S = dofile("Tools/regression/skins_env.lua")
local Quests = dofile("Tools/regression/quests_fake.lua")

local env, K, ns = S.New({
	setup = function(env)
		env._resolveRects = true
		Quests.Install(env, Quests.List(8))
	end,
	before = function(env)
		Quests.Tracker(env, S.Blizzard(env))
	end,
})
K.Modules.Enable("Skins")
S.LoadAddOn(env, "Blizzard_ObjectiveTracker")
env.RunTimers()
S.W.Settle(env)
env.SetCombat(true)
S.W.Settle(env)

local parts = ns.Quests.Parts()
local before = {}
for _, frame in ipairs({ parts.card, parts.glass, parts.cap, parts.cap.label, parts.cap.count, parts.view, parts.more, ns.Quests.Rows()[1] }) do
	before[frame] = #frame._calls
end
parts.cap.GetFrameLevel = function() return env.Secret(12345) end
parts.cap.GetFrameStrata = function() return env.Secret("private-strata") end
parts.view.GetRect = function() error("native getter refused") end
parts.card.GetAlpha = function() return env.Secret(0.12345) end

local log = K.Store.Data().devlog
local start = #log
local passed, failed = K.DevTest.Run()
assert(passed and failed == 0, "/kstyle test can capture the quest-card snapshot during combat")
local entries, seen, redacted, refused, registered = 0, {}, false, false, false
for i = start + 1, #log do
	local entry = log[i]
	if entry.module == "Skins.Quests" then
		entries = entries + 1
		local message = entry.message
		assert(#message < 800, "each diagnostic line is bounded")
		assert(not message:find("12345", 1, true) and not message:find("private-strata", 1, true), "secret native state is never serialized")
		local part = message:match("^part=([^ ]+)")
		if part then seen[part] = true end
		if part == "cap" then
			redacted = message:find("GetFrameLevel=<secret>", 1, true) and message:find("GetFrameStrata=<secret>", 1, true)
		elseif part == "view" then
			refused = message:find("rect=<unavailable>", 1, true) ~= nil
		end
	elseif entry.module == "DevTest" and entry.message:find("PASS quest card diagnostics", 1, true) then
		registered = true
	end
end
assert(registered, "the quest snapshot is registered with /kstyle test")
assert(entries == 13, "one state line and twelve known parts bound the dump, got " .. entries)
for _, name in ipairs({ "holder", "card", "glass", "cap", "cap.title", "cap.count", "view", "more", "row.1", "row.1.title", "row.1.objective", "row.1.count" }) do
	assert(seen[name], "the snapshot includes " .. name)
end
assert(redacted and refused, "secret and unavailable frame state are explicit without raising")
for frame, mark in pairs(before) do
	for i = mark + 1, #frame._calls do
		local method = frame._calls[i].method
		assert(not method:match("^Set") and not method:match("^Clear") and method ~= "Show" and method ~= "Hide", "diagnostics never mutate a quest frame: " .. method)
	end
end
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))

do
	local autoEnv, autoK, autoNs = S.New({
		setup = function(otherEnv)
			otherEnv._resolveRects = true
			Quests.Install(otherEnv, Quests.List(8))
		end,
		before = function(otherEnv)
			Quests.Tracker(otherEnv, S.Blizzard(otherEnv))
		end,
	})
	autoK.Modules.Enable("Skins")
	S.LoadAddOn(autoEnv, "Blizzard_ObjectiveTracker")
	autoEnv.RunTimers()
	S.W.Settle(autoEnv)
	local function Automatic()
		local count = 0
		for _, entry in ipairs(autoK.Store.Data().devlog) do
			if entry.module == "Skins.Quests" and entry.message:find("automatic=no-visible-rows", 1, true) then
				count = count + 1
				assert(entry.message:find("measuredRows=", 1, true) and entry.message:find("slotHeight=", 1, true), "the automatic trigger records measured rows and slot height")
			end
		end
		return count
	end
	assert(Automatic() == 0, "a normally visible card never emits an automatic diagnostic")
	autoEnv.SetCombat(true)
	for _, row in ipairs(autoNs.Quests.Rows()) do row:Hide() end
	autoEnv.RunTimers()
	assert(Automatic() == 1, "the deferred combat check catches measured rows that are no longer visible")
	for _ = 1, 20 do autoNs.QuestCard.CheckDiagnostic() end
	assert(Automatic() == 1, "identical failures are deduplicated")
	local card = autoNs.Quests.Card()
	for height = 0, -5, -1 do
		autoNs.QuestCard.Place(autoNs.Quests.Holder(), 0, 200, card:GetWidth(), height)
		autoNs.QuestCard.Render()
	end
	assert(Automatic() == 3, "automatic diagnostics stop at three distinct snapshots per session")
	assert(#autoEnv._errors == 0 and autoK.ErrorCount() == 0, tostring(autoEnv._errors[1]))
end

do
	local emptyEnv, emptyK, emptyNs = S.New({
		setup = function(e)
			Quests.Install(e, Quests.List(8))
			e.C_QuestLog.GetTitleForQuestID = function() return nil end
		end,
		before = function(e) Quests.Tracker(e, S.Blizzard(e)) end,
	})
	emptyK.Modules.Enable("Skins")
	S.LoadAddOn(emptyEnv, "Blizzard_ObjectiveTracker")
	emptyEnv.RunTimers()
	local automatic, context = false, false
	for _, entry in ipairs(emptyK.Store.Data().devlog) do
		if entry.module == "Skins.Quests" then
			if entry.message:find("automatic=no-visible-rows measuredRows=0", 1, true) then automatic = true end
			if entry.message:find("watches=8 read=title-unavailable", 1, true)
				and entry.message:find("style=", 1, true) and entry.message:find("guideIsShown=", 1, true)
				and entry.message:find("trigger=", 1, true) then context = true end
		end
	end
	assert(emptyNs.QuestData.Count() == 0 and automatic and context, "a zero-row initial read records watched quests, missing input, HUD style, guide state and last trigger")
	assert(#emptyEnv._errors == 0 and emptyK.ErrorCount() == 0, tostring(emptyEnv._errors[1]))
end

print("test-skins-questcard-diagnostics: ok")
