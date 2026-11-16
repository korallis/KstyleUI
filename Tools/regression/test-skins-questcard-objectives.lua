-- test-skins-questcard-objectives.lua: an open guide leaves complete quest rows accessible at the acceptance screens.
local Boot = dofile("Tools/regression/questcard_guide_env.lua")
local Geometry = dofile("Tools/regression/geometry.lua")

for _, screen in ipairs({ { width = 3456, height = 2234 }, { width = 1920, height = 1080 }, { width = 5120, height = 1440 } }) do
	for _, style in ipairs({ "medallions", "frames", "orbs" }) do
		local R = Boot(screen)
		R.K.Options.Write("HudStyle", "style", style)
		R.settle()
		local ns, env, K = R.ns, R.env, R.K
		local seen = {}
		for _ = 1, 8 do
			local view = assert(Geometry.ScaledRect(ns.Quests.Parts().view, env.UIParent, K.Scale.Root()))
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
		assert(R.rxp.RXPFrame:IsShown() and ns.RestedXP.Rail.Hidden() == 0, "the guide keeps its complete current step")
		assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
		print(style .. " " .. screen.width .. "x" .. screen.height .. ": all quest objectives visible through the wheel")
	end
end

print("test-skins-questcard-objectives: ok")
