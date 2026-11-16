-- test-skins-questcard-objectives.lua: an open guide leaves complete quest rows accessible at the acceptance screens.
local Boot = dofile("Tools/regression/questcard_guide_env.lua")
local Geometry = dofile("Tools/regression/geometry.lua")

for _, screen in ipairs({ { width = 3456, height = 2234 }, { width = 1920, height = 1080 }, { width = 5120, height = 1440 } }) do
	for _, style in ipairs({ "medallions", "frames", "orbs" }) do
		local R = Boot(screen)
		R.K.Options.Write("HudStyle", "style", style)
		R.settle()
		local ns, env, K = R.ns, R.env, R.K
		if screen.width == 5120 and style ~= "orbs" then
			assert(ns.Quests.Parts().cap.row:IsShown(), "a complete first quest fits with QUESTS 8 at 5120x1440, as on staging")
			assert(ns.Quests.Rows()[1].questID == 301 and not ns.Quests.Rows()[2]:IsShown(), "5120x1440 preserves staging's one visible quest")
			assert(ns.Quests.Parts().more:GetText() == "7 more, scroll down", "a full card keeps staging's scroll hint")
		end
		local hiddenSteps = ns.RestedXP.Rail.Hidden()
		local seen = {}
		for _ = 1, 8 do
			local parts = ns.Quests.Parts()
			local view = assert(Geometry.ScaledRect(ns.Quests.Parts().view, env.UIParent, K.Scale.Root()))
			if not parts.cap.row:IsShown() then
				local card = assert(Geometry.ScaledRect(ns.Quests.Card(), env.UIParent, K.Scale.Root()))
				local title = assert(Geometry.ScaledRect(ns.Quests.Rows()[1].title, env.UIParent, K.Scale.Root()))
				assert(card.top - title.top >= 11 - K.Scale.Pixel(1), "compact titles keep the normal eleven-unit top padding")
				assert(parts.more:GetText():find("Quests 8:", 1, true), "compact pages keep the total quest count visible")
			end
			for _, row in ipairs(ns.Quests.Rows()) do
				if row:IsShown() then
					seen[row.questID] = true
					local entry
					for i = 1, ns.QuestData.Count() do
						if ns.QuestData.Get(i).id == row.questID then entry = ns.QuestData.Get(i) end
					end
					for i = 1, entry.count do
						local line = row.lines[i]
						local what = style .. " " .. screen.width .. "x" .. screen.height .. " quest " .. row.questID .. " objective " .. i
						assert(line.text:IsVisible(), what .. ": scrolling must show objectives with their quest title")
						local rect = assert(Geometry.ScaledRect(line.text, env.UIParent, K.Scale.Root()))
						assert(rect.top <= view.top + K.Scale.Pixel(1) and rect.bottom >= view.bottom - K.Scale.Pixel(1), what .. ": the whole objective fits inside the clipped view")
						if entry.objectives[i].count then
							assert(line.count:IsVisible() and line.count:GetText() == entry.objectives[i].count, what .. ": progress is visible")
						end
					end
				end
			end
			local card = ns.Quests.Card()
			card:GetScript("OnMouseWheel")(card, -1)
		end
		for _, quest in ipairs(R.quests) do assert(seen[quest.id], "the wheel reaches every tracked quest") end
		ns.QuestCard.Scroll(-99)
		R.quests[1].objectives[1].text = "Obtain Enchanted Gyrozephyr from the northern shore of Windsong Lake and return to the camp: 0/7"
		R.log.Fire("QUEST_LOG_UPDATE")
		R.settle()
		local first = ns.Quests.Rows()[1].lines[1]
		assert(first.text:IsVisible() and first.count:IsVisible(), "a three-line first objective keeps its progress beside its title")
		local rect = assert(Geometry.ScaledRect(first.text, env.UIParent, K.Scale.Root()))
		local view = assert(Geometry.ScaledRect(ns.Quests.Parts().view, env.UIParent, K.Scale.Root()))
		assert(rect.bottom >= view.bottom - K.Scale.Pixel(1), "the complete wrapped first objective fits in the view")
		assert(R.rxp.RXPFrame:IsShown() and ns.RestedXP.Rail.Hidden() == hiddenSteps, "scrolling quests preserves the guide's visible steps")
		assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
		print(style .. " " .. screen.width .. "x" .. screen.height .. ": all quest objectives visible through the wheel")
	end
end

print("test-skins-questcard-objectives: ok")
