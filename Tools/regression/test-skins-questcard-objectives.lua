-- test-skins-questcard-objectives.lua: an open guide leaves complete quest rows accessible at the acceptance screens.
local Boot = dofile("Tools/regression/questcard_guide_env.lua")
local Geometry = dofile("Tools/regression/geometry.lua")

for _, screen in ipairs({ { width = 3456, height = 2234 }, { width = 1920, height = 1080 }, { width = 5120, height = 1440 } }) do
	for _, style in ipairs({ "medallions", "frames", "orbs" }) do
		local R = Boot(screen)
		R.settle()
		local ns, env, K = R.ns, R.env, R.K
		if screen.width == 5120 and style ~= "orbs" then
			assert(ns.Quests.Parts().cap:IsShown(), "a complete first quest fits with QUESTS 8 at 5120x1440, as on staging")
			assert(ns.Quests.Rows()[1].questID == 301 and ns.Quests.Rows()[2]:IsShown(), "5120x1440 uses the composed height for the next quest")
			local complete = 0
			for _, row in ipairs(ns.Quests.Rows()) do if row:IsShown() and not row.clipped then complete = complete + 1 end end
			assert(ns.Quests.Parts().more:GetText() == (8 - complete) .. " more, scroll down", "the scroll hint counts quests not completely visible at the composed height")
		end
		local hiddenSteps = ns.RestedXP.Rail.Hidden()
		local seen = {}
		for _ = 1, 8 do
			local parts = ns.Quests.Parts()
			local view = assert(Geometry.ScaledRect(ns.Quests.Parts().view, env.UIParent, K.Scale.Root()))
			local cardBounds = assert(Geometry.ScaledRect(ns.Quests.Card(), env.UIParent, K.Scale.Root()))
			local point, relative, _, _, foot = parts.more:GetPoint(2)
			assert(point == "BOTTOM" and relative == ns.Quests.Card(), "the hint's bottom is anchored inside its card")
			local hintBottom = cardBounds.bottom + foot * K.Widgets.ScaleFactor(parts.more)
			assert(hintBottom - cardBounds.bottom >= K.Scale.Pixel(1) + 4 - 1e-6, "the hint's descenders and shadow must clear the bottom border; increase compact footer padding")
			local compact = parts.more:GetText():find("Quests 8:", 1, true) ~= nil
			if compact then
				assert(not parts.cap:IsShown() and not parts.cap.rule:IsVisible(), "compact pages must hide the section cap and its rule independently of the measured cap state")
				local title = assert(Geometry.ScaledRect(ns.Quests.Rows()[1].title, env.UIParent, K.Scale.Root()))
				assert(cardBounds.top - title.top >= 11 - K.Scale.Pixel(1), "compact titles keep the normal eleven-unit top padding")
				assert(parts.more:GetText():find("Quests 8:", 1, true), "compact pages keep the total quest count visible")
				local header = parts.glass.chrome.header or {}
				local rule = header[3]
				if rule and rule:IsVisible() then
					local rect = assert(Geometry.ScaledRect(rule, env.UIParent, K.Scale.Root()))
					assert(rect.top <= title.bottom or rect.bottom >= title.top or rect.right <= title.left or rect.left >= title.right,
						"a compact header rule must not overlap the first quest title's bounds")
				end
				for _, region in ipairs(header) do
					assert(not region:IsVisible(), "compact pages hide the empty header band and separator")
				end
			end
			for _, row in ipairs(ns.Quests.Rows()) do
				if row:IsShown() then
					seen[row.questID] = seen[row.questID] or not row.clipped or row == ns.Quests.Rows()[1]
					local entry
					for i = 1, ns.QuestData.Count() do
						if ns.QuestData.Get(i).id == row.questID then entry = ns.QuestData.Get(i) end
					end
					for i = 1, entry.count do
						local line = row.lines[i]
						local what = style .. " " .. screen.width .. "x" .. screen.height .. " quest " .. row.questID .. " objective " .. i
						assert(row.clipped or line.text:IsVisible(), what .. ": scrolling must show objectives with their quest title")
						if line.text:IsVisible() then
							local rect = assert(Geometry.ScaledRect(line.text, env.UIParent, K.Scale.Root()))
							assert(rect.top <= view.top + K.Scale.Pixel(1) and rect.bottom >= view.bottom - K.Scale.Pixel(1), what .. ": fit quest objectives to whole lines above the footer")
							if entry.objectives[i].count then
								assert(line.count:IsVisible() and line.count:GetText() == entry.objectives[i].count, what .. ": progress is visible")
							end
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
		assert(rect.bottom >= view.bottom - K.Scale.Pixel(1), "the displayed first objective and its progress fit inside the view")
		assert(R.rxp.RXPFrame:IsShown() and ns.RestedXP.Rail.Hidden() == hiddenSteps, "scrolling quests preserves the guide's visible steps")
		assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
		print(style .. " " .. screen.width .. "x" .. screen.height .. ": all quest objectives visible through the wheel")
	end
end

print("test-skins-questcard-objectives: ok")
