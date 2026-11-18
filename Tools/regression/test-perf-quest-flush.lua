-- test-perf-quest-flush.lua: repeated quest events read new data but skip unchanged card renders, including retained partial reads.
local Boot = dofile("Tools/regression/questcard_guide_env.lua")
local R = Boot({ width = 1920, height = 1080 })
local renders, original = 0, R.ns.QuestCard.Render
R.ns.QuestCard.Render = function(...)
	renders = renders + 1
	return original(...)
end
R.log.Fire("QUEST_LOG_UPDATE")
R.settle()
assert(renders == 0, "P10: skip the card render when the quest flush changed no data")
R.quests[1].objectives[1].text = "Putrid Claw: 2/7"
R.log.Fire("QUEST_LOG_UPDATE")
R.settle()
assert(renders == 1, "P10: changed objective text must still render immediately after the throttle")
R.log.super = R.quests[2].id
R.log.Fire("SUPER_TRACKING_CHANGED")
R.settle()
assert(renders == 2, "P10: super-tracking order must invalidate the quest render")
R.quests[1].complete = true
R.log.Fire("QUEST_LOG_UPDATE")
R.settle()
assert(renders == 3, "P10: completion must invalidate the quest render")
R.quests[1].failed = true
R.log.Fire("QUEST_LOG_UPDATE")
R.settle()
assert(renders == 4, "P10: failure state must invalidate the quest render")
local quests = dofile("Tools/regression/quests_fake.lua").List(25)
for i = 9, 25 do
	R.log.Track(quests[i])
end
R.settle()
R.log.super = 0
R.log.Fire("SUPER_TRACKING_CHANGED")
R.settle()
dofile("Tools/regression/instruction_budget.lua")(function()
	R.log.Fire("QUEST_LOG_UPDATE")
	R.env.RunTimers()
end, 15000, "P10: skip unchanged quest flush renders and reuse quest entries")
assert(#R.env._errors == 0 and R.K.ErrorCount() == 0, "unchanged-flush skipping must preserve the card")
print("perf quest flush ok")
