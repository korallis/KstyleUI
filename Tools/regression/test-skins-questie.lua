-- test-skins-questie.lua: Questie's independent tracker cannot draw through the quest card, and its Forever watch hooks preserve separated quest rows at every acceptance screen.
local Boot = dofile("Tools/regression/questcard_guide_env.lua")
local Questie = dofile("Tools/regression/questie_fake.lua")
local Geometry = dofile("Tools/regression/geometry.lua")

for _, screen in ipairs({ { width = 1920, height = 1080 }, { width = 2560, height = 1440 }, { width = 5120, height = 1440 }, { width = 3840, height = 2160 } }) do
	local R = Boot(screen, nil, nil, true, Questie.Install)
	local env, K, ns, other = R.env, R.K, R.ns, R.questie
	assert(not (other.frame:IsVisible() and ns.Quests.Card():IsVisible()), "Questie and the quest card draw on top of each other; use Questie's tracker option to select one")
	assert(not env.Questie.db.profile.trackerEnabled and other.calls == 1, "the default choice turns off Questie's tracker through its own API exactly once")
	assert(ns.QuestData.Count() == #R.quests, "the card keeps Questie-only watches when handing tracking back to the native watch list")
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
	K.Options.Write("Integrations", "questTracker", "questie")
	R.settle()
	assert(other.frame:IsVisible() and not ns.Quests.Card():IsVisible(), "selecting Questie relinquishes the card")
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

print("test-skins-questie: ok")
